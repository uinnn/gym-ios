import SwiftUI
import SwiftData
import UserNotifications

// MARK: - 1. Desfazer em tudo

/// Aviso "Desfazer" que aparece por alguns segundos depois de apagar, editar ou adicionar algo.
/// Usa o UndoManager do SwiftData: o desfazer reverte exatamente o que foi gravado (inclusive edições).
@MainActor @Observable
final class UndoCenter {
    static let shared = UndoCenter()
    private(set) var message: String?
    private(set) var token = 0
    @ObservationIgnored private var undo: (() -> Void)?
    @ObservationIgnored private var hideTask: Task<Void, Never>?

    func show(_ text: String, undo: @escaping () -> Void) {
        message = text
        self.undo = undo
        token &+= 1
        let t = token
        hideTask?.cancel()
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled, self?.token == t else { return }
            self?.dismiss()
        }
    }

    /// Registra a ação no UndoManager do contexto e mostra o aviso.
    func offer(_ text: String, in context: ModelContext) {
        if context.undoManager == nil { UndoCenter.enable(context) }
        show(text) { [weak context] in
            guard let um = context?.undoManager, um.canUndo else { return }
            um.undo()
        }
    }

    func perform() {
        withAnimation(.snappy) { undo?() }
        dismiss()
    }

    func dismiss() {
        hideTask?.cancel()
        undo = nil
        withAnimation(.snappy) { message = nil }
    }

    static func enable(_ context: ModelContext) {
        guard context.undoManager == nil else { return }
        let um = UndoManager()
        um.levelsOfUndo = 15          // memória limitada
        context.undoManager = um
    }
}

@MainActor
extension ModelContext {
    /// Apaga e oferece "Desfazer" por 5 s.
    func deleteUndoable<T: PersistentModel>(_ model: T, _ label: String = "Apagado") {
        UndoCenter.enable(self)
        undoManager?.beginUndoGrouping()
        delete(model)
        undoManager?.endUndoGrouping()
        UndoCenter.shared.offer(label, in: self)
    }

    /// Executa um bloco de alterações como um único passo desfazível.
    func undoable(_ label: String, _ changes: () -> Void) {
        UndoCenter.enable(self)
        undoManager?.beginUndoGrouping()
        changes()
        undoManager?.endUndoGrouping()
        UndoCenter.shared.offer(label, in: self)
    }
}

struct UndoToastModifier: ViewModifier {
    @Environment(\.modelContext) private var context
    @State private var center = UndoCenter.shared

    func body(content: Content) -> some View {
        content
            .onAppear { UndoCenter.enable(context) }
            .overlay(alignment: .bottom) {
                if let msg = center.message {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.uturn.backward.circle.fill").foregroundStyle(Theme.accent)
                        Text(msg).font(.subheadline.weight(.medium)).lineLimit(2)
                        Spacer(minLength: 4)
                        Button("Desfazer") { center.perform() }
                            .font(.subheadline.bold())
                            .buttonStyle(.tap)
                            .foregroundStyle(Theme.accent)
                    }
                    .padding(.leading, 16).padding(.trailing, 8)
                    .background(.ultraThickMaterial, in: Capsule())
                    .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
                    .padding(.horizontal)
                    .padding(.bottom, 58)       // acima da barra de abas
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .gesture(DragGesture().onEnded { if $0.translation.height > 10 { center.dismiss() } })
                    .id(center.token)
                }
            }
            .animation(.snappy, value: center.token)
    }
}

extension View {
    func undoToast() -> some View { modifier(UndoToastModifier()) }
}

// MARK: - 5. Lembretes inteligentes

/// Avisa só quando falta o registro, no horário em que você costuma fazê-lo (mediana dos últimos 21 dias).
/// Reagendado sempre que o app vai para segundo plano — então nunca avisa algo que você já registrou.
enum SmartReminders {
    static var enabled: Bool {
        get { UserDefaults.standard.bool(forKey: "smartReminders") }
        set { UserDefaults.standard.set(newValue, forKey: "smartReminders") }
    }
    private static let prefix = "smart-"
    private static let mainMeals: [Meal] = [.breakfast, .lunch, .dinner]

    static func requestAndEnable() async -> Bool {
        let ok = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
        enabled = ok
        return ok
    }

