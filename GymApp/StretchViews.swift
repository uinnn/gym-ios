import SwiftUI
import SwiftData

// MARK: - Preferências e histórico (por perfil)

struct StretchLog: Codable, Hashable {
    var date: Date
    var seconds: Int
    var name: String
    var count: Int
}

@Observable
@MainActor
final class StretchStore {
    static let shared = StretchStore()
    private let d = UserDefaults.standard
    private var pid: String { ProfileRegistry.shared.activeID }
    private func key(_ k: String) -> String { "stretch.\(pid).\(k)" }

    var conditions: Set<BodyCondition> {
        get { _ = version; return Set((d.stringArray(forKey: key("cond")) ?? []).compactMap(BodyCondition.init)) }
        set { d.set(newValue.map(\.rawValue), forKey: key("cond")); version += 1 }
    }
    var history: [StretchLog] {
        get { _ = version; return d.data(forKey: key("hist")).flatMap { try? JSONDecoder().decode([StretchLog].self, from: $0) } ?? [] }
        set { d.set(try? JSONEncoder().encode(Array(newValue.suffix(300))), forKey: key("hist")); version += 1 }
    }
    var custom: [StretchRoutine] {
        get { _ = version; return d.data(forKey: key("custom")).flatMap { try? JSONDecoder().decode([StretchRoutine].self, from: $0) } ?? [] }
        set { d.set(try? JSONEncoder().encode(newValue), forKey: key("custom")); version += 1 }
    }
    var favorites: Set<String> {
        get { _ = version; return Set(d.stringArray(forKey: key("fav")) ?? []) }
        set { d.set(Array(newValue), forKey: key("fav")); version += 1 }
    }
    /// Força a tela a atualizar quando algo muda (os valores moram no UserDefaults).
    private var version = 0

    func log(_ name: String, seconds: Int, count: Int) {
        history.append(StretchLog(date: .now, seconds: seconds, name: name, count: count))
    }

    var weekMinutes: Int {
        let start = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
        return history.filter { $0.date >= start }.map(\.seconds).reduce(0, +) / 60
    }

    /// Dias seguidos com pelo menos uma sessão.
    var streak: Int {
        let cal = Calendar.current
        let days = Set(history.map { cal.startOfDay(for: $0.date) })
        var day = cal.startOfDay(for: .now)
        if !days.contains(day) { day = cal.date(byAdding: .day, value: -1, to: day) ?? day }
        var n = 0
        while days.contains(day) { n += 1; day = cal.date(byAdding: .day, value: -1, to: day) ?? day }
        return n
    }
}

// MARK: - Recomendação

enum StretchCoach {
    struct Pick { let stretch: Stretch; let reasons: [String] }

    /// Monta uma rotina personalizada: condições marcadas pesam mais; músculos treinados nas últimas 36 h entram também.
    static func recommend(conditions: Set<BodyCondition>, trained: [Muscle], minutes: Int, focus: StretchFocus) -> [Pick] {
        let trainedAreas = Set(trained.flatMap(StretchCatalog.areas(for:)))
        var scored: [(Stretch, Double, [String])] = StretchCatalog.all.map { s in
            var score = 0.0
            var why: [String] = []
            for c in s.helps where conditions.contains(c) {
                score += c.group == .posture || c.group == .pain ? 3 : 2
                why.append(c.title)
            }
            if !trainedAreas.isDisjoint(with: s.areas) && s.kind == .stretch { score += 1.5; why.append("músculos treinados") }
            switch focus {
            case .warmup: score += s.kind == .mobility ? 3 : (s.kind == .activation ? 1 : -3)
            case .cooldown: score += s.kind == .stretch ? 2 : (s.kind == .release ? 1.5 : -2)
            case .relax: score += s.kind == .release ? 3 : (s.kind == .stretch ? 1 : -3)
            case .correct: score += s.kind == .activation ? 1.5 : 0
            case .balanced: break
            }
            if s.level == 3 { score -= 1 }
            score += Double(s.helps.count) * 0.05   // desempate: os mais versáteis
            return (s, score, why)
        }
        scored.sort { $0.1 > $1.1 }
        let budget = minutes * 60
        var used = 0, perArea: [StretchArea: Int] = [:]
        var out: [Pick] = []
        for (s, score, why) in scored where score > 0 {
            guard used + s.totalSeconds <= budget + 20 else { continue }
            let main = s.areas.first ?? .fullBody
            guard perArea[main, default: 0] < 2 else { continue }
            perArea[main, default: 0] += 1
            used += s.totalSeconds
            out.append(Pick(stretch: s, reasons: Array(why.prefix(3))))
            if used >= budget { break }
        }
        // Sem condições marcadas: completa com uma rotina geral equilibrada.
        if out.isEmpty {
            out = (StretchRoutine.presets.first { $0.id == (focus == .warmup ? "warmup" : focus == .relax ? "sleep" : "cooldown") }?.stretches ?? [])
                .map { Pick(stretch: $0, reasons: []) }
        }
        return out.sorted { $0.stretch.kind.order < $1.stretch.kind.order }
    }
}

