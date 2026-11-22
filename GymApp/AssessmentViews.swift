import SwiftUI
import SwiftData
import Charts

/// Contatos de apoio emocional (Brasil).
struct CrisisCard: View {
    var urgent = false

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Label(urgent ? "Você não está sozinho(a)" : "Precisa conversar?", systemImage: "heart.circle.fill")
                    .font(.headline).foregroundStyle(Theme.danger)
                Text(urgent
                     ? "Se você está pensando em se machucar ou sente que não aguenta mais, fale com alguém agora. Ligar é gratuito, sigiloso e funciona 24 horas."
                     : "Se estiver passando por um momento difícil, buscar apoio é um sinal de força.")
                    .font(.callout)
                HStack(spacing: 10) {
                    contact("CVV", "188", "tel://188", "phone.fill")
                    contact("SAMU", "192", "tel://192", "cross.case.fill")
                }
                if let chat = URL(string: "https://cvv.org.br/chat/") {
                    Link(destination: chat) {
                        Label("Conversar pelo chat do CVV", systemImage: "message.fill").font(.subheadline.bold())
                            .frame(maxWidth: .infinity).padding(10)
                            .background(Theme.danger.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                Text("Em emergência, vá ao pronto-socorro mais próximo. Para acompanhamento, o CAPS e as UBS do SUS oferecem atendimento psicológico gratuito.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private func contact(_ name: String, _ number: String, _ url: String, _ icon: String) -> some View {
        Link(destination: URL(string: url)!) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                Text(number).font(.title2.bold())
                Text(name).font(.caption2)
            }
            .foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 10)
            .background(Theme.danger, in: RoundedRectangle(cornerRadius: 14))
        }
    }
}

/// Questionário passo a passo.
struct AssessmentView: View {
    let kind: AssessmentKind
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var answers: [Int] = []
    @State private var index = 0
    @State private var result: AssessmentResult?

    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedBackground()
                if let result { resultView(result) } else { questionView }
            }
            .navigationTitle(kind.short)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(result == nil ? "Cancelar" : "Fechar") { dismiss() } }
                if index > 0 && result == nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { withAnimation(.spring) { index -= 1; answers.removeLast() } } label: { Image(systemName: "arrow.uturn.backward") }
                    }
                }
            }
        }
    }

    private var questionView: some View {
        let q = kind.questions
        return VStack(alignment: .leading, spacing: 18) {
            ProgressBar(progress: Double(index) / Double(q.count), tint: Theme.accent, height: 6)
            Text("Pergunta \(index + 1) de \(q.count)").font(.caption).foregroundStyle(.secondary)
            Text(kind.intro).font(.subheadline).foregroundStyle(.secondary)
            Text(q[index]).font(.title2.bold()).fixedSize(horizontal: false, vertical: true)
                .id(index)
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
            VStack(spacing: 10) {
                ForEach(Array(kind.options.enumerated()), id: \.offset) { i, opt in
                    Button { answer(i) } label: {
                        HStack {
                            Text(opt).font(.headline)
                            Spacer()
                            Text("\(i)").font(.caption.bold()).foregroundStyle(.secondary)
                        }
                        .foregroundStyle(.primary)
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(PressableStyle())
                }
            }
            Spacer()
            Text(kind.about).font(.caption2).foregroundStyle(.secondary)
        }
        .padding()
    }

    private func answer(_ v: Int) {
        answers.append(v)
        if index + 1 < kind.questions.count {
            withAnimation(.spring(duration: 0.4)) { index += 1 }
        } else {
            let r = AssessmentResult(kind: kind, answers: answers)
            context.insert(r)
            withAnimation(.spring) { result = r }
        }
    }

    private func resultView(_ r: AssessmentResult) -> some View {
        let lv = kind.level(r.score)
        let urgent = (kind == .phq9 && (r.answers.last ?? 0) > 0) || (kind == .phq9 && r.score >= 20)
        return ScrollView {
            VStack(spacing: 16) {
                if urgent { CrisisCard(urgent: true).appear() }
                VStack(spacing: 8) {
                    ZStack {
                        ProgressRing(progress: Double(r.score) / Double(kind.maxScore), lineWidth: 14,
                                     colors: [lv.color.opacity(0.7), lv.color, lv.color.opacity(0.7)])
                        VStack(spacing: 0) {
                            Text("\(r.score)\(kind == .who5 ? "%" : "")").font(.system(size: 44, weight: .bold, design: .rounded))
                            Text("de \(kind.maxScore)\(kind == .who5 ? "%" : "")").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 170, height: 170)
                    StatusChip(text: lv.label, color: lv.color)
                }
                .padding(.top).appear(0.05)
                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("O que isso significa", systemImage: "info.circle.fill").font(.headline).foregroundStyle(Theme.accent)
                        Text(lv.advice).font(.callout)
                        Text(kind.about).font(.caption).foregroundStyle(.secondary)
                        Text("Repita a cada 2–4 semanas para acompanhar a evolução. O resultado fica salvo só no seu celular.")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .appear(0.1)
                if !urgent && (lv.color == Theme.danger || lv.color == Theme.warm) { CrisisCard().appear(0.15) }
            }
            .padding()
        }
    }
}

/// Central dos questionários com histórico.
struct AssessmentsHubView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \AssessmentResult.date) private var results: [AssessmentResult]
    @State private var running: AssessmentKind?

    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(AssessmentKind.allCases) { k in card(k) }
                        CrisisCard()
                        Text("Estes questionários são ferramentas de triagem reconhecidas, não substituem avaliação de um psicólogo ou médico.")
                            .font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                    .padding()
                }
            }
            .navigationTitle("Autoavaliação")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("OK") { dismiss() } }
            .sheet(item: $running) { AssessmentView(kind: $0) }
        }
    }

    private func card(_ k: AssessmentKind) -> some View {
        let list = results.filter { $0.kind == k }
        return Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Image(systemName: k.icon).foregroundStyle(Theme.accent)
                        .frame(width: 36, height: 36).background(Theme.accent.opacity(0.15), in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(k.title).font(.headline)
                        Text("\(k.questions.count) perguntas · ~\(k.questions.count / 3 + 1) min").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let last = list.last {
                        let lv = k.level(last.score)
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(last.score)\(k == .who5 ? "%" : "")").font(.headline).foregroundStyle(lv.color)
                            Text(lv.label).font(.caption2).foregroundStyle(lv.color)
                        }
                    }
                }
                if list.count >= 2 {
                    Chart(list) { r in
                        LineMark(x: .value("Data", r.date), y: .value("Pontos", r.score))
                            .foregroundStyle(Theme.gradient).interpolationMethod(.monotone)
                        PointMark(x: .value("Data", r.date), y: .value("Pontos", r.score)).foregroundStyle(k.level(r.score).color)
                    }
                    .chartYScale(domain: 0...k.maxScore)
                    .frame(height: 110)
                    let d = list.last!.score - list[list.count - 2].score
                    let better = k.higherIsBetter ? d > 0 : d < 0
                    Text(d == 0 ? "Igual à vez anterior." : "\(d > 0 ? "+" : "")\(d) pontos desde a vez anterior — \(better ? "melhora" : "piora").")
                        .font(.caption).foregroundStyle(d == 0 ? Color.secondary : (better ? Theme.good : Theme.warm))
                }
                Button { running = k } label: {
                    Text(list.isEmpty ? "Responder" : "Responder de novo").font(.subheadline.bold()).frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered).tint(Theme.accent)
                if let last = list.last {
                    Text("Última vez: \(last.date.formatted(.relative(presentation: .named)))").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }
}
