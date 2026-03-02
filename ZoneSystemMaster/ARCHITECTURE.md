# Zone System Master — Technical Architecture

## Overview

This document describes the technical architecture of Zone System Master, a professional iOS application for black and white photography based on Ansel Adams' Zone System.

## Table of Contents

1. [Architecture Principles](#architecture-principles)
2. [Module Structure](#module-structure)
3. [Dependency Injection](#dependency-injection)
4. [Concurrency Model](#concurrency-model)
5. [Data Flow](#data-flow)
6. [UI Architecture](#ui-architecture)
7. [Apple Intelligence Integration](#apple-intelligence-integration)
8. [StoreKit 2 Implementation](#storekit-2-implementation)
9. [Cross-Platform Strategy](#cross-platform-strategy)
10. [Performance Considerations](#performance-considerations)

## Architecture Principles

### 1. Clean Architecture

The app follows Clean Architecture principles with clear separation of concerns:

- **Domain Layer**: Core types, protocols, and business logic
- **Data Layer**: Services, repositories, and external APIs
- **Presentation Layer**: ViewModels and Views

### 2. Swift 6 Strict Concurrency

All code is written with Swift 6 strict concurrency checking enabled:

```swift
// All enums are frozen and Sendable
@frozen
public enum Zone: Int, CaseIterable, Sendable { }

// Services are isolated to MainActor
@MainActor
public final class ExposureMeteringService: ExposureMeteringProtocol { }

// Protocols require Sendable conformance
public protocol ExposureMeteringProtocol: Sendable { }
```

### 3. Protocol-Oriented Design

Services are defined by protocols, enabling:
- Easy testing with mocks
- Multiple implementations
- Clear contracts

```swift
public protocol ExposureMeteringProtocol: Sendable {
    var meteringMode: MeteringMode { get set }
    func calculateEV(fromLux lux: Double) async throws -> ExposureValue
    func mapToZone(ev: ExposureValue, placementZone: Zone) -> Zone
}
```

## Module Structure

### SPM Package Organization

```
ZoneSystemMaster (Package)
├── ZoneSystemCore (Library)
│   ├── Protocols
│   └── Services
├── ZoneSystemUI (Library)
│   └── DesignSystem
├── ExposureEngine (Library)
├── ZoneMappingEngine (Library)
├── EmulsionPhysicsEngine (Library)
├── DarkroomEngine (Library)
├── PaperSimulationEngine (Library)
├── AICritiqueEngine (Library)
├── AnalogArchiveManager (Library)
├── InstaxBLEManager (Library)
├── PanoramicCompositionEngine (Library)
└── ZoneSystemMaster (Executable)
```

### Module Dependencies

```
ZoneSystemMaster
├── ZoneSystemCore (foundation)
├── ZoneSystemUI (UI components)
├── ExposureEngine
│   └── ZoneSystemCore
├── ZoneMappingEngine
│   └── ZoneSystemCore
├── EmulsionPhysicsEngine
│   └── ZoneSystemCore
├── DarkroomEngine
│   └── EmulsionPhysicsEngine
├── PaperSimulationEngine
│   └── EmulsionPhysicsEngine
├── AICritiqueEngine
│   └── ZoneSystemCore
├── AnalogArchiveManager
│   └── ZoneSystemCore
├── InstaxBLEManager
│   └── ZoneSystemCore
└── PanoramicCompositionEngine
    └── ZoneSystemCore
```

## Dependency Injection

### Using swift-dependencies

The app uses `swift-dependencies` for compile-time safe dependency injection:

```swift
// Define dependency key
private enum ExposureMeteringKey: DependencyKey {
    static let liveValue: any ExposureMeteringProtocol = ExposureMeteringService()
    static let testValue: any ExposureMeteringProtocol = MockExposureMeteringService()
    static let previewValue: any ExposureMeteringProtocol = MockExposureMeteringService()
}

// Extend DependencyValues
public extension DependencyValues {
    var exposureMetering: any ExposureMeteringProtocol {
        get { self[ExposureMeteringKey.self] }
        set { self[ExposureMeteringKey.self] = newValue }
    }
}

// Use in ViewModel
@Observable
@MainActor
final class ExposureMeterViewModel {
    @ObservationIgnored
    @Inject(\.exposureMetering) private var exposureMetering
}
```

### Dependency Container

A central container provides access to all services:

```swift
@Observable
@MainActor
public final class DependencyContainer {
    public static let shared = DependencyContainer()
    
    @ObservationIgnored
    public var exposureMetering: any ExposureMeteringProtocol
    
    @ObservationIgnored
    public var zoneMapping: any ZoneMappingProtocol
    
    // ... other services
}
```

### Environment Injection

Services are injected into the view hierarchy:

```swift
public struct DependencyContainerModifier: ViewModifier {
    let container: DependencyContainer
    
    public func body(content: Content) -> some View {
        content
            .environment(\.dependencyContainer, container)
    }
}

// Usage
ContentView()
    .withDependencyContainer(DependencyContainer.shared)
```

## Concurrency Model

### MainActor Isolation

All UI-related code runs on `@MainActor`:

```swift
@MainActor
public final class ExposureMeteringService: ExposureMeteringProtocol {
    public var meteringMode: MeteringMode = .spot
    
    public func calculateEV(fromLux lux: Double) async throws -> ExposureValue {
        // Runs on MainActor
    }
}
```

### Background Tasks

Heavy computation runs on background actors:

```swift
@globalActor
public struct ImageProcessingActor {
    public static let shared = ImageProcessor()
    
    public actor ImageProcessor {
        func processImage(_ image: CIImage) async throws -> ProcessedImage {
            // Runs on background thread
        }
    }
}
```

### Async Streams

For real-time updates, use AsyncStream:

```swift
public var timerUpdates: AsyncStream<TimerUpdate> {
    AsyncStream { continuation in
        self.continuation = continuation
    }
}
```

## Data Flow

### Unidirectional Data Flow

```
User Action → ViewModel → Service → Repository → Data Source
                                    ↓
UI Update ← ViewModel ← Service ← Repository
```

### Example: Film Roll Creation

```swift
// 1. User taps "Create Roll"
viewModel.createRoll(name: "Yosemite", format: .mm4x5, emulsion: .ilfordFP4, iso: 125)

// 2. ViewModel calls service
Task {
    let roll = try await analogArchive.createFilmRoll(
        format: format,
        emulsion: emulsion,
        iso: iso
    )
    rolls.append(roll)
}

// 3. Service uses SwiftData
func createFilmRoll(format: FilmFormat, emulsion: FilmEmulsion, iso: Int) async throws -> FilmRoll {
    let model = FilmRollModel(name: "New Roll", format: format, emulsion: emulsion, iso: iso)
    context.insert(model)
    try context.save()
    return model.toFilmRoll()
}
```

## UI Architecture

### MVVM + Observation

```swift
@Observable
@MainActor
final class ExposureMeterViewModel {
    var selectedZone: Zone = .zone5
    var measuredZone: Zone?
    var currentEV: ExposureValue = .ev12
    
    func measure() {
        // Business logic
    }
}

struct ExposureMeterView: View {
    @State private var viewModel = ExposureMeterViewModel()
    
    var body: some View {
        // UI uses viewModel properties directly
        ZoneScaleView(selectedZone: viewModel.selectedZone)
    }
}
```

### Liquid Glass Components

```swift
public struct LiquidGlassTheme {
    public struct Colors {
        public static let glassUltraThin = Color.white.opacity(0.05)
        public static let glassThin = Color.white.opacity(0.10)
        public static let glassRegular = Color.white.opacity(0.20)
        public static let glassThick = Color.white.opacity(0.35)
        public static let glassUltraThick = Color.white.opacity(0.50)
    }
}

// Usage
Text("Hello")
    .padding()
    .background(.ultraThinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
```

## Apple Intelligence Integration

### AICritiqueProtocol

```swift
public protocol AICritiqueProtocol: Sendable {
    func analyzeImage(_ image: CIImage) async throws -> ImageAnalysis
    func zoneCritique(for image: CIImage, zoneMap: ZoneMap) async throws -> ZoneCritique
    func suggestImprovements(for analysis: ImageAnalysis) async throws -> [ImprovementSuggestion]
    func chatWithAnsel(message: String, context: ChatContext?) async throws -> AnselResponse
    var isAIAvailable: Bool { get }
}
```

### Implementation

```swift
@MainActor
public final class AICritiqueService: AICritiqueProtocol {
    public var isAIAvailable: Bool {
        if #available(iOS 26.0, *) {
            // Check for Apple Intelligence availability
            return true
        }
        return false
    }
    
    public func chatWithAnsel(message: String, context: ChatContext?) async throws -> AnselResponse {
        // Use Apple Intelligence Foundation Models
        // This would integrate with the appropriate APIs
        
        return AnselResponse(
            message: "The Zone System is not just about exposure—it's about visualization...",
            suggestions: ["Learn about Zone Placement", "Study characteristic curves"],
            relatedTopics: ["Exposure", "Development", "Printing"],
            confidence: 0.92
        )
    }
}
```

## StoreKit 2 Implementation

### StoreProtocol

```swift
public protocol StoreProtocol: Sendable {
    var proProduct: Product? { get }
    var isProUnlocked: Bool { get }
    func purchasePro() async throws -> PurchaseResult
    func restorePurchases() async throws -> Bool
    func isFeatureAvailable(_ feature: AppFeature) -> Bool
    var productUpdates: AsyncStream<StoreUpdate> { get }
}
```

### Feature Gating

```swift
public enum AppFeature: String, CaseIterable, Sendable {
    case basicChat, exposureMeter, darkroomTimer, filmRollLog  // Free
    case zoneMapping, physicalModeling, aiCritique, instaxPrinting  // PRO
    
    public var isProFeature: Bool {
        switch self {
        case .basicChat, .exposureMeter, .darkroomTimer, .filmRollLog:
            return false
        default:
            return true
        }
    }
}

public func isFeatureAvailable(_ feature: AppFeature) -> Bool {
    if feature.isProFeature {
        return isProUnlocked
    }
    return true
}
```

### Purchase Flow

```swift
func purchasePro() async throws -> PurchaseResult {
    guard let product = proProduct else {
        throw StoreError.productNotAvailable
    }
    
    // Initiate purchase
    let result = try await product.purchase()
    
    switch result {
    case .success(let verification):
        // Verify transaction
        let transaction = try checkVerified(verification)
        isProUnlocked = true
        await transaction.finish()
        return .success
        
    case .userCancelled:
        return .cancelled
        
    case .pending:
        return .pending
        
    default:
        return .failed
    }
}
```

## Cross-Platform Strategy

### iOS / iPadOS

Shared codebase with adaptive layouts:

```swift
struct ContentView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    var body: some View {
        if horizontalSizeClass == .compact {
            iOSLayout()
        } else {
            iPadLayout()
        }
    }
}
```

### watchOS

Separate target with shared core:

```swift
// Watch Extension
import ZoneSystemCore

struct DarkroomTimerWatchView: View {
    @State private var viewModel = WatchTimerViewModel()
    
    var body: some View {
        TimerDisplay(remaining: viewModel.remainingTime)
    }
}
```

### Live Activities

```swift
import ActivityKit

struct DarkroomTimerAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var remainingTime: TimeInterval
        var currentPhase: String
    }
    
    var rollName: String
    var filmEmulsion: String
}
```

## Performance Considerations

### Image Processing

- Use Core Image for GPU-accelerated processing
- Process on background actors
- Cache processed images

```swift
@globalActor
struct ImageProcessingActor {
    static let shared = ImageProcessor()
    
    actor ImageProcessor {
        private let context = CIContext()
        
        func processImage(_ image: CIImage) async throws -> CIImage {
            // GPU-accelerated processing
        }
    }
}
```

### SwiftData Optimization

- Use `@Relationship` with appropriate delete rules
- Batch fetch with `FetchDescriptor`
- Index frequently queried fields with `@Attribute(.unique)`

```swift
@Model
final class FilmRollModel {
    @Attribute(.unique) var id: UUID
    @Relationship(deleteRule: .cascade)
    var exposures: [ExposureRecordModel]?
}
```

### Memory Management

- Use `@ObservationIgnored` for non-observable properties
- Weak references in delegates
- Proper cleanup in `deinit`

```swift
@Observable
@MainActor
final class ViewModel {
    @ObservationIgnored
    private var cancellables: Set<AnyCancellable> = []
    
    deinit {
        cancellables.removeAll()
    }
}
```

## Testing Strategy

### Unit Tests

```swift
@Test
func testExposureCalculation() async throws {
    let metering = MockExposureMeteringService()
    let ev = try await metering.calculateEV(fromLux: 100)
    #expect(ev == .ev5)
}
```

### UI Tests

```swift
@Test
func testZoneMeterFlow() async throws {
    let app = XCUIApplication()
    app.launch()
    
    app.tabBars.buttons["Meter"].tap()
    app.buttons["Measure"].tap()
    
    #expect(app.staticTexts["EV 12"].exists)
}
```

### Snapshot Tests

```swift
@Test
func testZoneScaleAppearance() {
    let view = ZoneScaleView(selectedZone: .zone5, measuredZone: nil) { _ in }
    assertSnapshot(of: view, as: .image)
}
```

## Security

### Data Protection

```xml
<!-- Entitlements -->
<key>com.apple.developer.default-data-protection</key>
<string>NSFileProtectionComplete</string>
```

### Keychain

```swift
enum KeychainError: Error {
    case itemNotFound
    case duplicateItem
    case invalidStatus(OSStatus)
}

func saveToKeychain(_ data: Data, service: String, account: String) throws {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: service,
        kSecAttrAccount as String: account,
        kSecValueData as String: data,
        kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
    ]
    
    let status = SecItemAdd(query as CFDictionary, nil)
    guard status == errSecSuccess else {
        throw KeychainError.invalidStatus(status)
    }
}
```

## Deployment

### App Store Requirements

- iOS 26.3+ / iPadOS 26.3+ / watchOS 26+
- Apple Silicon required for development
- 100MB+ download size
- In-app purchase for PRO tier

### CI/CD

```yaml
# .github/workflows/build.yml
name: Build and Test

on: [push, pull_request]

jobs:
  build:
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v4
      - name: Build
        run: swift build
      - name: Test
        run: swift test
```

---

*This architecture document is a living document and will be updated as the app evolves.*
