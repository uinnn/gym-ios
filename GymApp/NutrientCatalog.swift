import Foundation

enum NutrientGroup: String, CaseIterable, Identifiable {
    case macros = "Macronutrientes", fats = "Gorduras", minerals = "Minerais", vitamins = "Vitaminas"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .macros: "chart.pie.fill"
        case .fats: "drop.circle.fill"
        case .minerals: "atom"
        case .vitamins: "pills.fill"
        }
    }
}

/// Tipo de referência: atingir uma meta, ficar abaixo de um limite, ou ficar numa faixa.
enum NutrientKind { case target, limit }

struct NutrientRef {
    var min: Double?      // abaixo disso: baixo
    var rec: Double       // recomendado (RDA/AI) ou limite
    var max: Double?      // limite superior tolerável (UL)
}

struct NutrientInfo {
    let function: String
    let sources: String
    let tips: String
    let deficiency: String
    let excess: String
}

/// Contexto para calcular recomendações individuais.
struct NutrientContext {
    let male: Bool
    let age: Int
    let targets: NutritionTargets
}

enum NutrientID: String, CaseIterable, Identifiable {
    case protein, carbs, fiber, sugar, addedSugar
    case fat, saturated, mono, poly, trans, omega3, omega6, cholesterol
    case sodium, potassium, calcium, phosphorus, magnesium, iron, zinc, copper, manganese, selenium
    case vitaminA, b1, b2, b3, b6, b12, folate, vitaminC, vitaminD, vitaminE

    var id: String { rawValue }

    var group: NutrientGroup {
        switch self {
        case .protein, .carbs, .fiber, .sugar, .addedSugar: .macros
        case .fat, .saturated, .mono, .poly, .trans, .omega3, .omega6, .cholesterol: .fats
        case .sodium, .potassium, .calcium, .phosphorus, .magnesium, .iron, .zinc, .copper, .manganese, .selenium: .minerals
        default: .vitamins
        }
    }

    var title: String {
        switch self {
        case .protein: "Proteína"
        case .carbs: "Carboidratos"
        case .fiber: "Fibras"
        case .sugar: "Açúcares totais"
        case .addedSugar: "Açúcar de adição"
        case .fat: "Gorduras totais"
        case .saturated: "Gordura saturada"
        case .mono: "Gordura monoinsaturada"
        case .poly: "Gordura poli-insaturada"
        case .trans: "Gordura trans"
        case .omega3: "Ômega-3 (ALA)"
        case .omega6: "Ômega-6 (linoleico)"
        case .cholesterol: "Colesterol"
        case .sodium: "Sódio"
        case .potassium: "Potássio"
        case .calcium: "Cálcio"
        case .phosphorus: "Fósforo"
        case .magnesium: "Magnésio"
        case .iron: "Ferro"
        case .zinc: "Zinco"
        case .copper: "Cobre"
        case .manganese: "Manganês"
        case .selenium: "Selênio"
        case .vitaminA: "Vitamina A"
        case .b1: "Vitamina B1 (tiamina)"
        case .b2: "Vitamina B2 (riboflavina)"
        case .b3: "Vitamina B3 (niacina)"
        case .b6: "Vitamina B6 (piridoxina)"
        case .b12: "Vitamina B12 (cobalamina)"
        case .folate: "Folato (B9)"
        case .vitaminC: "Vitamina C"
        case .vitaminD: "Vitamina D"
        case .vitaminE: "Vitamina E"
        }
    }

    var unit: String {
        switch self {
        case .protein, .carbs, .fiber, .sugar, .addedSugar, .fat, .saturated, .mono, .poly, .trans, .omega3, .omega6: "g"
        case .selenium, .vitaminA, .b12, .folate, .vitaminD: "µg"
        default: "mg"
        }
    }

    var icon: String {
        switch self {
        case .protein: "fish.fill"
        case .carbs: "leaf.fill"
        case .fiber: "carrot.fill"
        case .sugar, .addedSugar: "cube.fill"
        case .fat, .saturated, .mono, .poly, .trans, .omega3, .omega6: "drop.fill"
        case .cholesterol: "heart.fill"
        case .sodium: "aqi.low"
        case .vitaminD: "sun.max.fill"
        case .vitaminC: "sparkles"
        default: group == .vitamins ? "pills.fill" : "atom"
        }
    }

