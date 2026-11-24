import Foundation
import Observation
import SwiftData
import SwiftUI
import UserNotifications

// MARK: - Humor

enum MoodTag: String, CaseIterable, Identifiable, Codable {
    case work, study, family, friends, partner, workout, badSleep, sick, nature, leisure, money, alone, food, alcohol, travel, screen
    var id: String { rawValue }
    var label: String {
        switch self {
        case .work: "Trabalho"
        case .study: "Estudos"
        case .family: "Família"
        case .friends: "Amigos"
        case .partner: "Relacionamento"
        case .workout: "Treino"
        case .badSleep: "Dormi mal"
        case .sick: "Doente"
        case .nature: "Sol / natureza"
        case .leisure: "Lazer"
        case .money: "Dinheiro"
        case .alone: "Sozinho(a)"
        case .food: "Comida"
        case .alcohol: "Álcool"
        case .travel: "Viagem"
        case .screen: "Muita tela"
        }
    }
    var icon: String {
        switch self {
        case .work: "briefcase.fill"
        case .study: "book.fill"
        case .family: "house.fill"
        case .friends: "person.2.fill"
        case .partner: "heart.fill"
        case .workout: "dumbbell.fill"
        case .badSleep: "bed.double.fill"
        case .sick: "cross.case.fill"
        case .nature: "sun.max.fill"
        case .leisure: "gamecontroller.fill"
        case .money: "dollarsign.circle.fill"
        case .alone: "person.fill"
        case .food: "fork.knife"
        case .alcohol: "wineglass.fill"
        case .travel: "airplane"
        case .screen: "iphone"
        }
    }
}

enum Mood {
    static let emojis = ["😢", "😕", "😐", "🙂", "😄"]
    static let labels = ["Muito mal", "Mal", "Neutro", "Bem", "Muito bem"]
    static func color(_ v: Double) -> Color {
        switch v {
        case ..<1.8: Theme.danger
        case ..<2.6: Theme.warm
        case ..<3.4: Theme.info
        case ..<4.2: Theme.good
        default: Theme.excellent
        }
    }
    static func emoji(_ v: Double) -> String { emojis[min(max(Int(v.rounded()) - 1, 0), 4)] }
}

@Model
final class MoodEntry {
    // Sincronização com o site (vazio/0 = nunca enviado)
    var syncID: String = ""
    var syncUpdated: Double = 0
    var syncSent: Double = 0
    var date: Date = Date.now
    var mood: Int = 3          // 1–5
    var energy: Int = 3        // 1–5
    var stress: Int = 3        // 1–5 (5 = muito estresse)
    var anxiety: Int = 3       // 1–5
    var tagsRaw: String = ""
    var note: String = ""

    init(date: Date = .now, mood: Int) { self.date = date; self.mood = mood }

    var tags: Set<MoodTag> {
        get { Set(tagsRaw.split(separator: ",").compactMap { MoodTag(rawValue: String($0)) }) }
        set { tagsRaw = newValue.map(\.rawValue).sorted().joined(separator: ",") }
    }
}

// MARK: - Sono

@Model
final class SleepEntry {
    // Sincronização com o site (vazio/0 = nunca enviado)
    var syncID: String = ""
    var syncUpdated: Double = 0
    var syncSent: Double = 0
    var bedtime: Date = Date.now
    var wake: Date = Date.now
    var quality: Int = 3       // 1–5
    var awakenings: Int = 0
    var note: String = ""

    init(bedtime: Date, wake: Date, quality: Int) { self.bedtime = bedtime; self.wake = wake; self.quality = quality }

    var hours: Double { max(0, wake.timeIntervalSince(bedtime) / 3600) }
    /// Dia a que o sono pertence (o dia em que acordou).
    var day: Date { Calendar.current.startOfDay(for: wake) }
}

// MARK: - Práticas (respiração, meditação, foco, ar livre)

enum PracticeKind: String, CaseIterable, Codable {
    case breathing, relaxation, meditation, focus, outdoor
    var label: String {
        switch self {
        case .breathing: "Respiração"
        case .relaxation: "Relaxamento"
        case .meditation: "Meditação"
        case .focus: "Foco"
        case .outdoor: "Ar livre"
        }
    }
    var icon: String {
        switch self {
        case .breathing: "wind"
        case .relaxation: "figure.mind.and.body"
        case .meditation: "brain.head.profile"
        case .focus: "timer"
        case .outdoor: "sun.max.fill"
        }
    }
}

