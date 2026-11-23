import SwiftUI
import SwiftData

struct MindInsight: Identifiable {
    let id = UUID()
    let icon: String
    let color: Color
    let title: String
    let text: String
    let strength: Double     // para ordenar (efeito absoluto)
}

/// Cruza humor com sono, treino, alimentação, água e práticas — tudo agrupado por dia uma única vez (O(n)).
enum MindInsightEngine {
    struct DayMood { var mood = 0.0, stress = 0.0, energy = 0.0, n = 0.0 }

    static func compute(moods: [MoodEntry], sleeps: [SleepEntry], workouts: [WorkoutSession], foods: [FoodLog],
                        water: [WaterLog], practices: [MindSession], steps: [Date: Double] = [:]) -> [MindInsight] {
        let cal = Calendar.current
        func day(_ d: Date) -> Date { cal.startOfDay(for: d) }

        var byDay: [Date: DayMood] = [:]
        var tagged: [Date: Set<MoodTag>] = [:]
        for m in moods {
            let d = day(m.date)
            var x = byDay[d] ?? DayMood()
            x.mood += Double(m.mood); x.stress += Double(m.stress); x.energy += Double(m.energy); x.n += 1
            byDay[d] = x
            tagged[d, default: []].formUnion(m.tags)
        }
        guard byDay.count >= 5 else { return [] }
        let days = byDay.mapValues { DayMood(mood: $0.mood / $0.n, stress: $0.stress / $0.n, energy: $0.energy / $0.n, n: 1) }

        var sleepHours: [Date: Double] = [:]
        for s in sleeps { sleepHours[s.day, default: 0] += s.hours }
        let trained = Set(workouts.filter { !$0.isActive }.map { day($0.start) })
        let practiced = Set(practices.map { day($0.date) })
        var waterDay: [Date: Double] = [:]
        for w in water { waterDay[day(w.date), default: 0] += w.ml }
        var sugarDay: [Date: Double] = [:], loggedFood = Set<Date>()
        for f in foods { let d = day(f.date); sugarDay[d, default: 0] += f.nutrients.sugar; loggedFood.insert(d) }

        var out: [MindInsight] = []

        func compare(_ name: String, icon: String, condition: (Date) -> Bool?, positive: String, negative: String,
                     metric: KeyPath<DayMood, Double> = \.mood, lowerIsBetter: Bool = false) {
            var yes: [Double] = [], no: [Double] = []
            for (d, m) in days {
                guard let c = condition(d) else { continue }
                if c { yes.append(m[keyPath: metric]) } else { no.append(m[keyPath: metric]) }
            }
            guard yes.count >= 3, no.count >= 3 else { return }
            let a = yes.reduce(0, +) / Double(yes.count), b = no.reduce(0, +) / Double(no.count)
            guard b > 0 else { return }
            let pct = (a - b) / b * 100
            guard abs(pct) >= 5 else { return }
            let good = lowerIsBetter ? pct < 0 : pct > 0
            out.append(MindInsight(icon: icon, color: good ? Theme.good : Theme.warm, title: name,
                                   text: (good ? positive : negative).replacingOccurrences(of: "{p}", with: "\(Int(abs(pct).rounded()))%")
                                    + " (\(yes.count) dias com × \(no.count) sem)",
                                   strength: abs(pct)))
        }

        compare("Treino e humor", icon: "dumbbell.fill", condition: { trained.contains($0) },
                positive: "Nos dias em que você treinou, seu humor foi {p} maior.",
                negative: "Nos dias de treino seu humor foi {p} menor — talvez cansaço; veja o sono e a recuperação.")
        compare("Treino e estresse", icon: "flame.fill", condition: { trained.contains($0) },
                positive: "Treinar esteve ligado a {p} menos estresse.",
                negative: "Nos dias de treino o estresse foi {p} maior.", metric: \.stress, lowerIsBetter: true)
        compare("Sono e humor", icon: "moon.zzz.fill", condition: { sleepHours[$0].map { $0 >= 7 } },
                positive: "Dormindo 7 h ou mais, seu humor fica {p} melhor.",
                negative: "Curiosamente, com 7 h+ de sono seu humor foi {p} menor.")
        compare("Sono e energia", icon: "bolt.fill", condition: { sleepHours[$0].map { $0 >= 7 } },
                positive: "Com 7 h ou mais de sono sua energia é {p} maior.",
                negative: "Mais sono não aumentou sua energia ({p} menor).", metric: \.energy)
        compare("Sono e estresse", icon: "bed.double.fill", condition: { sleepHours[$0].map { $0 < 6 } },
                positive: "Dormir menos de 6 h veio com {p} menos estresse (incomum).",
                negative: "Com menos de 6 h de sono seu estresse sobe {p}.", metric: \.stress, lowerIsBetter: true)
        compare("Práticas de respiração/meditação", icon: "wind", condition: { practiced.contains($0) },
                positive: "Nos dias com respiração, meditação ou foco, seu humor foi {p} maior.",
                negative: "Nos dias de prática o humor foi {p} menor — talvez você pratique justamente nos dias difíceis (o que é ótimo!).")
        compare("Água", icon: "drop.fill", condition: { waterDay[$0].map { $0 >= 2000 } },
                positive: "Bebendo 2 L de água ou mais, seu humor foi {p} melhor.",
                negative: "Mais água não melhorou o humor ({p} menor).")
        compare("Açúcar", icon: "cube.fill", condition: { loggedFood.contains($0) ? (sugarDay[$0] ?? 0) > 50 : nil },
                positive: "Dias com mais de 50 g de açúcar vieram com humor {p} maior.",
                negative: "Dias com mais de 50 g de açúcar tiveram humor {p} menor.")
        compare("Natureza e sol", icon: "sun.max.fill", condition: { tagged[$0].map { $0.contains(.nature) } },
                positive: "Dias com sol/natureza: humor {p} maior.",
                negative: "Dias com sol/natureza: humor {p} menor.")
        compare("Álcool", icon: "wineglass.fill", condition: { tagged[$0].map { $0.contains(.alcohol) } },
                positive: "Dias com álcool tiveram humor {p} maior — mas atenção ao dia seguinte.",
                negative: "Dias com álcool vieram com humor {p} menor.")
        compare("Amigos", icon: "person.2.fill", condition: { tagged[$0].map { $0.contains(.friends) || $0.contains(.family) } },
                positive: "Dias com amigos ou família: humor {p} maior. Conexão social é um dos maiores protetores da saúde mental.",
                negative: "Dias com amigos/família tiveram humor {p} menor.")
        compare("Telas", icon: "iphone", condition: { tagged[$0].map { $0.contains(.screen) } },
                positive: "Dias de muita tela tiveram humor {p} maior.",
                negative: "Dias de muita tela tiveram humor {p} menor.")

        compare("Passos e humor", icon: "figure.walk", condition: { steps[$0].map { $0 >= 7000 } },
                positive: "Nos dias com 7.000+ passos, seu humor foi {p} maior.",
                negative: "Dias com 7.000+ passos tiveram humor {p} menor.")
        compare("Passos e estresse", icon: "shoeprints.fill", condition: { steps[$0].map { $0 >= 7000 } },
                positive: "Caminhar 7.000+ passos veio com {p} menos estresse.",
                negative: "Nos dias de mais passos o estresse foi {p} maior.", metric: \.stress, lowerIsBetter: true)

        // Correlação sono × humor (Pearson)
        let pairs = days.compactMap { d, m in sleepHours[d].map { ($0, m.mood) } }
        if pairs.count >= 7 {
            let r = pearson(pairs.map(\.0), pairs.map(\.1))
            if abs(r) >= 0.3 {
                out.append(MindInsight(icon: "chart.xyaxis.line", color: r > 0 ? Theme.good : Theme.warm,
                                       title: "Correlação sono × humor: \(r.fmt(2))",
                                       text: r > 0 ? "Quanto mais você dorme, melhor tende a ser seu humor (correlação \(r >= 0.5 ? "forte" : "moderada"))."
                                                   : "Mais horas de sono estão ligadas a humor menor — pode valer avaliar a qualidade do sono.",
                                       strength: abs(r) * 40))
            }
        }

        // Tendência semanal
        let now = day(.now)
        let w1 = days.filter { $0.key > cal.date(byAdding: .day, value: -7, to: now)! }.map(\.value.mood)
        let w0 = days.filter { $0.key <= cal.date(byAdding: .day, value: -7, to: now)! && $0.key > cal.date(byAdding: .day, value: -14, to: now)! }.map(\.value.mood)
        if w1.count >= 3, w0.count >= 3 {
            let a = w1.reduce(0, +) / Double(w1.count), b = w0.reduce(0, +) / Double(w0.count)
            let d = a - b
            out.append(MindInsight(icon: d >= 0 ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill",
                                   color: d >= 0 ? Theme.good : Theme.warm, title: "Esta semana",
                                   text: abs(d) < 0.15 ? "Seu humor está estável em relação à semana passada (\(a.fmt(1))/5)."
                                        : "Seu humor médio \(d > 0 ? "subiu" : "caiu") de \(b.fmt(1)) para \(a.fmt(1)) em relação à semana passada.",
                                   strength: abs(d) * 30 + 1))
        }
        return out.sorted { $0.strength > $1.strength }
    }

