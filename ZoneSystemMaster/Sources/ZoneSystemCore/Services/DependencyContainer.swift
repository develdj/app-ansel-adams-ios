import Foundation
import SwiftUI
import Dependencies
import Observation

// MARK: - Dependency Keys

private enum ExposureMeteringKey: DependencyKey {
    static let liveValue: any ExposureMeteringProtocol = ExposureMeteringService()
    static let testValue: any ExposureMeteringProtocol = MockExposureMeteringService()
    static let previewValue: any ExposureMeteringProtocol = MockExposureMeteringService()
}

private enum ZoneMappingKey: DependencyKey {
    static let liveValue: any ZoneMappingProtocol = ZoneMappingService()
    static let testValue: any ZoneMappingProtocol = MockZoneMappingService()
    static let previewValue: any ZoneMappingProtocol = MockZoneMappingService()
}

private enum EmulsionPhysicsKey: DependencyKey {
    static let liveValue: any EmulsionPhysicsProtocol = EmulsionPhysicsService()
    static let testValue: any EmulsionPhysicsProtocol = MockEmulsionPhysicsService()
    static let previewValue: any EmulsionPhysicsProtocol = MockEmulsionPhysicsService()
}

private enum DarkroomTimerKey: DependencyKey {
    static let liveValue: any DarkroomTimerProtocol = DarkroomTimerService()
    static let testValue: any DarkroomTimerProtocol = MockDarkroomTimerService()
    static let previewValue: any DarkroomTimerProtocol = MockDarkroomTimerService()
}

private enum PaperSimulationKey: DependencyKey {
    static let liveValue: any PaperSimulationProtocol = PaperSimulationService()
    static let testValue: any PaperSimulationProtocol = MockPaperSimulationService()
    static let previewValue: any PaperSimulationProtocol = MockPaperSimulationService()
}

private enum AICritiqueKey: DependencyKey {
    static let liveValue: any AICritiqueProtocol = AICritiqueService()
    static let testValue: any AICritiqueProtocol = MockAICritiqueService()
    static let previewValue: any AICritiqueProtocol = MockAICritiqueService()
}

private enum AnalogArchiveKey: DependencyKey {
    static let liveValue: any AnalogArchiveProtocol = AnalogArchiveService()
    static let testValue: any AnalogArchiveProtocol = MockAnalogArchiveService()
    static let previewValue: any AnalogArchiveProtocol = MockAnalogArchiveService()
}

private enum InstaxBLEKey: DependencyKey {
    static let liveValue: any InstaxBLEProtocol = InstaxBLEService()
    static let testValue: any InstaxBLEProtocol = MockInstaxBLEService()
    static let previewValue: any InstaxBLEProtocol = MockInstaxBLEService()
}

private enum PanoramicCompositionKey: DependencyKey {
    static let liveValue: any PanoramicCompositionProtocol = PanoramicCompositionService()
    static let testValue: any PanoramicCompositionProtocol = MockPanoramicCompositionService()
    static let previewValue: any PanoramicCompositionProtocol = MockPanoramicCompositionService()
}

private enum StoreKey: DependencyKey {
    static let liveValue: any StoreProtocol = StoreService()
    static let testValue: any StoreProtocol = MockStoreService()
    static let previewValue: any StoreProtocol = MockStoreService(proUnlocked: true)
}

private enum SettingsKey: DependencyKey {
    static let liveValue: any SettingsProtocol = SettingsService()
    static let testValue: any SettingsProtocol = SettingsService()
    static let previewValue: any SettingsProtocol = SettingsService()
}

// MARK: - Dependency Values Extension

public extension DependencyValues {
    var exposureMetering: any ExposureMeteringProtocol {
        get { self[ExposureMeteringKey.self] }
        set { self[ExposureMeteringKey.self] = newValue }
    }
    
    var zoneMapping: any ZoneMappingProtocol {
        get { self[ZoneMappingKey.self] }
        set { self[ZoneMappingKey.self] = newValue }
    }
    
