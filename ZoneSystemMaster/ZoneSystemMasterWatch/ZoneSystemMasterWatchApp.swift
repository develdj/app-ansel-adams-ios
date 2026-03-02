import SwiftUI

// MARK: - Watch App Entry Point

@main
struct ZoneSystemMasterWatchApp: App {
    
    @WKApplicationDelegateAdaptor(WatchAppDelegate.self) var appDelegate
    
    @SceneBuilder var body: some Scene {
        WindowGroup {
            WatchContentView()
        }
        
        // Complications
        WKNotificationScene(controller: NotificationController.self, category: "timer_complete")
    }
}

// MARK: - Watch App Delegate

class WatchAppDelegate: NSObject, WKApplicationDelegate {
    
    func applicationDidFinishLaunching() {
        // Setup Watch Connectivity
        _ = WatchSessionManager.shared
    }
    
    func applicationDidBecomeActive() {
        // Request current timer state from iPhone
        WatchSessionManager.shared.requestTimerState()
    }
}

// MARK: - Watch Content View

struct WatchContentView: View {
    @StateObject private var sessionManager = WatchSessionManager.shared
    @StateObject private var timerViewModel = WatchTimerViewModel()
    
    var body: some View {
        TabView {
            // Timer View
            WatchTimerView(viewModel: timerViewModel)
                .tabItem {
                    Label("Timer", systemImage: "timer")
                }
            
            // Controls View
            WatchControlsView(viewModel: timerViewModel)
                .tabItem {
                    Label("Controls", systemImage: "slider.horizontal.3")
                }
            
            // Status View
            WatchStatusView(sessionManager: sessionManager)
                .tabItem {
                    Label("Status", systemImage: "info.circle")
                }
        }
        .onAppear {
            // Setup timer updates from phone
            setupTimerUpdates()
        }
    }
    
    private func setupTimerUpdates() {
        // Timer updates are handled through WatchSessionManager
    }
}

// MARK: - Watch Timer View

struct WatchTimerView: View {
    @ObservedObject var viewModel: WatchTimerViewModel
    