enum StretchFocus: String, CaseIterable, Identifiable {
    case balanced = "Equilibrado", correct = "Corrigir postura", warmup = "Aquecer", cooldown = "Pós-treino", relax = "Relaxar"
    var id: String { rawValue }
}

// MARK: - Tela principal

struct StretchHomeView: View {
    @Query(sort: \WorkoutSession.start, order: .reverse) private var sessions: [WorkoutSession]
    @State private var store = StretchStore.shared
    @State private var showConditions = false
    @State private var focus: StretchFocus = .balanced
    @State private var minutes = 10
    @State private var play: StretchRoutine?
    @State private var builder: StretchRoutine?
    @State private var query = ""
    @State private var area: StretchArea?

    private var trained: [Muscle] {
        let since = Date.now.addingTimeInterval(-36 * 3600)
        return Array(WorkoutMath.muscleSets(sessions.filter { !$0.isActive && $0.start >= since }).filter { $0.value >= 2 }.keys)
    }

    var body: some View {
        let picks = StretchCoach.recommend(conditions: store.conditions, trained: trained, minutes: minutes, focus: focus)
        ScrollView {
            VStack(spacing: 16) {
                statsCard
                conditionsCard
                recommendedCard(picks)
                SectionHeader(title: "Rotinas prontas", icon: "square.grid.2x2.fill")
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(StretchRoutine.presets) { r in routineTile(r) }
                }
                customSection
                librarySection
            }
            .padding()
        }
        .background(AnimatedBackground())
        .navigationTitle("Alongamentos")
        .sheet(isPresented: $showConditions) { ConditionsSheet() }
        .sheet(item: $builder) { r in RoutineBuilderSheet(routine: r) }
        .fullScreenCover(item: $play) { r in StretchPlayerView(routine: r) }
    }

    private var statsCard: some View {
        Card {
            HStack {
                stat("\(store.weekMinutes)", "min nos últimos 7 dias", "clock.fill")
                Divider().frame(height: 40)
                stat("\(store.streak)", store.streak == 1 ? "dia seguido" : "dias seguidos", "flame.fill")
                Divider().frame(height: 40)
                stat("\(store.history.count)", "sessões no total", "checkmark.seal.fill")
            }
        }
    }

    private func stat(_ v: String, _ l: String, _ icon: String) -> some View {
        VStack(spacing: 2) {
            Image(systemName: icon).foregroundStyle(Theme.accent)
            Text(v).font(.title2.bold()).contentTransition(.numericText())
            Text(l).font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var conditionsCard: some View {
        Button { showConditions = true } label: {
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label("O que você tem ou quer melhorar", systemImage: "person.fill.questionmark").font(.headline).foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(.secondary)
                    }
                    if store.conditions.isEmpty {
                        Text("Marque coisas como ombros protusos, escoliose, dor lombar ou posterior encurtado. As recomendações passam a ser feitas para você.")
                            .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.leading)
                    } else {
                        FlowChips(items: store.conditions.sorted { $0.title < $1.title }.map(\.title))
                    }
                }
            }
        }
        .buttonStyle(PressableStyle())
    }

    private func recommendedCard(_ picks: [StretchCoach.Pick]) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Label("Recomendado para você", systemImage: "wand.and.stars").font(.headline)
                Picker("Foco", selection: $focus) { ForEach(StretchFocus.allCases) { Text($0.rawValue).tag($0) } }
                    .pickerStyle(.segmented)
                Picker("Duração", selection: $minutes) {
                    ForEach([5, 10, 15, 20, 30], id: \.self) { Text("\($0) min").tag($0) }
                }
                .pickerStyle(.segmented)
                if !trained.isEmpty {
                    Label("Inclui o que você treinou recentemente: \(trained.map(\.label).joined(separator: ", "))", systemImage: "dumbbell.fill")
                        .font(.caption).foregroundStyle(.secondary)
                }
                ForEach(picks, id: \.stretch.id) { p in
                    NavigationLink { StretchDetailView(stretch: p.stretch) } label: {
                        HStack(alignment: .top, spacing: 10) {
                            kindIcon(p.stretch.kind)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(p.stretch.name).font(.subheadline.bold()).foregroundStyle(.primary).multilineTextAlignment(.leading)
                                Text(p.reasons.isEmpty ? p.stretch.kind.label : "Para: " + p.reasons.joined(separator: ", "))
                                    .font(.caption).foregroundStyle(.secondary).lineLimit(2).multilineTextAlignment(.leading)
                            }
                            Spacer()
                            Text(duration(p.stretch)).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        }
                    }
                }
                HStack {
                    Button {
                        play = StretchRoutine(id: "rec", name: "Recomendado para você", icon: "wand.and.stars", subtitle: "", ids: picks.map(\.stretch.id))
                    } label: {
                        Label("Começar (\(max(1, picks.map(\.stretch.totalSeconds).reduce(0, +) / 60)) min)", systemImage: "play.fill")
                            .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 12)
                            .foregroundStyle(.white).background(Theme.gradient, in: Capsule())
                    }
                    .buttonStyle(PressableStyle())
                    .disabled(picks.isEmpty)
                    Button {
                        builder = StretchRoutine(id: UUID().uuidString, name: "Minha rotina", icon: "star.fill", subtitle: "", ids: picks.map(\.stretch.id), custom: true)
                    } label: {
                        Image(systemName: "square.and.arrow.down").font(.headline).padding(12).background(.quaternary, in: Circle())
                    }
                    .accessibilityLabel("Salvar como rotina")
                }
            }
        }
    }

    private func routineTile(_ r: StretchRoutine) -> some View {
        Button { play = r } label: {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: r.icon).font(.title2).foregroundStyle(Theme.gradient)
                Text(r.name).font(.subheadline.bold()).foregroundStyle(.primary).multilineTextAlignment(.leading)
                Text(r.subtitle).font(.caption2).foregroundStyle(.secondary).lineLimit(2, reservesSpace: true).multilineTextAlignment(.leading)
                Label("\(r.minutes) min · \(r.ids.count)", systemImage: "play.circle.fill").font(.caption.bold()).foregroundStyle(Theme.accent)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(PressableStyle())
        .contextMenu {
            Button { builder = StretchRoutine(id: UUID().uuidString, name: r.name + " (minha)", icon: "star.fill", subtitle: "", ids: r.ids, custom: true) } label: {
                Label("Duplicar e editar", systemImage: "square.on.square")
            }
        }
    }

    private var customSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionHeader(title: "Minhas rotinas", icon: "star.fill")
                Spacer()
                Button {
                    builder = StretchRoutine(id: UUID().uuidString, name: "Minha rotina", icon: "star.fill", subtitle: "", ids: [], custom: true)
                } label: { Label("Criar", systemImage: "plus.circle.fill").font(.subheadline.bold()) }
            }
            if store.custom.isEmpty {
                Text("Monte uma rotina com os alongamentos que você preferir.").font(.caption).foregroundStyle(.secondary)
            }
            ForEach(store.custom) { r in
                Card {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(r.name).font(.subheadline.bold())
                            Text("\(r.ids.count) alongamentos · \(r.minutes) min").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button { builder = r } label: { Image(systemName: "pencil") }.buttonStyle(.bordered).buttonBorderShape(.circle)
                        Button { play = r } label: { Image(systemName: "play.fill") }.buttonStyle(.borderedProminent).buttonBorderShape(.circle)
                    }
                }
            }
        }
    }

    private var librarySection: some View {
        let list = StretchCatalog.all.filter { s in
            (area == nil || s.areas.contains(area!)) &&
            (query.isEmpty || AssistantParser.norm(s.name).contains(AssistantParser.norm(query)))
        }
        return VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Biblioteca (\(StretchCatalog.all.count))", icon: "books.vertical.fill")
            TextField("Buscar alongamento", text: $query).textFieldStyle(.roundedBorder)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    chip("Todos", area == nil) { area = nil }
                    ForEach(StretchArea.allCases) { a in chip(a.rawValue, area == a) { area = a } }
                }
            }
            ForEach(list) { s in
                NavigationLink { StretchDetailView(stretch: s) } label: {
                    HStack(spacing: 10) {
                        kindIcon(s.kind)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(s.name).font(.subheadline.bold()).foregroundStyle(.primary).multilineTextAlignment(.leading)
                            Text(s.areas.map(\.rawValue).joined(separator: " · ")).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if store.favorites.contains(s.id) { Image(systemName: "star.fill").foregroundStyle(.yellow).font(.caption) }
                        Text(duration(s)).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    }
                    .padding(10)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                }
            }
        }
    }

    private func chip(_ t: String, _ on: Bool, _ a: @escaping () -> Void) -> some View {
        Button { withAnimation { a() } } label: {
            Text(t).font(.caption.bold()).padding(.horizontal, 10).padding(.vertical, 6)
                .foregroundStyle(on ? .white : .primary)
                .background(on ? AnyShapeStyle(Theme.gradient) : AnyShapeStyle(.quaternary), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

func kindIcon(_ k: StretchKind) -> some View {
    let (icon, color): (String, Color) = switch k {
    case .mobility: ("arrow.triangle.2.circlepath", .orange)
    case .stretch: ("figure.flexibility", .blue)
    case .activation: ("bolt.fill", .green)
    case .release: ("leaf.fill", .purple)
    }
    return Image(systemName: icon).font(.subheadline).foregroundStyle(color).frame(width: 30, height: 30)
        .background(color.opacity(0.15), in: Circle())
}

func duration(_ s: Stretch) -> String {
    s.perSide ? "\(s.seconds)s × 2" : "\(s.seconds)s"
}

/// Chips que quebram linha.
struct FlowChips: View {
    let items: [String]
    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(items, id: \.self) { t in
                Text(t).font(.caption.bold()).padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Theme.accent.opacity(0.15), in: Capsule()).foregroundStyle(Theme.accent)
            }
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 6
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let w = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, row: CGFloat = 0, maxX: CGFloat = 0
        for s in subviews {
            let z = s.sizeThatFits(.unspecified)
            if x + z.width > w && x > 0 { x = 0; y += row + spacing; row = 0 }
            x += z.width + spacing; row = max(row, z.height); maxX = max(maxX, x)
        }
        return CGSize(width: min(maxX, w), height: y + row)
    }
    func placeSubviews(in b: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = b.minX, y = b.minY, row: CGFloat = 0
        for s in subviews {
            let z = s.sizeThatFits(.unspecified)
            if x + z.width > b.maxX && x > b.minX { x = b.minX; y += row + spacing; row = 0 }
            s.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(z))
            x += z.width + spacing; row = max(row, z.height)
        }
    }
}

