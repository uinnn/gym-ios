import SwiftUI
import Charts

enum BodyRegion: String, CaseIterable {
    case upper = "Superior", lower = "Inferior", core = "Core", cardio = "Cardio"

    static func of(_ m: Muscle) -> BodyRegion {
        switch m {
        case .chest, .back, .traps, .shoulders, .biceps, .triceps, .forearms: .upper
        case .glutes, .quads, .hamstrings, .calves, .adductors: .lower
        case .abs, .obliques, .lowerBack: .core
        case .cardio: .cardio
        }
    }

    var color: Color {
        switch self {
        case .upper: Theme.accent
        case .lower: Theme.accent2
        case .core: Theme.warm
        case .cardio: Theme.danger
        }
    }
}

enum Pattern: String, CaseIterable {
    case push = "Empurrar", pull = "Puxar", legs = "Pernas", core = "Core"

    static func of(_ m: Muscle) -> Pattern? {
        switch m {
        case .chest, .shoulders, .triceps: .push
        case .back, .traps, .biceps, .forearms: .pull
        case .glutes, .quads, .hamstrings, .calves, .adductors: .legs
        case .abs, .obliques, .lowerBack: .core
        case .cardio: nil
        }
    }
}

/// Estatísticas de um conjunto de exercícios planejados.
struct TrainingBreakdown {
    let muscleSets: [(Muscle, Double)]
    let total: Double
    let regions: [(BodyRegion, Double)]
    let patterns: [(Pattern, Double)]
    let compoundShare: Double
    let freeShare: Double
    let exercises: Int

    init(_ items: [RoutineItem]) {
        var ms: [Muscle: Double] = [:]
        var compound = 0.0, free = 0.0, all = 0.0
        for i in items {
            guard let x = i.exercise else { continue }
            let n = Double(i.sets)
            all += n
            if x.isCompound { compound += n }
            if x.isFreeWeight { free += n }
            for m in x.primary { ms[m, default: 0] += n }
            for m in x.secondary { ms[m, default: 0] += n * 0.5 }
        }
        let tot = ms.values.reduce(0, +)
        muscleSets = ms.sorted { $0.value > $1.value }.map { ($0.key, $0.value) }
        total = tot
        var rg: [BodyRegion: Double] = [:], pt: [Pattern: Double] = [:]
        for (m, v) in ms {
            rg[BodyRegion.of(m), default: 0] += v
            if let p = Pattern.of(m) { pt[p, default: 0] += v }
        }
        regions = BodyRegion.allCases.compactMap { r in rg[r].map { (r, $0) } }
        patterns = Pattern.allCases.map { ($0, pt[$0] ?? 0) }
        compoundShare = all > 0 ? compound / all : 0
        freeShare = all > 0 ? free / all : 0
        exercises = items.count
    }

    var pushPull: Double? {
        let push = patterns.first { $0.0 == .push }?.1 ?? 0, pull = patterns.first { $0.0 == .pull }?.1 ?? 0
        return pull > 0 ? push / pull : nil
    }
}

/// Cartão "Perfil do treino": % por músculo, região, padrão de movimento e tipo de exercício.
struct TrainingBreakdownCard: View {
    let items: [RoutineItem]
    var title = "Distribuição do treino"