    static func pearson(_ x: [Double], _ y: [Double]) -> Double {
        let n = Double(x.count)
        guard n > 1 else { return 0 }
        let mx = x.reduce(0, +) / n, my = y.reduce(0, +) / n
        var num = 0.0, dx = 0.0, dy = 0.0
        for i in x.indices { num += (x[i] - mx) * (y[i] - my); dx += pow(x[i] - mx, 2); dy += pow(y[i] - my, 2) }
        return dx > 0 && dy > 0 ? num / sqrt(dx * dy) : 0
    }
}

struct InsightRow: View {
    let insight: MindInsight
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: insight.icon).foregroundStyle(insight.color)
                .frame(width: 34, height: 34).background(insight.color.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 3) {
                Text(insight.title).font(.subheadline.bold())
                Text(insight.text).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct MindInsightsView: View {
    let insights: [MindInsight]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedBackground()
                ScrollView {
                    VStack(spacing: 12) {
                        if insights.isEmpty {
                            ContentUnavailableView("Ainda sem padrões", systemImage: "sparkles",
                                                   description: Text("Faça check-ins de humor por pelo menos 5 dias (e registre sono, treino e alimentação) para o app descobrir o que mais te afeta."))
                        }
                        ForEach(Array(insights.enumerated()), id: \.element.id) { i, ins in
                            Card { InsightRow(insight: ins) }.appear(Double(i) * 0.04)
                        }
                        Text("Correlação não é causa: estes padrões mostram o que costuma andar junto nos seus dados. Quanto mais dias registrados, mais confiáveis.")
                            .font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                    .padding()
                }
            }
            .navigationTitle("Corpo e mente")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("OK") { dismiss() } }
        }
    }
}
