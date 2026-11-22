import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct DataManagementView: View {
    @Environment(\.modelContext) private var context
    @Query private var weights: [WeightEntry]
    @Query private var measurements: [MeasurementEntry]
    @Query private var foodLogs: [FoodLog]
    @Query private var sessions: [WorkoutSession]
    @Query private var routines: [WorkoutRoutine]
    @Query private var water: [WaterLog]

    @State private var exportURL: URL?
    @State private var csvURL: URL?
    @State private var csvKind: BackupManager.CSVKind?
    @State private var importingJSON = false
    @State private var importingCSV = false
    @State private var pending: Backup?
    @State private var message: String?
    @State private var confirmDelete = false
    @State private var error: String?

    var body: some View {
        Form {
            Section("Seus dados") {
                row("scalemass.fill", "Pesagens", weights.count)
                row("ruler.fill", "Medições", measurements.count)
                row("fork.knife", "Alimentos registrados", foodLogs.count)
                row("drop.fill", "Registros de água", water.count)
                row("dumbbell.fill", "Treinos", sessions.filter { !$0.isActive }.count)
                row("list.bullet.rectangle.fill", "Rotinas", routines.count)
            }

            Section {
                if let url = exportURL {
                    ShareLink(item: url) {
                        Label("Salvar / enviar backup", systemImage: "square.and.arrow.up.fill")
                    }
                    Text(url.lastPathComponent).font(.caption).foregroundStyle(.secondary)
                } else {
                    Button { makeExport() } label: { Label("Criar backup completo (.json)", systemImage: "externaldrive.fill.badge.plus") }
                }
                Button { importingJSON = true } label: { Label("Restaurar de um backup", systemImage: "externaldrive.fill.badge.timemachine") }
            } header: { Text("Backup completo") } footer: {
                Text("Inclui perfil, pesagens, medidas, alimentação, água, jejum, treinos, rotinas, favoritos e tema. Salve no app Arquivos ou no iCloud Drive para trocar de celular ou reinstalar o app sem perder nada.")
            }

            Section {
                ForEach(BackupManager.CSVKind.allCases) { k in
                    Button { makeCSV(k) } label: {
                        HStack {
                            Label(k.rawValue, systemImage: "tablecells")
                            Spacer()
                            if csvKind == k, csvURL != nil { Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.good) }
                        }
                    }
                }
                if let url = csvURL, let k = csvKind {
                    ShareLink(item: url) { Label("Enviar \(k.rawValue).csv", systemImage: "square.and.arrow.up") }
                }
            } header: { Text("Exportar planilhas (CSV)") } footer: {
                Text("Abre no Excel, Google Planilhas ou Numbers.")
            }

            Section {
                Button { importingCSV = true } label: { Label("Importar pesagens de CSV", systemImage: "square.and.arrow.down") }
            } header: { Text("Importar de outros apps") } footer: {
                Text("Aceita planilhas com uma coluna de data e uma de peso (ex.: exportações de outros apps de balança). Pesagens repetidas são ignoradas.")
            }

            Section {
                Button("Apagar todos os dados", role: .destructive) { confirmDelete = true }
            } footer: {
                Text("Apaga pesagens, medidas, alimentação, treinos e rotinas (o perfil é mantido). Faça um backup antes.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(AnimatedBackground())
        .navigationTitle("Importar e exportar")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(isPresented: $importingJSON, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url):
                do { pending = try BackupManager.decode(url) }
                catch { self.error = "Arquivo inválido: não é um backup deste app." }
            case .failure: break
            }
        }
        .fileImporter(isPresented: $importingCSV, allowedContentTypes: [.commaSeparatedText, .plainText]) { result in
            if case .success(let url) = result {
                do {
                    let n = try BackupManager.importWeightsCSV(url, into: context)
                    message = n > 0 ? "\(n) pesagens importadas." : "Nenhuma pesagem nova encontrada no arquivo."
                } catch { self.error = "Não foi possível ler o arquivo CSV." }
            }
        }
        .confirmationDialog(pendingTitle, isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }),
                            titleVisibility: .visible) {
            Button("Juntar com meus dados") { restore(replace: false) }
            Button("Substituir tudo", role: .destructive) { restore(replace: true) }
            Button("Cancelar", role: .cancel) { pending = nil }
        } message: {
            Text("Juntar mantém o que você já tem e adiciona só o que for novo. Substituir apaga os dados atuais antes.")
        }
        .confirmationDialog("Apagar todos os dados? Não dá para desfazer.", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Apagar tudo", role: .destructive) {
                BackupManager.deleteAll(context, keepProfile: true)
                exportURL = nil
                message = "Dados apagados."
            }
        }
        .alert("Pronto", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK") { message = nil }
        } message: { Text(message ?? "") }
        .alert("Erro", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK") { error = nil }
        } message: { Text(error ?? "") }
    }

    private var pendingTitle: String {
        guard let p = pending else { return "" }
        return "Backup de \(p.exportedAt.formatted(date: .abbreviated, time: .shortened)): \(BackupManager.counts(p).summary)"
    }

    private func row(_ icon: String, _ t: String, _ n: Int) -> some View {
        LabeledContent { Text("\(n)").monospacedDigit() } label: { Label(t, systemImage: icon) }
    }

    private func makeExport() {
        do { withAnimation { exportURL = try? BackupManager.exportJSON(context) } }
        if exportURL == nil { error = "Não foi possível criar o backup." }
    }

    private func makeCSV(_ k: BackupManager.CSVKind) {
        csvKind = k
        csvURL = try? BackupManager.exportCSV(k, context)
        if csvURL == nil { error = "Não foi possível gerar o CSV." }
    }

    private func restore(replace: Bool) {
        guard let b = pending else { return }
        let c = BackupManager.restore(b, into: context, replace: replace)
        pending = nil
        exportURL = nil
        message = c.total > 0 ? "Importado: \(c.summary)." : "Nada novo para importar — tudo já estava no app."
    }
}
