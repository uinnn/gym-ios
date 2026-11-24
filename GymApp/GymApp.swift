import SwiftUI
import SwiftData

@main
struct GymApp: App {
    @State private var scanner = ScaleScanner()
    @State private var registry = ProfileRegistry.shared
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(scanner)
                .modelContainer(registry.container(for: registry.activeID))
                .id(registry.activeID)
                .transition(.opacity)
                .onChange(of: registry.activeID, initial: true) { _, id in PartyService.shared.load(profile: id) }
                .onChange(of: phase, initial: true) { _, p in
                    if p == .active { PartyService.shared.startPolling() } else { PartyService.shared.stopPolling() }
                }
        }
    }
}

struct RootView: View {
    @Environment(ScaleScanner.self) private var scanner
    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]
    @Query(sort: \WeightEntry.date, order: .reverse) private var entries: [WeightEntry]
    @State private var toast: Toast?
    @State private var report: WeightEntry?
    @Environment(\.scenePhase) private var rootPhase
    @State private var tab = 0
    private var store: ThemeStore { ThemeStore.shared }

    struct Toast: Equatable {
        let id = UUID()
        let text: String
        let entry: WeightEntry
        let suspicious: Bool
        var owner: ProfileInfo? = nil
        static func == (a: Toast, b: Toast) -> Bool { a.id == b.id }
    }

    var body: some View {
        TabView(selection: $tab) {
            DashboardView()
                .tabItem { Label("Início", systemImage: "house.fill") }.tag(0)
            BodyView()
                .tabItem { Label("Corpo", systemImage: "figure.stand") }.tag(1)
            NutritionView()
                .tabItem { Label("Alimentação", systemImage: "fork.knife") }.tag(2)
            WorkoutsView()
                .tabItem { Label("Treinos", systemImage: "dumbbell.fill") }.tag(3)
            MindView()
                .tabItem { Label("Mente", systemImage: "brain.head.profile") }.tag(4)
        }
        .tint(Theme.accent)
        .preferredColorScheme(store.appearance.scheme)
        .fontDesign(store.font.design)
        .modifier(TextSizeModifier(size: store.textSize.size))
        .overlay { HubOrb() }
        .overlay(alignment: .top) { toastView }
        .sensoryFeedback(.success, trigger: scanner.lastStable) { _, _ in store.haptics }
        .sensoryFeedback(.selection, trigger: tab) { _, _ in store.haptics }
        .onChange(of: scanner.lastStable) { _, s in
            guard let s else { return }
            save(s)
        }
        .sheet(item: $report) { ReportView(entry: $0) }
        .onChange(of: rootPhase, initial: true) { _, p in
            if p == .active {
                AchievementEngine.check(context)
                Task { await HealthSync.shared.refresh() }
            } else if p == .background {
                WidgetBridge.update(context)
            }
        }
        .onChange(of: AppRouter.shared.tab) { _, t in tab = t }
        .onChange(of: entries.count) { _, _ in AchievementEngine.check(context); WidgetBridge.update(context) }
        .fullScreenCover(isPresented: .constant(profiles.isEmpty)) {
            OnboardingView { }
        }
        .onAppear { syncRegistry() }
        .onChange(of: profileSignature) { _, _ in syncRegistry() }
    }

    private var profileSignature: String {
        guard let p = profiles.first else { return "" }
        return "\(p.name)|\(p.sexRaw)|\(p.birthDate.timeIntervalSince1970)|\(p.heightCm)|\(entries.first?.kg ?? 0)"
    }

    /// Mantém o resumo do perfil (lista de perfis) igual aos dados do banco.
    private func syncRegistry() {
        let reg = ProfileRegistry.shared
        guard let p = profiles.first else { return }
        reg.update(reg.activeID) {
            if !p.name.isEmpty { $0.name = p.name }
            $0.sexRaw = p.sexRaw; $0.birthDate = p.birthDate; $0.heightCm = p.heightCm
            $0.lastKg = entries.first?.kg; $0.lastWeighed = entries.first?.date
        }
    }

    @ViewBuilder private var toastView: some View {
        if let toast {
            HStack(spacing: 12) {
                Image(systemName: toast.suspicious ? "person.fill.questionmark" : "checkmark.circle.fill")
                    .foregroundStyle(toast.suspicious ? Theme.warm : Theme.good)
                    .symbolEffect(.bounce, value: toast.id)
                Text(toast.text).font(.subheadline.bold()).lineLimit(2)
                Spacer(minLength: 0)
                if let owner = toast.owner {
                    Button {
                        let e = toast.entry
                        ProfileRegistry.shared.addWeight(e.kg, date: e.date, to: owner.id)
                        withAnimation(.spring) {
                            context.delete(e)
                            self.toast = nil
                        }
                        syncRegistry()
                    } label: {
                        HStack(spacing: 4) { Text(owner.emoji); Text("Salvar em \(owner.name)") }
                    }
                    .font(.caption.bold())
                    .buttonStyle(.borderedProminent).tint(owner.color)
                }
                Button(toast.suspicious ? "Não sou eu" : "Desfazer") {
                    withAnimation(.spring) {
                        context.delete(toast.entry)
                        self.toast = nil
                    }
                    syncRegistry()
                }
                .font(.caption.bold())
                .buttonStyle(.bordered)
                Button {
                    report = toast.entry
                    withAnimation { self.toast = nil }
                } label: { Image(systemName: "doc.text.magnifyingglass") }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Theme.accent.opacity(0.4)))
            .padding(.horizontal)
            .padding(.top, 6)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    /// Salva o peso estável; ignora repetição da mesma pesagem (até 2 min e < 0,3 kg).
    private func save(_ s: ScaleScanner.StableWeight) {
        if let last = entries.first, s.date.timeIntervalSince(last.date) < 120, abs(last.kg - s.kg) < 0.3 {
            return
        }
        // Pesagem muito diferente da média recente: provavelmente outra pessoa.
        let recent = entries.prefix(5).map(\.kg)
        let avg = recent.isEmpty ? s.kg : recent.reduce(0, +) / Double(recent.count)
        let suspicious = !recent.isEmpty && abs(s.kg - avg) / avg > 0.08

        let e = WeightEntry(date: s.date, kg: s.kg)
        let hour = Calendar.current.component(.hour, from: s.date)
        if hour < 10 { e.tags = [.morning] } else if hour >= 21 { e.tags = [.night] }
        context.insert(e)
        let party = PartyService.shared
        let delta = entries.first.map { s.kg - $0.kg } ?? 0
        party.post(.weight, party.showExactWeight
                   ? "pesou \(s.kg.fmt(1)) kg" + (entries.isEmpty ? "" : " (\(delta.signed(1)) kg)")
                   : (entries.isEmpty ? "fez a primeira pesagem ⚖️" : "pesou-se: \(delta.signed(1)) kg"),
                   value: suspicious ? 0 : delta)
        if !suspicious { HealthSync.shared.saveWeight(s.kg, date: s.date) }

        let owner = (suspicious || recent.isEmpty) ? ProfileRegistry.shared.likelyOwner(of: s.kg) : nil
        var msg = "\(s.kg.fmt(2)) kg salvo"
        if let prev = entries.first { msg += " (\((s.kg - prev.kg).signed(2)))" }
        if suspicious { msg = "\(s.kg.fmt(2)) kg é bem diferente do seu habitual. É você?" }
        if let owner { msg = "\(s.kg.fmt(2)) kg parece ser de \(owner.name) (último: \((owner.lastKg ?? 0).fmt(1)) kg)." }
        let t = Toast(text: msg, entry: e, suspicious: suspicious || owner != nil, owner: owner)
        ProfileRegistry.shared.update(ProfileRegistry.shared.activeID) { $0.lastKg = s.kg; $0.lastWeighed = s.date }
        withAnimation(.spring(duration: 0.5)) { toast = t }

        if store.autoOpenReport && !t.suspicious {
            Task {
                try? await Task.sleep(for: .seconds(2.5))
                if toast == t { report = e }
            }
        }
        Task {
            try? await Task.sleep(for: .seconds(t.suspicious ? 12 : 4))
            if toast == t { withAnimation(.easeOut) { toast = nil } }
        }
    }
}

enum BodySection: String, CaseIterable, Identifiable {
    case metrics = "Métricas", measures = "Medidas", photos = "Fotos", history = "Histórico"
    var id: String { rawValue }
}

/// Aba Corpo: métricas, medidas e histórico de peso.
struct BodyView: View {
    @State private var section: BodySection = .metrics

    var body: some View {
        NavigationStack {
            Group {
                switch section {
                case .metrics: MetricsView()
                case .measures: MeasurementsView()
                case .photos: ProgressPhotosView()
                case .history: HistoryView()
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink { CompareView(mode: .weights) } label: { Image(systemName: "square.split.2x1") }
                }
            }
            .safeAreaInset(edge: .top) {
                Picker("Seção", selection: $section.animation(.spring(duration: 0.35))) {
                    ForEach(BodySection.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 6)
                .background(.bar)
            }
        }
    }
}

/// Tamanho de texto escolhido no tema (ou o do sistema).
struct TextSizeModifier: ViewModifier {
    let size: DynamicTypeSize?
    func body(content: Content) -> some View {
        if let size { content.dynamicTypeSize(size) } else { content }
    }
}
