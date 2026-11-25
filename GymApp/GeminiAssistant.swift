import SwiftUI
import UIKit
import Security

// MARK: - Cofre (Keychain) para a chave do Gemini

enum SecureStore {
    private static func query(_ account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "gym.secure", kSecAttrAccount as String: account]
    }

    static func get(_ account: String) -> String? {
        var q = query(account)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: AnyObject?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let d = out as? Data else { return nil }
        return String(data: d, encoding: .utf8)
    }

    static func set(_ account: String, _ value: String?) {
        SecItemDelete(query(account) as CFDictionary)
        guard let v = value, !v.isEmpty, let d = v.data(using: .utf8) else { return }
        var q = query(account)
        q[kSecValueData as String] = d
        q[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(q as CFDictionary, nil)
    }
}

// MARK: - Cliente do Gemini

enum Gemini {
    static var apiKey: String? {
        get { SecureStore.get("gemini.key") }
        set { SecureStore.set("gemini.key", newValue?.trimmingCharacters(in: .whitespacesAndNewlines)) }
    }
    static let defaultModel = "gemini-flash-lite-latest"
    static var model: String {
        get {
            let d = UserDefaults.standard
            if !d.bool(forKey: "gemini.liteMigrated") {          // passa a usar o Flash-Lite (mais rápido, limite maior)
                d.set(true, forKey: "gemini.liteMigrated")
                d.set(defaultModel, forKey: "gemini.model")
            }
            return d.string(forKey: "gemini.model").flatMap { $0.isEmpty ? nil : $0 } ?? defaultModel
        }
        set { UserDefaults.standard.set(newValue.trimmingCharacters(in: .whitespaces), forKey: "gemini.model") }
    }
    static var hasKey: Bool { !(apiKey ?? "").isEmpty }
    /// Há alguma IA disponível (Gemini ou a reserva Groq).
    static var isConfigured: Bool { hasKey || Groq.hasKey }
    /// Quem respondeu o último pedido (para mostrar na tela).
    static var lastProvider = "Gemini"

    enum Failure: LocalizedError {
        case noKey, badKey, quota, network, modelNotFound, invalid(String)
        var errorDescription: String? {
            switch self {
            case .noKey: "Configure sua chave do Gemini primeiro."
            case .badKey: "Chave do Gemini inválida ou sem permissão. Confira em Ajustes do Assistente."
            case .quota: "Limite gratuito do Gemini atingido. Espere um pouco (o limite renova por minuto e por dia)."
            case .network: "Sem conexão com o Gemini. As regras locais continuam funcionando."
            case .modelNotFound: "Modelo não encontrado. Toque em \"Buscar modelos disponíveis\"."
            case .invalid(let s): "O Gemini respondeu algo inesperado: \(s)"
            }
        }
    }

    struct Item: Decodable {
        var type: String
        var name: String?
        var grams: Double?
        var meal: String?
        var value: Double?
        var sets: Int?
        var reps: Int?
        var kg: Double?
        var km: Double?
        var minutes: Double?
        var part: String?
        var kcal100: Double?
        var protein100: Double?
        var carbs100: Double?
        var fat100: Double?
        var fiber100: Double?
        var dayOffset: Int?
    }

    struct Result: Decodable {
        var reply: String?
        var items: [Item]?
    }

    static let mealList = Meal.allCases.map(\.rawValue)

    private static var schema: [String: Any] {
        let num: [String: Any] = ["type": "NUMBER"]
        let int: [String: Any] = ["type": "INTEGER"]
        let str: [String: Any] = ["type": "STRING"]
        return [
            "type": "OBJECT",
            "properties": [
                "reply": str,
                "items": [
                    "type": "ARRAY",
                    "items": [
                        "type": "OBJECT",
                        "properties": [
                            "type": ["type": "STRING", "enum": ["food", "water", "weight", "sleep", "mood", "exercise", "cardio", "measure"]],
                            "name": str, "grams": num,
                            "meal": ["type": "STRING", "enum": mealList],
                            "value": num, "sets": int, "reps": int, "kg": num, "km": num, "minutes": num,
                            "part": ["type": "STRING", "enum": BodyPart.allCases.map(\.rawValue)],
                            "kcal100": num, "protein100": num, "carbs100": num, "fat100": num, "fiber100": num, "dayOffset": int,
                        ],
                        "required": ["type"],
                    ],
                ],
            ],
            "required": ["reply", "items"],
        ]
    }

