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

// MARK: - Interpretação dos comandos

struct AssistantDraft: Identifiable {
    enum Kind { case food, water, weight, sleep, mood, workout, unknown }
    let id = UUID()
    var kind: Kind
    var source: String
    var food: FoodItem?
    var alternatives: [FoodItem] = []
    var grams: Double = 0
    var value: Double = 0
    var meal: Meal = .lunch
    var date: Date = .now
}

/// Interpretador offline: entende frases como "comi 3 pães e 150 g de frango no almoço",
/// "bebi 2 copos de água", "pesei 82,5 kg", "dormi 7 horas", "humor 4", "começar treino".
@MainActor
enum AssistantParser {
    static func parse(_ raw: String, saved: [SavedFood]) -> [AssistantDraft] {
        var t = " " + FoodDatabase.normalize(raw).lowercased()
            .replacingOccurrences(of: "\n", with: " ") + " "
        guard t.trimmingCharacters(in: .whitespaces).count > 1 else { return [] }
        var out: [AssistantDraft] = []
        let cal = Calendar.current
        var date = Date.now
        if t.contains(" ontem") {
            date = cal.date(byAdding: .day, value: -1, to: .now) ?? .now
            t = t.replacingOccurrences(of: "ontem", with: " ")
        }

        // Peso
        if let m = first(#"(?:pesei|peso|pesando|estou com|to com|balanca)\D{0,12}(\d{2,3}(?:[.,]\d{1,2})?)\s*(?:kg|quilos?)?"#, t),
           let kg = num(m.groups[0]), (25...300).contains(kg) {
            out.append(AssistantDraft(kind: .weight, source: m.match, value: kg, date: date))
            t = t.replacingOccurrences(of: m.match, with: " ")
        }
        // Sono
        if let m = first(#"dormi\s+(?:umas?\s+)?([\d.,]+|\w+)\s*(?:h\b|horas?)(?:\s+e\s+(meia|\d+\s*min\w*))?"#, t),
           var h = num(m.groups[0]) {
            if m.groups.count > 1, !m.groups[1].isEmpty { h += m.groups[1] == "meia" ? 0.5 : (num(m.groups[1]) ?? 0) / 60 }
            if (1...16).contains(h) { out.append(AssistantDraft(kind: .sleep, source: m.match, value: h, date: date)) }
            t = t.replacingOccurrences(of: m.match, with: " ")
        }
        // Humor
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
        // Água
        for m in all(#"(?:bebi\s+)?(\d+(?:[.,]\d+)?|um|uma|dois|duas|tres|quatro|cinco|meio|meia)?\s*(ml|l\b|litros?|copos?|garrafas?|garrafinhas?|xicaras?)\s*(?:de\s+)?agua"#, t) {
            let q = m.groups[0].isEmpty ? 1 : (num(m.groups[0]) ?? 1)
            let u = m.groups[1]
            let ml = u == "ml" ? q : (u.hasPrefix("l") ? q * 1000 : u.hasPrefix("copo") ? q * 250
                : u.hasPrefix("garrafinha") ? q * 500 : u.hasPrefix("garrafa") ? q * 500 : q * 200)
            if ml > 0 && ml <= 5000 { out.append(AssistantDraft(kind: .water, source: m.match, value: ml, date: date)) }
            t = t.replacingOccurrences(of: m.match, with: " ")
        }
        // Treino
        if first(#"(?:comecar|iniciar|inicia|comeca|bora|vou)\s+(?:o\s+|um\s+)?(?:treino|treinar)"#, t) != nil {
            out.append(AssistantDraft(kind: .workout, source: "começar treino"))
            t = t.replacingOccurrences(of: "treino", with: " ").replacingOccurrences(of: "treinar", with: " ")
        }

        // Alimentos
        let meal = detectMeal(t, date: date)
        for (k, _) in mealWords { t = t.replacingOccurrences(of: k, with: " , ") }
        for w in [" comi ", " comendo ", " almocei ", " jantei ", " lanchei ", " tomei ", " bebi ", " acabei de ", " hoje ",
                  " eu ", " no ", " na ", " pro ", " pra ", " agora ", " tambem ", " mais ", " depois "] {
            t = t.replacingOccurrences(of: w, with: " , ")
        }
        let pieces = t.components(separatedBy: CharacterSet(charactersIn: ",.;!?\n"))
            .flatMap { $0.components(separatedBy: " e ") }
            .flatMap { $0.components(separatedBy: " com ") }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.count >= 2 && !stop.contains($0) }
        for p in pieces {
            if var d = food(p, saved: saved) { d.meal = meal; d.date = date; out.append(d) }
        }
        return out
    }

    // MARK: Refeição

    private static let mealWords: [(String, Meal)] = [
        ("cafe da manha", .breakfast), ("desjejum", .breakfast), ("lanche da manha", .morningSnack),
        ("almoco", .lunch), ("lanche da tarde", .afternoonSnack), ("pre treino", .afternoonSnack),
        ("pos treino", .afternoonSnack), ("lanche", .afternoonSnack), ("janta", .dinner), ("jantar", .dinner), ("ceia", .supper),
    ]

    private static func detectMeal(_ t: String, date: Date) -> Meal {
        if let m = mealWords.first(where: { t.contains($0.0) }) { return m.1 }
        if t.contains("almocei") { return .lunch }
        if t.contains("jantei") { return .dinner }
        if t.contains("lanchei") { return .afternoonSnack }
        let h = Calendar.current.component(.hour, from: .now)
        switch h {
        case ..<10: return .breakfast
        case ..<12: return .morningSnack
        case ..<15: return .lunch
        case ..<18: return .afternoonSnack
        case ..<22: return .dinner
        default: return .supper
        }
    }

    private static let stop: Set<String> = ["de", "do", "da", "o", "a", "um", "uma", "so", "ai", "que", "ja", "e", "com", "agua", "hoje", "ontem"]

    // MARK: Um alimento

    private static let units: [(String, Double?)] = [   // nil = usa a porção/unidade do alimento
        ("gramas", 1), ("grama", 1), ("gr", 1), ("g", 1), ("kg", 1000), ("quilo", 1000), ("ml", 1), ("litro", 1000),
        ("fatias", 25), ("fatia", 25), ("colheres de sopa", 15), ("colher de sopa", 15), ("colheres de cha", 5), ("colher de cha", 5),
        ("colheres", 15), ("colher", 15), ("xicaras", 120), ("xicara", 120), ("copos", 200), ("copo", 200), ("conchas", 100), ("concha", 100),
        ("pedacos", 60), ("pedaco", 60), ("scoops", 30), ("scoop", 30), ("dose", 30), ("doses", 30), ("bifes", 100), ("bife de", 100),
        ("files", 100), ("file de", 100), ("potes", 170), ("pote", 170), ("latas", 350), ("lata", 350), ("pratos", 350), ("prato", 350),
        ("porcoes", nil), ("porcao", nil), ("unidades", nil), ("unidade", nil),
    ]

    private static let numberWords: [String: Double] = [
        "um": 1, "uma": 1, "dois": 2, "duas": 2, "tres": 3, "quatro": 4, "cinco": 5, "seis": 6, "sete": 7, "oito": 8,
        "nove": 9, "dez": 10, "meio": 0.5, "meia": 0.5, "duzentos": 200, "trezentos": 300, "cem": 100, "cento e cinquenta": 150,
    ]

    static func food(_ piece: String, saved: [SavedFood]) -> AssistantDraft? {
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

        let (best, alts) = lookup(s, saved: saved)
        guard let best else { return AssistantDraft(kind: .unknown, source: piece) }
        let unitWeight = unitGrams(s, best)
        var grams: Double
        switch unitG {
        case .some(.some(let g)): grams = (qty ?? 1) * g
        case .some(.none): grams = (qty ?? 1) * (best.servingGrams ?? unitWeight ?? 100)
        case .none: grams = qty.map { $0 * (unitWeight ?? best.servingGrams ?? 100) } ?? (unitWeight ?? best.servingGrams ?? 100)
        }
        grams = min(max(grams.rounded(), 1), 3000)
        return AssistantDraft(kind: .food, source: piece, food: best, alternatives: alts, grams: grams)
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
    ]

    static func singular(_ s: String) -> String {
        s.split(separator: " ").map { w -> String in
            var w = String(w)
            if w.count > 3 {
                if w.hasSuffix("oes") || w.hasSuffix("aes") { w = String(w.dropLast(3)) + "ao" }
                else if w.hasSuffix("eis") { w = String(w.dropLast(3)) + "el" }
                else if w.hasSuffix("s") { w = String(w.dropLast()) }
            }
            return w
        }.joined(separator: " ")
    }

    static func lookup(_ name: String, saved: [SavedFood]) -> (FoodItem?, [FoodItem]) {
        let key = singular(name)
        let words = key.split(separator: " ").map(String.init)
        // 1) alimentos do próprio usuário (mais usados primeiro)
        let mine = saved.sorted { $0.useCount > $1.useCount }.compactMap(\.food).filter { f in
            let n = singular(FoodDatabase.normalize(f.name).lowercased())
            return words.allSatisfy { n.contains($0) }
        }
        let db = FoodDatabase.shared
        var results = Array(mine.prefix(3))
        if let syn = synonyms.first(where: { key == $0.0 || key.hasPrefix($0.0 + " ") }) {
            results += db.search(syn.1, limit: 3)
        }
        results += db.search(key, limit: 6)
        if results.isEmpty, let w = words.first { results += db.search(w, limit: 6) }
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
        ]
        if let t = table.first(where: { s.hasPrefix($0.0) }) { return t.1 }
        return f.servingGrams
    }

