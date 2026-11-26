import SwiftUI
import SwiftData
import UserNotifications

// MARK: - 8. Ajuste automático de calorias

/// Compara a tendência do peso com o objetivo e sugere mexer na meta de calorias (±150 kcal).
enum CalorieAdjust {
    private static var key: String { "kcalOffset.\(ProfileRegistry.shared.activeID)" }
    private static var dateKey: String { "kcalOffsetDate.\(ProfileRegistry.shared.activeID)" }

    /// Ajuste somado à meta de calorias deste perfil.
    static var offset: Double {
        get { UserDefaults.standard.double(forKey: key) }
        set { UserDefaults.standard.set(min(600, max(-600, newValue)), forKey: key) }
    }
    static var lastChange: Date? {
        get { UserDefaults.standard.object(forKey: dateKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: dateKey) }
    }

    struct Suggestion { let delta: Double; let weeklyPct: Double; let reason: String }

    /// Ritmo semanal (% do peso) pela regressão linear das pesagens dos últimos 21 dias.
    static func weeklyRate(_ weights: [WeightEntry]) -> Double? {
        let from = Date.now.addingTimeInterval(-21 * 86400)
        let pts = weights.filter { $0.date >= from && $0.kg > 0 }
        guard pts.count >= 4, let first = pts.map(\.date).min(), let last = pts.map(\.date).max(),
              last.timeIntervalSince(first) >= 10 * 86400 else { return nil }
        let xs = pts.map { $0.date.timeIntervalSince(first) / 86400 }, ys = pts.map(\.kg)
        let mx = xs.reduce(0, +) / Double(xs.count), my = ys.reduce(0, +) / Double(ys.count)
        let num = zip(xs, ys).map { ($0 - mx) * ($1 - my) }.reduce(0, +)
        let den = xs.map { ($0 - mx) * ($0 - mx) }.reduce(0, +)
        guard den > 0, my > 0 else { return nil }
        return num / den * 7 / my * 100
    }

    static func suggestion(weights: [WeightEntry], goal: Goal) -> Suggestion? {
        if let d = lastChange, Date.now.timeIntervalSince(d) < 14 * 86400 { return nil }
        guard let r = weeklyRate(weights) else { return nil }
        let pct = r.fmt(2)
        switch goal {
        case .lose:
            if r > -0.25 { return Suggestion(delta: -150, weeklyPct: r, reason: "Você está perdendo \(pct)% do peso por semana, abaixo do ideal (0,25–1%).") }
            if r < -1.0 { return Suggestion(delta: 150, weeklyPct: r, reason: "Você está perdendo \(pct)% por semana, rápido demais: risco de perder massa magra.") }
        case .gain:
            if r < 0.1 { return Suggestion(delta: 150, weeklyPct: r, reason: "Seu peso variou \(pct)% por semana; para ganhar massa o ideal é 0,1–0,5%.") }
            if r > 0.5 { return Suggestion(delta: -150, weeklyPct: r, reason: "Você está ganhando \(pct)% por semana, acima do ideal: mais gordura que músculo.") }
        case .maintain:
            if r > 0.25 { return Suggestion(delta: -150, weeklyPct: r, reason: "Seu peso está subindo \(pct)% por semana.") }
            if r < -0.25 { return Suggestion(delta: 150, weeklyPct: r, reason: "Seu peso está caindo \(pct)% por semana.") }
        }
        return nil
    }
}

struct CalorieAdjustCard: View {
    let weights: [WeightEntry]
    let goal: Goal
    var onChange: () -> Void = {}
    @State private var hidden = false

