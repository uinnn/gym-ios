import SwiftUI
import SwiftData
import Charts

// MARK: - Modelo genérico de comparação

/// Uma linha da tabela (ex.: "Gordura corporal").
struct CompareRow: Identifiable, Hashable {
    let id: String
    let title: String
    let unit: String
    var digits = 1
    /// true = maior é melhor; false = menor é melhor; nil = neutro.
    var higherIsBetter: Bool? = nil
    var group = "Geral"
}

/// Um item comparado (uma pesagem, um treino, um dia…).
struct CompareColumn: Identifiable {
    let id: String
    let date: Date
    let title: String
    let subtitle: String
    var values: [String: Double]
}

enum CompareMode: String, CaseIterable, Identifiable {
    case weights = "Pesagens", workouts = "Treinos", food = "Alimentação", mind = "Mente"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .weights: "scalemass.fill"
        case .workouts: "dumbbell.fill"
        case .food: "fork.knife"
        case .mind: "brain.head.profile"
        }
    }
    var noun: String {
        switch self {
        case .weights: "pesagens"
        case .workouts: "treinos"
        case .food: "dias"
        case .mind: "dias"
        }
    }
}

// MARK: - Tela

struct CompareView: View {
    @State var mode: CompareMode = .weights
    @Query private var profiles: [UserProfile]
    @Query(sort: \WeightEntry.date) private var weights: [WeightEntry]
    @Query private var measurements: [MeasurementEntry]
    @Query(sort: \WorkoutSession.start, order: .reverse) private var sessions: [WorkoutSession]
    @Query(sort: \FoodLog.date) private var foodLogs: [FoodLog]
    @Query(sort: \WaterLog.date) private var waterLogs: [WaterLog]
    @Query(sort: \MoodEntry.date) private var moods: [MoodEntry]
    @Query(sort: \SleepEntry.wake) private var sleeps: [SleepEntry]
    @Query(sort: \MindSession.date) private var practices: [MindSession]

    @State private var selected: [CompareMode: [String]] = [:]
    @State private var showPicker = false
    @State private var chartRow: String?
    @State private var showAllRows = false
    @State private var baseline = 0   // 0 = primeiro (mais antigo), 1 = anterior

    private var cal: Calendar { Calendar.current }

