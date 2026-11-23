import SwiftUI
import SwiftData
import PhotosUI
import Charts

// MARK: - Fotos de progresso

enum PhotoPose: String, CaseIterable, Identifiable, Codable {
    case front, side, back
    var id: String { rawValue }
    var title: String { switch self { case .front: "Frente"; case .side: "Lado"; case .back: "Costas" } }
}

@Model
final class ProgressPhoto {
    var date: Date = Date.now
    var poseRaw: String = PhotoPose.front.rawValue
    var kg: Double?
    var note: String = ""
    @Attribute(.externalStorage) var image: Data = Data()
    @Attribute(.externalStorage) var thumb: Data = Data()

    init(date: Date, pose: PhotoPose, kg: Double?, image: Data, thumb: Data) {
        self.date = date; poseRaw = pose.rawValue; self.kg = kg; self.image = image; self.thumb = thumb
    }
    var pose: PhotoPose { PhotoPose(rawValue: poseRaw) ?? .front }
}

enum PhotoCodec {
    /// Redimensiona e comprime (fotos de 12 MP viram ~300 KB; miniatura ~15 KB).
    static func encode(_ img: UIImage, maxSide: CGFloat, quality: CGFloat) -> Data {
        let s = img.size
        let scale = min(1, maxSide / max(s.width, s.height))
        let size = CGSize(width: (s.width * scale).rounded(), height: (s.height * scale).rounded())
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1
        let out = UIGraphicsImageRenderer(size: size, format: fmt).image { _ in img.draw(in: CGRect(origin: .zero, size: size)) }
        return out.jpegData(compressionQuality: quality) ?? Data()
    }
}

/// Cache de imagens decodificadas (evita decodificar JPEG a cada redesenho da grade).
final class PhotoImageCache {
    static let shared = PhotoImageCache()
    private let cache = NSCache<NSData, UIImage>()
    func image(_ data: Data) -> UIImage? {
        let key = data as NSData
        if let i = cache.object(forKey: key) { return i }
        guard let i = UIImage(data: data) else { return nil }
        cache.setObject(i, forKey: key)
        return i
    }
}

struct ProgressPhotosView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \ProgressPhoto.date, order: .reverse) private var photos: [ProgressPhoto]
    @Query(sort: \WeightEntry.date, order: .reverse) private var weights: [WeightEntry]
    @State private var pose: PhotoPose = .front
    @State private var picker: PhotosPickerItem?
    @State private var showCamera = false
    @State private var compare = false
    @State private var timelapse = false
    @State private var viewing: ProgressPhoto?

    var body: some View {
        let list = photos.filter { $0.pose == pose }
        ScrollView {
            VStack(spacing: 14) {
                Picker("", selection: $pose) { ForEach(PhotoPose.allCases) { Text($0.title).tag($0) } }.pickerStyle(.segmented)
                HStack {
                    Button { showCamera = true } label: { Label("Tirar foto", systemImage: "camera.fill").frame(maxWidth: .infinity) }
                        .buttonStyle(.borderedProminent).tint(Theme.accent)
                    PhotosPicker(selection: $picker, matching: .images) { Label("Galeria", systemImage: "photo").frame(maxWidth: .infinity) }
                        .buttonStyle(.bordered)
                }
                if list.count >= 2 {
                    HStack {
                        Button { compare = true } label: { Label("Comparar", systemImage: "rectangle.split.2x1").frame(maxWidth: .infinity) }
                        Button { timelapse = true } label: { Label("Linha do tempo", systemImage: "play.rectangle.fill").frame(maxWidth: .infinity) }
                    }
                    .buttonStyle(.bordered)
                }
                if list.isEmpty {
                    ContentUnavailableView("Sem fotos de \(pose.title.lowercased())", systemImage: "camera",
                                           description: Text("Tire fotos a cada 2–4 semanas, com a mesma luz, roupa e distância. As fotos ficam só no seu iPhone."))
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 6)], spacing: 6) {
                    ForEach(list) { p in
                        Button { viewing = p } label: {
                            ZStack(alignment: .bottomLeading) {
                                if let img = PhotoImageCache.shared.image(p.thumb) {
                                    Image(uiImage: img).resizable().scaledToFill()
                                } else { Color.secondary.opacity(0.2) }
                                Text(p.date, format: .dateTime.day().month(.abbreviated).year(.twoDigits))
                                    .font(.caption2.bold()).foregroundStyle(.white).padding(4)
                                    .background(.black.opacity(0.45), in: Capsule()).padding(4)
                            }
                            .frame(height: 150).clipped().clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
        }
        .background(AnimatedBackground())
        .onChange(of: picker) { _, it in
            Task {
                if let d = try? await it?.loadTransferable(type: Data.self), let img = UIImage(data: d) { add(img) }
                picker = nil
            }
        }
        .fullScreenCover(isPresented: $showCamera) { CameraPicker { add($0) }.ignoresSafeArea() }
        .sheet(isPresented: $compare) { PhotoCompareView(photos: list) }
        .fullScreenCover(isPresented: $timelapse) { PhotoTimelapseView(photos: list.reversed()) }
        .sheet(item: $viewing) { p in PhotoDetailView(photo: p) }
    }

    private func add(_ img: UIImage) {
        let full = PhotoCodec.encode(img, maxSide: 1600, quality: 0.75)
        let thumb = PhotoCodec.encode(img, maxSide: 360, quality: 0.6)
        context.insert(ProgressPhoto(date: .now, pose: pose, kg: weights.first?.kg, image: full, thumb: thumb))
    }
}

struct PhotoDetailView: View {
    @Bindable var photo: ProgressPhoto
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    var body: some View {
        NavigationStack {
            VStack {
                if let img = UIImage(data: photo.image) { Image(uiImage: img).resizable().scaledToFit() }
                HStack {
                    Text(photo.date, format: .dateTime.day().month(.wide).year())
                    if let kg = photo.kg { Text("· \(kg.fmt(1)) kg") }
                }
                .font(.subheadline.bold())
                TextField("Anotação", text: $photo.note).textFieldStyle(.roundedBorder).padding(.horizontal)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("OK") { dismiss() } }
                ToolbarItem(placement: .destructiveAction) {
                    Button(role: .destructive) { context.delete(photo); dismiss() } label: { Image(systemName: "trash") }
                }
            }
        }
    }
}

