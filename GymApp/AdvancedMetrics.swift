import SwiftUI
import SwiftData

// MARK: - Modelo de exibição (o mesmo para o app e para o site)

struct AdvMetric: Identifiable {
    enum Tone: String { case good, warn, bad, neutral, info }
    let id = UUID()
    var title: String
    var value: String
    var unit = ""
    var status = ""
    var tone: Tone = .neutral
    var detail = ""
    /// Linhas extras (rótulo, valor).
    var rows: [(String, String)] = []
    /// Barra de 0 a 1 (opcional).
    var progress: Double?

    var dict: [String: Any] {
        var d: [String: Any] = ["title": title, "value": value, "unit": unit, "status": status, "tone": tone.rawValue, "detail": detail,
                                "rows": rows.map { ["label": $0.0, "value": $0.1] }]
        if let progress { d["progress"] = progress }
        return d
    }
}

struct AdvGroup: Identifiable {
    let id = UUID()
    var title: String
    var icon: String
    var items: [AdvMetric]
    var dict: [String: Any] { ["title": title, "icon": icon, "items": items.map(\.dict)] }
}

// MARK: - Cálculos

/// Métricas avançadas: gasto real, aderência, qualidade da dieta, força relativa, carga de treino,
/// equilíbrio muscular, progressão, VO₂max, sono, correlações, peso real e hidratação.
@MainActor
enum AdvancedMetrics {
    struct Input {
        var profile: UserProfile?
        var weights: [WeightEntry]       // ordem crescente
        var measurements: [MeasurementEntry]
        var foods: [FoodLog]
        var water: [WaterLog]
        var sessions: [WorkoutSession]   // só terminados
        var cardio: [CardioSession]
        var sleeps: [SleepEntry]
        var moods: [MoodEntry]
    }

    static func compute(_ i: Input) -> [AdvGroup] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let targets = NutrientContext.make(i.profile, i.weights, i.measurements).targets
        let bodyKg = i.weights.last?.kg ?? 70
        let male = (i.profile?.sex ?? .male) == .male
        let age = i.profile?.age ?? 30
        func day(_ d: Date) -> Date { cal.startOfDay(for: d) }
        func daysAgo(_ n: Int) -> Date { cal.date(byAdding: .day, value: -n, to: today) ?? today }

        // por dia
        let foodsByDay = Dictionary(grouping: i.foods) { day($0.date) }
        let kcalByDay = foodsByDay.mapValues { $0.map(\.nutrients.kcal).reduce(0, +) }
        let waterByDay = Dictionary(grouping: i.water) { day($0.date) }.mapValues { $0.map(\.ml).reduce(0, +) }
        let trainedDays = Set(i.sessions.map { day($0.start) })
        let ewma = trend(i.weights)

        var groups: [AdvGroup] = []

