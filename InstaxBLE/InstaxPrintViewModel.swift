// InstaxPrintViewModel.swift
// Zone System Master - Instax BLE Integration
// ViewModel per gestione logica stampa Instax

import SwiftUI
import Combine
import CoreBluetooth

@MainActor
public final class InstaxPrintViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var connectionState: InstaxConnectionState = .disconnected
    @Published public var printerInfo: InstaxPrinterInfo?
    @Published public var discoveredPrinters: [DiscoveredPrinter] = []
    @Published public var selectedModel: InstaxPrinterModel = .miniLink
    @Published public var previewImage: UIImage?
    @Published public var sourceImage: UIImage?
    
    // Stampa
    @Published public var printEnabled = false
    @Published public var isPrinting = false
    @Published public var printProgress: Double?
    @Published public var printStatus = ""
    @Published public var printQueue: [InstaxPrintJob] = []
    
    // Errori
    @Published public var showError = false
    @Published public var errorMessage = ""
    
    // Impostazioni immagine
    @Published public var convertToBlackAndWhite = true
    @Published public var blackAndWhiteContrast: CGFloat = 1.1
    @Published public var enableDithering = true
    @Published public var ditheringType: DitheringType = .floydSteinberg
    @Published public var jpegQuality: CGFloat = 0.92
    @Published public var maxRetries = 3
    
    // MARK: - Private Properties
    
    private let bleManager = InstaxBLEManager()
    private let printManager: PrintJobManager
    private var cancellables = Set<AnyCancellable>()
    private var currentImageData: Data?
    
    public var onPrintComplete: (() -> Void)?
    
    // MARK: - Computed Properties
    
    public var canPrint: Bool {
        guard printEnabled,
              connectionState == .connected,
              previewImage != nil,
              !isPrinting else {
            return false
        }
        return true
    }
    
    // MARK: - Initialization
    
    public init() {
        self.printManager = PrintJobManager(bleManager: bleManager)
        setupBindings()
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        // Stato connessione
        bleManager.$connectionState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.connectionState = state
            }
            .store(in: &cancellables)
        
        // Info stampante
        bleManager.$printerInfo
            .receive(on: DispatchQueue.main)
            .sink { [weak self] info in
                self?.printerInfo = info
                if let model = info?.model {
                    self?.selectedModel = model
                }
            }
            .store(in: &cancellables)
        
        // Printeri scoperti
        bleManager.$discoveredPrinters
            .receive(on: DispatchQueue.main)
            .sink { [weak self] peripherals in
                self?.discoveredPrinters = peripherals.map { peripheral in
                    DiscoveredPrinter(
                        name: peripheral.name ?? "Sconosciuto",
                        address: peripheral.identifier.uuidString,
                        peripheral: peripheral
                    )
                }
            }
            .store(in: &cancellables)
        
        // Coda stampe
        printManager.$queue
            .receive(on: DispatchQueue.main)
            .sink { [weak self] queue in
                self?.printQueue = queue
            }
            .store(in: &cancellables)
        
        // Job corrente
        printManager.$currentJob
            .receive(on: DispatchQueue.main)
            .sink { [weak self] job in
                guard let job = job else {
                    self?.isPrinting = false
                    self?.printProgress = nil
                    self?.printStatus = ""
                    return
                }
                
                self?.isPrinting = true
                self?.printStatus = job.state.description
                
                if case .sending(let progress) = job.state {
                    self?.printProgress = progress
                } else if case .completed = job.state {
                    self?.isPrinting = false
                    self?.printProgress = nil
                    self?.onPrintComplete?()
                }
            }
            .store(in: &cancellables)
        
        // Sincronizza impostazioni
        $convertToBlackAndWhite
            .sink { [weak self] value in
                ImagePreprocessor.shared.convertToBlackAndWhite = value
            }
            .store(in: &cancellables)
        
        $blackAndWhiteContrast
            .sink { [weak self] value in
                ImagePreprocessor.shared.blackAndWhiteContrast = value
            }
            .store(in: &cancellables)
        
        $enableDithering
            .sink { [weak self] value in
                ImagePreprocessor.shared.enableDithering = value
            }
            .store(in: &cancellables)
        
        $jpegQuality
            .sink { [weak self] value in
                ImagePreprocessor.shared.jpegQuality = value
            }
            .store(in: &cancellables)
        
        $maxRetries
            .sink { [weak self] value in
                self?.printManager.maxRetries = value
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    /// Imposta l'immagine da stampare
    public func setImage(_ image: UIImage) {
        sourceImage = image
        updatePreview()
    }
    
    /// Aggiorna la preview
    public func updatePreview() {
        guard let image = sourceImage else { return }
        
        Task {
            do {
                let preprocessed = try await ImagePreprocessor.shared.preprocessImage(
                    image,
                    for: selectedModel
                )
                
                if let uiImage = UIImage(data: preprocessed) {
                    await MainActor.run {
                        self.previewImage = uiImage
                        self.currentImageData = preprocessed
                    }
                }
            } catch {
                showError(message: error.localizedDescription)
            }
        }
    }
    
    /// Connette a una stampante
    public func connectToPrinter(_ printer: DiscoveredPrinter) async {
        guard let peripheral = printer.peripheral as? CBPeripheral else {
            showError(message: "Stampante non valida")
            return
        }
        
        do {
            try await bleManager.connect(to: peripheral)
            try await Task.sleep(nanoseconds: 500_000_000) // Attendi scoperta servizi
            _ = try? await bleManager.requestPrinterInfo()
        } catch {
            showError(message: error.localizedDescription)
        }
    }
    
    /// Disconnette dalla stampante
    public func disconnect() {
        bleManager.disconnect()
    }
    
    /// Avvia scansione stampanti
    public func scanPrinters() async {
        do {
            try await bleManager.startScan(timeout: 10.0)
        } catch {
            showError(message: error.localizedDescription)
        }
    }
    
    /// Stampa l'immagine corrente
    public func printImage() {
        guard let image = previewImage else {
            showError(message: "Nessuna immagine selezionata")
            return
        }
        
        guard connectionState == .connected else {
            showError(message: "Stampante non connessa")
            return
        }
        
        guard printEnabled else {
            showError(message: "Abilita la stampa nelle impostazioni")
            return
        }
        
        printManager.printEnabled = true
        printManager.addJob(image: image, model: selectedModel)
    }
    
    /// Stampa un'immagine immediatamente
    public func printImage(_ image: UIImage) async throws {
        guard connectionState == .connected else {
            throw InstaxError.notConnected
        }
        
        guard printEnabled else {
            throw InstaxError.printCancelled
        }
        
        try await printManager.printImmediately(image: image, model: selectedModel)
    }
    
    /// Cancella la coda
    public func clearQueue() {
        printManager.clearQueue()
    }
    
    /// Aggiorna info stampante
    public func refreshPrinterInfo() {
        Task {
            do {
                _ = try await bleManager.requestPrinterInfo()
            } catch {
                showError(message: error.localizedDescription)
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func showError(message: String) {
        errorMessage = message
        showError = true
    }
}

// MARK: - DitheringType Conversion

extension DitheringType {
    var preprocessorType: ImagePreprocessor.DitheringType {
        switch self {
        case .floydSteinberg:
            return .floydSteinberg
        case .atkinson:
            return .atkinson
        case .jarvisJudiceNinke:
            return .jarvisJudiceNinke
        case .stucki:
            return .stucki
        case .burkes:
            return .burkes
        case .sierra:
            return .sierra
        }
    }
}

// MARK: - InstaxError Extension

extension InstaxError {
    static var notConnected: InstaxError {
        .connectionFailed
    }
}
