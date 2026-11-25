import SwiftUI
import SwiftData
import AuthenticationServices

// MARK: - Botão ao lado de cada registro (modo manual)

/// Mostra o estado de sincronização e, no modo manual, envia só aquele registro.
struct SyncButton<M: Syncable>: View {
    let item: M
    @State private var engine = SyncEngine.shared
    @State private var sending = false

    var body: some View {
        if engine.mode != .off && engine.signedIn && engine.profileID == ProfileRegistry.shared.activeID {
            Group {
                if sending {
                    ProgressView().controlSize(.mini)
                } else if item.isSynced {
                    Image(systemName: "checkmark.icloud.fill").foregroundStyle(Theme.good.opacity(0.8))
                } else if engine.mode == .manual {
                    Button {
                        sending = true
                        Task { await engine.send([item]); sending = false }
                    } label: {
                        Image(systemName: "icloud.and.arrow.up").foregroundStyle(Theme.accent)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Enviar para o site")
                } else {
                    Image(systemName: "icloud.slash").foregroundStyle(.secondary)
                        .accessibilityLabel("Aguardando internet")
                }
            }
            .font(.caption)
            .frame(width: 22)
        }
    }
}

// MARK: - Aviso de alterações vindas do site (modo manual)

struct SyncIncomingModifier: ViewModifier {
    @State private var engine = SyncEngine.shared
    @State private var showDetail = false

    func body(content: Content) -> some View {
        content
            .alert("Alterações feitas no site",
                   isPresented: Binding(get: { !engine.incoming.isEmpty && !showDetail }, set: { if !$0 && !showDetail { engine.discardIncoming() } })) {
                Button("Aplicar") { engine.apply(engine.incoming) }
                Button("Ver detalhes") { showDetail = true }
                Button("Agora não", role: .cancel) { engine.discardIncoming() }
            } message: {
                Text(summary)
            }
            .sheet(isPresented: $showDetail) { IncomingSheet { showDetail = false } }
    }

    private var summary: String {
        let g = Dictionary(grouping: engine.incoming, by: \.collection)
        let parts = g.map { "\($0.value.count) em \(SyncKind.label($0.key))" }.sorted()
        return "Há \(engine.incoming.count) alteração(ões): " + parts.joined(separator: ", ") + ". Aplicar neste iPhone?"
    }
}

private struct IncomingSheet: View {
    var close: () -> Void
    @State private var engine = SyncEngine.shared