        // ---------------------------------------------------------------- Nutrição
        var nut: [AdvMetric] = []
        // 1) Gasto calórico real (TDEE adaptativo)
        do {
            let start = daysAgo(21)
            let logged = kcalByDay.filter { $0.key >= start && $0.key < today && $0.value >= 800 }
            let ws = ewma.filter { $0.date >= start }
            if logged.count >= 10, ws.count >= 4, let first = ws.first, let last = ws.last,
               last.date.timeIntervalSince(first.date) >= 10 * 86400 {
                let days = last.date.timeIntervalSince(first.date) / 86400
                let slope = (last.kg - first.kg) / days                     // kg por dia (tendência)
                let intake = logged.values.reduce(0, +) / Double(logged.count)
                let tdee = intake - slope * 7700
                let goal = i.profile?.goal ?? .maintain
                let suggested = tdee + goal.calorieDelta
                let formula = AnalysisContext(profile: i.profile, entries: i.weights, measurements: i.measurements)?.current[.tdee]?.value
                var m = AdvMetric(title: "Gasto calórico real", value: tdee.fmt(0), unit: "kcal/dia",
                                  status: logged.count >= 18 ? "Alta confiança" : "Confiança média", tone: .info,
                                  detail: "Calculado com o que você comeu (\(logged.count) dias registrados) e a tendência do peso (\((slope * 7).signed(2)) kg/semana) nas últimas 3 semanas.")
                m.rows = [("Média ingerida", "\(intake.fmt(0)) kcal"), ("Sugestão para \(goal.label.lowercased())", "\(suggested.fmt(0)) kcal"),
                          ("Meta atual do app", "\(targets.kcal.fmt(0)) kcal")]
                if let f = formula { m.rows.append(("Estimativa por fórmula", "\(f.fmt(0)) kcal")) }
                nut.append(m)
            } else {
                nut.append(AdvMetric(title: "Gasto calórico real", value: "—", status: "Faltam dados", tone: .neutral,
                                     detail: "Precisa de 10+ dias com a alimentação registrada e 4+ pesagens nas últimas 3 semanas. Hoje: \(kcalByDay.filter { $0.key >= daysAgo(21) && $0.value >= 800 }.count) dias e \(i.weights.filter { $0.date >= daysAgo(21) }.count) pesagens."))
            }
        }
        // 2) Aderência às metas (7 dias)
        do {
            let days = (1...7).map(daysAgo)
            let logged = days.filter { (kcalByDay[$0] ?? 0) > 0 }
            let kcalOK = logged.filter { abs((kcalByDay[$0] ?? 0) - targets.kcal) <= targets.kcal * 0.1 }.count
            let protOK = logged.filter { (foodsByDay[$0] ?? []).map(\.nutrients.protein).reduce(0, +) >= targets.protein * 0.9 }.count
            let waterOK = days.filter { (waterByDay[$0] ?? 0) >= targets.water * 0.9 }.count
            var streak = 0
            for n in 1...60 {
                let d = daysAgo(n), k = kcalByDay[d] ?? 0
                if k > 0 && abs(k - targets.kcal) <= targets.kcal * 0.1 { streak += 1 } else { break }
            }
            let score = Double(kcalOK + protOK + waterOK) / 21
            var m = AdvMetric(title: "Aderência às metas", value: "\(Int((score * 100).rounded()))", unit: "%",
                              status: score >= 0.7 ? "Excelente" : score >= 0.45 ? "Boa" : "Pode melhorar",
                              tone: score >= 0.7 ? .good : score >= 0.45 ? .warn : .bad,
                              detail: "Últimos 7 dias completos. Calorias contam quando ficam a ±10% da meta.")
            m.rows = [("Calorias na meta", "\(kcalOK) de 7 dias"), ("Proteína ≥ 90%", "\(protOK) de 7 dias"),
                      ("Água ≥ 90%", "\(waterOK) de 7 dias"), ("Sequência nas calorias", "\(streak) dia(s)")]
            m.progress = score
            nut.append(m)
        }
        // 3) Qualidade da dieta
        do {
            let week = i.foods.filter { $0.date >= daysAgo(7) }
            let n = week.map(\.nutrients).total, mi = week.compactMap(\.micros).total
            if n.kcal > 500 {
                let protK = n.protein / n.kcal * 1000, fibK = n.fiber / n.kcal * 1000
                let variety = Set(week.map { $0.foodID.isEmpty ? $0.name : $0.foodID }).count
                let naK = n.potassium > 0 ? n.sodium / n.potassium : 0
                let o63 = mi.omega3 > 0 ? mi.omega6 / mi.omega3 : 0
                func part(_ v: Double, _ good: Double) -> Double { min(1, max(0, v / good)) }
                let s1 = part(protK, 50), s2 = part(fibK, 14), s3 = part(Double(variety), 30)
                let s4 = naK == 0 ? 0.5 : min(1, max(0, (2 - naK) / 1.2))
                let s5 = o63 == 0 ? 0.5 : min(1, max(0, (12 - o63) / 8))
                let score = (s1 + s2 + s3 + s4 + s5) / 5 * 100
                var m = AdvMetric(title: "Qualidade da dieta", value: score.fmt(0), unit: "/ 100",
                                  status: score >= 75 ? "Ótima" : score >= 55 ? "Boa" : "Pode melhorar",
                                  tone: score >= 75 ? .good : score >= 55 ? .warn : .bad,
                                  detail: "Nota dos últimos 7 dias, combinando densidade de proteína e fibra, variedade e equilíbrio de sódio e gorduras.")
                m.rows = [("Proteína por 1.000 kcal", "\(protK.fmt(0)) g (bom ≥ 50)"), ("Fibra por 1.000 kcal", "\(fibK.fmt(1)) g (bom ≥ 14)"),
                          ("Alimentos diferentes", "\(variety) (bom ≥ 30)"),
                          ("Sódio / potássio", naK > 0 ? "\(naK.fmt(2)) (bom < 1)" : "sem dados"),
                          ("Ômega-6 / ômega-3", o63 > 0 ? "\(o63.fmt(1)) (bom < 4)" : "sem dados")]
                m.progress = score / 100
                nut.append(m)
            }
        }
        groups.append(AdvGroup(title: "Nutrição", icon: "fork.knife", items: nut))