    // MARK: Regex

    struct Match { let match: String; let groups: [String] }

    private static func first(_ p: String, _ s: String) -> Match? { all(p, s).first }

    private static func all(_ p: String, _ s: String) -> [Match] {
        guard let re = try? NSRegularExpression(pattern: p, options: [.caseInsensitive]) else { return [] }
        let ns = s as NSString
        return re.matches(in: s, range: NSRange(location: 0, length: ns.length)).map { m in
            Match(match: ns.substring(with: m.range),
                  groups: (1..<m.numberOfRanges).map { m.range(at: $0).location == NSNotFound ? "" : ns.substring(with: m.range(at: $0)) })
        }
    }

    static func num(_ s: String) -> Double? {
        if let v = Double(s.replacingOccurrences(of: ",", with: ".")) { return v }
        if let m = first(#"(\d+)"#, s) { return Double(m.groups[0]) }
        return numberWords[s.trimmingCharacters(in: .whitespaces)]
    }

    // MARK: Executar

    @discardableResult
    static func commit(_ drafts: [AssistantDraft], in context: ModelContext) -> [String] {
        var done: [String] = []
        for d in drafts {
            switch d.kind {
            case .food:
                guard let f = d.food else { continue }
                Diary.log(f, grams: d.grams, meal: d.meal, date: d.date, in: context)
                done.append("\(f.name) (\(Int(d.grams)) g)")
            case .water:
                context.insert(WaterLog(date: d.date, ml: d.value))
                done.append("\(Int(d.value)) ml de água")
            case .weight:
                context.insert(WeightEntry(date: d.date, kg: d.value, source: "manual"))
                done.append("peso \(d.value.fmt(1)) kg")
            case .sleep:
                let wake = Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: d.date) ?? d.date
                context.insert(SleepEntry(bedtime: wake.addingTimeInterval(-d.value * 3600), wake: wake, quality: 3))
                done.append("sono de \(d.value.fmt(1)) h")
            case .mood:
                context.insert(MoodEntry(date: d.date, mood: Int(d.value)))
                done.append("humor \(Int(d.value))")
            case .workout:
                AppRouter.shared.tab = 3
                AppRouter.shared.openWorkout = true
                done.append("treino aberto")
            case .unknown: continue
            }
        }
        try? context.save()
        return done
    }
}