    var body: some View {
        let b = TrainingBreakdown(items)
        Card {
            VStack(alignment: .leading, spacing: 14) {
                Text(title).font(.headline)
                if b.total == 0 {
                    Text("Adicione exercícios de força para ver a distribuição.").font(.caption).foregroundStyle(.secondary)
                } else {
                    // % por músculo
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Quanto do treino vai para cada músculo").font(.caption.bold()).foregroundStyle(.secondary)
                        ForEach(b.muscleSets, id: \.0) { m, v in
                            HStack(spacing: 8) {
                                Image(systemName: m.icon).font(.caption).foregroundStyle(BodyRegion.of(m).color).frame(width: 18)
                                Text(m.label).font(.caption).frame(width: 84, alignment: .leading)
                                ProgressBar(progress: v / (b.muscleSets.first?.1 ?? 1), tint: BodyRegion.of(m).color, height: 7)
                                Text("\(Int((v / b.total * 100).rounded()))%").font(.caption.bold().monospacedDigit())
                                    .frame(width: 36, alignment: .trailing)
                            }
                        }
                    }
                    Divider()
                    // regiões
                    HStack(spacing: 16) {
                        Chart(b.regions, id: \.0) { r, v in
                            SectorMark(angle: .value("séries", v), innerRadius: .ratio(0.62), angularInset: 2)
                                .foregroundStyle(r.color).cornerRadius(3)
                        }
                        .frame(width: 96, height: 96)
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(b.regions, id: \.0) { r, v in
                                HStack {
                                    Circle().fill(r.color).frame(width: 9, height: 9)
                                    Text(r.rawValue).font(.caption)
                                    Spacer()
                                    Text("\(Int((v / b.total * 100).rounded()))%").font(.caption.bold())
                                }
                            }
                        }
                    }
                    Divider()
                    // padrões
                    HStack {
                        ForEach(b.patterns, id: \.0) { p, v in
                            VStack(spacing: 2) {
                                Text("\(Int((v / b.total * 100).rounded()))%").font(.subheadline.bold().monospacedDigit())
                                Text(p.rawValue).font(.caption2).foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    if let r = b.pushPull {
                        Text(pushPullText(r)).font(.caption2).foregroundStyle(r > 1.5 ? Theme.warm : .secondary)
                    }
                    Divider()
                    HStack {
                        share("Compostos", b.compoundShare, Theme.accent)
                        share("Isolados", 1 - b.compoundShare, Theme.accent2)
                        share("Pesos livres", b.freeShare, Theme.good)
                        share("Máquinas/cabos", 1 - b.freeShare, .purple)
                    }
                    Text("Séries contadas: músculo principal = 1, secundário = 0,5.").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func pushPullText(_ r: Double) -> String {
        if r > 1.5 { return "Empurrar/puxar = \(r.fmt(1)): muito mais empurrar que puxar. Adicione remadas/puxadas para equilibrar ombros e postura." }
        if r < 0.67 { return "Empurrar/puxar = \(r.fmt(1)): mais puxar que empurrar — ótimo para postura." }
        return "Empurrar/puxar = \(r.fmt(1)): equilibrado (ideal entre 0,7 e 1,3)."
    }

    private func share(_ t: String, _ v: Double, _ c: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(Int((v * 100).rounded()))%").font(.subheadline.bold().monospacedDigit()).foregroundStyle(c)
            Text(t).font(.caption2).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Visão do programa inteiro: séries semanais e frequência por músculo.
struct WeeklyProgramCard: View {
    let routines: [WorkoutRoutine]

    private var stats: (sets: [Muscle: Double], freq: [Muscle: Int]) {
        let scheduled = routines.filter { $0.weekday != 0 }
        let list = scheduled.isEmpty ? routines : scheduled
        var sets: [Muscle: Double] = [:]
        var freq: [Muscle: Int] = [:]
        for r in list {
            var hit = Set<Muscle>()
            for (m, v) in r.muscleSets { sets[m, default: 0] += v; if v >= 2 { hit.insert(m) } }
            for m in hit { freq[m, default: 0] += 1 }
        }
        return (sets, freq)
    }

    var body: some View {
        let (sets, freq) = stats
        let range = Muscle.weeklySetsRange
        let inRange = Muscle.trained.filter { range.contains(sets[$0] ?? 0) }.count
        Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Programa semanal").font(.headline)
                    Spacer()
                    Text("\(inRange)/\(Muscle.trained.count) músculos na faixa ideal").font(.caption.bold()).foregroundStyle(Theme.good)
                }
                ForEach(Muscle.trained) { m in
                    let n = sets[m] ?? 0, f = freq[m] ?? 0
                    let color: Color = n < range.lowerBound * 0.5 ? Theme.danger : (n < range.lowerBound ? Theme.warm
                                        : (n <= range.upperBound ? Theme.good : Theme.excellent))
                    HStack(spacing: 8) {
                        Text(m.label).font(.caption).frame(width: 84, alignment: .leading)
                        ProgressBar(progress: n / range.upperBound, tint: color, height: 7)
                        Text("\(n.fmt(0)) s").font(.caption.monospacedDigit()).frame(width: 34, alignment: .trailing)
                        Text("\(f)x").font(.caption2.bold()).foregroundStyle(f >= 2 ? Theme.good : .secondary).frame(width: 24)
                    }
                }
                Text("Séries por semana (s) e frequência (x por semana). Ideal para hipertrofia: 10–20 séries e 2x por semana por músculo.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}
