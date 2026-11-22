import SwiftData
import SwiftUI

/// Avatar redondo de um perfil.
struct ProfileAvatar: View {
    let info: ProfileInfo
    var size: CGFloat = 44

    var body: some View {
        Text(info.emoji)
            .font(.system(size: size * 0.5))
            .frame(width: size, height: size)
            .background(LinearGradient(colors: [info.color, info.color.opacity(0.6)], startPoint: .topLeading,
                                       endPoint: .bottomTrailing), in: Circle())
            .overlay(Circle().strokeBorder(.white.opacity(0.4), lineWidth: 1.5))
    }
}

/// Lista de perfis da família: trocar, criar, editar e apagar.
struct ProfileSwitcherView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable private var registry = ProfileRegistry.shared
    @State private var editing: ProfileInfo?
    @State private var creating = false
    @State private var deleting: ProfileInfo?

    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedBackground()
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(Array(registry.profiles.enumerated()), id: \.element.id) { i, p in
                            row(p).appear(Double(i) * 0.04)
                        }
                        Button { creating = true } label: {
                            Label("Adicionar perfil", systemImage: "person.crop.circle.badge.plus")
                                .font(.headline).frame(maxWidth: .infinity).padding()
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
                        }
                        .buttonStyle(PressableStyle())
                        Text("Cada perfil tem seus próprios dados: pesagens, medidas, alimentação, treinos e metas. Ao subir na balança, o app reconhece de quem é o peso pelo último peso de cada perfil e sugere salvar no perfil certo.")
                            .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center).padding(.top, 6)
                    }
                    .padding()
                }
            }
            .navigationTitle("Perfis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("OK") { dismiss() } }
            .sheet(isPresented: $creating) {
                ProfileEditorSheet(info: nil) { new in
                    withAnimation(.spring) { registry.activeID = new.id }
                    dismiss()
                }
            }
            .sheet(item: $editing) { p in ProfileEditorSheet(info: p) { _ in } }
            .confirmationDialog("Apagar o perfil \"\(deleting?.name ?? "")\" e TODOS os dados dele?",
                                isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
                                titleVisibility: .visible) {
                Button("Apagar perfil", role: .destructive) {
                    if let d = deleting { withAnimation { registry.delete(d.id) } }
                    deleting = nil
                }
            } message: { Text("Não dá para desfazer. Faça um backup antes, se quiser guardar os dados.") }
        }
    }

    private func row(_ p: ProfileInfo) -> some View {
        let on = p.id == registry.activeID
        return Button {
            withAnimation(.spring(duration: 0.4)) { registry.activeID = p.id }
            dismiss()
        } label: {
            HStack(spacing: 14) {
                ProfileAvatar(info: p, size: 54)
                    .scaleEffect(on ? 1.05 : 1)
                VStack(alignment: .leading, spacing: 3) {
                    Text(p.name).font(.headline).foregroundStyle(.primary)
                    Text("\(p.age) anos · \(Int(p.heightCm)) cm · \(Sex(rawValue: p.sexRaw)?.label ?? "")")
                        .font(.caption).foregroundStyle(.secondary)
                    if let kg = p.lastKg {
                        Text("Último peso: \(kg.fmt(2)) kg\(p.lastWeighed.map { " · \($0.formatted(.relative(presentation: .named)))" } ?? "")")
                            .font(.caption2).foregroundStyle(p.color)
                    }
                }
                Spacer()
                if on {
                    Image(systemName: "checkmark.circle.fill").font(.title2).foregroundStyle(Theme.good)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(14)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(on ? p.color : .clear, lineWidth: 2))
        }
        .buttonStyle(PressableStyle())
        .contextMenu {
            Button("Editar", systemImage: "pencil") { editing = p }
            if registry.profiles.count > 1 {
                Button("Apagar", systemImage: "trash", role: .destructive) { deleting = p }
            }
        }
    }
}

/// Criar ou editar um perfil: só nome, avatar, sexo, nascimento e altura.
struct ProfileEditorSheet: View {
    let info: ProfileInfo?
    var onSaved: (ProfileInfo) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var emoji = "🙂"
    @State private var color = 0
    @State private var sex: Sex = .male
    @State private var birth = Calendar.current.date(byAdding: .year, value: -25, to: .now)!
    @State private var height = 170.0

    var body: some View {
        let preview = ProfileInfo(id: "x", name: name, emoji: emoji, colorIndex: color)
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        ProfileAvatar(info: preview, size: 84).animation(.spring, value: emoji)
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                    TextField("Nome", text: $name).font(.headline).multilineTextAlignment(.center)
                }
                Section("Avatar") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 10) {
                        ForEach(ProfileRegistry.emojis, id: \.self) { e in
                            Button { emoji = e } label: {
                                Text(e).font(.title2).frame(width: 36, height: 36)
                                    .background(emoji == e ? Theme.accent.opacity(0.25) : .clear, in: Circle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(Palette.all.indices, id: \.self) { i in
                                Circle().fill(Palette.all[i].accent).frame(width: 30, height: 30)
                                    .overlay(Circle().strokeBorder(.primary, lineWidth: color == i ? 2.5 : 0))
                                    .onTapGesture { withAnimation { color = i } }
                            }
                        }
                    }
                }
                Section("Dados básicos") {
                    Picker("Sexo biológico", selection: $sex) {
                        ForEach(Sex.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    DatePicker("Nascimento", selection: $birth, in: ...Date.now, displayedComponents: .date)
                    LabeledContent("Idade", value: "\(Calendar.current.dateComponents([.year], from: birth, to: .now).year ?? 0) anos")
                    Stepper(value: $height, in: 80...230, step: 1) {
                        LabeledContent("Altura", value: "\(Int(height)) cm")
                    }
                }
                if info == nil {
                    Section {
                        Text("Metas, nível de atividade, alimentação e treinos são configurados depois, dentro do próprio perfil. A meta inicial de peso é calculada pela altura (IMC 22).")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(info == nil ? "Novo perfil" : "Editar perfil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(info == nil ? "Criar" : "Salvar") { save() }
                        .bold().disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                guard let i = info else { return }
                name = i.name; emoji = i.emoji; color = i.colorIndex
                sex = Sex(rawValue: i.sexRaw) ?? .male; birth = i.birthDate; height = i.heightCm
            }
        }
    }

    @MainActor private func save() {
        let reg = ProfileRegistry.shared
        if let i = info {
            reg.update(i.id) {
                $0.name = name; $0.emoji = emoji; $0.colorIndex = color
                $0.sexRaw = sex.rawValue; $0.birthDate = birth; $0.heightCm = height
            }
            // aplica no banco do perfil também
            let ctx = reg.container(for: i.id).mainContext
            if let p = (try? ctx.fetch(FetchDescriptor<UserProfile>()))?.first {
                p.name = name; p.sex = sex; p.birthDate = birth; p.heightCm = height
                try? ctx.save()
            }
            dismiss()
            onSaved(reg.profiles.first { $0.id == i.id } ?? i)
        } else {
            let new = reg.create(name: name, emoji: emoji, sex: sex, birth: birth, heightCm: height)
            reg.update(new.id) { $0.colorIndex = color }
            dismiss()
            onSaved(new)
        }
    }
}
