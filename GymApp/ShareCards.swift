import SwiftUI

// MARK: - Folha de compartilhamento com imagem

enum ShareStyle: String, CaseIterable, Identifiable {
    case gradient, dark, light
    var id: String { rawValue }
    var label: String {
        switch self {
        case .gradient: "Colorido"
        case .dark: "Escuro"
        case .light: "Claro"
        }
    }
}

enum ShareFormat: String, CaseIterable, Identifiable {
    case post, story, square
    var id: String { rawValue }
    var label: String {
        switch self {
        case .post: "Post 4:5"
        case .story: "Story 9:16"
        case .square: "Quadrado"
        }
    }
    var size: CGSize {
        switch self {
        case .post: CGSize(width: 360, height: 450)
        case .story: CGSize(width: 360, height: 640)
        case .square: CGSize(width: 360, height: 360)
        }
    }
}

/// Mostra a prévia da imagem, opções de estilo e o botão de compartilhar.
struct ShareImageSheet<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content
    @Environment(\.dismiss) private var dismiss
    @State private var style: ShareStyle = .gradient
    @State private var format: ShareFormat = .post
    @State private var image: Image?

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                ZStack {
                    if let image {
                        image.resizable().scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            .shadow(color: .black.opacity(0.25), radius: 16, y: 6)
                            .transition(.scale(scale: 0.95).combined(with: .opacity))
                            .id(style.rawValue + format.rawValue)
                    } else {
                        ProgressView()
                    }
                }
                .frame(maxHeight: .infinity)
                .animation(.spring(duration: 0.4), value: style)
                .animation(.spring(duration: 0.4), value: format)
                Picker("Formato", selection: $format) {
                    ForEach(ShareFormat.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                Picker("Estilo", selection: $style) {
                    ForEach(ShareStyle.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                if let image {
                    ShareLink(item: image, preview: SharePreview(title, image: image)) {
                        Label("Compartilhar imagem", systemImage: "square.and.arrow.up")
                            .font(.headline).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding()
                            .background(Theme.gradient, in: RoundedRectangle(cornerRadius: 16))
                    }
                }
                Text("Salve nas Fotos ou envie para Instagram, WhatsApp e outros pelo menu de compartilhar.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            .padding()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Fechar") { dismiss() } }
            .task(id: style.rawValue + format.rawValue) { render() }
        }
    }

    @MainActor private func render() {
        let size = format.size
        let view = ShareFrame(style: style, format: format) { content() }
            .frame(width: size.width, height: size.height)
            .environment(\.colorScheme, style == .light ? .light : .dark)
        let r = ImageRenderer(content: view)
        r.scale = 3
        if let ui = r.uiImage { image = Image(uiImage: ui) }
    }
}

/// Moldura comum: fundo, conteúdo e rodapé com a marca do app.
struct ShareFrame<Content: View>: View {
    let style: ShareStyle
    let format: ShareFormat
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            background
            VStack(spacing: 0) {
                Spacer(minLength: format == .story ? 40 : 18)
                content()
                Spacer(minLength: 12)
                HStack(spacing: 6) {
                    Image(systemName: "scalemass.fill")
                    Text("Gym").bold()
                    Text("·")
                    Text(Date.now, format: .dateTime.day().month(.abbreviated).year())
                }
                .font(.caption2)
                .opacity(0.8)
                .padding(.bottom, format == .story ? 30 : 14)
            }
            .padding(.horizontal, 20)
            .foregroundStyle(style == .light ? Color.black : Color.white)
        }
    }

    @ViewBuilder private var background: some View {
        switch style {
        case .gradient:
            ZStack {
                LinearGradient(colors: [Theme.accent, Theme.accent2], startPoint: .topLeading, endPoint: .bottomTrailing)
                Circle().fill(.white.opacity(0.12)).frame(width: 300).offset(x: 140, y: -200)
                Circle().fill(.black.opacity(0.10)).frame(width: 260).offset(x: -150, y: 240)
            }
        case .dark:
            ZStack {
                Color(red: 0.07, green: 0.07, blue: 0.09)
                Circle().fill(Theme.accent.opacity(0.35)).frame(width: 280).blur(radius: 60).offset(x: 120, y: -180)
                Circle().fill(Theme.accent2.opacity(0.30)).frame(width: 240).blur(radius: 60).offset(x: -120, y: 220)
            }
        case .light:
            ZStack {
                Color(red: 0.97, green: 0.97, blue: 0.98)
                Circle().fill(Theme.accent.opacity(0.25)).frame(width: 280).blur(radius: 60).offset(x: 120, y: -180)
                Circle().fill(Theme.accent2.opacity(0.20)).frame(width: 240).blur(radius: 60).offset(x: -120, y: 220)
            }
        }
    }
}

