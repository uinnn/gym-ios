import Foundation
import Observation
import SwiftData

enum Muscle: String, CaseIterable, Identifiable, Codable {
    case chest, back, traps, shoulders, biceps, triceps, forearms, abs, obliques, lowerBack,
         glutes, quads, hamstrings, calves, adductors, cardio
    var id: String { rawValue }

    var label: String {
        switch self {
        case .chest: "Peito"
        case .back: "Costas"
        case .traps: "Trapézio"
        case .shoulders: "Ombros"
        case .biceps: "Bíceps"
        case .triceps: "Tríceps"
        case .forearms: "Antebraços"
        case .abs: "Abdômen"
        case .obliques: "Oblíquos"
        case .lowerBack: "Lombar"
        case .glutes: "Glúteos"
        case .quads: "Quadríceps"
        case .hamstrings: "Posteriores"
        case .calves: "Panturrilhas"
        case .adductors: "Adutores"
        case .cardio: "Cardio"
        }
    }

    var icon: String {
        switch self {
        case .chest, .shoulders, .traps: "figure.arms.open"
        case .back, .lowerBack: "figure.rower"
        case .biceps, .triceps, .forearms: "dumbbell.fill"
        case .abs, .obliques: "figure.core.training"
        case .glutes, .quads, .hamstrings, .adductors: "figure.strengthtraining.functional"
        case .calves: "figure.step.training"
        case .cardio: "heart.fill"
        }
    }

    /// Séries semanais recomendadas para hipertrofia (Schoenfeld et al.): 10–20.
    static let weeklySetsRange = 10.0...20.0

    static let trained: [Muscle] = allCases.filter { $0 != .cardio }
}

enum Equipment: String, CaseIterable, Identifiable, Codable {
    case barbell, dumbbell, machine, cable, bodyweight, kettlebell, band, cardioMachine, other
    var id: String { rawValue }
    var label: String {
        switch self {
        case .barbell: "Barra"
        case .dumbbell: "Halteres"
        case .machine: "Máquina"
        case .cable: "Polia/cabo"
        case .bodyweight: "Peso corporal"
        case .kettlebell: "Kettlebell"
        case .band: "Elástico"
        case .cardioMachine: "Aparelho de cardio"
        case .other: "Outro"
        }
    }
}

enum ExerciseKind: String, Codable { case strength, bodyweight, timed, cardio }

struct Exercise: Identifiable, Hashable {
    let id: String
    let name: String
    let primary: [Muscle]
    let secondary: [Muscle]
    let equipment: Equipment
    let kind: ExerciseKind
    let met: Double
    let howTo: String
    let tip: String

    var allMuscles: [Muscle] { primary + secondary }
}

// MARK: - Registros de treino (salvos como JSON dentro da sessão)

enum SetKind: String, Codable, CaseIterable {
    case normal, warmup, drop, failure
    var short: String {
        switch self {
        case .normal: ""
        case .warmup: "A"
        case .drop: "D"
        case .failure: "F"
        }
    }
    var label: String {
        switch self {
        case .normal: "Normal"
        case .warmup: "Aquecimento"
        case .drop: "Drop-set"
        case .failure: "Até a falha"
        }
    }
}

struct SetLog: Codable, Identifiable, Hashable {
    var id = UUID()
    var kg: Double = 0
    var reps: Int = 0
    var minutes: Double = 0      // cardio / isometria
    var km: Double = 0
    var rpe: Double? = nil
    var kind: SetKind = .normal
    var done = false

    /// 1RM estimado (Epley até 10 reps, Brzycki acima — mais preciso em cada faixa).
    var e1RM: Double {
        guard kg > 0, reps > 0 else { return 0 }
        if reps == 1 { return kg }
        if reps <= 10 { return kg * (1 + Double(reps) / 30) }
        return kg * 36 / (37 - Double(min(reps, 36)))
    }
    var volume: Double { kg * Double(reps) }
}

struct SessionExercise: Codable, Identifiable, Hashable {
    var id = UUID()
    var exerciseID: String
    var sets: [SetLog]
    var restSeconds: Int = 90
    var note: String = ""

    var exercise: Exercise? { ExerciseCatalog.byID[exerciseID] }
    var doneSets: [SetLog] { sets.filter(\.done) }
    var workSets: [SetLog] { doneSets.filter { $0.kind != .warmup } }
}

@Model
final class WorkoutSession {
    var start: Date = Date.now
    var end: Date?
    var name: String = "Treino"
    var note: String = ""
    var data: Data = Data()
    var bodyKg: Double = 70
    var rating: Int = 0      // 1–5: como se sentiu

