import SwiftUI
import ZoneSystemCore
import ZoneSystemUI

// MARK: - Ansel Chat View

@MainActor
struct AnselChatView: View {

    @State private var viewModel = AnselChatViewModel()
    @Environment(DependencyContainer.self) private var container
    @State private var navigationManager = ChatNavigationManager.shared

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // Main content
                VStack(spacing: 0) {
                    // Chat messages
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: LiquidGlassTheme.Spacing.md) {
                                ForEach(viewModel.enhancedMessages) { message in
                                    EnhancedChatMessageBubble(message: message) { suggestion in
                                        handleActionSuggestion(suggestion)
                                    }
                                    .id(message.id)
                                }

                                if viewModel.isTyping {
                                    TypingIndicator()
                                        .id("typing")
                                }
                            }
                            .padding()
                            .padding(.bottom, viewModel.hasAnalysisImage ? 100 : 0) // Extra padding when action bar is shown
                        }
                        .onChange(of: viewModel.enhancedMessages) { _, _ in
                            withAnimation {
                                proxy.scrollTo(viewModel.enhancedMessages.last?.id, anchor: .bottom)
                            }
                        }
                        .onChange(of: viewModel.isTyping) { _, _ in
                            withAnimation {
                                proxy.scrollTo("typing", anchor: .bottom)
                            }
                        }
                    }

                    // Quick suggestions
                    if !viewModel.suggestions.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: LiquidGlassTheme.Spacing.sm) {
                                ForEach(viewModel.suggestions, id: \.self) { suggestion in
                                    SuggestionChip(text: suggestion) {
                                        viewModel.sendMessage(suggestion)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.vertical, LiquidGlassTheme.Spacing.sm)
                    }

                    // Input area
                    ChatInputBar(
                        text: $viewModel.inputText,
                        isLoading: viewModel.isTyping,
                        onSend: { viewModel.sendMessage() },
                        onImagePick: { viewModel.showImagePicker = true }
                    )
                    .padding()
                    .background(.ultraThinMaterial)
                }

                // Floating action bar - appears when image is analyzed
                if viewModel.hasAnalysisImage {
                    VStack(spacing: 0) {
                        // Gradient fade effect - more visible
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Color.black.opacity(0.15),
                                Color.black.opacity(0.3)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 40)
                        .ignoresSafeArea(edges: .bottom)

                        // Action bar with glass effect
                        HStack(spacing: 12) {
                            // Apply AI button
                            if viewModel.canApplySuggestions {
                                Button {
                                    viewModel.applyLastSuggestions()
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "sparkles")
                                            .font(.body.bold())
                                        Text("Apply AI")
                                            .font(.subheadline.weight(.semibold))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(
                                        LinearGradient(
                                            colors: [LiquidGlassTheme.Colors.primary, LiquidGlassTheme.Colors.primary.opacity(0.8)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .clipShape(Capsule())
                                    .shadow(color: LiquidGlassTheme.Colors.primary.opacity(0.4), radius: 8, y: 4)
                                }
                            }

                            // Edit button
                            Button {
                                viewModel.showImageEditor = true
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "slider.horizontal.3")
                                        .font(.body.bold())
                                    Text("Edit")
                                        .font(.subheadline.weight(.semibold))
                                }
                                .foregroundColor(.primary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(.ultraThinMaterial)
                                .clipShape(Capsule())
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                )
                                .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
                            }

                            Spacer()

                            // View analysis button with score
                            Button {
                                viewModel.showAnalysisResult = true
                            } label: {
                                HStack(spacing: 4) {
                                    if let result = viewModel.analysisResult {
                                        Text("\(result.qualityScore)")
                                            .font(.subheadline.weight(.bold))
                                            .foregroundColor(scoreColor(result.qualityScore))

                                        Text("Score")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(.thinMaterial)
                                .clipShape(Capsule())
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial)
                        .overlay(
                            Rectangle()
                                .fill(Color.white.opacity(0.15))
                                .frame(height: 1),
                            alignment: .top
                        )
                        .shadow(color: .black.opacity(0.2), radius: 10, y: -2)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(1)
                }
            }
            .navigationTitle("Chat with PAI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        navigationManager.navigate(to: .exposureMeter)
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.body.bold())
                            .foregroundColor(.secondary)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            viewModel.clearChat()
                        } label: {
                            Label("Clear Chat", systemImage: "arrow.counterclockwise")
                        }

                        Button {
                            navigationManager.navigate(to: .exposureMeter)
                        } label: {
                            Label("Go to Exposure Meter", systemImage: "camera.metering.matrix")
                        }

                        Button {
                            navigationManager.navigate(to: .darkroomTimer)
                        } label: {
                            Label("Go to Darkroom Timer", systemImage: "timer")
                        }

                        Button {
                            navigationManager.showGuidance(
                                title: "Using PAI Chat",
                                steps: [
                                    "Ask me anything about photography",
                                    "I can guide you to any app feature",
                                    "Tap action buttons to navigate",
                                    "Use step-by-step guides for help",
                                    "I remember our conversation context"
                                ]
                            )
                        } label: {
                            Label("Get Help", systemImage: "questionmark.circle")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .sheet(isPresented: $viewModel.showImagePicker) {
                ImagePicker { image in
                    viewModel.analyzeImage(image)
                }
            }
            .sheet(isPresented: $navigationManager.showGuidanceModal) {
                GuidanceModal(
                    title: navigationManager.guidanceTitle,
                    steps: navigationManager.guidanceSteps,
                    isPresented: $navigationManager.showGuidanceModal
                )
            }
            .sheet(isPresented: $viewModel.showAnalysisResult) {
                if let result = viewModel.analysisResult,
                   let image = viewModel.analysisImage {
                    ImageAnalysisResultModal(
                        result: result,
                        image: image,
                        isPresented: $viewModel.showAnalysisResult,
                        onApplyRecommendations: {
                            viewModel.applyLastSuggestions()
                        }
                    )
                }
            }
            .sheet(isPresented: $viewModel.showImageEditor) {
                if let image = viewModel.analysisImage,
                   let result = viewModel.analysisResult {
                    QuickImageEditorSheet(
                        image: image,
                        analysisResult: result,
                        pendingAdjustments: $viewModel.pendingAdjustments,
                        isPresented: $viewModel.showImageEditor
                    )
                }
            }
            .onAppear {
                viewModel.navigationManager = navigationManager
            }
        }
    }

    private func scoreColor(_ score: Int) -> Color {
        if score >= 80 { return .green }
        if score >= 60 { return .orange }
        return .red
    }

    // MARK: - Action Handler

    private func handleActionSuggestion(_ suggestion: PersonaSuggestion) {
        switch suggestion.actionType {
        case .openMeter:
            navigationManager.navigate(to: .exposureMeter)
        case .openTimer:
            navigationManager.navigate(to: .darkroomTimer)
        case .openArchive:
            navigationManager.navigate(to: .filmArchive)
        case .openEditor:
            navigationManager.navigate(to: .photoEditor)
        case .showGuidance:
            showGuidance(for: suggestion)
        default:
            // For other action types, just show the suggestion text
            viewModel.sendMessage(suggestion.title)
        }
    }

    private func showGuidance(for suggestion: PersonaSuggestion) {
        let steps = guidanceSteps(for: suggestion.actionType)
        navigationManager.showGuidance(
            title: suggestion.title,
            steps: steps
        )
    }

    private func guidanceSteps(for actionType: PersonaSuggestion.ActionType) -> [String] {
        switch actionType {
        case .openMeter:
            return [
                "Look for the Zone Meter tab in the bottom bar (second icon)",
                "Tap on it to open the exposure meter",
                "You'll see a zone scale from 0 (black) to 10 (white)",
                "Tap the zone where you want to place your subject's tone",
                "Tap the 'Measure' button to calculate exposure",
                "View your recommended aperture and shutter speed",
                "Adjust ISO or aperture if needed from the settings panel"
            ]
        case .openTimer:
            return [
                "Find the Darkroom tab in the bottom bar (third icon)",
                "Tap to open the darkroom timer",
                "Select your film type (e.g., HP5, Tri-X)",
                "Choose your developer (e.g., D-76, ID-11)",
                "Pick development time: N (normal), N+1, or N-1",
                "Start the timer and follow the audio cues",
                "Use red-light mode when working in actual darkroom"
            ]
        case .openArchive:
            return [
                "Tap the Archive tab (fourth icon) in bottom bar",
                "Tap the + button to create a new film roll",
                "Select format (35mm, 120, 4x5, etc.)",
                "Choose emulsion and ISO",
                "For each photo, log your exposure settings",
                "Add notes about subject or lighting conditions",
                "Record development after processing the roll"
            ]
        case .openEditor:
            return [
                "Open the Editor tab (fifth icon) from bottom bar",
                "Import a photo from your camera roll",
                "Review the zone histogram to see tonal distribution",
                "Use Dodge tool to lighten specific areas",
                "Use Burn tool to darken areas",
                "Apply film grain for aesthetic effect",
                "Export your edited image when satisfied"
            ]
        default:
            return []
        }
    }
}

