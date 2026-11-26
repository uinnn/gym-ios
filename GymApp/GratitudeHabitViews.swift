import SwiftUI
import SwiftData

// MARK: - Gratidão

struct GratitudeSheet: View {
    var existing: GratitudeEntry?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var items = ["", "", ""]

    private let prompts = ["Algo bom que aconteceu hoje…", "Uma pessoa que fez diferença…", "Algo simples que você aproveitou…"]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 6) {
                        Text("🙏").font(.system(size: 52))
                        Text("3 coisas boas").font(.title2.bold())
                        Text("Escrever 3 coisas pelas quais você é grato(a) melhora o humor e o sono em poucas semanas (Emmons & McCullough, 2003; Seligman, 2005).")
                            .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity).listRowBackground(Color.clear)
                }
                ForEach(items.indices, id: \.self) { i in
                    Section("\(i + 1).") {
                        TextField(prompts[i % prompts.count], text: $items[i], axis: .vertical).lineLimit(1...4)
                    }
                }
                Section {
                    Button("Adicionar mais um") { items.append("") }
                }
            }
            .navigationTitle("Gratidão")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        let e = existing ?? GratitudeEntry(items: [])
                        e.items = items
                        if existing == nil { context.insert(e) }
                        dismiss()
                    }
                    .bold().disabled(items.allSatisfy { $0.trimmingCharacters(in: .whitespaces).isEmpty })
                }
            }
            .onAppear {
                if let e = existing { items = e.items + Array(repeating: "", count: max(0, 3 - e.items.count)) }
            }
        }
    }
}

struct GratitudeHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \GratitudeEntry.date, order: .reverse) private var entries: [GratitudeEntry]
    @State private var editing: GratitudeEntry?
    @State private var adding = false

    var body: some View {
        let days = Set(entries.map { Calendar.current.startOfDay(for: $0.date) })
        let s = HabitMath.streaks(days)
        NavigationStack {
            List {
                Section {
                    HStack {
                        VStack { Text("\(entries.count)").font(.title2.bold()); Text("registros").font(.caption2) }.frame(maxWidth: .infinity)
                        VStack { Text("\(entries.map(\.items.count).reduce(0, +))").font(.title2.bold()); Text("coisas boas").font(.caption2) }.frame(maxWidth: .infinity)
                        VStack { Text("\(s.current)🔥").font(.title2.bold()); Text("dias seguidos").font(.caption2) }.frame(maxWidth: .infinity)
                    }
                }
                ForEach(entries) { e in
                    Button { editing = e } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(e.date, format: .dateTime.weekday(.wide).day().month(.wide)).font(.caption.bold()).foregroundStyle(Theme.accent)
                            ForEach(Array(e.items.enumerated()), id: \.offset) { _, t in
                                Label(t, systemImage: "sparkle").font(.subheadline).foregroundStyle(.primary)
                            }
                        }
                    }
                }
                .onDelete { idx in idx.forEach { context.deleteUndoable(entries[$0]) } }
            }
            .navigationTitle("Diário de gratidão")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("OK") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button { adding = true } label: { Image(systemName: "plus") } }
            }
            .sheet(item: $editing) { GratitudeSheet(existing: $0) }
            .sheet(isPresented: $adding) { GratitudeSheet() }
        }
    }

    @Environment(\.modelContext) private var context
}

// MARK: - Hábitos

