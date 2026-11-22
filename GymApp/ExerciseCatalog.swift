import Foundation

/// Biblioteca de exercícios. MET segundo o Compendium of Physical Activities (Ainsworth, 2011).
enum ExerciseCatalog {
    private static func s(_ id: String, _ name: String, _ p: [Muscle], _ sec: [Muscle], _ eq: Equipment,
                          met: Double = 5.0, _ how: String, _ tip: String) -> Exercise {
        Exercise(id: id, name: name, primary: p, secondary: sec, equipment: eq, kind: .strength, met: met, howTo: how, tip: tip)
    }
    private static func bw(_ id: String, _ name: String, _ p: [Muscle], _ sec: [Muscle], met: Double = 5.0,
                           _ how: String, _ tip: String) -> Exercise {
        Exercise(id: id, name: name, primary: p, secondary: sec, equipment: .bodyweight, kind: .bodyweight, met: met, howTo: how, tip: tip)
    }
    private static func timed(_ id: String, _ name: String, _ p: [Muscle], _ sec: [Muscle], met: Double = 4.0,
                              _ how: String, _ tip: String) -> Exercise {
        Exercise(id: id, name: name, primary: p, secondary: sec, equipment: .bodyweight, kind: .timed, met: met, howTo: how, tip: tip)
    }
    private static func cardio(_ id: String, _ name: String, _ eq: Equipment, met: Double, _ how: String, _ tip: String) -> Exercise {
        Exercise(id: id, name: name, primary: [.cardio], secondary: [], equipment: eq, kind: .cardio, met: met, howTo: how, tip: tip)
    }