        // ---------------------------------------------------------------- Treino
        var tr: [AdvMetric] = []
        let recent = i.sessions.filter { $0.start >= daysAgo(90) }
        func best1RM(_ id: String, in s: [WorkoutSession]) -> Double {
            s.flatMap { $0.exercises.filter { $0.exerciseID == id }.flatMap(\.workSets) }.map(\.e1RM).max() ?? 0
        }
        // 4) Força relativa, nível e DOTS
        do {
            let lifts: [(String, String, [Double], [Double])] = [   // id, nome, limites homem, limites mulher (× peso corporal)
                ("bench", "Supino", [0.5, 0.75, 1.25, 1.75], [0.25, 0.5, 0.75, 1.0]),
                ("squat", "Agachamento", [0.75, 1.25, 1.75, 2.5], [0.5, 0.75, 1.25, 1.75]),
                ("deadlift", "Levantamento terra", [1.0, 1.5, 2.25, 3.0], [0.5, 1.0, 1.5, 2.25]),
                ("ohp", "Desenvolvimento", [0.35, 0.55, 0.8, 1.1], [0.2, 0.35, 0.5, 0.75]),
            ]
            let names = ["Iniciante", "Novato", "Intermediário", "Avançado", "Elite"]
            var any = false
            var m = AdvMetric(title: "Força relativa", value: "", status: "", tone: .info,
                              detail: "1RM estimado (melhor dos últimos 90 dias) dividido pelo seu peso. Níveis de referência para \(male ? "homens" : "mulheres").")
            var levels: [Int] = []
            for (id, name, mt, ft) in lifts {
                let rm = best1RM(id, in: recent)
                guard rm > 0 else { continue }
                any = true
                let ratio = rm / bodyKg
                let t = male ? mt : ft
                let lv = t.lastIndex { ratio >= $0 }.map { $0 + 1 } ?? 0
                levels.append(lv)
                m.rows.append((name, "\(ratio.fmt(2))× peso · \(names[lv])"))
            }
            if any {
                let avgLv = Int((Double(levels.reduce(0, +)) / Double(levels.count)).rounded())
                m.value = names[avgLv]; m.status = "Nível geral"; m.tone = avgLv >= 3 ? .good : avgLv >= 2 ? .info : .neutral
                // DOTS (powerlifting): total dos três básicos ajustado pelo peso corporal
                let total = best1RM("squat", in: recent) + best1RM("bench", in: recent) + best1RM("deadlift", in: recent)
                if best1RM("squat", in: recent) > 0, best1RM("bench", in: recent) > 0, best1RM("deadlift", in: recent) > 0 {
                    let w = min(max(bodyKg, 40), 210)
                    let c: [Double] = male ? [-0.0000010930, 0.0007391293, -0.1918759221, 24.0900756, -307.75076]
                                           : [-0.0000010706, 0.0005158568, -0.1126655495, 13.6175032, -57.96288]
                    let den = c[0] * pow(w, 4) + c[1] * pow(w, 3) + c[2] * w * w + c[3] * w + c[4]
                    let dots = total * 500 / den
                    m.rows.append(("Total (3 básicos)", "\(total.fmt(0)) kg"))
                    m.rows.append(("DOTS", "\(dots.fmt(0)) pts (300 bom · 400 avançado · 500 elite)"))
                }
                tr.append(m)
            } else {
                tr.append(AdvMetric(title: "Força relativa", value: "—", status: "Faltam dados", detail: "Registre supino, agachamento, terra ou desenvolvimento com carga para ver seu nível."))
            }
        }
        // 5) Carga de treino: ACWR, monotonia e strain (sRPE de Foster)
        do {
            func load(_ s: WorkoutSession) -> Double {
                let rpes = s.exercises.flatMap(\.workSets).compactMap(\.rpe)
                let rpe = rpes.isEmpty ? 7 : rpes.reduce(0, +) / Double(rpes.count)
                return min(s.duration / 60, 180) * rpe
            }
            var daily: [Date: Double] = [:]
            for s in i.sessions where s.start >= daysAgo(28) { daily[day(s.start), default: 0] += load(s) }
            for c in i.cardio where c.start >= daysAgo(28) { daily[day(c.start), default: 0] += c.seconds / 60 * 6 }
            let acute = (0..<7).map { daily[daysAgo($0)] ?? 0 }
            let acuteSum = acute.reduce(0, +)
            let chronicWeek = (0..<28).map { daily[daysAgo($0)] ?? 0 }.reduce(0, +) / 4
            if chronicWeek > 0 {
                let ratio = acuteSum / chronicWeek
                let mean = acuteSum / 7
                let sd = sqrt(acute.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / 7)
                let monotony = sd > 0 ? mean / sd : 0
                let (st, tone): (String, AdvMetric.Tone) = ratio < 0.8 ? ("Carga caindo (destreino)", .warn)
                    : ratio <= 1.3 ? ("Zona ideal", .good) : ratio <= 1.5 ? ("Atenção: subiu rápido", .warn) : ("Risco de sobrecarga", .bad)
                var m = AdvMetric(title: "Carga de treino (ACWR)", value: ratio.fmt(2), status: st, tone: tone,
                                  detail: "Carga dos últimos 7 dias ÷ média semanal do último mês (minutos × esforço). Entre 0,8 e 1,3 é o ideal; acima de 1,5 o risco de lesão sobe.")
                m.rows = [("Carga da semana", acuteSum.fmt(0)), ("Média semanal (28 dias)", chronicWeek.fmt(0)),
                          ("Monotonia", monotony > 0 ? "\(monotony.fmt(2))\(monotony > 2 ? " · treino muito repetitivo" : "")" : "—"),
                          ("Strain", monotony > 0 ? (acuteSum * monotony).fmt(0) : "—")]
                m.progress = min(1, ratio / 2)
                tr.append(m)
            }
        }
        // 6) Equilíbrio muscular (28 dias)
        do {
            let ms = WorkoutMath.muscleSets(i.sessions.filter { $0.start >= daysAgo(28) })
            func s(_ list: [Muscle]) -> Double { list.map { ms[$0] ?? 0 }.reduce(0, +) }
            let push = s([.chest, .shoulders, .triceps]), pull = s([.back, .biceps, .traps])
            let quads = s([.quads]), hams = s([.hamstrings])
            let upper = push + pull, lower = s([.quads, .hamstrings, .glutes, .calves, .adductors])
            if upper + lower > 0 {
                func row(_ name: String, _ a: Double, _ b: Double, _ ok: ClosedRange<Double>) -> (String, String, Bool) {
                    guard b > 0 else { return (name, a > 0 ? "só o primeiro lado" : "—", a == 0) }
                    let r = a / b
                    return (name, "\(r.fmt(2)) \(ok.contains(r) ? "✓" : r > ok.upperBound ? "↑ alto" : "↓ baixo")", ok.contains(r))
                }
                let rows = [row("Empurrar / puxar", push, pull, 0.8...1.25), row("Quadríceps / posterior", quads, hams, 0.8...1.5),
                            row("Superior / inferior", upper, lower, 0.8...1.6)]
                let okCount = rows.filter(\.2).count
                var m = AdvMetric(title: "Equilíbrio muscular", value: "\(okCount)/3", unit: "em equilíbrio",
                                  status: okCount == 3 ? "Equilibrado" : "Ajustar", tone: okCount == 3 ? .good : okCount == 2 ? .warn : .bad,
                                  detail: "Séries das últimas 4 semanas. Desequilíbrios grandes favorecem dores e problemas de postura (ex.: muito peito e pouca costas).")
                m.rows = rows.map { ($0.0, $0.1) }
                tr.append(m)
            }
        }
        // 7) Progressão por exercício
        do {
            let ids = Set(i.sessions.filter { $0.start >= daysAgo(60) }.flatMap { $0.exercises.map(\.exerciseID) })
            var rows: [(String, String, Double)] = []
            var stalled: [String] = []
            for id in ids {
                guard let x = ExerciseCatalog.byID[id], x.kind == .strength || x.kind == .bodyweight else { continue }
                let last30 = best1RM(id, in: i.sessions.filter { $0.start >= daysAgo(30) })
                let prev30 = best1RM(id, in: i.sessions.filter { $0.start >= daysAgo(60) && $0.start < daysAgo(30) })
                if last30 > 0, prev30 > 0 { rows.append((x.name, "\(((last30 - prev30) / prev30 * 100).signed(1))%", (last30 - prev30) / prev30)) }
                // estagnado: treinou 3+ vezes nas últimas 3 semanas sem superar o melhor anterior
                let times = i.sessions.filter { $0.start >= daysAgo(21) && $0.exercises.contains { $0.exerciseID == id } }.count
                let before = best1RM(id, in: i.sessions.filter { $0.start < daysAgo(21) })
                if times >= 3, before > 0, best1RM(id, in: i.sessions.filter { $0.start >= daysAgo(21) }) <= before { stalled.append(x.name) }
            }
            if !rows.isEmpty || !stalled.isEmpty {
                let sorted = rows.sorted { $0.2 > $1.2 }
                let avg = rows.isEmpty ? 0 : rows.map(\.2).reduce(0, +) / Double(rows.count) * 100
                var m = AdvMetric(title: "Progressão (30 dias)", value: rows.isEmpty ? "—" : avg.signed(1), unit: rows.isEmpty ? "" : "% média",
                                  status: stalled.isEmpty ? "Evoluindo" : "\(stalled.count) estagnado(s)", tone: stalled.isEmpty ? .good : .warn,
                                  detail: "1RM estimado do último mês comparado com o mês anterior. Estagnado = 3+ treinos em 3 semanas sem superar o recorde.")
                m.rows = Array(sorted.prefix(8).map { ($0.0, $0.1) })
                if !stalled.isEmpty { m.rows.append(("Estagnados", stalled.prefix(4).joined(separator: ", "))) }
                tr.append(m)
            }
        }
        groups.append(AdvGroup(title: "Treino", icon: "dumbbell.fill", items: tr))

