import SwiftUI

// MARK: - Faixas e status

enum Tone {
    case low, good, excellent, warn, bad, neutral

    var color: Color {
        switch self {
        case .low: Theme.info
        case .good: Theme.good
        case .excellent: Theme.excellent
        case .warn: Theme.warm
        case .bad: Theme.danger
        case .neutral: .secondary
        }
    }
}

/// Uma faixa de classificação: vale para valores abaixo de `upTo`.
struct Band {
    let upTo: Double
    let label: String
    let tone: Tone
}

private func bands(_ items: (Double, String, Tone)...) -> [Band] {
    items.map { Band(upTo: $0.0, label: $0.1, tone: $0.2) }
}

// MARK: - Catálogo de métricas

enum MetricCategory: String, CaseIterable, Identifiable {
    case composition, muscle, metabolism, indices, health, shape, ideal, nutrition
    var id: String { rawValue }

    var title: String {
        switch self {
        case .composition: "Composição corporal"
        case .muscle: "Músculos e ossos"
        case .metabolism: "Metabolismo e energia"
        case .indices: "Índices corporais"
        case .health: "Saúde e risco"
        case .shape: "Formato e risco (medidas)"
        case .ideal: "Peso ideal e controle"
        case .nutrition: "Nutrição diária"
        }
    }

    var icon: String {
        switch self {
        case .composition: "chart.pie.fill"
        case .muscle: "figure.strengthtraining.traditional"
        case .metabolism: "flame.fill"
        case .indices: "function"
        case .health: "heart.text.square.fill"
        case .shape: "ruler.fill"
        case .ideal: "target"
        case .nutrition: "fork.knife"
        }
    }
}

enum MetricID: String, CaseIterable, Identifiable {
    // composição
    case weight, bmi, bodyFat, fatMass, subcutaneousFat, visceralFat, waterPercent, waterMass,
         proteinPercent, proteinMass, lbm, obesity
    // músculo e osso
    case smmPercent, smm, musclePercent, muscleMass, bone, ffmi, nffmi, muscularPotential
    // metabolismo
    case bmr, metabolicAge, tdee, maxDeficit, maxLossWeek
    // índices
    case bodyScore, fmi, bmiPrime, ponderal, bsa, height, age
    // formato (precisa de medidas)
    case whtr, whr, bri, absi, conicity, rfm, bai
    case mWaist, mAbdomen, mHip, mNeck, mChest, mShoulders, mArmL, mArmR, mForearmL, mForearmR, mThighL, mThighR, mCalfL, mCalfR, mWrist, frameSize, shoulderWaist, chestWaist, armSymmetry, thighSymmetry, calfSymmetry
    // peso ideal
    case standardWeight, idealWeight, healthyMin, healthyMax, weightControl, fatControl, muscleControl
    // nutrição
    case targetCalories, proteinNeed, fatNeed, carbNeed, fiberNeed, waterIntake
    // novas (músculo, saúde, peso, nutrição)
    case smi, asm, asmi, muscleFatRatio, waistRisk, cardioRisk, adjustedWeight, leanWeight, proteinCut

    var id: String { rawValue }

    var category: MetricCategory {
        switch self {
        case .weight, .bmi, .bodyFat, .fatMass, .subcutaneousFat, .visceralFat, .waterPercent, .waterMass,
             .proteinPercent, .proteinMass, .lbm, .obesity: .composition
        case .smmPercent, .smm, .musclePercent, .muscleMass, .bone, .ffmi, .nffmi, .muscularPotential: .muscle
        case .bmr, .metabolicAge, .tdee, .maxDeficit, .maxLossWeek: .metabolism
        case .bodyScore, .fmi, .bmiPrime, .ponderal, .bsa, .height, .age: .indices
        case .whtr, .whr, .bri, .absi, .conicity, .rfm, .bai,
             .mWaist, .mAbdomen, .mHip, .mNeck, .mChest, .mShoulders, .mArmL, .mArmR, .mForearmL, .mForearmR, .mThighL, .mThighR, .mCalfL, .mCalfR, .mWrist, .frameSize, .shoulderWaist, .chestWaist, .armSymmetry, .thighSymmetry, .calfSymmetry: .shape
        case .standardWeight, .idealWeight, .healthyMin, .healthyMax, .weightControl, .fatControl, .muscleControl: .ideal
        case .targetCalories, .proteinNeed, .fatNeed, .carbNeed, .fiberNeed, .waterIntake: .nutrition
        case .smi, .asm, .asmi, .muscleFatRatio: .muscle
        case .waistRisk, .cardioRisk: .health
        case .adjustedWeight, .leanWeight: .ideal
        case .proteinCut: .nutrition
        }
    }

    var title: String {
        switch self {
        case .weight: "Peso"
        case .bmi: "IMC"
        case .bodyFat: "Gordura corporal"
        case .fatMass: "Massa de gordura"
        case .subcutaneousFat: "Gordura subcutânea"
        case .visceralFat: "Gordura visceral"
        case .waterPercent: "Água corporal"
        case .waterMass: "Peso da água"
        case .proteinPercent: "Proteína"
        case .proteinMass: "Massa proteica"
        case .lbm: "Massa magra (LBM)"
        case .obesity: "Grau de obesidade"
        case .smmPercent: "Músculo esquelético"
        case .smm: "Massa muscular esquelética"
        case .musclePercent: "Taxa muscular"
        case .muscleMass: "Massa muscular"
        case .bone: "Massa óssea"
        case .ffmi: "FFMI"
        case .nffmi: "FFMI normalizado"
        case .muscularPotential: "Potencial muscular"
        case .bmr: "Metabolismo basal"
        case .metabolicAge: "Idade metabólica"
        case .tdee: "Gasto diário total"
        case .maxDeficit: "Déficit máximo seguro"
        case .maxLossWeek: "Perda máxima por semana"
        case .bodyScore: "Pontuação corporal"
        case .fmi: "Índice de massa gorda"
        case .bmiPrime: "IMC Prime"
        case .ponderal: "Índice ponderal"
        case .bsa: "Superfície corporal"
        case .height: "Altura"
        case .age: "Idade real"
        case .whtr: "Cintura / altura"
        case .whr: "Cintura / quadril"
        case .bri: "Índice de arredondamento"
        case .absi: "ABSI"
        case .conicity: "Índice de conicidade"
        case .rfm: "Gordura por cintura (RFM)"
        case .bai: "Índice de adiposidade (BAI)"
        case .standardWeight: "Peso padrão"
        case .idealWeight: "Peso ideal (média)"
        case .healthyMin: "Peso saudável mínimo"
        case .healthyMax: "Peso saudável máximo"
        case .weightControl: "Controle de peso"
        case .fatControl: "Controle de gordura"
        case .muscleControl: "Controle muscular"
        case .targetCalories: "Calorias para o objetivo"
        case .proteinNeed: "Proteína diária"
        case .fatNeed: "Gordura diária"
        case .carbNeed: "Carboidrato diário"
        case .fiberNeed: "Fibras diárias"
        case .waterIntake: "Água para beber"
        case .smi: "Índice de músculo esquelético"
        case .asm: "Músculo dos braços e pernas"
        case .asmi: "Índice de músculo apendicular"
        case .muscleFatRatio: "Relação músculo / gordura"
        case .waistRisk: "Risco pela cintura"
        case .cardioRisk: "Fatores de risco cardiometabólico"
        case .adjustedWeight: "Peso ajustado"
        case .leanWeight: "Peso com gordura ideal"
        case .proteinCut: "Proteína em déficit"
        default: measureMeta.title
        }
    }

