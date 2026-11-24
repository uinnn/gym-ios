import SwiftUI
import UIKit

/// Demonstrações em imagem vindas do free-exercise-db (github.com/yuhonas/free-exercise-db),
/// liberado em domínio público (Unlicense). Cada exercício tem 2 fotos (início e fim),
/// que o app alterna em loop como uma animação.
enum ExerciseMedia {
    static let base = "https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/"

    /// id do app → id do free-exercise-db.
    static let map: [String: String] = [
        // Peito
        "bench": "Barbell_Bench_Press_-_Medium_Grip", "bench-db": "Dumbbell_Bench_Press", "incline-bench": "Barbell_Incline_Bench_Press_-_Medium_Grip",
        "incline-db": "Incline_Dumbbell_Press", "decline-bench": "Decline_Barbell_Bench_Press", "chest-press": "Machine_Bench_Press",
        "fly-db": "Dumbbell_Flyes", "pec-deck": "Butterfly", "cable-cross": "Cable_Crossover", "pushup": "Pushups",
        "dips-chest": "Dips_-_Chest_Version", "incline-machine": "Leverage_Incline_Chest_Press", "decline-machine": "Leverage_Decline_Chest_Press",
        "smith-bench": "Smith_Machine_Bench_Press", "smith-incline": "Smith_Machine_Incline_Bench_Press", "cable-fly-low": "Low_Cable_Crossover",
        "cable-fly-mid": "Flat_Bench_Cable_Flyes", "cable-press": "Standing_Cable_Chest_Press", "single-cable-fly": "Single-Arm_Cable_Crossover",
        "svend-press": "Svend_Press", "floor-press": "Dumbbell_Floor_Press", "db-pullover": "Straight-Arm_Dumbbell_Pullover",
        "incline-pushup": "Incline_Push-Up", "decline-pushup": "Decline_Push-Up", "diamond-pushup": "Push-Ups_-_Close_Triceps_Position",
        "guillotine-press": "Barbell_Guillotine_Bench_Press", "hammer-chest": "Leverage_Chest_Press", "db-fly-incline": "Incline_Dumbbell_Flyes",
        "cable-cross-high": "Cable_Crossover", "wide-pushup": "Push-Up_Wide", "close-bench": "Close-Grip_Barbell_Bench_Press",
        "smith-close-bench": "Smith_Machine_Close-Grip_Bench_Press",
        // Costas
        "deadlift": "Barbell_Deadlift", "pullup": "Pullups", "chinup": "Chin-Up", "lat-pulldown": "Wide-Grip_Lat_Pulldown",
        "lat-pulldown-close": "Close-Grip_Front_Lat_Pulldown", "barbell-row": "Bent_Over_Barbell_Row", "db-row": "One-Arm_Dumbbell_Row",
        "seated-row": "Seated_Cable_Rows", "machine-row": "Leverage_Iso_Row", "tbar-row": "T-Bar_Row_with_Handle", "pullover": "Straight-Arm_Pulldown",
        "shrug": "Dumbbell_Shrug", "hyperextension": "Hyperextensions_Back_Extensions", "lat-pulldown-wide": "Wide-Grip_Lat_Pulldown",
        "lat-pulldown-under": "Underhand_Cable_Pulldowns", "single-arm-pulldown": "One_Arm_Lat_Pulldown", "straight-arm-pulldown": "Straight-Arm_Pulldown",
        "rope-pulldown": "Rope_Straight-Arm_Pulldown", "high-row-machine": "Leverage_High_Row", "seated-row-wide": "Seated_Cable_Rows",
        "seal-row": "Lying_Cambered_Barbell_Row", "smith-row": "Smith_Machine_Bent_Over_Row", "rack-pull": "Rack_Pulls",
        "good-morning": "Good_Morning", "machine-shrug": "Leverage_Shrug", "barbell-shrug": "Barbell_Shrug", "inverted-row": "Inverted_Row",
        "australian-pullup": "Inverted_Row", "superman": "Superman", "reverse-grip-row": "Reverse_Grip_Bent-Over_Rows",
        "db-row-chest": "Dumbbell_Incline_Row", "chest-supported-row": "Leverage_Iso_Row", "t-bar-chest": "Lying_T-Bar_Row",
        "kneeling-pulldown": "Kneeling_High_Pulley_Row", "cable-row-single": "Seated_One-arm_Cable_Pulley_Rows", "meadows-row": "One-Arm_Long_Bar_Row",
        "assisted-pullup": "Band_Assisted_Pull-Up", "dead-hang": "One_Handed_Hang", "sumo-deadlift": "Sumo_Deadlift",
        // Ombros
        "ohp": "Standing_Military_Press", "db-press": "Dumbbell_Shoulder_Press", "machine-press": "Machine_Shoulder_Military_Press",
        "lateral-raise": "Side_Lateral_Raise", "cable-lateral": "Cable_Seated_Lateral_Raise", "front-raise": "Front_Dumbbell_Raise",
        "rear-delt-fly": "Seated_Bent-Over_Rear_Delt_Raise", "face-pull": "Face_Pull", "upright-row": "Upright_Barbell_Row",
        "arnold-press": "Arnold_Dumbbell_Press", "smith-press": "Smith_Machine_Overhead_Shoulder_Press", "rear-delt-machine": "Reverse_Machine_Flyes",
        "cable-rear-fly": "Cable_Rear_Delt_Fly", "cable-front-raise": "Front_Cable_Raise", "cable-upright-row": "Upright_Cable_Row",
        "db-shoulder-seated": "Seated_Dumbbell_Press", "incline-lateral": "One-Arm_Incline_Lateral_Raise", "seated-lateral": "Seated_Side_Lateral_Raise",
        "behind-neck-press": "Standing_Barbell_Press_Behind_Neck", "band-pull-apart": "Band_Pull_Apart", "db-rear-delt-row": "Barbell_Rear_Delt_Row",
        "single-cable-lateral": "Standing_Low-Pulley_Deltoid_Raise",
        // Braços
        "barbell-curl": "Barbell_Curl", "db-curl": "Dumbbell_Alternate_Bicep_Curl", "hammer-curl": "Hammer_Curls", "preacher-curl": "Preacher_Curl",
        "cable-curl": "Standing_Biceps_Cable_Curl", "incline-curl": "Incline_Dumbbell_Curl", "concentration-curl": "Concentration_Curls",
        "triceps-pushdown": "Triceps_Pushdown", "triceps-rope": "Triceps_Pushdown_-_Rope_Attachment", "skullcrusher": "EZ-Bar_Skullcrusher",
        "overhead-ext": "Standing_Dumbbell_Triceps_Extension", "bench-dips": "Bench_Dips", "kickback": "Tricep_Dumbbell_Kickback",
        "wrist-curl": "Palms-Up_Barbell_Wrist_Curl_Over_A_Bench", "machine-curl": "Machine_Bicep_Curl", "cable-hammer": "Cable_Hammer_Curls_-_Rope_Attachment",
        "ez-curl": "EZ-Bar_Curl", "spider-curl": "Spider_Curl", "reverse-curl": "Reverse_Barbell_Curl", "drag-curl": "Drag_Curl",
        "preacher-machine": "Machine_Preacher_Curls", "triceps-machine": "Machine_Triceps_Extension", "dip-machine": "Dip_Machine",
        "overhead-cable-ext": "Triceps_Overhead_Extension_with_Rope", "single-pushdown": "Standing_Low-Pulley_One-Arm_Triceps_Extension",
        "reverse-pushdown": "Reverse_Grip_Triceps_Pushdown", "jm-press": "JM_Press", "db-skull": "Lying_Dumbbell_Tricep_Extension",
        "dips-triceps": "Dips_-_Triceps_Version", "reverse-wrist-curl": "Palms-Down_Wrist_Curl_Over_A_Bench", "plate-pinch": "Plate_Pinch",
        "cable-curl-high": "High_Cable_Curls", "zottman-curl": "Zottman_Curl", "cross-body-curl": "Cross_Body_Hammer_Curl",
        "cable-triceps-kickback": "One-Legged_Cable_Kickback", "db-french-single": "Standing_One-Arm_Dumbbell_Triceps_Extension",
        "tate-press": "Tate_Press", "v-bar-pushdown": "Triceps_Pushdown_-_V-Bar_Attachment", "wrist-roller": "Wrist_Roller",
        "cable-curl-bar": "Standing_Biceps_Cable_Curl",
        // Pernas
        "squat": "Barbell_Full_Squat", "front-squat": "Front_Barbell_Squat", "goblet-squat": "Goblet_Squat", "leg-press": "Leg_Press",
        "hack-squat": "Hack_Squat", "smith-squat": "Smith_Machine_Squat", "leg-extension": "Leg_Extensions", "lunge": "Dumbbell_Lunges",
        "bulgarian": "Split_Squat_with_Dumbbells", "stepup": "Dumbbell_Step_Ups", "rdl": "Romanian_Deadlift", "leg-curl": "Lying_Leg_Curls",
        "seated-leg-curl": "Seated_Leg_Curl", "hip-thrust": "Barbell_Hip_Thrust", "glute-bridge": "Barbell_Glute_Bridge",
        "abductor": "Thigh_Abductor", "adductor": "Thigh_Adductor", "cable-kickback": "Glute_Kickback", "standing-calf": "Standing_Calf_Raises",
        "seated-calf": "Seated_Calf_Raise", "kb-swing": "One-Arm_Kettlebell_Swings", "bw-squat": "Bodyweight_Squat", "jump-squat": "Freehand_Jump_Squat",
        "leg-press-narrow": "Narrow_Stance_Leg_Press", "single-leg-extension": "Single-Leg_Leg_Extension", "smith-lunge": "Smith_Single-Leg_Split_Squat",
        "walking-lunge": "Barbell_Walking_Lunge", "reverse-lunge": "Dumbbell_Rear_Lunge", "zercher-squat": "Zercher_Squats", "box-squat": "Box_Squat",
        "pistol-squat": "Kettlebell_Pistol_Squat", "standing-leg-curl": "Standing_Leg_Curl", "nordic-curl": "Natural_Glute_Ham_Raise",
        "db-rdl": "Stiff-Legged_Dumbbell_Deadlift", "single-rdl": "Kettlebell_One-Legged_Deadlift", "cable-pull-through": "Pull_Through",
        "glute-ham-raise": "Glute_Ham_Raise", "smith-rdl": "Smith_Machine_Stiff-Legged_Deadlift", "smith-hip-thrust": "Smith_Machine_Hip_Raise",
        "cable-adduction": "Cable_Hip_Adduction", "leg-press-calf": "Calf_Press_On_The_Leg_Press_Machine", "smith-calf": "Smith_Machine_Calf_Raise",
        "single-calf": "Dumbbell_Seated_One-Leg_Calf_Raise", "donkey-calf": "Donkey_Calf_Raises", "hack-narrow": "Narrow_Stance_Hack_Squats",
        "smith-split-squat": "Smith_Single-Leg_Split_Squat", "sissy-squat": "Weighted_Sissy_Squat", "kb-rdl": "Kettlebell_One-Legged_Deadlift",
        "single-hip-thrust": "Single_Leg_Glute_Bridge", "soleus-machine": "Seated_Calf_Raise", "hip-abduction-band": "Thigh_Abductor",
        // Abdômen e corpo todo
        "crunch": "Crunches", "leg-raise": "Flat_Bench_Lying_Leg_Raise", "hanging-knee": "Hanging_Leg_Raise", "cable-crunch": "Cable_Crunch",
        "russian-twist": "Russian_Twist", "ab-wheel": "Ab_Roller", "bicycle": "Cross-Body_Crunch", "mountain-climber": "Mountain_Climbers",
        "ab-machine": "Ab_Crunch_Machine", "decline-crunch": "Decline_Crunch", "cable-woodchop": "Standing_Cable_Wood_Chop",
        "pallof-press": "Pallof_Press", "hanging-leg-raise": "Hanging_Leg_Raise", "dead-bug": "Dead_Bug", "reverse-crunch": "Reverse_Crunch",
        "side-crunch": "Oblique_Crunches_-_On_The_Floor", "plank": "Plank", "flutter-kicks": "Flutter_Kicks", "weighted-plank": "Plank",
        "cable-side-bend": "One-Arm_High-Pulley_Cable_Side_Bends", "clean": "Power_Clean", "thruster": "Kettlebell_Thruster",
        "kb-snatch": "One-Arm_Kettlebell_Snatch", "sled-push": "Sled_Push", "battle-rope": "Battling_Ropes", "medball-slam": "Overhead_Slam",
        "box-jump": "Front_Box_Jump", "farmers-walk": "Farmers_Walk", "suitcase-carry": "Farmers_Walk",
        // Alongamentos (StretchCatalog)
        "stretch:upper-trap": "Side_Neck_Stretch", "stretch:chin-tuck": "Chin_To_Chest_Stretch", "stretch:doorway-pec": "Chest_And_Front_Of_Shoulder_Stretch",
        "stretch:band-pull": "Band_Pull_Apart", "stretch:cross-body": "Shoulder_Stretch", "stretch:sleeper": "Internal_Rotation_with_Band",
        "stretch:lat-stretch": "Overhead_Lat", "stretch:arm-circles": "Arm_Circles", "stretch:shoulder-dislocate": "Round_The_World_Shoulder_Stretch",
        "stretch:cat-cow": "Cat_Stretch", "stretch:child-pose": "Childs_Pose", "stretch:knees-chest": "Hug_Knees_To_Chest",
        "stretch:supine-twist": "Side-Lying_Floor_Stretch", "stretch:cobra": "Upward_Stretch", "stretch:side-bend": "Standing_Lateral_Stretch",
        "stretch:bird-dog": "Superman", "stretch:dead-bug": "Dead_Bug", "stretch:side-plank": "Side_Bridge", "stretch:pelvic-tilt": "Pelvic_Tilt_Into_Bridge",
        "stretch:hang": "One_Handed_Hang", "stretch:kneeling-hip-flexor": "Kneeling_Hip_Flexor", "stretch:couch": "Intermediate_Hip_Flexor_and_Quad_Stretch",
        "stretch:pigeon": "IT_Band_and_Glute_Stretch", "stretch:figure-four": "Ankle_On_The_Knee", "stretch:90-90": "90_90_Hamstring",
        "stretch:glute-bridge": "Butt_Lift_Bridge", "stretch:lateral-walk": "Monster_Walk", "stretch:hip-circles": "Hip_Circles_prone",
        "stretch:frog": "Adductor_Groin", "stretch:butterfly": "Groin_and_Back_Stretch", "stretch:side-lunge": "Side_Lying_Groin_Stretch",
        "stretch:straddle": "The_Straddle", "stretch:worlds-greatest": "Worlds_Greatest_Stretch",
        "stretch:standing-hamstring": "Standing_Hamstring_and_Calf_Stretch", "stretch:supine-hamstring": "Lying_Hamstring",
        "stretch:forward-fold": "Standing_Toe_Touches", "stretch:leg-swings": "Front_Leg_Raises", "stretch:quad-standing": "Quad_Stretch",
        "stretch:half-split": "Seated_Floor_Hamstring_Stretch", "stretch:it-band": "IT_Band_and_Glute_Stretch",
        "stretch:calf-wall": "Calf_Stretch_Hands_Against_Wall", "stretch:soleus": "Standing_Soleus_And_Achilles_Stretch",
        "stretch:ankle-knee-wall": "Ankle_Circles", "stretch:plantar-roll": "Foot-SMR", "stretch:calf-raise-slow": "Standing_Calf_Raises",
        "stretch:wrist-flexor": "Kneeling_Forearm_Stretch", "stretch:wrist-extensor": "Side_Wrist_Pull", "stretch:wrist-circles": "Wrist_Circles",
        "stretch:triceps-overhead": "Triceps_Stretch", "stretch:biceps-wall": "Standing_Biceps_Stretch", "stretch:happy-baby": "Lying_Bent_Leg_Groin",
        "stretch:deep-squat-hold": "Bodyweight_Squat", "stretch:inchworm": "Inchworm", "stretch:seated-twist": "Chair_Upper_Body_Stretch",
        "stretch:seated-figure-four": "Seated_Glute", "stretch:standing-chest-open": "Elbows_Back", "stretch:thread-needle": "Middle_Back_Stretch",
        "stretch:open-book": "Spinal_Stretch", "stretch:foam-thoracic": "Upper_Back_Stretch", "stretch:sphinx": "One_Half_Locust",
        "stretch:clamshell": "Band_Hip_Adductions", "stretch:lizard": "Runners_Stretch", "stretch:legs-wall": "Leg-Up_Hamstring_Stretch",
        "stretch:jefferson": "Standing_Toe_Touches", "stretch:neck-circles": "Side_Neck_Stretch", "stretch:spanish-squat": "Chair_Squat",
    ]

