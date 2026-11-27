import SwiftUI
import SwiftData
import UserNotifications

enum WorkoutStarter {
    /// Cria uma sessão a partir de uma rotina, já preenchendo cargas e reps da última vez.
    static func session(from routine: WorkoutRoutine?, history: [WorkoutSession], bodyKg: Double) -> WorkoutSession {
        let prefs = WorkoutPrefs.shared
        var warmed = Set<Muscle>()
        let exercises: [SessionExercise] = (routine?.items ?? []).map { item in
            let prev = WorkoutMath.previous(item.exerciseID, before: .now, in: history).filter { $0.kind != .warmup }
            let x = item.exercise
            let kind = x?.kind ?? .strength
            if kind == .cardio || kind == .timed {
                let sets = (0..<item.sets).map { i -> SetLog in
                    var s = SetLog()
                    s.minutes = prev.indices.contains(i) ? prev[i].minutes : Double(item.repsMin)
                    return s
                }
                return SessionExercise(exerciseID: item.exerciseID, sets: sets, restSeconds: item.restSeconds)
            }
            let plan = prefs.autoProgression
                ? WorkoutCoach.progression(prev: prev, sets: item.sets, range: item.repsMin...max(item.repsMin, item.repsMax), exercise: x)
                : WorkoutCoach.Plan(sets: (0..<item.sets).map { i in
                    let p = prev.indices.contains(i) ? prev[i] : prev.last
                    var s = SetLog(); s.kg = p?.kg ?? 0; s.reps = p?.reps ?? item.repsMax; return s
                }, hint: nil)
            var sets = plan.sets
            // aquecimento só no primeiro exercício composto de cada músculo
            if prefs.autoWarmup, let x, x.kind == .strength, x.isCompound, let m = x.primary.first, !warmed.contains(m),
               let top = sets.map(\.kg).max() {
                warmed.insert(m)
                sets = WorkoutCoach.warmups(topKg: top, exercise: x) + sets
            }
            var e = SessionExercise(exerciseID: item.exerciseID, sets: sets, restSeconds: item.restSeconds)
            e.hint = plan.hint
            return e
        }
        return WorkoutSession(name: routine?.name ?? "Treino livre", exercises: exercises, bodyKg: bodyKg)
    }
}

