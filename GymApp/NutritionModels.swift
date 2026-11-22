import Foundation
import SwiftData

// MARK: - Nutrientes

/// Valores nutricionais (por 100 g num alimento, ou já escalados num registro).
struct Nutrients: Codable, Hashable {
    var kcal = 0.0, protein = 0.0, carbs = 0.0, fat = 0.0, fiber = 0.0
    var sugar = 0.0, saturated = 0.0
    var sodium = 0.0, calcium = 0.0, iron = 0.0, potassium = 0.0, magnesium = 0.0
    var vitaminC = 0.0, cholesterol = 0.0, zinc = 0.0

    func scaled(_ factor: Double) -> Nutrients {
        Nutrients(kcal: kcal * factor, protein: protein * factor, carbs: carbs * factor, fat: fat * factor,
                  fiber: fiber * factor, sugar: sugar * factor, saturated: saturated * factor,
                  sodium: sodium * factor, calcium: calcium * factor, iron: iron * factor,
                  potassium: potassium * factor, magnesium: magnesium * factor, vitaminC: vitaminC * factor,
                  cholesterol: cholesterol * factor, zinc: zinc * factor)
    }

    static func + (a: Nutrients, b: Nutrients) -> Nutrients {
        Nutrients(kcal: a.kcal + b.kcal, protein: a.protein + b.protein, carbs: a.carbs + b.carbs, fat: a.fat + b.fat,
                  fiber: a.fiber + b.fiber, sugar: a.sugar + b.sugar, saturated: a.saturated + b.saturated,
                  sodium: a.sodium + b.sodium, calcium: a.calcium + b.calcium, iron: a.iron + b.iron,
                  potassium: a.potassium + b.potassium, magnesium: a.magnesium + b.magnesium,
                  vitaminC: a.vitaminC + b.vitaminC, cholesterol: a.cholesterol + b.cholesterol, zinc: a.zinc + b.zinc)
    }

    static let zero = Nutrients()
}

extension Sequence where Element == Nutrients {
    var total: Nutrients { reduce(.zero, +) }
}

/// Um alimento do banco de dados (TACO, Open Food Facts ou criado pelo usuário).
struct FoodItem: Codable, Hashable, Identifiable {
    var id: String                 // "taco-1", "off-7891000…", "custom-UUID"
    var name: String
    var category: String
    var brand: String? = nil
    var per100: Nutrients
    var servingGrams: Double? = nil
    var servingName: String? = nil

    var sourceLabel: String {
        if id.hasPrefix("taco") { return "TACO" }
        if id.hasPrefix("off") { return "Open Food Facts" }
        return "Meu alimento"
    }
}

enum Meal: String, CaseIterable, Identifiable, Codable {
    case breakfast, morningSnack, lunch, afternoonSnack, dinner, supper
    var id: String { rawValue }

    var label: String {
        switch self {
        case .breakfast: "Café da manhã"
        case .morningSnack: "Lanche da manhã"
        case .lunch: "Almoço"
        case .afternoonSnack: "Lanche da tarde"
        case .dinner: "Jantar"
        case .supper: "Ceia"
        }
    }

    var icon: String {
        switch self {
        case .breakfast: "sunrise.fill"
        case .morningSnack: "cup.and.saucer.fill"
        case .lunch: "sun.max.fill"
        case .afternoonSnack: "carrot.fill"
        case .dinner: "moon.fill"
        case .supper: "moon.zzz.fill"
        }
    }

    /// Fatia das calorias diárias sugerida para a refeição.
    var share: Double {
        switch self {
        case .breakfast: 0.25
        case .morningSnack: 0.08
        case .lunch: 0.30
        case .afternoonSnack: 0.10
        case .dinner: 0.22
        case .supper: 0.05
        }
    }

