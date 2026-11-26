import SwiftUI
import SwiftData
import VisionKit

enum FoodSource: String, CaseIterable, Identifiable {
    case recent = "Recentes", favorites = "Favoritos", taco = "Base", online = "Online", mine = "Meus"
    var id: String { rawValue }
}

struct FoodSearchView: View {
    let meal: Meal
    let day: Date
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \SavedFood.lastUsed, order: .reverse) private var saved: [SavedFood]
    @State private var query = ""
    @State private var source: FoodSource = .recent
    @State private var online: [FoodItem] = []
    @State private var loading = false
    @State private var error: String?
    @State private var picked: FoodItem?
    @State private var showScanner = false
    @State private var showCustom = false
    @State private var showPhoto = false
    @State private var showRecipes = false
    @State private var pending: FoodItem?
    @State private var editFood: FoodItem?
    @Environment(\.modelContext) private var context

    /// Abre a porção depois que a folha anterior terminou de fechar.
    private func takePending() { if let p = pending { pending = nil; picked = p } }
    @State private var category: String?

    private var results: [FoodItem] {
        let q = query.trimmingCharacters(in: .whitespaces)
        switch source {
        case .recent:
            let list = saved.compactMap(\.food)
            return q.isEmpty ? list : list.filter { FoodDatabase.normalize($0.name).contains(FoodDatabase.normalize(q)) }
        case .favorites:
            return saved.filter(\.favorite).compactMap(\.food)
        case .mine:
            return saved.filter(\.isCustom).compactMap(\.food)
        case .taco:
            if q.isEmpty {
                let all = FoodDatabase.shared.foods
                return category.map { c in all.filter { $0.category == c } } ?? Array(all.prefix(80))
            }
            return FoodDatabase.shared.search(q)
        case .online:
            return online
        }
    }

    var body: some View {
        let results = self.results          // calculado uma vez por atualização
        let savedByID = Dictionary(saved.map { ($0.foodID, $0) }, uniquingKeysWith: { a, _ in a })
        NavigationStack {
            List {
                Section {
                    Picker("Fonte", selection: $source.animation(.spring)) {
                        ForEach(FoodSource.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
                if source == .recent && query.isEmpty {
                    MealCombosSection(meal: meal, day: day) { dismiss() }
                }
                if source == .taco && query.isEmpty {
                    Section {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(FoodDatabase.shared.categories, id: \.self) { c in
                                    Button(c) { withAnimation { category = category == c ? nil : c } }
                                        .font(.caption.bold())
                                        .buttonStyle(.bordered)
                                        .tint(category == c ? Theme.accent : .secondary)
                                }
                            }
                        }
                    }
                    .listRowBackground(Color.clear)
                }
                if source == .online {
                    if loading { HStack { Spacer(); ProgressView(); Spacer() } }
                    if let error { Text(error).foregroundStyle(.secondary).font(.caption) }
                    if online.isEmpty && !loading {
                        Text("Digite o nome de um produto e toque em Buscar no teclado, ou use o leitor de código de barras.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                if results.isEmpty && source != .online {
                    ContentUnavailableView(emptyText, systemImage: "fork.knife")
                }
                ForEach(results) { food in
                    let sf = savedByID[food.id]
                    Button { picked = food } label: { FoodRow(food: food, saved: sf) }
                        .buttonStyle(.tap)
                        .swipeActions(edge: .leading) {
                            Button { toggleFavorite(food, sf) } label: {
                                Label(sf?.favorite == true ? "Desfavoritar" : "Favoritar", systemImage: sf?.favorite == true ? "star.slash" : "star.fill")
                            }.tint(.yellow)
                        }
                        .swipeActions(edge: .trailing) {
                            if let sf, source == .recent || sf.isCustom {
                                Button(role: .destructive) { withAnimation { context.deleteUndoable(sf, "Alimento removido") } } label: {
                                    Label(sf.isCustom ? "Apagar" : "Tirar dos recentes", systemImage: "trash")
                                }
                            }
                            Button { editFood = food } label: { Label("Editar", systemImage: "pencil") }.tint(Theme.accent)
                        }
                        .contextMenu {
                            Button("Adicionar", systemImage: "plus") { picked = food }
                            Button("Editar tudo", systemImage: "pencil") { editFood = food }
                            Button("Duplicar e editar", systemImage: "plus.square.on.square") {
                                var c = food; c.id = "copy-\(UUID().uuidString)"; c.name += " (cópia)"; editFood = c
                            }
                            Button(sf?.favorite == true ? "Remover dos favoritos" : "Favoritar",
                                   systemImage: sf?.favorite == true ? "star.slash" : "star") { toggleFavorite(food, sf) }
                            if let sf, sf.isCustom {
                                Button("Apagar alimento", systemImage: "trash", role: .destructive) { withAnimation { context.deleteUndoable(sf, "Alimento removido") } }
                            }
                        }
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Buscar alimento")
            .onSubmit(of: .search) { if source == .online || source == .recent { source = .online; searchOnline() } }
            .onChange(of: query) { _, q in
                if source == .recent && !q.isEmpty && results.isEmpty { source = .taco }
            }
            .navigationTitle(meal.label)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Fechar") { dismiss() } }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { showRecipes = true } label: { Image(systemName: "book.closed") }
                    Button { showPhoto = true } label: { Image(systemName: "camera.viewfinder") }
                    Button { showCustom = true } label: { Image(systemName: "square.and.pencil") }
                    Button { showScanner = true } label: { Image(systemName: "barcode.viewfinder") }
                }
            }
            .sheet(item: $picked) { food in
                FoodAmountSheet(food: food, meal: meal, day: day) { dismiss() }
            }
            .sheet(isPresented: $showScanner) {
                BarcodeScannerSheet { food in
                    showScanner = false
                    if let food { picked = food }
                }
            }
            .sheet(isPresented: $showCustom) { CustomFoodSheet { picked = $0 } }
            .sheet(item: $editFood) { f in CustomFoodSheet(editing: f) { _ in source = .mine } }
            .sheet(isPresented: $showPhoto, onDismiss: takePending) { FoodPhotoView { pending = $0 } }
            .sheet(isPresented: $showRecipes, onDismiss: takePending) { RecipesView { pending = $0 } }
            .onAppear { if saved.isEmpty { source = .taco } }
        }
    }

    private func toggleFavorite(_ food: FoodItem, _ s: SavedFood?) {
        if let s { s.favorite.toggle() } else { let n = SavedFood(food); n.favorite = true; context.insert(n) }
    }

    private var emptyText: String {
        switch source {
        case .recent: "Nada recente ainda"
        case .favorites: "Sem favoritos. Toque na estrela ao adicionar um alimento."
        case .mine: "Crie alimentos com o botão de lápis."
        default: "Nada encontrado"
        }
    }

    private func searchOnline() {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }
        loading = true; error = nil
        Task {
            do { online = try await OpenFoodFacts.search(q) }
            catch { self.error = "Não foi possível buscar online. Verifique a internet." }
            loading = false
        }
    }
}

struct FoodRow: View {
    let food: FoodItem
    let saved: SavedFood?

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    if saved?.favorite == true { Image(systemName: "star.fill").foregroundStyle(.yellow).font(.caption2) }
                    Text(food.name).font(.subheadline).lineLimit(2)
                }
                Text([food.brand, food.sourceLabel].compactMap { $0 }.joined(separator: " · "))
                    .font(.caption2).foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    tag("P", food.per100.protein, Theme.accent)
                    tag("C", food.per100.carbs, Theme.accent2)
                    tag("G", food.per100.fat, Theme.warm)
                }
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text(food.per100.kcal.fmt(0)).font(.headline.monospacedDigit())
                Text("kcal/100g").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
    }

    private func tag(_ l: String, _ v: Double, _ c: Color) -> some View {
        Text("\(l) \(v.fmt(1))").font(.caption2.bold()).foregroundStyle(c)
    }
}