struct ActiveWorkoutView: View {
    @Bindable var session: WorkoutSession
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \WorkoutSession.start, order: .reverse) private var history: [WorkoutSession]
    @State private var exercises: [SessionExercise] = []
    @State private var restEnd: Date?
    @State private var restTotal: Double = 90
    @State private var showPicker = false
    @State private var replacing: UUID?
    @State private var detail: Exercise?
    @State private var confirmCancel = false
    @State private var summary: WorkoutSession?
    @State private var prFlash: UUID?
    @State private var tick = 0
    @State private var undo: WorkoutUndo?
    @State private var collapsed: Set<UUID> = []
    @State private var noteOpen: Set<UUID> = []
    @State private var renaming = false
    @State private var newName = ""
    @State private var diskSave: Task<Void, Never>?
    @Environment(\.scenePhase) private var phase
    /// Campo em edição (série + qual valor): os atalhos do teclado agem sobre ele.
    struct FieldKey: Hashable { enum Kind { case kg, reps, minutes, km }; let set: UUID; let kind: Kind }
    @FocusState private var focus: FieldKey?

    private var past: [WorkoutSession] { history.filter { !$0.isActive && $0.persistentModelID != session.persistentModelID } }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                AnimatedBackground()
                ScrollView {
                    VStack(spacing: 14) {
                        header
                        ForEach($exercises) { $ex in
                            exerciseCard($ex)
                                .transition(.asymmetric(insertion: .scale(scale: 0.95).combined(with: .opacity), removal: .opacity))
                        }
                        Button { showPicker = true } label: {
                            Label("Adicionar exercício", systemImage: "plus")
                                .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.accent)
                                .frame(maxWidth: .infinity).padding(.vertical, 14)
                                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(Theme.accent.opacity(0.5), style: StrokeStyle(lineWidth: 1.2, dash: [6, 5])))
                        }
                        .buttonStyle(PressableStyle())
                        Button("Cancelar treino", role: .destructive) { confirmCancel = true }
                            .font(.subheadline).padding(.top, 8)
                        Color.clear.frame(height: (restEnd == nil ? 20 : 120) + (undo == nil ? 0 : 60))
                    }
                    .padding()
                }
                .scrollDismissesKeyboard(.interactively)
                VStack(spacing: 8) {
                    if let u = undo { UndoBanner(text: u.label) { performUndo() }.transition(.move(edge: .bottom).combined(with: .opacity)) }
                    if restEnd != nil { restBar.transition(.move(edge: .bottom).combined(with: .opacity)) }
                }
            }
            .navigationTitle(session.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Button { newName = session.name; renaming = true } label: {
                        HStack(spacing: 4) {
                            Text(session.name).font(.headline).foregroundStyle(.primary)
                            Image(systemName: "pencil").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button { saveNow(); dismiss() } label: { Image(systemName: "chevron.down") }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Finalizar") { finish() }.bold().tint(Theme.good)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    if let f = focus {
                        let step: Double = f.kind == .kg ? 2.5 : (f.kind == .km ? 0.5 : 1)
                        Button { bump(f, -step) } label: { Text("−\(step.fmt(step < 1 || f.kind == .kg ? 1 : 0))").bold().frame(minWidth: 52, minHeight: 36) }
                            .buttonStyle(.bordered)
                        Button { bump(f, step) } label: { Text("+\(step.fmt(step < 1 || f.kind == .kg ? 1 : 0))").bold().frame(minWidth: 52, minHeight: 36) }
                            .buttonStyle(.bordered)
                        Button { copyPrevious(f) } label: { Image(systemName: "arrow.down.to.line").frame(minWidth: 44, minHeight: 36) }
                            .buttonStyle(.bordered)
                            .accessibilityLabel("Igual à série anterior")
                    }
                    Spacer()
                    Button("OK") { focus = nil }.bold()
                }
            }
            .sheet(isPresented: $showPicker) {
                ExercisePickerView(single: replacing != nil) { picked in
                    withAnimation(.spring) {
                        if let r = replacing, let i = exercises.firstIndex(where: { $0.id == r }), let first = picked.first {
                            exercises[i].exerciseID = first.id
                        } else {
                            exercises += picked.map { SessionExercise(exerciseID: $0.id, sets: [SetLog(), SetLog(), SetLog()]) }
                        }
                    }
                    replacing = nil
                }
            }
            .sheet(item: $detail) { ExerciseDetailView(exercise: $0) }
            .alert("Nome do treino", isPresented: $renaming) {
                TextField("Nome", text: $newName)
                Button("Salvar") { if !newName.trimmingCharacters(in: .whitespaces).isEmpty { session.name = newName; saveNow() } }
                Button("Cancelar", role: .cancel) {}
            }
            .sheet(item: $summary, onDismiss: { dismiss() }) { WorkoutSummaryView(session: $0) }
            .confirmationDialog("Descartar este treino?", isPresented: $confirmCancel, titleVisibility: .visible) {
                Button("Descartar", role: .destructive) {
                    UserDefaults.standard.removeObject(forKey: restKey)
                    LiveActivities.end(); context.delete(session); try? context.save(); dismiss()
                }
            }
            .onAppear {
                exercises = session.exercises
                // séries todas feitas começam recolhidas; o descanso continua de onde parou
                collapsed = Set(exercises.filter { !$0.sets.isEmpty && $0.sets.allSatisfy(\.done) }.map(\.id))
                if let saved = UserDefaults.standard.array(forKey: restKey) as? [Double], saved.count == 2 {
                    let end = Date(timeIntervalSince1970: saved[0])
                    if end > .now { restTotal = saved[1]; restEnd = end }
                }
                UIApplication.shared.isIdleTimerDisabled = true
                LiveActivities.startWorkout(session.name, start: session.start, subtitle: liveSubtitle)
            }
            .onDisappear { UIApplication.shared.isIdleTimerDisabled = false; if session.modelContext != nil { saveNow() } }
            .onChange(of: exercises) { _, _ in save() }
            .onChange(of: phase) { _, p in
                // indo para o fundo: confirma o campo em edição e grava tudo no disco
                if p != .active { focus = nil; if session.modelContext != nil { saveNow() } }
            }
            .onChange(of: undo) { _, u in
                guard u != nil else { return }
                Task { try? await Task.sleep(for: .seconds(5)); if undo == u { withAnimation { undo = nil } } }
            }
            .sensoryFeedback(.success, trigger: tick) { _, _ in ThemeStore.shared.haptics }
            .sensoryFeedback(.impact(weight: .heavy), trigger: prFlash) { _, new in new != nil && ThemeStore.shared.haptics }
        }
    }

    /// Cada mudança vai para o treino na hora e para o disco em menos de 1 s:
    /// fechar o app, bloquear o celular ou acabar a bateria não perde séries.
    private func save() {
        session.exercises = exercises
        diskSave?.cancel()
        diskSave = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            try? context.save()
        }
    }

    private func saveNow() {
        diskSave?.cancel()
        session.exercises = exercises
        try? context.save()
    }

    private var restKey: String { "workout.rest.\(session.start.timeIntervalSince1970)" }

    // MARK: Cabeçalho

    private var header: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            let done = exercises.flatMap(\.workSets)
            let total = exercises.map { $0.sets.filter { $0.kind != .warmup }.count }.reduce(0, +)
            VStack(spacing: 10) {
                Text(WorkoutMath.clockText(session.duration))
                    .font(.system(size: 52, weight: .semibold, design: .rounded)).monospacedDigit()
                    .contentTransition(.numericText())
                HStack(spacing: 18) {
                    miniStat("\(done.map(\.volume).reduce(0, +).fmt(0)) kg", "volume")
                    miniStat("\(done.count)\(total > 0 ? "/\(total)" : "")", "séries")
                    miniStat(WorkoutMath.kcal(session).fmt(0), "kcal")
                }
                if total > 0 {
                    ProgressBar(progress: Double(done.count) / Double(total), tint: Theme.good, height: 4)
                        .padding(.horizontal, 24)
                    if done.count >= total {
                        Text("Tudo feito! Toque em Finalizar 🎉").font(.caption).foregroundStyle(Theme.good)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    private func miniStat(_ v: String, _ label: String) -> some View {
        HStack(spacing: 4) {
            Text(v).font(.subheadline.weight(.semibold)).monospacedDigit().contentTransition(.numericText())
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }

    // MARK: Exercício

    private func exerciseCard(_ ex: Binding<SessionExercise>) -> some View {
        let e = ex.wrappedValue
        let x = e.exercise
        let isCardio = x?.kind == .cardio || x?.kind == .timed
        let prev = WorkoutMath.previous(e.exerciseID, before: session.start, in: past)
        let best = WorkoutMath.best(e.exerciseID, in: past)
        let doneCount = e.sets.filter(\.done).count
        let allDone = !e.sets.isEmpty && doneCount == e.sets.count
        let isCollapsed = collapsed.contains(e.id)
        let index = exercises.firstIndex { $0.id == e.id } ?? 0
        return Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    Button { detail = x } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(x?.name ?? e.exerciseID).font(.headline).foregroundStyle(allDone ? Theme.good : Theme.accent)
                            Text("\(x?.primary.map(\.label).joined(separator: ", ") ?? "") · \(doneCount)/\(e.sets.count) séries")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.tap)
                    Spacer()
                    Button {
                        withAnimation(.spring(duration: 0.3)) {
                            if isCollapsed { collapsed.remove(e.id) } else { collapsed.insert(e.id) }
                        }
                    } label: {
                        Image(systemName: isCollapsed ? "chevron.down.circle" : "chevron.up.circle").font(.title3).foregroundStyle(.secondary)
                    }
                    .buttonStyle(.tap)
                    Menu {
                        Section {
                            Button("Marcar todas como feitas", systemImage: "checkmark.circle") {
                                withAnimation { for i in ex.wrappedValue.sets.indices { ex.wrappedValue.sets[i].done = true } }
                                tick += 1
                            }
                            Button(noteOpen.contains(e.id) || !e.note.isEmpty ? "Editar nota" : "Adicionar nota", systemImage: "note.text") {
                                withAnimation { _ = noteOpen.insert(e.id) }
                            }
                            Menu("Descanso: \(e.restSeconds) s") {
                                ForEach([0, 30, 45, 60, 90, 120, 150, 180, 240, 300], id: \.self) { s in
                                    Button("\(s) s") { ex.wrappedValue.restSeconds = s }
                                }
                            }
                        }
                        Section {
                            if !isCardio, let x, let top = e.sets.filter({ $0.kind != .warmup }).map(\.kg).max(), top > 0,
                               !e.sets.contains(where: { $0.kind == .warmup }) {
                                Button("Adicionar aquecimento", systemImage: "thermometer.medium") {
                                    withAnimation { ex.wrappedValue.sets.insert(contentsOf: WorkoutCoach.warmups(topKg: top, exercise: x), at: 0) }
                                }
                            }
                            if e.sets.contains(where: { !$0.done }) {
                                Button("Apagar séries não feitas", systemImage: "minus.circle") {
                                    withAnimation { ex.wrappedValue.sets.removeAll { !$0.done } }
                                }
                            }
                        }
                        Section {
                            if index > 0 {
                                Button("Mover para cima", systemImage: "arrow.up") { move(e.id, by: -1) }
                            }
                            if index < exercises.count - 1 {
                                Button("Mover para baixo", systemImage: "arrow.down") { move(e.id, by: 1) }
                            }
                            Button("Duplicar exercício", systemImage: "plus.square.on.square") {
                                var c = e
                                c.id = UUID()
                                c.sets = c.sets.map { var s = $0; s.id = UUID(); s.done = false; return s }
                                withAnimation { exercises.insert(c, at: index + 1) }
                            }
                            if let x, !isCardio {
                                Button("Aparelho ocupado: trocar já", systemImage: "person.2.fill") { quickSwap(ex, from: x) }
                            }
                            Button("Substituir exercício", systemImage: "arrow.triangle.2.circlepath") {
                                replacing = e.id; showPicker = true
                            }
                        }
                        Button("Remover exercício", systemImage: "trash", role: .destructive) { removeExercise(e.id) }
                    } label: { Image(systemName: "ellipsis.circle").font(.title3) }
                }
                if !isCollapsed {
                    if noteOpen.contains(e.id) || !e.note.isEmpty {
                        TextField("Nota do exercício (ajuste do banco, pegada, sensação…)", text: ex.note, axis: .vertical)
                            .font(.caption).lineLimit(1...3).padding(8)
                            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
                    }
                    if !isCardio, let line = e.hint.map({ ("chart.line.uptrend.xyaxis", $0) })
                        ?? best.map({ ("trophy", "Recorde \($0.kg.fmt(1)) kg × \($0.reps) · 1RM \($0.e1RM.fmt(1)) kg") }) {
                        Label(line.1, systemImage: line.0).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
                    }
                    HStack {
                        Text("SÉRIE").frame(width: 40, alignment: .leading)
                        Text("ANTERIOR").frame(maxWidth: .infinity, alignment: .leading)
                        Text(isCardio ? "MIN" : "KG").frame(width: 64)
                        Text(isCardio ? "KM" : "REPS").frame(width: 56)
                        Color.clear.frame(width: 44, height: 1)
                    }
                    .font(.system(size: 10, weight: .semibold)).tracking(0.6).foregroundStyle(.tertiary)

                    ForEach(e.sets) { s in
                        let i = e.sets.firstIndex { $0.id == s.id } ?? 0
                        let b = Binding<SetLog>(
                            get: { ex.wrappedValue.sets.first { $0.id == s.id } ?? s },
                            set: { nv in
                                if let k = ex.wrappedValue.sets.firstIndex(where: { $0.id == s.id }) { ex.wrappedValue.sets[k] = nv }
                            })
                        setRow(i: i, set: b, prev: prev.indices.contains(i) ? prev[i] : nil, cardio: isCardio, exercise: e,
                               best: best?.e1RM ?? 0)
                            .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .opacity))
                    }
                    // Barra de ações das séries
                    HStack(spacing: 0) {
                        Button { addSet(ex) } label: {
                            Label("Série", systemImage: "plus").frame(maxWidth: .infinity, minHeight: 36)
                        }
                        .foregroundStyle(Theme.accent)
                        Divider().frame(height: 18)
                        Button { removeLastSet(ex) } label: {
                            Label("Série", systemImage: "minus").frame(maxWidth: .infinity, minHeight: 36)
                        }
                        .foregroundStyle(.secondary)
                        .disabled(e.sets.isEmpty)
                        if !isCardio {
                            Divider().frame(height: 18)
                            Button { addDrop(ex) } label: {
                                Label("Drop", systemImage: "arrow.down.right").frame(maxWidth: .infinity, minHeight: 36)
                            }
                            .foregroundStyle(.secondary)
                            .disabled(e.sets.isEmpty)
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.plain)
                    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                } else {
                    // Resumo do exercício recolhido
                    Text(e.sets.filter(\.done).map { isCardio ? "\($0.minutes.fmt(0))min" : "\($0.kg.fmt(1))×\($0.reps)" }.joined(separator: "  ·  "))
                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary).lineLimit(2)
                }
            }
        }
        .onChange(of: allDone) { _, done in
            // recolhe sozinho ao terminar todas as séries (deixa a tela focada no próximo exercício)
            if done { withAnimation(.spring(duration: 0.4).delay(0.6)) { _ = collapsed.insert(e.id) } }
        }
    }

    private func setRow(i: Int, set: Binding<SetLog>, prev: SetLog?, cardio: Bool, exercise: SessionExercise, best: Double) -> some View {
        let s = set.wrappedValue
        let isPR = s.done && !cardio && s.kind != .warmup && s.e1RM > best && best > 0
        let workIndex = exercise.sets.prefix(i + 1).filter { $0.kind != .warmup }.count
        return HStack {
            Menu {
                Section("Tipo de série") {
                    ForEach(SetKind.allCases, id: \.self) { k in
                        Button { set.wrappedValue.kind = k } label: {
                            if s.kind == k { Label(k.label, systemImage: "checkmark") } else { Text(k.label) }
                        }
                    }
                }
                if !cardio {
                    Menu(s.rpe.map { "Esforço (RPE): \($0.fmt(1))" } ?? "Esforço (RPE)") {
                        ForEach([6.0, 7, 7.5, 8, 8.5, 9, 9.5, 10], id: \.self) { r in
                            Button("RPE \(r.fmt(r.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 1)) · \(rpeLabel(r))") { set.wrappedValue.rpe = r }
                        }
                        if s.rpe != nil { Button("Limpar RPE", role: .destructive) { set.wrappedValue.rpe = nil } }
                    }
                }
                Section {
                    Button("Duplicar série", systemImage: "plus.square.on.square") { duplicateSet(s.id, in: exercise.id) }
                    Button("Inserir série acima", systemImage: "arrow.up.to.line") { insertSet(above: s.id, in: exercise.id) }
                    if let p = prev {
                        Button("Usar valores da última vez (\(cardio ? "\(p.minutes.fmt(0)) min" : "\(p.kg.fmt(1)) × \(p.reps)"))", systemImage: "clock.arrow.circlepath") {
                            set.wrappedValue.kg = p.kg; set.wrappedValue.reps = p.reps
                            set.wrappedValue.minutes = p.minutes; set.wrappedValue.km = p.km
                        }
                    }
                }
                Button("Apagar série", systemImage: "trash", role: .destructive) { deleteSet(s.id, in: exercise.id) }
            } label: {
                VStack(spacing: 0) {
                    Text(s.kind == .normal ? "\(workIndex)" : s.kind.short)
                        .font(.subheadline.bold())
                        .foregroundStyle(s.kind == .warmup ? Theme.warm : (s.kind == .normal ? .primary : Theme.excellent))
                    if let r = s.rpe { Text("@\(r.fmt(r.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 1))").font(.system(size: 9).bold()).foregroundStyle(.secondary) }
                }
                .frame(width: 40, height: 44, alignment: .leading).contentShape(Rectangle())
            }
            Button {
                // toque no "anterior" copia os valores da última vez
                guard let p = prev else { return }
                set.wrappedValue.kg = p.kg; set.wrappedValue.reps = p.reps
                set.wrappedValue.minutes = p.minutes; set.wrappedValue.km = p.km
            } label: {
                Group {
                    if let p = prev {
                        Text(cardio ? "\(p.minutes.fmt(0)) min" : "\(p.kg.fmt(1)) × \(p.reps)")
                    } else { Text("—") }
                }
                .font(.caption).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            if cardio {
                field(value: set.minutes, key: FieldKey(set: s.id, kind: .minutes))
                field(value: set.km, key: FieldKey(set: s.id, kind: .km), width: 56)
            } else {
                field(value: set.kg, key: FieldKey(set: s.id, kind: .kg))
                LiveIntField(value: set.reps)
                    .focused($focus, equals: FieldKey(set: s.id, kind: .reps))
                    .frame(width: 56, height: 40)
                    .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            Button {
                withAnimation(.spring(duration: 0.3, bounce: 0.4)) { set.wrappedValue.done.toggle() }
                if set.wrappedValue.done {
                    focus = nil
                    tick += 1
                    startRest(Double(exercise.restSeconds))
                    let now = set.wrappedValue
                    if !cardio && now.kind != .warmup && now.e1RM > best && best > 0 { prFlash = now.id }
                }
            } label: {
                Image(systemName: s.done ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(s.done ? Theme.good : .secondary)
                    .symbolEffect(.bounce, value: s.done)
                    .frame(width: 44, height: 44).contentShape(Rectangle())
            }
            .buttonStyle(.tap)
        }
        .padding(.vertical, 2)
        .background(s.done ? Theme.good.opacity(0.08) : .clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(alignment: .topTrailing) {
            if isPR {
                Text("🏆 PR").font(.caption2.bold()).padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Theme.excellent, in: Capsule()).foregroundStyle(.white)
                    .offset(x: 4, y: -10)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .contextMenu {
            Button("Duplicar série", systemImage: "plus.square.on.square") { duplicateSet(s.id, in: exercise.id) }
            Button("Inserir série acima", systemImage: "arrow.up.to.line") { insertSet(above: s.id, in: exercise.id) }
            Button("Apagar série", systemImage: "trash", role: .destructive) { deleteSet(s.id, in: exercise.id) }
        }
    }

    private func rpeLabel(_ r: Double) -> String {
        switch r {
        case ..<7: "4+ reps sobrando"
        case ..<8: "3 reps sobrando"
        case ..<9: "2 reps sobrando"
        case ..<10: "1 rep sobrando"
        default: "até a falha"
        }
    }

    // MARK: Ações de séries e exercícios

    private func addSet(_ ex: Binding<SessionExercise>) {
        withAnimation(.spring(duration: 0.3)) {
            var s = ex.wrappedValue.sets.last(where: { $0.kind != .warmup }) ?? ex.wrappedValue.sets.last ?? SetLog()
            s.id = UUID(); s.done = false; s.kind = .normal; s.rpe = nil
            ex.wrappedValue.sets.append(s)
            collapsed.remove(ex.wrappedValue.id)
        }
    }

    /// Remove a última série ainda não feita (ou a última, se todas estiverem feitas), com opção de desfazer.
    private func removeLastSet(_ ex: Binding<SessionExercise>) {
        let sets = ex.wrappedValue.sets
        guard let target = sets.last(where: { !$0.done }) ?? sets.last else { return }
        deleteSet(target.id, in: ex.wrappedValue.id)
    }

    /// Drop-set: nova série com ~20% menos carga, logo após a última.
    private func addDrop(_ ex: Binding<SessionExercise>) {
        guard let last = ex.wrappedValue.sets.last else { return }
        let step = max(WorkoutCoach.increment(ex.wrappedValue.exercise), 1)
        withAnimation(.spring(duration: 0.3)) {
            var s = last
            s.id = UUID(); s.done = false; s.kind = .drop; s.rpe = nil
            s.kg = WorkoutCoach.round(last.kg * 0.8, step: step)
            ex.wrappedValue.sets.append(s)
        }
    }

    private func duplicateSet(_ id: UUID, in exID: UUID) {
        guard let ei = exercises.firstIndex(where: { $0.id == exID }),
              let si = exercises[ei].sets.firstIndex(where: { $0.id == id }) else { return }
        var s = exercises[ei].sets[si]
        s.id = UUID(); s.done = false
        withAnimation(.spring(duration: 0.3)) { exercises[ei].sets.insert(s, at: si + 1) }
    }

    private func insertSet(above id: UUID, in exID: UUID) {
        guard let ei = exercises.firstIndex(where: { $0.id == exID }),
              let si = exercises[ei].sets.firstIndex(where: { $0.id == id }) else { return }
        var s = exercises[ei].sets[si]
        s.id = UUID(); s.done = false; s.rpe = nil
        withAnimation(.spring(duration: 0.3)) { exercises[ei].sets.insert(s, at: si) }
    }

    private func deleteSet(_ id: UUID, in exID: UUID) {
        guard let ei = exercises.firstIndex(where: { $0.id == exID }),
              let si = exercises[ei].sets.firstIndex(where: { $0.id == id }) else { return }
        let removed = exercises[ei].sets[si]
        withAnimation(.spring(duration: 0.3)) {
            exercises[ei].sets.remove(at: si)
            undo = .set(exercise: exID, index: si, set: removed)
        }
    }

    private func removeExercise(_ id: UUID) {
        guard let i = exercises.firstIndex(where: { $0.id == id }) else { return }
        let removed = exercises[i]
        withAnimation(.spring(duration: 0.3)) {
            exercises.remove(at: i)
            undo = .exercise(index: i, exercise: removed)
        }
    }

    private func performUndo() {
        guard let u = undo else { return }
        withAnimation(.spring(duration: 0.3)) {
            switch u {
            case .set(let exID, let index, let s):
                if let ei = exercises.firstIndex(where: { $0.id == exID }) {
                    exercises[ei].sets.insert(s, at: min(index, exercises[ei].sets.count))
                    collapsed.remove(exID)
                }
            case .exercise(let index, let e):
                exercises.insert(e, at: min(index, exercises.count))
            }
            undo = nil
        }
    }

    private func move(_ id: UUID, by delta: Int) {
        guard let i = exercises.firstIndex(where: { $0.id == id }) else { return }
        let j = i + delta
        guard exercises.indices.contains(j) else { return }
        withAnimation(.spring(duration: 0.35)) { exercises.swapAt(i, j) }
    }

    /// Atalho do teclado: soma/subtrai no campo em foco (kg ±2,5 · reps ±1 · min ±1 · km ±0,5).
    private func bump(_ f: FieldKey, _ d: Double) {
        guard let loc = locate(f.set) else { return }
        let (ei, si) = loc
        var x = exercises[ei].sets[si]
        switch f.kind {
        case .kg: x.kg = max(0, x.kg + d)
        case .reps: x.reps = max(0, x.reps + Int(d))
        case .minutes: x.minutes = max(0, x.minutes + d)
        case .km: x.km = max(0, x.km + d)
        }
        exercises[ei].sets[si] = x
    }

    /// Copia o valor da série anterior do mesmo exercício.
    private func copyPrevious(_ f: FieldKey) {
        guard let loc = locate(f.set), loc.1 > 0 else { return }
        let (ei, si) = loc
        let p = exercises[ei].sets[si - 1]
        switch f.kind {
        case .kg: exercises[ei].sets[si].kg = p.kg
        case .reps: exercises[ei].sets[si].reps = p.reps
        case .minutes: exercises[ei].sets[si].minutes = p.minutes
        case .km: exercises[ei].sets[si].km = p.km
        }
    }

    private func locate(_ id: UUID) -> (Int, Int)? {
        for (ei, e) in exercises.enumerated() {
            if let si = e.sets.firstIndex(where: { $0.id == id }) { return (ei, si) }
        }
        return nil
    }

    private func field(value: Binding<Double>, key: FieldKey, width: CGFloat = 64) -> some View {
        LiveNumberField(value: value)
            .focused($focus, equals: key)
            .frame(width: width, height: 40)
            .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: Academia lotada

    /// Troca na hora por um equivalente de outro equipamento (favoritos primeiro), mantendo as séries feitas.
    private func quickSwap(_ ex: Binding<SessionExercise>, from x: Exercise) {
        let used = Set(exercises.map(\.exerciseID))
        let fav = WorkoutPrefs.shared.favorites
        let opts = ExerciseAlternatives.options(for: x.id).filter { !used.contains($0.id) }
        let other = opts.filter { $0.equipment != x.equipment }
        let pool = (other.isEmpty ? opts : other)
            .sorted { (fav.contains($0.id) ? 1 : 0, $0.score(style: .best, equip: .mixed)) > (fav.contains($1.id) ? 1 : 0, $1.score(style: .best, equip: .mixed)) }
        guard let pick = pool.prefix(3).randomElement() else { return }
        let prevKg = WorkoutMath.previous(pick.id, before: session.start, in: past).filter { $0.kind != .warmup }.map(\.kg).max() ?? 0
        withAnimation(.spring) {
            ex.wrappedValue.exerciseID = pick.id
            for i in ex.wrappedValue.sets.indices where !ex.wrappedValue.sets[i].done {
                ex.wrappedValue.sets[i].kg = prevKg
                if ex.wrappedValue.sets[i].kind == .warmup { ex.wrappedValue.sets[i].kg = (prevKg * 0.5).rounded() }
            }
            ex.wrappedValue.hint = "Trocado de \(x.name) (aparelho ocupado)"
        }
        tick += 1
    }

    // MARK: Descanso

    private func startRest(_ seconds: Double) {
        guard seconds > 0 else { return }
        restTotal = seconds
        withAnimation(.spring) { restEnd = Date.now.addingTimeInterval(seconds) }
        if let e = restEnd { UserDefaults.standard.set([e.timeIntervalSince1970, seconds], forKey: restKey) }
        LiveActivities.update(subtitle: liveSubtitle, restEnd: restEnd)
        let c = UNUserNotificationCenter.current()
        c.removePendingNotificationRequests(withIdentifiers: ["rest"])
        c.requestAuthorization(options: [.alert, .sound]) { ok, _ in
            guard ok else { return }
            let content = UNMutableNotificationContent()
            content.title = "Descanso terminado 💪"
            content.body = "Hora da próxima série."
            content.sound = .default
            c.add(UNNotificationRequest(identifier: "rest", content: content,
                                        trigger: UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)))
        }
    }

    private func stopRest() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["rest"])
        withAnimation(.spring) { restEnd = nil }
        UserDefaults.standard.removeObject(forKey: restKey)
        LiveActivities.update(subtitle: liveSubtitle, restEnd: nil)
    }

    private var liveSubtitle: String {
        let done = exercises.map { $0.sets.filter(\.done).count }.reduce(0, +)
        let total = exercises.map(\.sets.count).reduce(0, +)
        return "\(done)/\(total) séries"
    }

    private var restBar: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { ctx in
            let left = max(0, (restEnd ?? ctx.date).timeIntervalSince(ctx.date))
            HStack(spacing: 14) {
                ZStack {
                    Circle().stroke(.quaternary, lineWidth: 5)
                    Circle().trim(from: 0, to: left / max(restTotal, 1))
                        .stroke(Theme.gradient, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.25), value: left)
                    Image(systemName: "timer").font(.caption)
                }
                .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 0) {
                    Text("Descanso").font(.caption).foregroundStyle(.secondary)
                    Text(String(format: "%d:%02d", Int(left) / 60, Int(left) % 60))
                        .font(.title2.bold().monospacedDigit())
                }
                Spacer()
                Button("−15") { adjustRest(-15) }.buttonStyle(.bordered)
                Button("+15") { adjustRest(15) }.buttonStyle(.bordered)
                Button { stopRest() } label: { Image(systemName: "forward.end.fill") }.buttonStyle(.borderedProminent)
            }
            .padding()
            .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 22))
            .padding()
            .onChange(of: left <= 0) { _, ended in if ended { tick += 1; stopRest() } }
        }
    }

    private func adjustRest(_ d: Double) {
        guard let e = restEnd else { return }
        let n = e.addingTimeInterval(d)
        if n <= .now { stopRest(); return }
        let total = max(restTotal + d, 1)
        startRest(n.timeIntervalSinceNow)
        restTotal = total
    }

    // MARK: Finalizar

    private func finish() {
        // remove séries não marcadas e exercícios vazios
        var cleaned = exercises
        for i in cleaned.indices { cleaned[i].sets.removeAll { !$0.done } }
        cleaned.removeAll { $0.sets.isEmpty }
        exercises = cleaned
        session.exercises = cleaned
        session.end = .now
        try? context.save()
        let sets = cleaned.map(\.sets.count).reduce(0, +)
        let mins = session.duration / 60
        if sets > 0 {
            PartyService.shared.post(.workout, "concluiu \(session.name): \(Int(mins)) min, \(cleaned.count) exercícios, \(sets) séries 💪", value: mins)
        }
        stopRest()
        summary = session
        HealthSync.shared.saveStrength(session)
        LiveActivities.end()
        AchievementEngine.check(context)
    }
}