    static func folder(exercise id: String) -> String? { map[id] }
    static func folder(stretch id: String) -> String? { map["stretch:" + id] }

    static func urls(_ folder: String) -> [URL] {
        (0..<2).compactMap { URL(string: base + folder + "/\($0).jpg") }
    }

    static var allFolders: [String] { Array(Set(map.values)).sorted() }
}

// MARK: - Cache em disco (funciona offline depois de baixar)

actor MediaCache {
    static let shared = MediaCache()
    private let dir: URL = {
        let d = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("exercise-media", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }()
    private let memory = NSCache<NSURL, UIImage>()

    private func file(_ url: URL) -> URL {
        let parts = url.pathComponents.suffix(2).joined(separator: "_")
        return dir.appendingPathComponent(parts)
    }

    func image(_ url: URL) async -> UIImage? {
        if let m = memory.object(forKey: url as NSURL) { return m }
        let f = file(url)
        if let d = try? Data(contentsOf: f), let img = UIImage(data: d) { memory.setObject(img, forKey: url as NSURL); return img }
        guard let (d, r) = try? await URLSession.shared.data(from: url), (r as? HTTPURLResponse)?.statusCode == 200,
              let img = UIImage(data: d) else { return nil }
        try? d.write(to: f, options: .atomic)
        memory.setObject(img, forKey: url as NSURL)
        return img
    }

    func isCached(_ url: URL) -> Bool { FileManager.default.fileExists(atPath: file(url).path) }

    var diskBytes: Int {
        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.fileSizeKey])) ?? []
        return files.compactMap { try? $0.resourceValues(forKeys: [.fileSizeKey]).fileSize }.reduce(0, +)
    }

    func clear() {
        try? FileManager.default.removeItem(at: dir)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        memory.removeAllObjects()
    }
}

