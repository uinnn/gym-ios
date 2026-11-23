import Foundation

/// "Equilibrar músculos": ajusta o programa gerado para que cada músculo principal fique
/// entre 10 e 20 séries semanais e seja treinado pelo menos 2x por semana.
/// Séries contam 1 para o músculo principal e 0,5 para os secundários (mesma regra das estatísticas).
extension ProgramGenerator {
    static let balancedMuscles: [Muscle] = [.chest, .back, .shoulders, .biceps, .triceps, .quads, .hamstrings, .glutes, .calves, .abs]

    static func balance(_ plans: inout [Planned], goal: TrainingGoal, place: TrainingPlace,
                        focus: [Muscle: Int], maxExercises: Int) {
        guard plans.count >= 2 else { return }
        let (_, rmin, rmax, rest) = goal.scheme
        let home = place == .home
        let cap = maxExercises + 2
        let range = Muscle.weeklySetsRange
        var targets = balancedMuscles
        for (m, w) in focus where w > 0 && !targets.contains(m) { targets.append(m) }
        if home { targets.removeAll { $0 == .calves } }   // sem aparelho, panturrilha fica opcional

        func goalSets(_ m: Muscle) -> Double {
            switch focus[m] ?? 0 {
            case 3: 18
            case 2: 16
            case 1: 14
            default: 12
            }
        }
        func weekly(_ m: Muscle) -> Double {
            var v = 0.0
            for p in plans {
                for i in p.items {
                    guard let x = i.exercise, x.kind != .cardio else { continue }
                    if x.primary.contains(m) { v += Double(i.sets) } else if x.secondary.contains(m) { v += Double(i.sets) * 0.5 }
                }
            }
            return v
        }
        func trains(_ p: Planned, _ m: Muscle) -> Bool { p.items.contains { $0.exercise?.primary.contains(m) == true } }
        func freq(_ m: Muscle) -> Int { plans.filter { trains($0, m) }.count }
        func daySets(_ p: Planned) -> Int { p.items.reduce(0) { $0 + $1.sets } }
        func strengthCount(_ p: Planned) -> Int { p.items.filter { $0.exercise?.kind != .cardio }.count }

        func candidate(_ m: Muscle, notIn p: Planned) -> Exercise? {
            let used = Set(p.items.map(\.exerciseID))
            return ExerciseCatalog.all
                .filter { $0.primary.first == m && $0.kind != .cardio && !used.contains($0.id)
                    && ExerciseAlternatives.allowed($0.equipment, home: home) }
                .max { $0.score(style: .best, equip: .mixed) < $1.score(style: .best, equip: .mixed) }
        }
        func newItem(_ x: Exercise, sets: Int = 3) -> RoutineItem {
            let timed = x.kind == .timed
            return RoutineItem(exerciseID: x.id, sets: sets, repsMin: timed ? 1 : rmin, repsMax: timed ? 1 : rmax,
                               restSeconds: x.isCompound ? rest : max(60, rest - 30))
        }
        func insert(_ it: RoutineItem, day k: Int) {
            let at = plans[k].items.firstIndex { $0.exercise?.kind == .cardio } ?? plans[k].items.endIndex
            plans[k].items.insert(it, at: at)
        }
        /// Dia que ainda não treina o músculo, com espaço e menos volume.
        func freeDay(for m: Muscle, requireNew: Bool) -> Int? {
            plans.indices
                .filter { (!requireNew || !trains(plans[$0], m)) && strengthCount(plans[$0]) < cap && candidate(m, notIn: plans[$0]) != nil }
                .min { daySets(plans[$0]) < daySets(plans[$1]) }
        }

        for _ in 0..<4 {
            for m in targets {
                // 1) Frequência mínima de 2x por semana
                while freq(m) < 2, let k = freeDay(for: m, requireNew: true), let x = candidate(m, notIn: plans[k]) {
                    insert(newItem(x), day: k)
                }
                // 2) Volume mínimo: primeiro +1 série nos exercícios do músculo (até 5), depois um exercício novo
                var guardN = 0
                while weekly(m) < goalSets(m), guardN < 30 {
                    guardN += 1
                    var best: (Int, Int)?
                    for k in plans.indices {
                        for j in plans[k].items.indices where plans[k].items[j].exercise?.primary.first == m && plans[k].items[j].sets < 5 {
                            if best == nil || plans[k].items[j].sets < plans[best!.0].items[best!.1].sets { best = (k, j) }
                        }
                    }
                    if let b = best {
                        plans[b.0].items[b.1].sets += 1
                    } else if let k = freeDay(for: m, requireNew: false), let x = candidate(m, notIn: plans[k]) {
                        insert(newItem(x), day: k)
                    } else { break }
                }
            }
            // 3) Teto de 20 séries para qualquer músculo
            for m in Muscle.trained where m != .cardio {
                var guardN = 0
                while weekly(m) > range.upperBound, guardN < 40 {
                    guardN += 1
                    var worst: (Int, Int)?
                    for k in plans.indices {
                        for j in plans[k].items.indices where plans[k].items[j].exercise?.primary.contains(m) == true && plans[k].items[j].sets > 2 {
                            if worst == nil || plans[k].items[j].sets > plans[worst!.0].items[worst!.1].sets { worst = (k, j) }
                        }
                    }
                    if let w = worst {
                        plans[w.0].items[w.1].sets -= 1
                    } else if let k = plans.indices.first(where: { k in
                        plans[k].items.contains { $0.exercise?.primary.first == m && $0.exercise?.isIsolation == true } && freq(m) > 2
                    }), let j = plans[k].items.firstIndex(where: { $0.exercise?.primary.first == m && $0.exercise?.isIsolation == true }) {
                        plans[k].items.remove(at: j)
                    } else { break }
                }
            }
            let ok = targets.allSatisfy { freq($0) >= 2 && weekly($0) >= range.lowerBound && weekly($0) <= range.upperBound }
            if ok { break }
        }
        // compostos primeiro, cardio no fim
        for k in plans.indices {
            plans[k].items.sort { a, b in
                let ka = a.exercise?.kind == .cardio, kb = b.exercise?.kind == .cardio
                if ka != kb { return !ka }
                return (a.exercise?.isCompound == true) && (b.exercise?.isCompound != true)
            }
        }
    }

    /// Quantos dias por semana cada músculo é treinado como principal.
    static func frequency(_ plans: [Planned]) -> [Muscle: Int] {
        var f: [Muscle: Int] = [:]
        for p in plans {
            var seen = Set<Muscle>()
            for i in p.items { for m in i.exercise?.primary ?? [] where seen.insert(m).inserted { f[m, default: 0] += 1 } }
        }
        return f
    }
}
