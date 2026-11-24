import SwiftUI
import UserNotifications

// MARK: - Tema

struct ThemeSettingsView: View {
    @Bindable private var store = ThemeStore.shared
    @Namespace private var ns
    @State private var tab = 0
    @State private var confirmReset = false

    var body: some View {
        ZStack {
            AnimatedBackground()
            ScrollView {
                VStack(spacing: 18) {
                    preview
                    presets
                    Picker("Seção", selection: $tab.animation(.snappy)) {
                        Text("Cores").tag(0)
                        Text("Visual").tag(1)
                        Text("Texto").tag(2)
                        Text("Outros").tag(3)
                    }
                    .pickerStyle(.segmented)
                    switch tab {
                    case 0: colorsTab
                    case 1: visualTab
                    case 2: textTab
                    default: otherTab
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Tema e aparência")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Voltar ao tema padrão?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Restaurar padrão", role: .destructive) { withAnimation(.spring) { store.reset() } }
        }
    }

    // MARK: Prévia ao vivo

    private var preview: some View {
        VStack(spacing: 10) {
            SectionHeader(title: "Prévia", icon: "eye.fill")
            Card {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 14) {
                        ZStack {
                            ProgressRing(progress: 0.68, lineWidth: 9)
                            Text("68%").font(.subheadline.bold())
                        }
                        .frame(width: 66, height: 66)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Último peso").font(.caption).foregroundStyle(.secondary)
                            HStack(alignment: .firstTextBaseline, spacing: 3) {
                                Text("72,4").font(.system(size: 34, weight: .bold)).foregroundStyle(Theme.gradient)
                                Text("kg").foregroundStyle(.secondary)
                            }
                            HStack(spacing: 6) {
                                StatusChip(text: "Saudável", color: Theme.good)
                                StatusChip(text: "−0,6 kg", color: Theme.accent)
                            }
                        }
                    }
                    HStack(spacing: 10) {
                        miniTile("Proteína", "128 g", 0.8, "fish.fill")
                        miniTile("Água", "1,9 L", 0.6, "drop.fill")
                    }
                    HStack {
                        Text("Botão principal").font(.subheadline.bold()).foregroundStyle(.white)
                            .padding(.horizontal, 14).padding(.vertical, 9).background(Theme.gradient, in: Capsule())
                        Text("Secundário").font(.subheadline.bold()).foregroundStyle(Theme.accent)
                            .padding(.horizontal, 14).padding(.vertical, 9).background(Theme.accent.opacity(0.14), in: Capsule())
                    }
                }
            }
        }
        .animation(.spring(duration: 0.5), value: store.paletteID)
    }

    private func miniTile(_ t: String, _ v: String, _ p: Double, _ icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(t, systemImage: icon).font(.caption).foregroundStyle(.secondary)
            Text(v).font(.headline.monospacedDigit())
            ProgressBar(progress: p, height: 4)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: max(6, store.cornerRadius - 8), style: .continuous))
    }

    // MARK: Temas prontos

    private var presets: some View {
        VStack(spacing: 10) {
            SectionHeader(title: "Temas prontos", icon: "swatchpalette.fill")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(ThemePreset.all) { p in presetTile(p) }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func presetTile(_ p: ThemePreset) -> some View {
        let pal = Palette.all.first { $0.id == p.palette } ?? Palette.all[0]
        let on = store.matches(p)
        let dark = p.appearance.scheme == .dark
        let bg: Color = switch p.appearance {
        case .amoled: .black
        case .sepia: Color(red: 0.96, green: 0.93, blue: 0.87)
        case .midnight: Color(red: 0.04, green: 0.06, blue: 0.13)
        case .dark: Color(white: 0.11)
        default: Color(white: 0.95)
        }
        return Button { withAnimation(.spring(duration: 0.5)) { store.apply(p) } } label: {
            VStack(alignment: .leading, spacing: 6) {
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 14, style: .continuous).fill(bg)
                    RadialGradient(colors: [pal.accent.opacity(0.35), .clear], center: .topLeading, startRadius: 0, endRadius: 90)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    VStack(alignment: .leading, spacing: 5) {
                        RoundedRectangle(cornerRadius: 4).fill(LinearGradient(colors: [pal.accent, pal.accent2], startPoint: .leading, endPoint: .trailing))
                            .frame(width: 44, height: 8)
                        RoundedRectangle(cornerRadius: 4).fill((dark ? Color.white : .black).opacity(0.15)).frame(width: 64, height: 6)
                        RoundedRectangle(cornerRadius: 4).fill((dark ? Color.white : .black).opacity(0.10)).frame(width: 52, height: 6)
                        Text("Aa").font(.system(size: 15, weight: .bold, design: p.font.design)).foregroundStyle(dark ? .white : .black)
                    }
                    .padding(10)
                }
                .frame(width: 104, height: 84)
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(on ? Theme.accent : .primary.opacity(0.1), lineWidth: on ? 2.5 : 1))
                Text(p.name).font(.caption.bold()).foregroundStyle(on ? Theme.accent : .primary)
            }
        }
        .buttonStyle(PressableStyle())
    }

    // MARK: Cores

    private var colorsTab: some View {
        VStack(spacing: 14) {
            group("Aparência", "circle.lefthalf.filled") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 10) {
                    ForEach(Appearance.allCases) { a in
                        let on = store.appearance == a
                        Button { withAnimation(.spring(duration: 0.45)) { store.appearance = a } } label: {
                            VStack(spacing: 6) {
                                Image(systemName: a.icon).font(.title3).symbolEffect(.bounce, value: on)
                                Text(a.label).font(.caption.bold())
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .foregroundStyle(on ? .white : .primary)
                            .background {
                                if on { RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.gradient).matchedGeometryEffect(id: "ap", in: ns) }
                                else { RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.quaternary) }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            group("Cor de destaque", "paintpalette.fill") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 14) {
                    ForEach(Palette.all) { p in swatch(p.id, p.name, p.accent, p.accent2) }
                    let c = store.palette
                    swatch("custom", "Minha cor", Color(hex: store.customA) ?? c.accent, Color(hex: store.customB) ?? c.accent2)
                }
                if store.paletteID == "custom" {
                    Divider()
                    ColorPicker("Cor principal", selection: Binding(get: { Color(hex: store.customA) ?? .green },
                                                                    set: { store.customA = $0.hex }), supportsOpacity: false)
                    ColorPicker("Cor secundária", selection: Binding(get: { Color(hex: store.customB) ?? .blue },
                                                                     set: { store.customB = $0.hex }), supportsOpacity: false)
                }
            }
        }
    }

    private func swatch(_ id: String, _ name: String, _ a: Color, _ b: Color) -> some View {
        let on = store.paletteID == id
        return Button { withAnimation(.spring(duration: 0.5, bounce: 0.35)) { store.paletteID = id } } label: {
            VStack(spacing: 5) {
                ZStack {
                    Circle().fill(LinearGradient(colors: [a, b], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 40, height: 40)
                    if id == "custom" && !on { Image(systemName: "eyedropper").font(.caption.bold()).foregroundStyle(.white) }
                    if on {
                        Circle().strokeBorder(.primary, lineWidth: 2.5).frame(width: 50, height: 50)
                            .matchedGeometryEffect(id: "palette", in: ns)
                        Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.white)
                    }
                }
                .frame(width: 52, height: 52)
                Text(name).font(.caption2).lineLimit(1).minimumScaleFactor(0.7)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Visual

    private var visualTab: some View {
        VStack(spacing: 14) {
            group("Fundo", "sparkles") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                    ForEach(BackgroundStyle.allCases) { b in
                        let on = store.background == b
                        Button { withAnimation(.easeInOut(duration: 0.5)) { store.background = b } } label: {
                            VStack(spacing: 5) {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(b == .solid ? AnyShapeStyle(Color(.systemGray5))
                                          : AnyShapeStyle(LinearGradient(colors: [Theme.accent.opacity(0.6), Theme.accent2.opacity(0.35)],
                                                                         startPoint: .topLeading, endPoint: .bottomTrailing)))
                                    .frame(height: 52)
                                    .overlay(Image(systemName: b.icon).font(.title3).foregroundStyle(.white).symbolEffect(.pulse, isActive: on))
                                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(on ? Color.primary : .clear, lineWidth: 2.5))
                                Text(b.label).font(.caption2.bold()).lineLimit(1).minimumScaleFactor(0.8)
                            }
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
                if store.background != .solid {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Intensidade do fundo: \(Int(store.backgroundIntensity * 100))%").font(.caption).foregroundStyle(.secondary)
                        Slider(value: $store.backgroundIntensity, in: 0.2...1.5)
                    }
                }
            }
            group("Cartões", "rectangle.on.rectangle") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                    ForEach(CardStyle.allCases) { c in
                        choice(c.label, store.card == c) { store.card = c }
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Cantos: \(Int(store.cornerRadius)) pt").font(.caption).foregroundStyle(.secondary)
                    Slider(value: $store.cornerRadius, in: 4...32, step: 2)
                }
                Picker("Espaçamento", selection: $store.densityRaw) {
                    ForEach(Density.allCases) { Text($0.label).tag($0.rawValue) }
                }
                .pickerStyle(.segmented)
                Toggle("Bordas finas", isOn: $store.borders)
                Toggle("Sombra (no estilo Elevado)", isOn: $store.shadows)
            }
            .tint(Theme.accent)
        }
    }

    // MARK: Texto

    private var textTab: some View {
        VStack(spacing: 14) {
            group("Fonte", "textformat") {
                HStack(spacing: 8) {
                    ForEach(FontStyle.allCases) { f in
                        let on = store.font == f
                        Button { withAnimation { store.font = f } } label: {
                            VStack(spacing: 4) {
                                Text("Aa").font(.system(size: 22, weight: .semibold, design: f.design))
                                Text(f.label).font(.caption2)
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                            .foregroundStyle(on ? .white : .primary)
                            .background(on ? AnyShapeStyle(Theme.gradient) : AnyShapeStyle(.quaternary), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            group("Tamanho do texto", "textformat.size") {
                Picker("Tamanho", selection: $store.textSizeRaw) {
                    ForEach(TextSize.allCases) { Text($0.label).tag($0.rawValue) }
                }
                .pickerStyle(.segmented)
                Text("\"Sistema\" segue o tamanho escolhido nos Ajustes do iPhone.").font(.caption).foregroundStyle(.secondary)
            }
            group("Títulos de seção", "textformat.alt") {
                Picker("Títulos", selection: $store.headerRaw) {
                    ForEach(HeaderStyle.allCases) { Text($0.label).tag($0.rawValue) }
                }
                .pickerStyle(.segmented)
                SectionHeader(title: "Exemplo de seção", icon: "sparkles")
            }
        }
    }

    // MARK: Outros

    private var otherTab: some View {
        VStack(spacing: 14) {
            group("Movimento", "wand.and.stars") {
                Toggle("Animações", isOn: $store.animations)
                Toggle("Vibração (haptics)", isOn: $store.haptics)
            }
            .tint(Theme.accent)
            Button { confirmReset = true } label: {
                Label("Restaurar tema padrão", systemImage: "arrow.counterclockwise").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: Peças

    private func group<C: View>(_ title: String, _ icon: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: title, icon: icon)
            Card { VStack(alignment: .leading, spacing: 12) { content() } }
        }
    }

    private func choice(_ t: String, _ on: Bool, _ a: @escaping () -> Void) -> some View {
        Button { withAnimation(.spring) { a() } } label: {
            Text(t).font(.caption.bold()).frame(maxWidth: .infinity).padding(.vertical, 10)
                .foregroundStyle(on ? .white : .primary)
                .background(on ? AnyShapeStyle(Theme.gradient) : AnyShapeStyle(.quaternary), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
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