// MARK: - Chat Message Bubble

struct ChatMessageBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
            }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: LiquidGlassTheme.Spacing.xs) {
                // Message content
                if let image = message.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 200, maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: LiquidGlassTheme.CornerRadius.md))
                }
                
                Text(message.text)
                    .font(LiquidGlassTheme.Typography.body)
                    .padding(.horizontal, LiquidGlassTheme.Spacing.md)
                    .padding(.vertical, LiquidGlassTheme.Spacing.sm)
                    .background(
                        message.isUser
                        ? LiquidGlassTheme.Colors.primary
                        : LiquidGlassTheme.Colors.glassRegular
                    )
                    .foregroundColor(message.isUser ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: LiquidGlassTheme.CornerRadius.lg))
                
                // Timestamp
                Text(message.timestamp, style: .time)
                    .font(LiquidGlassTheme.Typography.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: 280, alignment: message.isUser ? .trailing : .leading)
            
            if !message.isUser {
                Spacer()
            }
        }
    }
}

// MARK: - Typing Indicator

struct TypingIndicator: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.secondary)
                        .frame(width: 6, height: 6)
                        .offset(y: isAnimating ? -4 : 0)
                        .animation(
                            .easeInOut(duration: 0.4)
                            .repeatForever()
                            .delay(Double(index) * 0.15),
                            value: isAnimating
                        )
                }
            }
            .padding(.horizontal, LiquidGlassTheme.Spacing.md)
            .padding(.vertical, LiquidGlassTheme.Spacing.md)
            .background(LiquidGlassTheme.Colors.glassRegular)
            .clipShape(RoundedRectangle(cornerRadius: LiquidGlassTheme.CornerRadius.lg))
            
            Spacer()
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Suggestion Chip

