import SwiftUI
import SwiftData
import Charts

struct MeasurementsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \MeasurementEntry.date) private var all: [MeasurementEntry]
    @Query private var profiles: [UserProfile]
    @Query(sort: \WeightEntry.date, order: .reverse) private var weights: [WeightEntry]
    @State private var showAdd = false
    @State private var selectedPart: BodyPart?
    @State private var showShare = false

    private var latest: MeasurementEntry? { all.merged() }

    var body: some View {
        Group {
            ZStack {
                AnimatedBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        if all.isEmpty {
                            emptyState.appear()
                        } else {
                            summaryCard.appear()
                            ratiosCard.appear(0.05)
                            symmetryCard.appear(0.1)
                            idealCard.appear(0.15)
                            SectionHeader(title: "Partes do corpo", icon: "figure.arms.open")
                            partsGrid
                            historyCard
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Medidas")
            .toolbar {
                Button { showShare = true } label: { Image(systemName: "square.and.arrow.up") }.disabled(all.isEmpty)
                Button { showAdd = true } label: { Image(systemName: "plus.circle.fill").font(.title3) }
            }
            .sheet(isPresented: $showShare) {
                if let m = latest {
                    ShareImageSheet(title: "Medidas") {
                        MeasurementsShareCard(latest: m, first: all.first, heightCm: profiles.first?.heightCm ?? 170)
                    }
                }
            }
            .sheet(isPresented: $showAdd) { AddMeasurementSheet() }
            .sheet(item: $selectedPart) { PartDetailView(part: $0) }
        }
    }

    // MARK: Vazio

    private var emptyState: some View {
        Card {
            VStack(spacing: 14) {
                Image(systemName: "ruler.fill").font(.system(size: 48)).foregroundStyle(Theme.gradient)
                    .symbolEffect(.bounce, value: showAdd)
                Text("Registre suas medidas").font(.title2.bold())
                Text("Com fita métrica: cintura, quadril, pescoço, braços, pernas e mais. Isso libera estimativa de gordura pelo método da Marinha, relação cintura/altura, simetria e proporções ideais.")
                    .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
                Button { showAdd = true } label: {
                    Text("Adicionar medidas").font(.headline).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding()
                        .background(Theme.gradient, in: RoundedRectangle(cornerRadius: 16))
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: Resumo

    private var summaryCard: some View {
        let first = all.first!, last = all.last!
        let trunk: [BodyPart] = [.chest, .waist, .abdomen, .hip, .thighL, .thighR]
        let lost = trunk.compactMap { p -> Double? in
            guard let a = all.first(where: { $0[p] != nil })?[p], let b = all.latestValue(p) else { return nil }
            return b - a
        }.reduce(0, +)
        return Card {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Última medição").font(.caption).foregroundStyle(.secondary)
                    Text(last.date, format: .dateTime.day().month(.wide).year()).font(.headline)
                    Text("\(all.count) medições desde \(first.date.formatted(.dateTime.day().month(.abbreviated).year()))")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(lost.signed(1)).font(.title.bold())
                        .foregroundStyle(lost <= 0 ? Theme.good : Theme.warm)
                        .contentTransition(.numericText())
                    Text("cm no tronco").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: Proporções e risco

    private struct Ratio: Identifiable {
        let id = UUID()
        let title: String, value: Double, digits: Int
        let status: String, color: Color, info: String
    }

    private var ratios: [Ratio] {
        guard let m = latest, let p = profiles.first else { return [] }
        var out: [Ratio] = []
        let male = p.sex == .male
        if let w = m.waist {
            let r = w / p.heightCm
            out.append(Ratio(title: "Cintura / altura", value: r, digits: 2,
                             status: r < 0.5 ? "Saudável" : (r < 0.6 ? "Risco aumentado" : "Risco alto"),
                             color: r < 0.5 ? Theme.good : (r < 0.6 ? Theme.warm : Theme.danger),
                             info: "Ideal abaixo de 0,50"))
            if let h = m.hip {
                let r2 = w / h, lim = male ? 0.9 : 0.8
                out.append(Ratio(title: "Cintura / quadril", value: r2, digits: 2,
                                 status: r2 < lim ? "Baixo risco" : "Risco elevado",
                                 color: r2 < lim ? Theme.good : Theme.warm,
                                 info: "OMS: < \(lim.fmt(2))"))
            }
            if let s = m.shoulders {
                let r3 = s / w
                out.append(Ratio(title: "Ombro / cintura (V)", value: r3, digits: 2,
                                 status: r3 >= 1.55 ? "Formato em V" : (r3 >= 1.4 ? "Bom" : "Retilíneo"),
                                 color: r3 >= 1.55 ? Theme.excellent : (r3 >= 1.4 ? Theme.good : Theme.info),
                                 info: "Índice Adônis ideal: 1,618"))
            }
            if let c = m.chest {
                let r4 = c / w
                out.append(Ratio(title: "Peito / cintura", value: r4, digits: 2,
                                 status: r4 >= 1.3 ? "Ótimo" : "Normal",
                                 color: r4 >= 1.3 ? Theme.excellent : Theme.good, info: "Atlético: ≥ 1,30"))
            }
            if let n = m.neck, let kg = weights.first?.kg {
                let a = BodyAnalysis(BodyInputs(kg: kg, profile: p, measurement: m))
                if a.fatMethod.hasPrefix("Marinha") {
                    out.append(Ratio(title: "Gordura (Marinha)", value: a.bodyFat, digits: 1,
                                     status: a[.bodyFat]?.status?.label ?? "", color: a[.bodyFat]?.status?.tone.color ?? .secondary,
                                     info: "Pescoço \(n.fmt(0)) cm"))
                }
            }
        }
        if let a = m.armL ?? m.armR, let w = m.wrist {
            out.append(Ratio(title: "Braço / punho", value: a / w, digits: 2,
                             status: a / w >= 2.3 ? "Bem desenvolvido" : "Em desenvolvimento",
                             color: a / w >= 2.3 ? Theme.excellent : Theme.info, info: "Clássico: ~2,5"))
        }
        return out
    }

    @ViewBuilder private var ratiosCard: some View {
        let list = ratios
        if !list.isEmpty {
            Card {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Proporções e risco").font(.headline)
                    ForEach(list) { r in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(r.title).font(.subheadline)
                                Text(r.info).font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(r.value.fmt(r.digits) + (r.title.hasPrefix("Gordura") ? "%" : ""))
                                    .font(.headline.monospacedDigit())
                                StatusChip(text: r.status, color: r.color)
                            }
                        }
                        Divider()
                    }
                }
            }
        }
    }

    // MARK: Simetria

    @ViewBuilder private var symmetryCard: some View {
        let pairs: [(String, Double, Double)] = BodyPart.pairs.compactMap { pair in
            guard let lv = latest?[pair.1], let rv = latest?[pair.2] else { return nil }
            return (pair.0, lv, rv)
        }
        if !pairs.isEmpty {
            Card {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Simetria esquerda × direita").font(.headline)
                    ForEach(pairs, id: \.0) { name, l, r in
                        let diff = abs(l - r) / max(l, r) * 100
                        VStack(spacing: 6) {
                            HStack {
                                Text(name).font(.subheadline)
                                Spacer()
                                StatusChip(text: diff < 3 ? "Equilibrado" : (diff < 6 ? "Leve diferença" : "Assimetria"),
                                           color: diff < 3 ? Theme.good : (diff < 6 ? Theme.warm : Theme.danger))
                            }
                            HStack(spacing: 8) {
                                Text("E \(l.fmt(1))").font(.caption.monospacedDigit()).frame(width: 56, alignment: .leading)
                                GeometryReader { g in
                                    let total = l + r
                                    HStack(spacing: 2) {
                                        Capsule().fill(Theme.accent).frame(width: g.size.width * l / total)
                                        Capsule().fill(Theme.accent2)
                                    }
                                }
                                .frame(height: 8)
                                Text("D \(r.fmt(1))").font(.caption.monospacedDigit()).frame(width: 56, alignment: .trailing)
                            }
                            Text("Diferença de \(abs(l - r).fmt(1)) cm (\(diff.fmt(1))%)")
                                .font(.caption2).foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    Text("Diferenças até 3% são normais. O lado dominante costuma ser um pouco maior.")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: Proporções ideais (McCallum / Grecian ideal)

    @ViewBuilder private var idealCard: some View {
        if let m = latest, let wrist = m.wrist {
            let chest = wrist * 6.5
            let ideals: [(BodyPart, Double)] = [
                (.chest, chest), (.waist, chest * 0.70), (.hip, chest * 0.85), (.neck, chest * 0.37),
                (.armR, chest * 0.36), (.forearmR, chest * 0.29), (.thighR, chest * 0.53), (.calfR, chest * 0.34),
            ]
            Card {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Proporção clássica").font(.headline)
                    Text("Ideal estético de McCallum, calculado a partir do seu punho (\(wrist.fmt(1)) cm).")
                        .font(.caption).foregroundStyle(.secondary)
                    ForEach(ideals, id: \.0) { part, ideal in
                        if let v = m[part] ?? (part == .armR ? m.armL : part == .forearmR ? m.forearmL
                                               : part == .thighR ? m.thighL : part == .calfR ? m.calfL : nil) {
                            let pct = v / ideal
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(part.label.replacingOccurrences(of: " direito", with: "")
                                        .replacingOccurrences(of: " direita", with: "")).font(.subheadline)
                                    Spacer()
                                    Text("\(v.fmt(1)) / \(ideal.fmt(1)) cm").font(.caption.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                                ProgressBar(progress: part == .waist ? ideal / v : pct,
                                            tint: (part == .waist ? ideal / v : pct) >= 0.95 ? Theme.excellent : Theme.accent,
                                            height: 6)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: Partes

    private var partsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ForEach(Array(BodyPart.allCases.enumerated()), id: \.element) { i, p in
                let values = all.compactMap { e in e[p].map { (e.date, $0) } }
                if let last = values.last {
                    Button { selectedPart = p } label: {
                        Card {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(p.label).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                HStack(alignment: .firstTextBaseline, spacing: 3) {
                                    Text(last.1.fmt(1)).font(.title2.bold())
                                    Text("cm").font(.caption).foregroundStyle(.secondary)
                                }
                                .foregroundStyle(.primary)
                                if values.count >= 2 {
                                    let d = last.1 - values.first!.1
                                    Text("\(d.signed(1)) cm desde o início").font(.caption2.bold())
                                        .foregroundStyle(partColor(p, d))
                                    Chart(Array(values.enumerated()), id: \.offset) { _, v in
                                        LineMark(x: .value("D", v.0), y: .value("cm", v.1))
                                            .foregroundStyle(Theme.gradient)
                                            .interpolationMethod(.monotone)
                                    }
                                    .chartXAxis(.hidden).chartYAxis(.hidden)
                                    .chartYScale(domain: .automatic(includesZero: false))
                                    .frame(height: 30)
                                } else {
                                    Text("1 registro").font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .buttonStyle(PressableStyle())
                    .appear(Double(i) * 0.02)
                }
            }
        }
    }

    private func partColor(_ p: BodyPart, _ d: Double) -> Color {
        guard let smaller = p.smallerIsBetter, d != 0 else { return .secondary }
        return (d < 0) == smaller ? Theme.good : Theme.warm
    }

    // MARK: Histórico

    private var historyCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 0) {
                Text("Registros").font(.headline).padding(.bottom, 8)
                ForEach(all.reversed()) { e in
                    HStack {
                        Image(systemName: "ruler").foregroundStyle(Theme.accent)
                        Text(e.date, format: .dateTime.day().month(.abbreviated).year()).font(.subheadline)
                        Spacer()
                        Text("\(e.filledCount) medidas").font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 10)
                    .contextMenu {
                        Button("Apagar", systemImage: "trash", role: .destructive) {
                            withAnimation { context.delete(e) }
                        }
                    }
                    Divider()
                }
                Text("Toque e segure num registro para apagar.").font(.caption2).foregroundStyle(.secondary).padding(.top, 8)
            }
        }
    }
}

// MARK: - Adicionar

struct AddMeasurementSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \MeasurementEntry.date) private var all: [MeasurementEntry]
    @State private var values: [BodyPart: Double] = [:]
    @State private var date = Date.now
    @State private var help: BodyPart?

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Data", selection: $date, in: ...Date.now)
                Section {
                    ForEach(BodyPart.allCases) { p in
                        HStack {
                            Button { help = p } label: {
                                Image(systemName: "questionmark.circle").foregroundStyle(Theme.accent)
                            }
                            .buttonStyle(.plain)
                            Text(p.label)
                            Spacer()
                            TextField(all.latestValue(p).map { $0.fmt(1) } ?? "cm",
                                      value: Binding(get: { values[p] }, set: { values[p] = $0 }),
                                      format: .number.precision(.fractionLength(0...1)))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                            Text("cm").foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Preencha só o que quiser")
                } footer: {
                    Text("O valor cinza é sua última medida. Toque em \"Repetir últimas\" para partir delas e só ajustar.")
                }
            }
            .navigationTitle("Novas medidas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") { save() }.disabled(values.values.allSatisfy { $0 <= 0 })
                }
                ToolbarItem(placement: .bottomBar) {
                    Button("Repetir últimas", systemImage: "arrow.clockwise") {
                        for p in BodyPart.allCases { if let v = all.latestValue(p) { values[p] = v } }
                    }
                    .disabled(all.isEmpty)
                }
            }
            .alert(help?.label ?? "", isPresented: Binding(get: { help != nil }, set: { if !$0 { help = nil } })) {
                Button("OK") { help = nil }
            } message: {
                Text(help?.howTo ?? "")
            }
        }
    }

    private func save() {
        let m = MeasurementEntry(date: date)
        for (p, v) in values where v > 0 { m[p] = v }
        context.insert(m)
        dismiss()
    }
}

// MARK: - Detalhe de uma parte

struct PartDetailView: View {
    let part: BodyPart
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \MeasurementEntry.date) private var all: [MeasurementEntry]

    var body: some View {
        let values = all.compactMap { e in e[part].map { (date: e.date, cm: $0) } }
        NavigationStack {
            ZStack {
                AnimatedBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        if let last = values.last {
                            VStack(spacing: 4) {
                                Text(last.cm.fmt(1)).font(.system(size: 60, weight: .bold, design: .rounded))
                                    .foregroundStyle(Theme.gradient)
                                Text("cm").foregroundStyle(.secondary)
                            }
                            .padding(.top).appear()
                        }
                        if values.count >= 2 {
                            Card {
                                Chart(Array(values.enumerated()), id: \.offset) { _, v in
                                    AreaMark(x: .value("Data", v.date), y: .value("cm", v.cm))
                                        .foregroundStyle(LinearGradient(colors: [Theme.accent.opacity(0.3), .clear],
                                                                        startPoint: .top, endPoint: .bottom))
                                        .interpolationMethod(.monotone)
                                    LineMark(x: .value("Data", v.date), y: .value("cm", v.cm))
                                        .foregroundStyle(Theme.gradient)
                                        .lineStyle(StrokeStyle(lineWidth: 3))
                                        .interpolationMethod(.monotone)
                                    PointMark(x: .value("Data", v.date), y: .value("cm", v.cm))
                                        .foregroundStyle(Theme.accent)
                                }
                                .chartYScale(domain: .automatic(includesZero: false))
                                .frame(height: 200)
                            }
                            .appear(0.05)
                            let cms = values.map(\.cm)
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                MetricTile(title: "Desde o início", value: (cms.last! - cms.first!).signed(1), unit: "cm",
                                           icon: "arrow.left.and.right", tint: Theme.accent)
                                MetricTile(title: "Desde a anterior", value: (cms.last! - cms[cms.count - 2]).signed(1),
                                           unit: "cm", icon: "clock.arrow.circlepath", tint: Theme.accent2)
                                MetricTile(title: "Mínimo", value: cms.min()!.fmt(1), unit: "cm",
                                           icon: "arrow.down.to.line", tint: Theme.good)
                                MetricTile(title: "Máximo", value: cms.max()!.fmt(1), unit: "cm",
                                           icon: "arrow.up.to.line", tint: Theme.warm)
                            }
                            .appear(0.1)
                        }
                        Card {
                            VStack(alignment: .leading) {
                                Label("Como medir", systemImage: "ruler").font(.headline).foregroundStyle(Theme.accent)
                                Text(part.howTo).font(.callout).padding(.top, 4)
                            }
                        }
                        .appear(0.15)
                    }
                    .padding()
                }
            }
            .navigationTitle(part.label)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("OK") { dismiss() } }
        }
    }
}
