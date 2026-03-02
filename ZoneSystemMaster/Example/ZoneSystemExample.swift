// MARK: - Zone System Master - Example Usage
// Esempio di utilizzo completo dell'AI Engine
// Swift 6.0

import SwiftUI
import UIKit

// MARK: - Example App Structure

@main
struct ZoneSystemMasterApp: App {
    @StateObject private var coordinator = ZoneSystemCoordinator()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(coordinator)
        }
    }
}

// MARK: - Main Content View

struct ContentView: View {
    @EnvironmentObject var coordinator: ZoneSystemCoordinator
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab Analisi
            AnalysisTabView(selectedImage: $selectedImage, showImagePicker: $showImagePicker)
                .tabItem {
                    Label("Analisi", systemImage: "photo")
                }
                .tag(0)
            
            // Tab Chatbot
            ChatTabView()
                .tabItem {
                    Label("Ansel", systemImage: "bubble.left.fill")
                }
                .tag(1)
            
            // Tab Storico
            HistoryTabView()
                .tabItem {
                    Label("Storico", systemImage: "clock")
                }
                .tag(2)
            
            // Tab Impostazioni
            SettingsTabView()
                .tabItem {
                    Label("Impostazioni", systemImage: "gear")
                }
                .tag(3)
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(selectedImage: $selectedImage)
        }
    }
}

// MARK: - Analysis Tab

struct AnalysisTabView: View {
    @EnvironmentObject var coordinator: ZoneSystemCoordinator
    @Binding var selectedImage: UIImage?
    @Binding var showImagePicker: Bool
    
    var body: some View {
        NavigationView {
            VStack {
                if let image = selectedImage {
                    coordinator.analysisView(for: image)
                } else {
                    EmptyStateView(showImagePicker: $showImagePicker)
                }
            }
            .navigationTitle("Zone System Master")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showImagePicker = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }
}

struct EmptyStateView: View {
    @Binding var showImagePicker: Bool
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Logo
            VStack(spacing: 16) {
                Image(systemName: "camera.aperture")
                    .font(.system(size: 80))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.gray, .black],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                Text("Zone System Master")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("AI Critique Engine by Ansel Adams")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Features
            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(icon: "chart.bar", title: "Analisi Zone", description: "Mappatura completa delle 11 zone")
                FeatureRow(icon: "waveform", title: "Gamma Dinamica", description: "Valutazione stops e contrasto")
                FeatureRow(icon: "bubble.left", title: "Critica AI", description: "Feedback in stile Ansel Adams")
                FeatureRow(icon: "lightbulb", title: "Suggerimenti", description: "Consigli esposizione e sviluppo")
            }
            .padding(.horizontal)
            
            Spacer()
            
            // CTA
            Button(action: { showImagePicker = true }) {
                HStack {
                    Image(systemName: "photo")
                    Text("Carica Immagine")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        colors: [.gray, .black],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.bottom, 30)
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Chat Tab

struct ChatTabView: View {
    @EnvironmentObject var coordinator: ZoneSystemCoordinator
    
    var body: some View {
        NavigationView {
            coordinator.chatbotView()
                .navigationTitle("Chatta con Ansel")
        }
    }
}

// MARK: - History Tab

struct HistoryTabView: View {
    @EnvironmentObject var coordinator: ZoneSystemCoordinator
    
    var body: some View {
        NavigationView {
            List {
                if coordinator.analysisHistory.isEmpty {
                    Section {
                        Text("Nessuna analisi nello storico")
                            .foregroundColor(.secondary)
                    }
                } else {
                    ForEach(coordinator.analysisHistory, id: \.imageId) { analysis in
                        HistoryRow(analysis: analysis)
                    }
                    .onDelete { indexSet in
                        // Implementa cancellazione
                    }
                }
            }
            .navigationTitle("Storico Analisi")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { coordinator.clearHistory() }) {
                        Text("Cancella")
                    }
                }
            }
        }
    }
}

struct HistoryRow: View {
    let analysis: ImageAnalysisResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: sceneIcon)
                    .foregroundColor(.accentColor)
                
                Text(analysis.sceneType.rawValue)
                    .font(.headline)
                
                Spacer()
                
                Text("\(Int(analysis.technicalScore))")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(scoreColor)
            }
            
            HStack {
                Label("\(analysis.dynamicRange.dynamicRangeStops, specifier: "%.1f") stops", systemImage: "waveform")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(analysis.timestamp, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var sceneIcon: String {
        switch analysis.sceneType {
        case .landscape: return "mountain.2"
        case .portrait: return "person.crop.rectangle"
        case .street: return "building.2"
        case .xpan: return "panorama"
        case .architecture: return "building.columns"
        case .macro: return "leaf"
        case .unknown: return "questionmark"
        }
    }
    
    private var scoreColor: Color {
        if analysis.technicalScore >= 80 { return .green }
        if analysis.technicalScore >= 60 { return .blue }
        if analysis.technicalScore >= 40 { return .orange }
        return .red
    }
}

// MARK: - Settings Tab

struct SettingsTabView: View {
    @AppStorage("preferredLanguage") private var language = "it"
    @AppStorage("showZoneColors") private var showZoneColors = true
    @AppStorage("detailedAnalysis") private var detailedAnalysis = true
    
    var body: some View {
        NavigationView {
            Form {
                Section("Lingua") {
                    Picker("Lingua", selection: $language) {
                        Text("Italiano").tag("it")
                        Text("English").tag("en")
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("Visualizzazione") {
                    Toggle("Colori Zone", isOn: $showZoneColors)
                    Toggle("Analisi Dettagliata", isOn: $detailedAnalysis)
                }
                
                Section("Informazioni") {
                    HStack {
                        Text("Versione")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("AI Engine")
                        Spacer()
                        Text("Apple Intelligence On-Device")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section {
                    Text("Zone System Master utilizza Apple Intelligence per l'analisi on-device delle immagini. I tuoi dati non lasciano mai il dispositivo.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Impostazioni")
        }
    }
}

// MARK: - Image Picker

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Usage Examples

/*
 ESEMPI DI UTILIZZO:
 
 1. Analisi singola immagine:
    let coordinator = ZoneSystemCoordinator()
    await coordinator.analyzeImage(image)
    if let analysis = coordinator.currentAnalysis {
        print("Punteggio tecnico: \(analysis.technicalScore)")
    }
 
 2. Analisi batch:
    let images = [image1, image2, image3]
    let results = await coordinator.analyzeBatch(images: images) { current, total in
        print("Progresso: \(current)/\(total)")
    }
 
 3. Chat con Ansel:
    let response = try await coordinator.chatWithAdams("Come imposto l'esposizione?")
    print(response.content)
 
 4. Ottieni suggerimenti:
    if let suggestions = coordinator.getSuggestions() {
        for suggestion in suggestions.suggestions {
            print(suggestion.title)
        }
    }
 
 5. Analisi zone specifica:
    let zoneAnalyzer = ZoneAnalyzer()
    let distribution = try await zoneAnalyzer.analyze(image: image)
    print("Zona dominante: \(distribution.dominantZone)")
 
 6. Confronto analisi:
    let comparison = coordinator.compareAnalyses(analysis1, analysis2)
    print(comparison.summary)
 */
