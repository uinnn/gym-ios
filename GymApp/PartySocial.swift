import SwiftUI
import SwiftData

// MARK: - Métricas de desafios e duelos

enum ChallengeMetric: String, Codable, CaseIterable, Identifiable {
    case workouts, minutes, weighins, checkins, practices, water, activeDays, meals
    var id: String { rawValue }

    var title: String {
        switch self {
        case .workouts: "Treinos"
        case .minutes: "Minutos de treino"
        case .weighins: "Pesagens"
        case .checkins: "Check-ins de humor"
        case .practices: "Práticas (respiração/meditação)"
        case .water: "Dias com meta de água"
        case .activeDays: "Dias ativos"
        case .meals: "Refeições registradas"
        }
    }
    var unit: String {
        switch self {
        case .workouts: "treinos"
        case .minutes: "min"
        case .weighins: "pesagens"
        case .checkins: "check-ins"
        case .practices: "práticas"
        case .water: "dias"
        case .activeDays: "dias"
        case .meals: "refeições"
        }
    }
    var icon: String {
        switch self {
        case .workouts: "dumbbell.fill"
        case .minutes: "timer"
        case .weighins: "scalemass.fill"
        case .checkins: "face.smiling"
        case .practices: "wind"
        case .water: "drop.fill"
        case .activeDays: "calendar"
        case .meals: "fork.knife"
        }
    }
    var defaultTarget: Double {
        switch self {
        case .workouts: 12
        case .minutes: 600
        case .weighins: 7
        case .checkins: 7
        case .practices: 10
        case .water: 7
        case .activeDays: 7
        case .meals: 40
        }
    }

    /// Valor de um membro numa janela de tempo (uma passada pelos eventos).
    func value(_ events: [PartyEvent], member: String, from: Double, to: Double) -> Double {
        var total = 0.0
        var days = Set<Int>()
        for e in events where e.member == member && e.ts >= from && e.ts < to && e.kind.isActivity {
            switch self {
            case .workouts: if e.kind == .workout { total += 1 }
            case .minutes: if e.kind == .workout { total += e.value }
            case .weighins: if e.kind == .weight { total += 1 }
            case .checkins: if e.kind == .mood { total += 1 }
            case .practices: if e.kind == .practice { total += 1 }
            case .meals: if e.kind == .food { total += 1 }
            case .water: if e.kind == .water { days.insert(Int(e.ts / 86400)) }
            case .activeDays: days.insert(Int(e.ts / 86400))
            }
        }
        return self == .water || self == .activeDays ? Double(days.count) : total
    }
}

struct ChallengeSpec: Codable {
    var metric: ChallengeMetric
    var target: Double
    var days: Int
    var group: Bool          // true = soma do grupo; false = meta para cada um
}

struct DuelSpec: Codable {
    var metric: ChallengeMetric
    var days: Int
}

enum SocialCodec {
    static func encode<T: Encodable>(_ v: T) -> String { (try? JSONEncoder().encode(v)).flatMap { String(data: $0, encoding: .utf8) } ?? "" }
    static func decode<T: Decodable>(_ s: String?, as: T.Type) -> T? {
        guard let s, let d = s.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(T.self, from: d)
    }
}

// MARK: - Desafios

struct ChallengesCard: View {
    let party: Party
    let events: [PartyEvent]
    @State private var creating = false

