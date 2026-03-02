// MARK: - Chatbot Views
// Interfaccia chat per Ansel Adams Chatbot
// Swift 6.0

import SwiftUI

// MARK: - Chat View

public struct AdamsChatView: View {
    @StateObject private var viewModel: ChatViewModel
    @State private var messageText: String = ""
    @FocusState private var isInputFocused: Bool
    
    public init(analysis: ImageAnalysisResult? = nil) {
        _viewModel = StateObject(wrappedValue: ChatViewModel(analysis: analysis))
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            ChatHeaderView()
            
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.messages.count) { _ in
                    if let lastMessage = viewModel.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Input area
            ChatInputView(
                text: $messageText,
                isFocused: _isInputFocused,
                onSend: sendMessage,
                isLoading: viewModel.isLoading
            )
        }
        .background(Color(.systemGroupedBackground))
    }
    
    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        let message = messageText
        messageText = ""
        isInputFocused = false
        
        Task {
            await viewModel.sendMessage(message)
        }
    }
}

// MARK: - Chat View Model

@MainActor
public class ChatViewModel: ObservableObject {
    @Published public var messages: [ChatMessage] = []
    @Published public var isLoading: Bool = false
    
    private let chatbot: AdamsChatbot
    private var currentAnalysis: ImageAnalysisResult?
    
    public init(analysis: ImageAnalysisResult? = nil) {
        self.chatbot = AdamsChatbot()
        self.currentAnalysis = analysis
        
        // Messaggio di benvenuto
        Task {
            await loadWelcomeMessage()
        }
    }
    
    private func loadWelcomeMessage() async {
        isLoading = true
        
        do {
            let welcomeMessage: String
            if let analysis = currentAnalysis {
                let suggestion = await chatbot.getAutomaticSuggestion(for: analysis)
                welcomeMessage = suggestion.content
            } else {
                let response = try await chatbot.sendMessage("ciao")
                welcomeMessage = response.content
            }
            
            let message = ChatMessage(role: .assistant, content: welcomeMessage, relatedAnalysis: currentAnalysis)
            messages.append(message)
        } catch {
            let errorMessage = ChatMessage(
                role: .assistant,
                content: "Salve! Sono Ansel Adams. Come posso aiutarti con la fotografia oggi?"
            )
            messages.append(errorMessage)
        }
        
        isLoading = false
    }
    
    public func sendMessage(_ text: String) async {
        isLoading = true
        
        do {
            let response: ChatMessage
            if let analysis = currentAnalysis {
                response = try await chatbot.sendMessage(text, withAnalysis: analysis)
            } else {
                response = try await chatbot.sendMessage(text)
            }
            
            messages.append(response)
        } catch {
            let errorMessage = ChatMessage(
                role: .assistant,
                content: "Mi scuso, ho avuto un problema nel processare la tua richiesta. Puoi riprovare?"
            )
            messages.append(errorMessage)
        }
        
        isLoading = false
    }
    
    public func resetConversation() {
        chatbot.resetConversation()
        messages.removeAll()
        
        Task {
            await loadWelcomeMessage()
        }
    }
    
    public func setAnalysis(_ analysis: ImageAnalysisResult) {
        self.currentAnalysis = analysis
    }
}

// MARK: - Chat Header

struct ChatHeaderView: View {
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.gray, .black],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                
                Image(systemName: "camera.aperture")
                    .font(.title2)
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Ansel Adams")
                    .font(.headline)
                
                Text("Maestro del Zone System")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Status indicator
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                Text("Online")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(.gray.opacity(0.3)),
            alignment: .bottom
        )
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.role == .user {
                Spacer()
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                // Content
                Text(message.content)
                    .font(.body)
                    .padding(12)
                    .background(message.role == .user ? Color.accentColor : Color(.systemBackground))
                    .foregroundColor(message.role == .user ? .white : .primary)
                    .cornerRadius(16)
                    .cornerRadius(message.role == .user ? 4 : 16, corners: .bottomRight)
                    .cornerRadius(message.role == .user ? 16 : 4, corners: .bottomLeft)
                
                // Timestamp
                Text(formatTime(message.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
            }
            .frame(maxWidth: 280, alignment: message.role == .user ? .trailing : .leading)
            
            if message.role == .assistant {
                Spacer()
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Chat Input

struct ChatInputView: View {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    let onSend: () -> Void
    let isLoading: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Text field
            HStack {
                TextField("Chiedi ad Ansel...", text: $text, axis: .vertical)
                    .focused(isFocused)
                    .lineLimit(1...4)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }
            .background(Color(.systemBackground))
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
            
            // Send button
            Button(action: onSend) {
                ZStack {
                    Circle()
                        .fill(text.isEmpty ? Color.gray.opacity(0.3) : Color.accentColor)
                        .frame(width: 44, height: 44)
                    
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
            }
            .disabled(text.isEmpty || isLoading)
        }
        .padding()
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(.gray.opacity(0.3)),
            alignment: .top
        )
    }
}

// MARK: - Quick Actions View

public struct QuickActionsView: View {
    let onAction: (String) -> Void
    
    private let actions = [
        ("Esposizione", "sun.max", "Come imposto l'esposizione?"),
        ("Sviluppo", "timer", "Che sviluppo usare?"),
        ("Filtri", "camera.filters", "Quale filtro?"),
        ("Stampa", "printer", "Consigli stampa?"),
        ("Zone", "ruler", "Spiegami le zone"),
        ("Critica", "eye", "Cosa ne pensi?")
    ]
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Domande Rapide")
                .font(.headline)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(actions, id: \.0) { action in
                        QuickActionButton(
                            title: action.0,
                            icon: action.1,
                            query: action.2,
                            onTap: onAction
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let query: String
    let onTap: (String) -> Void
    
    var body: some View {
        Button(action: { onTap(query) }) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline)
                Text(title)
                    .font(.subheadline)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.accentColor.opacity(0.1))
            .foregroundColor(.accentColor)
            .cornerRadius(20)
        }
    }
}

// MARK: - Suggested Topics View

public struct SuggestedTopicsView: View {
    let onTopicSelected: (String) -> Void
    
    private let topics = [
        "Zone System",
        "Esposizione",
        "Sviluppo N+, N-",
        "Filtri colorati",
        "Dodge & Burn",
        "Gamma dinamica",
        "Composizione",
        "Luce naturale"
    ]
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Argomenti")
                .font(.headline)
            
            FlowLayout(spacing: 8) {
                ForEach(topics, id: \.self) { topic in
                    TopicChip(title: topic, onTap: onTopicSelected)
                }
            }
        }
        .padding()
    }
}

struct TopicChip: View {
    let title: String
    let onTap: (String) -> Void
    
    var body: some View {
        Button(action: { onTap("Spiegami \(title.lowercased())") }) {
            Text(title)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.gray.opacity(0.15))
                .foregroundColor(.primary)
                .cornerRadius(16)
        }
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }
                
                positions.append(CGPoint(x: x, y: y))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
                
                self.size.width = max(self.size.width, x)
            }
            
            self.size.height = y + lineHeight
        }
    }
}

// MARK: - Corner Radius Extension

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Preview

#Preview {
    AdamsChatView()
}
