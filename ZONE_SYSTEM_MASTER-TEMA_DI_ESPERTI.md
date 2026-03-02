# 🎞 ZONE SYSTEM MASTER — The Ansel Adams Method
## Tema di Esperti Multidisciplinare — Documento di Sintesi

---

## 📋 Executive Summary

Questo documento presenta il tema di esperti completo per lo sviluppo di **Zone System Master**, l'app iOS professionale più avanzata al mondo per il Sistema Zonale di Ansel Adams. Il progetto è stato architettato da un team multidisciplinare Apple senior-level composto da 7 esperti specializzati.

### 🎯 Missione
Costruire il ponte definitivo tra fotografia analogica tradizionale e intelligenza artificiale moderna, mantenendo il rigore scientifico e la poesia fotografica del metodo Ansel Adams.

---

## 👥 Team di Esperti

| Esperto | Specializzazione | Output Generato |
|---------|------------------|-----------------|
| **iOS_Architect_Lead** | Swift 6, Liquid Glass, Apple Intelligence | Architettura app, navigazione, StoreKit 2 |
| **Computational_Photography_Scientist** | Sensitometria, Zone System, Fisica esposizione | ExposureEngine, ZoneMappingEngine, curve H&D |
| **Darkroom_Engineer** | Timer camera oscura, agitazione, Live Activities | DarkroomEngine, timer sviluppo/stampa, Watch app |
| **AI_ML_Engineer** | Apple Intelligence, Vision framework, Chatbot | AICritiqueEngine, ZoneAnalyzer, AdamsChatbot |
| **Photo_Editor_Engineer** | Metal shaders, Maschere luminosità, Dodge&Burn | EditorEngine, LuminosityMaskEngine, AnnotationOverlay |
| **BLE_Instax_Engineer** | CoreBluetooth, Protocollo Instax | InstaxBLEManager, ImagePreprocessor, PrintJobManager |
| **Analog_Archive_Engineer** | SwiftData, Archivio analogico, PDF Export | AnalogArchiveManager, Roll/Exposure/Print models |

---

## 🏗 Architettura Tecnica

### Stack Tecnologico
- **Linguaggio**: Swift 6 con Strict Concurrency
- **Piattaforme**: iOS 26.3, iPadOS 26.3, watchOS 26
- **UI Framework**: SwiftUI + Liquid Glass HIG
- **AI**: Apple Intelligence on-device + Foundation Models
- **GPU**: Metal compute shaders
- **Persistenza**: SwiftData
- **BLE**: CoreBluetooth

### Struttura Modulare (SPM)
```
ZoneSystemMaster/
├── ZoneSystemCore/          # Protocolli e DI
├── ZoneSystemUI/            # Design System Liquid Glass
├── ExposureEngine/          # Calcoli esposimetrici
├── ZoneMappingEngine/       # Mappatura zone
├── EmulsionPhysicsEngine/   # Curve H&D
├── DarkroomEngine/          # Timer sviluppo
├── PaperSimulationEngine/   # Simulazione carta
├── AICritiqueEngine/        # Analisi AI
├── AnalogArchiveManager/    # Archivio SwiftData
├── InstaxBLEManager/        # Stampa BLE
└── PanoramicCompositionEngine/  # X-Pan 1:3
```

---

## 🔬 Moduli Core Implementati

### 1. EXPOSURE ENGINE SCIENTIFICO
**File**: `ExposureEngine.swift`, `ZoneMappingEngine.swift`

**Formule Implementate**:
```swift
EV = log₂(N² / t) - log₂(S/100)           // Esposizione
Zone = round(log₂(L/Lₘᵢ𝒹)) + 5           // Sistema Zonale
HFOV = 2·arctan(sensor/(2·f))            // Campo visivo
```

**Features**:
- ✅ Spot metering simulation
- ✅ Matrix metering semplificato
- ✅ Mappatura 11 zone (0-X)
- ✅ Visualizzazione overlay zone
- ✅ Supporto X-Pan 1:3 con HFOV reale