    var unit: String {
        switch self {
        case .weight, .fatMass, .waterMass, .proteinMass, .lbm, .smm, .muscleMass, .bone,
             .standardWeight, .idealWeight, .healthyMin, .healthyMax, .weightControl, .fatControl,
             .muscleControl, .maxLossWeek: "kg"
        case .bodyFat, .subcutaneousFat, .waterPercent, .proteinPercent, .obesity, .smmPercent,
             .musclePercent, .muscularPotential, .rfm, .bai: "%"
        case .bmi, .ffmi, .nffmi, .fmi: "kg/m²"
        case .ponderal: "kg/m³"
        case .bsa: "m²"
        case .height: "cm"
        case .age, .metabolicAge: "anos"
        case .bmr, .tdee, .maxDeficit, .targetCalories: "kcal"
        case .proteinNeed, .fatNeed, .carbNeed, .fiberNeed: "g"
        case .waterIntake: "L"
        case .visceralFat: "nível"
        case .bodyScore: "pts"
        case .bmiPrime, .whtr, .whr, .bri, .absi, .conicity: ""
        case .smi, .asmi: "kg/m²"
        case .asm, .adjustedWeight, .leanWeight: "kg"
        case .muscleFatRatio: ""
        case .waistRisk: "cm"
        case .cardioRisk: "fatores"
        case .proteinCut: "g"
        default: measureMeta.unit
        }
    }

    var digits: Int {
        switch self {
        case .bmr, .tdee, .maxDeficit, .targetCalories, .proteinNeed, .fatNeed, .carbNeed, .fiberNeed,
             .height, .age, .metabolicAge, .visceralFat, .bodyScore, .cardioRisk, .proteinCut, .waistRisk: 0
        case .muscleFatRatio: 2
        case .weight, .whtr, .whr, .bmiPrime, .bsa, .conicity, .shoulderWaist, .chestWaist: 2
        case .absi: 4
        default: 1
        }
    }

    var icon: String {
        switch self {
        case .weight: "scalemass.fill"
        case .bmi: "figure.stand"
        case .bodyFat, .fatMass: "drop.halffull"
        case .subcutaneousFat: "square.3.layers.3d.down.right"
        case .visceralFat: "heart.text.square.fill"
        case .waterPercent, .waterMass: "drop.fill"
        case .proteinPercent, .proteinMass: "atom"
        case .lbm: "bolt.heart.fill"
        case .obesity: "exclamationmark.triangle.fill"
        case .smmPercent, .smm: "figure.strengthtraining.traditional"
        case .musclePercent, .muscleMass: "dumbbell.fill"
        case .bone: "figure.walk"
        case .ffmi, .nffmi: "medal.fill"
        case .muscularPotential: "chart.line.uptrend.xyaxis"
        case .bmr: "flame.fill"
        case .metabolicAge: "hourglass"
        case .tdee: "bolt.fill"
        case .maxDeficit, .maxLossWeek: "arrow.down.forward.circle.fill"
        case .bodyScore: "star.fill"
        case .fmi: "circle.dotted.circle"
        case .bmiPrime: "plusminus"
        case .ponderal: "cube.fill"
        case .bsa: "square.dashed"
        case .height: "ruler.fill"
        case .age: "birthday.cake.fill"
        case .whtr, .whr, .rfm, .bai: "ruler"
        case .bri, .absi, .conicity: "circle.circle"
        case .standardWeight, .idealWeight: "target"
        case .healthyMin, .healthyMax: "checkmark.shield.fill"
        case .weightControl, .fatControl, .muscleControl: "slider.horizontal.3"
        case .targetCalories: "flame.circle.fill"
        case .proteinNeed: "fish.fill"
        case .fatNeed: "drop.circle.fill"
        case .carbNeed: "leaf.fill"
        case .fiberNeed: "carrot.fill"
        case .waterIntake: "waterbottle.fill"
        case .smi, .asmi: "figure.strengthtraining.functional"
        case .asm: "figure.arms.open"
        case .muscleFatRatio: "scalemass"
        case .waistRisk: "ruler"
        case .cardioRisk: "heart.text.square.fill"
        case .adjustedWeight, .leanWeight: "target"
        case .proteinCut: "fish.fill"
        default: measureMeta.icon
        }
    }

    /// Para colorir variações: true = subir é bom, false = descer é bom, nil = depende/neutro.
    var higherIsBetter: Bool? {
        switch self {
        case .smmPercent, .smm, .musclePercent, .muscleMass, .bone, .waterPercent, .waterMass,
             .proteinPercent, .proteinMass, .lbm, .ffmi, .nffmi, .bodyScore, .muscularPotential,
             .smi, .asm, .asmi, .muscleFatRatio: true
        case .waistRisk, .cardioRisk: false
        case .bmi, .bodyFat, .fatMass, .subcutaneousFat, .visceralFat, .obesity, .metabolicAge, .fmi,
             .whtr, .whr, .bri, .absi, .conicity, .rfm, .bai, .bmiPrime: false
        case .mWaist, .mAbdomen, .mNeck, .armSymmetry, .thighSymmetry, .calfSymmetry: false
        case .mArmL, .mArmR, .mForearmL, .mForearmR, .mCalfL, .mCalfR, .mShoulders, .mChest, .shoulderWaist, .chestWaist: true
        default: nil
        }
    }

    /// Precisa de medidas (cintura/quadril/pescoço) para existir.
    var needsMeasurements: Bool { category == .shape }

    /// Métricas mostradas na tela inicial.
    static let highlights: [MetricID] = [.bmi, .bodyFat, .smm, .visceralFat, .waterPercent, .bmr,
                                         .metabolicAge, .bone, .proteinPercent, .lbm]
}

// MARK: - Informações (texto educativo)

struct MetricInfo {
    let what: String
    let how: String
    let tip: String
}

