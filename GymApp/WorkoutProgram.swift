import SwiftUI
import SwiftData

enum TrainingGoal: String, CaseIterable, Identifiable {
    case hypertrophy, strength, fatLoss, general
    var id: String { rawValue }
    var label: String {
        switch self {
        case .hypertrophy: "Hipertrofia"
        case .strength: "Força"
        case .fatLoss: "Emagrecimento"
        case .general: "Saúde geral"
        }
    }
    var icon: String {
        switch self {
        case .hypertrophy: "figure.strengthtraining.traditional"
        case .strength: "scalemass.fill"
        case .fatLoss: "flame.fill"
        case .general: "heart.fill"
        }
    }
    /// (séries, reps mín, reps máx, descanso s)
    var scheme: (Int, Int, Int, Int) {
        switch self {
        case .hypertrophy: (3, 8, 12, 90)
        case .strength: (4, 4, 6, 180)
        case .fatLoss: (3, 12, 15, 60)
        case .general: (3, 10, 12, 75)
        }
    }
}

enum TrainingLevel: String, CaseIterable, Identifiable {
    case beginner, intermediate, advanced
    var id: String { rawValue }
    var label: String {
        switch self {
        case .beginner: "Iniciante"
        case .intermediate: "Intermediário"
        case .advanced: "Avançado"
        }
    }
}

enum TrainingPlace: String, CaseIterable, Identifiable {
    case gym, home
    var id: String { rawValue }
    var label: String { self == .gym ? "Academia" : "Casa (halteres)" }
}

/// Gera um programa de treino completo.
enum ProgramGenerator {
    private static let days: [String: (String, String, [String])] = [
        "fullA": ("Full body A", "figure.mixed.cardio", ["squat", "bench", "barbell-row", "lateral-raise", "triceps-pushdown", "barbell-curl", "plank"]),
        "fullB": ("Full body B", "figure.mixed.cardio", ["deadlift", "ohp", "lat-pulldown", "leg-press", "db-curl", "overhead-ext", "crunch"]),
        "fullC": ("Full body C", "figure.mixed.cardio", ["bulgarian", "incline-db", "seated-row", "leg-curl", "face-pull", "hammer-curl", "leg-raise"]),
        "upperA": ("Superior A", "figure.arms.open", ["bench", "barbell-row", "db-press", "lat-pulldown", "lateral-raise", "barbell-curl", "triceps-pushdown"]),
        "lowerA": ("Inferior A", "figure.strengthtraining.functional", ["squat", "rdl", "leg-press", "leg-curl", "standing-calf", "hanging-knee"]),
        "upperB": ("Superior B", "figure.arms.open", ["incline-db", "seated-row", "ohp", "pullup", "rear-delt-fly", "hammer-curl", "overhead-ext"]),
        "lowerB": ("Inferior B", "figure.strengthtraining.functional", ["deadlift", "bulgarian", "leg-extension", "seated-leg-curl", "hip-thrust", "seated-calf", "cable-crunch"]),
        "push": ("Empurrar (peito, ombro, tríceps)", "arrow.up.forward", ["bench", "incline-db", "ohp", "lateral-raise", "cable-cross", "triceps-rope", "overhead-ext"]),
        "pull": ("Puxar (costas, bíceps)", "arrow.down.backward", ["pullup", "barbell-row", "seated-row", "face-pull", "barbell-curl", "hammer-curl", "shrug"]),
        "legs": ("Pernas", "figure.strengthtraining.functional", ["squat", "rdl", "leg-press", "leg-extension", "leg-curl", "standing-calf", "plank"]),
        "pushB": ("Empurrar B", "arrow.up.forward", ["incline-bench", "db-press", "chest-press", "cable-lateral", "fly-db", "skullcrusher"]),
        "pullB": ("Puxar B", "arrow.down.backward", ["deadlift", "lat-pulldown", "db-row", "rear-delt-fly", "incline-curl", "cable-curl"]),
        "legsB": ("Pernas B", "figure.strengthtraining.functional", ["hack-squat", "hip-thrust", "bulgarian", "seated-leg-curl", "seated-calf", "hanging-knee"]),
    ]