struct PhotoCompareView: View {
    let photos: [ProgressPhoto]     // mais recente primeiro
    @Environment(\.dismiss) private var dismiss
    @State private var a = 0
    @State private var b = 0
    @State private var split = 0.5

    var body: some View {
        let before = photos[min(b, photos.count - 1)], after = photos[min(a, photos.count - 1)]
        NavigationStack {
            VStack(spacing: 12) {
                GeometryReader { g in
                    ZStack {
                        image(after).frame(width: g.size.width, height: g.size.height)
                        image(before).frame(width: g.size.width, height: g.size.height)
                            .mask(alignment: .leading) { Rectangle().frame(width: g.size.width * split) }
                        Rectangle().fill(.white).frame(width: 3).position(x: g.size.width * split, y: g.size.height / 2)
                    }
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0).onChanged { split = min(max($0.location.x / g.size.width, 0), 1) })
                }
                .clipShape(RoundedRectangle(cornerRadius: 14))
                HStack {
                    label(before, "Antes"); Spacer(); label(after, "Depois")
                }
                if let k0 = before.kg, let k1 = after.kg {
                    let days = Calendar.current.dateComponents([.day], from: before.date, to: after.date).day ?? 0
                    Text("\((k1 - k0).signed(1)) kg em \(days) dias").font(.headline).foregroundStyle(k1 <= k0 ? Theme.good : Theme.warm)
                }
                HStack {
                    Picker("Antes", selection: $b) { ForEach(photos.indices, id: \.self) { Text(photos[$0].date, format: .dateTime.day().month().year(.twoDigits)).tag($0) } }
                    Picker("Depois", selection: $a) { ForEach(photos.indices, id: \.self) { Text(photos[$0].date, format: .dateTime.day().month().year(.twoDigits)).tag($0) } }
                }
            }
            .padding()
            .navigationTitle("Antes e depois")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { a = 0; b = photos.count - 1 }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("OK") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    if let img = sideBySide(before, after) {
                        ShareLink(item: Image(uiImage: img), preview: SharePreview("Antes e depois", image: Image(uiImage: img))) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            }
        }
    }

    private func image(_ p: ProgressPhoto) -> some View {
        Group {
            if let img = PhotoImageCache.shared.image(p.image) { Image(uiImage: img).resizable().scaledToFill() } else { Color.gray }
        }
        .clipped()
    }

    private func label(_ p: ProgressPhoto, _ t: String) -> some View {
        VStack(alignment: .leading) {
            Text(t).font(.caption.bold())
            Text(p.date, format: .dateTime.day().month().year()).font(.caption2).foregroundStyle(.secondary)
        }
    }

    /// Imagem lado a lado para compartilhar.
    private func sideBySide(_ x: ProgressPhoto, _ y: ProgressPhoto) -> UIImage? {
        guard let i1 = PhotoImageCache.shared.image(x.image), let i2 = PhotoImageCache.shared.image(y.image) else { return nil }
        let h: CGFloat = 1200
        let w1 = i1.size.width * h / i1.size.height, w2 = i2.size.width * h / i2.size.height
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: w1 + w2, height: h), format: fmt).image { _ in
            i1.draw(in: CGRect(x: 0, y: 0, width: w1, height: h))
            i2.draw(in: CGRect(x: w1, y: 0, width: w2, height: h))
        }
    }
}