extension MetricID {
    var info: MetricInfo {
        switch self {
        case .weight: MetricInfo(
            what: "Massa total do corpo: músculos, gordura, ossos, água, órgãos e o que está no intestino.",
            how: "Lido direto da balança via Bluetooth, com resolução de 0,05 kg.",
            tip: "O peso oscila até 1–2 kg por dia (água, sal, carboidratos, intestino). Pese-se sempre no mesmo horário, de preferência ao acordar, após ir ao banheiro e antes de comer. Observe a média semanal, não o dia isolado.")
        case .bmi: MetricInfo(
            what: "Índice de Massa Corporal: relação entre peso e altura, usada pela OMS para classificar o peso.",
            how: "IMC = peso (kg) ÷ altura² (m).",
            tip: "É ótimo para populações, mas não distingue músculo de gordura: pessoas musculosas podem ter IMC alto e ser saudáveis. Combine com gordura corporal e cintura/altura.")
        case .bodyFat: MetricInfo(
            what: "Percentual do peso que é tecido adiposo (gordura essencial + gordura de reserva).",
            how: "Usa o método mais preciso disponível com seus dados: 1) Marinha dos EUA (pescoço + cintura [+ quadril]), 2) RFM (cintura e altura), 3) CUN-BAE (IMC, idade e sexo; validado contra DEXA). Cadastre medidas para maior precisão.",
            tip: "Reduza com déficit calórico moderado, proteína alta, treino de força e sono adequado. Faixas saudáveis variam com idade e sexo (Gallagher et al., 2000).")
        case .fatMass: MetricInfo(
            what: "Quantos quilos do seu peso são gordura.",
            how: "Peso × gordura corporal %.",
            tip: "É o número que realmente importa num emagrecimento: o ideal é perder gordura preservando a massa magra.")
        case .subcutaneousFat: MetricInfo(
            what: "Gordura logo abaixo da pele (a que dá para \"pinçar\"). É a maior parte da gordura total.",
            how: "Estimada como a gordura total menos a parcela visceral típica para seu sexo.",
            tip: "Menos perigosa que a visceral, mas em excesso também aumenta riscos. Diminui junto com a gordura total.")
        case .visceralFat: MetricInfo(
            what: "Gordura dentro do abdômen, ao redor dos órgãos. É a mais ligada a diabetes, pressão alta e doenças cardíacas.",
            how: "Nível estimado (escala 1–30, como nas balanças de bioimpedância) a partir de gordura corporal, idade e, se informada, cintura.",
            tip: "Nível 1–9 é saudável. Responde muito bem a exercício aeróbico, treino de força, menos álcool e açúcar, e sono. Medir a cintura regularmente é o melhor jeito de acompanhar.")
        case .waterPercent: MetricInfo(
            what: "Percentual do peso que é água. Músculos têm ~75% de água; gordura, ~10%.",
            how: "Massa magra × 0,732: a hidratação da massa magra é praticamente constante em adultos (Wang et al., 1999). A fórmula de Watson (1980) aparece como comparação.",
            tip: "Valores baixos podem indicar desidratação ou muita gordura. Beba água ao longo do dia e mantenha massa muscular.")
        case .waterMass: MetricInfo(
            what: "Litros (≈ kg) de água no seu corpo.",
            how: "Massa magra × 0,732 (Wang, 1999); compare com Watson (1980), que usa peso, altura, idade e sexo.",
            tip: "Varia bastante ao longo do dia: é um dos motivos do peso oscilar.")
        case .proteinPercent: MetricInfo(
            what: "Percentual do peso formado por proteínas (músculos, órgãos, enzimas).",
            how: "Massa magra − água − minerais ósseos, dividido pelo peso.",
            tip: "16–20% é normal. Aumenta com treino de força e ingestão adequada de proteína.")
        case .proteinMass: MetricInfo(
            what: "Quilos de proteína no corpo.",
            how: "Massa magra − água corporal − massa óssea.",
            tip: "Indicador indireto de massa muscular e nutrição.")
        case .lbm: MetricInfo(
            what: "Lean Body Mass: tudo que não é gordura (músculos, ossos, órgãos, água).",
            how: "Peso − massa de gordura. Comparado também com as fórmulas de Boer, James e Hume.",
            tip: "Quanto maior, maior o metabolismo. Preserve-a com treino de força e proteína, principalmente em dieta.")
        case .obesity: MetricInfo(
            what: "Quanto seu peso está acima (ou abaixo) do peso padrão para a sua altura.",
            how: "(peso − peso padrão) ÷ peso padrão × 100. Peso padrão = IMC 22.",
            tip: "Entre −10% e +10% é considerado normal. Acima de 20% indica obesidade.")
        case .smmPercent: MetricInfo(
            what: "Percentual do peso formado pelos músculos que você movimenta voluntariamente (braços, pernas, tronco).",
            how: "~53% (homens) ou ~48% (mulheres) da massa magra, segundo ressonância magnética de corpo inteiro (Janssen et al., 2000), com ajuste de idade após os 45.",
            tip: "É o músculo que você treina. Treino de força 2–4x por semana com progressão de carga é o principal estímulo.")
        case .smm: MetricInfo(
            what: "Quilos de músculo esquelético.",
            how: "Massa magra × fração esquelética típica para sexo e idade.",
            tip: "Após os 30 anos perdemos 3–8% por década sem treino (sarcopenia). Força e proteína revertem isso.")
        case .musclePercent: MetricInfo(
            what: "Percentual do peso formado por todo tipo de músculo (esquelético, liso e cardíaco) + água neles.",
            how: "(Massa magra − massa óssea) ÷ peso. É o \"muscle rate\" das balanças de bioimpedância.",
            tip: "Sobe quando você ganha músculo ou perde gordura.")
        case .muscleMass: MetricInfo(
            what: "Quilos de massa muscular total.",
            how: "Massa magra − massa óssea.",
            tip: "Indicador amplo de força e saúde metabólica.")
        case .bone: MetricInfo(
            what: "Peso estimado dos minerais dos ossos.",
            how: "Proporção típica da massa magra (~5,5%). Comparado com a referência por faixa de peso.",
            tip: "Muda muito devagar. Treino de impacto/força, cálcio, vitamina D e proteína ajudam a manter.")
        case .ffmi: MetricInfo(
            what: "Fat-Free Mass Index: \"IMC\" só da massa magra. Mostra o quanto você é musculoso para sua altura.",
            how: "Massa magra ÷ altura².",
            tip: "Homens: 18–20 médio, 22+ bem treinado, ~25 é o limite natural típico. Mulheres: 15–17 médio, 19+ bem treinada.")
        case .nffmi: MetricInfo(
            what: "FFMI ajustado para 1,80 m, permitindo comparar pessoas de alturas diferentes.",
            how: "FFMI + 6,1 × (1,8 − altura em m) (Kouri et al., 1995).",
            tip: "Mesmas faixas do FFMI.")
        case .muscularPotential: MetricInfo(
            what: "Quanto da massa magra máxima natural estimada você já atingiu.",
            how: "Massa magra ÷ massa magra no FFMI normalizado de 25 (homens) / 21 (mulheres).",
            tip: "É uma referência motivacional, não uma regra. Iniciantes ganham rápido; perto de 90% o progresso fica lento.")
        case .bmr: MetricInfo(
            what: "Calorias que seu corpo gasta em repouso total, só para se manter vivo (respirar, coração, cérebro).",
            how: "Mifflin-St Jeor (1990), a fórmula mais precisa em estudos comparativos. Também mostramos Katch-McArdle, Harris-Benedict revisada e Cunningham.",
            tip: "Corresponde a ~60–70% do gasto diário. Massa muscular maior aumenta o basal.")
        case .metabolicAge: MetricInfo(
            what: "A idade de uma pessoa \"média\" com o mesmo metabolismo basal que o seu.",
            how: "Parte da sua idade real e ajusta pela composição: gordura acima do esperado para sua idade e sexo envelhece (~1,2 ano por ponto %), massa magra acima da média (FFMI) rejuvenesce. É o mesmo princípio das balanças de bioimpedância.",
            tip: "Abaixo da idade real é ótimo. Aumentar massa muscular e reduzir gordura \"rejuvenesce\" esse número.")
        case .tdee: MetricInfo(
            what: "Total de calorias que você gasta por dia, incluindo atividades.",
            how: "Metabolismo basal × fator de atividade (1,2 a 1,9).",
            tip: "Comer isso mantém o peso. Ajuste o nível de atividade no perfil para refinar.")
        case .maxDeficit: MetricInfo(
            what: "Maior déficit calórico diário que a gordura do seu corpo consegue sustentar sem sacrificar músculo.",
            how: "Limite de Alpert (2005): ~31 kcal por libra de gordura por dia.",
            tip: "Fique bem abaixo disso para conforto. Déficits de 300–500 kcal são mais fáceis de manter.")
        case .maxLossWeek: MetricInfo(
            what: "Perda máxima de gordura por semana dentro do limite de Alpert.",
            how: "Déficit máximo × 7 ÷ 7.700 kcal/kg.",
            tip: "Perder 0,5–1% do peso por semana é a recomendação mais comum.")
        case .bodyScore: MetricInfo(
            what: "Nota geral de 0 a 100 da sua composição corporal.",
            how: "Média ponderada de 5 notas de 0 a 100: gordura corporal (30%, nota máxima só na faixa ótima), massa muscular pelo FFMI normalizado (30%), IMC (15%), gordura visceral (15%) e cintura/altura ou idade metabólica (10%). Ter pouca gordura não basta: sem massa muscular a nota fica limitada.",
            tip: "Use como resumo rápido. Veja quais métricas estão fora da faixa para saber onde agir.")
        case .fmi: MetricInfo(
            what: "Fat Mass Index: \"IMC\" só da gordura.",
            how: "Massa de gordura ÷ altura² (faixas de Kelly et al., 2009).",
            tip: "Separa gordura de músculo melhor que o IMC.")
        case .bmiPrime: MetricInfo(
            what: "IMC dividido pelo limite superior saudável (25).",
            how: "IMC ÷ 25.",
            tip: "Abaixo de 1,0 = dentro do limite; 1,2 = 20% acima.")
        case .ponderal: MetricInfo(
            what: "Índice de Rohrer: como o IMC, mas usa altura³, sendo mais justo para pessoas muito altas ou baixas.",
            how: "Peso ÷ altura³.",
            tip: "11–15 é a faixa normal para adultos.")
        case .bsa: MetricInfo(
            what: "Área da superfície do corpo. Usada em medicina para doses e índices cardíacos.",
            how: "Fórmula de Mosteller: √(altura cm × peso ÷ 3600).",
            tip: "Valor informativo; adultos ficam em torno de 1,6–2,0 m².")
        case .height: MetricInfo(
            what: "Sua altura cadastrada.",
            how: "Informada no perfil.",
            tip: "Meça descalço, encostado na parede, de manhã.")
        case .age: MetricInfo(
            what: "Sua idade cronológica.",
            how: "Calculada pela data de nascimento.",
            tip: "Compare com a idade metabólica.")
        case .whtr: MetricInfo(
            what: "Relação cintura/altura: um dos melhores preditores de risco cardiometabólico.",
            how: "Cintura ÷ altura.",
            tip: "Regra simples: mantenha a cintura menor que metade da sua altura (< 0,5).")
        case .whr: MetricInfo(
            what: "Relação cintura/quadril: indica onde a gordura se acumula.",
            how: "Cintura ÷ quadril (critérios da OMS).",
            tip: "Homens < 0,90 e mulheres < 0,80 indicam baixo risco.")
        case .bri: MetricInfo(
            what: "Body Roundness Index: estima o quanto o corpo é \"arredondado\", associado à gordura visceral.",
            how: "Fórmula de Thomas et al. (2013), usando cintura e altura.",
            tip: "Valores acima de ~6,9 associam-se a maior mortalidade em estudos populacionais.")
        case .absi: MetricInfo(
            what: "A Body Shape Index: risco ligado ao formato do corpo independente do IMC.",
            how: "Cintura ÷ (IMC^⅔ × altura^½) (Krakauer, 2012).",
            tip: "Valores típicos ~0,080. Quanto maior, maior a concentração abdominal.")
        case .conicity: MetricInfo(
            what: "Compara seu abdômen com um cilindro do mesmo peso e altura.",
            how: "Cintura ÷ (0,109 × √(peso ÷ altura)).",
            tip: "1,0 = cilindro perfeito. Valores maiores indicam acúmulo abdominal.")
        case .rfm: MetricInfo(
            what: "Relative Fat Mass: estimativa de gordura usando só cintura e altura.",
            how: "64 (homens) ou 76 (mulheres) − 20 × altura ÷ cintura (Woolcott, 2018; validado com DEXA).",
            tip: "Bom para conferir a estimativa principal de gordura.")
        case .bai: MetricInfo(
            what: "Body Adiposity Index: estimativa de gordura usando quadril e altura.",
            how: "Quadril ÷ altura^1,5 − 18 (Bergman, 2011).",
            tip: "Menos preciso em extremos; use como comparação.")
        case .standardWeight: MetricInfo(
            what: "Peso correspondente a IMC 22, o centro da faixa saudável.",
            how: "22 × altura².",
            tip: "Referência usada pelas balanças de bioimpedância.")
        case .idealWeight: MetricInfo(
            what: "Média das fórmulas clássicas de peso ideal.",
            how: "Média de Devine (1974), Robinson (1983), Miller (1983) e Hamwi (1964).",
            tip: "São referências antigas que só usam altura. Composição corporal importa mais.")
        case .healthyMin: MetricInfo(
            what: "Menor peso considerado saudável para sua altura.",
            how: "IMC 18,5 × altura².",
            tip: "Abaixo disso há risco de desnutrição e perda óssea.")
        case .healthyMax: MetricInfo(
            what: "Maior peso considerado saudável para sua altura.",
            how: "IMC 24,9 × altura².",
            tip: "Acima disso, avalie gordura e cintura para entender o risco real.")
        case .weightControl: MetricInfo(
            what: "Quanto falta mudar no peso para chegar ao peso padrão.",
            how: "Peso padrão − peso atual.",
            tip: "Negativo = perder; positivo = ganhar.")
        case .fatControl: MetricInfo(
            what: "Quanto de gordura mudar para chegar ao meio da faixa saudável, mantendo a massa magra.",
            how: "Calcula o peso em que sua massa magra atual teria a gordura ideal.",
            tip: "Negativo = perder gordura.")
        case .muscleControl: MetricInfo(
            what: "Quanto de músculo esquelético ganhar para sair da faixa baixa.",
            how: "Diferença até o limite inferior normal de músculo esquelético.",
            tip: "Zero significa que você já está na faixa normal ou acima.")
        case .targetCalories: MetricInfo(
            what: "Calorias diárias sugeridas para o seu objetivo.",
            how: "Gasto total −500 (perder), +0 (manter) ou +300 (ganhar), nunca abaixo do basal.",
            tip: "Acompanhe o peso por 2–3 semanas e ajuste 100–200 kcal se o ritmo não estiver bom.")
        case .proteinNeed: MetricInfo(
            what: "Proteína diária recomendada para preservar e construir músculo.",
            how: "1,6 g por kg (ISSN) ou 2,2 g por kg de massa magra quando a gordura está alta.",
            tip: "Divida em 3–5 refeições com 20–40 g cada.")
        case .fatNeed: MetricInfo(
            what: "Gordura alimentar diária sugerida.",
            how: "25% das calorias do objetivo ÷ 9 kcal/g.",
            tip: "Priorize azeite, castanhas, peixes, ovos e abacate. Não fique abaixo de ~0,5 g/kg.")
        case .carbNeed: MetricInfo(
            what: "Carboidratos diários: o restante das calorias.",
            how: "(Calorias − proteína × 4 − gordura × 9) ÷ 4.",
            tip: "Concentre perto dos treinos. Prefira integrais, frutas, legumes e tubérculos.")
        case .fiberNeed: MetricInfo(
            what: "Fibras recomendadas por dia.",
            how: "14 g para cada 1.000 kcal (Dietary Guidelines).",
            tip: "Ajudam saciedade, intestino e colesterol.")
        case .waterIntake: MetricInfo(
            what: "Água para beber por dia.",
            how: "35 ml por kg de peso.",
            tip: "Aumente em dias quentes ou de treino. Urina clara é um bom sinal.")
        case .smi: MetricInfo(
            what: "Músculo esquelético dividido pela altura ao quadrado. Usado em pesquisas para identificar perda de músculo (sarcopenia) independentemente do tamanho da pessoa.",
            how: "Massa muscular esquelética ÷ altura² (Janssen et al., 2004). Referências: homens < 8,5 risco alto e 8,5–10,75 risco moderado; mulheres < 5,75 e 5,75–6,75.",
            tip: "Treino de força 2–3x por semana e proteína suficiente são o que mais protege o músculo, principalmente depois dos 40.")
        case .asm: MetricInfo(
            what: "Massa magra dos braços e das pernas: o músculo que você usa para se mover. É o principal marcador de força e independência com a idade.",
            how: "Equação antropométrica de Lee et al. (2000), validada contra exame de imagem (ressonância): peso, altura, idade e sexo.",
            tip: "Agachamento, remadas, supino e caminhadas com carga aumentam esse número.")
        case .asmi: MetricInfo(
            what: "Músculo de braços e pernas ajustado pela altura: o critério do consenso europeu de sarcopenia (EWGSOP2).",
            how: "Músculo apendicular ÷ altura². Baixo: homens < 7,0 kg/m², mulheres < 5,5 kg/m² (Cruz-Jentoft et al., 2019).",
            tip: "Se estiver baixo, priorize treino de força e ~1,6 g/kg de proteína por dia.")
        case .muscleFatRatio: MetricInfo(
            what: "Quantos kg de músculo esquelético você tem para cada kg de gordura. Relações maiores estão ligadas a menor risco de síndrome metabólica.",
            how: "Massa muscular esquelética ÷ massa de gordura.",
            tip: "Sobe tanto ganhando músculo quanto perdendo gordura — por isso mostra a recomposição melhor que o peso.")
        case .waistRisk: MetricInfo(
            what: "Circunferência da cintura comparada com os limites da OMS para risco de doenças metabólicas e cardiovasculares.",
            how: "Homens: risco aumentado ≥ 94 cm, alto ≥ 102 cm. Mulheres: ≥ 80 cm e ≥ 88 cm (OMS/IDF).",
            tip: "A cintura costuma cair mesmo quando o peso para: meça a cada 2–4 semanas no mesmo ponto (na altura do umbigo).")
        case .cardioRisk: MetricInfo(
            what: "Quantos fatores de risco cardiometabólico ligados ao corpo você tem hoje: IMC alto, gordura corporal alta, gordura visceral alta, cintura/altura ≥ 0,5 e cintura/quadril alta.",
            how: "Soma dos critérios da OMS e das faixas de gordura por idade e sexo. Exames de sangue e pressão não entram aqui.",
            tip: "Cada fator a menos reduz o risco. Cintura e gordura visceral respondem rápido a déficit calórico, sono e atividade.")
        case .adjustedWeight: MetricInfo(
            what: "Peso usado em clínicas para calcular doses e necessidades quando há excesso de peso: considera só parte do peso acima do ideal.",
            how: "Peso ideal (Devine) + 0,4 × (peso atual − peso ideal), quando o peso está mais de 20% acima do ideal.",
            tip: "Útil para calcular proteína em quem tem bastante gordura a perder.")
        case .leanWeight: MetricInfo(
            what: "O peso que você teria mantendo toda a massa magra atual e chegando ao meio da faixa saudável de gordura para sua idade.",
            how: "Massa magra ÷ (1 − gordura alvo). Faixas de gordura de Gallagher et al. (2000).",
            tip: "Uma meta de peso mais realista que o IMC, porque respeita o músculo que você já tem.")
        case .proteinCut: MetricInfo(
            what: "Proteína diária para preservar músculo durante a perda de gordura.",
            how: "2,3 a 3,1 g por kg de massa magra (Helms et al., 2014); mostramos o meio da faixa.",
            tip: "Em déficit, a proteína alta também aumenta a saciedade e o gasto da digestão.")
        default: measureInfo
        }
    }
}

