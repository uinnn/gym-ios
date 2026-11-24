import Foundation
import SwiftData

enum Sex: String, CaseIterable, Identifiable {
    case male, female
    var id: String { rawValue }
    var label: String { self == .male ? "Masculino" : "Feminino" }
}

enum ActivityLevel: String, CaseIterable, Identifiable {
    case sedentary, light, moderate, active, veryActive
    var id: String { rawValue }

    var label: String {
        switch self {
        case .sedentary: "Sedentário"
        case .light: "Leve (1–3x/sem)"
        case .moderate: "Moderado (3–5x/sem)"
        case .active: "Ativo (6–7x/sem)"
        case .veryActive: "Muito ativo (2x/dia)"
        }
    }

    var factor: Double {
        switch self {
        case .sedentary: 1.2
        case .light: 1.375
        case .moderate: 1.55
        case .active: 1.725
        case .veryActive: 1.9
        }
    }
}

enum Goal: String, CaseIterable, Identifiable {
    case lose, maintain, gain
    var id: String { rawValue }
    var label: String {
        switch self {
        case .lose: "Perder peso"
        case .maintain: "Manter"
        case .gain: "Ganhar massa"
        }
    }
    /// Ajuste diário de calorias sobre o gasto total.
    var calorieDelta: Double {
        switch self {
        case .lose: -500
        case .maintain: 0
        case .gain: 300
        }
    }
}

@Model
final class UserProfile {
    // Sincronização com o site (vazio/0 = nunca enviado)
    var syncID: String = ""
    var syncUpdated: Double = 0
    var syncSent: Double = 0
    var name: String = ""
    var sexRaw: String = Sex.male.rawValue
    var birthDate: Date = Calendar.current.date(byAdding: .year, value: -25, to: .now)!
    var heightCm: Double = 170
    var goalWeightKg: Double = 70
    var activityRaw: String = ActivityLevel.moderate.rawValue
    var goalRaw: String = Goal.maintain.rawValue
    var waistCm: Double?
    var createdAt: Date = Date.now

    init() {}

    var sex: Sex {
        get { Sex(rawValue: sexRaw) ?? .male }
        set { sexRaw = newValue.rawValue }
    }
    var activity: ActivityLevel {
        get { ActivityLevel(rawValue: activityRaw) ?? .moderate }
        set { activityRaw = newValue.rawValue }
    }
    var goal: Goal {
        get { Goal(rawValue: goalRaw) ?? .maintain }
        set { goalRaw = newValue.rawValue }
    }
    var age: Int {
        Calendar.current.dateComponents([.year], from: birthDate, to: .now).year ?? 25
    }
}

enum WeighTag: String, CaseIterable, Identifiable {
    case fasting, afterWorkout, afterMeal, morning, night, sick, travel
    var id: String { rawValue }
    var label: String {
        switch self {
        case .fasting: "Em jejum"
        case .afterWorkout: "Pós-treino"
        case .afterMeal: "Após refeição"
        case .morning: "Ao acordar"
        case .night: "À noite"
        case .sick: "Doente"
        case .travel: "Viagem"
        }
    }
    var icon: String {
        switch self {
        case .fasting: "moon.zzz.fill"
        case .afterWorkout: "figure.run"
        case .afterMeal: "fork.knife"
        case .morning: "sunrise.fill"
        case .night: "moon.fill"
        case .sick: "cross.case.fill"
        case .travel: "airplane"
        }
    }
}

@Model
final class WeightEntry {
    // Sincronização com o site (vazio/0 = nunca enviado)
    var syncID: String = ""
    var syncUpdated: Double = 0
    var syncSent: Double = 0
    var date: Date = Date.now
    var kg: Double = 0
    var source: String = "scale"   // "scale" ou "manual"
    var note: String = ""
    var tagsRaw: String = ""        // tags separadas por vírgula

    init(date: Date = .now, kg: Double, source: String = "scale") {
        self.date = date
        self.kg = kg
        self.source = source
    }

    var tags: Set<WeighTag> {
        get { Set(tagsRaw.split(separator: ",").compactMap { WeighTag(rawValue: String($0)) }) }
        set { tagsRaw = newValue.map(\.rawValue).sorted().joined(separator: ",") }
    }
}

/// Partes do corpo que podem ser medidas (cm).
enum BodyPart: String, CaseIterable, Identifiable {
    case neck, shoulders, chest, armL, armR, forearmL, forearmR, wrist,
         waist, abdomen, hip, thighL, thighR, calfL, calfR
    var id: String { rawValue }