    var body: some View {
        let now = Date.now.timeIntervalSince1970
        let list = events.filter { $0.kind == .challenge }.compactMap { e -> (PartyEvent, ChallengeSpec)? in
            SocialCodec.decode(e.extra, as: ChallengeSpec.self).map { (e, $0) }
        }
        let active = list.filter { $0.0.ts + Double($0.1.days) * 86400 > now }
        let finished = list.filter { $0.0.ts + Double($0.1.days) * 86400 <= now }.suffix(3)
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Desafios", systemImage: "flag.checkered").font(.headline)
                    Spacer()
                    Button { creating = true } label: { Image(systemName: "plus.circle.fill").font(.title3) }
                }
                if active.isEmpty {
                    Text("Nenhum desafio ativo. Crie um para o grupo todo, como \"12 treinos na semana\".")
                        .font(.callout).foregroundStyle(.secondary)
                }
                ForEach(active, id: \.0.id) { e, spec in row(e, spec, now: now) }
                if !finished.isEmpty {
                    Divider()
                    Text("Encerrados").font(.caption.bold()).foregroundStyle(.secondary)
                    ForEach(Array(finished), id: \.0.id) { e, spec in row(e, spec, now: now) }
                }
            }
        }
        .sheet(isPresented: $creating) { NewChallengeSheet() }
    }

    private func row(_ e: PartyEvent, _ spec: ChallengeSpec, now: Double) -> some View {
        let end = e.ts + Double(spec.days) * 86400
        let values = party.members.map { ($0, spec.metric.value(events, member: $0.id, from: e.ts, to: end)) }
        let total = values.map(\.1).reduce(0, +)
        let done = spec.group ? total >= spec.target : values.allSatisfy { $0.1 >= spec.target }
        let left = max(0, end - now)
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: spec.metric.icon).foregroundStyle(Theme.accent)
                Text(e.text).font(.subheadline.bold())
                Spacer()
                if done { Text("🏆").font(.title3) }
            }
            if spec.group {
                ProgressBar(progress: total / max(spec.target, 1), tint: done ? Theme.good : Theme.accent, height: 8)
                Text("\(total.fmt(0)) de \(spec.target.fmt(0)) \(spec.metric.unit) juntos")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(values, id: \.0.id) { m, v in
                    HStack(spacing: 6) {
                        Text(m.emoji)
                        ProgressBar(progress: v / max(spec.target, 1), tint: v >= spec.target ? Theme.good : Theme.accent, height: 6)
                        Text("\(v.fmt(0))/\(spec.target.fmt(0))").font(.caption2.monospacedDigit()).frame(width: 52, alignment: .trailing)
                    }
                }
            }
            Text(left > 0 ? "Termina em \(Self.remaining(left)) · criado por \(e.name)" : "Encerrado · criado por \(e.name)")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }

    static func remaining(_ s: Double) -> String {
        let d = Int(s / 86400), h = Int(s.truncatingRemainder(dividingBy: 86400) / 3600)
        return d > 0 ? "\(d)d \(h)h" : "\(h)h"
    }
}

struct NewChallengeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var metric = ChallengeMetric.workouts
    @State private var target = ChallengeMetric.workouts.defaultTarget
    @State private var days = 7
    @State private var group = true

    var body: some View {
        NavigationStack {
            Form {
                Picker("Métrica", selection: $metric) {
                    ForEach(ChallengeMetric.allCases) { Label($0.title, systemImage: $0.icon).tag($0) }
                }
                .onChange(of: metric) { _, m in target = m.defaultTarget * (group ? 1 : 0.5) }
                Picker("Tipo", selection: $group) {
                    Text("Meta do grupo (soma)").tag(true)
                    Text("Meta para cada um").tag(false)
                }
                Stepper("Meta: \(target.fmt(0)) \(metric.unit)", value: $target, in: 1...10000,
                        step: metric == .minutes ? 30 : 1)
                Picker("Duração", selection: $days) {
                    Text("3 dias").tag(3); Text("1 semana").tag(7); Text("2 semanas").tag(14); Text("1 mês").tag(30)
                }
            }
            .navigationTitle("Novo desafio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Criar") {
                        let spec = ChallengeSpec(metric: metric, target: target, days: days, group: group)
                        let title = "\(target.fmt(0)) \(metric.unit) em \(days) dias" + (group ? " (grupo)" : " (cada um)")
                        PartyService.shared.post(.challenge, title, value: target, extra: SocialCodec.encode(spec))
                        dismiss()
                    }
                    .bold()
                }
            }
        }
    }
}

// MARK: - Duelos

struct DuelsCard: View {
    let party: Party
    let events: [PartyEvent]
    @State private var creating = false

