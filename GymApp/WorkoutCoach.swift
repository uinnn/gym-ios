import Foundation

/// Progressão dupla (reps → carga) e aquecimento automático.
enum WorkoutCoach {
    struct Plan { var sets: [SetLog]; var hint: String? }

    /// Menor salto de carga prático para o equipamento.
    static func increment(_ x: Exercise?) -> Double {
        switch x?.equipment {
        case .barbell: 2.5
        case .dumbbell, .kettlebell: 2
        case .machine, .cable: (x?.primary.contains { [.quads, .glutes, .hamstrings, .back].contains($0) } ?? false) ? 5 : 2.5
        case .bodyweight: 0
        default: 1
        }
    }

    static func round(_ kg: Double, step: Double) -> Double {
        guard step > 0 else { return kg }
        return (kg / step).rounded() * step
    }

    /// Bateu o topo da faixa em todas as séries (e sem esforço máximo) → sobe a carga e volta ao início da faixa.
    /// Senão mantém a carga e tenta +1 rep. Errou muito abaixo da faixa → reduz ~10%.
    static func progression(prev: [SetLog], sets n: Int, range: ClosedRange<Int>, exercise x: Exercise?) -> Plan {
        guard !prev.isEmpty, let topKg = prev.map(\.kg).max() else {
            return Plan(sets: (0..<n).map { _ in var s = SetLog(); s.reps = range.upperBound; return s }, hint: nil)
        }
        let work = prev.filter { $0.kg >= topKg * 0.95 }
        let minReps = work.map(\.reps).min() ?? 0
        let maxRPE = work.compactMap(\.rpe).max() ?? 0
        let inc = increment(x)
        let bodyweight = x?.equipment == .bodyweight

        var kg = topKg, reps: Int, hint: String
        if minReps >= range.upperBound && maxRPE < 9.5 {
            if bodyweight || topKg == 0 {
                reps = range.upperBound + 1
                hint = "Você bateu \(range.upperBound) reps em todas: tente +1 rep ou adicione peso"
            } else {
                kg = topKg + inc
                reps = range.lowerBound
                hint = "Suba para \(kg.fmt(1)) kg (+\(inc.fmt(1))) e faça \(range.lowerBound)+ reps"
            }
        } else if minReps < range.lowerBound - 2 && topKg > 0 && !bodyweight {
            kg = max(0, round(topKg * 0.9, step: inc))
            reps = range.lowerBound
            hint = "Ficou abaixo da faixa: reduza para \(kg.fmt(1)) kg e foque na técnica"
        } else {
            reps = min(range.upperBound, max(range.lowerBound, minReps + 1))
            hint = "Mantenha \(topKg.fmt(1)) kg e busque \(reps) reps em todas as séries"
        }
        let sets = (0..<n).map { _ -> SetLog in var s = SetLog(); s.kg = kg; s.reps = reps; return s }
        return Plan(sets: sets, hint: hint)
    }

    /// Rampa de aquecimento conforme a carga de trabalho.
    static func warmups(topKg: Double, exercise x: Exercise) -> [SetLog] {
        let step = max(increment(x), 1)
        let ramp: [(Double, Int)]
        switch topKg {
        case ..<20: return []
        case ..<50: ramp = [(0.5, 10), (0.75, 5)]
        case ..<100: ramp = [(0.4, 10), (0.6, 6), (0.8, 3)]
        default: ramp = [(0.4, 8), (0.6, 5), (0.75, 3), (0.9, 1)]
        }
        return ramp.map { f, r in
            var s = SetLog(); s.kind = .warmup; s.kg = round(topKg * f, step: step); s.reps = r; return s
        }
    }
}
