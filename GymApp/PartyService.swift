import Foundation
import Observation
import UserNotifications

// MARK: - Configuração do Firebase

/// Chaves do projeto Firebase. Pode ser preenchido aqui (vale para todos que instalarem o app)
/// ou dentro do app, na tela da Party.
enum FirebaseConfig {
    static let builtInAPIKey = "AIzaSyCPlTqK15G585C72wAgH07Nty59ka6kjOA"
    static let builtInProjectID = "gymapp-1afd0"

    static var apiKey: String { UserDefaults.standard.string(forKey: "fb.apiKey").nonEmpty ?? builtInAPIKey }
    static var projectID: String { UserDefaults.standard.string(forKey: "fb.projectID").nonEmpty ?? builtInProjectID }
    static var isConfigured: Bool { !apiKey.isEmpty && !projectID.isEmpty }
}

private extension Optional where Wrapped == String {
    var nonEmpty: String? { (self?.isEmpty ?? true) ? nil : self }
}

// MARK: - Modelos

enum PartyKind: String, Codable, CaseIterable, Identifiable {
    case weight, food, workout, mood, sleep, practice
    var id: String { rawValue }

    var title: String {
        switch self {
        case .weight: "Pesagens"
        case .food: "Alimentação"
        case .workout: "Treinos"
        case .mood: "Humor"
        case .sleep: "Sono"
        case .practice: "Práticas (respiração, meditação)"
        }
    }
    var icon: String {
        switch self {
        case .weight: "scalemass.fill"
        case .food: "fork.knife"
        case .workout: "dumbbell.fill"
        case .mood: "face.smiling"
        case .sleep: "moon.zzz.fill"
        case .practice: "wind"
        }
    }
    /// Pontos de constância no ranking.
    var points: Int {
        switch self {
        case .workout: 5
        case .weight, .mood, .practice: 2
        case .food, .sleep: 1
        }
    }
}

struct PartyMember: Codable, Identifiable, Hashable {
    var id: String
    var name: String
    var emoji: String
    var joined: Double
}

struct PartyEvent: Codable, Identifiable, Hashable {
    var id: String
    var member: String
    var name: String
    var emoji: String
    var kind: PartyKind
    var text: String
    var value: Double
    var ts: Double
    var date: Date { Date(timeIntervalSince1970: ts) }
}

struct Party: Codable, Equatable {
    var code: String
    var name: String
    var owner: String
    var members: [PartyMember]
    static let maxMembers = 6      // dono + 5 convidados
}

enum PartyError: LocalizedError {
    case notConfigured, notFound, full, http(Int, String)
    var errorDescription: String? {
        switch self {
        case .notConfigured: "Servidor não configurado."
        case .notFound: "Party não encontrada. Confira o código."
        case .full: "Essa party já está cheia (máximo de 6 pessoas)."
        case .http(let c, let m): "Erro do servidor (\(c)): \(m)"
        }
    }
}

// MARK: - Cliente REST (sem SDK: app menor e compilação mais rápida)