    private static let homeSwap: [String: String?] = [
        "bench": "bench-db", "incline-bench": "incline-db", "barbell-row": "db-row", "seated-row": "db-row",
        "lat-pulldown": "pullup", "ohp": "db-press", "leg-press": "goblet-squat", "leg-extension": "lunge",
        "leg-curl": "rdl", "seated-leg-curl": "glute-bridge", "triceps-pushdown": "overhead-ext", "triceps-rope": "bench-dips",
        "cable-cross": "fly-db", "chest-press": "pushup", "cable-lateral": "lateral-raise", "face-pull": "rear-delt-fly",
        "cable-curl": "db-curl", "standing-calf": nil, "seated-calf": nil, "squat": "goblet-squat", "deadlift": "rdl",
        "hack-squat": "goblet-squat", "cable-crunch": "crunch", "skullcrusher": "overhead-ext", "barbell-curl": "db-curl",
        "hip-thrust": "glute-bridge", "shrug": "shrug",
    ]

    static func split(days n: Int) -> [String] {
        switch n {
        case ...2: ["fullA", "fullB"]
        case 3: ["fullA", "fullB", "fullC"]
        case 4: ["upperA", "lowerA", "upperB", "lowerB"]
        case 5: ["push", "pull", "legs", "upperA", "lowerB"]
        default: ["push", "pull", "legs", "pushB", "pullB", "legsB"]
        }
    }

    static func splitName(days n: Int) -> String {
        switch n {
        case ...3: "Full body"
        case 4: "Superior / Inferior"
        case 5: "PPL + Superior/Inferior"
        default: "Push / Pull / Legs 2x"
        }
    }

    static func make(goal: TrainingGoal, level: TrainingLevel, days: Int, place: TrainingPlace) -> [WorkoutRoutine] {
        let (sets, rmin, rmax, rest) = goal.scheme
        return split(days: days).enumerated().compactMap { i, key in
            guard let d = Self.days[key] else { return nil }
            var ids = d.2
            if place == .home { ids = ids.compactMap { id in homeSwap.keys.contains(id) ? homeSwap[id]! : id } }
            var seen = Set<String>()
            ids = ids.filter { seen.insert($0).inserted }
            if level == .beginner { ids = Array(ids.prefix(5)) }
            var items: [RoutineItem] = ids.enumerated().map { j, id in
                let compound = j < 2 && (ExerciseCatalog.byID[id]?.primary.count ?? 1) >= 1
                let extra = level == .advanced && compound ? 1 : 0
                let isTimed = ExerciseCatalog.byID[id]?.kind == .timed
                return RoutineItem(exerciseID: id, sets: sets + extra,
                                   repsMin: isTimed ? 1 : (goal == .strength && !compound ? 8 : rmin),
                                   repsMax: isTimed ? 1 : (goal == .strength && !compound ? 12 : rmax),
                                   restSeconds: compound ? rest : max(60, rest - 30))
            }
            if goal == .fatLoss {
                items.append(RoutineItem(exerciseID: place == .gym ? "walk-incline" : "hiit", sets: 1, repsMin: 20, repsMax: 20, restSeconds: 0))
            }
            return WorkoutRoutine(name: d.0, icon: d.1, order: i, items: items)
        }
    }
}

// MARK: - Gerador (tela)