        // ---------------------------------------------------------------- Cardio
        var car: [AdvMetric] = []
        // 8) VO2max estimado (fórmula de Daniels & Gilbert a partir de corridas)
        do {
            func vo2max(km: Double, seconds: Double) -> Double? {
                let t = seconds / 60
                guard km >= 1.5, t >= 6, t <= 240 else { return nil }
                let v = km * 1000 / t
                let vo2 = -4.60 + 0.182258 * v + 0.000104 * v * v
                let pct = 0.8 + 0.1894393 * exp(-0.012778 * t) + 0.2989558 * exp(-0.1932605 * t)
                let r = vo2 / pct
                return (20...90).contains(r) ? r : nil
            }
            let runs = i.cardio.filter { $0.kind == .run && $0.start >= daysAgo(90) }
            let vals = runs.compactMap { r in vo2max(km: r.km, seconds: r.seconds).map { (r.start, $0) } }.sorted { $0.0 < $1.0 }
            if let best = vals.map(\.1).max() {
                let base = male ? 47.5 : 39.5
                let fitnessAge = min(90, max(18, 25 + (base - best) / 0.32))
                let cls: (String, AdvMetric.Tone) = {
                    let norm = base - 0.32 * Double(age - 25)
                    return best >= norm + 6 ? ("Excelente", .good) : best >= norm ? ("Bom", .good) : best >= norm - 6 ? ("Regular", .warn) : ("Baixo", .bad)
                }()
                var m = AdvMetric(title: "VO₂max estimado", value: best.fmt(1), unit: "ml/kg/min", status: cls.0, tone: cls.1,
                                  detail: "Estimado pelas suas corridas dos últimos 90 dias (distância e tempo). Correr em ritmo forte deixa a estimativa mais precisa.")
                m.rows = [("Idade de condicionamento", "\(Int(fitnessAge.rounded())) anos (sua idade: \(age))"), ("Corridas usadas", "\(vals.count)")]
                if vals.count >= 2, let f = vals.first?.1, let l = vals.last?.1 { m.rows.append(("Evolução no período", "\((l - f).signed(1))")) }
                car.append(m)
            } else {
                car.append(AdvMetric(title: "VO₂max estimado", value: "—", status: "Faltam dados", detail: "Registre uma corrida de pelo menos 1,5 km (no app de cardio ou pelo Assistente) para estimar."))
            }
        }
        groups.append(AdvGroup(title: "Cardio", icon: "figure.run", items: car))

