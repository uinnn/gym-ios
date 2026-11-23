import SwiftUI
import SwiftData
import PhotosUI
import Vision

// MARK: - Receitas

struct RecipeItem: Codable, Hashable, Identifiable {
    var id = UUID()
    var food: FoodItem
    var grams: Double
}

@Model
final class Recipe {
    var uid: String = UUID().uuidString
    var name: String = ""
    var servings: Int = 1
    var data: Data = Data()
    var created: Date = Date.now

    init(name: String) { self.name = name }

    var items: [RecipeItem] {
        get { (try? JSONDecoder().decode([RecipeItem].self, from: data)) ?? [] }
        set { data = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    static func totals(_ items: [RecipeItem]) -> (nutrients: Nutrients, grams: Double) {
        (items.map { $0.food.per100.scaled($0.grams / 100) }.total, items.map(\.grams).reduce(0, +))
    }

    /// Vira um alimento normal (por 100 g, porção = 1 porção da receita) para usar no diário.
    var asFood: FoodItem {
        let t = Self.totals(items)
        let factor = t.grams > 0 ? 100 / t.grams : 0
        return FoodItem(id: "recipe-\(uid)", name: name, category: "Receitas", brand: nil,
                        per100: t.nutrients.scaled(factor), servingGrams: t.grams / Double(max(servings, 1)),
                        servingName: "porção")
    }
}

struct RecipesView: View {
    var onPick: (FoodItem) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \Recipe.created, order: .reverse) private var recipes: [Recipe]
    @State private var editing: Recipe?

    var body: some View {
        NavigationStack {
            List {
                if recipes.isEmpty {
                    ContentUnavailableView("Nenhuma receita", systemImage: "book.closed",
                                           description: Text("Monte um prato com vários ingredientes (ex.: strogonoff, vitamina, marmita) e registre tudo de uma vez."))
                }
                ForEach(recipes) { r in
                    let f = r.asFood
                    let serving = f.per100.scaled((f.servingGrams ?? 100) / 100)
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(r.name).font(.headline)
                            Text("\(r.items.count) ingredientes · \(r.servings) porç\(r.servings == 1 ? "ão" : "ões") · \(Int(serving.kcal)) kcal/porção")
                                .font(.caption).foregroundStyle(.secondary)
                            Text("P \(Int(serving.protein)) g · C \(Int(serving.carbs)) g · G \(Int(serving.fat)) g")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Registrar") { onPick(f); dismiss() }.buttonStyle(.borderedProminent).tint(Theme.accent).font(.caption.bold())
                    }
                    .contentShape(Rectangle())
                    .swipeActions(edge: .leading) { Button("Editar") { editing = r }.tint(Theme.info) }
                }
                .onDelete { idx in idx.forEach { context.delete(recipes[$0]) } }
            }
            .navigationTitle("Receitas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Fechar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button { let r = Recipe(name: ""); context.insert(r); editing = r } label: { Image(systemName: "plus") }
                }
            }
            .sheet(item: $editing, onDismiss: cleanup) { RecipeEditor(recipe: $0) }
        }
    }

    /// Remove receitas criadas e abandonadas vazias.
    private func cleanup() {
        for r in recipes where r.items.isEmpty && r.name.trimmingCharacters(in: .whitespaces).isEmpty { context.delete(r) }
    }
}

struct RecipeEditor: View {
    @Bindable var recipe: Recipe
    @Environment(\.dismiss) private var dismiss
    @State private var items: [RecipeItem] = []
    @State private var query = ""