    static let system = """
    Você é o assistente do app de academia e nutrição "Gym", em português do Brasil. Responda SEMPRE em JSON no esquema pedido.
    Tarefas:
    1) Registro: transforme o que o usuário comeu, bebeu ou fez em itens.
       - food: name = nome simples em português no estilo da tabela TACO (ex.: "Arroz, tipo 1, cozido", "Frango, peito, sem pele, grelhado", "Feijão, carioca, cozido"); grams = gramas estimadas comidas; meal = uma de \(mealList.joined(separator: ", ")); kcal100/protein100/carbs100/fat100/fiber100 = valores por 100 g estimados.
         Para pratos prontos (ex.: "PF", "marmita", "strogonoff"), quebre em ingredientes com gramas. Porções brasileiras típicas: 1 escumadeira de arroz ≈ 90 g, 1 concha de feijão ≈ 100 g, 1 pão francês 50 g, 1 ovo 50 g, 1 bife 100–120 g.
       - water: value = ml. weight: value = kg. sleep: value = horas. mood: value = 1 a 5.
       - exercise: name = nome do exercício em português, sets, reps, kg (carga por série).
       - cardio: name = "corrida", "caminhada" ou "bike"; km; minutes.
       - measure: part (parte do corpo), value em cm.
       - dayOffset: 0 = hoje, -1 = ontem.
    2) Foto: identifique cada alimento visível e estime as gramas; use items do tipo food e um reply curto descrevendo o prato e o total estimado de kcal e proteína.
    3) Pergunta ou pedido de conselho: responda em reply (curto, prático, até 6 frases) usando os DADOS DO USUÁRIO abaixo; items vazio, a não ser que o usuário peça para registrar algo.
    Nunca invente registros que o usuário não mencionou. Se algo for ambíguo, faça a estimativa mais comum e diga no reply. Não dê diagnóstico médico.
    """

    /// Pergunta ao Gemini; se ele falhar (limite, rede, modelo fora do ar…) e o Groq estiver configurado, usa o Groq.
    static func ask(_ text: String, image: UIImage?, context: String) async throws -> Result {
        if hasKey {
            do {
                let r = try await askGemini(text, image: image, context: context)
                lastProvider = "Gemini"
                return r
            } catch {
                guard Groq.hasKey else { throw error }
            }
        }
        guard Groq.hasKey else { throw Failure.noKey }
        let r = try await Groq.ask(text, image: image, context: context)
        lastProvider = "Groq"
        return r
    }

    static func askGemini(_ text: String, image: UIImage?, context: String) async throws -> Result {
        do {
            return try await send(text, image: image, context: context)
        } catch Failure.modelNotFound {
            // O modelo salvo saiu do ar: pergunta ao Google quais existem e tenta de novo com o melhor.
            guard let best = try await availableModels().first else { throw Failure.invalid("nenhum modelo disponível para esta chave") }
            model = best
            return try await send(text, image: image, context: context)
        }
    }

