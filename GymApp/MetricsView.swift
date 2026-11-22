import SwiftUI
import SwiftData
import Charts

/// Junta perfil, pesagens e medidas para calcular análises em qualquer ponto do tempo.
struct AnalysisContext {
    let profile: UserProfile
    let entries: [WeightEntry]          // ordem crescente de data
    let measurements: [MeasurementEntry]

    init?(profile: UserProfile?, entries: [WeightEntry], measurements: [MeasurementEntry]) {
        guard let profile, !entries.isEmpty else { return nil }
        self.profile = profile
        self.entries = entries.sorted { $0.date < $1.date }
        self.measurements = measurements
    }

    func analysis(_ e: WeightEntry) -> BodyAnalysis {
        BodyAnalysis(BodyInputs(kg: e.kg, profile: profile, measurement: measurements.merged(before: e.date)))
    }

    var current: BodyAnalysis { analysis(entries.last!) }
    var start: BodyAnalysis { analysis(entries.first!) }
    var goal: BodyAnalysis { BodyAnalysis(current.input.with(kg: profile.goalWeightKg)) }

    func progress(_ id: MetricID) -> GoalProgress? {
        guard let c = current[id], let s = start[id], let g = goal[id] else { return nil }
        return GoalProgress(start: s.value, current: c.value, target: g.value)
    }

    /// Série histórica de uma métrica.
    func series(_ id: MetricID) -> [(date: Date, value: Double)] {
        entries.compactMap { e in analysis(e)[id].map { (e.date, $0.value) } }
    }
}

// MARK: - Aba Métricas

struct MetricsView: View {
    @Query private var profiles: [UserProfile]
    @Query(sort: \WeightEntry.date) private var entries: [WeightEntry]
    @Query private var measurements: [MeasurementEntry]
    @State private var category: MetricCategory?
    @State private var selected: MetricID?
    @Namespace private var ns

    var body: some View {
        Group {
            ZStack {
                AnimatedBackground()
                if let ctx = AnalysisContext(profile: profiles.first, entries: entries, measurements: measurements) {
                    content(ctx)
                } else {
                    ContentUnavailableView("Nenhuma pesagem ainda", systemImage: "scalemass",
                                           description: Text("Suba na balança para ver suas métricas."))
                }
            }
            .navigationTitle("Métricas")
        }
    }

    private func content(_ ctx: AnalysisContext) -> some View {
        let a = ctx.current
        let metrics = a.metrics
        return ScrollView {
            VStack(spacing: 16) {
                scoreCard(a).appear()
                categoryPicker.appear(0.05)
                ForEach(MetricCategory.allCases.filter { category == nil || $0 == category }) { cat in
                    let items = metrics.filter { $0.id.category == cat }
                    if !items.isEmpty {
                        SectionHeader(title: cat.title, icon: cat.icon)
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                                  spacing: 12) {
                            ForEach(Array(items.enumerated()), id: \.element.id) { i, m in
                                Button { selected = m.id } label: {
                                    MetricCard(metric: m, progress: ctx.progress(m.id)?.fraction)
                                }
                                .buttonStyle(PressableStyle())
                                .appear(Double(i) * 0.03)
                            }
                        }
                    } else if cat == .shape {
                        SectionHeader(title: cat.title, icon: cat.icon)
                        Card {
                            Label("Cadastre cintura, quadril e pescoço na aba Medidas para liberar 7 índices de formato e risco e uma estimativa de gordura mais precisa.",
                                  systemImage: "ruler")
                                .font(.subheadline)
                        }
                    }
                }
                Text("Sem a impedância (a balança não a envia), a composição é estimada com as fórmulas mais validadas disponíveis para os seus dados. Toque em qualquer métrica para ver como é calculada.")
                    .font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            .padding()
        }
        .sheet(item: $selected) { id in
            MetricDetailView(id: id, ctx: ctx)
                .presentationDragIndicator(.visible)
        }
    }

