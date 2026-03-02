import Foundation
import SwiftData
import SwiftUI

// MARK: - Statistics Engine
/// Motore di statistiche e analisi dell'archivio analogico
@MainActor
final class StatisticsEngine: ObservableObject {
    
    // MARK: - Singleton
    static let shared = StatisticsEngine()
    
    // MARK: - Published Properties
    @Published var isLoading = false
    @Published var currentStats: ArchiveStatistics?
    @Published var monthlyStats: [MonthlyStatistics] = []
    @Published var filmUsageStats: [FilmUsageStat] = []
    @Published var cameraUsageStats: [CameraUsageStat] = []
    @Published var lensUsageStats: [LensUsageStat] = []
    @Published var locationStats: [LocationStat] = []
    @Published var timeDistribution: TimeDistributionStats?
    @Published var exposureDistribution: ExposureDistributionStats?
    
    private init() {}
    
    // MARK: - Main Statistics
    
    /// Calcola tutte le statistiche
    func calculateAllStatistics(context: ModelContext) async throws {
        isLoading = true
        defer { isLoading = false }
        
        async let archiveStats = calculateArchiveStatistics(context: context)
        async let filmStats = calculateFilmUsage(context: context)
        async let cameraStats = calculateCameraUsage(context: context)
        async let lensStats = calculateLensUsage(context: context)
        async let locationStats = calculateLocationStats(context: context)
        async let timeStats = calculateTimeDistribution(context: context)
        async let exposureStats = calculateExposureDistribution(context: context)
        
        currentStats = try await archiveStats
        filmUsageStats = try await filmStats
        cameraUsageStats = try await cameraStats
        lensUsageStats = try await lensStats
        locationStats = try await locationStats
        timeDistribution = try await timeStats
        exposureDistribution = try await exposureStats
    }
    
    /// Statistiche generali dell'archivio
    func calculateArchiveStatistics(context: ModelContext) async throws -> ArchiveStatistics {
        let rolls = try context.fetch(FetchDescriptor<Roll>())
        let exposures = try context.fetch(FetchDescriptor<Exposure>())
        let prints = try context.fetch(FetchDescriptor<Print>())
        
        return ArchiveStatistics(
            totalRolls: rolls.count,
            totalExposures: exposures.count,
            totalPrints: prints.count,
            rollsByStatus: Dictionary(grouping: rolls, by: { $0.status }).mapValues { $0.count },
            rollsByFilmManufacturer: Dictionary(grouping: rolls, by: { $0.filmManufacturer }).mapValues { $0.count },
            exposuresByRating: Dictionary(grouping: exposures, by: { $0.rating }).mapValues { $0.count },
            exposuresByLightCondition: Dictionary(grouping: exposures, by: { $0.lightCondition }).mapValues { $0.count },
            keepersCount: exposures.filter { $0.keepers }.count,
            averageExposuresPerRoll: rolls.isEmpty ? 0 : Double(exposures.count) / Double(rolls.count)
        )
    }
    
    // MARK: - Film Usage Statistics
    
    func calculateFilmUsage(context: ModelContext) async throws -> [FilmUsageStat] {
        let rolls = try context.fetch(FetchDescriptor<Roll>())
        
        let grouped = Dictionary(grouping: rolls) { roll in
            "\(roll.filmManufacturer.rawValue) \(roll.filmName)"
        }
        
        return grouped.map { (key, rolls) in
            let exposures = rolls.flatMap { $0.exposures ?? [] }
            let keepers = exposures.filter { $0.keepers }.count
            
            return FilmUsageStat(
                filmName: key,
                manufacturer: rolls.first?.filmManufacturer ?? .other,
                iso: rolls.first?.nominalISO ?? 0,
                rollCount: rolls.count,
                exposureCount: exposures.count,
                keeperCount: keepers,
                keeperRate: exposures.isEmpty ? 0 : Double(keepers) / Double(exposures.count) * 100,
                lastUsed: rolls.map { $0.dateLoaded }.max() ?? Date()
            )
        }.sorted { $0.exposureCount > $1.exposureCount }
    }
    
    // MARK: - Camera Usage Statistics
    