// MARK: - Peças reutilizáveis (sem animação, para renderizar estático)

struct ShareTile: View {
    let title: String
    let value: String
    var unit: String = ""
    var icon: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                if let icon { Image(systemName: icon).font(.caption2) }
                Text(title).font(.caption2).opacity(0.8).lineLimit(1)
            }
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value).font(.system(.title3, design: .rounded).bold()).lineLimit(1).minimumScaleFactor(0.6)
                Text(unit).font(.caption2).opacity(0.8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.primary.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
    }
}

struct StaticRing: View {
    let progress: Double
    var lineWidth: CGFloat = 10

    var body: some View {
        ZStack {
            Circle().stroke(Color.primary.opacity(0.15), lineWidth: lineWidth)
            Circle().trim(from: 0, to: ProgressBar.clamp(progress))
                .stroke(Color.primary, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

struct ShareHeader: View {
    let icon: String
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.title2)
            Text(title).font(.title2.bold()).multilineTextAlignment(.center)
            if let subtitle { Text(subtitle).font(.caption).opacity(0.8) }
        }
    }
}

private let twoCols = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]

// MARK: - Cartões

struct MetricsShareCard: View {
    let analysis: BodyAnalysis
    let date: Date
    var delta: Double? = nil
    var name: String = ""

    var body: some View {
        let a = analysis
        VStack(spacing: 14) {
            ShareHeader(icon: "figure.stand", title: name.isEmpty ? "Minhas métricas" : "Métricas de \(name)",
                        subtitle: date.formatted(date: .long, time: .omitted))
            HStack(spacing: 18) {
                ZStack {
                    StaticRing(progress: a.bodyScore / 100)
                    VStack(spacing: 0) {
                        Text(a.bodyScore.fmt(0)).font(.title.bold())
                        Text("pontos").font(.caption2).opacity(0.8)
                    }
                }
                .frame(width: 92, height: 92)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(a.input.kg.fmt(2)).font(.system(size: 40, weight: .bold, design: .rounded))
                        Text("kg").font(.headline).opacity(0.8)
                    }
                    if let delta { Text("\(delta.signed(2)) kg desde a anterior").font(.caption.bold()) }
                    Text(a.bodyType.name).font(.subheadline.bold()).opacity(0.9)
                }
            }
            LazyVGrid(columns: twoCols, spacing: 8) {
                ShareTile(title: "IMC", value: a.bmi.fmt(1), icon: "figure.stand")
                ShareTile(title: "Gordura", value: a.bodyFat.fmt(1), unit: "%", icon: "drop.halffull")
                ShareTile(title: "Massa magra", value: a.lbm.fmt(1), unit: "kg", icon: "bolt.heart.fill")
                ShareTile(title: "Músculo esquelético", value: a.smm.fmt(1), unit: "kg", icon: "figure.strengthtraining.traditional")
                ShareTile(title: "Água", value: (a.water / a.input.kg * 100).fmt(1), unit: "%", icon: "drop.fill")
                ShareTile(title: "Metabolismo", value: a.mifflin.fmt(0), unit: "kcal", icon: "flame.fill")
                ShareTile(title: "Gordura visceral", value: a.visceral.fmt(0), icon: "heart.text.square.fill")
                ShareTile(title: "Idade metabólica", value: a.metabolicAge.fmt(0), unit: "anos", icon: "hourglass")
            }
        }
    }
}

struct MeasurementsShareCard: View {
    let latest: MeasurementEntry
    let first: MeasurementEntry?
    let heightCm: Double

    var body: some View {
        let parts = BodyPart.allCases.filter { latest[$0] != nil }.prefix(10)
        VStack(spacing: 14) {
            ShareHeader(icon: "ruler.fill", title: "Minhas medidas", subtitle: latest.date.formatted(date: .long, time: .omitted))
            LazyVGrid(columns: twoCols, spacing: 8) {
                ForEach(Array(parts)) { p in
                    ShareTile(title: p.label, value: valueText(p), unit: "cm")
                }
            }
            if let w = latest.waist {
                HStack(spacing: 8) {
                    ShareTile(title: "Cintura / altura", value: (w / heightCm).fmt(2))
                    if let h = latest.hip { ShareTile(title: "Cintura / quadril", value: (w / h).fmt(2)) }
                    if let s = latest.shoulders { ShareTile(title: "Ombro / cintura", value: (s / w).fmt(2)) }
                }
            }
        }
    }
}