    static let all: [Exercise] = [
        // PEITO
        s("bench", "Supino reto com barra", [.chest], [.triceps, .shoulders], .barbell, met: 6,
          "Deitado no banco, pés no chão, escápulas retraídas. Desça a barra até a linha do peito e empurre até estender os braços.",
          "Mantenha leve arco lombar e cotovelos a ~45° do tronco para proteger os ombros."),
        s("bench-db", "Supino reto com halteres", [.chest], [.triceps, .shoulders], .dumbbell,
          "Halteres na altura do peito, palmas para frente. Empurre para cima aproximando-os no topo.",
          "Maior amplitude que a barra; desça até sentir alongar o peitoral."),
        s("incline-bench", "Supino inclinado com barra", [.chest], [.shoulders, .triceps], .barbell, met: 6,
          "Banco a 30–45°. Desça a barra até a parte alta do peito e empurre.", "Inclinação acima de 45° vira exercício de ombro."),
        s("incline-db", "Supino inclinado com halteres", [.chest], [.shoulders, .triceps], .dumbbell,
          "Banco a 30°. Empurre os halteres para cima e desça controlando.", "Ótimo para a porção superior do peitoral."),
        s("decline-bench", "Supino declinado", [.chest], [.triceps], .barbell,
          "Banco declinado, pés presos. Desça a barra até a parte baixa do peito.", "Foca na porção inferior do peitoral."),
        s("chest-press", "Supino na máquina", [.chest], [.triceps, .shoulders], .machine,
          "Ajuste o banco para as pegadas ficarem na linha do peito. Empurre e volte devagar.", "Bom para iniciantes e para ir perto da falha com segurança."),
        s("fly-db", "Crucifixo com halteres", [.chest], [.shoulders], .dumbbell,
          "Deitado, braços quase estendidos. Abra em arco até alongar o peito e feche.", "Cotovelos levemente flexionados o tempo todo."),
        s("pec-deck", "Voador (peck deck)", [.chest], [.shoulders], .machine,
          "Sentado, braços nas almofadas. Feche à frente do peito contraindo.", "Segure 1 segundo na contração."),
        s("cable-cross", "Crossover na polia", [.chest], [.shoulders], .cable,
          "Polias altas, um passo à frente. Traga as mãos para baixo e à frente cruzando levemente.", "Varie a altura das polias para focar partes diferentes."),
        bw("pushup", "Flexão de braço", [.chest], [.triceps, .shoulders, .abs], met: 3.8,
           "Mãos um pouco além dos ombros, corpo alinhado. Desça até o peito quase tocar o chão.", "Comece com joelhos no chão se precisar."),
        bw("dips-chest", "Paralelas (mergulho)", [.chest, .triceps], [.shoulders], met: 6,
           "Nas barras paralelas, incline o tronco à frente e desça até ~90° nos cotovelos.", "Mais inclinado = mais peito; mais reto = mais tríceps."),

        // COSTAS
        s("deadlift", "Levantamento terra", [.back, .hamstrings, .glutes], [.lowerBack, .traps, .forearms], .barbell, met: 6,
          "Barra sobre o meio do pé, coluna neutra. Empurre o chão com as pernas e estenda o quadril.", "A barra sobe rente às canelas. Nunca arredonde a lombar."),
        bw("pullup", "Barra fixa", [.back], [.biceps, .forearms], met: 8,
           "Pegada pronada além dos ombros. Puxe até o queixo passar a barra.", "Use elástico ou máquina graviton para progredir."),
        bw("chinup", "Barra fixa supinada", [.back, .biceps], [.forearms], met: 8,
           "Pegada supinada na largura dos ombros. Puxe levando o peito à barra.", "Mais fácil que a pronada e ótima para bíceps."),
        s("lat-pulldown", "Puxada frontal", [.back], [.biceps], .cable,
          "Sentado, pegada aberta. Puxe a barra até o alto do peito levando os cotovelos para baixo.", "Não jogue o tronco para trás; pense em puxar com os cotovelos."),
        s("lat-pulldown-close", "Puxada com triângulo", [.back], [.biceps], .cable,
          "Pegada neutra fechada. Puxe até o peito mantendo o tronco estável.", "Boa para a parte inferior do grande dorsal."),
        s("barbell-row", "Remada curvada com barra", [.back], [.biceps, .lowerBack, .traps], .barbell, met: 6,
          "Tronco inclinado ~45°, coluna neutra. Puxe a barra até o umbigo.", "Contraia as escápulas no topo."),
        s("db-row", "Remada unilateral (serrote)", [.back], [.biceps], .dumbbell,
          "Apoie joelho e mão no banco. Puxe o halter até o quadril.", "Cotovelo junto ao corpo, sem girar o tronco."),
        s("seated-row", "Remada sentada na polia", [.back], [.biceps, .traps], .cable,
          "Sentado, coluna ereta. Puxe o triângulo até o abdômen e volte alongando.", "Não balance o tronco."),
        s("machine-row", "Remada na máquina", [.back], [.biceps], .machine,
          "Peito apoiado. Puxe as alças levando os cotovelos para trás.", "Apoio no peito tira a carga da lombar."),
        s("tbar-row", "Remada cavalinho (T-bar)", [.back], [.biceps, .lowerBack], .barbell,
          "Sobre a barra T, tronco inclinado. Puxe até o peito.", "Pegada neutra fechada foca o meio das costas."),
        s("pullover", "Pullover na polia", [.back], [.chest], .cable,
          "Em pé, braços estendidos à frente na polia alta. Traga a barra até as coxas em arco.", "Ótimo para sentir o grande dorsal."),
        s("shrug", "Encolhimento com halteres", [.traps], [.forearms], .dumbbell,
          "Em pé, halteres ao lado. Eleve os ombros em direção às orelhas.", "Sem girar os ombros; segure 1 s no topo."),
        bw("hyperextension", "Hiperextensão lombar", [.lowerBack], [.glutes, .hamstrings], met: 3.5,
           "No banco romano, desça o tronco e suba até alinhar com as pernas.", "Não hiperestenda no topo."),

        // OMBROS
        s("ohp", "Desenvolvimento militar com barra", [.shoulders], [.triceps, .traps], .barbell, met: 6,
          "Em pé, barra na altura da clavícula. Empurre acima da cabeça e volte.", "Contraia abdômen e glúteos para não arquear a lombar."),
        s("db-press", "Desenvolvimento com halteres", [.shoulders], [.triceps], .dumbbell,
          "Sentado, halteres na altura das orelhas. Empurre para cima.", "Não precisa encostar os halteres no topo."),
        s("machine-press", "Desenvolvimento na máquina", [.shoulders], [.triceps], .machine,
          "Ajuste o banco, empurre as alças para cima.", "Seguro para treinar perto da falha."),
        s("lateral-raise", "Elevação lateral", [.shoulders], [.traps], .dumbbell,
          "Em pé, eleve os halteres lateralmente até a linha dos ombros.", "Carga leve, cotovelos levemente flexionados; lidere com o cotovelo."),
        s("cable-lateral", "Elevação lateral na polia", [.shoulders], [], .cable,
          "Polia baixa do lado oposto. Eleve o braço lateralmente.", "Tensão constante ao longo do movimento."),
        s("front-raise", "Elevação frontal", [.shoulders], [.chest], .dumbbell,
          "Eleve os halteres à frente até a altura dos ombros.", "O deltoide anterior já trabalha muito no supino."),
        s("rear-delt-fly", "Crucifixo inverso", [.shoulders], [.back, .traps], .dumbbell,
          "Tronco inclinado, abra os braços para os lados.", "Foco no deltoide posterior, importante para a postura."),
        s("face-pull", "Face pull", [.shoulders], [.traps, .back], .cable,
          "Corda na polia alta. Puxe em direção ao rosto abrindo os cotovelos.", "Excelente para saúde do ombro."),
        s("upright-row", "Remada alta", [.shoulders, .traps], [.biceps], .barbell,
          "Pegada média, puxe a barra até o peito com cotovelos altos.", "Pare na linha dos ombros se sentir desconforto."),
        s("arnold-press", "Desenvolvimento Arnold", [.shoulders], [.triceps], .dumbbell,
          "Comece com palmas viradas para você e gire enquanto empurra.", "Movimento completo para os três feixes."),

        // BÍCEPS
        s("barbell-curl", "Rosca direta com barra", [.biceps], [.forearms], .barbell,
          "Em pé, cotovelos junto ao corpo. Flexione até o topo e desça devagar.", "Sem balançar o tronco."),
        s("db-curl", "Rosca alternada com halteres", [.biceps], [.forearms], .dumbbell,
          "Alterne os braços girando o punho para cima.", "Supinar no topo aumenta a contração."),
        s("hammer-curl", "Rosca martelo", [.biceps, .forearms], [], .dumbbell,
          "Pegada neutra, flexione os cotovelos.", "Trabalha braquial e braquiorradial."),
        s("preacher-curl", "Rosca Scott", [.biceps], [], .machine,
          "Braços apoiados no banco Scott, flexione.", "Não estenda totalmente com carga pesada."),
        s("cable-curl", "Rosca na polia", [.biceps], [.forearms], .cable,
          "Polia baixa, flexione mantendo os cotovelos fixos.", "Tensão constante."),
        s("incline-curl", "Rosca inclinada", [.biceps], [], .dumbbell,
          "Banco a 45°, braços pendendo. Flexione.", "Grande alongamento da cabeça longa."),
        s("concentration-curl", "Rosca concentrada", [.biceps], [], .dumbbell,
          "Sentado, cotovelo apoiado na coxa. Flexione.", "Ótima conexão mente-músculo."),

        // TRÍCEPS
        s("triceps-pushdown", "Tríceps na polia (pushdown)", [.triceps], [], .cable,
          "Cotovelos junto ao corpo, estenda os braços para baixo.", "Só o antebraço se move."),
        s("triceps-rope", "Tríceps corda", [.triceps], [], .cable,
          "Com a corda, estenda e abra as mãos no final.", "Abrir a corda no fim aumenta a contração."),
        s("skullcrusher", "Tríceps testa", [.triceps], [], .barbell,
          "Deitado, desça a barra W em direção à testa flexionando só os cotovelos.", "Use barra W para poupar os punhos."),
        s("overhead-ext", "Tríceps francês", [.triceps], [], .dumbbell,
          "Halter acima da cabeça, desça atrás da nuca e estenda.", "Alonga a cabeça longa do tríceps."),
        s("close-bench", "Supino fechado", [.triceps, .chest], [.shoulders], .barbell, met: 6,
          "Pegada na largura dos ombros, cotovelos junto ao corpo.", "Ótimo composto para tríceps."),
        bw("bench-dips", "Mergulho no banco", [.triceps], [.chest, .shoulders], met: 3.8,
           "Mãos no banco atrás de você, desça flexionando os cotovelos.", "Pés mais longe = mais difícil."),
        s("kickback", "Tríceps coice", [.triceps], [], .dumbbell,
          "Tronco inclinado, estenda o braço para trás.", "Carga leve e contração forte."),

        // ANTEBRAÇO
        s("wrist-curl", "Rosca de punho", [.forearms], [], .dumbbell,
          "Antebraço apoiado, flexione o punho.", "Também treina a pegada."),
        timed("farmer-walk", "Caminhada do fazendeiro", [.forearms, .traps], [.abs, .glutes], met: 6,
              "Segure cargas pesadas e caminhe com postura ereta.", "Excelente para pegada e core."),

        // PERNAS
        s("squat", "Agachamento livre", [.quads, .glutes], [.hamstrings, .lowerBack, .abs], .barbell, met: 6,
          "Barra no trapézio, pés na largura dos ombros. Desça até as coxas ficarem paralelas ou abaixo e suba.", "Joelhos acompanham a ponta dos pés; peito aberto."),
        s("front-squat", "Agachamento frontal", [.quads], [.glutes, .abs], .barbell, met: 6,
          "Barra apoiada na frente dos ombros, tronco mais vertical.", "Exige mobilidade de punho e tornozelo."),
        s("goblet-squat", "Agachamento goblet", [.quads, .glutes], [.abs], .dumbbell,
          "Segure um halter junto ao peito e agache.", "Ótimo para aprender o padrão do agachamento."),
        s("leg-press", "Leg press 45°", [.quads, .glutes], [.hamstrings], .machine,
          "Pés na plataforma na largura dos ombros. Desça até ~90° e empurre.", "Não tire a lombar do encosto."),
        s("hack-squat", "Agachamento hack", [.quads], [.glutes], .machine,
          "Costas apoiadas, desça controlando e empurre.", "Pés mais baixos = mais quadríceps."),
        s("smith-squat", "Agachamento no Smith", [.quads, .glutes], [.hamstrings], .machine,
          "Barra guiada, agache com os pés um pouco à frente.", "Mais estável que a barra livre."),
        s("leg-extension", "Cadeira extensora", [.quads], [], .machine,
          "Sentado, estenda os joelhos e desça devagar.", "Segure 1 s no topo."),
        s("lunge", "Afundo com halteres", [.quads, .glutes], [.hamstrings, .adductors], .dumbbell,
          "Dê um passo à frente e desça até o joelho de trás quase tocar o chão.", "Passada maior = mais glúteo."),
        s("bulgarian", "Agachamento búlgaro", [.quads, .glutes], [.hamstrings, .adductors], .dumbbell,
          "Pé de trás apoiado no banco, desça com a perna da frente.", "Um dos melhores para glúteo e quadríceps."),
        s("stepup", "Subida no banco (step-up)", [.quads, .glutes], [.hamstrings], .dumbbell,
          "Suba no banco com uma perna e desça controlando.", "Não impulsione com a perna de baixo."),
        s("rdl", "Stiff / levantamento romeno", [.hamstrings, .glutes], [.lowerBack], .barbell, met: 6,
          "Joelhos levemente flexionados, leve o quadril para trás descendo a barra rente às pernas.", "Pare quando sentir alongar os posteriores, sem arredondar a coluna."),
        s("leg-curl", "Mesa flexora", [.hamstrings], [.calves], .machine,
          "Deitado, flexione os joelhos levando o rolo aos glúteos.", "Quadril colado no banco."),
        s("seated-leg-curl", "Cadeira flexora", [.hamstrings], [], .machine,
          "Sentado, flexione os joelhos.", "Posição sentada alonga mais os posteriores."),
        s("hip-thrust", "Elevação pélvica (hip thrust)", [.glutes], [.hamstrings], .barbell,
          "Costas no banco, barra no quadril. Eleve o quadril até alinhar o tronco.", "Contraia forte no topo e olhe para frente."),
        bw("glute-bridge", "Ponte de glúteo", [.glutes], [.hamstrings], met: 3.5,
           "Deitado, pés no chão, eleve o quadril.", "Versão unilateral aumenta a dificuldade."),
        s("abductor", "Cadeira abdutora", [.glutes], [], .machine,
          "Sentado, abra as pernas contra a resistência.", "Trabalha glúteo médio."),
        s("adductor", "Cadeira adutora", [.adductors], [], .machine,
          "Sentado, feche as pernas contra a resistência.", "Controle a volta."),
        s("cable-kickback", "Glúteo na polia (coice)", [.glutes], [.hamstrings], .cable,
          "Tornozeleira na polia baixa, estenda o quadril para trás.", "Sem arquear a lombar."),
        s("standing-calf", "Panturrilha em pé", [.calves], [], .machine,
          "Na ponta dos pés, suba o máximo e desça alongando.", "Amplitude total e pausa embaixo."),
        s("seated-calf", "Panturrilha sentado", [.calves], [], .machine,
          "Sentado, eleve os calcanhares.", "Foca o sóleo."),
        s("sumo-deadlift", "Terra sumô", [.glutes, .quads, .adductors], [.back, .hamstrings], .barbell, met: 6,
          "Pés bem afastados, pegada por dentro das pernas. Suba estendendo o quadril.", "Joelhos abertos acompanhando os pés."),
        s("kb-swing", "Swing com kettlebell", [.glutes, .hamstrings], [.lowerBack, .shoulders, .cardio], .kettlebell, met: 9.8,
          "Balance o kettlebell entre as pernas e projete o quadril à frente.", "O movimento vem do quadril, não dos braços."),
        bw("bw-squat", "Agachamento livre (sem peso)", [.quads, .glutes], [.hamstrings], met: 5,
           "Agache com o peso do corpo mantendo o tronco ereto.", "Ótimo aquecimento."),
        bw("jump-squat", "Agachamento com salto", [.quads, .glutes], [.calves, .cardio], met: 8,
           "Agache e salte explosivamente.", "Aterrisse suave, joelhos flexionados."),

        // ABDÔMEN
        bw("crunch", "Abdominal supra", [.abs], [], met: 3.8,
           "Deitado, joelhos flexionados, eleve os ombros contraindo o abdômen.", "Não puxe o pescoço."),
        bw("leg-raise", "Elevação de pernas", [.abs], [.obliques], met: 3.8,
           "Deitado ou pendurado, eleve as pernas estendidas.", "Desça devagar sem tirar a lombar do chão."),
        bw("hanging-knee", "Elevação de joelhos na barra", [.abs], [.forearms], met: 4,
           "Pendurado na barra, eleve os joelhos ao peito.", "Evite balançar."),
        timed("plank", "Prancha", [.abs], [.shoulders, .lowerBack], met: 3.8,
              "Apoie antebraços e pontas dos pés, corpo reto.", "Registre o tempo em minutos (ex.: 0,75 = 45 s)."),
        timed("side-plank", "Prancha lateral", [.obliques], [.abs, .shoulders], met: 3.8,
              "Apoie um antebraço, corpo de lado e alinhado.", "Faça os dois lados."),
        s("cable-crunch", "Abdominal na polia", [.abs], [], .cable,
          "Ajoelhado, corda atrás da cabeça, flexione o tronco.", "Permite adicionar carga progressivamente."),
        bw("russian-twist", "Giro russo", [.obliques], [.abs], met: 3.8,
           "Sentado inclinado, gire o tronco de um lado para o outro.", "Segure um peso para aumentar a carga."),
        s("ab-wheel", "Roda abdominal", [.abs], [.shoulders, .lowerBack], .other,
          "Ajoelhado, role a roda à frente e volte.", "Não deixe a lombar afundar."),
        bw("bicycle", "Abdominal bicicleta", [.abs, .obliques], [], met: 3.8,
           "Leve o cotovelo ao joelho oposto alternando.", "Movimento lento e controlado."),
        bw("mountain-climber", "Escalador (mountain climber)", [.abs], [.shoulders, .quads, .cardio], met: 8,
           "Em prancha alta, traga os joelhos ao peito alternando rápido.", "Ótimo para condicionamento."),
        bw("burpee", "Burpee", [.quads, .chest], [.shoulders, .abs, .cardio], met: 8,
           "Agache, jogue as pernas para trás, flexão, volte e salte.", "Exercício de corpo inteiro e cardio."),

        // CARDIO
        cardio("walk", "Caminhada", .other, met: 3.5, "Caminhe em ritmo moderado (~5 km/h).", "Registre minutos e km."),
        cardio("walk-incline", "Caminhada inclinada na esteira", .cardioMachine, met: 6,
               "Esteira com inclinação de 8–12% em ritmo de caminhada.", "Ótimo gasto calórico com baixo impacto."),
        cardio("run", "Corrida", .other, met: 9.8, "Corrida contínua em ritmo moderado (~10 km/h).", "Aumente o volume no máximo 10% por semana."),
        cardio("treadmill", "Corrida na esteira", .cardioMachine, met: 9, "Esteira em ritmo de corrida.", "1% de inclinação simula a rua."),
        cardio("hiit", "HIIT (intervalado)", .other, met: 8, "Alterne tiros intensos com recuperação (ex.: 30 s/60 s).", "1–2x por semana é suficiente."),
        cardio("bike", "Bicicleta ergométrica", .cardioMachine, met: 7, "Pedale em intensidade moderada.", "Ajuste o banco na altura do quadril."),
        cardio("cycling", "Ciclismo", .other, met: 7.5, "Pedal ao ar livre em ritmo moderado.", "Use capacete."),
        cardio("elliptical", "Elíptico (transport)", .cardioMachine, met: 5, "Movimento contínuo no elíptico.", "Baixo impacto nas articulações."),
        cardio("rowing", "Remo ergômetro", .cardioMachine, met: 7, "Empurre com as pernas, depois puxe com os braços.", "60% pernas, 20% tronco, 20% braços."),
        cardio("stairs", "Escada / simulador de escada", .cardioMachine, met: 9, "Suba degraus em ritmo constante.", "Não se apoie no corrimão."),
        cardio("jump-rope", "Pular corda", .other, met: 11, "Saltos baixos e rítmicos.", "Excelente para coordenação."),
        cardio("swim", "Natação", .other, met: 7, "Nado contínuo em ritmo moderado.", "Trabalha o corpo todo sem impacto."),
        cardio("soccer", "Futebol", .other, met: 7, "Partida recreativa.", "Registre a duração."),
        cardio("dance", "Dança", .other, met: 5, "Aula ou dança livre.", "Ótimo para humor e saúde mental."),
        cardio("yoga", "Yoga", .other, met: 3, "Sequência de posturas com respiração.", "Ajuda flexibilidade, estresse e sono."),
        cardio("stretch", "Alongamento / mobilidade", .other, met: 2.3, "Rotina de alongamento.", "Ideal ao fim do treino ou em dias de descanso."),
    ]

    static let byID: [String: Exercise] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    /// Nome + músculos já normalizados (sem acento, minúsculo), calculado uma vez.
    private static let searchKeys: [String: String] = Dictionary(uniqueKeysWithValues: all.map {
        ($0.id, FoodDatabase.normalize($0.name + " " + $0.primary.map(\.label).joined(separator: " ")))
    })

    static func search(_ q: String, muscle: Muscle? = nil, equipment: Equipment? = nil) -> [Exercise] {
        let words = FoodDatabase.normalize(q).split(separator: " ").map(String.init)
        return all.filter { e in
            if let muscle, !e.allMuscles.contains(muscle) { return false }
            if let equipment, e.equipment != equipment { return false }
            guard !words.isEmpty, let key = searchKeys[e.id] else { return true }
            return words.allSatisfy { key.contains($0) }
        }
    }
}
