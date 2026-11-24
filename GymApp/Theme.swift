import SwiftUI
import UIKit
import Observation

struct Palette: Identifiable, Equatable {
    let id: String
    let name: String
    let accent: Color
    let accent2: Color

    /// A ordem importa: hábitos usam o índice para a cor (novas paletas só no fim).
    static let all: [Palette] = [
        Palette(id: "mint", name: "Menta",
                accent: Color(red: 0.32, green: 0.84, blue: 0.62), accent2: Color(red: 0.30, green: 0.62, blue: 1.00)),
        Palette(id: "ocean", name: "Oceano",
                accent: Color(red: 0.20, green: 0.70, blue: 1.00), accent2: Color(red: 0.36, green: 0.36, blue: 0.95)),
        Palette(id: "sunset", name: "Pôr do sol",
                accent: Color(red: 1.00, green: 0.55, blue: 0.30), accent2: Color(red: 0.95, green: 0.30, blue: 0.55)),
        Palette(id: "lavender", name: "Lavanda",
                accent: Color(red: 0.66, green: 0.52, blue: 1.00), accent2: Color(red: 0.95, green: 0.50, blue: 0.85)),
        Palette(id: "ruby", name: "Rubi",
                accent: Color(red: 0.95, green: 0.25, blue: 0.40), accent2: Color(red: 1.00, green: 0.55, blue: 0.35)),
        Palette(id: "forest", name: "Floresta",
                accent: Color(red: 0.30, green: 0.72, blue: 0.38), accent2: Color(red: 0.70, green: 0.82, blue: 0.25)),
        Palette(id: "aurora", name: "Aurora",
                accent: Color(red: 0.25, green: 0.90, blue: 0.80), accent2: Color(red: 0.72, green: 0.40, blue: 1.00)),
        Palette(id: "neon", name: "Neon",
                accent: Color(red: 0.75, green: 1.00, blue: 0.20), accent2: Color(red: 0.10, green: 0.90, blue: 1.00)),
        Palette(id: "gold", name: "Ouro",
                accent: Color(red: 0.95, green: 0.75, blue: 0.25), accent2: Color(red: 0.90, green: 0.45, blue: 0.20)),
        Palette(id: "graphite", name: "Grafite",
                accent: Color(red: 0.55, green: 0.60, blue: 0.68), accent2: Color(red: 0.35, green: 0.40, blue: 0.48)),
        Palette(id: "cherry", name: "Cereja",
                accent: Color(red: 0.86, green: 0.16, blue: 0.32), accent2: Color(red: 0.55, green: 0.10, blue: 0.40)),
        Palette(id: "coffee", name: "Café",
                accent: Color(red: 0.70, green: 0.50, blue: 0.34), accent2: Color(red: 0.45, green: 0.32, blue: 0.24)),
        Palette(id: "sakura", name: "Sakura",
                accent: Color(red: 1.00, green: 0.56, blue: 0.70), accent2: Color(red: 0.98, green: 0.76, blue: 0.62)),
        Palette(id: "arctic", name: "Ártico",
                accent: Color(red: 0.45, green: 0.80, blue: 0.95), accent2: Color(red: 0.70, green: 0.85, blue: 1.00)),
        Palette(id: "terra", name: "Terracota",
                accent: Color(red: 0.84, green: 0.43, blue: 0.29), accent2: Color(red: 0.62, green: 0.55, blue: 0.35)),
        Palette(id: "wine", name: "Vinho",
                accent: Color(red: 0.60, green: 0.18, blue: 0.35), accent2: Color(red: 0.85, green: 0.45, blue: 0.45)),
        Palette(id: "pastel", name: "Pastel",
                accent: Color(red: 0.55, green: 0.75, blue: 0.95), accent2: Color(red: 0.85, green: 0.70, blue: 0.95)),
        Palette(id: "citrus", name: "Cítrico",
                accent: Color(red: 1.00, green: 0.80, blue: 0.10), accent2: Color(red: 0.40, green: 0.85, blue: 0.30)),
        Palette(id: "indigo", name: "Índigo",
                accent: Color(red: 0.35, green: 0.40, blue: 0.95), accent2: Color(red: 0.20, green: 0.75, blue: 0.85)),
        Palette(id: "sport", name: "Esportivo",
                accent: Color(red: 1.00, green: 0.30, blue: 0.10), accent2: Color(red: 1.00, green: 0.70, blue: 0.00)),
    ]
}

