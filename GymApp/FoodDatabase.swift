import Foundation

/// Banco de alimentos embutido (valores por 100 g):
/// TACO/UNICAMP (598), IBGE/POF 2008–09 (1.970) e alguns itens complementares estimados.
final class FoodDatabase {
    static let shared = FoodDatabase()
    let foods: [FoodItem]
    private let index: [(key: String, food: FoodItem)]

    private struct Raw: Decodable {
        let i: String, n: String, c: String, s: String
        let v: [Double]   // ordem: ver build_foods.py
    }

    private init() {
        guard let url = Bundle.main.url(forResource: "foods", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let raw = try? JSONDecoder().decode([Raw].self, from: data) else {
            foods = []; index = []; return
        }
        foods = raw.compactMap { r in
            guard r.v.count >= 34 else { return nil }
            let v = r.v
            let n = Nutrients(kcal: v[0], protein: v[1], carbs: v[2], fat: v[3], fiber: v[4], sugar: v[5],
                              saturated: v[6], sodium: v[7], calcium: v[8], iron: v[9], potassium: v[10],
                              magnesium: v[11], vitaminC: v[12], cholesterol: v[13], zinc: v[14])
            let m = Micros(mono: v[15], poly: v[16], trans: v[17], omega3: v[18], omega6: v[19], addedSugar: v[20],
                           phosphorus: v[21], manganese: v[22], copper: v[23], selenium: v[24], vitaminA: v[25],
                           b1: v[26], b2: v[27], b3: v[28], b6: v[29], b12: v[30], folate: v[31],
                           vitaminD: v[32], vitaminE: v[33])
            return FoodItem(id: r.i, name: r.n, category: r.c, per100: n, micros: m)
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
        let micros = Micros(mono: v("monounsaturated-fat_100g"), poly: v("polyunsaturated-fat_100g"),
                            trans: v("trans-fat_100g"), omega3: v("omega-3-fat_100g"), omega6: v("omega-6-fat_100g"),
                            addedSugar: v("added-sugars_100g"), phosphorus: v("phosphorus_100g") * 1000,
                            manganese: v("manganese_100g") * 1000, copper: v("copper_100g") * 1000,
                            selenium: v("selenium_100g") * 1_000_000, vitaminA: v("vitamin-a_100g") * 1_000_000,
                            b1: v("vitamin-b1_100g") * 1000, b2: v("vitamin-b2_100g") * 1000,
                            b3: v("vitamin-pp_100g") * 1000, b6: v("vitamin-b6_100g") * 1000,
                            b12: v("vitamin-b12_100g") * 1_000_000, folate: v("vitamin-b9_100g") * 1_000_000,
                            vitaminD: v("vitamin-d_100g") * 1_000_000, vitaminE: v("vitamin-e_100g") * 1000)
        return FoodItem(id: "off-\(code)", name: name, category: "Produto industrializado",
                        brand: p.brands?.split(separator: ",").first.map { String($0).trimmingCharacters(in: .whitespaces) },
                        per100: per100, servingGrams: p.serving_quantity?.value, servingName: p.serving_size,
                        micros: micros)
    }
}