        // ---------------------------------------------------------------- Sono e mente
        var mind: [AdvMetric] = []
        // 9) Regularidade e débito de sono
        do {
            let last = i.sleeps.filter { $0.wake >= daysAgo(14) }
            if last.count >= 4 {
                func minutes(_ d: Date, pivot: Int) -> Double {      // minutos a partir de um horário de corte (evita a virada da meia-noite)
                    let c = cal.dateComponents([.hour, .minute], from: d)
                    var m = Double((c.hour ?? 0) * 60 + (c.minute ?? 0)) - Double(pivot * 60)
                    if m < 0 { m += 1440 }
                    return m
                }
                func sd(_ v: [Double]) -> Double { let m = v.reduce(0, +) / Double(v.count); return sqrt(v.map { ($0 - m) * ($0 - m) }.reduce(0, +) / Double(v.count)) }
                let bedSD = sd(last.map { minutes($0.bedtime, pivot: 12) }), wakeSD = sd(last.map { minutes($0.wake, pivot: 0) })
                let score = max(0, min(100, 100 - (bedSD + wakeSD) / 2 * 0.8))
                let week = i.sleeps.filter { $0.wake >= daysAgo(7) }
                let debt = max(0, week.map { 7.5 - $0.hours }.reduce(0, +))
                var m = AdvMetric(title: "Regularidade do sono", value: score.fmt(0), unit: "/ 100",
                                  status: score >= 80 ? "Muito regular" : score >= 60 ? "Regular" : "Irregular",
                                  tone: score >= 80 ? .good : score >= 60 ? .warn : .bad,
                                  detail: "Dormir e acordar em horários parecidos melhora energia, humor e recuperação, tanto quanto dormir mais horas.")
                m.rows = [("Variação na hora de dormir", "±\(Int(bedSD)) min"), ("Variação na hora de acordar", "±\(Int(wakeSD)) min"),
                          ("Débito de sono (7 dias)", debt > 0.1 ? "\(debt.fmt(1)) h abaixo de 7,5 h/noite" : "sem débito ✓")]
                m.progress = score / 100
                mind.append(m)
            }
        }
        // 10) Correlações (seus padrões)
        do {
            var found: [(String, String)] = []
            let span = (1...60).map(daysAgo)
            let sleepByDay = Dictionary(grouping: i.sleeps, by: \.day).mapValues { $0.map(\.hours).reduce(0, +) }
            let moodByDay = Dictionary(grouping: i.moods) { day($0.date) }.mapValues { l in Double(l.map(\.mood).reduce(0, +)) / Double(l.count) }
            let energyByDay = Dictionary(grouping: i.moods) { day($0.date) }.mapValues { l in Double(l.map(\.energy).reduce(0, +)) / Double(l.count) }
            let volByDay = Dictionary(grouping: i.sessions) { day($0.start) }.mapValues { $0.map(WorkoutMath.volume).reduce(0, +) }
            func compare(_ title: String, _ days: [Date], split: (Date) -> Bool?, value: (Date) -> Double?, unit: String, pct: Bool) {
                var a: [Double] = [], b: [Double] = []
                for d in days { guard let s = split(d), let v = value(d) else { continue }; if s { a.append(v) } else { b.append(v) } }
                guard a.count >= 3, b.count >= 3 else { return }
                let ma = a.reduce(0, +) / Double(a.count), mb = b.reduce(0, +) / Double(b.count)
                guard mb != 0 else { return }
                let diff = pct ? (ma - mb) / abs(mb) * 100 : ma - mb
                guard abs(diff) >= (pct ? 5 : 0.2) else { return }
                found.append((title, pct ? "\(diff.signed(0))% (\(ma.fmt(0)) vs \(mb.fmt(0))\(unit))" : "\(diff.signed(1)) (\(ma.fmt(1)) vs \(mb.fmt(1)))"))
            }
            compare("Volume de treino com 7 h+ de sono", span, split: { d in sleepByDay[d].map { $0 >= 7 } }, value: { volByDay[$0] }, unit: " kg", pct: true)
            compare("Humor nos dias em que treina", span, split: { d in moodByDay[d] == nil ? nil : trainedDays.contains(d) }, value: { moodByDay[$0] }, unit: "", pct: false)
            compare("Humor com 7 h+ de sono", span, split: { d in sleepByDay[d].map { $0 >= 7 } }, value: { moodByDay[$0] }, unit: "", pct: false)
            compare("Energia com água na meta", span, split: { d in energyByDay[d] == nil ? nil : (waterByDay[d] ?? 0) >= targets.water * 0.9 }, value: { energyByDay[$0] }, unit: "", pct: false)
            compare("Energia no dia seguinte a 90%+ das calorias", span, split: { d in
                guard let prev = cal.date(byAdding: .day, value: -1, to: d), let k = kcalByDay[prev], energyByDay[d] != nil else { return nil }
                return k >= targets.kcal * 0.9
            }, value: { energyByDay[$0] }, unit: "", pct: false)
            var m = AdvMetric(title: "Seus padrões", value: found.isEmpty ? "—" : "\(found.count)", unit: found.isEmpty ? "" : "encontrado(s)",
                              status: found.isEmpty ? "Ainda aprendendo" : "Últimos 60 dias", tone: .info,
                              detail: found.isEmpty ? "Quanto mais você registra sono, humor, água e treinos, mais padrões aparecem (precisa de 3+ dias em cada lado da comparação)."
                                  : "Comparações entre dias com e sem cada hábito. Mostram associação, não necessariamente causa.")
            m.rows = found
            mind.append(m)
        }
        groups.append(AdvGroup(title: "Sono e mente", icon: "moon.stars.fill", items: mind))

