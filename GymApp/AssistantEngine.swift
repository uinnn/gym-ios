import Foundation
import Speech
import AVFoundation
import SwiftData

// MARK: - Transcrição de voz (no próprio iPhone quando disponível)

@Observable
@MainActor
final class SpeechTranscriber {
    var text = ""
    var recording = false
    var error: String?
    /// Muda quando a gravação termina (para disparar ações depois de falar).
    var finishedCount = 0

    @ObservationIgnored private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "pt-BR"))
    @ObservationIgnored private let engine = AVAudioEngine()
    @ObservationIgnored private var request: SFSpeechAudioBufferRecognitionRequest?
    @ObservationIgnored private var task: SFSpeechRecognitionTask?
    @ObservationIgnored private var prefix = ""

    func toggle(appendingTo current: String) async {
        if recording { stop(); return }
        error = nil
        guard await Self.authorize() else {
            error = "Permita o microfone e o reconhecimento de fala em Ajustes > Gym."
            return
        }
        guard let recognizer, recognizer.isAvailable else {
            error = "Reconhecimento de fala indisponível agora."
            return
        }
        prefix = current.isEmpty ? "" : current + " "
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            let req = SFSpeechAudioBufferRecognitionRequest()
            req.shouldReportPartialResults = true
            if recognizer.supportsOnDeviceRecognition { req.requiresOnDeviceRecognition = true }
            req.addsPunctuation = true
            req.contextualStrings = AssistantParser.speechHints
            request = req
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            input.removeTap(onBus: 0)
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { buf, _ in req.append(buf) }
            engine.prepare()
            try engine.start()
            recording = true
            task = recognizer.recognitionTask(with: req) { [weak self] result, err in
                Task { @MainActor in
                    guard let self else { return }
                    if let result { self.text = self.prefix + result.bestTranscription.formattedString }
                    if err != nil || result?.isFinal == true { self.stop() }
                }
            }
        } catch {
            self.error = "Não consegui usar o microfone."
            stop()
        }
    }

    func stop() {
        guard recording || task != nil else { return }
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.finish()
        request = nil; task = nil
        if recording { finishedCount += 1 }
        recording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private static func authorize() async -> Bool {
        let speech = await withCheckedContinuation { c in
            SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0 == .authorized) }
        }
        guard speech else { return false }
        return await AVAudioApplication.requestRecordPermission()
    }
}

// MARK: - Dados que o assistente consulta

struct AssistantData {
    var saved: [SavedFood] = []
    var logs: [FoodLog] = []            // ordem crescente de data
    var water: [WaterLog] = []
    var weights: [WeightEntry] = []     // ordem crescente de data
    var sessions: [WorkoutSession] = [] // qualquer ordem
    var cardio: [CardioSession] = []
    var moods: [MoodEntry] = []
    var sleeps: [SleepEntry] = []
    var profile: UserProfile?
    var targets: NutritionTargets = .fallback

    var bodyKg: Double { weights.last?.kg ?? 70 }

    func logs(on day: Date) -> [FoodLog] {
        let cal = Calendar.current
        return logs.filter { cal.isDate($0.date, inSameDayAs: day) }
    }

    func waterMl(on day: Date) -> Double {
        let cal = Calendar.current
        return water.filter { cal.isDate($0.date, inSameDayAs: day) }.map(\.ml).reduce(0, +)
    }
}

// MARK: - Rascunho de registro

struct AssistantDraft: Identifiable {
    enum Kind { case food, water, weight, sleep, mood, workout, exercise, cardio, measure, answer, unknown }
    let id = UUID()
    var kind: Kind
    var source: String
    /// Nome como foi falado (para aprender a escolha do usuário).
    var spoken = ""
    var food: FoodItem?
    var alternatives: [FoodItem] = []
    var grams: Double = 0
    var value: Double = 0
    var meal: Meal = .lunch
    var date: Date = .now
    // treino
    var exerciseID = ""
    var sets = 0
    var reps = 0
    var kg = 0.0
    // cardio
    var cardioKind: CardioKind = .run
    var km = 0.0
    var minutes = 0.0
    // medidas
    var part: BodyPart = .waist
    // resposta
    var text = ""

    var exercise: Exercise? { ExerciseCatalog.byID[exerciseID] }
    var isRecord: Bool { kind != .answer && kind != .unknown }
}

// MARK: - Interpretador local

/// Interpretador offline: entende frases como "comi 3 pães e 150 g de frango no almoço",
/// "supino 3x10 com 60 kg", "corri 5 km em 28 min", "cintura 82 cm", "quanto de proteína falta hoje?",
/// "na verdade foram 2 pães", "tira o arroz", "repete o café da manhã de ontem".
@MainActor
enum AssistantParser {
    /// Palavras que ajudam o reconhecimento de fala.
    static let speechHints = ["supino", "agachamento", "leg press", "puxada", "remada", "rosca", "tríceps", "stiff",
                              "whey", "tapioca", "cuscuz", "kg", "gramas", "séries", "repetições", "proteína", "calorias"]

