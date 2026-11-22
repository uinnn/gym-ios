import Foundation

/// Tabela TACO (UNICAMP) embutida no app: 597 alimentos brasileiros, valores por 100 g.
final class FoodDatabase {
    static let shared = FoodDatabase()
    let foods: [FoodItem]
    private let index: [(key: String, food: FoodItem)]

    private struct Raw: Decodable {
        let id: Int, n: String, cat: String
        let kcal, p, c, f, fib, na, ca, fe, k, mg, vc, chol, sat, zn: Double
    }

    private init() {
        guard let url = Bundle.main.url(forResource: "taco", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let raw = try? JSONDecoder().decode([Raw].self, from: data) else {
            foods = []; index = []; return
        }
        foods = raw.map {
            FoodItem(id: "taco-\($0.id)", name: $0.n, category: $0.cat,
                     per100: Nutrients(kcal: $0.kcal, protein: $0.p, carbs: $0.c, fat: $0.f, fiber: $0.fib,
                                       sugar: 0, saturated: $0.sat, sodium: $0.na, calcium: $0.ca, iron: $0.fe,
                                       potassium: $0.k, magnesium: $0.mg, vitaminC: $0.vc,
                                       cholesterol: $0.chol, zinc: $0.zn))
        }
        index = foods.map { (Self.normalize($0.name), $0) }
    }

    static func normalize(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "pt_BR"))
            .replacingOccurrences(of: ",", with: " ")
    }

    /// Busca por palavras (todas precisam aparecer), priorizando quem começa com a primeira.
    func search(_ query: String, limit: Int = 60) -> [FoodItem] {
        let words = Self.normalize(query).split(separator: " ").map(String.init).filter { !$0.isEmpty }
        guard !words.isEmpty else { return [] }
        let hits = index.filter { item in words.allSatisfy { item.key.contains($0) } }
        return hits.sorted { a, b in
            let ap = a.key.hasPrefix(words[0]), bp = b.key.hasPrefix(words[0])
            if ap != bp { return ap }
            return a.key.count < b.key.count
        }
        .prefix(limit).map(\.food)
    }

    func food(id: String) -> FoodItem? { foods.first { $0.id == id } }

    var categories: [String] { Array(Set(foods.map(\.category))).sorted() }
}

/// Cliente do Open Food Facts (base aberta de produtos industrializados).
enum OpenFoodFacts {
    private static let fields = "code,product_name,product_name_pt,brands,nutriments,serving_quantity,serving_size"

    private struct ProductResponse: Decodable { let status: Int?; let product: Product? }
    private struct SearchResponse: Decodable { let products: [Product]? }

    struct Product: Decodable {
        let code: String?
        let product_name: String?
        let product_name_pt: String?
        let brands: String?
        let nutriments: [String: FlexibleDouble]?
        let serving_quantity: FlexibleDouble?
        let serving_size: String?
    }

    /// Aceita número ou texto numérico no JSON.
    struct FlexibleDouble: Decodable {
        let value: Double?
        init(from decoder: Decoder) throws {
            let c = try decoder.singleValueContainer()
            if let d = try? c.decode(Double.self) { value = d }
            else if let s = try? c.decode(String.self) { value = Double(s.replacingOccurrences(of: ",", with: ".")) }
            else { value = nil }
        }
    }

    private static func request(_ url: URL) -> URLRequest {
        var r = URLRequest(url: url, timeoutInterval: 15)
        r.setValue("GymApp/0.1 (iOS)", forHTTPHeaderField: "User-Agent")
        return r
    }

    static func product(barcode: String) async throws -> FoodItem? {
        let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(barcode).json?fields=\(fields)")!
        let (data, _) = try await URLSession.shared.data(for: request(url))
        let r = try JSONDecoder().decode(ProductResponse.self, from: data)
        guard r.status == 1, let p = r.product else { return nil }
        return convert(p, fallbackCode: barcode)
    }

    static func search(_ query: String) async throws -> [FoodItem] {
        var c = URLComponents(string: "https://br.openfoodfacts.org/cgi/search.pl")!
        c.queryItems = [
            .init(name: "search_terms", value: query), .init(name: "search_simple", value: "1"),
            .init(name: "action", value: "process"), .init(name: "json", value: "1"),
            .init(name: "page_size", value: "30"), .init(name: "fields", value: fields),
        ]
        let (data, _) = try await URLSession.shared.data(for: request(c.url!))
        let r = try JSONDecoder().decode(SearchResponse.self, from: data)
        return (r.products ?? []).compactMap { convert($0, fallbackCode: nil) }
    }

    private static func convert(_ p: Product, fallbackCode: String?) -> FoodItem? {
        let name = (p.product_name_pt?.isEmpty == false ? p.product_name_pt : p.product_name) ?? ""
        guard !name.isEmpty, let n = p.nutriments else { return nil }
        func v(_ k: String) -> Double { n[k]?.value ?? 0 }
        var kcal = v("energy-kcal_100g")
        if kcal == 0 { kcal = v("energy_100g") / 4.184 }
        guard kcal > 0 || v("proteins_100g") > 0 else { return nil }
        let per100 = Nutrients(kcal: kcal, protein: v("proteins_100g"), carbs: v("carbohydrates_100g"),
                               fat: v("fat_100g"), fiber: v("fiber_100g"), sugar: v("sugars_100g"),
                               saturated: v("saturated-fat_100g"), sodium: v("sodium_100g") * 1000,
                               calcium: v("calcium_100g") * 1000, iron: v("iron_100g") * 1000,
                               potassium: v("potassium_100g") * 1000, magnesium: v("magnesium_100g") * 1000,
                               vitaminC: v("vitamin-c_100g") * 1000, cholesterol: v("cholesterol_100g") * 1000,
                               zinc: v("zinc_100g") * 1000)
        let code = p.code ?? fallbackCode ?? UUID().uuidString
        return FoodItem(id: "off-\(code)", name: name, category: "Produto industrializado",
                        brand: p.brands?.split(separator: ",").first.map { String($0).trimmingCharacters(in: .whitespaces) },
                        per100: per100, servingGrams: p.serving_quantity?.value, servingName: p.serving_size)
    }
}
