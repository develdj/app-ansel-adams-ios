# Struttura File - Instax BLE Integration

## File Creati

### Core Framework (Sources/InstaxBLE/)

1. **InstaxTypes.swift** (11,308 bytes)
   - UUID BLE Instax
   - Enum modelli stampante
   - Event Type e Info Type
   - Stato connessione e stampa
   - Errori
   - Informazioni stampante
   - Job di stampa
   - Struttura pacchetto Instax
   - Costanti

2. **InstaxBLEManager.swift** (19,276 bytes)
   - Gestione CoreBluetooth
   - Scan dispositivi
   - Connessione/disconnessione
   - Invio/ricezione pacchetti
   - Gestione stato
   - CBCentralManagerDelegate
   - CBPeripheralDelegate

3. **InstaxPrinter.swift** (12,875 bytes)
   - Modelli stampante
   - Comandi specifici
   - LED Patterns
   - Print Settings
   - Printer Status

4. **ImagePreprocessor.swift** (15,983 bytes)
   - Conversione formato
   - Conversione B/N
   - Dithering algoritmi:
     - Floyd-Steinberg
     - Atkinson
     - Jarvis-Judice-Ninke
     - Stucki
     - Burkes
     - Sierra
     - Ordered (Bayer)
   - Compressione JPEG

5. **PrintJobManager.swift** (9,101 bytes)
   - Coda stampe
   - Progress tracking
   - Error handling
   - Retry logic

6. **InstaxPrintView.swift** (20,576 bytes)
   - UI SwiftUI completa
   - Preview immagine
   - Selezione modello
   - Controlli stampa
   - Coda stampe
   - ImagePicker
   - PrinterSelectorView
   - PrintSettingsView

7. **InstaxPrintViewModel.swift** (9,518 bytes)
   - ViewModel per UI
   - Gestione stato
   - Bindings
   - Logica business

8. **InstaxBLEExtensions.swift** (12,378 bytes)
   - Estensioni Data
   - Estensioni String
   - Estensioni CBPeripheral
   - Estensioni UIImage
   - Estensioni CGSize
   - Logger
   - Notification names

9. **Example.swift** (16,155 bytes)
   - 8 esempi di utilizzo:
     1. Utilizzo base
     2. Utilizzo personalizzato
     3. Utilizzo programmatico
     4. Gestione avanzata
     5. SwiftUI con ViewModel
     6. Background printing
     7. Integrazione fotocamera
     8. Gestione errori

### Test (Tests/InstaxBLETests/)

10. **InstaxBLETests.swift** (12,196 bytes)
    - Test InstaxPacket
    - Test InstaxPrinterModel
    - Test ImagePreprocessor
    - Test InstaxError
    - Test LEDPattern
    - Test Data extensions
    - Test CGSize extensions
    - Test InstaxPrintSettings
    - Test InstaxPrinterInfo
    - Performance tests
    - Integration tests

### Configurazione

11. **Package.swift** (877 bytes)
    - Configurazione SPM
    - Target iOS 15+
    - Swift 5.9+

12. **Info.plist** (1,716 bytes)
    - Autorizzazioni Bluetooth
    - Background modes
    - Configurazione app

### Documentazione

13. **README.md** (7,926 bytes)
    - Installazione
    - Utilizzo
    - Protocollo BLE
    - Modelli supportati
    - Preprocessing
    - Gestione errori
    - LED patterns
    - Notifiche

14. **FILE_STRUCTURE.md** (Questo file)
    - Riepilogo struttura

## Protocollo BLE Implementato

### UUID
- Service: `70954782-2d83-473d-9e5f-81e1d02d5273`
- Write Characteristic: `70954783-2d83-473d-9e5f-81e1d02d5273`
- Notify Characteristic: `70954784-2d83-473d-9e5f-81e1d02d5273`

### Formato Pacchetto
```
[Header: 2 bytes] [Length: 2 bytes] [OpCode: 2 bytes] [Payload: n bytes] [Checksum: 1 byte]
```

### Comandi Supportati
- PRINT_IMAGE_DOWNLOAD_START (0x10, 0x00)
- PRINT_IMAGE_DOWNLOAD_DATA (0x10, 0x01)
- PRINT_IMAGE_DOWNLOAD_END (0x10, 0x02)
- PRINT_IMAGE (0x10, 0x80)
- DEVICE_INFO_SERVICE (0x00, 0x01)
- LED_PATTERN_SETTINGS (0x30, 0x01)

## Modelli Supportati

| Modello | Risoluzione | Chunk Size |
|---------|-------------|------------|
| Mini Link | 600×800 | 900 |
| Mini Link 2 | 600×800 | 900 |
| Mini Link 3 | 600×800 | 900 |
| Mini LiPlay | 600×800 | 900 |
| Square Link | 800×800 | 1808 |
| Link Wide | 1260×840 | 900 |

## Totale Linee di Codice

- Core Framework: ~2,500 linee
- Test: ~400 linee
- Documentazione: ~300 linee
- **Totale: ~3,200 linee**