    /// Modelos que aceitam generateContent, do mais indicado (Flash mais novo) para o menos.
    static func availableModels() async throws -> [String] {
        guard let key = apiKey, !key.isEmpty else { throw Failure.noKey }
        var req = URLRequest(url: URL(string: "https://generativelanguage.googleapis.com/v1beta/models?pageSize=200")!)
        req.setValue(key, forHTTPHeaderField: "x-goog-api-key")
        req.timeoutInterval = 20
        let (data, resp): (Data, URLResponse)
        do { (data, resp) = try await URLSession.shared.data(for: req) } catch { throw Failure.network }
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        if code == 400 || code == 401 || code == 403 { throw Failure.badKey }
        guard code == 200, let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let list = obj["models"] as? [[String: Any]] else { throw Failure.invalid("lista de modelos, código \(code)") }
        let names = list.compactMap { m -> String? in
            guard let n = m["name"] as? String,
                  (m["supportedGenerationMethods"] as? [String])?.contains("generateContent") == true else { return nil }
            return n.replacingOccurrences(of: "models/", with: "")
        }
        let bad = ["embedding", "image", "tts", "audio", "live", "vision", "aqa", "imagen", "veo", "thinking", "exp", "preview", "learnlm", "gemma"]
        func score(_ n: String) -> Double {
            var s = 0.0
            if n.contains("flash") { s += 100 }
            if n.contains("lite") { s += 30 }      // Flash-Lite primeiro: mais rápido e com o maior limite grátis
            if n.contains("pro") { s += 20 }
            if n.hasSuffix("latest") { s += 15 }
            if bad.contains(where: n.contains) { s -= 200 }
            // versão (ex.: gemini-3.0-flash → 3.0)
            if let r = n.range(of: #"\d+(\.\d+)?"#, options: .regularExpression), let v = Double(n[r]) { s += v * 10 }
            return s
        }
        return names.filter { $0.hasPrefix("gemini") }.sorted { score($0) > score($1) }
    }

    private static func send(_ text: String, image: UIImage?, context: String) async throws -> Result {
        guard let key = apiKey, !key.isEmpty else { throw Failure.noKey }
        var parts: [[String: Any]] = [["text": "DADOS DO USUÁRIO:\n\(context)\n\nMENSAGEM:\n\(text.isEmpty ? "(veja a foto)" : text)"]]
        if let image, let jpg = image.downscaled(maxSide: 1024).jpegData(compressionQuality: 0.7) {
            parts.append(["inline_data": ["mime_type": "image/jpeg", "data": jpg.base64EncodedString()]])
        }
        let body: [String: Any] = [
            "system_instruction": ["parts": [["text": system]]],
            "contents": [["role": "user", "parts": parts]],
            "generationConfig": ["responseMimeType": "application/json", "responseSchema": schema, "temperature": 0.2],
        ]
        let model = model.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "gemini-flash-latest"
        var req = URLRequest(url: URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent")!)
        req.httpMethod = "POST"
        req.timeoutInterval = 45
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(key, forHTTPHeaderField: "x-goog-api-key")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp): (Data, URLResponse)
        do { (data, resp) = try await URLSession.shared.data(for: req) } catch { throw Failure.network }
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        if code == 429 { throw Failure.quota }
        if code == 404 { throw Failure.modelNotFound }
        if code == 400 || code == 401 || code == 403 {
            let msg = String(data: data, encoding: .utf8) ?? ""
            if msg.contains("API_KEY") || msg.contains("API key") || code != 400 { throw Failure.badKey }
            throw Failure.invalid("erro \(code)")
        }
        guard code == 200,
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let cands = obj["candidates"] as? [[String: Any]],
              let content = cands.first?["content"] as? [String: Any],
              let ps = content["parts"] as? [[String: Any]],
              let json = ps.compactMap({ $0["text"] as? String }).first,
              let jd = json.data(using: .utf8) else { throw Failure.invalid("código \(code)") }
        do { return try JSONDecoder().decode(Result.self, from: jd) } catch { throw Failure.invalid("JSON") }
    }

    /// Resumo compacto dos dados do usuário para dar contexto às respostas.
    @MainActor static func context(_ d: AssistantData) -> String {
        let cal = Calendar.current
        var lines: [String] = []
        if let p = d.profile {
            lines.append("Perfil: \(p.sex == .male ? "homem" : "mulher"), \(p.age) anos, \(Int(p.heightCm)) cm, objetivo \(p.goal.label.lowercased()), peso meta \(p.goalWeightKg.fmt(1)) kg.")
        }
        let t = d.targets
        lines.append("Metas diárias: \(Int(t.kcal)) kcal, \(Int(t.protein)) g proteína, \(Int(t.carbs)) g carbo, \(Int(t.fat)) g gordura, \(Int(t.fiber)) g fibra, \(Int(t.water)) ml água.")
        for (label, offset) in [("Hoje", 0), ("Ontem", -1)] {
            guard let day = cal.date(byAdding: .day, value: offset, to: .now) else { continue }
            let logs = d.logs(on: day)
            let n = logs.map(\.nutrients).total
            var s = "\(label): \(Int(n.kcal)) kcal, \(Int(n.protein)) g prot, \(Int(n.carbs)) g carbo, \(Int(n.fat)) g gord, \(Int(n.fiber)) g fibra, água \(Int(d.waterMl(on: day))) ml."
            if offset == 0 && !logs.isEmpty {
                s += " Comidas: " + logs.prefix(20).map { "\($0.meal.label): \($0.name) \(Int($0.grams)) g" }.joined(separator: "; ") + "."
            }
            lines.append(s)
        }
        let week = (1...7).compactMap { cal.date(byAdding: .day, value: -$0, to: .now) }
        let kcals = week.map { d.logs(on: $0).map(\.nutrients.kcal).reduce(0, +) }.filter { $0 > 0 }
        if !kcals.isEmpty { lines.append("Média de kcal nos últimos dias registrados: \(Int(kcals.reduce(0, +) / Double(kcals.count))).") }
        if let w = d.weights.last {
            var s = "Peso atual \(w.kg.fmt(1)) kg (\(w.date.formatted(.dateTime.day().month())))."
            if let ref = d.weights.last(where: { $0.date <= cal.date(byAdding: .day, value: -30, to: .now)! }) {
                s += " Há 30 dias: \(ref.kg.fmt(1)) kg."
            }
            lines.append(s)
        }
        let recent = d.sessions.filter { !$0.isActive }.sorted { $0.start > $1.start }.prefix(4)
        if !recent.isEmpty {
            lines.append("Últimos treinos: " + recent.map { "\($0.name) em \($0.start.formatted(.dateTime.day().month())) (\(WorkoutMath.setsCount($0)) séries)" }.joined(separator: "; ") + ".")
        }
        let sleeps = d.sleeps.filter { $0.wake >= cal.date(byAdding: .day, value: -7, to: .now)! }
        if !sleeps.isEmpty { lines.append("Sono médio 7 dias: \((sleeps.map(\.hours).reduce(0, +) / Double(sleeps.count)).fmt(1)) h.") }
        lines.append("Agora: \(Date.now.formatted(.dateTime.weekday(.wide).hour().minute())).")
        return lines.joined(separator: "\n")
    }

    /// Converte a resposta em rascunhos, reaproveitando o banco de alimentos quando possível.
    @MainActor static func drafts(_ r: Result, data: AssistantData) -> [AssistantDraft] {
        var out: [AssistantDraft] = []
        let cal = Calendar.current
        if let reply = r.reply, !reply.isEmpty { out.append(AssistantDraft(kind: .answer, source: "", text: reply)) }
        for it in r.items ?? [] {
            let date = cal.date(byAdding: .day, value: min(0, max(-7, it.dayOffset ?? 0)), to: .now) ?? .now
            let meal = it.meal.flatMap(Meal.init(rawValue:)) ?? .lunch
            switch it.type {
            case "food":
                guard let name = it.name, !name.isEmpty else { continue }
                var (best, alts) = AssistantParser.lookup(name, data: data)
                // Se o banco não tiver nada parecido, usa a estimativa da própria IA.
                let estimate: FoodItem? = (it.kcal100 ?? 0) > 0 ? FoodItem(
                    id: "ai-" + AssistantParser.norm(name).filter { $0.isLetter || $0.isNumber },
                    name: name, category: "Estimativa IA",
                    per100: Nutrients(kcal: it.kcal100 ?? 0, protein: it.protein100 ?? 0, carbs: it.carbs100 ?? 0,
                                      fat: it.fat100 ?? 0, fiber: it.fiber100 ?? 0)) : nil
                if let b = best, let e = estimate, e.per100.kcal > 0,
                   abs(b.per100.kcal - e.per100.kcal) / e.per100.kcal > 0.6 {
                    best = e    // o banco achou algo bem diferente (ex.: cru vs. frito)
                }
                if let e = estimate { alts.insert(e, at: 0) }
                guard let food = best ?? estimate else { continue }
                var d = AssistantDraft(kind: .food, source: name, spoken: AssistantParser.singular(AssistantParser.norm(name)),
                                       food: food, alternatives: Array(alts.prefix(8)), grams: max(1, (it.grams ?? 100).rounded()))
                d.meal = meal; d.date = date
                out.append(d)
            case "water": if let v = it.value, v > 0 { out.append(AssistantDraft(kind: .water, source: "", value: v, date: date)) }
            case "weight": if let v = it.value, (25...300).contains(v) { out.append(AssistantDraft(kind: .weight, source: "", value: v, date: date)) }
            case "sleep": if let v = it.value, (1...16).contains(v) { out.append(AssistantDraft(kind: .sleep, source: "", value: v, date: date)) }
            case "mood": if let v = it.value { out.append(AssistantDraft(kind: .mood, source: "", value: min(5, max(1, v.rounded())), date: date)) }
            case "exercise":
                guard let name = it.name, let x = AssistantParser.matchExercise(name) else { continue }
                var d = AssistantDraft(kind: .exercise, source: name, spoken: AssistantParser.singular(AssistantParser.norm(name)), date: date)
                d.exerciseID = x.id; d.sets = max(1, it.sets ?? 1); d.reps = max(1, it.reps ?? 10); d.kg = it.kg ?? 0
                out.append(d)
            case "cardio":
                let n = AssistantParser.norm(it.name ?? "")
                var d = AssistantDraft(kind: .cardio, source: n, date: date)
                d.cardioKind = n.contains("bik") || n.contains("pedal") ? .bike : n.contains("camin") ? .walk : .run
                d.km = it.km ?? 0; d.minutes = it.minutes ?? 0
                if d.km > 0 || d.minutes > 0 { out.append(d) }
            case "measure":
                guard let p = it.part.flatMap(BodyPart.init(rawValue:)), let v = it.value else { continue }
                var d = AssistantDraft(kind: .measure, source: "", value: v, date: date)
                d.part = p
                out.append(d)
            default: continue
            }
        }
        return out
    }
}

extension UIImage {
    func downscaled(maxSide: CGFloat) -> UIImage {
        let s = max(size.width, size.height)
        guard s > maxSide else { return self }
        let f = maxSide / s
        let newSize = CGSize(width: size.width * f, height: size.height * f)
        return UIGraphicsImageRenderer(size: newSize).image { _ in draw(in: CGRect(origin: .zero, size: newSize)) }
    }
}

// MARK: - Groq (reserva)

/// Groq: API compatível com a da OpenAI, muito rápida e com bom limite grátis. Usada quando o Gemini falha.
enum Groq {
    static var apiKey: String? {
        get { SecureStore.get("groq.key") }
        set { SecureStore.set("groq.key", newValue?.trimmingCharacters(in: .whitespacesAndNewlines)) }
    }
    static var hasKey: Bool { !(apiKey ?? "").isEmpty }
    static let defaultModel = "llama-3.3-70b-versatile"
    static var model: String {
        get { UserDefaults.standard.string(forKey: "groq.model").flatMap { $0.isEmpty ? nil : $0 } ?? defaultModel }
        set { UserDefaults.standard.set(newValue.trimmingCharacters(in: .whitespaces), forKey: "groq.model") }
    }
    /// Modelo que lê imagens (escolhido sozinho a partir da lista da sua conta).
    static var visionModel: String? {
        get { UserDefaults.standard.string(forKey: "groq.vision") }
        set { UserDefaults.standard.set(newValue, forKey: "groq.vision") }
    }

