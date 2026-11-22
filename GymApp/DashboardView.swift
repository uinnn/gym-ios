import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Environment(ScaleScanner.self) private var scanner
    @Query private var profiles: [UserProfile]
    @Query(sort: \WeightEntry.date, order: .reverse) private var entries: [WeightEntry]
    @State private var appeared = false

    private var profile: UserProfile? { profiles.first }
    private var latest: WeightEntry? { entries.first }

    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        header
                        hero
                        if let profile, let kg = latest?.kg {
                            let m = BodyMetrics(kg: kg, profile: profile)
                            metricsGrid(m)
                            bmiCard(m)
                            needsCard(m)
                        }
                        if entries.count >= 2 { trendCard }
                        Text("Gordura, músculo e água são estimativas calculadas a partir de peso, altura, idade e sexo. A sua balança não envia a bioimpedância pelo Bluetooth.")
                            .font(.caption2).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding()
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 24)
                }
            }
            .navigationBarHidden(true)
            .onAppear { withAnimation(.spring(duration: 0.7)) { appeared = true } }
        }
    }

    // MARK: Cabeçalho

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(Date.now, format: .dateTime.weekday(.wide).day().month(.wide))
                    .font(.subheadline).foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Text(greeting).font(.largeTitle.bold())
            }
            Spacer()
            BluetoothBadge()
        }
    }

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: .now)
        let g = h < 12 ? "Bom dia" : (h < 18 ? "Boa tarde" : "Boa noite")
        if let n = profile?.name, !n.isEmpty { return "\(g), \(n.split(separator: " ").first ?? "")" }
        return g
    }

    // MARK: Peso principal

    private var hero: some View {
        Card {
            HStack(spacing: 20) {
                ZStack {
                    ProgressRing(progress: goalProgress, lineWidth: 12)
                    VStack(spacing: 0) {
                        Text("\(Int(goalProgress * 100))%")
                            .font(.title3.bold()).contentTransition(.numericText())
                        Text("da meta").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .frame(width: 104, height: 104)

                VStack(alignment: .leading, spacing: 6) {
                    if let live = scanner.live {
                        LiveIndicator(stable: live.isStable)
                        weightText(live.kg)
                    } else if let latest {
                        Text("Último peso").font(.caption).foregroundStyle(.secondary)
                        weightText(latest.kg)
                        deltaLabel
                        Text(latest.date, format: .relative(presentation: .named))
                            .font(.caption2).foregroundStyle(.secondary)
                    } else {
                        Text("Suba na balança").font(.headline)
                        Text("O peso aparece aqui e é salvo sozinho quando estabilizar.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if let p = profile {
                        Text("Meta: \(p.goalWeightKg.fmt()) kg")
                            .font(.caption.bold()).foregroundStyle(Theme.accent)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .animation(.spring(duration: 0.5), value: scanner.live?.kg)
    }

    private func weightText(_ kg: Double) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(kg.fmt(2))
                .font(.system(size: 46, weight: .bold, design: .rounded))
                .contentTransition(.numericText(value: kg))
                .foregroundStyle(Theme.gradient)
            Text("kg").font(.headline).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var deltaLabel: some View {
        if entries.count >= 2 {
            let d = entries[0].kg - entries[1].kg
            Label("\(d >= 0 ? "+" : "")\(d.fmt(2)) kg desde a última",
                  systemImage: d > 0 ? "arrow.up.right" : (d < 0 ? "arrow.down.right" : "equal"))
                .font(.caption.bold())
                .foregroundStyle(trendColor(d))
        }
    }

    private func trendColor(_ d: Double) -> Color {
        guard let p = profile, d != 0 else { return .secondary }
        let good = p.goal == .gain ? d > 0 : (p.goal == .lose ? d < 0 : abs(d) < 0.5)
        return good ? Theme.accent : Theme.warm
    }

    private var goalProgress: Double {
        guard let p = profile, let start = entries.last?.kg, let now = latest?.kg else { return 0 }
        let total = p.goalWeightKg - start
        if abs(total) < 0.1 { return abs(now - p.goalWeightKg) < 0.5 ? 1 : 0 }
        return min(max((now - start) / total, 0), 1)
    }

    // MARK: Métricas

    private func metricsGrid(_ m: BodyMetrics) -> some View {
        let cols = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
        return LazyVGrid(columns: cols, spacing: 12) {
            MetricTile(title: "IMC", value: m.bmi.fmt(), icon: "figure.stand",
                       tint: Theme.bmiColor(m.bmiCategory.level), caption: m.bmiCategory.label)
            MetricTile(title: "Gordura (est.)", value: m.bodyFatPercent.fmt(), unit: "%",
                       icon: "drop.halffull", tint: Theme.warm, caption: "\(m.fatMassKg.fmt()) kg")
            MetricTile(title: "Músculo (est.)", value: m.muscleMassKg.fmt(), unit: "kg",
                       icon: "figure.strengthtraining.traditional", tint: Theme.accent)
            MetricTile(title: "Massa magra", value: m.leanMassKg.fmt(), unit: "kg",
                       icon: "bolt.heart", tint: Theme.accent2)
            MetricTile(title: "Água corporal", value: m.waterPercent.fmt(), unit: "%",
                       icon: "drop.fill", tint: .cyan)
            MetricTile(title: "Metabolismo basal", value: m.bmr.fmt(0), unit: "kcal",
                       icon: "flame.fill", tint: Theme.danger)
        }
    }

    private func bmiCard(_ m: BodyMetrics) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Índice de massa corporal").font(.headline)
                    Spacer()
                    Text(m.bmi.fmt()).font(.headline).foregroundStyle(Theme.bmiColor(m.bmiCategory.level))
                }
                RangeBar(value: m.bmi, range: 15...35,
                         stops: [(18.5, Theme.accent2), (25, Theme.accent), (30, Theme.warm), (35, Theme.danger)])
                HStack {
                    Text("15"); Spacer(); Text("18,5"); Spacer(); Text("25"); Spacer(); Text("30"); Spacer(); Text("35")
                }
                .font(.caption2).foregroundStyle(.secondary)
                Text("Peso saudável para sua altura: \(m.healthyRange.lowerBound.fmt()) – \(m.healthyRange.upperBound.fmt()) kg")
                    .font(.caption)
            }
        }
    }

    private func needsCard(_ m: BodyMetrics) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                Text("Suas necessidades diárias").font(.headline)
                HStack {
                    need("flame.fill", m.targetCalories.fmt(0), "kcal", Theme.warm)
                    Spacer()
                    need("fork.knife", m.proteinGrams.fmt(0), "g proteína", Theme.accent)
                    Spacer()
                    need("waterbottle.fill", m.waterLiters.fmt(1), "L água", Theme.accent2)
                }
                Text("Gasto total estimado: \(m.tdee.fmt(0)) kcal/dia · objetivo: \(m.profile.goal.label.lowercased())")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func need(_ icon: String, _ value: String, _ unit: String, _ tint: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.title2).foregroundStyle(tint)
                .symbolEffect(.bounce, value: appeared)
            Text(value).font(.title3.bold())
            Text(unit).font(.caption2).foregroundStyle(.secondary)
        }
    }

    // MARK: Tendência

    private var trendCard: some View {
        let recent = Array(entries.prefix(30).reversed())
        let minKg = (recent.map(\.kg).min() ?? 0) - 1
        let maxKg = (recent.map(\.kg).max() ?? 0) + 1
        return Card {
            VStack(alignment: .leading, spacing: 10) {
                Text("Tendência recente").font(.headline)
                Chart(recent) { e in
                    AreaMark(x: .value("Data", e.date), yStart: .value("Min", minKg), yEnd: .value("Peso", e.kg))
                        .foregroundStyle(LinearGradient(colors: [Theme.accent.opacity(0.35), .clear],
                                                        startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.catmullRom)
                    LineMark(x: .value("Data", e.date), y: .value("Peso", e.kg))
                        .foregroundStyle(Theme.gradient)
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                        .interpolationMethod(.catmullRom)
                }
                .chartYScale(domain: minKg...maxKg)
                .chartXAxis(.hidden)
                .frame(height: 120)
            }
        }
    }
}

/// Ponto pulsante "medindo/estável".
struct LiveIndicator: View {
    let stable: Bool
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(stable ? Theme.accent : Theme.warm)
                .frame(width: 8, height: 8)
                .scaleEffect(pulse ? 1.6 : 1)
                .opacity(pulse ? 0.4 : 1)
            Text(stable ? "Peso estável — salvo" : "Medindo…")
                .font(.caption.bold())
                .foregroundStyle(stable ? Theme.accent : Theme.warm)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever()) { pulse = true }
        }
    }
}

/// Ícone do estado do Bluetooth.
struct BluetoothBadge: View {
    @Environment(ScaleScanner.self) private var scanner

    var body: some View {
        let on = scanner.bluetoothState == .poweredOn && scanner.isScanning
        Image(systemName: "scalemass.fill")
            .font(.title3)
            .foregroundStyle(on ? Theme.accent : .secondary)
            .frame(width: 44, height: 44)
            .background(.ultraThinMaterial, in: Circle())
            .symbolEffect(.pulse, isActive: scanner.live != nil)
    }
}
