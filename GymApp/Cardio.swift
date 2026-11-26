import SwiftUI
import SwiftData
import CoreLocation
import MapKit
import Charts

// MARK: - Modelo

enum CardioKind: String, Codable, CaseIterable, Identifiable {
    case run, walk, bike
    var id: String { rawValue }
    var title: String { switch self { case .run: "Corrida"; case .walk: "Caminhada"; case .bike: "Pedalada" } }
    var icon: String { switch self { case .run: "figure.run"; case .walk: "figure.walk"; case .bike: "figure.outdoor.cycle" } }
    var verb: String { switch self { case .run: "correu"; case .walk: "caminhou"; case .bike: "pedalou" } }

    /// kcal pelas equações metabólicas do ACSM (corrida/caminhada) e MET por velocidade (bike).
    func kcal(kg: Double, km: Double, seconds: Double, climbM: Double) -> Double {
        guard seconds > 0 else { return 0 }
        let minutes = seconds / 60
        let mPerMin = km * 1000 / minutes
        let grade = km > 0 ? climbM / (km * 1000) : 0
        switch self {
        case .run:
            let vo2 = 0.2 * mPerMin + 0.9 * mPerMin * grade + 3.5        // ml/kg/min
            return vo2 * kg / 1000 * 5 * minutes
        case .walk:
            let vo2 = 0.1 * mPerMin + 1.8 * mPerMin * grade + 3.5
            return vo2 * kg / 1000 * 5 * minutes
        case .bike:
            let kmh = km / (seconds / 3600)
            let met: Double = kmh < 16 ? 4 : kmh < 19 ? 6.8 : kmh < 22 ? 8 : kmh < 25.5 ? 10 : 12
            return met * kg * seconds / 3600
        }
    }
}

@Model
final class CardioSession {
    // Sincronização com o site (vazio/0 = nunca enviado)
    var syncID: String = ""
    var syncUpdated: Double = 0
    var syncSent: Double = 0
    var start: Date = Date.now
    var seconds: Double = 0
    var km: Double = 0
    var kcal: Double = 0
    var climbM: Double = 0
    var kindRaw: String = CardioKind.run.rawValue
    var route: Data = Data()          // [lat, lon] intercalados em Float32 (compacto)
    var splits: [Double] = []         // segundos por km

    init(kind: CardioKind) { kindRaw = kind.rawValue }

    var kind: CardioKind { CardioKind(rawValue: kindRaw) ?? .run }
    /// Ritmo em segundos por km.
    var pace: Double { km > 0 ? seconds / km : 0 }

    var coordinates: [CLLocationCoordinate2D] {
        route.withUnsafeBytes { raw in
            let f = raw.bindMemory(to: Float32.self)
            return stride(from: 0, to: f.count - 1, by: 2).map {
                CLLocationCoordinate2D(latitude: CLLocationDegrees(f[$0]), longitude: CLLocationDegrees(f[$0 + 1]))
            }
        }
    }

    static func pack(_ c: [CLLocationCoordinate2D]) -> Data {
        var f = [Float32](); f.reserveCapacity(c.count * 2)
        for p in c { f.append(Float32(p.latitude)); f.append(Float32(p.longitude)) }
        return f.withUnsafeBufferPointer { Data(buffer: $0) }
    }
}

enum CardioFormat {
    static func pace(_ s: Double) -> String {
        guard s.isFinite, s > 0, s < 3600 else { return "--:--" }
        return String(format: "%d:%02d", Int(s) / 60, Int(s) % 60)
    }
    static func time(_ s: Double) -> String {
        let t = Int(s)
        return t >= 3600 ? String(format: "%d:%02d:%02d", t / 3600, t % 3600 / 60, t % 60) : String(format: "%d:%02d", t / 60, t % 60)
    }
}

// MARK: - Rastreador GPS