    func calculateCameraUsage(context: ModelContext) async throws -> [CameraUsageStat] {
        let exposures = try context.fetch(FetchDescriptor<Exposure>())
        
        let grouped = Dictionary(grouping: exposures) {
            "\($0.cameraBrand) \($0.cameraModel)"
        }
        
        return grouped.map { (key, exposures) in
            let keepers = exposures.filter { $0.keepers }.count
            let firstExposure = exposures.map { $0.dateTaken }.min() ?? Date()
            let lastExposure = exposures.map { $0.dateTaken }.max() ?? Date()
            
            return CameraUsageStat(
                cameraName: key.isEmpty ? "Non specificata" : key,
                exposureCount: exposures.count,
                keeperCount: keepers,
                keeperRate: Double(keepers) / Double(exposures.count) * 100,
                rollCount: Set(exposures.compactMap { $0.roll?.id }).count,
                firstUsed: firstExposure,
                lastUsed: lastExposure
            )
        }.sorted { $0.exposureCount > $1.exposureCount }
    }
    
    // MARK: - Lens Usage Statistics
    
    func calculateLensUsage(context: ModelContext) async throws -> [LensUsageStat] {
        let exposures = try context.fetch(FetchDescriptor<Exposure>())
        
        let grouped = Dictionary(grouping: exposures) {
            "\($0.lensBrand) \($0.lensModel)"
        }
        
        return grouped.map { (key, exposures) in
            let keepers = exposures.filter { $0.keepers }.count
            let focalLengths = exposures.map { $0.focalLength }
            let avgFocalLength = focalLengths.isEmpty ? 0 : Double(focalLengths.reduce(0, +)) / Double(focalLengths.count)
            
            return LensUsageStat(
                lensName: key.isEmpty ? "Non specificato" : key,
                exposureCount: exposures.count,
                keeperCount: keepers,
                keeperRate: Double(keepers) / Double(exposures.count) * 100,
                averageFocalLength: avgFocalLength,
                mostUsedFocalLength: focalLengths.mostCommon() ?? 0
            )
        }.sorted { $0.exposureCount > $1.exposureCount }
    }
    
    // MARK: - Location Statistics
    
    func calculateLocationStats(context: ModelContext) async throws -> [LocationStat] {
        let exposures = try context.fetch(FetchDescriptor<Exposure>())
        let exposuresWithLocation = exposures.filter { $0.locationName != nil }
        
        let grouped = Dictionary(grouping: exposuresWithLocation) { $0.locationName! }
        
        return grouped.map { (location, exposures) in
            let keepers = exposures.filter { $0.keepers }.count
            let firstVisit = exposures.map { $0.dateTaken }.min() ?? Date()
            let lastVisit = exposures.map { $0.dateTaken }.max() ?? Date()
            
            return LocationStat(
                name: location,
                exposureCount: exposures.count,
                keeperCount: keepers,
                keeperRate: Double(keepers) / Double(exposures.count) * 100,
                firstVisit: firstVisit,
                lastVisit: lastVisit,
                hasGPS: exposures.contains { $0.hasGPS },
                latitude: exposures.first { $0.hasGPS }?.latitude,
                longitude: exposures.first { $0.hasGPS }?.longitude
            )
        }.sorted { $0.exposureCount > $1.exposureCount }
    }
    
    // MARK: - Time Distribution Statistics
    
    func calculateTimeDistribution(context: ModelContext) async throws -> TimeDistributionStats {
        let exposures = try context.fetch(FetchDescriptor<Exposure>())
        let calendar = Calendar.current
        
        // Per ora del giorno
        var hourlyDistribution = Array(repeating: 0, count: 24)
        for exposure in exposures {
            let hour = calendar.component(.hour, from: exposure.dateTaken)
            hourlyDistribution[hour] += 1
        }
        
        // Per giorno della settimana
        var weekdayDistribution = Array(repeating: 0, count: 7)
        for exposure in exposures {
            let weekday = calendar.component(.weekday, from: exposure.dateTaken) - 1
            weekdayDistribution[weekday] += 1
        }
        
        // Per mese
        var monthlyDistribution = Array(repeating: 0, count: 12)
        for exposure in exposures {
            let month = calendar.component(.month, from: exposure.dateTaken) - 1
            monthlyDistribution[month] += 1
        }
        
        // Per anno
        let yearlyDistribution = Dictionary(grouping: exposures) {
            calendar.component(.year, from: $0.dateTaken)
        }.mapValues { $0.count }
        
        return TimeDistributionStats(
            hourlyDistribution: hourlyDistribution,
            weekdayDistribution: weekdayDistribution,
            monthlyDistribution: monthlyDistribution,
            yearlyDistribution: yearlyDistribution.sorted { $0.key > $1.key }
        )
    }
    