    var kind: NutrientKind {
        switch self {
        case .sugar, .addedSugar, .saturated, .trans, .cholesterol, .sodium: .limit
        default: .target
        }
    }

    func value(_ n: Nutrients, _ m: Micros) -> Double {
        switch self {
        case .protein: n.protein
        case .carbs: n.carbs
        case .fiber: n.fiber
        case .sugar: n.sugar
        case .addedSugar: m.addedSugar
        case .fat: n.fat
        case .saturated: n.saturated
        case .mono: m.mono
        case .poly: m.poly
        case .trans: m.trans
        case .omega3: m.omega3
        case .omega6: m.omega6
        case .cholesterol: n.cholesterol
        case .sodium: n.sodium
        case .potassium: n.potassium
        case .calcium: n.calcium
        case .phosphorus: m.phosphorus
        case .magnesium: n.magnesium
        case .iron: n.iron
        case .zinc: n.zinc
        case .copper: m.copper
        case .manganese: m.manganese
        case .selenium: m.selenium
        case .vitaminA: m.vitaminA
        case .b1: m.b1
        case .b2: m.b2
        case .b3: m.b3
        case .b6: m.b6
        case .b12: m.b12
        case .folate: m.folate
        case .vitaminC: n.vitaminC
        case .vitaminD: m.vitaminD
        case .vitaminE: m.vitaminE
        }
    }

    /// Referências para adultos (IOM/NIH, OMS, Dietary Guidelines), ajustadas por sexo e idade.
    func reference(_ c: NutrientContext) -> NutrientRef {
        let m = c.male, a = c.age, t = c.targets
        switch self {
        case .protein: return NutrientRef(min: t.protein * 0.8, rec: t.protein, max: t.protein * 1.6)
        case .carbs: return NutrientRef(min: 130, rec: t.carbs, max: t.kcal * 0.65 / 4)
        case .fiber: return NutrientRef(min: m ? 30 : 21, rec: max(t.fiber, m ? 38 : 25), max: 70)
        case .sugar: return NutrientRef(rec: t.kcal * 0.10 / 4)
        case .addedSugar: return NutrientRef(rec: min(t.kcal * 0.10 / 4, m ? 36 : 25))
        case .fat: return NutrientRef(min: t.kcal * 0.20 / 9, rec: t.fat, max: t.kcal * 0.35 / 9)
        case .saturated: return NutrientRef(rec: t.kcal * 0.10 / 9)
        case .mono: return NutrientRef(min: t.kcal * 0.10 / 9, rec: t.kcal * 0.15 / 9)
        case .poly: return NutrientRef(min: t.kcal * 0.06 / 9, rec: t.kcal * 0.08 / 9, max: t.kcal * 0.11 / 9)
        case .trans: return NutrientRef(rec: t.kcal * 0.01 / 9)
        case .omega3: return NutrientRef(min: m ? 1.1 : 0.8, rec: m ? 1.6 : 1.1)
        case .omega6: return NutrientRef(min: m ? 11 : 8, rec: m ? 17 : 12, max: t.kcal * 0.10 / 9)
        case .cholesterol: return NutrientRef(rec: 300)
        case .sodium: return NutrientRef(min: 500, rec: 2000)
        case .potassium: return NutrientRef(min: m ? 2500 : 2000, rec: m ? 3400 : 2600)
        case .calcium: return NutrientRef(min: 700, rec: (!m && a > 50) || a > 70 ? 1200 : 1000, max: a > 50 ? 2000 : 2500)
        case .phosphorus: return NutrientRef(min: 580, rec: 700, max: a > 70 ? 3000 : 4000)
        case .magnesium: return NutrientRef(min: m ? 330 : 255, rec: m ? (a < 31 ? 400 : 420) : (a < 31 ? 310 : 320))
        case .iron: return NutrientRef(min: m || a > 50 ? 6 : 8.1, rec: m || a > 50 ? 8 : 18, max: 45)
        case .zinc: return NutrientRef(min: m ? 9.4 : 6.8, rec: m ? 11 : 8, max: 40)
        case .copper: return NutrientRef(min: 0.7, rec: 0.9, max: 10)
        case .manganese: return NutrientRef(min: m ? 1.8 : 1.4, rec: m ? 2.3 : 1.8, max: 11)
        case .selenium: return NutrientRef(min: 45, rec: 55, max: 400)
        case .vitaminA: return NutrientRef(min: m ? 625 : 500, rec: m ? 900 : 700, max: 3000)
        case .b1: return NutrientRef(min: m ? 1.0 : 0.9, rec: m ? 1.2 : 1.1)
        case .b2: return NutrientRef(min: m ? 1.1 : 0.9, rec: m ? 1.3 : 1.1)
        case .b3: return NutrientRef(min: m ? 12 : 11, rec: m ? 16 : 14, max: 35)
        case .b6: return NutrientRef(min: 1.1, rec: a > 50 ? (m ? 1.7 : 1.5) : 1.3, max: 100)
        case .b12: return NutrientRef(min: 2.0, rec: 2.4)
        case .folate: return NutrientRef(min: 320, rec: 400, max: 1000)
        case .vitaminC: return NutrientRef(min: m ? 75 : 60, rec: m ? 90 : 75, max: 2000)
        case .vitaminD: return NutrientRef(min: 10, rec: a > 70 ? 20 : 15, max: 100)
        case .vitaminE: return NutrientRef(min: 12, rec: 15, max: 1000)
        }
    }