/// Login anônimo (Identity Toolkit) + Firestore via REST.
actor FirebaseClient {
    static let shared = FirebaseClient()
    private let d = UserDefaults.standard
    private let session: URLSession = {
        let c = URLSessionConfiguration.default
        c.timeoutIntervalForRequest = 15
        c.waitsForConnectivity = false
        return URLSession(configuration: c)
    }()

    private var idToken: String?
    private var expiry = Date.distantPast

    var uid: String? { d.string(forKey: "fb.uid") }

    func token() async throws -> String {
        guard FirebaseConfig.isConfigured else { throw PartyError.notConfigured }
        if let t = idToken, expiry > .now.addingTimeInterval(60) { return t }
        let key = FirebaseConfig.apiKey
        let json: [String: Any]
        if let refresh = d.string(forKey: "fb.refresh") {
            var r = URLRequest(url: URL(string: "https://securetoken.googleapis.com/v1/token?key=\(key)")!)
            r.httpMethod = "POST"
            r.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            r.httpBody = "grant_type=refresh_token&refresh_token=\(refresh)".data(using: .utf8)
            let j = try await send(r)
            json = ["idToken": j["id_token"] ?? "", "refreshToken": j["refresh_token"] ?? "",
                    "localId": j["user_id"] ?? "", "expiresIn": j["expires_in"] ?? "3600"]
        } else {
            var r = URLRequest(url: URL(string: "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=\(key)")!)
            r.httpMethod = "POST"
            r.setValue("application/json", forHTTPHeaderField: "Content-Type")
            r.httpBody = try JSONSerialization.data(withJSONObject: ["returnSecureToken": true])
            json = try await send(r)
        }
        guard let t = json["idToken"] as? String, !t.isEmpty else { throw PartyError.http(401, "sem token") }
        idToken = t
        expiry = .now.addingTimeInterval(Double(json["expiresIn"] as? String ?? "3600") ?? 3600)
        if let r = json["refreshToken"] as? String, !r.isEmpty { d.set(r, forKey: "fb.refresh") }
        if let u = json["localId"] as? String, !u.isEmpty { d.set(u, forKey: "fb.uid") }
        return t
    }

    private var base: String {
        "https://firestore.googleapis.com/v1/projects/\(FirebaseConfig.projectID)/databases/(default)/documents"
    }

    /// method + caminho relativo (ex.: "parties/ABC123") + corpo opcional.
    func request(_ method: String, _ path: String, query: String = "", body: [String: Any]? = nil) async throws -> [String: Any] {
        let t = try await token()
        var r = URLRequest(url: URL(string: "\(base)/\(path)\(query.isEmpty ? "" : "?" + query)")!)
        r.httpMethod = method
        r.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization")
        if let body {
            r.setValue("application/json", forHTTPHeaderField: "Content-Type")
            r.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        return try await send(r)
    }

    /// runQuery devolve uma lista, não um objeto.
    func runQuery(_ parent: String, _ q: [String: Any]) async throws -> [[String: Any]] {
        let t = try await token()
        var r = URLRequest(url: URL(string: "\(base)/\(parent):runQuery")!)
        r.httpMethod = "POST"
        r.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization")
        r.setValue("application/json", forHTTPHeaderField: "Content-Type")
        r.httpBody = try JSONSerialization.data(withJSONObject: ["structuredQuery": q])
        let (data, resp) = try await session.data(for: r)
        try check(resp, data)
        let arr = (try JSONSerialization.jsonObject(with: data) as? [[String: Any]]) ?? []
        return arr.compactMap { $0["document"] as? [String: Any] }
    }

    private func send(_ r: URLRequest) async throws -> [String: Any] {
        let (data, resp) = try await session.data(for: r)
        try check(resp, data)
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    private func check(_ resp: URLResponse, _ data: Data) throws {
        guard let h = resp as? HTTPURLResponse, !(200..<300).contains(h.statusCode) else { return }
        if h.statusCode == 404 { throw PartyError.notFound }
        if h.statusCode == 400 || h.statusCode == 401 { idToken = nil }
        let msg = ((try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? [String: Any])?["message"] as? String
        throw PartyError.http(h.statusCode, msg ?? "")
    }
}

// MARK: - Codificação de valores do Firestore

enum FS {
    static func s(_ v: String) -> [String: Any] { ["stringValue": v] }
    static func n(_ v: Double) -> [String: Any] { ["doubleValue": v] }
    static func map(_ f: [String: Any]) -> [String: Any] { ["mapValue": ["fields": f]] }

    static func str(_ f: [String: Any]?, _ k: String) -> String { (f?[k] as? [String: Any])?["stringValue"] as? String ?? "" }
    static func num(_ f: [String: Any]?, _ k: String) -> Double {
        guard let v = f?[k] as? [String: Any] else { return 0 }
        if let d = v["doubleValue"] as? Double { return d }
        if let i = v["integerValue"] as? String { return Double(i) ?? 0 }
        return 0
    }
    static func fields(_ doc: [String: Any]) -> [String: Any] { doc["fields"] as? [String: Any] ?? [:] }
    static func docID(_ doc: [String: Any]) -> String { (doc["name"] as? String)?.split(separator: "/").last.map(String.init) ?? "" }
}

// MARK: - Serviço da party (estado observável)

@Observable
@MainActor
final class PartyService {
    static let shared = PartyService()
    private let d = UserDefaults.standard
    private let api = FirebaseClient.shared

    private(set) var party: Party?
    private(set) var events: [PartyEvent] = []
    private(set) var unread = 0
    private(set) var syncing = false
    var lastError: String?

    /// O que este perfil compartilha.
    var shared: Set<PartyKind> {
        didSet { d.set(shared.map(\.rawValue), forKey: key("share")) }
    }
    var showExactWeight: Bool { didSet { d.set(showExactWeight, forKey: key("exactKg")) } }
    var notify: Bool { didSet { d.set(notify, forKey: key("notify")) } }

    @ObservationIgnored private var profileID = ""
    @ObservationIgnored private var pending: [PartyEvent] = []
    @ObservationIgnored private var lastPoll = Date.distantPast
    @ObservationIgnored private var pollTask: Task<Void, Never>?

    private init() {
        shared = Set(PartyKind.allCases); showExactWeight = false; notify = true
        load(profile: ProfileRegistry.shared.activeID)
    }

    private func key(_ k: String) -> String { "party.\(profileID).\(k)" }

    /// Cada perfil da família pode estar numa party diferente.
    func load(profile id: String) {
        guard id != profileID else { return }
        profileID = id
        party = d.data(forKey: key("party")).flatMap { try? JSONDecoder().decode(Party.self, from: $0) }
        events = d.data(forKey: key("events")).flatMap { try? JSONDecoder().decode([PartyEvent].self, from: $0) } ?? []
        pending = d.data(forKey: key("pending")).flatMap { try? JSONDecoder().decode([PartyEvent].self, from: $0) } ?? []
        if let raw = d.stringArray(forKey: key("share")) { shared = Set(raw.compactMap(PartyKind.init)) } else { shared = Set(PartyKind.allCases) }
        showExactWeight = d.bool(forKey: key("exactKg"))
        notify = d.object(forKey: key("notify")) as? Bool ?? true
        unread = d.integer(forKey: key("unread"))
        lastPoll = .distantPast
    }

    private func persist() {
        let e = JSONEncoder()
        d.set(party.flatMap { try? e.encode($0) }, forKey: key("party"))
        d.set(try? e.encode(events), forKey: key("events"))
        d.set(try? e.encode(pending), forKey: key("pending"))
        d.set(unread, forKey: key("unread"))
    }

    private var lastTS: Double { events.last?.ts ?? (party?.members.first { $0.id == myMemberID }?.joined ?? 0) }

    // MARK: Identidade

    private var me: ProfileInfo { ProfileRegistry.shared.active }
    private var myMemberID: String {
        let uid = d.string(forKey: "fb.uid") ?? ""
        let p = profileID.filter { $0.isLetter || $0.isNumber }
        return "m_" + (uid + "_" + p).filter { $0.isLetter || $0.isNumber || $0 == "_" }
    }
    func isMe(_ memberID: String) -> Bool { memberID == myMemberID }

    // MARK: Criar / entrar / sair

    func create(name: String) async throws {
        _ = try await api.token()
        let code = Self.newCode()
        let now = Date.now.timeIntervalSince1970
        let uid = await api.uid ?? ""
        _ = try await api.request("POST", "parties", query: "documentId=\(code)", body: ["fields": [
            "name": FS.s(name), "owner": FS.s(uid),
            "members": FS.map([myMemberID: memberValue(now)]),
        ]])
        party = Party(code: code, name: name, owner: uid,
                      members: [PartyMember(id: myMemberID, name: me.name, emoji: me.emoji, joined: now)])
        events = []; unread = 0
        persist()
    }

    func join(code raw: String) async throws {
        let code = raw.uppercased().filter { $0.isLetter || $0.isNumber }
        _ = try await api.token()
        var p = try await fetchParty(code)
        if !p.members.contains(where: { $0.id == myMemberID }) {
            guard p.members.count < Party.maxMembers else { throw PartyError.full }
            let now = Date.now.timeIntervalSince1970
            _ = try await api.request("PATCH", "parties/\(code)", query: "updateMask.fieldPaths=members.\(myMemberID)",
                                      body: ["fields": ["members": FS.map([myMemberID: memberValue(now)])]])
            p.members.append(PartyMember(id: myMemberID, name: me.name, emoji: me.emoji, joined: now))
        }
        party = p
        events = []; unread = 0
        persist()
        await refresh(force: true)
    }

    func leave() async {
        if let code = party?.code {
            // updateMask sem o campo no corpo = remove a chave
            _ = try? await api.request("PATCH", "parties/\(code)", query: "updateMask.fieldPaths=members.\(myMemberID)",
                                       body: ["fields": [:] as [String: Any]])
        }
        party = nil; events = []; pending = []; unread = 0
        persist()
    }

    func markRead() { if unread != 0 { unread = 0; persist() } }

    private func memberValue(_ joined: Double) -> [String: Any] {
        FS.map(["name": FS.s(me.name), "emoji": FS.s(me.emoji), "joined": FS.n(joined)])
    }

    private func fetchParty(_ code: String) async throws -> Party {
        let doc = try await api.request("GET", "parties/\(code)")
        let f = FS.fields(doc)
        let membersF = ((f["members"] as? [String: Any])?["mapValue"] as? [String: Any])?["fields"] as? [String: Any] ?? [:]
        let members = membersF.compactMap { id, v -> PartyMember? in
            let m = ((v as? [String: Any])?["mapValue"] as? [String: Any])?["fields"] as? [String: Any]
            return PartyMember(id: id, name: FS.str(m, "name"), emoji: FS.str(m, "emoji"), joined: FS.num(m, "joined"))
        }.sorted { $0.joined < $1.joined }
        return Party(code: code, name: FS.str(f, "name"), owner: FS.str(f, "owner"), members: members)
    }

    private static func newCode() -> String {
        let chars = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")     // sem 0/O/1/I
        return String((0..<6).map { _ in chars.randomElement()! })
    }

    // MARK: Publicar

    /// Registra uma atividade deste perfil (se ele estiver numa party e compartilhar esse tipo).
    func post(_ kind: PartyKind, _ text: String, value: Double = 0) {
        guard party != nil, shared.contains(kind) else { return }
        let e = PartyEvent(id: UUID().uuidString, member: myMemberID, name: me.name, emoji: me.emoji,
                           kind: kind, text: text, value: value, ts: Date.now.timeIntervalSince1970)
        pending.append(e)
        insertSorted([e])
        persist()
        Task { await flush() }
    }

    private func flush() async {
        guard let code = party?.code, !pending.isEmpty else { return }
        let uid = await api.uid ?? ""
        var sent = Set<String>()
        for e in pending {
            do {
                _ = try await api.request("POST", "parties/\(code)/events", query: "documentId=\(e.id)", body: ["fields": [
                    "uid": FS.s(uid), "member": FS.s(e.member), "name": FS.s(e.name), "emoji": FS.s(e.emoji),
                    "kind": FS.s(e.kind.rawValue), "text": FS.s(e.text), "value": FS.n(e.value), "ts": FS.n(e.ts),
                ]])
                sent.insert(e.id)
            } catch PartyError.http(409, _) {
                sent.insert(e.id)              // já enviado antes
            } catch {
                lastError = error.localizedDescription
                break                          // sem rede: tenta de novo na próxima sincronização
            }
        }
        if !sent.isEmpty { pending.removeAll { sent.contains($0.id) }; persist() }
    }

    // MARK: Sincronizar

    /// Busca só os eventos novos (ts > último conhecido). Barato o bastante para rodar a cada minuto.
    func refresh(force: Bool = false) async {
        guard let code = party?.code, FirebaseConfig.isConfigured, !syncing else { return }
        guard force || Date.now.timeIntervalSince(lastPoll) > 20 else { return }
        syncing = true; lastPoll = .now
        defer { syncing = false }
        await flush()
        do {
            if let p = try? await fetchParty(code), p != party { party = p }
            let docs = try await api.runQuery("parties/\(code)", [
                "from": [["collectionId": "events"]],
                "where": ["fieldFilter": ["field": ["fieldPath": "ts"], "op": "GREATER_THAN", "value": FS.n(lastTS)]],
                "orderBy": [["field": ["fieldPath": "ts"], "direction": "ASCENDING"]],
                "limit": 300,
            ])
            let known = Set(events.map(\.id))
            let new = docs.compactMap { doc -> PartyEvent? in
                let f = FS.fields(doc)
                guard let kind = PartyKind(rawValue: FS.str(f, "kind")) else { return nil }
                return PartyEvent(id: FS.docID(doc), member: FS.str(f, "member"), name: FS.str(f, "name"),
                                  emoji: FS.str(f, "emoji"), kind: kind, text: FS.str(f, "text"),
                                  value: FS.num(f, "value"), ts: FS.num(f, "ts"))
            }.filter { !known.contains($0.id) }
            if !new.isEmpty {
                insertSorted(new)
                let others = new.filter { $0.member != myMemberID }
                unread += others.count
                if notify { notifyLocal(others) }
            }
            lastError = nil
            persist()
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func insertSorted(_ new: [PartyEvent]) {
        events.append(contentsOf: new)
        events.sort { $0.ts < $1.ts }
        if events.count > 1500 { events.removeFirst(events.count - 1500) }
    }

    /// Sincroniza a cada minuto enquanto o app está aberto.
    func startPolling() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh(force: true)
                try? await Task.sleep(for: .seconds(60))
            }
        }
    }
    func stopPolling() { pollTask?.cancel(); pollTask = nil }

    private func notifyLocal(_ list: [PartyEvent]) {
        guard !list.isEmpty else { return }
        let c = UNUserNotificationCenter.current()
        c.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        let batch = list.count > 3 ? [list.last!] : list
        for e in batch {
            let n = UNMutableNotificationContent()
            n.title = "\(e.emoji) \(e.name) · \(party?.name ?? "Party")"
            n.body = list.count > 3 ? "\(e.text) (+\(list.count - 1) novidades)" : e.text
            n.sound = .default
            c.add(UNNotificationRequest(identifier: "party-\(e.id)", content: n, trigger: nil))
        }
    }

    // MARK: Estatísticas

    struct MemberStats: Identifiable {
        let member: PartyMember
        var points = 0, activeDays = 0, streak = 0
        var counts: [PartyKind: Int] = [:]
        var weightDelta = 0.0, workoutMinutes = 0.0, avgMood: Double?
        var id: String { member.id }
    }

    /// Estatísticas da party num período (uma passada pelos eventos).
    func stats(since: Date) -> [MemberStats] {
        guard let party else { return [] }
        let cal = Calendar.current
        let t0 = since.timeIntervalSince1970
        var byMember = Dictionary(uniqueKeysWithValues: party.members.map { ($0.id, MemberStats(member: $0)) })
        var days: [String: Set<Date>] = [:], allDays: [String: Set<Date>] = [:]
        var moodSum: [String: (Double, Int)] = [:]
        for e in events {
            let day = cal.startOfDay(for: e.date)
            allDays[e.member, default: []].insert(day)
            guard e.ts >= t0, var s = byMember[e.member] else { continue }
            s.counts[e.kind, default: 0] += 1
            s.points += e.kind.points
            days[e.member, default: []].insert(day)
            switch e.kind {
            case .weight: s.weightDelta += e.value
            case .workout: s.workoutMinutes += e.value
            case .mood: let m = moodSum[e.member] ?? (0, 0); moodSum[e.member] = (m.0 + e.value, m.1 + 1)
            default: break
            }
            byMember[e.member] = s
        }
        return byMember.values.map { s in
            var s = s
            s.activeDays = days[s.id]?.count ?? 0
            s.points += s.activeDays * 3            // aparecer todo dia vale mais que fazer muito num dia só
            s.streak = HabitMath.streaks(allDays[s.id] ?? []).current
            if let m = moodSum[s.id], m.1 > 0 { s.avgMood = m.0 / Double(m.1) }
            return s
        }.sorted { $0.points > $1.points }
    }
}
