import Foundation

/// Exercícios extras (foco em máquinas, cabos e variações), com ajuste do aparelho e erros comuns.
enum ExerciseLibrary {
    private static func x(_ id: String, _ name: String, _ p: [Muscle], _ sec: [Muscle], _ eq: Equipment, met: Double = 5.0,
                          _ how: String, _ tip: String, setup: String = "", _ mistakes: [String] = []) -> Exercise {
        Exercise(id: id, name: name, primary: p, secondary: sec, equipment: eq, kind: .strength, met: met,
                 howTo: how, tip: tip, setup: setup, mistakes: mistakes)
    }
    private static func b(_ id: String, _ name: String, _ p: [Muscle], _ sec: [Muscle], met: Double = 5.0,
                          _ how: String, _ tip: String, _ mistakes: [String] = []) -> Exercise {
        Exercise(id: id, name: name, primary: p, secondary: sec, equipment: .bodyweight, kind: .bodyweight, met: met,
                 howTo: how, tip: tip, mistakes: mistakes)
    }
    private static func t(_ id: String, _ name: String, _ p: [Muscle], _ sec: [Muscle], _ eq: Equipment = .bodyweight,
                          met: Double = 4.0, _ how: String, _ tip: String, _ mistakes: [String] = []) -> Exercise {
        Exercise(id: id, name: name, primary: p, secondary: sec, equipment: eq, kind: .timed, met: met,
                 howTo: how, tip: tip, mistakes: mistakes)
    }

