import SwiftUI
import SwiftData
import Charts

/// Escala de 1 a 5 com bolinhas tocáveis.
struct DotScale: View {
    let title: String
    let icon: String
    @Binding var value: Int
    var low: String
    var high: String
    var tint: Color = Theme.accent

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon).font(.subheadline.bold())
            HStack(spacing: 10) {
                ForEach(1...5, id: \.self) { i in
                    Button {
                        withAnimation(.spring(duration: 0.3, bounce: 0.4)) { value = i }
                    } label: {
                        Circle()
                            .fill(i <= value ? AnyShapeStyle(tint) : AnyShapeStyle(.quaternary))
                            .frame(width: i == value ? 34 : 28, height: i == value ? 34 : 28)
                            .overlay { if i == value { Text("\(i)").font(.caption.bold()).foregroundStyle(.white) } }
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                }
            }
            HStack { Text(low); Spacer(); Text(high) }.font(.caption2).foregroundStyle(.secondary)
        }
    }
}

/// Check-in de humor (novo ou edição do de hoje).
struct MoodCheckInSheet: View {
    var existing: MoodEntry?
    var initialMood: Int = 3
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var mood = 3
    @State private var energy = 3
    @State private var stress = 3
    @State private var anxiety = 3
    @State private var tags: Set<MoodTag> = []
    @State private var note = ""
    @State private var date = Date.now
    @State private var saved = false

    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedBackground()
                ScrollView {
                    VStack(spacing: 18) {
                        VStack(spacing: 6) {
                            Text(Mood.emojis[mood - 1]).font(.system(size: 84))
                                .contentTransition(.symbolEffect(.replace))
                                .scaleEffect(saved ? 1.25 : 1)
                                .id(mood)
                                .transition(.scale.combined(with: .opacity))
                            Text(Mood.labels[mood - 1]).font(.title2.bold()).foregroundStyle(Mood.color(Double(mood)))
                        }
                        .animation(.spring(duration: 0.35, bounce: 0.5), value: mood)
                        HStack(spacing: 8) {
                            ForEach(1...5, id: \.self) { i in
                                Button { mood = i } label: {
                                    Text(Mood.emojis[i - 1]).font(.system(size: 36))
                                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                                        .background(mood == i ? Mood.color(Double(i)).opacity(0.25) : .clear,
                                                    in: RoundedRectangle(cornerRadius: 14))
                                        .scaleEffect(mood == i ? 1.1 : 1)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        Card {
                            VStack(spacing: 18) {
                                DotScale(title: "Energia", icon: "bolt.fill", value: $energy, low: "Sem energia", high: "Cheio(a) de energia", tint: Theme.warm)
                                DotScale(title: "Estresse", icon: "flame.fill", value: $stress, low: "Tranquilo(a)", high: "Muito estressado(a)", tint: Theme.danger)
                                DotScale(title: "Ansiedade", icon: "waveform.path.ecg", value: $anxiety, low: "Calmo(a)", high: "Muito ansioso(a)", tint: Theme.excellent)
                            }
                        }
                        Card {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("O que marcou seu dia?").font(.headline)
                                FlowLayout(spacing: 8) {
                                    ForEach(MoodTag.allCases) { t in
                                        let on = tags.contains(t)
                                        Button {
                                            withAnimation(.spring(duration: 0.25)) { if on { tags.remove(t) } else { tags.insert(t) } }
                                        } label: {
                                            Label(t.label, systemImage: t.icon).font(.caption.bold())
                                                .padding(.horizontal, 10).padding(.vertical, 7)
                                                .foregroundStyle(on ? .white : .primary)
                                                .background(on ? AnyShapeStyle(Theme.gradient) : AnyShapeStyle(.quaternary), in: Capsule())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                TextField("Quer escrever algo? (opcional)", text: $note, axis: .vertical)
                                    .lineLimit(2...6).padding(10)
                                    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
                                DatePicker("Quando", selection: $date, in: ...Date.now).font(.caption)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle(existing == nil ? "Check-in" : "Editar check-in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Salvar") { save() }.bold() }
                if let e = existing {
                    ToolbarItem(placement: .bottomBar) {
                        Button("Apagar", role: .destructive) { context.delete(e); dismiss() }
                    }
                }
            }
            .sensoryFeedback(.success, trigger: saved) { _, _ in ThemeStore.shared.haptics }
            .onAppear {
                if let e = existing {
                    mood = e.mood; energy = e.energy; stress = e.stress; anxiety = e.anxiety
                    tags = e.tags; note = e.note; date = e.date
                } else { mood = initialMood }
            }
        }
    }

    private func save() {
        let e = existing ?? MoodEntry(date: date, mood: mood)
        e.date = date; e.mood = mood; e.energy = energy; e.stress = stress; e.anxiety = anxiety
        e.tags = tags; e.note = note
        if existing == nil {
            context.insert(e)
            PartyService.shared.post(.mood, "fez check-in: \(Mood.emojis[min(max(mood - 1, 0), 4)]) humor \(mood)/5", value: Double(mood))
        }
        withAnimation(.spring) { saved = true }
        Task { try? await Task.sleep(for: .seconds(0.35)); dismiss() }
    }
}

/// Histórico e padrões de humor.
struct MoodHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \MoodEntry.date) private var entries: [MoodEntry]
    @State private var days = 30
    @State private var editing: MoodEntry?

    private struct DayAvg: Identifiable { let id: Date; let mood, energy, stress, anxiety: Double }

    var body: some View {
        let cal = Calendar.current
        let start = cal.date(byAdding: .day, value: -days, to: .now) ?? .now
        let list = entries.filter { $0.date >= start }
        let perDay = Dictionary(grouping: list) { cal.startOfDay(for: $0.date) }.map { d, es in
            DayAvg(id: d, mood: avg(es.map(\.mood)), energy: avg(es.map(\.energy)), stress: avg(es.map(\.stress)),
                   anxiety: avg(es.map(\.anxiety)))
        }.sorted { $0.id < $1.id }
        NavigationStack {
            ZStack {
                AnimatedBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        Picker("Período", selection: $days.animation(.spring)) {
                            Text("7 dias").tag(7); Text("30 dias").tag(30); Text("90 dias").tag(90); Text("1 ano").tag(365)
                        }
                        .pickerStyle(.segmented)
                        if list.isEmpty {
                            ContentUnavailableView("Sem check-ins no período", systemImage: "face.smiling",
                                                   description: Text("Registre seu humor para ver padrões."))
                        } else {
                            summary(list).appear()
                            chart(perDay).appear(0.05)
                            distribution(list).appear(0.1)
                            tagImpact(list).appear(0.15)
                            weekdays(list).appear(0.2)
                            entriesList(list).appear(0.25)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Humor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("OK") { dismiss() } }
            .sheet(item: $editing) { MoodCheckInSheet(existing: $0) }
        }
    }

    private func avg(_ v: [Int]) -> Double { v.isEmpty ? 0 : Double(v.reduce(0, +)) / Double(v.count) }

    private func summary(_ l: [MoodEntry]) -> some View {
        let m = avg(l.map(\.mood)), e = avg(l.map(\.energy)), s = avg(l.map(\.stress)), a = avg(l.map(\.anxiety))
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            MetricTile(title: "Humor médio", value: "\(Mood.emoji(m)) \(m.fmt(1))", icon: "face.smiling", tint: Mood.color(m))
            MetricTile(title: "Energia média", value: e.fmt(1), unit: "/5", icon: "bolt.fill", tint: Theme.warm)
            MetricTile(title: "Estresse médio", value: s.fmt(1), unit: "/5", icon: "flame.fill", tint: Theme.danger)
            MetricTile(title: "Ansiedade média", value: a.fmt(1), unit: "/5", icon: "waveform.path.ecg", tint: Theme.excellent)
        }
    }

    private func chart(_ d: [DayAvg]) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                Text("Evolução").font(.headline)
                Chart {
                    ForEach(d) { x in
                        LineMark(x: .value("Dia", x.id), y: .value("Valor", x.mood), series: .value("S", "Humor"))
                            .foregroundStyle(Theme.good).interpolationMethod(.monotone).lineStyle(StrokeStyle(lineWidth: 3))
                        LineMark(x: .value("Dia", x.id), y: .value("Valor", x.energy), series: .value("S", "Energia"))
                            .foregroundStyle(Theme.warm).interpolationMethod(.monotone)
                        LineMark(x: .value("Dia", x.id), y: .value("Valor", x.stress), series: .value("S", "Estresse"))
                            .foregroundStyle(Theme.danger).interpolationMethod(.monotone).lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                    }
                }
                .chartYScale(domain: 1...5)
                .frame(height: 200)
                HStack(spacing: 12) {
                    legend(Theme.good, "Humor"); legend(Theme.warm, "Energia"); legend(Theme.danger, "Estresse")
                }
            }
        }
    }

