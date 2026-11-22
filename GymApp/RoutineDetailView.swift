import SwiftUI
import SwiftData

/// Visualização de uma rotina (somente leitura), com atalhos para começar e editar.
struct RoutineDetailView: View {
    @Bindable var routine: WorkoutRoutine
    var onStart: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \WorkoutSession.start, order: .reverse) private var sessions: [WorkoutSession]
    @Query(sort: \WeightEntry.date, order: .reverse) private var weights: [WeightEntry]
    @State private var editing = false
    @State private var detail: Exercise?

    private var past: [WorkoutSession] { sessions.filter { !$0.isActive } }
    private var bodyKg: Double { weights.first?.kg ?? 70 }

    var body: some View {
        let same = past.filter { $0.name == routine.name }
        NavigationStack {
            ZStack(alignment: .bottom) {
                AnimatedBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        header.appear()
                        statsGrid(same).appear(0.05)
                        musclesCard.appear(0.1)
                        SectionHeader(title: "Exercícios", icon: "list.number")
                        ForEach(Array(routine.items.enumerated()), id: \.element.id) { i, item in
                            itemCard(i, item).appear(0.12 + Double(i) * 0.03)
                        }
                        Color.clear.frame(height: 90)
                    }
                    .padding()
                }
                Button {
                    dismiss(); onStart()
                } label: {
                    Label("Começar treino", systemImage: "play.fill")
                        .font(.headline).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding()
                        .background(Theme.gradient, in: RoundedRectangle(cornerRadius: 18))
                        .shadow(color: Theme.accent.opacity(0.4), radius: 12, y: 4)
                }
                .buttonStyle(PressableStyle())
                .padding()
            }
            .navigationTitle(routine.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Fechar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button { editing = true } label: { Label("Editar", systemImage: "pencil") }
                }
            }
            .sheet(isPresented: $editing) { RoutineEditorView(routine: routine) }
            .sheet(item: $detail) { ExerciseDetailView(exercise: $0) }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: routine.icon).font(.system(size: 36)).foregroundStyle(.white)
                .frame(width: 76, height: 76).background(Theme.gradient, in: RoundedRectangle(cornerRadius: 22))
            Text(routine.name).font(.title2.bold())
            Text(routine.weekday == 0 ? "Sem dia definido" : "Toda \(Weekday.name(routine.weekday).lowercased())")
                .font(.subheadline).foregroundStyle(Theme.accent)
        }
        .padding(.top, 6)
    }

    private func statsGrid(_ same: [WorkoutSession]) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                  spacing: 10) {
            mini("Exercícios", "\(routine.items.count)", "list.bullet")
            mini("Séries", "\(routine.totalSets)", "square.stack.3d.up.fill")
            mini("Duração", "~\(Int(routine.estimatedMinutes)) min", "timer")
            mini("Calorias", "~\(routine.estimatedKcal(bodyKg: bodyKg).fmt(0))", "flame.fill")
            mini("Feito", "\(same.count)x", "checkmark.seal.fill")
            mini("Último volume", same.first.map { "\(WorkoutMath.volume($0).fmt(0)) kg" } ?? "—", "scalemass.fill")
        }
    }

    private func mini(_ t: String, _ v: String, _ icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).foregroundStyle(Theme.accent).font(.caption)
            Text(v).font(.subheadline.bold()).lineLimit(1).minimumScaleFactor(0.7)
            Text(t).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var musclesCard: some View {
        let ms = routine.muscleSets
        return Card {
            VStack(alignment: .leading, spacing: 8) {
                Text("Músculos (séries)").font(.headline)
                FlowLayout(spacing: 6) {
                    ForEach(ms, id: \.0) { m, n in
                        Label("\(m.label) \(n.fmt(n.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 1))", systemImage: m.icon)
                            .font(.caption.bold()).padding(.horizontal, 10).padding(.vertical, 6)
                            .background(Theme.accent.opacity(min(0.12 + n * 0.04, 0.5)), in: Capsule())
                    }
                }
            }
        }
    }

    private func itemCard(_ i: Int, _ item: RoutineItem) -> some View {
        let x = item.exercise
        let cardio = x?.kind == .cardio || x?.kind == .timed
        let prev = WorkoutMath.previous(item.exerciseID, before: .now, in: past).filter { $0.kind != .warmup }
        let best = WorkoutMath.best(item.exerciseID, in: past)
        return Button { detail = x } label: {
            Card {
                HStack(alignment: .top, spacing: 12) {
                    Text("\(i + 1)").font(.headline).foregroundStyle(.white)
                        .frame(width: 32, height: 32).background(Theme.gradient, in: Circle())
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Text(x?.name ?? item.exerciseID).font(.subheadline.bold()).foregroundStyle(.primary)
                            if WorkoutPrefs.shared.favorites.contains(item.exerciseID) {
                                Image(systemName: "star.fill").font(.caption2).foregroundStyle(.yellow)
                            }
                        }
                        Text(cardio ? "\(item.sets) × \(item.repsMin) min"
                                    : "\(item.sets) séries × \(item.repsMin)–\(item.repsMax) reps · descanso \(item.restSeconds) s")
                            .font(.caption).foregroundStyle(.secondary)
                        if !prev.isEmpty, !cardio {
                            Text("Última vez: \(prev.map { "\($0.kg.fmt(1))×\($0.reps)" }.joined(separator: ", "))")
                                .font(.caption2).foregroundStyle(Theme.accent).lineLimit(1)
                        }
                        if let b = best, !cardio {
                            Text("Recorde: 1RM \(b.e1RM.fmt(1)) kg").font(.caption2).foregroundStyle(Theme.excellent)
                        }
                    }
                    Spacer()
                    Image(systemName: "info.circle").foregroundStyle(.tertiary)
                }
            }
        }
        .buttonStyle(PressableStyle())
    }
}
