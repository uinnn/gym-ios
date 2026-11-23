import WidgetKit
import SwiftUI
import ActivityKit

// MARK: - Linha do tempo

struct SnapEntry: TimelineEntry {
    let date: Date
    let snap: WidgetSnapshot
}

struct SnapProvider: TimelineProvider {
    static let sample: WidgetSnapshot = {
        var s = WidgetSnapshot()
        s.name = "Você"; s.kg = 72.4; s.kgDelta7 = -0.6; s.goalKg = 70; s.waterMl = 1250; s.waterGoalMl = 2500
        s.kcal = 1340; s.kcalGoal = 2100; s.streak = 5; s.nextWorkout = "Treino A"
        return s
    }()

    func placeholder(in context: Context) -> SnapEntry { SnapEntry(date: .now, snap: Self.sample) }
    func getSnapshot(in context: Context, completion: @escaping (SnapEntry) -> Void) {
        completion(SnapEntry(date: .now, snap: WidgetSnapshot.load() ?? Self.sample))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapEntry>) -> Void) {
        var snap = WidgetSnapshot.load() ?? WidgetSnapshot()
        // água e calorias zeram à meia-noite mesmo sem abrir o app
        if !Calendar.current.isDateInToday(snap.updated) { snap.waterMl = 0; snap.kcal = 0 }
        let midnight = Calendar.current.startOfDay(for: .now).addingTimeInterval(86400 + 60)
        completion(Timeline(entries: [SnapEntry(date: .now, snap: snap)], policy: .after(min(midnight, .now.addingTimeInterval(3600)))))
    }
}

private let accent = Color(red: 0.36, green: 0.42, blue: 0.98)
private let waterColor = Color(red: 0.2, green: 0.6, blue: 1.0)

private func fmt(_ v: Double, _ d: Int) -> String {
    v.formatted(.number.precision(.fractionLength(d)).locale(Locale(identifier: "pt_BR")))
}

// MARK: - Visualizações

struct SnapView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapEntry

    var body: some View {
        let s = entry.snap
        switch family {
        case .accessoryCircular:
            Gauge(value: min(s.waterMl / max(s.waterGoalMl, 1), 1)) {
                Image(systemName: "drop.fill")
            } currentValueLabel: { Text(fmt(s.waterMl / 1000, 1)) }
            .gaugeStyle(.accessoryCircular)
        case .accessoryRectangular:
            VStack(alignment: .leading) {
                Text(s.kg.map { "\(fmt($0, 1)) kg" } ?? "--").font(.headline)
                if let d = s.kgDelta7 { Text("\(d > 0 ? "+" : "")\(fmt(d, 1)) kg em 7 dias").font(.caption) }
                Text("🔥 \(s.streak) dias · 💧 \(fmt(s.waterMl / 1000, 1)) L").font(.caption2)
            }
        case .accessoryInline:
            Text("🔥 \(s.streak) dias · \(Int(s.kcal)) kcal")
        case .systemSmall:
            small(s)
        default:
            medium(s)
        }
    }

    private func small(_ s: WidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Peso", systemImage: "scalemass.fill").font(.caption.bold()).foregroundStyle(accent)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(s.kg.map { fmt($0, 1) } ?? "--").font(.system(size: 34, weight: .bold, design: .rounded))
                Text("kg").font(.caption)
            }
            if let d = s.kgDelta7 {
                Text("\(d > 0 ? "▲" : "▼") \(fmt(abs(d), 1)) kg / 7 dias").font(.caption2)
                    .foregroundStyle(d <= 0 ? .green : .orange)
            }
            Spacer()
            HStack {
                Text("🔥 \(s.streak)").font(.caption.bold())
                Spacer()
                Text("💧 \(fmt(s.waterMl / 1000, 1))L").font(.caption.bold())
            }
        }
    }

    private func medium(_ s: WidgetSnapshot) -> some View {
        HStack(spacing: 14) {
            small(s)
            VStack(alignment: .leading, spacing: 8) {
                bar("Calorias", "\(Int(s.kcal))/\(Int(s.kcalGoal))", s.kcal / max(s.kcalGoal, 1), .orange)
                bar("Água", "\(fmt(s.waterMl / 1000, 1))/\(fmt(s.waterGoalMl / 1000, 1)) L", s.waterMl / max(s.waterGoalMl, 1), waterColor)
                if let n = s.nextWorkout {
                    Label(n, systemImage: "dumbbell.fill").font(.caption.bold()).lineLimit(1)
                }
            }
        }
    }

    private func bar(_ t: String, _ v: String, _ p: Double, _ c: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack { Text(t).font(.caption2.bold()); Spacer(); Text(v).font(.caption2) }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(c.opacity(0.2))
                    Capsule().fill(c).frame(width: g.size.width * min(max(p, 0), 1))
                }
            }
            .frame(height: 6)
        }
    }
}

struct GymSummaryWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "GymSummary", provider: SnapProvider()) { e in
            SnapView(entry: e).containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Resumo do dia")
        .description("Peso, tendência, água, calorias e sequência.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

// MARK: - Live Activity

struct TimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TimerActivityAttributes.self) { ctx in
            HStack {
                Image(systemName: ctx.attributes.kind == "workout" ? "dumbbell.fill" : "timer").font(.title2).foregroundStyle(accent)
                VStack(alignment: .leading) {
                    Text(ctx.attributes.title).font(.headline)
                    Text(ctx.state.subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if let r = ctx.state.restEnd, r > .now {
                    VStack(alignment: .trailing) {
                        Text("Descanso").font(.caption2)
                        Text(timerInterval: Date.now...r, countsDown: true).font(.title2.bold().monospacedDigit())
                            .multilineTextAlignment(.trailing).frame(width: 80)
                    }
                } else {
                    Text(ctx.attributes.start, style: .timer).font(.title2.bold().monospacedDigit())
                        .multilineTextAlignment(.trailing).frame(width: 90)
                }
            }
            .padding()
        } dynamicIsland: { ctx in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(ctx.attributes.title, systemImage: ctx.attributes.kind == "workout" ? "dumbbell.fill" : "timer").font(.caption.bold())
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(ctx.attributes.start, style: .timer).font(.caption.monospacedDigit()).multilineTextAlignment(.trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if let r = ctx.state.restEnd, r > .now {
                        HStack {
                            Text("Descanso")
                            Spacer()
                            Text(timerInterval: Date.now...r, countsDown: true).bold().monospacedDigit()
                        }
                    } else if let g = ctx.state.goalEnd {
                        ProgressView(timerInterval: ctx.attributes.start...max(g, ctx.attributes.start.addingTimeInterval(1)), countsDown: false)
                            .tint(accent)
                    } else {
                        Text(ctx.state.subtitle).font(.caption)
                    }
                }
            } compactLeading: {
                Image(systemName: ctx.attributes.kind == "workout" ? "dumbbell.fill" : "timer").foregroundStyle(accent)
            } compactTrailing: {
                if let r = ctx.state.restEnd, r > .now {
                    Text(timerInterval: Date.now...r, countsDown: true).monospacedDigit().frame(width: 44)
                } else {
                    Text(ctx.attributes.start, style: .timer).monospacedDigit().frame(width: 52)
                }
            } minimal: {
                Image(systemName: ctx.attributes.kind == "workout" ? "dumbbell.fill" : "timer").foregroundStyle(accent)
            }
        }
    }
}

@main
struct GymWidgetBundle: WidgetBundle {
    var body: some Widget {
        GymSummaryWidget()
        TimerLiveActivity()
    }
}
