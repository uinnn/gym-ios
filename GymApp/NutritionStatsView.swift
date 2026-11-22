import SwiftUI
import SwiftData
import Charts

struct NutritionStatsView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [UserProfile]
    @Query(sort: \WeightEntry.date) private var weights: [WeightEntry]
    @Query private var measurements: [MeasurementEntry]
    @Query(sort: \FoodLog.date) private var logs: [FoodLog]
    @Query(sort: \WaterLog.date) private var water: [WaterLog]
    @State private var days = 14

    private struct DayStat: Identifiable {
        let id: Date
        let n: Nutrients
        let water: Double
    }

    private var targets: NutritionTargets {
        guard let ctx = AnalysisContext(profile: profiles.first, entries: weights, measurements: measurements)
        else { return .fallback }
        return NutritionTargets(analysis: ctx.current)
    }

    private var formulaTDEE: Double? {
        AnalysisContext(profile: profiles.first, entries: weights, measurements: measurements)?.current.tdee
    }

    private var stats: [DayStat] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        return (0..<days).reversed().compactMap { i in
            guard let d = cal.date(byAdding: .day, value: -i, to: today) else { return nil }
            return DayStat(id: d, n: logs.filter { cal.isSameDay($0.date, d) }.map(\.nutrients).total,
                           water: water.filter { cal.isSameDay($0.date, d) }.map(\.ml).reduce(0, +))
        }
    }

    var body: some View {
        let s = stats, t = targets
        let logged = s.filter { $0.n.kcal > 0 }
        NavigationStack {
            ZStack {
                AnimatedBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        Picker("Período", selection: $days.animation(.spring)) {
                            Text("7 dias").tag(7); Text("14 dias").tag(14); Text("30 dias").tag(30)
                        }
                        .pickerStyle(.segmented)
                        if logged.isEmpty {
                            ContentUnavailableView("Sem registros", systemImage: "fork.knife",
                                                   description: Text("Registre refeições para ver suas estatísticas."))
                        } else {
                            kcalChart(s, t).appear()
                            summaryGrid(logged, t).appear(0.05)
                            macroSplit(logged).appear(0.1)
                            adaptiveCard.appear(0.15)
                            topFoods.appear(0.2)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Estatísticas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("OK") { dismiss() } }
        }
    }

    private func kcalChart(_ s: [DayStat], _ t: NutritionTargets) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Text("Calorias por dia").font(.headline)
                Chart {
                    ForEach(s) { d in
                        BarMark(x: .value("Dia", d.id, unit: .day), y: .value("kcal", d.n.kcal))
                            .foregroundStyle(abs(d.n.kcal - t.kcal) / t.kcal <= 0.1 ? Theme.good
                                             : (d.n.kcal > t.kcal ? Theme.warm : Theme.accent2))
                            .cornerRadius(4)
                    }
                    RuleMark(y: .value("Meta", t.kcal))
                        .foregroundStyle(Theme.warm).lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                        .annotation(position: .top, alignment: .leading) {
                            Text("Meta \(t.kcal.fmt(0))").font(.caption2.bold()).foregroundStyle(Theme.warm)
                        }
                }
                .frame(height: 200)
                HStack(spacing: 12) {
                    legend(Theme.good, "±10% da meta"); legend(Theme.warm, "Acima"); legend(Theme.accent2, "Abaixo")
                }
            }
        }
    }

    private func legend(_ c: Color, _ t: String) -> some View {
        HStack(spacing: 4) { Circle().fill(c).frame(width: 8, height: 8); Text(t).font(.caption2) }
    }

    private func summaryGrid(_ logged: [DayStat], _ t: NutritionTargets) -> some View {
        let n = Double(logged.count)
        let avg = logged.map(\.n).total.scaled(1 / n)
        let inRange = logged.filter { abs($0.n.kcal - t.kcal) / t.kcal <= 0.1 }.count
        let protHit = logged.filter { $0.n.protein >= t.protein * 0.9 }.count
        let waterAvg = logged.map(\.water).reduce(0, +) / n
        let fiberHit = logged.filter { $0.n.fiber >= t.fiber * 0.8 }.count
        let cols = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
        return LazyVGrid(columns: cols, spacing: 12) {
            MetricTile(title: "Média diária", value: avg.kcal.fmt(0), unit: "kcal", icon: "flame.fill", tint: Theme.warm,
                       caption: "\((avg.kcal - t.kcal).signed(0)) vs meta", progress: avg.kcal / t.kcal)
            MetricTile(title: "Dias na meta", value: "\(inRange)/\(logged.count)", icon: "target", tint: Theme.good,
                       caption: "\(Int(Double(inRange) / n * 100))% de aderência", progress: Double(inRange) / n)
            MetricTile(title: "Proteína média", value: avg.protein.fmt(0), unit: "g", icon: "fish.fill", tint: Theme.accent,
                       caption: "Meta batida em \(protHit) dias", progress: avg.protein / t.protein)
            MetricTile(title: "Fibras média", value: avg.fiber.fmt(0), unit: "g", icon: "leaf.fill", tint: Theme.good,
                       caption: "≥80% da meta em \(fiberHit) dias", progress: avg.fiber / t.fiber)
            MetricTile(title: "Água média", value: (waterAvg / 1000).fmt(2), unit: "L", icon: "drop.fill", tint: Theme.info,
                       progress: waterAvg / t.water)
            MetricTile(title: "Sódio médio", value: avg.sodium.fmt(0), unit: "mg", icon: "aqi.low",
                       tint: avg.sodium > t.sodiumMax ? Theme.danger : Theme.good,
                       caption: avg.sodium > t.sodiumMax ? "Acima do limite" : "Dentro do limite")
            MetricTile(title: "Dias registrados", value: "\(logged.count)", icon: "calendar", tint: .purple,
                       caption: "de \(days) dias")
            MetricTile(title: "Balanço do período", value: ((avg.kcal - (formulaTDEE ?? t.kcal)) * n).fmt(0), unit: "kcal",
                       icon: "plusminus.circle", tint: .indigo,
                       caption: "≈ \(((avg.kcal - (formulaTDEE ?? t.kcal)) * n / 7700).signed(2)) kg de gordura")
        }
    }

    private func macroSplit(_ logged: [DayStat]) -> some View {
        let tot = logged.map(\.n).total
        let kP = tot.protein * 4, kC = tot.carbs * 4, kF = tot.fat * 9
        let sum = max(kP + kC + kF, 1)
        let parts: [(String, Double, Color)] = [("Proteína", kP / sum, Theme.accent), ("Carboidrato", kC / sum, Theme.accent2),
                                                ("Gordura", kF / sum, Theme.warm)]
        return Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("Distribuição de macros").font(.headline)
                HStack(spacing: 20) {
                    Chart(parts, id: \.0) { p in
                        SectorMark(angle: .value("%", p.1), innerRadius: .ratio(0.6), angularInset: 2)
                            .foregroundStyle(p.2).cornerRadius(4)
                    }
                    .frame(width: 120, height: 120)
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(parts, id: \.0) { p in
                            HStack {
                                Circle().fill(p.2).frame(width: 10, height: 10)
                                Text(p.0).font(.subheadline)
                                Spacer()
                                Text("\(Int(p.1 * 100))%").font(.subheadline.bold())
                            }
                        }
                        Text("Referência: P 15–35%, C 45–65%, G 20–35% (IOM).").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: TDEE adaptativo

    /// Gasto real estimado = consumo médio − variação de peso × 7.700 kcal/kg ÷ dias.
    private var adaptive: (tdee: Double, days: Int, weightChange: Double)? {
        let cal = Calendar.current
        guard let start = cal.date(byAdding: .day, value: -days, to: .now) else { return nil }
        let w = weights.filter { $0.date >= start }
        let loggedDays = Set(logs.filter { $0.date >= start }.map { cal.startOfDay(for: $0.date) })
        guard w.count >= 4, loggedDays.count >= 7 else { return nil }
        // tendência por regressão linear (mais robusta que primeiro − último)
        let xs = w.map { $0.date.timeIntervalSince(start) / 86400 }, ys = w.map(\.kg)
        let mx = xs.reduce(0, +) / Double(xs.count), my = ys.reduce(0, +) / Double(ys.count)
        let slope = zip(xs, ys).map { ($0 - mx) * ($1 - my) }.reduce(0, +) / max(xs.map { pow($0 - mx, 2) }.reduce(0, +), 0.001)
        let intake = logs.filter { $0.date >= start }.map(\.nutrients.kcal).reduce(0, +) / Double(loggedDays.count)
        return (intake - slope * 7700, loggedDays.count, slope * Double(days))
    }

    private var adaptiveCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Label("Gasto real (TDEE adaptativo)", systemImage: "brain.head.profile").font(.headline)
                if let a = adaptive {
                    HStack(alignment: .firstTextBaseline) {
                        Text(a.tdee.fmt(0)).font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.gradient)
                        Text("kcal/dia").foregroundStyle(.secondary)
                    }
                    if let f = formulaTDEE {
                        Text("Fórmula: \(f.fmt(0)) kcal · diferença \((a.tdee - f).signed(0)) kcal")
                            .font(.subheadline)
                    }
                    Text("Com base em \(a.days) dias registrados e tendência de \(a.weightChange.signed(2)) kg no período. Quanto mais dias completos, mais preciso.")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("Precisa de pelo menos 7 dias de refeições registradas e 4 pesagens no período. Ele mede seu gasto real comparando o que você come com como seu peso muda.")
                        .font(.callout).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var topFoods: some View {
        let cal = Calendar.current
        let start = cal.date(byAdding: .day, value: -days, to: .now) ?? .now
        let grouped = Dictionary(grouping: logs.filter { $0.date >= start }, by: \.name)
            .map { (name: $0.key, kcal: $0.value.map(\.nutrients.kcal).reduce(0, +), count: $0.value.count) }
            .sorted { $0.kcal > $1.kcal }.prefix(8)
        let total = max(grouped.map(\.kcal).reduce(0, +), 1)
        return Card {
            VStack(alignment: .leading, spacing: 10) {
                Text("Maiores fontes de calorias").font(.headline)
                ForEach(Array(grouped.enumerated()), id: \.offset) { _, g in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(g.name).font(.subheadline).lineLimit(1)
                            Spacer()
                            Text("\(g.kcal.fmt(0)) kcal · \(g.count)x").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        }
                        ProgressBar(progress: g.kcal / total, tint: Theme.accent, height: 4)
                    }
                }
            }
        }
    }
}
