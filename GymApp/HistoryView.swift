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

struct HistoryView: View {
    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]
    @Query(sort: \WeightEntry.date) private var all: [WeightEntry]
    @State private var range: HistoryRange = .month
    @State private var selectedDate: Date?
    @State private var showAdd = false

    private var entries: [WeightEntry] {
        guard let d = range.days,
              let start = Calendar.current.date(byAdding: .day, value: -d, to: .now) else { return all }
        return all.filter { $0.date >= start }
    }

    var body: some View {
        NavigationStack {
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
                            chartCard
                            statsGrid
                            listCard
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Histórico")
            .toolbar {
                Button { showAdd = true } label: { Image(systemName: "plus.circle.fill") }
            }
            .sheet(isPresented: $showAdd) { AddWeightSheet() }
        }
    }

    // MARK: Gráfico

    private var selected: WeightEntry? {
        guard let selectedDate else { return nil }
        return entries.min { abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate)) }
    }

    private var chartCard: some View {
        let kgs = entries.map(\.kg) + (profiles.first.map { [$0.goalWeightKg] } ?? [])
        let lo = (kgs.min() ?? 0) - 1, hi = (kgs.max() ?? 0) + 1
        return Card {
            VStack(alignment: .leading, spacing: 8) {
                if let s = selected {
                    Text("\(s.kg.fmt(2)) kg").font(.title.bold()).contentTransition(.numericText())
                    Text(s.date, format: .dateTime.day().month().year().hour().minute())
                        .font(.caption).foregroundStyle(.secondary)
                } else if let last = entries.last {
                    Text("\(last.kg.fmt(2)) kg").font(.title.bold()).contentTransition(.numericText())
                    Text("Toque e arraste no gráfico").font(.caption).foregroundStyle(.secondary)
                }
                Chart {
                    ForEach(entries) { e in
                        AreaMark(x: .value("Data", e.date), yStart: .value("Base", lo), yEnd: .value("Peso", e.kg))
                            .foregroundStyle(LinearGradient(colors: [Theme.accent.opacity(0.3), .clear],
                                                            startPoint: .top, endPoint: .bottom))
                            .interpolationMethod(.monotone)
                        LineMark(x: .value("Data", e.date), y: .value("Peso", e.kg))
                            .foregroundStyle(Theme.gradient)
                            .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                            .interpolationMethod(.monotone)
                        if entries.count < 40 {
                            PointMark(x: .value("Data", e.date), y: .value("Peso", e.kg))
                                .foregroundStyle(Theme.accent)
                                .symbolSize(30)
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
                        RuleMark(x: .value("Selecionado", s.date))
                            .foregroundStyle(.secondary.opacity(0.5))
                    }
                }
                .chartYScale(domain: lo...hi)
                .chartXSelection(value: $selectedDate)
                .frame(height: 240)
                .animation(.spring(duration: 0.6), value: range)
            }
        }
    }

    // MARK: Estatísticas

    private var statsGrid: some View {
        let kgs = entries.map(\.kg)
        let first = entries.first!, last = entries.last!
        let change = last.kg - first.kg
        let days = max(1, last.date.timeIntervalSince(first.date) / 86400)
        let perWeek = change / days * 7
        let avg = kgs.reduce(0, +) / Double(kgs.count)
        let cols = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
        return LazyVGrid(columns: cols, spacing: 12) {
            MetricTile(title: "Variação no período", value: "\(change >= 0 ? "+" : "")\(change.fmt(2))",
                       unit: "kg", icon: change <= 0 ? "arrow.down.right" : "arrow.up.right",
                       tint: change <= 0 ? Theme.accent : Theme.warm)
            MetricTile(title: "Ritmo semanal", value: "\(perWeek >= 0 ? "+" : "")\(perWeek.fmt(2))",
                       unit: "kg/sem", icon: "speedometer", tint: Theme.accent2,
                       caption: abs(perWeek) > 1 ? "Ritmo acelerado" : "Ritmo sustentável")
            MetricTile(title: "Média", value: avg.fmt(2), unit: "kg", icon: "equal.circle", tint: .purple)
            MetricTile(title: "Pesagens", value: "\(kgs.count)", icon: "checkmark.circle", tint: .teal,
                       caption: "\(Set(entries.map { Calendar.current.startOfDay(for: $0.date) }).count) dias")
            MetricTile(title: "Mínimo", value: (kgs.min() ?? 0).fmt(2), unit: "kg",
                       icon: "arrow.down.to.line", tint: Theme.accent)
            MetricTile(title: "Máximo", value: (kgs.max() ?? 0).fmt(2), unit: "kg",
                       icon: "arrow.up.to.line", tint: Theme.danger)
            if let p = profiles.first {
                let remaining = last.kg - p.goalWeightKg
                MetricTile(title: "Falta para a meta", value: abs(remaining).fmt(1), unit: "kg",
                           icon: "flag.checkered", tint: Theme.warm,
                           caption: eta(remaining: remaining, perWeek: perWeek))
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

    // MARK: Lista

    private var listCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 0) {
                Text("Pesagens").font(.headline).padding(.bottom, 8)
                let rev = Array(entries.reversed())
                ForEach(Array(rev.enumerated()), id: \.element.id) { i, e in
                    let prev = i + 1 < rev.count ? rev[i + 1].kg : nil
                    HStack {
                        Image(systemName: e.source == "manual" ? "pencil.circle.fill" : "scalemass.fill")
                            .foregroundStyle(e.source == "manual" ? Theme.accent2 : Theme.accent)
                        VStack(alignment: .leading) {
                            Text(e.date, format: .dateTime.day().month(.abbreviated).hour().minute())
                                .font(.subheadline)
                        }
                        Spacer()
                        if let prev {
                            let d = e.kg - prev
                            Text("\(d >= 0 ? "+" : "")\(d.fmt(2))")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(d <= 0 ? Theme.accent : Theme.warm)
                        }
                        Text("\(e.kg.fmt(2)) kg").font(.subheadline.bold().monospacedDigit())
                    }
                    .padding(.vertical, 10)
                    .contextMenu {
                        Button("Apagar", systemImage: "trash", role: .destructive) {
                            withAnimation { context.delete(e) }
                        }
                    }
                    if i < rev.count - 1 { Divider() }
                }
                Text("Toque e segure numa pesagem para apagar.")
                    .font(.caption2).foregroundStyle(.secondary).padding(.top, 8)
            }
        }
    }
}

struct AddWeightSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \WeightEntry.date, order: .reverse) private var entries: [WeightEntry]
    @State private var kg: Double = 70
    @State private var date = Date.now

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
                    Stepper("Ajustar", value: $kg.animation(.snappy), in: 20...300, step: 0.1)
                }
                DatePicker("Data", selection: $date, in: ...Date.now)
            }
            .navigationTitle("Adicionar peso")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        context.insert(WeightEntry(date: date, kg: kg, source: "manual"))
                        dismiss()
                    }
                }
            }
            .onAppear { if let k = entries.first?.kg { kg = k } }
        }
        .presentationDetents([.medium])
    }
}