    var body: some View {
        let now = Date.now.timeIntervalSince1970
        let duels = events.filter { $0.kind == .duel }.compactMap { e -> (PartyEvent, DuelSpec)? in
            SocialCodec.decode(e.extra, as: DuelSpec.self).map { (e, $0) }
        }.filter { $0.0.ts + Double($0.1.days) * 86400 > now - 3 * 86400 }      // ativos + recém-encerrados
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Duelos 1×1", systemImage: "figure.fencing").font(.headline)
                    Spacer()
                    if party.members.count > 1 {
                        Button { creating = true } label: { Image(systemName: "plus.circle.fill").font(.title3) }
                    }
                }
                if duels.isEmpty {
                    Text(party.members.count > 1 ? "Desafie alguém: quem treina mais na semana?" : "Convide alguém para duelar.")
                        .font(.callout).foregroundStyle(.secondary)
                }
                ForEach(duels.reversed(), id: \.0.id) { e, spec in duelRow(e, spec, now: now) }
            }
        }
        .sheet(isPresented: $creating) { NewDuelSheet(party: party) }
    }

    private func duelRow(_ e: PartyEvent, _ spec: DuelSpec, now: Double) -> some View {
        let end = e.ts + Double(spec.days) * 86400
        let a = party.members.first { $0.id == e.member }
        let b = party.members.first { $0.id == e.target }
        let va = spec.metric.value(events, member: e.member, from: e.ts, to: end)
        let vb = spec.metric.value(events, member: e.target ?? "", from: e.ts, to: end)
        let over = now >= end
        return VStack(spacing: 6) {
            HStack {
                side(a?.emoji ?? e.emoji, a?.name ?? e.name, va, win: over && va > vb)
                Text("×").font(.title2.bold()).foregroundStyle(.secondary)
                side(b?.emoji ?? "❔", b?.name ?? "Saiu", vb, win: over && vb > va)
            }
            let total = max(va + vb, 1)
            GeometryReader { g in
                HStack(spacing: 2) {
                    Capsule().fill(Theme.accent).frame(width: max(4, g.size.width * va / total))
                    Capsule().fill(Theme.warm).frame(maxWidth: .infinity)
                }
            }
            .frame(height: 6)
            Text("\(spec.metric.title) · " + (over ? (va == vb ? "Empate!" : "Encerrado") : "termina em \(ChallengesCard.remaining(end - now))"))
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(10).background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
    }

    private func side(_ emoji: String, _ name: String, _ v: Double, win: Bool) -> some View {
        VStack(spacing: 2) {
            Text(emoji).font(.title2)
            Text(name).font(.caption.bold()).lineLimit(1)
            Text(v.fmt(0)).font(.title3.bold()).foregroundStyle(win ? Theme.good : .primary)
            if win { Text("🏆 venceu").font(.caption2) }
        }
        .frame(maxWidth: .infinity)
    }
}

struct NewDuelSheet: View {
    let party: Party
    @Environment(\.dismiss) private var dismiss
    @State private var opponent = ""
    @State private var metric = ChallengeMetric.workouts
    @State private var days = 7

    var body: some View {
        let service = PartyService.shared
        let others = party.members.filter { !service.isMe($0.id) }
        NavigationStack {
            Form {
                Picker("Adversário", selection: $opponent) {
                    ForEach(others) { Text("\($0.emoji) \($0.name)").tag($0.id) }
                }
                Picker("Quem tem mais", selection: $metric) {
                    ForEach(ChallengeMetric.allCases) { Label($0.title, systemImage: $0.icon).tag($0) }
                }
                Picker("Duração", selection: $days) {
                    Text("3 dias").tag(3); Text("1 semana").tag(7); Text("2 semanas").tag(14)
                }
            }
            .navigationTitle("Novo duelo")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { if opponent.isEmpty { opponent = others.first?.id ?? "" } }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Desafiar") {
                        let name = others.first { $0.id == opponent }?.name ?? ""
                        service.post(.duel, "desafiou \(name) para um duelo de \(metric.title.lowercased()) (\(days) dias) ⚔️",
                                     target: opponent, extra: SocialCodec.encode(DuelSpec(metric: metric, days: days)))
                        dismiss()
                    }
                    .bold().disabled(opponent.isEmpty)
                }
            }
        }
    }
}

// MARK: - Feed com reações e comentários

struct PartyFeedCard: View {
    let events: [PartyEvent]
    @State private var commenting: PartyEvent?
    static let reactions = ["👏", "🔥", "💪", "❤️", "😂"]