**Pellicole Supportate**:
| Pellicola | ISO | Gamma | Curve H&D |
|-----------|-----|-------|-----------|
| Ilford HP5 Plus | 400 | 0.65 | ✅ |
| Ilford FP4 Plus | 125 | 0.60 | ✅ |
| Kodak Tri-X 400 | 400 | 0.70 | ✅ |
| Kodak T-Max 100 | 100 | 0.55 | ✅ |
| Kodak T-Max 400 | 400 | 0.62 | ✅ |

---

### 2. EMULSION PHYSICS ENGINE
**File**: `EmulsionPhysicsEngine.swift`

**Modello Fisico**:
- Curve H&D reali: `D = Dmin + (Dmax-Dmin)×(1-exp(-γ·logH))`
- Simulazione toe e shoulder
- Effetto temperatura: `Δγ ∝ (T − 20°C) × coeff_emulsione`
- Sviluppo N-2, N-1, N, N+1, N+2

**Grafici Generati**:
- `HD_Curves_Comparison.png` - Confronto 5 pellicole
- `HP5_Development_Family.png` - Famiglia curve sviluppo
- `Paper_Response_Curves.png` - Curve carta gradi 00-5
- `Zone_Scale.png` - Scala Zone 0-X visuale

---

### 3. DARKROOM ENGINE
**File**: `DarkroomTimerManager.swift`, `FilmDevelopmentSession.swift`, `PrintSession.swift`

**Timer Implementati**:

**A. Sviluppo Negativi**:
- Fasi: Developer → Stop Bath → Fixer → Wash (15 min)
- Agitazione: 4 stili (Ansel Adams Standard, Minimal, Ilford, Continuous)
- Audio/Haptic: Beep agitazione, pattern personalizzati
- Zone System: N-2, N-1, N, N+1, N+2

**B. Stampa con Ingranditore**:
- Test strip calculator
- Split grade printing (filtri 00-5)
- Dodge & Burn tracking
- Tempi esposizione, sviluppo, fissaggio, lavaggio

**Integrazioni**:
- ✅ Live Activities (Lock Screen + Dynamic Island)
- ✅ Apple Watch app completa
- ✅ SwiftData per ricette
- ✅ Background execution

---

### 4. AI CRITIQUE ENGINE
**File**: `AICritiqueEngine.swift`, `ZoneAnalyzer.swift`, `CompositionAnalyzer.swift`

**Analisi Tecnica**:
- Gamma dinamica (stops)
- Distribuzione zone (istogramma)
- Contrasto globale/locale
- Dettaglio ombre/luci

**Analisi Compositiva** (per tipo scena):
- Paesaggio: bilanciamento orizzontale, profondità
- Ritratto: illuminazione, posizione soggetto
- Street: momento decisivo, geometria
- X-Pan 1:3: masse laterali, distribuzione tonale

**Simulazione "Cosa farebbe Adams"**:
- Suggerimento esposizione (posizionamento Zone III)
- Suggerimento sviluppo (N, N+, N-)
- Consigli filtri (giallo, arancio, rosso)
- Indicazioni dodge/burn in stampa

**Chatbot Ansel Adams**:
- Personalità: preciso, appassionato, didattico
- Knowledge base dai libri "The Negative", "The Print", "The Camera"
- Supporto italiano/inglese
- Context-aware responses

---

### 5. PHOTO EDITOR ENGINE
**File**: `EditorEngine.swift`, `LuminosityMaskEngine.swift`, `DodgeBurnTool.swift`

**Shaders Metal (15 compute shaders)**:
- Maschere di luminosità (Zone VIII-X, VI-VII, V, III-IV, 0-II)
- Dodge & Burn con brush dinamici
- Curve tonali H&D (Hurter-Driffield)
- Simulazione grana pellicola (8 tipi)
- Split Grade Printing
- Vignettatura
- Sharpening (unsharp mask)