struct PhotoTimelapseView: View {
    let photos: [ProgressPhoto]      // mais antiga primeiro
    @Environment(\.dismiss) private var dismiss
    @State private var index = 0
    @State private var playing = true
    @State private var speed = 0.6

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if photos.indices.contains(index), let img = PhotoImageCache.shared.image(photos[index].image) {
                Image(uiImage: img).resizable().scaledToFit().id(index).transition(.opacity)
            }
            VStack {
                HStack {
                    Button { dismiss() } label: { Image(systemName: "xmark.circle.fill").font(.title) }
                    Spacer()
                }
                Spacer()
                if photos.indices.contains(index) {
                    let p = photos[index]
                    VStack(spacing: 4) {
                        Text(p.date, format: .dateTime.day().month(.wide).year()).font(.headline)
                        if let kg = p.kg { Text("\(kg.fmt(1)) kg").font(.title2.bold()) }
                    }
                    .padding(10).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
                Slider(value: Binding(get: { Double(index) }, set: { index = Int($0.rounded()); playing = false }),
                       in: 0...Double(max(photos.count - 1, 1)))
                HStack {
                    Button { playing.toggle() } label: { Image(systemName: playing ? "pause.fill" : "play.fill").font(.title) }
                    Spacer()
                    Picker("", selection: $speed) { Text("Lento").tag(1.0); Text("Normal").tag(0.6); Text("Rápido").tag(0.3) }.pickerStyle(.segmented).frame(width: 220)
                }
            }
            .foregroundStyle(.white)
            .padding()
        }
        .task(id: "\(playing)\(speed)") {
            while playing && !Task.isCancelled {
                try? await Task.sleep(for: .seconds(speed))
                guard playing else { break }
                withAnimation(.easeInOut(duration: speed * 0.6)) { index = (index + 1) % max(photos.count, 1) }
            }
        }
    }
}

// MARK: - Previsão de meta

/// Regressão linear do peso nos últimos 45 dias, com intervalo de confiança de 95% na inclinação.
struct GoalForecast {
    let slopePerWeek: Double
    let eta: Date?
    let etaRange: (Date, Date)?
    let reachable: Bool
    let points: [(Date, Double)]
    let fitted: (a: Double, b: Double, t0: Date)