// MARK: - Resumo

struct WorkoutSummaryView: View {
    @Bindable var session: WorkoutSession
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \WorkoutSession.start, order: .reverse) private var history: [WorkoutSession]
    @State private var appeared = false
    @State private var showShare = false

    var body: some View {
        let past = history.filter { $0.persistentModelID != session.persistentModelID && $0.start < session.start }
        let prs: [(Exercise, SetLog)] = session.exercises.compactMap { e in
            guard let x = e.exercise, x.kind == .strength || x.kind == .bodyweight,
                  let top = e.workSets.max(by: { $0.e1RM < $1.e1RM }) else { return nil }
            let best = WorkoutMath.best(e.exerciseID, in: past)?.e1RM ?? 0
            return top.e1RM > best ? (x, top) : nil
        }
        let muscles = WorkoutMath.muscleSets([session]).sorted { $0.value > $1.value }
        NavigationStack {
            ZStack {
                AnimatedBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        VStack(spacing: 8) {
                            Image(systemName: "trophy.fill").font(.system(size: 64)).foregroundStyle(Theme.gradient)
                                .scaleEffect(appeared ? 1 : 0.3).rotationEffect(.degrees(appeared ? 0 : -30))
                            Text("Treino concluído!").font(.largeTitle.bold())
                            Text(session.name).foregroundStyle(.secondary)
                        }
                        .padding(.top)
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                            MetricTile(title: "Duração", value: WorkoutMath.durationText(session.duration), icon: "timer", tint: Theme.accent)
                            MetricTile(title: "Volume", value: WorkoutMath.volume(session).fmt(0), unit: "kg", icon: "scalemass.fill", tint: Theme.accent2)
                            MetricTile(title: "Séries", value: "\(WorkoutMath.setsCount(session))", icon: "checkmark.circle.fill", tint: Theme.good)
                            MetricTile(title: "Calorias", value: WorkoutMath.kcal(session).fmt(0), unit: "kcal", icon: "flame.fill", tint: Theme.warm)
                        }
                        .appear(0.1)
                        compareCard(past).appear(0.15)
                        if !prs.isEmpty {
                            Card {
                                VStack(alignment: .leading, spacing: 8) {
                                    Label("Novos recordes (\(prs.count))", systemImage: "star.fill").font(.headline).foregroundStyle(Theme.excellent)
                                    ForEach(prs, id: \.0.id) { x, s in
                                        HStack {
                                            Text(x.name).font(.subheadline)
                                            Spacer()
                                            Text("\(s.kg.fmt(1)) kg × \(s.reps) · 1RM \(s.e1RM.fmt(1))").font(.caption.monospacedDigit())
                                        }
                                    }
                                }
                            }
                            .appear(0.2)
                        }
                        Card {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Músculos trabalhados").font(.headline)
                                ForEach(muscles, id: \.key) { m, n in
                                    HStack {
                                        Text(m.label).font(.subheadline)
                                        Spacer()
                                        Text("\(n.fmt(1)) séries").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                                    }
                                    ProgressBar(progress: n / max(muscles.first?.value ?? 1, 1), tint: Theme.accent, height: 4)
                                }
                            }
                        }
                        .appear(0.3)
                        Card {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Como você se sentiu?").font(.headline)
                                HStack {
                                    ForEach(1...5, id: \.self) { i in
                                        Button { withAnimation(.spring) { session.rating = i } } label: {
                                            Text(["😫", "😕", "🙂", "😃", "🔥"][i - 1]).font(.largeTitle)
                                                .scaleEffect(session.rating == i ? 1.3 : 1)
                                                .opacity(session.rating == 0 || session.rating == i ? 1 : 0.4)
                                        }
                                        .buttonStyle(.tap).frame(maxWidth: .infinity)
                                    }
                                }
                                TextField("Anotações do treino", text: $session.note, axis: .vertical)
                                    .lineLimit(2...4).padding(10)
                                    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
                            }
                        }
                        .appear(0.4)
                    }
                    .padding()
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showShare = true } label: { Label("Compartilhar", systemImage: "square.and.arrow.up") }
                }
                ToolbarItem(placement: .confirmationAction) { Button("Concluir") { dismiss() }.bold() }
            }
            .sheet(isPresented: $showShare) {
                ShareImageSheet(title: "Treino") { WorkoutShareCard(session: session, prs: prs.count) }
            }
            .onAppear { withAnimation(.spring(duration: 0.8, bounce: 0.5)) { appeared = true } }
            .sensoryFeedback(.success, trigger: appeared) { _, _ in ThemeStore.shared.haptics }
        }
    }

    /// Compara com a última vez que fez a mesma rotina.
    @ViewBuilder private func compareCard(_ past: [WorkoutSession]) -> some View {
        if let prev = past.filter({ $0.name == session.name && !$0.isActive }).max(by: { $0.start < $1.start }) {
            let v1 = WorkoutMath.volume(session), v0 = WorkoutMath.volume(prev)
            let s1 = WorkoutMath.setsCount(session), s0 = WorkoutMath.setsCount(prev)
            let pct = v0 > 0 ? (v1 - v0) / v0 * 100 : 0
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Comparado com a última vez", systemImage: "arrow.left.arrow.right").font(.headline)
                    HStack {
                        delta("Volume", pct, "%")
                        Spacer()
                        delta("Séries", Double(s1 - s0), "")
                        Spacer()
                        delta("Duração", (session.duration - prev.duration) / 60, " min", invert: true)
                    }
                    Text(pct >= 5 ? "Você levantou \(Int(pct))% mais que da última vez. Evolução real! 🚀"
                         : (pct > -5 ? "Mesmo nível da última sessão. Manter também é vitória — tente +1 rep na próxima."
                                     : "Um pouco abaixo da última vez. Dias assim acontecem: sono, comida e estresse influenciam."))
                        .font(.callout)
                }
            }
        }
    }

    private func delta(_ t: String, _ v: Double, _ unit: String, invert: Bool = false) -> some View {
        let good = invert ? v <= 0 : v >= 0
        return VStack(spacing: 2) {
            Text("\(v.signed(0))\(unit)").font(.headline.monospacedDigit()).foregroundStyle(good ? Theme.good : Theme.warm)
            Text(t).font(.caption2).foregroundStyle(.secondary)
        }
    }
}
