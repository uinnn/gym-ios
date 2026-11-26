import SwiftUI
import SwiftData

// MARK: - Campo numérico que grava enquanto você digita

/// O `TextField(value:format:)` só grava ao sair do campo; este grava a cada tecla,
/// então nada se perde se o app for fechado ou o celular bloquear no meio da digitação.
struct LiveNumberField: View {
    @Binding var value: Double
    var integer = false
    var placeholder = "0"
    @State private var text = ""

    private static let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = .current
        f.usesGroupingSeparator = false
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 2
        return f
    }()

    var body: some View {
        TextField(placeholder, text: $text)
            .keyboardType(integer ? .numberPad : .decimalPad)
            .multilineTextAlignment(.center)
            .onAppear { text = Self.format(value, integer: integer) }
            .onChange(of: text) { _, t in
                let v = Self.parse(t) ?? 0
                if v != value { value = integer ? v.rounded() : v }
            }
            .onChange(of: value) { _, v in
                if (Self.parse(text) ?? 0) != v { text = Self.format(v, integer: integer) }
            }
    }

    static func format(_ v: Double, integer: Bool) -> String {
        guard v != 0 else { return "" }
        return integer ? "\(Int(v))" : (formatter.string(from: NSNumber(value: v)) ?? "\(v)")
    }

    static func parse(_ t: String) -> Double? {
        let s = t.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        return s.isEmpty ? nil : Double(s)
    }
}

/// Versão inteira (repetições).
struct LiveIntField: View {
    @Binding var value: Int
    var body: some View {
        LiveNumberField(value: Binding(get: { Double(value) }, set: { value = max(0, Int($0)) }), integer: true)
    }
}

// MARK: - Desfazer

/// O que foi apagado por último no treino (para o botão "Desfazer").
enum WorkoutUndo: Equatable {
    case set(exercise: UUID, index: Int, set: SetLog)
    case exercise(index: Int, exercise: SessionExercise)

    var label: String {
        switch self {
        case .set: "Série apagada"
        case .exercise(_, let e): "\(e.exercise?.name ?? "Exercício") removido"
        }
    }
}

struct UndoBanner: View {
    let text: String
    var undo: () -> Void
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "trash").foregroundStyle(.secondary)
            Text(text).font(.subheadline.bold()).lineLimit(1)
            Spacer()
            Button("Desfazer", action: undo).font(.subheadline.bold()).buttonStyle(.borderedProminent).tint(Theme.accent)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(.ultraThickMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.2), radius: 10, y: 4)
        .padding(.horizontal)
    }
}

// MARK: - Editar um treino já terminado

struct SessionEditorView: View {
    @Bindable var session: WorkoutSession
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var exercises: [SessionExercise] = []
    @State private var name = ""
    @State private var start = Date.now
    @State private var minutes: Double = 60
    @State private var note = ""
    @State private var rating = 0
    @State private var showPicker = false
    @State private var editMode: EditMode = .inactive

    var body: some View {
        NavigationStack {
            List {
                Section("Treino") {
                    TextField("Nome", text: $name)
                    DatePicker("Início", selection: $start)
                    HStack {
                        Text("Duração")
                        Spacer()
                        LiveNumberField(value: $minutes, integer: true).frame(width: 70)
                            .padding(.vertical, 6).background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
                        Text("min").foregroundStyle(.secondary)
                    }
                    Picker("Como se sentiu", selection: $rating) {
                        Text("—").tag(0)
                        ForEach(1...5, id: \.self) { Text(["😫", "😕", "🙂", "😃", "🔥"][$0 - 1]).tag($0) }
                    }
                    TextField("Anotações", text: $note, axis: .vertical).lineLimit(1...4)
                }
                ForEach($exercises) { $e in
                    Section {
                        ForEach($e.sets) { $s in setRow($s, cardio: e.exercise?.kind == .cardio || e.exercise?.kind == .timed, index: e.sets.firstIndex { $0.id == s.id } ?? 0) }
                            .onDelete { e.sets.remove(atOffsets: $0) }
                            .onMove { e.sets.move(fromOffsets: $0, toOffset: $1) }
                        Button {
                            var n = e.sets.last ?? SetLog()
                            n.id = UUID(); n.kind = .normal; n.done = true
                            withAnimation { e.sets.append(n) }
                        } label: { Label("Adicionar série", systemImage: "plus") }
                    } header: {
                        HStack {
                            Text(e.exercise?.name ?? e.exerciseID)
                            Spacer()
                            Button(role: .destructive) { withAnimation { exercises.removeAll { $0.id == e.id } } } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
                .onMove { exercises.move(fromOffsets: $0, toOffset: $1) }
                Section {
                    Button { showPicker = true } label: { Label("Adicionar exercício", systemImage: "plus.circle.fill") }
                } footer: {
                    Text("Deslize uma série para a esquerda para apagar. Toque em Organizar para reordenar séries e exercícios.")
                }
            }
            .environment(\.editMode, $editMode)
            .navigationTitle("Editar treino")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Salvar") { save() }.bold() }
                ToolbarItem(placement: .bottomBar) {
                    Button(editMode.isEditing ? "Concluir" : "Organizar") { withAnimation { editMode = editMode.isEditing ? .inactive : .active } }
                }
            }
            .sheet(isPresented: $showPicker) {
                ExercisePickerView(single: false) { picked in
                    withAnimation {
                        exercises += picked.map { x in
                            SessionExercise(exerciseID: x.id, sets: (0..<3).map { _ in var s = SetLog(); s.done = true; return s })
                        }
                    }
                }
            }
            .onAppear {
                exercises = session.exercises
                name = session.name
                start = session.start
                minutes = ((session.end ?? .now).timeIntervalSince(session.start) / 60).rounded()
                note = session.note
                rating = session.rating
            }
        }
    }

    private func setRow(_ s: Binding<SetLog>, cardio: Bool, index: Int) -> some View {
        HStack(spacing: 10) {
            Menu {
                ForEach(SetKind.allCases, id: \.self) { k in Button(k.label) { s.wrappedValue.kind = k } }
            } label: {
                Text(s.wrappedValue.kind == .normal ? "\(index + 1)" : s.wrappedValue.kind.short)
                    .font(.subheadline.bold()).frame(width: 28, alignment: .leading)
                    .foregroundStyle(s.wrappedValue.kind == .warmup ? Theme.warm : (s.wrappedValue.kind == .normal ? .primary : Theme.excellent))
            }
            Spacer()
            if cardio {
                cell(LiveNumberField(value: s.minutes), "min")
                cell(LiveNumberField(value: s.km), "km")
            } else {
                cell(LiveNumberField(value: s.kg), "kg")
                Text("×").foregroundStyle(.secondary)
                cell(LiveIntField(value: s.reps), "reps")
            }
        }
    }

    private func cell<V: View>(_ field: V, _ unit: String) -> some View {
        HStack(spacing: 4) {
            field.frame(width: 62).padding(.vertical, 6).background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
            Text(unit).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func save() {
        var cleaned = exercises
        for i in cleaned.indices { cleaned[i].sets = cleaned[i].sets.map { var x = $0; x.done = true; return x } }
        cleaned.removeAll { $0.sets.isEmpty }
        session.exercises = cleaned
        session.name = name.isEmpty ? "Treino" : name
        session.start = start
        session.end = start.addingTimeInterval(max(1, minutes) * 60)
        session.note = note
        session.rating = rating
        try? context.save()
        dismiss()
    }
}