@Observable
final class CardioTracker: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private(set) var coords: [CLLocationCoordinate2D] = []
    private(set) var meters = 0.0
    private(set) var climb = 0.0
    private(set) var elapsed = 0.0
    private(set) var splits: [Double] = []
    private(set) var running = false
    private(set) var paused = false
    private(set) var accuracy: Double = -1
    private(set) var denied = false
    var currentPace = 0.0                     // s/km nos últimos ~200 m

    @ObservationIgnored private var last: CLLocation?
    @ObservationIgnored private var segmentStart = Date()
    @ObservationIgnored private var accumulated = 0.0
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var lastSplitAt = 0.0
    @ObservationIgnored private var recent: [(Date, Double)] = []

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.activityType = .fitness
        manager.distanceFilter = 5
    }

    func requestPermission() { manager.requestWhenInUseAuthorization() }

    func start() {
        coords = []; meters = 0; climb = 0; elapsed = 0; splits = []; accumulated = 0; lastSplitAt = 0
        last = nil; recent = []
        running = true; paused = false
        segmentStart = .now
        manager.allowsBackgroundLocationUpdates = true
        manager.showsBackgroundLocationIndicator = true
        manager.pausesLocationUpdatesAutomatically = false
        manager.startUpdatingLocation()
        startTimer()
    }

    func pause() {
        guard running, !paused else { return }
        paused = true
        accumulated += Date.now.timeIntervalSince(segmentStart)
        last = nil
        manager.stopUpdatingLocation()
    }

    func resume() {
        guard running, paused else { return }
        paused = false
        segmentStart = .now
        manager.startUpdatingLocation()
    }

    func stop() {
        if !paused { accumulated += Date.now.timeIntervalSince(segmentStart) }
        elapsed = accumulated
        running = false
        timer?.invalidate(); timer = nil
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self, self.running, !self.paused else { return }
            self.elapsed = self.accumulated + Date.now.timeIntervalSince(self.segmentStart)
        }
    }

    func locationManagerDidChangeAuthorization(_ m: CLLocationManager) {
        denied = m.authorizationStatus == .denied || m.authorizationStatus == .restricted
    }

    func locationManager(_ m: CLLocationManager, didUpdateLocations locs: [CLLocation]) {
        for loc in locs {
            accuracy = loc.horizontalAccuracy
            // descarta leituras imprecisas ou antigas
            guard loc.horizontalAccuracy >= 0, loc.horizontalAccuracy < 25, abs(loc.timestamp.timeIntervalSinceNow) < 10 else { continue }
            if let prev = last {
                let d = loc.distance(from: prev)
                let dt = loc.timestamp.timeIntervalSince(prev.timestamp)
                guard dt > 0, d / dt < 25 else { continue }      // > 90 km/h = salto de GPS
                meters += d
                let dz = loc.altitude - prev.altitude
                if dz > 0, loc.verticalAccuracy >= 0, loc.verticalAccuracy < 15 { climb += dz }
                recent.append((loc.timestamp, meters))
                recent.removeAll { loc.timestamp.timeIntervalSince($0.0) > 60 }
                if let first = recent.first, meters - first.1 > 30 {
                    currentPace = loc.timestamp.timeIntervalSince(first.0) / ((meters - first.1) / 1000)
                }
                let km = Int(meters / 1000)
                if km > splits.count {
                    let now = accumulated + Date.now.timeIntervalSince(segmentStart)
                    splits.append(now - lastSplitAt); lastSplitAt = now
                }
            }
            last = loc
            coords.append(loc.coordinate)
        }
    }
}

// MARK: - Tela de cardio ao vivo