    // MARK: - Exposure Distribution Statistics
    
    func calculateExposureDistribution(context: ModelContext) async throws -> ExposureDistributionStats {
        let exposures = try context.fetch(FetchDescriptor<Exposure>())
        
        // Distribuzione ISO
        let isoDistribution = Dictionary(grouping: exposures) { $0.isoUsed }.mapValues { $0.count }
        
        // Distribuzione aperture
        let apertureRanges = [
            ("f/1.0 - f/2.0", 1.0...2.0),
            ("f/2.0 - f/2.8", 2.0...2.8),
            ("f/2.8 - f/4.0", 2.8...4.0),
            ("f/4.0 - f/5.6", 4.0...5.6),
            ("f/5.6 - f/8.0", 5.6...8.0),
            ("f/8.0 - f/11", 8.0...11.0),
            ("f/11 - f/16", 11.0...16.0),
            ("f/16 - f/22", 16.0...22.0),
            ("f/22+", 22.0...64.0)
        ]
        
        var apertureDistribution: [(String, Int)] = []
        for (label, range) in apertureRanges {
            let count = exposures.filter { range.contains($0.aperture.fStop) }.count
            apertureDistribution.append((label, count))
        }
        
        // Distribuzione tempi
        let shutterRanges = [
            ("< 1/1000", 0...0.001),
            ("1/500 - 1/1000", 0.001...0.002),
            ("1/250 - 1/500", 0.002...0.004),
            ("1/125 - 1/250", 0.004...0.008),
            ("1/60 - 1/125", 0.008...0.016),
            ("1/30 - 1/60", 0.016...0.033),
            ("1/15 - 1/30", 0.033...0.066),
            ("1/8 - 1/15", 0.066...0.125),
            ("1/4 - 1/8", 0.125...0.25),
            ("1/2 - 1/4", 0.25...0.5),
            ("1-2 sec", 0.5...2.0),
            ("> 2 sec", 2.0...1000.0)
        ]
        
        var shutterDistribution: [(String, Int)] = []
        for (label, range) in shutterRanges {
            let count = exposures.filter { range.contains($0.shutterSpeed.seconds) }.count
            shutterDistribution.append((label, count))
        }
        
        // Distribuzione focali
        let focalRanges = [
            ("< 24mm (Grandangolo)", 0..<24),
            ("24-35mm", 24..<35),
            ("35-50mm", 35..<50),
            ("50-85mm", 50..<85),
            ("85-135mm", 85..<135),
            ("135-200mm", 135..<200),
            ("> 200mm (Tele)", 200..<1000)
        ]
        
        var focalDistribution: [(String, Int)] = []
        for (label, range) in focalRanges {
            let count = exposures.filter { range.contains($0.focalLength) }.count
            focalDistribution.append((label, count))
        }
        
        return ExposureDistributionStats(
            isoDistribution: isoDistribution.sorted { $0.key < $1.key },
            apertureDistribution: apertureDistribution,
            shutterDistribution: shutterDistribution,
            focalLengthDistribution: focalDistribution
        )
    }
    
    // MARK: - Monthly Statistics
    
    func calculateMonthlyStatistics(year: Int, context: ModelContext) async throws -> [MonthlyStatistics] {
        let exposures = try context.fetch(FetchDescriptor<Exposure>())
        let rolls = try context.fetch(FetchDescriptor<Roll>())
        let calendar = Calendar.current
        
        var monthlyStats: [MonthlyStatistics] = []
        
        for month in 1...12 {
            let monthExposures = exposures.filter {
                calendar.component(.year, from: $0.dateTaken) == year &&
                calendar.component(.month, from: $0.dateTaken) == month
            }
            
            let monthRolls = rolls.filter {
                calendar.component(.year, from: $0.dateLoaded) == year &&
                calendar.component(.month, from: $0.dateLoaded) == month
            }
            
            monthlyStats.append(MonthlyStatistics(
                month: month,
                year: year,
                exposureCount: monthExposures.count,
                keeperCount: monthExposures.filter { $0.keepers }.count,
                rollCount: monthRolls.count
            ))
        }
        
        return monthlyStats
    }
    
