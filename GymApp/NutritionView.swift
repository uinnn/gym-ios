import SwiftUI
import SwiftData

/// Operações comuns do diário.
enum Diary {
    @MainActor static func log(_ food: FoodItem, grams: Double, meal: Meal, date: Date, in context: ModelContext) {
        let log = FoodLog(date: date, meal: meal, food: food, grams: grams)
        context.insert(log)
        HealthSync.shared.saveFood(kcal: log.nutrients.kcal, date: date)
        PartyService.shared.post(.food, "comeu \(food.name) (\(Int(grams)) g · \(Int(log.nutrients.kcal)) kcal)", value: log.nutrients.kcal)
        let id = food.id
        let saved = (try? context.fetch(FetchDescriptor<SavedFood>(predicate: #Predicate { $0.foodID == id })))?.first
        if let saved {
            saved.useCount += 1
            saved.lastUsed = .now
            saved.lastGrams = grams
        } else {
            let s = SavedFood(food)
            s.useCount = 1
            s.lastGrams = grams
            context.insert(s)
        }
    }

    /// Junta data do dia escolhido com a hora atual (para registros em outros dias).
    static func timestamp(for day: Date) -> Date {
        let cal = Calendar.current
        if cal.isDateInToday(day) { return .now }
        let t = cal.dateComponents([.hour, .minute], from: .now)
        return cal.date(bySettingHour: t.hour ?? 12, minute: t.minute ?? 0, second: 0, of: day) ?? day
    }
}

struct NutritionView: View {
    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]
    @Query(sort: \WeightEntry.date) private var weights: [WeightEntry]
    @Query private var measurements: [MeasurementEntry]
    @Query(sort: \FoodLog.date) private var logs: [FoodLog]
    @Query(sort: \WaterLog.date) private var water: [WaterLog]
    @Query(sort: \WorkoutSession.start) private var sessions: [WorkoutSession]
    @State private var showAssistant = false
    @State private var day = Calendar.current.startOfDay(for: .now)
    @State private var addingMeal: Meal?
    @State private var editing: FoodLog?
    @State private var showPlan = false
    @State private var showStats = false
    @State private var nutrientDetail: NutrientID?
    @State private var showShare = false

    private var cal: Calendar { Calendar.current }
    /// Guarda resultados entre atualizações da tela (o corpo da view é avaliado muitas vezes).
    private final class Memo {
        var logsKey = "", dayLogs: [FoodLog] = []
        var targetsKey = "", targets: NutritionTargets = .fallback, nutrientContext: NutrientContext?
    }
    @State private var memo = Memo()
    @State private var adjustBump = 0

    private var dayLogs: [FoodLog] {
        let key = "\(day.timeIntervalSince1970)|\(logs.count)|\(logs.last?.date.timeIntervalSince1970 ?? 0)"
        if memo.logsKey != key {
            memo.dayLogs = logs.filter { cal.isSameDay($0.date, day) }
            memo.logsKey = key
        }
        return memo.dayLogs
    }

    private var targetsKey: String {
        let p = profiles.first
        return "\(weights.count)|\(weights.last?.kg ?? 0)|\(measurements.count)|\(p?.heightCm ?? 0)|\(p?.sexRaw ?? "")|\(p?.birthDate.timeIntervalSince1970 ?? 0)|\(p?.activityRaw ?? "")|\(p?.goalRaw ?? "")|\(p?.goalWeightKg ?? 0)|\(CalorieAdjust.offset)"
    }

    private func refreshTargets() {
        let key = targetsKey
        guard memo.targetsKey != key else { return }
        memo.targetsKey = key
        let ctx = AnalysisContext(profile: profiles.first, entries: weights, measurements: measurements)
        let t = ctx.map { NutritionTargets(analysis: $0.current) } ?? .fallback
        memo.targets = t
        memo.nutrientContext = NutrientContext(male: (profiles.first?.sex ?? .male) == .male, age: profiles.first?.age ?? 30, targets: t)
    }

    private var nutrientContext: NutrientContext {
        refreshTargets()
        return memo.nutrientContext ?? NutrientContext(male: true, age: 30, targets: .fallback)
    }
    private var todayWater: Double { water.filter { cal.isDateInToday($0.date) }.map(\.ml).reduce(0, +) }
    private var dayWater: Double { water.filter { cal.isSameDay($0.date, day) }.map(\.ml).reduce(0, +) }
    private var totals: Nutrients { dayLogs.map(\.nutrients).total }
    /// Calorias gastas em treinos no dia escolhido.
    private var workoutKcal: Double {
        sessions.filter { !$0.isActive && cal.isSameDay($0.start, day) }.map(WorkoutMath.kcal).reduce(0, +)
    }

    private var targets: NutritionTargets {
        refreshTargets()
        return memo.targets
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        DayStrip(day: $day, logs: logs, targetKcal: targets.kcal).appear()
                        summaryCard.id(adjustBump).appear(0.05)
                        if Calendar.current.isDateInToday(day), let g = profiles.first?.goal {
                            CalorieAdjustCard(weights: weights, goal: g) { adjustBump += 1 }
                        }
                        HStack(spacing: 12) {
                            WaterCard(day: day, total: dayWater, goal: targets.water)
                            FastingCard()
                        }
                        .appear(0.1)
                        .onAppear { WaterReminder.reschedule(todayMl: todayWater, targetMl: targets.water) }
                        .onChange(of: todayWater) { _, ml in WaterReminder.reschedule(todayMl: ml, targetMl: targets.water) }
                        ForEach(Array(Meal.allCases.enumerated()), id: \.element) { i, meal in
                            mealCard(meal).appear(0.12 + Double(i) * 0.03)
                        }
                        microsCard.appear(0.3)
                    }
                    .padding()
                }
            }
            .sheet(isPresented: $showAssistant) { AssistantView() }
            .navigationTitle("Alimentação")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showAssistant = true } label: { Image(systemName: "mic.fill") }
                }
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink { CompareView(mode: .food) } label: { Image(systemName: "square.split.2x1") }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button { showStats = true } label: { Image(systemName: "chart.bar.xaxis") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Plano alimentar do dia", systemImage: "list.bullet.clipboard") { showPlan = true }
                        Button("Copiar refeições de ontem", systemImage: "doc.on.doc") { copyYesterday() }
                        Button("Compartilhar o dia", systemImage: "square.and.arrow.up") { showShare = true }
                        Button("Adicionar em \(Meal.forNow().label)", systemImage: "plus") { addingMeal = .forNow() }
                    } label: { Image(systemName: "ellipsis.circle") }
                }
            }
            .sheet(item: $addingMeal) { FoodSearchView(meal: $0, day: day) }
            .sheet(item: $editing) { EditLogSheet(log: $0) }
            .sheet(isPresented: $showPlan) { MealPlanView(day: day, targets: targets) }
            .sheet(isPresented: $showStats) { NutritionStatsView() }
            .sheet(item: $nutrientDetail) { NutrientDetailView(id: $0) }
            .sheet(isPresented: $showShare) {
                let t = targets
                ShareImageSheet(title: "Alimentação") {
                    NutritionShareCard(day: day, totals: totals, target: t.kcal, protein: t.protein, carbs: t.carbs,
                                       fat: t.fat, waterL: dayWater / 1000, meals: Set(dayLogs.map(\.mealRaw)).count)
                }
            }
        }
    }

    // MARK: Resumo

    private var summaryCard: some View {
        let t = targets, n = totals
        let hk = HealthSync.shared
        let burned = hk.isOn && hk.useActiveKcal && Calendar.current.isDateInToday(day) ? max(workoutKcal, hk.activeKcal) : workoutKcal
        let goal = t.kcal + (WorkoutPrefs.shared.addWorkoutKcal ? burned : 0)
        let remaining = goal - n.kcal
        return Card {
            VStack(spacing: 16) {
                HStack(spacing: 20) {
                    ZStack {
                        ProgressRing(progress: n.kcal / goal, lineWidth: 14,
                                     colors: n.kcal > goal * 1.1 ? [Theme.warm, Theme.danger] : nil)
                        VStack(spacing: 0) {
                            Text(abs(remaining).fmt(0)).font(.title2.bold()).contentTransition(.numericText())
                            Text(remaining >= 0 ? "restantes" : "acima").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 120, height: 120)
                    VStack(alignment: .leading, spacing: 10) {
                        kcalRow("Meta", goal, "target")
                        kcalRow("Consumido", n.kcal, "fork.knife")
                        kcalRow(WorkoutPrefs.shared.addWorkoutKcal ? "Treino (somado)" : "Gasto no treino", burned, "dumbbell.fill")
                        kcalRow("Saldo", n.kcal - burned, "plusminus")
                    }
                }
                HStack(spacing: 12) {
                    MacroBar(title: "Proteína", value: n.protein, goal: t.protein, tint: Theme.accent)
                    MacroBar(title: "Carbo", value: n.carbs, goal: t.carbs, tint: Theme.accent2)
                    MacroBar(title: "Gordura", value: n.fat, goal: t.fat, tint: Theme.warm)
                    MacroBar(title: "Fibras", value: n.fiber, goal: t.fiber, tint: Theme.good)
                }
            }
        }
    }

    private func kcalRow(_ title: String, _ v: Double, _ icon: String, unit: String = "kcal") -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(Theme.accent).frame(width: 20)
            VStack(alignment: .leading, spacing: 0) {
                Text(title).font(.caption2).foregroundStyle(.secondary)
                Text("\(v.fmt(0)) \(unit)").font(.subheadline.bold()).contentTransition(.numericText())
            }
        }
    }

    // MARK: Refeições

    private func mealCard(_ meal: Meal) -> some View {
        let items = dayLogs.filter { $0.meal == meal }
        let n = items.map(\.nutrients).total
        let goal = targets.kcal * meal.share
        return Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: meal.icon).foregroundStyle(Theme.accent)
                        .frame(width: 32, height: 32).background(Theme.accent.opacity(0.15), in: Circle())
                    VStack(alignment: .leading, spacing: 1) {
                        Text(meal.label).font(.headline)
                        Text(items.isEmpty ? "Sugerido: ~\(goal.fmt(0)) kcal"
                                           : "\(n.kcal.fmt(0)) kcal · P \(n.protein.fmt(0)) · C \(n.carbs.fmt(0)) · G \(n.fat.fmt(0))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button { addingMeal = meal } label: {
                        Image(systemName: "plus.circle.fill").font(.title2).foregroundStyle(Theme.gradient)
                    }
                    .buttonStyle(PressableStyle())
                }
                if !items.isEmpty {
                    ProgressBar(progress: n.kcal / max(goal, 1), tint: n.kcal > goal * 1.3 ? Theme.warm : Theme.accent, height: 4)
                    ForEach(items) { log in
                        Button { editing = log } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(log.name).font(.subheadline).lineLimit(1)
                                    Text("\(log.grams.fmt(0)) g").font(.caption2).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("\(log.nutrients.kcal.fmt(0)) kcal").font(.subheadline.monospacedDigit())
                            }
                            .foregroundStyle(.primary)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Editar", systemImage: "pencil") { editing = log }
                            Button("Duplicar", systemImage: "plus.square.on.square") {
                                let c = FoodLog(date: log.date, meal: log.meal, food: log.asFood, grams: log.grams)
                                context.insert(c)
                            }
                            Button("Apagar", systemImage: "trash", role: .destructive) {
                                withAnimation { context.delete(log) }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: Micronutrientes

    private var microsCard: some View {
        NutrientsDayCard(n: totals, m: dayLogs.compactMap(\.micros).total, e: dayLogs.map(\.extras).total,
                         ctx: nutrientContext) { nutrientDetail = $0 }
    }

    private func copyYesterday() {
        guard let y = cal.date(byAdding: .day, value: -1, to: day) else { return }
        let src = logs.filter { cal.isSameDay($0.date, y) }
        for l in src {
            let date = cal.date(byAdding: .day, value: 1, to: l.date) ?? day
            context.insert(FoodLog(date: date, meal: l.meal, food: l.asFood, grams: l.grams))
        }
    }
}

// MARK: - Componentes

struct MacroBar: View {
    let title: String, value: Double, goal: Double, tint: Color

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .bottom) {
                Capsule().fill(.quaternary)
                Capsule().fill(LinearGradient(colors: [tint.opacity(0.6), tint], startPoint: .bottom, endPoint: .top))
                    .frame(height: 60 * min(value / max(goal, 1), 1))
                    .animation(.spring(duration: 0.8, bounce: 0.3), value: value)
            }
            .frame(width: 14, height: 60)
            Text("\(value.fmt(0))g").font(.caption.bold().monospacedDigit()).contentTransition(.numericText())
            Text("/\(goal.fmt(0))").font(.caption2).foregroundStyle(.secondary)
            Text(title).font(.caption2).foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Faixa com os últimos 14 dias para trocar o dia.
struct DayStrip: View {
    @Binding var day: Date
    let logs: [FoodLog]
    let targetKcal: Double

    var body: some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let days = (0..<14).reversed().compactMap { cal.date(byAdding: .day, value: -$0, to: today) }
        let first = days.first ?? today
        let kcalByDay = Dictionary(grouping: logs.filter { $0.date >= first }) { cal.startOfDay(for: $0.date) }
            .mapValues { $0.map(\.nutrients.kcal).reduce(0, +) }
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(days, id: \.self) { d in
                        let on = cal.isSameDay(d, day)
                        let kcal = kcalByDay[d] ?? 0
                        Button {
                            withAnimation(.spring(duration: 0.35)) { day = d }
                        } label: {
                            VStack(spacing: 4) {
                                Text(d, format: .dateTime.weekday(.narrow)).font(.caption2)
                                Text(d, format: .dateTime.day()).font(.headline)
                                Circle()
                                    .fill(kcal == 0 ? Color.clear : (abs(kcal - targetKcal) / targetKcal < 0.1 ? Theme.good : Theme.warm))
                                    .frame(width: 6, height: 6)
                            }
                            .frame(width: 44, height: 66)
                            .foregroundStyle(on ? .white : .primary)
                            .background(on ? AnyShapeStyle(Theme.gradient) : AnyShapeStyle(.ultraThinMaterial),
                                        in: RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                        .id(d)
                    }
                }
            }
            .onAppear { proxy.scrollTo(today, anchor: .trailing) }
        }
    }
}

