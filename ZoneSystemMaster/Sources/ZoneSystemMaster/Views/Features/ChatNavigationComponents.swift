import SwiftUI
import ZoneSystemCore
import ZoneSystemUI

// MARK: - Action Suggestion Button
// Tappable button that navigates to app features or shows guidance

struct ActionSuggestionButton: View {
    let suggestion: PersonaSuggestion
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: LiquidGlassTheme.Spacing.sm) {
                // Icon based on action type
                Image(systemName: iconName(for: suggestion.actionType))
                    .font(.title3)
                    .foregroundColor(LiquidGlassTheme.Colors.primary)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 4) {
                    Text(suggestion.title)
                        .font(LiquidGlassTheme.Typography.body.weight(.semibold))
                        .foregroundColor(.primary)

                    Text(suggestion.description)
                        .font(LiquidGlassTheme.Typography.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(LiquidGlassTheme.Colors.glassRegular)
            .clipShape(RoundedRectangle(cornerRadius: LiquidGlassTheme.CornerRadius.lg))
        }
        .buttonStyle(.plain)
    }

    private func iconName(for actionType: PersonaSuggestion.ActionType) -> String {
        switch actionType {
        case .openMeter:
            return "camera.metering.matrix"
        case .openTimer:
            return "timer"
        case .openArchive:
            return "folder.badge.plus"
        case .openEditor:
            return "photo.stack"
        case .showGuidance:
            return "lightbulb.fill"
        default:
            return "questionmark.circle"
        }
    }
}

// MARK: - Guidance Modal
// Translucent overlay with step-by-step instructions

struct GuidanceModal: View {
    let title: String
    let steps: [String]
    let isPresented: Binding<Bool>

    @State private var currentStep = 0

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isPresented.wrappedValue = false
                    }
                }

            // Translucent modal
            VStack(spacing: LiquidGlassTheme.Spacing.xl) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(LiquidGlassTheme.Typography.title3.weight(.bold))

                        Text("Step \(currentStep + 1) of \(steps.count)")
                            .font(LiquidGlassTheme.Typography.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isPresented.wrappedValue = false
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                }

                // Step indicator
                HStack(spacing: 8) {
                    ForEach(0..<steps.count, id: \.self) { index in
                        Circle()
                            .fill(index <= currentStep ? LiquidGlassTheme.Colors.primary : Color.gray.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }

                // Current step
                VStack(spacing: LiquidGlassTheme.Spacing.md) {
                    Image(systemName: stepIcon(for: currentStep))
                        .font(.system(size: 60))
                        .foregroundColor(LiquidGlassTheme.Colors.primary)

                    Text(steps[currentStep])
                        .font(LiquidGlassTheme.Typography.body)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Navigation buttons
                HStack(spacing: LiquidGlassTheme.Spacing.md) {
                    if currentStep > 0 {
                        Button {
                            withAnimation {
                                currentStep -= 1
                            }
                        } label: {
                            HStack {
                                Image(systemName: "chevron.left")
                                Text("Previous")
                            }
                            .font(LiquidGlassTheme.Typography.body.weight(.medium))
                            .foregroundColor(.primary)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(LiquidGlassTheme.Colors.glassThin)
                            .clipShape(RoundedRectangle(cornerRadius: LiquidGlassTheme.CornerRadius.md))
                        }
                    }

                    Button {
                        if currentStep < steps.count - 1 {
                            withAnimation {
                                currentStep += 1
                            }
                        } else {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isPresented.wrappedValue = false
                            }
                        }
                    } label: {
                        HStack {
                            Text(currentStep < steps.count - 1 ? "Next" : "Got it!")
                            if currentStep < steps.count - 1 {
                                Image(systemName: "chevron.right")
                            }
                        }
                        .font(LiquidGlassTheme.Typography.body.weight(.semibold))
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(LiquidGlassTheme.Colors.primary)
                        .clipShape(RoundedRectangle(cornerRadius: LiquidGlassTheme.CornerRadius.md))
                    }
                }
            }
            .padding(LiquidGlassTheme.Spacing.xl)
            .background(
                RoundedRectangle(cornerRadius: LiquidGlassTheme.CornerRadius.xl)
                    .fill(.ultraThinMaterial)
                    .shadow(radius: 20)
            )
            .padding(LiquidGlassTheme.Spacing.xl)
        }
    }

    private func stepIcon(for step: Int) -> String {
        let icons = [
            "magazine", // For opening/selecting
            "hand.tap", // For tapping/selecting
            "slider.horizontal.3", // For adjusting
            "checkmark.circle", // For confirmation
            "chevron.forward" // For navigation
        ]
        return icons[step % icons.count]
    }
}

// MARK: - Navigation Manager
// Handles navigation from chat to different app features

@Observable
@MainActor
final class ChatNavigationManager {
    static let shared = ChatNavigationManager()

    var selectedDestination: AppDestination?
    var showGuidanceModal = false
    var guidanceTitle = ""
    var guidanceSteps: [String] = []

    private init() {}

    func navigate(to destination: AppDestination) {
        selectedDestination = destination
    }

    func showGuidance(title: String, steps: [String]) {
        guidanceTitle = title
        guidanceSteps = steps
        showGuidanceModal = true
    }

    func dismissGuidance() {
        showGuidanceModal = false
        guidanceTitle = ""
        guidanceSteps = []
    }
}

// MARK: - App Destination Enum

