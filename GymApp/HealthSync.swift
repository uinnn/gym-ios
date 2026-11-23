import Foundation
import HealthKit
import Observation
import SwiftData

/// Integração com o Apple Saúde. Fica ligada a um único perfil da família (o dono do iPhone).
@Observable
@MainActor
final class HealthSync {
    static let shared = HealthSync()
    @ObservationIgnored private let store = HKHealthStore()
    @ObservationIgnored private let d = UserDefaults.standard

    /// Perfil ligado ao Saúde (nil = desligado).
    private(set) var linkedProfile: String?

    // leituras de hoje / recentes
    private(set) var steps = 0.0
    private(set) var activeKcal = 0.0
    private(set) var restingHR: Double?
    private(set) var hrv: Double?
    private(set) var dailySteps: [Date: Double] = [:]    // últimos 90 dias
    // prontidão: hoje (últimas 24 h) e linha de base de 30 dias
    private(set) var hrvToday: Double?
    private(set) var hrvBase: Double?
    private(set) var rhrToday: Double?
    private(set) var rhrBase: Double?
    private(set) var lastNightHours: Double?
    private(set) var lastRefresh: Date?

    /// Usar calorias ativas do Saúde na meta de calorias (em vez de só as dos treinos).
    var useActiveKcal: Bool { didSet { d.set(useActiveKcal, forKey: "hk.useActive") } }

    var available: Bool { HKHealthStore.isHealthDataAvailable() }
    var isOn: Bool { linkedProfile != nil && linkedProfile == ProfileRegistry.shared.activeID }

    private init() {
        linkedProfile = d.string(forKey: "hk.profile")
        useActiveKcal = d.bool(forKey: "hk.useActive")
    }

    private var shareTypes: Set<HKSampleType> {
        [HKQuantityType(.bodyMass), HKQuantityType(.dietaryWater), HKQuantityType(.dietaryEnergyConsumed),
         HKObjectType.workoutType()]
    }
    private var readTypes: Set<HKObjectType> {
        [HKQuantityType(.stepCount), HKQuantityType(.activeEnergyBurned), HKQuantityType(.restingHeartRate),
         HKQuantityType(.heartRateVariabilitySDNN), HKQuantityType(.bodyMass), HKCategoryType(.sleepAnalysis),
         HKObjectType.workoutType()]
    }

    func connect() async throws {
        guard available else { return }
        try await store.requestAuthorization(toShare: shareTypes, read: readTypes)
        linkedProfile = ProfileRegistry.shared.activeID
        d.set(linkedProfile, forKey: "hk.profile")
        await refresh()
    }

    func disconnect() {
        linkedProfile = nil
        d.removeObject(forKey: "hk.profile")
        steps = 0; activeKcal = 0; restingHR = nil; hrv = nil; dailySteps = [:]
    }

    // MARK: Escrita

    private func save(_ s: HKSample) {
        guard isOn else { return }
        store.save(s) { _, _ in }
    }