struct SuggestionChip: View {
    let text: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(text)
                .font(LiquidGlassTheme.Typography.caption)
                .padding(.horizontal, LiquidGlassTheme.Spacing.md)
                .padding(.vertical, LiquidGlassTheme.Spacing.xs)
                .background(LiquidGlassTheme.Colors.glassThin)
                .foregroundColor(.primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Chat Input Bar

struct ChatInputBar: View {
    @Binding var text: String
    let isLoading: Bool
    let onSend: () -> Void
    let onImagePick: () -> Void
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: LiquidGlassTheme.Spacing.sm) {
            // Image button
            Button(action: onImagePick) {
                Image(systemName: "photo")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            
            // Text field
            TextField("Ask Ansel about exposure, development, printing...", text: $text)
                .font(LiquidGlassTheme.Typography.body)
                .padding(.horizontal, LiquidGlassTheme.Spacing.md)
                .padding(.vertical, LiquidGlassTheme.Spacing.sm)
                .background(LiquidGlassTheme.Colors.glassThin)
                .clipShape(RoundedRectangle(cornerRadius: LiquidGlassTheme.CornerRadius.md))
                .focused($isFocused)
                .submitLabel(.send)
                .onSubmit {
                    if !text.isEmpty && !isLoading {
                        onSend()
                    }
                }
            
            // Send button
            Button(action: onSend) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundColor(text.isEmpty ? .secondary : LiquidGlassTheme.Colors.primary)
            }
            .disabled(text.isEmpty || isLoading)
        }
    }
}

