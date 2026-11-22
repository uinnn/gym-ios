import SwiftUI
import SwiftData

/// Gerador de cardápio a partir das metas e da tabela TACO.
struct MealPlanner {
    enum Role: String { case protein, carb, legume, veg, fruit, fat, dairy, snack }

    struct Item: Identifiable {
        let id = UUID()
        let role: Role
        let food: FoodItem
        let grams: Double
        var nutrients: Nutrients { food.per100.scaled(grams / 100) }
    }

    struct PlannedMeal: Identifiable {
        let meal: Meal
        var items: [Item]
        var id: Meal { meal }
        var total: Nutrients { items.map(\.nutrients).total }
    }

    /// Termos de busca na TACO para cada papel em cada refeição.
    private static let candidates: [Meal: [(Role, [String])]] = [
        .breakfast: [
            (.protein, ["ovo galinha inteiro cozido", "queijo minas frescal", "presunto"]),
            (.carb, ["pao trigo frances", "pao trigo forma integral", "aveia flocos", "cuscuz milho cozido", "tapioca"]),
            (.fruit, ["mamao papaia", "banana prata", "melao", "morango", "maca fuji"]),
            (.dairy, ["iogurte natural", "leite vaca integral", "leite vaca desnatado uht"]),
        ],
        .morningSnack: [
            (.fruit, ["banana prata", "maca fuji", "pera", "laranja pera", "abacaxi"]),
            (.snack, ["castanha-do-brasil crua", "amendoim torrado", "castanha-de-caju", "noz"]),
        ],
        .lunch: [
            (.protein, ["frango peito sem pele grelhado", "carne bovina patinho sem gordura grelhado",
                        "carne bovina contra-file sem gordura grelhado", "merluza file assado", "frango coxa sem pele assada",
                        "porco lombo assado"]),
            (.carb, ["arroz tipo 1 cozido", "arroz integral cozido", "batata doce cozida",
                     "mandioca cozida", "batata inglesa cozida"]),
            (.legume, ["feijao carioca cozido", "feijao preto cozido", "lentilha cozida"]),
            (.veg, ["brocolis cozido", "alface crespa crua", "tomate com semente cru", "cenoura crua", "abobrinha italiana cozida",
                    "couve manteiga refogada"]),
            (.fat, ["azeite oliva"]),
        ],
        .afternoonSnack: [
            (.dairy, ["iogurte natural", "queijo minas frescal", "leite vaca desnatado uht"]),
            (.carb, ["pao trigo forma integral", "biscoito salgado cream cracker", "aveia flocos", "tapioca"]),
            (.fruit, ["banana prata", "maca fuji", "uva italiana", "manga palmer"]),
        ],
        .dinner: [
            (.protein, ["frango peito sem pele grelhado", "ovo galinha inteiro cozido", "merluza file assado",
                        "carne bovina patinho sem gordura grelhado", "atum conserva oleo"]),
            (.carb, ["arroz tipo 1 cozido", "batata doce cozida", "arroz integral cozido", "mandioca cozida", "inhame cozido"]),
            (.veg, ["brocolis cozido", "abobrinha italiana cozida", "alface crespa crua", "tomate com semente cru",
                    "chuchu cozido", "repolho"]),
            (.fat, ["azeite oliva"]),
        ],
    ]

    private static var resolved: [Meal: [(Role, [FoodItem])]] = {
        var out: [Meal: [(Role, [FoodItem])]] = [:]
        for (meal, roles) in candidates {
            out[meal] = roles.map { role, terms in
                (role, terms.compactMap { FoodDatabase.shared.search($0, limit: 1).first })
            }.filter { !$0.1.isEmpty }
        }
        return out
    }()

    let targets: NutritionTargets
    let seed: Int
    var swaps: [String: Int] = [:]   // "meal-role" → deslocamento

    func plan() -> [PlannedMeal] {
        let meals: [Meal] = [.breakfast, .morningSnack, .lunch, .afternoonSnack, .dinner]
        let shareSum = meals.map(\.share).reduce(0, +)
        return meals.map { meal in
            let share = meal.share / shareSum
            return PlannedMeal(meal: meal, items: build(meal, kcal: targets.kcal * share,
                                                        protein: targets.protein * share,
                                                        carbs: targets.carbs * share, fat: targets.fat * share))
        }
    }

    private func pick(_ meal: Meal, _ role: Role, _ list: [FoodItem]) -> FoodItem {
        let off = swaps["\(meal.rawValue)-\(role.rawValue)"] ?? 0
        let i = abs(seed &* 31 &+ meal.rawValue.count &* 7 &+ role.rawValue.count &+ off) % list.count
        return list[i]
    }

    private func r5(_ g: Double, _ lo: Double, _ hi: Double) -> Double {
        (min(max(g, lo), hi) / 5).rounded() * 5
    }