        // ---------------------------------------------------------------- Corpo
        var body: [AdvMetric] = []
        // 11) Peso real (tendência suavizada)
        if let last = ewma.last {
            let weekAgo = ewma.last { $0.date <= last.date.addingTimeInterval(-7 * 86400) }
            let rate = weekAgo.map { last.kg - $0.kg } ?? 0
            let pct = weekAgo.map { ($0.kg > 0 ? rate / $0.kg * 100 : 0) } ?? 0
            let goal = i.profile?.goal ?? .maintain
            let ok: Bool = {
                switch goal {
                case .lose: return pct <= -0.25 && pct >= -1.0
                case .gain: return pct >= 0.1 && pct <= 0.5
                case .maintain: return abs(pct) <= 0.25
                }
            }()
            var m = AdvMetric(title: "Peso real (tendência)", value: last.kg.fmt(1), unit: "kg",
                              status: weekAgo == nil ? "Poucos dados" : (ok ? "Ritmo ideal" : "Fora do ritmo ideal"),
                              tone: weekAgo == nil ? .neutral : ok ? .good : .warn,
                              detail: "Média móvel exponencial das pesagens: filtra as oscilações de água e sal e mostra o peso que realmente está mudando.")
            m.rows = [("Última balança", "\((i.weights.last?.kg ?? 0).fmt(1)) kg"),
                      ("Ritmo semanal", weekAgo == nil ? "—" : "\(rate.signed(2)) kg (\(pct.signed(2))%)"),
                      ("Ideal para \(goal.label.lowercased())", goal == .lose ? "−0,25% a −1% por semana" : goal == .gain ? "+0,1% a +0,5% por semana" : "±0,25% por semana")]
            body.append(m)
        }
        // 12) Hidratação por kg
        do {
            let days = (1...7).map(daysAgo)
            let logged = days.filter { (waterByDay[$0] ?? 0) > 0 }
            if !logged.isEmpty {
                let avg = logged.map { waterByDay[$0] ?? 0 }.reduce(0, +) / Double(logged.count)
                let perKg = avg / bodyKg
                let trainDays = logged.filter { trainedDays.contains($0) }
                let ideal = 35.0
                var m = AdvMetric(title: "Hidratação por kg", value: perKg.fmt(0), unit: "ml/kg",
                                  status: perKg >= ideal ? "Bem hidratado" : perKg >= 28 ? "Quase lá" : "Abaixo do ideal",
                                  tone: perKg >= ideal ? .good : perKg >= 28 ? .warn : .bad,
                                  detail: "Média dos dias com água registrada nos últimos 7 dias. Referência: 35 ml por kg, mais ~500 ml nos dias de treino.")
                m.rows = [("Média por dia", "\(avg.fmt(0)) ml"), ("Ideal para você", "\((bodyKg * ideal).fmt(0)) ml (+500 ml se treinar)")]
                if !trainDays.isEmpty {
                    let t = trainDays.map { waterByDay[$0] ?? 0 }.reduce(0, +) / Double(trainDays.count)
                    m.rows.append(("Nos dias de treino", "\(t.fmt(0)) ml"))
                }
                m.progress = min(1, perKg / ideal)
                body.append(m)
            }
        }
        groups.append(AdvGroup(title: "Corpo", icon: "figure.stand", items: body))

