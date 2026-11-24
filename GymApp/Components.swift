import SwiftUI

// MARK: - Fundos

/// Fundo do app conforme o tema escolhido.
struct AnimatedBackground: View {
    @Environment(\.colorScheme) private var scheme
    private var store: ThemeStore { ThemeStore.shared }

    var body: some View {
        ZStack {
            Theme.base(scheme)
            Group {
                switch store.background {
                case .blobs: BlobsBackground(animated: store.animations)
                case .aurora: AuroraBackground(animated: store.animations)
                case .particles: ParticlesBackground(animated: store.animations)
                case .gradient:
                    LinearGradient(colors: [Theme.accent.opacity(0.24), Theme.accent2.opacity(0.14), .clear],
                                   startPoint: .top, endPoint: .center)
                case .spotlight: SpotlightBackground()
                case .dots: DotsBackground()
                case .waves: WavesBackground(animated: store.animations)
                case .solid: EmptyView()
                }
            }
            .opacity(store.backgroundIntensity)
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.6), value: store.paletteID)
    }
}

/// Brilho suave no topo: limpo e sem distrair.
private struct SpotlightBackground: View {
    var body: some View {
        GeometryReader { g in
            ZStack {
                RadialGradient(colors: [Theme.accent.opacity(0.22), .clear], center: .init(x: 0.15, y: 0),
                               startRadius: 0, endRadius: g.size.width * 0.9)
                RadialGradient(colors: [Theme.accent2.opacity(0.14), .clear], center: .init(x: 0.95, y: 0.05),
                               startRadius: 0, endRadius: g.size.width * 0.7)
            }
        }
    }
}

private struct DotsBackground: View {
    var body: some View {
        Canvas { ctx, size in
            let step: CGFloat = 22
            var y: CGFloat = 0
            while y < size.height {
                var x: CGFloat = (Int(y / step) % 2 == 0) ? 0 : step / 2
                let fade = max(0.0, 1 - Double(y / size.height) * 1.3)
                while x < size.width {
                    ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 2.2, height: 2.2)),
                             with: .color(Theme.accent.opacity(0.35 * fade)))
                    x += step
                }
                y += step
            }
        }
        .overlay(LinearGradient(colors: [Theme.accent.opacity(0.10), .clear], startPoint: .top, endPoint: .center))
    }
}

private struct WavesBackground: View {
    let animated: Bool
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !animated)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                for i in 0..<3 {
                    var p = Path()
                    let base = size.height * (0.12 + Double(i) * 0.07)
                    let amp = 18.0 + Double(i) * 8
                    p.move(to: CGPoint(x: 0, y: 0))
                    p.addLine(to: CGPoint(x: 0, y: base))
                    for x in stride(from: 0.0, through: size.width, by: 6) {
                        let y = base + sin(x / size.width * .pi * 2 + t * (0.4 + Double(i) * 0.15) + Double(i)) * amp
                        p.addLine(to: CGPoint(x: x, y: y))
                    }
                    p.addLine(to: CGPoint(x: size.width, y: 0))
                    p.closeSubpath()
                    ctx.fill(p, with: .color((i == 1 ? Theme.accent2 : Theme.accent).opacity(0.10)))
                }
            }
        }
    }
}

private struct BlobsBackground: View {
    let animated: Bool
    @State private var move = false

    var body: some View {
        ZStack {
            Circle().fill(Theme.accent.opacity(0.22)).frame(width: 340).blur(radius: 90)
                .offset(x: move ? -120 : 80, y: move ? -260 : -170)
            Circle().fill(Theme.accent2.opacity(0.18)).frame(width: 300).blur(radius: 90)
                .offset(x: move ? 140 : -60, y: move ? 120 : 280)
            Circle().fill(Theme.accent.opacity(0.10)).frame(width: 220).blur(radius: 70)
                .offset(x: move ? 60 : -140, y: move ? 420 : 40)
        }
        .onAppear {
            guard animated else { return }
            withAnimation(.easeInOut(duration: 9).repeatForever(autoreverses: true)) { move = true }
        }
    }
}

private struct AuroraBackground: View {
    let animated: Bool
    @State private var spin = false

    var body: some View {
        AngularGradient(colors: [Theme.accent, Theme.accent2, Theme.accent.opacity(0.4), Theme.accent2, Theme.accent],
                        center: .center)
            .opacity(0.30)
            .frame(width: 900, height: 900)
            .blur(radius: 120)
            .rotationEffect(.degrees(spin ? 360 : 0))
            .offset(y: -250)
            .onAppear {
                guard animated else { return }
                withAnimation(.linear(duration: 40).repeatForever(autoreverses: false)) { spin = true }
            }
    }
}

