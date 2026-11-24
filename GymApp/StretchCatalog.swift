import Foundation

// MARK: - Condições que o usuário pode marcar

enum ConditionGroup: String, CaseIterable, Identifiable {
    case posture = "Postura", pain = "Dores e tensões", mobility = "Mobilidade", lifestyle = "Rotina", goals = "Objetivos"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .posture: "figure.stand"
        case .pain: "bandage.fill"
        case .mobility: "figure.flexibility"
        case .lifestyle: "desktopcomputer"
        case .goals: "target"
        }
    }
}

enum BodyCondition: String, CaseIterable, Identifiable, Codable {
    // postura
    case protractedShoulders, forwardHead, kyphosis, hyperlordosis, anteriorPelvicTilt, posteriorPelvicTilt, flatBack,
         scoliosis, unevenShoulders, wingedScapula, kneeValgus, kneeVarus, flatFeet, hyperextendedKnees, duckFeet
    // dores
    case lowBackPain, neckTension, tensionHeadache, sciatica, kneePain, plantarFasciitis, shoulderImpingement,
         wristPain, elbowPain, jawTension, hipPain
    // mobilidade
    case tightHamstrings, tightHipFlexors, tightCalves, tightHips, poorOverhead, tightChest, tightThoracic,
         tightITBand, tightAdductors, tightQuads, tightLats
    // rotina
    case deskWork, phoneUse, runner, standingJob, driving, poorSleep, stress, lifter
    // objetivos
    case touchToes, deepSquat, splits, frontSplits, bridge

    var id: String { rawValue }

    var group: ConditionGroup {
        switch self {
        case .protractedShoulders, .forwardHead, .kyphosis, .hyperlordosis, .anteriorPelvicTilt, .posteriorPelvicTilt, .flatBack,
             .scoliosis, .unevenShoulders, .wingedScapula, .kneeValgus, .kneeVarus, .flatFeet, .hyperextendedKnees, .duckFeet: .posture
        case .lowBackPain, .neckTension, .tensionHeadache, .sciatica, .kneePain, .plantarFasciitis, .shoulderImpingement,
             .wristPain, .elbowPain, .jawTension, .hipPain: .pain
        case .tightHamstrings, .tightHipFlexors, .tightCalves, .tightHips, .poorOverhead, .tightChest, .tightThoracic,
             .tightITBand, .tightAdductors, .tightQuads, .tightLats: .mobility
        case .deskWork, .phoneUse, .runner, .standingJob, .driving, .poorSleep, .stress, .lifter: .lifestyle
        case .touchToes, .deepSquat, .splits, .frontSplits, .bridge: .goals
        }
    }

    var title: String {
        switch self {
        case .protractedShoulders: "Ombros protusos (para frente)"
        case .forwardHead: "Cabeça projetada à frente"
        case .kyphosis: "Cifose (costas curvadas)"
        case .hyperlordosis: "Hiperlordose lombar"
        case .anteriorPelvicTilt: "Anteversão pélvica (bumbum empinado)"
        case .posteriorPelvicTilt: "Retroversão pélvica (bumbum encaixado)"
        case .flatBack: "Retificação da coluna"
        case .scoliosis: "Escoliose"
        case .unevenShoulders: "Ombros desnivelados"
        case .wingedScapula: "Escápula alada"
        case .kneeValgus: "Joelhos para dentro (valgo)"
        case .kneeVarus: "Joelhos para fora (varo)"
        case .flatFeet: "Pé chato / pisada pronada"
        case .hyperextendedKnees: "Joelhos hiperestendidos"
        case .duckFeet: "Pés de pato (pontas para fora)"
        case .lowBackPain: "Dor lombar"
        case .neckTension: "Tensão no pescoço e trapézio"
        case .tensionHeadache: "Dor de cabeça tensional"
        case .sciatica: "Dor no ciático / piriforme"
        case .kneePain: "Dor no joelho (patelar)"
        case .plantarFasciitis: "Fascite plantar / dor na sola"
        case .shoulderImpingement: "Dor ou impacto no ombro"
        case .wristPain: "Dor nos punhos"
        case .elbowPain: "Cotovelo de tenista/golfista"
        case .jawTension: "Tensão na mandíbula (bruxismo)"
        case .hipPain: "Dor ou travamento no quadril"
        case .tightHamstrings: "Posterior da coxa encurtado"
        case .tightHipFlexors: "Flexores do quadril encurtados"
        case .tightCalves: "Panturrilha / tornozelo travado"
        case .tightHips: "Quadril travado (rotação)"
        case .poorOverhead: "Pouca mobilidade acima da cabeça"
        case .tightChest: "Peitoral encurtado"
        case .tightThoracic: "Torácica rígida (meio das costas)"
        case .tightITBand: "Lateral da coxa tensa (banda iliotibial)"
        case .tightAdductors: "Adutores (parte interna) encurtados"
        case .tightQuads: "Quadríceps encurtado"
        case .tightLats: "Dorsais encurtados"
        case .deskWork: "Trabalho sentado muitas horas"
        case .phoneUse: "Uso muito o celular"
        case .runner: "Corro com frequência"
        case .standingJob: "Fico muito tempo em pé"
        case .driving: "Dirijo muito"
        case .poorSleep: "Dificuldade para relaxar ou dormir"
        case .stress: "Estresse / ansiedade"
        case .lifter: "Treino musculação pesada"
        case .touchToes: "Encostar as mãos no chão"
        case .deepSquat: "Agachamento profundo"
        case .splits: "Abertura lateral (espacate)"
        case .frontSplits: "Abertura frontal"
        case .bridge: "Ponte / costas mais flexíveis"
        }
    }

