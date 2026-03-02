// InstaxBLEManager.swift
// Zone System Master - Instax BLE Integration
// Gestione CoreBluetooth per stampanti Instax

import Foundation
import CoreBluetooth
import Combine

// MARK: - InstaxBLEManager

@MainActor
public final class InstaxBLEManager: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public private(set) var connectionState: InstaxConnectionState = .disconnected
    @Published public private(set) var printerInfo: InstaxPrinterInfo?
    @Published public private(set) var discoveredPrinters: [CBPeripheral] = []
    @Published public private(set) var isScanning = false
    
    // MARK: - Private Properties
    
    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var writeCharacteristic: CBCharacteristic?
    private var notifyCharacteristic: CBCharacteristic?
    
    private var connectionContinuation: CheckedContinuation<Void, Error>?
    private var responseContinuation: CheckedContinuation<Data, Error>?
    private var printContinuation: CheckedContinuation<Void, Error>?
    
    private var scanTimeoutTimer: Timer?
    private var responseTimeoutTimer: Timer?
    private var printTimeoutTimer: Timer?
    
    private var isWaitingForResponse = false
    private var imagePacketQueue: [Data] = []
    private var currentPrintJob: InstaxPrintJob?
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    public override init() {
        super.init()
        self.centralManager = CBCentralManager(delegate: self, queue: .main)
    }
    
    // MARK: - Public Methods
    
    /// Inizia la scansione delle stampanti Instax
    public func startScan(timeout: TimeInterval = 10.0) async throws {
        guard centralManager.state == .poweredOn else {
            throw mapBluetoothState(centralManager.state)
        }
        
        await MainActor.run {
            discoveredPrinters.removeAll()
            isScanning = true
            connectionState = .scanning
        }
        
        // Avvia scansione
        centralManager.scanForPeripherals(
            withServices: [InstaxUUID.service],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
        
        // Timer timeout
        scanTimeoutTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.stopScan()
            }
        }
        
        // Attendi che l'utente selezioni una stampante o timeout
        try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
    }
    
    /// Ferma la scansione
    public func stopScan() {
        scanTimeoutTimer?.invalidate()
        scanTimeoutTimer = nil
        centralManager.stopScan()
        isScanning = false
        if case .scanning = connectionState {
            connectionState = .disconnected
        }
    }
    
    /// Connette a una stampante specifica
    public func connect(to peripheral: CBPeripheral, timeout: TimeInterval = 30.0) async throws {
        guard centralManager.state == .poweredOn else {
            throw mapBluetoothState(centralManager.state)
        }
        
        // Disconnetti se già connesso
        if let connected = connectedPeripheral {
            centralManager.cancelPeripheralConnection(connected)
        }
        
        await MainActor.run {
            connectionState = .connecting
        }
        
        // Avvia connessione
        centralManager.connect(peripheral, options: nil)
        
        // Attendi connessione con timeout
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    Task { @MainActor [weak self] in
                        self?.connectionContinuation = continuation
                    }
                }
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw InstaxError.connectionTimeout
            }
            
            try await group.next()!
            group.cancelAll()
        }
        
        connectedPeripheral = peripheral
        peripheral.delegate = self
        
        // Scopri servizi
        peripheral.discoverServices([InstaxUUID.service])
    }
    
    /// Connette alla prima stampante trovata
    public func connectToFirstPrinter(timeout: TimeInterval = 30.0) async throws {
        try await startScan(timeout: 5.0)
        
        guard let firstPrinter = discoveredPrinters.first else {
            throw InstaxError.printerNotFound
        }
        
        try await connect(to: firstPrinter, timeout: timeout)
    }
    
    /// Disconnette dalla stampante
    public func disconnect() {
        guard let peripheral = connectedPeripheral else { return }
        
        connectionState = .disconnecting
        centralManager.cancelPeripheralConnection(peripheral)
        
        // Cleanup
        writeCharacteristic = nil
        notifyCharacteristic = nil
        imagePacketQueue.removeAll()
        currentPrintJob = nil
    }
    
    /// Invia un pacchetto alla stampante
    public func sendPacket(_ packet: InstaxPacket, waitForResponse: Bool = true) async throws -> Data? {
        guard let peripheral = connectedPeripheral,
              let characteristic = writeCharacteristic else {
            throw InstaxError.notConnected
        }
        
        let data = packet.toData()
        
        // Se il pacchetto è troppo grande, dividilo
        if data.count > InstaxConstants.maxPacketSize {
            try await sendLargePacket(data, peripheral: peripheral, characteristic: characteristic)
        } else {
            peripheral.writeValue(data, for: characteristic, type: .withResponse)
        }
        
        if waitForResponse {
            return try await waitForResponse(timeout: InstaxConstants.responseTimeout)
        }
        
        return nil
    }
    
    /// Richiede informazioni alla stampante
    public func requestPrinterInfo() async throws -> InstaxPrinterInfo {
        // Richiedi info immagine
        let imageInfoPacket = InstaxPacket(
            eventType: .deviceInfoService,
            subCode: 0x00,
            payload: Data([InstaxInfoType.imageSupportInfo.rawValue])
        )
        
        _ = try await sendPacket(imageInfoPacket, waitForResponse: true)
        
        // Richiedi info batteria
        let batteryPacket = InstaxPacket(
            eventType: .deviceInfoService,
            subCode: 0x00,
            payload: Data([InstaxInfoType.batteryInfo.rawValue])
        )
        
        _ = try await sendPacket(batteryPacket, waitForResponse: true)
        
        // Richiedi info funzioni
        let functionPacket = InstaxPacket(
            eventType: .deviceInfoService,
            subCode: 0x00,
            payload: Data([InstaxInfoType.printerFunctionInfo.rawValue])
        )
        
        _ = try await sendPacket(functionPacket, waitForResponse: true)
        
        guard let info = printerInfo else {
            throw InstaxError.unexpectedResponse
        }
        
        return info
    }
    
    // MARK: - Private Methods
    
    private func sendLargePacket(_ data: Data, peripheral: CBPeripheral, characteristic: CBCharacteristic) async throws {
        let chunkSize = InstaxConstants.maxPacketSize
        let numChunks = Int(ceil(Double(data.count) / Double(chunkSize)))
        
        for i in 0..<numChunks {
            let start = i * chunkSize
            let end = min(start + chunkSize, data.count)
            let chunk = Data(data[start..<end])
            
            peripheral.writeValue(chunk, for: characteristic, type: .withResponse)
            
            // Piccola pausa tra i chunk
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }
    }
    
    private func waitForResponse(timeout: TimeInterval) async throws -> Data {
        try await withThrowingTaskGroup(of: Data.self) { group in
            group.addTask {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
                    Task { @MainActor [weak self] in
                        self?.responseContinuation = continuation
                        
                        // Timer timeout
                        self?.responseTimeoutTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { _ in
                            Task { @MainActor [weak self] in
                                self?.responseContinuation?.resume(throwing: InstaxError.timeout)
                                self?.responseContinuation = nil
                            }
                        }
                    }
                }
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw InstaxError.timeout
            }
            
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
    
    private func mapBluetoothState(_ state: CBManagerState) -> InstaxError {
        switch state {
        case .poweredOff:
            return .bluetoothPoweredOff
        case .unauthorized:
            return .bluetoothUnauthorized
        case .unsupported:
            return .bluetoothNotAvailable
        default:
            return .unknown
        }
    }
    
    private func parsePrinterResponse(_ data: Data) {
        guard data.count >= 7 else { return }
        
        // Valida checksum
        guard InstaxPacket.validateChecksum(packet: data) else {
            print("Checksum non valido")
            return
        }
        
        // Parsa header
        let header = (UInt16(data[0]) << 8) | UInt16(data[1])
        guard header == InstaxPacket.printerHeader else { return }
        
        // Parsa lunghezza
        let length = (UInt16(data[2]) << 8) | UInt16(data[3])
        guard data.count >= length else { return }
        
        // Parsa opcode
        let op1 = data[4]
        let op2 = data[5]
        
        // Parsa payload
        let payloadLength = Int(length) - 7
        let payload = payloadLength > 0 ? Data(data[6..<(6 + payloadLength)]) : Data()
        
        // Gestisci risposta
        handleResponse(op1: op1, op2: op2, payload: payload)
    }
    
    private func handleResponse(op1: UInt8, op2: UInt8, payload: Data) {
        // Info servizi
        if op1 == 0x00 && op2 == 0x01 && payload.count >= 1 {
            let infoType = payload[0]
            
            switch infoType {
            case InstaxInfoType.imageSupportInfo.rawValue:
                if payload.count >= 5 {
                    let width = (UInt16(payload[1]) << 8) | UInt16(payload[2])
                    let height = (UInt16(payload[3]) << 8) | UInt16(payload[4])
                    
                    let model: InstaxPrinterModel?
                    if width == 600 && height == 800 {
                        model = .miniLink
                    } else if width == 800 && height == 800 {
                        model = .squareLink
                    } else if width == 1260 && height == 840 {
                        model = .linkWide
                    } else {
                        model = nil
                    }
                    
                    printerInfo = InstaxPrinterInfo(
                        name: connectedPeripheral?.name ?? "Unknown",
                        address: connectedPeripheral?.identifier.uuidString ?? "",
                        model: model,
                        imageSize: CGSize(width: Int(width), height: Int(height))
                    )
                }
                
            case InstaxInfoType.batteryInfo.rawValue:
                if payload.count >= 3 {
                    let batteryState = Int(payload[1])
                    let batteryPercentage = Int(payload[2])
                    
                    if var info = printerInfo {
                        info = InstaxPrinterInfo(
                            name: info.name,
                            address: info.address,
                            model: info.model,
                            batteryPercentage: batteryPercentage,
                            batteryState: batteryState,
                            isCharging: info.isCharging,
                            photosLeft: info.photosLeft,
                            imageSize: info.imageSize,
                            firmwareVersion: info.firmwareVersion
                        )
                        printerInfo = info
                    }
                }
                
            case InstaxInfoType.printerFunctionInfo.rawValue:
                if payload.count >= 2 {
                    let dataByte = payload[1]
                    let photosLeft = Int(dataByte & 0x0F)
                    let isCharging = (dataByte & 0x80) != 0
                    
                    if var info = printerInfo {
                        info = InstaxPrinterInfo(
                            name: info.name,
                            address: info.address,
                            model: info.model,
                            batteryPercentage: info.batteryPercentage,
                            batteryState: info.batteryState,
                            isCharging: isCharging,
                            photosLeft: photosLeft,
                            imageSize: info.imageSize,
                            firmwareVersion: info.firmwareVersion
                        )
                        printerInfo = info
                    }
                }
                
            default:
                break
            }
        }
        
        // Completa la continuation se in attesa
        if let continuation = responseContinuation {
            let responseData = Data([op1, op2] + payload)
            continuation.resume(returning: responseData)
            responseContinuation = nil
            responseTimeoutTimer?.invalidate()
            responseTimeoutTimer = nil
        }
    }
}

