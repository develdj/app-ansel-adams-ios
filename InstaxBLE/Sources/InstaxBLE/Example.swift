// Example.swift
// Zone System Master - Instax BLE Integration
// Esempio di utilizzo completo del framework

import SwiftUI
import Combine

// MARK: - Esempio 1: Utilizzo Base con UI Predefinita

struct BasicExampleView: View {
    var body: some View {
        // UI completa predefinita
        InstaxPrintView(onPrintComplete: {
            print("Stampa completata!")
        })
    }
}

// MARK: - Esempio 2: Utilizzo Personalizzato

struct CustomExampleView: View {
    @StateObject private var viewModel = InstaxPrintViewModel()
    @State private var selectedImage: UIImage?
    @State private var isConnecting = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Stato connessione
                ConnectionStatusView(state: viewModel.connectionState)
                
                // Selezione immagine
                ImageSelectionView(image: $selectedImage)
                    .onChange(of: selectedImage) { newImage in
                        if let image = newImage {
                            viewModel.setImage(image)
                        }
                    }
                
                // Preview
                if let preview = viewModel.previewImage {
                    Image(uiImage: preview)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 200)
                        .cornerRadius(8)
                }
                
                // Controlli
                VStack(spacing: 12) {
                    // Selezione modello
                    Picker("Modello", selection: $viewModel.selectedModel) {
                        ForEach(InstaxPrinterModel.allCases) { model in
                            Text(model.rawValue).tag(model)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    // Toggle B/N
                    Toggle("Bianco e Nero", isOn: $viewModel.convertToBlackAndWhite)
                    
                    // Toggle dithering
                    Toggle("Dithering", isOn: $viewModel.enableDithering)
                    
                    // Toggle stampa abilitata
                    Toggle("Stampa Abilitata", isOn: $viewModel.printEnabled)
                        .tint(.green)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                
                Spacer()
                
                // Pulsanti azione
                HStack(spacing: 16) {
                    Button(action: { connectToPrinter() }) {
                        if isConnecting {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Label("Connetti", systemImage: "link")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.connectionState == .connected)
                    
                    Button(action: { viewModel.disconnect() }) {
                        Label("Disconnetti", systemImage: "xmark.circle")
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .disabled(viewModel.connectionState != .connected)
                    
                    Spacer()
                    
                    Button(action: { viewModel.printImage() }) {
                        Label("Stampa", systemImage: "printer.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!viewModel.canPrint)
                }
            }
            .padding()
            .navigationTitle("Stampa Instax")
            .alert("Errore", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage)
            }
        }
    }
    
    private func connectToPrinter() {
        isConnecting = true
        Task {
            await viewModel.scanPrinters()
            isConnecting = false
        }
    }
}

// MARK: - Esempio 3: Utilizzo Programmatico

class ProgrammaticExample {
    let bleManager = InstaxBLEManager()
    let printManager = PrintJobManager()
    var cancellables = Set<AnyCancellable>()
    
    func setup() {
        // Monitora stato connessione
        bleManager.$connectionState
            .sink { state in
                print("Stato: \(state.description)")
            }
            .store(in: &cancellables)
        
        // Monitora info stampante
        bleManager.$printerInfo
            .sink { info in
                if let info = info {
                    print("Batteria: \(info.batteryPercentage)%")
                    print("Carta: \(info.photosLeft) fogli")
                }
            }
            .store(in: &cancellables)
    }
    
    func printImage(_ image: UIImage) async throws {
        // 1. Verifica Bluetooth
        guard bleManager.connectionState == .connected else {
            // Connetti se necessario
            try await bleManager.connectToFirstPrinter()
        }
        
        // 2. Richiedi info stampante
        let info = try await bleManager.requestPrinterInfo()
        print("Stampante: \(info.name)")
        
        // 3. Verifica carta
        guard info.photosLeft > 0 else {
            throw InstaxError.outOfPaper
        }
        
        // 4. Verifica batteria
        guard info.batteryPercentage > 10 else {
            throw InstaxError.batteryLow
        }
        
        // 5. Configura preprocessing
        ImagePreprocessor.shared.convertToBlackAndWhite = true
        ImagePreprocessor.shared.enableDithering = true
        ImagePreprocessor.shared.ditheringType = .floydSteinberg
        
        // 6. Preprocessa immagine
        guard let model = info.model else {
            throw InstaxError.unknown
        }
        
        let processedData = try await ImagePreprocessor.shared.preprocessImage(
            image,
            for: model
        )
        
        print("Immagine preprocessata: \(processedData.count) bytes")
        
        // 7. Configura stampa
        printManager.printEnabled = true
        printManager.maxRetries = 3
        
        // 8. Aggiungi alla coda
        printManager.addJob(image: image, model: model)
        
        // 9. Attendi completamento
        printManager.onPrintCompleted = { job in
            print("Stampa completata: \(job.id)")
        }
        
        printManager.onPrintFailed = { job, error in
            print("Stampa fallita: \(error.localizedDescription)")
        }
    }
    
    func printMultipleImages(_ images: [UIImage]) async throws {
        for image in images {
            try await printImage(image)
            // Attendi tra una stampa e l'altra
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 secondi
        }
    }
    
    func disconnect() {
        bleManager.disconnect()
    }
}

// MARK: - Esempio 4: Gestione Avanzata

class AdvancedExample {
    let bleManager = InstaxBLEManager()
    
    /// Stampa con callback dettagliati
    func printWithCallbacks(image: UIImage, model: InstaxPrinterModel) {
        let printManager = PrintJobManager(bleManager: bleManager)
        
        printManager.onPrintStarted = { job in
            print("Stampa iniziata: \(job.id)")
        }
        
        printManager.onPrintProgress = { job, progress in
            print("Progresso: \(Int(progress * 100))%")
        }
        
        printManager.onPrintCompleted = { job in
            print("Stampa completata: \(job.id)")
        }
        
        printManager.onPrintFailed = { job, error in
            print("Stampa fallita: \(error.localizedDescription)")
        }
        
        printManager.printEnabled = true
        printManager.addJob(image: image, model: model)
    }
    
    /// Configura LED stampante
    func configureLED() async throws {
        guard let peripheral = bleManager.connectedPeripheral,
              let characteristic = bleManager.writeCharacteristic else {
            throw InstaxError.notConnected
        }
        
        let printer = InstaxPrinter(
            model: .miniLink,
            name: "INSTAX-12345678",
            address: "FA:AB:BC:..."
        )
        
        // Pattern arcobaleno
        let rainbowPacket = printer.createLEDPatternPacket(pattern: .rainbow())
        _ = try await bleManager.sendPacket(rainbowPacket, waitForResponse: false)
        
        // Attendi 5 secondi
        try await Task.sleep(nanoseconds: 5_000_000_000)
        
        // Spegni LED
        let offPacket = printer.createLEDPatternPacket(pattern: .off())
        _ = try await bleManager.sendPacket(offPacket, waitForResponse: false)
    }
    
    /// Monitora accelerometro (Mini Link 2/3)
    func monitorAccelerometer() async throws {
        let printer = InstaxPrinter(
            model: .miniLink2,
            name: "INSTAX-12345678",
            address: "FA:AB:BC:..."
        )
        
        let packet = printer.createXYZAxisInfoPacket()
        
        // Invia richiesta ogni secondo
        while bleManager.connectionState == .connected {
            if let response = try? await bleManager.sendPacket(packet, waitForResponse: true) {
                // Parsa dati accelerometro
                print("Accelerometro: \(response.hexString)")
            }
            try await Task.sleep(nanoseconds: 1_000_000_000)
        }
    }
}

// MARK: - Esempio 5: SwiftUI con ViewModel Personalizzato

class CustomPrintViewModel: InstaxPrintViewModel {
    @Published var customProperty: String = ""
    
    override init() {
        super.init()
        setupCustomBindings()
    }
    
    private func setupCustomBindings() {
        // Aggiungi binding personalizzati
        $connectionState
            .sink { [weak self] state in
                self?.customProperty = "Stato: \(state.description)"
            }
            .store(in: &cancellables)
    }
    
    func customPrintFunction() {
        // Logica di stampa personalizzata
        print("Stampa personalizzata")
    }
}

struct CustomPrintViewWithViewModel: View {
    @StateObject private var viewModel = CustomPrintViewModel()
    
    var body: some View {
        VStack {
            Text(viewModel.customProperty)
            
            Button("Stampa Personalizzata") {
                viewModel.customPrintFunction()
            }
        }
    }
}

// MARK: - View di Supporto

struct ConnectionStatusView: View {
    let state: InstaxConnectionState
    
    var body: some View {
        HStack {
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
            
            Text(state.description)
                .font(.caption)
            
            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
    
    private var statusColor: Color {
        switch state {
        case .connected: return .green
        case .connecting, .scanning: return .orange
        case .error: return .red
        default: return .gray
        }
    }
}

struct ImageSelectionView: View {
    @Binding var image: UIImage?
    @State private var showImagePicker = false
    
    var body: some View {
        VStack {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 150)
                    .cornerRadius(8)
            } else {
                Button("Seleziona Immagine") {
                    showImagePicker = true
                }
                .frame(maxWidth: .infinity, minHeight: 150)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(selectedImage: $image)
        }
    }
}

// MARK: - Esempio 6: Background Printing

class BackgroundPrintManager {
    let bleManager = InstaxBLEManager()
    let printManager = PrintJobManager()
    
    func printInBackground(images: [UIImage], model: InstaxPrinterModel) {
        Task {
            do {
                // Connetti
                try await bleManager.connectToFirstPrinter()
                
                // Configura
                printManager.printEnabled = true
                
                // Aggiungi tutti i job
                for image in images {
                    printManager.addJob(image: image, model: model)
                }
                
                // Attendi completamento
                while !printManager.queue.isEmpty || printManager.isProcessing {
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                }
                
                // Disconnetti
                bleManager.disconnect()
                
            } catch {
                print("Errore: \(error)")
            }
        }
    }
}

// MARK: - Esempio 7: Integrazione con App Fotocamera

struct CameraIntegrationExample: View {
    @StateObject private var viewModel = InstaxPrintViewModel()
    @State private var capturedImage: UIImage?
    @State private var showCamera = false
    
    var body: some View {
        VStack {
            if let image = capturedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                
                Button("Stampa immediatamente") {
                    Task {
                        try? await viewModel.printImage(image)
                    }
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button("Scatta Foto") {
                    showCamera = true
                }
            }
        }
        .sheet(isPresented: $showCamera) {
            // La tua view fotocamera
            Text("Fotocamera")
        }
        .onChange(of: capturedImage) { newImage in
            if let image = newImage {
                viewModel.setImage(image)
            }
        }
    }
}

// MARK: - Esempio 8: Gestione Errori Avanzata

struct ErrorHandlingExample {
    func handlePrintError(_ error: Error) -> String {
        if let instaxError = error as? InstaxError {
            switch instaxError {
            case .bluetoothPoweredOff:
                return "Accendi il Bluetooth per continuare"
            case .printerNotFound:
                return "Nessuna stampante trovata. Accendi la stampante e riprova."
            case .outOfPaper:
                return "Carta esaurita. Inserisci una nuova cartuccia."
            case .batteryLow:
                return "Batteria scarica. Carica la stampante."
            case .imageTooLarge:
                return "Immagine troppo grande. Riduci la risoluzione."
            default:
                return instaxError.localizedDescription
            }
        }
        return error.localizedDescription
    }
    
    func retryPrint(image: UIImage, model: InstaxPrinterModel, maxRetries: Int = 3) async {
        var attempts = 0
        
        while attempts < maxRetries {
            do {
                try await printImage(image, model: model)
                print("Stampa riuscita al tentativo \(attempts + 1)")
                return
            } catch {
                attempts += 1
                print("Tentativo \(attempts) fallito: \(error)")
                
                if attempts < maxRetries {
                    // Attendi prima di riprovare
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                }
            }
        }
        
        print("Stampa fallita dopo \(maxRetries) tentativi")
    }
    
    private func printImage(_ image: UIImage, model: InstaxPrinterModel) async throws {
        // Implementazione stampa
    }
}