    var detail: String {
        switch self {
        case .protractedShoulders: "Ombros arredondados para frente, geralmente por peitoral encurtado e costas superiores fracas."
        case .forwardHead: "A orelha fica à frente do ombro quando você está de lado. Comum com celular e computador."
        case .kyphosis: "Curvatura aumentada no meio das costas (\"corcunda\")."
        case .hyperlordosis: "Curva lombar acentuada; costuma vir com abdômen e glúteos fracos."
        case .anteriorPelvicTilt: "Pelve inclinada para frente: flexores do quadril tensos e glúteos/abdômen fracos."
        case .posteriorPelvicTilt: "Pelve encaixada para trás, lombar reta; posteriores da coxa tensos."
        case .flatBack: "Perda das curvas naturais da coluna."
        case .scoliosis: "Curva lateral da coluna. Alongamentos ajudam no conforto e na simetria, mas não corrigem a curva: siga a orientação de um fisioterapeuta."
        case .unevenShoulders: "Um ombro mais alto que o outro."
        case .wingedScapula: "A escápula \"descola\" das costelas; serrátil anterior fraco."
        case .kneeValgus: "Joelhos caem para dentro ao agachar ou pular; glúteo médio fraco."
        case .kneeVarus: "Joelhos afastados com os pés juntos."
        case .flatFeet: "Arco do pé baixo, tornozelo cai para dentro."
        case .hyperextendedKnees: "Joelhos \"travam\" para trás quando em pé."
        case .duckFeet: "Pontas dos pés viradas para fora ao andar."
        case .lowBackPain: "Dor ou rigidez na lombar sem lesão grave."
        case .neckTension: "Pescoço e trapézio duros, sensação de peso nos ombros."
        case .tensionHeadache: "Dor de cabeça em faixa, ligada à tensão do pescoço."
        case .sciatica: "Dor que desce pelo glúteo e pela perna."
        case .kneePain: "Dor na frente do joelho ao subir escadas ou agachar."
        case .plantarFasciitis: "Dor na sola/calcanhar, pior nos primeiros passos do dia."
        case .shoulderImpingement: "Dor ao levantar o braço acima da cabeça."
        case .wristPain: "Punhos doloridos ou rígidos (digitação, flexões)."
        case .elbowPain: "Dor na parte de fora ou de dentro do cotovelo."
        case .jawTension: "Ranger ou apertar os dentes, dor na mandíbula."
        case .hipPain: "Desconforto na articulação do quadril ou na virilha."
        case .tightHamstrings: "Dificuldade de esticar as pernas com o tronco inclinado."
        case .tightHipFlexors: "Frente do quadril tensa de tanto ficar sentado."
        case .tightCalves: "Calcanhar sai do chão ao agachar."
        case .tightHips: "Dificuldade para sentar de pernas cruzadas ou girar o quadril."
        case .poorOverhead: "Não consegue levantar os braços retos acima da cabeça sem arquear as costas."
        case .tightChest: "Peito tenso, ombros puxados para frente."
        case .tightThoracic: "Pouco giro e extensão no meio das costas."
        case .tightITBand: "Tensão na lateral da coxa, comum em corredores."
        case .tightAdductors: "Parte interna da coxa limita abrir as pernas."
        case .tightQuads: "Frente da coxa tensa; difícil levar o calcanhar ao glúteo."
        case .tightLats: "Costas laterais limitam levantar os braços."
        case .deskWork: "Muitas horas sentado no computador."
        case .phoneUse: "Cabeça baixa no celular por longos períodos."
        case .runner: "Corrida frequente pede quadril, panturrilha e posterior soltos."
        case .standingJob: "Pernas e lombar cansadas de ficar em pé."
        case .driving: "Muito tempo dirigindo (quadril e lombar)."
        case .poorSleep: "Alongamentos leves e respiração ajudam a desligar."
        case .stress: "Tensão acumulada no corpo."
        case .lifter: "Musculação pesada pede mobilidade de quadril, ombros e tornozelos."
        case .touchToes: "Meta: flexibilidade de posterior e lombar."
        case .deepSquat: "Meta: tornozelo, quadril e adutores para descer bem."
        case .splits: "Meta: adutores e quadril para a abertura lateral."
        case .frontSplits: "Meta: posterior e flexores para a abertura frontal."
        case .bridge: "Meta: extensão de coluna e ombros."
        }
    }
}

// MARK: - Alongamentos

enum StretchArea: String, CaseIterable, Identifiable, Codable {
    case neck = "Pescoço", shoulders = "Ombros", chest = "Peitoral", upperBack = "Costas superiores", lowerBack = "Lombar",
         core = "Abdômen", hips = "Quadril", glutes = "Glúteos", hamstrings = "Posterior da coxa", quads = "Quadríceps",
         adductors = "Adutores", calves = "Panturrilhas", feet = "Pés", arms = "Braços", wrists = "Punhos", fullBody = "Corpo todo"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .neck: "person.bust"
        case .shoulders, .arms: "figure.arms.open"
        case .chest: "figure.strengthtraining.traditional"
        case .upperBack, .lowerBack: "figure.flexibility"
        case .core: "figure.core.training"
        case .hips, .glutes: "figure.cooldown"
        case .hamstrings, .quads, .adductors: "figure.step.training"
        case .calves, .feet: "shoeprints.fill"
        case .wrists: "hand.raised.fill"
        case .fullBody: "figure.mind.and.body"
        }
    }
}

enum StretchKind: String, Codable {
    case mobility, stretch, activation, release
    var label: String {
        switch self {
        case .mobility: "Mobilidade (dinâmico)"
        case .stretch: "Alongamento (estático)"
        case .activation: "Fortalecimento corretivo"
        case .release: "Relaxamento"
        }
    }
    var order: Int { switch self { case .mobility: 0; case .stretch: 1; case .activation: 2; case .release: 3 } }
}

struct Stretch: Identifiable, Hashable {
    let id: String
    let name: String
    let areas: [StretchArea]
    let kind: StretchKind
    let seconds: Int
    let perSide: Bool
    let steps: [String]
    let tip: String
    let helps: [BodyCondition]
    var level = 1   // 1 fácil, 2 médio, 3 avançado

    /// Tempo total (lados somados).
    var totalSeconds: Int { seconds * (perSide ? 2 : 1) }
}

enum StretchCatalog {
    private typealias C = BodyCondition

