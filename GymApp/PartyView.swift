import SwiftUI

struct PartyView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var service = PartyService.shared
    @State private var period = 0
    @State private var showSettings = false
    @State private var showChat = false
    @State private var showAchievements = false
    @State private var configured = FirebaseConfig.isConfigured

    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedBackground()
                Group {
                    if !configured { ServerSetupView { configured = FirebaseConfig.isConfigured } }
                    else if let party = service.party { content(party) }
                    else { PartyStartView() }
                }
            }
            .navigationTitle(service.party?.name ?? "Party")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("OK") { dismiss() } }
                if service.party != nil {
                    ToolbarItemGroup(placement: .primaryAction) {
                        Button { showChat = true } label: { Image(systemName: "bubble.left.and.bubble.right.fill") }
                        Button { showAchievements = true } label: { Image(systemName: "medal.fill") }
                        Button { showSettings = true } label: { Image(systemName: "slider.horizontal.3") }
                    }
                }
            }
            .sheet(isPresented: $showSettings) { PartySettingsView() }
            .sheet(isPresented: $showChat) { PartyChatView() }
            .sheet(isPresented: $showAchievements) { AchievementsView() }
            .task { await service.refresh(force: true); service.markRead() }
            .refreshable { await service.refresh(force: true) }
        }
    }

    private func content(_ party: Party) -> some View {
        let since = period == 0 ? Calendar.current.date(byAdding: .day, value: -7, to: .now)!
                                : Calendar.current.date(byAdding: .day, value: -30, to: .now)!
        let stats = service.stats(since: since)
        return ScrollView {
            VStack(spacing: 14) {
                inviteCard(party)
                Picker("", selection: $period) { Text("7 dias").tag(0); Text("30 dias").tag(1) }.pickerStyle(.segmented)
                totalsCard(stats)
                ChallengesCard(party: party, events: service.events)
                rankingCard(stats)
                DuelsCard(party: party, events: service.events)
                PartyFeedCard(events: service.events)
                if let err = service.lastError {
                    Text(err).font(.caption2).foregroundStyle(.secondary)
                }
            }
            .padding()
        }
    }

    private func inviteCard(_ party: Party) -> some View {
        Card {
            VStack(spacing: 10) {
                HStack(spacing: -8) {
                    ForEach(party.members) { m in
                        Text(m.emoji).font(.title2).frame(width: 42, height: 42)
                            .background(.ultraThinMaterial, in: Circle()).overlay(Circle().strokeBorder(.background, lineWidth: 2))
                    }
                }
                Text("\(party.members.count)/\(Party.maxMembers) membros").font(.caption).foregroundStyle(.secondary)
                HStack {
                    Text(party.code).font(.system(.title, design: .monospaced).bold()).kerning(4)
                    Button { UIPasteboard.general.string = party.code } label: { Image(systemName: "doc.on.doc") }
                }
                if party.members.count < Party.maxMembers {
                    ShareLink(item: "Entra na minha party \"\(party.name)\" no app Gym! Código: \(party.code)") {
                        Label("Convidar", systemImage: "person.badge.plus").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent).tint(Theme.accent)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func totalsCard(_ s: [PartyService.MemberStats]) -> some View {
        let workouts = s.map { $0.counts[.workout] ?? 0 }.reduce(0, +)
        let minutes = s.map(\.workoutMinutes).reduce(0, +)
        let lost = s.map { min(0, $0.weightDelta) }.reduce(0, +)
        let checkins = s.map { ($0.counts[.mood] ?? 0) + ($0.counts[.practice] ?? 0) }.reduce(0, +)
        let moods = s.compactMap(\.avgMood)
        return Card {
            VStack(alignment: .leading, spacing: 10) {
                Label("A party junta", systemImage: "person.3.fill").font(.headline)
                LazyVGrid(columns: [GridItem(), GridItem()], spacing: 10) {
                    tile("\(workouts)", "treinos", "dumbbell.fill")
                    tile("\(Int(minutes))", "min treinando", "timer")
                    tile(abs(lost).fmt(1) + " kg", "perdidos", "arrow.down.circle.fill")
                    tile("\(checkins)", "check-ins e práticas", "brain.head.profile")
                    if !moods.isEmpty {
                        let m = moods.reduce(0, +) / Double(moods.count)
                        tile(Mood.emoji(m) + " " + m.fmt(1), "humor médio", "face.smiling")
                    }
                    tile("\(s.map(\.activeDays).reduce(0, +))", "dias ativos (soma)", "calendar")
                }
            }
        }
    }

    private func tile(_ v: String, _ l: String, _ icon: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Image(systemName: icon).foregroundStyle(Theme.accent)
            Text(v).font(.title3.bold()).contentTransition(.numericText())
            Text(l).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10).background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
    }

    private func rankingCard(_ s: [PartyService.MemberStats]) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Label("Ranking de constância", systemImage: "trophy.fill").font(.headline)
                ForEach(Array(s.enumerated()), id: \.element.id) { i, m in
                    HStack(spacing: 10) {
                        Text(i < 3 ? ["🥇", "🥈", "🥉"][i] : "\(i + 1)º").frame(width: 28)
                        Text(m.member.emoji).font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(m.member.name + (service.isMe(m.id) ? " (você)" : "")).font(.subheadline.bold())
                            Text(detail(m)).font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if !service.isMe(m.id), canNudge(m.id) {
                            Button {
                                service.post(.nudge, "cutucou \(m.member.name): bora se mexer hoje? 👉", target: m.id)
                            } label: { Text("👉").font(.title3) }
                            .buttonStyle(.plain)
                        }
                        VStack(alignment: .trailing) {
                            Text("\(m.points)").font(.headline)
                            if m.streak > 0 { Text("\(m.streak)🔥").font(.caption2) }
                        }
                    }
                }
                Text("Pontos: treino 5 · pesagem, humor e prática 2 · refeição e sono 1 · +3 por dia ativo.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    /// Pode cutucar quem está há 2 dias sem atividade, no máximo uma vez por dia.
    private func canNudge(_ member: String) -> Bool {
        let now = Date.now.timeIntervalSince1970
        let lastActivity = service.events.last { $0.member == member && $0.kind.isActivity }?.ts ?? 0
        let lastNudge = service.events.last { $0.kind == .nudge && $0.target == member && service.isMe($0.member) }?.ts ?? 0
        return now - lastActivity > 2 * 86400 && now - lastNudge > 86400
    }

    private func detail(_ m: PartyService.MemberStats) -> String {
        var p = ["\(m.activeDays) dias ativos"]
        if let w = m.counts[.workout] { p.append("\(w) treinos") }
        if m.counts[.weight] != nil, abs(m.weightDelta) >= 0.05 { p.append(m.weightDelta.signed(1) + " kg") }
        return p.joined(separator: " · ")
    }

}

// MARK: - Sem party

struct PartyStartView: View {
    @State private var service = PartyService.shared
    @State private var name = ""
    @State private var code = ""
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        Form {
            Section {
                VStack(spacing: 8) {
                    Text("🎉").font(.system(size: 56))
                    Text("Treine junto").font(.title2.bold())
                    Text("Crie uma party com até 5 pessoas. Vocês veem as pesagens, refeições, treinos e check-ins uns dos outros, recebem avisos e disputam o ranking de constância.")
                        .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity).listRowBackground(Color.clear)
            }
            Section("Criar party") {
                TextField("Nome (ex.: Família Silva)", text: $name)
                Button("Criar") { run { try await service.create(name: name.trimmingCharacters(in: .whitespaces)) } }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || busy)
            }
            Section("Entrar com código") {
                TextField("Código de 6 letras", text: $code).textInputAutocapitalization(.characters).autocorrectionDisabled()
                Button("Entrar") { run { try await service.join(code: code) } }
                    .disabled(code.filter { $0.isLetter || $0.isNumber }.count != 6 || busy)
            }
            if busy { Section { ProgressView().frame(maxWidth: .infinity) } }
            if let error { Section { Text(error).foregroundStyle(Theme.danger) } }
        }
        .scrollContentBackground(.hidden)
    }

    private func run(_ op: @escaping () async throws -> Void) {
        busy = true; error = nil
        Task {
            do { try await op() } catch { self.error = error.localizedDescription }
            busy = false
        }
    }
}

// MARK: - Configurações

struct PartySettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var service = PartyService.shared
    @State private var confirmLeave = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(PartyKind.shareable) { k in
                        Toggle(isOn: Binding(get: { service.shared.contains(k) },
                                             set: { on in if on { service.shared.insert(k) } else { service.shared.remove(k) } })) {
                            Label(k.title, systemImage: k.icon)
                        }
                    }
                } header: { Text("O que compartilhar") } footer: {
                    Text("Só o resumo vai para a party (ex.: \"treinou 45 min\"). Seus dados completos continuam só no seu iPhone.")
                }
                Section {
                    Toggle("Mostrar meu peso exato", isOn: $service.showExactWeight)
                } footer: { Text("Desligado: a party vê só a variação (ex.: −0,4 kg).") }
                Section { Toggle("Notificar novidades da party", isOn: $service.notify) }
                Section {
                    Button("Sair da party", role: .destructive) { confirmLeave = true }
                }
            }
            .navigationTitle("Party")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("OK") { dismiss() } }
            .confirmationDialog("Sair da party?", isPresented: $confirmLeave, titleVisibility: .visible) {
                Button("Sair", role: .destructive) { Task { await service.leave(); dismiss() } }
            }
        }
    }
}

struct ServerSetupView: View {
    var onSave: () -> Void
    @State private var apiKey = UserDefaults.standard.string(forKey: "fb.apiKey") ?? ""
    @State private var project = UserDefaults.standard.string(forKey: "fb.projectID") ?? ""

    var body: some View {
        Form {
            Section {
                Text("A party precisa de um servidor Firebase. Cole as chaves do projeto (Configurações do projeto → Geral).")
                    .font(.callout)
            }
            Section("Firebase") {
                TextField("Chave de API da Web", text: $apiKey).autocorrectionDisabled().textInputAutocapitalization(.never)
                TextField("ID do projeto", text: $project).autocorrectionDisabled().textInputAutocapitalization(.never)
                Button("Salvar") {
                    UserDefaults.standard.set(apiKey.trimmingCharacters(in: .whitespaces), forKey: "fb.apiKey")
                    UserDefaults.standard.set(project.trimmingCharacters(in: .whitespaces), forKey: "fb.projectID")
                    onSave()
                }
                .disabled(apiKey.isEmpty || project.isEmpty)
            }
        }
        .scrollContentBackground(.hidden)
    }
}
