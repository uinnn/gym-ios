import SwiftUI
import SwiftData
import Charts

enum MindSheet: Identifiable {
    case checkIn(MoodEntry?, Int), moodHistory, sleepLog, sleep, breathing(BreathTechnique), relaxation, meditation, focus
    case gratitude, gratitudeHistory, insights([MindInsight]), assessments, crisis

    var id: String {
        switch self {
        case .checkIn(let e, let m): "checkin-\(e?.persistentModelID.hashValue ?? 0)-\(m)"
        case .moodHistory: "mood"
        case .sleepLog: "sleeplog"
        case .sleep: "sleep"
        case .breathing(let t): "breath-\(t.rawValue)"
        case .relaxation: "relax"
        case .meditation: "meditation"
        case .focus: "focus"
        case .gratitude: "gratitude"
        case .gratitudeHistory: "gratitudeHistory"
        case .insights: "insights"
        case .assessments: "assessments"
        case .crisis: "crisis"
        }
    }
}

struct MindView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \MoodEntry.date) private var moods: [MoodEntry]
    @Query(sort: \SleepEntry.wake) private var sleeps: [SleepEntry]
    @Query(sort: \MindSession.date) private var practices: [MindSession]
    @Query(sort: \GratitudeEntry.date) private var gratitude: [GratitudeEntry]
    @Query(sort: \AssessmentResult.date) private var assessments: [AssessmentResult]
    @Query(sort: \WorkoutSession.start) private var workouts: [WorkoutSession]
    @Query(sort: \FoodLog.date) private var foods: [FoodLog]
    @Query(sort: \WaterLog.date) private var water: [WaterLog]
    @Bindable private var prefs = MindPrefs.shared
    @State private var sheet: MindSheet?
    @State private var memo = Memo()

    /// Insights só são recalculados quando a quantidade de registros muda.
    private final class Memo { var key = ""; var insights: [MindInsight] = [] }

    private var insights: [MindInsight] {
        let key = "\(moods.count)|\(sleeps.count)|\(workouts.count)|\(foods.count)|\(water.count)|\(practices.count)|\(moods.last?.date.timeIntervalSince1970 ?? 0)|\(HealthSync.shared.dailySteps.count)"
        if memo.key != key {
            memo.insights = MindInsightEngine.compute(moods: moods, sleeps: sleeps, workouts: workouts, foods: foods,
                                                      water: water, practices: practices, steps: HealthSync.shared.dailySteps)
            memo.key = key
        }
        return memo.insights
    }

    var body: some View {
        let cal = Calendar.current
        let todayMood = moods.last { cal.isDateInToday($0.date) }
        let ins = insights
        NavigationStack {
            ZStack {
                AnimatedBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        checkInCard(todayMood).appear()
                        quickGrid.appear(0.05)
                        if !moods.isEmpty { moodWeekCard.appear(0.08) }
                        sleepCard.appear(0.1)
                        insightsCard(ins).appear(0.12)
                        HabitsCard().appear(0.14)
                        practiceCard.appear(0.16)
                        breathingList.appear(0.18)
                        assessmentCard.appear(0.2)
                        gratitudeCard.appear(0.22)
                        reminderCard.appear(0.24)
                        CrisisCard().appear(0.26)
                    }
                    .padding()
                }
            }
            .navigationTitle("Mente")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink { CompareView(mode: .mind) } label: { Image(systemName: "square.split.2x1") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { sheet = .crisis } label: { Image(systemName: "heart.circle.fill").foregroundStyle(Theme.danger) }
                }
            }
            .sheet(item: $sheet) { s in sheetView(s) }
        }
    }

    @ViewBuilder private func sheetView(_ s: MindSheet) -> some View {
        switch s {
        case .checkIn(let e, let m): MoodCheckInSheet(existing: e, initialMood: m)
        case .moodHistory: MoodHistoryView()
        case .sleepLog: SleepLogSheet()
        case .sleep: SleepView()
        case .breathing(let t): BreathingView(technique: t)
        case .relaxation: RelaxationView()
        case .meditation: TimerPracticeView(kind: .meditation)
        case .focus: TimerPracticeView(kind: .focus)
        case .gratitude: GratitudeSheet()
        case .gratitudeHistory: GratitudeHistoryView()
        case .insights(let i): MindInsightsView(insights: i)
        case .assessments: AssessmentsHubView()
        case .crisis:
            NavigationStack {
                ScrollView { CrisisCard(urgent: true).padding() }
                    .navigationTitle("Apoio").navigationBarTitleDisplayMode(.inline)
            }
            .presentationDetents([.medium, .large])
        }
    }

    // MARK: Check-in

    private func checkInCard(_ today: MoodEntry?) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                if let t = today {
                    HStack(spacing: 14) {
                        Text(Mood.emojis[max(0, min(4, t.mood - 1))]).font(.system(size: 52))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Hoje você está: \(Mood.labels[max(0, min(4, t.mood - 1))].lowercased())").font(.headline)
                            HStack(spacing: 12) {
                                mini("bolt.fill", t.energy, Theme.warm)
                                mini("flame.fill", t.stress, Theme.danger)
                                mini("waveform.path.ecg", t.anxiety, Theme.excellent)
                            }
                            if !t.tags.isEmpty {
                                Text(t.tags.map(\.label).sorted().joined(separator: " · ")).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                            }
                        }
                        Spacer()
                        Button { sheet = .checkIn(t, t.mood) } label: { Image(systemName: "pencil.circle.fill").font(.title2) }
                    }
                    Button("Novo check-in") { sheet = .checkIn(nil, 3) }.font(.caption.bold())
                } else {
                    Text("Como você está agora?").font(.title3.bold())
                    HStack(spacing: 6) {
                        ForEach(1...5, id: \.self) { i in
                            Button { sheet = .checkIn(nil, i) } label: {
                                VStack(spacing: 4) {
                                    Text(Mood.emojis[i - 1]).font(.system(size: 40))
                                    Text(Mood.labels[i - 1]).font(.system(size: 9)).foregroundStyle(.secondary).lineLimit(1)
                                }
                                .frame(maxWidth: .infinity).padding(.vertical, 8)
                                .background(Mood.color(Double(i)).opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                            }
                            .buttonStyle(PressableStyle())
                        }
                    }
                    Text("Leva 10 segundos. Com alguns dias de registros, o app mostra o que mais influencia seu humor.")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func mini(_ icon: String, _ v: Int, _ c: Color) -> some View {
        Label("\(v)", systemImage: icon).font(.caption.bold()).foregroundStyle(c)
    }

    private var quickGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
            quick("wind", "Respirar", Theme.accent) { sheet = .breathing(.sigh) }
            quick("figure.mind.and.body", "Relaxar", Theme.good) { sheet = .relaxation }
            quick("brain.head.profile", "Meditar", Theme.excellent) { sheet = .meditation }
            quick("timer", "Foco", Theme.warm) { sheet = .focus }
            quick("moon.zzz.fill", "Sono", Theme.info) { sheet = .sleepLog }
            quick("heart.text.square.fill", "Gratidão", Theme.danger) { sheet = .gratitude }
        }
    }

    private func quick(_ icon: String, _ t: String, _ c: Color, _ a: @escaping () -> Void) -> some View {
        Button(action: a) {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.title3).foregroundStyle(c)
                    .frame(width: 44, height: 44).background(c.opacity(0.15), in: Circle())
                Text(t).font(.caption.bold()).foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(PressableStyle())
    }

    // MARK: Humor da semana

    private var moodWeekCard: some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let days = (0..<7).reversed().compactMap { cal.date(byAdding: .day, value: -$0, to: today) }
        let start = days.first ?? today
        let byDay = Dictionary(grouping: moods.filter { $0.date >= start }) { cal.startOfDay(for: $0.date) }
            .mapValues { Double($0.map(\.mood).reduce(0, +)) / Double($0.count) }
        let vals = byDay.values
        let avg = vals.isEmpty ? 0 : vals.reduce(0, +) / Double(vals.count)
        return Button { sheet = .moodHistory } label: {
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Humor da semana").font(.headline).foregroundStyle(.primary)
                        Spacer()
                        if avg > 0 { Text("\(Mood.emoji(avg)) \(avg.fmt(1))").font(.subheadline.bold()).foregroundStyle(Mood.color(avg)) }
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                    }
                    HStack {
                        ForEach(days, id: \.self) { d in
                            VStack(spacing: 4) {
                                if let v = byDay[d] {
                                    Text(Mood.emoji(v)).font(.title2)
                                } else {
                                    Circle().fill(.quaternary).frame(width: 26, height: 26)
                                }
                                Text(d, format: .dateTime.weekday(.narrow)).font(.caption2).foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
        .buttonStyle(PressableStyle())
    }

    // MARK: Sono

    private var sleepCard: some View {
        let last = sleeps.last
        let recent = sleeps.suffix(7)
        let avg = recent.isEmpty ? 0 : recent.map(\.hours).reduce(0, +) / Double(recent.count)
        let loggedToday = last.map { Calendar.current.isDateInToday($0.wake) } ?? false
        return Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Sono", systemImage: "moon.stars.fill").font(.headline).foregroundStyle(Theme.info)
                    Spacer()
                    Button("Detalhes") { sheet = .sleep }.font(.caption.bold())
                }
                if let l = last {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(loggedToday ? "Última noite" : "Último registro").font(.caption2).foregroundStyle(.secondary)
                            Text(SleepMath.hm(l.hours)).font(.title.bold()).foregroundStyle(l.hours < 7 ? Theme.warm : Theme.good)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Média 7 dias").font(.caption2).foregroundStyle(.secondary)
                            Text(SleepMath.hm(avg)).font(.title3.bold())
                        }
                    }
                    ProgressBar(progress: avg / prefs.sleepGoal, tint: avg < 7 ? Theme.warm : Theme.good, height: 6)
                }
                if !loggedToday {
                    Button { sheet = .sleepLog } label: {
                        Label("Registrar a noite passada", systemImage: "plus.circle.fill").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered).tint(Theme.info)
                }
            }
        }
    }

    // MARK: Insights

    private func insightsCard(_ ins: [MindInsight]) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Corpo e mente", systemImage: "sparkles").font(.headline).foregroundStyle(Theme.accent)
                    Spacer()
                    Button("Ver todos") { sheet = .insights(ins) }.font(.caption.bold())
                }
                if ins.isEmpty {
                    Text("Com 5+ dias de check-in, o app cruza seu humor com sono, treinos, alimentação, água e práticas para mostrar o que mais te afeta.")
                        .font(.caption).foregroundStyle(.secondary)
                    ProgressBar(progress: Double(Set(moods.map { Calendar.current.startOfDay(for: $0.date) }).count) / 5,
                                tint: Theme.accent, height: 5)
                } else {
                    ForEach(ins.prefix(3)) { InsightRow(insight: $0) }
                }
            }
        }
    }

    // MARK: Práticas

    private var practiceCard: some View {
        let cal = Calendar.current
        let weekStart = cal.date(byAdding: .day, value: -6, to: cal.startOfDay(for: .now))!
        let week = practices.filter { $0.date >= weekStart }
        let byKind = Dictionary(grouping: week, by: \.kind).mapValues { $0.map(\.seconds).reduce(0, +) / 60 }
        let total = byKind.values.reduce(0, +)
        let streak = HabitMath.streaks(Set(practices.map { cal.startOfDay(for: $0.date) })).current
        return Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Práticas (7 dias)", systemImage: "figure.mind.and.body").font(.headline)
                    Spacer()
                    Text("\(Int(total)) min").font(.headline).foregroundStyle(Theme.accent)
                    if streak > 0 { Text("· \(streak)🔥").font(.subheadline.bold()) }
                }
                ForEach(PracticeKind.allCases, id: \.self) { k in
                    let m = byKind[k] ?? 0
                    HStack(spacing: 8) {
                        Image(systemName: k.icon).frame(width: 20).foregroundStyle(Theme.accent)
                        Text(k.label).font(.caption).frame(width: 80, alignment: .leading)
                        ProgressBar(progress: m / max(total, 1), tint: Theme.accent, height: 6)
                        Text("\(Int(m)) min").font(.caption.monospacedDigit()).frame(width: 50, alignment: .trailing)
                    }
                }
                HStack {
                    Button {
                        context.insert(MindSession(kind: .outdoor, detail: "Ar livre", seconds: 15 * 60))
                    } label: { Label("+15 min ao ar livre", systemImage: "sun.max.fill") }
                    .buttonStyle(.bordered).tint(Theme.warm)
                    Spacer()
                }
                .font(.caption.bold())
                Text("A OMS recomenda práticas de manejo do estresse; 10 minutos por dia de respiração ou meditação já reduzem ansiedade em semanas.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private var breathingList: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Respiração guiada", icon: "wind")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(BreathTechnique.allCases) { t in
                        Button { sheet = .breathing(t) } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Image(systemName: t.icon).font(.title2).foregroundStyle(.white)
                                Text(t.name).font(.subheadline.bold()).foregroundStyle(.white).lineLimit(2)
                                Text(t.subtitle).font(.caption2).foregroundStyle(.white.opacity(0.85)).lineLimit(2)
                            }
                            .frame(width: 170, height: 130, alignment: .topLeading)
                            .padding(14)
                            .background(Theme.gradient, in: RoundedRectangle(cornerRadius: 20))
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
            }
        }
    }

    private var assessmentCard: some View {
        Button { sheet = .assessments } label: {
            Card {
                HStack(spacing: 14) {
                    Image(systemName: "list.clipboard.fill").font(.title2).foregroundStyle(Theme.accent)
                        .frame(width: 44, height: 44).background(Theme.accent.opacity(0.15), in: Circle())
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Autoavaliação").font(.headline).foregroundStyle(.primary)
                        let last = AssessmentKind.allCases.compactMap { k in assessments.last { $0.kind == k } }
                        Text(last.isEmpty ? "PHQ-9 (humor), GAD-7 (ansiedade) e WHO-5 (bem-estar)"
                                          : last.map { "\($0.kind.short): \($0.score)\($0.kind == .who5 ? "%" : "") (\($0.kind.level($0.score).label.lowercased()))" }.joined(separator: " · "))
                            .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                }
            }
        }
        .buttonStyle(PressableStyle())
    }

    private var gratitudeCard: some View {
        let s = HabitMath.streaks(Set(gratitude.map { Calendar.current.startOfDay(for: $0.date) }))
        let today = gratitude.last.map { Calendar.current.isDateInToday($0.date) } ?? false
        return Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Gratidão", systemImage: "heart.text.square.fill").font(.headline).foregroundStyle(Theme.danger)
                    Spacer()
                    if s.current > 0 { Text("\(s.current)🔥").font(.subheadline.bold()) }
                    Button("Histórico") { sheet = .gratitudeHistory }.font(.caption.bold())
                }
                if let g = gratitude.last, today {
                    ForEach(Array(g.items.enumerated()), id: \.offset) { _, t in Label(t, systemImage: "sparkle").font(.subheadline) }
                } else {
                    Button { sheet = .gratitude } label: {
                        Label("Escrever 3 coisas boas de hoje", systemImage: "pencil").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered).tint(Theme.danger)
                }
            }
        }
    }

    private var reminderCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                Toggle(isOn: $prefs.checkInReminder.animation()) { Label("Lembrete de check-in diário", systemImage: "bell.fill") }
                    .tint(Theme.accent)
                if prefs.checkInReminder {
                    DatePicker("Horário", selection: $prefs.checkInTime, displayedComponents: .hourAndMinute)
                }
            }
        }
    }
}