    func saveWeight(_ kg: Double, date: Date) {
        save(HKQuantitySample(type: HKQuantityType(.bodyMass), quantity: HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: kg),
                              start: date, end: date))
    }

    func saveWater(_ ml: Double, date: Date) {
        save(HKQuantitySample(type: HKQuantityType(.dietaryWater), quantity: HKQuantity(unit: .literUnit(with: .milli), doubleValue: ml),
                              start: date, end: date))
    }

    func saveFood(kcal: Double, date: Date) {
        guard kcal > 0 else { return }
        save(HKQuantitySample(type: HKQuantityType(.dietaryEnergyConsumed), quantity: HKQuantity(unit: .kilocalorie(), doubleValue: kcal),
                              start: date, end: date))
    }

    func saveStrength(_ s: WorkoutSession) {
        guard isOn, let end = s.end else { return }
        saveWorkout(.traditionalStrengthTraining, start: s.start, end: end, kcal: WorkoutMath.kcal(s), km: nil)
    }

    func saveCardio(_ s: CardioSession) {
        let type: HKWorkoutActivityType = s.kind == .run ? .running : s.kind == .walk ? .walking : .cycling
        saveWorkout(type, start: s.start, end: s.start.addingTimeInterval(s.seconds), kcal: s.kcal, km: s.km)
    }

    private func saveWorkout(_ type: HKWorkoutActivityType, start: Date, end: Date, kcal: Double, km: Double?) {
        guard isOn else { return }
        let config = HKWorkoutConfiguration()
        config.activityType = type
        let builder = HKWorkoutBuilder(healthStore: store, configuration: config, device: .local())
        Task {
            do {
                try await builder.beginCollection(at: start)
                var samples: [HKSample] = [HKQuantitySample(type: HKQuantityType(.activeEnergyBurned),
                                                            quantity: HKQuantity(unit: .kilocalorie(), doubleValue: kcal),
                                                            start: start, end: end)]
                if let km, km > 0 {
                    let dt: HKQuantityType = type == .cycling ? HKQuantityType(.distanceCycling) : HKQuantityType(.distanceWalkingRunning)
                    samples.append(HKQuantitySample(type: dt, quantity: HKQuantity(unit: .meterUnit(with: .kilo), doubleValue: km),
                                                    start: start, end: end))
                }
                try await builder.addSamples(samples)
                try await builder.endCollection(at: end)
                _ = try await builder.finishWorkout()
            } catch {}
        }
    }

    // MARK: Leitura

    func refresh() async {
        guard isOn else { return }
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        async let st = sum(.stepCount, .count(), from: today)
        async let ak = sum(.activeEnergyBurned, .kilocalorie(), from: today)
        async let rhr = average(.restingHeartRate, HKUnit.count().unitDivided(by: .minute()), days: 7)
        async let v = average(.heartRateVariabilitySDNN, .secondUnit(with: .milli), days: 7)
        async let daily = dailySum(.stepCount, .count(), days: 90)
        async let hT = average(.heartRateVariabilitySDNN, .secondUnit(with: .milli), days: 1)
        async let hB = average(.heartRateVariabilitySDNN, .secondUnit(with: .milli), days: 30)
        async let rT = average(.restingHeartRate, HKUnit.count().unitDivided(by: .minute()), days: 1)
        async let rB = average(.restingHeartRate, HKUnit.count().unitDivided(by: .minute()), days: 30)
        async let nights = sleepNights(days: 1)
        steps = await st; activeKcal = await ak; restingHR = await rhr; hrv = await v; dailySteps = await daily
        hrvToday = await hT; hrvBase = await hB; rhrToday = await rT; rhrBase = await rB
        let n = await nights
        lastNightHours = n.last.map { $0.wake.timeIntervalSince($0.bed) / 3600 }
        lastRefresh = .now
    }

    private func sum(_ id: HKQuantityTypeIdentifier, _ unit: HKUnit, from: Date) async -> Double {
        await withCheckedContinuation { c in
            let q = HKStatisticsQuery(quantityType: HKQuantityType(id),
                                      quantitySamplePredicate: HKQuery.predicateForSamples(withStart: from, end: .now),
                                      options: .cumulativeSum) { _, r, _ in
                c.resume(returning: r?.sumQuantity()?.doubleValue(for: unit) ?? 0)
            }
            store.execute(q)
        }
    }

    private func average(_ id: HKQuantityTypeIdentifier, _ unit: HKUnit, days: Int) async -> Double? {
        await withCheckedContinuation { c in
            let from = Date.now.addingTimeInterval(-Double(days) * 86400)
            let q = HKStatisticsQuery(quantityType: HKQuantityType(id),
                                      quantitySamplePredicate: HKQuery.predicateForSamples(withStart: from, end: .now),
                                      options: .discreteAverage) { _, r, _ in
                c.resume(returning: r?.averageQuantity()?.doubleValue(for: unit))
            }
            store.execute(q)
        }
    }

    private func dailySum(_ id: HKQuantityTypeIdentifier, _ unit: HKUnit, days: Int) async -> [Date: Double] {
        let cal = Calendar.current
        let anchor = cal.startOfDay(for: .now)
        let from = cal.date(byAdding: .day, value: -days, to: anchor)!
        return await withCheckedContinuation { c in
            let q = HKStatisticsCollectionQuery(quantityType: HKQuantityType(id),
                                                quantitySamplePredicate: HKQuery.predicateForSamples(withStart: from, end: .now),
                                                options: .cumulativeSum, anchorDate: anchor, intervalComponents: DateComponents(day: 1))
            q.initialResultsHandler = { _, r, _ in
                var out: [Date: Double] = [:]
                r?.enumerateStatistics(from: from, to: .now) { s, _ in
                    if let v = s.sumQuantity()?.doubleValue(for: unit), v > 0 { out[s.startDate] = v }
                }
                c.resume(returning: out)
            }
            store.execute(q)
        }
    }

    /// Noites de sono (dormindo, qualquer estágio) dos últimos dias, agrupadas por noite.
    func sleepNights(days: Int) async -> [(bed: Date, wake: Date)] {
        guard isOn else { return [] }
        let from = Date.now.addingTimeInterval(-Double(days) * 86400)
        let samples: [HKCategorySample] = await withCheckedContinuation { c in
            let q = HKSampleQuery(sampleType: HKCategoryType(.sleepAnalysis),
                                  predicate: HKQuery.predicateForSamples(withStart: from, end: .now),
                                  limit: HKObjectQueryNoLimit,
                                  sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]) { _, s, _ in
                c.resume(returning: (s as? [HKCategorySample]) ?? [])
            }
            store.execute(q)
        }
        let asleep: Set<Int> = [HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue, HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                                HKCategoryValueSleepAnalysis.asleepDeep.rawValue, HKCategoryValueSleepAnalysis.asleepREM.rawValue]
        // junta trechos com intervalos < 1 h numa mesma noite
        var nights: [(bed: Date, wake: Date)] = []
        for s in samples where asleep.contains(s.value) {
            if let last = nights.last, s.startDate.timeIntervalSince(last.wake) < 3600 {
                nights[nights.count - 1].wake = max(last.wake, s.endDate)
            } else {
                nights.append((s.startDate, s.endDate))
            }
        }
        return nights.filter { $0.wake.timeIntervalSince($0.bed) >= 3 * 3600 }
    }

    /// Importa noites que ainda não estão no app. Retorna quantas foram adicionadas.
    func importSleep(into ctx: ModelContext) async -> Int {
        let nights = await sleepNights(days: 30)
        let existing = Set(((try? ctx.fetch(FetchDescriptor<SleepEntry>())) ?? []).map(\.day))
        var added = 0
        for n in nights {
            let e = SleepEntry(bedtime: n.bed, wake: n.wake, quality: 3)
            guard !existing.contains(e.day) else { continue }
            e.note = "Apple Saúde"
            ctx.insert(e)
            added += 1
        }
        return added
    }
}