// MARK: - CBCentralManagerDelegate

extension InstaxBLEManager: CBCentralManagerDelegate {
    
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("Bluetooth acceso")
        case .poweredOff:
            connectionState = .error(.bluetoothPoweredOff)
        case .unauthorized:
            connectionState = .error(.bluetoothUnauthorized)
        case .unsupported:
            connectionState = .error(.bluetoothNotAvailable)
        default:
            connectionState = .error(.unknown)
        }
    }
    
    public func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        // Filtra solo stampanti Instax
        guard let name = peripheral.name,
              name.hasPrefix("INSTAX-") else { return }
        
        // Aggiungi se non già presente
        if !discoveredPrinters.contains(where: { $0.identifier == peripheral.identifier }) {
            discoveredPrinters.append(peripheral)
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connesso a: \(peripheral.name ?? "Unknown")")
        connectionContinuation?.resume()
        connectionContinuation = nil
    }
    
    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("Connessione fallita: \(error?.localizedDescription ?? "Unknown error")")
        connectionContinuation?.resume(throwing: InstaxError.connectionFailed)
        connectionContinuation = nil
        connectionState = .error(.connectionFailed)
    }
    
    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("Disconnesso da: \(peripheral.name ?? "Unknown")")
        
        connectedPeripheral = nil
        writeCharacteristic = nil
        notifyCharacteristic = nil
        connectionState = .disconnected
        printerInfo = nil
    }
}

