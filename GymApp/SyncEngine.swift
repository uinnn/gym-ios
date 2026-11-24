import Foundation
import SwiftData
import Network
import Observation

// MARK: - Conta (e-mail e senha) — separada do login anônimo da Party

enum SyncAuthError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let m) = self { return m }; return nil }

    static func from(_ code: String) -> SyncAuthError {
        let m: String = switch code {
        case let c where c.hasPrefix("EMAIL_EXISTS"): "Esse e-mail já tem conta. Use \"Entrar\"."
        case let c where c.hasPrefix("EMAIL_NOT_FOUND"), let c where c.hasPrefix("INVALID_LOGIN_CREDENTIALS"),
             let c where c.hasPrefix("INVALID_PASSWORD"): "E-mail ou senha incorretos."
        case let c where c.hasPrefix("WEAK_PASSWORD"): "Senha fraca: use pelo menos 6 caracteres."
        case let c where c.hasPrefix("INVALID_EMAIL"): "E-mail inválido."
        case let c where c.hasPrefix("TOO_MANY_ATTEMPTS"): "Muitas tentativas. Espere alguns minutos."
        case let c where c.hasPrefix("OPERATION_NOT_ALLOWED"), let c where c.hasPrefix("ADMIN_ONLY"):
            "Login por e-mail não está ativado no Firebase (Authentication → Método de login → E-mail/senha)."
        case let c where c.hasPrefix("USER_DISABLED"): "Esta conta foi desativada."
        case let c where c.hasPrefix("TOKEN_EXPIRED"), let c where c.hasPrefix("INVALID_REFRESH_TOKEN"),
             let c where c.hasPrefix("USER_NOT_FOUND"): "Sua sessão expirou. Entre de novo."
        default: "Erro do Firebase: \(code)"
        }
        return .message(m)
    }
}

actor SyncAuth {
    static let shared = SyncAuth()
    private let d = UserDefaults.standard
    private var idToken: String?
    private var expiry = Date.distantPast
    private let session: URLSession = {
        let c = URLSessionConfiguration.default
        c.timeoutIntervalForRequest = 20
        c.waitsForConnectivity = false
        return URLSession(configuration: c)
    }()

    nonisolated var uid: String? { UserDefaults.standard.string(forKey: "sync.uid") }
    nonisolated var email: String? { UserDefaults.standard.string(forKey: "sync.email") }
    nonisolated var isSignedIn: Bool { SecureStore.get("sync.refresh") != nil && uid != nil }

    private func call(_ endpoint: String, _ body: [String: Any]) async throws -> [String: Any] {
        guard FirebaseConfig.isConfigured else { throw SyncAuthError.message("Firebase não configurado.") }
        var r = URLRequest(url: URL(string: "https://identitytoolkit.googleapis.com/v1/accounts:\(endpoint)?key=\(FirebaseConfig.apiKey)")!)
        r.httpMethod = "POST"
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp): (Data, URLResponse)
        do { (data, resp) = try await session.data(for: r) } catch { throw SyncAuthError.message("Sem conexão com a internet.") }
        let j = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        if let h = resp as? HTTPURLResponse, !(200..<300).contains(h.statusCode) {
            let msg = ((j["error"] as? [String: Any])?["message"] as? String) ?? "HTTP \(h.statusCode)"
            throw SyncAuthError.from(msg)
        }
        return j
    }

    private func store(_ j: [String: Any]) {
        if let t = j["idToken"] as? String { idToken = t }
        expiry = .now.addingTimeInterval(Double(j["expiresIn"] as? String ?? "3600") ?? 3600)
        if let r = j["refreshToken"] as? String { SecureStore.set("sync.refresh", r) }
        if let u = j["localId"] as? String { d.set(u, forKey: "sync.uid") }
        if let e = j["email"] as? String { d.set(e, forKey: "sync.email") }
    }

    func signUp(email: String, password: String) async throws {
        let j = try await call("signUp", ["email": email, "password": password, "returnSecureToken": true])
        store(j)
        try? await sendVerification()
    }

    func signIn(email: String, password: String) async throws {
        let j = try await call("signInWithPassword", ["email": email, "password": password, "returnSecureToken": true])
        store(j)
    }

    func sendVerification() async throws {
        _ = try await call("sendOobCode", ["requestType": "VERIFY_EMAIL", "idToken": try await token()])
    }

    func resetPassword(email: String) async throws {
        _ = try await call("sendOobCode", ["requestType": "PASSWORD_RESET", "email": email])
    }

    /// Consulta se o e-mail já foi verificado.
    func emailVerified() async -> Bool {
        guard let t = try? await token(), let j = try? await call("lookup", ["idToken": t]),
              let u = (j["users"] as? [[String: Any]])?.first else { return false }
        return u["emailVerified"] as? Bool ?? false
    }

    func signOut() {
        idToken = nil
        SecureStore.set("sync.refresh", nil)
        d.removeObject(forKey: "sync.uid")
        d.removeObject(forKey: "sync.email")
    }

    func token() async throws -> String {
        if let t = idToken, expiry > .now.addingTimeInterval(60) { return t }
        guard let refresh = SecureStore.get("sync.refresh") else { throw SyncAuthError.message("Entre na sua conta.") }
        var r = URLRequest(url: URL(string: "https://securetoken.googleapis.com/v1/token?key=\(FirebaseConfig.apiKey)")!)
        r.httpMethod = "POST"
        r.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let enc = refresh.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? refresh
        r.httpBody = "grant_type=refresh_token&refresh_token=\(enc)".data(using: .utf8)
        let (data, resp): (Data, URLResponse)
        do { (data, resp) = try await session.data(for: r) } catch { throw SyncAuthError.message("Sem conexão com a internet.") }
        let j = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        guard (resp as? HTTPURLResponse)?.statusCode == 200, let t = j["id_token"] as? String else {
            let msg = ((j["error"] as? [String: Any])?["message"] as? String) ?? "TOKEN_EXPIRED"
            throw SyncAuthError.from(msg)
        }
        idToken = t
        expiry = .now.addingTimeInterval(Double(j["expires_in"] as? String ?? "3600") ?? 3600)
        if let nr = j["refresh_token"] as? String { SecureStore.set("sync.refresh", nr) }
        return t
    }
}