    var emulsionPhysics: any EmulsionPhysicsProtocol {
        get { self[EmulsionPhysicsKey.self] }
        set { self[EmulsionPhysicsKey.self] = newValue }
    }
    
    var darkroomTimer: any DarkroomTimerProtocol {
        get { self[DarkroomTimerKey.self] }
        set { self[DarkroomTimerKey.self] = newValue }
    }
    
    var paperSimulation: any PaperSimulationProtocol {
        get { self[PaperSimulationKey.self] }
        set { self[PaperSimulationKey.self] = newValue }
    }
    
    var aiCritique: any AICritiqueProtocol {
        get { self[AICritiqueKey.self] }
        set { self[AICritiqueKey.self] = newValue }
    }
    
    var analogArchive: any AnalogArchiveProtocol {
        get { self[AnalogArchiveKey.self] }
        set { self[AnalogArchiveKey.self] = newValue }
    }
    
    var instaxBLE: any InstaxBLEProtocol {
        get { self[InstaxBLEKey.self] }
        set { self[InstaxBLEKey.self] = newValue }
    }
    
    var panoramicComposition: any PanoramicCompositionProtocol {
        get { self[PanoramicCompositionKey.self] }
        set { self[PanoramicCompositionKey.self] = newValue }
    }
    
    var store: any StoreProtocol {
        get { self[StoreKey.self] }
        set { self[StoreKey.self] = newValue }
    }
    
    var settings: any SettingsProtocol {
        get { self[SettingsKey.self] }
        set { self[SettingsKey.self] = newValue }
    }
}

// MARK: - Dependency Container

/// Central dependency container for the app
@Observable
@MainActor
public final class DependencyContainer {
    
    // MARK: - Shared Instance
    
    public static let shared = DependencyContainer()
    
    // MARK: - Services
    
    @ObservationIgnored
    public var exposureMetering: any ExposureMeteringProtocol
    
    @ObservationIgnored
    public var zoneMapping: any ZoneMappingProtocol
    
    @ObservationIgnored
    public var emulsionPhysics: any EmulsionPhysicsProtocol
    
    @ObservationIgnored
    public var darkroomTimer: any DarkroomTimerProtocol
    
    @ObservationIgnored
    public var paperSimulation: any PaperSimulationProtocol
    
    @ObservationIgnored
    public var aiCritique: any AICritiqueProtocol
    
    @ObservationIgnored
    public var analogArchive: any AnalogArchiveProtocol
    
    @ObservationIgnored
    public var instaxBLE: any InstaxBLEProtocol
    
    @ObservationIgnored
    public var panoramicComposition: any PanoramicCompositionProtocol
    
    @ObservationIgnored
    public var store: any StoreProtocol
    
    @ObservationIgnored
    public var settings: any SettingsProtocol
    
    // MARK: - Initialization
    
    private init() {
        @Dependency(\.exposureMetering) var metering
        @Dependency(\.zoneMapping) var mapping
        @Dependency(\.emulsionPhysics) var physics
        @Dependency(\.darkroomTimer) var timer
        @Dependency(\.paperSimulation) var paper
        @Dependency(\.aiCritique) var critique
        @Dependency(\.analogArchive) var archive
        @Dependency(\.instaxBLE) var ble
        @Dependency(\.panoramicComposition) var panoramic
        @Dependency(\.store) var storeService
        @Dependency(\.settings) var settingsService
        
        self.exposureMetering = metering
        self.zoneMapping = mapping
        self.emulsionPhysics = physics
        self.darkroomTimer = timer
        self.paperSimulation = paper
        self.aiCritique = critique
        self.analogArchive = archive
        self.instaxBLE = ble
        self.panoramicComposition = panoramic
        self.store = storeService
        self.settings = settingsService
    }
    
    // MARK: - Preview Configuration
    