// MARK: - Condições

struct ConditionsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var store = StretchStore.shared
    @State private var selected = StretchStore.shared.conditions

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Marque o que você tem, sente ou quer conquistar. Dor forte, formigamento ou lesão: procure um médico ou fisioterapeuta antes.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                ForEach(ConditionGroup.allCases) { g in
                    Section {
                        ForEach(BodyCondition.allCases.filter { $0.group == g }) { c in
                            Button {
                                if selected.contains(c) { selected.remove(c) } else { selected.insert(c) }
                            } label: {
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: selected.contains(c) ? "checkmark.circle.fill" : "circle")
                                        .font(.title3).foregroundStyle(selected.contains(c) ? Theme.accent : .secondary)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(c.title).font(.subheadline.bold()).foregroundStyle(.primary)
                                        Text(c.detail).font(.caption).foregroundStyle(.secondary)
                                        Text("\(StretchCatalog.all.filter { $0.helps.contains(c) }.count) exercícios ajudam")
                                            .font(.caption2).foregroundStyle(Theme.accent)
                                    }
                                }
                            }
                        }
                    } header: { Label(g.rawValue, systemImage: g.icon) }
                }
            }
            .navigationTitle("Suas condições (\(selected.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Limpar") { selected = [] } }
                ToolbarItem(placement: .confirmationAction) { Button("Salvar") { store.conditions = selected; dismiss() }.bold() }
            }
            .sensoryFeedback(.selection, trigger: selected.count)
        }
    }
}