    init(name: String, exercises: [SessionExercise], bodyKg: Double) {
        self.name = name
        self.bodyKg = bodyKg
        self.exercises = exercises
    }

    var exercises: [SessionExercise] {
        get { Caches.sessions.decode(data) ?? [] }
        set { data = Caches.sessions.encode(newValue) }
    }

    var duration: TimeInterval { (end ?? .now).timeIntervalSince(start) }
    var isActive: Bool { end == nil }
}

/// Exercício planejado numa rotina.
struct RoutineItem: Codable, Identifiable, Hashable {
    var id = UUID()
    var exerciseID: String
    var sets: Int = 3
    var repsMin: Int = 8
    var repsMax: Int = 12
    var restSeconds: Int = 90

    var exercise: Exercise? { ExerciseCatalog.byID[exerciseID] }
}

@Model
final class WorkoutRoutine {
    var name: String = "Rotina"
    var icon: String = "dumbbell.fill"
    var order: Int = 0
    var data: Data = Data()
    var createdAt: Date = Date.now
    /// Dia da semana (Calendar: 1 = domingo … 7 = sábado). 0 = sem dia.
    var weekday: Int = 0

    init(name: String, icon: String = "dumbbell.fill", order: Int = 0, items: [RoutineItem]) {
        self.name = name
        self.icon = icon
        self.order = order
        self.items = items
    }

    var items: [RoutineItem] {
        get { Caches.routines.decode(data) ?? [] }
        set { data = Caches.routines.encode(newValue) }
    }

    var muscles: [Muscle] {
        var seen: [Muscle] = []
        for m in items.compactMap(\.exercise).flatMap(\.primary) where !seen.contains(m) { seen.append(m) }
        return seen
    }
}

extension WorkoutRoutine {
    var totalSets: Int { items.map(\.sets).reduce(0, +) }

    /// Duração estimada: ~40 s por série + descanso.
    var estimatedMinutes: Double {
        items.map { i -> Double in
            if i.exercise?.kind == .cardio || i.exercise?.kind == .timed { return Double(i.repsMin * i.sets) }
            return Double(i.sets) * (40 + Double(i.restSeconds)) / 60
        }.reduce(0, +)
    }

    func estimatedKcal(bodyKg: Double) -> Double {
        let ex = items.compactMap(\.exercise)
        guard !ex.isEmpty else { return 0 }
        let met = ex.map(\.met).reduce(0, +) / Double(ex.count)
        return met * bodyKg * estimatedMinutes / 60
    }

    var muscleSets: [(Muscle, Double)] {
        var out: [Muscle: Double] = [:]
        for i in items {
            guard let x = i.exercise, x.kind != .cardio else { continue }
            for m in x.primary { out[m, default: 0] += Double(i.sets) }
            for m in x.secondary { out[m, default: 0] += Double(i.sets) * 0.5 }
        }
        return out.sorted { $0.value > $1.value }.map { ($0.key, $0.value) }
    }
}

enum Weekday {
    /// Ordem de segunda a domingo (valores do Calendar).
    static let mondayFirst = [2, 3, 4, 5, 6, 7, 1]
    static func name(_ d: Int) -> String {
        ["", "Domingo", "Segunda", "Terça", "Quarta", "Quinta", "Sexta", "Sábado"][min(max(d, 0), 7)]
    }
    static func short(_ d: Int) -> String {
        ["", "Dom", "Seg", "Ter", "Qua", "Qui", "Sex", "Sáb"][min(max(d, 0), 7)]
    }
    static var today: Int { Calendar.current.component(.weekday, from: .now) }
}

/// Exercícios favoritos e preferências de treino (salvos no aparelho).
@Observable
final class WorkoutPrefs {
    static let shared = WorkoutPrefs()
    private let d = UserDefaults.standard

    var favorites: Set<String> { didSet { d.set(Array(favorites), forKey: "favExercises") } }
    var addWorkoutKcal: Bool { didSet { d.set(addWorkoutKcal, forKey: "addWorkoutKcal") } }
    // últimas escolhas do gerador
    var goalRaw: String { didSet { d.set(goalRaw, forKey: "genGoal") } }
    var levelRaw: String { didSet { d.set(levelRaw, forKey: "genLevel") } }
    var placeRaw: String { didSet { d.set(placeRaw, forKey: "genPlace") } }
    var days: [Int] { didSet { d.set(days, forKey: "genDays") } }
    /// Foco por músculo: 0 normal, 1 prioridade, 2 alta, 3 máxima.
    var focus: [String: Int] { didSet { d.set(focus, forKey: "genFocus") } }
    var advanced: Bool { didSet { d.set(advanced, forKey: "genAdvanced") } }
    var styleRaw: String { didSet { d.set(styleRaw, forKey: "genStyle") } }
    var equipRaw: String { didSet { d.set(equipRaw, forKey: "genEquip") } }
    var volumeDelta: Int { didSet { d.set(volumeDelta, forKey: "genVolume") } }
    var maxExercises: Int { didSet { d.set(maxExercises, forKey: "genMaxEx") } }