    static let extra: [Exercise] = [
        // MARK: PEITO
        x("incline-machine", "Supino inclinado na máquina", [.chest], [.shoulders, .triceps], .machine,
          "Sente com as costas apoiadas e empurre as pegadas para cima e à frente até quase estender. Volte devagar até alongar o peito.",
          "Pense em aproximar os cotovelos um do outro ao empurrar para sentir mais o peitoral superior.",
          setup: "Ajuste o banco para as pegadas ficarem na altura da parte alta do peito.",
          ["Tirar as escápulas do banco no fim", "Descer rápido demais", "Banco muito baixo, virando desenvolvimento"]),
        x("decline-machine", "Supino declinado na máquina", [.chest], [.triceps], .machine,
          "Empurre as pegadas para baixo e à frente, estendendo os braços, e volte controlando.",
          "Bom substituto do declinado com barra, sem precisar de ajudante.",
          setup: "Pegadas alinhadas com a parte baixa do peito.", ["Encolher os ombros", "Amplitude curta"]),
        x("smith-bench", "Supino reto no Smith", [.chest], [.triceps, .shoulders], .machine, met: 6,
          "Deitado no banco, destrave a barra, desça até o peito e empurre na linha guiada.",
          "Posicione o banco para a barra tocar a linha dos mamilos.",
          setup: "Banco centralizado sob a barra; trave de segurança logo abaixo do peito.",
          ["Banco desalinhado (barra no pescoço ou na barriga)", "Quicar a barra no peito"]),
        x("smith-incline", "Supino inclinado no Smith", [.chest], [.shoulders, .triceps], .machine, met: 6,
          "Banco a 30°. Desça a barra até a parte alta do peito e empurre.", "Ótimo para treinar perto da falha com segurança.",
          setup: "Banco a 30° e posicionado para a barra descer na clavícula baixa.", ["Inclinação acima de 45°", "Cotovelos totalmente abertos a 90°"]),
        x("cable-fly-low", "Crucifixo na polia baixa (de baixo para cima)", [.chest], [.shoulders], .cable,
          "Polias embaixo. Com braços semiflexionados, traga as mãos para cima e para o centro até a altura do queixo.",
          "Ênfase na porção superior do peitoral.", setup: "Polias na posição mais baixa; um passo à frente.",
          ["Flexionar demais os cotovelos (vira rosca)", "Usar impulso do corpo"]),
        x("cable-fly-mid", "Crucifixo na polia média", [.chest], [.shoulders], .cable,
          "Polias na altura do peito. Feche os braços em arco à frente do peito e volte alongando.",
          "Mantenha o peito aberto e os ombros para trás.", setup: "Polias na altura dos ombros.",
          ["Ombros indo para frente no fim", "Abrir além do confortável"]),
        x("cable-press", "Supino em pé na polia", [.chest], [.triceps, .shoulders], .cable,
          "De costas para a polia, em base afastada, empurre as manoplas à frente até estender e volte.",
          "Tensão constante, ótimo como finalizador.", setup: "Polias na altura do peito.", ["Arquear a lombar", "Perder o equilíbrio por base curta"]),
        x("single-cable-fly", "Crucifixo unilateral na polia", [.chest], [.shoulders], .cable,
          "Um braço por vez, leve a mão cruzando a frente do corpo até passar da linha média.",
          "Cruzar a linha média aumenta a contração.", setup: "Polia na altura do ombro.", ["Girar o tronco junto"]),
        x("svend-press", "Svend press (anilha)", [.chest], [.shoulders], .other,
          "Aperte uma anilha entre as palmas na frente do peito e estenda os braços à frente, sem parar de apertar.",
          "A força de apertar é o que trabalha o peito.", ["Parar de pressionar as mãos"]),
        x("floor-press", "Supino no chão com halteres", [.chest], [.triceps], .dumbbell,
          "Deitado no chão, desça até os cotovelos tocarem o chão e empurre.", "Protege ombros sensíveis e fortalece o final do movimento.",
          ["Bater os cotovelos com força no chão"]),
        x("db-pullover", "Pullover com halter", [.chest], [.back, .triceps], .dumbbell,
          "Deitado no banco, halter acima do peito, desça-o atrás da cabeça em arco e volte.", "Cotovelos levemente flexionados e fixos.",
          ["Descer além da mobilidade do ombro", "Dobrar e esticar os cotovelos"]),
        b("incline-pushup", "Flexão inclinada (mãos elevadas)", [.chest], [.triceps, .shoulders],
          "Mãos num banco, corpo reto, desça o peito até o banco e empurre.", "Versão mais fácil para iniciantes.", ["Quadril caído"]),
        b("decline-pushup", "Flexão declinada (pés elevados)", [.chest], [.shoulders, .triceps],
          "Pés num banco, mãos no chão, desça e empurre.", "Mais difícil e foca o peitoral superior.", ["Quadril alto demais"]),
        b("diamond-pushup", "Flexão diamante", [.triceps], [.chest],
          "Mãos juntas formando um losango sob o peito; desça e empurre.", "Ênfase no tríceps.", ["Cotovelos abrindo para fora"]),

        // MARK: COSTAS
        x("lat-pulldown-wide", "Puxada aberta (pegada larga)", [.back], [.biceps], .cable,
          "Pegada bem aberta, puxe a barra até o alto do peito levando os cotovelos para baixo e para trás.",
          "Peito estufado em direção à barra.", setup: "Almofada das coxas firme, sem folga.",
          ["Puxar atrás da nuca", "Balançar o tronco para trás", "Puxar só com os braços"]),
        x("lat-pulldown-under", "Puxada supinada", [.back], [.biceps], .cable,
          "Pegada supinada na largura dos ombros, puxe até o peito.", "Mais bíceps e amplitude para o grande dorsal.",
          setup: "Coxas presas sob a almofada.", ["Encolher os ombros no topo"]),
        x("single-arm-pulldown", "Puxada unilateral na polia", [.back], [.biceps], .cable,
          "Ajoelhado ou sentado, puxe a manopla com um braço trazendo o cotovelo até a cintura.", "Corrige assimetrias.",
          setup: "Polia alta com manopla simples.", ["Girar o tronco"]),
        x("straight-arm-pulldown", "Pulldown com braços estendidos", [.back], [.triceps], .cable,
          "Em pé, braços quase estendidos, leve a barra da altura da cabeça até as coxas em arco.",
          "Isola o dorsal sem usar o bíceps.", setup: "Polia alta com barra reta ou corda.", ["Dobrar os cotovelos", "Curvar a lombar"]),
        x("machine-pulldown", "Puxada na máquina articulada", [.back], [.biceps], .machine,
          "Puxe as pegadas para baixo levando os cotovelos às costelas e volte devagar.", "Permite treinar cada lado separado.",
          setup: "Banco ajustado para alcançar as pegadas com braços estendidos.", ["Tirar o quadril do banco"]),
        x("assisted-pullup", "Barra fixa assistida (gravitron)", [.back], [.biceps], .machine,
          "Joelhos na plataforma, puxe o corpo até o queixo passar da barra.", "Reduza a assistência com o tempo.",
          setup: "Quanto mais peso no pino, mais ajuda.", ["Meia repetição", "Soltar o corpo na descida"]),
        x("chest-supported-row", "Remada com apoio no peito (máquina)", [.back], [.biceps, .traps], .machine,
          "Peito na almofada, puxe as pegadas levando os cotovelos para trás e junte as escápulas.",
          "Elimina o roubo da lombar.", setup: "Altura do banco: pegadas na linha da parte baixa do peito.",
          ["Tirar o peito do apoio", "Encolher os ombros"]),
        x("low-row-machine", "Remada baixa articulada", [.back], [.biceps], .machine,
          "Puxe as pegadas em direção ao abdômen, cotovelos junto ao corpo.", "Foco no dorsal inferior.",
          setup: "Pés firmes; braço estendido sem tirar o peito do apoio.", ["Jogar o tronco para trás"]),
        x("high-row-machine", "Remada alta articulada", [.back], [.traps, .biceps], .machine,
          "Puxe as pegadas de cima para baixo e para trás, cotovelos abertos.", "Trabalha dorsal superior e romboides.",
          setup: "Banco para as pegadas ficarem acima da cabeça.", ["Amplitude curta"]),
        x("seated-row-wide", "Remada sentada com pegada aberta", [.back], [.traps, .shoulders], .cable,
          "Barra larga, puxe até o peito com cotovelos abertos, juntando as escápulas.", "Mais ênfase em romboides e deltoide posterior.",
          setup: "Joelhos levemente flexionados.", ["Balançar o tronco"]),
        x("seal-row", "Remada seal (deitado no banco)", [.back], [.biceps], .barbell,
          "Deitado de bruços num banco alto, puxe a barra até o banco.", "Zero ajuda da lombar.", ["Levantar o peito do banco"]),
        x("pendlay-row", "Remada Pendlay", [.back], [.biceps, .lowerBack], .barbell, met: 6,
          "Tronco paralelo ao chão, puxe a barra do chão até o abdômen e devolva ao chão a cada repetição.", "Explosiva e estrita.",
          ["Levantar o tronco ao puxar", "Lombar arredondada"]),
        x("meadows-row", "Remada Meadows", [.back], [.biceps], .barbell,
          "De lado para uma barra presa no canto (landmine), puxe a ponta com uma mão.", "Ótimo alongamento do dorsal.", ["Rodar o tronco"]),
        x("smith-row", "Remada curvada no Smith", [.back], [.biceps], .machine,
          "Tronco inclinado, puxe a barra guiada até o abdômen.", "Mais estável que a barra livre.", ["Lombar arredondada"]),
        x("rack-pull", "Rack pull (terra parcial)", [.back], [.lowerBack, .traps, .glutes], .barbell, met: 6,
          "Barra apoiada no rack na altura dos joelhos; estenda o quadril levantando-a.", "Sobrecarga para a parte final do terra.",
          ["Hiperestender a lombar no topo"]),
        x("good-morning", "Bom dia (good morning)", [.hamstrings], [.lowerBack, .glutes], .barbell,
          "Barra nas costas, joelhos semiflexionados, incline o tronco à frente levando o quadril para trás e volte.", "Comece leve.",
          ["Arredondar a coluna", "Carga alta cedo demais"]),
        x("back-extension-machine", "Extensão lombar na máquina", [.lowerBack], [.glutes], .machine,
          "Sentado, empurre o encosto para trás estendendo o tronco e volte.", "Movimento lento e controlado.",
          setup: "Rolo na altura das escápulas; cinto no quadril.", ["Hiperestender demais"]),
        x("machine-shrug", "Encolhimento na máquina", [.traps], [], .machine,
          "Eleve os ombros em direção às orelhas, segure 1 segundo e desça.", "Não gire os ombros.", ["Usar os braços", "Girar os ombros"]),
        x("barbell-shrug", "Encolhimento com barra", [.traps], [.forearms], .barbell,
          "Barra à frente das coxas, eleve os ombros e desça devagar.", "Use straps se a pegada falhar.", ["Dobrar os cotovelos"]),
        b("inverted-row", "Remada invertida", [.back], [.biceps],
          "Sob uma barra baixa, corpo reto, puxe o peito até a barra.", "Pés mais à frente = mais difícil.", ["Quadril caído"]),

        // MARK: OMBROS
        x("smith-press", "Desenvolvimento no Smith", [.shoulders], [.triceps], .machine,
          "Sentado, desça a barra até o queixo e empurre para cima.", "Banco levemente à frente da barra.",
          setup: "Encosto a 80–90°.", ["Descer atrás da nuca", "Arquear a lombar"]),
        x("machine-lateral", "Elevação lateral na máquina", [.shoulders], [], .machine,
          "Braços nas almofadas, eleve-os lateralmente até a altura dos ombros.", "Tensão constante no deltoide lateral.",
          setup: "Eixo da máquina alinhado com o ombro.", ["Encolher o trapézio", "Subir acima da linha do ombro"]),
        x("rear-delt-machine", "Voador inverso (deltoide posterior)", [.shoulders], [.traps], .machine,
          "De frente para o encosto, abra os braços para trás com cotovelos levemente flexionados.", "Pense em levar as mãos longe, não para trás.",
          setup: "Pegadas na altura dos ombros; braços para a posição posterior.", ["Juntar as escápulas demais (vira trapézio)"]),
        x("cable-rear-fly", "Crucifixo inverso na polia", [.shoulders], [.traps], .cable,
          "Cabos cruzados na altura dos ombros, abra os braços para trás.", "Use cargas leves.", setup: "Polias na altura dos ombros, cabos cruzados.",
          ["Usar o tronco"]),
        x("cable-front-raise", "Elevação frontal na polia", [.shoulders], [], .cable,
          "De costas para a polia baixa, eleve o cabo à frente até a altura dos ombros.", "Raramente necessário se já faz supino.", ["Balançar o corpo"]),
        x("cable-upright-row", "Remada alta na polia", [.shoulders], [.traps], .cable,
          "Puxe a barra até a linha do peito com os cotovelos acima das mãos.", "Não suba além do peito para poupar o ombro.", ["Pegada fechada demais"]),
        x("db-shoulder-seated", "Desenvolvimento sentado com halteres (neutro)", [.shoulders], [.triceps], .dumbbell,
          "Palmas uma de frente para a outra, empurre os halteres para cima.", "Pegada neutra é mais amigável ao ombro.", ["Bater os halteres no topo"]),
        x("landmine-press", "Landmine press", [.shoulders], [.chest, .triceps], .barbell,
          "Segure a ponta da barra no ombro e empurre para cima e à frente.", "Bom para quem sente o ombro no desenvolvimento.", ["Arquear a lombar"]),
        x("lu-raise", "Elevação Y (Lu raise)", [.shoulders], [.traps], .dumbbell,
          "Com halteres leves, eleve os braços à frente e acima da cabeça em Y.", "Use carga bem leve.", ["Carga pesada"]),
        x("incline-lateral", "Elevação lateral deitado no banco inclinado", [.shoulders], [], .dumbbell,
          "Deitado de lado num banco inclinado, eleve o halter lateralmente.", "Mais tensão no início do movimento.", ["Girar o tronco"]),
        b("pike-pushup", "Flexão pike", [.shoulders], [.triceps],
          "Quadril elevado em V invertido, desça a cabeça em direção ao chão e empurre.", "Progressão para parada de mão.", ["Cotovelos abertos"]),

        // MARK: BÍCEPS
        x("machine-curl", "Rosca na máquina", [.biceps], [], .machine,
          "Braços no apoio, flexione os cotovelos e desça devagar.", "Ótimo para falha segura.",
          setup: "Cotovelo alinhado com o eixo da máquina.", ["Tirar os cotovelos do apoio"]),
        x("cable-curl-bar", "Rosca na polia com barra W", [.biceps], [.forearms], .cable,
          "Polia baixa, flexione até perto dos ombros mantendo os cotovelos fixos.", "Tensão constante.", ["Cotovelos indo à frente"]),
        x("bayesian-curl", "Rosca bayesiana (polia atrás)", [.biceps], [], .cable,
          "De costas para a polia baixa, braço para trás, flexione o cotovelo.", "Treina o bíceps alongado.",
          setup: "Polia baixa, um passo à frente.", ["Levar o ombro à frente"]),
        x("cable-hammer", "Rosca martelo na corda", [.biceps], [.forearms], .cable,
          "Corda na polia baixa, pegada neutra, flexione os cotovelos.", "Braquial e antebraço.", ["Balançar"]),
        x("ez-curl", "Rosca com barra W", [.biceps], [.forearms], .barbell,
          "Pegada na barra W, flexione até os ombros e desça controlando.", "Mais confortável para os punhos.", ["Jogar o quadril"]),
        x("spider-curl", "Rosca spider", [.biceps], [], .dumbbell,
          "De bruços num banco inclinado, braços pendurados, flexione.", "Ótima contração no topo.", ["Mover os ombros"]),
        x("reverse-curl", "Rosca inversa", [.forearms], [.biceps], .barbell,
          "Pegada pronada, flexione os cotovelos.", "Antebraço e braquiorradial.", ["Punhos dobrando"]),
        x("drag-curl", "Rosca drag", [.biceps], [], .barbell,
          "Arraste a barra rente ao corpo levando os cotovelos para trás.", "Foco na cabeça longa.", ["Afastar a barra do corpo"]),
        x("preacher-machine", "Rosca Scott na máquina", [.biceps], [], .machine,
          "Braços no apoio, flexione e desça controlando até quase estender.", "Não estenda bruscamente.",
          setup: "Banco com axilas encostadas no topo do apoio.", ["Estender com tranco"]),

        // MARK: TRÍCEPS
        x("triceps-machine", "Tríceps na máquina", [.triceps], [], .machine,
          "Empurre as pegadas para baixo estendendo os cotovelos.", "Cotovelos fixos.", setup: "Cotovelos alinhados ao eixo.", ["Usar o ombro"]),
        x("dip-machine", "Mergulho na máquina", [.triceps], [.chest], .machine,
          "Empurre as pegadas para baixo até estender os braços.", "Tronco ereto para focar no tríceps.", ["Encolher os ombros"]),
        x("overhead-cable-ext", "Tríceps francês na polia (corda)", [.triceps], [], .cable,
          "De costas para a polia, corda atrás da cabeça, estenda os braços à frente e acima.", "Cabeça longa alongada.",
          setup: "Polia baixa ou média.", ["Abrir os cotovelos"]),
        x("single-pushdown", "Tríceps unilateral na polia", [.triceps], [], .cable,
          "Com uma manopla, estenda o cotovelo para baixo.", "Corrige assimetrias.", ["Mover o ombro"]),
        x("reverse-pushdown", "Tríceps na polia com pegada supinada", [.triceps], [], .cable,
          "Pegada supinada na barra, estenda os cotovelos.", "Ênfase na cabeça medial.", ["Carga alta demais"]),
        x("jm-press", "JM press", [.triceps], [.chest], .barbell,
          "Híbrido de supino fechado e testa: desça a barra em direção ao queixo e empurre.", "Exercício avançado.", ["Descer rápido"]),
        x("db-skull", "Tríceps testa com halteres", [.triceps], [], .dumbbell,
          "Deitado, desça os halteres ao lado da cabeça flexionando os cotovelos e estenda.", "Mais liberdade para os punhos.", ["Cotovelos abrindo"]),
        x("smith-close-bench", "Supino fechado no Smith", [.triceps], [.chest], .machine,
          "Pegada na largura dos ombros, desça até o peito e empurre.", "Mais seguro para ir à falha.", ["Pegada fechada demais"]),
        b("dips-triceps", "Paralelas com tronco ereto", [.triceps], [.chest, .shoulders],
          "Corpo vertical, desça até os cotovelos a 90° e suba.", "Ereto = mais tríceps.", ["Descer demais com ombro sensível"]),

        // MARK: ANTEBRAÇO
        x("reverse-wrist-curl", "Rosca de punho inversa", [.forearms], [], .dumbbell,
          "Antebraços apoiados, palmas para baixo, eleve os punhos.", "Extensores do antebraço.", ["Carga alta"]),
        t("dead-hang", "Suspensão na barra (dead hang)", [.forearms], [.back], .bodyweight,
          "Pendure-se na barra com braços estendidos pelo máximo de tempo.", "Melhora pegada e descomprime a coluna.", ["Soltar os ombros totalmente se houver dor"]),
        t("plate-pinch", "Pinça de anilhas", [.forearms], [], .other,
          "Segure duas anilhas lisas juntas com os dedos pelo tempo máximo.", "Fortalece a pinça.", []),

        // MARK: QUADRÍCEPS
        x("leg-press-horizontal", "Leg press horizontal", [.quads], [.glutes], .machine,
          "Sentado, empurre a plataforma até quase estender os joelhos e volte até 90°.", "Bom para iniciantes.",
          setup: "Encosto para os joelhos chegarem a ~90° sem tirar o quadril.", ["Travar os joelhos", "Tirar o quadril do banco"]),
        x("leg-press-narrow", "Leg press com pés fechados e baixos", [.quads], [], .machine,
          "Pés juntos na parte baixa da plataforma; desça até onde o quadril não sai do banco.", "Mais ênfase no quadríceps.",
          setup: "Pés na metade inferior da plataforma.", ["Calcanhar saindo da plataforma"]),
        x("leg-press-single", "Leg press unilateral", [.quads], [.glutes], .machine,
          "Uma perna de cada vez, desça controlando e empurre.", "Corrige diferenças entre as pernas.", ["Joelho entrando para dentro"]),
        x("pendulum-squat", "Agachamento pêndulo", [.quads], [.glutes], .machine,
          "Ombros nas almofadas, desça fundo mantendo as costas apoiadas e empurre.", "Muito quadríceps com pouca carga na lombar.",
          setup: "Pés no meio da plataforma, largura do quadril.", ["Amplitude curta", "Calcanhar saindo"]),
        x("v-squat", "Agachamento V-squat", [.quads], [.glutes], .machine,
          "De frente para a máquina, ombros sob as almofadas, desça e suba.", "Alternativa ao hack.", ["Joelho para dentro"]),
        x("belt-squat", "Agachamento com cinto (belt squat)", [.quads], [.glutes], .machine,
          "Carga presa no cinto do quadril, agache sem carga na coluna.", "Ideal com dor lombar.", ["Inclinar o tronco à frente"]),
        x("reverse-hack", "Hack invertido", [.glutes], [.quads, .hamstrings], .machine,
          "De frente para o encosto, desça levando o quadril para trás e suba.", "Mais glúteo que o hack normal.", ["Arredondar a lombar"]),
        x("sissy-squat", "Sissy squat", [.quads], [], .bodyweight,
          "Apoiado, incline o corpo para trás flexionando os joelhos à frente e volte.", "Isola o reto femoral.", ["Descer rápido"]),
        x("single-leg-extension", "Cadeira extensora unilateral", [.quads], [], .machine,
          "Uma perna por vez, estenda o joelho e segure 1 segundo.", "Corrige assimetrias.",
          setup: "Eixo da máquina alinhado ao joelho; rolo acima do tornozelo.", ["Chutar com impulso"]),
        x("smith-lunge", "Afundo no Smith", [.quads], [.glutes], .machine,
          "Pé à frente, barra guiada nas costas, desça o joelho de trás e suba.", "Mais estável que o afundo livre.", ["Passada curta demais"]),
        x("walking-lunge", "Afundo andando", [.quads], [.glutes, .hamstrings], .dumbbell, met: 6,
          "Dê passos longos descendo o joelho de trás até perto do chão.", "Passos longos = mais glúteo.", ["Joelho da frente colapsando"]),
        x("reverse-lunge", "Afundo reverso", [.quads], [.glutes], .dumbbell,
          "Dê um passo para trás e desça; volte à posição inicial.", "Mais gentil com os joelhos.", ["Tronco caindo à frente"]),
        x("zercher-squat", "Agachamento Zercher", [.quads], [.glutes, .abs], .barbell, met: 6,
          "Barra na dobra dos cotovelos, agache mantendo o tronco ereto.", "Muito core.", ["Arredondar as costas"]),
        x("box-squat", "Agachamento no caixote", [.quads], [.glutes, .hamstrings], .barbell, met: 6,
          "Sente rapidamente no caixote mantendo a tensão e suba.", "Ensina profundidade.", ["Relaxar no caixote"]),
        x("heel-elevated-goblet", "Goblet com calcanhar elevado", [.quads], [.glutes], .dumbbell,
          "Calcanhares numa anilha, agache fundo com o halter no peito.", "Mais quadríceps e amplitude.", ["Tronco caindo"]),
        b("wall-sit", "Cadeirinha na parede", [.quads], [],
          "Costas na parede, joelhos a 90°, segure.", "Isométrico, ótimo para iniciantes.", ["Joelhos além dos pés"]),
        b("pistol-squat", "Agachamento pistola", [.quads], [.glutes],
          "Em uma perna, a outra estendida à frente, agache e suba.", "Use um apoio no início.", ["Calcanhar subindo"]),

        // MARK: POSTERIORES
        x("standing-leg-curl", "Flexora em pé (unilateral)", [.hamstrings], [], .machine,
          "Em pé, flexione um joelho levando o calcanhar ao glúteo.", "Isole uma perna por vez.",
          setup: "Joelho alinhado com o eixo da máquina.", ["Inclinar o quadril"]),
        x("nordic-curl", "Flexão nórdica", [.hamstrings], [], .bodyweight,
          "Ajoelhado, pés presos, desça o corpo à frente o mais devagar possível.", "Excelente para prevenir lesões.", ["Dobrar o quadril"]),
        x("db-rdl", "Stiff com halteres", [.hamstrings], [.glutes, .lowerBack], .dumbbell,
          "Halteres à frente das coxas, leve o quadril para trás descendo até alongar e volte.", "Halteres rentes às pernas.", ["Arredondar a lombar", "Dobrar demais os joelhos"]),
        x("single-rdl", "Stiff unilateral", [.hamstrings], [.glutes], .dumbbell,
          "Em uma perna, incline o tronco levando a outra perna para trás.", "Equilíbrio e glúteo médio.", ["Girar o quadril"]),
        x("cable-pull-through", "Pull-through na polia", [.glutes], [.hamstrings], .cable,
          "De costas para a polia baixa, corda entre as pernas, estenda o quadril.", "Ensina o movimento do quadril.", ["Puxar com os braços"]),
        x("glute-ham-raise", "Glute ham raise", [.hamstrings], [.glutes], .machine,
          "No banco GHD, desça o tronco à frente e suba flexionando os joelhos.", "Avançado.", ["Usar impulso"]),
        x("smith-rdl", "Stiff no Smith", [.hamstrings], [.glutes], .machine,
          "Barra guiada, quadril para trás até alongar os posteriores.", "Caminho fixo, mais estável.", ["Lombar arredondada"]),

        // MARK: GLÚTEOS
        x("hip-thrust-machine", "Elevação pélvica na máquina", [.glutes], [.hamstrings], .machine,
          "Costas no encosto, cinto no quadril, eleve o quadril e contraia.", "Segure 1 segundo no topo.",
          setup: "Pés afastados na largura do quadril; joelhos a 90° no topo.", ["Hiperestender a lombar", "Empurrar com a ponta dos pés"]),
        x("smith-hip-thrust", "Elevação pélvica no Smith", [.glutes], [.hamstrings], .machine,
          "Costas no banco, barra guiada no quadril, eleve e contraia.", "Use uma almofada na barra.", ["Queixo para cima"]),
        x("glute-kickback-machine", "Glúteo na máquina (coice)", [.glutes], [.hamstrings], .machine,
          "Empurre a plataforma para trás estendendo o quadril.", "Movimento curto e controlado.", ["Arquear a lombar"]),
        x("cable-abduction", "Abdução de quadril na polia", [.glutes], [], .cable,
          "Caneleira na polia baixa, afaste a perna lateralmente.", "Glúteo médio.", ["Inclinar o tronco"]),
        x("abductor-lean", "Abdutora com tronco inclinado", [.glutes], [], .machine,
          "Na abdutora, incline o tronco à frente e abra as pernas.", "Mais glúteo máximo.", ["Fechar rápido"]),
        x("frog-pump", "Frog pump", [.glutes], [], .bodyweight,
          "Deitado, solas dos pés juntas, eleve o quadril.", "Ótimo aquecimento de glúteo.", []),
        x("kb-deadlift", "Terra com kettlebell", [.glutes], [.hamstrings, .lowerBack], .kettlebell,
          "Kettlebell entre os pés, leve o quadril para trás, pegue e estenda o quadril.", "Bom para aprender o terra.", ["Agachar em vez de dobrar o quadril"]),
        b("donkey-kick", "Coice de glúteo no chão", [.glutes], [],
          "De quatro apoios, chute uma perna para cima com joelho flexionado.", "Contraia no topo.", ["Arquear a lombar"]),
        b("fire-hydrant", "Hidrante", [.glutes], [],
          "De quatro apoios, abra a perna lateralmente.", "Glúteo médio.", ["Girar o tronco"]),

        // MARK: ADUTORES E PANTURRILHAS
        x("cable-adduction", "Adução de quadril na polia", [.adductors], [], .cable,
          "Caneleira na polia, traga a perna para dentro cruzando à frente.", "Movimento controlado.", ["Usar o tronco"]),
        x("copenhagen", "Prancha Copenhagen", [.adductors], [.obliques], .bodyweight,
          "Prancha lateral com a perna de cima apoiada num banco.", "Previne lesões na virilha.", ["Quadril caindo"]),
        x("leg-press-calf", "Panturrilha no leg press", [.calves], [], .machine,
          "Pontas dos pés na borda da plataforma, empurre estendendo os tornozelos.", "Pause no alongamento.",
          setup: "Trave de segurança destravada só com pernas estendidas.", ["Dobrar os joelhos", "Amplitude curta"]),
        x("smith-calf", "Panturrilha no Smith", [.calves], [], .machine,
          "Pontas dos pés numa anilha, barra nas costas, suba e desça.", "Amplitude completa.", ["Quicar embaixo"]),
        x("single-calf", "Panturrilha unilateral com halter", [.calves], [], .dumbbell,
          "Num degrau, uma perna por vez, suba e desça.", "Segure-se em algo.", ["Pressa"]),
        x("donkey-calf", "Panturrilha burrinho", [.calves], [], .machine,
          "Tronco inclinado, quadril sob a almofada, eleve os calcanhares.", "Ótimo alongamento.", ["Dobrar os joelhos"]),
        x("tibialis-raise", "Elevação de tibial", [.calves], [], .bodyweight,
          "Costas na parede, calcanhares à frente, eleve as pontas dos pés.", "Protege os joelhos e canelas.", []),

        // MARK: ABDÔMEN
        x("ab-machine", "Abdominal na máquina", [.abs], [], .machine,
          "Segure as pegadas e flexione o tronco aproximando costelas e quadril.", "Expire ao contrair.",
          setup: "Peito sob as almofadas; carga que permita 10–15 reps.", ["Puxar com os braços", "Usar o quadril"]),
        x("decline-crunch", "Abdominal no banco declinado", [.abs], [], .bodyweight,
          "Pés presos, flexione o tronco sem subir tudo.", "Segure uma anilha para progredir.", ["Puxar a cabeça"]),
        x("cable-woodchop", "Lenhador na polia", [.obliques], [.abs, .shoulders], .cable,
          "Gire o tronco puxando o cabo da polia alta até o quadril oposto.", "Gire a partir do tronco, não dos braços.", ["Dobrar os cotovelos"]),
        x("pallof-press", "Pallof press", [.obliques], [.abs], .cable,
          "De lado para a polia, empurre a manopla à frente sem deixar o tronco girar.", "Anti-rotação.", ["Girar o tronco"]),
        x("captain-chair", "Elevação de pernas no apoio (cadeira romana)", [.abs], [.obliques], .machine,
          "Antebraços no apoio, eleve os joelhos até o peito.", "Encaixe o quadril no topo.", ["Balançar"]),
        b("hanging-leg-raise", "Elevação de pernas estendidas na barra", [.abs], [.forearms],
          "Pendurado, eleve as pernas estendidas até a altura do quadril ou mais.", "Avançado.", ["Balançar o corpo"]),
        b("dead-bug", "Dead bug", [.abs], [],
          "Deitado, braços e pernas para cima, estenda braço e perna opostos sem tirar a lombar do chão.", "Ótimo para o core profundo.", ["Lombar descolando"]),
        b("reverse-crunch", "Abdominal reverso", [.abs], [],
          "Deitado, leve os joelhos ao peito tirando o quadril do chão.", "Foco no abdômen inferior.", ["Usar impulso"]),
        t("hollow-hold", "Hollow hold", [.abs], [], .bodyweight,
          "Deitado, eleve pernas e ombros do chão formando uma banana e segure.", "Lombar colada no chão.", ["Lombar arqueada"]),
        b("v-up", "Abdominal canivete (V-up)", [.abs], [],
          "Eleve tronco e pernas ao mesmo tempo tocando os pés.", "Avançado.", ["Puxar com o pescoço"]),
        b("side-crunch", "Abdominal oblíquo", [.obliques], [.abs],
          "Deitado de lado ou com joelhos caídos, flexione o tronco lateralmente.", "Movimento curto.", []),
        t("bird-dog", "Bird dog", [.lowerBack], [.glutes, .abs], .bodyweight,
          "De quatro apoios, estenda braço e perna opostos e segure.", "Estabilidade da lombar.", ["Girar o quadril"]),
        t("suitcase-carry", "Caminhada com carga unilateral", [.obliques], [.forearms, .traps], .dumbbell,
          "Caminhe segurando um halter pesado em apenas uma mão, sem inclinar.", "Excelente para o core.", ["Inclinar para o lado"]),

        // MARK: CORPO TODO
        x("clean", "Arremesso (power clean)", [.quads], [.glutes, .back, .traps], .barbell, met: 8,
          "Puxe a barra do chão explosivamente e receba-a nos ombros.", "Aprenda com um treinador.", ["Puxar com os braços", "Lombar arredondada"]),
        x("thruster", "Thruster", [.quads], [.shoulders, .glutes], .barbell, met: 8,
          "Agachamento frontal seguido de desenvolvimento num só movimento.", "Muito condicionamento.", ["Perder a postura"]),
        x("kb-goblet-clean", "Clean com kettlebell", [.glutes], [.shoulders, .forearms], .kettlebell, met: 7,
          "Do balanço, traga o kettlebell até a posição de rack no ombro.", "Kettlebell gira em volta do punho.", ["Bater no antebraço"]),
        x("kb-snatch", "Snatch com kettlebell", [.shoulders], [.glutes, .hamstrings], .kettlebell, met: 8,
          "Do balanço, leve o kettlebell acima da cabeça num movimento.", "Avançado.", []),
        x("sled-push", "Empurrar trenó", [.quads], [.glutes, .calves], .other, met: 8,
          "Incline o corpo e empurre o trenó com passos curtos e fortes.", "Condicionamento sem impacto.", ["Tronco ereto demais"]),
        x("battle-rope", "Corda naval (battle rope)", [.shoulders], [.abs, .forearms], .other, met: 8,
          "Movimente as cordas em ondas alternadas rapidamente.", "Intervalos de 20–40 s.", ["Usar só os braços"]),
        x("medball-slam", "Arremesso de medicine ball no chão", [.abs], [.shoulders, .back], .other, met: 7,
          "Eleve a bola acima da cabeça e arremesse com força no chão.", "Potência e condicionamento.", []),
        b("box-jump", "Salto no caixote", [.quads], [.glutes, .calves], met: 8,
          "Salte sobre o caixote aterrissando suavemente.", "Desça andando, não pulando.", ["Aterrissar com joelhos para dentro"]),
        b("bear-crawl", "Engatinhar (bear crawl)", [.shoulders], [.abs, .quads], met: 6,
          "De quatro, joelhos fora do chão, ande para frente e para trás.", "Core e coordenação.", ["Quadril alto"]),
    ]
}

