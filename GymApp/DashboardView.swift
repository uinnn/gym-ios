import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Environment(ScaleScanner.self) private var scanner
    @Query private var profiles: [UserProfile]
    @Query(sort: \WeightEntry.date, order: .reverse) private var entries: [WeightEntry]
    @Query private var measurements: [MeasurementEntry]
    @Query(sort: \WorkoutSession.start, order: .reverse) private var sessions: [WorkoutSession]
    @State private var report: WeightEntry?
    @State private var metric: MetricID?
    @State private var showAddWeight = false
    @State private var showAddMeasure = false
    @State private var showProfiles = false
    @State private var showSettings = false
    @State private var showParty = false

    private var profile: UserProfile? { profiles.first }
    private var latest: WeightEntry? { entries.first }
    private var ctx: AnalysisContext? { AnalysisContext(profile: profile, entries: entries, measurements: measurements) }

    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        header.appear()
                        hero.appear(0.05)
                        quickActions.appear(0.1)
                        HealthTodayCard().appear(0.12)
                        if let ctx {
                            let a = ctx.current
                            scoreStrip(a).appear(0.15)
                            SectionHeader(title: "Destaques", icon: "sparkles")
                            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                                      spacing: 12) {
                                ForEach(Array(MetricID.highlights.enumerated()), id: \.element) { i, id in
                                    if let m = a[id] {
                                        Button { metric = id } label: {
                                            MetricCard(metric: m, progress: ctx.progress(id)?.fraction)
                                        }
                                        .buttonStyle(PressableStyle())
                                        .appear(0.15 + Double(i) * 0.03)
                                    }
                                }
                            }
                            needsCard(a).appear(0.2)
                        }
                        if entries.count >= 2 { trendCard.appear(0.25) }
                        if let goal = profiles.first?.goalWeightKg { ForecastCard(weights: entries, goal: goal).appear(0.27) }
                    }
                    .padding()
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $report) { ReportView(entry: $0) }
            .sheet(item: $metric) { id in
                if let ctx { MetricDetailView(id: id, ctx: ctx) }
            }
            .sheet(isPresented: $showAddWeight) { AddWeightSheet() }
            .sheet(isPresented: $showAddMeasure) { AddMeasurementSheet() }
            .sheet(isPresented: $showParty) { PartyView() }
        }
    }

    // MARK: Cabeçalho

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(Date.now, format: .dateTime.weekday(.wide).day().month(.wide))
                    .font(.subheadline).foregroundStyle(.secondary).textCase(.uppercase)
                Text(greeting).font(.largeTitle.bold())
            }
            Spacer()
            Button { showParty = true } label: {
                Image(systemName: "person.3.fill").font(.body).foregroundStyle(.secondary)
                    .frame(width: 44, height: 44).background(.ultraThinMaterial, in: Circle())
                    .overlay(alignment: .topTrailing) {
                        if PartyService.shared.unread > 0 {
                            Text("\(min(PartyService.shared.unread, 99))").font(.system(size: 10, weight: .bold)).foregroundStyle(.white)
                                .padding(.horizontal, 5).padding(.vertical, 2).background(Theme.danger, in: Capsule())
                        }
                    }
            }
            .buttonStyle(PressableStyle())
            Button { showSettings = true } label: {
                Image(systemName: "gearshape.fill").font(.title3).foregroundStyle(.secondary)
                    .frame(width: 44, height: 44).background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(PressableStyle())
            BluetoothBadge()
            Button { showProfiles = true } label: {
                ProfileAvatar(info: ProfileRegistry.shared.active, size: 44)
                    .overlay(alignment: .bottomTrailing) {
                        if ProfileRegistry.shared.profiles.count > 1 {
                            Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white).padding(3).background(Theme.accent, in: Circle())
                        }
                    }
            }
            .buttonStyle(PressableStyle())
        }
        .sheet(isPresented: $showProfiles) { ProfileSwitcherView() }
        .sheet(isPresented: $showSettings) { ProfileView() }
    }

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: .now)
        let g = h < 12 ? "Bom dia" : (h < 18 ? "Boa tarde" : "Boa noite")
        if let n = profile?.name, !n.isEmpty { return "\(g), \(n.split(separator: " ").first ?? "")" }
        return g
    }

    // MARK: Peso principal

    private var hero: some View {
        Button {
            if scanner.live == nil, let latest { report = latest }
        } label: {
            Card {
                HStack(spacing: 20) {
                    ZStack {
                        ProgressRing(progress: goalProgress, lineWidth: 12)
                        VStack(spacing: 0) {
                            Text("\(Int(goalProgress * 100))%").font(.title3.bold()).contentTransition(.numericText())
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
                            let now = scanner.live?.kg ?? latest?.kg ?? p.goalWeightKg
                            let rem = p.goalWeightKg - now
                            Text(abs(rem) < 0.3 ? "Meta: \(p.goalWeightKg.fmt()) kg · atingida! 🎉"
                                 : "Meta: \(p.goalWeightKg.fmt()) kg · \(abs(rem).fmt(1)) kg \(rem > 0 ? "a ganhar" : "a perder")")
                                .font(.caption.bold()).foregroundStyle(Theme.accent)
                        }
                    }
                    .foregroundStyle(.primary)
                    Spacer(minLength: 0)
                    if scanner.live == nil, latest != nil {
                        Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .buttonStyle(PressableStyle())
        .animation(.spring(duration: 0.5), value: scanner.live?.kg)
    }

    private func weightText(_ kg: Double) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(kg.fmt(2))
                .font(.system(size: 46, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(.numericText(value: kg))
                .foregroundStyle(Theme.gradient)
                .layoutPriority(1)
            Text("kg").font(.headline).foregroundStyle(.secondary).fixedSize()
        }
    }

    @ViewBuilder private var deltaLabel: some View {
        if entries.count >= 2 {
            let d = entries[0].kg - entries[1].kg
            Label("\(d.signed(2)) kg desde a última",
                  systemImage: d > 0 ? "arrow.up.right" : (d < 0 ? "arrow.down.right" : "equal"))
                .font(.caption.bold()).foregroundStyle(trendColor(d))
        }
    }

    private func trendColor(_ d: Double) -> Color {
        guard let p = profile, d != 0 else { return .secondary }
        let good = p.goal == .gain ? d > 0 : (p.goal == .lose ? d < 0 : abs(d) < 0.5)
        return good ? Theme.good : Theme.warm
    }

    /// Quão perto da meta você está: 100% = no peso meta. Usa o peso ao vivo durante a pesagem.
    private var goalProgress: Double {
        guard let p = profile, let now = scanner.live?.kg ?? latest?.kg, p.goalWeightKg > 0 else { return 0 }
        let diff = abs(now - p.goalWeightKg)
        return max(0, 1 - diff / p.goalWeightKg)
    }

    // MARK: Ações rápidas

    private var quickActions: some View {
        HStack(spacing: 12) {
            quick("plus", "Peso", Theme.accent) { showAddWeight = true }
            quick("ruler", "Medidas", Theme.accent2) { showAddMeasure = true }
            if let latest { quick("doc.text.magnifyingglass", "Relatório", .purple) { report = latest } }
        }
    }

    private func quick(_ icon: String, _ title: String, _ tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.headline).foregroundStyle(tint)
                    .frame(width: 40, height: 40).background(tint.opacity(0.15), in: Circle())
                Text(title).font(.caption.bold()).foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(PressableStyle())
    }

    // MARK: Resumo

    private func scoreStrip(_ a: BodyAnalysis) -> some View {
        Card {
            HStack(spacing: 14) {
                ZStack {
                    ProgressRing(progress: a.bodyScore / 100, lineWidth: 7)
                    Text(a.bodyScore.fmt(0)).font(.subheadline.bold())
                }
                .frame(width: 54, height: 54)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Pontuação corporal · \(a.bodyType.name)").font(.subheadline.bold())
                    Text(a.bodyType.detail).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
            }
        }
    }

    private func needsCard(_ a: BodyAnalysis) -> some View {
        let cal = a[.targetCalories]?.value ?? 0
        let prot = a[.proteinNeed]?.value ?? 0, fat = a[.fatNeed]?.value ?? 0, carb = a[.carbNeed]?.value ?? 0
        return Card {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Seu dia").font(.headline)
                    Spacer()
                    Text("\(cal.fmt(0)) kcal").font(.headline).foregroundStyle(Theme.warm)
                }
                GeometryReader { g in
                    let total = max(1, prot * 4 + fat * 9 + carb * 4)
                    HStack(spacing: 3) {
                        Capsule().fill(Theme.accent).frame(width: g.size.width * prot * 4 / total)
                        Capsule().fill(Theme.warm).frame(width: g.size.width * fat * 9 / total)
                        Capsule().fill(Theme.accent2)
                    }
                }
                .frame(height: 10)
                HStack {
                    macro("Proteína", prot, Theme.accent)
                    Spacer()
                    macro("Gordura", fat, Theme.warm)
                    Spacer()
                    macro("Carbo", carb, Theme.accent2)
                    Spacer()
                    VStack(spacing: 2) {
                        Text("\(a.input.kg * 0.035, specifier: "%.1f") L").font(.subheadline.bold())
                        Text("Água").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                let burned = sessions.filter { !$0.isActive && Calendar.current.isDateInToday($0.start) }
                    .map(WorkoutMath.kcal).reduce(0, +)
                if burned > 0 {
                    Label("Treino hoje: \(burned.fmt(0)) kcal gastas", systemImage: "dumbbell.fill")
                        .font(.caption.bold()).foregroundStyle(Theme.warm)
                }
                Text("Gasto total \(a.tdee.fmt(0)) kcal · objetivo: \(a.input.goal.label.lowercased())")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func macro(_ title: String, _ g: Double, _ tint: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(g.fmt(0)) g").font(.subheadline.bold()).foregroundStyle(tint)
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
    }

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
            Circle().fill(stable ? Theme.good : Theme.warm)
                .frame(width: 8, height: 8)
                .scaleEffect(pulse ? 1.6 : 1)
                .opacity(pulse ? 0.4 : 1)
            Text(stable ? "Peso estável — salvo" : "Medindo…")
                .font(.caption.bold())
                .foregroundStyle(stable ? Theme.good : Theme.warm)
        }
        .onAppear { withAnimation(.easeInOut(duration: 0.8).repeatForever()) { pulse = true } }
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