    enum Failure: LocalizedError {
        case badKey, quota, network, noVision, invalid(String)
        var errorDescription: String? {
            switch self {
            case .badKey: "Chave do Groq inválida. Confira nos ajustes da IA."
            case .quota: "Limite grátis do Groq atingido também. Tente de novo em alguns minutos."
            case .network: "Sem conexão com a IA. As regras locais continuam funcionando."
            case .noVision: "A reserva (Groq) não tem modelo que lê fotos na sua conta. Tente a foto mais tarde."
            case .invalid(let m): "A IA respondeu algo inesperado: \(m)"
            }
        }
    }

    private static let schemaHint = """
    Responda SOMENTE com um objeto JSON neste formato (sem texto fora do JSON):
    {"reply": string, "items": [{"type": "food"|"water"|"weight"|"sleep"|"mood"|"exercise"|"cardio"|"measure",
      "name"?: string, "grams"?: number, "meal"?: \(Gemini.mealList.map { "\"\($0)\"" }.joined(separator: "|")),
      "value"?: number, "sets"?: integer, "reps"?: integer, "kg"?: number, "km"?: number, "minutes"?: number,
      "part"?: \(BodyPart.allCases.map { "\"\($0.rawValue)\"" }.joined(separator: "|")),
      "kcal100"?: number, "protein100"?: number, "carbs100"?: number, "fat100"?: number, "fiber100"?: number, "dayOffset"?: integer}]}
    """

