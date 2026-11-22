import XCTest
import SwiftData
@testable import Gym

/// Benchmark dos caminhos mais pesados do app, com dados realistas (1 ano de uso).
/// Imprime linhas "BENCH <nome> <mediana ms>" que o workflow coleta.
@MainActor
final class BenchmarkTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    private var profile: UserProfile!
    private var weights: [WeightEntry] = []
    private var measurements: [MeasurementEntry] = []
    private var sessions: [WorkoutSession] = []
    private var logs: [FoodLog] = []
    private var saved: [SavedFood] = []

    /// Gerador determinístico (mesmos dados em toda execução).
    private struct LCG {
        var s: UInt64 = 42
        mutating func next() -> Double {
            s = s &* 6364136223846793005 &+ 1442695040888963407
            return Double(s >> 11) / Double(1 << 53)
        }
    }

    override func setUp() async throws {
        let schema = Schema([UserProfile.self, WeightEntry.self, MeasurementEntry.self, FoodLog.self, SavedFood.self,
                             WaterLog.self, FastingSession.self, WorkoutSession.self, WorkoutRoutine.self])
        container = try ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        context = container.mainContext
        var r = LCG()
        let p = UserProfile()
        p.name = "Bench"; p.heightCm = 175; p.goalWeightKg = 72
        context.insert(p); profile = p
        let start = Date.now.addingTimeInterval(-365 * 86400)
        for d in 0..<365 {
            let w = WeightEntry(date: start.addingTimeInterval(Double(d) * 86400 + 7 * 3600), kg: 78 - Double(d) * 0.015 + r.next())
            context.insert(w); weights.append(w)
        }
        for i in 0..<30 {
            let m = MeasurementEntry(date: start.addingTimeInterval(Double(i) * 12 * 86400))
            m.waist = 86 - Double(i) * 0.1; m.hip = 98; m.neck = 38; m.armL = 34; m.armR = 34.5
            m.thighL = 56; m.thighR = 56.4; m.calfL = 37; m.calfR = 37.2; m.wrist = 17; m.shoulders = 118; m.chest = 100
            context.insert(m); measurements.append(m)
        }
        let ids = ["bench", "squat", "deadlift", "barbell-row", "ohp", "lat-pulldown", "leg-press", "lateral-raise",
                   "barbell-curl", "triceps-rope", "rdl", "incline-db"]
        for i in 0..<150 {
            let ex = (0..<6).map { j -> SessionExercise in
                let id = ids[(i + j) % ids.count]
                let sets = (0..<4).map { _ in SetLog(kg: 40 + r.next() * 60, reps: 6 + Int(r.next() * 6), done: true) }
                return SessionExercise(exerciseID: id, sets: sets)
            }
            let s = WorkoutSession(name: "Treino \(i % 4)", exercises: ex, bodyKg: 76)
            s.start = start.addingTimeInterval(Double(i) * 2.4 * 86400)
            s.end = s.start.addingTimeInterval(3600)
            context.insert(s); sessions.append(s)
        }
        let foods = Array(FoodDatabase.shared.foods.prefix(400))
        for d in 0..<180 {
            for k in 0..<12 {
                let f = foods[(d * 7 + k * 13) % foods.count]
                let l = FoodLog(date: start.addingTimeInterval(Double(d) * 86400 + Double(k) * 3600), meal: Meal.allCases[k % 6],
                                food: f, grams: 50 + r.next() * 150)
                context.insert(l); logs.append(l)
            }
        }
        for f in foods.prefix(300) {
            let s = SavedFood(f); context.insert(s); saved.append(s)
        }
        try context.save()
    }

    /// Mede `block` várias vezes e imprime a mediana.
    private func bench(_ name: String, iterations: Int = 7, _ block: () -> Void) {
        block() // aquecimento
        var times: [Double] = []
        let clock = ContinuousClock()
        for _ in 0..<iterations {
            let t = clock.measure { block() }
            times.append(Double(t.components.attoseconds) / 1e15 + Double(t.components.seconds) * 1000)
        }
        times.sort()
        let median = times[times.count / 2]
        print(String(format: "BENCH %@ %.3f", name, median))
    }

    func testBenchmarks() {
        // 1. Análise corporal completa de uma pesagem
        bench("01_analise_corporal") {
            for w in weights.suffix(30) {
                let a = BodyAnalysis(BodyInputs(kg: w.kg, profile: profile, measurement: measurements.last))
                for id in MetricID.allCases { _ = a[id] }
            }
        }
        // 2. Tela de métricas: todas as métricas + progresso até a meta de cada uma
        bench("02_tela_metricas") {
            guard let ctx = AnalysisContext(profile: profile, entries: weights, measurements: measurements) else { return }
            let a = ctx.current
            for m in a.metrics { _ = ctx.progress(m.id) }
            _ = a.bodyScore; _ = a.bodyType
        }
        // 3. Histórico de uma métrica (gráfico do detalhe)
        bench("03_historico_metrica", iterations: 3) {
            guard let ctx = AnalysisContext(profile: profile, entries: weights, measurements: measurements) else { return }
            _ = ctx.series(.bodyFat)
        }
        // 4. Medidas mescladas por data (usadas em cada análise)
        bench("04_medidas_mescladas") {
            for w in weights.suffix(120) { _ = measurements.merged(before: w.date) }
        }
        // 5. Busca de alimentos (2.589 itens)
        let queries = ["arroz", "frango grelhado", "pao", "queijo", "banana", "feijao carioca", "ovo", "pizza", "leite", "batata"]
        bench("05_busca_alimentos") { for q in queries { _ = FoodDatabase.shared.search(q) } }
        // 6. Melhores fontes de nutrientes
        bench("06_melhores_fontes") {
            for id in [NutrientID.protein, .iron, .calcium, .vitaminC, .fiber] { _ = FoodDatabase.shared.topSources(id) }
        }
        // 7. Busca de exercícios
        bench("07_busca_exercicios") {
            for q in ["supino", "agachamento", "rosca", "costas", "perna", "ombro", "abdomen", "corrida"] {
                _ = ExerciseCatalog.search(q)
            }
        }
        // 8. Histórico de treino: recorde e última vez de cada exercício (tela de treino ao vivo)
        bench("08_recordes_treino") {
            for id in ["bench", "squat", "deadlift", "ohp", "barbell-row", "lat-pulldown"] {
                _ = WorkoutMath.best(id, in: sessions)
                _ = WorkoutMath.previous(id, before: .now, in: sessions)
            }
        }
        // 9. Estatísticas de treino: volume, calorias e séries por músculo
        bench("09_estatisticas_treino") {
            _ = sessions.map(WorkoutMath.volume).reduce(0, +)
            _ = sessions.map(WorkoutMath.kcal).reduce(0, +)
            _ = WorkoutMath.muscleSets(sessions)
        }
        // 10. Diário de alimentação: totais e nutrientes de 14 dias
        bench("10_diario_14_dias") {
            let cal = Calendar.current
            for i in 0..<14 {
                let day = cal.date(byAdding: .day, value: -i - 180, to: .now)!
                let dl = logs.filter { cal.isDate($0.date, inSameDayAs: day) }
                _ = dl.map(\.nutrients).total
                _ = dl.compactMap(\.micros).total
            }
        }
        // 11. Alimentos salvos (lista de recentes/favoritos)
        bench("11_alimentos_salvos") { _ = saved.compactMap(\.food).count }
        // 12. Metas nutricionais (calculadas a cada atualização da tela de alimentação)
        bench("12_metas_nutricionais") {
            for _ in 0..<10 {
                if let ctx = AnalysisContext(profile: profile, entries: weights, measurements: measurements) {
                    _ = NutritionTargets(analysis: ctx.current)
                }
            }
        }
    }
}