// MARK: - Image Picker

struct ImagePicker: UIViewControllerRepresentable {
    let onImageSelected: (UIImage) -> Void
    
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
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImageSelected(image)
            }
            picker.dismiss(animated: true)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - Chat Message Model

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let isUser: Bool
    let timestamp: Date
    let image: UIImage?
    let suggestions: [String]
    
    init(text: String, isUser: Bool, image: UIImage? = nil, suggestions: [String] = []) {
        self.text = text
        self.isUser = isUser
        self.timestamp = Date()
        self.image = image
        self.suggestions = suggestions
    }
}

// MARK: - View Model

@Observable
@MainActor
final class AnselChatViewModel {

    var messages: [ChatMessage] = []
    var enhancedMessages: [EnhancedChatMessage] = []
    var inputText = ""
    var isTyping = false
    var showImagePicker = false
    var suggestions: [String] = []
    var showAnalysisResult = false
    var analysisResult: ZoneSystemAnalysisResult?
    var analysisImage: UIImage?

    // MARK: - New Toolbar Features
    var showImageEditor = false
    var pendingAdjustments: [ImageAdjustmentRecommendation] = []

    // Direct computed properties for @Observable
    var canApplySuggestions: Bool {
        !pendingAdjustments.isEmpty
    }

    var hasAnalysisImage: Bool {
        analysisImage != nil
    }

    // MARK: - Navigation
    @ObservationIgnored
    weak var navigationManager: ChatNavigationManager?

    @ObservationIgnored
    @Inject(\.aiCritique) private var aiCritique
    private let visionAnalyzer = VisionImageAnalyzer.shared