        return groups.filter { !$0.items.isEmpty }
    }

    /// Média móvel exponencial do peso (um ponto por pesagem).
    static func trend(_ weights: [WeightEntry]) -> [(date: Date, kg: Double)] {
        var out: [(Date, Double)] = []
        var t: Double?
        for w in weights {
            let alpha = 0.15
            t = t.map { $0 + alpha * (w.kg - $0) } ?? w.kg
            out.append((w.date, t!))
        }
        return out.map { (date: $0.0, kg: $0.1) }
    }

    /// Lê tudo do banco do perfil (para o resumo enviado ao site).
    static func compute(context: ModelContext) -> [AdvGroup] {
        compute(Input(
            profile: (try? context.fetch(FetchDescriptor<UserProfile>()))?.first,
            weights: (try? context.fetch(FetchDescriptor<WeightEntry>(sortBy: [SortDescriptor(\.date)]))) ?? [],
            measurements: (try? context.fetch(FetchDescriptor<MeasurementEntry>())) ?? [],
            foods: (try? context.fetch(FetchDescriptor<FoodLog>())) ?? [],
            water: (try? context.fetch(FetchDescriptor<WaterLog>())) ?? [],
            sessions: ((try? context.fetch(FetchDescriptor<WorkoutSession>())) ?? []).filter { !$0.isActive },
            cardio: (try? context.fetch(FetchDescriptor<CardioSession>())) ?? [],
            sleeps: (try? context.fetch(FetchDescriptor<SleepEntry>())) ?? [],
            moods: (try? context.fetch(FetchDescriptor<MoodEntry>())) ?? []))
    }
}

