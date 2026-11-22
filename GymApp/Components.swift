import SwiftUI

// MARK: - Fundos

/// Fundo do app conforme o tema escolhido.
struct AnimatedBackground: View {
    @Environment(\.colorScheme) private var scheme
    private var store: ThemeStore { ThemeStore.shared }

    var body: some View {
        ZStack {
            base
            switch store.background {
            case .blobs: BlobsBackground(animated: store.animations)
            case .aurora: AuroraBackground(animated: store.animations)
            case .particles: ParticlesBackground(animated: store.animations)
            case .gradient:
                LinearGradient(colors: [Theme.accent.opacity(0.28), Theme.accent2.opacity(0.18), .clear],
                               startPoint: .top, endPoint: .bottom)
            case .solid: EmptyView()
            }
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.6), value: store.paletteID)
    }

    private var base: Color {
        store.appearance == .amoled && scheme == .dark ? .black : Color(.systemGroupedBackground)
    }
}

private struct BlobsBackground: View {
    let animated: Bool
    @State private var move = false

    var body: some View {
        ZStack {
            Circle().fill(Theme.accent.opacity(0.28)).frame(width: 340).blur(radius: 90)
                .offset(x: move ? -120 : 80, y: move ? -260 : -170)
            Circle().fill(Theme.accent2.opacity(0.24)).frame(width: 300).blur(radius: 90)
                .offset(x: move ? 140 : -60, y: move ? 120 : 280)
            Circle().fill(Theme.accent.opacity(0.14)).frame(width: 220).blur(radius: 70)
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
            .opacity(0.35)
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
                             with: .color((i.isMultiple(of: 2) ? Theme.accent : Theme.accent2).opacity(0.35)))
                }
            }
            .blur(radius: 1.5)
        }
        .background(LinearGradient(colors: [Theme.accent.opacity(0.12), .clear], startPoint: .top, endPoint: .bottom))
    }
}

// MARK: - Cartões

struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    private var style: CardStyle { ThemeStore.shared.card }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                switch style {
                case .glass: shape.fill(.ultraThinMaterial)
                case .solid: shape.fill(Color(.secondarySystemGroupedBackground))
                case .outline: shape.fill(.clear)
                }
            }
            .overlay(shape.strokeBorder(style == .outline ? Theme.accent.opacity(0.5) : .white.opacity(0.1),
                                        lineWidth: style == .outline ? 1.5 : 1))
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

    private func clamp(_ v: Double) -> Double { min(max(v, 0), 1) }
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
        .onAppear { withAnimation(.spring(duration: 1, bounce: 0.2).delay(0.1)) { shown = min(max(progress, 0), 1) } }
        .onChange(of: progress) { _, v in withAnimation(.spring) { shown = min(max(v, 0), 1) } }
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
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .font(.subheadline.bold())
                        .foregroundStyle(tint)
                        .frame(width: 30, height: 30)
                        .background(tint.opacity(0.15), in: Circle())
                    Spacer()
                }
                Text(title).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(value).font(.title2.bold()).contentTransition(.numericText())
                        .minimumScaleFactor(0.6).lineLimit(1)
                    Text(unit).font(.caption).foregroundStyle(.secondary)
                }
                if let caption {
                    Text(caption).font(.caption2.bold()).foregroundStyle(tint).lineLimit(1)
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
                (min(max(v, range.lowerBound), range.upperBound) - range.lowerBound) / span * w
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

/// Título de seção.
struct SectionHeader: View {
    let title: String
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 6) {
            if let icon { Image(systemName: icon).foregroundStyle(Theme.accent) }
            Text(title).font(.title3.bold())
            Spacer()
        }
        .padding(.top, 6)
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
