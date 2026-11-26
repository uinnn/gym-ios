import SwiftUI
import SwiftData
import PhotosUI

/// Assistente: digite ou fale ("comi 3 pães e 150 g de frango", "supino 3x10 60 kg", "quanto de proteína falta?")
/// ou mande a foto do prato. Regras locais primeiro; o Gemini entra quando você pede ou quando as regras não entendem.
struct AssistantView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var saved: [SavedFood]
    @Query private var profiles: [UserProfile]
    @Query(sort: \WeightEntry.date) private var weights: [WeightEntry]
    @Query private var measurements: [MeasurementEntry]
    @Query(sort: \FoodLog.date) private var logs: [FoodLog]
    @Query(sort: \WaterLog.date) private var water: [WaterLog]
    @Query private var sessions: [WorkoutSession]
    @Query(sort: \SleepEntry.wake) private var sleeps: [SleepEntry]

    @State private var speech = SpeechTranscriber()
    @State private var text = ""
    @State private var drafts: [AssistantDraft] = []
    @State private var fromAI = false
    @State private var done: [String] = []
    @State private var pulse = false
    @State private var image: UIImage?
    @State private var photoItem: PhotosPickerItem?
    @State private var showGallery = false
    @State private var showCamera = false
    @State private var showSettings = false
    @State private var thinking = false
    @State private var aiError: String?
    @State private var aiReady = Gemini.isConfigured
    @FocusState private var focused: Bool

    private static let examples = [
        "Comi 3 pães e 150 g de frango no almoço",
        "Café da manhã: 2 ovos, 1 banana e 30 g de aveia",
        "Supino 3x10 com 60 kg e rosca 3x12 com 14",
        "Corri 5 km em 28 minutos",
        "Bebi 2 copos de água",
        "Pesei 82,5 kg e cintura 84 cm",
        "Quanto de proteína falta hoje?",
        "Repete o café da manhã de ontem",
        "Comi 2 pães, na verdade foram 3",
        "Dormi 7 horas e meia",
    ]

    private var data: AssistantData {
        let since = Calendar.current.date(byAdding: .day, value: -45, to: .now) ?? .distantPast
        return AssistantData(saved: saved, logs: logs.filter { $0.date >= since }, water: water.filter { $0.date >= since },
                             weights: weights, sessions: sessions, sleeps: sleeps, profile: profiles.first,
                             targets: NutrientContext.make(profiles.first, weights, measurements).targets)
    }

    /// As regras não entenderam algo (ou é uma pergunta sem resposta local): vale chamar a IA.
    private var needsAI: Bool {
        image != nil || drafts.contains { $0.kind == .unknown } || (!text.isEmpty && drafts.isEmpty)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    inputCard
                    if let e = speech.error ?? aiError {
                        Label(e, systemImage: "exclamationmark.triangle.fill").font(.footnote).foregroundStyle(.orange)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if !done.isEmpty { doneCard }
                    if thinking {
                        HStack { ProgressView(); Text("Pensando com a IA…").foregroundStyle(.secondary) }.padding()
                    }
                    ForEach(drafts.filter { $0.kind == .answer }) { a in answerCard(a.text) }
                    if drafts.contains(where: { $0.kind != .answer }) { draftsCard }
                    else if drafts.isEmpty && text.isEmpty && image == nil && !thinking { examplesCard }
                }
                .padding()
            }
            .background(AnimatedBackground())
            .navigationTitle("Assistente")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Fechar") { speech.stop(); dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Button { showSettings = true } label: {
                        Image(systemName: aiReady ? "sparkles" : "gearshape")
                    }
                    .accessibilityLabel("Ajustes da IA")
                }
            }
            .safeAreaInset(edge: .bottom) { if drafts.contains(where: \.isRecord) { confirmBar } }
            .onChange(of: speech.text) { _, t in text = t }
            .task(id: text) {
                // Interpreta enquanto você digita ou fala (pequena pausa para não refazer a cada letra).
                guard !fromAI else { return }
                try? await Task.sleep(for: .milliseconds(350))
                guard !Task.isCancelled, !fromAI else { return }
                drafts = AssistantParser.parse(text, data: data)
                aiError = nil
            }
            .onChange(of: speech.finishedCount) { _, _ in
                // Falou e as regras não entenderam: pergunta à IA automaticamente.
                Task {
                    try? await Task.sleep(for: .milliseconds(450))
                    if aiReady && needsAI && !thinking { await askAI() }
                }
            }
            .onChange(of: photoItem) { _, it in
                guard let it else { return }
                Task {
                    // Fotos do iCloud podem demorar para baixar; HEIC também abre pelo UIImage.
                    if let d = try? await it.loadTransferable(type: Data.self), let img = UIImage(data: d) {
                        image = img.downscaled(maxSide: 2048)
                        aiError = nil
                    } else {
                        aiError = "Não consegui abrir essa foto. Tente outra ou tire uma pela câmera."
                    }
                    photoItem = nil
                }
            }
            // O seletor da galeria fica fora do Menu: dentro dele o iOS fecha o menu e não abre a galeria.
            .photosPicker(isPresented: $showGallery, selection: $photoItem, matching: .images, photoLibrary: .shared())
            .fullScreenCover(isPresented: $showCamera) { CameraPicker { image = $0 }.ignoresSafeArea() }
            .sheet(isPresented: $showSettings, onDismiss: { aiReady = Gemini.isConfigured }) { GeminiSettingsView() }
            .sensoryFeedback(.success, trigger: done.count) { _, n in n > 0 && ThemeStore.shared.haptics }
            .onDisappear { speech.stop() }
        }
    }

    // MARK: Entrada

    private var inputCard: some View {
        Card {
            VStack(spacing: 12) {
                ZStack(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("Diga ou digite o que comeu, treinou, bebeu, pesou — ou faça uma pergunta…")
                            .foregroundStyle(.tertiary).padding(.top, 8).padding(.leading, 5)
                    }
                    TextEditor(text: Binding(get: { text }, set: { text = $0; fromAI = false }))
                        .focused($focused)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 70, maxHeight: 150)
                }
                if let image {
                    HStack {
                        Image(uiImage: image).resizable().scaledToFill().frame(width: 64, height: 64)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        Text("Foto anexada: o Gemini vai identificar os alimentos e estimar as gramas.")
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button { self.image = nil } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                    }
                }
                HStack(spacing: 10) {
                    Menu {
                        Button { showCamera = true } label: { Label("Tirar foto do prato", systemImage: "camera.fill") }
                        Button { showGallery = true } label: { Label("Escolher da galeria", systemImage: "photo") }
                    } label: {
                        Image(systemName: "camera.fill").font(.title3).frame(width: 44, height: 44)
                            .background(.quaternary, in: Circle())
                    }
                    if !text.isEmpty || image != nil {
                        Button("Limpar", role: .destructive) {
                            speech.stop(); text = ""; drafts = []; image = nil; fromAI = false; aiError = nil
                        }
                        .font(.subheadline)
                    }
                    Spacer()
                    if aiReady && (!text.isEmpty || image != nil) {
                        Button { Task { await askAI() } } label: {
                            Label("IA", systemImage: "sparkles").font(.subheadline.bold())
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .foregroundStyle(needsAI ? .white : Theme.accent)
                                .background(needsAI ? AnyShapeStyle(Theme.gradient) : AnyShapeStyle(Theme.accent.opacity(0.15)), in: Capsule())
                        }
                        .disabled(thinking)
                    }
                    Button {
                        focused = false
                        Task { await speech.toggle(appendingTo: text) }
                    } label: {
                        Image(systemName: speech.recording ? "stop.fill" : "mic.fill")
                            .font(.title2.bold()).foregroundStyle(.white)
                            .frame(width: 60, height: 60)
                            .background(speech.recording ? AnyShapeStyle(Theme.danger) : AnyShapeStyle(Theme.gradient), in: Circle())
                            .overlay(Circle().stroke(Theme.danger.opacity(0.4), lineWidth: 6)
                                .scaleEffect(speech.recording && pulse ? 1.35 : 1).opacity(speech.recording ? 1 : 0))
                    }
                    .buttonStyle(PressableStyle())
                    .onAppear { withAnimation(.easeInOut(duration: 0.8).repeatForever()) { pulse = true } }
                }
            }
        }
    }

    private var examplesCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                Label("Experimente", systemImage: "sparkles").font(.headline)
                ForEach(Self.examples, id: \.self) { ex in
                    Button { text = ex; fromAI = false } label: {
                        HStack {
                            Text("“\(ex)”").font(.subheadline).foregroundStyle(.primary).multilineTextAlignment(.leading)
                            Spacer()
                            Image(systemName: "arrow.up.left").font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 3)
                    }
                }
                if aiReady {
                    Text("Com a IA ligada: mande a foto do prato, frases livres (“almocei um PF”) ou peça conselhos (“o que como no jantar para bater a proteína?”).")
                        .font(.caption).foregroundStyle(.secondary).padding(.top, 4)
                } else {
                    Button { showSettings = true } label: {
                        Label("Ligar a IA gratuita (Gemini) para fotos, frases livres e conselhos", systemImage: "sparkles")
                            .font(.caption.bold())
                    }
                    .padding(.top, 4)
                }
                Text("Nada é salvo antes de você confirmar.").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var doneCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 6) {
                Label("Registrado", systemImage: "checkmark.circle.fill").font(.headline).foregroundStyle(Theme.accent)
                ForEach(done, id: \.self) { Text("• " + $0).font(.subheadline) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .transition(.scale.combined(with: .opacity))
    }

    private func answerCard(_ t: String) -> some View {
        Card {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: fromAI ? "sparkles" : "text.bubble.fill").foregroundStyle(Theme.accent).font(.title3)
                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedStringKey(t)).font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                    if fromAI { Text("Respondido por \(Gemini.lastProvider)").font(.caption2).foregroundStyle(.secondary) }
                }
            }
        }
    }

    // MARK: Conferência

    private var draftsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Label(fromAI ? "A IA entendeu isto — confira" : "Entendi isto — confira", systemImage: "wand.and.stars").font(.headline)
                let rows = drafts.indices.filter { drafts[$0].kind != .answer }
                ForEach(rows, id: \.self) { i in
                    draftRow($drafts[i])
                    if i != rows.last { Divider() }
                }
                let foods = drafts.filter { $0.kind == .food }
                if !foods.isEmpty {
                    let kcal = foods.compactMap { d in d.food.map { $0.per100.kcal * d.grams / 100 } }.reduce(0, +)
                    let prot = foods.compactMap { d in d.food.map { $0.per100.protein * d.grams / 100 } }.reduce(0, +)
                    Text("Total da comida: \(Int(kcal)) kcal · \(Int(prot)) g de proteína")
                        .font(.caption.bold()).foregroundStyle(.secondary)
                }
                if drafts.contains(where: { $0.kind == .unknown }) && aiReady && !fromAI {
                    Button { Task { await askAI() } } label: {
                        Label("Não entendi tudo — perguntar à IA", systemImage: "sparkles").font(.subheadline.bold())
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func draftRow(_ d: Binding<AssistantDraft>) -> some View {
        let v = d.wrappedValue
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon(v)).font(.title3).foregroundStyle(v.kind == .unknown ? .orange : Theme.accent).frame(width: 28)
            VStack(alignment: .leading, spacing: 6) {
                switch v.kind {
                case .food:
                    if let f = v.food {
                        Menu {
                            ForEach(v.alternatives) { a in
                                Button(a.category == "Estimativa IA" ? "\(a.name) (estimativa da IA)" : a.name) {
                                    d.wrappedValue.food = a
                                    AssistantParser.learn(spoken: v.spoken, food: a, context: context)
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(f.name).font(.subheadline.bold()).foregroundStyle(.primary).multilineTextAlignment(.leading)
                                Image(systemName: "chevron.up.chevron.down").font(.caption2)
                            }
                        }
                        if f.category == "Estimativa IA" {
                            Text("Valores estimados pela IA").font(.caption2).foregroundStyle(.orange)
                        }
                        Stepper("\(Int(v.grams)) g · \(Int(f.per100.kcal * v.grams / 100)) kcal · \(Int(f.per100.protein * v.grams / 100)) g prot",
                                value: d.grams, in: 1...3000, step: 10)
                            .font(.caption)
                        Picker("Refeição", selection: d.meal) {
                            ForEach(Meal.allCases) { Text($0.label).tag($0) }
                        }
                        .pickerStyle(.menu).font(.caption).labelsHidden()
                    }
                case .exercise:
                    Menu {
                        ForEach(similarExercises(v)) { x in
                            Button(x.name) {
                                d.wrappedValue.exerciseID = x.id
                                AssistantParser.learnExercise(spoken: v.spoken, id: x.id)
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(v.exercise?.name ?? v.exerciseID).font(.subheadline.bold()).foregroundStyle(.primary)
                            Image(systemName: "chevron.up.chevron.down").font(.caption2)
                        }
                    }
                    Stepper("\(v.sets) séries", value: d.sets, in: 1...20).font(.caption)
                    Stepper("\(v.reps) repetições", value: d.reps, in: 1...100).font(.caption)
                    Stepper("\(v.kg.fmt(1)) kg", value: d.kg, in: 0...500, step: v.kg >= 20 ? 2.5 : 1).font(.caption)
                case .cardio:
                    Picker("Tipo", selection: d.cardioKind) {
                        ForEach(CardioKind.allCases) { Label($0.title, systemImage: $0.icon).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Stepper("\(v.km.fmt(1)) km", value: d.km, in: 0...300, step: 0.5).font(.caption)
                    Stepper("\(Int(v.minutes)) min", value: d.minutes, in: 1...600, step: 1).font(.caption)
                case .measure:
                    Picker("Parte", selection: d.part) { ForEach(BodyPart.allCases) { Text($0.label).tag($0) } }
                        .pickerStyle(.menu).font(.caption)
                    Stepper("\(v.value.fmt(1)) cm", value: d.value, in: 10...200, step: 0.5).font(.subheadline)
                case .water:
                    Stepper("Água: \(Int(v.value)) ml", value: d.value, in: 50...5000, step: 50).font(.subheadline)
                case .weight:
                    Stepper("Peso: \(v.value.fmt(1)) kg", value: d.value, in: 25...300, step: 0.1).font(.subheadline)
                case .sleep:
                    Stepper("Sono: \(v.value.fmt(1)) h", value: d.value, in: 1...16, step: 0.5).font(.subheadline)
                case .mood:
                    Stepper("Humor: \(Int(v.value)) de 5", value: d.value, in: 1...5, step: 1).font(.subheadline)
                case .workout:
                    Text("Abrir a aba Treinos e começar um treino").font(.subheadline)
                case .unknown:
                    Text(v.text == "question" ? "Não sei responder isso sozinho" : "Não encontrei “\(v.source)”").font(.subheadline)
                    Text(aiReady ? "Toque em IA para perguntar à IA." : "Tente outro nome, ou ligue a IA nos ajustes (✨).")
                        .font(.caption).foregroundStyle(.secondary)
                case .answer:
                    EmptyView()
                }
                if v.isRecord && !Calendar.current.isDateInToday(v.date) {
                    Text(v.date.formatted(.relative(presentation: .named))).font(.caption2.bold()).foregroundStyle(.orange)
                }
            }
            Spacer(minLength: 0)
            Button { withAnimation { drafts.removeAll { $0.id == v.id } } } label: {
                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
            }
            .buttonStyle(.tap)
        }
    }

    private func similarExercises(_ d: AssistantDraft) -> [Exercise] {
        guard let x = d.exercise else { return Array(ExerciseCatalog.all.prefix(20)) }
        return ExerciseCatalog.all.filter { $0.primary.first == x.primary.first }.sorted { $0.name < $1.name }
    }

    private func icon(_ d: AssistantDraft) -> String {
        switch d.kind {
        case .food: "fork.knife"
        case .water: "drop.fill"
        case .weight: "scalemass.fill"
        case .sleep: "bed.double.fill"
        case .mood: "face.smiling"
        case .workout, .exercise: "dumbbell.fill"
        case .cardio: d.cardioKind.icon
        case .measure: "ruler.fill"
        case .answer: "text.bubble"
        case .unknown: "questionmark.circle"
        }
    }

    // MARK: Ações

    private func askAI() async {
        guard aiReady else { showSettings = true; return }
        speech.stop()
        thinking = true
        aiError = nil
        defer { thinking = false }
        do {
            let d = data
            let r = try await Gemini.ask(text, image: image, context: Gemini.context(d))
            withAnimation {
                drafts = Gemini.drafts(r, data: d)
                fromAI = true
                image = nil
            }
        } catch {
            aiError = error.localizedDescription
        }
    }

    private var confirmBar: some View {
        let n = drafts.filter(\.isRecord).count
        return Button {
            speech.stop()
            let opensWorkout = drafts.contains { $0.kind == .workout }
            let result = AssistantParser.commit(drafts, data: data, in: context)
            withAnimation(.spring) { done = result; drafts = []; text = ""; fromAI = false; image = nil }
            if opensWorkout { dismiss() }
        } label: {
            Label("Registrar \(n) \(n == 1 ? "item" : "itens")", systemImage: "checkmark.circle.fill")
                .font(.headline).foregroundStyle(.white).frame(maxWidth: .infinity).padding()
                .background(Theme.gradient, in: Capsule())
        }
        .buttonStyle(PressableStyle())
        .padding(.horizontal).padding(.bottom, 8)
    }
}