// MARK: - Entradas

struct BodyInputs {
    var kg: Double
    var heightCm: Double
    var age: Int
    var isMale: Bool
    var activity: Double
    var goal: Goal
    var neck: Double?
    var waist: Double?
    var hip: Double?
    var parts: [BodyPart: Double] = [:]

    init(kg: Double, profile: UserProfile, measurement: MeasurementEntry? = nil) {
        var p: [BodyPart: Double] = [:]
        if let m = measurement { for part in BodyPart.allCases { if let v = m[part] { p[part] = v } } }
        self.init(kg: kg, profile: profile, parts: p)
    }

    /// Versão rápida: recebe as medidas já prontas (sem criar objetos do banco).
    init(kg: Double, profile: UserProfile, parts: [BodyPart: Double]) {
        self.kg = kg
        heightCm = profile.heightCm
        age = profile.age
        isMale = profile.sex == .male
        activity = profile.activity.factor
        goal = profile.goal
        self.parts = parts
        if self.parts[.waist] == nil, let w = profile.waistCm { self.parts[.waist] = w }
        neck = self.parts[.neck]
        waist = self.parts[.waist]
        hip = self.parts[.hip]
    }

    func with(kg: Double) -> BodyInputs { var c = self; c.kg = kg; return c }
}

// MARK: - Métrica calculada