    // MARK: - Comparison Statistics
    
    func comparePeriods(period1: DateInterval, period2: DateInterval, context: ModelContext) async throws -> PeriodComparison {
        let exposures = try context.fetch(FetchDescriptor<Exposure>())
        
        let exposures1 = exposures.filter { period1.contains($0.dateTaken) }
        let exposures2 = exposures.filter { period2.contains($0.dateTaken) }
        
        return PeriodComparison(
            period1: PeriodStats(
                name: "Periodo 1",
                exposureCount: exposures1.count,
                keeperCount: exposures1.filter { $0.keepers }.count,
                rollCount: Set(exposures1.compactMap { $0.roll?.id }).count
            ),
            period2: PeriodStats(
                name: "Periodo 2",
                exposureCount: exposures2.count,
                keeperCount: exposures2.filter { $0.keepers }.count,
                rollCount: Set(exposures2.compactMap { $0.roll?.id }).count
            )
        )
    }
}

// MARK: - Statistics Types

struct FilmUsageStat: Identifiable, Sendable {
    let id = UUID()
    let filmName: String
    let manufacturer: FilmManufacturer
    let iso: Int
    let rollCount: Int
    let exposureCount: Int
    let keeperCount: Int
    let keeperRate: Double
    let lastUsed: Date
}

struct CameraUsageStat: Identifiable, Sendable {
    let id = UUID()
    let cameraName: String
    let exposureCount: Int
    let keeperCount: Int
    let keeperRate: Double
    let rollCount: Int
    let firstUsed: Date
    let lastUsed: Date
}

struct LensUsageStat: Identifiable, Sendable {
    let id = UUID()
    let lensName: String
    let exposureCount: Int
    let keeperCount: Int
    let keeperRate: Double
    let averageFocalLength: Double
    let mostUsedFocalLength: Int
}

struct LocationStat: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let exposureCount: Int
    let keeperCount: Int
    let keeperRate: Double
    let firstVisit: Date
    let lastVisit: Date
    let hasGPS: Bool
    let latitude: Double?
    let longitude: Double?
}

struct TimeDistributionStats: Sendable {
    let hourlyDistribution: [Int]
    let weekdayDistribution: [Int]
    let monthlyDistribution: [Int]
    let yearlyDistribution: [(key: Int, value: Int)]
    
    var peakHour: Int {
        hourlyDistribution.enumerated().max { $0.element < $1.element }?.offset ?? 0
    }
    
    var peakWeekday: Int {
        weekdayDistribution.enumerated().max { $0.element < $1.element }?.offset ?? 0
    }
    
    var peakMonth: Int {
        monthlyDistribution.enumerated().max { $0.element < $1.element }?.offset ?? 0
    }
}

struct ExposureDistributionStats: Sendable {
    let isoDistribution: [(key: Int, value: Int)]
    let apertureDistribution: [(String, Int)]
    let shutterDistribution: [(String, Int)]
    let focalLengthDistribution: [(String, Int)]
    
    var mostUsedISO: Int {
        isoDistribution.max { $0.value < $1.value }?.key ?? 400
    }
    
    var mostCommonAperture: String {
        apertureDistribution.max { $0.1 < $1.1 }?.0 ?? "f/8"
    }
}

struct PeriodComparison: Sendable {
    let period1: PeriodStats
    let period2: PeriodStats
    
    var exposureChange: Double {
        guard period1.exposureCount > 0 else { return 0 }
        return Double(period2.exposureCount - period1.exposureCount) / Double(period1.exposureCount) * 100
    }
    
    var keeperRateChange: Double {
        period2.keeperRate - period1.keeperRate
    }
}

struct PeriodStats: Sendable {
    let name: String
    let exposureCount: Int
    let keeperCount: Int
    let rollCount: Int
    
    var keeperRate: Double {
        exposureCount > 0 ? Double(keeperCount) / Double(exposureCount) * 100 : 0
    }
}

// MARK: - Array Extensions
extension Array where Element: Hashable {
    func mostCommon() -> Element? {
        let counts = reduce(into: [:]) { counts, element in
            counts[element, default: 0] += 1
        }
        return counts.max { $0.value < $1.value }?.key
    }
}

extension DateInterval {
    func contains(_ date: Date) -> Bool {
        date >= start && date <= end
    }
}