    func weight(_ m: Muscle) -> Int { focus[m.rawValue] ?? 0 }

    private init() {
        favorites = Set(d.stringArray(forKey: "favExercises") ?? [])
        addWorkoutKcal = d.object(forKey: "addWorkoutKcal") as? Bool ?? true
        goalRaw = d.string(forKey: "genGoal") ?? "hypertrophy"
        levelRaw = d.string(forKey: "genLevel") ?? "beginner"
        placeRaw = d.string(forKey: "genPlace") ?? "gym"
        days = (d.array(forKey: "genDays") as? [Int]) ?? [2, 4, 6]
        focus = (d.dictionary(forKey: "genFocus") as? [String: Int]) ?? [:]
        advanced = d.bool(forKey: "genAdvanced")
        styleRaw = d.string(forKey: "genStyle") ?? "balanced"
        equipRaw = d.string(forKey: "genEquip") ?? "mixed"
        volumeDelta = d.integer(forKey: "genVolume")
        maxExercises = d.object(forKey: "genMaxEx") as? Int ?? 8
    }

    func toggle(_ id: String) {
        if favorites.contains(id) { favorites.remove(id) } else { favorites.insert(id) }
    }
}

enum ExerciseStyle: String, CaseIterable, Identifiable {
    case balanced, compound, isolation, best
    var id: String { rawValue }
    var label: String {
        switch self {
        case .balanced: "Equilibrado"
        case .compound: "Mais compostos"
        case .isolation: "Mais isolados"
        case .best: "Os melhores"
        }
    }
    var detail: String {
        switch self {
        case .balanced: "Mistura de multiarticulares e isoladores, como um programa clássico."
        case .compound: "Prioriza exercícios que trabalham vários músculos (mais eficiência e força)."
        case .isolation: "Prioriza exercícios focados em um músculo (ótimo para detalhes e articulações sensíveis)."
        case .best: "Os exercícios com maior evidência de estímulo para cada músculo."
        }
    }
}

enum EquipmentPreference: String, CaseIterable, Identifiable {
    case mixed, free, machines
    var id: String { rawValue }
    var label: String {
        switch self {
        case .mixed: "Misto"
        case .free: "Pesos livres"
        case .machines: "Máquinas e cabos"
        }
    }
}

extension Exercise {
    var isCompound: Bool { primary.count >= 2 || allMuscles.count >= 3 }
    var isIsolation: Bool { primary.count == 1 && secondary.count <= 1 }
    var isFreeWeight: Bool { [.barbell, .dumbbell, .kettlebell, .bodyweight].contains(equipment) }

    /// Exercícios com melhor relação estímulo/fadiga segundo a literatura e a prática.
    static let staples: Set<String> = [
        "bench", "incline-db", "chest-press", "cable-cross", "squat", "hack-squat", "leg-press", "bulgarian", "deadlift",
        "rdl", "hip-thrust", "leg-curl", "seated-leg-curl", "leg-extension", "pullup", "lat-pulldown", "barbell-row",
        "seated-row", "ohp", "db-press", "lateral-raise", "cable-lateral", "face-pull", "triceps-rope", "overhead-ext",
        "incline-curl", "preacher-curl", "standing-calf", "cable-crunch", "hanging-knee",
    ]

    func score(style: ExerciseStyle, equip: EquipmentPreference) -> Int {
        var s = 0
        switch style {
        case .balanced: s += Exercise.staples.contains(id) ? 1 : 0
        case .compound: s += isCompound ? 3 : 0
        case .isolation: s += isIsolation ? 3 : 0
        case .best: s += Exercise.staples.contains(id) ? 3 : 0
        }
        switch equip {
        case .mixed: break
        case .free: s += isFreeWeight ? 2 : 0
        case .machines: s += (equipment == .machine || equipment == .cable) ? 2 : 0
        }
        if WorkoutPrefs.shared.favorites.contains(id) { s += 2 }
        return s
    }
}