enum Appearance: String, CaseIterable, Identifiable {
    case system, light, dark, amoled, sepia, midnight
    var id: String { rawValue }
    var label: String {
        switch self {
        case .system: "Sistema"
        case .light: "Claro"
        case .dark: "Escuro"
        case .amoled: "AMOLED"
        case .sepia: "Papel"
        case .midnight: "Meia-noite"
        }
    }
    var icon: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max.fill"
        case .dark: "moon.stars.fill"
        case .amoled: "moon.fill"
        case .sepia: "book.closed.fill"
        case .midnight: "sparkles"
        }
    }
    var scheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light, .sepia: .light
        case .dark, .amoled, .midnight: .dark
        }
    }
}

enum BackgroundStyle: String, CaseIterable, Identifiable {
    case blobs, aurora, particles, gradient, solid, spotlight, dots, waves
    var id: String { rawValue }
    var label: String {
        switch self {
        case .blobs: "Bolhas"
        case .aurora: "Aurora"
        case .particles: "Partículas"
        case .gradient: "Degradê"
        case .solid: "Liso"
        case .spotlight: "Holofote"
        case .dots: "Pontilhado"
        case .waves: "Ondas"
        }
    }
    var icon: String {
        switch self {
        case .blobs: "circle.hexagongrid.fill"
        case .aurora: "sparkles"
        case .particles: "aqi.medium"
        case .gradient: "square.fill.on.square.fill"
        case .solid: "square.fill"
        case .spotlight: "light.max"
        case .dots: "circle.grid.3x3.fill"
        case .waves: "water.waves"
        }
    }
}

enum CardStyle: String, CaseIterable, Identifiable {
    case glass, solid, outline, elevated, tinted, minimal
    var id: String { rawValue }
    var label: String {
        switch self {
        case .glass: "Vidro"
        case .solid: "Sólido"
        case .outline: "Contorno"
        case .elevated: "Elevado"
        case .tinted: "Colorido"
        case .minimal: "Mínimo"
        }
    }
}

enum FontStyle: String, CaseIterable, Identifiable {
    case system, rounded, serif, mono
    var id: String { rawValue }
    var label: String {
        switch self {
        case .system: "Padrão"
        case .rounded: "Arredondada"
        case .serif: "Serifada"
        case .mono: "Mono"
        }
    }
    var design: Font.Design {
        switch self {
        case .system: .default
        case .rounded: .rounded
        case .serif: .serif
        case .mono: .monospaced
        }
    }
}

enum TextSize: String, CaseIterable, Identifiable {
    case system, small, medium, large, xlarge
    var id: String { rawValue }
    var label: String {
        switch self {
        case .system: "Sistema"
        case .small: "P"
        case .medium: "M"
        case .large: "G"
        case .xlarge: "GG"
        }
    }
    var size: DynamicTypeSize? {
        switch self {
        case .system: nil
        case .small: .small
        case .medium: .large
        case .large: .xLarge
        case .xlarge: .xxLarge
        }
    }
}

enum Density: String, CaseIterable, Identifiable {
    case compact, normal, airy
    var id: String { rawValue }
    var label: String {
        switch self {
        case .compact: "Compacto"
        case .normal: "Normal"
        case .airy: "Espaçoso"
        }
    }
    var padding: CGFloat { switch self { case .compact: 12; case .normal: 16; case .airy: 20 } }
}

enum HeaderStyle: String, CaseIterable, Identifiable {
    case bold, caps, bar
    var id: String { rawValue }
    var label: String {
        switch self {
        case .bold: "Negrito"
        case .caps: "Discreto"
        case .bar: "Com barra"
        }
    }
}

/// Preferências visuais e de comportamento, salvas no aparelho.
@Observable
final class ThemeStore {
    static let shared = ThemeStore()
    private let d = UserDefaults.standard

