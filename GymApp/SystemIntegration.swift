import SwiftUI
import SwiftData
import ActivityKit
import WidgetKit
import AppIntents

// MARK: - Live Activities (Dynamic Island / tela bloqueada)

@MainActor
enum LiveActivities {
    private static var current: Activity<TimerActivityAttributes>?

    private static var enabled: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

    static func startWorkout(_ name: String, start: Date, subtitle: String) {
        begin(TimerActivityAttributes(kind: "workout", title: name, start: start),
              .init(subtitle: subtitle, restEnd: nil, goalEnd: nil))
    }

    static func startFasting(hours: Double, start: Date) {
        begin(TimerActivityAttributes(kind: "fasting", title: "Jejum \(Int(hours))h", start: start),
              .init(subtitle: "Meta às \(start.addingTimeInterval(hours * 3600).formatted(date: .omitted, time: .shortened))",
                    restEnd: nil, goalEnd: start.addingTimeInterval(hours * 3600)))
    }

    private static func begin(_ a: TimerActivityAttributes, _ s: TimerActivityAttributes.ContentState) {
        guard enabled else { return }
        // reaproveita se já existe uma igual (ex.: app reaberto no meio do treino)
        if let existing = Activity<TimerActivityAttributes>.activities.first(where: { $0.attributes.kind == a.kind && $0.attributes.start == a.start }) {
            current = existing
            return
        }
        end()
        current = try? Activity.request(attributes: a, content: .init(state: s, staleDate: nil))
    }

    static func update(subtitle: String, restEnd: Date?) {
        guard let c = current else { return }
        let s = TimerActivityAttributes.ContentState(subtitle: subtitle, restEnd: restEnd, goalEnd: c.content.state.goalEnd)
        Task { await c.update(.init(state: s, staleDate: nil)) }
    }

    static func end() {
        let all = Activity<TimerActivityAttributes>.activities
        current = nil
        Task { for a in all { await a.end(nil, dismissalPolicy: .immediate) } }
    }
}

// MARK: - Widgets: o app grava um resumo no App Group