    var body: some View {
        NavigationStack {
            List {
                ForEach(Dictionary(grouping: engine.incoming, by: \.collection).sorted { $0.key < $1.key }, id: \.key) { c, list in
                    Section("\(SyncKind.label(c)) (\(list.count))") {
                        ForEach(list) { r in
                            HStack {
                                Image(systemName: r.deleted ? "trash" : "arrow.down.circle")
                                    .foregroundStyle(r.deleted ? Theme.danger : Theme.accent)
                                Text(describe(r)).font(.subheadline)
                                Spacer()
                                Text(Date(timeIntervalSince1970: r.updated / 1000), format: .relative(presentation: .named))
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Do site")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Agora não") { engine.discardIncoming(); close() } }
                ToolbarItem(placement: .confirmationAction) { Button("Aplicar tudo") { engine.apply(engine.incoming); close() }.bold() }
            }
        }
    }

    private func describe(_ r: RemoteChange) -> String {
        if r.deleted { return "Apagado no site" }
        let p = r.payload
        if let n = p["name"] as? String, !n.isEmpty {
            if let g = p["grams"] as? Double { return "\(n) · \(Int(g)) g" }
            return n
        }
        if let kg = p["kg"] as? Double { return "Pesagem \(kg.fmt(1)) kg" }
        if let ml = p["ml"] as? Double { return "Água \(Int(ml)) ml" }
        if let m = p["mood"] as? Int { return "Humor \(m)" }
        return "Registro atualizado"
    }
}

extension View {
    func syncIncomingPrompt() -> some View { modifier(SyncIncomingModifier()) }
}

// MARK: - Ajustes

struct SyncSettingsView: View {
    @Environment(\.webAuthenticationSession) private var webAuth
    @State private var engine = SyncEngine.shared
    @State private var email = ""
    @State private var password = ""
    @State private var creating = false
    @State private var working = false
    @State private var error: String?
    @State private var info: String?
    @State private var verified: Bool?
    @State private var confirmOut = false
    @State private var showPending = false
    @State private var confirmRestore = false

    var body: some View {
        Form {
            if engine.signedIn { accountSection; modeSection; statusSection; maintenanceSection } else { loginSection }
            Section {
                Label("O app continua funcionando 100% offline. Sem internet, nada é perdido: os registros esperam na fila e são enviados depois.", systemImage: "wifi.slash")
                Label("Só o perfil \"\(profileName)\" deste iPhone sincroniza com o site.", systemImage: "person.fill")
                Label("Se o mesmo registro for editado no app e no site, vale a edição mais recente. Exclusões também sincronizam.", systemImage: "arrow.triangle.2.circlepath")
                Label("Fotos de progresso, rotas de GPS do cardio e dados do Apple Saúde ficam só no iPhone.", systemImage: "lock.fill")
            } header: { Text("Como funciona") }
            .font(.caption).foregroundStyle(.secondary)
        }
        .navigationTitle("Sincronização")
        .navigationBarTitleDisplayMode(.inline)
        .task { if engine.signedIn { verified = await SyncAuth.shared.emailVerified(); engine.refreshPending() } }
        .sheet(isPresented: $showPending) { PendingSheet() }
        .confirmationDialog("Baixar tudo da sua conta para este iPhone?", isPresented: $confirmRestore, titleVisibility: .visible) {
            Button("Restaurar") { Task { await engine.restoreAll() } }
        } message: {
            Text("Os registros da conta entram neste iPhone (o mais recente vence). Nada daqui é apagado.")
        }
        .alert("Restaurar seus dados?", isPresented: Binding(get: { engine.offerRestore }, set: { engine.offerRestore = $0 })) {
            Button("Restaurar agora") { Task { await engine.restoreAll() } }
            Button("Agora não", role: .cancel) {}
        } message: {
            Text("Este iPhone está sem registros. Quer baixar tudo o que está salvo na sua conta (pesagens, alimentação, treinos…)?")
        }
        .confirmationDialog("Sair da conta? Os dados continuam neste iPhone e no site.", isPresented: $confirmOut, titleVisibility: .visible) {
            Button("Sair", role: .destructive) { Task { await engine.signOut() } }
        }
    }

    private var profileName: String {
        ProfileRegistry.shared.profiles.first { $0.id == engine.profileID }?.name ?? ProfileRegistry.shared.active.name
    }

    // MARK: Entrar / criar conta

    private var loginSection: some View {
        Section {
            Button {
                Task { await google() }
            } label: {
                HStack {
                    Image(systemName: "g.circle.fill").font(.title3)
                    Text("Continuar com Google").bold()
                    Spacer()
                }
            }
            .disabled(working)
            Picker("", selection: $creating) {
                Text("Entrar").tag(false)
                Text("Criar conta").tag(true)
            }
            .pickerStyle(.segmented)
            TextField("E-mail", text: $email)
                .keyboardType(.emailAddress).textContentType(.username)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
            SecureField("Senha (mín. 6 caracteres)", text: $password)
                .textContentType(creating ? .newPassword : .password)
            Button {
                Task { await submit() }
            } label: {
                HStack {
                    Text(creating ? "Criar conta" : "Entrar").bold()
                    Spacer()
                    if working { ProgressView() }
                }
            }
            .disabled(working || email.isEmpty || password.count < 6)
            if !creating {
                Button("Esqueci a senha") {
                    Task {
                        do { try await SyncAuth.shared.resetPassword(email: email); info = "Enviamos um e-mail para redefinir a senha." }
                        catch { self.error = error.localizedDescription }
                    }
                }
                .font(.caption).disabled(email.isEmpty)
            }
            if let error { Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange).font(.caption) }
            if let info { Label(info, systemImage: "envelope.fill").foregroundStyle(Theme.accent).font(.caption) }
        } header: {
            Text("Conta")
        } footer: {
            Text("A mesma conta é usada para entrar no site. O login com Google abre o seu site (\(FirebaseConfig.projectID).web.app), que precisa estar publicado.")
        }
    }

    private func google() async {
        working = true; error = nil; info = nil
        defer { working = false }
        do {
            let url = URL(string: "https://\(FirebaseConfig.projectID).web.app/app-login.html")!
            let cb = try await webAuth.authenticate(using: url, callbackURLScheme: "gymapp")
            guard let token = URLComponents(url: cb, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "refresh" })?.value else {
                error = "O site não devolveu o login."; return
            }
            try await SyncAuth.shared.signIn(refreshToken: token)
            engine.didSignIn()
            verified = true
        } catch let e as ASWebAuthenticationSessionError where e.code == .canceledLogin {
            return
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func submit() async {
        working = true; error = nil; info = nil
        defer { working = false }
        do {
            if creating {
                try await SyncAuth.shared.signUp(email: email.trimmingCharacters(in: .whitespaces), password: password)
                info = "Conta criada! Enviamos um e-mail de verificação."
            } else {
                try await SyncAuth.shared.signIn(email: email.trimmingCharacters(in: .whitespaces), password: password)
            }
            password = ""
            engine.didSignIn()
            verified = await SyncAuth.shared.emailVerified()
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: Conta conectada

    private var accountSection: some View {
        Section("Conta") {
            LabeledContent("E-mail", value: engine.email ?? "—")
            if verified == false {
                VStack(alignment: .leading, spacing: 6) {
                    Label("E-mail ainda não verificado", systemImage: "envelope.badge").foregroundStyle(.orange).font(.subheadline)
                    Text("Verifique para depois poder entrar também com o Google na mesma conta.").font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Button("Reenviar e-mail") { Task { try? await SyncAuth.shared.sendVerification(); info = "E-mail reenviado." } }
                        Button("Já verifiquei") { Task { verified = await SyncAuth.shared.emailVerified() } }
                    }
                    .font(.caption).buttonStyle(.bordered)
                }
            }
            if let info { Text(info).font(.caption).foregroundStyle(Theme.accent) }
            Button("Sair da conta", role: .destructive) { confirmOut = true }
        }
    }

    private var modeSection: some View {
        Section {
            Picker("Sincronização", selection: Binding(get: { engine.mode }, set: { new in
                let wasOff = engine.mode == .off
                engine.mode = new
                if wasOff && new != .off && engine.lastSync == nil { Task { await engine.uploadEverything() } }
            })) {
                ForEach(SyncMode.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            switch engine.mode {
            case .auto:
                Text("Cada pesagem, água, refeição, treino e os outros registros são enviados sozinhos quando houver internet. Ao abrir o app, as mudanças feitas no site entram automaticamente.")
            case .manual:
                Text("Nada é enviado sozinho: toque na nuvem ao lado de cada registro, ou em \"Enviar tudo\". Ao abrir o app, se houver mudanças do site, ele pergunta antes de aplicar.")
            case .off:
                Text("Nada é enviado nem recebido. O app funciona normalmente, só neste iPhone.")
            }
        } header: { Text("Modo") }
        .font(.caption)
    }

    private var maintenanceSection: some View {
        Section {
            NavigationLink { SyncHealthView() } label: {
                Label("Verificar sincronização", systemImage: "stethoscope")
            }
            Button { confirmRestore = true } label: {
                Label("Restaurar tudo da minha conta", systemImage: "arrow.down.to.line.circle")
            }
            .disabled(engine.busy || !engine.online)
        } header: { Text("Manutenção") } footer: {
            Text("Use \"Restaurar\" num iPhone novo ou se algo sumiu. \"Verificar\" compara este iPhone com a conta e corrige as diferenças.")
        }
    }

    private var statusSection: some View {
        Section {
            HStack {
                Label(engine.online ? "Online" : "Sem internet", systemImage: engine.online ? "wifi" : "wifi.slash")
                    .foregroundStyle(engine.online ? Theme.good : .orange)
                Spacer()
                if let last = engine.lastSync {
                    Text("Última: \(last.formatted(.relative(presentation: .named)))").font(.caption).foregroundStyle(.secondary)
                }
            }
            Button { showPending = true } label: {
                LabeledContent("Pendentes de envio", value: "\(engine.pendingCount)")
            }
            .disabled(engine.pendingCount == 0)
            if let p = engine.progress {
                ProgressView(value: Double(p.done), total: Double(max(p.total, 1))) { Text("Enviando \(p.done) de \(p.total)").font(.caption) }
            }
            Button {
                Task { await engine.uploadPending() }
            } label: { Label("Enviar tudo que está pendente", systemImage: "icloud.and.arrow.up") }
            .disabled(engine.busy || engine.pendingCount == 0 || engine.mode == .off || !engine.online)
            Button {
                Task { await engine.pull() }
            } label: { Label("Buscar alterações do site agora", systemImage: "icloud.and.arrow.down") }
            .disabled(engine.busy || engine.mode == .off || !engine.online)
            Button {
                Task { await engine.uploadEverything() }
            } label: { Label("Reenviar todo o histórico", systemImage: "arrow.clockwise.icloud") }
            .disabled(engine.busy || engine.mode == .off || !engine.online)
            if engine.busy { HStack { ProgressView(); Text("Sincronizando…").font(.caption) } }
            if let s = engine.status { Text(s).font(.caption).foregroundStyle(.secondary) }
        } header: { Text("Estado") }
    }
}

private struct PendingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var engine = SyncEngine.shared
    @State private var groups: [(String, [any Syncable])] = []

    var body: some View {
        NavigationStack {
            List {
                if engine.pendingDeletes > 0 {
                    Section { Label("\(engine.pendingDeletes) exclusão(ões) esperando envio", systemImage: "trash") }
                }
                ForEach(groups, id: \.0) { label, items in
                    Section {
                        Button {
                            Task { await engine.send(items); reload() }
                        } label: { Label("Enviar \(items.count) de \(label)", systemImage: "icloud.and.arrow.up") }
                        .disabled(!engine.online || engine.busy)
                    } header: { Text(label) }
                }
            }
            .navigationTitle("Pendentes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("OK") { dismiss() } } }
            .onAppear(perform: reload)
        }
    }

    private func reload() { groups = engine.pendingItems() }
}


// MARK: - Saúde da sincronização

struct SyncHealthView: View {
    @State private var engine = SyncEngine.shared
    @State private var rows: [SyncEngine.HealthRow] = []
    @State private var loading = false
    @State private var fixing = false
    @State private var error: String?
    @State private var checkedAt: Date?

    private var problems: Int { rows.filter { !$0.ok }.count }

    var body: some View {
        List {
            Section {
                HStack(spacing: 14) {
                    Image(systemName: loading ? "hourglass" : rows.isEmpty ? "questionmark.circle" : problems == 0 ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(rows.isEmpty || loading ? Color.secondary : problems == 0 ? Theme.good : .orange)
                        .symbolEffect(.pulse, isActive: loading)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(loading ? "Comparando…" : rows.isEmpty ? "Ainda não verificado" : problems == 0 ? "Tudo sincronizado" : "\(problems) tipo(s) com diferenças")
                            .font(.headline)
                        if let checkedAt { Text("Verificado \(checkedAt.formatted(.relative(presentation: .named)))").font(.caption).foregroundStyle(.secondary) }
                    }
                }
                .padding(.vertical, 4)
                if let error { Label(error, systemImage: "wifi.exclamationmark").font(.caption).foregroundStyle(.orange) }
                if problems > 0 {
                    Button {
                        Task {
                            fixing = true
                            await engine.fixDifferences(rows)
                            fixing = false
                            await check()
                        }
                    } label: {
                        HStack {
                            Label("Corrigir diferenças", systemImage: "wand.and.stars").bold()
                            Spacer()
                            if fixing { ProgressView() }
                        }
                    }
                    .disabled(fixing || loading)
                }
            }
            if !rows.isEmpty {
                Section {
                    ForEach(rows) { r in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: r.ok ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                    .foregroundStyle(r.ok ? Theme.good : .orange)
                                Text(r.label).font(.subheadline.bold())
                                Spacer()
                                Text("iPhone \(r.local) · conta \(r.remote)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                            }
                            if !r.ok {
                                VStack(alignment: .leading, spacing: 2) {
                                    if !r.onlyLocal.isEmpty { Text("• \(r.onlyLocal.count) só neste iPhone (serão enviados)") }
                                    if !r.newerLocal.isEmpty { Text("• \(r.newerLocal.count) mais novos aqui (serão enviados)") }
                                    if r.onlyRemote > 0 { Text("• \(r.onlyRemote) só na conta (serão baixados)") }
                                    if r.newerRemote > 0 { Text("• \(r.newerRemote) mais novos na conta (serão baixados)") }
                                }
                                .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                } header: { Text("Por tipo de registro") } footer: {
                    Text("\"Corrigir\" segue a regra de sempre: a edição mais recente vence. Nada é apagado, a não ser exclusões feitas de propósito no app ou no site.")
                }
            }
        }
        .navigationTitle("Verificar sincronização")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { Button { Task { await check() } } label: { Image(systemName: "arrow.clockwise") }.disabled(loading) }
        .task { await check() }
        .refreshable { await check() }
    }

    private func check() async {
        loading = true; error = nil
        defer { loading = false }
        do { rows = try await engine.checkHealth(); checkedAt = .now }
        catch { self.error = error.localizedDescription }
    }
}