    var body: some View {
        let t = Recipe.totals(items)
        let per = t.nutrients.scaled(1 / Double(max(recipe.servings, 1)))
        let results = query.count >= 2 ? FoodDatabase.shared.search(query, limit: 15) : []
        NavigationStack {
            Form {
                Section {
                    TextField("Nome da receita", text: $recipe.name)
                    Stepper("Rende \(recipe.servings) porç\(recipe.servings == 1 ? "ão" : "ões")", value: $recipe.servings, in: 1...50)
                }
                Section("Por porção") {
                    HStack {
                        stat("\(Int(per.kcal))", "kcal"); stat("\(Int(per.protein)) g", "proteína")
                        stat("\(Int(per.carbs)) g", "carbo"); stat("\(Int(per.fat)) g", "gordura")
                    }
                    Text("Receita inteira: \(Int(t.grams)) g · \(Int(t.nutrients.kcal)) kcal").font(.caption).foregroundStyle(.secondary)
                }
                Section("Ingredientes") {
                    ForEach($items) { $it in
                        HStack {
                            Text(it.food.name).lineLimit(2)
                            Spacer()
                            TextField("g", value: $it.grams, format: .number).keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing).frame(width: 60)
                            Text("g").foregroundStyle(.secondary)
                        }
                    }
                    .onDelete { items.remove(atOffsets: $0) }
                    TextField("Buscar ingrediente…", text: $query).autocorrectionDisabled()
                    ForEach(results) { f in
                        Button {
                            items.append(RecipeItem(food: f, grams: f.servingGrams ?? 100))
                            query = ""
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill").foregroundStyle(Theme.accent)
                                Text(f.name).foregroundStyle(.primary).lineLimit(2)
                                Spacer()
                                Text("\(Int(f.per100.kcal)) kcal/100g").font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Receita")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { items = recipe.items }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") {
                        recipe.items = items
                        if recipe.name.trimmingCharacters(in: .whitespaces).isEmpty { recipe.name = "Minha receita" }
                        dismiss()
                    }
                    .bold().disabled(items.isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
            }
        }
    }

    private func stat(_ v: String, _ l: String) -> some View {
        VStack(spacing: 1) { Text(v).font(.subheadline.bold()); Text(l).font(.caption2).foregroundStyle(.secondary) }.frame(maxWidth: .infinity)
    }
}

// MARK: - Lista de compras

struct ShoppingListView: View {
    let targets: NutritionTargets
    let seed: Int
    @Environment(\.dismiss) private var dismiss
    @State private var days = 7
    @AppStorage("shopping.checked") private var checkedRaw = ""

    struct Line: Identifiable { let id: String; let name: String; let category: String; let grams: Double }

    /// Junta os cardápios de N dias (cada dia com uma variação diferente) e soma por alimento.
    private var lines: [Line] {
        var byID: [String: (FoodItem, Double)] = [:]
        for d in 0..<days {
            for m in MealPlanner(targets: targets, seed: seed + d, swaps: [:]).plan() {
                for i in m.items { byID[i.food.id, default: (i.food, 0)].1 += i.grams }
            }
        }
        return byID.values.map { Line(id: $0.0.id, name: $0.0.name, category: $0.0.category, grams: $0.1) }
            .sorted { ($0.category, $0.name) < ($1.category, $1.name) }
    }

    private var checked: Set<String> { Set(checkedRaw.split(separator: "|").map(String.init)) }

    var body: some View {
        let list = lines
        let groups = Dictionary(grouping: list, by: \.category).sorted { $0.key < $1.key }
        NavigationStack {
            List {
                Section {
                    Picker("Para", selection: $days) {
                        Text("3 dias").tag(3); Text("1 semana").tag(7); Text("2 semanas").tag(14)
                    }
                    .pickerStyle(.segmented)
                } footer: { Text("Quantidades somadas dos cardápios gerados, já com peso cozido convertido para compra quando possível. Ajuste ao seu gosto.") }
                ForEach(groups, id: \.key) { cat, items in
                    Section(cat) {
                        ForEach(items) { l in
                            let on = checked.contains(l.id)
                            Button { toggle(l.id) } label: {
                                HStack {
                                    Image(systemName: on ? "checkmark.circle.fill" : "circle").foregroundStyle(on ? Theme.good : .secondary)
                                    Text(l.name).strikethrough(on).foregroundStyle(on ? .secondary : .primary)
                                    Spacer()
                                    Text(Self.amount(l.grams, name: l.name)).font(.callout.monospacedDigit()).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Lista de compras")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("OK") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    ShareLink(item: text(list)) { Image(systemName: "square.and.arrow.up") }
                }
                ToolbarItem(placement: .bottomBar) { Button("Desmarcar tudo") { checkedRaw = "" } }
            }
        }
    }

    private func toggle(_ id: String) {
        var c = checked
        if c.contains(id) { c.remove(id) } else { c.insert(id) }
        checkedRaw = c.joined(separator: "|")
    }

    /// Alimentos cozidos viram peso cru aproximado (arroz/feijão/macarrão rendem ~2,5×; carnes perdem ~25%).
    static func amount(_ g: Double, name: String) -> String {
        let n = name.lowercased()
        var raw = g
        if n.contains("cozid") && (n.contains("arroz") || n.contains("feij") || n.contains("macarr") || n.contains("lentilha")) { raw = g / 2.5 }
        else if n.contains("grelhad") || n.contains("assad") { raw = g / 0.75 }
        let rounded = (raw / 50).rounded(.up) * 50
        return rounded >= 1000 ? "\((rounded / 1000).fmt(1)) kg" : "\(Int(rounded)) g"
    }

    private func text(_ list: [Line]) -> String {
        "🛒 Lista de compras (\(days) dias)\n" + list.map { "• \($0.name) — \(Self.amount($0.grams, name: $0.name))" }.joined(separator: "\n")
    }
}

// MARK: - Foto do prato

/// Reconhece o prato com o classificador de imagens do próprio iPhone (Vision, sem internet)
/// e sugere alimentos da tabela.
struct FoodPhotoView: View {
    var onPick: (FoodItem) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var item: PhotosPickerItem?
    @State private var image: UIImage?
    @State private var showCamera = false
    @State private var guesses: [(label: String, confidence: Float, foods: [FoodItem])] = []
    @State private var working = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if let image {
                        Image(uiImage: image).resizable().scaledToFill().frame(height: 220).clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 14)).listRowInsets(EdgeInsets())
                    }
                    HStack {
                        Button { showCamera = true } label: { Label("Câmera", systemImage: "camera.fill").frame(maxWidth: .infinity) }
                            .buttonStyle(.borderedProminent).tint(Theme.accent)
                        PhotosPicker(selection: $item, matching: .images) {
                            Label("Galeria", systemImage: "photo").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                    .listRowBackground(Color.clear)
                } footer: {
                    Text("O reconhecimento roda no próprio iPhone. Ele identifica o tipo de comida; confira o alimento e ajuste a porção antes de salvar.")
                }
                if working { Section { ProgressView("Analisando…").frame(maxWidth: .infinity) } }
                if !working, image != nil, guesses.isEmpty {
                    Section { Text("Não reconheci comida nesta foto. Tente mais perto e com boa luz, ou busque pelo nome.").foregroundStyle(.secondary) }
                }
                ForEach(guesses, id: \.label) { g in
                    Section("\(g.label.capitalized) · \(Int(g.confidence * 100))%") {
                        ForEach(g.foods) { f in
                            Button { onPick(f); dismiss() } label: {
                                HStack {
                                    Text(f.name).foregroundStyle(.primary)
                                    Spacer()
                                    Text("\(Int(f.per100.kcal)) kcal/100g").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Foto do prato")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Fechar") { dismiss() } }
            .onChange(of: item) { _, it in
                Task {
                    if let data = try? await it?.loadTransferable(type: Data.self), let img = UIImage(data: data) { analyze(img) }
                }
            }
            .fullScreenCover(isPresented: $showCamera) { CameraPicker { analyze($0) }.ignoresSafeArea() }
        }
    }

    private func analyze(_ img: UIImage) {
        image = img
        working = true
        guesses = []
        Task.detached(priority: .userInitiated) {
            let result = FoodPhotoClassifier.classify(img)
            await MainActor.run { guesses = result; working = false }
        }
    }
}

enum FoodPhotoClassifier {
    /// Rótulos do classificador da Apple (inglês) → termos de busca na tabela.
    static let map: [String: String] = [
        "pizza": "pizza", "hamburger": "hamburguer", "sandwich": "sanduiche", "hotdog": "cachorro-quente",
        "salad": "alface", "rice": "arroz cozido", "pasta": "macarrao cozido", "spaghetti": "macarrao cozido",
        "noodle": "macarrao", "bread": "pao", "toast": "pao torrado", "egg": "ovo", "fried_egg": "ovo frito",
        "omelet": "omelete", "steak": "carne bovina grelhado", "meat": "carne bovina", "beef": "carne bovina",
        "chicken": "frango", "fried_chicken": "frango frito", "fish": "peixe", "sushi": "sushi", "salmon": "salmao",
        "shrimp": "camarao", "beans": "feijao cozido", "soup": "sopa", "french_fries": "batata frita",
        "potato": "batata cozida", "sweet_potato": "batata doce", "corn": "milho", "cake": "bolo",
        "cookie": "biscoito", "chocolate": "chocolate", "ice_cream": "sorvete", "donut": "rosquinha",
        "pancake": "panqueca", "waffle": "waffle", "cheese": "queijo", "yogurt": "iogurte", "milk": "leite",
        "coffee": "cafe", "juice": "suco", "banana": "banana", "apple": "maca", "orange": "laranja",
        "strawberry": "morango", "grape": "uva", "watermelon": "melancia", "pineapple": "abacaxi", "mango": "manga",
        "papaya": "mamao", "avocado": "abacate", "lemon": "limao", "tomato": "tomate", "carrot": "cenoura",
        "broccoli": "brocolis", "lettuce": "alface", "cucumber": "pepino", "onion": "cebola", "mushroom": "cogumelo",
        "taco": "taco", "burrito": "burrito", "pie": "torta", "sausage": "linguica", "bacon": "bacon",
        "nut": "castanha", "peanut": "amendoim", "granola": "granola", "oatmeal": "aveia", "cereal": "cereal",
        "acai": "acai", "tapioca": "tapioca", "pork": "porco", "lasagna": "lasanha", "popcorn": "pipoca",
    ]

    static func classify(_ image: UIImage) -> [(label: String, confidence: Float, foods: [FoodItem])] {
        guard let cg = image.cgImage else { return [] }
        let req = VNClassifyImageRequest()
        let handler = VNImageRequestHandler(cgImage: cg, orientation: .init(image.imageOrientation))
        try? handler.perform([req])
        let obs = (req.results ?? []).filter { $0.confidence > 0.05 }.prefix(60)
        var out: [(String, Float, [FoodItem])] = []
        var seen = Set<String>()
        for o in obs {
            let key = o.identifier.lowercased()
            guard let term = map[key] ?? map.first(where: { key.contains($0.key) })?.value, !seen.contains(term) else { continue }
            seen.insert(term)
            let foods = FoodDatabase.shared.search(term, limit: 5)
            if !foods.isEmpty { out.append((key.replacingOccurrences(of: "_", with: " "), o.confidence, foods)) }
            if out.count >= 4 { break }
        }
        return out
    }
}

extension CGImagePropertyOrientation {
    init(_ o: UIImage.Orientation) {
        switch o {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}

/// Câmera simples (UIImagePickerController).
struct CameraPicker: UIViewControllerRepresentable {
    var onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let p = UIImagePickerController()
        p.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        p.delegate = context.coordinator
        return p
    }
    func updateUIViewController(_ vc: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ p: CameraPicker) { parent = p }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let img = info[.originalImage] as? UIImage { parent.onImage(img) }
            parent.dismiss()
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.dismiss() }
    }
}