@Model
final class MindSession {
    // Sincronização com o site (vazio/0 = nunca enviado)
    var syncID: String = ""
    var syncUpdated: Double = 0
    var syncSent: Double = 0
    var date: Date = Date.now
    var kindRaw: String = PracticeKind.breathing.rawValue
    var detail: String = ""
    var seconds: Double = 0

    init(kind: PracticeKind, detail: String = "", seconds: Double, date: Date = .now) {
        self.kindRaw = kind.rawValue; self.detail = detail; self.seconds = seconds; self.date = date
    }
    var kind: PracticeKind { PracticeKind(rawValue: kindRaw) ?? .breathing }
}

// MARK: - Gratidão

@Model
final class GratitudeEntry {
    // Sincronização com o site (vazio/0 = nunca enviado)
    var syncID: String = ""
    var syncUpdated: Double = 0
    var syncSent: Double = 0
    var date: Date = Date.now
    var text: String = ""          // itens separados por quebra de linha
    init(date: Date = .now, items: [String]) { self.date = date; self.items = items }
    var items: [String] {
        get { text.split(separator: "\n").map(String.init) }
        set { text = newValue.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }.joined(separator: "\n") }
    }
}

// MARK: - Hábitos

@Model
final class Habit {
    // Sincronização com o site (vazio/0 = nunca enviado)
    var syncID: String = ""
    var syncUpdated: Double = 0
    var syncSent: Double = 0
    var uid: String = UUID().uuidString
    var name: String = ""
    var icon: String = "checkmark.circle.fill"
    var colorIndex: Int = 0
    var order: Int = 0
    var createdAt: Date = Date.now
    var archived: Bool = false

    init(name: String, icon: String, colorIndex: Int, order: Int) {
        self.name = name; self.icon = icon; self.colorIndex = colorIndex; self.order = order
    }
    var color: Color { Palette.all[colorIndex % Palette.all.count].accent }
}

@Model
final class HabitLog {
    // Sincronização com o site (vazio/0 = nunca enviado)
    var syncID: String = ""
    var syncUpdated: Double = 0
    var syncSent: Double = 0
    var habitUID: String = ""
    var day: Date = Date.now
    init(habitUID: String, day: Date) { self.habitUID = habitUID; self.day = Calendar.current.startOfDay(for: day) }
}

enum HabitMath {
    /// Sequência atual (dias seguidos até hoje ou ontem) e recorde.
    static func streaks(_ days: Set<Date>) -> (current: Int, best: Int) {
        let cal = Calendar.current
        var d = cal.startOfDay(for: .now)
        if !days.contains(d) { d = cal.date(byAdding: .day, value: -1, to: d)! }
        var current = 0
        while days.contains(d) { current += 1; d = cal.date(byAdding: .day, value: -1, to: d)! }
        var best = 0, run = 0
        var prev: Date?
        for day in days.sorted() {
            if let p = prev, cal.dateComponents([.day], from: p, to: day).day == 1 { run += 1 } else { run = 1 }
            best = max(best, run); prev = day
        }
        return (current, best)
    }

    static let suggestions: [(String, String)] = [
        ("Meditar", "brain.head.profile"), ("Ler 10 páginas", "book.fill"), ("Sem celular na cama", "iphone.slash"),
        ("Tomar sol 15 min", "sun.max.fill"), ("Caminhar", "figure.walk"), ("Beber 2 L de água", "drop.fill"),
        ("Alongar", "figure.flexibility"), ("Dormir antes das 23h", "moon.zzz.fill"), ("Escrever no diário", "pencil.and.scribble"),
        ("Falar com alguém querido", "person.2.fill"), ("Sem álcool", "wineglass"), ("Arrumar a cama", "bed.double.fill"),
    ]
}

// MARK: - Questionários validados

enum AssessmentKind: String, CaseIterable, Identifiable, Codable {
    case phq9, gad7, who5
    var id: String { rawValue }