    var body: some View {
        if !hidden, let s = CalorieAdjust.suggestion(weights: weights, goal: goal) {
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Ajuste de calorias sugerido", systemImage: "slider.horizontal.below.square.and.square.filled")
                        .font(.headline).foregroundStyle(Theme.accent)
                    Text(s.reason).font(.callout)
                    Text("Sugestão: \(s.delta > 0 ? "+" : "")\(Int(s.delta)) kcal por dia (ajuste atual: \(Int(CalorieAdjust.offset)) kcal).")
                        .font(.callout.bold())
                    HStack {
                        Button("Aplicar") {
                            CalorieAdjust.offset += s.delta
                            CalorieAdjust.lastChange = .now
                            withAnimation { hidden = true }
                            onChange()
                        }
                        .buttonStyle(.borderedProminent)
                        Button("Agora não") {
                            CalorieAdjust.lastChange = .now
                            withAnimation { hidden = true }
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
    }
}

// MARK: - 9. Lembretes de água inteligentes

enum WaterReminder {
    static var enabled: Bool {
        get { UserDefaults.standard.bool(forKey: "smartWater") }
        set { UserDefaults.standard.set(newValue, forKey: "smartWater") }
    }
    private static let hours = [10, 12, 14, 16, 18, 20]
    private static let ids = hours.map { "water-\($0)" } + ["water-morning"]

    /// Agenda avisos só nos horários em que você estará abaixo do ritmo (8h → 21h). Chame a cada registro de água.
    static func reschedule(todayMl: Double, targetMl: Double) {
        let c = UNUserNotificationCenter.current()
        c.removePendingNotificationRequests(withIdentifiers: ids)
        guard enabled, targetMl > 0 else { return }
        let cal = Calendar.current
        for h in hours {
            guard let at = cal.date(bySettingHour: h, minute: 0, second: 0, of: .now), at > .now else { continue }
            let expected = targetMl * Double(h - 8) / 13
            guard todayMl < expected * 0.85 else { continue }
            let content = UNMutableNotificationContent()
            content.title = "Hora de beber água 💧"
            content.body = "Até as \(h)h o ideal seria \(Int(expected)) ml. Faltam \(Int(expected - todayMl)) ml para entrar no ritmo."
            content.sound = .default
            let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: at)
            c.add(UNNotificationRequest(identifier: "water-\(h)", content: content,
                                        trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)))
        }
        // amanhã cedo, caso o app não seja aberto
        if let tomorrow = cal.date(byAdding: .day, value: 1, to: .now),
           let at = cal.date(bySettingHour: 10, minute: 0, second: 0, of: tomorrow) {
            let content = UNMutableNotificationContent()
            content.title = "Bom dia! 💧"
            content.body = "Comece a hidratação: a meta é \(Int(targetMl)) ml hoje."
            let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: at)
            c.add(UNNotificationRequest(identifier: "water-morning", content: content,
                                        trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)))
        }
    }

    static func requestAndEnable() async -> Bool {
        let ok = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        enabled = ok
        return ok
    }
}

// MARK: - 7. Refeições frequentes

struct MealCombo: Identifiable {
    let id: String
    let meal: Meal
    let items: [(food: FoodItem, grams: Double)]
    let count: Int
    var kcal: Double { items.map { $0.food.per100.kcal * $0.grams / 100 }.reduce(0, +) }
    var title: String { items.map(\.food.name).joined(separator: " + ") }
}

enum MealCombos {
    /// Combinações de 2–6 alimentos repetidas pelo menos 3x na mesma refeição nos últimos 60 dias.
    static func find(_ logs: [FoodLog], meal: Meal) -> [MealCombo] {
        let cal = Calendar.current
        var groups: [Date: [FoodLog]] = [:]
        for l in logs where l.meal == meal { groups[cal.startOfDay(for: l.date), default: []].append(l) }
        var counts: [[String]: [[FoodLog]]] = [:]
        for g in groups.values {
            let ids = Array(Set(g.map(\.foodID))).sorted()
            guard (2...6).contains(ids.count) else { continue }
            counts[ids, default: []].append(g)
        }
        return counts.filter { $0.value.count >= 3 }
            .sorted { $0.value.count > $1.value.count }
            .prefix(4)
            .map { ids, days in
                let all = days.flatMap { $0 }
                let items = ids.compactMap { id -> (food: FoodItem, grams: Double)? in
                    let ls = all.filter { $0.foodID == id }
                    guard let last = ls.max(by: { $0.date < $1.date }) else { return nil }
                    return (last.asFood, (ls.map(\.grams).reduce(0, +) / Double(ls.count)).rounded())
                }
                return MealCombo(id: ids.joined(separator: "|"), meal: meal, items: items, count: days.count)
            }
    }
}

