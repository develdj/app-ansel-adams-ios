# Zone System Master - Instax BLE Integration

Framework Swift completo per la stampa diretta su stampanti Instax Fujifilm via Bluetooth Low Energy (BLE).

## Caratteristiche

- **Supporto multi-modello**: Instax Mini Link, Mini Link 2, Mini Link 3, Mini LiPlay, Square Link, Link Wide
- **Protocollo BLE completo**: Implementazione nativa del protocollo Instax
- **Preprocessing avanzato**: Conversione B/N, dithering, compressione JPEG
- **Gestione coda**: Coda stampe con retry automatico
- **UI SwiftUI**: Interfaccia utente completa e personalizzabile
- **Error handling**: Gestione completa degli errori comuni

## Requisiti

- iOS 15.0+
- Swift 6.0+
- Xcode 15.0+
- Framework: CoreBluetooth, UIKit, SwiftUI, Combine

## Installazione

### Swift Package Manager

Aggiungi al tuo `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/InstaxBLE.git", from: "1.0.0")
]
```

### Manualmente

Copia tutti i file `.swift` nella cartella del tuo progetto.

## Configurazione

### Info.plist

Aggiungi le seguenti chiavi al tuo `Info.plist`:

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>Questa app utilizza il Bluetooth per connettersi alle stampanti Instax.</string>

<key>UIBackgroundModes</key>
<array>
    <string>bluetooth-central</string>
</array>
```

## Utilizzo

### Utilizzo Base

```swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        InstaxPrintView()
    }
}
```

### Utilizzo Avanzato

```swift
import SwiftUI

struct MyPrintView: View {
    @StateObject private var viewModel = InstaxPrintViewModel()
    @State private var selectedImage: UIImage?
    
    var body: some View {
        VStack {
            // Preview immagine
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            }
            
            // Controlli
            Button("Stampa") {
                if let image = selectedImage {
                    Task {
                        try? await viewModel.printImage(image)
                    }
                }
            }
            .disabled(!viewModel.canPrint)
        }
        .onAppear {
            // Configura
            viewModel.printEnabled = true
            viewModel.selectedModel = .miniLink
            viewModel.convertToBlackAndWhite = true
            viewModel.enableDithering = true
        }
    }
}
```

### Utilizzo Programmatico

```swift
import UIKit

class PrintManager {
    let bleManager = InstaxBLEManager()
    let printManager = PrintJobManager()
    
    func printImage(_ image: UIImage) async throws {
        // 1. Connetti alla stampante
        try await bleManager.connectToFirstPrinter()
        
        // 2. Richiedi info
        let info = try await bleManager.requestPrinterInfo()
        print("Stampante: \(info.name)")
        print("Batteria: \(info.batteryPercentage)%")
        print("Carta rimanente: \(info.photosLeft)")
        
        // 3. Preprocessa immagine
        let processedData = try await ImagePreprocessor.shared.preprocessImage(
            image,
            for: .miniLink
        )
        
        // 4. Stampa
        printManager.printEnabled = true
        printManager.addJob(image: image, model: .miniLink)
    }
}
```

## Protocollo BLE

### UUID

| Tipo | UUID |
|------|------|
| Service | `70954782-2d83-473d-9e5f-81e1d02d5273` |
| Write Characteristic | `70954783-2d83-473d-9e5f-81e1d02d5273` |
| Notify Characteristic | `70954784-2d83-473d-9e5f-81e1d02d5273` |

### Formato Pacchetto

```
[Header: 2 bytes] [Length: 2 bytes] [OpCode: 2 bytes] [Payload: n bytes] [Checksum: 1 byte]
```

- Header client → printer: `0x4162` ('Ab')
- Header printer → client: `0x6142` ('aB')
- Checksum: `(255 - (sum(bytes) & 255)) & 255`

### Comandi Principali

| Comando | OpCode | Descrizione |
|---------|--------|-------------|
| PRINT_IMAGE_DOWNLOAD_START | 0x10, 0x00 | Inizio download immagine |
| PRINT_IMAGE_DOWNLOAD_DATA | 0x10, 0x01 | Dati immagine (chunk) |
| PRINT_IMAGE_DOWNLOAD_END | 0x10, 0x02 | Fine download immagine |
| PRINT_IMAGE | 0x10, 0x80 | Avvia stampa |
| DEVICE_INFO_SERVICE | 0x00, 0x01 | Richiedi info dispositivo |

## Modelli Supportati

| Modello | Risoluzione | Chunk Size | Formato |
|---------|-------------|------------|---------|
| Mini Link | 600×800 | 900 | Mini |
| Mini Link 2 | 600×800 | 900 | Mini |
| Mini Link 3 | 600×800 | 900 | Mini |
| Mini LiPlay | 600×800 | 900 | Mini |
| Square Link | 800×800 | 1808 | Square |
| Link Wide | 1260×840 | 900 | Wide |

## Preprocessing Immagini

### Conversione B/N

```swift
ImagePreprocessor.shared.convertToBlackAndWhite = true
ImagePreprocessor.shared.blackAndWhiteContrast = 1.1
```

### Dithering

```swift
ImagePreprocessor.shared.enableDithering = true
ImagePreprocessor.shared.ditheringType = .floydSteinberg
```

Tipi di dithering supportati:
- Floyd-Steinberg
- Atkinson
- Jarvis-Judice-Ninke
- Stucki
- Burkes
- Sierra
- Ordered (Bayer)

### Compressione

```swift
ImagePreprocessor.shared.jpegQuality = 0.92
```

## Gestione Errori

```swift
do {
    try await bleManager.connectToFirstPrinter()
} catch InstaxError.bluetoothPoweredOff {
    // Bluetooth spento
} catch InstaxError.printerNotFound {
    // Stampante non trovata
} catch InstaxError.connectionTimeout {
    // Timeout connessione
} catch {
    // Altri errori
}
```

## LED Patterns

```swift
let printer = InstaxPrinter(model: .miniLink, name: "INSTAX-12345678", address: "FA:AB:BC:...")

