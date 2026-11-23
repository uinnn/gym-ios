import SwiftUI
import SwiftData

// MARK: - Técnicas de respiração

struct BreathPhase {
    let label: String
    let seconds: Double
    let scale: CGFloat      // tamanho do círculo ao fim da fase
}

enum BreathTechnique: String, CaseIterable, Identifiable {
    case box, fourSevenEight, coherent, sigh, relax
    var id: String { rawValue }

    var name: String {
        switch self {
        case .box: "Respiração quadrada"
        case .fourSevenEight: "4-7-8 para dormir"
        case .coherent: "Coerência cardíaca"
        case .sigh: "Suspiro fisiológico"
        case .relax: "Relaxante 4-6"
        }
    }
    var subtitle: String {
        switch self {
        case .box: "4 s inspira · 4 s segura · 4 s expira · 4 s segura"
        case .fourSevenEight: "4 s inspira · 7 s segura · 8 s expira"
        case .coherent: "5,5 s inspira · 5,5 s expira (≈ 5,5 respirações/min)"
        case .sigh: "2 inspirações pelo nariz · expiração longa pela boca"
        case .relax: "4 s inspira · 6 s expira"
        }
    }
    var benefit: String {
        switch self {
        case .box: "Usada por militares e atletas para manter a calma e o foco sob pressão."
        case .fourSevenEight: "Desacelera o corpo antes de dormir (método do Dr. Andrew Weil)."
        case .coherent: "Sincroniza respiração e batimentos, aumentando a variabilidade cardíaca e reduzindo o estresse."
        case .sigh: "A forma mais rápida de baixar o estresse em tempo real (Balban et al., Stanford, 2023)."
        case .relax: "Expirar mais longo que inspirar ativa o sistema parassimpático (modo descanso)."
        }
    }
    var icon: String {
        switch self {
        case .box: "square"
        case .fourSevenEight: "moon.zzz.fill"
        case .coherent: "heart.fill"
        case .sigh: "wind"
        case .relax: "leaf.fill"
        }
    }
    var phases: [BreathPhase] {
        switch self {
        case .box: [.init(label: "Inspire", seconds: 4, scale: 1), .init(label: "Segure", seconds: 4, scale: 1),
                    .init(label: "Expire", seconds: 4, scale: 0.5), .init(label: "Segure", seconds: 4, scale: 0.5)]
        case .fourSevenEight: [.init(label: "Inspire pelo nariz", seconds: 4, scale: 1), .init(label: "Segure", seconds: 7, scale: 1),
                               .init(label: "Expire pela boca", seconds: 8, scale: 0.5)]
        case .coherent: [.init(label: "Inspire", seconds: 5.5, scale: 1), .init(label: "Expire", seconds: 5.5, scale: 0.5)]
        case .sigh: [.init(label: "Inspire", seconds: 2, scale: 0.85), .init(label: "Mais um pouco", seconds: 1, scale: 1),
                     .init(label: "Expire devagar", seconds: 6, scale: 0.5)]
        case .relax: [.init(label: "Inspire", seconds: 4, scale: 1), .init(label: "Expire", seconds: 6, scale: 0.5)]
        }
    }
}

struct BreathingView: View {
    let technique: BreathTechnique
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var minutes = 3.0
    @State private var running = false
    @State private var phaseIndex = 0
    @State private var phaseEnd = Date.now
    @State private var scale: CGFloat = 0.5
    @State private var elapsed: Double = 0
    @State private var cycles = 0
    @State private var finished = false
    @State private var task: Task<Void, Never>?
    @State private var haptic = 0