    var body: some View {
        let candidates = candidates(mode)
        let picked = (selected[mode] ?? []).compactMap { id in candidates.first { $0.id == id } }.sorted { $0.date < $1.date }
        let rows = rows(mode, picked)
        ScrollView {
            VStack(spacing: 14) {
                Picker("Tipo", selection: $mode.animation()) {
                    ForEach(CompareMode.allCases) { Label($0.rawValue, systemImage: $0.icon).tag($0) }
                }
                .pickerStyle(.segmented)

                selectionCard(candidates, picked)
                if picked.count >= 2 {
                    summaryCard(picked, rows).appear(0.03)
                    chartCard(picked, rows).appear(0.06)
                    tableCard(picked, rows).appear(0.09)
                } else if candidates.count < 2 {
                    ContentUnavailableView("Poucos registros", systemImage: mode.icon,
                                           description: Text("Você precisa de pelo menos 2 \(mode.noun) registrados para comparar."))
                } else {
                    ContentUnavailableView("Escolha o que comparar", systemImage: "square.split.2x1",
                                           description: Text("Selecione 2 ou mais \(mode.noun) — quantos quiser."))
                }
            }
            .padding()
        }
        .background(AnimatedBackground())
        .navigationTitle("Comparar")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPicker) {
            ComparePickerSheet(mode: mode, candidates: candidates, selection: Binding(
                get: { Set(selected[mode] ?? []) },
                set: { selected[mode] = Array($0) }))
        }
        .onChange(of: mode) { _, _ in chartRow = nil; showAllRows = false }
        .onAppear {
            // Começa com os 2 mais recentes de cada tipo, para já mostrar algo útil.
            if (selected[mode] ?? []).isEmpty {
                selected[mode] = Array(candidates.sorted { $0.date > $1.date }.prefix(2).map(\.id))
            }
        }
    }

    // MARK: Seleção

    private func selectionCard(_ all: [CompareColumn], _ picked: [CompareColumn]) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("\(picked.count) \(mode.noun) selecionados", systemImage: "checklist").font(.headline)
                    Spacer()
                    Button { showPicker = true } label: { Label("Escolher", systemImage: "plus.circle.fill").font(.subheadline.bold()) }
                }
                if !picked.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(picked.enumerated()), id: \.element.id) { i, c in
                                HStack(spacing: 6) {
                                    Circle().fill(color(i)).frame(width: 8, height: 8)
                                    VStack(alignment: .leading, spacing: 0) {
                                        Text(c.title).font(.caption.bold())
                                        Text(c.subtitle).font(.caption2).foregroundStyle(.secondary)
                                    }
                                    Button { remove(c.id) } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                                }
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(.quaternary, in: Capsule())
                            }
                        }
                    }
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        let byDate = all.sorted { $0.date > $1.date }
                        ForEach([2, 3, 5, 7, 10], id: \.self) { n in
                            if byDate.count >= n { preset("Últimos \(n)") { selected[mode] = byDate.prefix(n).map(\.id) } }
                        }
                        if let f = byDate.last, let l = byDate.first, byDate.count > 2 {
                            preset("Primeiro × último") { selected[mode] = [f.id, l.id] }
                        }
                        if mode != .workouts, byDate.count > 4 {
                            preset("1 por semana (5)") { selected[mode] = weekly(byDate, 5) }
                            preset("1 por mês (6)") { selected[mode] = monthly(byDate, 6) }
                        }
                        if mode == .workouts, let name = byDate.first?.title {
                            let same = byDate.filter { $0.title == name }
                            if same.count >= 2 { preset("Últimos \"\(name)\"") { selected[mode] = same.prefix(5).map(\.id) } }
                        }
                        if !picked.isEmpty { preset("Limpar") { selected[mode] = [] } }
                    }
                }
            }
        }
    }

    private func preset(_ t: String, _ a: @escaping () -> Void) -> some View {
        Button { withAnimation { a() } } label: {
            Text(t).font(.caption.bold()).padding(.horizontal, 10).padding(.vertical, 6)
                .background(Theme.accent.opacity(0.15), in: Capsule()).foregroundStyle(Theme.accent)
        }
        .buttonStyle(.tap)
    }

    private func weekly(_ byDate: [CompareColumn], _ n: Int) -> [String] {
        var seen = Set<Int>(), out: [String] = []
        for c in byDate {
            let w = cal.component(.weekOfYear, from: c.date) + cal.component(.yearForWeekOfYear, from: c.date) * 100
            if seen.insert(w).inserted { out.append(c.id) }
            if out.count == n { break }
        }
        return out
    }

    private func monthly(_ byDate: [CompareColumn], _ n: Int) -> [String] {
        var seen = Set<Int>(), out: [String] = []
        for c in byDate {
            let m = cal.component(.month, from: c.date) + cal.component(.year, from: c.date) * 100
            if seen.insert(m).inserted { out.append(c.id) }
            if out.count == n { break }
        }
        return out
    }

    private func remove(_ id: String) { withAnimation { selected[mode]?.removeAll { $0 == id } } }

    static let colors: [Color] = [.blue, .orange, .green, .purple, .pink, .teal, .red, .indigo, .yellow, .mint, .brown, .cyan]
    private func color(_ i: Int) -> Color { Self.colors[i % Self.colors.count] }

    // MARK: Resumo

    private func summaryCard(_ cols: [CompareColumn], _ rows: [CompareRow]) -> some View {
        let first = cols.first!, last = cols.last!
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: first.date), to: cal.startOfDay(for: last.date)).day ?? 0
        var better: [String] = [], worse: [String] = []
        for r in rows {
            guard let a = first.values[r.id], let b = last.values[r.id], abs(b - a) > 0.0001 else { continue }
            let pct = a != 0 ? (b - a) / abs(a) * 100 : 0
            guard abs(pct) >= 1 || a == 0 else { continue }
            let txt = "\(r.title): \(fmt(a, r)) → \(fmt(b, r)) \(r.unit) (\(b > a ? "+" : "")\(fmt(b - a, r)))"
            if let h = r.higherIsBetter { (h == (b > a)) ? better.append(txt) : worse.append(txt) }
        }
        let wins = winsPerColumn(cols, rows)
        let champion = wins.enumerated().max { $0.element < $1.element }
        return Card {
            VStack(alignment: .leading, spacing: 10) {
                Label("Resumo", systemImage: "text.magnifyingglass").font(.headline)
                Text("\(cols.count) \(mode.noun) em \(days) dia(s): de \(first.date.formatted(.dateTime.day().month(.abbreviated).year(.twoDigits))) a \(last.date.formatted(.dateTime.day().month(.abbreviated).year(.twoDigits))). Comparando o primeiro com o último:")
                    .font(.subheadline).foregroundStyle(.secondary)
                if !better.isEmpty {
                    bullets("Melhorou", better.prefix(showAllRows ? 50 : 5), Theme.accent, "arrow.up.right.circle.fill")
                }
                if !worse.isEmpty {
                    bullets("Piorou", worse.prefix(showAllRows ? 50 : 5), Theme.danger, "arrow.down.right.circle.fill")
                }
                if better.isEmpty && worse.isEmpty {
                    Text("Quase nada mudou entre o primeiro e o último.").font(.subheadline)
                }
                if let champion, champion.element > 0 {
                    Divider()
                    HStack(alignment: .top) {
                        Image(systemName: "trophy.fill").foregroundStyle(.yellow)
                        Text("Melhor no geral: **\(cols[champion.offset].title)** (\(cols[champion.offset].subtitle)), o melhor em \(champion.element) de \(rows.filter { $0.higherIsBetter != nil }.count) itens.")
                            .font(.subheadline)
                    }
                }
                insight(cols).map { t in
                    HStack(alignment: .top) {
                        Image(systemName: "lightbulb.fill").foregroundStyle(Theme.warm)
                        Text(t).font(.subheadline)
                    }
                }
            }
        }
    }

    private func bullets(_ title: String, _ items: ArraySlice<String>, _ c: Color, _ icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: icon).font(.subheadline.bold()).foregroundStyle(c)
            ForEach(Array(items), id: \.self) { Text("• " + $0).font(.caption) }
        }
    }

    private func winsPerColumn(_ cols: [CompareColumn], _ rows: [CompareRow]) -> [Int] {
        var wins = Array(repeating: 0, count: cols.count)
        for r in rows {
            guard let h = r.higherIsBetter, let i = bestIndex(cols, r, h) else { continue }
            wins[i] += 1
        }
        return wins
    }

    private func bestIndex(_ cols: [CompareColumn], _ r: CompareRow, _ h: Bool) -> Int? {
        let vals = cols.enumerated().compactMap { i, c in c.values[r.id].map { (i, $0) } }
        guard vals.count >= 2, Set(vals.map(\.1)).count > 1 else { return nil }
        return (h ? vals.max { $0.1 < $1.1 } : vals.min { $0.1 < $1.1 })?.0
    }

    /// Uma observação extra, específica de cada tipo.
    private func insight(_ cols: [CompareColumn]) -> String? {
        let first = cols.first!, last = cols.last!
        switch mode {
        case .weights:
            guard let w0 = first.values["weight"], let w1 = last.values["weight"],
                  let f0 = first.values["fatMass"], let f1 = last.values["fatMass"] else { return nil }
            let dw = w1 - w0, df = f1 - f0, dl = dw - df
            if abs(dw) < 0.2 { return "Peso estável, mas a composição mudou: \(df >= 0 ? "+" : "")\(df.fmt(1)) kg de gordura e \(dl >= 0 ? "+" : "")\(dl.fmt(1)) kg de massa magra." }
            return "Da variação de \(dw >= 0 ? "+" : "")\(dw.fmt(1)) kg, cerca de \(df >= 0 ? "+" : "")\(df.fmt(1)) kg foi gordura e \(dl >= 0 ? "+" : "")\(dl.fmt(1)) kg massa magra (água, músculo, glicogênio). Bioimpedância oscila com hidratação: compare pesagens feitas no mesmo horário."
        case .workouts:
            let v = cols.compactMap { $0.values["volume"] }
            guard v.count >= 2, let a = v.first, let b = v.last, a > 0 else { return nil }
            let pct = (b - a) / a * 100
            return pct > 2 ? "O volume subiu \(Int(pct))%: sinal de sobrecarga progressiva. Mantenha a técnica e descanse bem."
                : pct < -10 ? "O volume caiu \(Int(-pct))%. Se não foi um deload planejado, veja sono, alimentação e estresse."
                : "Volume parecido. Para evoluir, tente +1 rep ou +1 série nos principais exercícios."
        case .food:
            let p = cols.compactMap { $0.values["pctKcal"] }
            guard !p.isEmpty else { return nil }
            let within = p.filter { (90...110).contains($0) }.count
            let prot = cols.compactMap { $0.values["protein"] }
            let protAvg = prot.reduce(0, +) / Double(max(prot.count, 1))
            return "\(within) de \(p.count) dias ficaram entre 90% e 110% da meta de calorias. Proteína média: \(protAvg.fmt(0)) g/dia."
        case .mind:
            let pairs = cols.compactMap { c -> (Double, Double)? in
                guard let s = c.values["sleepH"], let m = c.values["mood"] else { return nil }
                return (s, m)
            }
            guard pairs.count >= 3 else { return nil }
            let good = pairs.filter { $0.0 >= 7 }.map(\.1), bad = pairs.filter { $0.0 < 7 }.map(\.1)
            guard !good.isEmpty, !bad.isEmpty else { return nil }
            let g = good.reduce(0, +) / Double(good.count), b = bad.reduce(0, +) / Double(bad.count)
            return "Nos dias com 7 h ou mais de sono seu humor médio foi \(g.fmt(1)); com menos de 7 h, \(b.fmt(1))."
        }
    }

    // MARK: Gráfico

    private func chartCard(_ cols: [CompareColumn], _ rows: [CompareRow]) -> some View {
        let available = rows.filter { r in cols.filter { $0.values[r.id] != nil }.count >= 2 }
        let row = available.first { $0.id == chartRow } ?? available.first
        return Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Gráfico", systemImage: "chart.xyaxis.line").font(.headline)
                    Spacer()
                    if let row {
                        Menu {
                            ForEach(available) { r in Button(r.title) { chartRow = r.id } }
                        } label: {
                            HStack(spacing: 4) { Text(row.title).lineLimit(1); Image(systemName: "chevron.up.chevron.down") }
                                .font(.subheadline.bold())
                        }
                    }
                }
                if let row {
                    let pts = cols.enumerated().compactMap { i, c in c.values[row.id].map { (i, c, $0) } }
                    Chart {
                        ForEach(pts, id: \.1.id) { i, c, v in
                            BarMark(x: .value("Item", "\(i + 1). \(c.title)"), y: .value(row.unit, v))
                                .foregroundStyle(color(i).gradient)
                                .cornerRadius(6)
                                .annotation(position: .top) { Text(fmt(v, row)).font(.caption2.bold()) }
                        }
                        if pts.count >= 2 {
                            let avg = pts.map(\.2).reduce(0, +) / Double(pts.count)
                            RuleMark(y: .value("Média", avg))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                                .foregroundStyle(.secondary)
                                .annotation(position: .trailing, alignment: .leading) { Text("média").font(.caption2).foregroundStyle(.secondary) }
                        }
                    }
                    .chartXAxis { AxisMarks { _ in AxisValueLabel().font(.caption2) } }
                    .frame(height: 200)
                    if let h = row.higherIsBetter {
                        Text(h ? "Quanto maior, melhor." : "Quanto menor, melhor.").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: Tabela

    private func tableCard(_ cols: [CompareColumn], _ rows: [CompareRow]) -> some View {
        let groups = Dictionary(grouping: rows, by: \.group)
        let order = rows.map(\.group).reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
        let visible = showAllRows ? order : Array(order.prefix(2))
        return Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Tabela", systemImage: "tablecells").font(.headline)
                    Spacer()
                    Picker("Diferença", selection: $baseline) {
                        Text("vs. 1º").tag(0)
                        Text("vs. anterior").tag(1)
                    }
                    .pickerStyle(.segmented).frame(width: 170)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 8) {
                        GridRow {
                            Text("")
                            ForEach(Array(cols.enumerated()), id: \.element.id) { i, c in
                                VStack(alignment: .leading, spacing: 1) {
                                    HStack(spacing: 4) { Circle().fill(color(i)).frame(width: 7, height: 7); Text(c.title).font(.caption.bold()) }
                                    Text(c.subtitle).font(.caption2).foregroundStyle(.secondary)
                                }
                                .frame(minWidth: 80, alignment: .leading)
                            }
                        }
                        ForEach(visible, id: \.self) { g in
                            GridRow {
                                Text(g.uppercased()).font(.caption2.bold()).foregroundStyle(Theme.accent).padding(.top, 6)
                                    .gridCellColumns(cols.count + 1)
                            }
                            ForEach(groups[g] ?? []) { r in
                                let best = r.higherIsBetter.flatMap { bestIndex(cols, r, $0) }
                                GridRow {
                                    VStack(alignment: .leading, spacing: 0) {
                                        Text(r.title).font(.caption)
                                        if !r.unit.isEmpty { Text(r.unit).font(.caption2).foregroundStyle(.tertiary) }
                                    }
                                    .frame(width: 130, alignment: .leading)
                                    ForEach(Array(cols.enumerated()), id: \.element.id) { i, c in
                                        cell(r, cols, i, isBest: best == i)
                                    }
                                }
                                Divider().gridCellUnsizedAxes(.horizontal)
                            }
                        }
                    }
                }
                if order.count > 2 {
                    Button(showAllRows ? "Mostrar menos" : "Mostrar tudo (\(rows.count) itens)") { withAnimation { showAllRows.toggle() } }
                        .font(.subheadline.bold())
                }
                Text("🏆 = melhor valor entre os selecionados. Verde = melhorou, vermelho = piorou (em relação ao \(baseline == 0 ? "primeiro" : "anterior")).")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func cell(_ r: CompareRow, _ cols: [CompareColumn], _ i: Int, isBest: Bool) -> some View {
        if let v = cols[i].values[r.id] {
            let refIndex = baseline == 0 ? 0 : i - 1
            let ref = i > 0 ? cols[refIndex].values[r.id] : nil
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 2) {
                    Text(fmt(v, r)).font(.subheadline.bold().monospacedDigit())
                    if isBest { Text("🏆").font(.caption2) }
                }
                if let ref, abs(v - ref) > 0.0001 {
                    let d = v - ref
                    let good = r.higherIsBetter.map { $0 == (d > 0) }
                    Text("\(d > 0 ? "▲" : "▼") \(fmt(abs(d), r))\(ref != 0 ? " (\(Int((abs(d) / abs(ref) * 100).rounded()))%)" : "")")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(good == nil ? Color.secondary : (good! ? Theme.accent : Theme.danger))
                }
            }
            .frame(minWidth: 80, alignment: .leading)
        } else {
            Text("—").foregroundStyle(.tertiary).frame(minWidth: 80, alignment: .leading)
        }
    }

    private func fmt(_ v: Double, _ r: CompareRow) -> String { v.fmt(r.digits) }

    // MARK: Dados

    private func candidates(_ m: CompareMode) -> [CompareColumn] {
        switch m {
        case .weights: weightColumns()
        case .workouts: workoutColumns()
        case .food: foodColumns()
        case .mind: mindColumns()
        }
    }

    private func rows(_ m: CompareMode, _ cols: [CompareColumn]) -> [CompareRow] {
        let all: [CompareRow]
        switch m {
        case .weights: all = Self.weightRows
        case .workouts: all = Self.workoutRows + workoutExtraRows(cols)
        case .food: all = Self.foodRows
        case .mind: all = Self.mindRows
        }
        return all.filter { r in cols.contains { $0.values[r.id] != nil } }
    }

    // Pesagens

    private static let weightMetrics: [(MetricID, String)] = [
        (.weight, "Composição"), (.bodyFat, "Composição"), (.fatMass, "Composição"), (.lbm, "Composição"),
        (.visceralFat, "Composição"), (.waterPercent, "Composição"), (.bmi, "Composição"),
        (.smm, "Músculo e osso"), (.smmPercent, "Músculo e osso"), (.muscleMass, "Músculo e osso"), (.bone, "Músculo e osso"),
        (.ffmi, "Músculo e osso"), (.proteinPercent, "Músculo e osso"),
        (.bmr, "Metabolismo"), (.tdee, "Metabolismo"), (.metabolicAge, "Metabolismo"), (.bodyScore, "Metabolismo"),
        (.mWaist, "Medidas"), (.mAbdomen, "Medidas"), (.mHip, "Medidas"), (.mChest, "Medidas"), (.mArmR, "Medidas"),
        (.mThighR, "Medidas"), (.whtr, "Medidas"),
    ]

    private static var weightRows: [CompareRow] {
        weightMetrics.map { id, g in
            CompareRow(id: id.rawValue, title: id.title, unit: id.unit, digits: id.digits,
                       higherIsBetter: id == .weight ? nil : id.higherIsBetter, group: g)
        }
    }

    private func weightColumns() -> [CompareColumn] {
        guard let ctx = AnalysisContext(profile: profiles.first, entries: weights, measurements: measurements) else {
            return weights.map { e in
                CompareColumn(id: "w\(e.date.timeIntervalSince1970)", date: e.date, title: e.date.formatted(.dateTime.day().month(.abbreviated)),
                              subtitle: e.date.formatted(.dateTime.year().hour().minute()), values: ["weight": e.kg])
            }
        }
        return weights.map { e in
            let a = ctx.analysis(e)
            var v: [String: Double] = [:]
            for (id, _) in Self.weightMetrics { if let m = a[id], m.value.isFinite, m.value != 0 { v[id.rawValue] = m.value } }
            v["weight"] = e.kg
            return CompareColumn(id: "w\(e.date.timeIntervalSince1970)", date: e.date,
                                 title: e.date.formatted(.dateTime.day().month(.abbreviated)),
                                 subtitle: "\(e.kg.fmt(1)) kg · \(e.date.formatted(.dateTime.hour().minute()))", values: v)
        }
    }

    // Treinos

    private static let workoutRows: [CompareRow] = [
        CompareRow(id: "minutes", title: "Duração", unit: "min", digits: 0, group: "Sessão"),
        CompareRow(id: "exercises", title: "Exercícios", unit: "", digits: 0, group: "Sessão"),
        CompareRow(id: "sets", title: "Séries válidas", unit: "", digits: 0, higherIsBetter: true, group: "Sessão"),
        CompareRow(id: "reps", title: "Repetições", unit: "", digits: 0, higherIsBetter: true, group: "Sessão"),
        CompareRow(id: "volume", title: "Volume (carga × reps)", unit: "kg", digits: 0, higherIsBetter: true, group: "Sessão"),
        CompareRow(id: "density", title: "Densidade", unit: "kg/min", digits: 0, higherIsBetter: true, group: "Sessão"),
        CompareRow(id: "avgKg", title: "Carga média por série", unit: "kg", digits: 1, higherIsBetter: true, group: "Sessão"),
        CompareRow(id: "kcal", title: "Calorias", unit: "kcal", digits: 0, higherIsBetter: true, group: "Sessão"),
        CompareRow(id: "rpe", title: "RPE médio", unit: "", digits: 1, group: "Sessão"),
        CompareRow(id: "rating", title: "Como se sentiu", unit: "1–5", digits: 0, higherIsBetter: true, group: "Sessão"),
        CompareRow(id: "bodyKg", title: "Peso corporal", unit: "kg", digits: 1, group: "Sessão"),
    ]

    private func workoutColumns() -> [CompareColumn] {
        sessions.filter { !$0.isActive }.map { s in
            let ex = s.exercises
            let work = ex.flatMap(\.workSets)
            var v: [String: Double] = [
                "minutes": s.duration / 60,
                "exercises": Double(ex.filter { !$0.doneSets.isEmpty }.count),
                "sets": Double(work.count),
                "reps": Double(work.map(\.reps).reduce(0, +)),
                "volume": WorkoutMath.volume(s),
                "kcal": WorkoutMath.kcal(s),
                "bodyKg": s.bodyKg,
            ]
            if s.duration > 60 { v["density"] = WorkoutMath.volume(s) / (s.duration / 60) }
            let loaded = work.filter { $0.kg > 0 }
            if !loaded.isEmpty { v["avgKg"] = loaded.map(\.kg).reduce(0, +) / Double(loaded.count) }
            let rpes = work.compactMap(\.rpe)
            if !rpes.isEmpty { v["rpe"] = rpes.reduce(0, +) / Double(rpes.count) }
            if s.rating > 0 { v["rating"] = Double(s.rating) }
            for (m, n) in WorkoutMath.muscleSets([s]) where n > 0 { v["mus-\(m.rawValue)"] = n }
            for e in ex {
                guard let best = e.workSets.max(by: { $0.e1RM < $1.e1RM }), best.e1RM > 0 else { continue }
                v["e1rm-\(e.exerciseID)"] = max(v["e1rm-\(e.exerciseID)"] ?? 0, best.e1RM)
                v["top-\(e.exerciseID)"] = max(v["top-\(e.exerciseID)"] ?? 0, e.workSets.map(\.kg).max() ?? 0)
            }
            return CompareColumn(id: "s\(s.start.timeIntervalSince1970)", date: s.start, title: s.name,
                                 subtitle: s.start.formatted(.dateTime.day().month(.abbreviated).hour().minute()), values: v)
        }
    }

    private func workoutExtraRows(_ cols: [CompareColumn]) -> [CompareRow] {
        var out: [CompareRow] = []
        for m in Muscle.allCases where cols.contains(where: { $0.values["mus-\(m.rawValue)"] != nil }) {
            out.append(CompareRow(id: "mus-\(m.rawValue)", title: m.label, unit: "séries", digits: 1, higherIsBetter: true, group: "Séries por músculo"))
        }
        // Exercícios presentes em pelo menos 2 dos treinos selecionados.
        var count: [String: Int] = [:]
        for c in cols { for k in c.values.keys where k.hasPrefix("e1rm-") { count[k, default: 0] += 1 } }
        for (k, n) in count.sorted(by: { $0.key < $1.key }) where n >= 2 {
            let id = String(k.dropFirst(5))
            let name = ExerciseCatalog.byID[id]?.name ?? id
            out.append(CompareRow(id: k, title: "\(name): 1RM estimado", unit: "kg", digits: 1, higherIsBetter: true, group: "Exercícios em comum"))
            out.append(CompareRow(id: "top-\(id)", title: "\(name): maior carga", unit: "kg", digits: 1, higherIsBetter: true, group: "Exercícios em comum"))
        }
        return out
    }

    // Alimentação

    private static var foodRows: [CompareRow] {
        var r: [CompareRow] = [
            CompareRow(id: "kcal", title: "Calorias", unit: "kcal", digits: 0, group: "Resumo"),
            CompareRow(id: "pctKcal", title: "% da meta de calorias", unit: "%", digits: 0, group: "Resumo"),
            CompareRow(id: "water", title: "Água", unit: "ml", digits: 0, higherIsBetter: true, group: "Resumo"),
            CompareRow(id: "items", title: "Alimentos registrados", unit: "", digits: 0, group: "Resumo"),
            CompareRow(id: "meals", title: "Refeições", unit: "", digits: 0, group: "Resumo"),
            CompareRow(id: "pctP", title: "Proteína (% das kcal)", unit: "%", digits: 0, group: "Distribuição"),
            CompareRow(id: "pctC", title: "Carboidratos (% das kcal)", unit: "%", digits: 0, group: "Distribuição"),
            CompareRow(id: "pctF", title: "Gorduras (% das kcal)", unit: "%", digits: 0, group: "Distribuição"),
        ]
        for id in NutrientID.allCases {
            r.append(CompareRow(id: id.rawValue, title: id.title, unit: id.unit, digits: id.unit == "g" ? 1 : (id.unit == "µg" ? 1 : 0),
                                higherIsBetter: id.kind == .limit ? false : (id.group == .macros && id != .protein && id != .fiber ? nil : true),
                                group: id.group.rawValue))
        }
        return r
    }

    private func foodColumns() -> [CompareColumn] {
        let target = NutrientContext.make(profiles.first, weights, measurements).targets.kcal
        let byDay = Dictionary(grouping: foodLogs) { cal.startOfDay(for: $0.date) }
        let water = Dictionary(grouping: waterLogs) { cal.startOfDay(for: $0.date) }.mapValues { $0.map(\.ml).reduce(0, +) }
        return byDay.map { day, logs in
            let n = logs.map(\.nutrients).total, m = logs.compactMap(\.micros).total, e = logs.map(\.extras).total
            var v: [String: Double] = [
                "kcal": n.kcal, "items": Double(logs.count), "meals": Double(Set(logs.map(\.mealRaw)).count),
            ]
            if target > 0 { v["pctKcal"] = n.kcal / target * 100 }
            if let w = water[day] { v["water"] = w }
            if n.kcal > 0 {
                v["pctP"] = n.protein * 4 / n.kcal * 100
                v["pctC"] = n.carbs * 4 / n.kcal * 100
                v["pctF"] = n.fat * 9 / n.kcal * 100
            }
            for id in NutrientID.allCases { let x = id.value(n, m, e); if x > 0 { v[id.rawValue] = x } }
            return CompareColumn(id: "f\(day.timeIntervalSince1970)", date: day,
                                 title: day.formatted(.dateTime.day().month(.abbreviated)),
                                 subtitle: "\(day.formatted(.dateTime.weekday(.abbreviated))) · \(Int(n.kcal)) kcal", values: v)
        }
    }

    // Mente

    private static let mindRows: [CompareRow] = [
        CompareRow(id: "mood", title: "Humor", unit: "1–5", digits: 1, higherIsBetter: true, group: "Humor"),
        CompareRow(id: "energy", title: "Energia", unit: "1–5", digits: 1, higherIsBetter: true, group: "Humor"),
        CompareRow(id: "stress", title: "Estresse", unit: "1–5", digits: 1, higherIsBetter: false, group: "Humor"),
        CompareRow(id: "anxiety", title: "Ansiedade", unit: "1–5", digits: 1, higherIsBetter: false, group: "Humor"),
        CompareRow(id: "checkins", title: "Registros de humor", unit: "", digits: 0, group: "Humor"),
        CompareRow(id: "sleepH", title: "Sono", unit: "h", digits: 1, higherIsBetter: true, group: "Sono"),
        CompareRow(id: "sleepQ", title: "Qualidade do sono", unit: "1–5", digits: 0, higherIsBetter: true, group: "Sono"),
        CompareRow(id: "wakeups", title: "Despertares", unit: "", digits: 0, higherIsBetter: false, group: "Sono"),
        CompareRow(id: "practice", title: "Práticas (respiração, meditação…)", unit: "min", digits: 0, higherIsBetter: true, group: "Práticas"),
        CompareRow(id: "trained", title: "Treinou", unit: "sim=1", digits: 0, group: "Práticas"),
    ]

    private func mindColumns() -> [CompareColumn] {
        let moodDay = Dictionary(grouping: moods) { cal.startOfDay(for: $0.date) }
        let sleepDay = Dictionary(grouping: sleeps, by: \.day)
        let practiceDay = Dictionary(grouping: practices) { cal.startOfDay(for: $0.date) }
        let trainedDays = Set(sessions.map { cal.startOfDay(for: $0.start) })
        let days = Set(moodDay.keys).union(sleepDay.keys).union(practiceDay.keys)
        return days.map { day in
            var v: [String: Double] = [:]
            if let ms = moodDay[day], !ms.isEmpty {
                let c = Double(ms.count)
                v["mood"] = Double(ms.map(\.mood).reduce(0, +)) / c
                v["energy"] = Double(ms.map(\.energy).reduce(0, +)) / c
                v["stress"] = Double(ms.map(\.stress).reduce(0, +)) / c
                v["anxiety"] = Double(ms.map(\.anxiety).reduce(0, +)) / c
                v["checkins"] = c
            }
            if let s = sleepDay[day], !s.isEmpty {
                v["sleepH"] = s.map(\.hours).reduce(0, +)
                v["sleepQ"] = Double(s.map(\.quality).max() ?? 0)
                v["wakeups"] = Double(s.map(\.awakenings).reduce(0, +))
            }
            if let p = practiceDay[day] { v["practice"] = p.map(\.seconds).reduce(0, +) / 60 }
            v["trained"] = trainedDays.contains(day) ? 1 : 0
            let moodTxt = v["mood"].map { "humor \($0.fmt(1))" } ?? (v["sleepH"].map { "sono \($0.fmt(1)) h" } ?? "")
            return CompareColumn(id: "m\(day.timeIntervalSince1970)", date: day,
                                 title: day.formatted(.dateTime.day().month(.abbreviated)),
                                 subtitle: "\(day.formatted(.dateTime.weekday(.abbreviated))) · \(moodTxt)", values: v)
        }
    }
}

