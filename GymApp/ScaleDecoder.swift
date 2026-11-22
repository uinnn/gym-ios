import Foundation

struct WeightReading {
    let kg: Double
}

/// Onde o peso está dentro do pacote: posição do byte, ordem dos bytes e divisor.
struct WeightFormat: Codable, Equatable, Hashable {
    var source: String      // "adv" ou UUID da característica
    var offset: Int
    var bigEndian: Bool
    var divisor: Double     // 10 → 0,1 kg; 100 → 0,01 kg

    var label: String {
        "byte \(offset) · \(bigEndian ? "BE" : "LE") · ÷\(Int(divisor))"
    }

    func read(_ data: Data) -> Double? {
        let b = [UInt8](data)
        guard offset + 1 < b.count else { return nil }
        let hi = bigEndian ? b[offset] : b[offset + 1]
        let lo = bigEndian ? b[offset + 1] : b[offset]
        return Double(UInt16(hi) << 8 | UInt16(lo)) / divisor
    }
}

/// Decodificador de peso.
///
/// O formato exato dos dados da balança varia por modelo. Em vez de adivinhar,
/// o app mostra todos os números "plausíveis" de cada pacote e você escolhe o que bate
/// com o visor da balança. Essa escolha fica salva e passa a ser usada para ler o peso.
enum ScaleDecoder {
    private static let key = "weightFormat"

    static var savedFormat: WeightFormat? {
        get {
            guard let d = UserDefaults.standard.data(forKey: key) else { return nil }
            return try? JSONDecoder().decode(WeightFormat.self, from: d)
        }
        set {
            if let newValue, let d = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(d, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
    }

    static func decode(_ data: Data, source: String) -> WeightReading? {
        guard let f = savedFormat, f.source == source, let kg = f.read(data) else { return nil }
        return WeightReading(kg: kg)
    }

    /// Todos os valores entre 10 e 250 kg que o pacote poderia representar.
    static func candidates(_ data: Data, source: String) -> [(WeightFormat, Double)] {
        var out: [(WeightFormat, Double)] = []
        for offset in 0..<max(0, data.count - 1) {
            for be in [true, false] {
                for div in [10.0, 100.0] {
                    let f = WeightFormat(source: source, offset: offset, bigEndian: be, divisor: div)
                    if let v = f.read(data), (10...250).contains(v) { out.append((f, v)) }
                }
            }
        }
        return out
    }
}

extension Data {
    var hex: String { map { String(format: "%02X", $0) }.joined(separator: " ") }
}