enum AppDestination: Equatable {
    case exposureMeter
    case darkroomTimer
    case filmArchive
    case photoEditor
    case chat

    var tabItem: Int {
        switch self {
        case .chat: return 0
        case .exposureMeter: return 1
        case .darkroomTimer: return 2
        case .filmArchive: return 3
        case .photoEditor: return 4
        }
    }
}

// MARK: - Enhanced Chat Message with Actions

struct EnhancedChatMessage: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let isUser: Bool
    let timestamp: Date
    let image: UIImage?
    let suggestions: [String]
    let actionSuggestions: [PersonaSuggestion]

    init(
        text: String,
        isUser: Bool,
        image: UIImage? = nil,
        suggestions: [String] = [],
        actionSuggestions: [PersonaSuggestion] = []
    ) {
        self.text = text
        self.isUser = isUser
        self.timestamp = Date()
        self.image = image
        self.suggestions = suggestions
        self.actionSuggestions = actionSuggestions
    }

    static func == (lhs: EnhancedChatMessage, rhs: EnhancedChatMessage) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Enhanced Message Bubble with Actions

struct EnhancedChatMessageBubble: View {
    let message: EnhancedChatMessage
    let onActionTap: (PersonaSuggestion) -> Void
    @State private var isExpanded: Bool = true
    @State private var isAppeared = false

    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
            }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: LiquidGlassTheme.Spacing.sm) {
                // Message content
                if let image = message.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 200, maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: LiquidGlassTheme.CornerRadius.md))
                        .scaleEffect(isAppeared ? 1.0 : 0.9)
                        .opacity(isAppeared ? 1 : 0)
                }

                // Collapsible text section for AI messages
                if !message.isUser {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top) {
                            ZStack {
                                // Text content
                                Text(message.text)
                                    .font(LiquidGlassTheme.Typography.body)
                                    .lineLimit(isExpanded ? nil : 2)
                                    .lineSpacing(4)
                                    .opacity(isExpanded ? 1.0 : 0.7)
                                    .animation(.easeInOut(duration: 0.25), value: isExpanded)

                                // Liquid Glass fade overlay for truncated text
                                if !isExpanded {
                                    VStack {
                                        Spacer()
                                        LinearGradient(
                                            colors: [
                                                Color.clear,
                                                Color.clear.opacity(0.1),
                                                Color(UIColor.systemBackground).opacity(0.5)
                                            ],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                        .frame(height: 30)
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                    }
                                    .allowsHitTesting(false)
                                }
                            }

                            Spacer(minLength: 24)

                            Button {
                                withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                                    isExpanded.toggle()
                                }
                            } label: {
                                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                    .font(.caption.bold())
                                    .foregroundColor(.secondary)
                                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(LiquidGlassTheme.Spacing.md)
                        .background(
                            ZStack {
                                // Glass background with blur
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(.ultraThinMaterial)
                                    .opacity(0.7)

                                // Subtle border
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                Color.white.opacity(0.12),
                                                Color.white.opacity(0.04)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            }
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                } else {
                    // User messages stay full
                    Text(message.text)
                        .font(LiquidGlassTheme.Typography.body)
                        .padding(.horizontal, LiquidGlassTheme.Spacing.md)
                        .padding(.vertical, LiquidGlassTheme.Spacing.sm)
                        .background(LiquidGlassTheme.Colors.primary)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: LiquidGlassTheme.CornerRadius.lg))
                }

                // Action suggestions (only for AI messages when expanded)
                if !message.isUser && isExpanded && !message.actionSuggestions.isEmpty {
                    VStack(spacing: LiquidGlassTheme.Spacing.xs) {
                        ForEach(Array(message.actionSuggestions.enumerated()), id: \.element.id) { index, suggestion in
                            ActionSuggestionButton(suggestion: suggestion) {
                                onActionTap(suggestion)
                            }
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.9).combined(with: .opacity),
                                removal: .scale(scale: 0.95).combined(with: .opacity)
                            ))
                            .animation(.spring(response: 0.4, dampingFraction: 0.8).delay(Double(index) * 0.05), value: isExpanded)
                        }
                    }
                    .padding(.top, LiquidGlassTheme.Spacing.xs)
                }

                // Timestamp
                Text(message.timestamp, style: .time)
                    .font(LiquidGlassTheme.Typography.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: 320, alignment: message.isUser ? .trailing : .leading)
            .scaleEffect(isAppeared ? 1.0 : 0.95)
            .opacity(isAppeared ? 1 : 0)
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isAppeared)
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    isAppeared = true
                }
            }

            if !message.isUser {
                Spacer()
            }
        }
    }
}

// MARK: - Preview Helpers

#Preview("Action Buttons") {
    VStack(spacing: 20) {
        ActionSuggestionButton(
            suggestion: PersonaSuggestion(
                title: "Open Exposure Meter",
                description: "Measure light and place zones",
                actionType: .openMeter
            )
        ) {}

        ActionSuggestionButton(
            suggestion: PersonaSuggestion(
                title: "Show Step-by-Step Guide",
                description: "Get guided instructions",
                actionType: .showGuidance
            )
        ) {}
    }
    .padding()
}

#Preview("Guidance Modal") {
    GuidanceModal(
        title: "Using the Zone Meter",
        steps: [
            "Open Zone Meter from the tab bar",
            "Select the zone representing your target tone",
            "Tap the Measure button",
            "View your recommended exposure settings",
            "Adjust aperture or ISO if needed"
        ],
        isPresented: .constant(true)
    )
}
