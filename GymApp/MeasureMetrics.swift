import Foundation

/// Medidas de fita como métricas, com faixas de referência e explicações.
extension MetricID {
    var measurePart: BodyPart? {
        switch self {
        case .mWaist: .waist
        case .mAbdomen: .abdomen
        case .mHip: .hip
        case .mNeck: .neck
        case .mChest: .chest
        case .mShoulders: .shoulders
        case .mArmL: .armL
        case .mArmR: .armR
        case .mForearmL: .forearmL
        case .mForearmR: .forearmR
        case .mThighL: .thighL
        case .mThighR: .thighR
        case .mCalfL: .calfL
        case .mCalfR: .calfR
        case .mWrist: .wrist
        default: nil
        }
    }

    var measureMeta: (title: String, unit: String, icon: String) {
        if let p = measurePart { return (p.label, "cm", "ruler") }
        switch self {
        case .frameSize: return ("Tamanho da ossatura", "", "hand.raised.fill")
        case .shoulderWaist: return ("Ombro / cintura (Adônis)", "", "figure.arms.open")
        case .chestWaist: return ("Peito / cintura", "", "figure.arms.open")
        case .armSymmetry: return ("Simetria dos braços", "%", "arrow.left.and.right")
        case .thighSymmetry: return ("Simetria das coxas", "%", "arrow.left.and.right")
        case .calfSymmetry: return ("Simetria das panturrilhas", "%", "arrow.left.and.right")
        default: return ("", "", "ruler")
        }
    }

