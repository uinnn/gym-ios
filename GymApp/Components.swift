import SwiftUI

enum Theme {
    static let accent = Color(red: 0.32, green: 0.84, blue: 0.62)      // verde menta
    static let accent2 = Color(red: 0.30, green: 0.62, blue: 1.00)     // azul
    static let warm = Color(red: 1.00, green: 0.62, blue: 0.30)        // laranja
    static let danger = Color(red: 1.00, green: 0.38, blue: 0.42)
    static let gradient = LinearGradient(colors: [accent, accent2],
                                         startPoint: .topLeading, endPoint: .bottomTrailing)

    static func bmiColor(_ level: Int) -> Color {
        [accent2, accent, warm, danger][min(max(level, 0), 3)]
    }
}

/// Fundo animado com manchas de cor suaves.
struct AnimatedBackground: View {
    @State private var move = false

    var body: some View {
        ZStack {
            Color(.systemBackground)
            Circle().fill(Theme.accent.opacity(0.25))
                .frame(width: 320).blur(radius: 90)
                .offset(x: move ? -120 : 80, y: move ? -260 : -180)
            Circle().fill(Theme.accent2.opacity(0.22))
                .frame(width: 280).blur(radius: 90)
                .offset(x: move ? 140 : -60, y: move ? 120 : 260)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 9).repeatForever(autoreverses: true)) { move = true }
        }
    }
}

/// Cartão com efeito de vidro.
struct Card<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(.white.opacity(0.12)))
    }
}

/// Anel de progresso animado.
struct ProgressRing: View {
    var progress: Double
    var lineWidth: CGFloat = 14
    var gradient: AngularGradient = AngularGradient(colors: [Theme.accent, Theme.accent2, Theme.accent],
                                                    center: .center)
    @State private var shown: Double = 0

    var body: some View {
        ZStack {
            Circle().stroke(.quaternary, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: shown)
                .stroke(gradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .onAppear { withAnimation(.spring(duration: 1.2, bounce: 0.25)) { shown = clamp(progress) } }
        .onChange(of: progress) { _, v in withAnimation(.spring(duration: 0.8)) { shown = clamp(v) } }
    }

    private func clamp(_ v: Double) -> Double { min(max(v, 0), 1) }
}

/// Cartão pequeno com uma métrica.
struct MetricTile: View {
    let title: String
    let value: String
    var unit: String = ""
    let icon: String
    var tint: Color = Theme.accent
    var caption: String? = nil

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
                Text(title).font(.caption).foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(value).font(.title2.bold()).contentTransition(.numericText())
                    Text(unit).font(.caption).foregroundStyle(.secondary)
                }
                if let caption {
                    Text(caption).font(.caption2).foregroundStyle(tint)
                }
            }
        }
    }
}

/// Barra horizontal com faixas coloridas e um marcador (ex.: IMC).
struct RangeBar: View {
    let value: Double
    let range: ClosedRange<Double>
    let stops: [(Double, Color)]   // limite superior de cada faixa

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let pos = (min(max(value, range.lowerBound), range.upperBound) - range.lowerBound)
                / (range.upperBound - range.lowerBound) * w
            ZStack(alignment: .leading) {
                HStack(spacing: 3) {
                    ForEach(Array(stops.enumerated()), id: \.offset) { i, s in
                        let lower = i == 0 ? range.lowerBound : stops[i - 1].0
                        Capsule().fill(s.1.opacity(0.85))
                            .frame(width: max(0, (min(s.0, range.upperBound) - lower)
                                              / (range.upperBound - range.lowerBound) * w - 3))
                    }
                }
                Circle().fill(.white)
                    .frame(width: 16, height: 16)
                    .shadow(radius: 3)
                    .offset(x: pos - 8)
            }
        }
        .frame(height: 16)
    }
}

extension Double {
    func fmt(_ digits: Int = 1) -> String {
        formatted(.number.precision(.fractionLength(digits)))
    }
}