extension Exercise {
    enum Level: String { case beginner = "Iniciante", intermediate = "Intermediário", advanced = "Avançado" }

    var level: Level {
        if ["clean", "kb-snatch", "pistol-squat", "nordic-curl", "glute-ham-raise", "jm-press", "v-up",
            "hanging-leg-raise", "zercher-squat", "pendlay-row", "deadlift", "front-squat", "sumo-deadlift"].contains(id) { return .advanced }
        switch equipment {
        case .machine, .cable, .cardioMachine: return .beginner
        case .barbell: return .intermediate
        default: return isCompound ? .intermediate : .beginner
        }
    }

    var breathing: String {
        switch kind {
        case .strength, .bodyweight:
            "Inspire e trave o abdômen antes de descer (fase excêntrica); expire na parte mais difícil da subida. Em cargas altas, segure o ar durante a repetição."
        case .timed: "Respire curto e contínuo, sem prender o ar, mantendo o abdômen firme."
        case .cardio: "Respire em ritmo constante; se não consegue falar frases curtas, você está em alta intensidade."
        }
    }

    /// Erros comuns: os específicos do exercício + os gerais pelo equipamento.
    var allMistakes: [String] {
        guard kind == .strength || kind == .bodyweight else { return mistakes }
        var g: [String]
        switch equipment {
        case .machine: g = ["Banco ou almofadas mal ajustados", "Soltar o peso de volta sem controle"]
        case .cable: g = ["Usar impulso do corpo", "Deixar a carga 'bater' entre as repetições"]
        case .barbell, .dumbbell, .kettlebell: g = ["Carga maior que a técnica permite", "Encurtar a amplitude"]
        default: g = ["Pressa: faça a descida em 2–3 segundos"]
        }
        return mistakes + g.filter { !mistakes.contains($0) }
    }

    /// Passos numerados a partir do texto (uma frase por passo).
    var steps: [String] {
        howTo.split(separator: ".", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }
}