// MARK: - Animação (alterna início e fim)

struct ExerciseAnimation: View {
    let folder: String
    var height: CGFloat = 220
    @State private var frames: [UIImage] = []
    @State private var index = 0
    @State private var failed = false
    @State private var playing = true

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white)
            if frames.count == 2 {
                ZStack {
                    Image(uiImage: frames[0]).resizable().scaledToFit().opacity(index == 0 ? 1 : 0)
                    Image(uiImage: frames[1]).resizable().scaledToFit().opacity(index == 1 ? 1 : 0)
                }
                .padding(6)
                .overlay(alignment: .bottomLeading) {
                    Text(index == 0 ? "Início" : "Fim").font(.caption2.bold()).foregroundStyle(.white)
                        .padding(.horizontal, 8).padding(.vertical, 3).background(.black.opacity(0.55), in: Capsule()).padding(8)
                }
                .overlay(alignment: .bottomTrailing) {
                    Button { playing.toggle() } label: {
                        Image(systemName: playing ? "pause.fill" : "play.fill").font(.caption.bold()).foregroundStyle(.white)
                            .padding(7).background(.black.opacity(0.55), in: Circle())
                    }
                    .padding(8)
                }
            } else if failed {
                VStack(spacing: 6) {
                    Image(systemName: "wifi.slash").font(.title2)
                    Text("Sem conexão para carregar a demonstração.").font(.caption)
                }
                .foregroundStyle(.secondary)
            } else {
                ProgressView()
            }
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .task(id: folder) {
            frames = []; failed = false; index = 0
            var out: [UIImage] = []
            for u in ExerciseMedia.urls(folder) { if let img = await MediaCache.shared.image(u) { out.append(img) } }
            if out.count == 2 { frames = out } else { failed = true; return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(1100))
                if playing { withAnimation(.easeInOut(duration: 0.35)) { index = 1 - index } }
            }
        }
        .accessibilityLabel("Demonstração do exercício: posição inicial e final")
    }
}