    // swiftlint:disable line_length
    static let all: [Stretch] = [
        // Pescoço
        Stretch(id: "chin-tuck", name: "Retração do queixo (chin tuck)", areas: [.neck], kind: .activation, seconds: 40, perSide: false,
                steps: ["Sentado ou em pé, olhe para frente.", "Leve o queixo para trás como se fizesse um \"queixo duplo\", sem baixar a cabeça.", "Segure 3 s e solte; repita durante o tempo."],
                tip: "Imagine um fio puxando o topo da cabeça para cima.", helps: [.forwardHead, .neckTension, .tensionHeadache, .phoneUse, .deskWork, .kyphosis]),
        Stretch(id: "upper-trap", name: "Alongamento do trapézio superior", areas: [.neck], kind: .stretch, seconds: 30, perSide: true,
                steps: ["Sente-se e segure a lateral do banco com a mão direita.", "Incline a orelha esquerda em direção ao ombro esquerdo.", "Com a mão esquerda, puxe a cabeça suavemente."],
                tip: "Mantenha o ombro do lado alongado baixo.", helps: [.neckTension, .tensionHeadache, .unevenShoulders, .stress, .deskWork, .driving]),
        Stretch(id: "levator", name: "Alongamento do levantador da escápula", areas: [.neck], kind: .stretch, seconds: 30, perSide: true,
                steps: ["Gire a cabeça 45° para a esquerda.", "Olhe para o bolso da calça (nariz para a axila).", "Com a mão esquerda na nuca, puxe levemente para baixo."],
                tip: "A tensão deve aparecer atrás e ao lado do pescoço.", helps: [.neckTension, .tensionHeadache, .forwardHead, .phoneUse]),
        Stretch(id: "neck-circles", name: "Rotações lentas de pescoço", areas: [.neck], kind: .mobility, seconds: 40, perSide: false,
                steps: ["Deixe o queixo cair no peito.", "Role a cabeça devagar até um ombro e volte ao centro.", "Alterne os lados, sem levar a cabeça para trás com força."],
                tip: "Movimento lento, sem dor.", helps: [.neckTension, .stress, .deskWork]),
        Stretch(id: "scm", name: "Alongamento do esternocleidomastoideo", areas: [.neck], kind: .stretch, seconds: 25, perSide: true,
                steps: ["Mãos cruzadas sobre a clavícula, segurando a pele para baixo.", "Incline a cabeça para o lado oposto e olhe levemente para cima.", "Respire devagar."],
                tip: "Sente a frente/lateral do pescoço.", helps: [.forwardHead, .neckTension, .tensionHeadache]),
        Stretch(id: "jaw-release", name: "Relaxamento da mandíbula", areas: [.neck], kind: .release, seconds: 60, perSide: false,
                steps: ["Coloque a ponta da língua atrás dos dentes de cima.", "Abra a boca devagar mantendo a língua lá; feche.", "Massageie com os dedos os músculos na frente da orelha."],
                tip: "Dentes não devem se encostar em repouso.", helps: [.jawTension, .tensionHeadache, .stress]),

        // Ombros e peitoral
        Stretch(id: "doorway-pec", name: "Peitoral no batente da porta", areas: [.chest, .shoulders], kind: .stretch, seconds: 30, perSide: true,
                steps: ["Apoie o antebraço no batente, cotovelo na altura do ombro.", "Dê um passo à frente com a perna do mesmo lado.", "Gire o tronco levemente para fora até sentir o peito."],
                tip: "Não deixe o ombro subir para a orelha.", helps: [.protractedShoulders, .tightChest, .kyphosis, .deskWork, .shoulderImpingement, .lifter]),
        Stretch(id: "wall-angel", name: "Anjo na parede (wall angel)", areas: [.shoulders, .upperBack], kind: .activation, seconds: 45, perSide: false,
                steps: ["Costas, glúteos e cabeça encostados na parede.", "Braços em \"W\" encostados na parede.", "Deslize até um \"Y\" e volte, sem perder o contato."],
                tip: "Se a lombar descolar, dobre um pouco os joelhos.", helps: [.protractedShoulders, .kyphosis, .poorOverhead, .forwardHead, .wingedScapula, .deskWork]),
        Stretch(id: "band-pull", name: "Abertura com elástico", areas: [.upperBack, .shoulders], kind: .activation, seconds: 40, perSide: false,
                steps: ["Segure um elástico à frente, braços esticados na altura do peito.", "Abra os braços aproximando as escápulas.", "Volte devagar. Sem elástico, faça com toalha esticada."],
                tip: "Ombros longe das orelhas.", helps: [.protractedShoulders, .kyphosis, .unevenShoulders, .shoulderImpingement]),
        Stretch(id: "prone-ytw", name: "Y-T-W deitado de bruços", areas: [.upperBack, .shoulders], kind: .activation, seconds: 60, perSide: false,
                steps: ["Deite de bruços, testa apoiada numa toalha.", "Levante os braços formando Y, depois T, depois W, polegares para cima.", "Segure 2 s em cada letra."],
                tip: "Quem trabalha são as costas, não a lombar.", helps: [.protractedShoulders, .kyphosis, .wingedScapula, .forwardHead, .scoliosis]),
        Stretch(id: "cross-body", name: "Ombro posterior (braço cruzado)", areas: [.shoulders], kind: .stretch, seconds: 30, perSide: true,
                steps: ["Leve o braço esticado na frente do peito.", "Com o outro braço, puxe pelo cotovelo.", "Mantenha o ombro baixo."],
                tip: "Gire levemente o tronco para o lado oposto para intensificar.", helps: [.shoulderImpingement, .lifter, .poorOverhead]),
        Stretch(id: "sleeper", name: "Sleeper stretch (rotação interna)", areas: [.shoulders], kind: .stretch, seconds: 30, perSide: true, steps: ["Deite de lado sobre o ombro a alongar, braço a 90° à frente.", "Cotovelo dobrado a 90°, dedos para o teto.", "Com a outra mão, empurre o antebraço em direção ao chão devagar."],
                tip: "Pare antes de qualquer dor na frente do ombro.", helps: [.shoulderImpingement, .lifter], level: 2),
        Stretch(id: "lat-stretch", name: "Dorsal no banco (ajoelhado)", areas: [.upperBack, .shoulders], kind: .stretch, seconds: 35, perSide: false,
                steps: ["Ajoelhe diante de um banco/cadeira.", "Apoie os cotovelos no banco, mãos juntas atrás da cabeça.", "Leve o quadril para trás e afunde o peito."],
                tip: "Mantenha o abdômen firme para não arquear a lombar.", helps: [.poorOverhead, .tightLats, .kyphosis, .lifter, .bridge]),
        Stretch(id: "child-side", name: "Postura da criança com inclinação", areas: [.upperBack, .lowerBack], kind: .stretch, seconds: 30, perSide: true,
                steps: ["Sente nos calcanhares e leve os braços à frente no chão.", "Caminhe as mãos para um lado.", "Respire na lateral do tronco."],
                tip: "Ótimo para a lateral das costas e dorsais.", helps: [.tightLats, .scoliosis, .lowBackPain, .poorOverhead, .stress]),
        Stretch(id: "arm-circles", name: "Círculos de braço", areas: [.shoulders], kind: .mobility, seconds: 40, perSide: false,
                steps: ["Braços abertos na altura dos ombros.", "Faça círculos pequenos que vão aumentando.", "Inverta o sentido na metade do tempo."],
                tip: "Bom aquecimento antes de treino de peito e ombro.", helps: [.lifter, .poorOverhead, .deskWork]),
        Stretch(id: "shoulder-dislocate", name: "Passagem de bastão (dislocate)", areas: [.shoulders, .chest], kind: .mobility, seconds: 45, perSide: false,
                steps: ["Segure um cabo de vassoura ou toalha com pegada bem aberta.", "Leve os braços esticados da frente do quadril até atrás das costas.", "Volte devagar; feche a pegada aos poucos com o tempo."],
                tip: "Nunca force: abra mais a pegada se travar.", helps: [.poorOverhead, .tightChest, .protractedShoulders, .lifter], level: 2),
        Stretch(id: "scap-pushup", name: "Flexão escapular", areas: [.shoulders, .upperBack], kind: .activation, seconds: 40, perSide: false,
                steps: ["Na posição de prancha alta, braços esticados.", "Sem dobrar os cotovelos, aproxime e afaste as escápulas.", "Empurre o chão no final."],
                tip: "Fortalece o serrátil: chave para escápula alada.", helps: [.wingedScapula, .shoulderImpingement, .protractedShoulders]),
        Stretch(id: "wall-slide", name: "Deslizamento na parede (serrátil)", areas: [.shoulders], kind: .activation, seconds: 40, perSide: false,
                steps: ["De frente para a parede, antebraços apoiados nela.", "Deslize os braços para cima afastando-os da cabeça.", "Desça devagar mantendo a pressão."],
                tip: "Imagine abraçar a parede.", helps: [.wingedScapula, .poorOverhead, .shoulderImpingement]),

        // Costas e coluna
        Stretch(id: "cat-cow", name: "Gato-vaca", areas: [.upperBack, .lowerBack], kind: .mobility, seconds: 45, perSide: false,
                steps: ["Em quatro apoios, mãos sob os ombros e joelhos sob o quadril.", "Inspire afundando a barriga e olhando à frente.", "Expire arredondando as costas, queixo no peito."],
                tip: "Mova vértebra por vértebra.", helps: [.lowBackPain, .kyphosis, .flatBack, .scoliosis, .deskWork, .stress, .anteriorPelvicTilt]),
        Stretch(id: "thread-needle", name: "Agulha (thread the needle)", areas: [.upperBack], kind: .mobility, seconds: 30, perSide: true,
                steps: ["Em quatro apoios, passe um braço por baixo do corpo.", "Apoie o ombro e a lateral da cabeça no chão.", "Volte abrindo o braço para o teto."],
                tip: "Gire pelo meio das costas, não pela lombar.", helps: [.tightThoracic, .kyphosis, .neckTension, .scoliosis, .deskWork]),
        Stretch(id: "open-book", name: "Livro aberto (rotação torácica)", areas: [.upperBack, .chest], kind: .mobility, seconds: 35, perSide: true,
                steps: ["Deite de lado, joelhos dobrados a 90°, braços esticados à frente.", "Abra o braço de cima para o outro lado, seguindo com o olhar.", "Mantenha os joelhos juntos no chão."],
                tip: "Expire ao abrir.", helps: [.tightThoracic, .kyphosis, .tightChest, .scoliosis, .lowBackPain]),
        Stretch(id: "foam-thoracic", name: "Extensão torácica no rolo ou toalha", areas: [.upperBack], kind: .mobility, seconds: 60, perSide: false,
                steps: ["Deite com um rolo (ou toalha enrolada) no meio das costas.", "Mãos atrás da cabeça, glúteos no chão.", "Estenda as costas sobre o rolo e volte; mude a altura do rolo."],
                tip: "Não role sobre a lombar.", helps: [.kyphosis, .tightThoracic, .protractedShoulders, .forwardHead, .deskWork, .flatBack]),
        Stretch(id: "child-pose", name: "Postura da criança", areas: [.lowerBack, .upperBack], kind: .release, seconds: 60, perSide: false,
                steps: ["Ajoelhado, sente nos calcanhares.", "Leve o tronco à frente com os braços estendidos.", "Respire fundo pela barriga."],
                tip: "Afaste os joelhos se o quadril incomodar.", helps: [.lowBackPain, .stress, .poorSleep, .hyperlordosis, .standingJob]),
        Stretch(id: "knees-chest", name: "Joelhos ao peito", areas: [.lowerBack, .glutes], kind: .release, seconds: 45, perSide: false,
                steps: ["Deitado de costas, abrace os dois joelhos.", "Puxe-os em direção ao peito.", "Balance levemente de um lado para o outro."],
                tip: "Massageia a lombar.", helps: [.lowBackPain, .hyperlordosis, .anteriorPelvicTilt, .poorSleep, .standingJob]),
        Stretch(id: "supine-twist", name: "Torção deitado", areas: [.lowerBack, .glutes], kind: .stretch, seconds: 35, perSide: true,
                steps: ["Deitado, braços abertos em T.", "Leve um joelho dobrado para o lado oposto.", "Mantenha os ombros no chão e olhe para o outro lado."],
                tip: "Respire fundo e deixe a gravidade trabalhar.", helps: [.lowBackPain, .scoliosis, .poorSleep, .stress, .driving, .tightThoracic]),
        Stretch(id: "sphinx", name: "Esfinge", areas: [.lowerBack, .core], kind: .stretch, seconds: 40, perSide: false,
                steps: ["De bruços, apoie os antebraços no chão.", "Levante o peito, quadril no chão.", "Relaxe os glúteos e respire."],
                tip: "Se doer a lombar, desça um pouco.", helps: [.flatBack, .posteriorPelvicTilt, .bridge, .deskWork]),
        Stretch(id: "cobra", name: "Cobra", areas: [.lowerBack, .core], kind: .stretch, seconds: 30, perSide: false,
                steps: ["De bruços, mãos ao lado do peito.", "Empurre o chão estendendo os braços aos poucos.", "Ombros longe das orelhas."],
                tip: "Evite se a extensão piora a dor.", helps: [.flatBack, .posteriorPelvicTilt, .bridge], level: 2),
        Stretch(id: "side-bend", name: "Inclinação lateral em pé", areas: [.core, .lowerBack], kind: .stretch, seconds: 25, perSide: true,
                steps: ["Em pé, braço levantado acima da cabeça.", "Incline o tronco para o lado oposto.", "Não gire o tronco; empurre o quadril para o lado contrário."],
                tip: "Na escoliose, foque no lado mais encurtado conforme orientação profissional.", helps: [.scoliosis, .unevenShoulders, .tightLats, .standingJob, .tightITBand]),
        Stretch(id: "bird-dog", name: "Perdigueiro (bird dog)", areas: [.core, .lowerBack, .glutes], kind: .activation, seconds: 45, perSide: true,
                steps: ["Em quatro apoios, abdômen firme.", "Estenda o braço e a perna opostos até ficarem alinhados.", "Segure 3 s e volte sem perder o equilíbrio."],
                tip: "Imagine um copo d'água nas costas.", helps: [.lowBackPain, .scoliosis, .hyperlordosis, .anteriorPelvicTilt, .lifter]),
        Stretch(id: "dead-bug", name: "Dead bug", areas: [.core], kind: .activation, seconds: 45, perSide: false,
                steps: ["Deitado, braços para o teto, joelhos a 90°.", "Estenda braço e perna opostos devagar, sem descolar a lombar.", "Alterne os lados."],
                tip: "A lombar fica colada no chão o tempo todo.", helps: [.hyperlordosis, .anteriorPelvicTilt, .lowBackPain, .hyperextendedKnees]),
        Stretch(id: "side-plank", name: "Prancha lateral", areas: [.core], kind: .activation, seconds: 25, perSide: true,
                steps: ["Deite de lado apoiado no antebraço.", "Eleve o quadril formando uma linha reta.", "Joelhos no chão para facilitar."],
                tip: "Na escoliose costuma ser indicada para o lado da convexidade: confirme com seu fisio.", helps: [.scoliosis, .lowBackPain, .kneeValgus, .unevenShoulders]),
        Stretch(id: "pelvic-tilt", name: "Báscula pélvica deitado", areas: [.lowerBack, .core], kind: .activation, seconds: 45, perSide: false,
                steps: ["Deitado com joelhos dobrados, pés no chão.", "Contraia o abdômen colando a lombar no chão.", "Solte devagar e repita."],
                tip: "Ensina o controle da pelve.", helps: [.anteriorPelvicTilt, .hyperlordosis, .lowBackPain]),
        Stretch(id: "hang", name: "Suspensão na barra", areas: [.upperBack, .shoulders], kind: .release, seconds: 30, perSide: false,
                steps: ["Segure numa barra com os braços esticados.", "Deixe o corpo pendurado, pés tocando o chão se preciso.", "Respire e relaxe a coluna."],
                tip: "Descomprime a coluna e solta os ombros.", helps: [.poorOverhead, .tightLats, .lowBackPain, .scoliosis, .lifter], level: 2),

        // Quadril e glúteos
        Stretch(id: "kneeling-hip-flexor", name: "Flexor do quadril ajoelhado", areas: [.hips, .quads], kind: .stretch, seconds: 35, perSide: true,
                steps: ["Ajoelhe com um pé à frente (posição de afundo).", "Contraia o glúteo da perna de trás e encaixe a pelve.", "Leve o quadril levemente à frente."],
                tip: "Levante o braço do lado de trás para intensificar.", helps: [.tightHipFlexors, .anteriorPelvicTilt, .hyperlordosis, .deskWork, .driving, .runner, .lowBackPain, .frontSplits]),
        Stretch(id: "couch", name: "Couch stretch (sofá)", areas: [.quads, .hips], kind: .stretch, seconds: 40, perSide: true,
                steps: ["Ajoelhe de costas para um sofá/parede, peito do pé de trás apoiado nele.", "Outro pé à frente no chão.", "Suba o tronco e contraia o glúteo."],
                tip: "Intenso: comece com o tronco inclinado.", helps: [.tightQuads, .tightHipFlexors, .anteriorPelvicTilt, .kneePain, .runner, .frontSplits], level: 2),
        Stretch(id: "pigeon", name: "Pombo", areas: [.glutes, .hips], kind: .stretch, seconds: 45, perSide: true,
                steps: ["Leve uma perna dobrada à frente, canela na diagonal.", "Estenda a outra perna para trás.", "Incline o tronco à frente apoiado nas mãos."],
                tip: "Se o joelho incomodar, faça a versão deitado (figura 4).", helps: [.sciatica, .tightHips, .lowBackPain, .runner, .hipPain, .driving], level: 2),
        Stretch(id: "figure-four", name: "Figura 4 deitado (piriforme)", areas: [.glutes, .hips], kind: .stretch, seconds: 35, perSide: true,
                steps: ["Deitado, cruze o tornozelo sobre o joelho oposto.", "Puxe a coxa da perna de baixo em direção ao peito.", "Mantenha a cabeça no chão."],
                tip: "Versão mais segura do pombo.", helps: [.sciatica, .tightHips, .lowBackPain, .deskWork, .poorSleep, .hipPain]),
        Stretch(id: "90-90", name: "Rotação de quadril 90/90", areas: [.hips, .glutes], kind: .mobility, seconds: 45, perSide: false,
                steps: ["Sentado, uma perna à frente e outra ao lado, ambas a 90°.", "Gire os joelhos para o outro lado sem tirar os pés do chão.", "Mantenha o tronco alto."],
                tip: "Use as mãos atrás como apoio no começo.", helps: [.tightHips, .hipPain, .deepSquat, .lifter, .duckFeet, .driving]),
        Stretch(id: "glute-bridge", name: "Ponte de glúteo", areas: [.glutes, .core], kind: .activation, seconds: 45, perSide: false,
                steps: ["Deitado, joelhos dobrados, pés no chão.", "Empurre os calcanhares e suba o quadril.", "Aperte os glúteos 2 s no topo."],
                tip: "Costelas para baixo; não arqueie a lombar.", helps: [.anteriorPelvicTilt, .hyperlordosis, .lowBackPain, .kneeValgus, .kneePain, .deskWork, .hyperextendedKnees]),
        Stretch(id: "clamshell", name: "Concha (clamshell)", areas: [.glutes, .hips], kind: .activation, seconds: 40, perSide: true,
                steps: ["Deitado de lado, joelhos dobrados e pés juntos.", "Abra o joelho de cima sem mexer o quadril.", "Feche devagar."],
                tip: "Fortalece o glúteo médio, que segura o joelho.", helps: [.kneeValgus, .kneePain, .flatFeet, .runner, .hipPain]),
        Stretch(id: "lateral-walk", name: "Caminhada lateral (com ou sem elástico)", areas: [.glutes], kind: .activation, seconds: 40, perSide: false,
                steps: ["Semiagachado, elástico acima dos joelhos (opcional).", "Dê passos laterais mantendo os joelhos afastados.", "Volte para o outro lado."],
                tip: "Pés apontando para frente.", helps: [.kneeValgus, .duckFeet, .runner, .kneePain]),
        Stretch(id: "hip-circles", name: "Círculos de quadril em quatro apoios", areas: [.hips], kind: .mobility, seconds: 30, perSide: true,
                steps: ["Em quatro apoios, levante um joelho do chão.", "Desenhe círculos grandes com o joelho.", "Inverta o sentido."],
                tip: "Aquecimento ótimo antes de pernas.", helps: [.tightHips, .lifter, .runner, .hipPain]),
        Stretch(id: "frog", name: "Sapo (adutores)", areas: [.adductors, .hips], kind: .stretch, seconds: 45, perSide: false,
                steps: ["Em quatro apoios, afaste os joelhos o máximo confortável.", "Pés para fora, alinhados com os joelhos.", "Leve o quadril para trás devagar."],
                tip: "Base para a abertura lateral.", helps: [.tightAdductors, .splits, .deepSquat, .tightHips], level: 2),
        Stretch(id: "butterfly", name: "Borboleta", areas: [.adductors, .hips], kind: .stretch, seconds: 40, perSide: false,
                steps: ["Sentado, junte as solas dos pés.", "Segure os pés e mantenha a coluna alta.", "Incline o tronco à frente devagar."],
                tip: "Não force os joelhos para baixo com as mãos.", helps: [.tightAdductors, .splits, .tightHips, .deepSquat]),
        Stretch(id: "side-lunge", name: "Afundo lateral (cossack)", areas: [.adductors, .hips], kind: .mobility, seconds: 40, perSide: false,
                steps: ["Pernas bem afastadas.", "Desça sobre uma perna mantendo a outra esticada.", "Troque de lado passando pelo centro."],
                tip: "Calcanhar da perna dobrada no chão.", helps: [.tightAdductors, .deepSquat, .splits, .lifter]),
        Stretch(id: "straddle", name: "Abertura sentado (straddle)", areas: [.adductors, .hamstrings], kind: .stretch, seconds: 45, perSide: false,
                steps: ["Sentado, pernas abertas em V.", "Pontas dos pés para o teto.", "Incline o tronco à frente com a coluna reta."],
                tip: "Sente sobre uma almofada se a lombar arredondar.", helps: [.splits, .tightAdductors, .tightHamstrings], level: 2),
        Stretch(id: "lizard", name: "Lagarto", areas: [.hips, .adductors], kind: .stretch, seconds: 35, perSide: true,
                steps: ["Posição de afundo, mãos no chão por dentro do pé da frente.", "Joelho de trás no chão.", "Desça o quadril; apoie os antebraços se conseguir."],
                tip: "Abre quadril e virilha.", helps: [.tightHipFlexors, .tightHips, .deepSquat, .frontSplits, .splits], level: 2),
        Stretch(id: "worlds-greatest", name: "Maior alongamento do mundo", areas: [.fullBody, .hips], kind: .mobility, seconds: 40, perSide: true,
                steps: ["Dê um passo à frente em afundo, mão oposta no chão.", "Leve o cotovelo do mesmo lado da perna em direção ao pé.", "Gire o tronco abrindo o braço para o teto."],
                tip: "Aquecimento completo antes de qualquer treino.", helps: [.tightHipFlexors, .tightThoracic, .tightHips, .lifter, .runner, .deskWork]),

        // Posterior e quadríceps
        Stretch(id: "standing-hamstring", name: "Posterior em pé (perna no apoio)", areas: [.hamstrings], kind: .stretch, seconds: 30, perSide: true,
                steps: ["Apoie o calcanhar num degrau ou banco baixo.", "Perna esticada, ponta do pé para cima.", "Incline o tronco à frente com a coluna reta."],
                tip: "Pense em levar o umbigo à coxa, não o nariz ao joelho.", helps: [.tightHamstrings, .posteriorPelvicTilt, .touchToes, .runner, .lowBackPain, .frontSplits, .flatBack]),
        Stretch(id: "supine-hamstring", name: "Posterior deitado com toalha", areas: [.hamstrings], kind: .stretch, seconds: 35, perSide: true,
                steps: ["Deitado, passe uma toalha na sola do pé.", "Suba a perna esticada até sentir o posterior.", "A outra perna fica esticada no chão."],
                tip: "Protege a lombar: ótimo para quem tem dor.", helps: [.tightHamstrings, .lowBackPain, .sciatica, .touchToes, .posteriorPelvicTilt]),
        Stretch(id: "forward-fold", name: "Flexão à frente em pé", areas: [.hamstrings, .lowerBack], kind: .stretch, seconds: 35, perSide: false,
                steps: ["Em pé, pés na largura do quadril.", "Dobre o quadril e deixe o tronco pendurar.", "Joelhos levemente dobrados se precisar."],
                tip: "Balance a cabeça para soltar o pescoço.", helps: [.touchToes, .tightHamstrings, .stress, .standingJob]),
        Stretch(id: "leg-swings", name: "Balanço de pernas", areas: [.hamstrings, .hips], kind: .mobility, seconds: 30, perSide: true,
                steps: ["Segure numa parede.", "Balance a perna para frente e para trás, solta.", "Aumente a amplitude aos poucos; depois faça de lado."],
                tip: "Aquecimento dinâmico para corrida e pernas.", helps: [.runner, .tightHamstrings, .tightHipFlexors, .lifter, .frontSplits]),
        Stretch(id: "quad-standing", name: "Quadríceps em pé", areas: [.quads], kind: .stretch, seconds: 30, perSide: true,
                steps: ["Segure o pé e leve o calcanhar ao glúteo.", "Joelhos juntos, quadril encaixado.", "Apoie-se numa parede se precisar."],
                tip: "Contraia o glúteo para sentir mais.", helps: [.tightQuads, .kneePain, .runner, .anteriorPelvicTilt, .standingJob]),
        Stretch(id: "half-split", name: "Meia abertura (half split)", areas: [.hamstrings], kind: .stretch, seconds: 35, perSide: true,
                steps: ["Ajoelhado, estenda uma perna à frente com o calcanhar no chão.", "Leve o quadril para trás sobre o joelho de trás.", "Incline o tronco com a coluna reta."],
                tip: "Base para a abertura frontal.", helps: [.frontSplits, .tightHamstrings, .touchToes]),
        Stretch(id: "it-band", name: "Lateral da coxa em pé (cruzando)", areas: [.hips, .quads], kind: .stretch, seconds: 30, perSide: true,
                steps: ["Cruze a perna a alongar por trás da outra.", "Empurre o quadril para o lado da perna de trás.", "Incline o tronco para o lado oposto."],
                tip: "A banda não estica muito: o foco é o quadril lateral.", helps: [.tightITBand, .runner, .kneePain, .kneeVarus]),

        // Panturrilhas e pés
        Stretch(id: "calf-wall", name: "Panturrilha na parede", areas: [.calves], kind: .stretch, seconds: 30, perSide: true,
                steps: ["Mãos na parede, uma perna atrás esticada.", "Calcanhar de trás no chão, ponta do pé para frente.", "Incline o corpo à frente."],
                tip: "Depois dobre o joelho de trás para alongar o sóleo.", helps: [.tightCalves, .plantarFasciitis, .runner, .deepSquat, .flatFeet, .standingJob, .duckFeet]),
        Stretch(id: "soleus", name: "Sóleo (joelho dobrado)", areas: [.calves], kind: .stretch, seconds: 30, perSide: true,
                steps: ["Igual ao da parede, mas com o joelho de trás dobrado.", "Mantenha o calcanhar no chão.", "Sente a parte baixa da panturrilha."],
                tip: "Essencial para o agachamento profundo.", helps: [.tightCalves, .deepSquat, .plantarFasciitis, .runner]),
        Stretch(id: "ankle-knee-wall", name: "Mobilidade de tornozelo (joelho na parede)", areas: [.calves, .feet], kind: .mobility, seconds: 40, perSide: true,
                steps: ["Pé a um palmo da parede.", "Leve o joelho até tocar a parede sem tirar o calcanhar do chão.", "Volte; afaste o pé aos poucos."],
                tip: "Joelho na direção do 2º dedo.", helps: [.tightCalves, .deepSquat, .kneeValgus, .flatFeet, .lifter]),
        Stretch(id: "plantar-roll", name: "Rolar a sola do pé na bolinha", areas: [.feet], kind: .release, seconds: 45, perSide: true,
                steps: ["Sentado ou em pé, pise numa bolinha (tênis ou garrafa gelada).", "Role do calcanhar aos dedos.", "Pare nos pontos tensos."],
                tip: "Garrafa gelada alivia a fascite.", helps: [.plantarFasciitis, .flatFeet, .standingJob, .runner]),
        Stretch(id: "toe-stretch", name: "Alongamento dos dedos do pé", areas: [.feet], kind: .stretch, seconds: 30, perSide: false,
                steps: ["Ajoelhe com os dedos dos pés dobrados no chão.", "Sente sobre os calcanhares devagar.", "Respire; saia se doer muito."],
                tip: "Depois faça com o peito do pé no chão.", helps: [.plantarFasciitis, .flatFeet, .runner]),
        Stretch(id: "short-foot", name: "Pé curto (arco do pé)", areas: [.feet], kind: .activation, seconds: 40, perSide: false,
                steps: ["Em pé ou sentado, pés no chão.", "Sem dobrar os dedos, aproxime a base do dedão do calcanhar.", "O arco do pé sobe; segure 5 s."],
                tip: "Fortalece o arco e ajuda o joelho.", helps: [.flatFeet, .kneeValgus, .plantarFasciitis, .duckFeet]),
        Stretch(id: "calf-raise-slow", name: "Elevação de panturrilha lenta", areas: [.calves], kind: .activation, seconds: 45, perSide: false,
                steps: ["Em pé num degrau, calcanhares para fora.", "Suba em 2 s e desça em 4 s abaixo do degrau.", "Segure numa parede."],
                tip: "A descida lenta trata tendões.", helps: [.plantarFasciitis, .runner, .tightCalves, .hyperextendedKnees]),

        // Braços e punhos
        Stretch(id: "wrist-flexor", name: "Flexores do punho", areas: [.wrists, .arms], kind: .stretch, seconds: 25, perSide: true,
                steps: ["Braço esticado à frente, palma para cima.", "Com a outra mão, puxe os dedos para baixo.", "Cotovelo esticado."],
                tip: "Faça pausas a cada hora de digitação.", helps: [.wristPain, .elbowPain, .deskWork, .phoneUse, .lifter]),
        Stretch(id: "wrist-extensor", name: "Extensores do punho", areas: [.wrists, .arms], kind: .stretch, seconds: 25, perSide: true,
                steps: ["Braço esticado, palma para baixo.", "Puxe a mão para baixo com a outra mão.", "Gire levemente para dentro."],
                tip: "Alivia o cotovelo de tenista.", helps: [.elbowPain, .wristPain, .deskWork, .phoneUse]),
        Stretch(id: "wrist-circles", name: "Rotação de punhos e dedos", areas: [.wrists], kind: .mobility, seconds: 30, perSide: false,
                steps: ["Entrelace os dedos.", "Gire os punhos em círculos.", "Abra e feche as mãos com força algumas vezes."],
                tip: "Antes de flexões e supino.", helps: [.wristPain, .deskWork, .lifter, .phoneUse]),
        Stretch(id: "triceps-overhead", name: "Tríceps acima da cabeça", areas: [.arms, .shoulders], kind: .stretch, seconds: 25, perSide: true,
                steps: ["Levante o braço e dobre o cotovelo, mão nas costas.", "Com a outra mão, puxe o cotovelo.", "Cabeça reta."],
                tip: "Solta também o dorsal.", helps: [.poorOverhead, .tightLats, .lifter]),
        Stretch(id: "biceps-wall", name: "Bíceps na parede", areas: [.arms, .chest], kind: .stretch, seconds: 25, perSide: true,
                steps: ["Palma apoiada na parede atrás de você, braço esticado.", "Gire o corpo para o lado oposto.", "Polegar para baixo intensifica."],
                tip: "Bom após treino de braço.", helps: [.tightChest, .protractedShoulders, .elbowPain, .lifter]),

        // Relaxamento
        Stretch(id: "legs-wall", name: "Pernas na parede", areas: [.hamstrings, .lowerBack], kind: .release, seconds: 120, perSide: false,
                steps: ["Deite com o glúteo perto da parede.", "Suba as pernas apoiadas na parede.", "Braços soltos; respire devagar."],
                tip: "Ótimo antes de dormir e após ficar em pé.", helps: [.poorSleep, .stress, .standingJob, .tightHamstrings, .runner]),
        Stretch(id: "box-breath", name: "Respiração diafragmática deitado", areas: [.fullBody], kind: .release, seconds: 90, perSide: false,
                steps: ["Deitado, uma mão no peito e outra na barriga.", "Inspire pelo nariz em 4 s enchendo a barriga.", "Expire pela boca em 6 s."],
                tip: "Expirar mais longo acalma o sistema nervoso.", helps: [.stress, .poorSleep, .tensionHeadache, .jawTension, .neckTension]),
        Stretch(id: "happy-baby", name: "Bebê feliz", areas: [.hips, .lowerBack], kind: .release, seconds: 45, perSide: false,
                steps: ["Deitado, segure a parte de fora dos pés.", "Joelhos abertos em direção às axilas.", "Balance suavemente."],
                tip: "Solta quadril e lombar.", helps: [.tightHips, .tightAdductors, .lowBackPain, .poorSleep, .deepSquat]),
        Stretch(id: "reclined-butterfly", name: "Borboleta deitada", areas: [.adductors, .hips], kind: .release, seconds: 90, perSide: false,
                steps: ["Deitado, junte as solas dos pés e deixe os joelhos caírem.", "Almofadas sob os joelhos se precisar.", "Respire fundo."],
                tip: "Relaxante: ótimo para a noite.", helps: [.poorSleep, .stress, .tightAdductors]),

        // Agachamento e corpo todo
        Stretch(id: "deep-squat-hold", name: "Agachamento profundo segurando", areas: [.hips, .calves, .adductors], kind: .mobility, seconds: 45, perSide: false,
                steps: ["Pés um pouco mais abertos que o quadril, pontas levemente para fora.", "Desça o máximo com os calcanhares no chão.", "Use os cotovelos para empurrar os joelhos para fora."],
                tip: "Segure em algo se cair para trás.", helps: [.deepSquat, .tightCalves, .tightHips, .tightAdductors, .lifter, .deskWork]),
        Stretch(id: "jefferson", name: "Jefferson curl leve", areas: [.hamstrings, .lowerBack], kind: .mobility, seconds: 40, perSide: false,
                steps: ["Em pé, enrole a coluna de cima para baixo, vértebra por vértebra.", "Deixe os braços pendurados.", "Suba desenrolando devagar."],
                tip: "Sem peso no começo; evite com hérnia.", helps: [.touchToes, .tightHamstrings, .flatBack], level: 3),
        Stretch(id: "bridge-pose", name: "Ponte completa / meia ponte", areas: [.lowerBack, .shoulders, .chest], kind: .mobility, seconds: 30, perSide: false,
                steps: ["Deitado, mãos ao lado das orelhas, dedos para os pés.", "Suba o quadril e, se conseguir, empurre o chão até estender os braços.", "Iniciantes: fique na ponte de glúteo com os braços no chão."],
                tip: "Aqueça bem ombros e costas antes.", helps: [.bridge, .poorOverhead, .tightChest], level: 3),
        Stretch(id: "inchworm", name: "Lagarta (inchworm)", areas: [.hamstrings, .shoulders, .fullBody], kind: .mobility, seconds: 45, perSide: false,
                steps: ["Em pé, leve as mãos ao chão.", "Caminhe com as mãos até a prancha.", "Volte caminhando com as mãos até os pés."],
                tip: "Aquecimento geral rápido.", helps: [.tightHamstrings, .lifter, .runner, .touchToes]),
        Stretch(id: "seated-twist", name: "Torção sentado na cadeira", areas: [.upperBack, .lowerBack], kind: .mobility, seconds: 25, perSide: true,
                steps: ["Sentado na ponta da cadeira, pés no chão.", "Gire o tronco segurando o encosto.", "Cresça a coluna ao inspirar e gire ao expirar."],
                tip: "Pausa de escritório perfeita.", helps: [.deskWork, .driving, .tightThoracic, .lowBackPain, .scoliosis]),
        Stretch(id: "seated-figure-four", name: "Figura 4 sentado na cadeira", areas: [.glutes, .hips], kind: .stretch, seconds: 30, perSide: true,
                steps: ["Sentado, cruze o tornozelo sobre o joelho oposto.", "Coluna reta, incline o tronco à frente.", "Empurre levemente o joelho para baixo."],
                tip: "Dá para fazer no trabalho.", helps: [.deskWork, .sciatica, .tightHips, .driving]),
        Stretch(id: "standing-chest-open", name: "Abertura de peito com mãos atrás", areas: [.chest, .shoulders], kind: .stretch, seconds: 30, perSide: false,
                steps: ["Entrelace as mãos atrás das costas.", "Estenda os braços e afaste-os das costas.", "Abra o peito e olhe levemente para cima."],
                tip: "Pausa rápida para quem usa computador.", helps: [.protractedShoulders, .tightChest, .kyphosis, .deskWork, .phoneUse]),
        Stretch(id: "knee-tke", name: "Extensão terminal do joelho", areas: [.quads], kind: .activation, seconds: 40, perSide: true,
                steps: ["Elástico atrás do joelho preso à frente (ou toalha empurrando a parede).", "Dobre levemente e estenda o joelho contraindo a coxa.", "Segure 2 s."],
                tip: "Fortalece o vasto medial, que estabiliza a patela.", helps: [.kneePain, .kneeValgus, .hyperextendedKnees]),
        Stretch(id: "spanish-squat", name: "Isometria de joelho (parede)", areas: [.quads], kind: .activation, seconds: 30, perSide: false,
                steps: ["Costas na parede, desça até os joelhos a ~60°.", "Joelhos alinhados com os pés.", "Segure respirando."],
                tip: "Isometria costuma aliviar dor patelar.", helps: [.kneePain, .kneeValgus, .runner]),
    ]
    // swiftlint:enable line_length

