import Foundation

/// Cache de JSON decodificado, indexado pelo próprio conteúdo (Data).
///
/// Treinos, rotinas e alimentos salvos guardam seus dados como JSON dentro do banco.
/// Sem cache, cada leitura (`session.exercises`) decodificava o JSON de novo — centenas de
/// vezes por tela. Como a chave é o conteúdo, qualquer alteração gera uma entrada nova
/// e o cache nunca devolve dados desatualizados.
final class DecodeCache<T: Codable> {
    private final class Box { let value: T; init(_ v: T) { value = v } }
    private let cache = NSCache<NSData, Box>()

    init(limit: Int = 2000) { cache.countLimit = limit }

    func decode(_ data: Data) -> T? {
        guard !data.isEmpty else { return nil }
        let key = data as NSData
        if let hit = cache.object(forKey: key) { return hit.value }
        guard let v = try? JSONDecoder().decode(T.self, from: data) else { return nil }
        cache.setObject(Box(v), forKey: key)
        return v
    }

    func encode(_ value: T) -> Data {
        let data = (try? JSONEncoder().encode(value)) ?? Data()
        if !data.isEmpty { cache.setObject(Box(value), forKey: data as NSData) }
        return data
    }
}

enum Caches {
    static let sessions = DecodeCache<[SessionExercise]>()
    static let routines = DecodeCache<[RoutineItem]>()
    static let foods = DecodeCache<FoodItem>(limit: 4000)
}