// MARK: - Detalhe

struct StretchDetailView: View {
    let stretch: Stretch
    @State private var store = StretchStore.shared
    @State private var play: StretchRoutine?

    var body: some View {
        let s = stretch
        List {
            Section {
                HStack(spacing: 12) {
                    kindIcon(s.kind)
                    VStack(alignment: .leading) {
                        Text(s.kind.label).font(.subheadline.bold())
                        Text("\(duration(s)) · nível \(["", "fácil", "médio", "avançado"][s.level])").font(.caption).foregroundStyle(.secondary)
                    }
                }
                LabeledContent("Áreas", value: s.areas.map(\.rawValue).joined(separator: ", "))
            }
            Section("Como fazer") {
                ForEach(Array(s.steps.enumerated()), id: \.offset) { i, t in
                    HStack(alignment: .top) {
                        Text("\(i + 1)").font(.caption.bold()).foregroundStyle(.white).frame(width: 22, height: 22)
                            .background(Theme.accent, in: Circle())
                        Text(t).font(.subheadline)
                    }
                }
            }
            Section("Dica") { Label(s.tip, systemImage: "lightbulb.fill").font(.subheadline) }
            if !s.helps.isEmpty {
                Section("Ajuda em") {
                    ForEach(s.helps) { c in
                        HStack {
                            Text(c.title).font(.subheadline)
                            Spacer()
                            if store.conditions.contains(c) { Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent) }
                        }
                    }
                }
            }
            Section {
                Text("Alongue até sentir tensão confortável, nunca dor. Respire devagar e não faça \"molinhas\" nos estáticos.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .navigationTitle(s.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button {
                var f = store.favorites
                if f.contains(s.id) { f.remove(s.id) } else { f.insert(s.id) }
                store.favorites = f
            } label: { Image(systemName: store.favorites.contains(s.id) ? "star.fill" : "star") }
            Button { play = StretchRoutine(id: "one-\(s.id)", name: s.name, icon: "play", subtitle: "", ids: [s.id]) } label: {
                Image(systemName: "play.fill")
            }
        }
        .fullScreenCover(item: $play) { StretchPlayerView(routine: $0) }
    }
}