// MARK: - Água

struct Wave: Shape {
    var phase: Double
    var level: Double
    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(phase, level) }
        set { phase = newValue.first; level = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let y = rect.height * (1 - level)
        p.move(to: CGPoint(x: 0, y: y))
        for x in stride(from: 0, through: rect.width, by: 2) {
            let rel = x / rect.width
            p.addLine(to: CGPoint(x: x, y: y + sin(rel * .pi * 2 + phase) * 4))
        }
        p.addLine(to: CGPoint(x: rect.width, y: rect.height))
        p.addLine(to: CGPoint(x: 0, y: rect.height))
        p.closeSubpath()
        return p
    }
}

struct WaterCard: View {
    @Environment(\.modelContext) private var context
    let day: Date
    let total: Double
    let goal: Double
    @State private var phase = 0.0
    @State private var bump = 0

    var body: some View {
        let level = min(total / max(goal, 1), 1)
        Card {
            VStack(alignment: .leading, spacing: 8) {
                Label("Água", systemImage: "drop.fill").font(.subheadline.bold()).foregroundStyle(Theme.info)
                ZStack {
                    RoundedRectangle(cornerRadius: 14).fill(Theme.info.opacity(0.1))
                    Wave(phase: phase, level: level)
                        .fill(LinearGradient(colors: [Theme.info.opacity(0.5), Theme.info], startPoint: .top, endPoint: .bottom))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .animation(.spring(duration: 0.9), value: level)
                    VStack(spacing: 0) {
                        Text("\((total / 1000).fmt(2)) L").font(.headline).contentTransition(.numericText())
                        Text("de \((goal / 1000).fmt(1)) L").font(.caption2)
                    }
                }
                .frame(height: 80)
                .onAppear {
                    guard ThemeStore.shared.animations else { return }
                    withAnimation(.linear(duration: 2.5).repeatForever(autoreverses: false)) { phase = .pi * 2 }
                }
                HStack(spacing: 6) {
                    ForEach([200.0, 500.0], id: \.self) { ml in
                        Button("+\(Int(ml))") {
                            context.insert(WaterLog(date: Diary.timestamp(for: day), ml: ml))
                            HealthSync.shared.saveWater(ml, date: Diary.timestamp(for: day))
                            if total < goal, total + ml >= goal, Calendar.current.isDateInToday(day) {
                                PartyService.shared.post(.water, "bateu a meta de água (\((goal / 1000).fmt(1)) L) 💧", value: goal / 1000)
                            }
                            bump += 1
                        }
                        .font(.caption.bold())
                        .buttonStyle(.bordered).tint(Theme.info)
                    }
                    Button {
                        let fetch = FetchDescriptor<WaterLog>(sortBy: [SortDescriptor(\.date, order: .reverse)])
                        if let last = (try? context.fetch(fetch))?.first(where: { Calendar.current.isSameDay($0.date, day) }) {
                            context.delete(last)
                        }
                    } label: { Image(systemName: "arrow.uturn.backward") }
                    .font(.caption).buttonStyle(.bordered).tint(.secondary)
                }
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: bump) { _, _ in ThemeStore.shared.haptics }
    }
}

// MARK: - Jejum

struct FastingCard: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \FastingSession.start, order: .reverse) private var sessions: [FastingSession]
    @State private var showOptions = false

    private var active: FastingSession? { sessions.first { $0.end == nil } }

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                Label("Jejum", systemImage: "timer").font(.subheadline.bold()).foregroundStyle(Theme.excellent)
                if let s = active {
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        let h = s.duration / 3600
                        VStack(alignment: .leading, spacing: 4) {
                            ZStack {
                                ProgressRing(progress: h / s.goalHours, lineWidth: 7,
                                             colors: [Theme.excellent, Theme.accent2, Theme.excellent])
                                Text(Self.clock(s.duration)).font(.caption.bold().monospacedDigit())
                            }
                            .frame(height: 56)
                            Text(Self.phase(h)).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                    Button("Encerrar") { withAnimation { s.end = .now }; LiveActivities.end() }
                        .font(.caption.bold()).buttonStyle(.borderedProminent).tint(Theme.excellent)
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        if let last = sessions.first {
                            Text("Último: \(Self.clock(last.duration))").font(.caption.bold())
                            Text(last.completed ? "Meta cumprida ✓" : "Meta de \(Int(last.goalHours))h")
                                .font(.caption2).foregroundStyle(last.completed ? Theme.good : .secondary)
                        } else {
                            Text("Nenhum jejum ainda").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .frame(height: 56, alignment: .center)
                    Menu {
                        ForEach([12.0, 14.0, 16.0, 18.0, 20.0, 24.0], id: \.self) { h in
                            Button("\(Int(h)):\(Int(24 - min(h, 24))) — \(Int(h)) horas") {
                                let f = FastingSession(goalHours: h)
                                context.insert(f)
                                LiveActivities.startFasting(hours: h, start: f.start)
                            }
                        }
                    } label: {
                        Text("Iniciar").font(.caption.bold()).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent).tint(Theme.excellent)
                }
            }
        }
    }

    static func clock(_ t: TimeInterval) -> String {
        let s = Int(t)
        return String(format: "%02d:%02d:%02d", s / 3600, s / 60 % 60, s % 60)
    }

    static func phase(_ h: Double) -> String {
        switch h {
        case ..<4: "Digestão"
        case ..<12: "Usando glicogênio"
        case ..<18: "Início da cetose"
        default: "Cetose"
        }
    }
}