// MARK: - Quantidade

struct FoodAmountSheet: View {
    let food: FoodItem
    var meal: Meal
    let day: Date
    var onAdded: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var saved: [SavedFood]
    @State private var grams: Double = 100
    @State private var chosenMeal: Meal = .lunch
    @State private var added = false

    private var savedFood: SavedFood? { saved.first { $0.foodID == food.id } }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(food.name).font(.headline)
                        Text([food.brand, food.category, food.sourceLabel].compactMap { $0 }.joined(separator: " · "))
                            .font(.caption).foregroundStyle(.secondary)
                        if let a = food.allergens, !a.isEmpty {
                            Label(a.joined(separator: " · "), systemImage: "exclamationmark.triangle.fill")
                                .font(.caption.bold()).foregroundStyle(.orange)
                        }
                    }
                    Picker("Refeição", selection: $chosenMeal) {
                        ForEach(Meal.allCases) { Label($0.label, systemImage: $0.icon).tag($0) }
                    }
                    GramsField(grams: $grams, serving: food.servingGrams.map { (food.servingName ?? "porção", $0) })
                }
                NutrientsSummary(n: food.per100.scaled(grams / 100), m: food.micros?.scaled(grams / 100), e: food.extras?.scaled(grams / 100) ?? [:])
                Section {
                    Button {
                        toggleFavorite()
                    } label: {
                        Label(savedFood?.favorite == true ? "Remover dos favoritos" : "Adicionar aos favoritos",
                              systemImage: savedFood?.favorite == true ? "star.slash" : "star")
                    }
                }
            }
            .navigationTitle("Adicionar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Voltar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Adicionar") {
                        Diary.log(food, grams: grams, meal: chosenMeal, date: Diary.timestamp(for: day), in: context)
                        added = true
                        dismiss()
                        onAdded()
                    }
                    .bold()
                }
            }
            .sensoryFeedback(.success, trigger: added) { _, _ in ThemeStore.shared.haptics }
            .onAppear {
                chosenMeal = meal
                grams = savedFood?.lastGrams ?? food.servingGrams ?? 100
            }
        }
        .presentationDetents([.large])
    }

    private func toggleFavorite() {
        if let s = savedFood { s.favorite.toggle() } else {
            let s = SavedFood(food)
            s.favorite = true
            context.insert(s)
        }
    }
}