    var body: some View {
        let service = PartyService.shared
        // agrupa reações e comentários por evento numa passada só
        var reacts: [String: [String: Int]] = [:], mine: [String: Set<String>] = [:], comments: [String: Int] = [:]
        for e in events {
            guard let t = e.target else { continue }
            if e.kind == .reaction {
                reacts[t, default: [:]][e.text, default: 0] += 1
                if service.isMe(e.member) { mine[t, default: []].insert(e.text) }
            } else if e.kind == .comment { comments[t, default: 0] += 1 }
        }
        let feed = events.filter { $0.kind.isActivity || [.achievement, .nudge, .challenge, .duel].contains($0.kind) }.suffix(80).reversed()
        return Card {
            VStack(alignment: .leading, spacing: 14) {
                Label("Atividades", systemImage: "list.bullet").font(.headline)
                if feed.isEmpty {
                    Text("Nada ainda. Assim que alguém pesar, comer, treinar ou fizer um check-in, aparece aqui.")
                        .font(.callout).foregroundStyle(.secondary)
                }
                ForEach(Array(feed)) { e in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: e.kind.icon).foregroundStyle(e.kind == .achievement ? Theme.warm : Theme.accent)
                                .frame(width: 30, height: 30)
                                .background(Theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(e.emoji) \(e.name)").font(.subheadline.bold())
                                Text(e.text).font(.callout).fixedSize(horizontal: false, vertical: true)
                                Text(e.date, format: .relative(presentation: .named)).font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                        HStack(spacing: 6) {
                            ForEach(Self.reactions, id: \.self) { r in
                                let n = reacts[e.id]?[r] ?? 0
                                let isMine = mine[e.id]?.contains(r) == true
                                Button {
                                    guard !isMine else { return }
                                    service.post(.reaction, r, target: e.id)
                                } label: {
                                    Text(n > 0 ? "\(r) \(n)" : r).font(.caption)
                                        .padding(.horizontal, 7).padding(.vertical, 3)
                                        .background(isMine ? Theme.accent.opacity(0.25) : Color.secondary.opacity(0.1), in: Capsule())
                                }
                                .buttonStyle(.plain)
                                .opacity(n > 0 || !service.isMe(e.member) ? 1 : 0.5)
                            }
                            Spacer()
                            Button { commenting = e } label: {
                                Label("\(comments[e.id] ?? 0)", systemImage: "bubble.left").font(.caption)
                            }
                            .buttonStyle(.plain).foregroundStyle(.secondary)
                        }
                        .padding(.leading, 40)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .sheet(item: $commenting) { CommentsSheet(event: $0) }
    }
}

struct CommentsSheet: View {
    let event: PartyEvent
    @Environment(\.dismiss) private var dismiss
    @State private var service = PartyService.shared
    @State private var text = ""

    var body: some View {
        let list = service.events.filter { $0.kind == .comment && $0.target == event.id }
        NavigationStack {
            VStack(spacing: 0) {
                List {
                    Section {
                        Text("\(event.emoji) \(event.name)").font(.subheadline.bold())
                        Text(event.text)
                    }
                    Section("Comentários") {
                        if list.isEmpty { Text("Seja o primeiro a comentar.").foregroundStyle(.secondary) }
                        ForEach(list) { c in
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(c.emoji) \(c.name)").font(.caption.bold())
                                Text(c.text)
                                Text(c.date, format: .relative(presentation: .named)).font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                MessageBar(text: $text, placeholder: "Comentar…") {
                    service.post(.comment, text, target: event.id)
                }
            }
            .navigationTitle("Comentários")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("OK") { dismiss() } }
        }
    }
}

struct MessageBar: View {
    @Binding var text: String
    var placeholder: String
    var send: () -> Void

    var body: some View {
        HStack {
            TextField(placeholder, text: $text, axis: .vertical).lineLimit(1...4)
                .padding(10).background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 18))
            Button {
                let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !t.isEmpty else { return }
                text = t
                send()
                text = ""
            } label: { Image(systemName: "arrow.up.circle.fill").font(.title) }
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(10)
        .background(.bar)
    }
}

// MARK: - Chat

struct PartyChatView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var service = PartyService.shared
    @State private var text = ""

    var body: some View {
        let msgs = service.events.filter { $0.kind == .chat }.suffix(300)
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            if msgs.isEmpty {
                                Text("Mande a primeira mensagem para a party 👋").foregroundStyle(.secondary).padding(.top, 40)
                            }
                            ForEach(Array(msgs)) { m in bubble(m).id(m.id) }
                        }
                        .padding()
                    }
                    .onAppear { proxy.scrollTo(msgs.last?.id, anchor: .bottom) }
                    .onChange(of: msgs.count) { _, _ in withAnimation { proxy.scrollTo(msgs.last?.id, anchor: .bottom) } }
                }
                MessageBar(text: $text, placeholder: "Mensagem") { service.post(.chat, text) }
            }
            .navigationTitle("Chat · \(service.party?.name ?? "")")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("OK") { dismiss() } }
            .task {
                while !Task.isCancelled {
                    await service.refresh(force: true)
                    try? await Task.sleep(for: .seconds(8))     // mais rápido enquanto o chat está aberto
                }
            }
        }
    }

    private func bubble(_ m: PartyEvent) -> some View {
        let mine = service.isMe(m.member)
        return HStack {
            if mine { Spacer(minLength: 50) }
            VStack(alignment: mine ? .trailing : .leading, spacing: 2) {
                if !mine { Text("\(m.emoji) \(m.name)").font(.caption2.bold()).foregroundStyle(.secondary) }
                Text(m.text)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(mine ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(.quaternary), in: RoundedRectangle(cornerRadius: 16))
                    .foregroundStyle(mine ? .white : .primary)
                Text(m.date, format: .dateTime.hour().minute()).font(.caption2).foregroundStyle(.secondary)
            }
            if !mine { Spacer(minLength: 50) }
        }
    }
}