    public static func preview(proUnlocked: Bool = true) -> DependencyContainer {
        let container = DependencyContainer.shared
        container.configureForPreview(proUnlocked: proUnlocked)
        return container
    }
    
    private func configureForPreview(proUnlocked: Bool) {
        self.exposureMetering = MockExposureMeteringService()
        self.zoneMapping = MockZoneMappingService()
        self.emulsionPhysics = MockEmulsionPhysicsService()
        self.darkroomTimer = MockDarkroomTimerService()
        self.paperSimulation = MockPaperSimulationService()
        self.aiCritique = MockAICritiqueService()
        self.analogArchive = MockAnalogArchiveService()
        self.instaxBLE = MockInstaxBLEService()
        self.panoramicComposition = MockPanoramicCompositionService()
        self.store = MockStoreService(proUnlocked: proUnlocked)
        self.settings = SettingsService()
    }
    
    // MARK: - Testing Configuration
    
    public static func testing() -> DependencyContainer {
        let container = DependencyContainer.shared
        container.configureForTesting()
        return container
    }
    
    private func configureForTesting() {
        self.exposureMetering = MockExposureMeteringService()
        self.zoneMapping = MockZoneMappingService()
        self.emulsionPhysics = MockEmulsionPhysicsService()
        self.darkroomTimer = MockDarkroomTimerService()
        self.paperSimulation = MockPaperSimulationService()
        self.aiCritique = MockAICritiqueService()
        self.analogArchive = MockAnalogArchiveService()
        self.instaxBLE = MockInstaxBLEService()
        self.panoramicComposition = MockPanoramicCompositionService()
        self.store = MockStoreService()
        self.settings = SettingsService()
    }
}

// MARK: - Environment Key

private struct DependencyContainerKey: EnvironmentKey {
    static let defaultValue: DependencyContainer = .shared
}

public extension EnvironmentValues {
    var dependencyContainer: DependencyContainer {
        get { self[DependencyContainerKey.self] }
        set { self[DependencyContainerKey.self] = newValue }
    }
}

// MARK: - View Modifier

public struct DependencyContainerModifier: ViewModifier {
    let container: DependencyContainer
    
    public init(container: DependencyContainer = .shared) {
        self.container = container
    }
    
    public func body(content: Content) -> some View {
        content
            .environment(\.dependencyContainer, container)
    }
}

public extension View {
    func withDependencyContainer(_ container: DependencyContainer = .shared) -> some View {
        modifier(DependencyContainerModifier(container: container))
    }
}

// MARK: - Property Wrapper

@propertyWrapper
@MainActor
public struct Inject<Service>: DynamicProperty {
    @Environment(\.dependencyContainer) private var container
    
    private let keyPath: KeyPath<DependencyContainer, Service>
    
    public init(_ keyPath: KeyPath<DependencyContainer, Service>) {
        self.keyPath = keyPath
    }
    
    public var wrappedValue: Service {
        container[keyPath: keyPath]
    }
}

// MARK: - Service Registration

/// Protocol for services that need initialization
public protocol InitializableService: Sendable {
    init()
}

/// Service registry for dynamic service management
@MainActor
public final class ServiceRegistry {
    
    public static let shared = ServiceRegistry()
    
    private var services: [String: Any] = [:]
    private let lock = NSLock()
    
    private init() {}
    
    public func register<Service>(_ type: Service.Type, instance: Service) {
        lock.lock()
        services[String(describing: type)] = instance
        lock.unlock()
    }
    
    public func resolve<Service>(_ type: Service.Type) -> Service? {
        lock.lock()
        defer { lock.unlock() }
        return services[String(describing: type)] as? Service
    }
    
    public func unregister<Service>(_ type: Service.Type) {
        lock.lock()
        services.removeValue(forKey: String(describing: type))
        lock.unlock()
    }
    
    public func clear() {
        lock.lock()
        services.removeAll()
        lock.unlock()
    }
}
