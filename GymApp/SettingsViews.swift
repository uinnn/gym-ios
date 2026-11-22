import SwiftUI
import UserNotifications

// MARK: - Tema

struct ThemeSettingsView: View {
    @Bindable private var store = ThemeStore.shared
    @Namespace private var ns

    var body: some View {
        ZStack {
            AnimatedBackground()
            ScrollView {
                VStack(spacing: 20) {
                    preview.appear()
                    section("Aparência", "circle.lefthalf.filled") { appearancePicker }.appear(0.05)
                    section("Cor de destaque", "paintpalette.fill") { palettePicker }.appear(0.1)
                    section("Fundo", "sparkles") { backgroundPicker }.appear(0.15)
                    section("Cartões", "rectangle.on.rectangle") {
                        Picker("Cartões", selection: Binding(get: { store.card }, set: { v in withAnimation(.spring) { store.card = v } })) {
                            ForEach(CardStyle.allCases) { Text($0.label).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }
                    .appear(0.2)
                    section("Movimento", "wand.and.stars") {
                        VStack(spacing: 12) {
                            Toggle("Animações", isOn: $store.animations)
                            Toggle("Vibração (haptics)", isOn: $store.haptics)
                        }
                        .tint(Theme.accent)
                    }
                    .appear(0.25)
                }
                .padding()
            }
        }
        .navigationTitle("Tema")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func section<C: View>(_ title: String, _ icon: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon).font(.headline)
            Card { content() }
        }
    }

    /// Prévia ao vivo.
    private var preview: some View {
        Card {
            HStack(spacing: 16) {
                ZStack {
                    ProgressRing(progress: 0.68, lineWidth: 10)
                    Text("68%").font(.headline)
                }
                .frame(width: 76, height: 76)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Prévia").font(.caption).foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text("72,40").font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.gradient)
                        Text("kg").foregroundStyle(.secondary)
                    }
                    HStack {
                        StatusChip(text: "Saudável", color: Theme.good)
                        StatusChip(text: store.palette.name, color: Theme.accent)
                    }
                }
            }
        }
        .animation(.spring(duration: 0.5), value: store.paletteID)
    }

    private var appearancePicker: some View {
        HStack(spacing: 10) {
            ForEach(Appearance.allCases) { a in
                let on = store.appearance == a
                Button {
                    withAnimation(.spring(duration: 0.45)) { store.appearance = a }
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: a.icon)
                            .font(.title2)
                            .symbolEffect(.bounce, value: on)
                            .frame(width: 52, height: 52)
                            .background {
                                if on {
                                    Circle().fill(Theme.gradient).matchedGeometryEffect(id: "appearance", in: ns)
                                } else {
                                    Circle().fill(.quaternary)
                                }
                            }
                            .foregroundStyle(on ? .white : .primary)
                        Text(a.label).font(.caption.bold())
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var palettePicker: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 16) {
            ForEach(Palette.all) { p in
                let on = store.paletteID == p.id
                Button {
                    withAnimation(.spring(duration: 0.5, bounce: 0.35)) { store.paletteID = p.id }
                } label: {
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(colors: [p.accent, p.accent2], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 44, height: 44)
                                .scaleEffect(on ? 1.1 : 1)
                            if on {
                                Circle().strokeBorder(.primary, lineWidth: 2.5)
                                    .frame(width: 54, height: 54)
                                    .matchedGeometryEffect(id: "palette", in: ns)
                                Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.white)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .frame(width: 56, height: 56)
                        Text(p.name).font(.caption2).lineLimit(1).minimumScaleFactor(0.7)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var backgroundPicker: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
            ForEach(BackgroundStyle.allCases) { b in
                let on = store.background == b
                Button {
                    withAnimation(.easeInOut(duration: 0.5)) { store.background = b }
                } label: {
                    VStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(LinearGradient(colors: b == .solid ? [Color(.systemGray5), Color(.systemGray5)]
                                                 : [Theme.accent.opacity(0.6), Theme.accent2.opacity(0.4)],
                                                 startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(height: 64)
                            .overlay(Image(systemName: b.icon).font(.title2).foregroundStyle(.white)
                                .symbolEffect(.pulse, isActive: on))
                            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(on ? Color.primary : .clear, lineWidth: 2.5))
                        Text(b.label).font(.caption.bold())
                    }
                }
                .buttonStyle(PressableStyle())
            }
        }
    }
}

// MARK: - Lembretes

@Observable
final class ReminderStore {
    static let shared = ReminderStore()
    private let d = UserDefaults.standard

    var enabled: Bool { didSet { d.set(enabled, forKey: "reminderOn"); apply() } }
    var time: Date { didSet { d.set(time.timeIntervalSince1970, forKey: "reminderTime"); apply() } }
    var denied = false

    private init() {
        enabled = d.bool(forKey: "reminderOn")
        let t = d.double(forKey: "reminderTime")
        time = t > 0 ? Date(timeIntervalSince1970: t)
                     : Calendar.current.date(bySettingHour: 7, minute: 30, second: 0, of: .now)!
    }

    private func apply() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["weigh"])
        guard enabled else { return }
        center.requestAuthorization(options: [.alert, .sound, .badge]) { ok, _ in
            DispatchQueue.main.async { self.denied = !ok }
            guard ok else { return }
            let content = UNMutableNotificationContent()
            content.title = "Hora de se pesar ⚖️"
            content.body = "Pese-se no mesmo horário todo dia para uma tendência confiável."
            content.sound = .default
            let comps = Calendar.current.dateComponents([.hour, .minute], from: self.time)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            center.add(UNNotificationRequest(identifier: "weigh", content: content, trigger: trigger))
        }
    }
}