struct CardioLiveView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \WeightEntry.date, order: .reverse) private var weights: [WeightEntry]
    @State private var tracker = CardioTracker()
    @State private var kind = CardioKind.run
    @State private var camera: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var saved: CardioSession?
    @State private var confirmStop = false

    private var kg: Double { weights.first?.kg ?? 70 }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Map(position: $camera) {
                    UserAnnotation()
                    if tracker.coords.count > 1 {
                        MapPolyline(coordinates: tracker.coords).stroke(Theme.accent, lineWidth: 5)
                    }
                }
                .mapControls { MapUserLocationButton() }
                .frame(maxHeight: .infinity)

                VStack(spacing: 14) {
                    if !tracker.running {
                        Picker("", selection: $kind) {
                            ForEach(CardioKind.allCases) { Label($0.title, systemImage: $0.icon).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }
                    Text(String(format: "%.2f km", tracker.meters / 1000))
                        .font(.system(size: 52, weight: .bold, design: .rounded)).monospacedDigit()
                        .contentTransition(.numericText())
                    HStack {
                        stat("Tempo", CardioFormat.time(tracker.elapsed))
                        stat(kind == .bike ? "km/h" : "Ritmo", kind == .bike
                             ? (tracker.currentPace > 0 ? (3600 / tracker.currentPace).fmt(1) : "--")
                             : CardioFormat.pace(tracker.currentPace))
                        stat("kcal", Int(kind.kcal(kg: kg, km: tracker.meters / 1000, seconds: tracker.elapsed, climbM: tracker.climb)).description)
                    }
                    if tracker.accuracy > 25 || tracker.accuracy < 0, tracker.running {
                        Label("Procurando sinal de GPS…", systemImage: "location.slash").font(.caption).foregroundStyle(Theme.warm)
                    }
                    if tracker.denied {
                        Text("Permita a localização em Ajustes → Gym para registrar o percurso.").font(.caption).foregroundStyle(Theme.danger)
                    }
                    controls
                }
                .padding()
                .background(.bar)
            }
            .navigationTitle(kind.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { if tracker.running { confirmStop = true } else { dismiss() } }
                }
            }
            .onAppear { tracker.requestPermission() }
            .confirmationDialog("Descartar esta atividade?", isPresented: $confirmStop, titleVisibility: .visible) {
                Button("Descartar", role: .destructive) { tracker.stop(); dismiss() }
            }
            .sheet(item: $saved, onDismiss: { dismiss() }) { CardioDetailView(session: $0) }
        }
        .interactiveDismissDisabled(tracker.running)
    }

    private var controls: some View {
        HStack(spacing: 20) {
            if !tracker.running {
                Button { tracker.start() } label: {
                    Label("Iniciar", systemImage: "play.fill").font(.headline).frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.borderedProminent).tint(Theme.good)
            } else {
                Button { tracker.paused ? tracker.resume() : tracker.pause() } label: {
                    Image(systemName: tracker.paused ? "play.fill" : "pause.fill").font(.title2).frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.bordered)
                Button { finish() } label: {
                    Image(systemName: "stop.fill").font(.title2).frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.borderedProminent).tint(Theme.danger)
            }
        }
    }

    private func stat(_ t: String, _ v: String) -> some View {
        VStack(spacing: 2) {
            Text(v).font(.title3.bold()).monospacedDigit()
            Text(t).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func finish() {
        tracker.stop()
        guard tracker.meters > 50 else { dismiss(); return }
        let s = CardioSession(kind: kind)
        s.start = Date.now.addingTimeInterval(-tracker.elapsed)
        s.seconds = tracker.elapsed
        s.km = tracker.meters / 1000
        s.climbM = tracker.climb
        s.kcal = kind.kcal(kg: kg, km: s.km, seconds: s.seconds, climbM: s.climbM)
        s.route = CardioSession.pack(Self.simplify(tracker.coords))
        s.splits = tracker.splits
        context.insert(s)
        HealthSync.shared.saveCardio(s)
        PartyService.shared.post(.workout, "\(kind.verb) \(s.km.fmt(2)) km em \(CardioFormat.time(s.seconds))"
                                 + (kind == .bike ? "" : " (ritmo \(CardioFormat.pace(s.pace))/km)") + " 🏃", value: s.seconds / 60)
        AchievementEngine.check(context)
        saved = s
    }

    /// Reduz pontos do percurso (mantém 1 a cada ~10 m) para guardar pouco.
    static func simplify(_ c: [CLLocationCoordinate2D]) -> [CLLocationCoordinate2D] {
        guard c.count > 2 else { return c }
        var out = [c[0]]
        var lastLoc = CLLocation(latitude: c[0].latitude, longitude: c[0].longitude)
        for p in c.dropFirst() {
            let l = CLLocation(latitude: p.latitude, longitude: p.longitude)
            if l.distance(from: lastLoc) >= 10 { out.append(p); lastLoc = l }
        }
        if let last = c.last { out.append(last) }
        return out
    }
}

// MARK: - Detalhe e histórico

struct CardioDetailView: View {
    let session: CardioSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let coords = session.coordinates
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    if coords.count > 1 {
                        Map(initialPosition: .automatic, interactionModes: [.zoom, .pan]) {
                            MapPolyline(coordinates: coords).stroke(Theme.accent, lineWidth: 5)
                            Annotation("", coordinate: coords[0]) { Circle().fill(Theme.good).frame(width: 12) }
                            Annotation("", coordinate: coords[coords.count - 1]) { Circle().fill(Theme.danger).frame(width: 12) }
                        }
                        .frame(height: 260).clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    Card {
                        LazyVGrid(columns: [GridItem(), GridItem(), GridItem()], spacing: 14) {
                            cell(session.km.fmt(2), "km")
                            cell(CardioFormat.time(session.seconds), "tempo")
                            cell(session.kind == .bike ? (session.km / (session.seconds / 3600)).fmt(1) : CardioFormat.pace(session.pace),
                                 session.kind == .bike ? "km/h" : "min/km")
                            cell("\(Int(session.kcal))", "kcal")
                            cell("\(Int(session.climbM))", "m subida")
                            cell(session.start.formatted(.dateTime.day().month(.abbreviated)), "data")
                        }
                    }
                    if !session.splits.isEmpty {
                        Card {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Parciais por km", systemImage: "flag.fill").font(.headline)
                                Chart(Array(session.splits.enumerated()), id: \.offset) { i, s in
                                    BarMark(x: .value("km", "\(i + 1)"), y: .value("ritmo", s / 60))
                                        .foregroundStyle(s == session.splits.min() ? Theme.good : Theme.accent)
                                }
                                .chartYAxisLabel("min/km")
                                .frame(height: 160)
                                ForEach(Array(session.splits.enumerated()), id: \.offset) { i, s in
                                    HStack { Text("km \(i + 1)"); Spacer(); Text(CardioFormat.pace(s)).monospacedDigit() }.font(.callout)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle(session.kind.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("OK") { dismiss() } }
        }
    }

    private func cell(_ v: String, _ l: String) -> some View {
        VStack(spacing: 2) { Text(v).font(.headline.monospacedDigit()); Text(l).font(.caption2).foregroundStyle(.secondary) }
    }
}

struct CardioCard: View {
    @Query(sort: \CardioSession.start, order: .reverse) private var sessions: [CardioSession]
    @State private var live = false
    @State private var detail: CardioSession?

    var body: some View {
        let weekAgo = Date.now.addingTimeInterval(-7 * 86400)
        let week = sessions.filter { $0.start > weekAgo }
        let best5k = sessions.filter { $0.kind == .run && $0.km >= 5 }.map(\.pace).min()
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Cardio com GPS", systemImage: "location.fill").font(.headline)
                    Spacer()
                    Button { live = true } label: { Label("Iniciar", systemImage: "play.fill").font(.subheadline.bold()) }
                        .buttonStyle(.borderedProminent).tint(Theme.good)
                }
                if !sessions.isEmpty {
                    HStack {
                        mini("\(week.map(\.km).reduce(0, +).fmt(1)) km", "na semana")
                        mini("\(sessions.map(\.km).reduce(0, +).fmt(0)) km", "no total")
                        mini(best5k.map { CardioFormat.pace($0) } ?? "--", "melhor ritmo 5 km+")
                    }
                    ForEach(sessions.prefix(3)) { s in
                        Button { detail = s } label: {
                            HStack {
                                Image(systemName: s.kind.icon).foregroundStyle(Theme.accent).frame(width: 26)
                                VStack(alignment: .leading) {
                                    Text("\(s.km.fmt(2)) km · \(CardioFormat.time(s.seconds))").font(.subheadline.bold())
                                    Text(s.start, format: .dateTime.weekday().day().month()).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(s.kind == .bike ? "" : "\(CardioFormat.pace(s.pace))/km").font(.caption.monospacedDigit())
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.tap)
                    }
                } else {
                    Text("Corrida, caminhada ou pedalada com mapa, ritmo, parciais por km e calorias.")
                        .font(.callout).foregroundStyle(.secondary)
                }
            }
        }
        .fullScreenCover(isPresented: $live) { CardioLiveView() }
        .sheet(item: $detail) { CardioDetailView(session: $0) }
    }

    private func mini(_ v: String, _ l: String) -> some View {
        VStack(alignment: .leading, spacing: 1) { Text(v).font(.subheadline.bold()); Text(l).font(.caption2).foregroundStyle(.secondary) }
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Periodização e deload

/// Analisa as últimas semanas e recomenda manter, progredir ou fazer deload.
enum Periodization {
    struct Status {
        let weeksInARow: Int
        let stalled: Int            // exercícios principais sem recorde há 3+ semanas
        let tracked: Int
        let avgRPE: Double?
        let ratingDrop: Bool
        var recommendDeload: Bool { weeksInARow >= 6 || (weeksInARow >= 4 && (stalled * 2 >= max(tracked, 1) || ratingDrop || (avgRPE ?? 0) >= 9)) }
        var reasons: [String] {
            var r: [String] = []
            if weeksInARow >= 4 { r.append("\(weeksInARow) semanas seguidas de treino") }
            if tracked > 0, stalled > 0 { r.append("\(stalled) de \(tracked) exercícios principais sem recorde há 3+ semanas") }
            if let a = avgRPE, a >= 8.5 { r.append("esforço médio alto (RPE \(a.fmt(1)))") }
            if ratingDrop { r.append("você tem se sentido pior nos treinos") }
            return r
        }
    }

    static func analyze(_ sessions: [WorkoutSession]) -> Status {
        let cal = Calendar.current
        let done = sessions.filter { !$0.isActive }
        // semanas consecutivas (até a atual) com 2+ treinos
        var perWeek: [Date: Int] = [:]
        for s in done { if let w = cal.dateInterval(of: .weekOfYear, for: s.start)?.start { perWeek[w, default: 0] += 1 } }
        var weeks = 0
        var w = cal.dateInterval(of: .weekOfYear, for: .now)!.start
        if (perWeek[w] ?? 0) < 2 { w = cal.date(byAdding: .weekOfYear, value: -1, to: w)! }
        while (perWeek[w] ?? 0) >= 2 { weeks += 1; w = cal.date(byAdding: .weekOfYear, value: -1, to: w)! }

        // estagnação: melhor 1RM nas últimas 3 semanas vs antes
        let cut = Date.now.addingTimeInterval(-21 * 86400)
        var before: [String: Double] = [:], recent: [String: Double] = [:], freq: [String: Int] = [:]
        var rpes: [Double] = []
        for s in done {
            for e in s.exercises {
                guard let top = e.workSets.map(\.e1RM).max(), top > 0 else { continue }
                freq[e.exerciseID, default: 0] += 1
                if s.start >= cut { recent[e.exerciseID] = max(recent[e.exerciseID] ?? 0, top) }
                else { before[e.exerciseID] = max(before[e.exerciseID] ?? 0, top) }
                if s.start >= cut { rpes.append(contentsOf: e.workSets.compactMap(\.rpe)) }
            }
        }
        let main = freq.sorted { $0.value > $1.value }.prefix(6).map(\.key).filter { before[$0] != nil && recent[$0] != nil }
        let stalled = main.filter { recent[$0]! <= before[$0]! }.count

        let rated = done.filter { $0.rating > 0 }.prefix(10)
        let r1 = rated.prefix(4).map { Double($0.rating) }, r0 = rated.dropFirst(4).map { Double($0.rating) }
        let drop = r1.count >= 3 && r0.count >= 3 && r1.reduce(0, +) / Double(r1.count) < r0.reduce(0, +) / Double(r0.count) - 0.6

        return Status(weeksInARow: weeks, stalled: stalled, tracked: main.count,
                      avgRPE: rpes.isEmpty ? nil : rpes.reduce(0, +) / Double(rpes.count), ratingDrop: drop)
    }

    static var deloadUntil: Date? {
        get { UserDefaults.standard.object(forKey: "deloadUntil.\(ProfileRegistry.shared.activeID)") as? Date }
        set { UserDefaults.standard.set(newValue, forKey: "deloadUntil.\(ProfileRegistry.shared.activeID)") }
    }
    static var inDeload: Bool { (deloadUntil ?? .distantPast) > .now }
}

struct PeriodizationCard: View {
    let sessions: [WorkoutSession]
    @State private var deloadUntil = Periodization.deloadUntil

    var body: some View {
        let st = Periodization.analyze(sessions)
        let active = (deloadUntil ?? .distantPast) > .now
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Label(active ? "Semana de deload" : "Periodização", systemImage: active ? "battery.50percent" : "calendar.badge.clock")
                    .font(.headline)
                if active, let until = deloadUntil {
                    Text("Até \(until.formatted(.dateTime.weekday(.wide).day().month())): faça ~50–60% das séries de sempre, com 85–90% da carga e longe da falha (RPE ≤ 7). É assim que o corpo absorve o treino e volta mais forte.")
                        .font(.callout)
                    Button("Encerrar deload") { set(nil) }.font(.caption)
                } else if st.recommendDeload {
                    Text("Hora de um deload 🔋").font(.subheadline.bold()).foregroundStyle(Theme.warm)
                    ForEach(st.reasons, id: \.self) { Label($0, systemImage: "exclamationmark.circle").font(.caption) }
                    Text("Uma semana mais leve a cada 4–6 de treino duro reduz a fadiga acumulada e destrava os ganhos (Bell et al., 2023).")
                        .font(.caption).foregroundStyle(.secondary)
                    Button { set(Calendar.current.date(byAdding: .day, value: 7, to: .now)) } label: {
                        Label("Programar deload de 7 dias", systemImage: "calendar.badge.plus").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent).tint(Theme.warm)
                } else {
                    let left = max(0, 5 - st.weeksInARow)
                    Text(st.weeksInARow == 0 ? "Treine 2+ vezes por semana para o app acompanhar seu ciclo."
                         : "Semana \(st.weeksInARow) do ciclo · fase de progressão. Continue aumentando reps e carga (veja a sugestão em cada exercício)."
                           + (left > 0 ? " Deload sugerido em ~\(left) semana\(left == 1 ? "" : "s")." : ""))
                        .font(.callout)
                    ProgressBar(progress: Double(st.weeksInARow) / 5, tint: Theme.accent, height: 6)
                    if !st.reasons.isEmpty {
                        ForEach(st.reasons, id: \.self) { Text("• " + $0).font(.caption).foregroundStyle(.secondary) }
                    }
                }
            }
        }
    }

    private func set(_ d: Date?) {
        Periodization.deloadUntil = d
        withAnimation { deloadUntil = d }
    }
}
