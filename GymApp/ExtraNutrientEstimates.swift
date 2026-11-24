import Foundation

/// TACO e IBGE não analisam vitamina K, B5, biotina, colina, iodo, cromo e molibdênio.
/// Estes valores (por 100 g) são estimativas típicas de tabelas internacionais (USDA FoodData Central,
/// Dietary Reference Intakes) por tipo de alimento, aplicadas pela palavra-chave do nome.
enum ExtraNutrientEstimates {
    /// Ordem: vitamina K (µg), B5 (mg), biotina (µg), colina (mg), iodo (µg), cromo (µg), molibdênio (µg).
    private typealias V = (k: Double, b5: Double, bio: Double, cho: Double, iod: Double, cr: Double, mo: Double)

    /// A primeira regra cujo padrão aparecer no nome vence (as mais específicas vêm antes).
    private static let source: [(String, V)] = [
        (#"\bfigado|\bmiudo"#, (3, 7, 40, 330, 3, 2, 100)),
        (#"\bovo|\bgema|\bomelete"#, (0.3, 1.5, 20, 290, 50, 1, 10)),
        (#"\bclara"#, (0, 0.2, 7, 1, 7, 0, 1)),
        (#"couve.?flor"#, (16, 0.6, 1.5, 45, 0, 1, 2)),
        (#"\bsalsa\b|\bsalsinha|\bcheiro.verde"#, (1600, 0.4, 0, 13, 0, 0, 0)),
        (#"\bcouve|\bbertalha|\bmostarda (folha|crua)"#, (400, 0.1, 0.5, 10, 0, 0, 0)),
        (#"\bespinafre"#, (480, 0.1, 0.5, 19, 0, 0, 0)),
        (#"\bagriao|\brucula|\bchicoria|\bescarola|\bcatalonha|\bserralha"#, (200, 0.3, 0.5, 13, 0, 0, 0)),
        (#"\bbrocolis"#, (100, 0.6, 1, 19, 0, 11, 2)),
        (#"\balface|\bacelga"#, (110, 0.1, 0.5, 13, 0, 0, 0)),
        (#"\brepolho|\bcouve.de.bruxelas"#, (76, 0.2, 0.5, 11, 0, 1, 0)),
        (#"\bcebolinha|\balho.por|\bmanjericao|\bcoentro|\bhortela"#, (200, 0.2, 0, 6, 0, 0, 0)),
        (#"\bvagem|\bquiabo|\baspargo|\bpepino|\babobrinha|\bchuchu|\bjilo|\bberinjela|\bpimentao"#, (20, 0.2, 1, 8, 0, 1, 0)),
        (#"\balga|\bnori\b|\bkombu"#, (5, 0.5, 0, 0, 2000, 0, 0)),
        (#"\bsal\b"#, (0, 0, 0, 0, 2500, 0, 0)),
        (#"\bsalmao|\btruta"#, (0.1, 1.6, 5, 90, 30, 0, 0)),
        (#"\bsardinha|\bcavala|\barenque"#, (2, 0.6, 5, 75, 35, 0, 0)),
        (#"\batum"#, (0.3, 0.4, 2, 65, 15, 0, 0)),
        (#"\bcamarao|\blagosta|\bcaranguejo|\bsiri\b"#, (0, 0.3, 2, 135, 35, 0, 0)),
        (#"\bmarisco|\bostra|\bmexilhao|\blula|\bpolvo"#, (0.1, 0.5, 5, 65, 60, 0, 0)),
        (#"\bpeixe|\bpescada|\btilapia|\bmerluza|\bbacalhau|\bcacao|\bcorvina|\bpintado|\btambaqui|\bdourado|\bpiaba|\bpacu|\bsurubim|\bbagre|\blinguado|\bcacao"#,
            (0.1, 0.5, 2, 65, 50, 0, 0)),
        (#"\bfrango|\bgalinha|\bperu\b|\bpato\b|\bchester|\bsobrecoxa|\bcoxa\b|\bpeito\b"#, (2, 1.0, 2, 65, 7, 1, 1)),
        (#"\bbacon|\blinguica|\bpresunto|\bsalsicha|\bsalame|\bmortadela|\bapresuntado|\bcalabresa|\bpaio\b"#, (0.2, 0.6, 2, 60, 5, 1, 2)),
        (#"\bporco|\bsuin|\blombo|\bpernil|\bcopa\b|\btoucinho|\bleitao"#, (0, 0.7, 2, 70, 3, 1, 2)),
        (#"\bcarne|\bbovin|\bboi\b|\bpatinho|\balcatra|\bcontra.?fil|\bpicanha|\bacem\b|\bmusculo|\bmaminha|\bfil[eé]\b|\bcostela|\bfraldinha|\bcupim|\bcoxao|\blagarto|\bhamburguer|\bcharque|\bcarneiro|\bcordeiro|\bcabrito|\bvitela|\bmoida"#,
            (1.5, 0.6, 1.5, 80, 3, 2, 3)),
        (#"\bmanteiga"#, (7, 0.1, 0.5, 19, 30, 0, 0)),
        (#"\brequeijao|\bqueijo|\bricota|\bcottage|\bmucarela|\bmussarela|\bparmesao|\bprovolone|\bcoalho"#, (2.5, 0.4, 2, 16, 30, 1, 5)),
        (#"\biogurte|\bcoalhada|\bkefir"#, (0.2, 0.4, 2, 15, 35, 1, 5)),
        (#"\bleite\b|\bleite |\bcreme de leite|\bnata\b|\bachocolatado|\bvitamina de"#, (0.3, 0.37, 2, 15, 30, 1, 5)),
        (#"\bwhey|\bproteina isolada|\bcaseina"#, (0, 1.5, 10, 50, 50, 5, 10)),
        (#"\bsoja|\btofu|\bedamame"#, (3, 0.2, 10, 35, 1, 2, 50)),
        (#"\bfeijao|\blentilha|\bgrao.de.bico|\bervilha|\bfava\b|\bfeijoada"#, (5, 0.25, 2, 33, 1, 2, 75)),
        (#"\bamendoim|\bpacoca"#, (0, 1.8, 17, 53, 1, 1, 30)),
        (#"\bcastanha|\bamendoa|\bnoz|\bnozes|\bavela|\bpistache|\bmacadamia|\bpecan"#, (4, 0.6, 15, 30, 1, 1, 20)),
        (#"\bgergelim|\bchia|\blinhaca|\bsemente|\bgirassol|\babobora \(semente"#, (4, 1, 10, 50, 1, 1, 15)),
        (#"\baveia|\bgranola|\bfarelo"#, (2, 1.1, 20, 40, 1, 4, 50)),
        (#"\barroz integral|\bquinoa|\btrigo integral|\bcenteio|\bcevada"#, (1, 0.4, 3, 15, 1, 2, 25)),
        (#"\barroz"#, (0, 0.4, 1, 2, 1, 1, 15)),
        (#"\bpao integral|\bpao de forma integral|\bpao multigr"#, (2, 0.6, 3, 27, 10, 4, 20)),
        (#"\bpao|\bbisnaguinha|\btorrada|\bbisc|\bbolacha|\bbolo|\bcroissant|\bwrap|\btapioca|\bcuscuz"#, (1, 0.4, 2, 13, 10, 2, 10)),
        (#"\bmacarrao|\bmassa|\blasanha|\bnhoque|\bespaguete|\bmiojo"#, (0, 0.1, 1, 10, 1, 1, 10)),
        (#"\bmilho|\bpipoca|\bfuba|\bpolenta|\bcanjica"#, (0.3, 0.7, 1, 23, 1, 1, 10)),
        (#"\bbatata.doce"#, (2, 0.8, 1.5, 13, 1, 2, 1)),
        (#"\bbatata|\bmandioca|\baipim|\bmacaxeira|\binhame|\bcara\b|\bmandioquinha|\bbaroa"#, (2, 0.3, 0.5, 13, 1, 2, 1)),
        (#"\bcogumelo|\bchampignon|\bshimeji|\bshiitake"#, (0, 1.5, 9, 17, 0, 1, 0)),
        (#"\babacate"#, (21, 1.4, 3, 14, 0, 0, 0)),
        (#"\bkiwi"#, (40, 0.2, 0.5, 8, 0, 0, 0)),
        (#"\buva|\bpassas?\b"#, (15, 0.05, 0.5, 6, 0, 2, 0)),
        (#"\bbanana"#, (0.5, 0.33, 2.6, 10, 0, 1, 0)),
        (#"\bmorango|\bamora|\bframboesa|\bmirtilo"#, (5, 0.2, 1.5, 6, 0, 1, 0)),
        (#"\btomate|\bmolho de tomate|\bextrato de tomate"#, (8, 0.1, 4, 7, 0, 1, 0)),
        (#"\bcenoura"#, (13, 0.3, 5, 9, 0, 0, 0)),
        (#"\babobora|\bjerimum"#, (1, 0.3, 0.5, 8, 0, 0, 0)),
        (#"\bbeterraba|\brabanete|\bnabo"#, (0.2, 0.15, 0.5, 6, 0, 0, 0)),
        (#"\bcebola|\balho\b"#, (0.4, 0.12, 0.9, 6, 0, 1, 0)),
        (#"\bchocolate|\bcacau|\bbrigadeiro"#, (7, 0.4, 3, 12, 5, 2, 10)),
        (#"\bazeite|\boleo de soja|\boleo de canola"#, (60, 0, 0, 0.3, 0, 0, 0)),
        (#"\bmaionese|\bmargarina"#, (30, 0.1, 0.5, 10, 5, 0, 0)),
        (#"\bcafe\b|\bcafe "#, (0.1, 0.25, 0, 2.6, 0, 1, 0)),
    ]

    private static let rules: [(NSRegularExpression, V)] =
        source.map { (try! NSRegularExpression(pattern: $0.0, options: [.caseInsensitive]), $0.1) }

    /// Padrão por categoria, quando nenhuma palavra-chave bater.
    private static func category(_ c: String) -> V? {
        let c = FoodDatabase.normalize(c)
        if c.contains("folhosas") || c.contains("verduras") { return (30, 0.2, 1, 10, 0, 1, 0) }
        if c.contains("fruta") { return (3, 0.2, 1, 5, 0, 0.5, 0) }
        if c.contains("tuberosas") { return (2, 0.3, 0.5, 12, 1, 1, 1) }
        if c.contains("leguminosa") { return (5, 0.3, 2, 33, 1, 2, 60) }
        if c.contains("pescado") { return (0.1, 0.5, 2, 65, 40, 0, 0) }
        if c.contains("carne") { return (1, 0.6, 1.5, 75, 3, 1, 2) }
        if c.contains("aves") { return (2, 1, 2, 65, 7, 1, 1) }
        if c.contains("latic") || c.contains("leite") { return (0.5, 0.4, 2, 15, 30, 1, 5) }
        if c.contains("castanha") || c.contains("nozes") || c.contains("semente") { return (4, 0.6, 12, 35, 1, 1, 20) }
        if c.contains("cereais") || c.contains("farinha") || c.contains("panificados") { return (1, 0.4, 2, 12, 5, 2, 15) }
        return nil
    }

    /// Estimativas por 100 g para um alimento do banco (vazio se não houver base para estimar).
    static func estimate(name: String, category c: String, per100 n: Nutrients) -> [String: Double] {
        let key = FoodDatabase.normalize(name)
        let ns = key as NSString
        let range = NSRange(location: 0, length: ns.length)
        guard let v = rules.first(where: { $0.0.firstMatch(in: key, range: range) != nil })?.1 ?? category(c) else { return [:] }
        // Preparações com muita água (cozidos, sopas) têm menos por 100 g.
        let dilution = key.contains("cozid") || key.contains("caldo") || key.contains("sopa") ? 0.6 : 1
        var out: [String: Double] = [:]
        func put(_ id: NutrientID, _ x: Double) { if x > 0 { out[id.rawValue] = x * dilution } }
        put(.vitaminK, v.k); put(.b5, v.b5); put(.biotin, v.bio); put(.choline, v.cho)
        put(.iodine, v.iod); put(.chromium, v.cr); put(.molybdenum, v.mo)
        return out
    }
}