    var measureInfo: MetricInfo {
        let how = measurePart.map { "Fita métrica: \($0.howTo) Meça de manhã, em jejum, relaxado e sempre no mesmo ponto; a fita deve encostar na pele sem apertar." }
            ?? ""
        switch self {
        case .mWaist: return MetricInfo(
            what: "Circunferência da cintura: o melhor indicador simples de gordura abdominal e visceral, mais ligado a risco cardiovascular e diabetes do que o peso ou o IMC.",
            how: how,
            tip: "Referência da OMS (2008) e IDF para adultos: homens risco aumentado ≥ 94 cm e alto ≥ 102 cm; mulheres aumentado ≥ 80 cm e alto ≥ 88 cm. Mais importante que o número absoluto é mantê-la abaixo de metade da sua altura. Perder 5 cm de cintura costuma trazer melhora clara de pressão e glicemia.")
        case .mAbdomen: return MetricInfo(
            what: "Circunferência na altura do umbigo. Costuma ser alguns centímetros maior que a cintura e reflete gordura abdominal e distensão.",
            how: how,
            tip: "Varia bastante com refeição, gases e retenção de líquido. Compare sempre no mesmo horário. Usa as mesmas faixas de risco da cintura como referência aproximada.")
        case .mHip: return MetricInfo(
            what: "Circunferência do quadril no ponto mais largo dos glúteos. Reflete glúteos, ossatura pélvica e gordura subcutânea dos quadris.",
            how: how,
            tip: "Sozinho não indica risco: é usado na relação cintura/quadril (OMS) e no índice de adiposidade (BAI). Gordura no quadril é metabolicamente menos perigosa que a abdominal. Treino de glúteos aumenta essa medida com músculo.")
        case .mNeck: return MetricInfo(
            what: "Circunferência do pescoço. Usada no cálculo de gordura da Marinha dos EUA e associada a risco metabólico e apneia do sono.",
            how: how,
            tip: "Estudos (Ben-Noun, 2001; Preis, 2010) associam valores ≥ 37 cm (homens) e ≥ 34 cm (mulheres) a maior risco cardiometabólico; acima de 40–43 cm aumenta o risco de apneia. Em quem treina trapézio, pode ser maior por músculo.")
        case .mChest: return MetricInfo(
            what: "Circunferência do tórax na linha dos mamilos. Reflete peitoral, dorsais, caixa torácica e gordura.",
            how: how,
            tip: "Útil para acompanhar ganho de massa em peito e costas. Compare com a cintura: peito/cintura ≥ 1,3 indica tronco atlético.")
        case .mShoulders: return MetricInfo(
            what: "Circunferência dos ombros no ponto mais largo (deltoides).",
            how: how,
            tip: "Cresce com treino de ombros e costas. Combinada com a cintura forma o índice de Adônis (proporção estética do 'formato em V').")
        case .mArmL, .mArmR: return MetricInfo(
            what: "Circunferência do braço (bíceps + tríceps + gordura). Em saúde pública, a circunferência do braço (CB/MUAC) é usada para avaliar estado nutricional.",
            how: how,
            tip: "Referência nutricional (OMS/MUAC): abaixo de ~23 cm (homens) ou 22 cm (mulheres) sugere baixa reserva muscular. Para hipertrofia, ganhos de 0,5–1 cm por mês são bons em iniciantes. Meça sempre relaxado OU sempre contraído, nunca misture.")
        case .mForearmL, .mForearmR: return MetricInfo(
            what: "Circunferência do antebraço, no ponto mais largo abaixo do cotovelo.",
            how: how,
            tip: "Relacionada à força de pegada, que é um dos melhores preditores de saúde e longevidade em estudos populacionais. Cresce com remadas, puxadas, rosca martelo e exercícios de pegada.")
        case .mThighL, .mThighR: return MetricInfo(
            what: "Circunferência da coxa (quadríceps, posteriores, adutores e gordura).",
            how: how,
            tip: "Acompanha ganho de massa nas pernas. Coxas maiores (por músculo) estão associadas a menor risco cardiovascular em estudos de coorte. Diferenças grandes entre os lados podem indicar compensação ou lesão antiga.")
        case .mCalfL, .mCalfR: return MetricInfo(
            what: "Circunferência da panturrilha. A OMS e a ESPEN a usam como marcador simples de massa muscular, principalmente em idosos.",
            how: how,
            tip: "Abaixo de 31 cm indica baixa massa muscular (risco de sarcopenia). O consenso asiático (AWGS 2019) usa < 34 cm (homens) e < 33 cm (mulheres). Responde bem a treino de panturrilha em pé com amplitude completa.")
        case .mWrist: return MetricInfo(
            what: "Circunferência do punho. Quase não muda com peso ou treino, por isso indica o tamanho da sua ossatura.",
            how: how,
            tip: "Usado para estimar a estrutura óssea (pequena, média, grande) e as proporções clássicas do corpo. Pessoas com punho maior tendem a ter mais potencial de massa muscular.")
        case .frameSize: return MetricInfo(
            what: "Tamanho da estrutura óssea, calculado pela relação altura ÷ punho (Grant, 1980; tabelas Metropolitan Life).",
            how: "r = altura (cm) ÷ punho (cm). Homens: > 10,4 pequena, 9,6–10,4 média, < 9,6 grande. Mulheres: > 11 pequena, 10,1–11 média, < 10,1 grande.",
            tip: "Explica por que duas pessoas da mesma altura podem ter pesos saudáveis diferentes: ossatura grande permite peso um pouco maior dentro da faixa saudável.")
        case .shoulderWaist: return MetricInfo(
            what: "Relação entre ombros e cintura, conhecida como índice de Adônis. Mede o 'formato em V' do tronco.",
            how: "Ombros (cm) ÷ cintura (cm).",
            tip: "É uma referência estética, não de saúde. A proporção áurea (1,618) é considerada o ideal clássico. Melhora aumentando ombros/costas (elevação lateral, puxadas) e reduzindo a cintura.")
        case .chestWaist: return MetricInfo(
            what: "Relação entre peito e cintura.",
            how: "Peito (cm) ÷ cintura (cm).",
            tip: "Valores ≥ 1,3 indicam tronco atlético. Sobe com ganho de músculo no peito e nas costas e com perda de gordura abdominal.")
        case .armSymmetry, .thighSymmetry, .calfSymmetry: return MetricInfo(
            what: "Diferença percentual entre o lado esquerdo e o direito.",
            how: "|esquerdo − direito| ÷ maior lado × 100.",
            tip: "Até 3% é normal (o lado dominante costuma ser maior). Acima de 6% vale incluir exercícios unilaterais (halteres, búlgaro, rosca alternada) começando pelo lado mais fraco e igualando as repetições.")
        default: return MetricInfo(what: "", how: "", tip: "")
        }
    }
}