struct MealCombosSection: View {
    let meal: Meal
    let day: Date
    var onLogged: () -> Void
    @Environment(\.modelContext) private var context
    @Query private var logs: [FoodLog]

    init(meal: Meal, day: Date, onLogged: @escaping () -> Void) {
        self.meal = meal; self.day = day; self.onLogged = onLogged
        let from = Date.now.addingTimeInterval(-60 * 86400)
        _logs = Query(filter: #Predicate<FoodLog> { $0.date >= from })
    }

    var body: some View {
        let combos = MealCombos.find(logs, meal: meal)
        if !combos.isEmpty {
                Section {
                    ForEach(combos) { c in
                        Button {
                            for it in c.items {
                                Diary.log(it.food, grams: it.grams, meal: meal, date: Diary.timestamp(for: day), in: context)
                            }
                            onLogged()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(c.title).font(.subheadline.bold()).lineLimit(2)
                                    Text("\(Int(c.kcal)) kcal · repetida \(c.count)x").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "plus.circle.fill").font(.title3).foregroundStyle(Theme.accent)
                            }
                        }
                        .buttonStyle(.tap)
                    }
                } header: { Text("Refeições frequentes · um toque") }
        }
    }
}

// MARK: - 5. Recuperação muscular

enum Recovery {
    /// Horas para recuperar após um treino típico (~6 séries) do músculo.
    static func baseHours(_ m: Muscle) -> Double {
        switch m {
        case .quads, .hamstrings, .glutes, .back, .chest, .lowerBack: 72
        case .abs, .calves, .forearms, .obliques: 36
        default: 48
        }
    }

    /// 0 = acabou de treinar, 1 = recuperado.
    static func status(_ sessions: [WorkoutSession], now: Date = .now) -> [Muscle: (recovered: Double, last: Date)] {
        var out: [Muscle: (recovered: Double, last: Date)] = [:]
        let from = now.addingTimeInterval(-7 * 86400)
        for s in sessions where !s.isActive && s.start >= from {
            let end = s.end ?? s.start
            var load: [Muscle: Double] = [:]
            for e in s.exercises {
                guard let x = e.exercise, x.kind != .cardio else { continue }
                let n = Double(e.workSets.count)
                for m in x.primary { load[m, default: 0] += n }
                for m in x.secondary { load[m, default: 0] += n * 0.5 }
            }
            for (m, sets) in load where sets >= 1 {
                let need = baseHours(m) * min(1.5, max(0.5, sets / 6))
                let r = min(1, now.timeIntervalSince(end) / 3600 / need)
                if let cur = out[m] { out[m] = (min(cur.recovered, r), max(cur.last, end)) } else { out[m] = (r, end) }
            }
        }
        return out
    }

    static func color(_ r: Double) -> Color { r < 0.5 ? Theme.danger : (r < 0.9 ? Theme.warm : Theme.good) }
}

struct RecoveryView: View {
    @Query(sort: \WorkoutSession.start, order: .reverse) private var sessions: [WorkoutSession]

    private let regions: [(String, [Muscle])] = [
        ("Superior", [.chest, .back, .shoulders, .traps, .biceps, .triceps, .forearms]),
        ("Core", [.abs, .obliques, .lowerBack]),
        ("Inferior", [.quads, .hamstrings, .glutes, .adductors, .calves]),
    ]

    var body: some View {
        let st = Recovery.status(Array(sessions.prefix(30)))
        ScrollView {
            VStack(spacing: 14) {
                HStack(spacing: 14) {
                    legend(Theme.danger, "Treinado agora"); legend(Theme.warm, "Recuperando"); legend(Theme.good, "Pronto")
                }
                .font(.caption)
                ForEach(regions, id: \.0) { title, muscles in
                    Card {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(title).font(.headline)
                            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                                ForEach(muscles) { m in tile(m, st[m]) }
                            }
                        }
                    }
                }
                Text("Estimativa: músculos grandes levam ~72 h, pequenos ~48 h, ajustado pelo número de séries. Use como guia, não como regra; dor e cansaço também contam.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding()
        }
        .background(AnimatedBackground())
        .navigationTitle("Recuperação muscular")
    }