    var title: String {
        switch self {
        case .phq9: "PHQ-9 · Humor e depressão"
        case .gad7: "GAD-7 · Ansiedade"
        case .who5: "WHO-5 · Bem-estar"
        }
    }
    var short: String {
        switch self {
        case .phq9: "PHQ-9"
        case .gad7: "GAD-7"
        case .who5: "WHO-5"
        }
    }
    var icon: String {
        switch self {
        case .phq9: "cloud.drizzle.fill"
        case .gad7: "waveform.path.ecg"
        case .who5: "sun.max.fill"
        }
    }
    var intro: String {
        switch self {
        case .phq9: "Nas últimas 2 semanas, com que frequência você foi incomodado(a) por algum destes problemas?"
        case .gad7: "Nas últimas 2 semanas, com que frequência você foi incomodado(a) por estes problemas?"
        case .who5: "Para cada afirmação, indique o que mais se aproxima de como você se sentiu nas últimas 2 semanas."
        }
    }
    var about: String {
        switch self {
        case .phq9: "Questionário de 9 itens usado no mundo todo para rastrear sintomas depressivos (Kroenke, Spitzer & Williams, 2001). Validado no Brasil. É uma triagem, não um diagnóstico."
        case .gad7: "Questionário de 7 itens para rastrear sintomas de ansiedade generalizada (Spitzer et al., 2006). Validado no Brasil. É uma triagem, não um diagnóstico."
        case .who5: "Índice de Bem-Estar da OMS, 5 itens (OMS, 1998). Mede bem-estar positivo; valores baixos indicam que vale investigar melhor o humor."
        }
    }

    var questions: [String] {
        switch self {
        case .phq9: [
            "Pouco interesse ou pouco prazer em fazer as coisas",
            "Se sentir para baixo, deprimido(a) ou sem perspectiva",
            "Dificuldade para pegar no sono, permanecer dormindo ou dormir mais do que de costume",
            "Se sentir cansado(a) ou com pouca energia",
            "Falta de apetite ou comer demais",
            "Se sentir mal consigo mesmo(a), achar que é um fracasso ou que decepcionou a família ou a si mesmo(a)",
            "Dificuldade para se concentrar nas coisas (como ler ou ver TV)",
            "Lentidão para se movimentar ou falar, a ponto de outras pessoas perceberem — ou o oposto, estar muito agitado(a) ou inquieto(a)",
            "Pensar em se ferir de alguma maneira ou que seria melhor estar morto(a)",
        ]
        case .gad7: [
            "Se sentir nervoso(a), ansioso(a) ou muito tenso(a)",
            "Não ser capaz de impedir ou de controlar as preocupações",
            "Se preocupar muito com diversas coisas",
            "Dificuldade para relaxar",
            "Ficar tão agitado(a) que se torna difícil permanecer sentado(a)",
            "Ficar facilmente aborrecido(a) ou irritado(a)",
            "Sentir medo como se algo horrível fosse acontecer",
        ]
        case .who5: [
            "Me senti alegre e de bom humor",
            "Me senti calmo(a) e tranquilo(a)",
            "Me senti ativo(a) e com energia",
            "Acordei me sentindo descansado(a) e revigorado(a)",
            "Meu dia a dia foi preenchido com coisas que me interessam",
        ]
        }
    }

    var options: [String] {
        switch self {
        case .phq9, .gad7: ["Nenhuma vez", "Vários dias", "Mais da metade dos dias", "Quase todos os dias"]
        case .who5: ["Em nenhum momento", "Alguma vez", "Menos da metade do tempo", "Mais da metade do tempo",
                     "A maior parte do tempo", "O tempo todo"]
        }
    }

    var maxScore: Int { self == .who5 ? 100 : questions.count * 3 }

    /// WHO-5: soma 0–25 × 4 = 0–100%. Os outros: soma direta.
    func score(_ answers: [Int]) -> Int {
        let s = answers.reduce(0, +)
        return self == .who5 ? s * 4 : s
    }

