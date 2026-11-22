import SwiftUI
import SwiftData
import Charts

enum SleepMath {
    /// Minutos do horário relativos ao meio-dia (lida com quem dorme depois da meia-noite).
    static func minutesFromNoon(_ d: Date) -> Double {
        let c = Calendar.current.dateComponents([.hour, .minute], from: d)
        var m = Double((c.hour ?? 0) * 60 + (c.minute ?? 0)) - 720
        if m < 0 { m += 1440 }
        return m
    }

    static func clock(fromNoon m: Double) -> String {
        let total = (Int(m.rounded()) + 720) % 1440
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    static func sd(_ v: [Double]) -> Double {
        guard v.count > 1 else { return 0 }
        let mean = v.reduce(0, +) / Double(v.count)
        return sqrt(v.map { pow($0 - mean, 2) }.reduce(0, +) / Double(v.count))
    }

    static func hm(_ hours: Double) -> String {
        let m = Int((hours * 60).rounded())
        return "\(m / 60)h\(String(format: "%02d", m % 60))"
    }
}

struct SleepLogSheet: View {
    var existing: SleepEntry?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var bedtime = Date.now
    @State private var wake = Date.now
    @State private var quality = 3
    @State private var awakenings = 0
    @State private var note = ""

    var body: some View {
        let hours = max(0, wake.timeIntervalSince(bedtime) / 3600)
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 4) {
                        Image(systemName: "moon.stars.fill").font(.system(size: 40)).foregroundStyle(Theme.gradient)
                        Text(SleepMath.hm(hours)).font(.system(size: 44, weight: .bold, design: .rounded))
                            .contentTransition(.numericText(value: hours))
                        Text(hours < 7 ? "Abaixo do recomendado (7–9 h)" : (hours <= 9 ? "Dentro do recomendado" : "Acima de 9 h"))
                            .font(.caption).foregroundStyle(hours < 7 ? Theme.warm : Theme.good)
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }
                Section {
                    DatePicker("Deitou", selection: $bedtime.animation(), in: ...Date.now)
                    DatePicker("Acordou", selection: $wake.animation(), in: ...Date.now)
                }
                Section {
                    DotScale(title: "Qualidade do sono", icon: "sparkles", value: $quality, low: "Péssima", high: "Excelente", tint: Theme.excellent)
                    Stepper("Acordou \(awakenings)x durante a noite", value: $awakenings, in: 0...20)
                    TextField("Observação (sonhos, barulho, cafeína…)", text: $note)
                }
            }
            .navigationTitle(existing == nil ? "Registrar sono" : "Editar sono")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") { save() }.bold().disabled(hours <= 0 || hours > 20)
                }
                if let e = existing {
                    ToolbarItem(placement: .bottomBar) { Button("Apagar", role: .destructive) { context.delete(e); dismiss() } }
                }
            }
            .onAppear {
                if let e = existing {
                    bedtime = e.bedtime; wake = e.wake; quality = e.quality; awakenings = e.awakenings; note = e.note
                } else {
                    let cal = Calendar.current
                    let today = cal.startOfDay(for: .now)
                    wake = min(cal.date(bySettingHour: 7, minute: 0, second: 0, of: today)!, .now)
                    bedtime = cal.date(byAdding: .hour, value: -8, to: wake)!
                }
            }
        }
    }

    private func save() {
        let e = existing ?? SleepEntry(bedtime: bedtime, wake: wake, quality: quality)
        e.bedtime = bedtime; e.wake = wake; e.quality = quality; e.awakenings = awakenings; e.note = note
        if existing == nil { context.insert(e) }
        dismiss()
    }
}

