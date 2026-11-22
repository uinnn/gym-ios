import SwiftUI
import SwiftData
import Charts

extension NutrientContext {
    static func make(_ profile: UserProfile?, _ weights: [WeightEntry], _ measurements: [MeasurementEntry]) -> NutrientContext {
        let targets = AnalysisContext(profile: profile, entries: weights, measurements: measurements)
            .map { NutritionTargets(analysis: $0.current) } ?? .fallback
        return NutrientContext(male: (profile?.sex ?? .male) == .male, age: profile?.age ?? 30, targets: targets)
    }
}

private extension NutrientID.Status {
    var color: Color {
        switch self {
        case .low: Theme.info
        case .ok: Theme.good
        case .high: Theme.danger
        }
    }
}

private func fmtValue(_ v: Double) -> String { v.fmt(v >= 100 ? 0 : (v >= 10 ? 1 : 2)) }

// MARK: - Cartão do dia

struct NutrientsDayCard: View {
    let n: Nutrients
    let m: Micros
    let ctx: NutrientContext
    var onSelect: (NutrientID) -> Void
    @State private var expanded: Set<NutrientGroup> = [.minerals, .vitamins]

    var body: some View {
        let all = NutrientID.allCases.map { id -> (NutrientID, Double, NutrientRef) in
            (id, id.value(n, m), id.reference(ctx))
        }
        let okCount = all.filter { $0.0.status($0.1, $0.2).0 == .ok }.count
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Nutrientes do dia", systemImage: "atom").font(.headline)
                    Spacer()
                    Text("\(okCount)/\(all.count) adequados").font(.caption.bold()).foregroundStyle(Theme.good)
                }
                ProgressBar(progress: Double(okCount) / Double(all.count), tint: Theme.good, height: 6)
                ForEach(NutrientGroup.allCases) { g in
                    let rows = all.filter { $0.0.group == g }
                    VStack(alignment: .leading, spacing: 8) {
                        Button {
                            withAnimation(.spring(duration: 0.35)) {
                                if expanded.contains(g) { expanded.remove(g) } else { expanded.insert(g) }
                            }
                        } label: {
                            HStack {
                                Image(systemName: g.icon).foregroundStyle(Theme.accent)
                                Text(g.rawValue).font(.subheadline.bold())
                                Spacer()
                                let low = rows.filter { $0.0.status($0.1, $0.2).0 != .ok }.count
                                if low > 0 { Text("\(low) a ajustar").font(.caption2).foregroundStyle(Theme.warm) }
                                Image(systemName: "chevron.down").font(.caption)
                                    .rotationEffect(.degrees(expanded.contains(g) ? 180 : 0))
                            }
                            .foregroundStyle(.primary)
                        }
                        .buttonStyle(.plain)
                        if expanded.contains(g) {
                            ForEach(rows, id: \.0) { id, v, r in
                                Button { onSelect(id) } label: { row(id, v, r) }
                                    .buttonStyle(.plain)
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                    }
                    if g != NutrientGroup.allCases.last { Divider() }
                }
                Text("Toque em um nutriente para saber para que serve, onde encontrar e quanto consumir.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private func row(_ id: NutrientID, _ v: Double, _ r: NutrientRef) -> some View {
        let s = id.status(v, r)
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(id.title).font(.subheadline).foregroundStyle(.primary)
                Spacer()
                Text("\(fmtValue(v)) / \(fmtValue(r.rec)) \(id.unit)")
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
            }
            ProgressBar(progress: v / max(r.rec, 0.0001), tint: s.0.color, height: 5)
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Detalhe do nutriente

struct NutrientDetailView: View {
    let id: NutrientID
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [UserProfile]
    @Query(sort: \WeightEntry.date) private var weights: [WeightEntry]
    @Query private var measurements: [MeasurementEntry]
    @Query(sort: \FoodLog.date) private var logs: [FoodLog]

    var body: some View {
        let ctx = NutrientContext.make(profiles.first, weights, measurements)
        let r = id.reference(ctx)
        let cal = Calendar.current
        let today = logs.filter { cal.isDateInToday($0.date) }
        let value = id.value(today.map(\.nutrients).total, today.compactMap(\.micros).total)
        let series: [(Date, Double)] = (0..<14).reversed().compactMap { i in
            guard let d = cal.date(byAdding: .day, value: -i, to: cal.startOfDay(for: .now)) else { return nil }
            let l = logs.filter { cal.isSameDay($0.date, d) }
            return l.isEmpty ? nil : (d, id.value(l.map(\.nutrients).total, l.compactMap(\.micros).total))
        }
        let avg = series.isEmpty ? 0 : series.map(\.1).reduce(0, +) / Double(series.count)
        let contributors = Dictionary(grouping: today, by: \.name)
            .map { ($0.key, $0.value.map { id.value($0.nutrients, $0.micros ?? .zero) }.reduce(0, +)) }
            .filter { $0.1 > 0 }.sorted { $0.1 > $1.1 }.prefix(6)
        let info = id.info

        NavigationStack {
            ZStack {
                AnimatedBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        hero(value, r).appear()
                        refCard(value, r, avg: avg).appear(0.05)
                        if series.count >= 2 { chartCard(series, r).appear(0.1) }
                        Card {
                            VStack(alignment: .leading, spacing: 14) {
                                block("Para que serve", "heart.text.square.fill", info.function)
                                Divider()
                                block("Onde encontrar", "basket.fill", info.sources)
                                Divider()
                                block("Dicas", "lightbulb.fill", info.tips)
                                Divider()
                                block("Se faltar", "arrow.down.circle.fill", info.deficiency)
                                Divider()
                                block("Se exceder", "exclamationmark.triangle.fill", info.excess)
                            }
                        }
                        .appear(0.15)
                        if !contributors.isEmpty {
                            Card {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Suas fontes hoje").font(.headline)
                                    ForEach(Array(contributors.enumerated()), id: \.offset) { _, c in
                                        HStack {
                                            Text(c.0).font(.subheadline).lineLimit(1)
                                            Spacer()
                                            Text("\(fmtValue(c.1)) \(id.unit)").font(.caption.monospacedDigit())
                                        }
                                        ProgressBar(progress: c.1 / max(value, 0.0001), tint: Theme.accent, height: 4)
                                    }
                                }
                            }
                            .appear(0.2)
                        }
                        Card {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Mais ricos em \(id.title.lowercased()) (por 100 g)").font(.headline)
                                ForEach(Array(FoodDatabase.shared.topSources(id).enumerated()), id: \.offset) { i, s in
                                    HStack {
                                        Text("\(i + 1).").font(.caption.bold()).foregroundStyle(Theme.accent).frame(width: 22)
                                        Text(s.0.name).font(.subheadline).lineLimit(1)
                                        Spacer()
                                        Text("\(fmtValue(s.1)) \(id.unit)").font(.caption.monospacedDigit())
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        .appear(0.25)
                        Text("Referências para adultos: IOM/NIH (RDA/AI e limite superior tolerável), OMS e Dietary Guidelines. Gestantes, crianças e pessoas com doenças têm necessidades diferentes.")
                            .font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                    .padding()
                }
            }
            .navigationTitle(id.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("OK") { dismiss() } }
        }
    }

    private func hero(_ v: Double, _ r: NutrientRef) -> some View {
        let s = id.status(v, r)
        return VStack(spacing: 10) {
            ZStack {
                ProgressRing(progress: v / max(r.rec, 0.0001), lineWidth: 14,
                             colors: [s.0.color.opacity(0.7), s.0.color, s.0.color.opacity(0.7)])
                VStack(spacing: 0) {
                    Image(systemName: id.icon).foregroundStyle(s.0.color)
                    Text(fmtValue(v)).font(.system(size: 34, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                    Text("\(id.unit) hoje").font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(width: 170, height: 170)
            StatusChip(text: s.1, color: s.0.color)
            Text("\(Int(v / max(r.rec, 0.0001) * 100))% \(id.kind == .limit ? "do limite" : "do recomendado")")
                .font(.subheadline).foregroundStyle(.secondary)
        }
        .padding(.top)
    }

    private func refCard(_ v: Double, _ r: NutrientRef, avg: Double) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("Quanto consumir").font(.headline)
                HStack {
                    if let mn = r.min { refItem("Mínimo", mn, Theme.info) ; Spacer() }
                    refItem(id.kind == .limit ? "Limite" : "Recomendado", r.rec, id.kind == .limit ? Theme.warm : Theme.good)
                    if let mx = r.max { Spacer(); refItem("Máximo seguro", mx, Theme.danger) }
                }
                let top = max(r.max ?? r.rec * 1.5, v * 1.1, r.rec * 1.2)
                let stops: [(Double, Color)] = id.kind == .limit
                    ? [(r.min ?? 0, Theme.info), (r.rec, Theme.good), (top, Theme.danger)]
                    : [(r.min ?? r.rec * 0.7, Theme.info), (r.max ?? top, Theme.good), (top, Theme.danger)]
                RangeBar(value: v, range: 0...top, stops: stops.filter { $0.0 > 0 }, target: r.rec)
                    .padding(.top, 10)
                if avg > 0 {
                    Text("Sua média nos dias registrados (14 dias): \(fmtValue(avg)) \(id.unit)")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func refItem(_ t: String, _ v: Double, _ c: Color) -> some View {
        VStack(spacing: 2) {
            Text(t).font(.caption2).foregroundStyle(.secondary)
            Text("\(fmtValue(v)) \(id.unit)").font(.subheadline.bold()).foregroundStyle(c)
        }
    }

    private func chartCard(_ s: [(Date, Double)], _ r: NutrientRef) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                Text("Últimos 14 dias").font(.headline)
                Chart {
                    ForEach(Array(s.enumerated()), id: \.offset) { _, p in
                        BarMark(x: .value("Dia", p.0, unit: .day), y: .value(id.unit, p.1))
                            .foregroundStyle(id.status(p.1, r).0.color).cornerRadius(3)
                    }
                    RuleMark(y: .value("Ref", r.rec))
                        .foregroundStyle(Theme.warm).lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                }
                .frame(height: 150)
            }
        }
    }

    private func block(_ t: String, _ icon: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(t, systemImage: icon).font(.subheadline.bold()).foregroundStyle(Theme.accent)
            Text(text).font(.callout).fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Tabela nutricional de um alimento

/// Seção de formulário com a tabela nutricional completa e % da recomendação diária.
struct NutrientsSummary: View {
    let n: Nutrients
    var m: Micros? = nil
    @Query private var profiles: [UserProfile]
    @Query(sort: \WeightEntry.date) private var weights: [WeightEntry]
    @Query private var measurements: [MeasurementEntry]
    @State private var showAll = false
    @State private var detail: NutrientID?

    var body: some View {
        let ctx = NutrientContext.make(profiles.first, weights, measurements)
        let micros = m ?? .zero
        Section {
            HStack {
                big("Calorias", n.kcal, "kcal", Theme.warm, ctx.targets.kcal)
                big("Proteína", n.protein, "g", Theme.accent, ctx.targets.protein)
                big("Carbo", n.carbs, "g", Theme.accent2, ctx.targets.carbs)
                big("Gordura", n.fat, "g", Theme.danger, ctx.targets.fat)
            }
            let ids = NutrientID.allCases.filter { ![.protein, .carbs, .fat].contains($0) }
            let shown = showAll ? ids : ids.filter { [.fiber, .sugar, .saturated, .sodium, .calcium, .iron].contains($0) }
            ForEach(shown) { id in
                let v = id.value(n, micros), r = id.reference(ctx)
                Button { detail = id } label: {
                    HStack {
                        Text(id.title).foregroundStyle(.primary)
                        Spacer()
                        Text("\(fmtValue(v)) \(id.unit)").monospacedDigit().foregroundStyle(.secondary)
                        Text("\(Int((v / max(r.rec, 0.0001) * 100).rounded()))%")
                            .font(.caption.bold().monospacedDigit())
                            .frame(width: 44, alignment: .trailing)
                            .foregroundStyle(id.kind == .limit && v > r.rec * 0.3 ? Theme.warm : Theme.accent)
                    }
                }
            }
            Button(showAll ? "Mostrar menos" : "Tabela completa (\(ids.count) nutrientes)") {
                withAnimation { showAll.toggle() }
            }
        } header: {
            Text("Tabela nutricional")
        } footer: {
            Text("% = quanto esta porção cobre da sua recomendação diária (ou do limite, para sódio, açúcar, saturada, trans e colesterol). Valores 0 podem significar \"não analisado\" na tabela de origem.")
        }
        .sheet(item: $detail) { NutrientDetailView(id: $0) }
    }

    private func big(_ t: String, _ v: Double, _ u: String, _ c: Color, _ goal: Double) -> some View {
        VStack(spacing: 2) {
            Text(v.fmt(0)).font(.title3.bold()).foregroundStyle(c).contentTransition(.numericText())
            Text("\(u) \(t.lowercased())").font(.caption2).foregroundStyle(.secondary)
            Text("\(Int(v / max(goal, 1) * 100))%").font(.caption2.bold()).foregroundStyle(c)
        }
        .frame(maxWidth: .infinity)
    }
}