struct HabitsCard: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Habit> { !$0.archived }, sort: \Habit.order) private var habits: [Habit]
    @Query private var logs: [HabitLog]
    @State private var managing = false
    @State private var tick = 0

    var body: some View {
        let today = Calendar.current.startOfDay(for: .now)
        let byHabit = Dictionary(grouping: logs, by: \.habitUID).mapValues { Set($0.map(\.day)) }
        let doneToday = habits.filter { byHabit[$0.uid]?.contains(today) == true }.count
        Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Hábitos de hoje", systemImage: "checklist").font(.headline)
                    Spacer()
                    if !habits.isEmpty { Text("\(doneToday)/\(habits.count)").font(.subheadline.bold()).foregroundStyle(Theme.good) }
                    Button { managing = true } label: { Image(systemName: "slider.horizontal.3") }
                }
                if habits.isEmpty {
                    Button { managing = true } label: {
                        Label("Criar meus hábitos", systemImage: "plus.circle.fill").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered).tint(Theme.accent)
                } else {
                    ProgressBar(progress: Double(doneToday) / Double(habits.count), tint: Theme.good, height: 6)
                    ForEach(habits) { h in
                        let days = byHabit[h.uid] ?? []
                        let done = days.contains(today)
                        let streak = HabitMath.streaks(days).current
                        Button { toggle(h, done: done, today: today) } label: {
                            HStack(spacing: 12) {
                                Image(systemName: done ? "checkmark.circle.fill" : "circle").font(.title2)
                                    .foregroundStyle(done ? h.color : .secondary)
                                    .symbolEffect(.bounce, value: done)
                                Image(systemName: h.icon).foregroundStyle(h.color).frame(width: 22)
                                Text(h.name).font(.subheadline).strikethrough(done, color: .secondary)
                                    .foregroundStyle(done ? .secondary : .primary)
                                Spacer()
                                if streak > 0 { Text("\(streak)🔥").font(.caption.bold()) }
                                weekDots(days, color: h.color)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.tap)
                    }
                }
            }
        }
        .sensoryFeedback(.success, trigger: tick) { _, _ in ThemeStore.shared.haptics }
        .sheet(isPresented: $managing) { HabitManagerView() }
    }

    private func weekDots(_ days: Set<Date>, color: Color) -> some View {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        return HStack(spacing: 3) {
            ForEach((0..<7).reversed(), id: \.self) { i in
                let d = cal.date(byAdding: .day, value: -i, to: today)!
                Circle().fill(days.contains(d) ? color : Color.secondary.opacity(0.2)).frame(width: 6, height: 6)
            }
        }
    }

    private func toggle(_ h: Habit, done: Bool, today: Date) {
        withAnimation(.spring(duration: 0.3)) {
            if done {
                logs.filter { $0.habitUID == h.uid && $0.day == today }.forEach { context.delete($0) }
            } else {
                context.insert(HabitLog(habitUID: h.uid, day: today))
                tick += 1
            }
        }
    }
}

struct HabitManagerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Habit> { !$0.archived }, sort: \Habit.order) private var habits: [Habit]
    @Query private var logs: [HabitLog]
    @State private var name = ""
    @State private var icon = "checkmark.circle.fill"
    @State private var color = 0

    private let icons = ["checkmark.circle.fill", "brain.head.profile", "book.fill", "iphone.slash", "sun.max.fill", "figure.walk",
                         "drop.fill", "figure.flexibility", "moon.zzz.fill", "pencil.and.scribble", "person.2.fill", "wineglass",
                         "bed.double.fill", "leaf.fill", "music.note", "paintbrush.fill"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Novo hábito") {
                    TextField("Nome (ex.: Meditar 10 min)", text: $name)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(icons, id: \.self) { i in
                                Image(systemName: i).frame(width: 36, height: 36)
                                    .foregroundStyle(icon == i ? .white : Palette.all[color].accent)
                                    .background(icon == i ? AnyShapeStyle(Palette.all[color].accent) : AnyShapeStyle(.quaternary), in: Circle())
                                    .hitTarget().onTapGesture { icon = i }
                            }
                        }
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(Palette.all.indices, id: \.self) { i in
                                Circle().fill(Palette.all[i].accent).frame(width: 26, height: 26)
                                    .overlay(Circle().strokeBorder(.primary, lineWidth: color == i ? 2 : 0))
                                    .hitTarget().onTapGesture { color = i }
                            }
                        }
                    }
                    Button("Adicionar") { add(name, icon) }.disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                Section("Sugestões") {
                    ForEach(HabitMath.suggestions.filter { s in !habits.contains { $0.name == s.0 } }, id: \.0) { s in
                        Button { add(s.0, s.1) } label: { Label(s.0, systemImage: s.1) }
                    }
                }
                if !habits.isEmpty {
                    Section("Meus hábitos") {
                        ForEach(habits) { h in
                            let days = Set(logs.filter { $0.habitUID == h.uid }.map(\.day))
                            let st = HabitMath.streaks(days)
                            HStack {
                                Label(h.name, systemImage: h.icon).foregroundStyle(h.color)
                                Spacer()
                                Text("\(days.count) dias · recorde \(st.best)").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .onDelete { idx in idx.forEach { habits[$0].archived = true } }
                        .onMove { from, to in
                            var list = habits
                            list.move(fromOffsets: from, toOffset: to)
                            for (i, h) in list.enumerated() { h.order = i }
                        }
                    }
                }
            }
            .navigationTitle("Hábitos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { EditButton() }
                ToolbarItem(placement: .confirmationAction) { Button("OK") { dismiss() } }
            }
        }
    }

    private func add(_ n: String, _ i: String) {
        context.insert(Habit(name: n.trimmingCharacters(in: .whitespaces), icon: i, colorIndex: color, order: habits.count))
        name = ""
    }
}