    var label: String {
        switch self {
        case .neck: "Pescoço"
        case .shoulders: "Ombros"
        case .chest: "Peitoral"
        case .armL: "Braço esquerdo"
        case .armR: "Braço direito"
        case .forearmL: "Antebraço esquerdo"
        case .forearmR: "Antebraço direito"
        case .wrist: "Punho"
        case .waist: "Cintura"
        case .abdomen: "Abdômen"
        case .hip: "Quadril"
        case .thighL: "Coxa esquerda"
        case .thighR: "Coxa direita"
        case .calfL: "Panturrilha esquerda"
        case .calfR: "Panturrilha direita"
        }
    }

    var howTo: String {
        switch self {
        case .neck: "Logo abaixo do pomo de Adão, fita levemente inclinada para baixo na frente."
        case .shoulders: "Circunferência na parte mais larga dos ombros, braços relaxados."
        case .chest: "Na linha dos mamilos, após expirar normalmente."
        case .armL, .armR: "No ponto mais largo do bíceps, braço relaxado (ou contraído — sempre igual)."
        case .forearmL, .forearmR: "No ponto mais largo, logo abaixo do cotovelo."
        case .wrist: "Logo acima do osso do punho."
        case .waist: "Na menor circunferência entre as costelas e o umbigo, após expirar."
        case .abdomen: "Na altura do umbigo, relaxado."
        case .hip: "No ponto mais largo dos glúteos, pés juntos."
        case .thighL, .thighR: "Logo abaixo do glúteo, no ponto mais largo da coxa."
        case .calfL, .calfR: "No ponto mais largo da panturrilha, em pé."
        }
    }

    /// Se diminuir costuma ser o objetivo (true), aumentar (false) ou neutro (nil).
    var smallerIsBetter: Bool? {
        switch self {
        case .waist, .abdomen: true
        case .neck, .hip, .wrist: nil
        default: false
        }
    }

    var keyPath: ReferenceWritableKeyPath<MeasurementEntry, Double?> {
        switch self {
        case .neck: \.neck
        case .shoulders: \.shoulders
        case .chest: \.chest
        case .armL: \.armL
        case .armR: \.armR
        case .forearmL: \.forearmL
        case .forearmR: \.forearmR
        case .wrist: \.wrist
        case .waist: \.waist
        case .abdomen: \.abdomen
        case .hip: \.hip
        case .thighL: \.thighL
        case .thighR: \.thighR
        case .calfL: \.calfL
        case .calfR: \.calfR
        }
    }

    /// Pares esquerdo/direito para simetria.
    static let pairs: [(String, BodyPart, BodyPart)] = [
        ("Braços", .armL, .armR), ("Antebraços", .forearmL, .forearmR),
        ("Coxas", .thighL, .thighR), ("Panturrilhas", .calfL, .calfR),
    ]
}

@Model
final class MeasurementEntry {
    // Sincronização com o site (vazio/0 = nunca enviado)
    var syncID: String = ""
    var syncUpdated: Double = 0
    var syncSent: Double = 0
    var date: Date = Date.now
    var neck: Double?
    var shoulders: Double?
    var chest: Double?
    var armL: Double?
    var armR: Double?
    var forearmL: Double?
    var forearmR: Double?
    var wrist: Double?
    var waist: Double?
    var abdomen: Double?
    var hip: Double?
    var thighL: Double?
    var thighR: Double?
    var calfL: Double?
    var calfR: Double?
    var note: String = ""

    init(date: Date = .now) { self.date = date }

    subscript(_ part: BodyPart) -> Double? {
        get { self[keyPath: part.keyPath] }
        set { self[keyPath: part.keyPath] = newValue }
    }

    var filledCount: Int { BodyPart.allCases.filter { self[$0] != nil }.count }
}

extension Array where Element == MeasurementEntry {
    /// Medida mais recente até a data (a lista pode estar em qualquer ordem).
    func latest(before date: Date = .distantFuture) -> MeasurementEntry? {
        filter { $0.date <= date }.max { $0.date < $1.date }
    }

    /// Valor mais recente de uma parte, olhando todas as medições.
    func latestValue(_ part: BodyPart, before date: Date = .distantFuture) -> Double? {
        filter { $0.date <= date && $0[part] != nil }.max { $0.date < $1.date }?[part]
    }

    /// Junta as últimas medidas de cada parte numa entrada virtual (para os cálculos).
    func merged(before date: Date = .distantFuture) -> MeasurementEntry? {
        let parts = mergedParts(before: date)
        guard !parts.isEmpty else { return nil }
        let m = MeasurementEntry(date: date)
        for (p, v) in parts { m[p] = v }
        return m
    }

    /// Valor mais recente de cada parte até a data, numa única passada (sem criar objetos).
    func mergedParts(before date: Date = .distantFuture) -> [BodyPart: Double] {
        var out: [BodyPart: Double] = [:]
        var when: [BodyPart: Date] = [:]
        for e in self where e.date <= date {
            for p in BodyPart.allCases {
                if let v = e[p], e.date >= (when[p] ?? .distantPast) { out[p] = v; when[p] = e.date }
            }
        }
        return out
    }
}
