import SwiftUI
import SwiftData

@main
struct GymApp: App {
    @State private var scanner = ScaleScanner()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(scanner)
                .tint(Theme.accent)
        }
        .modelContainer(for: [UserProfile.self, WeightEntry.self])
    }
}

struct RootView: View {
    @Environment(ScaleScanner.self) private var scanner
    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]
    @Query(sort: \WeightEntry.date, order: .reverse) private var entries: [WeightEntry]
    @State private var toast: String?
    @State private var tab = 0

    var body: some View {
        TabView(selection: $tab) {
            DashboardView()
                .tabItem { Label("Início", systemImage: "house.fill") }.tag(0)
            HistoryView()
                .tabItem { Label("Histórico", systemImage: "chart.xyaxis.line") }.tag(1)
            ProfileView()
                .tabItem { Label("Perfil", systemImage: "person.crop.circle") }.tag(2)
        }
        .overlay(alignment: .top) {
            if let toast {
                Label(toast, systemImage: "checkmark.circle.fill")
                    .font(.subheadline.bold())
                    .padding(.horizontal, 18).padding(.vertical, 12)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().strokeBorder(Theme.accent.opacity(0.5)))
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 8)
            }
        }
        .sensoryFeedback(.success, trigger: scanner.lastStable)
        .onChange(of: scanner.lastStable) { _, s in
            guard let s else { return }
            save(s)
        }
        .fullScreenCover(isPresented: .constant(profiles.isEmpty)) {
            OnboardingView { }
        }
    }

    /// Salva o peso estável; ignora repetição da mesma pesagem (até 2 min e < 0,3 kg).
    private func save(_ s: ScaleScanner.StableWeight) {
        if let last = entries.first, s.date.timeIntervalSince(last.date) < 120, abs(last.kg - s.kg) < 0.3 {
            return
        }
        let diff = entries.first.map { s.kg - $0.kg }
        context.insert(WeightEntry(date: s.date, kg: s.kg))
        var msg = "\(s.kg.fmt(2)) kg salvo"
        if let diff { msg += " (\(diff >= 0 ? "+" : "")\(diff.fmt(2)))" }
        withAnimation(.spring(duration: 0.5)) { toast = msg }
        Task {
            try? await Task.sleep(for: .seconds(3))
            withAnimation(.easeOut) { toast = nil }
        }
    }
}