// MARK: - CBPeripheralDelegate

extension InstaxBLEManager: CBPeripheralDelegate {
    
    public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            print("Errore scoperta servizi: \(error.localizedDescription)")
            connectionState = .error(.serviceNotFound)
            return
        }
        
        guard let services = peripheral.services else { return }
        
        for service in services {
            if service.uuid == InstaxUUID.service {
                peripheral.discoverCharacteristics(
                    [InstaxUUID.writeCharacteristic, InstaxUUID.notifyCharacteristic],
                    for: service
                )
            }
        }
    }
    
    public func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        if let error = error {
            print("Errore scoperta characteristics: \(error.localizedDescription)")
            connectionState = .error(.characteristicNotFound)
            return
        }
        
        guard let characteristics = service.characteristics else { return }
        
        for characteristic in characteristics {
            if characteristic.uuid == InstaxUUID.writeCharacteristic {
                writeCharacteristic = characteristic
            } else if characteristic.uuid == InstaxUUID.notifyCharacteristic {
                notifyCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
        
        // Se entrambe le characteristic sono state trovate, la connessione è completa
        if writeCharacteristic != nil && notifyCharacteristic != nil {
            connectionState = .connected
        }
    }
    
    public func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        if let error = error {
            print("Errore lettura characteristic: \(error.localizedDescription)")
            return
        }
        
        guard let data = characteristic.value else { return }
        
        parsePrinterResponse(data)
    }
    
    public func peripheral(
        _ peripheral: CBPeripheral,
        didWriteValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        if let error = error {
            print("Errore scrittura characteristic: \(error.localizedDescription)")
        }
    }
}

// MARK: - Error Extension

extension InstaxError {
    static var notConnected: InstaxError {
        .connectionFailed
    }
}
