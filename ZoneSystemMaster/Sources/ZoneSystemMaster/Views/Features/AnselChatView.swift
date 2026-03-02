import SwiftUI
import ZoneSystemCore
import ZoneSystemUI

// MARK: - Ansel Chat View

@MainActor
struct AnselChatView: View {
    
    @State private var viewModel = AnselChatViewModel()
    @Environment(DependencyContainer.self) private var container
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Chat messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: LiquidGlassTheme.Spacing.md) {
                            ForEach(viewModel.messages) { message in
                                ChatMessageBubble(message: message)
                                    .id(message.id)
                            }
                            
                            if viewModel.isTyping {
                                TypingIndicator()
                                    .id("typing")
                            }
                        }
                        .padding()
                    }
                    .onChange(of: viewModel.messages) { _, _ in
                        withAnimation {
                            proxy.scrollTo(viewModel.messages.last?.id, anchor: .bottom)
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
            .navigationTitle("Chat with Ansel")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.clearChat()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                    }
                }
            }
            .sheet(isPresented: $viewModel.showImagePicker) {
                ImagePicker { image in
                    viewModel.analyzeImage(image)
                }
            }
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
    var inputText = ""
    var isTyping = false
    var showImagePicker = false
    var suggestions: [String] = []
    
    @ObservationIgnored
    @Inject(\.aiCritique) private var aiCritique
    
    init() {
        // Add welcome message
        messages.append(ChatMessage(
            text: "Welcome! I'm here to help you master the Zone System. Ask me about exposure, development, printing, or anything related to black and white photography.",
            isUser: false,
            suggestions: [
                "What is the Zone System?",
                "How do I expose for Zone III?",
                "Development times for HP5"
            ]
        ))
    }
    
    func sendMessage(_ text: String? = nil) {
        let messageText = text ?? inputText
        guard !messageText.isEmpty else { return }
        
        // Add user message
        messages.append(ChatMessage(text: messageText, isUser: true))
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
                    suggestions = response.suggestions
                    isTyping = false
                }
            } catch {
                await MainActor.run {
                    messages.append(ChatMessage(
                        text: "I apologize, but I'm having trouble processing your question. Please try again.",
                        isUser: false
                    ))
                    isTyping = false
                }
            }
        }
    }
    
    func analyzeImage(_ image: UIImage) {
        messages.append(ChatMessage(text: "Analyzing this image...", isUser: true, image: image))
        isTyping = true
        
        Task {
            // Simulate analysis
            try? await Task.sleep(for: .seconds(2))
            
            await MainActor.run {
                messages.append(ChatMessage(
                    text: "This is a well-composed image with good tonal range. The shadows appear to be properly placed in Zone III, and highlights are well-controlled. Consider slightly more development to increase midtone contrast.",
                    isUser: false,
                    suggestions: [
                        "How to increase contrast?",
                        "Zone placement tips",
                        "Development recommendations"
                    ]
                ))
                suggestions = ["How to increase contrast?", "Zone placement tips", "Development recommendations"]
                isTyping = false
            }
        }
    }
    
    func clearChat() {
        messages.removeAll { !$0.isUser }
        suggestions = []
    }
}

// MARK: - Preview

#Preview {
    AnselChatView()
        .environment(DependencyContainer.preview())
}