    /// Classificação (texto, cor, orientação).
    func level(_ score: Int) -> (label: String, color: Color, advice: String) {
        switch self {
        case .phq9:
            switch score {
            case ..<5: return ("Mínimo", Theme.good, "Poucos sintomas. Continue cuidando do sono, movimento e conexões.")
            case ..<10: return ("Leve", Theme.info, "Sintomas leves. Observe por algumas semanas; atividade física, sono regular e contato social ajudam.")
            case ..<15: return ("Moderado", Theme.warm, "Vale conversar com um profissional de saúde (psicólogo, médico de família ou psiquiatra).")
            case ..<20: return ("Moderadamente grave", Theme.danger, "Recomendado procurar avaliação profissional em breve.")
            default: return ("Grave", Theme.danger, "Procure ajuda profissional o quanto antes. Você não precisa passar por isso sozinho(a).")
            }
        case .gad7:
            switch score {
            case ..<5: return ("Mínimo", Theme.good, "Poucos sinais de ansiedade.")
            case ..<10: return ("Leve", Theme.info, "Ansiedade leve. Técnicas de respiração, exercício e sono regular costumam ajudar bastante.")
            case ..<15: return ("Moderado", Theme.warm, "Considere conversar com um profissional; terapia (ex.: TCC) é muito eficaz para ansiedade.")
            default: return ("Grave", Theme.danger, "Procure avaliação profissional. Ansiedade intensa tem tratamento eficaz.")
            }
        case .who5:
            switch score {
            case ...28: return ("Bem-estar muito baixo", Theme.danger, "Valor associado a possível depressão. Recomendado procurar um profissional e fazer o PHQ-9.")
            case ...50: return ("Bem-estar baixo", Theme.warm, "Abaixo de 50% vale investigar o humor (faça o PHQ-9) e conversar com alguém de confiança.")
            case ..<70: return ("Bem-estar moderado", Theme.info, "Bom, com espaço para melhorar. Veja o que mais influencia seu humor nos insights.")
            default: return ("Bem-estar alto", Theme.good, "Ótimo nível de bem-estar!")
            }
        }
    }

    /// Para gráficos: true quando maior = melhor.
    var higherIsBetter: Bool { self == .who5 }
}

@Model
final class AssessmentResult {
    var date: Date = Date.now
    var kindRaw: String = AssessmentKind.phq9.rawValue
    var answersRaw: String = ""
    var score: Int = 0

    init(kind: AssessmentKind, answers: [Int]) {
        kindRaw = kind.rawValue
        answersRaw = answers.map(String.init).joined(separator: ",")
        score = kind.score(answers)
    }
    var kind: AssessmentKind { AssessmentKind(rawValue: kindRaw) ?? .phq9 }
    var answers: [Int] { answersRaw.split(separator: ",").compactMap { Int($0) } }
}

// MARK: - Preferências e lembretes da mente

@Observable
final class MindPrefs {
    static let shared = MindPrefs()
    private let d = UserDefaults.standard

    var checkInReminder: Bool { didSet { d.set(checkInReminder, forKey: "mindReminder"); schedule() } }
    var checkInTime: Date { didSet { d.set(checkInTime.timeIntervalSince1970, forKey: "mindReminderTime"); schedule() } }
    var sleepGoal: Double { didSet { d.set(sleepGoal, forKey: "sleepGoal") } }

    private init() {
        checkInReminder = d.bool(forKey: "mindReminder")
        let t = d.double(forKey: "mindReminderTime")
        checkInTime = t > 0 ? Date(timeIntervalSince1970: t) : Calendar.current.date(bySettingHour: 21, minute: 0, second: 0, of: .now)!
        sleepGoal = d.object(forKey: "sleepGoal") as? Double ?? 8
    }

    private func schedule() {
        let c = UNUserNotificationCenter.current()
        c.removePendingNotificationRequests(withIdentifiers: ["mood"])
        guard checkInReminder else { return }
        let time = checkInTime
        c.requestAuthorization(options: [.alert, .sound]) { ok, _ in
            guard ok else { return }
            let content = UNMutableNotificationContent()
            content.title = "Como foi seu dia? 🙂"
            content.body = "Leva 10 segundos registrar seu humor."
            content.sound = .default
            let comps = Calendar.current.dateComponents([.hour, .minute], from: time)
            c.add(UNNotificationRequest(identifier: "mood", content: content,
                                        trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)))
        }
    }
}