@MainActor
enum WidgetBridge {
    static func update(_ ctx: ModelContext) {
        var snap = WidgetSnapshot()
        let profile = (try? ctx.fetch(FetchDescriptor<UserProfile>()))?.first
        snap.name = profile?.name ?? ""
        var w = FetchDescriptor<WeightEntry>(sortBy: [SortDescriptor(\.date, order: .reverse)]); w.fetchLimit = 60
        let weights = (try? ctx.fetch(w)) ?? []
        if let last = weights.first {
            snap.kg = last.kg
            let weekAgo = last.date.addingTimeInterval(-7 * 86400)
            if let old = weights.first(where: { $0.date <= weekAgo }) { snap.kgDelta7 = last.kg - old.kg }
            if let p = profile {
                snap.goalKg = p.goalWeightKg
                let t = NutritionTargets(analysis: BodyAnalysis(BodyInputs(kg: last.kg, profile: p)))
                snap.kcalGoal = t.kcal; snap.waterGoalMl = t.water
            }
        }
        let today = Calendar.current.startOfDay(for: .now)
        snap.waterMl = ((try? ctx.fetch(FetchDescriptor<WaterLog>(predicate: #Predicate { $0.date >= today }))) ?? []).map(\.ml).reduce(0, +)
        snap.kcal = ((try? ctx.fetch(FetchDescriptor<FoodLog>(predicate: #Predicate { $0.date >= today }))) ?? []).map(\.nutrients.kcal).reduce(0, +)
        // sequência: dias seguidos com qualquer registro (pesagem, treino, refeição ou humor)
        let since = today.addingTimeInterval(-120 * 86400)
        var days = Set<Date>()
        let cal = Calendar.current
        for e in weights where e.date >= since { days.insert(cal.startOfDay(for: e.date)) }
        for s in (try? ctx.fetch(FetchDescriptor<WorkoutSession>(predicate: #Predicate { $0.start >= since }))) ?? [] { days.insert(cal.startOfDay(for: s.start)) }
        for f in (try? ctx.fetch(FetchDescriptor<FoodLog>(predicate: #Predicate { $0.date >= since }))) ?? [] { days.insert(cal.startOfDay(for: f.date)) }
        for m in (try? ctx.fetch(FetchDescriptor<MoodEntry>(predicate: #Predicate { $0.date >= since }))) ?? [] { days.insert(cal.startOfDay(for: m.date)) }
        snap.streak = HabitMath.streaks(days).current
        let routines = (try? ctx.fetch(FetchDescriptor<WorkoutRoutine>(sortBy: [SortDescriptor(\.order)]))) ?? []
        let wd = Weekday.today
        snap.nextWorkout = routines.first { $0.weekday == wd }?.name ?? routines.first?.name
        snap.save()
        WidgetCenter.shared.reloadAllTimelines()
    }
}

// MARK: - Navegação pedida por Atalhos/Siri

@Observable
@MainActor
final class AppRouter {
    static let shared = AppRouter()
    var tab = 0
    var openCardio = false
    var openWorkout = false
}

// MARK: - Atalhos e Siri (App Intents)

struct LogWaterIntent: AppIntent {
    static let title: LocalizedStringResource = "Registrar água"
    static let description = IntentDescription("Adiciona água ao diário de hoje.")

    @Parameter(title: "Mililitros", default: 250) var ml: Int

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let ctx = ProfileRegistry.shared.container(for: ProfileRegistry.shared.activeID).mainContext
        ctx.insert(WaterLog(date: .now, ml: Double(ml)))
        try? ctx.save()
        HealthSync.shared.saveWater(Double(ml), date: .now)
        WidgetBridge.update(ctx)
        let total = WidgetSnapshot.load()?.waterMl ?? Double(ml)
        return .result(dialog: "Pronto! \(ml) ml registrados. Hoje: \((total / 1000).fmt(2)) L.")
    }
}

struct StartWorkoutIntent: AppIntent {
    static let title: LocalizedStringResource = "Começar treino"
    static let description = IntentDescription("Abre o Gym no treino do dia.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        AppRouter.shared.tab = 3
        AppRouter.shared.openWorkout = true
        return .result()
    }
}

struct StartCardioIntent: AppIntent {
    static let title: LocalizedStringResource = "Começar corrida"
    static let description = IntentDescription("Abre o cardio com GPS.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        AppRouter.shared.tab = 3
        AppRouter.shared.openCardio = true
        return .result()
    }
}

struct TodaySummaryIntent: AppIntent {
    static let title: LocalizedStringResource = "Resumo do dia"
    static let description = IntentDescription("Diz peso, calorias e água de hoje.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let ctx = ProfileRegistry.shared.container(for: ProfileRegistry.shared.activeID).mainContext
        WidgetBridge.update(ctx)
        guard let s = WidgetSnapshot.load() else { return .result(dialog: "Ainda não há dados.") }
        var parts: [String] = []
        if let kg = s.kg { parts.append("Peso \(kg.fmt(1)) kg") }
        parts.append("\(Int(s.kcal)) de \(Int(s.kcalGoal)) kcal")
        parts.append("\((s.waterMl / 1000).fmt(1)) de \((s.waterGoalMl / 1000).fmt(1)) L de água")
        if s.streak > 0 { parts.append("\(s.streak) dias seguidos") }
        return .result(dialog: "\(parts.joined(separator: ", ")).")
    }
}

struct GymShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: LogWaterIntent(), phrases: ["Registrar água no \(.applicationName)", "Beber água no \(.applicationName)"],
                    shortTitle: "Registrar água", systemImageName: "drop.fill")
        AppShortcut(intent: StartWorkoutIntent(), phrases: ["Começar treino no \(.applicationName)", "Treinar no \(.applicationName)"],
                    shortTitle: "Começar treino", systemImageName: "dumbbell.fill")
        AppShortcut(intent: StartCardioIntent(), phrases: ["Começar corrida no \(.applicationName)", "Correr com o \(.applicationName)"],
                    shortTitle: "Começar corrida", systemImageName: "figure.run")
        AppShortcut(intent: TodaySummaryIntent(), phrases: ["Resumo do dia no \(.applicationName)", "Como estou hoje no \(.applicationName)"],
                    shortTitle: "Resumo do dia", systemImageName: "chart.bar.fill")
    }
}

// MARK: - Apple Saúde: telas

struct HealthSection: View {
    @State private var hk = HealthSync.shared
    @State private var error: String?

    var body: some View {
        Section {
            if !hk.available {
                Text("Apple Saúde indisponível neste aparelho.").foregroundStyle(.secondary)
            } else if hk.isOn {
                Label("Conectado a este perfil", systemImage: "checkmark.circle.fill").foregroundStyle(Theme.good)
                Toggle(isOn: $hk.useActiveKcal) { Label("Usar calorias ativas na meta", systemImage: "flame.fill") }
                Button("Desconectar", role: .destructive) { hk.disconnect() }
            } else {
                Button {
                    Task {
                        do { try await hk.connect() } catch { self.error = error.localizedDescription }
                    }
                } label: { Label("Conectar ao Apple Saúde", systemImage: "heart.fill") }
                if hk.linkedProfile != nil {
                    Text("Já está ligado a outro perfil da família. Conectar aqui troca o perfil.").font(.caption).foregroundStyle(.secondary)
                }
            }
            if let error { Text(error).font(.caption).foregroundStyle(Theme.danger) }
        } header: { Text("Apple Saúde") } footer: {
            Text("Envia pesagens, água, calorias e treinos, e lê passos, calorias ativas, frequência cardíaca de repouso, variabilidade (HRV) e sono. Só um perfil da família pode ficar ligado: o dono deste iPhone.")
        }
    }
}

struct HealthTodayCard: View {
    @State private var hk = HealthSync.shared

    var body: some View {
        if hk.isOn {
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Hoje no Apple Saúde", systemImage: "heart.fill").font(.headline).foregroundStyle(Theme.danger)
                    HStack {
                        item("\(Int(hk.steps).formatted())", "passos", "figure.walk", progress: hk.steps / 8000)
                        item("\(Int(hk.activeKcal))", "kcal ativas", "flame.fill", progress: nil)
                        if let r = hk.restingHR { item("\(Int(r))", "bpm repouso", "heart.fill", progress: nil) }
                        if let v = hk.hrv { item("\(Int(v))", "ms HRV", "waveform.path.ecg", progress: nil) }
                    }
                    if let v = hk.hrv, let r = hk.restingHR {
                        Text(readiness(hrv: v, rhr: r)).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .task { await hk.refresh() }
        }
    }

    private func item(_ v: String, _ l: String, _ icon: String, progress: Double?) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Image(systemName: icon).foregroundStyle(Theme.accent)
            Text(v).font(.headline).contentTransition(.numericText())
            Text(l).font(.caption2).foregroundStyle(.secondary)
            if let progress { ProgressBar(progress: progress, tint: Theme.good, height: 4) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Prontidão simples pela HRV média e FC de repouso (valores populacionais de referência).
    private func readiness(hrv: Double, rhr: Double) -> String {
        if hrv >= 50 && rhr <= 65 { return "Recuperação boa: dia ótimo para treinar pesado." }
        if hrv < 25 || rhr >= 80 { return "Sinais de cansaço (HRV baixa ou repouso alto): prefira um treino leve, sono e hidratação." }
        return "Recuperação normal."
    }
}
