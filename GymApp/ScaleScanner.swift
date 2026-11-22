import CoreBluetooth
import Foundation
import Observation

/// Um pacote Bluetooth recebido (anúncio ou notificação de característica).
struct Packet: Identifiable {
    let id = UUID()
    let date: Date
    let source: String   // "adv" ou UUID da característica
    let data: Data
}

/// Um dispositivo Bluetooth visto durante a busca.
@Observable
final class SeenDevice: Identifiable {
    let id: UUID
    var name: String
    var rssi: Int
    var lastSeen: Date
    var packets: [Packet] = []
    let peripheral: CBPeripheral

    init(peripheral: CBPeripheral, name: String, rssi: Int) {
        self.id = peripheral.identifier
        self.peripheral = peripheral
        self.name = name
        self.rssi = rssi
        self.lastSeen = .now
    }

    /// Guarda só pacotes diferentes do último da mesma origem (a balança repete muito).
    func add(_ data: Data, source: String) {
        if let last = packets.last(where: { $0.source == source }), last.data == data { return }
        packets.append(Packet(date: .now, source: source, data: data))
        if packets.count > 200 { packets.removeFirst(packets.count - 200) }
    }

    var latestWeight: WeightReading? {
        for p in packets.reversed() {
            if let w = ScaleDecoder.decode(p.data, source: p.source) { return w }
        }
        return nil
    }
}

/// Faz a busca Bluetooth (BLE) e guarda os dados brutos de cada dispositivo.
@Observable
final class ScaleScanner: NSObject {
    var devices: [UUID: SeenDevice] = [:]
    var isScanning = false
    var bluetoothState: CBManagerState = .unknown
    var showOnlyNamed = true
    var connectedID: UUID?

    private var central: CBCentralManager!

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: .main)
    }

    var sortedDevices: [SeenDevice] {
        devices.values
            .filter { !showOnlyNamed || $0.name != "Sem nome" }
            .sorted { $0.rssi > $1.rssi }
    }

    func start() {
        guard central.state == .poweredOn else { return }
        central.scanForPeripherals(withServices: nil,
                                   options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
        isScanning = true
    }

    func stop() {
        central.stopScan()
        isScanning = false
    }

    func clear() { devices.removeAll() }

    /// Conecta para ler também as notificações (algumas balanças só enviam o peso assim).
    func connect(_ device: SeenDevice) {
        if let id = connectedID, let old = devices[id] { central.cancelPeripheralConnection(old.peripheral) }
        connectedID = device.id
        device.peripheral.delegate = self
        central.connect(device.peripheral)
    }

    func disconnect(_ device: SeenDevice) {
        central.cancelPeripheralConnection(device.peripheral)
        if connectedID == device.id { connectedID = nil }
    }
}

extension ScaleScanner: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        bluetoothState = central.state
        if central.state == .poweredOn { start() } else { isScanning = false }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let name = (advertisementData[CBAdvertisementDataLocalNameKey] as? String)
            ?? peripheral.name ?? "Sem nome"
        let device = devices[peripheral.identifier]
            ?? SeenDevice(peripheral: peripheral, name: name, rssi: RSSI.intValue)
        device.name = name
        device.rssi = RSSI.intValue
        device.lastSeen = .now
        if let mfg = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data {
            device.add(mfg, source: "adv")
        }
        devices[peripheral.identifier] = device
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices(nil)
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
        if connectedID == peripheral.identifier { connectedID = nil }
    }
}

extension ScaleScanner: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        peripheral.services?.forEach { peripheral.discoverCharacteristics(nil, for: $0) }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        for c in service.characteristics ?? [] {
            if c.properties.contains(.notify) || c.properties.contains(.indicate) {
                peripheral.setNotifyValue(true, for: c)
            }
            if c.properties.contains(.read) { peripheral.readValue(for: c) }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        guard let data = characteristic.value, let device = devices[peripheral.identifier] else { return }
        device.add(data, source: characteristic.uuid.uuidString)
    }
}