    private func build(_ meal: Meal, kcal: Double, protein: Double, carbs: Double, fat: Double) -> [Item] {
        guard let roles = Self.resolved[meal] else { return [] }
        var items: [Item] = []
        var left = Nutrients(kcal: kcal, protein: protein, carbs: carbs, fat: fat)
        func add(_ role: Role, _ food: FoodItem, _ grams: Double) {
            let it = Item(role: role, food: food, grams: grams)
            items.append(it)
            let n = it.nutrients
            left = Nutrients(kcal: left.kcal - n.kcal, protein: left.protein - n.protein,
                             carbs: left.carbs - n.carbs, fat: left.fat - n.fat)
        }
        let order: [Role] = [.veg, .legume, .fruit, .dairy, .protein, .snack, .carb, .fat]
        for role in order {
            guard let list = roles.first(where: { $0.0 == role })?.1 else { continue }
            let f = pick(meal, role, list), p = f.per100
            switch role {
            case .veg: add(role, f, 80)
            case .legume: add(role, f, 100)
            case .fruit: add(role, f, r5(100, 80, 150))
            case .dairy: add(role, f, p.kcal > 150 ? 30 : 150)
            case .protein:
                let g = p.protein > 1 ? left.protein * 0.85 / p.protein * 100 : 100
                add(role, f, r5(g, 40, 250))
            case .snack: add(role, f, r5(max(left.kcal, 60) / max(p.kcal, 1) * 100 * 0.6, 10, 40))
            case .carb:
                let g = p.carbs > 1 ? max(left.carbs, 10) / p.carbs * 100 : 50
                add(role, f, r5(g, 20, 350))
            case .fat:
                let g = max(left.fat, 0) / max(p.fat, 1) * 100
                if g >= 3 { add(role, f, r5(g, 5, 15)) }
            }
        }
        return items
    }
}

struct MealPlanView: View {
    let day: Date
    let targets: NutritionTargets
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var seed = 0
    @State private var swaps: [String: Int] = [:]
    @State private var addedMeals: Set<Meal> = []

    private var planner: MealPlanner { MealPlanner(targets: targets, seed: seed, swaps: swaps) }

    var body: some View {
        let plan = planner.plan()
        let total = plan.map(\.total).total
        NavigationStack {
            ZStack {
                AnimatedBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        Card {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Total do plano").font(.headline)
                                    Spacer()
                                    Text("\(total.kcal.fmt(0)) / \(targets.kcal.fmt(0)) kcal").font(.subheadline.bold())
                                        .contentTransition(.numericText())
                                }
                                HStack(spacing: 12) {
                                    MacroBar(title: "Proteína", value: total.protein, goal: targets.protein, tint: Theme.accent)
                                    MacroBar(title: "Carbo", value: total.carbs, goal: targets.carbs, tint: Theme.accent2)
                                    MacroBar(title: "Gordura", value: total.fat, goal: targets.fat, tint: Theme.warm)
                                    MacroBar(title: "Fibras", value: total.fiber, goal: targets.fiber, tint: Theme.good)
                                }
                                Text("Cardápio gerado com alimentos da tabela TACO para bater suas metas. Troque qualquer item com 🔄.")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .appear()
                        ForEach(Array(plan.enumerated()), id: \.element.id) { i, m in
                            mealCard(m).appear(0.05 + Double(i) * 0.05)
                        }
                    }
                    .padding()
                    .animation(.spring(duration: 0.5), value: seed)
                    .animation(.spring(duration: 0.4), value: swaps)
                }
            }
            .navigationTitle("Plano alimentar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Fechar") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { seed += 1; swaps = [:]; addedMeals = [] } label: {
                        Label("Gerar outro", systemImage: "dice.fill")
                    }
                }
            }
            .onAppear { seed = Calendar.current.ordinality(of: .day, in: .era, for: day) ?? 0 }
        }
    }

    private func mealCard(_ m: MealPlanner.PlannedMeal) -> some View {
        let done = addedMeals.contains(m.meal)
        return Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label(m.meal.label, systemImage: m.meal.icon).font(.headline)
                    Spacer()
                    Text("\(m.total.kcal.fmt(0)) kcal").font(.subheadline.bold()).foregroundStyle(Theme.accent)
                }
                ForEach(m.items) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.food.name).font(.subheadline).lineLimit(1)
                            Text("\(item.grams.fmt(0)) g · P \(item.nutrients.protein.fmt(0)) C \(item.nutrients.carbs.fmt(0)) G \(item.nutrients.fat.fmt(0))")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(item.nutrients.kcal.fmt(0)).font(.caption.monospacedDigit())
                        Button {
                            swaps["\(m.meal.rawValue)-\(item.role.rawValue)", default: 0] += 1
                        } label: { Image(systemName: "arrow.triangle.2.circlepath") }
                        .buttonStyle(.borderless)
                    }
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
                }
                Button {
                    for it in m.items {
                        Diary.log(it.food, grams: it.grams, meal: m.meal, date: Diary.timestamp(for: day), in: context)
                    }
                    withAnimation(.spring) { _ = addedMeals.insert(m.meal) }
                } label: {
                    Label(done ? "Adicionado ao diário" : "Adicionar ao diário",
                          systemImage: done ? "checkmark.circle.fill" : "plus.circle")
                        .font(.subheadline.bold()).frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered).tint(done ? Theme.good : Theme.accent)
                .disabled(done)
            }
        }
    }
}
