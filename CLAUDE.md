# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Zone System Master is a professional iOS photography app based on Ansel Adams' Zone System. It includes:
- **Zone System Photo Editor** - B&W photo editing with Metal shaders, luminosity masks, dodge/burn, and film grain simulation
- **Darkroom Timer** - Multi-phase timer for film development with Apple Watch support and Live Activities
- **Exposure Meter** - Light metering with zone placement visualization
- **Analog Archive** - Film roll, exposure, and print tracking with SwiftData
- **Instax BLE** - Bluetooth printing to Fujifilm Instax printers
- **AI Chatbot** - Ansel Adams persona chatbot powered by Apple Intelligence

## Build Commands

```bash
# Build the main app (Xcode project)
cd ZoneSystemMaster
xcodebuild -project ZoneSystemMaster.xcodeproj -scheme ZoneSystemMaster -destination 'platform=iOS Simulator,name=iPhone 16' build

# Build InstaxBLE package
cd InstaxBLE
swift build

# Run tests
swift test

# Run tests in Xcode
# Cmd+U with test target selected
```

## Requirements

- iOS 17.0+ / iPadOS 17.0+ / watchOS 9.0+ / macOS 14.0+ / visionOS 1.0+
- Xcode 15.0+
- Swift 6.0 with strict concurrency enabled
- Metal 3.0+ for GPU-accelerated image processing

## Architecture

### Module Structure

The project follows Clean Architecture with three layers:
- **Domain Layer** - Core types, protocols, business logic (`ZoneSystemCore`)
- **Data Layer** - Services, repositories, SwiftData models
- **Presentation Layer** - ViewModels, Views (`ZoneSystemUI`)

Key modules (all depend on `ZoneSystemCore`):
- `ExposureEngine` - Light metering calculations
- `ZoneMappingEngine` - Zone placement algorithms
- `EmulsionPhysicsEngine` - Film characteristic curves (H&D curves)
- `DarkroomEngine` - Timer and development workflows
- `PaperSimulationEngine` - Multigrade paper simulation
- `AICritiqueEngine` - Image analysis and Ansel chatbot
- `AnalogArchiveManager` - Film roll/exposure/print tracking
- `InstaxBLEManager` - Bluetooth printer communication
- `PanoramicCompositionEngine` - XPan composition tools

### Dependency Injection

Uses `swift-dependencies` pattern with `DependencyContainer`:

```swift
@Observable
@MainActor
public final class DependencyContainer {
    public static let shared = DependencyContainer()
    public var exposureMetering: any ExposureMeteringProtocol
    public var zoneMapping: any ZoneMappingProtocol
    // ... other services
}

// Inject into views
ContentView()
    .withDependencyContainer(DependencyContainer.shared)
```

### Concurrency Model

All services use Swift 6 strict concurrency:
- UI code: `@MainActor` isolation
- Protocols: `Sendable` conformance
- Enums: `@frozen` for performance
- Heavy image processing: Custom global actors

```swift
@frozen
public enum Zone: Int, CaseIterable, Sendable { }

@MainActor
public final class ExposureMeteringService: ExposureMeteringProtocol { }
```

### Data Models (SwiftData)

```swift
@Model class FilmRollModel {
    @Relationship(deleteRule: .cascade) var exposures: [ExposureRecordModel]?
}
@Model class ExposureRecordModel {
    var roll: FilmRollModel?
    @Relationship(deleteRule: .cascade) var prints: [PrintRecordModel]?
}
@Model class PrintRecordModel {
    var exposure: ExposureRecordModel?
}
```

### UI Architecture

MVVM with SwiftUI's `@Observable` macro:

```swift
@Observable
@MainActor
final class ExposureMeterViewModel {
    var selectedZone: Zone = .zone5
    func measure() { }
}

struct ExposureMeterView: View {
    @State private var viewModel = ExposureMeterViewModel()
}
```

Liquid Glass design system in `ZoneSystemUI/DesignSystem/LiquidGlassTheme.swift`:
- Glass materials with opacity levels (ultraThin, thin, regular, thick, ultraThick)
- Zone-based color palette (zone0 through zone10)
- Consistent spacing and typography tokens

## Platform Targets

- **ZoneSystemMaster** - Main iOS/iPadOS app
- **ZoneSystemMasterWidget** - Live Activity widget (iOS 16.1+)
- **ZoneSystemMasterWatch** - Apple Watch companion app
- **InstaxBLE** - Standalone Swift Package for Instax printing

## Key File Locations

| Component | Location |
|-----------|----------|
| App Entry Point | `ZoneSystemMaster/Sources/ZoneSystemMaster/App/ZoneSystemMasterApp.swift` |
| Main View | `ZoneSystemMaster/Sources/ZoneSystemMaster/Views/Main/ContentView.swift` |
| Core Protocols | `ZoneSystemMaster/Sources/ZoneSystemCore/Protocols/` |
| Services | `ZoneSystemMaster/Sources/ZoneSystemCore/Services/` |
| Metal Shaders | `ZoneSystemMaster/Shaders/ZoneSystemShaders.metal` |
| Design System | `ZoneSystemMaster/Sources/ZoneSystemUI/DesignSystem/LiquidGlassTheme.swift` |
| Timer Manager | `ZoneSystemMaster/Managers/DarkroomTimerManager.swift` |
| Watch App | `ZoneSystemMaster/ZoneSystemMasterWatch/ZoneSystemMasterWatchApp.swift` |
| Instax Package | `InstaxBLE/Sources/InstaxBLE/` |

## Zone System Reference

| Zone | Luminance | Description |
|------|-----------|-------------|
| 0 | 0% | Pure black |
| I | 1% | Near black |
| II | 3.5% | First texture |
| III | 9% | Shadow detail |
| IV | 18% | Dark foliage |
| V | 36% | Middle gray (18% card) |
| VI | 50% | Caucasian skin |
| VII | 68% | Light skin |
| VIII | 81% | White with texture |
| IX | 91% | Glaring snow |
| X | 100% | Paper white |

Development time adjustments: N-2 (60%), N-1 (80%), N (100%), N+1 (130%), N+2 (170%)

## Testing

Tests use XCTest with `@MainActor`:

```swift
@MainActor
final class ZoneSystemTests: XCTestCase {
    var coordinator: ZoneSystemCoordinator!
    var zoneAnalyzer: ZoneAnalyzer!

    override func setUp() {
        coordinator = ZoneSystemCoordinator()
        zoneAnalyzer = ZoneAnalyzer()
    }
}
```

## StoreKit 2

Feature gating via `StoreProtocol`:
- Free: basicChat, exposureMeter, darkroomTimer, filmRollLog
- PRO: zoneMapping, physicalModeling, aiCritique, instaxPrinting

## Privacy Permissions Required

- Camera (light metering)
- Photo Library (import/export)
- Bluetooth (Instax printing)
- Location (GPS tagging exposures)
- Apple Intelligence (AI chatbot)