// MARK: - Seleção livre

struct ComparePickerSheet: View {
    let mode: CompareMode
    let candidates: [CompareColumn]
    @Binding var selection: Set<String>
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    var body: some View {
        let list = candidates.sorted { $0.date > $1.date }.filter {
            query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) || $0.subtitle.localizedCaseInsensitiveContains(query)
        }
        let months = Dictionary(grouping: list) { Calendar.current.dateInterval(of: .month, for: $0.date)?.start ?? $0.date }
        NavigationStack {
            List {
                ForEach(months.keys.sorted(by: >), id: \.self) { month in
                    Section(month.formatted(.dateTime.month(.wide).year())) {
                        ForEach(months[month] ?? []) { c in
                            Button { toggle(c.id) } label: {
                                HStack {
                                    Image(systemName: selection.contains(c.id) ? "checkmark.circle.fill" : "circle")
                                        .font(.title3).foregroundStyle(selection.contains(c.id) ? Theme.accent : .secondary)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(c.title).font(.subheadline.bold()).foregroundStyle(.primary)
                                        Text(c.subtitle).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $query, prompt: "Buscar")
            .navigationTitle("Escolher \(mode.noun)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Limpar") { selection = [] }.disabled(selection.isEmpty)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Comparar (\(selection.count))") { dismiss() }.bold()
                }
            }
            .sensoryFeedback(.selection, trigger: selection.count)
        }
    }

    private func toggle(_ id: String) {
        if selection.contains(id) { selection.remove(id) } else { selection.insert(id) }
    }
}
