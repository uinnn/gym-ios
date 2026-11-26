import SwiftUI
import SwiftData

// MARK: - Personal trainer (lado do aluno): convites, permissões e caixa de recados/treinos

struct TrainerLink: Identifiable, Hashable {
    let id: String          // uid do personal
    var name: String
    var email: String
    var scopes: [String: Bool]
}

struct InboxMessage: Identifiable, Hashable {
    let id: String
    var type: String        // "note" | "routine"
    var fromName: String
    var text: String
    var about: String
    var name: String
    var note: String
    var items: [RoutineItem]
    var created: Date
    var read: Bool
    var imported: Bool
}

@Observable
@MainActor
final class TrainerService {
    static let shared = TrainerService()

    static let scopes: [(key: String, title: String, detail: String, icon: String)] = [
        ("body", "Corpo", "Peso, medidas, composição e perfil", "figure.stand"),
        ("food", "Alimentação", "Refeições, água, jejum e nutrientes", "fork.knife"),
        ("training", "Treinos", "Treinos, rotinas e cardio", "dumbbell.fill"),
        ("mind", "Mente e sono", "Humor, sono, práticas, gratidão e hábitos", "brain.head.profile"),
    ]
    static let defaultScopes: [String: Bool] = ["body": true, "food": true, "training": true, "mind": false]

    var trainers: [TrainerLink] = []
    var inbox: [InboxMessage] = []
    var loading = false
    var error: String?
    var lastCode: (code: String, expires: Date)?
    var unread: Int { inbox.filter { !$0.read }.count }

    private var base: String { "https://firestore.googleapis.com/v1/projects/\(FirebaseConfig.projectID)/databases/(default)/documents" }
    private var uid: String? { SyncAuth.shared.uid }

    // MARK: REST

    private func call(_ method: String, _ path: String, query: String = "", body: [String: Any]? = nil) async throws -> [String: Any] {
        let t = try await SyncAuth.shared.token()
        var r = URLRequest(url: URL(string: path.hasPrefix("http") ? path : "\(base)/\(path)\(query.isEmpty ? "" : "?" + query)")!)
        r.httpMethod = method
        r.timeoutInterval = 20
        r.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization")
        if let body {
            r.setValue("application/json", forHTTPHeaderField: "Content-Type")
            r.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, resp): (Data, URLResponse)
        do { (data, resp) = try await URLSession.shared.data(for: r) } catch { throw SyncAuthError.message("Sem conexão com a internet.") }
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        let obj = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        guard (200..<300).contains(code) else {
            if code == 403 { throw SyncAuthError.message("Sem permissão.") }
            throw SyncAuthError.message(((obj["error"] as? [String: Any])?["message"] as? String) ?? "Erro \(code)")
        }
        return obj
    }

    /// Converte um valor do Firestore REST em tipos simples (String, Double, Bool, Date, [Any], [String: Any]).
    static func plain(_ v: Any?) -> Any? {
        guard let v = v as? [String: Any] else { return nil }
        if let s = v["stringValue"] as? String { return s }
        if let d = v["doubleValue"] as? Double { return d }
        if let i = v["integerValue"] as? String { return Double(i) }
        if let b = v["booleanValue"] as? Bool { return b }
        if let t = v["timestampValue"] as? String { return ISO8601DateFormatter.withFraction.date(from: t) ?? ISO8601DateFormatter().date(from: t) }
        if let a = (v["arrayValue"] as? [String: Any])?["values"] as? [Any] { return a.compactMap(plain) }
        if v["arrayValue"] != nil { return [Any]() }
        if let m = (v["mapValue"] as? [String: Any])?["fields"] as? [String: Any] { return m.compactMapValues(plain) }
        if v["mapValue"] != nil { return [String: Any]() }
        return nil
    }

    private static func boolMap(_ m: [String: Bool]) -> [String: Any] {
        ["mapValue": ["fields": m.mapValues { ["booleanValue": $0] }]]
    }

    // MARK: Leitura

