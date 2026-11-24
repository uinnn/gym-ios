import SwiftUI
import SwiftData
import Charts

struct ExercisePickerView: View {
    var single = false
    var onPick: ([Exercise]) -> Void
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \WorkoutSession.start, order: .reverse) private var history: [WorkoutSession]
    @State private var query = ""
    @State private var muscle: Muscle?
    @State private var equipment: Equipment?
    @State private var selected: [Exercise] = []
    @State private var detail: Exercise?
    @State private var onlyFav = false

    private var recentIDs: [String] {
        var seen: [String] = []
        for s in history.prefix(10) { for e in s.exercises where !seen.contains(e.exerciseID) { seen.append(e.exerciseID) } }
        return seen
    }

    var body: some View {
        let fav = WorkoutPrefs.shared.favorites
        let results = ExerciseCatalog.search(query, muscle: muscle, equipment: equipment)
            .filter { !onlyFav || fav.contains($0.id) }
            .sorted { fav.contains($0.id) && !fav.contains($1.id) }
        let recent = recentIDs.compactMap { ExerciseCatalog.byID[$0] }
        NavigationStack {
            List {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            Button { withAnimation { onlyFav.toggle() } } label: { Label("Favoritos", systemImage: onlyFav ? "star.fill" : "star") }
                                .font(.caption.bold()).buttonStyle(.bordered).tint(onlyFav ? .yellow : .secondary)
                            ForEach(Muscle.allCases) { m in
                                Button(m.label) { withAnimation { muscle = muscle == m ? nil : m } }
                                    .font(.caption.bold()).buttonStyle(.bordered)
                                    .tint(muscle == m ? Theme.accent : .secondary)
                            }
                        }
                    }
                    Picker("Equipamento", selection: $equipment) {
                        Text("Qualquer equipamento").tag(Equipment?.none)
                        ForEach(Equipment.allCases) { Text($0.label).tag(Equipment?.some($0)) }
                    }
                }
                if query.isEmpty && muscle == nil && equipment == nil && !recent.isEmpty {
                    Section("Recentes") { ForEach(recent) { row($0) } }
                }
                Section("\(results.count) exercícios") { ForEach(results) { row($0) } }
            }
            .searchable(text: $query, prompt: "Buscar exercício ou músculo")
            .navigationTitle("Exercícios")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                if !single {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Adicionar (\(selected.count))") { onPick(selected); dismiss() }
                            .bold().disabled(selected.isEmpty)
                    }
                }
            }
            .sheet(item: $detail) { ExerciseDetailView(exercise: $0) }
        }
    }

    private func row(_ e: Exercise) -> some View {
        let on = selected.contains(e)
        return HStack {
            Button {
                if single { onPick([e]); dismiss(); return }
                withAnimation(.snappy) { if on { selected.removeAll { $0 == e } } else { selected.append(e) } }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: e.primary.first?.icon ?? "dumbbell.fill")
                        .foregroundStyle(on ? .white : Theme.accent)
                        .frame(width: 36, height: 36)
                        .background(on ? AnyShapeStyle(Theme.gradient) : AnyShapeStyle(Theme.accent.opacity(0.15)), in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            if WorkoutPrefs.shared.favorites.contains(e.id) {
                                Image(systemName: "star.fill").font(.caption2).foregroundStyle(.yellow)
                            }
                            Text(e.name).font(.subheadline).foregroundStyle(.primary)
                        }
                        Text("\(e.primary.map(\.label).joined(separator: ", ")) · \(e.equipment.label)")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if on, let i = selected.firstIndex(of: e) {
                        Text("\(i + 1)").font(.caption.bold()).foregroundStyle(Theme.accent)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Button { detail = e } label: { Image(systemName: "info.circle") }.buttonStyle(.borderless)
        }
    }
}