// MARK: - Registros sincronizáveis

/// Um registro do banco local que pode ir para o site e voltar.
protocol Syncable: PersistentModel {
    static var collection: String { get }
    var syncID: String { get set }
    var syncUpdated: Double { get set }
    var syncSent: Double { get set }
    func payload() -> [String: Any]
    func apply(_ p: [String: Any])
    init()
}

extension Syncable {
    var isPending: Bool { syncUpdated > syncSent }
    var isSynced: Bool { syncSent > 0 && syncSent >= syncUpdated }
}

private func ms(_ d: Date) -> Double { (d.timeIntervalSince1970 * 1000).rounded() }
private func syncDate(_ v: Any?) -> Date? { (v as? Double).map { Date(timeIntervalSince1970: $0 / 1000) } ?? (v as? Int).map { Date(timeIntervalSince1970: Double($0) / 1000) } }
private func dbl(_ v: Any?) -> Double? { (v as? Double) ?? (v as? Int).map(Double.init) }
private func json<T: Encodable>(_ v: T) -> Any? { (try? JSONEncoder().encode(v)).flatMap { try? JSONSerialization.jsonObject(with: $0) } }
private func decode<T: Decodable>(_ t: T.Type, _ v: Any?) -> T? {
    guard let v, JSONSerialization.isValidJSONObject(v) || v is [Any] || v is [String: Any],
          let d = try? JSONSerialization.data(withJSONObject: v) else { return nil }
    return try? JSONDecoder().decode(T.self, from: d)
}
private func blob(_ d: Data) -> Any? { d.isEmpty ? nil : try? JSONSerialization.jsonObject(with: d) }
private func unblob(_ v: Any?) -> Data? { v.flatMap { try? JSONSerialization.data(withJSONObject: $0) } }

extension WeightEntry: Syncable {
    static var collection: String { "weights" }
    convenience init() { self.init(kg: 0) }
    func payload() -> [String: Any] { ["date": ms(date), "kg": kg, "source": source, "note": note, "tags": tagsRaw] }
    func apply(_ p: [String: Any]) {
        if let d = syncDate(p["date"]) { date = d }
        if let v = dbl(p["kg"]) { kg = v }
        source = p["source"] as? String ?? source
        note = p["note"] as? String ?? note
        tagsRaw = p["tags"] as? String ?? tagsRaw
    }
}