struct Metric: Identifiable {
    let id: MetricID
    let value: Double
    var bands: [Band] = []
    var scale: ClosedRange<Double>? = nil
    var method: String? = nil
    var comparisons: [(String, Double)] = []

    var status: Band? {
        guard !bands.isEmpty else { return nil }
        return bands.first { value < $0.upTo } ?? bands.last
    }
    var display: String { value.fmt(id.digits) }
}

// MARK: - Motor de cálculo

struct BodyAnalysis {
    let input: BodyInputs

    // valores principais
    let h: Double, bmi: Double
    let bodyFat: Double, fatMethod: String
    let fatMass: Double, lbm: Double
    let water: Double, watson: Double, bone: Double, muscle: Double, smm: Double, protein: Double
    let visceral: Double
    let mifflin: Double, katch: Double, harris: Double, cunningham: Double
    let metabolicAge: Double, tdee: Double, target: Double
    let standard: Double
    let fatRange: (low: Double, healthy: Double, high: Double)

    init(_ i: BodyInputs) {
        input = i
        let W = i.kg, H = i.heightCm, A = Double(i.age), male = i.isMale
        h = H / 100
        bmi = W / (h * h)

        // Gordura: Marinha > RFM > CUN-BAE
        var bf: Double, method: String
        if let n = i.neck, let w = i.waist, male, w > n {
            bf = 495 / (1.0324 - 0.19077 * log10(w - n) + 0.15456 * log10(H)) - 450
            method = "Marinha dos EUA (pescoço + cintura)"
        } else if let n = i.neck, let w = i.waist, let hp = i.hip, !male, w + hp > n {
            bf = 495 / (1.29579 - 0.35004 * log10(w + hp - n) + 0.22100 * log10(H)) - 450
            method = "Marinha dos EUA (pescoço + cintura + quadril)"
        } else if let w = i.waist {
            bf = (male ? 64 : 76) - 20 * (H / w)
            method = "RFM (cintura e altura)"
        } else {
            let s = male ? 0.0 : 1.0, B = bmi
            bf = -44.988 + 0.503 * A + 10.689 * s + 3.172 * B - 0.026 * B * B + 0.181 * B * s
                - 0.02 * B * A - 0.005 * B * B * s + 0.00021 * B * B * A
            method = "CUN-BAE (IMC, idade e sexo)"
        }
        bodyFat = min(max(bf, 3), 65)
        fatMethod = method
        fatMass = W * bodyFat / 100
        lbm = W - fatMass

        // Água (Watson), osso, músculo, proteína
        let tbw = male ? 2.447 - 0.09516 * A + 0.1074 * H + 0.3362 * W
                       : -2.097 + 0.1069 * H + 0.2466 * W
        // Hidratação da massa magra é constante em adultos: 73,2% (Wang et al., 1999).
        // Usar a mesma gordura estimada mantém água, proteína e massa magra coerentes entre si.
        water = lbm * 0.732
        watson = tbw
        bone = lbm * 0.055
        muscle = lbm - bone
        // Músculo esquelético ≈ 53% (homens) / 48% (mulheres) da massa magra (Janssen et al., 2000, RM),
        // com perda de ~0,3%/ano após os 45.
        smm = lbm * (male ? 0.53 : 0.48) * (1 - max(0, A - 45) * 0.003)
        protein = max(0, lbm - water - bone)

        // Faixas de gordura por idade e sexo (Gallagher, 2000)
        let fr: (Double, Double, Double)
        switch (male, A) {
        case (true, ..<40): fr = (8, 20, 25)
        case (true, ..<60): fr = (11, 22, 28)
        case (true, _): fr = (13, 25, 30)
        case (false, ..<40): fr = (21, 33, 39)
        case (false, ..<60): fr = (23, 34, 40)
        default: fr = (24, 36, 42)
        }
        fatRange = (fr.0, fr.1, fr.2)

        // Gordura visceral (nível 1–30, estimado)
        var v = male ? (bodyFat - 12) / 1.2 + (A - 20) / 10 : (bodyFat - 22) / 1.4 + (A - 20) / 12
        if let w = i.waist {
            let byWaist = male ? (w - 72) / 2.8 : (w - 64) / 3
            v = (v + byWaist) / 2
        }
        visceral = min(max(v.rounded(), 1), 30)

        // Metabolismo
        mifflin = 10 * W + 6.25 * H - 5 * A + (male ? 5 : -161)
        katch = 370 + 21.6 * lbm
        harris = male ? 88.362 + 13.397 * W + 4.799 * H - 5.677 * A
                      : 447.593 + 9.247 * W + 3.098 * H - 4.330 * A
        cunningham = 500 + 22 * lbm
        // Idade metabólica: cada 1 ponto de gordura acima/abaixo do esperado para a idade
        // equivale a ~1,2 ano; massa magra acima da média (FFMI) também "rejuvenesce".
        // (Comparar Katch-McArdle com Mifflin dava viés de +10 a +15 anos em pessoas magras.)
        let refFat = (fatRange.low + fatRange.healthy) / 2
        let refFFMI = male ? 19.0 : 15.5
        let ffmiNow = lbm / (h * h)
        let rawAge = A + (bodyFat - refFat) * 1.2 - (ffmiNow - refFFMI) * 1.0
        metabolicAge = min(max(rawAge, max(12, A - 20)), A + 30).rounded()
        tdee = mifflin * i.activity
        target = max(mifflin, tdee + i.goal.calorieDelta)
        standard = 22 * h * h
    }

