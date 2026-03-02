import SwiftUI

// MARK: - Settings View

/// App settings and preferences
struct SettingsView: View {
    @AppStorage("audioEnabled") private var audioEnabled = true
    @AppStorage("hapticEnabled") private var hapticEnabled = true
    @AppStorage("countdownBeeps") private var countdownBeeps = true
    @AppStorage("defaultTemperature") private var defaultTemperature = 20.0
    @AppStorage("defaultAgitation") private var defaultAgitation = 0 // 0 = Standard
    @AppStorage("keepScreenOn") private var keepScreenOn = true
    @AppStorage("darkMode") private var darkMode = false
    
    @State private var showResetConfirmation = false
    @State private var showAboutSheet = false
    
    var body: some View {
        NavigationView {
            List {
                // Audio & Haptics
                audioHapticsSection
                
                // Timer Preferences
                timerPreferencesSection
                
                // Display
                displaySection
                
                // Data Management
                dataManagementSection
                
                // About
                aboutSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .confirmationDialog(
                "Reset All Data?",
                isPresented: $showResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Reset All Data", role: .destructive) {
                    resetAllData()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will delete all recipes and session history. This action cannot be undone.")
            }
            .sheet(isPresented: $showAboutSheet) {
                AboutView()
            }
        }
    }
    
    // MARK: - Audio & Haptics Section
    
    private var audioHapticsSection: some View {
        Section("Audio & Haptics") {
            Toggle(isOn: $audioEnabled) {
                Label("Sound Effects", systemImage: "speaker.wave.2.fill")
            }
            .onChange(of: audioEnabled) { _, newValue in
                AudioHapticFeedback.shared.setAudioEnabled(newValue)
            }
            
            Toggle(isOn: $hapticEnabled) {
                Label("Haptic Feedback", systemImage: "hand.tap.fill")
            }
            .onChange(of: hapticEnabled) { _, newValue in
                AudioHapticFeedback.shared.setHapticEnabled(newValue)
            }
            
            Toggle(isOn: $countdownBeeps) {
                Label("Countdown Beeps", systemImage: "timer")
            }
        }
    }
    
    // MARK: - Timer Preferences Section
    
    private var timerPreferencesSection: some View {
        Section("Timer Preferences") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Default Temperature: \(String(format: "%.1f", defaultTemperature))°C")
                    .font(.subheadline)
                
                Slider(value: $defaultTemperature, in: 15...25, step: 0.5)
            }
            .padding(.vertical, 4)
            
            Picker("Default Agitation", selection: $defaultAgitation) {
                ForEach(AgitationStyle.allCases.indices, id: \.self) { index in
                    Text(AgitationStyle.allCases[index].rawValue).tag(index)
                }
            }
        }
    }
    
    // MARK: - Display Section
    
    private var displaySection: some View {
        Section("Display") {
            Toggle(isOn: $keepScreenOn) {
                Label("Keep Screen On", systemImage: "display")
            }
            
            Toggle(isOn: $darkMode) {
                Label("Dark Mode", systemImage: "moon.fill")
            }
        }
    }
    
    // MARK: - Data Management Section
    
    private var dataManagementSection: some View {
        Section("Data Management") {
            Button(action: {
                exportRecipes()
            }) {
                Label("Export Recipes", systemImage: "square.and.arrow.up")
            }
            
            Button(action: {
                importRecipes()
            }) {
                Label("Import Recipes", systemImage: "square.and.arrow.down")
            }
            
            Button(action: {
                showResetConfirmation = true
            }) {
                Label("Reset All Data", systemImage: "trash")
                    .foregroundColor(.red)
            }
        }
    }
    
    // MARK: - About Section
    
    private var aboutSection: some View {
        Section("About") {
            Button(action: {
                showAboutSheet = true
            }) {
                Label("About Zone System Master", systemImage: "info.circle")
            }
            
            HStack {
                Label("Version", systemImage: "number")
                Spacer()
                Text("1.0.0")
                    .foregroundColor(.secondary)
            }
            
            Link(destination: URL(string: "https://example.com/support")!) {
                Label("Support", systemImage: "questionmark.circle")
            }
            
            Link(destination: URL(string: "https://example.com/privacy")!) {
                Label("Privacy Policy", systemImage: "hand.raised")
            }
        }
    }
    
    // MARK: - Actions
    
    private func exportRecipes() {
        // Implement export functionality
        print("Export recipes")
    }
    
    private func importRecipes() {
        // Implement import functionality
        print("Import recipes")
    }
    
    private func resetAllData() {
        // Implement reset functionality
        print("Reset all data")
    }
}

// MARK: - About View

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // App Icon
                    Image(systemName: "camera.aperture")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                    
                    // App Name
                    Text("Zone System Master")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Professional Darkroom Timer")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    // Description
                    VStack(alignment: .leading, spacing: 12) {
                        Text("About")
                            .font(.headline)
                        
                        Text("Zone System Master is a professional timer app for film photographers. Based on Ansel Adams' Zone System, it provides precise timing for film development and darkroom printing.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    
                    // Features
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Features")
                            .font(.headline)
                        
                        FeatureRow(icon: "timer", text: "Precise multi-phase timers")
                        FeatureRow(icon: "arrow.2.circlepath", text: "Agitation scheduling")
                        FeatureRow(icon: "book", text: "Recipe management")
                        FeatureRow(icon: "lock.screen", text: "Live Activities support")
                        FeatureRow(icon: "applewatch", text: "Apple Watch integration")
                        FeatureRow(icon: "speaker.wave.2", text: "Audio & haptic feedback")
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    
                    // Credits
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Credits")
                            .font(.headline)
                        
                        Text("Inspired by the work of Ansel Adams and the Zone System technique described in 'The Negative' and 'The Print'.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            Text(text)
                .font(.subheadline)
            
            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
}