extension MeasurementEntry: Syncable {
    static var collection: String { "measurements" }
    convenience init() { self.init(date: .now) }
    func payload() -> [String: Any] {
        var p: [String: Any] = ["date": ms(date), "note": note]
        for part in BodyPart.allCases { if let v = self[part] { p[part.rawValue] = v } }
        return p
    }
    func apply(_ p: [String: Any]) {
        if let d = syncDate(p["date"]) { date = d }
        note = p["note"] as? String ?? note
        for part in BodyPart.allCases { self[part] = dbl(p[part.rawValue]) }
    }
}

extension FoodLog: Syncable {
    static var collection: String { "foods" }
    convenience init() { self.init(date: .now, meal: .lunch, food: FoodItem(id: "", name: "", category: "", per100: Nutrients()), grams: 0) }
    func payload() -> [String: Any] {
        var p: [String: Any] = ["date": ms(date), "meal": mealRaw, "foodID": foodID, "name": name, "grams": grams]
        p["nutrients"] = json(nutrients)
        if let m = micros { p["micros"] = json(m) }
        if extrasData != nil { p["extras"] = extras }
        return p
    }
    func apply(_ p: [String: Any]) {
        if let d = syncDate(p["date"]) { date = d }
        mealRaw = p["meal"] as? String ?? mealRaw
        foodID = p["foodID"] as? String ?? foodID
        name = p["name"] as? String ?? name
        if let g = dbl(p["grams"]) { grams = g }
        if let n = decode(Nutrients.self, p["nutrients"]) { nutrients = n }
        micros = decode(Micros.self, p["micros"])
        if let e = p["extras"] as? [String: Double] { extras = e }
    }
}

extension SavedFood: Syncable {
    static var collection: String { "savedFoods" }
    convenience init() { self.init(FoodItem(id: "", name: "", category: "", per100: Nutrients())) }
    func payload() -> [String: Any] {
        var p: [String: Any] = ["foodID": foodID, "favorite": favorite, "useCount": useCount, "lastUsed": ms(lastUsed),
                                "lastGrams": lastGrams, "isCustom": isCustom]
        p["food"] = blob(data)
        return p
    }
    func apply(_ p: [String: Any]) {
        foodID = p["foodID"] as? String ?? foodID
        favorite = p["favorite"] as? Bool ?? favorite
        useCount = (p["useCount"] as? Int) ?? useCount
        if let d = syncDate(p["lastUsed"]) { lastUsed = d }
        if let g = dbl(p["lastGrams"]) { lastGrams = g }
        isCustom = p["isCustom"] as? Bool ?? isCustom
        if let d = unblob(p["food"]) { data = d }
    }
}

extension WaterLog: Syncable {
    static var collection: String { "water" }
    convenience init() { self.init(ml: 0) }
    func payload() -> [String: Any] { ["date": ms(date), "ml": ml] }
    func apply(_ p: [String: Any]) {
        if let d = syncDate(p["date"]) { date = d }
        if let v = dbl(p["ml"]) { ml = v }
    }
}

extension WorkoutSession: Syncable {
    static var collection: String { "workouts" }
    convenience init() { self.init(name: "Treino", exercises: [], bodyKg: 70) }
    func payload() -> [String: Any] {
        var p: [String: Any] = ["start": ms(start), "name": name, "note": note, "bodyKg": bodyKg, "rating": rating]
        if let end { p["end"] = ms(end) }
        p["exercises"] = blob(data) ?? []
        return p
    }
    func apply(_ p: [String: Any]) {
        if let d = syncDate(p["start"]) { start = d }
        end = syncDate(p["end"])
        name = p["name"] as? String ?? name
        note = p["note"] as? String ?? note
        if let v = dbl(p["bodyKg"]) { bodyKg = v }
        rating = (p["rating"] as? Int) ?? rating
        if let d = unblob(p["exercises"]) { data = d }
    }
}

extension WorkoutRoutine: Syncable {
    static var collection: String { "routines" }
    convenience init() { self.init(name: "Rotina", items: []) }
    func payload() -> [String: Any] {
        var p: [String: Any] = ["name": name, "icon": icon, "order": order, "createdAt": ms(createdAt), "weekday": weekday]
        p["items"] = blob(data) ?? []
        return p
    }
    func apply(_ p: [String: Any]) {
        name = p["name"] as? String ?? name
        icon = p["icon"] as? String ?? icon
        order = (p["order"] as? Int) ?? order
        if let d = syncDate(p["createdAt"]) { createdAt = d }
        weekday = (p["weekday"] as? Int) ?? weekday
        if let d = unblob(p["items"]) { data = d }
    }
}