// MARK: - Montar rotina

struct RoutineBuilderSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State var routine: StretchRoutine
    @State private var store = StretchStore.shared
    @State private var query = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Nome da rotina", text: $routine.name)
                    LabeledContent("Duração", value: "\(routine.minutes) min")
                }
                Section("Na rotina (arraste para ordenar)") {
                    if routine.ids.isEmpty { Text("Toque nos alongamentos abaixo para adicionar.").font(.caption).foregroundStyle(.secondary) }
                    ForEach(routine.ids, id: \.self) { id in
                        if let s = StretchCatalog.byID[id] {
                            HStack { kindIcon(s.kind); Text(s.name).font(.subheadline); Spacer(); Text(duration(s)).font(.caption).foregroundStyle(.secondary) }
                        }
                    }
                    .onMove { routine.ids.move(fromOffsets: $0, toOffset: $1) }
                    .onDelete { routine.ids.remove(atOffsets: $0) }
                }
                Section("Adicionar") {
                    TextField("Buscar", text: $query)
                    ForEach(StretchCatalog.all.filter { !routine.ids.contains($0.id) && (query.isEmpty || AssistantParser.norm($0.name).contains(AssistantParser.norm(query))) }) { s in
                        Button { withAnimation { routine.ids.append(s.id) } } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill").foregroundStyle(Theme.accent)
                                Text(s.name).font(.subheadline).foregroundStyle(.primary)
                                Spacer()
                                Text(s.areas.first?.rawValue ?? "").font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                if store.custom.contains(where: { $0.id == routine.id }) {
                    Section {
                        Button("Apagar rotina", role: .destructive) {
                            store.custom.removeAll { $0.id == routine.id }
                            dismiss()
                        }
                    }
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Montar rotina")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        var list = store.custom
                        if let i = list.firstIndex(where: { $0.id == routine.id }) { list[i] = routine } else { list.append(routine) }
                        store.custom = list
                        dismiss()
                    }
                    .bold().disabled(routine.ids.isEmpty || routine.name.isEmpty)
                }
            }
        }
    }
}