private struct ParticlesBackground: View {
    let animated: Bool
    private let seeds: [(x: Double, speed: Double, size: Double, phase: Double)] = (0..<28).map { i in
        let r = Double((i * 7919) % 1000) / 1000
        let r2 = Double((i * 104729) % 1000) / 1000
        return (x: r, speed: 0.02 + r2 * 0.05, size: 4 + r * 14, phase: r2)
    }

    var body: some View {
        TimelineView(.animation(paused: !animated)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                for (i, s) in seeds.enumerated() {
                    let y = (1 - (s.phase + t * s.speed).truncatingRemainder(dividingBy: 1)) * (size.height + 40) - 20
                    let x = s.x * size.width + sin(t * 0.6 + Double(i)) * 18
                    let rect = CGRect(x: x, y: y, width: s.size, height: s.size)
                    ctx.fill(Path(ellipseIn: rect),
                             with: .color((i.isMultiple(of: 2) ? Theme.accent : Theme.accent2).opacity(0.30)))
                }
            }
            .blur(radius: 1.5)
        }
        .background(LinearGradient(colors: [Theme.accent.opacity(0.10), .clear], startPoint: .top, endPoint: .bottom))
    }
}

// MARK: - Cartões

/// Cartão base de todo o app. Estilo, cantos, espaçamento, borda e sombra vêm do tema.
struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    @Environment(\.colorScheme) private var scheme
    private var store: ThemeStore { ThemeStore.shared }

    var body: some View {
        let style = store.card
        let shape = RoundedRectangle(cornerRadius: store.cornerRadius, style: .continuous)
        let dark = scheme == .dark
        content
            .padding(style == .minimal ? store.density.padding * 0.75 : store.density.padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                switch style {
                case .glass: shape.fill(.ultraThinMaterial)
                case .solid, .elevated: shape.fill(Theme.surface(scheme))
                case .tinted: shape.fill(Theme.surface(scheme)).overlay(shape.fill(Theme.accent.opacity(dark ? 0.10 : 0.07)))
                case .outline: shape.fill(Theme.surface(scheme).opacity(0.35))
                case .minimal: shape.fill(Color.primary.opacity(dark ? 0.04 : 0.025))
                }
            }
            .overlay {
                if style == .outline {
                    shape.strokeBorder(Theme.accent.opacity(0.55), lineWidth: 1.2)
                } else if store.borders && style != .minimal {
                    shape.strokeBorder(Color.primary.opacity(dark ? 0.08 : 0.06), lineWidth: 0.8)
                }
            }
            .shadow(color: .black.opacity(store.shadows && style == .elevated ? (dark ? 0.35 : 0.07) : 0),
                    radius: style == .elevated ? 14 : 0, y: style == .elevated ? 6 : 0)
    }
}

/// Anel de progresso animado.
struct ProgressRing: View {
    var progress: Double
    var lineWidth: CGFloat = 14
    var colors: [Color]? = nil
    @State private var shown: Double = 0

    var body: some View {
        let c = colors ?? [Theme.accent, Theme.accent2, Theme.accent]
        ZStack {
            Circle().stroke(.quaternary, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: shown)
                .stroke(AngularGradient(colors: c, center: .center),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .onAppear { withAnimation(.spring(duration: 1.2, bounce: 0.25)) { shown = clamp(progress) } }
        .onChange(of: progress) { _, v in withAnimation(.spring(duration: 0.8)) { shown = clamp(v) } }
    }

    private func clamp(_ v: Double) -> Double { v.isFinite ? min(max(v, 0), 1) : 0 }
}

/// Barra fina de progresso animada.
struct ProgressBar: View {
    var progress: Double
    var tint: Color = Theme.accent
    var height: CGFloat = 6
    @State private var shown: Double = 0

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                Capsule().fill(LinearGradient(colors: [tint.opacity(0.7), tint], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(height, g.size.width * shown))
            }
        }
        .frame(height: height)
        .onAppear { withAnimation(.spring(duration: 1, bounce: 0.2).delay(0.1)) { shown = Self.clamp(progress) } }
        .onChange(of: progress) { _, v in withAnimation(.spring) { shown = Self.clamp(v) } }
    }

    /// Protege contra NaN/infinito (ex.: divisão por meta zero), que quebrariam o desenho.
    static func clamp(_ v: Double) -> Double { v.isFinite ? min(max(v, 0), 1) : 0
    }
}