    var body: some View {
        let phase = technique.phases[phaseIndex]
        NavigationStack {
            ZStack {
                AnimatedBackground()
                VStack(spacing: 24) {
                    Spacer()
                    ZStack {
                        Circle().fill(Theme.accent.opacity(0.18)).frame(width: 300, height: 300).blur(radius: 30)
                            .scaleEffect(scale * 1.1)
                        Circle().fill(Theme.gradient).frame(width: 260, height: 260).scaleEffect(scale)
                            .shadow(color: Theme.accent.opacity(0.5), radius: 30)
                        VStack(spacing: 6) {
                            if finished {
                                Image(systemName: "checkmark.circle.fill").font(.system(size: 48))
                                Text("Concluído").font(.title2.bold())
                            } else if running {
                                Text(phase.label).font(.title2.bold())
                                TimelineView(.periodic(from: .now, by: 0.2)) { ctx in
                                    Text("\(max(0, Int(ceil(phaseEnd.timeIntervalSince(ctx.date)))))")
                                        .font(.system(size: 44, weight: .bold, design: .rounded)).monospacedDigit()
                                }
                            } else {
                                Image(systemName: technique.icon).font(.system(size: 40))
                                Text("Pronto?").font(.title3.bold())
                            }
                        }
                        .foregroundStyle(.white)
                    }
                    .frame(height: 320)
                    Text(technique.subtitle).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    if running || finished {
                        HStack(spacing: 24) {
                            stat("Ciclos", "\(cycles)")
                            stat("Tempo", "\(Int(elapsed) / 60):\(String(format: "%02d", Int(elapsed) % 60))")
                            stat("Meta", "\(Int(minutes)) min")
                        }
                    } else {
                        Picker("Duração", selection: $minutes) {
                            ForEach([1.0, 2, 3, 5, 10, 15], id: \.self) { Text("\(Int($0)) min").tag($0) }
                        }
                        .pickerStyle(.segmented)
                        Text(technique.benefit).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                    Spacer()
                    Button {
                        if running { stop(save: true) } else if finished { dismiss() } else { start() }
                    } label: {
                        Text(running ? "Encerrar" : (finished ? "Fechar" : "Começar"))
                            .font(.headline).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding()
                            .background(Theme.gradient, in: RoundedRectangle(cornerRadius: 18))
                    }
                    .buttonStyle(PressableStyle())
                }
                .padding()
            }
            .navigationTitle(technique.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Fechar") { stop(save: true); dismiss() } }
            .sensoryFeedback(.impact(weight: .light), trigger: haptic) { _, _ in ThemeStore.shared.haptics }
            .onDisappear { task?.cancel(); UIApplication.shared.isIdleTimerDisabled = false }
        }
    }

    private func stat(_ t: String, _ v: String) -> some View {
        VStack(spacing: 2) {
            Text(v).font(.headline.monospacedDigit())
            Text(t).font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func start() {
        running = true; finished = false; elapsed = 0; cycles = 0
        UIApplication.shared.isIdleTimerDisabled = true
        let phases = technique.phases
        let total = minutes * 60
        task = Task { @MainActor in
            while !Task.isCancelled && elapsed < total {
                for (i, p) in phases.enumerated() {
                    guard !Task.isCancelled else { return }
                    phaseIndex = i
                    phaseEnd = Date.now.addingTimeInterval(p.seconds)
                    haptic += 1
                    withAnimation(.easeInOut(duration: p.seconds)) { scale = p.scale }
                    try? await Task.sleep(for: .seconds(p.seconds))
                    elapsed += p.seconds
                }
                cycles += 1
            }
            if !Task.isCancelled { stop(save: true) }
        }
    }

    private func stop(save: Bool) {
        guard running else { return }
        task?.cancel()
        running = false
        finished = elapsed >= 20
        withAnimation(.spring) { scale = 0.75 }
        UIApplication.shared.isIdleTimerDisabled = false
        if save && elapsed >= 20 {
            context.insert(MindSession(kind: .breathing, detail: technique.name, seconds: elapsed))
            PartyService.shared.post(.practice, "fez respiração \(technique.name) (\(max(1, Int(elapsed) / 60)) min) 🌬️", value: elapsed / 60)
        }
    }
}

// MARK: - Relaxamento muscular progressivo (Jacobson)

struct RelaxationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var step = -1
    @State private var tensing = true
    @State private var phaseEnd = Date.now
    @State private var task: Task<Void, Never>?
    @State private var startedAt: Date?
    @State private var haptic = 0

    private let steps: [(String, String)] = [
        ("Mãos", "Feche as mãos com força, como se apertasse uma bola."),
        ("Braços", "Dobre os cotovelos e contraia os bíceps."),
        ("Ombros", "Leve os ombros em direção às orelhas."),
        ("Testa e olhos", "Franza a testa e feche os olhos com força."),
        ("Mandíbula", "Aperte os dentes (sem exagero) e contraia o rosto."),
        ("Pescoço", "Leve o queixo em direção ao peito."),
        ("Peito", "Inspire fundo e segure o ar, contraindo o peito."),
        ("Abdômen", "Contraia a barriga como se fosse levar um soco."),
        ("Glúteos", "Contraia os glúteos com força."),
        ("Coxas", "Estique as pernas e contraia as coxas."),
        ("Panturrilhas", "Puxe as pontas dos pés em direção ao rosto."),
        ("Pés", "Encolha os dedos dos pés."),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedBackground()
                VStack(spacing: 20) {
                    ProgressBar(progress: Double(max(step, 0)) / Double(steps.count), tint: Theme.accent, height: 6)
                    Spacer()
                    if step < 0 {
                        Image(systemName: "figure.mind.and.body").font(.system(size: 64)).foregroundStyle(Theme.gradient)
                        Text("Relaxamento muscular progressivo").font(.title2.bold()).multilineTextAlignment(.center)
                        Text("Contraia cada grupo muscular por 5 segundos e depois solte por 10, sentindo a diferença. Reduz tensão, ansiedade e ajuda a dormir (técnica de Jacobson). Duração: ~3 minutos.")
                            .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    } else if step < steps.count {
                        Text("\(step + 1) de \(steps.count)").font(.caption).foregroundStyle(.secondary)
                        Text(steps[step].0).font(.largeTitle.bold())
                        Text(tensing ? steps[step].1 : "Solte… respire e sinta os músculos relaxando.")
                            .font(.title3).multilineTextAlignment(.center).frame(minHeight: 80)
                        ZStack {
                            Circle().fill((tensing ? Theme.warm : Theme.good).opacity(0.25)).frame(width: 180, height: 180)
                                .scaleEffect(tensing ? 0.8 : 1.1)
                                .animation(.easeInOut(duration: tensing ? 5 : 10), value: tensing)
                            TimelineView(.periodic(from: .now, by: 0.2)) { ctx in
                                Text("\(max(0, Int(ceil(phaseEnd.timeIntervalSince(ctx.date)))))")
                                    .font(.system(size: 52, weight: .bold, design: .rounded)).monospacedDigit()
                            }
                        }
                        Text(tensing ? "CONTRAIA" : "RELAXE").font(.headline).foregroundStyle(tensing ? Theme.warm : Theme.good)
                    } else {
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 64)).foregroundStyle(Theme.good)
                        Text("Corpo relaxado").font(.title.bold())
                        Text("Fique mais um momento respirando devagar antes de levantar.").foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        if step < 0 { begin() } else { finish(); dismiss() }
                    } label: {
                        Text(step < 0 ? "Começar" : (step >= steps.count ? "Fechar" : "Encerrar"))
                            .font(.headline).foregroundStyle(.white).frame(maxWidth: .infinity).padding()
                            .background(Theme.gradient, in: RoundedRectangle(cornerRadius: 18))
                    }
                }
                .padding()
            }
            .navigationTitle("Relaxamento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Fechar") { finish(); dismiss() } }
            .sensoryFeedback(.impact(weight: .medium), trigger: haptic) { _, _ in ThemeStore.shared.haptics }
            .onDisappear { task?.cancel() }
        }
    }

    private func begin() {
        startedAt = .now
        task = Task { @MainActor in
            for i in steps.indices {
                guard !Task.isCancelled else { return }
                withAnimation { step = i; tensing = true }
                phaseEnd = .now.addingTimeInterval(5); haptic += 1
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled else { return }
                withAnimation { tensing = false }
                phaseEnd = .now.addingTimeInterval(10); haptic += 1
                try? await Task.sleep(for: .seconds(10))
            }
            withAnimation { step = steps.count }
            finish()
        }
    }

    private func finish() {
        task?.cancel()
        guard let s = startedAt else { return }
        startedAt = nil
        let secs = Date.now.timeIntervalSince(s)
        if secs >= 20 {
            context.insert(MindSession(kind: .relaxation, detail: "Relaxamento progressivo", seconds: secs))
            PartyService.shared.post(.practice, "fez relaxamento muscular (\(max(1, Int(secs) / 60)) min) 🧘", value: secs / 60)
        }
    }
}