    @MainActor
    static func reschedule(context: ModelContext) {
        let c = UNUserNotificationCenter.current()
        c.getPendingNotificationRequests { reqs in
            let ids = reqs.map(\.identifier).filter { $0.hasPrefix(prefix) }
            c.removePendingNotificationRequests(withIdentifiers: ids)
        }
        guard enabled else { return }
        let cal = Calendar.current
        let now = Date.now
        let today = cal.startOfDay(for: now)
        guard let since = cal.date(byAdding: .day, value: -21, to: today) else { return }

        // Refeições: só o necessário (data e refeição) do período.
        var mealDesc = FetchDescriptor<FoodLog>(predicate: #Predicate { $0.date >= since })
        mealDesc.propertiesToFetch = [\.date, \.mealRaw]
        let logs = (try? context.fetch(mealDesc)) ?? []
        var minutes: [String: [Int]] = [:]
        var loggedToday = Set<String>()
        for l in logs {
            if l.date >= today { loggedToday.insert(l.mealRaw); continue }
            let m = cal.component(.hour, from: l.date) * 60 + cal.component(.minute, from: l.date)
            minutes[l.mealRaw, default: []].append(m)
        }
        for meal in mainMeals where !loggedToday.contains(meal.rawValue) {
            guard let list = minutes[meal.rawValue], list.count >= 5 else { continue }   // hábito real
            let median = list.sorted()[list.count / 2] + 45                              // folga de 45 min
            schedule(c, id: "meal-\(meal.rawValue)", minuteOfDay: median, now: now,
                     title: "\(meal.label) não registrado",
                     body: "Você costuma registrar por volta deste horário. Toque para anotar em segundos.")
        }

        // Pesagem: costuma pesar e ainda não pesou hoje.
        var wDesc = FetchDescriptor<WeightEntry>(predicate: #Predicate { $0.date >= since })
        wDesc.propertiesToFetch = [\.date]
        let ws = (try? context.fetch(wDesc)) ?? []
        if !ws.contains(where: { $0.date >= today }) {
            let past = ws.map { cal.component(.hour, from: $0.date) * 60 + cal.component(.minute, from: $0.date) }
            if past.count >= 7 {
                let median = past.sorted()[past.count / 2] + 60
                schedule(c, id: "weigh", minuteOfDay: median, now: now,
                         title: "Hora da pesagem ⚖️", body: "Ainda não há pesagem hoje. Suba na balança com o app aberto.")
            }
        }
    }

    private static func schedule(_ c: UNUserNotificationCenter, id: String, minuteOfDay: Int, now: Date, title: String, body: String) {
        let cal = Calendar.current
        guard let at = cal.date(bySettingHour: min(minuteOfDay / 60, 23), minute: minuteOfDay % 60, second: 0, of: now),
              at > now else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: at)
        c.add(UNNotificationRequest(identifier: prefix + id, content: content,
                                    trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)))
    }
}

// MARK: - 3. Registro rápido por texto

/// Campo no topo do diário: "2 ovos e 1 pão no café" → registra na hora (com Desfazer).
struct QuickLogBar: View {
    let day: Date
    @Environment(\.modelContext) private var context
    @Query private var saved: [SavedFood]
    @State private var text = ""
    @State private var feedback: String?
    @FocusState private var focused: Bool

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "text.bubble.fill").foregroundStyle(Theme.accent)
                    TextField("Ex.: 2 ovos e 1 pão no café", text: $text)
                        .focused($focused)
                        .submitLabel(.done)
                        .onSubmit(submit)
                        .frame(minHeight: 44)
                    if !text.isEmpty {
                        Button { submit() } label: {
                            Image(systemName: "arrow.up.circle.fill").font(.title2).foregroundStyle(Theme.gradient)
                        }
                        .buttonStyle(.tap)
                        .accessibilityLabel("Registrar")
                    }
                }
                if let feedback {
                    Text(feedback).font(.caption).foregroundStyle(.secondary).transition(.opacity)
                }
            }
        }
    }

    private func submit() {
        let raw = text.trimmingCharacters(in: .whitespaces)
        guard !raw.isEmpty else { return }
        let cal = Calendar.current
        let since = cal.date(byAdding: .day, value: -14, to: day) ?? day
        var d = FetchDescriptor<FoodLog>(predicate: #Predicate { $0.date >= since }, sortBy: [SortDescriptor(\.date)])
        d.fetchLimit = 400
        let data = AssistantData(saved: saved, logs: (try? context.fetch(d)) ?? [])
        var drafts = AssistantParser.parse(raw, data: data).filter { $0.kind == .food && $0.food != nil }
        guard !drafts.isEmpty else {
            withAnimation { feedback = "Não entendi. Tente “150 g de arroz” ou “2 ovos no almoço”." }
            return
        }
        // Refeição: a dita ou a do horário (o interpretador decide); dia = o aberto no diário.
        if !cal.isDateInToday(day) { for i in drafts.indices { drafts[i].date = day } }
        UndoCenter.enable(context)
        context.undoManager?.beginUndoGrouping()
        let done = AssistantParser.commit(drafts, data: data, in: context)
        context.undoManager?.endUndoGrouping()
        UndoCenter.shared.offer("Registrado: " + done.joined(separator: ", "), in: context)
        withAnimation { text = ""; feedback = nil }
        focused = false
    }
}