    init() {
        // Add welcome message with action suggestions
        enhancedMessages.append(EnhancedChatMessage(
            text: "Welcome! I'm PAI (Photography AI), your expert photography assistant. I can help you master the Zone System and guide you through using all features of this app. Ask me anything about exposure, development, printing, or how to use any feature!\n\nI can show you step-by-step how to use the Zone Meter, Darkroom Timer, Film Archive, and Photo Editor.",
            isUser: false,
            suggestions: [
                "What is the Zone System?",
                "How do I use the exposure meter?",
                "Development times for HP5"
            ],
            actionSuggestions: [
                PersonaSuggestion(
                    title: "Open Exposure Meter",
                    description: "Measure light and place zones",
                    actionType: .openMeter
                ),
                PersonaSuggestion(
                    title: "Show Me How It Works",
                    description: "Get step-by-step guidance",
                    actionType: .showGuidance
                )
            ]
        ))
    }
            ]
        ))
    }
    
    func sendMessage(_ text: String? = nil) {
        let messageText = text ?? inputText
        guard !messageText.isEmpty else { return }

        // Add user message
        messages.append(ChatMessage(text: messageText, isUser: true))
        enhancedMessages.append(EnhancedChatMessage(text: messageText, isUser: true))
        inputText = ""
        suggestions = []

        // Generate response
        isTyping = true

        Task {
            do {
                let context = ChatContext(
                    currentImage: nil,
                    currentZoneMap: nil,
                    recentExposures: [],
                    userLevel: .intermediate
                )

                let response = try await aiCritique.chatWithAnsel(message: messageText, context: context)

                await MainActor.run {
                    messages.append(ChatMessage(
                        text: response.message,
                        isUser: false,
                        suggestions: response.suggestions
                    ))

                    // Create enhanced message with action suggestions
                    let actionSuggestions = generateActionSuggestions(from: response)
                    enhancedMessages.append(EnhancedChatMessage(
                        text: response.message,
                        isUser: false,
                        suggestions: response.suggestions,
                        actionSuggestions: actionSuggestions
                    ))

                    suggestions = response.suggestions
                    isTyping = false
                }
            } catch {
                await MainActor.run {
                    messages.append(ChatMessage(
                        text: "I apologize, but I'm having trouble processing your question. Please try again.",
                        isUser: false
                    ))
                    enhancedMessages.append(EnhancedChatMessage(
                        text: "I apologize, but I'm having trouble processing your question. Please try again.",
                        isUser: false
                    ))
                    isTyping = false
                }
            }
        }
    }

    private func generateActionSuggestions(from response: AnselResponse) -> [PersonaSuggestion] {
        var suggestions: [PersonaSuggestion] = []

        // Analyze the response to determine relevant actions
        let lowerMessage = response.message.lowercased()

        // Check if response mentions specific features
        if lowerMessage.contains("meter") || lowerMessage.contains("exposure") || lowerMessage.contains("zone") {
            suggestions.append(PersonaSuggestion(
                title: "Open Exposure Meter",
                description: "Measure light and place zones",
                actionType: .openMeter
            ))
        }

        if lowerMessage.contains("development") || lowerMessage.contains("develop") || lowerMessage.contains("timer") {
            suggestions.append(PersonaSuggestion(
                title: "Open Darkroom Timer",
                description: "Start development timer",
                actionType: .openTimer
            ))
        }

        if lowerMessage.contains("archive") || lowerMessage.contains("roll") || lowerMessage.contains("film log") {
            suggestions.append(PersonaSuggestion(
                title: "Open Film Archive",
                description: "Log your exposures",
                actionType: .openArchive
            ))
        }

        if lowerMessage.contains("edit") || lowerMessage.contains("dodge") || lowerMessage.contains("burn") {
            suggestions.append(PersonaSuggestion(
                title: "Open Photo Editor",
                description: "Edit with zone tools",
                actionType: .openEditor
            ))
        }

        // Always add guidance option
        if !suggestions.isEmpty {
            suggestions.append(PersonaSuggestion(
                title: "Show Step-by-Step Guide",
                description: "Get guided instructions",
                actionType: .showGuidance
            ))
        }

        return suggestions
    }
    
    func analyzeImage(_ image: UIImage) {
        messages.append(ChatMessage(text: "Analyzing this image...", isUser: true, image: image))
        enhancedMessages.append(EnhancedChatMessage(text: "Analyzing this image...", isUser: true, image: image))
        isTyping = true

        Task {
            do {
                // Use real Vision framework analysis
                let result = try await visionAnalyzer.analyzeImage(image)

                await MainActor.run {
                    self.analysisResult = result
                    self.analysisImage = image
                    self.showAnalysisResult = true
                    self.pendingAdjustments = result.recommendations
                    // @Observable will automatically notify the view of changes

                    // Generate response text based on analysis
                    let responseText = generateAnalysisResponse(result: result)

                    messages.append(ChatMessage(
                        text: responseText,
                        isUser: false,
                        suggestions: result.recommendations.map { $0.title }
                    ))

                    enhancedMessages.append(EnhancedChatMessage(
                        text: responseText,
                        isUser: false,
                        suggestions: result.recommendations.map { $0.title },
                        actionSuggestions: result.recommendations.map { rec in
                            PersonaSuggestion(
                                title: rec.title,
                                description: rec.description,
                                actionType: .showGuidance
                            )
                        }
                    ))

                    suggestions = result.recommendations.map { $0.title }
                    isTyping = false
                }
            } catch {
                await MainActor.run {
                    messages.append(ChatMessage(
                        text: "I apologize, but I had trouble analyzing that image. Please try again with a different photo.",
                        isUser: false
                    ))
                    enhancedMessages.append(EnhancedChatMessage(
                        text: "I apologize, but I had trouble analyzing that image. Please try again with a different photo.",
                        isUser: false
                    ))
                    isTyping = false
                }
            }
        }
    }

    private func generateAnalysisResponse(result: ZoneSystemAnalysisResult) -> String {
        var response = ""

        // Overall assessment
        switch result.exposureAssessment {
        case .underexposed:
            response += "⚠️ This image appears **underexposed**. The shadows are deep and may lack detail in Zones 0-II. "
        case .overexposed:
            response += "⚠️ This image appears **overexposed**. The highlights may be blown out in Zones IX-X. "
        case .highContrast:
            response += "📊 This image has **high contrast** - strong difference between darkest and lightest areas. "
        case .lowContrast:
            response += "📊 This image has **low contrast** - may appear flat or muddy. "
        case .properlyExposed:
            response += "✅ This image is **properly exposed** with good tonal distribution. "
        }

        // Quality score
        response += "\n\n**Quality Score: \(result.qualityScore)/100**"

        // Tonal range
        if result.hasFullTonalRange {
            response += "\n\n✨ Excellent tonal range - the image utilizes nearly the full Zone System scale."
        } else {
            response += "\n\n📈 The tonal range could be expanded - consider adjusting development or exposure."
        }

        // Zone histogram insight
        let dominantZones = result.zoneHistogram.enumerated().filter { $0.element > 10 }.map { "\($0.offset)" }
        if !dominantZones.isEmpty {
            response += "\n\n**Dominant Zones**: \(dominantZones.joined(separator: ", "))"
        }

        // Recommendations summary
        if !result.recommendations.isEmpty {
            response += "\n\n**I have \(result.recommendations.count) recommendations** - tap the button below to see details."
        }

        return response
    }
    
    func clearChat() {
        messages.removeAll { !$0.isUser }
        enhancedMessages.removeAll { !$0.isUser }
        suggestions = []
        // Reset analysis state
        pendingAdjustments = []
        analysisResult = nil
        analysisImage = nil
    }

    // MARK: - Apply AI Suggestions

    func applyLastSuggestions() {
        guard let result = analysisResult else { return }
        pendingAdjustments = result.recommendations

        // Navigate to photo editor with adjustments
        // This will integrate with the existing photo editor
        navigationManager?.navigate(to: .photoEditor)

        // Store adjustments for the editor to apply
        // TODO: Pass adjustments to photo editor via NavigationManager

        // Add confirmation message
        enhancedMessages.append(EnhancedChatMessage(
            text: "I've prepared \(pendingAdjustments.count) AI-recommended adjustments for the photo editor.",
            isUser: false,
            actionSuggestions: [
                PersonaSuggestion(
                    title: "Open Photo Editor",
                    description: "Review and fine-tune adjustments",
                    actionType: .openEditor
                )
            ]
        ))
    }
}