    // MARK: Lista completa (calculada uma vez e guardada)

    /// Guarda os resultados: cada análise calcula suas ~80 métricas só uma vez,
    /// em vez de recalcular tudo a cada consulta `análise[id]`.
    final class Cache {
        var metrics: [Metric]?
        var byID: [MetricID: Metric] = [:]
        var bodyScore: Double?
    }
    private let cache = Cache()

    var metrics: [Metric] {
        if let m = cache.metrics { return m }
        let m = computeMetrics()
        cache.metrics = m
        cache.byID = Dictionary(m.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        return m
    }

    private func computeMetrics() -> [Metric] {
        let W = input.kg, male = input.isMale, A = Double(input.age), h2 = h * h
        let fr = fatRange
        var out: [Metric] = []
        func add(_ m: Metric) { out.append(m) }

        // Composição
        add(Metric(id: .weight, value: W,
                   bands: bands((18.5 * h2, "Abaixo", .low), (25 * h2, "Saudável", .good),
                                (30 * h2, "Sobrepeso", .warn), (.infinity, "Obesidade", .bad)),
                   scale: (15 * h2)...(35 * h2)))
        add(Metric(id: .bmi, value: bmi,
                   bands: bands((18.5, "Abaixo do peso", .low), (25, "Saudável", .good),
                                (30, "Sobrepeso", .warn), (35, "Obesidade I", .bad),
                                (40, "Obesidade II", .bad), (.infinity, "Obesidade III", .bad)),
                   scale: 15...40))
        let fatBands = bands((fr.low, "Baixo", .low), (fr.healthy, "Saudável", .good),
                             (fr.high, "Alto", .warn), (.infinity, "Muito alto", .bad))
        var fatComps: [(String, Double)] = []
        let sx = male ? 1.0 : 0.0
        fatComps.append(("Deurenberg (IMC, idade, sexo)", 1.2 * bmi + 0.23 * A - 10.8 * sx - 5.4))
        do {
            let s0 = male ? 0.0 : 1.0, B = bmi
            let cun = -44.988 + 0.503 * A + 10.689 * s0 + 3.172 * B - 0.026 * B * B + 0.181 * B * s0
                - 0.02 * B * A - 0.005 * B * B * s0 + 0.00021 * B * B * A
            if !fatMethod.hasPrefix("CUN") { fatComps.append(("CUN-BAE", cun)) }
        }
        if let w = input.waist, !fatMethod.hasPrefix("RFM") { fatComps.append(("RFM (cintura)", (male ? 64 : 76) - 20 * (input.heightCm / w))) }
        add(Metric(id: .bodyFat, value: bodyFat, bands: fatBands, scale: 0...50, method: fatMethod,
                   comparisons: fatComps.map { ($0.0, min(max($0.1, 3), 65)) }))
        add(Metric(id: .fatMass, value: fatMass,
                   bands: bands((W * fr.low / 100, "Baixo", .low), (W * fr.healthy / 100, "Saudável", .good),
                                (W * fr.high / 100, "Alto", .warn), (.infinity, "Muito alto", .bad)),
                   scale: 0...(W * 0.5)))
        add(Metric(id: .subcutaneousFat, value: bodyFat * (male ? 0.85 : 0.90),
                   bands: bands((fr.low * 0.85, "Baixo", .low), (fr.healthy * 0.88, "Saudável", .good),
                                (fr.high * 0.88, "Alto", .warn), (.infinity, "Muito alto", .bad)),
                   scale: 0...45))
        add(Metric(id: .visceralFat, value: visceral,
                   bands: bands((10, "Saudável", .good), (15, "Alto", .warn), (.infinity, "Muito alto", .bad)),
                   scale: 1...30))
        let wl = male ? 50.0 : 45.0, wh = male ? 65.0 : 60.0
        add(Metric(id: .waterPercent, value: water / W * 100,
                   bands: bands((wl, "Baixo", .low), (wh, "Saudável", .good), (.infinity, "Ótimo", .excellent)),
                   scale: 30...75))
        add(Metric(id: .waterMass, value: water,
                   bands: bands((W * wl / 100, "Baixo", .low), (W * wh / 100, "Saudável", .good),
                                (.infinity, "Ótimo", .excellent)),
                   scale: (W * 0.3)...(W * 0.75), comparisons: [("Watson (1980)", watson)]))
        add(Metric(id: .proteinPercent, value: protein / W * 100,
                   bands: bands((16, "Baixo", .low), (20, "Normal", .good), (.infinity, "Ótimo", .excellent)),
                   scale: 8...25))
        add(Metric(id: .proteinMass, value: protein,
                   bands: bands((W * 0.16, "Baixo", .low), (W * 0.20, "Normal", .good), (.infinity, "Ótimo", .excellent)),
                   scale: (W * 0.08)...(W * 0.25)))
        let boer = male ? 0.407 * W + 0.267 * input.heightCm - 19.2 : 0.252 * W + 0.473 * input.heightCm - 48.3
        let james = male ? 1.1 * W - 128 * pow(W / input.heightCm, 2) * 100 * 100 / 10000
                         : 1.07 * W - 148 * pow(W / input.heightCm, 2) * 100 * 100 / 10000
        let hume = male ? 0.32810 * W + 0.33929 * input.heightCm - 29.5336
                        : 0.29569 * W + 0.41813 * input.heightCm - 43.2933
        add(Metric(id: .lbm, value: lbm, method: fatMethod,
                   comparisons: [("Boer", boer), ("James", james), ("Hume", hume)]))
        let obesity = (W - standard) / standard * 100
        add(Metric(id: .obesity, value: obesity,
                   bands: bands((-10, "Abaixo", .low), (10, "Normal", .good), (20, "Sobrepeso", .warn),
                                (.infinity, "Obesidade", .bad)),
                   scale: -30...50))

        // Músculo e osso
        let sl = male ? 33.0 : 24.0, sh = male ? 39.0 : 30.0
        add(Metric(id: .smmPercent, value: smm / W * 100,
                   bands: bands((sl, "Baixo", .low), (sh, "Normal", .good), (.infinity, "Excelente", .excellent)),
                   scale: (sl - 13)...(sh + 11)))
        add(Metric(id: .smm, value: smm,
                   bands: bands((W * sl / 100, "Baixo", .low), (W * sh / 100, "Normal", .good),
                                (.infinity, "Excelente", .excellent)),
                   scale: (W * (sl - 13) / 100)...(W * (sh + 11) / 100)))
        let ml = male ? 70.0 : 60.0, mh = male ? 80.0 : 70.0
        add(Metric(id: .musclePercent, value: muscle / W * 100,
                   bands: bands((ml, "Baixo", .low), (mh, "Normal", .good), (.infinity, "Excelente", .excellent)),
                   scale: 45...95))
        add(Metric(id: .muscleMass, value: muscle,
                   bands: bands((W * ml / 100, "Baixo", .low), (W * mh / 100, "Normal", .good),
                                (.infinity, "Excelente", .excellent)),
                   scale: (W * 0.45)...(W * 0.95)))
        let boneRef: Double = male ? (W < 60 ? 2.5 : (W < 75 ? 2.9 : 3.2)) : (W < 45 ? 1.8 : (W < 60 ? 2.2 : 2.5))
        add(Metric(id: .bone, value: bone,
                   bands: bands((boneRef - 0.3, "Baixo", .low), (boneRef + 0.4, "Normal", .good),
                                (.infinity, "Ótimo", .excellent)),
                   scale: 1...5, comparisons: [("Referência para seu peso", boneRef)]))
        let ffmi = lbm / h2
        let ffmiBands = male
            ? bands((18, "Abaixo da média", .low), (20, "Médio", .good), (22, "Bom", .good),
                    (25, "Excelente", .excellent), (.infinity, "Excepcional", .excellent))
            : bands((15, "Abaixo da média", .low), (17, "Médio", .good), (19, "Bom", .good),
                    (21, "Excelente", .excellent), (.infinity, "Excepcional", .excellent))
        add(Metric(id: .ffmi, value: ffmi, bands: ffmiBands, scale: male ? 14...28 : 11...24))
        add(Metric(id: .nffmi, value: ffmi + 6.1 * (1.8 - h), bands: ffmiBands, scale: male ? 14...28 : 11...24))
        let limit = male ? 25.0 : 21.0
        let maxLbm = (limit - 6.1 * (1.8 - h)) * h2
        add(Metric(id: .muscularPotential, value: lbm / maxLbm * 100,
                   bands: bands((75, "Espaço para crescer", .good), (90, "Avançado", .excellent),
                                (.infinity, "Perto do limite", .excellent)),
                   scale: 50...100, comparisons: [("Massa magra máxima estimada (kg)", maxLbm)]))

        // Metabolismo
        add(Metric(id: .bmr, value: mifflin, method: "Mifflin-St Jeor",
                   comparisons: [("Katch-McArdle", katch), ("Harris-Benedict revisada", harris),
                                 ("Cunningham", cunningham)]))
        add(Metric(id: .metabolicAge, value: metabolicAge,
                   bands: bands((A - 3, "Mais jovem que você", .excellent), (A + 3, "Compatível", .good),
                                (.infinity, "Mais velha que você", .warn)),
                   scale: max(12, A - 25)...(A + 25)))
        add(Metric(id: .tdee, value: tdee,
                   comparisons: [("Sedentário", mifflin * 1.2), ("Leve", mifflin * 1.375),
                                 ("Moderado", mifflin * 1.55), ("Ativo", mifflin * 1.725),
                                 ("Muito ativo", mifflin * 1.9)]))
        let maxDef = fatMass * 2.20462 * 31
        add(Metric(id: .maxDeficit, value: maxDef))
        add(Metric(id: .maxLossWeek, value: maxDef * 7 / 7700))

        // Índices
        add(Metric(id: .bodyScore, value: bodyScore,
                   bands: bands((60, "Precisa de atenção", .bad), (75, "Regular", .warn), (90, "Bom", .good),
                                (.infinity, "Excelente", .excellent)),
                   scale: 0...100))
        let fmi = fatMass / h2
        add(Metric(id: .fmi, value: fmi,
                   bands: male ? bands((3, "Baixo", .low), (6, "Saudável", .good), (9, "Excesso", .warn), (.infinity, "Obesidade", .bad))
                               : bands((5, "Baixo", .low), (9, "Saudável", .good), (13, "Excesso", .warn), (.infinity, "Obesidade", .bad)),
                   scale: 0...16))
        add(Metric(id: .bmiPrime, value: bmi / 25,
                   bands: bands((0.74, "Abaixo", .low), (1, "Saudável", .good), (1.2, "Sobrepeso", .warn), (.infinity, "Obesidade", .bad)),
                   scale: 0.6...1.6))
        add(Metric(id: .ponderal, value: W / (h2 * h),
                   bands: bands((11, "Baixo", .low), (15, "Normal", .good), (17, "Alto", .warn), (.infinity, "Muito alto", .bad)),
                   scale: 8...20))
        add(Metric(id: .bsa, value: sqrt(input.heightCm * W / 3600)))
        add(Metric(id: .height, value: input.heightCm))
        add(Metric(id: .age, value: A))

        // Formato (medidas)
        if let w = input.waist {
            add(Metric(id: .whtr, value: w / input.heightCm,
                       bands: bands((0.4, "Baixo", .low), (0.5, "Saudável", .good), (0.6, "Risco aumentado", .warn),
                                    (.infinity, "Risco alto", .bad)),
                       scale: 0.3...0.8))
            let wm = w / 100
            let briInner = max(0, 1 - pow(wm / (2 * .pi), 2) / pow(0.5 * h, 2))
            add(Metric(id: .bri, value: 364.2 - 365.5 * sqrt(briInner),
                       bands: bands((5, "Baixo risco", .good), (6.9, "Risco moderado", .warn), (.infinity, "Risco alto", .bad)),
                       scale: 1...12))
            add(Metric(id: .absi, value: wm / (pow(bmi, 2.0 / 3) * sqrt(h))))
            add(Metric(id: .conicity, value: wm / (0.109 * sqrt(W / h)),
                       bands: bands((male ? 1.25 : 1.18, "Adequado", .good), (.infinity, "Acúmulo abdominal", .warn)),
                       scale: 1.0...1.5))
            add(Metric(id: .rfm, value: (male ? 64 : 76) - 20 * (input.heightCm / w), bands: fatBands, scale: 0...50))
            if let hp = input.hip {
                add(Metric(id: .whr, value: w / hp,
                           bands: male ? bands((0.9, "Baixo risco", .good), (1.0, "Risco moderado", .warn), (.infinity, "Risco alto", .bad))
                                       : bands((0.8, "Baixo risco", .good), (0.85, "Risco moderado", .warn), (.infinity, "Risco alto", .bad)),
                           scale: 0.6...1.2))
            }
        }
        if let hp = input.hip {
            add(Metric(id: .bai, value: hp / pow(h, 1.5) - 18, bands: fatBands, scale: 0...50))
        }
        out.append(contentsOf: measurementMetrics)

        // Peso ideal
        let inches = input.heightCm / 2.54 - 60
        let devine = (male ? 50 : 45.5) + 2.3 * inches
        let robinson = (male ? 52 : 49) + (male ? 1.9 : 1.7) * inches
        let miller = (male ? 56.2 : 53.1) + (male ? 1.41 : 1.36) * inches
        let hamwi = (male ? 48 : 45.5) + (male ? 2.7 : 2.2) * inches
        add(Metric(id: .standardWeight, value: standard))
        add(Metric(id: .idealWeight, value: (devine + robinson + miller + hamwi) / 4,
                   comparisons: [("Devine", devine), ("Robinson", robinson), ("Miller", miller), ("Hamwi", hamwi)]))
        add(Metric(id: .healthyMin, value: 18.5 * h2))
        add(Metric(id: .healthyMax, value: 24.9 * h2))
        add(Metric(id: .weightControl, value: standard - W))
        let bfTarget = (fr.low + fr.healthy) / 2 / 100
        let targetW = lbm / (1 - bfTarget)
        add(Metric(id: .fatControl, value: targetW * bfTarget - fatMass))
        add(Metric(id: .muscleControl, value: max(0, W * sl / 100 - smm)))

        // Nutrição
        add(Metric(id: .targetCalories, value: target))
        let prot = bmi >= 27 ? 2.2 * lbm : 1.6 * W
        let fat = target * 0.25 / 9
        let carb = max(0, (target - prot * 4 - fat * 9) / 4)
        add(Metric(id: .proteinNeed, value: prot))
        add(Metric(id: .fatNeed, value: fat))
        add(Metric(id: .carbNeed, value: carb))
        add(Metric(id: .fiberNeed, value: target / 1000 * 14))
        add(Metric(id: .waterIntake, value: W * 0.035))

        // Músculo: sarcopenia e recomposição
        let smiV = smm / h2
        add(Metric(id: .smi, value: smiV,
                   bands: male ? bands((8.5, "Risco alto", .bad), (10.75, "Risco moderado", .warn), (.infinity, "Normal", .good))
                               : bands((5.75, "Risco alto", .bad), (6.75, "Risco moderado", .warn), (.infinity, "Normal", .good)),
                   scale: male ? 6...14 : 4...10))
        let asmV = max(0, 0.244 * W + 7.8 * h + 6.6 * sx - 0.098 * A - 3.3)
        add(Metric(id: .asm, value: asmV, method: "Lee et al. (2000)"))
        add(Metric(id: .asmi, value: asmV / h2,
                   bands: male ? bands((7.0, "Baixo", .bad), (8.5, "Normal", .good), (.infinity, "Ótimo", .excellent))
                               : bands((5.5, "Baixo", .bad), (6.8, "Normal", .good), (.infinity, "Ótimo", .excellent)),
                   scale: male ? 5...11 : 4...9))
        if fatMass > 0 {
            add(Metric(id: .muscleFatRatio, value: smm / fatMass,
                       bands: male ? bands((1.2, "Baixa", .warn), (2, "Boa", .good), (.infinity, "Excelente", .excellent))
                                   : bands((0.8, "Baixa", .warn), (1.3, "Boa", .good), (.infinity, "Excelente", .excellent)),
                       scale: 0...(male ? 4 : 3)))
        }

        // Saúde e risco
        if let w = input.waist {
            add(Metric(id: .waistRisk, value: w,
                       bands: male ? bands((94, "Baixo risco", .good), (102, "Risco aumentado", .warn), (.infinity, "Risco alto", .bad))
                                   : bands((80, "Baixo risco", .good), (88, "Risco aumentado", .warn), (.infinity, "Risco alto", .bad)),
                       scale: male ? 60...130 : 55...120))
        }
        var factors: [(String, Double)] = []
        if bmi >= 30 { factors.append(("IMC ≥ 30", bmi)) }
        if bodyFat > fr.high { factors.append(("Gordura acima da faixa", bodyFat)) }
        if visceral >= 10 { factors.append(("Gordura visceral ≥ 10", visceral)) }
        if let w = input.waist, w / input.heightCm >= 0.5 { factors.append(("Cintura/altura ≥ 0,5", w / input.heightCm)) }
        if let w = input.waist, let hp = input.hip, w / hp >= (male ? 0.9 : 0.85) { factors.append(("Cintura/quadril alta", w / hp)) }
        add(Metric(id: .cardioRisk, value: Double(factors.count),
                   bands: bands((1, "Nenhum fator", .excellent), (2, "1 fator", .warn), (.infinity, "2+ fatores", .bad)),
                   scale: 0...5, method: input.waist == nil ? "Sem medida de cintura: avaliados 3 de 5 critérios" : nil,
                   comparisons: factors))

        // Peso: ajustado (clínico) e com gordura ideal
        if W > devine * 1.2 { add(Metric(id: .adjustedWeight, value: devine + 0.4 * (W - devine), comparisons: [("Peso ideal (Devine)", devine)])) }
        add(Metric(id: .leanWeight, value: targetW, comparisons: [("Gordura alvo (%)", bfTarget * 100), ("Diferença para hoje (kg)", targetW - W)]))
        add(Metric(id: .proteinCut, value: lbm * 2.7, comparisons: [("Mínimo (2,3 g/kg magra)", lbm * 2.3), ("Máximo (3,1 g/kg magra)", lbm * 3.1)]))
        return out
    }

    subscript(_ id: MetricID) -> Metric? {
        if cache.metrics == nil { _ = metrics }
        return cache.byID[id]
    }

    /// Componentes da pontuação (0–100 cada) e seus pesos.
    var scoreParts: [(name: String, score: Double, weight: Double)] {
        let male = input.isMale
        // Gordura: 100 na faixa ótima (mais estreita que a saudável), cai 7 pts por ponto % fora dela.
        let optLo = male ? max(fatRange.low + 2, 10) : max(fatRange.low + 2, 20)
        let optHi = male ? min(fatRange.healthy - 4, 16) : min(fatRange.healthy - 5, 26)
        let fatDist = bodyFat < optLo ? optLo - bodyFat : max(0, bodyFat - optHi)
        let fat = max(0, 100 - fatDist * 7)
        // Músculo pelo FFMI normalizado: 15 (homens) / 13 (mulheres) = 0; 23 / 19 = 100.
        let nffmi = lbm / (h * h) + 6.1 * (1.8 - h)
        let (m0, m1) = male ? (15.0, 23.0) : (13.0, 19.0)
        let muscle = min(max((nffmi - m0) / (m1 - m0), 0), 1) * 100
        // IMC: 100 entre 20 e 24, −12 por ponto fora.
        let bmiS = max(0, 100 - (bmi < 20 ? (20 - bmi) : max(0, bmi - 24)) * 12)
        // Visceral: 100 até 5, −9 por nível acima.
        let visc = max(0, 100 - max(0, visceral - 5) * 9)
        var parts: [(String, Double, Double)] = [("Gordura corporal", fat, 0.30), ("Massa muscular (FFMI)", muscle, 0.30),
                                                 ("IMC", bmiS, 0.15), ("Gordura visceral", visc, 0.15)]
        if let w = input.waist {
            let r = w / input.heightCm
            parts.append(("Cintura / altura", max(0, 100 - max(0, r - 0.45) * 400), 0.10))
        } else {
            let age = max(0, 100 - max(0, metabolicAge - Double(input.age)) * 5)
            parts.append(("Idade metabólica", age, 0.10))
        }
        return parts.map { (name: $0.0, score: $0.1, weight: $0.2) }
    }

    /// Nota 0–100: média ponderada de gordura, músculo, IMC, visceral e cintura/idade metabólica.
    var bodyScore: Double {
        if let s = cache.bodyScore { return s }
        let s = computeBodyScore()
        cache.bodyScore = s
        return s
    }

    private func computeBodyScore() -> Double {
        let p = scoreParts
        let total = p.map { $0.score * $0.weight }.reduce(0, +) / p.map(\.weight).reduce(0, +)
        return min(max(total, 5), 100).rounded()
    }

    /// Tipo de corpo pela combinação gordura × músculo. O músculo usa o FFMI (massa magra
    /// relativa à altura), que não fica "inflado" em pessoas leves como o % de músculo.
    var bodyType: (name: String, detail: String) {
        let fatLevel = bodyFat < fatRange.low ? 0 : (bodyFat < fatRange.healthy ? 1 : 2)
        let ffmi = lbm / (h * h)
        let muscleLevel = ffmi < (input.isMale ? 18 : 15) ? 0 : (ffmi < (input.isMale ? 21 : 17.5) ? 1 : 2)
        let table = [
            ["Magro", "Magro com músculo", "Atlético magro"],
            ["Pouco músculo", "Equilibrado", "Musculoso"],
            ["Obesidade oculta", "Acima do peso", "Robusto / forte"],
        ]
        let details = [
            ["Pouca gordura e pouco músculo. Foque em ganhar massa com treino de força e superávit calórico.",
             "Pouca gordura e músculo normal. Ótimo para ganhar massa limpa.",
             "Pouca gordura e muito músculo: físico de atleta."],
            ["Gordura normal, músculo baixo. Treino de força trará a maior mudança.",
             "Gordura e músculo dentro do normal. Mantenha a rotina!",
             "Gordura normal e muito músculo. Excelente composição."],
            ["Gordura alta com pouco músculo (\"falso magro\"). Força + leve déficit é o caminho.",
             "Gordura acima do ideal. Déficit moderado e treino ajudam.",
             "Muito músculo, mas gordura alta. Um cutting gradual revela o físico."],
        ]
        return (table[fatLevel][muscleLevel], details[fatLevel][muscleLevel])
    }
}

// MARK: - Progresso para a meta

struct GoalProgress {
    let start: Double, current: Double, target: Double

    /// 0…1 (nil quando não há caminho a percorrer).
    var fraction: Double? {
        let total = target - start
        guard abs(total) > 0.0001 else { return nil }
        return min(max((current - start) / total, 0), 1)
    }
    var remaining: Double { target - current }
}