    var body: some View {
        VStack(spacing: 8) {
            // Session Type
            if let sessionType = viewModel.sessionType {
                HStack {
                    Image(systemName: sessionType.icon)
                        .foregroundColor(sessionType.color)
                    Text(sessionType.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Current Phase
            Text(viewModel.currentPhase)
                .font(.headline)
                .lineLimit(1)
            
            // Timer Display
            Text(viewModel.formattedRemainingTime)
                .font(.system(size: 48, weight: .bold, design: .monospaced))
                .foregroundColor(timerColor)
                .minimumScaleFactor(0.5)
            
            // Progress
            ProgressView(value: viewModel.progress)
                .tint(.blue)
            
            // Phase indicator
            Text("Phase \(viewModel.currentPhaseIndex + 1) of \(viewModel.totalPhases)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Agitation Alert
            if viewModel.isAgitationRequired {
                HStack {
                    Image(systemName: "arrow.2.circlepath")
                        .symbolEffect(.pulse)
                    Text("AGITATE!")
                        .fontWeight(.bold)
                }
                .foregroundColor(.yellow)
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(Color.yellow.opacity(0.2))
                .cornerRadius(8)
            }
        }
        .padding()
    }
    
    private var timerColor: Color {
        if viewModel.remainingTime < 10 {
            return .red
        } else if viewModel.remainingTime < 30 {
            return .orange
        }
        return .primary
    }
}

// MARK: - Watch Controls View

struct WatchControlsView: View {
    @ObservedObject var viewModel: WatchTimerViewModel
    
    var body: some View {
        VStack(spacing: 12) {
            // Play/Pause
            Button(action: {
                viewModel.togglePlayPause()
            }) {
                Image(systemName: viewModel.isRunning ? "pause.fill" : "play.fill")
                    .font(.title2)
                    .frame(maxWidth: .infinity)
            }
            .tint(viewModel.isRunning ? .orange : .green)
            .buttonStyle(.borderedProminent)
            
            // Stop
            Button(action: {
                viewModel.stop()
            }) {
                Image(systemName: "stop.fill")
                    .font(.title2)
                    .frame(maxWidth: .infinity)
            }
            .tint(.red)
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.isRunning && !viewModel.isPaused)
            
            // Skip Phase
            Button(action: {
                viewModel.skipPhase()
            }) {
                Label("Skip Phase", systemImage: "forward.fill")
                    .font(.caption)
            }
            .tint(.blue)
            .buttonStyle(.bordered)
            .disabled(!viewModel.isRunning && !viewModel.isPaused)
            
            // Acknowledge Agitation
            if viewModel.isAgitationRequired {
                Button(action: {
                    viewModel.acknowledgeAgitation()
                }) {
                    Label("Done Agitating", systemImage: "checkmark")
                        .font(.caption)
                }
                .tint(.yellow)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
}

// MARK: - Watch Status View

struct WatchStatusView: View {
    @ObservedObject var sessionManager: WatchSessionManager
    
    var body: some View {
        List {
            Section("Connection") {
                HStack {
                    Text("iPhone Status")
                    Spacer()
                    Text(sessionManager.isReachable ? "Connected" : "Disconnected")
                        .foregroundColor(sessionManager.isReachable ? .green : .red)
                }
                
                HStack {
                    Text("Last Update")
                    Spacer()
                    if let lastUpdate = sessionManager.lastUpdateTime {
                        Text(timeAgo(from: lastUpdate))
                            .foregroundColor(.secondary)
                    } else {
                        Text("Never")
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Section("Timer Info") {
                if let phase = sessionManager.currentPhase {
                    HStack {
                        Text("Current Phase")
                        Spacer()
                        Text(phase)
                            .foregroundColor(.secondary)
                    }
                }
                
                if sessionManager.totalPhases > 0 {
                    HStack {
                        Text("Progress")
                        Spacer()
                        Text("\(sessionManager.currentPhaseIndex + 1)/\(sessionManager.totalPhases)")
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Section("Actions") {
                Button(action: {
                    sessionManager.requestTimerState()
                }) {
                    Label("Sync with iPhone", systemImage: "arrow.clockwise")
                }
            }
        }
        .listStyle(.carousel)
    }
    
    private func timeAgo(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Watch Timer View Model

@MainActor
class WatchTimerViewModel: ObservableObject {
    
    @Published var sessionType: SessionType?
    @Published var currentPhase: String = "Ready"
    @Published var currentPhaseIndex: Int = 0
    @Published var totalPhases: Int = 0
    @Published var remainingTime: TimeInterval = 0
    @Published var progress: Double = 0
    @Published var isAgitationRequired: Bool = false
    @Published var isRunning: Bool = false
    @Published var isPaused: Bool = false
    
    private var sessionManager = WatchSessionManager.shared
    
    var formattedRemainingTime: String {
        let totalSeconds = Int(remainingTime)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        if minutes > 0 {
            return String(format: "%d:%02d", minutes, seconds)
        }
        return String(format: "%02d", seconds)
    }
    
    init() {
        setupSubscriptions()
    }
    
    private func setupSubscriptions() {
        // Subscribe to session manager updates
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateFromSessionManager()
            }
        }
    }
    
    private func updateFromSessionManager() {
        sessionType = sessionManager.sessionType
        currentPhase = sessionManager.currentPhase ?? "Ready"
        currentPhaseIndex = sessionManager.currentPhaseIndex
        totalPhases = sessionManager.totalPhases
        remainingTime = sessionManager.remainingTime
        progress = sessionManager.progress
        isAgitationRequired = sessionManager.isAgitationRequired
        isRunning = sessionManager.isTimerRunning
        isPaused = sessionManager.isTimerPaused
    }
    
    func togglePlayPause() {
        if isRunning {
            sessionManager.sendCommand(.pause)
        } else if isPaused {
            sessionManager.sendCommand(.resume)
        } else {
            sessionManager.sendCommand(.start)
        }
    }
    
    func stop() {
        sessionManager.sendCommand(.stop)
    }
    
    func skipPhase() {
        sessionManager.sendCommand(.skipPhase)
    }
    
    func acknowledgeAgitation() {
        sessionManager.sendCommand(.acknowledgeAgitation)
    }
}

// MARK: - Watch Session Manager

@MainActor
class WatchSessionManager: NSObject, ObservableObject {
    
    static let shared = WatchSessionManager()
    
    @Published var isReachable: Bool = false
    @Published var lastUpdateTime: Date?
    
    // Timer state
    @Published var sessionType: SessionType?
    @Published var currentPhase: String?
    @Published var currentPhaseIndex: Int = 0
    @Published var totalPhases: Int = 0
    @Published var remainingTime: TimeInterval = 0
    @Published var progress: Double = 0
    @Published var isAgitationRequired: Bool = false
    @Published var isTimerRunning: Bool = false
    @Published var isTimerPaused: Bool = false
    
    private var session: WCSession?
    
    private override init() {
        super.init()
        setupSession()
    }
    
    private func setupSession() {
        guard WCSession.isSupported() else { return }
        
        session = WCSession.default
        session?.delegate = self
        session?.activate()
    }
    
    func requestTimerState() {
        sendCommand(.requestTimerState)
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
}

// MARK: - WCSessionDelegate

extension WatchSessionManager: WCSessionDelegate {
    
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            isReachable = session.isReachable
        }
    }
    
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in
            handleMessage(message)
        }
    }
    
    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in
            handleMessage(applicationContext)
        }
    }
    
    @MainActor
    private func handleMessage(_ message: [String: Any]) {
        lastUpdateTime = Date()
        
        guard let typeString = message["type"] as? String,
              let type = WatchMessageType(rawValue: typeString) else {
            return
        }
        
        switch type {
        case .timerStateUpdate:
            updateTimerState(from: message)
        case .sessionStarted:
            handleSessionStarted(from: message)
        case .phaseCompleted:
            handlePhaseCompleted(from: message)
        case .sessionCompleted:
            handleSessionCompleted(from: message)
        case .agitationAlert:
            isAgitationRequired = true
            // Trigger haptic
            WKInterfaceDevice.current().play(.notification)
        default:
            break
        }
    }
    
    private func updateTimerState(from message: [String: Any]) {
        if let phase = message["currentPhase"] as? String {
            currentPhase = phase
        }
        if let phaseIndex = message["currentPhaseIndex"] as? Int {
            currentPhaseIndex = phaseIndex
        }
        if let remaining = message["remainingTime"] as? TimeInterval {
            remainingTime = remaining
        }
        if let prog = message["progress"] as? Double {
            progress = prog
        }
        if let agitation = message["isAgitationRequired"] as? Bool {
            isAgitationRequired = agitation
        }
        if let state = message["timerState"] as? String {
            isTimerRunning = state == "running"
            isTimerPaused = state == "paused"
        }
    }
    
    private func handleSessionStarted(from message: [String: Any]) {
        if let typeString = message["sessionType"] as? String {
            sessionType = SessionType(rawValue: typeString)
        }
        if let total = message["totalPhases"] as? Int {
            totalPhases = total
        }
        // Play start haptic
        WKInterfaceDevice.current().play(.start)
    }
    
    private func handlePhaseCompleted(from message: [String: Any]) {
        // Play completion haptic
        WKInterfaceDevice.current().play(.success)
    }
    
    private func handleSessionCompleted(from message: [String: Any]) {
        // Play completion haptic
        WKInterfaceDevice.current().play(.success)
        sessionType = nil
        currentPhase = nil
    }
}

// MARK: - Notification Controller

class NotificationController: WKUserNotificationHostingController<NotificationView> {
    
    override var body: NotificationView {
        return NotificationView()
    }
    
    override func didReceive(_ notification: UNNotification) {
        // Handle notification
    }
}

// MARK: - Notification View

struct NotificationView: View {
    var body: some View {
        VStack {
            Text("Timer Complete!")
                .font(.headline)
            
            Image(systemName: "checkmark.circle.fill")
                .font(.largeTitle)
                .foregroundColor(.green)
        }
    }
}

// MARK: - Preview

#Preview {
    WatchContentView()
}