    static let byID: [String: Stretch] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    /// Áreas mais exigidas por músculo treinado (para alongar depois do treino).
    static func areas(for m: Muscle) -> [StretchArea] {
        switch m {
        case .chest: [.chest, .shoulders]
        case .back: [.upperBack]
        case .shoulders: [.shoulders]
        case .biceps, .triceps: [.arms]
        case .quads: [.quads, .hips]
        case .hamstrings: [.hamstrings]
        case .glutes: [.glutes, .hips]
        case .calves: [.calves]
        case .abs: [.core, .lowerBack]
        default: []
        }
    }
}

// MARK: - Rotinas

struct StretchRoutine: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var icon: String
    var subtitle: String
    var ids: [String]
    var custom = false

    var stretches: [Stretch] { ids.compactMap { StretchCatalog.byID[$0] } }
    var minutes: Int { max(1, (stretches.map(\.totalSeconds).reduce(0, +) + 59) / 60) }

    static let presets: [StretchRoutine] = [
        StretchRoutine(id: "desk", name: "Pausa do escritório", icon: "desktopcomputer", subtitle: "Pescoço, peito e quadril sem sair da cadeira",
                       ids: ["chin-tuck", "upper-trap", "standing-chest-open", "seated-twist", "seated-figure-four", "wrist-flexor", "wrist-extensor"]),
        StretchRoutine(id: "posture", name: "Postura em dia", icon: "figure.stand", subtitle: "Contra ombros para frente e costas curvadas",
                       ids: ["foam-thoracic", "doorway-pec", "thread-needle", "wall-angel", "prone-ytw", "chin-tuck", "kneeling-hip-flexor", "glute-bridge"]),
        StretchRoutine(id: "warmup", name: "Aquecimento pré-treino", icon: "flame.fill", subtitle: "Dinâmico: prepara o corpo todo",
                       ids: ["arm-circles", "cat-cow", "worlds-greatest", "hip-circles", "leg-swings", "inchworm", "ankle-knee-wall", "deep-squat-hold"]),
        StretchRoutine(id: "cooldown", name: "Pós-treino", icon: "figure.cooldown", subtitle: "Volta à calma e flexibilidade",
                       ids: ["child-pose", "doorway-pec", "lat-stretch", "kneeling-hip-flexor", "figure-four", "supine-hamstring", "calf-wall", "box-breath"]),
        StretchRoutine(id: "lowback", name: "Alívio da lombar", icon: "bandage.fill", subtitle: "Suave e seguro para dor lombar comum",
                       ids: ["pelvic-tilt", "knees-chest", "cat-cow", "child-pose", "supine-twist", "figure-four", "supine-hamstring", "bird-dog", "glute-bridge"]),
        StretchRoutine(id: "neck", name: "Pescoço e cabeça", icon: "person.bust", subtitle: "Tensão, celular e dor de cabeça",
                       ids: ["neck-circles", "chin-tuck", "upper-trap", "levator", "scm", "thread-needle", "jaw-release", "box-breath"]),
        StretchRoutine(id: "hips", name: "Quadril livre", icon: "figure.flexibility", subtitle: "Para quem passa o dia sentado",
                       ids: ["hip-circles", "90-90", "kneeling-hip-flexor", "pigeon", "frog", "lizard", "happy-baby"]),
        StretchRoutine(id: "sleep", name: "Antes de dormir", icon: "moon.stars.fill", subtitle: "Relaxamento e respiração",
                       ids: ["child-pose", "supine-twist", "figure-four", "happy-baby", "reclined-butterfly", "legs-wall", "box-breath"]),
        StretchRoutine(id: "runner", name: "Corredor", icon: "figure.run", subtitle: "Panturrilha, quadril e posterior",
                       ids: ["leg-swings", "calf-wall", "soleus", "kneeling-hip-flexor", "quad-standing", "it-band", "figure-four", "plantar-roll"]),
        StretchRoutine(id: "squat", name: "Agachamento profundo", icon: "figure.strengthtraining.functional", subtitle: "Tornozelo, quadril e adutores",
                       ids: ["ankle-knee-wall", "soleus", "side-lunge", "frog", "90-90", "deep-squat-hold"]),
        StretchRoutine(id: "splits", name: "Rumo à abertura", icon: "figure.gymnastics", subtitle: "Abertura lateral e frontal (progressivo)",
                       ids: ["leg-swings", "butterfly", "frog", "straddle", "lizard", "half-split", "couch"]),
        StretchRoutine(id: "feet", name: "Pés e joelhos", icon: "shoeprints.fill", subtitle: "Fascite, pé chato e joelho para dentro",
                       ids: ["plantar-roll", "toe-stretch", "short-foot", "calf-wall", "ankle-knee-wall", "clamshell", "spanish-squat"]),
    ]
}
