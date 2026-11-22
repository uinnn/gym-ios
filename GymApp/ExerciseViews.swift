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

    private var recentIDs: [String] {
        var seen: [String] = []
        for s in history.prefix(10) { for e in s.exercises where !seen.contains(e.exerciseID) { seen.append(e.exerciseID) } }
        return seen
    }

    var body: some View {
        let results = ExerciseCatalog.search(query, muscle: muscle, equipment: equipment)
        let recent = recentIDs.compactMap { ExerciseCatalog.byID[$0] }
        NavigationStack {
            List {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
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
                        Text(e.name).font(.subheadline).foregroundStyle(.primary)
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

    private struct Point: Identifiable {
        let id = UUID()
        let date: Date, e1RM: Double, volume: Double, topKg: Double
    }

    private var points: [Point] {
        sessions.filter { !$0.isActive }.compactMap { s in
            guard let e = s.exercises.first(where: { $0.exerciseID == exercise.id }), !e.workSets.isEmpty else { return nil }
            let w = e.workSets
            return Point(date: s.start, e1RM: w.map(\.e1RM).max() ?? 0, volume: w.map(\.volume).reduce(0, +),
                         topKg: w.map(\.kg).max() ?? 0)
        }
    }

    var body: some View {
        let p = points
        let strength = exercise.kind == .strength || exercise.kind == .bodyweight
        NavigationStack {
            ZStack {
                AnimatedBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        VStack(spacing: 8) {
                            Image(systemName: exercise.primary.first?.icon ?? "dumbbell.fill")
                                .font(.system(size: 44)).foregroundStyle(Theme.gradient)
                                .frame(width: 90, height: 90).background(Theme.accent.opacity(0.12), in: Circle())
                            FlowLayout(spacing: 6) {
                                ForEach(exercise.primary) { StatusChip(text: $0.label, color: Theme.accent) }
                                ForEach(exercise.secondary) { StatusChip(text: $0.label, color: .secondary) }
                                StatusChip(text: exercise.equipment.label, color: Theme.accent2)
                            }
                        }
                        .appear()
                        Card {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Como fazer", systemImage: "list.number").font(.subheadline.bold()).foregroundStyle(Theme.accent)
                                Text(exercise.howTo).font(.callout)
                                Divider()
                                Label("Dica", systemImage: "lightbulb.fill").font(.subheadline.bold()).foregroundStyle(Theme.accent)
                                Text(exercise.tip).font(.callout)
                                Divider()
                                Text("Gasto: MET \(exercise.met.fmt(1)) (≈ \((exercise.met * 70 / 60).fmt(1)) kcal/min para 70 kg)")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .appear(0.05)
                        if strength, let best = p.max(by: { $0.e1RM < $1.e1RM }) {
                            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                                MetricTile(title: "1RM estimado", value: best.e1RM.fmt(1), unit: "kg", icon: "trophy.fill", tint: Theme.excellent)
                                MetricTile(title: "Maior carga", value: (p.map(\.topKg).max() ?? 0).fmt(1), unit: "kg", icon: "scalemass.fill", tint: Theme.accent)
                                MetricTile(title: "Maior volume", value: (p.map(\.volume).max() ?? 0).fmt(0), unit: "kg", icon: "chart.bar.fill", tint: Theme.accent2)
                                MetricTile(title: "Sessões", value: "\(p.count)", icon: "calendar", tint: Theme.good)
                            }
                            .appear(0.1)
                            percentCard(best.e1RM).appear(0.15)
                        }
                        if strength && p.count >= 2 {
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
                                    let gain = p.last!.e1RM - p.first!.e1RM
                                    Text("\(gain.signed(1)) kg desde o primeiro registro (\((gain / max(p.first!.e1RM, 1) * 100).signed(0))%)")
                                        .font(.caption).foregroundStyle(gain >= 0 ? Theme.good : Theme.warm)
                                }
                            }
                            .appear(0.2)
                        }
                        if p.isEmpty {
                            Text("Faça este exercício em um treino para ver recordes e evolução.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle(exercise.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("OK") { dismiss() } }
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
}
