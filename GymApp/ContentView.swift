import SwiftUI
import CoreBluetooth

struct ContentView: View {
    @Environment(ScaleScanner.self) private var scanner

    var body: some View {
        @Bindable var scanner = scanner
        NavigationStack {
            List {
                if scanner.bluetoothState != .poweredOn {
                    Label(stateText, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
                Section {
                    Toggle("Só dispositivos com nome", isOn: $scanner.showOnlyNamed)
                } footer: {
                    Text("Suba na balança para ela ligar o Bluetooth. Ela costuma aparecer com nomes como \"Chipsea\", \"OKOK\" ou \"Scale\".")
                }
                Section("Dispositivos (\(scanner.sortedDevices.count))") {
                    ForEach(scanner.sortedDevices) { device in
                        NavigationLink(value: device.id) {
                            DeviceRow(device: device)
                        }
                    }
                }
            }
            .navigationTitle("Balança")
            .navigationDestination(for: UUID.self) { id in
                if let d = scanner.devices[id] { DeviceDetailView(device: d) }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Limpar", action: scanner.clear)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(scanner.isScanning ? "Parar" : "Buscar") {
                        scanner.isScanning ? scanner.stop() : scanner.start()
                    }
                }
            }
        }
    }

    private var stateText: String {
        switch scanner.bluetoothState {
        case .poweredOff: "Bluetooth desligado"
        case .unauthorized: "Permita o Bluetooth em Ajustes > Gym"
        case .unsupported: "Bluetooth não suportado"
        default: "Aguardando Bluetooth…"
        }
    }
}

struct DeviceRow: View {
    let device: SeenDevice

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(device.name).font(.headline)
                Text("\(device.packets.count) pacotes · \(device.rssi) dBm")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if let w = device.latestWeight {
                Text(w.kg, format: .number.precision(.fractionLength(1)))
                    .font(.title3.bold()) + Text(" kg")
            }
        }
    }
}

struct DeviceDetailView: View {
    @Environment(ScaleScanner.self) private var scanner
    let device: SeenDevice
    @State private var format = ScaleDecoder.savedFormat

    var body: some View {
        List {
            Section {
                VStack(spacing: 4) {
                    if let w = device.latestWeight {
                        Text(w.kg, format: .number.precision(.fractionLength(1)))
                            .font(.system(size: 64, weight: .bold, design: .rounded))
                        Text("kg").foregroundStyle(.secondary)
                        Label(w.isStable ? "Peso estável" : "Medindo…",
                              systemImage: w.isStable ? "checkmark.seal.fill" : "waveform")
                            .foregroundStyle(w.isStable ? .green : .orange)
                            .padding(.top, 4)
                        if let imp = w.rawImpedance {
                            Text("Valor bruto bytes 4–5: \(imp)")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    } else {
                        Text("Formato ainda não definido")
                            .font(.headline)
                        Text("Suba na balança. Quando o peso estabilizar, toque abaixo no valor que for igual ao do visor.")
                            .font(.caption).multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)
                if let format {
                    LabeledContent("Formato salvo", value: format.label)
                    Button("Esquecer formato", role: .destructive) {
                        ScaleDecoder.savedFormat = nil
                        self.format = nil
                    }
                }
            }

            Section {
                if scanner.connectedID == device.id {
                    Button("Desconectar") { scanner.disconnect(device) }
                } else {
                    Button("Conectar (ler notificações)") { scanner.connect(device) }
                }
                ShareLink(item: log, preview: SharePreview("Log da balança")) {
                    Label("Compartilhar log bruto", systemImage: "square.and.arrow.up")
                }
            } footer: {
                Text("Se nenhum valor bater com o visor, toque em Conectar: algumas balanças só enviam o peso depois de conectadas. Mande o log para análise.")
            }

            Section("Pacotes recebidos (mais recentes primeiro)") {
                ForEach(device.packets.reversed()) { p in
                    PacketRow(packet: p) { f in
                        ScaleDecoder.savedFormat = f
                        format = f
                    }
                }
            }
        }
        .navigationTitle(device.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var log: String {
        let df = ISO8601DateFormatter()
        return ([ "Dispositivo: \(device.name) (\(device.id))" ] + device.packets.map {
            "\(df.string(from: $0.date)) [\($0.source)] \($0.data.hex)"
        }).joined(separator: "\n")
    }
}

struct PacketRow: View {
    let packet: Packet
    let onPick: (WeightFormat) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(packet.source == "adv" ? "Anúncio" : "Caract. \(packet.source)")
                Spacer()
                Text(packet.date, format: .dateTime.hour().minute().second())
            }
            .font(.caption2).foregroundStyle(.secondary)
            Text(packet.data.hex).font(.system(.footnote, design: .monospaced))
                .textSelection(.enabled)
            let cands = ScaleDecoder.candidates(packet.data, source: packet.source)
            if !cands.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(cands, id: \.0) { f, v in
                            Button {
                                onPick(f)
                            } label: {
                                Text("\(v, specifier: "%.1f") kg").font(.caption)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
        }
    }
}
