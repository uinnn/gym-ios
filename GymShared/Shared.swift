import Foundation
#if canImport(ActivityKit)
import ActivityKit
#endif

/// Dados compartilhados entre o app e os widgets (via App Group).
enum SharedStore {
    static let group = "group.com.gym.app"
    static var defaults: UserDefaults { UserDefaults(suiteName: group) ?? .standard }
}

/// Resumo que o app grava para os widgets lerem.
struct WidgetSnapshot: Codable {
    var name = ""
    var kg: Double?
    var kgDelta7: Double?
    var goalKg: Double?
    var waterMl = 0.0
    var waterGoalMl = 2000.0
    var kcal = 0.0
    var kcalGoal = 2000.0
    var streak = 0
    var nextWorkout: String?
    var updated = Date.now

    static let key = "widgetSnapshot"
    static func load() -> WidgetSnapshot? {
        SharedStore.defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(WidgetSnapshot.self, from: $0) }
    }
    func save() { SharedStore.defaults.set(try? JSONEncoder().encode(self), forKey: Self.key) }
}

#if canImport(ActivityKit)
/// Live Activity genérica: treino (com descanso) e jejum.
struct TimerActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var subtitle: String
        var restEnd: Date?
        var goalEnd: Date?
    }
    var kind: String          // "workout" | "fasting"
    var title: String
    var start: Date
}
#endif
