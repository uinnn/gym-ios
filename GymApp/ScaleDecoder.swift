import Foundation

struct WeightReading {
    let kg: Double
    var isStable = false
    var rawImpedance: Int?   // bytes 4–5; significado ainda a confirmar
}

/// Formato da balança OKOK/Chipsea, descoberto pelos logs (15 bytes de anúncio):
///
///     C0 | cont | peso BE ÷100 | ?? ?? (BE) | 0A 01 | status | MAC (6 bytes)
///     0    1      2–3            4–5          6–7     8        9–14
///
/// - `cont` só incrementa a cada anúncio.
/// - `status` 0x24 = medindo, 0x25 = peso estável (bit 0).
/// - bytes 4–5 vieram sempre 0x1770 (6000); possivelmente a impedância (600,0 Ω) ou um valor fixo.
enum OKOKFormat {
    static func decode(_ data: Data) -> WeightReading? {
        let b = [UInt8](data)
        guard b.count == 15, b[0] == 0xC0, b[6] == 0x0A else { return nil }
        let raw = Int(b[2]) << 8 | Int(b[3])
        guard raw > 0 else { return nil }
        let imp = Int(b[4]) << 8 | Int(b[5])
        return WeightReading(kg: Double(raw) / 100,
                             isStable: b[8] & 0x01 == 1,
                             rawImpedance: imp > 0 ? imp : nil)
    }
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
        if source == "adv", let r = OKOKFormat.decode(data) { return r }
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
