import SwiftUI
import SwiftData
import UserNotifications

enum WorkoutStarter {
    /// Cria uma sessão a partir de uma rotina, já preenchendo cargas e reps da última vez.
    static func session(from routine: WorkoutRoutine?, history: [WorkoutSession], bodyKg: Double) -> WorkoutSession {
        let exercises: [SessionExercise] = (routine?.items ?? []).map { item in
            let prev = WorkoutMath.previous(item.exerciseID, before: .now, in: history).filter { $0.kind != .warmup }
            let kind = item.exercise?.kind ?? .strength
            let sets = (0..<item.sets).map { i -> SetLog in
                var s = SetLog()
                if kind == .cardio || kind == .timed {
                    s.minutes = prev.indices.contains(i) ? prev[i].minutes : Double(item.repsMin)
                } else {
                    let p = prev.indices.contains(i) ? prev[i] : prev.last
                    s.kg = p?.kg ?? 0
                    s.reps = p?.reps ?? item.repsMax
                }
                return s
            }
            return SessionExercise(exerciseID: item.exerciseID, sets: sets, restSeconds: item.restSeconds)
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
    @FocusState private var focused: Bool

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
                            Label("Adicionar exercício", systemImage: "plus.circle.fill")
                                .font(.headline).frame(maxWidth: .infinity).padding()
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
                        }
                        .buttonStyle(PressableStyle())
                        Button("Cancelar treino", role: .destructive) { confirmCancel = true }
                            .font(.subheadline).padding(.top, 8)
                        Color.clear.frame(height: restEnd == nil ? 20 : 120)
                    }
                    .padding()
                }
                .scrollDismissesKeyboard(.interactively)
                if restEnd != nil { restBar.transition(.move(edge: .bottom).combined(with: .opacity)) }
            }
            .navigationTitle(session.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { save(); dismiss() } label: { Image(systemName: "chevron.down") }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Finalizar") { finish() }.bold().tint(Theme.good)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("OK") { focused = false }
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
            .sheet(item: $summary, onDismiss: { dismiss() }) { WorkoutSummaryView(session: $0) }
            .confirmationDialog("Descartar este treino?", isPresented: $confirmCancel, titleVisibility: .visible) {
                Button("Descartar", role: .destructive) { context.delete(session); dismiss() }
            }
            .onAppear {
                exercises = session.exercises
                UIApplication.shared.isIdleTimerDisabled = true
            }
            .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
            .onChange(of: exercises) { _, _ in save() }
            .sensoryFeedback(.success, trigger: tick) { _, _ in ThemeStore.shared.haptics }
            .sensoryFeedback(.impact(weight: .heavy), trigger: prFlash) { _, new in new != nil && ThemeStore.shared.haptics }
        }
    }

    private func save() { session.exercises = exercises }

    // MARK: Cabeçalho

    private var header: some View {
        Card {
            TimelineView(.periodic(from: .now, by: 1)) { _ in
                let done = exercises.flatMap(\.workSets)
                HStack {
                    stat("Duração", WorkoutMath.durationText(session.duration), "timer")
                    Spacer()
                    stat("Volume", "\(done.map(\.volume).reduce(0, +).fmt(0)) kg", "scalemass.fill")
                    Spacer()
                    stat("Séries", "\(done.count)", "checkmark.circle.fill")
                    Spacer()
                    stat("kcal", WorkoutMath.kcal(session).fmt(0), "flame.fill")
                }
            }
        }
    }

    private func stat(_ t: String, _ v: String, _ icon: String) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon).foregroundStyle(Theme.accent).font(.caption)
            Text(v).font(.subheadline.bold().monospacedDigit()).contentTransition(.numericText())
            Text(t).font(.caption2).foregroundStyle(.secondary)
        }
    }

    // MARK: Exercício

    private func exerciseCard(_ ex: Binding<SessionExercise>) -> some View {
        let e = ex.wrappedValue
        let x = e.exercise
        let isCardio = x?.kind == .cardio || x?.kind == .timed
        let prev = WorkoutMath.previous(e.exerciseID, before: session.start, in: past)
        let best = WorkoutMath.best(e.exerciseID, in: past)
        return Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Button { detail = x } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(x?.name ?? e.exerciseID).font(.headline).foregroundStyle(Theme.accent)
                            Text(x?.primary.map(\.label).joined(separator: ", ") ?? "")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Menu {
                        Menu("Descanso: \(e.restSeconds) s") {
                            ForEach([0, 30, 45, 60, 90, 120, 150, 180, 240, 300], id: \.self) { s in
                                Button("\(s) s") { ex.wrappedValue.restSeconds = s }
                            }
                        }
                        Button("Substituir exercício", systemImage: "arrow.triangle.2.circlepath") {
                            replacing = e.id; showPicker = true
                        }
                        Button("Remover", systemImage: "trash", role: .destructive) {
                            withAnimation { exercises.removeAll { $0.id == e.id } }
                        }
                    } label: { Image(systemName: "ellipsis.circle").font(.title3) }
                }
                if let x, !isCardio, let top = e.doneSets.map(\.kg).max(),
                   x.load.factor != 1 || x.load.bodyFraction > 0 || x.load.perSide {
                    Text("≈ \(x.load.real(kg: top, bodyKg: session.bodyKg).fmt(1)) kg reais movidos na série mais pesada")
                        .font(.caption2).foregroundStyle(Theme.accent2)
                }
                if let best, !isCardio {
                    Text("Recorde: \(best.kg.fmt(1)) kg × \(best.reps) · 1RM estimado \(best.e1RM.fmt(1)) kg")
                        .font(.caption2).foregroundStyle(Theme.excellent)
                }
                HStack {
                    Text("Série").frame(width: 40, alignment: .leading)
                    Text("Anterior").frame(maxWidth: .infinity, alignment: .leading)
                    Text(isCardio ? "min" : "kg").frame(width: 64)
                    Text(isCardio ? "km" : "reps").frame(width: 52)
                    Image(systemName: "checkmark").frame(width: 36)
                }
                .font(.caption2.bold()).foregroundStyle(.secondary)

                ForEach(e.sets) { s in
                    let i = e.sets.firstIndex { $0.id == s.id } ?? 0
                    let b = Binding<SetLog>(
                        get: { ex.wrappedValue.sets.first { $0.id == s.id } ?? s },
                        set: { nv in
                            if let k = ex.wrappedValue.sets.firstIndex(where: { $0.id == s.id }) { ex.wrappedValue.sets[k] = nv }
                        })
                    setRow(i: i, set: b, prev: prev.indices.contains(i) ? prev[i] : nil, cardio: isCardio, exercise: e,
                           best: best?.e1RM ?? 0)
                }
                Button {
                    withAnimation(.spring(duration: 0.3)) {
                        var s = ex.wrappedValue.sets.last ?? SetLog()
                        s.id = UUID(); s.done = false; s.kind = .normal
                        ex.wrappedValue.sets.append(s)
                    }
                } label: {
                    Label("Adicionar série", systemImage: "plus").font(.subheadline.bold()).frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered).tint(Theme.accent)
            }
        }
    }

    private func setRow(i: Int, set: Binding<SetLog>, prev: SetLog?, cardio: Bool, exercise: SessionExercise, best: Double) -> some View {
        let s = set.wrappedValue
        let isPR = s.done && !cardio && s.kind != .warmup && s.e1RM > best && best > 0
        return HStack {
            Menu {
                ForEach(SetKind.allCases, id: \.self) { k in
                    Button(k.label) { set.wrappedValue.kind = k }
                }
                Button("Apagar série", role: .destructive) {
                    if let ei = exercises.firstIndex(where: { $0.id == exercise.id }) {
                        withAnimation { exercises[ei].sets.removeAll { $0.id == s.id } }
                    }
                }
            } label: {
                Text(s.kind == .normal ? "\(i + 1)" : s.kind.short)
                    .font(.subheadline.bold())
                    .foregroundStyle(s.kind == .warmup ? Theme.warm : (s.kind == .normal ? .primary : Theme.excellent))
                    .frame(width: 40, alignment: .leading)
            }
            Group {
                if let p = prev {
                    Text(cardio ? "\(p.minutes.fmt(0)) min" : "\(p.kg.fmt(1)) × \(p.reps)")
                } else { Text("—") }
            }
            .font(.caption).foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            if cardio {
                field(value: set.minutes)
                field(value: set.km, width: 52)
            } else {
                field(value: set.kg)
                TextField("0", value: set.reps, format: .number)
                    .keyboardType(.numberPad).multilineTextAlignment(.center)
                    .focused($focused)
                    .frame(width: 52, height: 34)
                    .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
            }
            Button {
                withAnimation(.spring(duration: 0.3, bounce: 0.4)) { set.wrappedValue.done.toggle() }
                if set.wrappedValue.done {
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
                    .frame(width: 36)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 3)
        .background(s.done ? Theme.good.opacity(0.10) : .clear, in: RoundedRectangle(cornerRadius: 8))
        .overlay(alignment: .topTrailing) {
            if isPR {
                Text("🏆 PR").font(.caption2.bold()).padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Theme.excellent, in: Capsule()).foregroundStyle(.white)
                    .offset(x: 4, y: -10)
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }

    private func field(value: Binding<Double>, width: CGFloat = 64) -> some View {
        TextField("0", value: value, format: .number.precision(.fractionLength(0...2)))
            .keyboardType(.decimalPad).multilineTextAlignment(.center)
            .focused($focused)
            .frame(width: width, height: 34)
            .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: Descanso

    private func startRest(_ seconds: Double) {
        guard seconds > 0 else { return }
        restTotal = seconds
        withAnimation(.spring) { restEnd = Date.now.addingTimeInterval(seconds) }
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
        let sets = cleaned.map(\.sets.count).reduce(0, +)
        let mins = session.duration / 60
        if sets > 0 {
            PartyService.shared.post(.workout, "concluiu \(session.name): \(Int(mins)) min, \(cleaned.count) exercícios, \(sets) séries 💪", value: mins)
        }
        stopRest()
        summary = session
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
                                        .buttonStyle(.plain).frame(maxWidth: .infinity)
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