extension BodyAnalysis {
    /// Medidas e índices derivados das medidas.
    var measurementMetrics: [Metric] {
        let p = input.parts
        let male = input.isMale
        var out: [Metric] = []
        func band(_ items: (Double, String, Tone)...) -> [Band] { items.map { Band(upTo: $0.0, label: $0.1, tone: $0.2) } }

        let waistBands = male
            ? band((94, "Baixo risco", .good), (102, "Risco aumentado", .warn), (.infinity, "Risco alto", .bad))
            : band((80, "Baixo risco", .good), (88, "Risco aumentado", .warn), (.infinity, "Risco alto", .bad))
        if let v = p[.waist] { out.append(Metric(id: .mWaist, value: v, bands: waistBands, scale: male ? 60...130 : 55...120)) }
        if let v = p[.abdomen] { out.append(Metric(id: .mAbdomen, value: v, bands: waistBands, scale: male ? 60...135 : 55...125)) }
        if let v = p[.hip] { out.append(Metric(id: .mHip, value: v)) }
        if let v = p[.neck] {
            out.append(Metric(id: .mNeck, value: v,
                              bands: male ? band((37, "Adequado", .good), (40, "Aumentado", .warn), (.infinity, "Alto", .bad))
                                          : band((34, "Adequado", .good), (37, "Aumentado", .warn), (.infinity, "Alto", .bad)),
                              scale: male ? 30...48 : 26...44))
        }
        if let v = p[.chest] { out.append(Metric(id: .mChest, value: v)) }
        if let v = p[.shoulders] { out.append(Metric(id: .mShoulders, value: v)) }
        let armBands = male ? band((23, "Baixa reserva", .low), (32, "Adequado", .good), (38, "Desenvolvido", .excellent), (.infinity, "Muito desenvolvido", .excellent))
                            : band((22, "Baixa reserva", .low), (30, "Adequado", .good), (34, "Desenvolvido", .excellent), (.infinity, "Muito desenvolvido", .excellent))
        if let v = p[.armL] { out.append(Metric(id: .mArmL, value: v, bands: armBands, scale: 18...48)) }
        if let v = p[.armR] { out.append(Metric(id: .mArmR, value: v, bands: armBands, scale: 18...48)) }
        if let v = p[.forearmL] { out.append(Metric(id: .mForearmL, value: v)) }
        if let v = p[.forearmR] { out.append(Metric(id: .mForearmR, value: v)) }
        if let v = p[.thighL] { out.append(Metric(id: .mThighL, value: v)) }
        if let v = p[.thighR] { out.append(Metric(id: .mThighR, value: v)) }
        let calfBands = band((31, "Baixa massa muscular", .low), (male ? 34 : 33, "Limítrofe", .warn), (.infinity, "Adequada", .good))
        if let v = p[.calfL] { out.append(Metric(id: .mCalfL, value: v, bands: calfBands, scale: 25...48)) }
        if let v = p[.calfR] { out.append(Metric(id: .mCalfR, value: v, bands: calfBands, scale: 25...48)) }
        if let v = p[.wrist] {
            out.append(Metric(id: .mWrist, value: v))
            let r = input.heightCm / v
            out.append(Metric(id: .frameSize, value: r,
                              bands: male ? band((9.6, "Ossatura grande", .excellent), (10.4, "Ossatura média", .good), (.infinity, "Ossatura pequena", .low))
                                          : band((10.1, "Ossatura grande", .excellent), (11, "Ossatura média", .good), (.infinity, "Ossatura pequena", .low)),
                              scale: 8...13))
        }
        if let s = p[.shoulders], let w = p[.waist] {
            out.append(Metric(id: .shoulderWaist, value: s / w,
                              bands: band((1.3, "Retilíneo", .low), (1.45, "Equilibrado", .good), (1.618, "Formato em V", .excellent),
                                          (.infinity, "Proporção áurea", .excellent)),
                              scale: 1.1...1.8, comparisons: [("Ideal clássico (proporção áurea)", 1.618)]))
        }
        if let c = p[.chest], let w = p[.waist] {
            out.append(Metric(id: .chestWaist, value: c / w,
                              bands: band((1.15, "Abaixo", .low), (1.3, "Normal", .good), (.infinity, "Atlético", .excellent)),
                              scale: 0.9...1.6))
        }
        func sym(_ id: MetricID, _ a: BodyPart, _ b: BodyPart) {
            guard let l = p[a], let r = p[b], max(l, r) > 0 else { return }
            out.append(Metric(id: id, value: abs(l - r) / max(l, r) * 100,
                              bands: band((3, "Equilibrado", .good), (6, "Leve diferença", .warn), (.infinity, "Assimetria", .bad)),
                              scale: 0...12, comparisons: [("Esquerdo (cm)", l), ("Direito (cm)", r)]))
        }
        sym(.armSymmetry, .armL, .armR)
        sym(.thighSymmetry, .thighL, .thighR)
        sym(.calfSymmetry, .calfL, .calfR)
        return out
    }
}
