import SwiftUI
import SwiftData

/// Campos do perfil.
struct ProfileForm: View {
    @Bindable var profile: UserProfile

    var body: some View {
        Section("Sobre você") {
            TextField("Nome", text: $profile.name)
                .textContentType(.givenName)
            Picker("Sexo biológico", selection: Binding(get: { profile.sex }, set: { profile.sex = $0 })) {
                ForEach(Sex.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            DatePicker("Nascimento", selection: $profile.birthDate, in: ...Date.now, displayedComponents: .date)
            LabeledContent("Idade", value: "\(profile.age) anos")
            Stepper(value: $profile.heightCm, in: 100...230, step: 1) {
                LabeledContent("Altura", value: "\(Int(profile.heightCm)) cm")
            }
        }
        Section("Objetivo") {
            Picker("Objetivo", selection: Binding(get: { profile.goal }, set: { profile.goal = $0 })) {
                ForEach(Goal.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            Stepper(value: $profile.goalWeightKg, in: 30...250, step: 0.5) {
                LabeledContent("Peso meta", value: "\(profile.goalWeightKg.fmt()) kg")
            }
            Picker("Atividade física", selection: Binding(get: { profile.activity }, set: { profile.activity = $0 })) {
                ForEach(ActivityLevel.allCases) { Text($0.label).tag($0) }
            }
        }
    }
}

struct ProfileView: View {
    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]
    @Query(sort: \WeightEntry.date, order: .reverse) private var entries: [WeightEntry]
    @Query private var measurements: [MeasurementEntry]
    @Bindable private var store = ThemeStore.shared
    @Bindable private var reminders = ReminderStore.shared
    @Bindable private var workout = WorkoutPrefs.shared
    @State private var showScanner = false
    @State private var confirmReset = false

    var body: some View {
        NavigationStack {
            Form {
                if let p = profiles.first {
                    header(p)
                    ProfileForm(profile: p)
                }
                Section("Personalização") {
                    NavigationLink {
                        ThemeSettingsView()
                    } label: {
                        HStack {
                            Label("Tema e aparência", systemImage: "paintpalette.fill")
                            Spacer()
                            Circle().fill(Theme.gradient).frame(width: 22, height: 22)
                        }
                    }
                    Toggle(isOn: $store.autoOpenReport) {
                        Label("Abrir relatório após pesar", systemImage: "doc.text.magnifyingglass")
                    }
                    Toggle(isOn: $store.haptics) { Label("Vibração", systemImage: "iphone.radiowaves.left.and.right") }
                }
                Section {
                    Toggle(isOn: $workout.addWorkoutKcal) { Label("Somar calorias do treino à meta", systemImage: "flame.fill") }
                } header: { Text("Treino e alimentação") } footer: {
                    Text("Quando ligado, as calorias gastas nos treinos do dia aumentam sua meta de alimentação. Nesse caso, prefira o nível de atividade \"Sedentário\" ou \"Leve\" no perfil para não contar o exercício duas vezes.")
                }
                Section {
                    Toggle(isOn: $reminders.enabled.animation()) { Label("Lembrete diário", systemImage: "bell.badge.fill") }
                    if reminders.enabled {
                        DatePicker("Horário", selection: $reminders.time, displayedComponents: .hourAndMinute)
                    }
                } header: { Text("Lembretes") } footer: {
                    if reminders.denied { Text("Notificações bloqueadas. Ative em Ajustes > Notificações > Gym.") }
                    else { Text("Pesar-se no mesmo horário deixa a tendência mais confiável.") }
                }
                Section("Dados") {
                    LabeledContent("Pesagens", value: "\(entries.count)")
                    LabeledContent("Medições corporais", value: "\(measurements.count)")
                    Button { showScanner = true } label: {
                        Label("Diagnóstico Bluetooth", systemImage: "antenna.radiowaves.left.and.right")
                    }
                    Button("Apagar todas as pesagens", role: .destructive) { confirmReset = true }
                }
                Section {
                    Text("As métricas de composição são estimativas por fórmulas científicas e não substituem avaliação médica ou de um nutricionista.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AnimatedBackground())
            .navigationTitle("Perfil")
            .sheet(isPresented: $showScanner) { ContentView() }
            .confirmationDialog("Apagar \(entries.count) pesagens? Não dá para desfazer.",
                                isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Apagar tudo", role: .destructive) { entries.forEach { context.delete($0) } }
            }
        }
    }

    private func header(_ p: UserProfile) -> some View {
        Section {
            HStack(spacing: 16) {
                Text(String(p.name.first ?? "🙂"))
                    .font(.largeTitle.bold()).foregroundStyle(.white)
                    .frame(width: 72, height: 72)
                    .background(Theme.gradient, in: Circle())
                VStack(alignment: .leading) {
                    Text(p.name.isEmpty ? "Seu perfil" : p.name).font(.title2.bold())
                    Text("\(p.age) anos · \(Int(p.heightCm)) cm · \(p.sex.label)")
                        .font(.subheadline).foregroundStyle(.secondary)
                    if let first = entries.last {
                        Text("Usando desde \(first.date.formatted(.dateTime.month(.wide).year()))")
                            .font(.caption).foregroundStyle(Theme.accent)
                    }
                }
            }
            .padding(.vertical, 6)
        }
    }
}

/// Cadastro inicial em etapas.
struct OnboardingView: View {
    @Environment(\.modelContext) private var context
    @State private var profile = UserProfile()
    @State private var step = 0
    var onDone: () -> Void

    var body: some View {
        ZStack {
            AnimatedBackground()
            VStack(spacing: 24) {
                Spacer()
                Image(systemName: icons[step])
                    .font(.system(size: 72))
                    .foregroundStyle(Theme.gradient)
                    .symbolEffect(.bounce, value: step)
                    .contentTransition(.symbolEffect(.replace))
                Text(titles[step]).font(.largeTitle.bold()).multilineTextAlignment(.center)
                Text(subtitles[step]).foregroundStyle(.secondary).multilineTextAlignment(.center)

                Group {
                    switch step {
                    case 0:
                        TextField("Seu nome", text: $profile.name)
                            .font(.title2).multilineTextAlignment(.center)
                            .padding().background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    case 1:
                        VStack(spacing: 16) {
                            Picker("Sexo", selection: Binding(get: { profile.sex }, set: { profile.sex = $0 })) {
                                ForEach(Sex.allCases) { Text($0.label).tag($0) }
                            }
                            .pickerStyle(.segmented)
                            DatePicker("Nascimento", selection: $profile.birthDate, in: ...Date.now, displayedComponents: .date)
                        }
                    case 2:
                        VStack {
                            Text("\(Int(profile.heightCm)) cm")
                                .font(.system(size: 52, weight: .bold, design: .rounded))
                                .contentTransition(.numericText(value: profile.heightCm))
                            Slider(value: $profile.heightCm.animation(.snappy), in: 120...220, step: 1)
                                .tint(Theme.accent)
                        }
                    default:
                        VStack(spacing: 16) {
                            Picker("Objetivo", selection: Binding(get: { profile.goal }, set: { profile.goal = $0 })) {
                                ForEach(Goal.allCases) { Text($0.label).tag($0) }
                            }
                            .pickerStyle(.segmented)
                            Text("\(profile.goalWeightKg.fmt()) kg")
                                .font(.system(size: 44, weight: .bold, design: .rounded))
                                .contentTransition(.numericText(value: profile.goalWeightKg))
                            Slider(value: $profile.goalWeightKg.animation(.snappy), in: 35...200, step: 0.5)
                                .tint(Theme.accent)
                            Picker("Atividade", selection: Binding(get: { profile.activity }, set: { profile.activity = $0 })) {
                                ForEach(ActivityLevel.allCases) { Text($0.label).tag($0) }
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal: .move(edge: .leading).combined(with: .opacity)))
                .id(step)

                Spacer()

                HStack(spacing: 8) {
                    ForEach(0..<4) { i in
                        Capsule().fill(i <= step ? Theme.accent : Color.secondary.opacity(0.3))
                            .frame(width: i == step ? 24 : 8, height: 8)
                    }
                }
                Button {
                    if step < 3 {
                        withAnimation(.spring(duration: 0.5)) { step += 1 }
                    } else {
                        context.insert(profile)
                        onDone()
                    }
                } label: {
                    Text(step < 3 ? "Continuar" : "Começar")
                        .font(.headline).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding()
                        .background(Theme.gradient, in: RoundedRectangle(cornerRadius: 18))
                }
                .padding(.horizontal)
            }
            .padding()
        }
    }

    private let icons = ["hand.wave.fill", "person.fill", "ruler.fill", "flag.checkered"]
    private let titles = ["Bem-vindo!", "Sobre você", "Sua altura", "Seu objetivo"]
    private let subtitles = [
        "Vamos cuidar da sua saúde física e mental, um passo de cada vez.",
        "Usamos sexo e idade para estimar sua composição corporal.",
        "Necessária para o IMC e o metabolismo.",
        "Defina a meta. Você pode mudar quando quiser.",
    ]
}