// MARK: - Conquistas

struct AchievementDef: Identifiable {
    let id: String
    let emoji: String
    let title: String
    let detail: String
    let target: Double
    let stat: KeyPath<AchievementStats, Double>
}

struct AchievementStats {
    var workouts = 0.0, weighins = 0.0, kgLost = 0.0, kgGained = 0.0, moods = 0.0, moodStreak = 0.0,
        practices = 0.0, meals = 0.0, gratitude = 0.0, sleeps = 0.0, cardioKm = 0.0
}

@MainActor
enum AchievementEngine {
    static let all: [AchievementDef] = {
        var a: [AchievementDef] = []
        func add(_ id: String, _ e: String, _ t: String, _ d: String, _ n: Double, _ s: KeyPath<AchievementStats, Double>) {
            a.append(AchievementDef(id: id, emoji: e, title: t, detail: d, target: n, stat: s))
        }
        for (n, e) in [(1.0, "🎉"), (10, "💪"), (25, "🏋️"), (50, "🔥"), (100, "💯"), (250, "🦾"), (500, "👑")] {
            add("w\(Int(n))", e, n == 1 ? "Primeiro treino" : "\(Int(n)) treinos", "Conclua \(Int(n)) treino\(n == 1 ? "" : "s")", n, \.workouts)
        }
        for (n, e) in [(1.0, "⬇️"), (3, "📉"), (5, "🎯"), (10, "🏅"), (20, "🏆")] {
            add("l\(Int(n))", e, "−\(Int(n)) kg", "Perca \(Int(n)) kg desde a primeira pesagem", n, \.kgLost)
        }
        for (n, e) in [(2.0, "📈"), (5, "🍗")] {
            add("g\(Int(n))", e, "+\(Int(n)) kg", "Ganhe \(Int(n)) kg desde a primeira pesagem (para quem quer ganhar massa)", n, \.kgGained)
        }
        for (n, e) in [(10.0, "⚖️"), (50, "📊"), (100, "🧮")] {
            add("p\(Int(n))", e, "\(Int(n)) pesagens", "Pese-se \(Int(n)) vezes", n, \.weighins)
        }
        for (n, e) in [(7.0, "🙂"), (30, "🧠"), (100, "🌈")] {
            add("m\(Int(n))", e, "\(Int(n)) check-ins", "Faça \(Int(n)) check-ins de humor", n, \.moods)
        }
        for (n, e) in [(7.0, "📆"), (30, "🗓️")] {
            add("ms\(Int(n))", e, "\(Int(n)) dias seguidos", "Check-in de humor \(Int(n)) dias seguidos", n, \.moodStreak)
        }
        for (n, e) in [(10.0, "🌬️"), (50, "🧘")] {
            add("pr\(Int(n))", e, "\(Int(n)) práticas", "Faça \(Int(n)) práticas de respiração, meditação ou foco", n, \.practices)
        }
        for (n, e) in [(50.0, "🍽️"), (500, "📒")] {
            add("f\(Int(n))", e, "\(Int(n)) refeições", "Registre \(Int(n)) alimentos no diário", n, \.meals)
        }
        add("gr30", "🙏", "30 dias de gratidão", "Escreva no diário de gratidão 30 vezes", 30, \.gratitude)
        add("sl30", "😴", "30 noites", "Registre 30 noites de sono", 30, \.sleeps)
        for (n, e) in [(10.0, "🏃"), (42.2, "🏅"), (100, "🚀")] {
            add("c\(Int(n))", e, "\(n.fmt(n == 42.2 ? 1 : 0)) km", "Percorra \(n.fmt(n == 42.2 ? 1 : 0)) km em cardio com GPS", n, \.cardioKm)
        }
        return a
    }()

