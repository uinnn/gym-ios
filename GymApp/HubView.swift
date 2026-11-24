import SwiftUI

/// Botão flutuante presente em todas as abas: abre a Central (perfil, Party e ajustes).
/// Pode ser arrastado para qualquer altura e gruda na borda esquerda ou direita.
struct HubOrb: View {
    @AppStorage("hub.orbY") private var savedY = 0.72
    @AppStorage("hub.orbLeft") private var left = false
    @AppStorage("hub.orbHidden") private var hidden = false
    @State private var drag: CGSize = .zero
    @State private var open = false
    @State private var assistant = false
    @State private var pulse = false
    private var party: PartyService { PartyService.shared }

    var body: some View {
        GeometryReader { geo in
            let size: CGFloat = 54
            let x = left ? size / 2 + 10 : geo.size.width - size / 2 - 10
            let y = min(max(savedY * geo.size.height, 80), geo.size.height - 110)
            if !hidden {
                orb(size)
                    .position(x: x + drag.width, y: y + drag.height)
                    .gesture(
                        DragGesture(minimumDistance: 8)
                            .onChanged { drag = $0.translation }
                            .onEnded { v in
                                let endX = x + v.translation.width, endY = y + v.translation.height
                                withAnimation(.spring(duration: 0.35, bounce: 0.3)) {
                                    left = endX < geo.size.width / 2
                                    savedY = min(max(endY / geo.size.height, 0.1), 0.92)
                                    drag = .zero
                                }
                            }
                    )
                    .onTapGesture { open = true }
                    .onLongPressGesture(minimumDuration: 0.4) { assistant = true }
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .ignoresSafeArea(.keyboard)
        .sheet(isPresented: $open) {
            HubView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $assistant) { AssistantView() }
        .sensoryFeedback(.impact(weight: .medium), trigger: assistant) { _, new in new && ThemeStore.shared.haptics }
        .sensoryFeedback(.impact(weight: .light), trigger: open) { _, new in new && ThemeStore.shared.haptics }
    }

    private func orb(_ size: CGFloat) -> some View {
        let unread = party.unread
        return ZStack {
            Circle().fill(Theme.gradient).opacity(0.35).scaleEffect(pulse && unread > 0 ? 1.35 : 1)
            Circle().fill(.ultraThinMaterial)
            Circle().strokeBorder(Theme.gradient, lineWidth: 2)
            Text(ProfileRegistry.shared.active.emoji).font(.system(size: 26))
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
        .overlay(alignment: .topTrailing) {
            if unread > 0 {
                Text("\(min(unread, 99))").font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                    .padding(.horizontal, 5).padding(.vertical, 2).background(Theme.danger, in: Capsule())
                    .offset(x: 4, y: -4)
            }
        }
        .contentShape(Circle())
        .accessibilityLabel("Central: perfil, Party e ajustes")
        .onAppear { withAnimation(.easeInOut(duration: 1.2).repeatForever()) { pulse = true } }
    }
}

/// Central: tudo o que não é de uma aba só — perfil, Party e configurações.
struct HubView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable private var store = ThemeStore.shared
    @Bindable private var reminders = ReminderStore.shared
    @AppStorage("hub.orbHidden") private var orbHidden = false
    @State private var party = PartyService.shared
    @State private var sheet: HubSheet?
    @State private var water = WaterReminder.enabled

    enum HubSheet: String, Identifiable {
        case sync, assistant, party, chat, achievements, partySettings, profiles, profile, theme, data, scale
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    Button { sheet = .assistant } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "mic.fill").font(.title2).foregroundStyle(.white)
                                .frame(width: 48, height: 48).background(.white.opacity(0.2), in: Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Assistente").font(.headline)
                                Text("Fale ou digite: “comi 2 ovos e 1 pão”").font(.caption).opacity(0.9)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .foregroundStyle(.white).padding(14)
                        .background(Theme.gradient, in: RoundedRectangle(cornerRadius: 20))
                    }
                    .buttonStyle(PressableStyle())
                    profileCard
                    partyCard
                    quickToggles
                    settingsGrid
                }
                .padding()
            }
            .background(AnimatedBackground())
            .navigationTitle("Central")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("OK") { dismiss() } } }
            .sheet(item: $sheet) { s in
                switch s {
                case .sync: NavigationStack { SyncSettingsView() }
                case .assistant: AssistantView()
                case .party: PartyView()
                case .chat: PartyChatView()
                case .achievements: AchievementsView()
                case .partySettings: PartySettingsView()
                case .profiles: ProfileSwitcherView()
                case .profile: ProfileView()
                case .theme: NavigationStack { ThemeSettingsView() }
                case .data: NavigationStack { DataManagementView() }
                case .scale: ContentView()
                }
            }
            .task { await party.refresh() }
        }
    }

    // MARK: Perfil

    private var profileCard: some View {
        let reg = ProfileRegistry.shared
        return Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    ProfileAvatar(info: reg.active, size: 52)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(reg.active.name).font(.title3.bold())
                        Text("\(reg.active.lastKg.map { "\($0.fmt(1)) kg · " } ?? "")\(reg.profiles.count) perfil(is) neste iPhone")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button { sheet = .profile } label: {
                        Label("Editar", systemImage: "pencil").font(.caption.bold())
                    }
                    .buttonStyle(.bordered).buttonBorderShape(.capsule)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(reg.profiles) { p in
                            Button {
                                withAnimation(.spring(duration: 0.4)) { reg.activeID = p.id }
                            } label: {
                                VStack(spacing: 4) {
                                    ProfileAvatar(info: p, size: 40)
                                        .overlay(Circle().strokeBorder(p.id == reg.activeID ? Theme.accent : .clear, lineWidth: 3))
                                    Text(p.name).font(.caption2).lineLimit(1).frame(width: 56)
                                        .foregroundStyle(p.id == reg.activeID ? .primary : .secondary)
                                }
                            }
                            .buttonStyle(PressableStyle())
                        }
                        Button { sheet = .profiles } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "plus").font(.headline).frame(width: 40, height: 40)
                                    .background(.quaternary, in: Circle())
                                Text("Gerenciar").font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
            }
        }
    }

    // MARK: Party

    private var partyCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label(party.party?.name ?? "Party", systemImage: "person.3.fill").font(.headline)
                    Spacer()
                    if party.unread > 0 {
                        Text("\(party.unread) nova(s)").font(.caption.bold()).foregroundStyle(.white)
                            .padding(.horizontal, 8).padding(.vertical, 3).background(Theme.danger, in: Capsule())
                    }
                }
                if let p = party.party {
                    HStack(spacing: -8) {
                        ForEach(p.members) { m in
                            Text(m.emoji).font(.title3).frame(width: 36, height: 36)
                                .background(.ultraThinMaterial, in: Circle())
                                .overlay(Circle().strokeBorder(.background, lineWidth: 2))
                        }
                        Text("  \(p.members.count)/\(Party.maxMembers) · código \(p.code)")
                            .font(.caption).foregroundStyle(.secondary).padding(.leading, 12)
                    }
                    let recent = party.events.suffix(3).reversed()
                    if recent.isEmpty {
                        Text("Nada por aqui ainda. Treine, pese-se ou mande uma mensagem!").font(.caption).foregroundStyle(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(Array(recent)) { e in
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: e.kind.icon).font(.caption).foregroundStyle(Theme.accent).frame(width: 16)
                                    Text("\(e.emoji) \(e.name): ").font(.caption.bold()) + Text(e.text).font(.caption)
                                    Spacer(minLength: 0)
                                    Text(e.date, format: .relative(presentation: .numeric)).font(.caption2).foregroundStyle(.tertiary)
                                }
                                .lineLimit(2)
                            }
                        }
                    }
                    HStack(spacing: 8) {
                        pill("Abrir", "rectangle.stack.person.crop.fill", prominent: true) { sheet = .party }
                        pill("Chat", "bubble.left.and.bubble.right.fill") { sheet = .chat }
                        pill("Conquistas", "medal.fill") { sheet = .achievements }
                        pill("", "slider.horizontal.3") { sheet = .partySettings }
                    }
                } else {
                    Text("Treine junto com amigos e família: ranking semanal, desafios, duelos, reações e chat.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    pill("Criar ou entrar numa party", "person.badge.plus", prominent: true) { sheet = .party }
                }
            }
        }
    }

    private func pill(_ title: String, _ icon: String, prominent: Bool = false, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Group {
                if title.isEmpty { Image(systemName: icon) } else { Label(title, systemImage: icon) }
            }
            .font(.caption.bold()).frame(maxWidth: title.isEmpty ? nil : .infinity).padding(.vertical, 8).padding(.horizontal, 10)
            .foregroundStyle(prominent ? .white : .primary)
            .background(prominent ? AnyShapeStyle(Theme.gradient) : AnyShapeStyle(.quaternary), in: Capsule())
        }
        .buttonStyle(PressableStyle())
    }

    // MARK: Atalhos

    private var quickToggles: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Label("Rápido", systemImage: "bolt.fill").font(.headline)
                HStack(spacing: 8) {
                    ForEach(Appearance.allCases) { a in
                        Button { withAnimation(.spring(duration: 0.4)) { store.appearance = a } } label: {
                            VStack(spacing: 4) {
                                Image(systemName: a.icon).font(.body)
                                Text(a.label).font(.caption2)
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 8)
                            .foregroundStyle(store.appearance == a ? .white : .primary)
                            .background(store.appearance == a ? AnyShapeStyle(Theme.gradient) : AnyShapeStyle(.quaternary),
                                        in: RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
                Toggle(isOn: $store.haptics) { Label("Vibração", systemImage: "iphone.radiowaves.left.and.right") }
                Toggle(isOn: $reminders.enabled.animation()) { Label("Lembrete de pesagem", systemImage: "bell.badge.fill") }
                Toggle(isOn: Binding(get: { water }, set: { on in
                    water = on
                    if on { Task { water = await WaterReminder.requestAndEnable() } } else { WaterReminder.enabled = false; WaterReminder.reschedule(todayMl: 0, targetMl: 0) }
                })) { Label("Lembretes de água", systemImage: "drop.fill") }
                Toggle(isOn: Binding(get: { !orbHidden }, set: { orbHidden = !$0 })) {
                    Label("Botão flutuante da Central", systemImage: "circle.circle.fill")
                }
            }
            .font(.subheadline)
        }
    }

    // MARK: Ajustes

    private var settingsGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ajustes").font(.headline).padding(.leading, 4)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                tile("Perfil e metas", "Idade, altura, objetivo, treino, Apple Saúde", "person.crop.circle.fill", .profile)
                tile("Tema", "Cores, fundo e aparência", "paintpalette.fill", .theme)
                tile("Perfis da família", "Trocar, criar e editar", "person.2.fill", .profiles)
                tile("Party", "Privacidade e notificações", "person.3.fill", .partySettings)
                tile("Sincronização", "Site, conta e modo automático ou manual", "arrow.triangle.2.circlepath.icloud.fill", .sync)
                tile("Backup", "Importar e exportar dados", "arrow.up.arrow.down.circle.fill", .data)
                tile("Balança", "Conexão e diagnóstico", "scalemass.fill", .scale)
            }
            if orbHidden {
                Text("O botão flutuante está oculto. A Central continua no ícone de engrenagem da tela Início.")
                    .font(.caption).foregroundStyle(.secondary).padding(.horizontal, 4)
            } else {
                Text("Dica: arraste o botão flutuante para mudar de lugar e segure-o para abrir o Assistente.")
                    .font(.caption).foregroundStyle(.secondary).padding(.horizontal, 4)
            }
        }
    }

    private func tile(_ title: String, _ sub: String, _ icon: String, _ s: HubSheet) -> some View {
        Button { sheet = s } label: {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: icon).font(.title3).foregroundStyle(Theme.gradient)
                Text(title).font(.subheadline.bold()).foregroundStyle(.primary)
                Text(sub).font(.caption2).foregroundStyle(.secondary).lineLimit(2, reservesSpace: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(PressableStyle())
    }
}
