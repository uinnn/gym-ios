import SwiftUI
import PhotosUI
import Vision

/// Lê a tabela nutricional de uma foto com OCR do próprio iPhone (Vision, offline) e converte para 100 g.
enum NutritionLabelReader {
    struct Result {
        var per100 = Nutrients()
        var serving: Double?
        var found = 0
    }

    static func read(_ image: UIImage) async -> Result {
        guard let cg = image.cgImage else { return Result() }
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        return await Task.detached(priority: .userInitiated) {
            let req = VNRecognizeTextRequest()
            req.recognitionLevel = .accurate
            req.recognitionLanguages = ["pt-BR"]
            req.usesLanguageCorrection = false
            try? VNImageRequestHandler(cgImage: cg, orientation: orientation).perform([req])
            let obs = (req.results ?? []).compactMap { o -> Piece? in
                guard let t = o.topCandidates(1).first?.string else { return nil }
                return Piece(text: t, box: o.boundingBox)
            }
            return parse(obs)
        }.value
    }

    struct Piece { let text: String; let box: CGRect }

    // MARK: Parser

    /// Agrupa pedaços de texto em linhas (pela altura na foto) e lê cada nutriente.
    static func parse(_ pieces: [Piece]) -> Result {
        let rows = groupRows(pieces)
        let lines = rows.map { norm($0) }
        var r = Result()
        r.serving = serving(in: lines.joined(separator: "\n"))

        // Colunas: no rótulo novo (RDC 429/2020) há "100 g | porção | %VD"; no antigo, só a porção.
        var per100Col: Int? = nil
        if let header = lines.first(where: { $0.range(of: #"\b100\s*(g|ml)\b"#, options: .regularExpression) != nil }) {
            let nums = numbers(in: header).filter { $0.unit == "g" || $0.unit == "ml" }
            per100Col = nums.firstIndex { $0.value == 100 } ?? 0
        }

        func value(_ line: String, kcal: Bool = false) -> Double? {
            var nums = numbers(in: line).filter { $0.unit != "%" && $0.unit != "kj" }
            if kcal {
                let k = nums.filter { $0.unit == "kcal" }
                if !k.isEmpty { nums = k }
            }
            guard !nums.isEmpty else { return nil }
            if let c = per100Col {
                return nums.indices.contains(c) ? nums[c].value : (c == 0 ? nums[0].value : nil)
            }
            return nums[0].value
        }

        func find(_ keys: [String], not excl: [String] = [], kcal: Bool = false) -> Double? {
            for l in lines where keys.contains(where: l.contains) && !excl.contains(where: l.contains) {
                if let v = value(l, kcal: kcal) { r.found += 1; return v }
            }
            return nil
        }

        var n = Nutrients()
        n.kcal = find(["valor energetico", "valor calorico", "energia"], kcal: true) ?? 0
        n.carbs = find(["carboidrato"], not: ["acucar"]) ?? 0
        n.sugar = find(["acucares totais", "acucar total"]) ?? find(["acucares"], not: ["adicionad", "alcool"]) ?? 0
        n.protein = find(["proteina"]) ?? 0
        n.fat = find(["gorduras totais", "gordura total", "lipidios"]) ?? 0
        n.saturated = find(["saturada"]) ?? 0
        n.fiber = find(["fibra"]) ?? 0
        n.sodium = find(["sodio"]) ?? 0

        // Sem coluna de 100 g: os valores são da porção.
        if per100Col == nil, let s = r.serving, s > 0 { n = n.scaled(100 / s) }
        r.per100 = n
        return r
    }

    private static func groupRows(_ pieces: [Piece]) -> [String] {
        let sorted = pieces.sorted { $0.box.midY > $1.box.midY }
        var rows: [[Piece]] = []
        for p in sorted {
            if let last = rows.last?.first, abs(last.box.midY - p.box.midY) < max(last.box.height, p.box.height) * 0.6 {
                rows[rows.count - 1].append(p)
            } else {
                rows.append([p])
            }
        }
        return rows.map { $0.sorted { $0.box.minX < $1.box.minX }.map(\.text).joined(separator: " ") }
    }

    static func norm(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "pt_BR"))
    }

    private static let numberRegex = try! NSRegularExpression(
        pattern: #"(\d+(?:[.,]\d+)?)\s*(%|kcal|kj|mg|mcg|g|ml)?"#, options: [.caseInsensitive])

    struct Num { let value: Double; let unit: String }

    static func numbers(in line: String) -> [Num] {
        let ns = line as NSString
        return numberRegex.matches(in: line, range: NSRange(location: 0, length: ns.length)).compactMap { m in
            let raw = ns.substring(with: m.range(at: 1)).replacingOccurrences(of: ",", with: ".")
            guard let v = Double(raw) else { return nil }
            let unit = m.range(at: 2).location == NSNotFound ? "" : ns.substring(with: m.range(at: 2)).lowercased()
            return Num(value: v, unit: unit)
        }
    }

    private static let servingRegex = try! NSRegularExpression(
        pattern: #"porc(?:ao|oes)[^0-9\n]{0,25}(\d+(?:[.,]\d+)?)\s*(g|ml)\b"#, options: [.caseInsensitive])

    static func serving(in text: String) -> Double? {
        let ns = text as NSString
        guard let m = servingRegex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) else { return nil }
        return Double(ns.substring(with: m.range(at: 1)).replacingOccurrences(of: ",", with: "."))
    }
}

/// Botões de câmera/galeria que leem a tabela e devolvem o resultado.
struct NutritionLabelScanSection: View {
    var onResult: (NutritionLabelReader.Result) -> Void
    @State private var showCamera = false
    @State private var item: PhotosPickerItem?
    @State private var busy = false
    @State private var message: String?

    var body: some View {
        Section {
            HStack(spacing: 12) {
                Button { showCamera = true } label: {
                    Label("Fotografar", systemImage: "camera.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                PhotosPicker(selection: $item, matching: .images) {
                    Label("Galeria", systemImage: "photo").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .disabled(busy)
            if busy {
                HStack { ProgressView(); Text("Lendo a tabela…").foregroundStyle(.secondary) }
            } else if let message {
                Text(message).font(.footnote).foregroundStyle(.secondary)
            }
        } header: {
            Text("Ler tabela nutricional")
        } footer: {
            Text("Fotografe a tabela reta e bem iluminada. A leitura é feita no próprio iPhone; confira os valores antes de salvar.")
        }
        .sheet(isPresented: $showCamera) { CameraPicker { process($0) }.ignoresSafeArea() }
        .onChange(of: item) { _, it in
            guard let it else { return }
            Task {
                if let d = try? await it.loadTransferable(type: Data.self), let img = UIImage(data: d) { process(img) }
                item = nil
            }
        }
    }

    private func process(_ img: UIImage) {
        busy = true
        Task {
            let r = await NutritionLabelReader.read(img)
            busy = false
            if r.found == 0 {
                message = "Não consegui ler a tabela. Tente outra foto, mais perto e sem reflexo."
            } else {
                message = "\(r.found) de 8 valores lidos\(r.serving.map { ", porção de \(Int($0)) g" } ?? ""). Confira abaixo."
                onResult(r)
            }
        }
    }
}
