import Foundation

/// Quanto peso a pessoa realmente move num exercício, considerando a física do equipamento.
struct LoadModel {
    /// Fração do peso registrado que vira resistência real (ex.: leg press 45° ≈ sen 45° = 0,71).
    var factor: Double = 1
    /// Fração do peso corporal que também é movida (ex.: flexão ≈ 64–75% do corpo).
    var bodyFraction: Double = 0
    /// Peso registrado é por halter/lado (o total é o dobro).
    var perSide = false
    /// Explicação da física.
    var note: String

    func real(kg: Double, bodyKg: Double) -> Double {
        kg * factor * (perSide ? 2 : 1) + bodyKg * bodyFraction
    }
}

extension Exercise {
    var load: LoadModel {
        switch id {
        // Máquinas inclinadas: a componente da gravidade no trilho é peso × sen(ângulo).
        case "leg-press":
            return LoadModel(factor: 0.71, note: "No leg press 45° o trilho é inclinado: a força que suas pernas fazem é peso × sen 45° ≈ 71% das anilhas. O carrinho (40–70 kg, varia por marca) também entra, e o atrito do trilho tira um pouco. Ex.: 100 kg de anilhas ≈ 71 kg + ~35 kg do carrinho.")
        case "hack-squat":
            return LoadModel(factor: 0.71, bodyFraction: 0.85 * 0.71, note: "No hack (≈45°) você empurra ~71% das anilhas e do carrinho, mais ~71% do seu corpo acima das canelas, que também desliza no trilho.")
        case "smith-squat":
            return LoadModel(bodyFraction: 0.85, note: "A barra guiada é 100% vertical. Algumas Smith têm contrapeso (barra pesando 7–15 kg em vez de 20). Você também levanta ~85% do seu corpo (tudo acima das canelas).")
        // Agachamentos e afundos: o corpo acima das pernas também é carga.
        case "squat", "front-squat":
            return LoadModel(bodyFraction: 0.85, note: "Além da barra, você levanta ~85% do próprio corpo (tudo exceto canelas e pés). Ex.: 60 kg na barra + 70 kg de corpo ≈ 120 kg movidos pelas pernas.")
        case "goblet-squat":
            return LoadModel(bodyFraction: 0.85, note: "Halter + ~85% do seu peso corporal.")
        case "lunge", "bulgarian":
            return LoadModel(bodyFraction: 0.85, perSide: true, note: "Registre o peso de um halter (o total é o dobro). A perna da frente sustenta a maior parte (~80–90%) do corpo + halteres, por isso é tão intenso com pouca carga.")
        case "stepup":
            return LoadModel(bodyFraction: 0.95, perSide: true, note: "Uma perna eleva praticamente todo o seu corpo + os dois halteres (registre o peso de um).")
        case "sumo-deadlift", "deadlift":
            return LoadModel(bodyFraction: 0.1, note: "A barra é carga 100% vertical; o tronco também é erguido (~10% extra efetivo). Registre o total (barra 20 kg + anilhas).")
        case "rdl":
            return LoadModel(bodyFraction: 0.25, note: "Barra + o tronco que você inclina e levanta (~25–30% do corpo pesa sobre os posteriores).")
        case "hip-thrust":
            return LoadModel(bodyFraction: 0.45, note: "Barra + ~45% do corpo (quadril e coxas), que também é elevado.")
        case "glute-bridge":
            return LoadModel(bodyFraction: 0.45, note: "Você eleva ~45% do corpo (quadril, coxas e parte do tronco).")
        case "standing-calf":
            return LoadModel(bodyFraction: 1.0, note: "Em pé você eleva TODO o seu corpo + a carga da máquina. Por isso a panturrilha aguenta tanto peso.")
        case "seated-calf":
            return LoadModel(note: "Sentado, só a carga sobre os joelhos conta (o corpo não é erguido).")
        case "kb-swing":
            return LoadModel(factor: 1.0, note: "A força no fundo do movimento chega a 2–3× o peso do kettlebell por causa da aceleração.")
        // Peso corporal
        case "pushup":
            return LoadModel(bodyFraction: 0.69, note: "Na flexão você empurra ~64% (topo) a ~75% (embaixo) do seu peso (Ebben et al., 2011). Com joelhos no chão, ~49%.")
        case "pullup", "chinup":
            return LoadModel(bodyFraction: 0.95, note: "Você ergue ~95% do corpo (menos mãos e antebraços) + qualquer peso extra registrado.")
        case "dips-chest":
            return LoadModel(bodyFraction: 0.95, note: "Você empurra ~95% do corpo + peso extra.")
        case "bench-dips":
            return LoadModel(bodyFraction: 0.55, note: "Com pés no chão, os braços sustentam ~50–60% do corpo. Pés elevados aumentam a carga.")
        case "bw-squat", "jump-squat", "burpee":
            return LoadModel(bodyFraction: 0.85, note: "As pernas movem ~85% do seu corpo a cada repetição.")
        case "crunch", "bicycle", "russian-twist":
            return LoadModel(bodyFraction: 0.30, note: "O abdômen eleva o tronco superior (~30% do corpo) — a resistência real é pequena, por isso valem mais repetições ou carga extra.")
        case "leg-raise", "hanging-knee":
            return LoadModel(bodyFraction: 0.35, note: "As pernas pesam ~35% do corpo; com pernas estendidas o braço de alavanca dobra a dificuldade.")
        case "hyperextension":
            return LoadModel(bodyFraction: 0.5, note: "A lombar e os glúteos elevam ~50% do corpo (tronco + cabeça + braços).")
        case "plank", "side-plank", "mountain-climber":
            return LoadModel(bodyFraction: 0.6, note: "Os apoios sustentam o corpo; o core mantém ~60% do peso alinhado contra a gravidade.")
        case "farmer-walk":
            return LoadModel(perSide: true, note: "Registre o peso de uma mão; você carrega o dobro + o próprio corpo a cada passo.")
        case "ab-wheel":
            return LoadModel(bodyFraction: 0.5, note: "Ajoelhado, o core controla ~50% do corpo em alavanca longa; em pé, muito mais.")
        // Cabos e polias
        case "lat-pulldown", "lat-pulldown-close", "seated-row", "triceps-pushdown", "triceps-rope", "cable-curl",
             "cable-cross", "face-pull", "pullover", "cable-crunch", "cable-kickback", "cable-lateral":
            return LoadModel(note: "Em polias 1:1 o peso da placa é a resistência real. Algumas máquinas usam polia dupla (2:1): aí a resistência é metade do número da placa. A roldana tem atrito de ~5–10%.")
        // Halteres (registro por halter)
        case "bench-db", "incline-db", "fly-db", "db-press", "lateral-raise", "front-raise", "rear-delt-fly", "db-curl",
             "hammer-curl", "incline-curl", "shrug", "arnold-press":
            return LoadModel(perSide: true, note: notesFor(id))
        case "db-row", "concentration-curl", "overhead-ext", "kickback", "wrist-curl":
            return LoadModel(note: notesFor(id))
        default:
            switch equipment {
            case .machine:
                return LoadModel(note: "Em máquinas com alavancas e cames, o número da placa não é o peso real: o braço de alavanca muda a resistência ao longo do movimento (pode ser 50–120% da placa). Compare cargas só na mesma máquina.")
            case .barbell:
                return LoadModel(note: "Barra livre: a carga é 100% real e vertical. Registre o total (barra olímpica 20 kg, barra W ~10 kg + anilhas).")
            case .bodyweight:
                return LoadModel(bodyFraction: 0.5, note: "Parte do seu peso corporal é a resistência.")
            default:
                return LoadModel(note: "A carga registrada é a resistência real.")
            }
        }
    }

    private func notesFor(_ id: String) -> String {
        switch id {
        case "lateral-raise", "front-raise", "rear-delt-fly", "fly-db":
            return "Registre o peso de um halter. Com o braço estendido o torque no ombro é alto: 10 kg a ~60 cm do ombro equivalem a ~6 kg·m — por isso cargas pequenas já são pesadas. A resistência é máxima com o braço na horizontal."
        case "db-curl", "hammer-curl", "incline-curl", "concentration-curl":
            return "Registre o peso de um halter. A resistência é máxima com o antebraço na horizontal (meio do movimento) e quase zero no topo."
        case "overhead-ext", "kickback":
            return "Um halter. No tríceps francês a cabeça longa é alongada, gerando mais estímulo com menos carga."
        default:
            return "Registre o peso de um halter (o total movido é o dobro nos exercícios com dois halteres)."
        }
    }
}
