import Foundation
import WatchConnectivity
import Combine

// MARK: - Watch Connectivity Manager

/// Manages communication between iPhone and Apple Watch
/// Syncs timer state, controls, and session data
@MainActor
final class WatchConnectivityManager: NSObject, ObservableObject {
    
    static let shared = WatchConnectivityManager()
    
    // MARK: - Published Properties
    
    @Published var isWatchConnected: Bool = false
    @Published var isWatchAppInstalled: Bool = false
    @Published var lastReceivedMessage: WatchMessage?
    @Published var isReachable: Bool = false
    
    // MARK: - Private Properties
    
    private var session: WCSession?
    private var cancellables = Set<AnyCancellable>()
    private var messageHandlers: [WatchMessageType: ([String: Any]) -> Void] = [:]
    
    // MARK: - Initialization
    
    private override init() {
        super.init()
        setupSession()
    }
    
    // MARK: - Setup
    
    private func setupSession() {
        guard WCSession.isSupported() else {
            print("Watch Connectivity not supported")
            return
        }
        
        session = WCSession.default
        session?.delegate = self
        session?.activate()
    }
    
    // MARK: - Message Handlers
    
    func registerHandler(for type: WatchMessageType, handler: @escaping ([String: Any]) -> Void) {
        messageHandlers[type] = handler
    }
    
    func removeHandler(for type: WatchMessageType) {
        messageHandlers.removeValue(forKey: type)
    }
    
    // MARK: - Send Messages
    
    func sendTimerState(
        state: TimerState,
        currentPhase: String,
        remainingTime: TimeInterval,
        progress: Double,
        isAgitationRequired: Bool = false
    ) {
        let message: [String: Any] = [
            "type": WatchMessageType.timerStateUpdate.rawValue,
            "timerState": timerStateString(from: state),
            "currentPhase": currentPhase,
            "remainingTime": remainingTime,
            "progress": progress,
            "isAgitationRequired": isAgitationRequired,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        sendMessage(message)
    }
    
    func sendSessionStarted(sessionType: SessionType, totalPhases: Int, phaseNames: [String]) {
        let message: [String: Any] = [
            "type": WatchMessageType.sessionStarted.rawValue,
            "sessionType": sessionType.rawValue,
            "totalPhases": totalPhases,
            "phaseNames": phaseNames,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        sendMessage(message)
    }
    
    func sendPhaseCompleted(phaseIndex: Int, phaseName: String) {
        let message: [String: Any] = [
            "type": WatchMessageType.phaseCompleted.rawValue,
            "phaseIndex": phaseIndex,
            "phaseName": phaseName,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        sendMessage(message)
    }
    
    func sendSessionCompleted(success: Bool) {
        let message: [String: Any] = [
            "type": WatchMessageType.sessionCompleted.rawValue,
            "success": success,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        sendMessage(message)
    }
    
    func sendAgitationAlert() {
        let message: [String: Any] = [
            "type": WatchMessageType.agitationAlert.rawValue,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        sendMessage(message)
    }
    
    func sendRecipeInfo(recipeName: String, developer: String, time: String) {
        let message: [String: Any] = [
            "type": WatchMessageType.recipeInfo.rawValue,
            "recipeName": recipeName,
            "developer": developer,
            "time": time,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        sendMessage(message)
    }
    
    // MARK: - Private Send Methods
    
    private func sendMessage(_ message: [String: Any]) {
        guard let session = session, isReachable else {
            // Queue for later if not reachable
            updateApplicationContext(message)
            return
        }
        
        session.sendMessage(message, replyHandler: nil) { error in
            print("Failed to send message: \(error.localizedDescription)")
        }
    }
    
    private func updateApplicationContext(_ context: [String: Any]) {
        guard let session = session else { return }
        
        do {
            try session.updateApplicationContext(context)
        } catch {
            print("Failed to update application context: \(error)")
        }
    }
    
    private func sendCommand(_ command: WatchCommand) {
        let message: [String: Any] = [
            "type": WatchMessageType.command.rawValue,
            "command": command.rawValue,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        sendMessage(message)
    }
    
    // MARK: - Helper Methods
    
    private func timerStateString(from state: TimerState) -> String {
        switch state {
        case .idle: return "idle"
        case .running: return "running"
        case .paused: return "paused"
        case .completed: return "completed"
        }
    }
    
    private func parseTimerState(from string: String) -> TimerState {
        switch string {
        case "running": return .running(startTime: Date(), pausedDuration: 0)
        case "paused": return .paused(elapsedAtPause: 0)
        case "completed": return .completed
        default: return .idle
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityManager: WCSessionDelegate {
    
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            if let error = error {
                print("WCSession activation error: \(error)")
                return
            }
            
            isWatchConnected = activationState == .activated
            isWatchAppInstalled = session.isWatchAppInstalled
            isReachable = session.isReachable
            
            print("WCSession activated: \(activationState.rawValue)")
        }
    }
    
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        print("WCSession became inactive")
    }
    
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        print("WCSession deactivated")
        // Reactivate if needed
        session.activate()
    }
    
    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in
            isWatchAppInstalled = session.isWatchAppInstalled
            isReachable = session.isReachable
            print("Watch state changed - Installed: \(isWatchAppInstalled), Reachable: \(isReachable)")
        }
    }
    
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in
            handleReceivedMessage(message)
        }
    }
    
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        Task { @MainActor in
            handleReceivedMessage(message)
            replyHandler(["status": "received"])
        }
    }
    
    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in
            handleReceivedMessage(applicationContext)
        }
    }
    
    @MainActor
    private func handleReceivedMessage(_ message: [String: Any]) {
        guard let typeString = message["type"] as? String,
              let type = WatchMessageType(rawValue: typeString) else {
            print("Received message with unknown type")
            return
        }
        
        let watchMessage = WatchMessage(type: type, data: message)
        lastReceivedMessage = watchMessage
        
        // Call registered handler if exists
        if let handler = messageHandlers[type] {
            handler(message)
        }
        
        // Handle built-in message types
        switch type {
        case .command:
            if let commandString = message["command"] as? String,
               let command = WatchCommand(rawValue: commandString) {
                handleCommand(command)
            }
        default:
            break
        }
    }
    
    @MainActor
    private func handleCommand(_ command: WatchCommand) {
        NotificationCenter.default.post(
            name: .watchCommandReceived,
            object: nil,
            userInfo: ["command": command]
        )
    }
}

