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

@Model
final class WeightEntry {
    var date: Date = Date.now
    var kg: Double = 0
    var source: String = "scale"   // "scale" ou "manual"

    init(date: Date = .now, kg: Double, source: String = "scale") {
        self.date = date
        self.kg = kg
        self.source = source
    }
}

/// Métricas calculadas a partir de peso + perfil.
///
/// A balança envia só o peso (a impedância não chega pelo Bluetooth), então a composição
/// corporal é **estimada** por fórmulas validadas em população, não medida.
struct BodyMetrics {
    let kg: Double
    let profile: UserProfile

    private var h: Double { profile.heightCm / 100 }
    private var isMale: Bool { profile.sex == .male }

    /// Índice de massa corporal.
    var bmi: Double { kg / (h * h) }

    var bmiCategory: (label: String, level: Int) {
        switch bmi {
        case ..<18.5: ("Abaixo do peso", 0)
        case ..<25: ("Saudável", 1)
        case ..<30: ("Sobrepeso", 2)
        default: ("Obesidade", 3)
        }
    }

    /// Gordura corporal estimada (Deurenberg, 1991).
    var bodyFatPercent: Double {
        let v = 1.2 * bmi + 0.23 * Double(profile.age) - 10.8 * (isMale ? 1 : 0) - 5.4
        return min(max(v, 3), 60)
    }
    var fatMassKg: Double { kg * bodyFatPercent / 100 }
    var leanMassKg: Double { kg - fatMassKg }
    /// Água corporal ≈ 73% da massa magra.
    var waterPercent: Double { leanMassKg * 0.73 / kg * 100 }
    /// Massa muscular esquelética ≈ 52% (H) / 46% (M) da massa magra.
    var muscleMassKg: Double { leanMassKg * (isMale ? 0.52 : 0.46) }

    /// Metabolismo basal (Mifflin-St Jeor).
    var bmr: Double {
        10 * kg + 6.25 * profile.heightCm - 5 * Double(profile.age) + (isMale ? 5 : -161)
    }
    /// Gasto energético total diário.
    var tdee: Double { bmr * profile.activity.factor }
    var targetCalories: Double { max(1200, tdee + profile.goal.calorieDelta) }

    /// Proteína: 1,6 g/kg (faixa recomendada para quem treina).
    var proteinGrams: Double { kg * 1.6 }
    /// Água para beber: 35 ml/kg.
    var waterLiters: Double { kg * 0.035 }

    /// Faixa de peso saudável para a altura (IMC 18,5–24,9).
    var healthyRange: ClosedRange<Double> { (18.5 * h * h)...(24.9 * h * h) }

    /// Relação cintura/altura (se a cintura foi informada). < 0,5 = baixo risco.
    var waistToHeight: Double? { profile.waistCm.map { $0 / profile.heightCm } }
}