extension CardioSession: Syncable {
    static var collection: String { "cardio" }
    convenience init() { self.init(kind: .run) }
    func payload() -> [String: Any] {
        ["start": ms(start), "seconds": seconds, "km": km, "kcal": kcal, "climbM": climbM, "kind": kindRaw, "splits": splits]
    }
    func apply(_ p: [String: Any]) {
        if let d = syncDate(p["start"]) { start = d }
        if let v = dbl(p["seconds"]) { seconds = v }
        if let v = dbl(p["km"]) { km = v }
        if let v = dbl(p["kcal"]) { kcal = v }
        if let v = dbl(p["climbM"]) { climbM = v }
        kindRaw = p["kind"] as? String ?? kindRaw
        if let s = p["splits"] as? [Any] { splits = s.compactMap(dbl) }
    }
}

extension MoodEntry: Syncable {
    static var collection: String { "moods" }
    convenience init() { self.init(mood: 3) }
    func payload() -> [String: Any] {
        ["date": ms(date), "mood": mood, "energy": energy, "stress": stress, "anxiety": anxiety, "tags": tagsRaw, "note": note]
    }
    func apply(_ p: [String: Any]) {
        if let d = syncDate(p["date"]) { date = d }
        mood = (p["mood"] as? Int) ?? mood
        energy = (p["energy"] as? Int) ?? energy
        stress = (p["stress"] as? Int) ?? stress
        anxiety = (p["anxiety"] as? Int) ?? anxiety
        tagsRaw = p["tags"] as? String ?? tagsRaw
        note = p["note"] as? String ?? note
    }
}

extension SleepEntry: Syncable {
    static var collection: String { "sleep" }
    convenience init() { self.init(bedtime: .now, wake: .now, quality: 3) }
    func payload() -> [String: Any] {
        ["bedtime": ms(bedtime), "wake": ms(wake), "quality": quality, "awakenings": awakenings, "note": note]
    }
    func apply(_ p: [String: Any]) {
        if let d = syncDate(p["bedtime"]) { bedtime = d }
        if let d = syncDate(p["wake"]) { wake = d }
        quality = (p["quality"] as? Int) ?? quality
        awakenings = (p["awakenings"] as? Int) ?? awakenings
        note = p["note"] as? String ?? note
    }
}

extension UserProfile: Syncable {
    static var collection: String { "profile" }
    func payload() -> [String: Any] {
        var p: [String: Any] = ["name": name, "sex": sexRaw, "birthDate": ms(birthDate), "heightCm": heightCm,
                                "goalWeightKg": goalWeightKg, "activity": activityRaw, "goal": goalRaw, "createdAt": ms(createdAt)]
        if let w = waistCm { p["waistCm"] = w }
        return p
    }
    func apply(_ p: [String: Any]) {
        name = p["name"] as? String ?? name
        sexRaw = p["sex"] as? String ?? sexRaw
        if let d = syncDate(p["birthDate"]) { birthDate = d }
        if let v = dbl(p["heightCm"]) { heightCm = v }
        if let v = dbl(p["goalWeightKg"]) { goalWeightKg = v }
        activityRaw = p["activity"] as? String ?? activityRaw
        goalRaw = p["goal"] as? String ?? goalRaw
        waistCm = dbl(p["waistCm"])
    }
}

/// Tipos sincronizados e como cada um é buscado/criado (apaga o tipo concreto).
struct SyncKind {
    let collection: String
    let label: String
    let fetch: (ModelContext) -> [any Syncable]
    let make: (ModelContext) -> any Syncable

    static func of<T: Syncable>(_ t: T.Type, _ label: String) -> SyncKind {
        SyncKind(collection: T.collection, label: label,
                 fetch: { (try? $0.fetch(FetchDescriptor<T>())) ?? [] },
                 make: { ctx in let m = T(); ctx.insert(m); return m })
    }