// MARK: - Editar registro

struct EditLogSheet: View {
    @Bindable var log: FoodLog
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var grams: Double = 100
    @State private var meal: Meal = .lunch

    var body: some View {
        let food = log.asFood
        NavigationStack {
            Form {
                Section(log.name) {
                    Picker("Refeição", selection: $meal) {
                        ForEach(Meal.allCases) { Label($0.label, systemImage: $0.icon).tag($0) }
                    }
                    GramsField(grams: $grams)
                }
                NutrientsSummary(n: food.per100.scaled(grams / 100), m: food.micros?.scaled(grams / 100), e: food.extras?.scaled(grams / 100) ?? [:])
                Section {
                    Button("Apagar", role: .destructive) { context.delete(log); dismiss() }
                }
            }
            .navigationTitle("Editar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        log.rescale(to: grams)
                        log.mealRaw = meal.rawValue
                        dismiss()
                    }
                }
            }
            .onAppear { grams = log.grams; meal = log.meal }
        }
        .presentationDetents([.medium, .large])
    }
}

/// Campo de gramas com atalhos.
struct GramsField: View {
    @Binding var grams: Double
    var serving: (name: String, grams: Double)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Quantidade")
                Spacer()
                TextField("g", value: $grams, format: .number.precision(.fractionLength(0...1)))
                    .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 80)
                    .font(.title3.bold())
                Text("g").foregroundStyle(.secondary)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    if let s = serving {
                        chip("1 porção (\(s.grams.fmt(0)) g)") { grams = s.grams }
                    }
                    ForEach([25.0, 50, 100, 150, 200, 300], id: \.self) { g in
                        chip("\(Int(g)) g") { grams = g }
                    }
                    chip("−10") { grams = max(1, grams - 10) }
                    chip("+10") { grams += 10 }
                }
            }
        }
    }

    private func chip(_ t: String, _ action: @escaping () -> Void) -> some View {
        Button(t) { withAnimation(.snappy) { action() } }
            .font(.caption.bold()).buttonStyle(.bordered).tint(Theme.accent)
    }
}

