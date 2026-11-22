import SwiftUI
import SwiftData

@main
struct GymApp: App {
    @State private var scanner = ScaleScanner()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(scanner)
        }
        .modelContainer(for: [UserProfile.self, WeightEntry.self, MeasurementEntry.self])
    }
}

struct RootView: View {
    @Environment(ScaleScanner.self) private var scanner
    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]
    @Query(sort: \WeightEntry.date, order: .reverse) private var entries: [WeightEntry]
    @State private var toast: Toast?
    @State private var report: WeightEntry?
    @State private var tab = 0
    private var store: ThemeStore { ThemeStore.shared }

    struct Toast: Equatable {
        let id = UUID()
        let text: String
        let entry: WeightEntry
        let suspicious: Bool
        static func == (a: Toast, b: Toast) -> Bool { a.id == b.id }
    }

    var body: some View {
        TabView(selection: $tab) {
            DashboardView()
                .tabItem { Label("Início", systemImage: "house.fill") }.tag(0)
            MetricsView()
                .tabItem { Label("Métricas", systemImage: "chart.pie.fill") }.tag(1)
            HistoryView()
                .tabItem { Label("Histórico", systemImage: "chart.xyaxis.line") }.tag(2)
            MeasurementsView()
                .tabItem { Label("Medidas", systemImage: "ruler.fill") }.tag(3)
            ProfileView()
                .tabItem { Label("Perfil", systemImage: "person.crop.circle") }.tag(4)
        }
        .tint(Theme.accent)
        .preferredColorScheme(store.appearance.scheme)
        .overlay(alignment: .top) { toastView }
        .sensoryFeedback(.success, trigger: scanner.lastStable) { _, _ in store.haptics }
        .sensoryFeedback(.selection, trigger: tab) { _, _ in store.haptics }
        .onChange(of: scanner.lastStable) { _, s in
            guard let s else { return }
            save(s)
        }
        .sheet(item: $report) { ReportView(entry: $0) }
        .fullScreenCover(isPresented: .constant(profiles.isEmpty)) {
            OnboardingView { }
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
                Button(toast.suspicious ? "Não sou eu" : "Desfazer") {
                    withAnimation(.spring) {
                        context.delete(toast.entry)
                        self.toast = nil
                    }
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

        var msg = "\(s.kg.fmt(2)) kg salvo"
        if let prev = entries.first { msg += " (\((s.kg - prev.kg).signed(2)))" }
        if suspicious { msg = "\(s.kg.fmt(2)) kg é bem diferente do seu habitual. É você?" }
        let t = Toast(text: msg, entry: e, suspicious: suspicious)
        withAnimation(.spring(duration: 0.5)) { toast = t }

        if store.autoOpenReport && !suspicious {
            Task {
                try? await Task.sleep(for: .seconds(2.5))
                if toast == t { report = e }
            }
        }
        Task {
            try? await Task.sleep(for: .seconds(suspicious ? 10 : 4))
            if toast == t { withAnimation(.easeOut) { toast = nil } }
        }
    }
}