    static func parse(_ raw: String, data: AssistantData) -> [AssistantDraft] {
        var text = " " + norm(raw) + " "
        guard text.trimmingCharacters(in: .whitespaces).count > 1 else { return [] }
        let cal = Calendar.current
        var date = Date.now
        if text.contains(" ontem") {
            date = cal.date(byAdding: .day, value: -1, to: .now) ?? .now
        }
        let isQuestion = raw.contains("?") || first(#"^\s*(quanto|quantos|quantas|como|qual|quais|o que|oque|falta|me diz|me fala|resumo|devo|posso|preciso|sera)\b"#, text) != nil
        if isQuestion {
            if let a = answer(text, data: data) { return [AssistantDraft(kind: .answer, source: raw, text: a)] }
            return [AssistantDraft(kind: .unknown, source: raw, text: "question")]
        }
        text = text.replacingOccurrences(of: " ontem ", with: " ").replacingOccurrences(of: " de ontem ", with: " ")

        var out: [AssistantDraft] = []
        let meal = detectMeal(text)

        // Divide em orações; correções e remoções agem sobre o que veio antes.
        let clauses = text
            .replacingOccurrences(of: " na verdade ", with: ". na verdade ")
            .replacingOccurrences(of: " corrigindo ", with: ". na verdade ")
            .replacingOccurrences(of: " ops ", with: ". na verdade ")
            .replacingOccurrences(of: " tira ", with: ". tira ")
            .replacingOccurrences(of: " remove ", with: ". tira ")
            .replacingOccurrences(of: " apaga ", with: ". tira ")
            .replacingOccurrences(of: " depois ", with: ". ")
            .components(separatedBy: CharacterSet(charactersIn: ".;!\n"))
            .map { " " + $0.trimmingCharacters(in: .whitespaces) + " " }
            .filter { $0.trimmingCharacters(in: .whitespaces).count > 1 }

        for clause in clauses {
            var c = clause
            // Remover
            if let m = first(#"^\s*tira\s+(?:o|a|os|as)?\s*(.+?)\s*$"#, c) {
                let key = singular(m.groups[0])
                out.removeAll { d in
                    d.kind == .food && (singular(norm(d.food?.name ?? "")).contains(key) || d.spoken.contains(key))
                }
                continue
            }
            let correcting = c.hasPrefix(" na verdade ")
            if correcting {
                c = c.replacingOccurrences(of: " na verdade ", with: " ")
                    .replacingOccurrences(of: " foram ", with: " ").replacingOccurrences(of: " foi ", with: " ")
                    .replacingOccurrences(of: " era ", with: " ").replacingOccurrences(of: " eram ", with: " ")
            }
            // Repetir refeição
            if first(#"\b(repet\w*|mesm[oa]|igual)\b"#, c) != nil {
                let m = detectMealOptional(c) ?? meal
                out += repeatMeal(m, data: data)
                continue
            }
            // Treino: séries
            let ex = exercises(c)
            if !ex.isEmpty {
                out += ex.map { var d = $0; d.date = date; return d }
                continue
            }
            // Cardio
            if let d = cardio(c) { var d = d; d.date = date; out.append(d); continue }
            // Medidas
            let ms = measures(c)
            if !ms.isEmpty { out += ms.map { var d = $0; d.date = date; return d }; c = strip(c, ms.map(\.source)) }

            out += simple(&c, date: date)
            // Alimentos
            for var d in foods(c, data: data) {
                d.meal = meal; d.date = date
                if correcting, let i = out.lastIndex(where: { $0.kind == .food && ($0.food?.id == d.food?.id || $0.spoken == d.spoken) }) {
                    out[i].grams = d.grams
                } else {
                    out.append(d)
                }
            }
        }
        return out
    }

    // MARK: Peso, sono, humor, água, abrir treino

    private static func simple(_ t: inout String, date: Date) -> [AssistantDraft] {
        var out: [AssistantDraft] = []
        if let m = first(#"(?:pesei|peso|pesando|estou com|to com|balanca)\D{0,12}(\d{2,3}(?:[.,]\d{1,2})?)\s*(?:kg|quilos?)?"#, t),
           let kg = num(m.groups[0]), (25...300).contains(kg) {
            out.append(AssistantDraft(kind: .weight, source: m.match, value: kg, date: date))
            t = t.replacingOccurrences(of: m.match, with: " ")
        }
        if let m = first(#"dormi\s+(?:umas?\s+|so\s+)?([\d.,]+|\w+)\s*(?:h\b|horas?)(?:\s+e\s+(meia|\d+\s*min\w*))?"#, t),
           var h = num(m.groups[0]) {
            if m.groups.count > 1, !m.groups[1].isEmpty { h += m.groups[1] == "meia" ? 0.5 : (num(m.groups[1]) ?? 0) / 60 }
            if (1...16).contains(h) { out.append(AssistantDraft(kind: .sleep, source: m.match, value: h, date: date)) }
            t = t.replacingOccurrences(of: m.match, with: " ")
        }
        if let m = first(#"humor\s*(?:de|nota|=)?\s*(\d)"#, t), let v = num(m.groups[0]), (1...5).contains(v) {
            out.append(AssistantDraft(kind: .mood, source: m.match, value: v, date: date))
            t = t.replacingOccurrences(of: m.match, with: " ")
        } else if let m = first(#"(?:estou|to|me sinto|me sentindo|dia)\s+(muito bem|otimo|feliz|animad\w|bem|normal|ok|cansad\w|triste|mal|estressad\w|ansios\w|pessimo|horrivel)"#, t) {
            let w = m.groups[0]
            let v: Double = ["muito bem", "otimo", "feliz"].contains(where: w.hasPrefix) || w.hasPrefix("animad") ? 5
                : w == "bem" ? 4 : (w == "normal" || w == "ok") ? 3
                : (w == "pessimo" || w == "horrivel") ? 1 : 2
            out.append(AssistantDraft(kind: .mood, source: m.match, value: v, date: date))
            t = t.replacingOccurrences(of: m.match, with: " ")
        }
        for m in all(#"(?:bebi\s+)?(\d+(?:[.,]\d+)?|um|uma|dois|duas|tres|quatro|cinco|meio|meia)?\s*(ml|l\b|litros?|copos?|garrafas?|garrafinhas?|xicaras?)\s*(?:de\s+)?agua"#, t) {
            let q = m.groups[0].isEmpty ? 1 : (num(m.groups[0]) ?? 1)
            let u = m.groups[1]
            let ml = u == "ml" ? q : (u.hasPrefix("l") ? q * 1000 : u.hasPrefix("copo") ? q * 250
                : u.hasPrefix("garrafa") ? q * 500 : q * 200)
            if ml > 0 && ml <= 5000 { out.append(AssistantDraft(kind: .water, source: m.match, value: ml, date: date)) }
            t = t.replacingOccurrences(of: m.match, with: " ")
        }
        if first(#"(?:comecar|iniciar|inicia|comeca|bora|vou|abre|abrir)\s+(?:o\s+|um\s+|meu\s+)?(?:treino|treinar)"#, t) != nil {
            out.append(AssistantDraft(kind: .workout, source: "começar treino"))
            t = t.replacingOccurrences(of: "treino", with: " ").replacingOccurrences(of: "treinar", with: " ")
        }
        return out
    }

    // MARK: Treino (séries, repetições, carga)

    private static let exerciseAliases: [(String, String)] = [
        ("supino inclinado com halter", "incline-db"), ("supino inclinado", "incline-bench"), ("supino declinado", "decline-bench"),
        ("supino com halter", "bench-db"), ("supino maquina", "chest-press"), ("supino fechado", "close-bench"), ("supino", "bench"),
        ("agachamento livre", "squat"), ("agachamento hack", "hack-squat"), ("hack", "hack-squat"), ("agachamento bulgaro", "bulgarian"),
        ("bulgaro", "bulgarian"), ("goblet", "goblet-squat"), ("agachamento", "squat"), ("leg press", "leg-press"), ("leg", "leg-press"),
        ("terra sumo", "sumo-deadlift"), ("levantamento terra", "deadlift"), ("terra", "deadlift"), ("stiff", "rdl"), ("romeno", "rdl"),
        ("cadeira extensora", "leg-extension"), ("extensora", "leg-extension"), ("cadeira flexora", "seated-leg-curl"),
        ("mesa flexora", "leg-curl"), ("flexora", "leg-curl"), ("abdutora", "abductor"), ("adutora", "adductor"),
        ("elevacao pelvica", "hip-thrust"), ("hip thrust", "hip-thrust"), ("afundo", "lunge"), ("passada", "walking-lunge"),
        ("panturrilha sentado", "seated-calf"), ("panturrilha", "standing-calf"), ("gemeos", "standing-calf"),
        ("puxada supinada", "lat-pulldown-under"), ("puxada triangulo", "lat-pulldown-close"), ("puxada", "lat-pulldown"),
        ("pulldown", "lat-pulldown"), ("barra fixa", "pullup"), ("barra", "pullup"), ("remada baixa", "seated-row"),
        ("remada sentada", "seated-row"), ("remada cavalinho", "tbar-row"), ("serrote", "db-row"), ("remada unilateral", "db-row"),
        ("remada maquina", "machine-row"), ("remada alta", "upright-row"), ("remada", "barbell-row"), ("pullover", "pullover"),
        ("desenvolvimento com halter", "db-press"), ("desenvolvimento maquina", "machine-press"), ("desenvolvimento arnold", "arnold-press"),
        ("desenvolvimento", "ohp"), ("elevacao lateral", "lateral-raise"), ("lateral", "lateral-raise"), ("elevacao frontal", "front-raise"),
        ("crucifixo inverso", "rear-delt-fly"), ("face pull", "face-pull"), ("encolhimento", "shrug"),
        ("rosca martelo", "hammer-curl"), ("martelo", "hammer-curl"), ("rosca alternada", "db-curl"), ("rosca scott", "preacher-curl"),
        ("scott", "preacher-curl"), ("rosca concentrada", "concentration-curl"), ("rosca polia", "cable-curl"), ("rosca direta", "barbell-curl"),
        ("rosca", "barbell-curl"), ("triceps corda", "triceps-rope"), ("triceps testa", "skullcrusher"), ("testa", "skullcrusher"),
        ("triceps frances", "overhead-ext"), ("frances", "overhead-ext"), ("triceps coice", "kickback"), ("triceps banco", "bench-dips"),
        ("triceps", "triceps-pushdown"), ("pulley", "triceps-pushdown"), ("crucifixo", "fly-db"), ("voador", "pec-deck"),
        ("peck deck", "pec-deck"), ("crossover", "cable-cross"), ("paralela", "dips-chest"), ("mergulho", "dips-chest"),
        ("flexao", "pushup"), ("abdominal infra", "leg-raise"), ("abdominal", "crunch"), ("prancha", "plank"), ("burpee", "burpee"),
    ]

    /// Encontra o exercício pelo nome falado (atalhos, nome do catálogo e erros de fala).
    static func matchExercise(_ spoken: String) -> Exercise? {
        let s = singular(norm(spoken)).trimmingCharacters(in: .whitespaces)
        guard s.count >= 3 else { return nil }
        if let id = UserDefaults.standard.dictionary(forKey: "assistant.exAliases")?[s] as? String, let x = ExerciseCatalog.byID[id] { return x }
        if let a = exerciseAliases.first(where: { s == $0.0 || s.hasPrefix($0.0 + " ") || s.hasSuffix(" " + $0.0) || s.contains(" " + $0.0 + " ") }),
           let x = ExerciseCatalog.byID[a.1] { return x }
        let words = s.split(separator: " ").map(String.init).filter { $0.count > 2 }
        guard !words.isEmpty else { return nil }
        let candidates = ExerciseCatalog.all.filter { x in
            let n = singular(norm(x.name))
            return words.allSatisfy { n.contains($0) }
        }
        if let best = candidates.min(by: { $0.name.count < $1.name.count }) { return best }
        // erro de fala: compara cada palavra com os atalhos
        for w in words where w.count >= 4 {
            if let a = exerciseAliases.first(where: { !$0.0.contains(" ") && distance(w, $0.0) <= (w.count > 6 ? 2 : 1) }) {
                return ExerciseCatalog.byID[a.1]
            }
        }
        return nil
    }

    private static func exercises(_ clause: String) -> [AssistantDraft] {
        // Só tenta se houver cara de série: "3x10", "3 series", "10 repeticoes".
        guard first(#"\d+\s*x\s*\d+|\bseries?\b|\brepeticoes\b|\breps?\b"#, clause) != nil else { return [] }
        let parts = clause.components(separatedBy: CharacterSet(charactersIn: ",")).flatMap { $0.components(separatedBy: " e ") }
        var out: [AssistantDraft] = []
        var lastExercise: Exercise?
        for p in parts {
            var sets = 0, reps = 0, kg = 0.0
            if let m = first(#"(\d+)\s*x\s*(\d+)"#, p) { sets = Int(m.groups[0]) ?? 0; reps = Int(m.groups[1]) ?? 0 }
            else if let m = first(#"(\d+|uma|duas|tres|quatro|cinco|seis)\s*series?\s*(?:de\s*)?(\d+)?"#, p) {
                sets = Int(num(m.groups[0]) ?? 0); reps = Int(m.groups[1]) ?? 0
                if reps == 0, let r = first(#"(\d+)\s*(?:reps?|repeticoes)"#, p) { reps = Int(r.groups[0]) ?? 0 }
            } else if let m = first(#"(\d+)\s*(?:reps?|repeticoes)"#, p) { sets = 1; reps = Int(m.groups[0]) ?? 0 }
            if let m = first(#"(\d+(?:[.,]\d+)?)\s*(?:kg|quilos?|kilos?)"#, p) { kg = num(m.groups[0]) ?? 0 }
            else if let m = first(#"(?:com|carga de|carga|peso de|a|@)\s+(\d+(?:[.,]\d+)?)\b(?!\s*(?:x|series?|reps?|repeticoes))"#, p) { kg = num(m.groups[0]) ?? 0 }
            let name = p.replacingOccurrences(of: #"\d+(?:[.,]\d+)?\s*(?:x\s*\d+|kg|quilos?|kilos?|series?|reps?|repeticoes)?"#,
                                              with: " ", options: .regularExpression)
                .replacingOccurrences(of: #"\b(fiz|fazendo|treinei|com|de|no|na|carga|peso|series?|reps?|repeticoes|uma|duas|tres|quatro|cinco|seis|cada|hoje)\b"#,
                                      with: " ", options: .regularExpression)
            let x = matchExercise(name) ?? (sets > 0 ? lastExercise : nil)
            guard let x, sets > 0 || reps > 0 else { continue }
            lastExercise = x
            var d = AssistantDraft(kind: .exercise, source: p.trimmingCharacters(in: .whitespaces))
            d.spoken = singular(norm(name)).trimmingCharacters(in: .whitespaces)
            d.exerciseID = x.id; d.sets = max(sets, 1); d.reps = max(reps, x.kind == .timed ? 1 : 1); d.kg = kg
            if reps == 0 { d.reps = 10 }
            out.append(d)
        }
        return out
    }

    // MARK: Cardio

    private static func cardio(_ c: String) -> AssistantDraft? {
        guard let k = first(#"\b(corri|corrida|correndo|caminhei|caminhada|andei|caminhando|pedalei|pedalada|bike|bicicleta|esteira)\b"#, c) else { return nil }
        let w = k.groups[0]
        let kind: CardioKind = ["pedalei", "pedalada", "bike", "bicicleta"].contains(w) ? .bike
            : ["caminhei", "caminhada", "andei", "caminhando"].contains(w) ? .walk : .run
        var km = 0.0, minutes = 0.0
        if let m = first(#"(\d+(?:[.,]\d+)?)\s*(?:km|quilometros?|k)\b"#, c) { km = num(m.groups[0]) ?? 0 }
        else if let m = first(#"(\d+)\s*(?:metros|m)\b"#, c) { km = (num(m.groups[0]) ?? 0) / 1000 }
        if let m = first(#"(\d+(?:[.,]\d+)?)\s*(?:h\b|horas?)(?:\s*e\s*(\d+)\s*(?:min\w*)?)?"#, c) {
            minutes = (num(m.groups[0]) ?? 0) * 60 + (Double(m.groups[1]) ?? 0)
        }
        if let m = first(#"(\d+)\s*(?:min\w*)"#, c), minutes == 0 || !c.contains(" e ") { minutes = max(minutes, num(m.groups[0]) ?? 0) }
        guard km > 0 || minutes > 0 else { return nil }
        let speed: Double = kind == .run ? 9.5 : kind == .walk ? 5 : 18
        if km == 0 { km = (speed * minutes / 60 * 10).rounded() / 10 }
        if minutes == 0 { minutes = (km / speed * 60).rounded() }
        var d = AssistantDraft(kind: .cardio, source: c.trimmingCharacters(in: .whitespaces))
        d.cardioKind = kind; d.km = km; d.minutes = minutes
        return d
    }

    // MARK: Medidas

    private static let partWords: [(String, BodyPart)] = [
        ("cintura", .waist), ("abdomen", .abdomen), ("barriga", .abdomen), ("umbigo", .abdomen), ("quadril", .hip),
        ("peitoral", .chest), ("peito", .chest), ("torax", .chest), ("braco esquerdo", .armL), ("braco direito", .armR),
        ("braco", .armR), ("biceps", .armR), ("antebraco esquerdo", .forearmL), ("antebraco", .forearmR),
        ("coxa esquerda", .thighL), ("coxa direita", .thighR), ("coxa", .thighR), ("panturrilha esquerda", .calfL),
        ("panturrilha direita", .calfR), ("panturrilha", .calfR), ("pescoco", .neck), ("ombros", .shoulders), ("ombro", .shoulders),
        ("punho", .wrist),
    ]

    private static func measures(_ c: String) -> [AssistantDraft] {
        var out: [AssistantDraft] = []
        for m in all(#"(cintura|abdomen|barriga|umbigo|quadril|peitoral|peito|torax|antebraco(?: esquerdo| direito)?|braco(?: esquerdo| direito)?|biceps|coxa(?: esquerda| direita)?|panturrilha(?: esquerda| direita)?|pescoco|ombros?|punho)\D{0,14}?(\d{2,3}(?:[.,]\d)?)\s*(?:cm|centimetros?)"#, c) {
            guard let cm = num(m.groups[1]), (10...200).contains(cm),
                  let p = partWords.first(where: { $0.0 == m.groups[0] })?.1 else { continue }
            var d = AssistantDraft(kind: .measure, source: m.match)
            d.part = p; d.value = cm
            out.append(d)
        }
        return out
    }

    // MARK: Repetir refeição

    private static func repeatMeal(_ meal: Meal, data: AssistantData) -> [AssistantDraft] {
        let cal = Calendar.current
        // última vez que essa refeição foi registrada antes de hoje
        let before = data.logs.filter { $0.meal == meal && !cal.isDateInToday($0.date) }
        guard let lastDay = before.last.map({ cal.startOfDay(for: $0.date) }) else {
            return [AssistantDraft(kind: .answer, source: "", text: "Não achei um \(meal.label.lowercased()) anterior para repetir.")]
        }
        return before.filter { cal.isDate($0.date, inSameDayAs: lastDay) }.map { l in
            var d = AssistantDraft(kind: .food, source: "repetir \(meal.label.lowercased())")
            d.food = l.asFood; d.grams = l.grams; d.meal = meal; d.alternatives = [l.asFood]
            d.spoken = singular(norm(l.name))
            return d
        }
    }

    // MARK: Refeição

    private static let mealWords: [(String, Meal)] = [
        ("cafe da manha", .breakfast), ("desjejum", .breakfast), ("lanche da manha", .morningSnack),
        ("almoco", .lunch), ("lanche da tarde", .afternoonSnack), ("pre treino", .afternoonSnack), ("pre-treino", .afternoonSnack),
        ("pos treino", .afternoonSnack), ("pos-treino", .afternoonSnack), ("lanche", .afternoonSnack), ("janta", .dinner),
        ("jantar", .dinner), ("ceia", .supper),
    ]

    private static func detectMealOptional(_ t: String) -> Meal? {
        if let m = mealWords.first(where: { t.contains($0.0) }) { return m.1 }
        if t.contains("almocei") { return .lunch }
        if t.contains("jantei") { return .dinner }
        if t.contains("lanchei") { return .afternoonSnack }
        return nil
    }

    private static func detectMeal(_ t: String) -> Meal {
        if let m = detectMealOptional(t) { return m }
        switch Calendar.current.component(.hour, from: .now) {
        case ..<10: return .breakfast
        case ..<12: return .morningSnack
        case ..<15: return .lunch
        case ..<18: return .afternoonSnack
        case ..<22: return .dinner
        default: return .supper
        }
    }

    // MARK: Alimentos

    private static let stop: Set<String> = ["de", "do", "da", "o", "a", "os", "as", "um", "uma", "so", "ai", "que", "ja", "e", "com",
                                            "agua", "hoje", "ontem", "tambem", "mais", "pouco", "muito", "isso", "foi", "foram"]

    private static func foods(_ text: String, data: AssistantData) -> [AssistantDraft] {
        var t = text
        for (k, _) in mealWords { t = t.replacingOccurrences(of: k, with: " , ") }
        for w in [" comi ", " comendo ", " almocei ", " jantei ", " lanchei ", " tomei ", " bebi ", " acabei de ", " hoje ",
                  " eu ", " no ", " na ", " pro ", " pra ", " agora ", " tambem ", " mais ", " uns ", " umas ", " meu ", " minha "] {
            t = t.replacingOccurrences(of: w, with: " , ")
        }
        let pieces = t.components(separatedBy: CharacterSet(charactersIn: ",?\n:"))
            .flatMap { $0.components(separatedBy: " e ") }
            .flatMap { $0.components(separatedBy: " com ") }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.count >= 2 && !stop.contains($0) }
        return pieces.compactMap { food($0, data: data) }
    }

    private static let units: [(String, Double?)] = [   // nil = usa a porção/unidade do alimento
        ("gramas", 1), ("grama", 1), ("gr", 1), ("g", 1), ("kg", 1000), ("quilo", 1000), ("ml", 1), ("litros", 1000), ("litro", 1000),
        ("fatias", 25), ("fatia", 25), ("colheres de sopa", 15), ("colher de sopa", 15), ("colheres de cha", 5), ("colher de cha", 5),
        ("colheres", 15), ("colher", 15), ("xicaras", 120), ("xicara", 120), ("copos", 200), ("copo", 200), ("conchas", 100), ("concha", 100),
        ("pedacos", 60), ("pedaco", 60), ("scoops", 30), ("scoop", 30), ("doses", 30), ("dose", 30), ("bifes", 100), ("bife de", 100),
        ("files", 100), ("file de", 100), ("potes", 170), ("pote", 170), ("latas", 350), ("lata", 350), ("pratos", 350), ("prato", 350),
        ("punhado", 30), ("porcoes", nil), ("porcao", nil), ("unidades", nil), ("unidade", nil),
    ]

    private static let numberWords: [String: Double] = [
        "um": 1, "uma": 1, "dois": 2, "duas": 2, "tres": 3, "quatro": 4, "cinco": 5, "seis": 6, "sete": 7, "oito": 8,
        "nove": 9, "dez": 10, "meio": 0.5, "meia": 0.5, "cem": 100, "cento e cinquenta": 150, "duzentos": 200,
        "duzentas": 200, "trezentos": 300, "trezentas": 300, "quatrocentos": 400, "quinhentos": 500,
    ]

    static func food(_ piece: String, data: AssistantData) -> AssistantDraft? {
        var s = piece
        var qty: Double? = nil
        if let m = first(#"^(\d+(?:[.,]\d+)?)"#, s) { qty = num(m.groups[0]); s = String(s.dropFirst(m.match.count)) }
        else if let w = numberWords.keys.sorted(by: { $0.count > $1.count }).first(where: { s.hasPrefix($0 + " ") }) {
            qty = numberWords[w]; s = String(s.dropFirst(w.count))
        }
        s = s.trimmingCharacters(in: .whitespaces)
        var unitG: Double?? = nil   // .some(nil) = porção
        for (u, g) in units where s.hasPrefix(u + " ") || s == u {
            unitG = .some(g); s = String(s.dropFirst(u.count)).trimmingCharacters(in: .whitespaces); break
        }
        for p in ["de ", "do ", "da ", "dos ", "das "] where s.hasPrefix(p) { s = String(s.dropFirst(p.count)) }
        s = s.trimmingCharacters(in: .whitespaces)
        guard s.count >= 2, !stop.contains(s) else { return nil }

        let (best, alts) = lookup(s, data: data)
        let spoken = singular(s)
        guard let best else { return AssistantDraft(kind: .unknown, source: piece, spoken: spoken) }
        let unitWeight = unitGrams(s, best)
        var grams: Double
        switch unitG {
        case .some(.some(let g)): grams = (qty ?? 1) * g
        case .some(.none): grams = (qty ?? 1) * (best.servingGrams ?? unitWeight ?? 100)
        case .none:
            let last: Double? = data.saved.first { $0.foodID == best.id }?.lastGrams
            let each: Double = unitWeight ?? best.servingGrams ?? 100
            if let q = qty { grams = q * each } else { grams = unitWeight ?? last ?? each }
        }
        grams = min(max(grams.rounded(), 1), 3000)
        return AssistantDraft(kind: .food, source: piece, spoken: spoken, food: best, alternatives: alts, grams: grams)
    }

    /// Nome falado → busca mais provável no banco.
    private static let synonyms: [(String, String)] = [
        ("pao de queijo", "pão de queijo"), ("pao integral", "pão trigo forma integral"), ("pao de forma", "pão trigo forma"),
        ("pao", "pão trigo francês"), ("frango", "frango peito sem pele grelhado"), ("peito de frango", "frango peito sem pele grelhado"),
        ("arroz integral", "arroz integral cozido"), ("arroz", "arroz tipo 1 cozido"), ("feijao preto", "feijão preto cozido"),
        ("feijao", "feijão carioca cozido"), ("ovo frito", "ovo galinha inteiro frito"), ("ovo", "ovo galinha inteiro cozido"),
        ("banana", "banana prata crua"), ("maca", "maçã fuji com casca"), ("batata doce", "batata doce cozida"),
        ("batata", "batata inglesa cozida"), ("carne moida", "carne bovina acém moído cozido"), ("carne", "carne bovina patinho grelhado"),
        ("bife", "carne bovina patinho grelhado"), ("patinho", "carne bovina patinho grelhado"), ("whey", "whey protein concentrado"),
        ("aveia", "aveia flocos"), ("leite", "leite vaca integral"), ("cafe", "café infusão"), ("iogurte", "iogurte natural"),
        ("queijo", "queijo minas frescal"), ("macarrao", "macarrão trigo cozido"), ("tapioca", "tapioca com manteiga"),
        ("cuscuz", "cuscuz milho cozido"), ("mamao", "mamão papaia"), ("laranja", "laranja pêra crua"), ("tomate", "tomate com semente"),
        ("alface", "alface crespa"), ("salada", "alface crespa"), ("acucar", "açúcar refinado"), ("azeite", "azeite oliva extra virgem"),
        ("manteiga", "manteiga com sal"), ("hamburguer", "hambúrguer bovino grelhado"), ("requeijao", "requeijão"),
        ("tilapia", "tilápia"), ("salmao", "salmão"), ("atum", "atum conserva"), ("pasta de amendoim", "amendoim pasta"),
        ("granola", "granola"), ("mel", "mel de abelha"), ("presunto", "presunto"), ("mussarela", "queijo mussarela"),
        ("muçarela", "queijo mussarela"), ("castanha", "castanha-do-brasil"), ("abacate", "abacate cru"), ("morango", "morango cru"),
    ]

    private static let aliasesKey = "assistant.aliases"

    /// Guarda a escolha do usuário ("frango" → "Frango, peito, cozido") para as próximas vezes.
    static func learn(spoken: String, food: FoodItem, context: ModelContext) {
        guard !spoken.isEmpty else { return }
        var d = UserDefaults.standard.dictionary(forKey: aliasesKey) as? [String: String] ?? [:]
        d[spoken] = food.id
        UserDefaults.standard.set(d, forKey: aliasesKey)
        let id = food.id
        if (try? context.fetch(FetchDescriptor<SavedFood>(predicate: #Predicate { $0.foodID == id })))?.first == nil {
            context.insert(SavedFood(food))   // garante que alimentos da IA/OFF possam ser achados depois
        }
    }

    static func learnExercise(spoken: String, id: String) {
        guard !spoken.isEmpty else { return }
        var d = UserDefaults.standard.dictionary(forKey: "assistant.exAliases") as? [String: String] ?? [:]
        d[spoken] = id
        UserDefaults.standard.set(d, forKey: "assistant.exAliases")
    }

    static func lookup(_ name: String, data: AssistantData) -> (FoodItem?, [FoodItem]) {
        let key = singular(name)
        let db = FoodDatabase.shared
        var results: [FoodItem] = []
        // 0) o que o usuário já escolheu para essa palavra
        if let id = (UserDefaults.standard.dictionary(forKey: aliasesKey) as? [String: String])?[key] {
            if let f = data.saved.first(where: { $0.foodID == id })?.food ?? db.food(id: id) { results.append(f) }
        }
        // 1) alimentos do próprio usuário (mais usados primeiro)
        let words = key.split(separator: " ").map(String.init)
        let mine = data.saved.sorted { $0.useCount > $1.useCount }.compactMap(\.food).filter { f in
            let n = singular(norm(f.name))
            return words.allSatisfy { n.contains($0) }
        }
        results += mine.prefix(3)
        // 2) sinônimos comuns e busca no banco
        if let syn = synonyms.first(where: { key == $0.0 || key.hasPrefix($0.0 + " ") }) {
            results += db.search(syn.1, limit: 3)
        }
        results += db.search(key, limit: 6)
        // 3) erro de fala: corrige palavra a palavra pelo vocabulário do banco
        if results.isEmpty {
            let fixed = words.map { Vocabulary.shared.closest($0) }.joined(separator: " ")
            if fixed != key {
                if let syn = synonyms.first(where: { fixed == $0.0 || fixed.hasPrefix($0.0 + " ") }) { results += db.search(syn.1, limit: 3) }
                results += db.search(fixed, limit: 6)
            }
        }
        if results.isEmpty, let w = words.max(by: { $0.count < $1.count }), w.count >= 4 { results += db.search(w, limit: 6) }
        var seen = Set<String>()
        let uniq = results.filter { seen.insert($0.id).inserted }
        return (uniq.first, Array(uniq.prefix(8)))
    }

    /// Peso típico de 1 unidade.
    private static func unitGrams(_ spoken: String, _ f: FoodItem) -> Double? {
        let s = singular(spoken)
        let table: [(String, Double)] = [
            ("pao de queijo", 40), ("bisnaguinha", 20), ("pao", 50), ("ovo", 50), ("banana", 90), ("maca", 130), ("laranja", 180),
            ("pera", 150), ("kiwi", 75), ("tangerina", 130), ("mexerica", 130), ("iogurte", 170), ("tapioca", 90), ("bife", 100),
            ("file", 100), ("coxa", 100), ("hamburguer", 90), ("batata", 150), ("castanha", 4), ("amendoa", 1.2), ("biscoito", 7),
            ("bolacha", 7), ("torrada", 10), ("whey", 30), ("barra", 40), ("coxinha", 80), ("pastel", 90), ("empada", 60),
            ("salsicha", 50), ("linguica", 80), ("pizza", 110), ("brigadeiro", 20), ("bombom", 20), ("cookie", 25), ("cafe", 50),
            ("abacate", 200), ("manga", 200), ("mamao", 150), ("goiaba", 170), ("pessego", 110), ("ameixa", 60), ("morango", 12),
            ("arroz", 150), ("feijao", 100), ("macarrao", 200), ("frango", 120), ("carne", 120), ("peixe", 120), ("salada", 50),
            ("cuscuz", 150), ("leite", 200), ("suco", 250), ("refrigerante", 350), ("cerveja", 350),
        ]
        if let t = table.first(where: { s.hasPrefix($0.0) }) { return t.1 }
        return f.servingGrams
    }

    // MARK: Perguntas respondidas localmente

    static func answer(_ t: String, data: AssistantData) -> String? {
        let cal = Calendar.current
        let day = t.contains("ontem") ? (cal.date(byAdding: .day, value: -1, to: .now) ?? .now) : .now
        let dayName = t.contains("ontem") ? "ontem" : "hoje"
        let logs = data.logs(on: day)
        let n = logs.map(\.nutrients).total
        let tg = data.targets

        func macro(_ name: String, _ v: Double, _ goal: Double, _ unit: String) -> String {
            let left = goal - v
            return left > 0
                ? "\(dayName.capitalized) você consumiu \(Int(v)) \(unit) de \(name) de \(Int(goal)) \(unit). Faltam \(Int(left)) \(unit)."
                : "\(dayName.capitalized) você consumiu \(Int(v)) \(unit) de \(name) — já bateu a meta de \(Int(goal)) \(unit)\(left < -goal * 0.1 ? " (passou \(Int(-left)) \(unit))" : "")."
        }
        if t.contains("protein") { return macro("proteína", n.protein, tg.protein, "g") + proteinTip(tg.protein - n.protein) }
        if t.contains("carbo") { return macro("carboidratos", n.carbs, tg.carbs, "g") }
        if t.contains("gordura") { return macro("gordura", n.fat, tg.fat, "g") }
        if t.contains("fibra") { return macro("fibras", n.fiber, tg.fiber, "g") }
        if t.contains("agua") || t.contains("bebi") {
            let ml = data.waterMl(on: day)
            return "\(dayName.capitalized) você bebeu \(Int(ml)) ml de \(Int(tg.water)) ml\(ml < tg.water ? " — faltam \(Int(tg.water - ml)) ml (~\(Int(((tg.water - ml) / 250).rounded(.up))) copos)" : ". Meta batida!")."
        }
        if t.contains("calori") || t.contains("kcal") || (t.contains("comi") && !t.contains("treino")) {
            var s = macro("calorias", n.kcal, tg.kcal, "kcal")
            if !logs.isEmpty {
                let top = Dictionary(grouping: logs, by: \.name).mapValues { $0.map(\.nutrients.kcal).reduce(0, +) }
                    .sorted { $0.value > $1.value }.prefix(3).map { "\($0.key) (\(Int($0.value)))" }
                s += " Maiores fontes: " + top.joined(separator: ", ") + "."
            }
            return s
        }
        if t.contains("peso") || t.contains("emagre") || t.contains("engord") {
            guard let last = data.weights.last else { return "Você ainda não tem pesagens registradas." }
            func change(_ days: Int) -> String? {
                guard let ref = data.weights.last(where: { $0.date <= cal.date(byAdding: .day, value: -days, to: .now)! }) else { return nil }
                let d = last.kg - ref.kg
                return "\(d >= 0 ? "+" : "")\(d.fmt(1)) kg em \(days) dias"
            }
            var s = "Último peso: \(last.kg.fmt(1)) kg (\(last.date.formatted(.relative(presentation: .named))))."
            let ch = [change(7), change(30)].compactMap { $0 }
            if !ch.isEmpty { s += " Variação: " + ch.joined(separator: ", ") + "." }
            if let g = data.profile?.goalWeightKg, g > 0 { s += " Faltam \(abs(last.kg - g).fmt(1)) kg para a meta de \(g.fmt(1)) kg." }
            return s
        }
        if t.contains("treino") || t.contains("treinei") || t.contains("academia") {
            let week = cal.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
            let done = data.sessions.filter { !$0.isActive && $0.start >= week }
            let last = data.sessions.filter { !$0.isActive }.max { $0.start < $1.start }
            var s = "Nesta semana você fez \(done.count) treino(s)."
            if let last { s += " Último: \(last.name), \(last.start.formatted(.relative(presentation: .named))), \(WorkoutMath.setsCount(last)) séries." }
            return s
        }
        if t.contains("sono") || t.contains("dormi") {
            let last7 = data.sleeps.filter { $0.wake >= cal.date(byAdding: .day, value: -7, to: .now)! }
            guard !last7.isEmpty else { return "Sem registros de sono nos últimos 7 dias." }
            let avg = last7.map(\.hours).reduce(0, +) / Double(last7.count)
            return "Média de sono nos últimos 7 dias: \(avg.fmt(1)) h\(avg < 7 ? " — abaixo das 7 h recomendadas" : "")."
        }
        if t.contains("resumo") || t.contains("como estou") || t.contains("como to") || t.contains("como foi") {
            let ml = data.waterMl(on: day)
            return "Resumo de \(dayName): \(Int(n.kcal))/\(Int(tg.kcal)) kcal, \(Int(n.protein))/\(Int(tg.protein)) g de proteína, \(Int(n.carbs)) g de carbo, \(Int(n.fat)) g de gordura e \(Int(ml))/\(Int(tg.water)) ml de água."
        }
        return nil
    }

    private static func proteinTip(_ left: Double) -> String {
        guard left > 15 else { return "" }
        let g = Int((left / 0.32).rounded())   // peito de frango ~32 g/100 g
        let eggs = Int((left / 6.5).rounded(.up))
        return " Isso dá ~\(g) g de peito de frango, \(Int((left / 24).rounded(.up))) scoop(s) de whey ou \(eggs) ovos."
    }

    // MARK: Utilidades

    nonisolated static func norm(_ s: String) -> String { FoodDatabase.normalize(s).lowercased() }

    nonisolated static func singular(_ s: String) -> String {
        s.split(separator: " ").map { w -> String in
            var w = String(w)
            if w.count > 3 {
                if w.hasSuffix("oes") || w.hasSuffix("aes") { w = String(w.dropLast(3)) + "ao" }
                else if w.hasSuffix("eis") { w = String(w.dropLast(3)) + "el" }
                else if w.hasSuffix("s") && !w.hasSuffix("ss") { w = String(w.dropLast()) }
            }
            return w
        }.joined(separator: " ")
    }

    private static func strip(_ s: String, _ parts: [String]) -> String {
        parts.reduce(s) { $0.replacingOccurrences(of: $1, with: " ") }
    }

    /// Distância de edição (Levenshtein) para tolerar erros de fala.
    nonisolated static func distance(_ a: String, _ b: String) -> Int {
        let a = Array(a.utf8), b = Array(b.utf8)
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var prev = Array(0...b.count), cur = Array(repeating: 0, count: b.count + 1)
        for i in 1...a.count {
            cur[0] = i
            for j in 1...b.count {
                cur[j] = min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1))
            }
            swap(&prev, &cur)
        }
        return prev[b.count]
    }

    struct Match { let match: String; let groups: [String] }

    private static var regexCache: [String: NSRegularExpression] = [:]

    static func first(_ p: String, _ s: String) -> Match? { all(p, s).first }

    static func all(_ p: String, _ s: String) -> [Match] {
        let re: NSRegularExpression
        if let r = regexCache[p] { re = r } else {
            guard let r = try? NSRegularExpression(pattern: p, options: [.caseInsensitive]) else { return [] }
            regexCache[p] = r; re = r
        }
        let ns = s as NSString
        return re.matches(in: s, range: NSRange(location: 0, length: ns.length)).map { m in
            Match(match: ns.substring(with: m.range),
                  groups: (1..<m.numberOfRanges).map { m.range(at: $0).location == NSNotFound ? "" : ns.substring(with: m.range(at: $0)) })
        }
    }

    static func num(_ s: String) -> Double? {
        let t = s.trimmingCharacters(in: .whitespaces)
        if let v = Double(t.replacingOccurrences(of: ",", with: ".")) { return v }
        if let v = numberWords[t] { return v }
        if let m = first(#"(\d+)"#, t) { return Double(m.groups[0]) }
        return nil
    }

    // MARK: Executar

    @discardableResult
    static func commit(_ drafts: [AssistantDraft], data: AssistantData, in context: ModelContext) -> [String] {
        var done: [String] = []
        var measure: MeasurementEntry?
        let exercises = drafts.filter { $0.kind == .exercise }
        for d in drafts {
            switch d.kind {
            case .food:
                guard let f = d.food else { continue }
                Diary.log(f, grams: d.grams, meal: d.meal, date: Diary.timestamp(for: d.date), in: context)
                done.append("\(f.name) (\(Int(d.grams)) g)")
            case .water:
                context.insert(WaterLog(date: Diary.timestamp(for: d.date), ml: d.value))
                done.append("\(Int(d.value)) ml de água")
            case .weight:
                context.insert(WeightEntry(date: Diary.timestamp(for: d.date), kg: d.value, source: "manual"))
                done.append("peso \(d.value.fmt(1)) kg")
            case .sleep:
                let wake = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: d.date) ?? d.date
                context.insert(SleepEntry(bedtime: wake.addingTimeInterval(-d.value * 3600), wake: wake, quality: 3))
                done.append("sono de \(d.value.fmt(1)) h")
            case .mood:
                context.insert(MoodEntry(date: Diary.timestamp(for: d.date), mood: Int(d.value)))
                done.append("humor \(Int(d.value))")
            case .workout:
                AppRouter.shared.tab = 3
                AppRouter.shared.openWorkout = true
                done.append("treino aberto")
            case .cardio:
                let s = CardioSession(kind: d.cardioKind)
                s.seconds = d.minutes * 60
                s.km = d.km
                s.start = Diary.timestamp(for: d.date).addingTimeInterval(-s.seconds)
                s.kcal = d.cardioKind.kcal(kg: data.bodyKg, km: d.km, seconds: s.seconds, climbM: 0)
                context.insert(s)
                done.append("\(d.cardioKind.title): \(d.km.fmt(1)) km em \(Int(d.minutes)) min")
            case .measure:
                if measure == nil { let m = MeasurementEntry(date: Diary.timestamp(for: d.date)); context.insert(m); measure = m }
                measure?[d.part] = d.value
                done.append("\(d.part.label): \(d.value.fmt(1)) cm")
            case .exercise, .answer, .unknown: continue
            }
        }
        if !exercises.isEmpty {
            let items = exercises.map { d in
                SessionExercise(exerciseID: d.exerciseID, sets: (0..<d.sets).map { _ in
                    var s = SetLog(); s.kg = d.kg; s.reps = d.reps; s.done = true; return s
                })
            }
            if let active = data.sessions.first(where: { $0.isActive }) {
                var ex = active.exercises
                for it in items {
                    if let i = ex.firstIndex(where: { $0.exerciseID == it.exerciseID }) { ex[i].sets += it.sets } else { ex.append(it) }
                }
                active.exercises = ex
                done.append("\(items.count) exercício(s) adicionados ao treino em andamento")
            } else {
                let s = WorkoutSession(name: "Treino registrado", exercises: items, bodyKg: data.bodyKg)
                let sets = items.map(\.sets.count).reduce(0, +)
                let end = Diary.timestamp(for: exercises[0].date)
                s.start = end.addingTimeInterval(-Double(sets) * 150)
                s.end = end
                context.insert(s)
                done.append("treino com \(items.count) exercício(s) e \(sets) séries")
            }
        }
        try? context.save()
        return done
    }
}

/// Vocabulário do banco de alimentos, para corrigir palavras mal transcritas.
final class Vocabulary {
    static let shared = Vocabulary()
    private lazy var words: [String] = {
        var set = Set<String>()
        for f in FoodDatabase.shared.foods {
            for w in AssistantParser.singular(AssistantParser.norm(f.name)).split(whereSeparator: { !$0.isLetter }) where w.count >= 4 {
                set.insert(String(w))
            }
        }
        return Array(set)
    }()
    private lazy var lookup = Set(words)

    @MainActor func closest(_ w: String) -> String {
        guard w.count >= 4, !lookup.contains(w) else { return w }
        let limit = w.count > 6 ? 2 : 1
        var best = w, bestD = limit + 1
        for c in words where abs(c.count - w.count) <= limit {
            let d = AssistantParser.distance(w, c)
            if d < bestD { bestD = d; best = c; if d == 1 { break } }
        }
        return best
    }
}