    private func legend(_ c: Color, _ t: String) -> some View {
        HStack(spacing: 4) { Circle().fill(c).frame(width: 10, height: 10); Text(t) }
    }

    private func tile(_ m: Muscle, _ s: (recovered: Double, last: Date)?) -> some View {
        let r = s?.recovered ?? 1
        let c = Recovery.color(r)
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: m.icon).foregroundStyle(c)
                Text(m.label).font(.subheadline.bold())
                Spacer()
                Text("\(Int(r * 100))%").font(.caption.bold().monospacedDigit()).foregroundStyle(c)
            }
            ProgressBar(progress: r, tint: c, height: 6)
            Text(s.map { "Treinado \($0.last.formatted(.relative(presentation: .named)))" } ?? "Sem treino na semana")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(10)
        .background(c.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - 12. Prontidão para treinar

enum Readiness {
    struct Result { let score: Int; let advice: String; let color: Color; let factors: [(String, String)] }

    @MainActor
    static func compute(sleep: [SleepEntry], moods: [MoodEntry], sessions: [WorkoutSession]) -> Result? {
        let hk = HealthSync.shared
        let cal = Calendar.current
        var parts: [(weight: Double, value: Double)] = []
        var factors: [(String, String)] = []

        // Sono: Saúde (última noite) ou registro manual de hoje
        let manual = sleep.first { cal.isDateInToday($0.wake) }
        if let h = (hk.isOn ? hk.lastNightHours : nil) ?? manual?.hours {
            var v = min(1, h / 8)
            if let q = manual?.quality { v = v * 0.7 + Double(q - 1) / 4 * 0.3 }
            parts.append((0.35, v)); factors.append(("Sono", "\(h.fmt(1)) h"))
        }
        // HRV hoje vs. média de 30 dias
        if hk.isOn, let t = hk.hrvToday, let b = hk.hrvBase, b > 0 {
            let ratio = t / b
            parts.append((0.25, min(1, max(0, (ratio - 0.7) / 0.4))))
            factors.append(("HRV", "\(Int(t)) ms (média \(Int(b)))"))
        }
        // FC de repouso hoje vs. média
        if hk.isOn, let t = hk.rhrToday, let b = hk.rhrBase, b > 0 {
            let diff = t - b
            parts.append((0.15, min(1, max(0, 1 - diff / 8))))
            factors.append(("FC repouso", "\(Int(t)) bpm (média \(Int(b)))"))
        }
        // Humor e energia de hoje
        if let m = moods.first(where: { cal.isDateInToday($0.date) }) {
            let v = (Double(m.energy - 1) / 4 * 0.6) + (Double(5 - m.stress) / 4 * 0.4)
            parts.append((0.15, v)); factors.append(("Energia / estresse", "\(m.energy)/5 · \(m.stress)/5"))
        }
        // Carga dos últimos 2 dias
        let recent = sessions.filter { !$0.isActive && $0.start > .now.addingTimeInterval(-48 * 3600) }
        let sets = recent.flatMap(\.exercises).map { $0.workSets.count }.reduce(0, +)
        parts.append((0.10, min(1, max(0, 1 - Double(sets) / 60))))
        factors.append(("Séries nas últimas 48 h", "\(sets)"))

        guard parts.count >= 2 else { return nil }
        let total = parts.map(\.weight).reduce(0, +)
        let score = Int((parts.map { $0.weight * $0.value }.reduce(0, +) / total * 100).rounded())
        switch score {
        case 75...: return Result(score: score, advice: "Treine pesado: bom dia para buscar recordes.", color: Theme.good, factors: factors)
        case 50..<75: return Result(score: score, advice: "Treino normal: siga o plano.", color: Theme.warm, factors: factors)
        default: return Result(score: score, advice: "Pegue leve: reduza a carga ou faça mobilidade e cardio leve.", color: Theme.danger, factors: factors)
        }
    }
}

struct ReadinessCard: View {
    @Query(sort: \SleepEntry.wake, order: .reverse) private var sleep: [SleepEntry]
    @Query(sort: \MoodEntry.date, order: .reverse) private var moods: [MoodEntry]
    @Query(sort: \WorkoutSession.start, order: .reverse) private var sessions: [WorkoutSession]

    var body: some View {
        let r = Readiness.compute(sleep: Array(sleep.prefix(3)), moods: Array(moods.prefix(5)), sessions: Array(sessions.prefix(10)))
        Card {
            if let r {
                HStack(spacing: 16) {
                    ZStack {
                        ProgressRing(progress: Double(r.score) / 100, lineWidth: 9, colors: [r.color, r.color])
                        Text("\(r.score)").font(.title2.bold().monospacedDigit())
                    }
                    .frame(width: 70, height: 70)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Prontidão para treinar").font(.caption.bold()).foregroundStyle(.secondary)
                        Text(r.advice).font(.subheadline.bold())
                        Text(r.factors.map { "\($0.0): \($0.1)" }.joined(separator: " · "))
                            .font(.caption2).foregroundStyle(.secondary).lineLimit(3)
                    }
                }
            } else {
                Label("Registre o sono e o humor de hoje (ou ligue o Apple Saúde) para ver sua prontidão para treinar.",
                      systemImage: "gauge.with.needle").font(.callout).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - 10. Resumo semanal

struct WeeklySummaryView: View {
    @Query(sort: \WorkoutSession.start, order: .reverse) private var sessions: [WorkoutSession]
    @Query(sort: \WeightEntry.date, order: .reverse) private var weights: [WeightEntry]
    @Query(sort: \SleepEntry.wake, order: .reverse) private var sleep: [SleepEntry]
    @Query(sort: \MoodEntry.date, order: .reverse) private var moods: [MoodEntry]
    @Query private var foods: [FoodLog]
    @Query private var water: [WaterLog]

    init() {
        let from = Date.now.addingTimeInterval(-15 * 86400)
        _foods = Query(filter: #Predicate<FoodLog> { $0.date >= from })
        _water = Query(filter: #Predicate<WaterLog> { $0.date >= from })
    }

    struct Week {
        var workouts = 0, sets = 0, cardioMin = 0.0
        var kcal: Double?, protein: Double?, waterL: Double?, sleepH: Double?, mood: Double?, weight: Double?
        var muscles: [(Muscle, Double)] = []
    }

    private func week(_ offset: Int) -> Week {
        let cal = Calendar.current
        let end = cal.date(byAdding: .day, value: -7 * offset + 1, to: cal.startOfDay(for: .now))!
        let start = cal.date(byAdding: .day, value: -7, to: end)!
        let inRange: (Date) -> Bool = { $0 >= start && $0 < end }
        var w = Week()
        let ss = sessions.filter { !$0.isActive && inRange($0.start) }
        w.workouts = ss.count
        w.sets = ss.flatMap(\.exercises).map { $0.workSets.count }.reduce(0, +)
        var ms: [Muscle: Double] = [:]
        for e in ss.flatMap(\.exercises) {
            guard let x = e.exercise else { continue }
            if x.kind == .cardio { w.cardioMin += e.workSets.map(\.minutes).reduce(0, +); continue }
            let n = Double(e.workSets.count)
            for m in x.primary { ms[m, default: 0] += n }
            for m in x.secondary { ms[m, default: 0] += n * 0.5 }
        }
        w.muscles = ms.sorted { $0.value > $1.value }.map { ($0.key, $0.value) }
        let fl = foods.filter { inRange($0.date) }
        let days = Set(fl.map { cal.startOfDay(for: $0.date) }).count
        if days > 0 {
            w.kcal = fl.map(\.nutrients.kcal).reduce(0, +) / Double(days)
            w.protein = fl.map(\.nutrients.protein).reduce(0, +) / Double(days)
        }
        let wl = water.filter { inRange($0.date) }
        let wd = Set(wl.map { cal.startOfDay(for: $0.date) }).count
        if wd > 0 { w.waterL = wl.map(\.ml).reduce(0, +) / Double(wd) / 1000 }
        let sl = sleep.filter { inRange($0.wake) }
        if !sl.isEmpty { w.sleepH = sl.map(\.hours).reduce(0, +) / Double(sl.count) }
        let md = moods.filter { inRange($0.date) }
        if !md.isEmpty { w.mood = Double(md.map(\.mood).reduce(0, +)) / Double(md.count) }
        let wt = weights.filter { inRange($0.date) }
        if !wt.isEmpty { w.weight = wt.map(\.kg).reduce(0, +) / Double(wt.count) }
        return w
    }

    var body: some View {
        let now = week(0), prev = week(1)
        ScrollView {
            VStack(spacing: 14) {
                Card {
                    VStack(spacing: 10) {
                        Text("Últimos 7 dias vs. 7 anteriores").font(.caption.bold()).foregroundStyle(.secondary)
                        row("Treinos", "\(now.workouts)", Double(now.workouts), Double(prev.workouts), higherIsBetter: true)
                        row("Séries", "\(now.sets)", Double(now.sets), Double(prev.sets), higherIsBetter: true)
                        row("Cardio", "\(Int(now.cardioMin)) min", now.cardioMin, prev.cardioMin, higherIsBetter: true)
                        row("Calorias / dia", now.kcal.map { "\(Int($0)) kcal" }, now.kcal, prev.kcal, higherIsBetter: nil)
                        row("Proteína / dia", now.protein.map { "\(Int($0)) g" }, now.protein, prev.protein, higherIsBetter: true)
                        row("Água / dia", now.waterL.map { "\($0.fmt(1)) L" }, now.waterL, prev.waterL, higherIsBetter: true)
                        row("Sono", now.sleepH.map { "\($0.fmt(1)) h" }, now.sleepH, prev.sleepH, higherIsBetter: true)
                        row("Humor", now.mood.map { "\($0.fmt(1))/5" }, now.mood, prev.mood, higherIsBetter: true)
                        row("Peso médio", now.weight.map { "\($0.fmt(1)) kg" }, now.weight, prev.weight, higherIsBetter: nil)
                    }
                }
                if !now.muscles.isEmpty {
                    Card {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Séries por músculo").font(.headline)
                            ForEach(now.muscles.prefix(12), id: \.0) { m, v in
                                HStack(spacing: 8) {
                                    Text(m.label).font(.caption).frame(width: 84, alignment: .leading)
                                    ProgressBar(progress: v / 20, tint: Muscle.weeklySetsRange.contains(v) ? Theme.good : Theme.warm, height: 6)
                                    Text(v.fmt(0)).font(.caption.monospacedDigit()).frame(width: 26, alignment: .trailing)
                                }
                            }
                            Text("Faixa ideal: 10–20 séries por semana.").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding()
        }
        .background(AnimatedBackground())
        .navigationTitle("Resumo semanal")
    }

    private func row(_ title: String, _ value: String?, _ a: Double?, _ b: Double?, higherIsBetter: Bool?) -> some View {
        HStack {
            Text(title).font(.subheadline)
            Spacer()
            Text(value ?? "—").font(.subheadline.bold().monospacedDigit())
            if let a, let b, b != 0 {
                let d = (a - b) / abs(b) * 100
                let good = higherIsBetter.map { $0 == (d >= 0) }
                Text("\(d >= 0 ? "▲" : "▼") \(Int(abs(d)))%")
                    .font(.caption2.bold().monospacedDigit())
                    .foregroundStyle(good == nil ? Color.secondary : (good! ? Theme.good : Theme.warm))
                    .frame(width: 56, alignment: .trailing)
            } else {
                Text("").frame(width: 56)
            }
        }
    }
}

// MARK: - 11. Biblioteca de conceitos

struct Concept: Identifiable {
    let id: String, title: String, icon: String, body: String
}

enum ConceptLibrary {
    static let all: [Concept] = [
        Concept(id: "rir", title: "RIR e RPE", icon: "gauge.with.dots.needle.67percent",
                body: "RIR (repetições na reserva) é quantas repetições você ainda conseguiria fazer ao terminar a série. RPE é a mesma ideia numa escala de 1 a 10: RPE 8 = 2 RIR. Para hipertrofia, a maioria das séries deve terminar entre 0 e 3 RIR. Muito longe da falha estimula pouco; ir à falha em tudo gera fadiga desnecessária."),
        Concept(id: "progression", title: "Sobrecarga progressiva", icon: "chart.line.uptrend.xyaxis",
                body: "Para continuar evoluindo, o estímulo precisa aumentar com o tempo: mais carga, mais repetições, mais séries ou melhor técnica. O app usa a progressão dupla: primeiro você sobe as repetições até o topo da faixa em todas as séries; depois aumenta a carga e volta ao início da faixa."),
        Concept(id: "volume", title: "Volume semanal (10–20 séries)", icon: "square.stack.3d.up.fill",
                body: "O volume é o número de séries difíceis por músculo na semana. A faixa de 10 a 20 séries funciona para a maioria das pessoas. Iniciantes evoluem bem perto de 10; avançados podem precisar de mais. Dividir o volume em 2 ou mais dias por semana costuma render mais do que concentrar tudo num dia."),
        Concept(id: "frequency", title: "Frequência de treino", icon: "calendar",
                body: "Treinar cada músculo pelo menos 2 vezes por semana permite distribuir o volume com séries de melhor qualidade e mantém a síntese de proteína muscular elevada mais vezes na semana."),
        Concept(id: "deficit", title: "Déficit e superávit calórico", icon: "flame.fill",
                body: "Para perder gordura, coma menos do que gasta (déficit). Um ritmo de 0,25% a 1% do peso por semana preserva a massa magra. Para ganhar massa, um superávit pequeno (0,1% a 0,5% por semana) minimiza o ganho de gordura. O peso oscila dia a dia por água e sal: olhe a tendência de 2 a 3 semanas."),
        Concept(id: "protein", title: "Proteína", icon: "fork.knife",
                body: "Para quem treina, 1,6 a 2,2 g de proteína por kg por dia é o recomendado. Dividir em 3 a 5 refeições com 20 a 40 g cada ajuda a aproveitar melhor. Em déficit, ficar no topo da faixa protege a massa muscular."),
        Concept(id: "creatine", title: "Creatina", icon: "pills.fill",
                body: "É o suplemento mais estudado para força e massa muscular. A dose é de 3 a 5 g por dia, todos os dias, em qualquer horário; não precisa de fase de saturação. Pode aumentar 1 a 2 kg de água dentro do músculo, o que é normal. Pessoas com doença renal devem consultar um médico."),
        Concept(id: "sleep", title: "Sono e recuperação", icon: "bed.double.fill",
                body: "Dormir 7 a 9 horas melhora a força, a recuperação, o controle do apetite e o humor. Menos de 6 horas por noite reduz o desempenho e aumenta a perda de massa magra em déficit. Horários regulares e quarto escuro e fresco ajudam."),
        Concept(id: "hrv", title: "HRV e FC de repouso", icon: "waveform.path.ecg",
                body: "A variabilidade da frequência cardíaca (HRV) mostra o quanto o sistema nervoso está recuperado: HRV acima da sua média costuma indicar boa recuperação. Uma frequência cardíaca de repouso acima do normal pode indicar cansaço, estresse, álcool ou início de doença. Compare sempre com a sua própria média."),
        Concept(id: "deload", title: "Deload", icon: "arrow.down.circle.fill",
                body: "Uma semana com cerca de metade do volume a cada 4 a 8 semanas ajuda a dissipar fadiga acumulada. Faça quando as cargas pararem de subir, as articulações reclamarem ou a motivação cair."),
        Concept(id: "warmup", title: "Aquecimento", icon: "thermometer.medium",
                body: "Antes dos exercícios pesados, faça séries de aproximação com cargas crescentes (por exemplo 40%, 60% e 80% da carga de trabalho) e poucas repetições. Elas não contam como séries de trabalho e não devem cansar."),
        Concept(id: "water", title: "Hidratação", icon: "drop.fill",
                body: "Uma referência é 35 ml por kg de peso por dia, mais em dias quentes ou de treino longo. Urina clara é um bom sinal de hidratação. Perder 2% do peso em suor já reduz o desempenho."),
        Concept(id: "fiber", title: "Fibras", icon: "leaf.fill",
                body: "A meta é 25 a 35 g por dia. Fibras aumentam a saciedade, ajudam o intestino e o controle da glicemia. Fontes: feijão, aveia, frutas com casca, verduras e cereais integrais."),
        Concept(id: "bodyfat", title: "Gordura corporal e bioimpedância", icon: "figure.stand",
                body: "Balanças de bioimpedância estimam a gordura pela condução elétrica, que varia com a hidratação. Pese-se sempre nas mesmas condições (manhã, em jejum, após ir ao banheiro) e olhe a tendência, não o número de um dia."),
    ]
}

struct ConceptLibraryView: View {
    @State private var query = ""
    var body: some View {
        let q = FoodDatabase.normalize(query)
        let list = q.isEmpty ? ConceptLibrary.all
            : ConceptLibrary.all.filter { FoodDatabase.normalize($0.title + " " + $0.body).contains(q) }
        List(list) { c in
            DisclosureGroup {
                Text(c.body).font(.callout).padding(.vertical, 4)
            } label: {
                Label(c.title, systemImage: c.icon).font(.subheadline.bold())
            }
        }
        .searchable(text: $query, prompt: "Buscar conceito")
        .navigationTitle("Aprenda")
    }
}

// MARK: - Central de insights (no painel)

struct InsightsHubCard: View {
    @Query(sort: \WeightEntry.date, order: .reverse) private var weights: [WeightEntry]
    @Query private var profiles: [UserProfile]
    @Query private var water: [WaterLog]
    @State private var smartWater = WaterReminder.enabled

    init() {
        let today = Calendar.current.startOfDay(for: .now)
        _water = Query(filter: #Predicate<WaterLog> { $0.date >= today })
    }

    var body: some View {
        VStack(spacing: 12) {
            ReadinessCard()
            if let g = profiles.first?.goal { CalorieAdjustCard(weights: weights, goal: g) }
            Card {
                VStack(spacing: 0) {
                    link("Métricas avançadas: gasto real, força, carga, VO₂max…", "chart.bar.doc.horizontal") { AdvancedMetricsView() }
                    Divider().padding(.vertical, 8)
                    link("Comparar pesagens, treinos, alimentação e humor", "square.split.2x1") { CompareView() }
                    Divider().padding(.vertical, 8)
                    link("Resumo semanal", "calendar.badge.clock") { WeeklySummaryView() }
                    Divider().padding(.vertical, 8)
                    link("Recuperação muscular", "figure.cooldown") { RecoveryView() }
                    Divider().padding(.vertical, 8)
                    link("Aprenda: conceitos de treino e nutrição", "book.fill") { ConceptLibraryView() }
                    Divider().padding(.vertical, 8)
                    Toggle(isOn: $smartWater) {
                        Label("Lembretes de água inteligentes", systemImage: "drop.fill").font(.subheadline)
                    }
                    .onChange(of: smartWater) { _, on in
                        Task {
                            if on { smartWater = await WaterReminder.requestAndEnable() } else { WaterReminder.enabled = false }
                            WaterReminder.reschedule(todayMl: water.map(\.ml).reduce(0, +), targetMl: WaterReminder.enabled ? (weights.first?.kg ?? 70) * 35 : 0)
                        }
                    }
                }
            }
        }
    }

    private func link<D: View>(_ title: String, _ icon: String, @ViewBuilder _ dest: @escaping () -> D) -> some View {
        NavigationLink { dest() } label: {
            HStack {
                Label(title, systemImage: icon).font(.subheadline.bold())
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.tap)
    }
}
