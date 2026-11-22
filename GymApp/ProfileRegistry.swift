import Foundation
import Observation
import SwiftData
import SwiftUI

/// Resumo de um perfil (guardado fora do banco de dados, para listar e trocar rápido).
struct ProfileInfo: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var emoji: String = "🙂"
    var colorIndex: Int = 0
    var sexRaw: String = Sex.male.rawValue
    var birthDate: Date = Calendar.current.date(byAdding: .year, value: -25, to: .now)!
    var heightCm: Double = 170
    var lastKg: Double?
    var lastWeighed: Date?

    var age: Int { Calendar.current.dateComponents([.year], from: birthDate, to: .now).year ?? 0 }
    var color: Color { Palette.all[colorIndex % Palette.all.count].accent }
}

/// Gerencia os perfis da família. Cada perfil tem seu próprio banco de dados (arquivo separado),
/// então pesagens, alimentação, treinos e medidas nunca se misturam.
@Observable
final class ProfileRegistry {
    static let shared = ProfileRegistry()
    private let d = UserDefaults.standard

    var profiles: [ProfileInfo] { didSet { save() } }
    var activeID: String { didSet { d.set(activeID, forKey: "activeProfile") } }

    @ObservationIgnored private var containers: [String: ModelContainer] = [:]

    static let schema = Schema([UserProfile.self, WeightEntry.self, MeasurementEntry.self, FoodLog.self, SavedFood.self,
                                WaterLog.self, FastingSession.self, WorkoutSession.self, WorkoutRoutine.self])

    private init() {
        if let data = d.data(forKey: "profiles"), let list = try? JSONDecoder().decode([ProfileInfo].self, from: data), !list.isEmpty {
            profiles = list
        } else {
            // primeiro uso (ou dados de antes dos perfis): o banco padrão vira o primeiro perfil
            profiles = [ProfileInfo(id: "default", name: "Eu")]
        }
        activeID = d.string(forKey: "activeProfile") ?? "default"
        if !profiles.contains(where: { $0.id == activeID }) { activeID = profiles[0].id }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(profiles) { d.set(data, forKey: "profiles") }
    }

    var active: ProfileInfo { profiles.first { $0.id == activeID } ?? profiles[0] }

    func container(for id: String) -> ModelContainer {
        if let c = containers[id] { return c }
        let config: ModelConfiguration
        if id == "default" {
            config = ModelConfiguration(schema: Self.schema)
        } else {
            let dir = URL.applicationSupportDirectory
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            config = ModelConfiguration(schema: Self.schema, url: dir.appending(path: "profile-\(id).store"))
        }
        let c = (try? ModelContainer(for: Self.schema, configurations: config))
            ?? (try! ModelContainer(for: Self.schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
        containers[id] = c
        return c
    }

    func update(_ id: String, _ change: (inout ProfileInfo) -> Void) {
        guard let i = profiles.firstIndex(where: { $0.id == id }) else { return }
        var p = profiles[i]
        change(&p)
        if p != profiles[i] { profiles[i] = p }
    }

    /// Cria um perfil novo já com o UserProfile básico no banco dele.
    @MainActor
    func create(name: String, emoji: String, sex: Sex, birth: Date, heightCm: Double) -> ProfileInfo {
        let info = ProfileInfo(id: UUID().uuidString, name: name, emoji: emoji, colorIndex: profiles.count,
                               sexRaw: sex.rawValue, birthDate: birth, heightCm: heightCm)
        let ctx = container(for: info.id).mainContext
        let p = UserProfile()
        p.name = name; p.sex = sex; p.birthDate = birth; p.heightCm = heightCm
        let h = heightCm / 100
        p.goalWeightKg = ((22 * h * h) * 2).rounded() / 2      // IMC 22 como meta inicial
        ctx.insert(p)
        try? ctx.save()
        profiles.append(info)
        return info
    }

    func delete(_ id: String) {
        guard profiles.count > 1 else { return }
        profiles.removeAll { $0.id == id }
        containers[id] = nil
        if id != "default" {
            let base = URL.applicationSupportDirectory.appending(path: "profile-\(id).store").path()
            for suffix in ["", "-shm", "-wal"] { try? FileManager.default.removeItem(atPath: base + suffix) }
        }
        if activeID == id { activeID = profiles[0].id }
    }

    /// Salva uma pesagem no banco de outro perfil.
    @MainActor
    func addWeight(_ kg: Double, date: Date, to id: String) {
        let ctx = container(for: id).mainContext
        ctx.insert(WeightEntry(date: date, kg: kg))
        try? ctx.save()
        update(id) { $0.lastKg = kg; $0.lastWeighed = date }
    }

    /// Perfil (que não seja o ativo) cujo último peso está mais perto deste peso (até 5%).
    func likelyOwner(of kg: Double) -> ProfileInfo? {
        profiles.filter { $0.id != activeID && $0.lastKg != nil }
            .map { ($0, abs(kg - $0.lastKg!) / $0.lastKg!) }
            .filter { $0.1 < 0.05 }
            .min { $0.1 < $1.1 }?.0
    }

    static let emojis = ["🙂", "😎", "👩", "👨", "👧", "👦", "👵", "👴", "🧑", "💪", "🏃", "🧘", "⭐️", "🌸", "🔥", "🐶"]
}
