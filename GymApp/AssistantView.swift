import SwiftUI
import SwiftData

/// Assistente: digite ou fale ("comi 3 pães e 150 g de frango", "bebi 2 copos de água", "pesei 82,5")
/// e confira o que será registrado antes de salvar.
struct AssistantView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var saved: [SavedFood]
    @State private var speech = SpeechTranscriber()
    @State private var text = ""
    @State private var drafts: [AssistantDraft] = []
    @State private var done: [String] = []
    @State private var pulse = false
    @FocusState private var focused: Bool

    private static let examples = [
        "Comi 3 pães e 150 g de frango no almoço",
        "Café da manhã: 2 ovos, 1 banana e 30 g de aveia",
        "Bebi 2 copos de água",
        "Pesei 82,5 kg",
        "Dormi 7 horas e meia",
        "Me sinto cansado",
        "Ontem jantei 200 g de arroz e 1 concha de feijão",
        "Começar treino",
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    inputCard
                    if let e = speech.error { Label(e, systemImage: "exclamationmark.triangle.fill").font(.footnote).foregroundStyle(.orange) }
                    if !done.isEmpty { doneCard }
                    if drafts.isEmpty && text.isEmpty { examplesCard } else if !drafts.isEmpty { draftsCard }
                }
                .padding()
            }
            .background(AnimatedBackground())
            .navigationTitle("Assistente")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Fechar") { speech.stop(); dismiss() } } }
            .safeAreaInset(edge: .bottom) { if !drafts.filter({ $0.kind != .unknown }).isEmpty { confirmBar } }
            .onChange(of: speech.text) { _, t in text = t }
            .task(id: text) {
                // Interpreta enquanto você digita ou fala (pequena pausa para não refazer a cada letra).
                try? await Task.sleep(for: .milliseconds(350))
                drafts = AssistantParser.parse(text, saved: saved)
            }
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
                        Text("Diga ou digite o que você comeu, bebeu, pesou ou dormiu…")
                            .foregroundStyle(.tertiary).padding(.top, 8).padding(.leading, 5)
                    }
                    TextEditor(text: $text)
                        .focused($focused)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 80, maxHeight: 160)
                }
                HStack {
                    if !text.isEmpty {
                        Button("Limpar", role: .destructive) { speech.stop(); text = ""; drafts = [] }.font(.subheadline)
                    }
                    Spacer()
                    Text(speech.recording ? "Ouvindo… toque para parar" : "Toque para falar")
                        .font(.caption).foregroundStyle(.secondary)
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
                    Button { text = ex } label: {
                        HStack {
                            Text("“\(ex)”").font(.subheadline).foregroundStyle(.primary).multilineTextAlignment(.leading)
                            Spacer()
                            Image(systemName: "arrow.up.left").font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                Text("Tudo é interpretado no próprio iPhone. Nada é salvo antes de você confirmar.")
                    .font(.caption).foregroundStyle(.secondary).padding(.top, 4)
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

    // MARK: Conferência

    private var draftsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Label("Entendi isto — confira", systemImage: "wand.and.stars").font(.headline)
                ForEach($drafts) { $d in
                    draftRow($d)
                    if d.id != drafts.last?.id { Divider() }
                }
                let foods = drafts.filter { $0.kind == .food }
                if !foods.isEmpty {
                    let kcal = foods.compactMap { d in d.food.map { $0.per100.kcal * d.grams / 100 } }.reduce(0, +)
                    let prot = foods.compactMap { d in d.food.map { $0.per100.protein * d.grams / 100 } }.reduce(0, +)
                    Text("Total da comida: \(Int(kcal)) kcal · \(Int(prot)) g de proteína")
                        .font(.caption.bold()).foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func draftRow(_ d: Binding<AssistantDraft>) -> some View {
        let v = d.wrappedValue
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon(v.kind)).font(.title3).foregroundStyle(v.kind == .unknown ? .orange : Theme.accent).frame(width: 28)
            VStack(alignment: .leading, spacing: 6) {
                switch v.kind {
                case .food:
                    if let f = v.food {
                        Menu {
                            ForEach(v.alternatives) { a in Button(a.name) { d.wrappedValue.food = a } }
                        } label: {
                            HStack(spacing: 4) {
                                Text(f.name).font(.subheadline.bold()).foregroundStyle(.primary).multilineTextAlignment(.leading)
                                Image(systemName: "chevron.up.chevron.down").font(.caption2)
                            }
                        }
                        HStack {
                            Stepper("\(Int(v.grams)) g · \(Int(f.per100.kcal * v.grams / 100)) kcal", value: d.grams, in: 1...3000, step: 10)
                                .font(.caption)
                        }
                        Picker("Refeição", selection: d.meal) {
                            ForEach(Meal.allCases) { Text($0.label).tag($0) }
                        }
                        .pickerStyle(.menu).font(.caption).labelsHidden()
                    }
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
                    Text("Não encontrei “\(v.source)”").font(.subheadline)
                    Text("Tente outro nome ou cadastre o alimento.").font(.caption).foregroundStyle(.secondary)
                }
                if v.kind != .food && v.kind != .unknown && !Calendar.current.isDateInToday(v.date) {
                    Text("Ontem").font(.caption2.bold()).foregroundStyle(.orange)
                }
                if v.kind == .food && !Calendar.current.isDateInToday(v.date) {
                    Text("Ontem").font(.caption2.bold()).foregroundStyle(.orange)
                }
            }
            Spacer(minLength: 0)
            Button { withAnimation { drafts.removeAll { $0.id == v.id } } } label: {
                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    private func icon(_ k: AssistantDraft.Kind) -> String {
        switch k {
        case .food: "fork.knife"
        case .water: "drop.fill"
        case .weight: "scalemass.fill"
        case .sleep: "bed.double.fill"
        case .mood: "face.smiling"
        case .workout: "dumbbell.fill"
        case .unknown: "questionmark.circle"
        }
    }

    private var confirmBar: some View {
        let n = drafts.filter { $0.kind != .unknown }.count
        return Button {
            speech.stop()
            let result = AssistantParser.commit(drafts, in: context)
            withAnimation(.spring) { done = result; drafts = []; text = "" }
            if drafts.contains(where: { $0.kind == .workout }) || result.contains("treino aberto") { dismiss() }
        } label: {
            Label("Registrar \(n) \(n == 1 ? "item" : "itens")", systemImage: "checkmark.circle.fill")
                .font(.headline).foregroundStyle(.white).frame(maxWidth: .infinity).padding()
                .background(Theme.gradient, in: Capsule())
        }
        .buttonStyle(PressableStyle())
        .padding(.horizontal).padding(.bottom, 8)
    }
}