// MARK: - Player guiado

struct StretchPlayerView: View {
    let routine: StretchRoutine
    @Environment(\.dismiss) private var dismiss
    @State private var steps: [(Stretch, String?)] = []
    @State private var index = 0
    @State private var left = 0
    @State private var paused = false
    @State private var prep = 5
    @State private var finished = false
    @State private var elapsed = 0

    var body: some View {
        ZStack {
            AnimatedBackground()
            if finished { doneView } else if steps.indices.contains(index) { stepView(steps[index]) }
        }
        .onAppear {
            steps = routine.stretches.flatMap { s in s.perSide ? [(s, "Lado esquerdo"), (s, "Lado direito")] : [(s, nil)] }
            start(0)
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                tick()
            }
        }
        .sensoryFeedback(.impact(weight: .heavy), trigger: index) { _, _ in ThemeStore.shared.haptics }
        .sensoryFeedback(.success, trigger: finished) { _, f in f && ThemeStore.shared.haptics }
    }

    private func start(_ i: Int) {
        index = i
        prep = i == 0 ? 5 : 3
        left = steps.indices.contains(i) ? steps[i].0.seconds : 0
    }

    private func tick() {
        guard !paused, !finished, steps.indices.contains(index) else { return }
        if prep > 0 { prep -= 1; return }
        elapsed += 1
        if left > 1 { left -= 1 } else { next() }
    }

    private func next() {
        if index + 1 < steps.count { withAnimation(.spring) { start(index + 1) } } else { finish() }
    }

    private func finish() {
        withAnimation(.spring) { finished = true }
        if elapsed >= 30 { StretchStore.shared.log(routine.name, seconds: elapsed, count: routine.ids.count) }
    }

    private func stepView(_ step: (Stretch, String?)) -> some View {
        let s = step.0
        let total = Double(s.seconds)
        return VStack(spacing: 18) {
            HStack {
                Button { if elapsed >= 30 { finish() } else { dismiss() } } label: {
                    Image(systemName: "xmark").font(.headline).padding(12).background(.ultraThinMaterial, in: Circle())
                }
                Spacer()
                Text("\(index + 1) de \(steps.count)").font(.subheadline.bold().monospacedDigit())
                Spacer()
                Color.clear.frame(width: 44, height: 44)
            }
            ProgressView(value: Double(index), total: Double(max(steps.count, 1))).tint(Theme.accent)
            Spacer(minLength: 0)
            kindIcon(s.kind).scaleEffect(1.6).padding(.bottom, 4)
            Text(s.name).font(.title2.bold()).multilineTextAlignment(.center)
            if let side = step.1 { Text(side).font(.headline).foregroundStyle(Theme.accent) }
            ZStack {
                ProgressRing(progress: prep > 0 ? 0 : 1 - Double(left) / total, lineWidth: 14)
                VStack(spacing: 2) {
                    Text(prep > 0 ? "\(prep)" : "\(left)").font(.system(size: 56, weight: .bold, design: .rounded))
                        .contentTransition(.numericText()).monospacedDigit()
                    Text(prep > 0 ? "prepare-se" : (paused ? "pausado" : "segundos")).font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(width: 190, height: 190)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(s.steps.enumerated()), id: \.offset) { i, t in
                    Text("\(i + 1). \(t)").font(.subheadline)
                }
                Label(s.tip, systemImage: "lightbulb.fill").font(.caption).foregroundStyle(.secondary).padding(.top, 2)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
            Spacer(minLength: 0)
            HStack(spacing: 28) {
                control("backward.fill") { if index > 0 { withAnimation { start(index - 1) } } }
                Button { paused.toggle() } label: {
                    Image(systemName: paused ? "play.fill" : "pause.fill").font(.title.bold()).foregroundStyle(.white)
                        .frame(width: 76, height: 76).background(Theme.gradient, in: Circle())
                }
                .buttonStyle(PressableStyle())
                control("forward.fill") { next() }
            }
            HStack(spacing: 12) {
                Button("−10 s") { left = max(1, left - 10) }
                Button("+10 s") { left += 10 }
            }
            .buttonStyle(.bordered).font(.subheadline)
        }
        .padding()
    }

    private func control(_ icon: String, _ a: @escaping () -> Void) -> some View {
        Button(action: a) {
            Image(systemName: icon).font(.title3).frame(width: 54, height: 54).background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(PressableStyle())
    }

    private var doneView: some View {
        VStack(spacing: 18) {
            Image(systemName: "checkmark.seal.fill").font(.system(size: 80)).foregroundStyle(Theme.gradient)
            Text("Alongamento concluído!").font(.title.bold())
            Text("\(routine.name) · \(max(1, elapsed / 60)) min").foregroundStyle(.secondary)
            Text("Constância vale mais que intensidade: 10 minutos por dia já mudam a postura e a mobilidade em poucas semanas.")
                .font(.subheadline).multilineTextAlignment(.center).foregroundStyle(.secondary).padding(.horizontal)
            Button { dismiss() } label: {
                Text("Fechar").font(.headline).foregroundStyle(.white).frame(maxWidth: .infinity).padding()
                    .background(Theme.gradient, in: Capsule())
            }
            .padding(.horizontal, 40)
        }
        .padding()
    }
}

// MARK: - Cartão na aba Treinos

struct StretchCard: View {
    @State private var store = StretchStore.shared

    var body: some View {
        NavigationLink { StretchHomeView() } label: {
            Card {
                HStack(spacing: 14) {
                    Image(systemName: "figure.flexibility").font(.title).foregroundStyle(Theme.gradient)
                        .frame(width: 52, height: 52).background(Theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Alongamentos e postura").font(.headline).foregroundStyle(.primary)
                        Text(store.conditions.isEmpty
                             ? "\(StretchCatalog.all.count) exercícios · rotinas para postura, dores e mobilidade"
                             : "Recomendações para \(store.conditions.count) condição(ões) · \(store.weekMinutes) min na semana")
                            .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.leading)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(PressableStyle())
    }
}
