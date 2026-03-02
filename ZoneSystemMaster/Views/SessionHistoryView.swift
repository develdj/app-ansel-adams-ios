import SwiftUI
import SwiftData
import Charts

// MARK: - Session History View

/// View for displaying development session history and statistics
struct SessionHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    
    @State private var sessions: [DevelopmentSession] = []
    @State private var selectedTimeRange: TimeRange = .month
    @State private var showStatistics = false
    
    enum TimeRange: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case year = "Year"
        case all = "All Time"
    }
    
    var body: some View {
        NavigationView {
            List {
                // Statistics Section
                statisticsSection
                
                // Time Range Selector
                timeRangeSection
                
                // Sessions List
                sessionsListSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showStatistics = true
                    }) {
                        Image(systemName: "chart.bar")
                    }
                }
            }
            .sheet(isPresented: $showStatistics) {
                StatisticsDetailView(sessions: sessions)
            }
            .onAppear {
                loadSessions()
            }
        }
    }
    
    // MARK: - Statistics Section
    
    private var statisticsSection: some View {
        Section {
            VStack(spacing: 16) {
                // Total sessions
                HStack(spacing: 20) {
                    StatCard(
                        value: "\(sessions.count)",
                        label: "Total Sessions",
                        icon: "film",
                        color: .blue
                    )
                    
                    let successfulSessions = sessions.filter { $0.wasSuccessful == true }.count
                    StatCard(
                        value: "\(successfulSessions)",
                        label: "Successful",
                        icon: "checkmark.circle",
                        color: .green
                    )
                }
                
                // This month
                let thisMonthSessions = sessions.filter {
                    Calendar.current.isDate($0.startedAt, equalTo: Date(), toGranularity: .month)
                }
                
                HStack(spacing: 20) {
                    StatCard(
                        value: "\(thisMonthSessions.count)",
                        label: "This Month",
                        icon: "calendar",
                        color: .orange
                    )
                    
                    let totalTime = sessions.reduce(0) { $0 + ($1.completedAt?.timeIntervalSince($1.startedAt) ?? 0) }
                    let hours = Int(totalTime) / 3600
                    StatCard(
                        value: "\(hours)",
                        label: "Total Hours",
                        icon: "clock",
                        color: .purple
                    )
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Time Range Section
    
    private var timeRangeSection: some View {
        Section {
            Picker("Time Range", selection: $selectedTimeRange) {
                ForEach(TimeRange.allCases, id: \.self) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: selectedTimeRange) { _, _ in
                loadSessions()
            }
        }
    }
    
    // MARK: - Sessions List Section
    
    private var sessionsListSection: some View {
        Section("Sessions") {
            if filteredSessions.isEmpty {
                Text("No sessions in this period")
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                ForEach(filteredSessions) { session in
                    SessionRow(session: session)
                }
            }
        }
    }
    
    private var filteredSessions: [DevelopmentSession] {
        let calendar = Calendar.current
        let now = Date()
        
        return sessions.filter { session in
            switch selectedTimeRange {
            case .week:
                return calendar.isDate(session.startedAt, equalTo: now, toGranularity: .weekOfYear)
            case .month:
                return calendar.isDate(session.startedAt, equalTo: now, toGranularity: .month)
            case .year:
                return calendar.isDate(session.startedAt, equalTo: now, toGranularity: .year)
            case .all:
                return true
            }
        }
    }
    
    // MARK: - Data Loading
    
    private func loadSessions() {
        let descriptor = FetchDescriptor<DevelopmentSession>(
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        sessions = (try? modelContext.fetch(descriptor)) ?? []
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title)
                    .fontWeight(.bold)
                
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Session Row

struct SessionRow: View {
    let session: DevelopmentSession
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Status indicator
                Circle()
                    .fill(statusColor)
                    .frame(width: 12, height: 12)
                
                Text(session.filmName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text(formattedDate(session.startedAt))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 12) {
                Label(session.developerName, systemImage: "drop")
                    .font(.caption)
                
                if let temp = session.temperatureActual {
                    Label(String(format: "%.1f°C", temp), systemImage: "thermometer")
                        .font(.caption)
                }
                
                Spacer()
                
                if let duration = sessionDuration {
                    Text(duration)
                        .font(.caption)
                        .monospacedDigit()
                }
            }
            .foregroundColor(.secondary)
            
            if let notes = session.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var statusColor: Color {
        guard let completed = session.wasSuccessful else { return .gray }
        return completed ? .green : .red
    }
    
    private var sessionDuration: String? {
        guard let completedAt = session.completedAt else { return nil }
        let duration = completedAt.timeIntervalSince(session.startedAt)
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return "\(minutes)m \(seconds)s"
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Statistics Detail View

struct StatisticsDetailView: View {
    let sessions: [DevelopmentSession]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                // Film usage chart
                filmUsageSection
                
                // Developer usage
                developerUsageSection
                
                // Success rate
                successRateSection
                
                // Monthly activity
                monthlyActivitySection
            }
            .navigationTitle("Statistics")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var filmUsageSection: some View {
        Section("Film Usage") {
            let filmCounts = Dictionary(grouping: sessions) { $0.filmName }
                .mapValues { $0.count }
                .sorted { $0.value > $1.value }
            
            if #available(iOS 16.0, *) {
                Chart(filmCounts, id: \.key) { film, count in
                    BarMark(
                        x: .value("Count", count),
                        y: .value("Film", film)
                    )
                    .foregroundStyle(by: .value("Film", film))
                }
                .frame(height: CGFloat(filmCounts.count * 40))
            } else {
                // Fallback for iOS 15
                ForEach(filmCounts, id: \.key) { film, count in
                    HStack {
                        Text(film)
                        Spacer()
                        Text("\(count)")
                            .fontWeight(.semibold)
                    }
                }
            }
        }
    }
    
    private var developerUsageSection: some View {
        Section("Developer Usage") {
            let devCounts = Dictionary(grouping: sessions) { $0.developerName }
                .mapValues { $0.count }
                .sorted { $0.value > $1.value }
            
            ForEach(devCounts, id: \.key) { dev, count in
                HStack {
                    Text(dev)
                    Spacer()
                    Text("\(count)")
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var successRateSection: some View {
        Section("Success Rate") {
            let completedSessions = sessions.filter { $0.wasSuccessful != nil }
            let successfulSessions = completedSessions.filter { $0.wasSuccessful == true }
            
            let successRate = completedSessions.isEmpty ? 0 :
                Double(successfulSessions.count) / Double(completedSessions.count) * 100
            
            VStack(spacing: 12) {
                HStack {
                    Text("Success Rate")
                    Spacer()
                    Text(String(format: "%.1f%%", successRate))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(successRate >= 80 ? .green : successRate >= 50 ? .orange : .red)
                }
                
                ProgressView(value: successRate, total: 100)
                    .tint(successRate >= 80 ? .green : successRate >= 50 ? .orange : .red)
                    .scaleEffect(y: 8)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                
                HStack {
                    Text("\(successfulSessions.count) successful")
                        .font(.caption)
                        .foregroundColor(.green)
                    Spacer()
                    let failed = completedSessions.count - successfulSessions.count
                    Text("\(failed) failed")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
    }
    
    private var monthlyActivitySection: some View {
        Section("Monthly Activity") {
            let calendar = Calendar.current
            let monthlyCounts = Dictionary(grouping: sessions) { session -> String in
                let components = calendar.dateComponents([.year, .month], from: session.startedAt)
                return "\(components.year ?? 0)-\(components.month ?? 0)"
            }
            .mapValues { $0.count }
            .sorted { $0.key > $1.key }
            .prefix(6)
            
            ForEach(Array(monthlyCounts), id: \.key) { month, count in
                HStack {
                    Text(formatMonth(month))
                    Spacer()
                    Text("\(count) sessions")
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private func formatMonth(_ monthString: String) -> String {
        let components = monthString.split(separator: "-")
        guard components.count == 2,
              let year = Int(components[0]),
              let month = Int(components[1]) else { return monthString }
        
        let dateComponents = DateComponents(year: year, month: month)
        let date = Calendar.current.date(from: dateComponents) ?? Date()
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview {
    SessionHistoryView()
}