// MARK: - Image Analysis Result Modal

struct ImageAnalysisResultModal: View {
    let result: ZoneSystemAnalysisResult
    let image: UIImage
    @Binding var isPresented: Bool
    var onApplyRecommendations: (() -> Void)? = nil

    @State private var selectedRecommendation: ImageAdjustmentRecommendation?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header with image thumbnail and score
                    HStack(spacing: 16) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(radius: 4)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Analysis Result")
                                .font(.title2.bold())

                            HStack(spacing: 8) {
                                Image(systemName: result.exposureAssessment.icon)
                                    .foregroundColor(Color(result.exposureAssessment.color))

                                Text(result.exposureAssessment.displayName)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }

                            // Quality Score
                            HStack(spacing: 8) {
                                Text("Quality:")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                Text("\(result.qualityScore)/100")
                                    .font(.headline)
                                    .foregroundColor(scoreColor(result.qualityScore))
                            }
                        }

                        Spacer()
                    }
                    .padding()
                    .background(LiquidGlassTheme.Colors.glassRegular)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    // Zone Histogram Visualization
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Zone Distribution")
                            .font(.headline)

                        HStack(alignment: .bottom, spacing: 2) {
                            ForEach(0..<11) { index in
                                VStack(spacing: 4) {
                                    Rectangle()
                                        .fill(zoneColor(for: index))
                                        .frame(height: CGFloat(result.zoneHistogram[index]) / 3)
                                        .frame(width: 24)
                                        .animation(.spring(), value: result.zoneHistogram[index])

                                    Text("\(index == 10 ? "X" : "\(index)")")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .frame(height: 100)
                        .padding()
                        .background(LiquidGlassTheme.Colors.glassThin)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Recommendations
                    if !result.recommendations.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Recommended Adjustments")
                                .font(.headline)

                            ForEach(result.recommendations) { rec in
                                RecommendationCard(recommendation: rec) {
                                    selectedRecommendation = rec
                                }
                            }
                        }
                    }

                    // Suggested Filters
                    if !result.suggestedFilters.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Suggested Filters")
                                .font(.headline)

                            ForEach(result.suggestedFilters) { filter in
                                FilterRecommendationCard(recommendation: filter)
                            }
                        }
                    }

                    // Composition Notes
                    if !result.compositionNotes.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Composition Notes")
                                .font(.headline)

                            ForEach(result.compositionNotes, id: \.self) { note in
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "lightbulb")
                                        .foregroundColor(.yellow)
                                        .font(.caption)

                                    Text(note)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }

                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle("Zone Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Apply All") {
                        onApplyRecommendations?()
                        isPresented = false
                    }
                    .buttonStyle(.borderedProminent)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                }
            }
        }
    }

    private func scoreColor(_ score: Int) -> Color {
        if score >= 80 { return .green }
        if score >= 60 { return .orange }
        return .red
    }

    private func zoneColor(for index: Int) -> Color {
        switch index {
        case 0: return Color(red: 0.05, green: 0.05, blue: 0.05)
        case 1: return Color(red: 0.1, green: 0.1, blue: 0.1)
        case 2: return Color(red: 0.15, green: 0.15, blue: 0.15)
        case 3: return Color(red: 0.2, green: 0.2, blue: 0.2)
        case 4: return Color(red: 0.3, green: 0.3, blue: 0.3)
        case 5: return Color(red: 0.4, green: 0.4, blue: 0.4)
        case 6: return Color(red: 0.5, green: 0.5, blue: 0.5)
        case 7: return Color(red: 0.6, green: 0.6, blue: 0.6)
        case 8: return Color(red: 0.7, green: 0.7, blue: 0.7)
        case 9: return Color(red: 0.85, green: 0.85, blue: 0.85)
        case 10: return Color(red: 0.95, green: 0.95, blue: 0.95)
        default: return .gray
        }
    }
}

