import SwiftUI
import SwiftData

/// Operações comuns do diário.
enum Diary {
    static func log(_ food: FoodItem, grams: Double, meal: Meal, date: Date, in context: ModelContext) {
        context.insert(FoodLog(date: date, meal: meal, food: food, grams: grams))
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
    @State private var day = Calendar.current.startOfDay(for: .now)
    @State private var addingMeal: Meal?
    @State private var editing: FoodLog?
    @State private var showPlan = false
    @State private var showStats = false
    @State private var showMicros = false

    private var cal: Calendar { Calendar.current }
    private var dayLogs: [FoodLog] { logs.filter { cal.isSameDay($0.date, day) } }
    private var dayWater: Double { water.filter { cal.isSameDay($0.date, day) }.map(\.ml).reduce(0, +) }
    private var totals: Nutrients { dayLogs.map(\.nutrients).total }

    private var targets: NutritionTargets {
        guard let ctx = AnalysisContext(profile: profiles.first, entries: weights, measurements: measurements)
        else { return .fallback }
        return NutritionTargets(analysis: ctx.current)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        DayStrip(day: $day, logs: logs, targetKcal: targets.kcal).appear()
                        summaryCard.appear(0.05)
                        HStack(spacing: 12) {
                            WaterCard(day: day, total: dayWater, goal: targets.water)
                            FastingCard()
                        }
                        .appear(0.1)
                        ForEach(Array(Meal.allCases.enumerated()), id: \.element) { i, meal in
                            mealCard(meal).appear(0.12 + Double(i) * 0.03)
                        }
                        microsCard.appear(0.3)
                    }
                    .padding()
                }
            }
            .navigationTitle("Alimentação")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showStats = true } label: { Image(systemName: "chart.bar.xaxis") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Plano alimentar do dia", systemImage: "list.bullet.clipboard") { showPlan = true }
                        Button("Copiar refeições de ontem", systemImage: "doc.on.doc") { copyYesterday() }
                        Button("Adicionar em \(Meal.forNow().label)", systemImage: "plus") { addingMeal = .forNow() }
                    } label: { Image(systemName: "ellipsis.circle") }
                }
            }
            .sheet(item: $addingMeal) { FoodSearchView(meal: $0, day: day) }
            .sheet(item: $editing) { EditLogSheet(log: $0) }
            .sheet(isPresented: $showPlan) { MealPlanView(day: day, targets: targets) }
            .sheet(isPresented: $showStats) { NutritionStatsView() }
        }
    }

    // MARK: Resumo

    private var summaryCard: some View {
        let t = targets, n = totals
        let remaining = t.kcal - n.kcal
        return Card {
            VStack(spacing: 16) {
                HStack(spacing: 20) {
                    ZStack {
                        ProgressRing(progress: n.kcal / t.kcal, lineWidth: 14,
                                     colors: n.kcal > t.kcal * 1.1 ? [Theme.warm, Theme.danger] : nil)
                        VStack(spacing: 0) {
                            Text(abs(remaining).fmt(0)).font(.title2.bold()).contentTransition(.numericText())
                            Text(remaining >= 0 ? "restantes" : "acima").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 120, height: 120)
                    VStack(alignment: .leading, spacing: 10) {
                        kcalRow("Meta", t.kcal, "target")
                        kcalRow("Consumido", n.kcal, "fork.knife")
                        kcalRow("Refeições", Double(Set(dayLogs.map(\.mealRaw)).count), "list.bullet", unit: "")
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
                                let c = FoodLog(date: log.date, meal: log.meal,
                                                food: FoodItem(id: log.foodID, name: log.name, category: "",
                                                               per100: log.nutrients.scaled(100 / max(log.grams, 1))),
                                                grams: log.grams)
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
        let n = totals, t = targets
        let rows: [(String, Double, Double, String, Bool)] = [   // nome, valor, meta, unidade, é limite máximo
            ("Sódio", n.sodium, t.sodiumMax, "mg", true),
            ("Açúcar", n.sugar, t.sugarMax, "g", true),
            ("Gordura saturada", n.saturated, t.saturatedMax, "g", true),
            ("Colesterol", n.cholesterol, t.cholesterolMax, "mg", true),
            ("Cálcio", n.calcium, t.calcium, "mg", false),
            ("Ferro", n.iron, t.iron, "mg", false),
            ("Potássio", n.potassium, t.potassium, "mg", false),
            ("Magnésio", n.magnesium, t.magnesium, "mg", false),
            ("Vitamina C", n.vitaminC, t.vitaminC, "mg", false),
            ("Zinco", n.zinc, t.zinc, "mg", false),
        ]
        return Card {
            VStack(alignment: .leading, spacing: 12) {
                Button {
                    withAnimation(.spring) { showMicros.toggle() }
                } label: {
                    HStack {
                        Label("Micronutrientes e limites", systemImage: "atom").font(.headline)
                        Spacer()
                        Image(systemName: "chevron.down").rotationEffect(.degrees(showMicros ? 180 : 0))
                    }
                    .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
                if showMicros {
                    ForEach(rows, id: \.0) { name, v, goal, unit, isMax in
                        let p = v / max(goal, 0.001)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(name).font(.subheadline)
                                Spacer()
                                Text("\(v.fmt(v < 10 ? 1 : 0)) / \(goal.fmt(0)) \(unit)")
                                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                            }
                            ProgressBar(progress: p, tint: isMax ? (p > 1 ? Theme.danger : Theme.warm)
                                                                 : (p >= 1 ? Theme.good : Theme.accent2), height: 5)
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    Text("Limites máximos em laranja/vermelho (OMS); metas de ingestão em azul/verde (IOM). Açúcar só é contado em produtos do Open Food Facts.")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func copyYesterday() {
        guard let y = cal.date(byAdding: .day, value: -1, to: day) else { return }
        let src = logs.filter { cal.isSameDay($0.date, y) }
        for l in src {
            let date = cal.date(byAdding: .day, value: 1, to: l.date) ?? day
            let food = FoodItem(id: l.foodID, name: l.name, category: "",
                                per100: l.nutrients.scaled(100 / max(l.grams, 1)))
            context.insert(FoodLog(date: date, meal: l.meal, food: food, grams: l.grams))
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
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(days, id: \.self) { d in
                        let on = cal.isSameDay(d, day)
                        let kcal = logs.filter { cal.isSameDay($0.date, d) }.map(\.nutrients.kcal).reduce(0, +)
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
                    Button("Encerrar") { withAnimation { s.end = .now } }
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
                                context.insert(FastingSession(goalHours: h))
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
        let per100 = log.nutrients.scaled(100 / max(log.grams, 1))
        NavigationStack {
            Form {
                Section(log.name) {
                    Picker("Refeição", selection: $meal) {
                        ForEach(Meal.allCases) { Label($0.label, systemImage: $0.icon).tag($0) }
                    }
                    GramsField(grams: $grams)
                }
                NutrientsSummary(n: per100.scaled(grams / 100))
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
                        log.nutrients = per100.scaled(grams / 100)
                        log.grams = grams
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

/// Seção de formulário com os nutrientes.
struct NutrientsSummary: View {
    let n: Nutrients

    var body: some View {
        Section("Nutrientes") {
            HStack {
                big("Calorias", n.kcal, "kcal", Theme.warm)
                big("Proteína", n.protein, "g", Theme.accent)
                big("Carbo", n.carbs, "g", Theme.accent2)
                big("Gordura", n.fat, "g", Theme.danger)
            }
            LabeledContent("Fibras", value: "\(n.fiber.fmt(1)) g")
            if n.sugar > 0 { LabeledContent("Açúcares", value: "\(n.sugar.fmt(1)) g") }
            LabeledContent("Gordura saturada", value: "\(n.saturated.fmt(1)) g")
            LabeledContent("Sódio", value: "\(n.sodium.fmt(0)) mg")
            LabeledContent("Cálcio", value: "\(n.calcium.fmt(0)) mg")
            LabeledContent("Ferro", value: "\(n.iron.fmt(1)) mg")
            LabeledContent("Potássio", value: "\(n.potassium.fmt(0)) mg")
        }
    }

    private func big(_ t: String, _ v: Double, _ u: String, _ c: Color) -> some View {
        VStack(spacing: 2) {
            Text(v.fmt(0)).font(.title3.bold()).foregroundStyle(c).contentTransition(.numericText())
            Text("\(u) \(t.lowercased())").font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
