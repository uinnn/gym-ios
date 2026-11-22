import SwiftUI
import SwiftData
import Charts

enum HistoryRange: String, CaseIterable, Identifiable {
    case week = "7D", month = "30D", quarter = "90D", year = "1A", all = "Tudo"
    var id: String { rawValue }
    var days: Int? {
        switch self {
        case .week: 7
        case .month: 30
        case .quarter: 90
        case .year: 365
        case .all: nil
        }
    }
}

enum HistoryGrouping: String, CaseIterable, Identifiable {
    case each = "Pesagens", week = "Semanas", month = "Meses"
    var id: String { rawValue }
}

struct HistoryView: View {
    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]
    @Query(sort: \WeightEntry.date) private var all: [WeightEntry]
    @State private var range: HistoryRange = .month
    @State private var grouping: HistoryGrouping = .each
    @State private var selectedDate: Date?
    @State private var showAdd = false
    @State private var report: WeightEntry?
    private var store: ThemeStore { ThemeStore.shared }

    private var entries: [WeightEntry] {
        guard let d = range.days,
              let start = Calendar.current.date(byAdding: .day, value: -d, to: .now) else { return all }
        return all.filter { $0.date >= start }
    }

    var body: some View {
        Group {
            ZStack {
                AnimatedBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        Picker("Período", selection: $range.animation(.spring)) {
                            ForEach(HistoryRange.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)

                        if entries.isEmpty {
                            ContentUnavailableView("Sem pesagens neste período",
                                                   systemImage: "chart.xyaxis.line",
                                                   description: Text("Suba na balança ou adicione um peso manualmente."))
                                .padding(.top, 40)
                        } else {
                            chartCard.appear()
                            streakCard.appear(0.05)
                            statsGrid.appear(0.1)
                            heatmapCard.appear(0.15)
                            listCard.appear(0.2)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Histórico")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    ShareLink(item: csvFile, preview: SharePreview("Pesagens.csv")) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(all.isEmpty)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAdd = true } label: { Image(systemName: "plus.circle.fill") }
                }
            }
            .sheet(isPresented: $showAdd) { AddWeightSheet() }
            .sheet(item: $report) { ReportView(entry: $0) }
        }
    }

    // MARK: Gráfico

    private var selected: WeightEntry? {
        guard let selectedDate else { return nil }
        return entries.min { abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate)) }
    }

    /// Média móvel de 7 dias (por data, não por número de pesagens).
    /// Janela deslizante sobre a lista ordenada: O(n) em vez de O(n²).
    private var movingAverage: [(date: Date, kg: Double)] {
        let list = all
        guard let firstDate = entries.first?.date else { return [] }
        var out: [(date: Date, kg: Double)] = []
        var lo = 0, sum = 0.0, hi = 0
        for e in list where e.date <= (entries.last?.date ?? .distantFuture) {
            sum += e.kg; hi += 1
            while list[lo].date <= e.date.addingTimeInterval(-7 * 86400) { sum -= list[lo].kg; lo += 1 }
            if e.date >= firstDate { out.append((e.date, sum / Double(hi - lo))) }
        }
        return out
    }

    private var chartCard: some View {
        let kgs = entries.map(\.kg) + (profiles.first.map { [$0.goalWeightKg] } ?? [])
        let lo = (kgs.min() ?? 0) - 1, hi = (kgs.max() ?? 0) + 1
        return Card {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    if let s = selected {
                        VStack(alignment: .leading) {
                            Text("\(s.kg.fmt(2)) kg").font(.title.bold()).contentTransition(.numericText())
                            Text(s.date, format: .dateTime.day().month().year().hour().minute())
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    } else if let last = entries.last {
                        VStack(alignment: .leading) {
                            Text("\(last.kg.fmt(2)) kg").font(.title.bold()).contentTransition(.numericText())
                            Text("Toque e arraste no gráfico").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Button {
                        withAnimation(.spring) { store.showMovingAverage.toggle() }
                    } label: {
                        Label("Média 7d", systemImage: store.showMovingAverage ? "checkmark.circle.fill" : "circle")
                            .font(.caption.bold())
                    }
                    .buttonStyle(.bordered).tint(Theme.accent2)
                }
                Chart {
                    ForEach(entries) { e in
                        AreaMark(x: .value("Data", e.date), yStart: .value("Base", lo), yEnd: .value("Peso", e.kg))
                            .foregroundStyle(LinearGradient(colors: [Theme.accent.opacity(0.3), .clear],
                                                            startPoint: .top, endPoint: .bottom))
                            .interpolationMethod(.monotone)
                        LineMark(x: .value("Data", e.date), y: .value("Peso", e.kg), series: .value("S", "Peso"))
                            .foregroundStyle(Theme.accent)
                            .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                            .interpolationMethod(.monotone)
                        if entries.count < 40 {
                            PointMark(x: .value("Data", e.date), y: .value("Peso", e.kg))
                                .foregroundStyle(Theme.accent).symbolSize(30)
                        }
                    }
                    if store.showMovingAverage && entries.count >= 3 {
                        ForEach(Array(movingAverage.enumerated()), id: \.offset) { _, p in
                            LineMark(x: .value("Data", p.date), y: .value("Peso", p.kg), series: .value("S", "Média"))
                                .foregroundStyle(Theme.accent2)
                                .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 3]))
                                .interpolationMethod(.monotone)
                        }
                    }
                    if let goal = profiles.first?.goalWeightKg {
                        RuleMark(y: .value("Meta", goal))
                            .foregroundStyle(Theme.warm)
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                            .annotation(position: .top, alignment: .leading) {
                                Text("Meta \(goal.fmt()) kg").font(.caption2.bold()).foregroundStyle(Theme.warm)
                            }
                    }
                    if let s = selected {
                        RuleMark(x: .value("Selecionado", s.date)).foregroundStyle(.secondary.opacity(0.5))
                    }
                }
                .chartYScale(domain: lo...hi)
                .chartXSelection(value: $selectedDate)
                .frame(height: 240)
                .animation(.spring(duration: 0.6), value: range)
            }
        }
    }

    // MARK: Sequência

    private var streak: (current: Int, best: Int, weekDays: Int) {
        let cal = Calendar.current
        let days = Set(all.map { cal.startOfDay(for: $0.date) })
        var current = 0
        var d = cal.startOfDay(for: .now)
        if !days.contains(d) { d = cal.date(byAdding: .day, value: -1, to: d)! }
        while days.contains(d) { current += 1; d = cal.date(byAdding: .day, value: -1, to: d)! }
        var best = 0, run = 0
        var prev: Date?
        for day in days.sorted() {
            if let p = prev, cal.dateComponents([.day], from: p, to: day).day == 1 { run += 1 } else { run = 1 }
            best = max(best, run); prev = day
        }
        let weekStart = cal.date(byAdding: .day, value: -6, to: cal.startOfDay(for: .now))!
        return (current, best, days.filter { $0 >= weekStart }.count)
    }

    private var streakCard: some View {
        let s = streak
        return Card {
            HStack(spacing: 0) {
                streakItem("flame.fill", "\(s.current)", "dias seguidos", Theme.warm)
                Divider().frame(height: 40)
                streakItem("trophy.fill", "\(s.best)", "recorde", Theme.excellent)
                Divider().frame(height: 40)
                streakItem("calendar", "\(s.weekDays)/7", "esta semana", Theme.accent)
            }
        }
    }

    private func streakItem(_ icon: String, _ value: String, _ label: String, _ tint: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).foregroundStyle(tint).symbolEffect(.bounce, value: value)
            Text(value).font(.title3.bold()).contentTransition(.numericText())
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Estatísticas

    private var statsGrid: some View {
        let kgs = entries.map(\.kg)
        let first = entries.first!, last = entries.last!
        let change = last.kg - first.kg
        let days = max(1, last.date.timeIntervalSince(first.date) / 86400)
        let perWeek = change / days * 7
        let avg = kgs.reduce(0, +) / Double(kgs.count)
        let sd = sqrt(kgs.map { pow($0 - avg, 2) }.reduce(0, +) / Double(kgs.count))
        let diffs = zip(kgs.dropFirst(), kgs).map { abs($0 - $1) }
        let avgSwing = diffs.isEmpty ? 0 : diffs.reduce(0, +) / Double(diffs.count)
        let cols = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
        return LazyVGrid(columns: cols, spacing: 12) {
            MetricTile(title: "Variação no período", value: change.signed(2), unit: "kg",
                       icon: change <= 0 ? "arrow.down.right" : "arrow.up.right",
                       tint: change <= 0 ? Theme.accent : Theme.warm)
            MetricTile(title: "Ritmo semanal", value: perWeek.signed(2), unit: "kg/sem",
                       icon: "speedometer", tint: Theme.accent2,
                       caption: abs(perWeek / avg) > 0.01 ? "Acelerado (>1%/sem)" : "Sustentável")
            MetricTile(title: "Média", value: avg.fmt(2), unit: "kg", icon: "equal.circle", tint: .purple)
            MetricTile(title: "Desvio padrão", value: sd.fmt(2), unit: "kg", icon: "waveform.path.ecg", tint: .pink,
                       caption: sd < 0.7 ? "Peso estável" : "Bastante variação")
            MetricTile(title: "Oscilação média", value: avgSwing.fmt(2), unit: "kg", icon: "arrow.up.arrow.down",
                       tint: .indigo, caption: "entre pesagens")
            MetricTile(title: "Pesagens", value: "\(kgs.count)", icon: "checkmark.circle", tint: .teal,
                       caption: "\(Set(entries.map { Calendar.current.startOfDay(for: $0.date) }).count) dias")
            MetricTile(title: "Mínimo", value: (kgs.min() ?? 0).fmt(2), unit: "kg",
                       icon: "arrow.down.to.line", tint: Theme.good)
            MetricTile(title: "Máximo", value: (kgs.max() ?? 0).fmt(2), unit: "kg",
                       icon: "arrow.up.to.line", tint: Theme.danger)
            if let p = profiles.first {
                let remaining = last.kg - p.goalWeightKg
                MetricTile(title: "Falta para a meta", value: abs(remaining).fmt(1), unit: "kg",
                           icon: "flag.checkered", tint: Theme.warm,
                           caption: eta(remaining: remaining, perWeek: perWeek))
                MetricTile(title: "Energia acumulada", value: (change * 7700).fmt(0), unit: "kcal",
                           icon: "bolt.fill", tint: .orange, caption: change < 0 ? "de déficit estimado" : "de superávit estimado")
            }
        }
    }

    private func eta(remaining: Double, perWeek: Double) -> String {
        if abs(remaining) < 0.3 { return "Meta atingida! 🎉" }
        guard perWeek != 0, (remaining > 0) == (perWeek < 0) else { return "Mantenha a constância" }
        let weeks = abs(remaining / perWeek)
        guard weeks < 260, let d = Calendar.current.date(byAdding: .day, value: Int(weeks * 7), to: .now)
        else { return "Mantenha a constância" }
        return "Previsão: \(d.formatted(.dateTime.month(.abbreviated).year()))"
    }

    // MARK: Mapa de calor

    private var heatmapCard: some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let weeks = 18
        let weekday = (cal.component(.weekday, from: today) + 5) % 7      // segunda = 0
        let start = cal.date(byAdding: .day, value: -(weeks - 1) * 7 - weekday, to: today)!
        let counts = Dictionary(grouping: all, by: { cal.startOfDay(for: $0.date) }).mapValues(\.count)
        return Card {
            VStack(alignment: .leading, spacing: 10) {
                Text("Constância").font(.headline)
                HStack(alignment: .top, spacing: 3) {
                    ForEach(0..<weeks, id: \.self) { w in
                        VStack(spacing: 3) {
                            ForEach(0..<7, id: \.self) { d in
                                let day = cal.date(byAdding: .day, value: w * 7 + d, to: start)!
                                let n = counts[day] ?? 0
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(day > today ? Color.clear : (n == 0 ? Color.secondary.opacity(0.15)
                                                                       : Theme.accent.opacity(min(1, 0.45 + Double(n) * 0.25))))
                                    .aspectRatio(1, contentMode: .fit)
                            }
                        }
                    }
                }
                HStack {
                    Text("\(weeks) semanas").font(.caption2).foregroundStyle(.secondary)
                    Spacer()
                    Text("Menos").font(.caption2).foregroundStyle(.secondary)
                    ForEach([0.15, 0.5, 0.75, 1.0], id: \.self) { o in
                        RoundedRectangle(cornerRadius: 2).fill(o == 0.15 ? Color.secondary.opacity(o) : Theme.accent.opacity(o))
                            .frame(width: 10, height: 10)
                    }
                    Text("Mais").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: Lista

    private struct WeightGroup: Identifiable {
        let id: Date
        let title: String
        let avg: Double, min: Double, max: Double, count: Int
    }

    private func groups(_ comp: Calendar.Component) -> [WeightGroup] {
        let cal = Calendar.current
        let dict = Dictionary(grouping: entries) { cal.dateInterval(of: comp, for: $0.date)!.start }
        return dict.map { start, list in
            let kgs = list.map(\.kg)
            let title = comp == .month
                ? start.formatted(.dateTime.month(.wide).year())
                : "Semana de \(start.formatted(.dateTime.day().month(.abbreviated)))"
            return WeightGroup(id: start, title: title, avg: kgs.reduce(0, +) / Double(kgs.count),
                         min: kgs.min()!, max: kgs.max()!, count: kgs.count)
        }
        .sorted { $0.id > $1.id }
    }

    private var listCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 0) {
                Picker("Agrupar", selection: $grouping.animation(.spring)) {
                    ForEach(HistoryGrouping.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.bottom, 10)
                switch grouping {
                case .each: eachList
                case .week: groupList(groups(.weekOfYear))
                case .month: groupList(groups(.month))
                }
            }
        }
    }

    @ViewBuilder private var eachList: some View {
        let rev = Array(entries.reversed())
        ForEach(Array(rev.enumerated()), id: \.element.id) { i, e in
            let prev = i + 1 < rev.count ? rev[i + 1].kg : nil
            Button { report = e } label: {
                HStack {
                    Image(systemName: e.source == "manual" ? "pencil.circle.fill" : "scalemass.fill")
                        .foregroundStyle(e.source == "manual" ? Theme.accent2 : Theme.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(e.date, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute())
                            .font(.subheadline)
                        if !e.tags.isEmpty || !e.note.isEmpty {
                            HStack(spacing: 4) {
                                ForEach(Array(e.tags), id: \.self) { Image(systemName: $0.icon) }
                                if !e.note.isEmpty { Text(e.note).lineLimit(1) }
                            }
                            .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if let prev {
                        let d = e.kg - prev
                        Text(d.signed(2)).font(.caption.monospacedDigit())
                            .foregroundStyle(d <= 0 ? Theme.good : Theme.warm)
                    }
                    Text("\(e.kg.fmt(2)) kg").font(.subheadline.bold().monospacedDigit())
                    Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
                }
                .foregroundStyle(.primary)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button("Ver relatório", systemImage: "doc.text.magnifyingglass") { report = e }
                Button("Apagar", systemImage: "trash", role: .destructive) {
                    withAnimation { context.delete(e) }
                }
            }
            if i < rev.count - 1 { Divider() }
        }
        Text("Toque para ver o relatório; toque e segure para apagar.")
            .font(.caption2).foregroundStyle(.secondary).padding(.top, 8)
    }

    @ViewBuilder private func groupList(_ list: [WeightGroup]) -> some View {
        ForEach(Array(list.enumerated()), id: \.element.id) { i, g in
            let next = i + 1 < list.count ? list[i + 1].avg : nil
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(g.title).font(.subheadline)
                    Text("\(g.count) pesagens · \(g.min.fmt(1))–\(g.max.fmt(1)) kg").font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                if let next {
                    let d = g.avg - next
                    Text(d.signed(2)).font(.caption.monospacedDigit()).foregroundStyle(d <= 0 ? Theme.good : Theme.warm)
                }
                Text("\(g.avg.fmt(2)) kg").font(.subheadline.bold().monospacedDigit())
            }
            .padding(.vertical, 10)
            if i < list.count - 1 { Divider() }
        }
    }

    // MARK: Exportar

    private var csvFile: URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("pesagens.csv")
        let df = ISO8601DateFormatter()
        var rows = ["data,peso_kg,origem,tags,nota"]
        for e in all {
            let note = e.note.replacingOccurrences(of: "\"", with: "'")
            rows.append("\(df.string(from: e.date)),\(e.kg),\(e.source),\(e.tagsRaw.replacingOccurrences(of: ",", with: "|")),\"\(note)\"")
        }
        try? rows.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}

struct AddWeightSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \WeightEntry.date, order: .reverse) private var entries: [WeightEntry]
    @State private var kg: Double = 70
    @State private var date = Date.now
    @State private var note = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        Text(kg.fmt(1)).font(.system(size: 56, weight: .bold, design: .rounded))
                            .contentTransition(.numericText(value: kg))
                        Text("kg").foregroundStyle(.secondary)
                        Spacer()
                    }
                    HStack {
                        ForEach([-1.0, -0.1, 0.1, 1.0], id: \.self) { step in
                            Button(step.signed(1)) { withAnimation(.snappy) { kg = max(20, kg + step) } }
                                .buttonStyle(.bordered)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
                DatePicker("Data", selection: $date, in: ...Date.now)
                TextField("Anotação (opcional)", text: $note)
            }
            .navigationTitle("Adicionar peso")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        let e = WeightEntry(date: date, kg: kg, source: "manual")
                        e.note = note
                        context.insert(e)
                        dismiss()
                    }
                }
            }
            .onAppear { if let k = entries.first?.kg { kg = k } }
        }
        .presentationDetents([.medium, .large])
    }
}
