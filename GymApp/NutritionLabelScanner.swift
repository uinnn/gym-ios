import SwiftUI
import PhotosUI
import Vision

/// Lê a tabela nutricional de uma foto com OCR do próprio iPhone (Vision, offline) e converte para 100 g.
enum NutritionLabelReader {
    struct Result {
        var per100 = Nutrients()
        var serving: Double?
        var found = 0
        var allergens: [String] = []
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
        let full = lines.joined(separator: "\n")
        r.serving = serving(in: full)
        r.allergens = allergens(in: full)

        // Colunas: no rótulo novo (RDC 429/2020) há "100 g | porção | %VD"; no antigo, só a porção.
        var per100Col: Int? = nil
        if let header = lines.first(where: { $0.range(of: #"\b100\s*(g|ml)\b"#, options: .regularExpression) != nil }) {
            let nums = numbers(in: header).filter { $0.unit == "g" || $0.unit == "ml" }
            per100Col = nums.firstIndex { $0.value == 100 } ?? 0
        }

        enum Kind { case kcal, grams, milligrams }

        /// Só aceita números com a unidade certa (ou sem unidade) e depois do nome do nutriente,
        /// para não confundir "100 ml", "200 g" da porção ou %VD com o valor.
        func value(_ line: String, key: String, kind: Kind) -> Double? {
            let tail = line.range(of: key).map { String(line[$0.upperBound...]) } ?? line
            var nums: [Double] = []
            for x in numbers(in: tail) {
                switch (kind, x.unit) {
                case (.kcal, "kcal"), (.kcal, ""), (.grams, "g"), (.grams, ""), (.milligrams, "mg"), (.milligrams, ""):
                    nums.append(x.value)
                case (.milligrams, "g"): nums.append(x.value * 1000)
                case (.grams, "mg"): nums.append(x.value / 1000)
                default: continue   // %, kJ, ml, mcg…
                }
            }
            // No kcal, se houver número com "kcal", ignora os sem unidade (ex.: kJ lido sem a unidade).
            if kind == .kcal {
                let k = numbers(in: tail).filter { $0.unit == "kcal" }.map(\.value)
                if !k.isEmpty { nums = k }
            }
            guard !nums.isEmpty else { return nil }
            if let c = per100Col { return nums.indices.contains(c) ? nums[c] : nums[0] }
            return nums[0]
        }

        func find(_ keys: [String], not excl: [String] = [], _ kind: Kind = .grams) -> Double? {
            for l in lines where !excl.contains(where: l.contains) {
                guard let k = keys.first(where: l.contains) else { continue }
                if let v = value(l, key: k, kind: kind) { r.found += 1; return v }
            }
            return nil
        }

        var n = Nutrients()
        n.kcal = find(["valor energetico", "valor calorico", "energia"], .kcal) ?? 0
        n.carbs = find(["carboidratos", "carboidrato"], not: ["acucar"]) ?? 0
        n.sugar = find(["acucares totais", "acucar total"]) ?? find(["acucares"], not: ["adicionad", "alcool"]) ?? 0
        n.protein = find(["proteinas", "proteina"]) ?? 0
        n.fat = find(["gorduras totais", "gordura total", "lipidios"]) ?? 0
        n.saturated = find(["saturadas", "saturada"]) ?? 0
        n.fiber = find(["fibras alimentares", "fibra alimentar", "fibras", "fibra"]) ?? 0
        n.sodium = find(["sodio"], .milligrams) ?? 0

        // Conferência: kcal ≈ 4·carbo + 4·proteína + 9·gordura. Se não bater, usa o calculado.
        let calc = 4 * n.carbs + 4 * n.protein + 9 * n.fat
        if calc > 0, n.kcal <= 0 || abs(n.kcal - calc) / calc > 0.5 { n.kcal = calc.rounded() }
        if n.sugar > n.carbs { n.sugar = 0 }
        if n.saturated > n.fat { n.saturated = 0 }

        // Sem coluna de 100 g: os valores são da porção.
        if per100Col == nil, let s = r.serving, s > 0 { n = n.scaled(100 / s) }
        r.per100 = n
        return r
    }

    // MARK: Alérgicos (RDC 26/2015) e glúten/lactose

    private static let allergenKeys: [(String, [String])] = [
        ("Leite", ["leite", "derivados de leite", "laticin"]), ("Ovo", ["ovo"]), ("Soja", ["soja"]),
        ("Trigo", ["trigo"]), ("Amendoim", ["amendoim"]),
        ("Castanhas/nozes", ["castanha", "nozes", "amendoa", "avela", "pistache", "macadamia", "peca"]),
        ("Peixe", ["peixe"]), ("Crustáceos", ["crustace", "camarao"]), ("Centeio/cevada/aveia", ["centeio", "cevada", "aveia"]),
        ("Látex natural", ["latex"]),
    ]

    /// Lê "ALÉRGICOS: CONTÉM ... PODE CONTER ...", "CONTÉM GLÚTEN" e "CONTÉM LACTOSE".
    static func allergens(in text: String) -> [String] {
        let t = text.replacingOccurrences(of: "\n", with: " ")
        func segment(after key: String) -> String? {
            guard let r = t.range(of: key) else { return nil }
            let rest = t[r.upperBound...]
            let end = rest.firstIndex { $0 == "." } ?? rest.endIndex
            return String(rest[..<end])
        }
        var out: [String] = []
        let alergicos = t.range(of: "alergicos") != nil
        let contem = alergicos ? (segment(after: "alergicos") ?? "") : ""
        let mainPart = contem.components(separatedBy: "pode conter").first ?? contem
        let traces = segment(after: "pode conter") ?? ""
        for (label, keys) in allergenKeys {
            if keys.contains(where: mainPart.contains) { out.append("Contém \(label.lowercased())") }
            else if keys.contains(where: traces.contains) { out.append("Pode conter \(label.lowercased())") }
        }
        if t.contains("contem gluten") && !t.contains("nao contem gluten") { out.append("Contém glúten") }
        if t.contains("contem lactose") && !t.contains("nao contem lactose") && !t.contains("zero lactose") { out.append("Contém lactose") }
        return out
    }

    private static func groupRows(_ pieces: [Piece]) -> [String] {
        let sorted = pieces.sorted { $0.box.midY > $1.box.midY }
        var rows: [(y: Double, h: Double, items: [Piece])] = []
        for p in sorted {
            if let i = rows.indices.min(by: { abs(rows[$0].y - p.box.midY) < abs(rows[$1].y - p.box.midY) }),
               abs(rows[i].y - p.box.midY) < min(rows[i].h, p.box.height) * 0.5 {
                rows[i].items.append(p)
            } else {
                rows.append((p.box.midY, p.box.height, [p]))
            }
        }
        return rows.sorted { $0.y > $1.y }
            .map { $0.items.sorted { $0.box.minX < $1.box.minX }.map(\.text).joined(separator: " ") }
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
            .fullScreenCover(isPresented: $showCamera) { CameraPicker { process($0) }.ignoresSafeArea() }
            .onChange(of: item) { _, it in
                guard let it else { return }
                Task {
                    if let d = try? await it.loadTransferable(type: Data.self), let img = UIImage(data: d) { process(img) }
                    item = nil
                }
            }
            if busy {
                HStack { ProgressView(); Text("Lendo a tabela…").foregroundStyle(.secondary) }
            } else if let message {
                Text(message).font(.footnote).foregroundStyle(.secondary)
            }
        } header: {
            Text("Ler tabela nutricional")
        } footer: {
            Text("Fotografe a tabela reta e bem iluminada; inclua a lista de ingredientes para detectar alérgicos. A leitura é feita no próprio iPhone; confira os valores antes de salvar.")
        }
    }

    private func process(_ img: UIImage) {
        busy = true
        Task {
            let r = await NutritionLabelReader.read(img)
            busy = false
            if r.found == 0 && r.allergens.isEmpty {
                message = "Não consegui ler a tabela. Tente outra foto, mais perto e sem reflexo."
            } else {
                message = "\(r.found) de 8 valores lidos\(r.serving.map { ", porção de \(Int($0)) g" } ?? ""). Confira abaixo."
                if !r.allergens.isEmpty { message! += " ⚠️ " + r.allergens.joined(separator: ", ") + "." }
                onResult(r)
            }
        }
    }
}