extension MeasurementsShareCard {
    func valueText(_ p: BodyPart) -> String {
        let v = latest[p] ?? 0
        guard let f = first?[p], abs(v - f) >= 0.1 else { return v.fmt(1) }
        return "\(v.fmt(1)) (\((v - f).signed(1)))"
    }
}

struct WorkoutShareCard: View {
    let session: WorkoutSession
    var prs: Int = 0

    var body: some View {
        let ex = session.exercises
        VStack(spacing: 14) {
            ShareHeader(icon: "dumbbell.fill", title: session.name,
                        subtitle: session.start.formatted(date: .long, time: .shortened))
            LazyVGrid(columns: twoCols, spacing: 8) {
                ShareTile(title: "Duração", value: WorkoutMath.durationText(session.duration), icon: "timer")
                ShareTile(title: "Volume", value: WorkoutMath.volume(session).fmt(0), unit: "kg", icon: "scalemass.fill")
                ShareTile(title: "Séries", value: "\(WorkoutMath.setsCount(session))", icon: "checkmark.circle.fill")
                ShareTile(title: "Calorias", value: WorkoutMath.kcal(session).fmt(0), unit: "kcal", icon: "flame.fill")
            }
            VStack(alignment: .leading, spacing: 6) {
                ForEach(ex.prefix(6)) { e in
                    HStack {
                        Text(e.exercise?.name ?? e.exerciseID).font(.caption.bold()).lineLimit(1)
                        Spacer()
                        if let top = e.workSets.max(by: { $0.e1RM < $1.e1RM }), top.kg > 0 {
                            Text("\(e.workSets.count)× · melhor \(top.kg.fmt(1))×\(top.reps)").font(.caption2)
                        } else {
                            Text("\(e.doneSets.count) séries").font(.caption2)
                        }
                    }
                }
                if ex.count > 6 { Text("+ \(ex.count - 6) exercícios").font(.caption2).opacity(0.8) }
            }
            .padding(12)
            .background(Color.primary.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
            if prs > 0 {
                Label("\(prs) novo(s) recorde(s)! 🏆", systemImage: "trophy.fill").font(.subheadline.bold())
            }
        }
    }
}

struct NutritionShareCard: View {
    let day: Date
    let totals: Nutrients
    let target: Double
    let protein: Double, carbs: Double, fat: Double
    let waterL: Double
    let meals: Int

    var body: some View {
        VStack(spacing: 14) {
            ShareHeader(icon: "fork.knife", title: "Meu dia de alimentação", subtitle: day.formatted(date: .long, time: .omitted))
            HStack(spacing: 18) {
                ZStack {
                    StaticRing(progress: totals.kcal / max(target, 1), lineWidth: 12)
                    VStack(spacing: 0) {
                        Text(totals.kcal.fmt(0)).font(.title2.bold())
                        Text("de \(target.fmt(0)) kcal").font(.caption2).opacity(0.8)
                    }
                }
                .frame(width: 110, height: 110)
                VStack(alignment: .leading, spacing: 8) {
                    macro("Proteína", totals.protein, protein)
                    macro("Carboidrato", totals.carbs, carbs)
                    macro("Gordura", totals.fat, fat)
                }
            }
            LazyVGrid(columns: twoCols, spacing: 8) {
                ShareTile(title: "Fibras", value: totals.fiber.fmt(0), unit: "g", icon: "leaf.fill")
                ShareTile(title: "Água", value: waterL.fmt(2), unit: "L", icon: "drop.fill")
                ShareTile(title: "Refeições", value: "\(meals)", icon: "list.bullet")
                ShareTile(title: "Sódio", value: totals.sodium.fmt(0), unit: "mg", icon: "aqi.low")
            }
        }
    }

    private func macro(_ t: String, _ v: Double, _ goal: Double) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(t).font(.caption2)
                Spacer()
                Text("\(v.fmt(0))/\(goal.fmt(0)) g").font(.caption2.bold())
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.15))
                    Capsule().fill(Color.primary).frame(width: g.size.width * min(v / max(goal, 1), 1))
                }
            }
            .frame(height: 6)
        }
    }
}
