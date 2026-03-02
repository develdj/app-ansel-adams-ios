import SwiftUI

// MARK: - Print Timer View

/// Timer view for darkroom printing with enlarger
struct PrintTimerView: View {
    @StateObject var session: PrintSession
    @StateObject private var liveActivity = UnifiedLiveActivityManager.shared
    
    @State private var showTestStripMode = false
    @State private var showSplitGradeMode = false
    @State private var showBurnDodgeSheet = false
    @State private var selectedTestStripRating: TestStripRating?
    
    var body: some View {
        VStack(spacing: 0) {
            // Mode Selector
            modeSelector
            
            ScrollView {
                VStack(spacing: 24) {
                    // Main Timer Display
                    timerDisplay
                    
                    // Exposure Controls
                    exposureControls
                    
                    // Test Strip Results
                    if session.currentMode == .testStrip && !session.testStripResults.isEmpty {
                        testStripResultsView
                    }
                    
                    // Burn & Dodge
                    if !session.burnDodgeTimes.isEmpty {
                        burnDodgeView
                    }
                    
                    // F-Stop Calculator
                    fStopCalculator
                    
                    // Phase List
                    phaseListView
                }
                .padding()
            }
            
            // Control Buttons
            controlButtons
        }
        .background(Color(.systemBackground))
        .navigationTitle("Print Timer")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showBurnDodgeSheet) {
            BurnDodgeSheet(session: session, isPresented: $showBurnDodgeSheet)
        }
        .onChange(of: session.timerManager.state) { _, _ in
            updateLiveActivity()
        }
    }
    
    // MARK: - Mode Selector
    
    private var modeSelector: some View {
        Picker("Mode", selection: Binding(
            get: { session.currentMode },
            set: { newMode in
                withAnimation {
                    session.currentMode = newMode
                }
            }
        )) {
            Text("Full Print").tag(PrintSession.PrintMode.fullPrint)
            Text("Test Strip").tag(PrintSession.PrintMode.testStrip)
            Text("Split Grade").tag(PrintSession.PrintMode.splitGrade)
        }
        .pickerStyle(.segmented)
        .padding()
        .background(Color(.secondarySystemBackground))
    }
    
    // MARK: - Timer Display
    
    private var timerDisplay: some View {
        VStack(spacing: 16) {
            // Exposure time display
            if session.useSplitGrade {
                HStack(spacing: 24) {
                    VStack {
                        Text("Filter 00")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(String(format: "%.1f", session.lowContrastExposure))
                            .font(.title2)
                            .monospacedDigit()
                    }
                    
                    Text("+")
                        .font(.title)
                        .foregroundColor(.secondary)
                    
                    VStack {
                        Text("Filter 5")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(String(format: "%.1f", session.highContrastExposure))
                            .font(.title2)
                            .monospacedDigit()
                    }
                }
            }
            
            // Main countdown
            Text(session.timerManager.formattedRemainingTime)
                .font(.system(size: 80, weight: .bold, design: .monospaced))
                .foregroundColor(.primary)
                .minimumScaleFactor(0.5)
            
            // Total exposure
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                Text("Total: \(session.formattedTotalExposure)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 20)
    }
    
    // MARK: - Exposure Controls
    
    private var exposureControls: some View {
        VStack(spacing: 16) {
            if session.currentMode == .fullPrint {
                // Base exposure slider
                VStack(alignment: .leading, spacing: 8) {
                    Text("Base Exposure")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text("0.5s")
                            .font(.caption)
                        
                        Slider(
                            value: $session.baseExposureSeconds,
                            in: 0.5...60,
                            step: 0.5
                        )
                        
                        Text("60s")
                            .font(.caption)
                    }
                    
                    Text(String(format: "%.1f seconds", session.baseExposureSeconds))
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                
                // Filter grade
                VStack(alignment: .leading, spacing: 8) {
                    Text("Multigrade Filter")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Picker("Filter", selection: $session.filterGrade) {
                        ForEach(0...5, id: \.self) { grade in
                            Text("\(grade)").tag(grade)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                
            } else if session.currentMode == .testStrip {
                // Test strip controls
                VStack(alignment: .leading, spacing: 12) {
                    Text("Test Strip Settings")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text("Steps:")
                        Picker("Steps", selection: $session.testStripStepCount) {
                            ForEach([3, 5, 7, 9], id: \.self) { count in
                                Text("\(count)").tag(count)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    HStack {
                        Text("Increment:")
                        Picker("Increment", selection: $session.testStripStepSize) {
                            Text("1s").tag(1.0)
                            Text("2s").tag(2.0)
                            Text("3s").tag(3.0)
                            Text("5s").tag(5.0)
                        }
                        .pickerStyle(.segmented)
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                
            } else if session.currentMode == .splitGrade {
                // Split grade controls
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Low Contrast (Filter 00)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Slider(
                                value: $session.lowContrastExposure,
                                in: 0...30,
                                step: 0.5
                            )
                            Text(String(format: "%.1fs", session.lowContrastExposure))
                                .font(.subheadline)
                                .monospacedDigit()
                                .frame(width: 50)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("High Contrast (Filter 5)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Slider(
                                value: $session.highContrastExposure,
                                in: 0...30,
                                step: 0.5
                            )
                            Text(String(format: "%.1fs", session.highContrastExposure))
                                .font(.subheadline)
                                .monospacedDigit()
                                .frame(width: 50)
                        }
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
            }
            
            // Burn & Dodge Button
            Button(action: {
                showBurnDodgeSheet = true
            }) {
                HStack {
                    Image(systemName: "circle.dashed")
                    Text("Burn & Dodge")
                    if !session.burnDodgeTimes.isEmpty {
                        Text("(\(session.burnDodgeTimes.count))")
                            .font(.caption)
                    }
                }
            }
            .buttonStyle(.bordered)
        }
    }
    
    // MARK: - Test Strip Results
    
    private var testStripResultsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Test Strip Results")
                .font(.headline)
            
            HStack(spacing: 8) {
                ForEach(TestStripRating.allCases, id: \.self) { rating in
                    Button(action: {
                        // Record result for current step
                        let currentStep = session.timerManager.currentPhaseIndex
                        session.recordTestStripResult(step: currentStep, rating: rating)
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: rating.icon)
                            Text(rating.rawValue)
                                .font(.caption2)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(session.testStripResults.last?.rating == rating ?
                                      Color.blue.opacity(0.2) : Color(.systemGray6))
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            if let bestExposure = session.getBestExposure() {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Best exposure: \(String(format: "%.1f", bestExposure))s")
                        .font(.subheadline)
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Burn & Dodge View
    
    private var burnDodgeView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Burn & Dodge Zones")
                .font(.headline)
            
            ForEach(session.burnDodgeTimes) { zone in
                HStack {
                    Image(systemName: zone.type == .burn ? "sun.max" : "sun.min")
                        .foregroundColor(zone.type == .burn ? .orange : .yellow)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(zone.area)
                            .font(.subheadline)
                        Text("\(zone.type.rawValue) for \(String(format: "%.1f", zone.duration))s")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        if let index = session.burnDodgeTimes.firstIndex(where: { $0.id == zone.id }) {
                            session.removeBurnDodgeZone(at: index)
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - F-Stop Calculator
    
    private var fStopCalculator: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("F-Stop Adjustments")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(session.getFStopAdjustments(), id: \.label) { adjustment in
                        VStack(spacing: 4) {
                            Text(adjustment.label)
                                .font(.caption)
                            Text(String(format: "%.1f", adjustment.time))
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .monospacedDigit()
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(adjustment.label == "Base" ?
                                      Color.blue.opacity(0.2) : Color(.systemGray6))
                        )
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Phase List
    
    private var phaseListView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Processing Phases")
                .font(.headline)
            
            VStack(spacing: 8) {
                ForEach(Array(session.timerManager.phases.enumerated()), id: \.element.id) { index, phase in
                    PhaseRow(
                        phase: phase,
                        index: index,
                        isCurrent: index == session.timerManager.currentPhaseIndex,
                        isCompleted: index < session.timerManager.currentPhaseIndex
                    )
                }
            }
        }
    }
    
    // MARK: - Control Buttons
    
    private var controlButtons: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                // Play/Pause Button
                Button(action: {
                    if session.isRunning {
                        session.pause()
                    } else {
                        session.startExposure()
                    }
                }) {
                    Image(systemName: session.isRunning ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(session.isRunning ? .orange : .green)
                }
                
                // Stop Button
                Button(action: {
                    session.stop()
                }) {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.red)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
    }
    
    // MARK: - Live Activity
    
    private func updateLiveActivity() {
        let sessionType: SessionType = session.currentMode == .testStrip ? .testStrip :
                                      session.useSplitGrade ? .splitGrade : .printDevelopment
        
        if session.isRunning {
            if !liveActivity.isActivityActive {
                liveActivity.startActivity(
                    sessionType: sessionType,
                    currentPhase: session.timerManager.currentPhase?.name ?? "Exposure",
                    totalPhases: session.timerManager.phases.count,
                    currentPhaseIndex: session.timerManager.currentPhaseIndex,
                    totalDuration: session.totalExposureTime,
                    remainingTime: session.timerManager.remainingTime
                )
            } else {
                liveActivity.updateActivity(
                    currentPhase: session.timerManager.currentPhase?.name ?? "Exposure",
                    currentPhaseIndex: session.timerManager.currentPhaseIndex,
                    remainingTime: session.timerManager.remainingTime,
                    progress: session.timerManager.progress
                )
            }
        } else if session.timerManager.state.isIdle {
            liveActivity.endActivity()
        }
    }
}

// MARK: - Burn & Dodge Sheet

struct BurnDodgeSheet: View {
    @ObservedObject var session: PrintSession
    @Binding var isPresented: Bool
    
    @State private var selectedType: BurnDodgeType = .burn
    @State private var area: String = ""
    @State private var duration: Double = 2.0
    @State private var toolSize: String = "Standard"
    
    var body: some View {
        NavigationView {
            Form {
                Section("Type") {
                    Picker("Action", selection: $selectedType) {
                        Text("Burn (darken)").tag(BurnDodgeType.burn)
                        Text("Dodge (lighten)").tag(BurnDodgeType.dodge)
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("Area") {
                    TextField("Describe area (e.g., 'sky', 'face')", text: $area)
                }
                
                Section("Duration") {
                    Slider(value: $duration, in: 0.5...10, step: 0.5)
                    Text(String(format: "%.1f seconds", duration))
                }
                
                Section("Tool Size") {
                    Picker("Size", selection: $toolSize) {
                        Text("Small").tag("Small")
                        Text("Standard").tag("Standard")
                        Text("Large").tag("Large")
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("Add Burn/Dodge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        session.addBurnDodgeZone(
                            type: selectedType,
                            area: area.isEmpty ? "Area \(session.burnDodgeTimes.count + 1)" : area,
                            duration: duration,
                            toolSize: toolSize
                        )
                        isPresented = false
                    }
                    .disabled(area.isEmpty)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        PrintTimerView(session: PrintSession())
    }
}