struct ProgramGeneratorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var routines: [WorkoutRoutine]
    @State private var goal: TrainingGoal = .hypertrophy
    @State private var level: TrainingLevel = .beginner
    @State private var days = 3
    @State private var place: TrainingPlace = .gym
    @State private var replace = true

    var body: some View {
        let preview = ProgramGenerator.make(goal: goal, level: level, days: days, place: place)
        NavigationStack {
            Form {
                Section("Objetivo") {
                    Picker("Objetivo", selection: $goal.animation()) {
                        ForEach(TrainingGoal.allCases) { Label($0.label, systemImage: $0.icon).tag($0) }
                    }
                    .pickerStyle(.inline).labelsHidden()
                }
                Section("Você") {
                    Picker("Nível", selection: $level.animation()) {
                        ForEach(TrainingLevel.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Stepper("\(days) dias por semana", value: $days.animation(), in: 2...6)
                    Picker("Local", selection: $place.animation()) {
                        ForEach(TrainingPlace.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                Section {
                    ForEach(Array(preview.enumerated()), id: \.offset) { _, r in
                        VStack(alignment: .leading, spacing: 4) {
                            Label(r.name, systemImage: r.icon).font(.subheadline.bold())
                            Text(r.items.compactMap { $0.exercise?.name }.joined(separator: " · "))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Divisão: \(ProgramGenerator.splitName(days: days))")
                } footer: {
                    let s = goal.scheme
                    let txt: String = "\(s.0) séries de \(s.1)–\(s.2) repetições, descanso de \(s.3) s. Progrida a carga quando completar o topo da faixa de repetições em todas as séries."
                    Text(txt)
                }
                if !routines.isEmpty {
                    Toggle("Substituir minhas rotinas atuais", isOn: $replace)
                }
            }
            .navigationTitle("Gerar programa")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Criar") {
                        if replace { routines.forEach { context.delete($0) } }
                        let base = replace ? 0 : routines.count
                        for r in preview { r.order += base; context.insert(r) }
                        dismiss()
                    }
                    .bold()
                }
            }
        }
    }
}

// MARK: - Editor de rotina

struct RoutineEditorView: View {
    @Bindable var routine: WorkoutRoutine
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var items: [RoutineItem] = []
    @State private var showPicker = false
    @State private var confirmDelete = false

    private let icons = ["dumbbell.fill", "figure.arms.open", "figure.strengthtraining.functional", "figure.mixed.cardio",
                         "arrow.up.forward", "arrow.down.backward", "figure.run", "heart.fill", "flame.fill", "bolt.fill"]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nome da rotina", text: $routine.name).font(.headline)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(icons, id: \.self) { i in
                                Button { routine.icon = i } label: {
                                    Image(systemName: i).frame(width: 40, height: 40)
                                        .foregroundStyle(routine.icon == i ? .white : Theme.accent)
                                        .background(routine.icon == i ? AnyShapeStyle(Theme.gradient) : AnyShapeStyle(.quaternary), in: Circle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                Section("Exercícios (\(items.count))") {
                    ForEach($items) { $item in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.exercise?.name ?? item.exerciseID).font(.subheadline.bold())
                            HStack {
                                Stepper("\(item.sets) séries", value: $item.sets, in: 1...10).font(.caption)
                            }
                            if item.exercise?.kind == .cardio || item.exercise?.kind == .timed {
                                Stepper("\(item.repsMin) min", value: $item.repsMin, in: 1...120).font(.caption)
                            } else {
                                Stepper("Reps: \(item.repsMin)–\(item.repsMax)", onIncrement: {
                                    item.repsMin += 1; item.repsMax += 1
                                }, onDecrement: {
                                    item.repsMin = max(1, item.repsMin - 1); item.repsMax = max(item.repsMin, item.repsMax - 1)
                                }).font(.caption)
                            }
                            Stepper("Descanso: \(item.restSeconds) s", value: $item.restSeconds, in: 0...300, step: 15).font(.caption)
                        }
                    }
                    .onDelete { items.remove(atOffsets: $0) }
                    .onMove { items.move(fromOffsets: $0, toOffset: $1) }
                    Button { showPicker = true } label: { Label("Adicionar exercício", systemImage: "plus.circle.fill") }
                }
                Section {
                    Button("Apagar rotina", role: .destructive) { confirmDelete = true }
                }
            }
            .navigationTitle("Editar rotina")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { EditButton() }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") { routine.items = items; dismiss() }.bold()
                }
            }
            .sheet(isPresented: $showPicker) {
                ExercisePickerView { picked in
                    items += picked.map { RoutineItem(exerciseID: $0.id) }
                }
            }
            .confirmationDialog("Apagar \"\(routine.name)\"?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Apagar", role: .destructive) { context.delete(routine); dismiss() }
            }
            .onAppear { items = routine.items }
        }
    }
}