    static func stats(_ ctx: ModelContext) -> AchievementStats {
        var s = AchievementStats()
        s.workouts = Double((try? ctx.fetchCount(FetchDescriptor<WorkoutSession>(predicate: #Predicate { $0.end != nil }))) ?? 0)
        s.weighins = Double((try? ctx.fetchCount(FetchDescriptor<WeightEntry>())) ?? 0)
        var first = FetchDescriptor<WeightEntry>(sortBy: [SortDescriptor(\.date)]); first.fetchLimit = 1
        var last = FetchDescriptor<WeightEntry>(sortBy: [SortDescriptor(\.date, order: .reverse)]); last.fetchLimit = 1
        if let a = (try? ctx.fetch(first))?.first, let b = (try? ctx.fetch(last))?.first {
            s.kgLost = max(0, a.kg - b.kg); s.kgGained = max(0, b.kg - a.kg)
        }
        let moods = (try? ctx.fetch(FetchDescriptor<MoodEntry>())) ?? []
        s.moods = Double(moods.count)
        s.moodStreak = Double(HabitMath.streaks(Set(moods.map { Calendar.current.startOfDay(for: $0.date) })).current)
        s.practices = Double((try? ctx.fetchCount(FetchDescriptor<MindSession>())) ?? 0)
        s.meals = Double((try? ctx.fetchCount(FetchDescriptor<FoodLog>())) ?? 0)
        s.gratitude = Double((try? ctx.fetchCount(FetchDescriptor<GratitudeEntry>())) ?? 0)
        s.sleeps = Double((try? ctx.fetchCount(FetchDescriptor<SleepEntry>())) ?? 0)
        s.cardioKm = ((try? ctx.fetch(FetchDescriptor<CardioSession>())) ?? []).map(\.km).reduce(0, +)
        return s
    }

    private static func key() -> String { "ach.\(ProfileRegistry.shared.activeID)" }

    static var unlocked: Set<String> { Set(UserDefaults.standard.stringArray(forKey: key()) ?? []) }

    /// Verifica conquistas novas. Na primeira vez, marca as já atingidas sem anunciar (evita enxurrada).
    @discardableResult
    static func check(_ ctx: ModelContext) -> [AchievementDef] {
        let s = stats(ctx)
        let d = UserDefaults.standard
        let firstRun = d.stringArray(forKey: key()) == nil
        var have = unlocked
        let new = all.filter { !have.contains($0.id) && s[keyPath: $0.stat] >= $0.target }
        guard !new.isEmpty || firstRun else { return [] }
        for a in new { have.insert(a.id) }
        d.set(Array(have), forKey: key())
        if firstRun { return [] }
        for a in new { PartyService.shared.post(.achievement, "desbloqueou \(a.emoji) \(a.title)!") }
        return new
    }
}

struct AchievementsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var stats = AchievementStats()
    @State private var unlocked = Set<String>()

    var body: some View {
        NavigationStack {
            ScrollView {
                let done = AchievementEngine.all.filter { unlocked.contains($0.id) }.count
                Text("\(done) de \(AchievementEngine.all.count) desbloqueadas").font(.subheadline).foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 10)], spacing: 10) {
                    ForEach(AchievementEngine.all) { a in
                        let ok = unlocked.contains(a.id)
                        let p = min(stats[keyPath: a.stat] / a.target, 1)
                        VStack(spacing: 4) {
                            Text(a.emoji).font(.system(size: 34)).grayscale(ok ? 0 : 1).opacity(ok ? 1 : 0.4)
                            Text(a.title).font(.caption.bold()).multilineTextAlignment(.center).lineLimit(2)
                            if !ok { ProgressBar(progress: p, tint: Theme.accent, height: 4) }
                        }
                        .frame(maxWidth: .infinity, minHeight: 104)
                        .padding(8)
                        .background(ok ? AnyShapeStyle(Theme.warm.opacity(0.15)) : AnyShapeStyle(.quaternary.opacity(0.4)),
                                    in: RoundedRectangle(cornerRadius: 14))
                        .help(a.detail)
                        .contextMenu { Text(a.detail) }
                    }
                }
                .padding()
            }
            .navigationTitle("Conquistas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("OK") { dismiss() } }
            .onAppear {
                AchievementEngine.check(context)
                stats = AchievementEngine.stats(context)
                unlocked = AchievementEngine.unlocked
            }
        }
    }
}