    /// Refeição provável pelo horário.
    static func forNow(_ date: Date = .now) -> Meal {
        switch Calendar.current.component(.hour, from: date) {
        case 4..<10: .breakfast
        case 10..<12: .morningSnack
        case 12..<15: .lunch
        case 15..<18: .afternoonSnack
        case 18..<22: .dinner
        default: .supper
        }
    }
}

// MARK: - Persistência

@Model
final class FoodLog {
    var date: Date = Date.now
    var mealRaw: String = Meal.lunch.rawValue
    var foodID: String = ""
    var name: String = ""
    var grams: Double = 100
    var nutrients: Nutrients = Nutrients()

    init(date: Date, meal: Meal, food: FoodItem, grams: Double) {
        self.date = date
        self.mealRaw = meal.rawValue
        self.foodID = food.id
        self.name = food.name
        self.grams = grams
        self.nutrients = food.per100.scaled(grams / 100)
    }

    var meal: Meal { Meal(rawValue: mealRaw) ?? .lunch }
}

/// Alimentos usados, favoritos, vindos da internet ou criados pelo usuário.
@Model
final class SavedFood {
    var foodID: String = ""
    var data: Data = Data()
    var favorite: Bool = false
    var useCount: Int = 0
    var lastUsed: Date = Date.now
    var lastGrams: Double = 100
    var isCustom: Bool = false

    init(_ food: FoodItem, custom: Bool = false) {
        foodID = food.id
        data = (try? JSONEncoder().encode(food)) ?? Data()
        isCustom = custom
    }

    var food: FoodItem? { try? JSONDecoder().decode(FoodItem.self, from: data) }
}

@Model
final class WaterLog {
    var date: Date = Date.now
    var ml: Double = 250
    init(date: Date = .now, ml: Double) { self.date = date; self.ml = ml }
}

@Model
final class FastingSession {
    var start: Date = Date.now
    var end: Date?
    var goalHours: Double = 16
    init(start: Date = .now, goalHours: Double) { self.start = start; self.goalHours = goalHours }

    var duration: TimeInterval { (end ?? .now).timeIntervalSince(start) }
    var completed: Bool { duration >= goalHours * 3600 }
}

// MARK: - Metas diárias

struct NutritionTargets {
    let kcal, protein, carbs, fat, fiber, water: Double     // água em ml
    let sodiumMax, sugarMax, saturatedMax, cholesterolMax: Double
    let calcium, iron, potassium, magnesium, vitaminC, zinc: Double

    init(analysis a: BodyAnalysis) {
        let male = a.input.isMale
        kcal = a[.targetCalories]?.value ?? 2000
        protein = a[.proteinNeed]?.value ?? 100
        fat = a[.fatNeed]?.value ?? 60
        carbs = a[.carbNeed]?.value ?? 250
        fiber = a[.fiberNeed]?.value ?? 28
        water = a.input.kg * 35
        sodiumMax = 2300
        sugarMax = kcal * 0.10 / 4
        saturatedMax = kcal * 0.10 / 9
        cholesterolMax = 300
        calcium = a.input.age > 50 && !male ? 1200 : 1000
        iron = male || a.input.age > 50 ? 8 : 18
        potassium = male ? 3400 : 2600
        magnesium = male ? 400 : 310
        vitaminC = male ? 90 : 75
        zinc = male ? 11 : 8
    }

    static let fallback = NutritionTargets(kcal: 2000, protein: 100, carbs: 250, fat: 65, fiber: 28, water: 2500)

    private init(kcal: Double, protein: Double, carbs: Double, fat: Double, fiber: Double, water: Double) {
        self.kcal = kcal; self.protein = protein; self.carbs = carbs; self.fat = fat
        self.fiber = fiber; self.water = water
        sodiumMax = 2300; sugarMax = 50; saturatedMax = 22; cholesterolMax = 300
        calcium = 1000; iron = 8; potassium = 3400; magnesium = 400; vitaminC = 90; zinc = 11
    }
}

extension Calendar {
    func isSameDay(_ a: Date, _ b: Date) -> Bool { isDate(a, inSameDayAs: b) }
}
