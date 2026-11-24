import Foundation
import SwiftData

/// Cópia completa dos dados do app em JSON (versão 1).
struct Backup: Codable {
    var version = 1
    var exportedAt = Date.now
    var profile: ProfileDTO?
    var weights: [WeightDTO] = []
    var measurements: [MeasurementDTO] = []
    var foodLogs: [FoodLogDTO] = []
    var savedFoods: [SavedFoodDTO] = []
    var water: [WaterDTO] = []
    var fasting: [FastingDTO] = []
    var sessions: [SessionDTO] = []
    var routines: [RoutineDTO] = []
    var settings: [String: String] = [:]
    // saúde mental (opcionais: backups antigos não têm)
    var moods: [MoodDTO]?
    var sleeps: [SleepDTO]?
    var practices: [PracticeDTO]?
    var gratitude: [GratitudeDTO]?
    var habits: [HabitDTO]?
    var habitLogs: [HabitLogDTO]?
    var assessments: [AssessmentDTO]?

    struct MoodDTO: Codable { var date: Date, mood: Int, energy: Int, stress: Int, anxiety: Int, tagsRaw: String, note: String }
    struct SleepDTO: Codable { var bedtime: Date, wake: Date, quality: Int, awakenings: Int, note: String }
    struct PracticeDTO: Codable { var date: Date, kindRaw: String, detail: String, seconds: Double }
    struct GratitudeDTO: Codable { var date: Date, text: String }
    struct HabitDTO: Codable { var uid: String, name: String, icon: String, colorIndex: Int, order: Int, archived: Bool }
    struct HabitLogDTO: Codable { var habitUID: String, day: Date }
    struct AssessmentDTO: Codable { var date: Date, kindRaw: String, answersRaw: String, score: Int }

    struct ProfileDTO: Codable {
        var name: String, sexRaw: String, birthDate: Date, heightCm: Double, goalWeightKg: Double
        var activityRaw: String, goalRaw: String, waistCm: Double?
    }
    struct WeightDTO: Codable { var date: Date, kg: Double, source: String, note: String, tagsRaw: String }
    struct MeasurementDTO: Codable { var date: Date, values: [String: Double], note: String }
    struct FoodLogDTO: Codable {
        var date: Date, mealRaw: String, foodID: String, name: String, grams: Double
        var nutrients: Nutrients, micros: Micros?
        var extras: [String: Double]? = nil
    }
    struct SavedFoodDTO: Codable {
        var foodID: String, food: FoodItem?, favorite: Bool, useCount: Int, lastUsed: Date, lastGrams: Double, isCustom: Bool
    }
    struct WaterDTO: Codable { var date: Date, ml: Double }
    struct FastingDTO: Codable { var start: Date, end: Date?, goalHours: Double }
    struct SessionDTO: Codable {
        var start: Date, end: Date?, name: String, note: String, exercises: [SessionExercise], bodyKg: Double, rating: Int
    }
    struct RoutineDTO: Codable { var name: String, icon: String, order: Int, weekday: Int, items: [RoutineItem] }

    /// Preferências salvas no aparelho que entram no backup.
    static let settingKeys = ["paletteID", "appearance", "background", "card", "genGoal", "genLevel", "genPlace",
                              "genStyle", "genEquip"]
}

enum BackupManager {
    struct Counts {
        var weights = 0, measurements = 0, foodLogs = 0, water = 0, fasting = 0, sessions = 0, routines = 0, savedFoods = 0
        var total: Int { weights + measurements + foodLogs + water + fasting + sessions + routines + savedFoods }
        var summary: String {
            "\(weights) pesagens, \(measurements) medições, \(foodLogs) alimentos registrados, \(sessions) treinos, \(routines) rotinas, \(water) registros de água, \(fasting) jejuns"
        }
    }

    // MARK: Exportar