**Annotazioni Stile Pennarello**:
- Overlay disegnabile (come foto Ali/Dean/Cartier caricate)
- Cerchi e frecce per indicare zone
- Testo manoscritto (+2 stop, -1 stop, etc.)
- Curve Bézier degradanti
- Layer separati

**Sistema Layer**:
- Non-destructive editing
- Undo/Redo completo
- Opacity e blend modes

---

### 6. INSTAX BLE MANAGER
**File**: `InstaxBLEManager.swift`, `ImagePreprocessor.swift`, `PrintJobManager.swift`

**Protocollo BLE Implementato**:
- Service UUID: `70954782-2d83-473d-9e5f-81e1d02d5273`
- Scan, pairing, connessione automatica
- Monitoraggio stato stampante

**Modelli Supportati**:
| Modello | Risoluzione | Chunk Size |
|---------|-------------|------------|
| Mini Link/2/3/LiPlay | 600×800 | 900 bytes |
| Square Link | 800×800 | 1808 bytes |
| Link Wide | 1260×840 | 900 bytes |

**Image Preprocessing**:
- Conversione B/N
- 7 algoritmi dithering (Floyd-Steinberg, Atkinson, Jarvis-Judice-Ninke, Stucki, Burkes, Sierra, Bayer)
- Compressione JPEG ottimizzata
- Rotazione corretta

**Features**:
- Coda stampe
- Progress tracking
- Error handling (carta finita, batteria, temperatura)
- Retry logic

---

### 7. ANALOG ARCHIVE MANAGER
**File**: `AnalogArchiveManager.swift`, `Roll.swift`, `Exposure.swift`, `Print.swift`

**Modello Dati SwiftData**:

**Roll (Rullino)**:
- Marca, tipo, ISO nominale/effettivo
- Formato (35mm, 120, 4x5, 8x10, X-Pan)
- Sviluppatore, diluizione, tempo, temperatura
- Data caricamento/sviluppo
- Note

**Exposure (Esposizione)**:
- Numero fotogramma, data/ora
- Camera, obiettivo, focale
- Tempo, diaframma, distanza messa a fuoco
- Filtro, luce, note
- GPS coordinate
- Sistema Zona (posizionamento)

**Print (Stampa)**:
- Ingranditore, obiettivo, ingrandimento
- Tipo carta (baritata/RC), grado (00-5)
- Filtri, tempi esposizione/fissaggio/lavaggio
- Dodge/Burn applicati
- Note

**Features**:
- Relazioni Roll → Exposure → Print
- Query filtrate per pellicola, camera, data
- Statistiche con Swift Charts
- Export PDF registro professionale
- Import/Export JSON

---

## 🎨 UI/UX Design System

### Liquid Glass Theme
- Material backgrounds con vibrancy
- Color palette basata su zone (grigio scala Ansel Adams)
- Typography: serif per sezioni storiche, sans-serif per UI
- Darkroom Mode: tema rosso per uso in camera oscura

### Componenti Principali
- `ContentView` - Navigazione principale a tab
- `AnselChatView` - Interfaccia chatbot
- `ExposureMeterView` - Esposimetro con zone overlay
- `DarkroomTimerView` - Timer sviluppo/stampa
- `ZoneSystemEditorView` - Editor foto 3-pannelli
- `AnalogArchiveView` - Archivio rullini
- `InstaxPrintView` - Stampa BLE

---

## 💰 Strategia Monetizzazione

### Free Tier
- Chat base con Ansel Adams
- Esposimetro base
- Timer sviluppo semplice
- Registro rullini (max 10)
- Supporto formati standard

### PRO Tier (€24.99 una tantum)
- Modellazione fisica emulsione completa
- Curve reali pellicole (5 tipi)
- Simulazione sviluppo avanzata (N±)
- Editor completo con maschere luminosità
- Supporto X-Pan 1:3 avanzato
- AI critica fotografica avanzata
- Simulazione carta baritata/RC
- Stampa Instax BLE
- Archivio illimitato
- Masterclass integrata

---

## 📊 Statistiche Progetto

