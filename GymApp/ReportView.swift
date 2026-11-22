import SwiftUI
import SwiftData

struct Insight: Identifiable {
    let id = UUID()
    let icon: String
    let color: Color
    let title: String
    let text: String
}

/// Relatório completo de uma pesagem.
struct ReportView: View {
    @Bindable var entry: WeightEntry
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]
    @Query(sort: \WeightEntry.date) private var entries: [WeightEntry]
    @Query private var measurements: [MeasurementEntry]
    @State private var confirmDelete = false

    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedBackground()
                if let ctx = AnalysisContext(profile: profiles.first, entries: entries, measurements: measurements) {
                    report(ctx)
                }
            }
            .navigationTitle("Relatório")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("OK") { dismiss() } }
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        if let ctx = AnalysisContext(profile: profiles.first, entries: entries, measurements: measurements) {
                            ShareLink(item: shareText(ctx)) { Label("Compartilhar resumo", systemImage: "square.and.arrow.up") }
                        }
                        Button("Apagar pesagem", systemImage: "trash", role: .destructive) { confirmDelete = true }
                    } label: { Image(systemName: "ellipsis.circle") }
                }
            }
            .confirmationDialog("Apagar esta pesagem?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Apagar", role: .destructive) {
                    context.delete(entry)
                    dismiss()
                }
            }
        }
    }

    private var index: Int? { entries.firstIndex { $0.persistentModelID == entry.persistentModelID } }
    private var previous: WeightEntry? { index.flatMap { $0 > 0 ? entries[$0 - 1] : nil } }

    private func entryAgo(days: Int) -> WeightEntry? {
        guard let ref = Calendar.current.date(byAdding: .day, value: -days, to: entry.date) else { return nil }
        return entries.filter { $0.date <= ref }.last
    }

    private func report(_ ctx: AnalysisContext) -> some View {
        let a = ctx.analysis(entry)
        let prevA = previous.map(ctx.analysis)
        return ScrollView {
            VStack(spacing: 16) {
                header(a).appear()
                changesCard.appear(0.05)
                insightsCard(insights(ctx, a)).appear(0.1)
                metricsTable(a, prevA).appear(0.15)
                tagsCard.appear(0.2)
            }
            .padding()
        }
    }

    // MARK: Cabeçalho

    private func header(_ a: BodyAnalysis) -> some View {
        Card {
            VStack(spacing: 14) {
                Text(entry.date, format: .dateTime.weekday(.wide).day().month(.wide).hour().minute())
                    .font(.subheadline).foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(entry.kg.fmt(2)).font(.system(size: 60, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.gradient)
                    Text("kg").font(.title3).foregroundStyle(.secondary)
                }
                HStack(spacing: 24) {
                    ZStack {
                        ProgressRing(progress: a.bodyScore / 100, lineWidth: 8)
                        Text(a.bodyScore.fmt(0)).font(.headline)
                    }
                    .frame(width: 60, height: 60)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Pontuação corporal").font(.caption).foregroundStyle(.secondary)
                        Text(a.bodyType.name).font(.headline)
                        if let s = a[.bmi]?.status {
                            StatusChip(text: "IMC \(a.bmi.fmt()) · \(s.label)", color: s.tone.color)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: Variações

    private var changesCard: some View {
        let rows: [(String, WeightEntry?)] = [
            ("Pesagem anterior", previous), ("7 dias", entryAgo(days: 7)),
            ("30 dias", entryAgo(days: 30)), ("Primeira", entries.first),
        ]
        return Card {
            VStack(alignment: .leading, spacing: 10) {
                Text("Variação de peso").font(.headline)
                ForEach(rows, id: \.0) { title, other in
                    if let other, other.persistentModelID != entry.persistentModelID {
                        let d = entry.kg - other.kg
                        HStack {
                            Text(title).font(.subheadline)
                            Text(other.date, format: .dateTime.day().month(.abbreviated))
                                .font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Image(systemName: d < 0 ? "arrow.down.right" : (d > 0 ? "arrow.up.right" : "equal"))
                            Text("\(d.signed(2)) kg").font(.subheadline.bold().monospacedDigit())
                        }
                        .foregroundStyle(weightColor(d))
                    }
                }
            }
        }
    }

    private func weightColor(_ d: Double) -> Color {
        guard abs(d) >= 0.05, let goal = profiles.first?.goal else { return .secondary }
        switch goal {
        case .lose: return d < 0 ? Theme.good : Theme.warm
        case .gain: return d > 0 ? Theme.good : Theme.warm
        case .maintain: return abs(d) < 1 ? Theme.good : Theme.warm
        }
    }

    // MARK: Análise

    private func insights(_ ctx: AnalysisContext, _ a: BodyAnalysis) -> [Insight] {
        var out: [Insight] = []
        let p = ctx.profile
        if let prev = previous {
            let d = entry.kg - prev.kg
            let hours = entry.date.timeIntervalSince(prev.date) / 3600
            if hours < 36 && abs(d) <= 1.5 {
                out.append(Insight(icon: "drop.fill", color: Theme.info, title: "Oscilação normal",
                                   text: "Variação de \(d.signed(2)) kg em \(Int(hours)) h. Mudanças de até 1–2 kg num dia são, na maioria, água, sal e conteúdo intestinal — não gordura."))
            }
        }
        // Média móvel de 7 dias vs semana anterior
        let week = entries.filter { $0.date <= entry.date && $0.date > entry.date.addingTimeInterval(-7 * 86400) }
        let prevWeek = entries.filter { $0.date <= entry.date.addingTimeInterval(-7 * 86400) && $0.date > entry.date.addingTimeInterval(-14 * 86400) }
        if !week.isEmpty, !prevWeek.isEmpty {
            let m1 = week.map(\.kg).reduce(0, +) / Double(week.count)
            let m0 = prevWeek.map(\.kg).reduce(0, +) / Double(prevWeek.count)
            let d = m1 - m0
            out.append(Insight(icon: "chart.line.uptrend.xyaxis", color: weightColor(d), title: "Tendência semanal",
                               text: "Sua média dos últimos 7 dias é \(m1.fmt(2)) kg, \(d.signed(2)) kg em relação à semana anterior. \(abs(d / m0) > 0.01 ? "Ritmo acima de 1% por semana: cuide para não perder massa magra." : "Ritmo sustentável.")"))
        }
        // Meta
        let remaining = entry.kg - p.goalWeightKg
        if abs(remaining) < 0.3 {
            out.append(Insight(icon: "trophy.fill", color: Theme.excellent, title: "Meta alcançada!",
                               text: "Você está no seu peso meta. Considere definir uma nova meta ou focar em composição (mais músculo, menos gordura)."))
        } else {
            out.append(Insight(icon: "flag.checkered", color: Theme.accent, title: "Rumo à meta",
                               text: "Faltam \(abs(remaining).fmt(1)) kg para \(p.goalWeightKg.fmt()) kg. No ritmo recomendado (0,5 kg/semana) isso leva cerca de \(max(1, Int((abs(remaining) / 0.5).rounded()))) semanas."))
        }
        // Recordes
        let before = entries.filter { $0.date < entry.date }
        if let minB = before.map(\.kg).min(), entry.kg < minB {
            out.append(Insight(icon: "star.fill", color: Theme.excellent, title: "Menor peso registrado",
                               text: "Novo recorde: \(entry.kg.fmt(2)) kg, \((minB - entry.kg).fmt(2)) kg abaixo do anterior."))
        } else if let maxB = before.map(\.kg).max(), entry.kg > maxB, p.goal == .gain {
            out.append(Insight(icon: "star.fill", color: Theme.excellent, title: "Maior peso registrado",
                               text: "Novo recorde de ganho: \(entry.kg.fmt(2)) kg."))
        }
        // Composição
        if let bf = a[.bodyFat], let s = bf.status {
            out.append(Insight(icon: "drop.halffull", color: s.tone.color, title: "Gordura \(s.label.lowercased())",
                               text: "Gordura estimada em \(bf.display)% (\(a.fatMass.fmt()) kg). Faixa saudável para sua idade: \(a.fatRange.low.fmt(0))–\(a.fatRange.healthy.fmt(0))%."))
        }
        if a.visceral >= 10 {
            out.append(Insight(icon: "heart.text.square.fill", color: Theme.warm, title: "Gordura visceral elevada",
                               text: "Nível \(a.visceral.fmt(0)). Atividade aeróbica regular, treino de força e redução de álcool e açúcar são as medidas mais eficazes."))
        }
        let metaAge = a.metabolicAge, age = Double(p.age)
        out.append(Insight(icon: "hourglass", color: metaAge <= age ? Theme.good : Theme.warm, title: "Idade metabólica \(metaAge.fmt(0)) anos",
                           text: metaAge <= age ? "\(Int(age - metaAge)) anos abaixo da sua idade real. Ótimo sinal de boa massa magra."
                                                : "\(Int(metaAge - age)) anos acima da idade real. Ganhar músculo e reduzir gordura baixa esse número."))
        // Nutrição
        if let cal = a[.targetCalories], let prot = a[.proteinNeed] {
            out.append(Insight(icon: "fork.knife", color: Theme.accent2, title: "Plano do dia",
                               text: "Para \(p.goal.label.lowercased()): ~\(cal.display) kcal, \(prot.display) g de proteína e \((entry.kg * 0.035).fmt(1)) L de água."))
        }
        // Constância
        let hour = Calendar.current.component(.hour, from: entry.date)
        let hours = entries.suffix(10).map { Calendar.current.component(.hour, from: $0.date) }
        if hours.count >= 4, (hours.max()! - hours.min()!) > 5 {
            out.append(Insight(icon: "clock.fill", color: Theme.info, title: "Dica de constância",
                               text: "Suas pesagens variam de horário (hoje às \(hour)h). Pesar-se sempre no mesmo horário deixa a tendência muito mais confiável."))
        }
        if !entry.tags.isEmpty, entry.tags.contains(.afterMeal) || entry.tags.contains(.afterWorkout) {
            out.append(Insight(icon: "info.circle.fill", color: Theme.info, title: "Contexto da pesagem",
                               text: "Pesagens após refeição ou treino tendem a mostrar valores diferentes do habitual por causa de comida e água."))
        }
        return out
    }

    private func insightsCard(_ list: [Insight]) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                Label("Análise", systemImage: "sparkles").font(.headline).foregroundStyle(Theme.accent)
                ForEach(Array(list.enumerated()), id: \.element.id) { i, ins in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: ins.icon).foregroundStyle(ins.color)
                            .frame(width: 34, height: 34)
                            .background(ins.color.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(ins.title).font(.subheadline.bold())
                            Text(ins.text).font(.callout).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .appear(0.1 + Double(i) * 0.05)
                }
            }
        }
    }

    // MARK: Tabela

    private func metricsTable(_ a: BodyAnalysis, _ prev: BodyAnalysis?) -> some View {
        let ids: [MetricID] = [.bmi, .bodyFat, .fatMass, .lbm, .smm, .smmPercent, .muscleMass, .musclePercent,
                               .visceralFat, .waterPercent, .waterMass, .bone, .proteinPercent, .bmr,
                               .metabolicAge, .obesity, .ffmi, .bodyScore]
        return Card {
            VStack(alignment: .leading, spacing: 0) {
                Text("Composição desta pesagem").font(.headline).padding(.bottom, 8)
                ForEach(ids) { id in
                    if let m = a[id] {
                        HStack(spacing: 10) {
                            Image(systemName: id.icon).foregroundStyle(m.status?.tone.color ?? Theme.accent)
                                .frame(width: 22)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(id.title).font(.subheadline)
                                if let s = m.status { Text(s.label).font(.caption2).foregroundStyle(s.tone.color) }
                            }
                            Spacer()
                            if let p = prev?[id] {
                                let d = m.value - p.value
                                if abs(d) >= pow(10, -Double(id.digits)) {
                                    Text(d.signed(id.digits)).font(.caption.monospacedDigit())
                                        .foregroundStyle(deltaColor(id, d))
                                }
                            }
                            Text("\(m.display) \(id.unit)").font(.subheadline.bold().monospacedDigit())
                        }
                        .padding(.vertical, 8)
                        Divider()
                    }
                }
            }
        }
    }

    private func deltaColor(_ id: MetricID, _ d: Double) -> Color {
        guard let better = id.higherIsBetter else { return .secondary }
        return (d > 0) == better ? Theme.good : Theme.warm
    }

    // MARK: Tags e nota

    private var tagsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("Contexto").font(.headline)
                FlowLayout(spacing: 8) {
                    ForEach(WeighTag.allCases) { tag in
                        let on = entry.tags.contains(tag)
                        Button {
                            withAnimation(.spring(duration: 0.3)) {
                                var t = entry.tags
                                if on { t.remove(tag) } else { t.insert(tag) }
                                entry.tags = t
                            }
                        } label: {
                            Label(tag.label, systemImage: tag.icon)
                                .font(.caption.bold())
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .foregroundStyle(on ? .white : .primary)
                                .background(on ? AnyShapeStyle(Theme.gradient) : AnyShapeStyle(.quaternary), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                TextField("Anotação (como se sentiu, o que comeu…)", text: $entry.note, axis: .vertical)
                    .lineLimit(2...5)
                    .padding(10)
                    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func shareText(_ ctx: AnalysisContext) -> String {
        let a = ctx.analysis(entry)
        var lines = ["Relatório — \(entry.date.formatted(date: .abbreviated, time: .shortened))",
                     "Peso: \(entry.kg.fmt(2)) kg"]
        for id in [MetricID.bmi, .bodyFat, .fatMass, .lbm, .smm, .visceralFat, .waterPercent, .bone, .bmr, .metabolicAge, .bodyScore] {
            if let m = a[id] { lines.append("\(id.title): \(m.display) \(id.unit)\(m.status.map { " (\($0.label))" } ?? "")") }
        }
        return lines.joined(separator: "\n")
    }
}

/// Layout que quebra linha automaticamente (para chips).
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0, width: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > maxW, x > 0 { x = 0; y += rowH + spacing; rowH = 0 }
            x += s.width + spacing
            rowH = max(rowH, s.height)
            width = max(width, x)
        }
        return CGSize(width: min(width, maxW), height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > bounds.maxX, x > bounds.minX { x = bounds.minX; y += rowH + spacing; rowH = 0 }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            rowH = max(rowH, s.height)
        }
    }
}
