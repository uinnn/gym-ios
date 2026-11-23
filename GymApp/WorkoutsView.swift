import SwiftUI
import SwiftData
import Charts

struct WorkoutsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \WorkoutRoutine.order) private var routines: [WorkoutRoutine]
    @Query(sort: \WorkoutSession.start, order: .reverse) private var sessions: [WorkoutSession]
    @Query(sort: \WeightEntry.date, order: .reverse) private var weights: [WeightEntry]
    @State private var active: WorkoutSession?
    @State private var editing: WorkoutRoutine?
    @State private var showGenerator = false
    @State private var showStats = false
    @State private var detail: WorkoutSession?
    @State private var viewing: WorkoutRoutine?
    @State private var cardioLive = false

    private var finished: [WorkoutSession] { sessions.filter { !$0.isActive } }
    private var running: WorkoutSession? { sessions.first { $0.isActive } }
    private var bodyKg: Double { weights.first?.kg ?? 70 }

    /// Rotina de hoje (se ainda não feita) ou a próxima da semana; sem dias, segue a sequência.
    private var nextRoutine: WorkoutRoutine? {
        guard !routines.isEmpty else { return nil }
        let scheduled = routines.filter { $0.weekday != 0 }
        if !scheduled.isEmpty {
            let today = Weekday.today
            let doneToday = finished.contains { Calendar.current.isDateInToday($0.start) }
            for offset in (doneToday ? 1 : 0)..<8 {
                let d = (today - 1 + offset) % 7 + 1
                if let r = scheduled.first(where: { $0.weekday == d }) { return r }
            }
        }
        guard let last = finished.first, let i = routines.firstIndex(where: { $0.name == last.name }) else { return routines.first }
        return routines[(i + 1) % routines.count]
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        if let r = running { resumeBanner(r).appear() }
                        weekCard.appear(0.05)
                        if let next = nextRoutine, running == nil { nextCard(next).appear(0.1) }
                        quickStart.appear(0.12)
                        CardioCard().appear(0.14)
                        PeriodizationCard(sessions: finished).appear(0.16)
                        routinesSection
                        if !finished.isEmpty { historySection }
                    }
                    .padding()
                }
            }
            .navigationTitle("Treinos")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showStats = true } label: { Image(systemName: "chart.bar.xaxis") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Gerar programa", systemImage: "wand.and.stars") { showGenerator = true }
                        Button("Nova rotina", systemImage: "plus") { newRoutine() }
                    } label: { Image(systemName: "plus.circle.fill") }
                }
            }
            .fullScreenCover(item: $active) { ActiveWorkoutView(session: $0) }
            .sheet(item: $editing) { RoutineEditorView(routine: $0) }
            .sheet(item: $viewing) { r in RoutineDetailView(routine: r) { start(r) } }
            .sheet(isPresented: $showGenerator) { ProgramGeneratorSheet() }
            .sheet(isPresented: $showStats) { WorkoutStatsView() }
            .sheet(item: $detail) { s in SessionDetailView(session: s) { start(copyOf: $0) } }
            .fullScreenCover(isPresented: $cardioLive) { CardioLiveView() }
            .onChange(of: AppRouter.shared.openCardio, initial: true) { _, v in
                if v { AppRouter.shared.openCardio = false; cardioLive = true }
            }
            .onChange(of: AppRouter.shared.openWorkout, initial: true) { _, v in
                guard v else { return }
                AppRouter.shared.openWorkout = false
                if let r = running { active = r } else if let n = nextRoutine { start(n) }
            }
        }
    }

    // MARK: Ações

    private func start(_ routine: WorkoutRoutine?) {
        if let r = running { active = r; return }
        let s = WorkoutStarter.session(from: routine, history: finished, bodyKg: bodyKg)
        context.insert(s)
        active = s
    }

    private func start(copyOf old: WorkoutSession) {
        guard running == nil else { active = running; return }
        let ex = old.exercises.map { e -> SessionExercise in
            var c = e
            c.id = UUID()
            c.sets = e.sets.map { var s = $0; s.id = UUID(); s.done = false; return s }
            return c
        }
        let s = WorkoutSession(name: old.name, exercises: ex, bodyKg: bodyKg)
        context.insert(s)
        detail = nil
        active = s
    }

    private func newRoutine() {
        let r = WorkoutRoutine(name: "Nova rotina", order: routines.count, items: [])
        context.insert(r)
        editing = r
    }

    // MARK: Cartões

    private func resumeBanner(_ s: WorkoutSession) -> some View {
        Button { active = s } label: {
            HStack {
                Image(systemName: "figure.strengthtraining.traditional").font(.title2)
                    .symbolEffect(.pulse)
                VStack(alignment: .leading) {
                    Text("Treino em andamento").font(.headline)
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        Text("\(s.name) · \(WorkoutMath.durationText(s.duration))").font(.caption)
                    }
                }
                Spacer()
                Text("Continuar").font(.subheadline.bold())
            }
            .foregroundStyle(.white).padding()
            .background(Theme.gradient, in: RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(PressableStyle())
    }

    private var weekCard: some View {
        let cal = Calendar.current
        let weekStart = cal.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        let week = finished.filter { $0.start >= weekStart }
        let goal = max(routines.count, 3)
        let days = (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: weekStart) }
        return Card {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Esta semana").font(.caption).foregroundStyle(.secondary)
                        Text("\(week.count) de \(goal) treinos").font(.title3.bold())
                    }
                    Spacer()
                    ZStack {
                        ProgressRing(progress: Double(week.count) / Double(goal), lineWidth: 7)
                        Text("\(Int(min(Double(week.count) / Double(goal), 1) * 100))%").font(.caption.bold())
                    }
                    .frame(width: 56, height: 56)
                }
                HStack {
                    ForEach(days, id: \.self) { d in
                        let did = week.contains { cal.isSameDay($0.start, d) }
                        VStack(spacing: 4) {
                            Text(d, format: .dateTime.weekday(.narrow)).font(.caption2).foregroundStyle(.secondary)
                            Circle().fill(did ? AnyShapeStyle(Theme.gradient) : AnyShapeStyle(.quaternary))
                                .frame(width: 28, height: 28)
                                .overlay { if did { Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.white) } }
                                .overlay { if cal.isDateInToday(d) && !did { Circle().strokeBorder(Theme.accent, lineWidth: 2) } }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                HStack {
                    mini("Volume", "\(week.map(WorkoutMath.volume).reduce(0, +).fmt(0)) kg")
                    Spacer()
                    mini("Tempo", WorkoutMath.durationText(week.map(\.duration).reduce(0, +)))
                    Spacer()
                    mini("Calorias", "\(week.map(WorkoutMath.kcal).reduce(0, +).fmt(0)) kcal")
                    Spacer()
                    mini("Séries", "\(week.map(WorkoutMath.setsCount).reduce(0, +))")
                }
                motivation(week: week, weekStart: weekStart)
            }
        }
    }

    /// Comparação com a semana passada até o mesmo dia, para motivar.
    @ViewBuilder private func motivation(week: [WorkoutSession], weekStart: Date) -> some View {
        let elapsed = Date.now.timeIntervalSince(weekStart)
        let lastStart = weekStart.addingTimeInterval(-7 * 86400)
        let last = finished.filter { $0.start >= lastStart && $0.start < lastStart.addingTimeInterval(elapsed) }
        let v1 = week.map(WorkoutMath.volume).reduce(0, +), v0 = last.map(WorkoutMath.volume).reduce(0, +)
        let s1 = week.map(WorkoutMath.setsCount).reduce(0, +), s0 = last.map(WorkoutMath.setsCount).reduce(0, +)
        let msg: (String, String, Color) = {
            if week.isEmpty && last.isEmpty { return ("figure.walk", "Comece hoje: o melhor treino é o que você faz.", Theme.accent) }
            if v0 > 0 {
                let p = (v1 - v0) / v0 * 100
                if p >= 5 { return ("arrow.up.right.circle.fill", "Você está \(Int(p))% acima da semana passada no volume. Continue assim! 🔥", Theme.good) }
                if p > -5 { return ("equal.circle.fill", "No mesmo ritmo da semana passada (\(s1) vs \(s0) séries). Constância é tudo.", Theme.accent2) }
                return ("arrow.down.right.circle.fill", "\(Int(-p))% abaixo da semana passada até aqui. Ainda dá tempo de virar o jogo!", Theme.warm)
            }
            return ("star.circle.fill", "\(week.count) treino(s) esta semana. Cada um conta! 💪", Theme.excellent)
        }()
        Label(msg.1, systemImage: msg.0).font(.caption.bold()).foregroundStyle(msg.2)
            .padding(10).frame(maxWidth: .infinity, alignment: .leading)
            .background(msg.2.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }

    private func mini(_ t: String, _ v: String) -> some View {
        VStack(spacing: 2) {
            Text(v).font(.subheadline.bold().monospacedDigit())
            Text(t).font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func nextCard(_ r: WorkoutRoutine) -> some View {
        Button { start(r) } label: {
            Card {
                HStack(spacing: 14) {
                    Image(systemName: r.icon).font(.title2).foregroundStyle(.white)
                        .frame(width: 54, height: 54).background(Theme.gradient, in: RoundedRectangle(cornerRadius: 16))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(r.weekday == Weekday.today ? "Treino de hoje" : (r.weekday == 0 ? "Próximo treino" : "Próximo: \(Weekday.name(r.weekday))"))
                            .font(.caption).foregroundStyle(.secondary)
                        Text(r.name).font(.headline).foregroundStyle(.primary)
                        Text("\(r.items.count) exercícios · \(r.muscles.prefix(3).map(\.label).joined(separator: ", "))")
                            .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer()
                    Image(systemName: "play.circle.fill").font(.system(size: 36)).foregroundStyle(Theme.gradient)
                }
            }
        }
        .buttonStyle(PressableStyle())
    }

    private var quickStart: some View {
        HStack(spacing: 12) {
            quick("bolt.fill", "Treino livre", Theme.accent) { start(nil) }
            quick("wand.and.stars", "Gerar programa", .purple) { showGenerator = true }
            quick("chart.bar.xaxis", "Estatísticas", Theme.accent2) { showStats = true }
        }
    }

    private func quick(_ icon: String, _ t: String, _ c: Color, _ a: @escaping () -> Void) -> some View {
        Button(action: a) {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.headline).foregroundStyle(c)
                    .frame(width: 40, height: 40).background(c.opacity(0.15), in: Circle())
                Text(t).font(.caption.bold()).foregroundStyle(.primary).lineLimit(1).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(PressableStyle())
    }

    @ViewBuilder private var routinesSection: some View {
        SectionHeader(title: "Semana de treino", icon: "calendar")
        if routines.isEmpty {
            Card {
                VStack(spacing: 12) {
                    Image(systemName: "wand.and.stars").font(.system(size: 40)).foregroundStyle(Theme.gradient)
                    Text("Monte seu programa em segundos").font(.headline)
                    Text("Escolha objetivo, nível e os dias da semana e o app cria todas as rotinas com séries, repetições e descanso.")
                        .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    Button("Gerar programa") { showGenerator = true }.buttonStyle(.borderedProminent).tint(Theme.accent)
                }
                .frame(maxWidth: .infinity)
            }
        } else {
            ForEach(Array(Weekday.mondayFirst.enumerated()), id: \.element) { i, day in
                dayRow(day).appear(0.12 + Double(i) * 0.03)
            }
            let unassigned = routines.filter { $0.weekday == 0 }
            if !unassigned.isEmpty {
                SectionHeader(title: "Sem dia definido", icon: "tray.fill")
                ForEach(unassigned) { routineCard($0) }
            }
            WeeklyProgramCard(routines: routines)
            TrainingBreakdownCard(items: routines.filter { $0.weekday != 0 }.flatMap(\.items), title: "Distribuição da semana")
            HStack {
                Button { showGenerator = true } label: { Label("Gerar novo programa", systemImage: "wand.and.stars") }
                Spacer()
                Button { newRoutine() } label: { Label("Nova rotina", systemImage: "plus") }
            }
            .font(.subheadline.bold())
            Text("Toque para ver · toque e segure para mover de dia, editar ou apagar").font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func dayRow(_ day: Int) -> some View {
        let list = routines.filter { $0.weekday == day }
        let isToday = day == Weekday.today
        let cal = Calendar.current
        let weekStart = cal.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        let doneThisWeek = finished.contains { $0.start >= weekStart && cal.component(.weekday, from: $0.start) == day }
        return HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 2) {
                Text(Weekday.short(day)).font(.caption.bold())
                    .foregroundStyle(isToday ? .white : .secondary)
                    .frame(width: 44, height: 28)
                    .background(isToday ? AnyShapeStyle(Theme.gradient) : AnyShapeStyle(.clear), in: Capsule())
                if doneThisWeek { Image(systemName: "checkmark.circle.fill").font(.caption).foregroundStyle(Theme.good) }
            }
            .padding(.top, 14)
            if list.isEmpty {
                HStack {
                    Image(systemName: "moon.zzz.fill").foregroundStyle(.secondary)
                    Text("Descanso").font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                    Menu {
                        ForEach(routines) { r in
                            Button("\(r.name)\(r.weekday == 0 ? "" : " (\(Weekday.short(r.weekday)))")") { move(r, to: day) }
                        }
                    } label: { Image(systemName: "plus.circle").foregroundStyle(Theme.accent) }
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 18).strokeBorder(.quaternary, style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
            } else {
                VStack(spacing: 8) { ForEach(list) { routineCard($0) } }
            }
        }
    }

    private func routineCard(_ r: WorkoutRoutine) -> some View {
        Button { viewing = r } label: {
            Card {
                HStack(spacing: 12) {
                    Image(systemName: r.icon).foregroundStyle(Theme.accent)
                        .frame(width: 40, height: 40).background(Theme.accent.opacity(0.15), in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(r.name).font(.headline).foregroundStyle(.primary).lineLimit(1)
                        Text("\(r.items.count) exercícios · ~\(Int(r.estimatedMinutes)) min · \(r.muscles.prefix(3).map(\.label).joined(separator: ", "))")
                            .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer()
                    Button { start(r) } label: {
                        Image(systemName: "play.circle.fill").font(.title).foregroundStyle(Theme.gradient)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .buttonStyle(PressableStyle())
        .contextMenu {
            Menu("Mover para…", systemImage: "calendar") {
                ForEach(Weekday.mondayFirst, id: \.self) { d in
                    Button(Weekday.name(d)) { move(r, to: d) }.disabled(d == r.weekday)
                }
                Button("Sem dia") { move(r, to: 0) }
            }
            Button("Ver", systemImage: "eye") { viewing = r }
            Button("Editar", systemImage: "pencil") { editing = r }
            Button("Duplicar", systemImage: "plus.square.on.square") {
                context.insert(WorkoutRoutine(name: r.name + " (cópia)", icon: r.icon, order: routines.count, items: r.items))
            }
            Button("Apagar", systemImage: "trash", role: .destructive) { context.delete(r) }
        }
    }

    /// Move a rotina para o dia; se o dia já tiver rotina, elas trocam de dia.
    private func move(_ r: WorkoutRoutine, to day: Int) {
        withAnimation(.spring(duration: 0.4)) {
            let old = r.weekday
            if day != 0 { for other in routines where other.weekday == day && other !== r { other.weekday = old } }
            r.weekday = day
        }
    }
    @ViewBuilder private var historySection: some View {
        SectionHeader(title: "Histórico", icon: "clock.arrow.circlepath")
        ForEach(finished.prefix(15)) { s in
            Button { detail = s } label: {
                Card {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(s.name).font(.subheadline.bold()).foregroundStyle(.primary)
                            Text(s.start, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute())
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 3) {
                            Text("\(WorkoutMath.volume(s).fmt(0)) kg").font(.subheadline.bold().monospacedDigit())
                                .foregroundStyle(.primary)
                            Text("\(WorkoutMath.durationText(s.duration)) · \(WorkoutMath.kcal(s).fmt(0)) kcal")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        if s.rating > 0 { Text(["😫", "😕", "🙂", "😃", "🔥"][s.rating - 1]) }
                    }
                }
            }
            .buttonStyle(PressableStyle())
        }
    }
}

// MARK: - Detalhe da sessão

struct SessionDetailView: View {
    let session: WorkoutSession
    var onRepeat: (WorkoutSession) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var confirmDelete = false
    @State private var showShare = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Data", value: session.start.formatted(date: .abbreviated, time: .shortened))
                    LabeledContent("Duração", value: WorkoutMath.durationText(session.duration))
                    LabeledContent("Volume", value: "\(WorkoutMath.volume(session).fmt(0)) kg")
                    LabeledContent("Séries", value: "\(WorkoutMath.setsCount(session))")
                    LabeledContent("Calorias", value: "\(WorkoutMath.kcal(session).fmt(0)) kcal")
                    if !session.note.isEmpty { Text(session.note).font(.callout) }
                }
                ForEach(session.exercises) { e in
                    Section(e.exercise?.name ?? e.exerciseID) {
                        ForEach(Array(e.sets.enumerated()), id: \.element.id) { i, s in
                            HStack {
                                Text(s.kind == .normal ? "\(i + 1)" : s.kind.short).frame(width: 28, alignment: .leading)
                                    .foregroundStyle(s.kind == .warmup ? Theme.warm : .primary)
                                if e.exercise?.kind == .cardio || e.exercise?.kind == .timed {
                                    Text("\(s.minutes.fmt(1)) min" + (s.km > 0 ? " · \(s.km.fmt(2)) km" : ""))
                                } else {
                                    Text("\(s.kg.fmt(1)) kg × \(s.reps)")
                                    Spacer()
                                    Text("1RM \(s.e1RM.fmt(1))").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                Section {
                    Button("Compartilhar imagem", systemImage: "square.and.arrow.up") { showShare = true }
                    Button("Repetir este treino", systemImage: "arrow.clockwise") { dismiss(); onRepeat(session) }
                    Button("Apagar treino", systemImage: "trash", role: .destructive) { confirmDelete = true }
                }
            }
            .navigationTitle(session.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("OK") { dismiss() } }
            .confirmationDialog("Apagar este treino?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Apagar", role: .destructive) { context.delete(session); dismiss() }
            }
            .sheet(isPresented: $showShare) {
                ShareImageSheet(title: "Treino") { WorkoutShareCard(session: session) }
            }
        }
    }
}

// MARK: - Estatísticas

struct WorkoutStatsView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \WorkoutSession.start) private var all: [WorkoutSession]
    @State private var weeks = 8

    private var sessions: [WorkoutSession] {
        let start = Calendar.current.date(byAdding: .weekOfYear, value: -weeks, to: .now) ?? .now
        return all.filter { !$0.isActive && $0.start >= start }
    }

    private struct WeekStat: Identifiable {
        let id: Date
        let volume: Double, count: Int, minutes: Double
    }

    private var weekly: [WeekStat] {
        let cal = Calendar.current
        let groups = Dictionary(grouping: sessions) { cal.dateInterval(of: .weekOfYear, for: $0.start)!.start }
        return (0..<weeks).reversed().compactMap { i -> WeekStat? in
            guard let d = cal.date(byAdding: .weekOfYear, value: -i, to: .now),
                  let ws = cal.dateInterval(of: .weekOfYear, for: d)?.start else { return nil }
            let g = groups[ws] ?? []
            return WeekStat(id: ws, volume: g.map(WorkoutMath.volume).reduce(0, +), count: g.count,
                            minutes: g.map(\.duration).reduce(0, +) / 60)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        Picker("Período", selection: $weeks.animation(.spring)) {
                            Text("4 semanas").tag(4); Text("8 semanas").tag(8); Text("12 semanas").tag(12); Text("1 ano").tag(52)
                        }
                        .pickerStyle(.segmented)
                        if sessions.isEmpty {
                            ContentUnavailableView("Sem treinos no período", systemImage: "dumbbell",
                                                   description: Text("Finalize treinos para ver suas estatísticas."))
                        } else {
                            totals.appear()
                            volumeChart.appear(0.05)
                            muscleCard.appear(0.1)
                            prsCard.appear(0.15)
                            frequentCard.appear(0.2)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Estatísticas de treino")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("OK") { dismiss() } }
        }
    }

    private var totals: some View {
        let s = sessions
        let vol = s.map(WorkoutMath.volume).reduce(0, +)
        let mins = s.map(\.duration).reduce(0, +) / 60
        let kcal = s.map(WorkoutMath.kcal).reduce(0, +)
        let perWeek = Double(s.count) / Double(weeks)
        let streak = weekly.reversed().prefix { $0.count > 0 }.count
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            MetricTile(title: "Treinos", value: "\(s.count)", icon: "checkmark.seal.fill", tint: Theme.good,
                       caption: "\(perWeek.fmt(1)) por semana")
            MetricTile(title: "Volume total", value: vol >= 10000 ? (vol / 1000).fmt(1) : vol.fmt(0),
                       unit: vol >= 10000 ? "t" : "kg", icon: "scalemass.fill", tint: Theme.accent)
            MetricTile(title: "Tempo total", value: WorkoutMath.durationText(mins * 60), icon: "timer", tint: Theme.accent2,
                       caption: "média \(WorkoutMath.durationText(mins * 60 / Double(s.count)))")
            MetricTile(title: "Calorias", value: kcal.fmt(0), unit: "kcal", icon: "flame.fill", tint: Theme.warm,
                       caption: "≈ \((kcal / 7700).fmt(2)) kg de gordura")
            MetricTile(title: "Séries", value: "\(s.map(WorkoutMath.setsCount).reduce(0, +))", icon: "square.stack.3d.up.fill",
                       tint: .purple)
            MetricTile(title: "Semanas seguidas", value: "\(streak)", icon: "flame.circle.fill", tint: .orange,
                       caption: "treinando ao menos 1x")
        }
    }

    private var volumeChart: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Text("Volume semanal").font(.headline)
                Chart(weekly) { w in
                    BarMark(x: .value("Semana", w.id, unit: .weekOfYear), y: .value("kg", w.volume))
                        .foregroundStyle(Theme.gradient).cornerRadius(4)
                        .annotation(position: .top) {
                            if w.count > 0 { Text("\(w.count)").font(.caption2).foregroundStyle(.secondary) }
                        }
                }
                .frame(height: 180)
                Text("Número sobre a barra = treinos na semana. Aumentar o volume aos poucos (sobrecarga progressiva) é o principal motor de ganho de força e massa.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private var muscleCard: some View {
        let lastWeek = sessions.filter { $0.start >= Date.now.addingTimeInterval(-7 * 86400) }
        let sets = WorkoutMath.muscleSets(lastWeek)
        let range = Muscle.weeklySetsRange
        return Card {
            VStack(alignment: .leading, spacing: 10) {
                Text("Séries por músculo (últimos 7 dias)").font(.headline)
                ForEach(Muscle.trained) { m in
                    let n = sets[m] ?? 0
                    let color: Color = n < range.lowerBound * 0.5 ? Theme.danger : (n < range.lowerBound ? Theme.warm
                                        : (n <= range.upperBound ? Theme.good : Theme.excellent))
                    HStack(spacing: 8) {
                        Text(m.label).font(.caption).frame(width: 86, alignment: .leading)
                        ProgressBar(progress: n / range.upperBound, tint: color, height: 8)
                        Text(n.fmt(1)).font(.caption.monospacedDigit()).frame(width: 32, alignment: .trailing)
                    }
                }
                Text("Faixa ideal para hipertrofia: 10–20 séries por semana por músculo (Schoenfeld, 2017). Secundários contam meia série.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private var prsCard: some View {
        var best: [String: SetLog] = [:]
        for s in sessions {
            for e in s.exercises where e.exercise?.kind == .strength {
                if let top = e.workSets.max(by: { $0.e1RM < $1.e1RM }), top.e1RM > (best[e.exerciseID]?.e1RM ?? 0) {
                    best[e.exerciseID] = top
                }
            }
        }
        let list = best.sorted { $0.value.e1RM > $1.value.e1RM }.prefix(10)
        return Card {
            VStack(alignment: .leading, spacing: 8) {
                Label("Recordes (1RM estimado)", systemImage: "trophy.fill").font(.headline).foregroundStyle(Theme.excellent)
                ForEach(Array(list), id: \.key) { id, s in
                    HStack {
                        Text(ExerciseCatalog.byID[id]?.name ?? id).font(.subheadline).lineLimit(1)
                        Spacer()
                        Text("\(s.e1RM.fmt(1)) kg").font(.subheadline.bold().monospacedDigit())
                        Text("(\(s.kg.fmt(1))×\(s.reps))").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var frequentCard: some View {
        var count: [String: Int] = [:]
        for s in sessions { for e in s.exercises { count[e.exerciseID, default: 0] += 1 } }
        let list = count.sorted { $0.value > $1.value }.prefix(8)
        let top = Double(list.first?.value ?? 1)
        return Card {
            VStack(alignment: .leading, spacing: 8) {
                Text("Exercícios mais feitos").font(.headline)
                ForEach(Array(list), id: \.key) { id, n in
                    HStack {
                        Text(ExerciseCatalog.byID[id]?.name ?? id).font(.subheadline).lineLimit(1)
                        Spacer()
                        Text("\(n)x").font(.caption.monospacedDigit())
                    }
                    ProgressBar(progress: Double(n) / top, tint: Theme.accent, height: 4)
                }
            }
        }
    }
}