    static let all: [SyncKind] = [
        .of(UserProfile.self, "Perfil"), .of(WeightEntry.self, "Pesagens"), .of(MeasurementEntry.self, "Medidas"),
        .of(FoodLog.self, "Alimentação"), .of(WaterLog.self, "Água"), .of(SavedFood.self, "Alimentos salvos"),
        .of(WorkoutSession.self, "Treinos"), .of(WorkoutRoutine.self, "Rotinas"), .of(CardioSession.self, "Cardio"),
        .of(MoodEntry.self, "Humor"), .of(SleepEntry.self, "Sono"),
    ]

    static func label(_ collection: String) -> String { all.first { $0.collection == collection }?.label ?? collection }
}

// MARK: - Motor

enum SyncMode: String, CaseIterable, Identifiable {
    case off, auto, manual
    var id: String { rawValue }
    var label: String { switch self { case .off: "Desligada"; case .auto: "Automática"; case .manual: "Manual" } }
}

struct RemoteChange: Identifiable {
    let id = UUID()
    let collection: String
    let syncID: String
    let updated: Double
    let deleted: Bool
    let payload: [String: Any]
    let server: String
}

@Observable
@MainActor
final class SyncEngine {
    static let shared = SyncEngine()
    private let d = UserDefaults.standard

    var mode: SyncMode { didSet { d.set(mode.rawValue, forKey: "sync.mode"); if mode == .auto { scheduleUpload() } } }
    /// Só este perfil do iPhone sincroniza.
    var profileID: String { didSet { d.set(profileID, forKey: "sync.profile") } }
    var signedIn = SyncAuth.shared.isSignedIn
    var email = SyncAuth.shared.email
    var busy = false
    var status: String?
    var lastSync: Date? { didSet { d.set(lastSync, forKey: "sync.last") } }
    var pendingCount = 0
    var online = true
    /// Alterações vindas do site esperando a confirmação (modo manual).
    var incoming: [RemoteChange] = []
    var progress: (done: Int, total: Int)?

    @ObservationIgnored private var suppress = false
    @ObservationIgnored private var uploadTask: Task<Void, Never>?
    @ObservationIgnored private var pendingTask: Task<Void, Never>?
    @ObservationIgnored private let monitor = NWPathMonitor()
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var lastPull = Date.distantPast