struct SleepView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \SleepEntry.wake) private var all: [SleepEntry]
    @Bindable private var prefs = MindPrefs.shared
    @State private var showLog = false
    @State private var editing: SleepEntry?
    @State private var days = 14

    var body: some View {
        let start = Calendar.current.date(byAdding: .day, value: -days, to: .now) ?? .now
        let list = all.filter { $0.wake >= start }
        NavigationStack {
            ZStack {
                AnimatedBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        Picker("Período", selection: $days.animation(.spring)) {
                            Text("7 dias").tag(7); Text("14 dias").tag(14); Text("30 dias").tag(30); Text("90 dias").tag(90)
                        }
                        .pickerStyle(.segmented)
                        if list.isEmpty {
                            ContentUnavailableView("Sem registros de sono", systemImage: "moon.zzz",
                                                   description: Text("Registre como dormiu para ver duração, regularidade e dívida de sono."))
                        } else {
                            stats(list).appear()
                            chart(list).appear(0.05)
                            timing(list).appear(0.1)
                        }
                        goalCard.appear(0.15)
                        tipsCard.appear(0.2)
                        if !list.isEmpty { listCard(list).appear(0.25) }
                    }
                    .padding()
                }
            }
            .navigationTitle("Sono")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("OK") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button { showLog = true } label: { Image(systemName: "plus.circle.fill") }
                }
            }
            .sheet(isPresented: $showLog) { SleepLogSheet() }
            .sheet(item: $editing) { SleepLogSheet(existing: $0) }
        }
    }

    private func stats(_ l: [SleepEntry]) -> some View {
        let hours = l.map(\.hours)
        let avg = hours.reduce(0, +) / Double(hours.count)
        let last7 = l.suffix(7)
        let debt = last7.map { max(0, prefs.sleepGoal - $0.hours) }.reduce(0, +)
        let q = Double(l.map(\.quality).reduce(0, +)) / Double(l.count)
        let regularity = SleepMath.sd(l.map { SleepMath.minutesFromNoon($0.bedtime) })
        let efficient = l.filter { $0.hours >= 7 && $0.hours <= 9 }.count
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            MetricTile(title: "Última noite", value: SleepMath.hm(l.last!.hours), icon: "moon.fill", tint: Theme.excellent,
                       caption: "qualidade \(l.last!.quality)/5")
            MetricTile(title: "Média", value: SleepMath.hm(avg), icon: "chart.bar.fill", tint: Theme.accent,
                       caption: avg < 7 ? "abaixo de 7 h" : "na faixa ideal", progress: avg / prefs.sleepGoal)
            MetricTile(title: "Dívida de sono (7 dias)", value: SleepMath.hm(debt), icon: "exclamationmark.triangle.fill",
                       tint: debt > 5 ? Theme.danger : (debt > 2 ? Theme.warm : Theme.good),
                       caption: "meta \(prefs.sleepGoal.fmt(1)) h/noite")
            MetricTile(title: "Regularidade", value: "±\(Int(regularity)) min", icon: "metronome.fill",
                       tint: regularity <= 30 ? Theme.good : (regularity <= 60 ? Theme.warm : Theme.danger),
                       caption: regularity <= 30 ? "horários consistentes" : "horários variam muito")
            MetricTile(title: "Qualidade média", value: q.fmt(1), unit: "/5", icon: "sparkles", tint: .purple)
            MetricTile(title: "Noites 7–9 h", value: "\(efficient)/\(l.count)", icon: "checkmark.seal.fill", tint: Theme.good,
                       progress: Double(efficient) / Double(l.count))
        }
    }

    private func chart(_ l: [SleepEntry]) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                Text("Horas por noite").font(.headline)
                Chart {
                    ForEach(l) { e in
                        BarMark(x: .value("Dia", e.day, unit: .day), y: .value("Horas", e.hours))
                            .foregroundStyle(e.hours < 6 ? Theme.danger : (e.hours < 7 ? Theme.warm : Theme.excellent))
                            .cornerRadius(4)
                    }
                    RuleMark(y: .value("Meta", prefs.sleepGoal))
                        .foregroundStyle(Theme.good).lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                        .annotation(position: .top, alignment: .leading) {
                            Text("Meta \(prefs.sleepGoal.fmt(1)) h").font(.caption2.bold()).foregroundStyle(Theme.good)
                        }
                }
                .frame(height: 180)
            }
        }
    }

    private func timing(_ l: [SleepEntry]) -> some View {
        let bed = l.map { SleepMath.minutesFromNoon($0.bedtime) }
        let wake = l.map { SleepMath.minutesFromNoon($0.wake) }
        let avgBed = bed.reduce(0, +) / Double(bed.count), avgWake = wake.reduce(0, +) / Double(wake.count)
        let mid = (avgBed + (avgWake < avgBed ? avgWake + 1440 : avgWake)) / 2
        let midHour = Double(((Int(mid) + 720) % 1440)) / 60
        let chrono = midHour < 3 ? "Matutino (cotovia)" : (midHour < 5 ? "Intermediário" : "Vespertino (coruja)")
        return Card {
            VStack(alignment: .leading, spacing: 10) {
                Text("Horários").font(.headline)
                HStack {
                    timeItem("Deita em média", SleepMath.clock(fromNoon: avgBed), "bed.double.fill")
                    Spacer()
                    timeItem("Acorda em média", SleepMath.clock(fromNoon: avgWake), "sunrise.fill")
                    Spacer()
                    timeItem("Meio do sono", SleepMath.clock(fromNoon: mid.truncatingRemainder(dividingBy: 1440)), "moon.haze.fill")
                }
                Label("Cronotipo estimado: \(chrono)", systemImage: "clock.fill").font(.caption.bold()).foregroundStyle(Theme.accent)
                Text("Pelo ponto médio do sono (método de Munique, Roenneberg). Manter horários iguais todos os dias, inclusive no fim de semana, é um dos fatores mais ligados a bom humor e energia.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private func timeItem(_ t: String, _ v: String, _ icon: String) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon).foregroundStyle(Theme.accent)
            Text(v).font(.headline.monospacedDigit())
            Text(t).font(.caption2).foregroundStyle(.secondary)
        }
    }

    private var goalCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                Stepper(value: $prefs.sleepGoal, in: 6...10, step: 0.5) {
                    LabeledContent("Meta de sono", value: "\(prefs.sleepGoal.fmt(1)) h")
                }
                Text("Adultos: 7–9 h por noite (National Sleep Foundation / AASM). Menos de 6 h de forma frequente está ligado a pior humor, mais fome, menos recuperação muscular e mais risco de doenças.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private var tipsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                Label("Higiene do sono", systemImage: "lightbulb.fill").font(.headline).foregroundStyle(Theme.accent)
                ForEach([
                    ("sun.max.fill", "Luz do sol pela manhã regula o relógio biológico."),
                    ("cup.and.saucer.fill", "Evite cafeína 8 h antes de dormir (ela dura ~5–6 h no corpo)."),
                    ("iphone.slash", "Telas e luz forte 1 h antes atrasam a melatonina."),
                    ("thermometer.snowflake", "Quarto fresco (18–20 °C), escuro e silencioso."),
                    ("wineglass", "Álcool dá sono, mas piora a qualidade e o sono profundo."),
                    ("figure.run", "Exercício ajuda, mas evite treino intenso perto de deitar."),
                    ("wind", "Use a respiração 4-7-8 da aba Mente para pegar no sono."),
                ], id: \.1) { icon, text in
                    Label(text, systemImage: icon).font(.caption)
                }
            }
        }
    }

    private func listCard(_ l: [SleepEntry]) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 0) {
                Text("Registros").font(.headline).padding(.bottom, 6)
                ForEach(l.reversed()) { e in
                    Button { editing = e } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(e.day, format: .dateTime.weekday(.wide).day().month(.abbreviated)).font(.subheadline)
                                Text("\(e.bedtime.formatted(date: .omitted, time: .shortened)) → \(e.wake.formatted(date: .omitted, time: .shortened)) · qualidade \(e.quality)/5")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(SleepMath.hm(e.hours)).font(.subheadline.bold().monospacedDigit())
                                .foregroundStyle(e.hours < 7 ? Theme.warm : Theme.good)
                        }
                        .foregroundStyle(.primary)
                        .padding(.vertical, 8).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Divider()
                }
            }
        }
    }
}