// Pattern arcobaleno
let rainbowPacket = printer.createLEDPatternPacket(pattern: .rainbow())

// Pattern pulsante
let pulsePacket = printer.createLEDPatternPacket(pattern: .pulseGreen())

// Pattern personalizzato
let customPattern = LEDPattern(
    colors: [
        LEDPattern.LEDColor(red: 255, green: 0, blue: 0),
        LEDPattern.LEDColor(red: 0, green: 255, blue: 0)
    ],
    speed: 5,
    repeatCount: 255
)
let customPacket = printer.createLEDPatternPacket(pattern: customPattern)
```

## Notifiche

```swift
NotificationCenter.default.addObserver(
    forName: .instaxPrinterConnected,
    object: nil,
    queue: .main
) { notification in
    if let info = notification.userInfo?[.instaxPrinterInfoKey] as? InstaxPrinterInfo {
        print("Connesso a: \(info.name)")
    }
}

NotificationCenter.default.addObserver(
    forName: .instaxPrintCompleted,
    object: nil,
    queue: .main
) { _ in
    print("Stampa completata!")
}
```

## Debug

```swift
// Abilita logging
InstaxLogger.isEnabled = true

// Log manuale
InstaxLogger.log("Messaggio di debug")
InstaxLogger.logData(data, label: "Pacchetto ricevuto")
InstaxLogger.logError(error)
```

## Struttura File

```
InstaxBLE/
├── InstaxTypes.swift          # Tipi, costanti, strutture
├── InstaxBLEManager.swift     # Gestione CoreBluetooth
├── InstaxPrinter.swift        # Modelli e comandi
├── ImagePreprocessor.swift    # Preprocessing immagini
├── PrintJobManager.swift      # Gestione coda stampe
├── InstaxPrintView.swift      # UI SwiftUI
├── InstaxPrintViewModel.swift # ViewModel
├── InstaxBLEExtensions.swift  # Estensioni utili
├── Info.plist                 # Configurazione
└── README.md                  # Documentazione
```

## Licenza

MIT License - Vedi LICENSE per dettagli.

## Crediti

- Protocollo BLE reverse-engineered dai progetti:
  - [InstaxBLE](https://github.com/javl/InstaxBLE) by javl
  - [instax_api](https://github.com/jpwsutton/instax_api) by jpwsutton
  - [InstaxLink](https://github.com/paorin/InstaxLink) by paorin
  - [instax-link-web](https://github.com/linssenste/instax-link-web) by linssenste

## Contributi

Contributi welcome! Per favore apri una issue o pull request.

## Disclaimer

Questo progetto non è affiliato con Fujifilm. Instax è un marchio registrato di Fujifilm Corporation.