    var paletteID: String { didSet { d.set(paletteID, forKey: "paletteID") } }
    var appearanceRaw: String { didSet { d.set(appearanceRaw, forKey: "appearance") } }
    var backgroundRaw: String { didSet { d.set(backgroundRaw, forKey: "background") } }
    var cardRaw: String { didSet { d.set(cardRaw, forKey: "card") } }
    var animations: Bool { didSet { d.set(animations, forKey: "animations") } }
    var haptics: Bool { didSet { d.set(haptics, forKey: "haptics") } }
    var autoOpenReport: Bool { didSet { d.set(autoOpenReport, forKey: "autoOpenReport") } }
    var showMovingAverage: Bool { didSet { d.set(showMovingAverage, forKey: "movingAvg") } }
    // Personalização avançada
    var fontRaw: String { didSet { d.set(fontRaw, forKey: "font") } }
    var textSizeRaw: String { didSet { d.set(textSizeRaw, forKey: "textSize") } }
    var densityRaw: String { didSet { d.set(densityRaw, forKey: "density") } }
    var headerRaw: String { didSet { d.set(headerRaw, forKey: "header") } }
    var cornerRadius: Double { didSet { d.set(cornerRadius, forKey: "corner") } }
    var borders: Bool { didSet { d.set(borders, forKey: "borders") } }
    var shadows: Bool { didSet { d.set(shadows, forKey: "shadows") } }
    var backgroundIntensity: Double { didSet { d.set(backgroundIntensity, forKey: "bgIntensity") } }
    var customA: String { didSet { d.set(customA, forKey: "customA") } }
    var customB: String { didSet { d.set(customB, forKey: "customB") } }

    private init() {
        paletteID = d.string(forKey: "paletteID") ?? "mint"
        appearanceRaw = d.string(forKey: "appearance") ?? Appearance.system.rawValue
        backgroundRaw = d.string(forKey: "background") ?? BackgroundStyle.spotlight.rawValue
        cardRaw = d.string(forKey: "card") ?? CardStyle.elevated.rawValue
        animations = d.object(forKey: "animations") as? Bool ?? true
        haptics = d.object(forKey: "haptics") as? Bool ?? true
        autoOpenReport = d.object(forKey: "autoOpenReport") as? Bool ?? true
        showMovingAverage = d.object(forKey: "movingAvg") as? Bool ?? true
        fontRaw = d.string(forKey: "font") ?? FontStyle.rounded.rawValue
        textSizeRaw = d.string(forKey: "textSize") ?? TextSize.system.rawValue
        densityRaw = d.string(forKey: "density") ?? Density.normal.rawValue
        headerRaw = d.string(forKey: "header") ?? HeaderStyle.caps.rawValue
        cornerRadius = d.object(forKey: "corner") as? Double ?? 20
        borders = d.object(forKey: "borders") as? Bool ?? true
        shadows = d.object(forKey: "shadows") as? Bool ?? true
        backgroundIntensity = d.object(forKey: "bgIntensity") as? Double ?? 1
        customA = d.string(forKey: "customA") ?? "#4FD69C"
        customB = d.string(forKey: "customB") ?? "#4D9EFF"
    }

    var palette: Palette {
        if paletteID == "custom" {
            return Palette(id: "custom", name: "Minha cor", accent: Color(hex: customA) ?? .green, accent2: Color(hex: customB) ?? .blue)
        }
        return Palette.all.first { $0.id == paletteID } ?? Palette.all[0]
    }
    var appearance: Appearance {
        get { Appearance(rawValue: appearanceRaw) ?? .system }
        set { appearanceRaw = newValue.rawValue }
    }
    var background: BackgroundStyle {
        get { BackgroundStyle(rawValue: backgroundRaw) ?? .spotlight }
        set { backgroundRaw = newValue.rawValue }
    }
    var card: CardStyle {
        get { CardStyle(rawValue: cardRaw) ?? .elevated }
        set { cardRaw = newValue.rawValue }
    }
    var font: FontStyle {
        get { FontStyle(rawValue: fontRaw) ?? .rounded }
        set { fontRaw = newValue.rawValue }
    }
    var textSize: TextSize {
        get { TextSize(rawValue: textSizeRaw) ?? .system }
        set { textSizeRaw = newValue.rawValue }
    }
    var density: Density {
        get { Density(rawValue: densityRaw) ?? .normal }
        set { densityRaw = newValue.rawValue }
    }
    var header: HeaderStyle {
        get { HeaderStyle(rawValue: headerRaw) ?? .caps }
        set { headerRaw = newValue.rawValue }
    }

    func apply(_ p: ThemePreset) {
        paletteID = p.palette
        appearance = p.appearance
        background = p.background
        card = p.card
        font = p.font
        header = p.header
        cornerRadius = p.corner
        borders = p.borders
        shadows = p.shadows
        density = p.density
    }

    func matches(_ p: ThemePreset) -> Bool {
        paletteID == p.palette && appearance == p.appearance && background == p.background && card == p.card && font == p.font
    }