enum ExerciseAlternatives {
    static func allowed(_ eq: Equipment, home: Bool) -> Bool {
        !home || [.dumbbell, .bodyweight, .kettlebell, .band, .other].contains(eq)
    }

    /// Exercícios equivalentes (mesmo músculo principal e tipo).
    static func options(for id: String, home: Bool = false) -> [Exercise] {
        guard let x = ExerciseCatalog.byID[id], let m = x.primary.first else { return [] }
        return ExerciseCatalog.all.filter {
            $0.id != id && $0.primary.first == m && ($0.kind == .cardio) == (x.kind == .cardio)
                && allowed($0.equipment, home: home)
        }
    }

    /// Sorteia um substituto, com 3x mais chance para favoritos.
    static func random(for id: String, home: Bool = false, excluding: Set<String> = []) -> Exercise? {
        let opts = options(for: id, home: home).filter { !excluding.contains($0.id) }
        guard !opts.isEmpty else { return nil }
        let fav = WorkoutPrefs.shared.favorites
        let pool = opts.flatMap { fav.contains($0.id) ? [$0, $0, $0] : [$0] }
        return pool.randomElement()
    }
}

// MARK: - Análise

enum WorkoutMath {
    /// Calorias pela fórmula de MET: MET × kg × horas (Compendium of Physical Activities).
    static func kcal(_ s: WorkoutSession) -> Double {
        let ex = s.exercises
        guard !ex.isEmpty else { return 0 }
        var total = 0.0
        var timed = 0.0
        for e in ex {
            guard let x = e.exercise else { continue }
            let done = e.doneSets
            if x.kind == .cardio || x.kind == .timed {
                let minutes = done.map(\.minutes).reduce(0, +)
                total += x.met * s.bodyKg * minutes / 60
                timed += minutes
            }
        }
        // musculação: tempo restante da sessão distribuído pela MET média dos exercícios de força
        let strength = ex.compactMap(\.exercise).filter { $0.kind == .strength || $0.kind == .bodyweight }
        if !strength.isEmpty {
            let met = strength.map(\.met).reduce(0, +) / Double(strength.count)
            let minutes = max(0, s.duration / 60 - timed)
            total += met * s.bodyKg * min(minutes, 180) / 60
        }
        return total
    }

    static func volume(_ s: WorkoutSession) -> Double {
        s.exercises.flatMap(\.workSets).map(\.volume).reduce(0, +)
    }

    static func setsCount(_ s: WorkoutSession) -> Int {
        s.exercises.map(\.workSets.count).reduce(0, +)
    }

    /// Séries por músculo (primário = 1, secundário = 0,5).
    static func muscleSets(_ sessions: [WorkoutSession]) -> [Muscle: Double] {
        var out: [Muscle: Double] = [:]
        for s in sessions {
            for e in s.exercises {
                guard let x = e.exercise else { continue }
                let n = Double(e.workSets.count)
                for m in x.primary { out[m, default: 0] += n }
                for m in x.secondary { out[m, default: 0] += n * 0.5 }
            }
        }
        return out
    }

    /// Melhor série (maior 1RM estimado) de um exercício e o maior volume numa sessão.
    static func best(_ exerciseID: String, in sessions: [WorkoutSession]) -> (e1RM: Double, kg: Double, reps: Int, volume: Double)? {
        var top: SetLog?
        var maxVolume = 0.0
        for s in sessions {
            for e in s.exercises where e.exerciseID == exerciseID {
                let work = e.workSets
                maxVolume = max(maxVolume, work.map(\.volume).reduce(0, +))
                for set in work where set.e1RM > (top?.e1RM ?? 0) { top = set }
            }
        }
        guard let t = top else { return nil }
        return (e1RM: t.e1RM, kg: t.kg, reps: t.reps, volume: maxVolume)
    }

    /// Últimas séries feitas desse exercício (para mostrar "anterior").
    /// Percorre uma vez guardando a sessão mais recente, em vez de ordenar todo o histórico.
    static func previous(_ exerciseID: String, before date: Date, in sessions: [WorkoutSession]) -> [SetLog] {
        var bestDate = Date.distantPast
        var result: [SetLog] = []
        for s in sessions where s.start < date && s.start > bestDate && !s.isActive {
            if let done = s.exercises.first(where: { $0.exerciseID == exerciseID })?.doneSets, !done.isEmpty {
                bestDate = s.start
                result = done
            }
        }
        return result
    }
    static func durationText(_ t: TimeInterval) -> String {
        let m = Int(t) / 60
        return m >= 60 ? "\(m / 60)h \(m % 60)min" : "\(m) min"
    }
}