struct ExerciseDetailView: View {
    let exercise: Exercise
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \WorkoutSession.start) private var sessions: [WorkoutSession]
    @Query(sort: \WeightEntry.date, order: .reverse) private var weights: [WeightEntry]
    @Query private var profiles: [UserProfile]
    private var prefs: WorkoutPrefs { WorkoutPrefs.shared }

    private struct Point: Identifiable {
        let id = UUID()
        let date: Date, e1RM: Double, volume: Double, topKg: Double, sets: Int, reps: Int, minutes: Double
    }

    private var points: [Point] {
        sessions.filter { !$0.isActive }.compactMap { s in
            guard let e = s.exercises.first(where: { $0.exerciseID == exercise.id }), !e.workSets.isEmpty else { return nil }
            let w = e.workSets
            return Point(date: s.start, e1RM: w.map(\.e1RM).max() ?? 0, volume: w.map(\.volume).reduce(0, +),
                         topKg: w.map(\.kg).max() ?? 0, sets: w.count, reps: w.map(\.reps).reduce(0, +),
                         minutes: w.map(\.minutes).reduce(0, +))
        }
    }

    @State private var exampleKg: Double?

    private var bodyKg: Double { weights.first?.kg ?? 70 }
    private var isFav: Bool { prefs.favorites.contains(exercise.id) }

    var body: some View {
        let p = points
        let strength = exercise.kind == .strength || exercise.kind == .bodyweight
        NavigationStack {
            ZStack {
                AnimatedBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        header.appear()
                        howToCard.appear(0.05)
                        loadCard(p).appear(0.07)
                        energyCard.appear(0.08)
                        if strength, !p.isEmpty {
                            recordsGrid(p).appear(0.1)
                            if let s = standard(p) { standardCard(s).appear(0.12) }
                            nextCard(p).appear(0.14)
                            percentCard(p.map(\.e1RM).max() ?? 0).appear(0.16)
                        } else if !p.isEmpty {
                            cardioGrid(p).appear(0.1)
                        }
                        if strength && p.count >= 2 { progressCard(p).appear(0.2) }
                        if p.isEmpty {
                            Text("Faça este exercício em um treino para ver recordes, evolução e sugestões de carga.")
                                .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        }
                        repsGuide.appear(0.25)
                    }
                    .padding()
                }
            }
            .navigationTitle(exercise.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { withAnimation(.spring) { prefs.toggle(exercise.id) } } label: {
                        Image(systemName: isFav ? "star.fill" : "star").foregroundStyle(.yellow)
                            .symbolEffect(.bounce, value: isFav)
                    }
                }
                ToolbarItem(placement: .confirmationAction) { Button("OK") { dismiss() } }
            }
        }
    }

    // MARK: Cabeçalho e execução

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: exercise.primary.first?.icon ?? "dumbbell.fill")
                .font(.system(size: 44)).foregroundStyle(Theme.gradient)
                .frame(width: 90, height: 90).background(Theme.accent.opacity(0.12), in: Circle())
            FlowLayout(spacing: 6) {
                ForEach(exercise.primary) { StatusChip(text: $0.label, color: Theme.accent) }
                ForEach(exercise.secondary) { StatusChip(text: $0.label, color: .secondary) }
                StatusChip(text: exercise.equipment.label, color: Theme.accent2)
                if isFav { StatusChip(text: "Favorito", color: .yellow) }
            }
        }
    }

    private var videoURL: URL? {
        let q = "como fazer \(exercise.name) execução correta"
        var c = URLComponents(string: "https://www.youtube.com/results")
        c?.queryItems = [URLQueryItem(name: "search_query", value: q)]
        return c?.url
    }

    private var howToCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Como fazer", systemImage: "list.number").font(.subheadline.bold()).foregroundStyle(Theme.accent)
                    Spacer()
                    StatusChip(text: exercise.level.rawValue, color: exercise.level == .advanced ? .orange : Theme.accent2)
                }
                ExerciseDemoSection(folder: ExerciseMedia.folder(exercise: exercise.id))
                let steps = exercise.steps
                ForEach(steps.indices, id: \.self) { i in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(i + 1)").font(.caption.bold().monospacedDigit()).foregroundStyle(.white)
                            .frame(width: 20, height: 20).background(Theme.accent, in: Circle())
                        Text(steps[i] + ".").font(.callout).fixedSize(horizontal: false, vertical: true)
                    }
                }
                if !exercise.setup.isEmpty {
                    Divider()
                    Label("Ajuste do aparelho", systemImage: "slider.horizontal.3").font(.subheadline.bold()).foregroundStyle(Theme.accent)
                    Text(exercise.setup).font(.callout)
                }
                Divider()
                Label("Dica", systemImage: "lightbulb.fill").font(.subheadline.bold()).foregroundStyle(Theme.accent)
                Text(exercise.tip).font(.callout)
                let mistakes = exercise.allMistakes
                if !mistakes.isEmpty {
                    Divider()
                    Label("Erros comuns", systemImage: "exclamationmark.triangle.fill").font(.subheadline.bold()).foregroundStyle(.orange)
                    ForEach(mistakes, id: \.self) { m in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.orange)
                            Text(m).fixedSize(horizontal: false, vertical: true)
                        }.font(.callout)
                    }
                }
                Divider()
                Label("Respiração", systemImage: "wind").font(.subheadline.bold()).foregroundStyle(Theme.accent)
                Text(exercise.breathing).font(.callout)
                if let url = videoURL {
                    Link(destination: url) {
                        Label("Ver vídeos de execução", systemImage: "play.rectangle.fill")
                            .font(.subheadline.bold()).frame(maxWidth: .infinity).padding(10)
                            .background(Color.red.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(.red)
                    }
                }
                let alts = ExerciseAlternatives.options(for: exercise.id).prefix(5)
                if !alts.isEmpty {
                    Divider()
                    Text("Alternativas para o mesmo músculo").font(.caption.bold()).foregroundStyle(.secondary)
                    Text(alts.map(\.name).joined(separator: " · ")).font(.caption)
                }
            }
        }
    }

    private func loadCard(_ p: [Point]) -> some View {
        let lm = exercise.load
        let usesBody = lm.bodyFraction > 0
        let base = exampleKg ?? (p.map(\.topKg).max().flatMap { $0 > 0 ? $0 : nil } ?? (usesBody && exercise.equipment == .bodyweight ? 0 : 20))
        let real = lm.real(kg: base, bodyKg: bodyKg)
        return Card {
            VStack(alignment: .leading, spacing: 10) {
                Label("Carga real", systemImage: "scalemass.fill").font(.headline).foregroundStyle(Theme.accent)
                Text(lm.note).font(.callout).fixedSize(horizontal: false, vertical: true)
                Divider()
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(lm.perSide ? "Registrado (por halter)" : (exercise.equipment == .bodyweight ? "Peso extra" : "Registrado"))
                            .font(.caption2).foregroundStyle(.secondary)
                        Text("\(base.fmt(1)) kg").font(.title3.bold().monospacedDigit()).contentTransition(.numericText())
                    }
                    Spacer()
                    Image(systemName: "arrow.right").foregroundStyle(.secondary)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Você move de fato").font(.caption2).foregroundStyle(.secondary)
                        Text("≈ \(real.fmt(1)) kg").font(.title3.bold().monospacedDigit()).foregroundStyle(Theme.gradient)
                            .contentTransition(.numericText())
                    }
                }
                Slider(value: Binding(get: { base }, set: { exampleKg = ($0 / 2.5).rounded() * 2.5 }), in: 0...max(200, base * 1.5))
                    .tint(Theme.accent)
                let p1: String? = lm.factor != 1 ? "\(Int(lm.factor * 100))% da carga" : nil
                let p2: String? = lm.perSide ? "× 2 halteres" : nil
                let p3: String? = usesBody ? "+ \(Int(lm.bodyFraction * 100))% do seu corpo (\((bodyKg * lm.bodyFraction).fmt(1)) kg)" : nil
                let parts: [String] = [p1, p2, p3].compactMap { $0 }
                if !parts.isEmpty {
                    Text("Cálculo: " + parts.joined(separator: " ")).font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var energyCard: some View {
        let perMin = exercise.met * bodyKg / 60
        let cardio = exercise.kind == .cardio || exercise.kind == .timed
        return Card {
            VStack(alignment: .leading, spacing: 10) {
                Label("Gasto de energia (para \(bodyKg.fmt(1)) kg)", systemImage: "flame.fill").font(.headline).foregroundStyle(Theme.warm)
                HStack {
                    energy("por minuto", perMin.fmt(1))
                    Spacer()
                    if cardio {
                        energy("30 min", (perMin * 30).fmt(0))
                        Spacer()
                        energy("60 min", (perMin * 60).fmt(0))
                    } else {
                        energy("por série*", (perMin * 1.5).fmt(0))
                        Spacer()
                        energy("4 séries*", (perMin * 6).fmt(0))
                    }
                }
                Text(cardio ? "MET \(exercise.met.fmt(1)): \(exercise.met.fmt(1))× o gasto em repouso (Compendium of Physical Activities)."
                            : "MET \(exercise.met.fmt(1)). *Série + descanso ≈ 1,5 min. Musculação gasta pouco na hora, mas o músculo ganho aumenta seu metabolismo o dia todo.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private func energy(_ t: String, _ v: String) -> some View {
        VStack(spacing: 2) {
            Text("\(v) kcal").font(.headline.monospacedDigit())
            Text(t).font(.caption2).foregroundStyle(.secondary)
        }
    }

    // MARK: Recordes

    private func recordsGrid(_ p: [Point]) -> some View {
        let best = p.max { $0.e1RM < $1.e1RM }!
        let totalVol = p.map(\.volume).reduce(0, +)
        let totalSets = p.map(\.sets).reduce(0, +), totalReps = p.map(\.reps).reduce(0, +)
        let span = max(1, (p.last!.date.timeIntervalSince(p.first!.date)) / 86400 / 7)
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            MetricTile(title: "1RM estimado", value: best.e1RM.fmt(1), unit: "kg", icon: "trophy.fill", tint: Theme.excellent,
                       caption: "\((best.e1RM / bodyKg).fmt(2))× seu peso")
            MetricTile(title: "Maior carga", value: (p.map(\.topKg).max() ?? 0).fmt(1), unit: "kg", icon: "scalemass.fill", tint: Theme.accent)
            MetricTile(title: "Maior volume", value: (p.map(\.volume).max() ?? 0).fmt(0), unit: "kg", icon: "chart.bar.fill", tint: Theme.accent2,
                       caption: "em uma sessão")
            MetricTile(title: "Volume total", value: totalVol >= 10000 ? (totalVol / 1000).fmt(1) : totalVol.fmt(0),
                       unit: totalVol >= 10000 ? "t" : "kg", icon: "shippingbox.fill", tint: .orange)
            MetricTile(title: "Séries / reps", value: "\(totalSets) / \(totalReps)", icon: "square.stack.3d.up.fill", tint: .purple,
                       caption: "média \((Double(totalReps) / Double(max(totalSets, 1))).fmt(1)) reps/série")
            MetricTile(title: "Sessões", value: "\(p.count)", icon: "calendar", tint: Theme.good,
                       caption: "\((Double(p.count) / span).fmt(1))x por semana")
            MetricTile(title: "Última vez", value: p.last!.date.formatted(.relative(presentation: .named)), icon: "clock.fill", tint: .teal)
            MetricTile(title: "Evolução", value: (p.count >= 2 ? (p.last!.e1RM - p.first!.e1RM) / max(p.first!.e1RM, 1) * 100 : 0).signed(0),
                       unit: "%", icon: "chart.line.uptrend.xyaxis", tint: Theme.good, caption: "do 1RM desde o início")
        }
    }

    private func cardioGrid(_ p: [Point]) -> some View {
        let mins = p.map(\.minutes).reduce(0, +)
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            MetricTile(title: "Sessões", value: "\(p.count)", icon: "calendar", tint: Theme.good)
            MetricTile(title: "Tempo total", value: WorkoutMath.durationText(mins * 60), icon: "timer", tint: Theme.accent)
            MetricTile(title: "Calorias totais", value: (exercise.met * bodyKg * mins / 60).fmt(0), unit: "kcal", icon: "flame.fill", tint: Theme.warm)
            MetricTile(title: "Média por sessão", value: (mins / Double(p.count)).fmt(0), unit: "min", icon: "equal.circle", tint: .purple)
        }
    }

    // MARK: Nível de força

    private struct Standard { let level: String, next: String?, nextKg: Double?, ratio: Double, progress: Double }

    /// Padrões aproximados de força (1RM ÷ peso corporal), baseados em tabelas tipo ExRx/Strength Level.
    private func standard(_ p: [Point]) -> Standard? {
        let maleTable: [String: [Double]] = [
            "bench": [0.5, 0.75, 1.0, 1.5, 2.0], "bench-db": [0.2, 0.3, 0.4, 0.6, 0.8],
            "squat": [0.75, 1.25, 1.5, 2.25, 2.75], "deadlift": [1.0, 1.5, 2.0, 2.5, 3.0],
            "ohp": [0.35, 0.55, 0.75, 1.0, 1.4], "barbell-row": [0.5, 0.75, 1.0, 1.5, 1.75],
            "barbell-curl": [0.2, 0.4, 0.6, 0.85, 1.15], "leg-press": [1.0, 2.0, 3.0, 4.0, 5.0],
            "incline-bench": [0.4, 0.65, 0.9, 1.25, 1.6], "front-squat": [0.6, 1.0, 1.25, 1.75, 2.25],
            "rdl": [0.6, 1.0, 1.4, 1.9, 2.4], "hip-thrust": [0.75, 1.25, 1.75, 2.5, 3.25],
        ]
        guard let base = maleTable[exercise.id] else { return nil }
        let female = profiles.first?.sex == .female
        let lower = [.quads, .glutes, .hamstrings].contains(exercise.primary.first ?? .chest)
        let t = base.map { $0 * (female ? (lower ? 0.7 : 0.55) : 1) }
        let names = ["Iniciante", "Novato", "Intermediário", "Avançado", "Elite"]
        let ratio = (p.map(\.e1RM).max() ?? 0) / bodyKg
        var idx = -1
        for (i, v) in t.enumerated() where ratio >= v { idx = i }
        let level = idx < 0 ? "Começando" : names[idx]
        let nextI = idx + 1
        let lo = idx < 0 ? 0 : t[idx]
        let hi = nextI < t.count ? t[nextI] : t.last!
        return Standard(level: level, next: nextI < names.count ? names[nextI] : nil,
                        nextKg: nextI < t.count ? t[nextI] * bodyKg : nil, ratio: ratio,
                        progress: nextI < t.count ? (ratio - lo) / max(hi - lo, 0.01) : 1)
    }

    private func standardCard(_ s: Standard) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Nível de força", systemImage: "medal.fill").font(.headline).foregroundStyle(Theme.excellent)
                    Spacer()
                    StatusChip(text: s.level, color: Theme.excellent)
                }
                ProgressBar(progress: s.progress, tint: Theme.excellent, height: 8)
                if let n = s.next, let kg = s.nextKg {
                    Text("Próximo nível (\(n)): 1RM de \(kg.fmt(1)) kg — \(s.ratio.fmt(2))× → \((kg / bodyKg).fmt(2))× seu peso.")
                        .font(.caption)
                } else {
                    Text("Nível máximo da tabela. Impressionante! 🏆").font(.caption)
                }
                Text("Referência aproximada para adultos treinados, ajustada pelo seu peso e sexo.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Próxima sessão (progressão dupla)

    private func nextCard(_ p: [Point]) -> some View {
        let last = sessions.filter { !$0.isActive }.last { s in s.exercises.contains { $0.exerciseID == exercise.id } }
        let sets = last?.exercises.first { $0.exerciseID == exercise.id }?.workSets ?? []
        let topKg = sets.map(\.kg).max() ?? 0
        let minReps = sets.map(\.reps).min() ?? 0
        let lower = [.quads, .glutes, .hamstrings].contains(exercise.primary.first ?? .chest)
        let step = exercise.equipment == .dumbbell ? 2.0 : (lower ? 5.0 : 2.5)
        let hitTop = minReps >= 12
        let suggestion = topKg == 0
            ? "Registre a carga usada para receber sugestões."
            : (hitTop ? "Você fez \(minReps)+ reps em todas as séries: suba para \((topKg + step).fmt(1)) kg e volte a ~8 reps."
                      : "Mantenha \(topKg.fmt(1)) kg e tente +1 repetição por série (alvo: 12 em todas).")
        return Card {
            VStack(alignment: .leading, spacing: 8) {
                Label("Sugestão para o próximo treino", systemImage: "arrow.up.forward.circle.fill")
                    .font(.headline).foregroundStyle(Theme.good)
                Text(suggestion).font(.callout)
                if !sets.isEmpty {
                    Text("Última sessão: \(sets.map { "\($0.kg.fmt(1))×\($0.reps)" }.joined(separator: ", "))")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Text("Método de progressão dupla: aumente repetições dentro da faixa e, ao atingir o topo, aumente a carga.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private func progressCard(_ p: [Point]) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                Text("Evolução do 1RM estimado").font(.headline)
                Chart(p) { pt in
                    LineMark(x: .value("Data", pt.date), y: .value("1RM", pt.e1RM))
                        .foregroundStyle(Theme.gradient).interpolationMethod(.monotone)
                        .lineStyle(StrokeStyle(lineWidth: 3))
                    PointMark(x: .value("Data", pt.date), y: .value("1RM", pt.e1RM)).foregroundStyle(Theme.accent)
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .frame(height: 180)
                Text("Volume por sessão").font(.subheadline.bold()).padding(.top, 6)
                Chart(p) { pt in
                    BarMark(x: .value("Data", pt.date, unit: .day), y: .value("kg", pt.volume))
                        .foregroundStyle(Theme.accent2).cornerRadius(3)
                }
                .frame(height: 120)
            }
        }
    }

    /// Tabela de cargas por % do 1RM.
    private func percentCard(_ orm: Double) -> some View {
        let rows: [(Int, Int, String)] = [(95, 2, "Força máxima"), (90, 3, "Força"), (85, 5, "Força"),
                                          (80, 8, "Força/hipertrofia"), (75, 10, "Hipertrofia"), (70, 12, "Hipertrofia"),
                                          (65, 15, "Resistência"), (60, 20, "Resistência")]
        return Card {
            VStack(alignment: .leading, spacing: 8) {
                Text("Cargas sugeridas pelo seu 1RM").font(.headline)
                ForEach(rows, id: \.0) { pct, reps, goal in
                    HStack {
                        Text("\(pct)%").font(.subheadline.bold().monospacedDigit()).frame(width: 46, alignment: .leading)
                        Text("~\(reps) reps").font(.subheadline).frame(width: 70, alignment: .leading)
                        Text(goal).font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Text("\((orm * Double(pct) / 100 / 2.5).rounded() * 2.5, specifier: "%.1f") kg")
                            .font(.subheadline.bold().monospacedDigit())
                    }
                }
            }
        }
    }

    private var repsGuide: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                Label("Guia rápido", systemImage: "book.fill").font(.headline).foregroundStyle(Theme.accent)
                guide("Força", "1–6 reps · 80–95% do 1RM · descanso 2–5 min")
                guide("Hipertrofia", "6–15 reps · 65–85% · descanso 1–3 min · 10–20 séries/semana por músculo")
                guide("Resistência", "15+ reps · <65% · descanso 30–60 s")
                guide("Intensidade", "Termine as séries a 1–3 repetições da falha (RIR 1–3)")
                guide("Técnica", "Amplitude completa e descida controlada (2–3 s) aumentam o estímulo")
            }
        }
    }

    private func guide(_ t: String, _ d: String) -> some View {
        HStack(alignment: .top) {
            Text(t).font(.caption.bold()).frame(width: 84, alignment: .leading)
            Text(d).font(.caption).foregroundStyle(.secondary)
        }
    }
}