    static func makeBackup(_ ctx: ModelContext) -> Backup {
        var b = Backup()
        if let p = (try? ctx.fetch(FetchDescriptor<UserProfile>()))?.first {
            b.profile = .init(name: p.name, sexRaw: p.sexRaw, birthDate: p.birthDate, heightCm: p.heightCm,
                              goalWeightKg: p.goalWeightKg, activityRaw: p.activityRaw, goalRaw: p.goalRaw, waistCm: p.waistCm)
        }
        b.weights = fetch(ctx, WeightEntry.self).map { .init(date: $0.date, kg: $0.kg, source: $0.source, note: $0.note, tagsRaw: $0.tagsRaw) }
        b.measurements = fetch(ctx, MeasurementEntry.self).map { m in
            var v: [String: Double] = [:]
            for p in BodyPart.allCases { if let x = m[p] { v[p.rawValue] = x } }
            return .init(date: m.date, values: v, note: m.note)
        }
        b.foodLogs = fetch(ctx, FoodLog.self).map {
            .init(date: $0.date, mealRaw: $0.mealRaw, foodID: $0.foodID, name: $0.name, grams: $0.grams,
                  nutrients: $0.nutrients, micros: $0.micros, extras: $0.extrasData == nil ? nil : $0.extras)
        }
        b.savedFoods = fetch(ctx, SavedFood.self).map {
            .init(foodID: $0.foodID, food: $0.food, favorite: $0.favorite, useCount: $0.useCount, lastUsed: $0.lastUsed,
                  lastGrams: $0.lastGrams, isCustom: $0.isCustom)
        }
        b.water = fetch(ctx, WaterLog.self).map { .init(date: $0.date, ml: $0.ml) }
        b.fasting = fetch(ctx, FastingSession.self).map { .init(start: $0.start, end: $0.end, goalHours: $0.goalHours) }
        b.sessions = fetch(ctx, WorkoutSession.self).filter { !$0.isActive }.map {
            .init(start: $0.start, end: $0.end, name: $0.name, note: $0.note, exercises: $0.exercises, bodyKg: $0.bodyKg, rating: $0.rating)
        }
        b.routines = fetch(ctx, WorkoutRoutine.self).map {
            .init(name: $0.name, icon: $0.icon, order: $0.order, weekday: $0.weekday, items: $0.items)
        }
        b.moods = fetch(ctx, MoodEntry.self).map { .init(date: $0.date, mood: $0.mood, energy: $0.energy, stress: $0.stress, anxiety: $0.anxiety, tagsRaw: $0.tagsRaw, note: $0.note) }
        b.sleeps = fetch(ctx, SleepEntry.self).map { .init(bedtime: $0.bedtime, wake: $0.wake, quality: $0.quality, awakenings: $0.awakenings, note: $0.note) }
        b.practices = fetch(ctx, MindSession.self).map { .init(date: $0.date, kindRaw: $0.kindRaw, detail: $0.detail, seconds: $0.seconds) }
        b.gratitude = fetch(ctx, GratitudeEntry.self).map { .init(date: $0.date, text: $0.text) }
        b.habits = fetch(ctx, Habit.self).map { .init(uid: $0.uid, name: $0.name, icon: $0.icon, colorIndex: $0.colorIndex, order: $0.order, archived: $0.archived) }
        b.habitLogs = fetch(ctx, HabitLog.self).map { .init(habitUID: $0.habitUID, day: $0.day) }
        b.assessments = fetch(ctx, AssessmentResult.self).map { .init(date: $0.date, kindRaw: $0.kindRaw, answersRaw: $0.answersRaw, score: $0.score) }
        let d = UserDefaults.standard
        for k in Backup.settingKeys { if let v = d.string(forKey: k) { b.settings[k] = v } }
        b.settings["favExercises"] = (d.stringArray(forKey: "favExercises") ?? []).joined(separator: ",")
        return b
    }

    static func exportJSON(_ ctx: ModelContext) throws -> URL {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        let data = try enc.encode(makeBackup(ctx))
        let name = "gym-backup-\(Date.now.formatted(.iso8601.year().month().day())).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try data.write(to: url, options: .atomic)
        return url
    }

    private static func fetch<T: PersistentModel>(_ ctx: ModelContext, _ t: T.Type) -> [T] {
        (try? ctx.fetch(FetchDescriptor<T>())) ?? []
    }

    // MARK: Importar