/// Cartão pequeno com uma métrica.
struct MetricTile: View {
    let title: String
    let value: String
    var unit: String = ""
    let icon: String
    var tint: Color = Theme.accent
    var caption: String? = nil
    var progress: Double? = nil

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.caption.bold())
                        .foregroundStyle(tint)
                        .frame(width: 24, height: 24)
                        .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    Text(title).font(.caption.weight(.medium)).foregroundStyle(.secondary).lineLimit(1)
                    Spacer(minLength: 0)
                }
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(value).font(.title2.weight(.bold)).monospacedDigit().contentTransition(.numericText())
                        .minimumScaleFactor(0.6).lineLimit(1)
                    Text(unit).font(.caption).foregroundStyle(.secondary)
                }
                if let caption {
                    Text(caption).font(.caption2.weight(.semibold)).foregroundStyle(tint).lineLimit(1)
                }
                if let progress { ProgressBar(progress: progress, tint: tint, height: 4) }
            }
        }
    }
}

/// Selo colorido de status ("Saudável", "Alto"...).
struct StatusChip: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption.bold())
            .padding(.horizontal, 10).padding(.vertical, 4)
            .foregroundStyle(color)
            .background(color.opacity(0.15), in: Capsule())
    }
}

/// Barra horizontal com faixas coloridas e um marcador.
struct RangeBar: View {
    let value: Double
    let range: ClosedRange<Double>
    let stops: [(Double, Color)]   // limite superior de cada faixa
    var target: Double? = nil
    @State private var shownValue: Double?

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let span = range.upperBound - range.lowerBound
            let x: (Double) -> Double = { v in
                guard v.isFinite, span > 0 else { return 0 }
                return (min(max(v, range.lowerBound), range.upperBound) - range.lowerBound) / span * w
            }
            ZStack(alignment: .leading) {
                HStack(spacing: 3) {
                    ForEach(Array(stops.enumerated()), id: \.offset) { i, s in
                        let lower = i == 0 ? range.lowerBound : max(range.lowerBound, stops[i - 1].0)
                        let upper = min(s.0, range.upperBound)
                        if upper > lower {
                            Capsule().fill(s.1.opacity(0.85))
                                .frame(width: max(0, (upper - lower) / span * w - 3))
                        }
                    }
                }
                if let target {
                    Image(systemName: "flag.fill").font(.system(size: 10)).foregroundStyle(.primary)
                        .offset(x: x(target) - 4, y: -14)
                }
                Circle().fill(.white)
                    .frame(width: 16, height: 16)
                    .overlay(Circle().strokeBorder(.black.opacity(0.15)))
                    .shadow(radius: 3)
                    .offset(x: x(shownValue ?? range.lowerBound) - 8)
            }
        }
        .frame(height: 16)
        .onAppear { withAnimation(.spring(duration: 1, bounce: 0.3).delay(0.15)) { shownValue = value } }
        .onChange(of: value) { _, v in withAnimation(.spring) { shownValue = v } }
    }
}

/// Título de seção (o estilo vem do tema: negrito, discreto ou com barra).
struct SectionHeader: View {
    let title: String
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 8) {
            switch ThemeStore.shared.header {
            case .bold:
                if let icon { Image(systemName: icon).foregroundStyle(Theme.accent) }
                Text(title).font(.title3.bold())
            case .caps:
                if let icon { Image(systemName: icon).font(.caption.bold()).foregroundStyle(Theme.accent) }
                Text(title.uppercased()).font(.footnote.weight(.semibold)).tracking(0.8).foregroundStyle(.secondary)
            case .bar:
                Capsule().fill(Theme.gradient).frame(width: 4, height: 18)
                Text(title).font(.headline)
                if let icon { Image(systemName: icon).font(.subheadline).foregroundStyle(.secondary) }
            }
            Spacer()
        }
        .padding(.top, 8)
        .padding(.horizontal, 2)
        .accessibilityAddTraits(.isHeader)
    }
}

/// Animação de entrada (sobe + aparece) com atraso.
struct AppearEffect: ViewModifier {
    let delay: Double
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 18)
            .scaleEffect(shown ? 1 : 0.97)
            .onAppear {
                guard ThemeStore.shared.animations else { shown = true; return }
                withAnimation(.spring(duration: 0.6, bounce: 0.25).delay(delay)) { shown = true }
            }
    }
}

extension View {
    func appear(_ delay: Double = 0) -> some View { modifier(AppearEffect(delay: delay)) }
}

extension Double {
    func fmt(_ digits: Int = 1) -> String {
        formatted(.number.precision(.fractionLength(digits)))
    }
    func signed(_ digits: Int = 1) -> String {
        (self > 0 ? "+" : "") + fmt(digits)
    }
}