    /// Busca personais e recados. Sem conta ou sem internet, não faz nada.
    func refresh() async {
        guard SyncAuth.shared.isSignedIn, let uid else { return }
        loading = true
        defer { loading = false }
        do {
            async let t = call("GET", "users/\(uid)/trainers", query: "pageSize=50")
            async let i = call("GET", "users/\(uid)/inbox", query: "pageSize=100")
            let (tr, ib) = try await (t, i)
            trainers = ((tr["documents"] as? [[String: Any]]) ?? []).compactMap { d in
                let f = (d["fields"] as? [String: Any] ?? [:]).compactMapValues(Self.plain)
                guard let id = (d["name"] as? String)?.split(separator: "/").last.map(String.init) else { return nil }
                return TrainerLink(id: id, name: f["name"] as? String ?? "Personal", email: f["email"] as? String ?? "",
                                   scopes: (f["scopes"] as? [String: Any] ?? [:]).compactMapValues { $0 as? Bool })
            }
            inbox = ((ib["documents"] as? [[String: Any]]) ?? []).compactMap(parseMessage).sorted { $0.created > $1.created }
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func parseMessage(_ d: [String: Any]) -> InboxMessage? {
        let f = (d["fields"] as? [String: Any] ?? [:]).compactMapValues(Self.plain)
        guard let id = (d["name"] as? String)?.split(separator: "/").last.map(String.init) else { return nil }
        let items: [RoutineItem] = (f["items"] as? [Any] ?? []).compactMap { any in
            guard let m = any as? [String: Any], let ex = m["exerciseID"] as? String, ExerciseCatalog.byID[ex] != nil else { return nil }
            func int(_ k: String, _ def: Int) -> Int { (m[k] as? Double).map { Int($0) } ?? def }
            let lo = max(1, int("repsMin", 8))
            return RoutineItem(exerciseID: ex, sets: max(1, int("sets", 3)), repsMin: lo, repsMax: max(lo, int("repsMax", lo)),
                               restSeconds: max(0, int("restSeconds", 90)))
        }
        return InboxMessage(id: id, type: f["type"] as? String ?? "note", fromName: f["fromName"] as? String ?? "Personal",
                            text: f["text"] as? String ?? "", about: f["about"] as? String ?? "", name: f["name"] as? String ?? "Treino",
                            note: f["note"] as? String ?? "", items: items, created: f["createdAt"] as? Date ?? .now,
                            read: f["read"] as? Bool ?? false, imported: f["imported"] as? Bool ?? false)
    }

    // MARK: Ações

    /// Cria um código de uso único (24 h) com as categorias escolhidas.
    func createInvite(scopes: [String: Bool], studentName: String) async throws -> String {
        guard let uid else { throw SyncAuthError.message("Entre na sua conta em Sincronização.") }
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        var rng = SystemRandomNumberGenerator()
        let code = String((0..<8).map { _ in alphabet[Int(rng.next(upperBound: UInt32(alphabet.count)))] })
        let expires = Date.now.addingTimeInterval(24 * 3600)
        _ = try await call("POST", "invites", query: "documentId=\(code)", body: ["fields": [
            "student": ["stringValue": uid],
            "studentName": ["stringValue": studentName],
            "scopes": Self.boolMap(scopes),
            "expires": ["doubleValue": (expires.timeIntervalSince1970 * 1000).rounded()],
            "createdAt": ["timestampValue": ISO8601DateFormatter().string(from: .now)],
        ]])
        lastCode = (code, expires)
        return code
    }

    func updateScopes(_ t: TrainerLink, _ scopes: [String: Bool]) async throws {
        guard let uid else { return }
        _ = try await call("PATCH", "users/\(uid)/trainers/\(t.id)", query: "updateMask.fieldPaths=scopes",
                           body: ["fields": ["scopes": Self.boolMap(scopes)]])
        if let i = trainers.firstIndex(of: t) { trainers[i].scopes = scopes }
    }

    /// Remove o acesso do personal (some dos dois lados).
    func remove(_ t: TrainerLink) async throws {
        guard let uid else { return }
        let root = "projects/\(FirebaseConfig.projectID)/databases/(default)/documents"
        _ = try await call("POST", "\(base):commit", body: ["writes": [
            ["delete": "\(root)/users/\(uid)/trainers/\(t.id)"],
            ["delete": "\(root)/trainers/\(t.id)/students/\(uid)"],
        ]])
        trainers.removeAll { $0.id == t.id }
    }

    func markRead(_ m: InboxMessage, imported: Bool = false) async {
        guard let uid else { return }
        var fields: [String: Any] = ["read": ["booleanValue": true]]
        var mask = "updateMask.fieldPaths=read"
        if imported { fields["imported"] = ["booleanValue": true]; mask += "&updateMask.fieldPaths=imported" }
        _ = try? await call("PATCH", "users/\(uid)/inbox/\(m.id)", query: mask, body: ["fields": fields])
        if let i = inbox.firstIndex(where: { $0.id == m.id }) { inbox[i].read = true; if imported { inbox[i].imported = true } }
    }

    func delete(_ m: InboxMessage) async {
        guard let uid else { return }
        _ = try? await call("DELETE", "users/\(uid)/inbox/\(m.id)")
        inbox.removeAll { $0.id == m.id }
    }

    /// Adiciona o treino recebido às rotinas do app (e ele sincroniza de volta).
    func importRoutine(_ m: InboxMessage, into context: ModelContext) async {
        let order = ((try? context.fetch(FetchDescriptor<WorkoutRoutine>())) ?? []).map(\.order).max() ?? 0
        let r = WorkoutRoutine(name: m.name, icon: "person.fill.checkmark", order: order + 1, items: m.items)
        context.insert(r)
        try? context.save()
        await markRead(m, imported: true)
    }
}

extension ISO8601DateFormatter {
    static let withFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}

// MARK: - Tela

struct TrainerView: View {
    @Environment(\.modelContext) private var context
    @State private var service = TrainerService.shared
    @State private var sync = SyncEngine.shared
    @State private var inviteScopes = TrainerService.defaultScopes
    @State private var creating = false
    @State private var editing: TrainerLink?
    @State private var removing: TrainerLink?
    @State private var toast: String?

    var body: some View {
        List {
            if !sync.signedIn {
                Section {
                    Label("Para conectar um personal trainer, entre na sua conta de sincronização (a mesma do site).", systemImage: "person.crop.circle.badge.exclamationmark")
                    NavigationLink("Abrir Sincronização") { SyncSettingsView() }
                }
            } else {
                inboxSection
                trainersSection
                inviteSection
                Section {
                    Text("O personal só vê as categorias que você liberar, e só pelo site. Ele não edita nem apaga seus registros. Os dados aparecem para ele conforme o app sincroniza.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Personal trainer")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await service.refresh() }
        .task { await service.refresh() }
        .sheet(item: $editing) { t in ScopesSheet(trainer: t) }
        .confirmationDialog("Remover o acesso de \(removing?.name ?? "")?", isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }),
                            titleVisibility: .visible) {
            Button("Remover acesso", role: .destructive) {
                if let t = removing { Task { try? await service.remove(t); toast = "Acesso removido." } }
            }
        } message: { Text("Ele deixa de ver seus dados na hora. Para voltar, gere um novo código.") }
        .overlay(alignment: .bottom) {
            if let toast {
                Text(toast).font(.subheadline.bold()).padding(.horizontal, 16).padding(.vertical, 10)
                    .background(.ultraThickMaterial, in: Capsule()).padding(.bottom, 20)
                    .task { try? await Task.sleep(for: .seconds(2.5)); withAnimation { self.toast = nil } }
            }
        }
    }

    @ViewBuilder private var inboxSection: some View {
        Section {
            if service.inbox.isEmpty {
                Text(service.loading ? "Buscando…" : "Nenhum recado ou treino recebido ainda.").font(.subheadline).foregroundStyle(.secondary)
            }
            ForEach(service.inbox) { m in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Image(systemName: m.type == "routine" ? "dumbbell.fill" : "envelope.fill").foregroundStyle(Theme.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(m.type == "routine" ? m.name : (m.about.isEmpty ? "Recado" : m.about)).font(.subheadline.bold())
                            Text("\(m.fromName) · \(m.created.formatted(.relative(presentation: .named)))").font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if !m.read { Text("novo").font(.caption2.bold()).foregroundStyle(.white).padding(.horizontal, 6).padding(.vertical, 2).background(Theme.accent, in: Capsule()) }
                    }
                    if m.type == "note" {
                        Text(m.text).font(.callout).textSelection(.enabled)
                    } else {
                        VStack(alignment: .leading, spacing: 3) {
                            ForEach(m.items) { i in
                                Text("• \(i.exercise?.name ?? i.exerciseID): \(i.sets)× \(i.repsMin)\(i.repsMax != i.repsMin ? "–\(i.repsMax)" : "") · \(i.restSeconds) s")
                                    .font(.caption)
                            }
                            if !m.note.isEmpty { Text("📝 \(m.note)").font(.caption).foregroundStyle(.secondary) }
                        }
                        if m.imported {
                            Label("Adicionado às suas rotinas", systemImage: "checkmark.circle.fill").font(.caption.bold()).foregroundStyle(Theme.good)
                        } else {
                            Button {
                                Task { await service.importRoutine(m, into: context); toast = "\"\(m.name)\" está nas suas rotinas." }
                            } label: { Label("Adicionar às minhas rotinas", systemImage: "plus.circle.fill").font(.subheadline.bold()) }
                            .buttonStyle(.borderedProminent).tint(Theme.accent)
                        }
                    }
                }
                .padding(.vertical, 4)
                .onAppear { if m.type == "note" && !m.read { Task { await service.markRead(m) } } }
                .swipeActions { Button("Apagar", role: .destructive) { Task { await service.delete(m) } } }
            }
        } header: {
            Text("Recados e treinos (\(service.unread) novo(s))")
        }
    }

    @ViewBuilder private var trainersSection: some View {
        Section("Quem tem acesso") {
            if service.trainers.isEmpty { Text("Nenhum personal conectado.").font(.subheadline).foregroundStyle(.secondary) }
            ForEach(service.trainers) { t in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "person.crop.circle.fill").font(.title2).foregroundStyle(Theme.accent)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(t.name).font(.subheadline.bold())
                            if !t.email.isEmpty { Text(t.email).font(.caption2).foregroundStyle(.secondary) }
                        }
                    }
                    Text("Vê: " + (TrainerService.scopes.filter { t.scopes[$0.key] == true }.map(\.title).joined(separator: ", ").nilIfEmpty ?? "nada"))
                        .font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Button("Permissões") { editing = t }.buttonStyle(.bordered)
                        Button("Remover", role: .destructive) { removing = t }.buttonStyle(.bordered)
                    }
                    .font(.caption.bold())
                }
                .padding(.vertical, 2)
            }
        }
    }

    @ViewBuilder private var inviteSection: some View {
        Section {
            ForEach(TrainerService.scopes, id: \.key) { s in
                Toggle(isOn: Binding(get: { inviteScopes[s.key] ?? false }, set: { inviteScopes[s.key] = $0 })) {
                    Label { VStack(alignment: .leading) { Text(s.title); Text(s.detail).font(.caption2).foregroundStyle(.secondary) } } icon: { Image(systemName: s.icon) }
                }
            }
            Button {
                Task {
                    creating = true
                    defer { creating = false }
                    do {
                        _ = try await service.createInvite(scopes: inviteScopes, studentName: ProfileRegistry.shared.profiles.first { $0.id == sync.profileID }?.name ?? "Aluno")
                    } catch { service.error = error.localizedDescription }
                }
            } label: {
                HStack { Label("Gerar código para o personal", systemImage: "key.fill").bold(); Spacer(); if creating { ProgressView() } }
            }
            .disabled(creating || !inviteScopes.values.contains(true))
            if let c = service.lastCode, c.expires > .now {
                VStack(spacing: 8) {
                    Text(c.code).font(.system(size: 34, weight: .heavy, design: .monospaced)).tracking(4).foregroundStyle(Theme.gradient)
                        .textSelection(.enabled)
                    Text("Vale até \(c.expires.formatted(date: .omitted, time: .shortened)) de \(c.expires.formatted(.dateTime.day().month())) · uso único").font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Button { UIPasteboard.general.string = c.code; toast = "Código copiado." } label: { Label("Copiar", systemImage: "doc.on.doc") }
                        ShareLink(item: "Meu código do Gym para você me acompanhar: \(c.code)\nUse em \(FirebaseConfig.projectID).web.app → Alunos → Adicionar aluno (vale 24 h).") {
                            Label("Compartilhar", systemImage: "square.and.arrow.up")
                        }
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            if let e = service.error { Label(e, systemImage: "exclamationmark.triangle.fill").font(.caption).foregroundStyle(.orange) }
        } header: { Text("Convidar personal") } footer: {
            Text("O personal digita o código no site, em Alunos → Adicionar aluno. Você pode mudar as permissões ou remover o acesso quando quiser.")
        }
    }
}

private struct ScopesSheet: View {
    let trainer: TrainerLink
    @Environment(\.dismiss) private var dismiss
    @State private var scopes: [String: Bool] = [:]
    @State private var saving = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(TrainerService.scopes, id: \.key) { s in
                        Toggle(isOn: Binding(get: { scopes[s.key] ?? false }, set: { scopes[s.key] = $0 })) {
                            Label { VStack(alignment: .leading) { Text(s.title); Text(s.detail).font(.caption2).foregroundStyle(.secondary) } } icon: { Image(systemName: s.icon) }
                        }
                    }
                } footer: { Text("Vale na hora: o que você desligar some do site do personal.") }
            }
            .navigationTitle(trainer.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        Task { saving = true; try? await TrainerService.shared.updateScopes(trainer, scopes); dismiss() }
                    }
                    .bold().disabled(saving)
                }
            }
            .onAppear { scopes = trainer.scopes }
        }
    }
}

extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
