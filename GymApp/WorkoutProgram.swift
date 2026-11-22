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

    struct Planned: Identifiable {
        let id = UUID()
        var name: String
        var icon: String
        var weekday: Int
        var items: [RoutineItem]
    }

    /// Gera o programa. `vary` troca parte dos exercícios por equivalentes (favoritos têm prioridade).
    static func make(goal: TrainingGoal, level: TrainingLevel, weekdays: [Int], place: TrainingPlace,
                     vary: Bool) -> [Planned] {
        let (sets, rmin, rmax, rest) = goal.scheme
        let order = Weekday.mondayFirst.filter { weekdays.contains($0) }
        let fav = WorkoutPrefs.shared.favorites
        let home = place == .home
        return split(days: max(order.count, 2)).enumerated().compactMap { i, key in
            guard let d = Self.days[key] else { return nil }
            var ids = d.2
            if home { ids = ids.compactMap { id in homeSwap.keys.contains(id) ? homeSwap[id]! : id } }
            var used = Set<String>()
            ids = ids.compactMap { id -> String? in
                var pick = id
                let opts = ExerciseAlternatives.options(for: id, home: home).filter { !used.contains($0.id) }
                if let f = opts.first(where: { fav.contains($0.id) }), !fav.contains(id), Bool.random() || !vary {
                    pick = f.id
                } else if vary, Int.random(in: 0..<100) < 45,
                          let r = ExerciseAlternatives.random(for: id, home: home, excluding: used) {
                    pick = r.id
                }
                guard used.insert(pick).inserted else { return nil }
                return pick
            }
            if level == .beginner { ids = Array(ids.prefix(5)) }
            var items: [RoutineItem] = ids.enumerated().map { j, id in
                let compound = j < 2
                let extra = level == .advanced && compound ? 1 : 0
                let isTimed = ExerciseCatalog.byID[id]?.kind == .timed
                return RoutineItem(exerciseID: id, sets: sets + extra,
                                   repsMin: isTimed ? 1 : (goal == .strength && !compound ? 8 : rmin),
                                   repsMax: isTimed ? 1 : (goal == .strength && !compound ? 12 : rmax),
                                   restSeconds: compound ? rest : max(60, rest - 30))
            }
            if goal == .fatLoss {
                items.append(RoutineItem(exerciseID: home ? "hiit" : "walk-incline", sets: 1, repsMin: 20, repsMax: 20, restSeconds: 0))
            }
            return Planned(name: d.0, icon: d.1, weekday: i < order.count ? order[i] : 0, items: items)
        }
    }
}

// MARK: - Gerador (tela)