    private func scoreCard(_ a: BodyAnalysis) -> some View {
        let type = a.bodyType
        return Card { VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 18) {
                ZStack {
                    ProgressRing(progress: a.bodyScore / 100, lineWidth: 12)
                    VStack(spacing: 0) {
                        Text(a.bodyScore.fmt(0)).font(.title.bold()).contentTransition(.numericText())
                        Text("pontos").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .frame(width: 100, height: 100)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Tipo de corpo").font(.caption).foregroundStyle(.secondary)
                    Text(type.name).font(.title3.bold()).foregroundStyle(Theme.gradient)
                    Text(type.detail).font(.caption).foregroundStyle(.secondary)
                    Text("Gordura: \(a.fatMethod)").font(.caption2).foregroundStyle(Theme.accent)
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                ForEach(a.scoreParts, id: \.name) { p in
                    HStack(spacing: 8) {
                        Text(p.name).font(.caption).frame(width: 130, alignment: .leading)
                        ProgressBar(progress: p.score / 100,
                                    tint: p.score >= 85 ? Theme.good : (p.score >= 60 ? Theme.warm : Theme.danger), height: 6)
                        Text(p.score.fmt(0)).font(.caption.monospacedDigit()).frame(width: 28, alignment: .trailing)
                    }
                }
            }
            .padding(.top, 10)
        } }
    }

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(nil, "Todas", "square.grid.2x2.fill")
                ForEach(MetricCategory.allCases) { chip($0, $0.title, $0.icon) }
            }
        }
    }

    private func chip(_ c: MetricCategory?, _ title: String, _ icon: String) -> some View {
        let on = category == c
        return Button {
            withAnimation(.spring(duration: 0.4)) { category = c }
        } label: {
            Label(title, systemImage: icon)
                .font(.subheadline.bold())
                .padding(.horizontal, 14).padding(.vertical, 8)
                .foregroundStyle(on ? .white : .primary)
                .background {
                    if on {
                        Capsule().fill(Theme.gradient).matchedGeometryEffect(id: "chip", in: ns)
                    } else {
                        Capsule().fill(.ultraThinMaterial)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

/// Botão que encolhe ao tocar.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(duration: 0.25), value: configuration.isPressed)
    }
}

/// Cartão de uma métrica na grade.
struct MetricCard: View {
    let metric: Metric
    var progress: Double?

    var body: some View {
        let tint = metric.status?.tone.color ?? Theme.accent
        Card {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: metric.id.icon)
                        .font(.subheadline.bold()).foregroundStyle(tint)
                        .frame(width: 30, height: 30)
                        .background(tint.opacity(0.15), in: Circle())
                    Spacer()
                    if let s = metric.status {
                        Circle().fill(s.tone.color).frame(width: 8, height: 8)
                    }
                }
                Text(metric.id.title).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(metric.display).font(.title2.bold()).contentTransition(.numericText())
                        .minimumScaleFactor(0.6).lineLimit(1)
                    Text(metric.id.unit).font(.caption).foregroundStyle(.secondary)
                }
                .foregroundStyle(.primary)
                Text(metric.status?.label ?? " ")
                    .font(.caption2.bold()).foregroundStyle(tint).lineLimit(1)
                if let progress {
                    HStack(spacing: 6) {
                        ProgressBar(progress: progress, tint: Theme.accent, height: 4)
                        Text("\(Int(progress * 100))%").font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - Detalhe

struct MetricDetailView: View {
    let id: MetricID
    let ctx: AnalysisContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let a = ctx.current
        NavigationStack {
            ZStack {
                AnimatedBackground()
                ScrollView {
                    if let m = a[id] {
                        VStack(spacing: 16) {
                            hero(m).appear()
                            if let scale = m.scale, !m.bands.isEmpty { rangeCard(m, scale).appear(0.05) }
                            if let p = ctx.progress(id) { goalCard(p).appear(0.1) }
                            historyCard.appear(0.15)
                            infoCard(m).appear(0.2)
                            if !m.comparisons.isEmpty { comparisonsCard(m).appear(0.25) }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle(id.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("OK") { dismiss() } }
        }
    }

    private func hero(_ m: Metric) -> some View {
        let tint = m.status?.tone.color ?? Theme.accent
        return VStack(spacing: 10) {
            Image(systemName: id.icon)
                .font(.system(size: 40)).foregroundStyle(tint)
                .frame(width: 80, height: 80)
                .background(tint.opacity(0.15), in: Circle())
                .symbolEffect(.bounce, value: m.value)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(m.display).font(.system(size: 56, weight: .bold, design: .rounded))
                    .contentTransition(.numericText(value: m.value))
                Text(id.unit).font(.title3).foregroundStyle(.secondary)
            }
            if let s = m.status { StatusChip(text: s.label, color: s.tone.color) }
            if let method = m.method {
                Text("Método: \(method)").font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top)
    }

    private func rangeCard(_ m: Metric, _ scale: ClosedRange<Double>) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                Text("Onde você está").font(.headline)
                RangeBar(value: m.value, range: scale,
                         stops: m.bands.map { ($0.upTo, $0.tone.color) },
                         target: ctx.goal[id]?.value)
                    .padding(.top, 8)
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(m.bands.enumerated()), id: \.offset) { i, b in
                        let lower = i == 0 ? nil : m.bands[i - 1].upTo
                        HStack {
                            Circle().fill(b.tone.color).frame(width: 10, height: 10)
                            Text(b.label).font(.subheadline)
                                .fontWeight(m.status?.label == b.label ? .bold : .regular)
                            Spacer()
                            Text(rangeText(lower, b.upTo)).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        }
                    }
                }
                if ctx.goal[id] != nil {
                    Label("A bandeira mostra o valor estimado no seu peso meta.", systemImage: "flag.fill")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func rangeText(_ lo: Double?, _ hi: Double) -> String {
        let d = id.digits
        guard let l = lo else { return "< \(hi.fmt(d))" }
        return hi.isInfinite ? "≥ \(l.fmt(d))" : "\(l.fmt(d)) – \(hi.fmt(d))"
    }

    private func goalCard(_ p: GoalProgress) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Progresso até a meta").font(.headline)
                    Spacer()
                    if let f = p.fraction {
                        Text("\(Int(f * 100))%").font(.headline).foregroundStyle(Theme.accent)
                    }
                }
                ProgressBar(progress: p.fraction ?? 1, tint: Theme.accent, height: 10)
                HStack {
                    stat("Início", p.start)
                    Spacer()
                    stat("Agora", p.current)
                    Spacer()
                    stat("Na meta", p.target)
                }
                Text(abs(p.remaining) < pow(10, -Double(id.digits))
                     ? "Você já está no valor previsto para a meta. 🎉"
                     : "Faltam \(p.remaining.signed(id.digits)) \(id.unit) para o valor previsto no peso meta (\(ctx.profile.goalWeightKg.fmt()) kg).")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func stat(_ title: String, _ v: Double) -> some View {
        VStack(spacing: 2) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(v.fmt(id.digits)).font(.subheadline.bold().monospacedDigit())
        }
    }

    @ViewBuilder private var historyCard: some View {
        let s = ctx.series(id)
        if s.count >= 2 {
            let vals = s.map(\.value)
            let lo = vals.min()!, hi = vals.max()!
            let pad = max((hi - lo) * 0.2, 0.5)
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Histórico").font(.headline)
                        Spacer()
                        let d = vals.last! - vals.first!
                        Text("\(d.signed(id.digits)) \(id.unit)")
                            .font(.subheadline.bold())
                            .foregroundStyle(deltaColor(d))
                    }
                    Chart(Array(s.enumerated()), id: \.offset) { _, p in
                        AreaMark(x: .value("Data", p.date), yStart: .value("Base", lo - pad), yEnd: .value("Valor", p.value))
                            .foregroundStyle(LinearGradient(colors: [Theme.accent.opacity(0.3), .clear],
                                                            startPoint: .top, endPoint: .bottom))
                            .interpolationMethod(.monotone)
                        LineMark(x: .value("Data", p.date), y: .value("Valor", p.value))
                            .foregroundStyle(Theme.gradient)
                            .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                            .interpolationMethod(.monotone)
                    }
                    .chartYScale(domain: (lo - pad)...(hi + pad))
                    .frame(height: 150)
                    HStack {
                        stat("Mínimo", lo); Spacer(); stat("Média", vals.reduce(0, +) / Double(vals.count))
                        Spacer(); stat("Máximo", hi)
                    }
                }
            }
        }
    }

    private func deltaColor(_ d: Double) -> Color {
        guard let better = id.higherIsBetter, d != 0 else { return .secondary }
        return (d > 0) == better ? Theme.good : Theme.warm
    }

    private func infoCard(_ m: Metric) -> some View {
        let info = id.info
        return Card {
            VStack(alignment: .leading, spacing: 14) {
                infoBlock("O que é", "info.circle.fill", info.what)
                Divider()
                infoBlock("Como é calculado", "function", info.how)
                Divider()
                infoBlock("Dicas e interpretação", "lightbulb.fill", info.tip)
            }
        }
    }

    private func infoBlock(_ title: String, _ icon: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon).font(.subheadline.bold()).foregroundStyle(Theme.accent)
            Text(text).font(.callout).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func comparisonsCard(_ m: Metric) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Text("Comparações").font(.headline)
                ForEach(Array(m.comparisons.enumerated()), id: \.offset) { _, c in
                    HStack {
                        Text(c.0).font(.subheadline)
                        Spacer()
                        Text(c.1.fmt(id.digits)).font(.subheadline.bold().monospacedDigit())
                        Text(id.unit).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