// MARK: - Supporting Types

enum WatchMessageType: String, Codable {
    case timerStateUpdate = "timer_state_update"
    case sessionStarted = "session_started"
    case phaseCompleted = "phase_completed"
    case sessionCompleted = "session_completed"
    case agitationAlert = "agitation_alert"
    case recipeInfo = "recipe_info"
    case command = "command"
    case settingsUpdate = "settings_update"
    case requestSync = "request_sync"
}

enum WatchCommand: String, Codable {
    case start = "start"
    case pause = "pause"
    case resume = "resume"
    case stop = "stop"
    case skipPhase = "skip_phase"
    case previousPhase = "previous_phase"
    case acknowledgeAgitation = "acknowledge_agitation"
    case requestTimerState = "request_timer_state"
}

struct WatchMessage: Identifiable {
    let id = UUID()
    let type: WatchMessageType
    let data: [String: Any]
    let timestamp: Date
    
    init(type: WatchMessageType, data: [String: Any]) {
        self.type = type
        self.data = data
        self.timestamp = Date()
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let watchCommandReceived = Notification.Name("watchCommandReceived")
    static let watchTimerStateUpdated = Notification.Name("watchTimerStateUpdated")
    static let watchSessionStarted = Notification.Name("watchSessionStarted")
    static let watchPhaseCompleted = Notification.Name("watchPhaseCompleted")
    static let watchSessionCompleted = Notification.Name("watchSessionCompleted")
    static let watchAgitationAlert = Notification.Name("watchAgitationAlert")
}

// MARK: - Watch App Message Sender (for Watch app)

/// Used by the Watch app to send messages to iPhone
@MainActor
final class WatchAppMessageSender: ObservableObject {
    
    static let shared = WatchAppMessageSender()
    
    private var session: WCSession?
    
    private init() {
        if WCSession.isSupported() {
            session = WCSession.default
        }
    }
    
    func sendCommand(_ command: WatchCommand) {
        let message: [String: Any] = [
            "type": WatchMessageType.command.rawValue,
            "command": command.rawValue,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        session?.sendMessage(message, replyHandler: nil) { error in
            print("Failed to send command: \(error.localizedDescription)")
        }
    }
    
    func requestTimerState() {
        sendCommand(.requestTimerState)
    }
    
    func sendAcknowledgment(agitationCompleted: Bool) {
        let message: [String: Any] = [
            "type": WatchMessageType.command.rawValue,
            "command": WatchCommand.acknowledgeAgitation.rawValue,
            "agitationCompleted": agitationCompleted,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        session?.sendMessage(message, replyHandler: nil) { error in
            print("Failed to send acknowledgment: \(error.localizedDescription)")
        }
    }
}