    static func ask(_ text: String, image: UIImage?, context: String) async throws -> Gemini.Result {
        do {
            return try await send(text, image: image, context: context)
        } catch Failure.invalid(let m) where m.hasPrefix("modelo") {
            // modelo desativado: escolhe outro da lista da conta e tenta de novo
            try await refreshModels()
            return try await send(text, image: image, context: context)
        }
    }

    private static func send(_ text: String, image: UIImage?, context: String) async throws -> Gemini.Result {
        guard let key = apiKey, !key.isEmpty else { throw Failure.badKey }
        let prompt = "DADOS DO USUÁRIO:\n\(context)\n\nMENSAGEM:\n\(text.isEmpty ? "(veja a foto)" : text)"
        var useModel = model
        var userContent: Any = prompt
        if let image {
            if visionModel == nil { try? await refreshModels() }
            guard let vm = visionModel, let jpg = image.downscaled(maxSide: 1024).jpegData(compressionQuality: 0.7) else { throw Failure.noVision }
            useModel = vm
            userContent = [["type": "text", "text": prompt],
                           ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(jpg.base64EncodedString())"]]]
        }
        var body: [String: Any] = [
            "model": useModel,
            "messages": [["role": "system", "content": Gemini.system + "\n\n" + schemaHint], ["role": "user", "content": userContent]],
            "temperature": 0.2,
        ]
        if image == nil { body["response_format"] = ["type": "json_object"] }
        var req = URLRequest(url: URL(string: "https://api.groq.com/openai/v1/chat/completions")!)
        req.httpMethod = "POST"
        req.timeoutInterval = 40
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp): (Data, URLResponse)
        do { (data, resp) = try await URLSession.shared.data(for: req) } catch { throw Failure.network }
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        let obj = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        let errMsg = ((obj["error"] as? [String: Any])?["message"] as? String) ?? ""
        if code == 429 { throw Failure.quota }
        if code == 401 || code == 403 { throw Failure.badKey }
        if code == 404 || errMsg.contains("model") && (errMsg.contains("decommissioned") || errMsg.contains("not exist") || errMsg.contains("not found")) {
            throw Failure.invalid("modelo indisponível")
        }
        guard code == 200, let content = ((obj["choices"] as? [[String: Any]])?.first?["message"] as? [String: Any])?["content"] as? String else {
            throw Failure.invalid(errMsg.isEmpty ? "código \(code)" : errMsg)
        }
        // tolera respostas com ```json … ```
        var json = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if let a = json.firstIndex(of: "{"), let b = json.lastIndex(of: "}") { json = String(json[a...b]) }
        guard let d = json.data(using: .utf8), let r = try? JSONDecoder().decode(Gemini.Result.self, from: d) else {
            return Gemini.Result(reply: content, items: [])
        }
        return r
    }