// MARK: - Recommendation Card

struct RecommendationCard: View {
    let recommendation: ImageAdjustmentRecommendation
    let onTap: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Icon based on type
                Image(systemName: iconForType(recommendation.type))
                    .font(.title2)
                    .foregroundColor(colorForPriority(recommendation.priority))
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 4) {
                    Text(recommendation.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.primary)

                    Text(recommendation.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(recommendation.zoneImpact)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(LiquidGlassTheme.Colors.glassRegular)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func iconForType(_ type: ImageAdjustmentRecommendation.AdjustmentType) -> String {
        switch type {
        case .dodge: return "sun.max.fill"
        case .burn: return "sun.max"
        case .overallExposure: return "aperture"
        case .contrast: return "slider.horizontal.3"
        case .filter: return "circle.lefthalf.filled"
        }
    }

    private func colorForPriority(_ priority: ImageAdjustmentRecommendation.Priority) -> Color {
        switch priority {
        case .critical: return .red
        case .recommended: return .orange
        case .optional: return .blue
        }
    }
}

// MARK: - Filter Recommendation Card

struct FilterRecommendationCard: View {
    let recommendation: FilterRecommendation

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: filterIcon)
                .font(.title3)
                .foregroundColor(LiquidGlassTheme.Colors.primary)

            VStack(alignment: .leading, spacing: 4) {
                Text(filterName)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)

                Text(recommendation.reason)
                    .font(.caption)
                    .foregroundColor(.secondary)

                if recommendation.exposureCompensation > 0 {
                    Text("+\(recommendation.exposureCompensation) stop compensation required")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }

            Spacer()
        }
        .padding()
        .background(LiquidGlassTheme.Colors.glassRegular)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var filterIcon: String {
        switch recommendation.filterType {
        case .yellow: return "circle.fill"
        case .orange: return "circle.fill"
        case .red: return "circle.fill"
        case .polarizer: return "polaroid"
        case .green: return "leaf.fill"
        case .none: return "circle"
        }
    }

    private var filterName: String {
        switch recommendation.filterType {
        case .yellow: return "Yellow Filter"
        case .orange: return "Orange Filter"
        case .red: return "Red Filter"
        case .polarizer: return "Polarizer"
        case .green: return "Green Filter"
        case .none: return "None"
        }
    }
}