// MARK: - Alimento próprio

struct CustomFoodSheet: View {
    var barcode: String? = nil
    /// Alimento a editar (qualquer origem). Alimentos da base/online viram uma cópia "Meu alimento".
    var editing: FoodItem? = nil
    var onCreated: (FoodItem) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var name = ""
    @State private var brand = ""
    @State private var serving: Double?
    @State private var servingName = ""
    @State private var perServing = false
    @State private var isSupplement = false
    @State private var n = Nutrients()
    @State private var m = Micros()
    @State private var e: [String: Double] = [:]
    @State private var chosen: [NutrientID] = []
    @State private var allergens: [String] = []
    @State private var category = ""
    @State private var updateLogs = true
    @State private var loaded = false
    @Query private var savedAll: [SavedFood]
    @State private var pastLogCount = 0

    private var isEditingOwn: Bool { editing.map { $0.id.hasPrefix("custom") } ?? false }
    private func logsDescriptor(_ id: String) -> FetchDescriptor<FoodLog> {
        FetchDescriptor(predicate: #Predicate { $0.foodID == id })
    }

    /// Campos fixos do formulário (os demais são escolhidos pelo usuário).
    private static let base: Set<NutrientID> = [.protein, .carbs, .sugar, .fat, .saturated, .fiber, .sodium]

    private static let templates: [(String, String, [NutrientID])] = [
        ("Multivitamínico", "pills.fill", [.vitaminA, .vitaminC, .vitaminD, .vitaminE, .vitaminK, .b1, .b2, .b3, .b5, .b6, .b12,
                                            .folate, .biotin, .zinc, .selenium, .iodine, .chromium, .magnesium, .calcium, .iron,
                                            .copper, .manganese, .molybdenum]),
        ("Vitamina D + K2", "sun.max.fill", [.vitaminD, .vitaminK]),
        ("Ômega-3", "fish.fill", [.omega3]),
        ("Ferro / anemia", "drop.fill", [.iron, .folate, .b12, .vitaminC]),
        ("Magnésio + zinco", "atom", [.magnesium, .zinc, .b6]),
        ("Cálcio", "figure.walk", [.calcium, .vitaminD]),
        ("Complexo B", "bolt.fill", [.b1, .b2, .b3, .b5, .b6, .b12, .folate, .biotin]),
    ]

    var body: some View {
        NavigationStack {
            Form {
                NutritionLabelScanSection { r in
                    withAnimation {
                        if r.found > 0 { n = r.per100; perServing = false }
                        if let s = r.serving { serving = s }
                        if !r.allergens.isEmpty { allergens = r.allergens }
                    }
                }
                if !allergens.isEmpty {
                    Section("Alérgicos") {
                        ForEach(allergens, id: \.self) { Label($0, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange) }
                        Button("Limpar", role: .destructive) { allergens = [] }
                    }
                }
                Section {
                    TextField("Nome", text: $name)
                    TextField("Marca (opcional)", text: $brand)
                    if editing != nil { TextField("Categoria", text: $category) }
                    Toggle("É um suplemento", isOn: $isSupplement.animation())
                    num(isSupplement ? "Peso de 1 unidade (g)" : "Porção (g)",
                        Binding(get: { serving ?? 0 }, set: { serving = $0 > 0 ? $0 : nil }))
                    TextField(isSupplement ? "Nome da unidade (cápsula, comprimido, scoop…)" : "Nome da porção (opcional)",
                              text: $servingName)
                    Picker("Valores informados", selection: $perServing.animation()) {
                        Text("Por 100 g").tag(false)
                        Text(isSupplement ? "Por unidade" : "Por porção").tag(true)
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Alimento")
                } footer: {
                    if isSupplement {
                        Text("Para cápsulas e comprimidos, informe o peso de 1 unidade (se não souber, use 1 g) e preencha os valores por unidade copiando o rótulo.")
                    }
                }
                Section(perServing ? "Por \(unitLabel) (veja o rótulo)" : "Por 100 g (veja o rótulo)") {
                    num("Calorias (kcal)", $n.kcal)
                    num("Proteína (g)", $n.protein)
                    num("Carboidratos (g)", $n.carbs)
                    num("Açúcares (g)", $n.sugar)
                    num("Gorduras (g)", $n.fat)
                    num("Gordura saturada (g)", $n.saturated)
                    num("Fibras (g)", $n.fiber)
                    num("Sódio (mg)", $n.sodium)
                }
                Section {
                    ForEach(chosen) { id in
                        num("\(id.title) (\(id.unit))", binding(id))
                            .swipeActions { Button("Remover", role: .destructive) { remove(id) } }
                    }
                    Menu {
                        Section("Modelos prontos") {
                            ForEach(Self.templates, id: \.0) { t in
                                Button { add(t.2) } label: { Label(t.0, systemImage: t.1) }
                            }
                        }
                        ForEach(NutrientGroup.allCases) { g in
                            let ids = NutrientID.allCases.filter { $0.group == g && !Self.base.contains($0) && !chosen.contains($0) }
                            if !ids.isEmpty {
                                Menu {
                                    ForEach(ids) { id in Button("\(id.title) (\(id.unit))") { add([id]) } }
                                } label: { Label(g.rawValue, systemImage: g.icon) }
                            }
                        }
                    } label: {
                        Label("Adicionar vitamina, mineral ou nutriente", systemImage: "plus.circle.fill")
                    }
                } header: {
                    Text("Vitaminas, minerais e outros (\(chosen.count))")
                } footer: {
                    Text("Escolha só o que aparece no rótulo. Use os modelos prontos para montar a lista de um multivitamínico de uma vez. Deslize para remover.")
                }
                if isEditingOwn && pastLogCount > 0 {
                    Section {
                        Toggle("Atualizar \(pastLogCount) registro\(pastLogCount == 1 ? "" : "s") já feito\(pastLogCount == 1 ? "" : "s")", isOn: $updateLogs)
                    } footer: {
                        Text("Recalcula o diário com os novos valores, mantendo as quantidades.")
                    }
                }
                if editing != nil && !isEditingOwn {
                    Section {
                        Label("Este alimento vem de uma base pública. Ao salvar, uma cópia editável é criada em \"Meus\".", systemImage: "info.circle")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
            .onAppear(perform: load)
            .navigationTitle(editing != nil ? (isEditingOwn ? "Editar alimento" : "Editar (cópia pessoal)")
                             : (isSupplement ? "Novo suplemento" : "Novo alimento"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar", action: save).disabled(!canSave)
                }
            }
        }
    }

    private var unitLabel: String {
        let nm = servingName.trimmingCharacters(in: .whitespaces)
        return nm.isEmpty ? (isSupplement ? "unidade" : "porção") : nm
    }

    private var canSave: Bool {
        guard !name.isEmpty else { return false }
        if perServing && (serving ?? 0) <= 0 { return false }
        return n.kcal > 0 || n.protein > 0 || n.carbs > 0 || n.fat > 0 || chosen.contains { $0.value(n, m, e) > 0 }
    }

    private func binding(_ id: NutrientID) -> Binding<Double> {
        Binding(get: { id.value(n, m, e) }, set: { id.set($0, &n, &m, &e) })
    }

    private func add(_ ids: [NutrientID]) {
        withAnimation {
            for id in ids where !chosen.contains(id) && !Self.base.contains(id) { chosen.append(id) }
            if ids.count > 3 && !isSupplement { isSupplement = true; perServing = true }
        }
    }

    private func remove(_ id: NutrientID) {
        id.set(0, &n, &m, &e)
        chosen.removeAll { $0 == id }
    }

    /// Preenche o formulário com TUDO do alimento sendo editado.
    private func load() {
        guard !loaded, let f = editing else { return }
        loaded = true
        name = f.name; brand = f.brand ?? ""; category = f.category
        serving = f.servingGrams; servingName = f.servingName ?? ""
        isSupplement = f.category == "Suplementos"
        perServing = false
        n = f.per100; m = f.micros ?? Micros(); e = f.extras ?? [:]
        allergens = f.allergens ?? []
        if isEditingOwn { pastLogCount = (try? context.fetchCount(logsDescriptor(f.id))) ?? 0 }
        chosen = NutrientID.allCases.filter { !Self.base.contains($0) && $0.value(n, m, e) > 0 }
    }

    private func save() {
        // Tudo é guardado por 100 g; valores por porção/unidade são convertidos.
        let f = perServing ? 100 / max(serving ?? 100, 0.01) : 1
        let usedMicros = chosen.contains { !$0.isExtra && $0.value(.zero, m) > 0 }
        let nm = servingName.trimmingCharacters(in: .whitespaces)
        let newID = barcode.map { "custom-bc-\($0)" } ?? "custom-\(UUID().uuidString)"
        let cat = category.trimmingCharacters(in: .whitespaces)
        let food = FoodItem(id: isEditingOwn ? editing!.id : newID, name: name,
                            category: isSupplement ? "Suplementos" : (cat.isEmpty || cat == "Suplementos" ? "Meus alimentos" : cat),
                            brand: brand.isEmpty ? nil : brand, per100: n.scaled(f), servingGrams: serving,
                            servingName: nm.isEmpty ? (isSupplement ? "unidade" : nil) : nm,
                            micros: usedMicros ? m.scaled(f) : nil,
                            allergens: allergens.isEmpty ? nil : allergens,
                            extras: e.isEmpty ? nil : e.scaled(f))
        UndoCenter.enable(context)
        context.undoManager?.beginUndoGrouping()
        defer {
            context.undoManager?.endUndoGrouping()
            if editing != nil { UndoCenter.shared.offer("\(food.name) salvo", in: context) }
        }
        if isEditingOwn, let s = savedAll.first(where: { $0.foodID == food.id }) {
            s.data = Caches.foods.encode(food)
            s.isCustom = true
            if updateLogs {
                // Recalcula os registros já feitos com os novos valores (mesmas gramas).
                for l in (try? context.fetch(logsDescriptor(food.id))) ?? [] {
                    let fresh = FoodLog(date: l.date, meal: l.meal, food: food, grams: l.grams)
                    l.name = fresh.name; l.nutrients = fresh.nutrients; l.micros = fresh.micros; l.extrasData = fresh.extrasData
                }
            }
        } else {
            context.insert(SavedFood(food, custom: true))
        }
        dismiss()
        onCreated(food)
    }

    private func num(_ title: String, _ b: Binding<Double>) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("0", value: b, format: .number.precision(.fractionLength(0...2)))
                .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 90)
        }
    }
}

// MARK: - Código de barras

struct BarcodeScannerSheet: View {
    var onResult: (FoodItem?) -> Void
    @Environment(\.modelContext) private var context
    @State private var status = "Aponte a câmera para o código de barras"
    @State private var busy = false
    @State private var manual = ""
    @State private var missing: String?
    @State private var showCreate = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                    ScannerRepresentable { code in lookup(code) }
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Theme.accent, lineWidth: 2))
                        .frame(height: 320)
                } else {
                    ContentUnavailableView("Câmera indisponível", systemImage: "camera.fill",
                                           description: Text("Permita o acesso à câmera em Ajustes ou digite o código abaixo."))
                }
                HStack {
                    if busy { ProgressView() }
                    Text(status).font(.subheadline).foregroundStyle(.secondary)
                }
                HStack {
                    TextField("Ou digite o código", text: $manual).keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                    Button("Buscar") { lookup(manual) }.buttonStyle(.borderedProminent).disabled(manual.count < 8)
                }
                if missing != nil {
                    Button { showCreate = true } label: {
                        Label("Fotografar a tabela e cadastrar", systemImage: "tablecells.badge.ellipsis")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
                Spacer()
            }
            .padding()
            .navigationTitle("Código de barras")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Fechar") { onResult(nil) } }
            .sheet(isPresented: $showCreate) {
                CustomFoodSheet(barcode: missing) { onResult($0) }
            }
        }
    }

    private func lookup(_ code: String) {
        guard !busy else { return }
        // Primeiro os alimentos que o usuário já cadastrou com este código.
        let localID = "custom-bc-\(code)"
        if let saved = try? context.fetch(FetchDescriptor<SavedFood>(predicate: #Predicate { $0.foodID == localID })).first?.food {
            onResult(saved)
            return
        }
        busy = true
        missing = nil
        status = "Buscando \(code)…"
        Task {
            let food = try? await OpenFoodFacts.product(barcode: code)
            busy = false
            if let food { onResult(food) } else {
                missing = code
                status = "Produto \(code) não encontrado. Cadastre lendo a tabela do rótulo."
            }
        }
    }
}

struct ScannerRepresentable: UIViewControllerRepresentable {
    var onCode: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let vc = DataScannerViewController(recognizedDataTypes: [.barcode(symbologies: [.ean13, .ean8, .upce, .code128])],
                                           qualityLevel: .balanced, isHighlightingEnabled: true)
        vc.delegate = context.coordinator
        try? vc.startScanning()
        return vc
    }

    func updateUIViewController(_ vc: DataScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onCode: onCode) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onCode: (String) -> Void
        private var last: String?
        init(onCode: @escaping (String) -> Void) { self.onCode = onCode }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem],
                         allItems: [RecognizedItem]) {
            for item in addedItems {
                if case .barcode(let b) = item, let code = b.payloadStringValue, code != last {
                    last = code
                    onCode(code)
                }
            }
        }
    }
}