/// Seção pronta para as telas de detalhe.
struct ExerciseDemoSection: View {
    let folder: String?
    var body: some View {
        if let folder {
            VStack(alignment: .leading, spacing: 6) {
                ExerciseAnimation(folder: folder)
                Text("Imagens: free-exercise-db (domínio público). Podem mostrar uma variação próxima do exercício.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Download para usar offline

struct MediaDownloadView: View {
    @State private var done = 0
    @State private var running = false
    @State private var bytes = 0
    private var total: Int { ExerciseMedia.allFolders.count * 2 }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Demonstrações de \(ExerciseMedia.map.count) exercícios e alongamentos. Ficam salvas no iPhone depois de abertas; baixe todas para usar sem internet.")
                .font(.caption).foregroundStyle(.secondary)
            if running { ProgressView(value: Double(done), total: Double(total)) }
            HStack {
                Button(running ? "Baixando… \(done)/\(total)" : "Baixar todas (~\(total * 60 / 1024) MB)") { Task { await download() } }
                    .disabled(running)
                Spacer()
                Text(ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)).font(.caption).foregroundStyle(.secondary)
            }
            Button("Apagar demonstrações salvas", role: .destructive) { Task { await MediaCache.shared.clear(); bytes = 0 } }
                .font(.caption)
        }
        .task { bytes = await MediaCache.shared.diskBytes }
    }

    private func download() async {
        running = true
        done = 0
        let urls = ExerciseMedia.allFolders.flatMap(ExerciseMedia.urls)
        await withTaskGroup(of: Void.self) { g in
            var it = urls.makeIterator()
            for _ in 0..<6 { if let u = it.next() { g.addTask { _ = await MediaCache.shared.image(u) } } }
            while await g.next() != nil {
                done += 1
                if let u = it.next() { g.addTask { _ = await MediaCache.shared.image(u) } }
            }
        }
        bytes = await MediaCache.shared.diskBytes
        running = false
    }
}