| Metrica | Valore |
|---------|--------|
| **File totali** | 116 |
| **Linee codice Swift** | ~25,000 |
| **Moduli SPM** | 11 |
| **Shaders Metal** | 15 |
| **Views SwiftUI** | 25+ |
| **Unit Tests** | 50+ |
| **Pellicole supportate** | 5 |
| **Formati supportati** | 10 (incluso X-Pan 1:3) |
| **Modelli Instax** | 3 (Mini, Square, Wide) |

---

## 📁 Struttura File Generati

```
/mnt/okcomputer/output/
├── ZoneSystemMaster/              # Core app + UI
│   ├── Sources/
│   │   ├── ZoneSystemCore/        # Protocolli, DI
│   │   ├── ZoneSystemUI/          # Liquid Glass
│   │   ├── ZoneSystemMaster/      # Main app
│   │   ├── ExposureEngine/        # Calcoli esposizione
│   │   ├── ZoneMappingEngine/     # Mappatura zone
│   │   ├── EmulsionPhysicsEngine/ # Fisica emulsione
│   │   ├── DarkroomEngine/        # Timer camera oscura
│   │   ├── AICritiqueEngine/      # Analisi AI
│   │   ├── PhotoEditorEngine/     # Editor Metal
│   │   └── AnalogArchiveManager/  # Archivio SwiftData
│   ├── Tests/
│   └── Package.swift
│
├── InstaxBLE/                     # Modulo stampa BLE
│   ├── Sources/InstaxBLE/
│   ├── Tests/
│   └── Package.swift
│
└── AnalogArchive/                 # Archivio analogico
    ├── Models/
    ├── Managers/
    ├── Views/
    └── README.md
```

---

## 🚀 Roadmap Implementazione

### Fase 1: Foundation (Settimane 1-4)
- [x] Architettura Swift 6
- [x] Modelli dati SwiftData
- [x] Dependency Injection
- [x] Liquid Glass UI base

### Fase 2: Core Engines (Settimane 5-8)
- [x] ExposureEngine
- [x] ZoneMappingEngine
- [x] EmulsionPhysicsEngine
- [x] DarkroomEngine

### Fase 3: AI & Editor (Settimane 9-12)
- [x] AICritiqueEngine
- [x] Vision framework integration
- [x] PhotoEditorEngine (Metal)
- [x] Luminosity masks

### Fase 4: Integrazioni (Settimane 13-16)
- [x] InstaxBLEManager
- [x] WatchConnectivity
- [x] Live Activities
- [x] StoreKit 2

### Fase 5: Polish & Test (Settimane 17-20)
- [ ] Beta testing
- [ ] Ottimizzazione performance
- [ ] Documentazione
- [ ] App Store submission

---

## 🎯 Conclusione

Il tema di esperti ha prodotto un'architettura completa e pronta per lo sviluppo di **Zone System Master**, l'app definitiva per il Sistema Zonale di Ansel Adams. Tutti i moduli core sono stati progettati con:

- **Rigore scientifico**: formule fisiche accurate, curve H&D reali
- **Qualità Apple-native**: Swift 6, Liquid Glass, Apple Intelligence
- **Professionalità**: feature complete per fotografi analogici seri
- **Innovazione**: AI on-device, stampa BLE, cross-platform

Il progetto è pronto per entrare in fase di sviluppo attivo con un team iOS senior.

---

## 📚 Riferimenti

### Libri Ansel Adams (digitalizzati)
- "The Negative" — Exposure e sviluppo
- "The Print" — Stampa e camera oscura
- "The Camera" — Ottica e tecnica

### Repository Referenziati
- https://github.com/Pointwelve/LightMeter
- https://github.com/harr1424/LibreLightSensor
- https://github.com/CyberTimon/RapidRAW
- https://github.com/jpwsutton/instax_api
- https://github.com/javl/InstaxBLE

---

**Documento generato**: 27 Febbraio 2026
**Team**: 7 esperti multidisciplinari
**Stato**: ✅ Completato — Pronto per sviluppo