struct ProgramGeneratorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var routines: [WorkoutRoutine]
    @Bindable private var prefs = WorkoutPrefs.shared
    @State private var vary = true
    @State private var replace = true
    @State private var preview: [ProgramGenerator.Planned] = []
    @State private var rolls = 0

    private var goal: TrainingGoal { TrainingGoal(rawValue: prefs.goalRaw) ?? .hypertrophy }
    private var level: TrainingLevel { TrainingLevel(rawValue: prefs.levelRaw) ?? .beginner }
    private var place: TrainingPlace { TrainingPlace(rawValue: prefs.placeRaw) ?? .gym }

    var body: some View {
        NavigationStack {
            Form {
                Section("Objetivo") {
                    Picker("Objetivo", selection: $prefs.goalRaw) {
                        ForEach(TrainingGoal.allCases) { Label($0.label, systemImage: $0.icon).tag($0.rawValue) }
                    }
                    .pickerStyle(.inline).labelsHidden()
                }
                Section {
                    HStack(spacing: 6) {
                        ForEach(Weekday.mondayFirst, id: \.self) { d in
                            let on = prefs.days.contains(d)
                            Button {
                                withAnimation(.spring(duration: 0.3)) {
                                    if on { prefs.days.removeAll { $0 == d } } else { prefs.days.append(d) }
                                }
                            } label: {
                                Text(Weekday.short(d)).font(.caption.bold())
                                    .frame(maxWidth: .infinity, minHeight: 40)
                                    .foregroundStyle(on ? .white : .primary)
                                    .background(on ? AnyShapeStyle(Theme.gradient) : AnyShapeStyle(.quaternary),
                                                in: RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } header: { Text("Dias de treino (\(prefs.days.count))") } footer: {
                    Text(prefs.days.count < 2 ? "Escolha pelo menos 2 dias." : "Divisão: \(ProgramGenerator.splitName(days: prefs.days.count)). Os outros dias ficam como descanso.")
                }
                Section("Você") {
                    Picker("Nível", selection: $prefs.levelRaw) {
                        ForEach(TrainingLevel.allCases) { Text($0.label).tag($0.rawValue) }
                    }
                    .pickerStyle(.segmented)
                    Picker("Local", selection: $prefs.placeRaw) {
                        ForEach(TrainingPlace.allCases) { Text($0.label).tag($0.rawValue) }
                    }
                    .pickerStyle(.segmented)
                    Toggle("Variar exercícios", isOn: $vary)
                    if !prefs.favorites.isEmpty {
                        Label("\(prefs.favorites.count) favoritos terão prioridade", systemImage: "star.fill")
                            .font(.caption).foregroundStyle(.yellow)
                    }
                }
                Section {
                    ForEach(preview) { r in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(Weekday.name(r.weekday)).font(.caption.bold()).foregroundStyle(Theme.accent)
                                Spacer()
                            }
                            Label(r.name, systemImage: r.icon).font(.subheadline.bold())
                            Text(r.items.compactMap { $0.exercise?.name }.joined(separator: " · "))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                    }
                    Button {
                        withAnimation(.spring) { rolls += 1 }
                    } label: { Label("Gerar outra variação", systemImage: "dice.fill") }
                } header: { Text("Prévia") } footer: {
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
                    Button("Criar") { create() }.bold().disabled(prefs.days.count < 2)
                }
            }
            .onAppear(perform: regenerate)
            .onChange(of: prefs.goalRaw) { _, _ in regenerate() }
            .onChange(of: prefs.levelRaw) { _, _ in regenerate() }
            .onChange(of: prefs.placeRaw) { _, _ in regenerate() }
            .onChange(of: prefs.days) { _, _ in regenerate() }
            .onChange(of: vary) { _, _ in regenerate() }
            .onChange(of: rolls) { _, _ in regenerate() }
        }
    }

    private func regenerate() {
        withAnimation(.spring) {
            preview = ProgramGenerator.make(goal: goal, level: level, weekdays: prefs.days, place: place, vary: vary)
        }
    }

    private func create() {
        if replace { routines.forEach { context.delete($0) } }
        let base = replace ? 0 : routines.count
        for (i, p) in preview.enumerated() {
            let r = WorkoutRoutine(name: p.name, icon: p.icon, order: base + i, items: p.items)
            r.weekday = p.weekday
            context.insert(r)
        }
        dismiss()
    }
}

// MARK: - Editor de rotina

struct RoutineEditorView: View {
    @Bindable var routine: WorkoutRoutine
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var items: [RoutineItem] = []
    @State private var showPicker = false
    @State private var replacing: UUID?
    @State private var confirmDelete = false

    private let icons = ["dumbbell.fill", "figure.arms.open", "figure.strengthtraining.functional", "figure.mixed.cardio",
                         "arrow.up.forward", "arrow.down.backward", "figure.run", "heart.fill", "flame.fill", "bolt.fill"]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nome da rotina", text: $routine.name).font(.headline)
                    Picker("Dia da semana", selection: $routine.weekday) {
                        Text("Sem dia").tag(0)
                        ForEach(Weekday.mondayFirst, id: \.self) { Text(Weekday.name($0)).tag($0) }
                    }
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
                Section {
                    ForEach($items) { $item in
                        itemRow($item)
                    }
                    .onDelete { items.remove(atOffsets: $0) }
                    .onMove { items.move(fromOffsets: $0, toOffset: $1) }
                    Button { replacing = nil; showPicker = true } label: { Label("Adicionar exercício", systemImage: "plus.circle.fill") }
                    Button {
                        withAnimation(.spring) {
                            var used = Set(items.map(\.exerciseID))
                            for i in items.indices {
                                if let r = ExerciseAlternatives.random(for: items[i].exerciseID, excluding: used) {
                                    used.insert(r.id); items[i].exerciseID = r.id
                                }
                            }
                        }
                    } label: { Label("Sortear todos os exercícios", systemImage: "dice.fill") }
                } header: { Text("Exercícios (\(items.count))") } footer: {
                    Text("Use 🔄 para trocar um exercício: escolha da lista ou sorteie um equivalente para o mesmo músculo (favoritos têm prioridade). Arraste com \"Editar\" para reordenar.")
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
                ExercisePickerView(single: replacing != nil) { picked in
                    if let r = replacing, let i = items.firstIndex(where: { $0.id == r }), let first = picked.first {
                        items[i].exerciseID = first.id
                    } else {
                        items += picked.map { RoutineItem(exerciseID: $0.id) }
                    }
                    replacing = nil
                }
            }
            .confirmationDialog("Apagar \"\(routine.name)\"?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Apagar", role: .destructive) { context.delete(routine); dismiss() }
            }
            .onAppear { items = routine.items }
        }
    }

    private func itemRow(_ item: Binding<RoutineItem>) -> some View {
        let it = item.wrappedValue
        let cardio = it.exercise?.kind == .cardio || it.exercise?.kind == .timed
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                if WorkoutPrefs.shared.favorites.contains(it.exerciseID) {
                    Image(systemName: "star.fill").font(.caption2).foregroundStyle(.yellow)
                }
                Text(it.exercise?.name ?? it.exerciseID).font(.subheadline.bold())
                Spacer()
                Menu {
                    Button("Escolher exercício", systemImage: "list.bullet") { replacing = it.id; showPicker = true }
                    Button("Sortear equivalente", systemImage: "dice.fill") {
                        let used = Set(items.map(\.exerciseID))
                        if let r = ExerciseAlternatives.random(for: it.exerciseID, excluding: used) {
                            withAnimation(.spring) { item.wrappedValue.exerciseID = r.id }
                        }
                    }
                    let opts = ExerciseAlternatives.options(for: it.exerciseID).prefix(8)
                    if !opts.isEmpty {
                        Section("Equivalentes") {
                            ForEach(Array(opts)) { o in
                                Button(o.name) { withAnimation { item.wrappedValue.exerciseID = o.id } }
                            }
                        }
                    }
                } label: { Image(systemName: "arrow.triangle.2.circlepath").foregroundStyle(Theme.accent) }
                .buttonStyle(.borderless)
            }
            Stepper("\(it.sets) séries", value: item.sets, in: 1...10).font(.caption)
            if cardio {
                Stepper("\(it.repsMin) min", value: item.repsMin, in: 1...120).font(.caption)
            } else {
                Stepper("Reps: \(it.repsMin)–\(it.repsMax)", onIncrement: {
                    item.wrappedValue.repsMin += 1; item.wrappedValue.repsMax += 1
                }, onDecrement: {
                    item.wrappedValue.repsMin = max(1, it.repsMin - 1)
                    item.wrappedValue.repsMax = max(item.wrappedValue.repsMin, it.repsMax - 1)
                }).font(.caption)
            }
            Stepper("Descanso: \(it.restSeconds) s", value: item.restSeconds, in: 0...300, step: 15).font(.caption)
        }
    }
}