// MARK: - Quick Image Editor Sheet
/// Simple image editor sheet for quick adjustments based on AI analysis

struct QuickImageEditorSheet: View {
    let image: UIImage
    let analysisResult: ZoneSystemAnalysisResult
    @Binding var pendingAdjustments: [ImageAdjustmentRecommendation]
    @Binding var isPresented: Bool

    @State private var exposure: Double = 0
    @State private var contrast: Double = 0
    @State private var selectedAdjustments: Set<ImageAdjustmentRecommendation.ID> = []

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Image preview
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(radius: 10)

                // Adjustment summary
                VStack(alignment: .leading, spacing: 12) {
                    Text("AI Recommendations")
                        .font(.headline)

                    if pendingAdjustments.isEmpty {
                        Text("No pending adjustments")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(pendingAdjustments) { adjustment in
                            HStack {
                                Image(systemName: iconForType(adjustment.type))
                                    .foregroundColor(colorForPriority(adjustment.priority))

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(adjustment.title)
                                        .font(.subheadline)
                                    Text(adjustment.zoneImpact)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Button {
                                    selectedAdjustments.insert(adjustment.id)
                                } label: {
                                    Image(systemName: selectedAdjustments.contains(adjustment.id) ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(selectedAdjustments.contains(adjustment.id) ? .green : .secondary)
                                }
                            }
                            .padding()
                            .background(LiquidGlassTheme.Colors.glassThin)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .padding()

                // Quick adjustment sliders
                VStack(alignment: .leading, spacing: 16) {
                    Text("Quick Adjustments")
                        .font(.headline)

                    HStack {
                        Text("Exposure")
                            .frame(width: 80, alignment: .leading)
                        Slider(value: $exposure, in: -2...2)
                            .tint(LiquidGlassTheme.Colors.primary)
                        Text("\(exposure, specifier: "%.1f")")
                            .frame(width: 40)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Contrast")
                            .frame(width: 80, alignment: .leading)
                        Slider(value: $contrast, in: -1...1)
                            .tint(LiquidGlassTheme.Colors.primary)
                        Text("\(contrast, specifier: "%.1f")")
                            .frame(width: 40)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()

                Spacer()
            }
            .padding()
            .navigationTitle("Quick Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Apply") {
                        // Apply selected adjustments and navigate to full editor
                        isPresented = false
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    private func iconForType(_ type: ImageAdjustmentRecommendation.AdjustmentType) -> String {
        switch type {
        case .dodge: return "sun.max.fill"
        case .burn: return "sun.max"
        case .overallExposure: return "aperture"
        case .contrast: return "slider.horizontal.3"
        case .filter: return "circle.lefthalf.filled"
        }
    }

    private func colorForPriority(_ priority: ImageAdjustmentRecommendation.Priority) -> Color {
        switch priority {
        case .critical: return .red
        case .recommended: return .orange
        case .optional: return .blue
        }
    }
}

// MARK: - Preview

#Preview {
    AnselChatView()
        .environment(DependencyContainer.preview())
}