    private func legend(_ c: Color, _ t: String) -> some View {
        HStack(spacing: 4) { Circle().fill(c).frame(width: 8, height: 8); Text(t).font(.caption2) }
    }

    private func distribution(_ l: [MoodEntry]) -> some View {
        let counts = (1...5).map { i in l.filter { $0.mood == i }.count }
        let total = max(l.count, 1)
        return Card {
            VStack(alignment: .leading, spacing: 8) {
                Text("Distribuição").font(.headline)
                HStack(alignment: .bottom, spacing: 10) {
                    ForEach(0..<5, id: \.self) { i in
                        VStack(spacing: 4) {
                            Text("\(Int(Double(counts[i]) / Double(total) * 100))%").font(.caption2.bold())
                            RoundedRectangle(cornerRadius: 6).fill(Mood.color(Double(i + 1)))
                                .frame(height: max(4, 90 * Double(counts[i]) / Double(total)))
                            Text(Mood.emojis[i]).font(.title3)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    private func tagImpact(_ l: [MoodEntry]) -> some View {
        let base = avg(l.map(\.mood))
        var by: [MoodTag: [Int]] = [:]
        for e in l { for t in e.tags { by[t, default: []].append(e.mood) } }
        let rows = by.filter { $0.value.count >= 2 }.map { (tag: $0.key, avg: avg($0.value), n: $0.value.count) }
            .sorted { $0.avg > $1.avg }
        return Card {
            VStack(alignment: .leading, spacing: 10) {
                Text("O que mais influencia seu humor").font(.headline)
                if rows.isEmpty {
                    Text("Marque o que aconteceu no dia nos check-ins para ver o impacto de cada coisa.").font(.caption).foregroundStyle(.secondary)
                }
                ForEach(rows, id: \.tag) { r in
                    let d = r.avg - base
                    HStack {
                        Label(r.tag.label, systemImage: r.tag.icon).font(.subheadline)
                        Spacer()
                        Text("\(r.n)x").font(.caption2).foregroundStyle(.secondary)
                        Text("\(Mood.emoji(r.avg)) \(d.signed(1))").font(.subheadline.bold().monospacedDigit())
                            .foregroundStyle(d >= 0 ? Theme.good : Theme.warm)
                    }
                }
                if !rows.isEmpty {
                    Text("Diferença do humor médio nos dias com cada marcação (média geral \(base.fmt(1))).")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func weekdays(_ l: [MoodEntry]) -> some View {
        let cal = Calendar.current
        let by = Dictionary(grouping: l) { cal.component(.weekday, from: $0.date) }.mapValues { avg($0.map(\.mood)) }
        return Card {
            VStack(alignment: .leading, spacing: 8) {
                Text("Humor por dia da semana").font(.headline)
                Chart(Weekday.mondayFirst, id: \.self) { d in
                    BarMark(x: .value("Dia", Weekday.short(d)), y: .value("Humor", by[d] ?? 0))
                        .foregroundStyle(Mood.color(by[d] ?? 0)).cornerRadius(4)
                }
                .chartYScale(domain: 0...5)
                .frame(height: 140)
            }
        }
    }

    private func entriesList(_ l: [MoodEntry]) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 0) {
                Text("Check-ins").font(.headline).padding(.bottom, 6)
                ForEach(l.reversed().prefix(60)) { e in
                    Button { editing = e } label: {
                        HStack(alignment: .top) {
                            Text(Mood.emojis[max(0, min(4, e.mood - 1))]).font(.title2)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(e.date, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated).hour().minute())
                                    .font(.subheadline).foregroundStyle(.primary)
                                Text("Energia \(e.energy) · Estresse \(e.stress) · Ansiedade \(e.anxiety)")
                                    .font(.caption2).foregroundStyle(.secondary)
                                if !e.note.isEmpty { Text(e.note).font(.caption).foregroundStyle(.secondary).lineLimit(2) }
                            }
                            Spacer()
                        }
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Divider()
                }
            }
        }
    }
}