// MARK: - Meditação e foco (timer)

struct TimerPracticeView: View {
    let kind: PracticeKind     // .meditation ou .focus
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var minutes = 10.0
    @State private var end: Date?
    @State private var startedAt: Date?
    @State private var breakTime = false
    @State private var rounds = 0
    @State private var haptic = 0
    @State private var done = false
    @State private var focusAccum: Double = 0
    @State private var blockStart: Date?

    private var isFocus: Bool { kind == .focus }

    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedBackground()
                VStack(spacing: 24) {
                    Spacer()
                    TimelineView(.periodic(from: .now, by: 0.5)) { ctx in
                        let total = (breakTime ? 5 : minutes) * 60
                        let left = end.map { max(0, $0.timeIntervalSince(ctx.date)) } ?? total
                        ZStack {
                            ProgressRing(progress: 1 - left / total, lineWidth: 16,
                                         colors: breakTime ? [Theme.good, Theme.accent2, Theme.good] : nil)
                            VStack(spacing: 4) {
                                Text(String(format: "%02d:%02d", Int(left) / 60, Int(left) % 60))
                                    .font(.system(size: 54, weight: .bold, design: .rounded)).monospacedDigit()
                                Text(isFocus ? (breakTime ? "Pausa" : "Foco") : "Meditação").font(.headline).foregroundStyle(.secondary)
                                if isFocus && rounds > 0 { Text("\(rounds) ciclo(s)").font(.caption) }
                            }
                        }
                        .frame(width: 260, height: 260)
                        .onChange(of: left <= 0) { _, ended in if ended && end != nil { phaseEnded() } }
                    }
                    if end == nil && !done {
                        Picker("Minutos", selection: $minutes) {
                            ForEach(isFocus ? [15.0, 25, 45, 50] : [3.0, 5, 10, 15, 20], id: \.self) { Text("\(Int($0)) min").tag($0) }
                        }
                        .pickerStyle(.segmented)
                        Text(isFocus ? "Técnica Pomodoro: blocos de foco com 5 min de pausa. O celular vibra ao fim de cada bloco."
                                     : "Sente-se confortável, feche os olhos e leve a atenção à respiração. Quando a mente divagar, gentilmente volte. O celular vibra ao final.")
                            .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                    Spacer()
                    Button {
                        if end == nil && !done { begin() } else { finish(); dismiss() }
                    } label: {
                        Text(end == nil && !done ? "Começar" : "Encerrar")
                            .font(.headline).foregroundStyle(.white).frame(maxWidth: .infinity).padding()
                            .background(Theme.gradient, in: RoundedRectangle(cornerRadius: 18))
                    }
                }
                .padding()
            }
            .navigationTitle(isFocus ? "Foco" : "Meditação")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Fechar") { finish(); dismiss() } }
            .sensoryFeedback(.success, trigger: haptic) { _, _ in ThemeStore.shared.haptics }
            .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        }
    }

    private func begin() {
        startedAt = .now
        blockStart = .now
        focusAccum = 0
        breakTime = false
        end = .now.addingTimeInterval(minutes * 60)
        UIApplication.shared.isIdleTimerDisabled = true
    }

    private func phaseEnded() {
        haptic += 1
        if isFocus {
            if !breakTime { rounds += 1; focusAccum += minutes * 60 }
            breakTime.toggle()
            blockStart = .now
            end = .now.addingTimeInterval((breakTime ? 5 : minutes) * 60)
        } else {
            end = nil; done = true
            finish()
        }
    }

    private func finish() {
        guard let s = startedAt else { return }
        startedAt = nil
        var worked = Date.now.timeIntervalSince(s)
        if isFocus {
            // conta só o tempo de foco (sem as pausas)
            worked = focusAccum + (!breakTime ? blockStart.map { Date.now.timeIntervalSince($0) } ?? 0 : 0)
        }
        if worked >= 30 {
            context.insert(MindSession(kind: kind, detail: isFocus ? "Pomodoro" : "Meditação", seconds: worked))
            PartyService.shared.post(.practice, isFocus ? "focou \(max(1, Int(worked) / 60)) min 🎯" : "meditou \(max(1, Int(worked) / 60)) min 🧘", value: worked / 60)
        }
        UIApplication.shared.isIdleTimerDisabled = false
    }
}
