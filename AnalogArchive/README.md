# Zone System Master — Analog Archive Manager

Un'applicazione iOS completa per la gestione dell'archivio fotografico analogico, progettata per fotografi che utilizzano pellicola e vogliono tenere traccia di ogni aspetto del processo fotografico.

## Caratteristiche Principali

### 📸 Gestione Rullini (Roll)
- Registrazione completa dei rullini caricati
- Supporto per tutte le marche di pellicola (Ilford, Kodak, Fujifilm, Foma, Adox, etc.)
- Gestione ISO nominale ed effettiva (push/pull processing)
- Formati supportati: 35mm, 120, 220, 4x5, 8x10, half-frame, etc.
- Tracking dello stato: caricato → in corso → esposto → sviluppato → scannerizzato → archiviato

### 📷 Registro Esposizioni (Exposure)
- Dettagli completi di ogni scatto:
  - Tempo e diaframma
  - Camera e obiettivo utilizzati
  - Lunghezza focale
  - Distanza di messa a fuoco
  - Filtri applicati
  - Condizioni di luce
  - Modalità di misurazione
- Supporto per il Sistema Zona (Zone System)
- Geolocalizzazione GPS
- Valutazione e classificazione "keepers"

### 🖼️ Gestione Stampe (Print)
- Registrazione dettagliata delle stampe in camera oscura:
  - Ingranditore e obiettivo utilizzati
  - Tipo e grado di carta
  - Filtri multigrado
  - Split grade printing
  - Tempi di esposizione base
  - Sviluppo, stop, fissaggio, lavaggio
  - Dodge & Burn operations
  - Tonalizzazione

### 📊 Statistiche e Analisi
- Dashboard con statistiche generali
- Grafici di attività mensile
- Distribuzione per pellicola, camera, obiettivo
- Analisi temporale (ora, giorno, mese)
- Distribuzione di ISO, diaframmi, tempi, focali
- Keeper rate per ogni categoria

### 📄 Esportazione PDF
- Registro completo stampabile per ogni rullino
- Archivio completo in formato PDF professionale
- Esportazione "Best Of" (solo keepers)
- Template professionale con:
  - Copertina con informazioni pellicola
  - Dettagli sviluppo
  - Tabella esposizioni completa
  - Informazioni stampe associate

### 💾 Import/Export JSON
- Backup completo dell'archivio in formato JSON
- Importazione dati da altre fonti
- Strategie di merge: skip, replace, merge
- Esportazione selettiva (keepers, rullini specifici)

## Architettura Tecnica

### SwiftData Models

```swift
// Relazioni: Roll → Exposure → Print
@Model class Roll {
    @Relationship(deleteRule: .cascade, inverse: \Exposure.roll)
    var exposures: [Exposure]?
}

@Model class Exposure {
    var roll: Roll?
    @Relationship(deleteRule: .cascade, inverse: \Print.exposure)
    var prints: [Print]?
}

@Model class Print {
    var exposure: Exposure?
    @Relationship(deleteRule: .cascade)
    var dodgeBurnOperations: [DodgeBurnOperation]?
}
```

### Value Types

- `FilmStock`: Pellicole predefinite con caratteristiche
- `Camera`: Macchine fotografiche
- `Lens`: Obiettivi con specifiche
- `Filter`: Filtri con compensazione esposizione
- `Aperture`, `ShutterSpeed`: Valori esposizione

### Managers

- `AnalogArchiveManager`: CRUD operations e query
- `PDFExporter`: Generazione PDF con UIGraphicsPDFRenderer
- `JSONImportExportManager`: Import/export JSON
- `StatisticsEngine`: Calcolo statistiche e aggregazioni

## Requisiti

- iOS 17.0+
- Swift 6.0
- SwiftData
- Swift Charts (per i grafici)

## Installazione

1. Clona il repository
2. Apri il progetto in Xcode 15+
3. Build e run su simulatore o dispositivo

## Struttura del Progetto

```
AnalogArchive/
├── AnalogArchiveApp.swift          # Entry point
├── ContentView.swift               # Main tab view
├── Models/
│   ├── Roll.swift                  # SwiftData model Roll
│   ├── Exposure.swift              # SwiftData model Exposure
│   ├── Print.swift                 # SwiftData model Print
│   ├── FilmStock.swift             # Value types pellicole
│   └── Camera.swift                # Value types camera/lens
├── Managers/
│   ├── AnalogArchiveManager.swift  # CRUD operations
│   ├── PDFExporter.swift           # PDF generation
│   ├── JSONImportExportManager.swift
│   └── StatisticsEngine.swift      # Analytics
└── Views/
    ├── RollListView.swift          # Lista rullini
    ├── RollFormView.swift          # Form rullino
    ├── ExposureViews.swift         # Esposizioni
    ├── PrintViews.swift            # Stampe
    ├── StatisticsView.swift        # Dashboard stats
    └── ExportOptionsView.swift     # Import/Export UI
```

## Pellicole Predefinite

Il sistema include un database completo di pellicole:

### Ilford
- HP5 Plus 400
- FP4 Plus 125
- Delta 100/400/3200
- Pan F Plus 50
- SFX 200

### Kodak
- Tri-X 400
- T-Max 100/400/P3200
- Portra 160/400/800
- Ektar 100
- Ektachrome E100

### Fujifilm
- Acros 100 II
- Superia X-tra 400
- Pro 400H
- Velvia 50
- Provia 100F

### E altre...
Foma, Adox, Rollei, Cinestill, Kentmere

## Sviluppatori Predefiniti

- D-76, ID-11, HC-110, Rodinal
- X-Tol, Ilfosol 3, Perceptol
- C-41, E-6, ECN-2

## Licenza

MIT License - Vedi LICENSE per dettagli

## Contributi

Contributi benvenuti! Per favore apri una issue o pull request.

## Roadmap

- [ ] Integrazione Photo Library per collegamento foto digitali
- [ ] Scansione QR code per negativi
- [ ] Sincronizzazione iCloud
- [ ] Widget per home screen
- [ ] Complicazioni Apple Watch
- [ ] Esportazione CSV/Excel
- [ ] Backup automatico