    static func decode(_ url: URL) throws -> Backup {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: url)
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return try dec.decode(Backup.self, from: data)
    }

    static func counts(_ b: Backup) -> Counts {
        Counts(weights: b.weights.count, measurements: b.measurements.count, foodLogs: b.foodLogs.count,
               water: b.water.count, fasting: b.fasting.count, sessions: b.sessions.count, routines: b.routines.count,
               savedFoods: b.savedFoods.count)
    }

    /// Importa. `replace` apaga tudo antes; senão junta, ignorando itens repetidos.
    @discardableResult
    static func restore(_ b: Backup, into ctx: ModelContext, replace: Bool) -> Counts {
        if replace { deleteAll(ctx, keepProfile: false) }
        var c = Counts()
        func key(_ d: Date) -> Int { Int(d.timeIntervalSince1970) }

        if let p = b.profile {
            let existing = (try? ctx.fetch(FetchDescriptor<UserProfile>()))?.first
            if existing == nil || replace {
                let u = existing ?? UserProfile()
                u.name = p.name; u.sexRaw = p.sexRaw; u.birthDate = p.birthDate; u.heightCm = p.heightCm
                u.goalWeightKg = p.goalWeightKg; u.activityRaw = p.activityRaw; u.goalRaw = p.goalRaw; u.waistCm = p.waistCm
                if existing == nil { ctx.insert(u) }
            }
        }
        let w0 = Set(fetch(ctx, WeightEntry.self).map { "\(key($0.date))-\($0.kg)" })
        for w in b.weights where !w0.contains("\(key(w.date))-\(w.kg)") {
            let e = WeightEntry(date: w.date, kg: w.kg, source: w.source)
            e.note = w.note; e.tagsRaw = w.tagsRaw
            ctx.insert(e); c.weights += 1
        }
        let m0 = Set(fetch(ctx, MeasurementEntry.self).map { key($0.date) })
        for m in b.measurements where !m0.contains(key(m.date)) {
            let e = MeasurementEntry(date: m.date)
            for (k, v) in m.values { if let p = BodyPart(rawValue: k) { e[p] = v } }
            e.note = m.note
            ctx.insert(e); c.measurements += 1
        }
        let f0 = Set(fetch(ctx, FoodLog.self).map { "\(key($0.date))-\($0.name)-\($0.grams)" })
        for f in b.foodLogs where !f0.contains("\(key(f.date))-\(f.name)-\(f.grams)") {
            let food = FoodItem(id: f.foodID, name: f.name, category: "", per100: f.nutrients.scaled(100 / max(f.grams, 0.1)),
                                micros: f.micros?.scaled(100 / max(f.grams, 0.1)))
            let e = FoodLog(date: f.date, meal: Meal(rawValue: f.mealRaw) ?? .lunch, food: food, grams: f.grams)
            e.nutrients = f.nutrients; e.micros = f.micros; e.extras = f.extras ?? [:]
            ctx.insert(e); c.foodLogs += 1
        }
        let s0 = Set(fetch(ctx, SavedFood.self).map(\.foodID))
        for s in b.savedFoods where !s0.contains(s.foodID) {
            guard let food = s.food else { continue }
            let e = SavedFood(food, custom: s.isCustom)
            e.favorite = s.favorite; e.useCount = s.useCount; e.lastUsed = s.lastUsed; e.lastGrams = s.lastGrams
            ctx.insert(e); c.savedFoods += 1
        }
        let wa0 = Set(fetch(ctx, WaterLog.self).map { "\(key($0.date))-\($0.ml)" })
        for w in b.water where !wa0.contains("\(key(w.date))-\(w.ml)") {
            ctx.insert(WaterLog(date: w.date, ml: w.ml)); c.water += 1
        }
        let fa0 = Set(fetch(ctx, FastingSession.self).map { key($0.start) })
        for f in b.fasting where !fa0.contains(key(f.start)) {
            let e = FastingSession(start: f.start, goalHours: f.goalHours)
            e.end = f.end
            ctx.insert(e); c.fasting += 1
        }
        let se0 = Set(fetch(ctx, WorkoutSession.self).map { key($0.start) })
        for s in b.sessions where !se0.contains(key(s.start)) {
            let e = WorkoutSession(name: s.name, exercises: s.exercises, bodyKg: s.bodyKg)
            e.start = s.start; e.end = s.end ?? s.start; e.note = s.note; e.rating = s.rating
            ctx.insert(e); c.sessions += 1
        }
        let r0 = Set(fetch(ctx, WorkoutRoutine.self).map(\.name))
        for r in b.routines where !r0.contains(r.name) {
            let e = WorkoutRoutine(name: r.name, icon: r.icon, order: r.order, items: r.items)
            e.weekday = r.weekday
            ctx.insert(e); c.routines += 1
        }
        restoreMind(b, ctx, key)
        let d = UserDefaults.standard
        for (k, v) in b.settings {
            if k == "favExercises" {
                let merged = Set(v.split(separator: ",").map(String.init)).union(WorkoutPrefs.shared.favorites)
                WorkoutPrefs.shared.favorites = merged
            } else if Backup.settingKeys.contains(k) {
                d.set(v, forKey: k)
            }
        }
        try? ctx.save()
        return c
    }

    private static func restoreMind(_ b: Backup, _ ctx: ModelContext, _ key: (Date) -> Int) {
        let mo0 = Set(fetch(ctx, MoodEntry.self).map { key($0.date) })
        for m in b.moods ?? [] where !mo0.contains(key(m.date)) {
            let e = MoodEntry(date: m.date, mood: m.mood)
            e.energy = m.energy; e.stress = m.stress; e.anxiety = m.anxiety; e.tagsRaw = m.tagsRaw; e.note = m.note
            ctx.insert(e)
        }
        let sl0 = Set(fetch(ctx, SleepEntry.self).map { key($0.wake) })
        for s in b.sleeps ?? [] where !sl0.contains(key(s.wake)) {
            let e = SleepEntry(bedtime: s.bedtime, wake: s.wake, quality: s.quality)
            e.awakenings = s.awakenings; e.note = s.note
            ctx.insert(e)
        }
        let pr0 = Set(fetch(ctx, MindSession.self).map { key($0.date) })
        for p in b.practices ?? [] where !pr0.contains(key(p.date)) {
            ctx.insert(MindSession(kind: PracticeKind(rawValue: p.kindRaw) ?? .breathing, detail: p.detail, seconds: p.seconds, date: p.date))
        }
        let gr0 = Set(fetch(ctx, GratitudeEntry.self).map { key($0.date) })
        for g in b.gratitude ?? [] where !gr0.contains(key(g.date)) {
            let e = GratitudeEntry(date: g.date, items: [])
            e.text = g.text
            ctx.insert(e)
        }
        let h0 = Set(fetch(ctx, Habit.self).map(\.uid))
        for h in b.habits ?? [] where !h0.contains(h.uid) {
            let e = Habit(name: h.name, icon: h.icon, colorIndex: h.colorIndex, order: h.order)
            e.uid = h.uid; e.archived = h.archived
            ctx.insert(e)
        }
        let hl0 = Set(fetch(ctx, HabitLog.self).map { "\($0.habitUID)-\(key($0.day))" })
        for l in b.habitLogs ?? [] where !hl0.contains("\(l.habitUID)-\(key(l.day))") {
            ctx.insert(HabitLog(habitUID: l.habitUID, day: l.day))
        }
        let as0 = Set(fetch(ctx, AssessmentResult.self).map { key($0.date) })
        for a in b.assessments ?? [] where !as0.contains(key(a.date)) {
            let e = AssessmentResult(kind: AssessmentKind(rawValue: a.kindRaw) ?? .phq9, answers: [])
            e.date = a.date; e.answersRaw = a.answersRaw; e.score = a.score
            ctx.insert(e)
        }
    }

    static func deleteAll(_ ctx: ModelContext, keepProfile: Bool) {
        fetch(ctx, MoodEntry.self).forEach { ctx.delete($0) }
        fetch(ctx, SleepEntry.self).forEach { ctx.delete($0) }
        fetch(ctx, MindSession.self).forEach { ctx.delete($0) }
        fetch(ctx, GratitudeEntry.self).forEach { ctx.delete($0) }
        fetch(ctx, Habit.self).forEach { ctx.delete($0) }
        fetch(ctx, HabitLog.self).forEach { ctx.delete($0) }
        fetch(ctx, AssessmentResult.self).forEach { ctx.delete($0) }
        fetch(ctx, WeightEntry.self).forEach { ctx.delete($0) }
        fetch(ctx, MeasurementEntry.self).forEach { ctx.delete($0) }
        fetch(ctx, FoodLog.self).forEach { ctx.delete($0) }
        fetch(ctx, SavedFood.self).forEach { ctx.delete($0) }
        fetch(ctx, WaterLog.self).forEach { ctx.delete($0) }
        fetch(ctx, FastingSession.self).forEach { ctx.delete($0) }
        fetch(ctx, WorkoutSession.self).forEach { ctx.delete($0) }
        fetch(ctx, WorkoutRoutine.self).forEach { ctx.delete($0) }
        if !keepProfile { fetch(ctx, UserProfile.self).forEach { ctx.delete($0) } }
        try? ctx.save()
    }

    // MARK: CSV

    enum CSVKind: String, CaseIterable, Identifiable {
        case weights = "Pesagens", measurements = "Medidas", food = "Alimentação", workouts = "Treinos (séries)"
        var id: String { rawValue }
        var file: String {
            switch self {
            case .weights: "pesagens"
            case .measurements: "medidas"
            case .food: "alimentacao"
            case .workouts: "treinos"
            }
        }
    }

    private static func esc(_ s: String) -> String { "\"\(s.replacingOccurrences(of: "\"", with: "'"))\"" }
    private static func n(_ v: Double?) -> String { v.map { String(format: "%.2f", $0) } ?? "" }

    static func exportCSV(_ kind: CSVKind, _ ctx: ModelContext) throws -> URL {
        let df = ISO8601DateFormatter()
        var rows: [String] = []
        switch kind {
        case .weights:
            rows.append("data,peso_kg,origem,tags,nota")
            for w in fetch(ctx, WeightEntry.self).sorted(by: { $0.date < $1.date }) {
                rows.append([df.string(from: w.date), n(w.kg), w.source, esc(w.tagsRaw), esc(w.note)].joined(separator: ","))
            }
        case .measurements:
            rows.append((["data"] + BodyPart.allCases.map(\.rawValue)).joined(separator: ","))
            for m in fetch(ctx, MeasurementEntry.self).sorted(by: { $0.date < $1.date }) {
                rows.append(([df.string(from: m.date)] + BodyPart.allCases.map { n(m[$0]) }).joined(separator: ","))
            }
        case .food:
            rows.append("data,refeicao,alimento,gramas,kcal,proteina_g,carbo_g,gordura_g,fibras_g,sodio_mg")
            for f in fetch(ctx, FoodLog.self).sorted(by: { $0.date < $1.date }) {
                let x = f.nutrients
                rows.append([df.string(from: f.date), f.meal.label, esc(f.name), n(f.grams), n(x.kcal), n(x.protein),
                             n(x.carbs), n(x.fat), n(x.fiber), n(x.sodium)].joined(separator: ","))
            }
        case .workouts:
            rows.append("data,treino,exercicio,serie,tipo,kg,reps,minutos,km,1rm_estimado")
            for s in fetch(ctx, WorkoutSession.self).filter({ !$0.isActive }).sorted(by: { $0.start < $1.start }) {
                for e in s.exercises {
                    for (i, set) in e.sets.enumerated() {
                        rows.append([df.string(from: s.start), esc(s.name), esc(e.exercise?.name ?? e.exerciseID), "\(i + 1)",
                                     set.kind.rawValue, n(set.kg), "\(set.reps)", n(set.minutes), n(set.km), n(set.e1RM)]
                            .joined(separator: ","))
                    }
                }
            }
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(kind.file).csv")
        try rows.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    /// Importa pesagens de um CSV qualquer: procura uma coluna de data e uma de peso.
    static func importWeightsCSV(_ url: URL, into ctx: ModelContext) throws -> Int {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let text = try String(contentsOf: url, encoding: .utf8)
        let lines = text.split(whereSeparator: \.isNewline).map(String.init)
        guard let header = lines.first else { return 0 }
        let sep: Character = header.contains(";") ? ";" : ","
        let cols = header.lowercased().split(separator: sep).map { $0.trimmingCharacters(in: .whitespaces.union(.init(charactersIn: "\""))) }
        let di = cols.firstIndex { $0.contains("data") || $0.contains("date") || $0.contains("time") } ?? 0
        let wi = cols.firstIndex { $0.contains("peso") || $0.contains("weight") || $0.contains("kg") } ?? 1
        let iso = ISO8601DateFormatter()
        let fmts = ["dd/MM/yyyy HH:mm", "dd/MM/yyyy", "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd HH:mm", "yyyy-MM-dd", "MM/dd/yyyy"].map { f -> DateFormatter in
            let d = DateFormatter(); d.dateFormat = f; d.locale = Locale(identifier: "pt_BR"); return d
        }
        let existing = Set(fetch(ctx, WeightEntry.self).map { "\(Int($0.date.timeIntervalSince1970))-\($0.kg)" })
        var added = 0
        for line in lines.dropFirst() {
            let f = line.split(separator: sep, omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces.union(.init(charactersIn: "\""))) }
            guard f.count > max(di, wi), let kg = Double(f[wi].replacingOccurrences(of: ",", with: ".")), kg > 10, kg < 400 else { continue }
            let ds = f[di]
            guard let date = iso.date(from: ds) ?? fmts.lazy.compactMap({ $0.date(from: ds) }).first else { continue }
            guard !existing.contains("\(Int(date.timeIntervalSince1970))-\(kg)") else { continue }
            ctx.insert(WeightEntry(date: date, kg: kg, source: "manual"))
            added += 1
        }
        try? ctx.save()
        return added
    }
}