    private init() {
        mode = SyncMode(rawValue: d.string(forKey: "sync.mode") ?? "") ?? .off
        profileID = d.string(forKey: "sync.profile") ?? ProfileRegistry.shared.activeID
        lastSync = d.object(forKey: "sync.last") as? Date
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                guard let self else { return }
                let was = self.online
                self.online = path.status == .satisfied
                if !was && self.online { self.appBecameActive() }
            }
        }
        monitor.start(queue: DispatchQueue(label: "sync.net"))
    }

    var enabled: Bool { mode != .off && signedIn }
    var context: ModelContext { ProfileRegistry.shared.container(for: profileID).mainContext }
    private var container: ModelContainer { ProfileRegistry.shared.container(for: profileID) }

    // MARK: Rastreamento de alterações

    /// Observa os salvamentos do banco do perfil sincronizado. Chame uma vez ao abrir o app.
    func start() {
        guard observers.isEmpty else { return }
        observers.append(NotificationCenter.default.addObserver(forName: ModelContext.willSave, object: nil, queue: nil) { [weak self] n in
            guard Thread.isMainThread, let ctx = n.object as? ModelContext else { return }
            MainActor.assumeIsolated { self?.willSave(ctx) }
        })
        observers.append(NotificationCenter.default.addObserver(forName: ModelContext.didSave, object: nil, queue: nil) { [weak self] n in
            guard Thread.isMainThread, let ctx = n.object as? ModelContext else { return }
            MainActor.assumeIsolated { self?.didSave(ctx) }
        })
        refreshPending()
    }

    private func willSave(_ ctx: ModelContext) {
        guard !suppress, mode != .off, ctx.container === container else { return }
        let now = (Date.now.timeIntervalSince1970 * 1000).rounded()
        for case let m as any Syncable in ctx.insertedModelsArray + ctx.changedModelsArray {
            var m = m
            if m.syncID.isEmpty { m.syncID = UUID().uuidString }
            m.syncUpdated = max(now, m.syncSent + 1)
        }
        for case let m as any Syncable in ctx.deletedModelsArray where !m.syncID.isEmpty {
            addTombstone(type(of: m).collection, m.syncID, now)
        }
    }

    private func didSave(_ ctx: ModelContext) {
        guard !suppress, mode != .off, ctx.container === container else { return }
        pendingTask?.cancel()
        pendingTask = Task { try? await Task.sleep(for: .seconds(1)); if !Task.isCancelled { refreshPending() } }
        if mode == .auto { scheduleUpload() }
    }

    private func mute(_ work: () -> Void) {
        suppress = true
        work()
        try? context.save()
        suppress = false
    }

    // MARK: Exclusões pendentes

    private struct Tombstone: Codable, Hashable { let collection: String; let id: String; let at: Double }
    private var tombstones: [Tombstone] {
        get { d.data(forKey: "sync.tomb").flatMap { try? JSONDecoder().decode([Tombstone].self, from: $0) } ?? [] }
        set { d.set(try? JSONEncoder().encode(newValue), forKey: "sync.tomb") }
    }
    private func addTombstone(_ c: String, _ id: String, _ at: Double) {
        guard mode != .off else { return }
        var t = tombstones
        t.removeAll { $0.id == id }
        t.append(Tombstone(collection: c, id: id, at: at))
        tombstones = t
    }

    func refreshPending() {
        guard mode != .off else { pendingCount = 0; return }
        pendingCount = SyncKind.all.reduce(0) { $0 + $1.fetch(context).filter(\.isPending).count } + tombstones.count
    }

    func pendingItems() -> [(String, [any Syncable])] {
        SyncKind.all.compactMap { k in
            let p = k.fetch(context).filter(\.isPending)
            return p.isEmpty ? nil : (k.label, p)
        }
    }

    var pendingDeletes: Int { tombstones.count }

    // MARK: Envio

    func scheduleUpload() {
        uploadTask?.cancel()
        uploadTask = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            await uploadPending()
        }
    }

    /// Envia tudo que está pendente (modo automático ou botão "Enviar tudo").
    func uploadPending() async {
        guard enabled, online, !busy else { return }
        let items = SyncKind.all.flatMap { $0.fetch(context).filter(\.isPending) }
        await upload(items, deletes: tombstones)
    }

    /// Envia itens específicos (botão ao lado de cada registro no modo manual).
    func send(_ items: [any Syncable]) async {
        guard signedIn else { status = "Entre na sua conta em Ajustes → Sincronização."; return }
        guard online else { status = "Sem internet: tente de novo quando estiver conectado."; return }
        await upload(items, deletes: [])
    }

    private func upload(_ items: [any Syncable], deletes: [Tombstone]) async {
        guard !items.isEmpty || !deletes.isEmpty, let uid = SyncAuth.shared.uid else { return }
        busy = true
        defer { busy = false; progress = nil; refreshPending() }
        // garante id em registros antigos
        mute { for case var m in items where m.syncID.isEmpty { m.syncID = UUID().uuidString } }
        let device = "iphone"
        var writes: [(write: [String: Any], item: (any Syncable)?, tomb: Tombstone?)] = []
        for m in items {
            let path = docPath(uid, type(of: m).collection, m.syncID)
            writes.append((write(path, payload: m.payload(), updated: m.syncUpdated, deleted: false, device: device), m, nil))
        }
        for t in deletes {
            writes.append((write(docPath(uid, t.collection, t.id), payload: [:], updated: t.at, deleted: true, device: device), nil, t))
        }
        progress = (0, writes.count)
        do {
            for chunk in stride(from: 0, to: writes.count, by: 300).map({ Array(writes[$0..<min($0 + 300, writes.count)]) }) {
                try await commit(chunk.map(\.write))
                let sent = chunk.compactMap(\.item)
                mute { for case var m in sent { m.syncSent = m.syncUpdated } }
                let done = Set(chunk.compactMap(\.tomb))
                if !done.isEmpty { tombstones = tombstones.filter { !done.contains($0) } }
                progress = ((progress?.done ?? 0) + chunk.count, writes.count)
            }
            lastSync = .now
            status = "Enviado: \(writes.count) registro(s)."
        } catch {
            status = "Falha ao enviar: \(error.localizedDescription). Tentarei de novo depois."
        }
    }

    private func docPath(_ uid: String, _ c: String, _ id: String) -> String {
        "projects/\(FirebaseConfig.projectID)/databases/(default)/documents/users/\(uid)/\(c)/\(id)"
    }

    private func write(_ name: String, payload: [String: Any], updated: Double, deleted: Bool, device: String) -> [String: Any] {
        let data = (try? JSONSerialization.data(withJSONObject: payload)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        return [
            "update": ["name": name, "fields": [
                "data": ["stringValue": data], "updated": ["doubleValue": updated],
                "deleted": ["booleanValue": deleted], "device": ["stringValue": device],
            ]],
            "updateTransforms": [["fieldPath": "server", "setToServerValue": "REQUEST_TIME"]],
        ]
    }

    private func commit(_ writes: [[String: Any]]) async throws {
        let t = try await SyncAuth.shared.token()
        var r = URLRequest(url: URL(string: "https://firestore.googleapis.com/v1/projects/\(FirebaseConfig.projectID)/databases/(default)/documents:commit")!)
        r.httpMethod = "POST"
        r.timeoutInterval = 30
        r.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization")
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.httpBody = try JSONSerialization.data(withJSONObject: ["writes": writes])
        let (data, resp) = try await URLSession.shared.data(for: r)
        guard let h = resp as? HTTPURLResponse, (200..<300).contains(h.statusCode) else {
            let msg = ((try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? [String: Any])?["message"] as? String
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
            throw SyncAuthError.message(code == 403 ? "sem permissão (confira as regras do Firestore)" : (msg ?? "HTTP \(code)"))
        }
    }

    // MARK: Busca do que mudou no site

    private func cursorKey(_ c: String) -> String { "sync.cursor.\(profileID).\(c)" }

    /// Ao abrir o app: se houver internet, procura alterações feitas no site. Sem internet, ignora.
    func appBecameActive() {
        guard enabled, online, !busy, Date.now.timeIntervalSince(lastPull) > 20 else { return }
        lastPull = .now
        Task {
            await pull()
            if mode == .auto { await uploadPending() }
        }
    }

    func pull() async {
        guard enabled, online, let uid = SyncAuth.shared.uid else { return }
        busy = true
        defer { busy = false }
        var found: [RemoteChange] = []
        do {
            let t = try await SyncAuth.shared.token()
            for k in SyncKind.all {
                var cursor = d.string(forKey: cursorKey(k.collection))
                while true {
                    let page = try await query(uid: uid, collection: k.collection, after: cursor, token: t)
                    found += page
                    guard page.count == 300, let last = page.last?.server else { break }
                    cursor = last
                }
            }
        } catch {
            status = "Não consegui buscar do site: \(error.localizedDescription)"
            return
        }
        // Só o que for mais novo que a versão local e não tiver vindo deste iPhone.
        let relevant = found.filter { isNewer($0) }
        advanceCursors(found.filter { !isNewer($0) })
        guard !relevant.isEmpty else { lastSync = .now; return }
        if mode == .auto { apply(relevant) } else { incoming = relevant }
    }

    private func isNewer(_ r: RemoteChange) -> Bool {
        guard let k = SyncKind.all.first(where: { $0.collection == r.collection }) else { return false }
        if let local = k.fetch(context).first(where: { $0.syncID == r.syncID }) { return r.updated > local.syncUpdated }
        return !r.deleted
    }

    private func advanceCursors(_ changes: [RemoteChange]) {
        for (c, list) in Dictionary(grouping: changes, by: \.collection) {
            if let maxS = list.map(\.server).max(), maxS > (d.string(forKey: cursorKey(c)) ?? "") { d.set(maxS, forKey: cursorKey(c)) }
        }
    }

    private func query(uid: String, collection: String, after: String?, token: String) async throws -> [RemoteChange] {
        var q: [String: Any] = [
            "from": [["collectionId": collection]],
            "orderBy": [["field": ["fieldPath": "server"], "direction": "ASCENDING"]],
            "limit": 300,
        ]
        if let after {
            q["where"] = ["fieldFilter": ["field": ["fieldPath": "server"], "op": "GREATER_THAN", "value": ["timestampValue": after]]]
        }
        var r = URLRequest(url: URL(string: "https://firestore.googleapis.com/v1/projects/\(FirebaseConfig.projectID)/databases/(default)/documents/users/\(uid):runQuery")!)
        r.httpMethod = "POST"
        r.timeoutInterval = 30
        r.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.httpBody = try JSONSerialization.data(withJSONObject: ["structuredQuery": q])
        let (data, resp) = try await URLSession.shared.data(for: r)
        guard let h = resp as? HTTPURLResponse, (200..<300).contains(h.statusCode) else {
            throw SyncAuthError.message((resp as? HTTPURLResponse)?.statusCode == 403 ? "sem permissão (regras do Firestore)" : "HTTP \((resp as? HTTPURLResponse)?.statusCode ?? 0)")
        }
        let arr = (try JSONSerialization.jsonObject(with: data) as? [[String: Any]]) ?? []
        return arr.compactMap { $0["document"] as? [String: Any] }.compactMap { doc in
            let f = doc["fields"] as? [String: Any] ?? [:]
            let id = (doc["name"] as? String)?.split(separator: "/").last.map(String.init) ?? ""
            let raw = (f["data"] as? [String: Any])?["stringValue"] as? String ?? "{}"
            let payload = (raw.data(using: .utf8).flatMap { try? JSONSerialization.jsonObject(with: $0) } as? [String: Any]) ?? [:]
            let upd = f["updated"] as? [String: Any]
            let updated = (upd?["doubleValue"] as? Double) ?? Double(upd?["integerValue"] as? String ?? "") ?? 0
            let deleted = (f["deleted"] as? [String: Any])?["booleanValue"] as? Bool ?? false
            let server = (f["server"] as? [String: Any])?["timestampValue"] as? String ?? ""
            return id.isEmpty ? nil : RemoteChange(collection: collection, syncID: id, updated: updated, deleted: deleted, payload: payload, server: server)
        }
    }

    /// Aplica as alterações do site no banco local (a edição mais recente vence).
    func apply(_ changes: [RemoteChange]) {
        mute {
            for k in SyncKind.all {
                let list = changes.filter { $0.collection == k.collection }
                guard !list.isEmpty else { continue }
                var local = Dictionary(k.fetch(context).map { ($0.syncID, $0) }, uniquingKeysWith: { a, _ in a })
                for r in list.sorted(by: { $0.updated < $1.updated }) {
                    if let m = local[r.syncID] {
                        guard r.updated > m.syncUpdated else { continue }
                        if r.deleted {
                            context.delete(m)
                            local[r.syncID] = nil
                        } else {
                            var m = m
                            m.apply(r.payload)
                            m.syncUpdated = r.updated
                            m.syncSent = r.updated
                        }
                    } else if !r.deleted {
                        // Perfil é único: o site atualiza o perfil existente em vez de criar outro.
                        if k.collection == UserProfile.collection, var p = k.fetch(context).first {
                            p.apply(r.payload); p.syncID = r.syncID; p.syncUpdated = r.updated; p.syncSent = r.updated
                            continue
                        }
                        var m = k.make(context)
                        m.apply(r.payload)
                        m.syncID = r.syncID
                        m.syncUpdated = r.updated
                        m.syncSent = r.updated
                        local[r.syncID] = m
                    }
                }
            }
        }
        advanceCursors(changes)
        incoming = []
        lastSync = .now
        status = "\(changes.count) alteração(ões) do site aplicada(s)."
        refreshPending()
    }

    func discardIncoming() { incoming = [] }

    // MARK: Primeira sincronização e conta

    /// Marca todo o histórico deste perfil para envio (primeira vez).
    func uploadEverything() async {
        guard signedIn else { return }
        let now = (Date.now.timeIntervalSince1970 * 1000).rounded()
        mute {
            for k in SyncKind.all {
                for case var m in k.fetch(context) {
                    if m.syncID.isEmpty { m.syncID = UUID().uuidString }
                    if m.syncUpdated == 0 { m.syncUpdated = now }
                    if m.syncSent >= m.syncUpdated { m.syncSent = 0 }
                }
            }
        }
        refreshPending()
        let items = SyncKind.all.flatMap { $0.fetch(context).filter(\.isPending) }
        await upload(items, deletes: tombstones)
    }

    func didSignIn() {
        signedIn = SyncAuth.shared.isSignedIn
        email = SyncAuth.shared.email
        profileID = ProfileRegistry.shared.activeID
        refreshPending()
    }

    func signOut() async {
        await SyncAuth.shared.signOut()
        signedIn = false
        email = nil
        mode = .off
        incoming = []
        for k in SyncKind.all { d.removeObject(forKey: cursorKey(k.collection)) }
    }
}