    func reset() { apply(ThemePreset.all[0]); textSize = .system; backgroundIntensity = 1; animations = true }
}

/// Combinações prontas, aplicadas com um toque.
struct ThemePreset: Identifiable {
    let id: String
    let name: String
    let palette: String
    let appearance: Appearance
    let background: BackgroundStyle
    let card: CardStyle
    let font: FontStyle
    let header: HeaderStyle
    var corner: Double = 20
    var borders = true
    var shadows = true
    var density: Density = .normal

    static let all: [ThemePreset] = [
        ThemePreset(id: "clean", name: "Clean", palette: "mint", appearance: .system, background: .spotlight, card: .elevated, font: .rounded, header: .caps),
        ThemePreset(id: "minimal", name: "Minimalista", palette: "graphite", appearance: .light, background: .solid, card: .minimal, font: .system, header: .caps, corner: 14, shadows: false),
        ThemePreset(id: "night", name: "Noturno", palette: "indigo", appearance: .midnight, background: .dots, card: .solid, font: .rounded, header: .bar),
        ThemePreset(id: "amoled", name: "AMOLED Neon", palette: "neon", appearance: .amoled, background: .solid, card: .outline, font: .rounded, header: .bar, corner: 18, shadows: false),
        ThemePreset(id: "paper", name: "Papel", palette: "coffee", appearance: .sepia, background: .solid, card: .solid, font: .serif, header: .bold, corner: 16, borders: true, shadows: false),
        ThemePreset(id: "glass", name: "Vidro", palette: "aurora", appearance: .dark, background: .aurora, card: .glass, font: .rounded, header: .bold, corner: 24),
        ThemePreset(id: "sport", name: "Esportivo", palette: "sport", appearance: .dark, background: .waves, card: .tinted, font: .system, header: .bar, corner: 14, density: .compact),
        ThemePreset(id: "pastel", name: "Pastel", palette: "pastel", appearance: .light, background: .blobs, card: .glass, font: .rounded, header: .caps, corner: 26, density: .airy),
        ThemePreset(id: "sakura", name: "Sakura", palette: "sakura", appearance: .light, background: .gradient, card: .elevated, font: .serif, header: .caps, corner: 22),
        ThemePreset(id: "terminal", name: "Terminal", palette: "forest", appearance: .amoled, background: .dots, card: .outline, font: .mono, header: .caps, corner: 8, shadows: false, density: .compact),
    ]
}

/// Cores do app. Lê o tema atual, então as telas se atualizam sozinhas quando ele muda.
enum Theme {
    static var accent: Color { ThemeStore.shared.palette.accent }
    static var accent2: Color { ThemeStore.shared.palette.accent2 }
    static let warm = Color(red: 1.00, green: 0.62, blue: 0.30)
    static let danger = Color(red: 1.00, green: 0.38, blue: 0.42)
    static let good = Color(red: 0.30, green: 0.80, blue: 0.50)
    static let info = Color(red: 0.35, green: 0.65, blue: 1.00)
    static let excellent = Color(red: 0.62, green: 0.45, blue: 1.00)
    static var gradient: LinearGradient {
        LinearGradient(colors: [accent, accent2], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// Fundo da tela conforme a aparência.
    static func base(_ scheme: ColorScheme) -> Color {
        switch ThemeStore.shared.appearance {
        case .amoled where scheme == .dark: .black
        case .sepia: Color(red: 0.96, green: 0.93, blue: 0.87)
        case .midnight: Color(red: 0.04, green: 0.06, blue: 0.13)
        default: Color(.systemGroupedBackground)
        }
    }

    /// Superfície dos cartões sólidos.
    static func surface(_ scheme: ColorScheme) -> Color {
        switch ThemeStore.shared.appearance {
        case .amoled where scheme == .dark: Color(white: 0.08)
        case .sepia: Color(red: 1.00, green: 0.98, blue: 0.94)
        case .midnight: Color(red: 0.09, green: 0.12, blue: 0.22)
        default: Color(.secondarySystemGroupedBackground)
        }
    }
}

extension Color {
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces).uppercased()
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt64(s, radix: 16) else { return nil }
        self.init(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
    }

    var hex: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(max(0, min(1, r)) * 255), Int(max(0, min(1, g)) * 255), Int(max(0, min(1, b)) * 255))
    }
}