// MARK: - Tela

struct AdvancedMetricsView: View {
    @Environment(\.modelContext) private var context
    @Query private var weights: [WeightEntry]
    @Query private var foods: [FoodLog]
    @Query private var sessions: [WorkoutSession]
    @State private var groups: [AdvGroup] = []

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if groups.isEmpty { ProgressView().padding(40) }
                ForEach(groups) { g in
                    VStack(alignment: .leading, spacing: 10) {
                        SectionHeader(title: g.title, icon: g.icon)
                        ForEach(g.items) { AdvMetricCard(m: $0) }
                    }
                }
                Text("Estimativas para acompanhar tendências; não substituem avaliação profissional.")
                    .font(.caption2).foregroundStyle(.secondary).padding(.top, 4)
            }
            .padding()
        }
        .background(AnimatedBackground())
        .navigationTitle("Métricas avançadas")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: "\(weights.count)|\(foods.count)|\(sessions.count)") { groups = AdvancedMetrics.compute(context: context) }
    }
}

struct AdvMetricCard: View {
    let m: AdvMetric
    @State private var open = false

    private var color: Color {
        switch m.tone {
        case .good: Theme.good
        case .warn: Theme.warm
        case .bad: Theme.danger
        case .info: Theme.accent
        case .neutral: .secondary
        }
    }

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(m.title).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                    Spacer()
                    if !m.status.isEmpty { StatusChip(text: m.status, color: color) }
                }
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(m.value).font(.system(.title, design: .rounded).bold()).monospacedDigit().contentTransition(.numericText())
                    Text(m.unit).font(.subheadline).foregroundStyle(.secondary)
                }
                if let p = m.progress { ProgressBar(progress: p, tint: color, height: 6) }
                if !m.rows.isEmpty {
                    VStack(spacing: 6) {
                        ForEach(Array(m.rows.enumerated()), id: \.offset) { _, r in
                            HStack(alignment: .top) {
                                Text(r.0).font(.caption).foregroundStyle(.secondary)
                                Spacer(minLength: 12)
                                Text(r.1).font(.caption.weight(.medium)).multilineTextAlignment(.trailing)
                            }
                        }
                    }
                }
                if !m.detail.isEmpty {
                    Button { withAnimation(.snappy) { open.toggle() } } label: {
                        Label(open ? "Menos" : "Como é calculado", systemImage: open ? "chevron.up" : "info.circle")
                            .font(.caption2.bold())
                    }
                    .buttonStyle(.plain).foregroundStyle(Theme.accent)
                    if open { Text(m.detail).font(.caption).foregroundStyle(.secondary).transition(.opacity) }
                }
            }
        }
    }
}