    enum Status { case low, ok, high }

    func status(_ v: Double, _ r: NutrientRef) -> (Status, String) {
        switch kind {
        case .limit:
            if v > r.rec { return (.high, "Acima do limite") }
            if let mn = r.min, v < mn { return (.low, "Abaixo do mínimo") }
            return (.ok, v > r.rec * 0.8 ? "Perto do limite" : "Dentro do limite")
        case .target:
            if let mx = r.max, v > mx { return (.high, "Acima do máximo") }
            if v >= r.rec * 0.9 { return (.ok, "Adequado") }
            if let mn = r.min, v >= mn { return (.ok, "Quase lá") }
            return (.low, "Abaixo do recomendado")
        }
    }

    // MARK: Informações

    var info: NutrientInfo {
        switch self {
        case .protein: NutrientInfo(
            function: "Constrói e repara músculos, pele, cabelo, enzimas, hormônios e anticorpos. Dá muita saciedade e tem o maior efeito térmico da digestão (~25% das calorias gastas para digeri-la).",
            sources: "Carnes, frango, peixes, ovos, laticínios, whey, leguminosas (feijão, lentilha, grão-de-bico), tofu, soja.",
            tips: "Divida em 3–5 refeições com 20–40 g cada (estímulo máximo de síntese muscular). Em dieta para perder gordura, mantenha proteína alta para preservar músculo.",
            deficiency: "Perda de massa muscular, fraqueza, queda de cabelo, cicatrização lenta, mais fome.",
            excess: "Em pessoas saudáveis até ~2,2 g/kg é seguro. Quem tem doença renal deve ter acompanhamento.")
        case .carbs: NutrientInfo(
            function: "Principal fonte de energia do cérebro e dos músculos em exercício intenso. Repõe o glicogênio muscular.",
            sources: "Arroz, batata, mandioca, pães, massas, aveia, frutas, leguminosas, tubérculos.",
            tips: "Prefira integrais e minimamente processados. Concentre perto dos treinos. Mínimo fisiológico recomendado: 130 g/dia.",
            deficiency: "Cansaço, baixo desempenho no treino, dor de cabeça, irritabilidade.",
            excess: "Excesso de calorias; refinados em excesso favorecem picos de glicose e fome.")
        case .fiber: NutrientInfo(
            function: "Alimenta a microbiota intestinal, regula o intestino, aumenta a saciedade, ajuda a controlar glicose e colesterol.",
            sources: "Feijões, lentilha, aveia, chia, linhaça, frutas com casca, verduras, legumes, cereais integrais.",
            tips: "Aumente aos poucos e beba bastante água. 14 g a cada 1.000 kcal é uma boa referência.",
            deficiency: "Prisão de ventre, mais fome, maior risco cardiovascular e de câncer de intestino.",
            excess: "Acima de ~70 g/dia pode causar gases e atrapalhar a absorção de minerais.")
        case .sugar: NutrientInfo(
            function: "Açúcares simples (naturais das frutas e leite + adicionados). Energia rápida.",
            sources: "Frutas, leite, doces, refrigerantes, sucos, biscoitos, molhos industrializados.",
            tips: "O natural das frutas e do leite vem com fibras e nutrientes; o problema principal é o adicionado.",
            deficiency: "Não há necessidade mínima de açúcar livre.",
            excess: "Cáries, ganho de peso, picos de glicose, triglicerídeos altos.")
        case .addedSugar: NutrientInfo(
            function: "Açúcar colocado em alimentos e bebidas (não é o natural das frutas).",
            sources: "Refrigerantes, sucos de caixa, doces, achocolatados, biscoitos, cereais matinais, molhos.",
            tips: "OMS: menos de 10% das calorias, idealmente menos de 5%. AHA: até 36 g (homens) e 25 g (mulheres).",
            deficiency: "Nenhuma — não é necessário.",
            excess: "Maior risco de obesidade, diabetes tipo 2, gordura no fígado e doenças cardíacas.")
        case .fat: NutrientInfo(
            function: "Energia concentrada (9 kcal/g), absorção de vitaminas A, D, E e K, produção de hormônios (incluindo testosterona) e estrutura das células.",
            sources: "Azeite, abacate, castanhas, sementes, peixes, ovos, carnes, laticínios.",
            tips: "Mantenha entre 20 e 35% das calorias. Priorize gorduras mono e poli-insaturadas.",
            deficiency: "Abaixo de 20% das calorias pode prejudicar hormônios e absorção de vitaminas.",
            excess: "Excesso calórico; saturada e trans em excesso pioram o colesterol.")
        case .saturated: NutrientInfo(
            function: "Gordura sólida em temperatura ambiente. Faz parte das membranas celulares.",
            sources: "Carnes gordas, manteiga, queijos, leite integral, coco, embutidos, frituras.",
            tips: "Até 10% das calorias. Troque parte dela por azeite, castanhas e peixes.",
            deficiency: "Não há necessidade de consumir.",
            excess: "Aumenta o LDL (colesterol \"ruim\") e o risco cardiovascular.")
        case .mono: NutrientInfo(
            function: "Gordura \"boa\" que melhora o perfil de colesterol e a sensibilidade à insulina.",
            sources: "Azeite de oliva, abacate, castanhas, amendoim, amêndoas.",
            tips: "Base da dieta mediterrânea. Use azeite como gordura principal.",
            deficiency: "Sem deficiência específica, mas dietas pobres tendem a ter mais saturada.",
            excess: "Apenas o excesso calórico.")
        case .poly: NutrientInfo(
            function: "Inclui ômega-3 e ômega-6, essenciais (o corpo não produz). Ação anti-inflamatória e cardiovascular.",
            sources: "Peixes gordos, linhaça, chia, nozes, óleos vegetais, sementes.",
            tips: "Mantenha ~6–11% das calorias e equilibre ômega-6 com ômega-3.",
            deficiency: "Pele seca, inflamação, problemas de visão e cognição.",
            excess: "Excesso calórico; óleos muito aquecidos oxidam.")
        case .trans: NutrientInfo(
            function: "Gordura artificial (hidrogenada) ou natural em pequena quantidade em carnes e leite de ruminantes.",
            sources: "Biscoitos recheados, sorvetes, salgadinhos, margarinas antigas, frituras industriais.",
            tips: "O ideal é zero. A OMS recomenda menos de 1% das calorias. Leia o rótulo: \"gordura vegetal hidrogenada\".",
            deficiency: "Não há necessidade.",
            excess: "A pior gordura para o coração: sobe o LDL e baixa o HDL.")
        case .omega3: NutrientInfo(
            function: "Anti-inflamatório, protege coração e cérebro, ajuda humor e recuperação muscular. ALA é a forma vegetal; EPA e DHA vêm dos peixes.",
            sources: "Linhaça, chia, nozes (ALA); sardinha, salmão, atum, cavala (EPA/DHA).",
            tips: "Coma peixe gordo 2x por semana. Moa a linhaça para absorver.",
            deficiency: "Pele seca, inflamação, pior humor e memória.",
            excess: "Suplementos em doses muito altas (>3 g EPA+DHA) podem afinar o sangue.")
        case .omega6: NutrientInfo(
            function: "Essencial para pele, cabelo, crescimento e funções imunes.",
            sources: "Óleos de soja, milho e girassol, sementes, castanhas, ovos.",
            tips: "A dieta moderna costuma ter de sobra; foque em aumentar o ômega-3.",
            deficiency: "Rara: pele seca e descamativa.",
            excess: "Relação ômega-6/ômega-3 muito alta favorece inflamação.")
        case .cholesterol: NutrientInfo(
            function: "Componente das células e base de hormônios e vitamina D. O fígado produz a maior parte.",
            sources: "Ovos, carnes, vísceras, frutos do mar, laticínios integrais.",
            tips: "Para a maioria das pessoas o colesterol da dieta afeta pouco o do sangue; saturada e trans pesam mais. Referência clássica: até 300 mg/dia.",
            deficiency: "Não há necessidade de consumo.",
            excess: "Em pessoas sensíveis pode elevar o LDL.")
        case .sodium: NutrientInfo(
            function: "Equilíbrio de líquidos, pressão arterial, transmissão nervosa e contração muscular.",
            sources: "Sal de cozinha (40% sódio), embutidos, temperos prontos, molhos, salgadinhos, pães, queijos.",
            tips: "OMS: até 2.000 mg (≈5 g de sal). Use ervas e limão para temperar. Quem treina muito e sua bastante precisa repor mais.",
            deficiency: "Rara: cãibras, tontura, náusea (comum em atletas de longa duração).",
            excess: "Pressão alta, retenção de líquidos, mais risco de AVC e doença renal.")
        case .potassium: NutrientInfo(
            function: "Equilibra o sódio, baixa a pressão, essencial para coração, músculos e nervos.",
            sources: "Feijão, batata, banana, abacate, laranja, tomate, folhas verdes, iogurte.",
            tips: "A maioria come pouco. Aumentar vegetais e leguminosas é o jeito mais fácil.",
            deficiency: "Cãibras, fraqueza, cansaço, arritmia, pressão alta.",
            excess: "Difícil pela comida; perigoso apenas com doença renal ou certos remédios.")
        case .calcium: NutrientInfo(
            function: "Ossos e dentes, contração muscular, coagulação e transmissão nervosa.",
            sources: "Leite, iogurte, queijos, sardinha com espinha, couve, brócolis, tofu, gergelim.",
            tips: "Precisa de vitamina D para ser absorvido. Distribua ao longo do dia (até ~500 mg por vez).",
            deficiency: "Osteopenia, osteoporose, cãibras.",
            excess: "Acima do limite (geralmente por suplementos): pedras nos rins, prisão de ventre.")
        case .phosphorus: NutrientInfo(
            function: "Ossos e dentes junto com o cálcio, produção de energia (ATP), DNA.",
            sources: "Carnes, peixes, ovos, laticínios, leguminosas, castanhas, refrigerantes de cola.",
            tips: "Quase todo mundo atinge facilmente com alimentação normal.",
            deficiency: "Rara: fraqueza, dor óssea.",
            excess: "Excesso (aditivos fosfatados) pode prejudicar os ossos e os rins.")
        case .magnesium: NutrientInfo(
            function: "Participa de mais de 300 reações: energia, músculos, sono, glicose e pressão.",
            sources: "Sementes de abóbora, castanhas, cacau, aveia, feijões, folhas verdes, banana.",
            tips: "Muito comum faltar. Suplementos de magnésio devem ficar até 350 mg/dia.",
            deficiency: "Cãibras, tremores, insônia, cansaço, ansiedade, arritmia.",
            excess: "Pela comida não há risco; suplementos em excesso causam diarreia.")
        case .iron: NutrientInfo(
            function: "Transporta oxigênio no sangue (hemoglobina) e nos músculos. Essencial para energia e imunidade.",
            sources: "Carnes vermelhas, fígado, feijão, lentilha, folhas escuras, cereais fortificados.",
            tips: "Combine ferro vegetal com vitamina C (laranja, limão). Café e chá na refeição reduzem a absorção. Mulheres precisam de mais (menstruação).",
            deficiency: "Anemia: cansaço, palidez, falta de ar, queda de cabelo, unhas fracas.",
            excess: "Acima de 45 mg (suplementos): náusea, prisão de ventre; acúmulo é tóxico.")
        case .zinc: NutrientInfo(
            function: "Imunidade, cicatrização, paladar, produção de testosterona e síntese de proteínas.",
            sources: "Carnes, frutos do mar (ostras), sementes de abóbora, castanhas, feijões, ovos.",
            tips: "Leguminosas deixadas de molho melhoram a absorção.",
            deficiency: "Imunidade baixa, perda de paladar, queda de cabelo, cicatrização lenta.",
            excess: "Acima de 40 mg/dia atrapalha a absorção de cobre.")
        case .copper: NutrientInfo(
            function: "Formação de glóbulos vermelhos, colágeno, energia e defesa antioxidante.",
            sources: "Fígado, castanhas, cacau, sementes, frutos do mar, leguminosas.",
            tips: "Raramente falta em dietas variadas.",
            deficiency: "Anemia, fraqueza, problemas neurológicos (raro).",
            excess: "Tóxico acima de 10 mg/dia.")
        case .manganese: NutrientInfo(
            function: "Metabolismo de carboidratos e gorduras, formação óssea, antioxidante.",
            sources: "Aveia, arroz integral, castanhas, chá, abacaxi, leguminosas.",
            tips: "Cereais integrais garantem a necessidade.",
            deficiency: "Rara.",
            excess: "Acima de 11 mg/dia pode afetar o sistema nervoso.")
        case .selenium: NutrientInfo(
            function: "Antioxidante, essencial para a tireoide e o sistema imune.",
            sources: "Castanha-do-pará (1 unidade ≈ 50–90 µg!), peixes, ovos, carnes, cereais.",
            tips: "1 a 2 castanhas-do-pará por dia já cobrem a necessidade.",
            deficiency: "Imunidade baixa, problemas de tireoide.",
            excess: "Acima de 400 µg: queda de cabelo, unhas frágeis, hálito de alho.")
        case .vitaminA: NutrientInfo(
            function: "Visão (principalmente noturna), pele, imunidade e reprodução.",
            sources: "Fígado, ovos, leite (retinol); cenoura, abóbora, batata-doce, manga, folhas escuras (betacaroteno).",
            tips: "É lipossolúvel: coma com um pouco de gordura. Betacaroteno dos vegetais não causa excesso.",
            deficiency: "Cegueira noturna, olhos secos, infecções frequentes.",
            excess: "Retinol acima de 3.000 µg (fígado/suplementos): toxicidade hepática; perigoso na gravidez.")
        case .b1: NutrientInfo(
            function: "Transforma carboidratos em energia; essencial para nervos e coração.",
            sources: "Carne de porco, cereais integrais, feijões, sementes de girassol, levedo.",
            tips: "Álcool em excesso reduz muito a absorção.",
            deficiency: "Cansaço, irritabilidade, formigamento; grave: beribéri.",
            excess: "Sem limite conhecido; o excesso é eliminado na urina.")
        case .b2: NutrientInfo(
            function: "Produção de energia, saúde da pele, olhos e metabolismo de outras vitaminas B.",
            sources: "Leite, iogurte, ovos, carnes, fígado, cogumelos, amêndoas.",
            tips: "Sensível à luz: guarde leite em embalagem opaca.",
            deficiency: "Rachaduras nos cantos da boca, língua inflamada, olhos sensíveis.",
            excess: "Sem toxicidade conhecida (urina fica amarelo forte).")
        case .b3: NutrientInfo(
            function: "Energia celular, saúde da pele, sistema nervoso e digestão.",
            sources: "Frango, atum, carnes, amendoim, cogumelos, cereais integrais.",
            tips: "O corpo também produz a partir do triptofano das proteínas.",
            deficiency: "Pelagra: dermatite, diarreia, confusão mental.",
            excess: "Suplementos acima de 35 mg: vermelhidão e calor na pele; doses altas afetam o fígado.")
        case .b6: NutrientInfo(
            function: "Metabolismo de proteínas, produção de neurotransmissores (serotonina, dopamina), formação do sangue.",
            sources: "Grão-de-bico, frango, peixes, batata, banana, carnes.",
            tips: "Quem come mais proteína precisa um pouco mais de B6.",
            deficiency: "Anemia, irritabilidade, depressão, dermatite.",
            excess: "Suplementos acima de 100 mg: dano nos nervos (formigamento).")
        case .b12: NutrientInfo(
            function: "Formação do sangue, DNA e manutenção dos nervos e do cérebro.",
            sources: "Só em alimentos de origem animal: carnes, peixes, ovos, leite; ou fortificados.",
            tips: "Vegetarianos e veganos precisam suplementar. Acima de 50 anos a absorção cai.",
            deficiency: "Anemia, cansaço, formigamento, perda de memória, depressão.",
            excess: "Sem toxicidade conhecida.")
        case .folate: NutrientInfo(
            function: "Formação de DNA e células, essencial na gravidez (previne defeitos no tubo neural).",
            sources: "Folhas verde-escuras, feijões, lentilha, brócolis, fígado, farinhas fortificadas.",
            tips: "Mulheres que planejam engravidar devem suplementar ácido fólico.",
            deficiency: "Anemia, cansaço, aftas.",
            excess: "Ácido fólico de suplementos acima de 1.000 µg pode mascarar falta de B12.")
        case .vitaminC: NutrientInfo(
            function: "Antioxidante, produção de colágeno, imunidade e absorção do ferro vegetal.",
            sources: "Acerola, caju, goiaba, laranja, kiwi, morango, pimentão, brócolis.",
            tips: "É destruída pelo calor e pela luz: prefira frutas e vegetais crus. Fumantes precisam de +35 mg.",
            deficiency: "Gengiva sangrando, cicatrização lenta, cansaço; grave: escorbuto.",
            excess: "Acima de 2.000 mg: diarreia, pedras nos rins.")
        case .vitaminD: NutrientInfo(
            function: "Absorção de cálcio, ossos, músculos, imunidade e humor.",
            sources: "Sol (a principal fonte), peixes gordos, gema de ovo, alimentos fortificados.",
            tips: "15–20 minutos de sol nos braços e pernas várias vezes por semana. Difícil atingir só pela comida; muitos precisam suplementar com orientação.",
            deficiency: "Ossos fracos, dor muscular, cansaço, imunidade baixa, humor deprimido.",
            excess: "Acima de 100 µg (4.000 UI) por longo tempo: cálcio alto no sangue.")
        case .vitaminE: NutrientInfo(
            function: "Antioxidante que protege as células, imunidade e saúde da pele.",
            sources: "Sementes de girassol, amêndoas, avelã, amendoim, azeite, abacate, espinafre.",
            tips: "Um punhado de castanhas por dia ajuda muito.",
            deficiency: "Rara: fraqueza muscular, problemas de visão.",
            excess: "Suplementos acima de 1.000 mg aumentam risco de sangramento.")
        }
    }
}

extension FoodDatabase {
    /// Alimentos mais ricos (por 100 g) em um nutriente.
    func topSources(_ id: NutrientID, limit: Int = 10) -> [(FoodItem, Double)] {
        foods.filter { $0.category != "Suplementos" }
            .map { ($0, id.value($0.per100, $0.micros ?? .zero)) }
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
            .prefix(limit).map { $0 }
    }
}