    /// Lê os modelos da conta e escolhe o melhor para texto e um que leia imagens.
    @discardableResult
    static func refreshModels() async throws -> [String] {
        guard let key = apiKey, !key.isEmpty else { throw Failure.badKey }
        var req = URLRequest(url: URL(string: "https://api.groq.com/openai/v1/models")!)
        req.timeoutInterval = 20
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        let (data, resp): (Data, URLResponse)
        do { (data, resp) = try await URLSession.shared.data(for: req) } catch { throw Failure.network }
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        if code == 401 || code == 403 { throw Failure.badKey }
        guard code == 200, let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let list = obj["data"] as? [[String: Any]] else { throw Failure.invalid("lista de modelos, código \(code)") }
        let ids = list.filter { ($0["active"] as? Bool) ?? true }.compactMap { $0["id"] as? String }
        let bad = ["whisper", "guard", "tts", "playai", "distil", "embed", "compound", "saba"]
        let chat = ids.filter { id in !bad.contains(where: id.lowercased().contains) }
        let prefer = ["llama-3.3-70b-versatile", "openai/gpt-oss-120b", "llama-4-maverick", "kimi-k2", "qwen3-32b", "llama-4-scout", "gpt-oss-20b", "llama-3.1-8b-instant"]
        func rank(_ id: String) -> Int { prefer.firstIndex { id.contains($0) } ?? prefer.count }
        let sorted = chat.sorted { rank($0) < rank($1) }
        if !sorted.contains(model), let first = sorted.first { model = first }
        visionModel = ids.first { $0.contains("llama-4-scout") } ?? ids.first { $0.contains("llama-4-maverick") } ?? ids.first { $0.contains("vision") }
        return sorted
    }
}

// MARK: - Ajustes da IA

struct GeminiSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var key = Gemini.apiKey ?? ""
    @State private var model = Gemini.model
    @State private var testing = false
    @State private var status: String?
    @State private var ok = false
    @State private var models: [String] = []
    @State private var loadingModels = false
    @State private var groqKey = Groq.apiKey ?? ""
    @State private var groqStatus: String?
    @State private var groqOK = false
    @State private var groqTesting = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("Cole aqui a chave", text: $key)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    Button {
                        if let s = UIPasteboard.general.string { key = s.trimmingCharacters(in: .whitespacesAndNewlines) }
                    } label: { Label("Colar da área de transferência", systemImage: "doc.on.clipboard") }
                    if !key.isEmpty {
                        Button(role: .destructive) { key = ""; Gemini.apiKey = nil; status = "Chave removida." } label: {
                            Label("Remover chave", systemImage: "trash")
                        }
                    }
                } header: {
                    Text("Principal: Gemini (Flash-Lite)")
                } footer: {
                    Text("A chave fica só neste iPhone, guardada no Keychain (o cofre de senhas do aparelho). Ela não vai para o código nem para o GitHub.")
                }
                Section {
                    Button {
                        Task { await test() }
                    } label: {
                        HStack {
                            Label("Salvar e testar", systemImage: "checkmark.seal")
                            Spacer()
                            if testing { ProgressView() }
                        }
                    }
                    .disabled(key.isEmpty || testing)
                    if let status {
                        Label(status, systemImage: ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(ok ? .green : .orange).font(.subheadline)
                    }
                }
                Section {
                    TextField("Modelo", text: $model).textInputAutocapitalization(.never).autocorrectionDisabled()
                    Button {
                        Task { await loadModels() }
                    } label: {
                        HStack {
                            Label("Buscar modelos disponíveis", systemImage: "arrow.clockwise")
                            Spacer()
                            if loadingModels { ProgressView() }
                        }
                    }
                    .disabled(key.isEmpty || loadingModels)
                    ForEach(models.prefix(8), id: \.self) { m in
                        Button { model = m } label: {
                            HStack {
                                Text(m).foregroundStyle(.primary)
                                Spacer()
                                if m == model { Image(systemName: "checkmark").foregroundStyle(Theme.accent) }
                            }
                        }
                    }
                } header: { Text("Modelo") } footer: {
                    Text("O app escolhe sozinho um modelo disponível se o salvo sair do ar. Prefira os \"flash\": rápidos e com limite gratuito maior.")
                }
                Section {
                    SecureField("Cole aqui a chave do Groq (gsk_…)", text: $groqKey)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    Button {
                        if let s = UIPasteboard.general.string { groqKey = s.trimmingCharacters(in: .whitespacesAndNewlines) }
                    } label: { Label("Colar da área de transferência", systemImage: "doc.on.clipboard") }
                    Button {
                        Task { await testGroq() }
                    } label: {
                        HStack {
                            Label("Salvar e testar a reserva", systemImage: "checkmark.seal")
                            Spacer()
                            if groqTesting { ProgressView() }
                        }
                    }
                    .disabled(groqKey.isEmpty || groqTesting)
                    if let groqStatus {
                        Label(groqStatus, systemImage: groqOK ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(groqOK ? .green : .orange).font(.subheadline)
                    }
                    if !groqKey.isEmpty {
                        Button(role: .destructive) { groqKey = ""; Groq.apiKey = nil; groqStatus = "Chave do Groq removida." } label: {
                            Label("Remover chave do Groq", systemImage: "trash")
                        }
                    }
                    Link(destination: URL(string: "https://console.groq.com/keys")!) {
                        Label("Criar chave grátis no Groq", systemImage: "arrow.up.right.square")
                    }
                } header: {
                    Text("Reserva: Groq")
                } footer: {
                    Text("Se o Gemini bater o limite ou falhar, o app usa o Groq na hora, sem você precisar fazer nada. Modelo atual: \(Groq.model).")
                }
                Section {
                    Link(destination: URL(string: "https://aistudio.google.com/apikey")!) {
                        Label("Criar chave no Google AI Studio", systemImage: "arrow.up.right.square")
                    }
                    Text("Nos planos gratuitos, o Google e o Groq podem usar o que você envia (frases e fotos) para melhorar os modelos. Evite mandar dados sensíveis.")
                        .font(.caption).foregroundStyle(.secondary)
                } header: { Text("Ajuda") }
            }
            .navigationTitle("IA do Assistente")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("OK") { save(); dismiss() } } }
        }
    }

    private func save() {
        Gemini.apiKey = key.isEmpty ? nil : key
        Gemini.model = model
        Groq.apiKey = groqKey.isEmpty ? nil : groqKey
    }

    private func testGroq() async {
        save()
        groqTesting = true
        defer { groqTesting = false }
        do {
            try await Groq.refreshModels()
            let r = try await Groq.ask("Responda apenas: ok", image: nil, context: "teste de conexão")
            groqOK = true
            groqStatus = "Reserva funcionando! (\(Groq.model)\(r.reply.map { ": \($0.prefix(30))" } ?? ""))"
        } catch {
            groqOK = false
            groqStatus = error.localizedDescription
        }
    }

    private func loadModels() async {
        save()
        loadingModels = true
        defer { loadingModels = false }
        do {
            models = try await Gemini.availableModels()
            if !models.contains(model), let first = models.first { model = first; Gemini.model = first }
            ok = !models.isEmpty
            status = models.isEmpty ? "Nenhum modelo disponível para esta chave." : "\(models.count) modelos encontrados."
        } catch {
            ok = false
            status = error.localizedDescription
        }
    }

    private func test() async {
        save()
        testing = true
        defer { testing = false }
        do {
            let r = try await Gemini.askGemini("Responda apenas: ok", image: nil, context: "teste de conexão")
            ok = true
            model = Gemini.model
            status = "Funcionando! (\(Gemini.model)\(r.reply.map { ": \($0.prefix(40))" } ?? ""))"
        } catch {
            ok = false
            status = error.localizedDescription
        }
    }
}