    init?(weights: [WeightEntry], goal: Double) {
        let cut = Date.now.addingTimeInterval(-45 * 86400)
        let pts = weights.filter { $0.date >= cut }.sorted { $0.date < $1.date }
        guard pts.count >= 5, let first = pts.first, let last = pts.last,
              last.date.timeIntervalSince(first.date) >= 7 * 86400 else { return nil }
        let t0 = first.date
        let x = pts.map { $0.date.timeIntervalSince(t0) / 86400 }, y = pts.map(\.kg)
        let n = Double(x.count)
        let mx = x.reduce(0, +) / n, my = y.reduce(0, +) / n
        var sxy = 0.0, sxx = 0.0
        for i in x.indices { sxy += (x[i] - mx) * (y[i] - my); sxx += (x[i] - mx) * (x[i] - mx) }
        guard sxx > 0 else { return nil }
        let b = sxy / sxx, a = my - b * mx
        var sse = 0.0
        for i in x.indices { let e = y[i] - (a + b * x[i]); sse += e * e }
        let se = sqrt(sse / max(n - 2, 1) / sxx)
        slopePerWeek = b * 7
        points = pts.map { ($0.date, $0.kg) }
        fitted = (a, b, t0)
        let nowX = Date.now.timeIntervalSince(t0) / 86400
        let current = a + b * nowX
        let diff = goal - current
        func eta(_ slope: Double) -> Date? {
            guard abs(slope) > 0.002, diff / slope > 0, diff / slope < 3 * 365 else { return nil }
            return Date.now.addingTimeInterval(diff / slope * 86400)
        }
        reachable = abs(diff) < 0.3 || eta(b) != nil
        self.eta = abs(diff) < 0.3 ? .now : eta(b)
        let fast = eta(b + (diff > 0 ? 1.96 : -1.96) * se), slow = eta(b - (diff > 0 ? 1.96 : -1.96) * se)
        etaRange = (fast != nil && slow != nil) ? (fast!, slow!) : nil
    }
}

struct ForecastCard: View {
    let weights: [WeightEntry]
    let goal: Double

    var body: some View {
        if let f = GoalForecast(weights: weights, goal: goal) {
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Previsão da meta", systemImage: "scope").font(.headline)
                    if let eta = f.eta {
                        Text(Calendar.current.isDateInToday(eta) ? "Você já está na meta! 🎯"
                             : "Nesse ritmo você chega a \(goal.fmt(1)) kg em \(eta.formatted(.dateTime.day().month(.wide).year())).")
                            .font(.callout.bold())
                        if let r = f.etaRange {
                            Text("Faixa provável: \(r.0.formatted(.dateTime.day().month(.abbreviated))) a \(r.1.formatted(.dateTime.day().month(.abbreviated).year())) (95% de confiança).")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    } else {
                        Text("No ritmo atual (\(f.slopePerWeek.signed(2)) kg/semana) você está se afastando ou parado em relação à meta de \(goal.fmt(1)) kg.")
                            .font(.callout)
                    }
                    Chart {
                        ForEach(Array(f.points.enumerated()), id: \.offset) { _, p in
                            PointMark(x: .value("Data", p.0), y: .value("kg", p.1)).foregroundStyle(Theme.accent.opacity(0.6)).symbolSize(20)
                        }
                        let end = f.eta.map { min($0, Date.now.addingTimeInterval(180 * 86400)) } ?? Date.now.addingTimeInterval(30 * 86400)
                        let y = { (d: Date) in f.fitted.a + f.fitted.b * d.timeIntervalSince(f.fitted.t0) / 86400 }
                        LineMark(x: .value("Data", f.fitted.t0), y: .value("kg", y(f.fitted.t0)), series: .value("s", "t"))
                            .foregroundStyle(Theme.accent2).lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 4]))
                        LineMark(x: .value("Data", end), y: .value("kg", y(end)), series: .value("s", "t"))
                            .foregroundStyle(Theme.accent2).lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 4]))
                        RuleMark(y: .value("Meta", goal)).foregroundStyle(Theme.good).lineStyle(StrokeStyle(dash: [2, 3]))
                            .annotation(position: .top, alignment: .leading) { Text("meta").font(.caption2).foregroundStyle(Theme.good) }
                    }
                    .chartYScale(domain: .automatic(includesZero: false))
                    .frame(height: 150)
                    Text("Tendência dos últimos 45 dias: \(f.slopePerWeek.signed(2)) kg/semana.").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Relatório mensal em PDF

@MainActor
enum MonthlyReport {
    struct ReportData {
        var name = "", month = Date.now
        var kgStart: Double?, kgEnd: Double?
        var metrics: [(String, String)] = []
        var avgKcal: Double?, avgProtein: Double?, loggedDays = 0, kcalTarget = 0.0, proteinTarget = 0.0
        var workouts = 0, workoutMin = 0.0, volume = 0.0, cardioKm = 0.0
        var avgSleep: Double?, avgMood: Double?, avgStress: Double?
        var measures: [(String, Double, Double)] = []
        var weights: [(Date, Double)] = []
    }

