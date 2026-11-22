import SwiftUI
import Observation

struct Palette: Identifiable, Equatable {
    let id: String
    let name: String
    let accent: Color
    let accent2: Color

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
    ]
}

enum Appearance: String, CaseIterable, Identifiable {
    case system, light, dark, amoled
    var id: String { rawValue }
    var label: String {
        switch self {
        case .system: "Sistema"
        case .light: "Claro"
        case .dark: "Escuro"
        case .amoled: "AMOLED"
        }
    }
    var icon: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max.fill"
        case .dark: "moon.stars.fill"
        case .amoled: "moon.fill"
        }
    }
    var scheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark, .amoled: .dark
        }
    }
}

enum BackgroundStyle: String, CaseIterable, Identifiable {
    case blobs, aurora, particles, gradient, solid
    var id: String { rawValue }
    var label: String {
        switch self {
        case .blobs: "Bolhas"
        case .aurora: "Aurora"
        case .particles: "Partículas"
        case .gradient: "Degradê"
        case .solid: "Liso"
        }
    }
    var icon: String {
        switch self {
        case .blobs: "circle.hexagongrid.fill"
        case .aurora: "sparkles"
        case .particles: "aqi.medium"
        case .gradient: "square.fill.on.square.fill"
        case .solid: "square.fill"
        }
    }
}

enum CardStyle: String, CaseIterable, Identifiable {
    case glass, solid, outline
    var id: String { rawValue }
    var label: String {
        switch self {
        case .glass: "Vidro"
        case .solid: "Sólido"
        case .outline: "Contorno"
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

    private init() {
        paletteID = d.string(forKey: "paletteID") ?? "mint"
        appearanceRaw = d.string(forKey: "appearance") ?? Appearance.system.rawValue
        backgroundRaw = d.string(forKey: "background") ?? BackgroundStyle.blobs.rawValue
        cardRaw = d.string(forKey: "card") ?? CardStyle.glass.rawValue
        animations = d.object(forKey: "animations") as? Bool ?? true
        haptics = d.object(forKey: "haptics") as? Bool ?? true
        autoOpenReport = d.object(forKey: "autoOpenReport") as? Bool ?? true
        showMovingAverage = d.object(forKey: "movingAvg") as? Bool ?? true
    }

    var palette: Palette { Palette.all.first { $0.id == paletteID } ?? Palette.all[0] }
    var appearance: Appearance {
        get { Appearance(rawValue: appearanceRaw) ?? .system }
        set { appearanceRaw = newValue.rawValue }
    }
    var background: BackgroundStyle {
        get { BackgroundStyle(rawValue: backgroundRaw) ?? .blobs }
        set { backgroundRaw = newValue.rawValue }
    }
    var card: CardStyle {
        get { CardStyle(rawValue: cardRaw) ?? .glass }
        set { cardRaw = newValue.rawValue }
    }
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
}
