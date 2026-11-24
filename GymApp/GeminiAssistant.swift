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
    static var model: String {
        get { UserDefaults.standard.string(forKey: "gemini.model").flatMap { $0.isEmpty ? nil : $0 } ?? "gemini-2.5-flash" }
        set { UserDefaults.standard.set(newValue.trimmingCharacters(in: .whitespaces), forKey: "gemini.model") }
    }
    static var isConfigured: Bool { !(apiKey ?? "").isEmpty }

    enum Failure: LocalizedError {
        case noKey, badKey, quota, network, invalid(String)
        var errorDescription: String? {
            switch self {
            case .noKey: "Configure sua chave do Gemini primeiro."
            case .badKey: "Chave do Gemini inválida ou sem permissão. Confira em Ajustes do Assistente."
            case .quota: "Limite gratuito do Gemini atingido. Espere um pouco (o limite renova por minuto e por dia)."
            case .network: "Sem conexão com o Gemini. As regras locais continuam funcionando."
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

    private static let mealList = Meal.allCases.map(\.rawValue)

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

    private static let system = """
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

    static func ask(_ text: String, image: UIImage?, context: String) async throws -> Result {
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
        let model = model.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "gemini-2.5-flash"
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

// MARK: - Ajustes da IA

struct GeminiSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var key = Gemini.apiKey ?? ""
    @State private var model = Gemini.model
    @State private var testing = false
    @State private var status: String?
    @State private var ok = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("Cole aqui a chave (começa com AIza…)", text: $key)
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
                    Text("Chave do Gemini")
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
                    Button("Usar o padrão (gemini-2.5-flash)") { model = "gemini-2.5-flash" }
                } header: { Text("Modelo") } footer: {
                    Text("Se o Google lançar um modelo novo ou desativar este, troque o nome aqui (veja a lista em ai.google.dev).")
                }
                Section {
                    Link(destination: URL(string: "https://aistudio.google.com/apikey")!) {
                        Label("Criar chave no Google AI Studio", systemImage: "arrow.up.right.square")
                    }
                    Text("No plano gratuito, o Google pode usar o que você envia (frases e fotos) para melhorar os modelos. Evite mandar dados sensíveis.")
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
    }

    private func test() async {
        save()
        testing = true
        defer { testing = false }
        do {
            let r = try await Gemini.ask("Responda apenas: ok", image: nil, context: "teste de conexão")
            ok = true
            status = "Funcionando! (\(Gemini.model)\(r.reply.map { ": \($0.prefix(40))" } ?? ""))"
        } catch {
            ok = false
            status = error.localizedDescription
        }
    }
}