    static func build(_ ctx: ModelContext, month: Date) -> ReportData {
        let cal = Calendar.current
        let start = cal.dateInterval(of: .month, for: month)!.start
        let end = cal.date(byAdding: .month, value: 1, to: start)!
        var d = ReportData()
        d.month = start
        let profile = (try? ctx.fetch(FetchDescriptor<UserProfile>()))?.first
        d.name = profile?.name ?? ""
        let ws = (try? ctx.fetch(FetchDescriptor<WeightEntry>(predicate: #Predicate { $0.date >= start && $0.date < end }, sortBy: [SortDescriptor(\.date)]))) ?? []
        d.weights = ws.map { ($0.date, $0.kg) }
        d.kgStart = ws.first?.kg; d.kgEnd = ws.last?.kg
        if let p = profile, let kg = ws.last?.kg {
            let a = BodyAnalysis(BodyInputs(kg: kg, profile: p))
            for id in [MetricID.bmi, .bodyFat, .fatMass, .lbm, .ffmi, .visceralFat, .bmr, .metabolicAge, .bodyScore] {
                if let m = a[id] { d.metrics.append((id.title, "\(m.display) \(id.unit)" + (m.status.map { " · \($0.label)" } ?? ""))) }
            }
            let t = NutritionTargets(analysis: a)
            d.kcalTarget = t.kcal; d.proteinTarget = t.protein
        }
        let foods = (try? ctx.fetch(FetchDescriptor<FoodLog>(predicate: #Predicate { $0.date >= start && $0.date < end }))) ?? []
        let byDay = Dictionary(grouping: foods) { cal.startOfDay(for: $0.date) }
        d.loggedDays = byDay.count
        if !byDay.isEmpty {
            d.avgKcal = foods.map(\.nutrients.kcal).reduce(0, +) / Double(byDay.count)
            d.avgProtein = foods.map(\.nutrients.protein).reduce(0, +) / Double(byDay.count)
        }
        let sessions = ((try? ctx.fetch(FetchDescriptor<WorkoutSession>(predicate: #Predicate { $0.start >= start && $0.start < end }))) ?? []).filter { !$0.isActive }
        d.workouts = sessions.count
        d.workoutMin = sessions.map(\.duration).reduce(0, +) / 60
        d.volume = sessions.map(WorkoutMath.volume).reduce(0, +)
        d.cardioKm = ((try? ctx.fetch(FetchDescriptor<CardioSession>(predicate: #Predicate { $0.start >= start && $0.start < end }))) ?? []).map(\.km).reduce(0, +)
        let sleeps = (try? ctx.fetch(FetchDescriptor<SleepEntry>(predicate: #Predicate { $0.wake >= start && $0.wake < end }))) ?? []
        if !sleeps.isEmpty { d.avgSleep = sleeps.map(\.hours).reduce(0, +) / Double(sleeps.count) }
        let moods = (try? ctx.fetch(FetchDescriptor<MoodEntry>(predicate: #Predicate { $0.date >= start && $0.date < end }))) ?? []
        if !moods.isEmpty {
            d.avgMood = Double(moods.map(\.mood).reduce(0, +)) / Double(moods.count)
            d.avgStress = Double(moods.map(\.stress).reduce(0, +)) / Double(moods.count)
        }
        let ms = (try? ctx.fetch(FetchDescriptor<MeasurementEntry>(predicate: #Predicate { $0.date >= start && $0.date < end }, sortBy: [SortDescriptor(\.date)]))) ?? []
        if let f = ms.first, let l = ms.last, ms.count >= 2 {
            for p in BodyPart.allCases { if let a = f[p], let b = l[p] { d.measures.append((p.label, a, b)) } }
        }
        return d
    }

    /// Gera o PDF (A4, vetorial) renderizando uma página SwiftUI.
    static func pdf(_ ctx: ModelContext, month: Date) -> URL? {
        let data = build(ctx, month: month)
        let url = FileManager.default.temporaryDirectory
            .appending(path: "Gym-relatorio-\(data.month.formatted(.iso8601.year().month())).pdf")
        let renderer = ImageRenderer(content: MonthlyReportPage(d: data).frame(width: 595, height: 842))
        var box = CGRect(x: 0, y: 0, width: 595, height: 842)
        guard let consumer = CGDataConsumer(url: url as CFURL), let pdf = CGContext(consumer: consumer, mediaBox: &box, nil) else { return nil }
        renderer.render { _, draw in
            pdf.beginPDFPage(nil)
            draw(pdf)
            pdf.endPDFPage()
        }
        pdf.closePDF()
        return url
    }
}

struct MonthlyReportPage: View {
    let d: MonthlyReport.ReportData

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Relatório mensal").font(.system(size: 22, weight: .bold))
                    Text("\(d.name) · \(d.month.formatted(.dateTime.month(.wide).year()))").font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Spacer()
                Text("Gym").font(.system(size: 18, weight: .heavy)).foregroundStyle(Theme.accent)
            }
            Divider()
            section("Peso") {
                if let a = d.kgStart, let b = d.kgEnd {
                    row("Início → fim do mês", "\(a.fmt(1)) → \(b.fmt(1)) kg (\((b - a).signed(1)) kg)")
                } else { row("Pesagens", "nenhuma no mês") }
                if d.weights.count >= 2 {
                    Chart(Array(d.weights.enumerated()), id: \.offset) { _, p in
                        LineMark(x: .value("d", p.0), y: .value("kg", p.1)).foregroundStyle(Theme.accent)
                    }
                    .chartYScale(domain: .automatic(includesZero: false))
                    .frame(height: 90)
                }
            }
            if !d.metrics.isEmpty {
                section("Composição corporal (última pesagem, estimativas)") { ForEach(d.metrics, id: \.0) { row($0.0, $0.1) } }
            }
            HStack(alignment: .top, spacing: 16) {
                section("Alimentação") {
                    row("Dias registrados", "\(d.loggedDays)")
                    row("Média diária", d.avgKcal.map { "\(Int($0)) / \(Int(d.kcalTarget)) kcal" } ?? "—")
                    row("Proteína média", d.avgProtein.map { "\(Int($0)) / \(Int(d.proteinTarget)) g" } ?? "—")
                }
                section("Treino") {
                    row("Treinos", "\(d.workouts)")
                    row("Tempo total", "\(Int(d.workoutMin)) min")
                    row("Volume", "\(Int(d.volume).formatted()) kg")
                    row("Cardio GPS", "\(d.cardioKm.fmt(1)) km")
                }
            }
            HStack(alignment: .top, spacing: 16) {
                section("Sono e mente") {
                    row("Sono médio", d.avgSleep.map { "\($0.fmt(1)) h" } ?? "—")
                    row("Humor médio", d.avgMood.map { "\($0.fmt(1)) / 5" } ?? "—")
                    row("Estresse médio", d.avgStress.map { "\($0.fmt(1)) / 5" } ?? "—")
                }
                if !d.measures.isEmpty {
                    section("Medidas (cm)") {
                        ForEach(d.measures.prefix(6), id: \.0) { m in row(m.0, "\(m.1.fmt(1)) → \(m.2.fmt(1)) (\((m.2 - m.1).signed(1)))") }
                    }
                }
            }
            Spacer()
            Text("Gerado pelo app Gym em \(Date.now.formatted(date: .abbreviated, time: .omitted)). Composição corporal estimada por fórmulas (peso, altura, idade e medidas); não substitui avaliação profissional.")
                .font(.system(size: 8)).foregroundStyle(.secondary)
        }
        .padding(32)
        .background(Color.white)
        .environment(\.colorScheme, .light)
    }

    private func section<C: View>(_ t: String, @ViewBuilder _ c: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(t).font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.accent)
            c()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func row(_ k: String, _ v: String) -> some View {
        HStack {
            Text(k).font(.system(size: 10)).foregroundStyle(.secondary)
            Spacer()
            Text(v).font(.system(size: 10, weight: .semibold))
        }
    }
}

struct MonthlyReportButton: View {
    @Environment(\.modelContext) private var context
    @State private var month = Date.now
    @State private var url: URL?

    var body: some View {
        let months = (0..<12).compactMap { Calendar.current.date(byAdding: .month, value: -$0, to: .now) }
        Picker("Mês", selection: $month) {
            ForEach(months, id: \.self) { Text($0.formatted(.dateTime.month(.wide).year())).tag($0) }
        }
        .onChange(of: month) { _, _ in url = nil }
        if let url {
            ShareLink(item: url) { Label("Enviar PDF", systemImage: "square.and.arrow.up.fill") }
        } else {
            Button { url = MonthlyReport.pdf(context, month: month) } label: { Label("Gerar relatório (PDF)", systemImage: "doc.richtext") }
        }
    }
}
