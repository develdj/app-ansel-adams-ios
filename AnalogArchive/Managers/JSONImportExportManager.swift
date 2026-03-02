import Foundation
import SwiftData

// MARK: - JSON Import/Export Manager
/// Gestisce l'importazione ed esportazione JSON dell'archivio
@MainActor
final class JSONImportExportManager: ObservableObject {
    
    // MARK: - Singleton
    static let shared = JSONImportExportManager()
    
    // MARK: - Published Properties
    @Published var isExporting = false
    @Published var isImporting = false
    @Published var exportProgress: Double = 0
    @Published var importProgress: Double = 0
    @Published var lastError: ImportExportError?
    
    private init() {}
    
    // MARK: - Export Methods
    
    /// Esporta l'intero archivio in JSON
    func exportCompleteArchive(context: ModelContext) async throws -> Data {
        isExporting = true
        exportProgress = 0
        defer { isExporting = false }
        
        // Recupera tutti i dati
        let rolls = try context.fetch(FetchDescriptor<Roll>())
        exportProgress = 0.2
        
        let exposures = try context.fetch(FetchDescriptor<Exposure>())
        exportProgress = 0.4
        
        let prints = try context.fetch(FetchDescriptor<Print>())
        exportProgress = 0.6
        
        // Crea struttura esportabile
        let archive = ArchiveExport(
            exportDate: Date(),
            version: "1.0",
            rolls: rolls.map { RollExport(from: $0) },
            exposures: exposures.map { ExposureExport(from: $0) },
            prints: prints.map { PrintExport(from: $0) }
        )
        
        exportProgress = 0.8
        
        // Codifica in JSON
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        let data = try encoder.encode(archive)
        exportProgress = 1.0
        
        return data
    }
    
    /// Esporta solo i rullini selezionati
    func exportRolls(_ rolls: [Roll], context: ModelContext) async throws -> Data {
        isExporting = true
        defer { isExporting = false }
        
        let rollIds = rolls.map { $0.id }
        
        // Recupera esposizioni e stampe correlate
        let allExposures = try context.fetch(FetchDescriptor<Exposure>())
        let relatedExposures = allExposures.filter { exposure in
            guard let roll = exposure.roll else { return false }
            return rollIds.contains(roll.id)
        }
        
        let exposureIds = relatedExposures.map { $0.id }
        
        let allPrints = try context.fetch(FetchDescriptor<Print>())
        let relatedPrints = allPrints.filter { print in
            guard let exposure = print.exposure else { return false }
            return exposureIds.contains(exposure.id)
        }
        
        let archive = ArchiveExport(
            exportDate: Date(),
            version: "1.0",
            rolls: rolls.map { RollExport(from: $0) },
            exposures: relatedExposures.map { ExposureExport(from: $0) },
            prints: relatedPrints.map { PrintExport(from: $0) }
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        return try encoder.encode(archive)
    }
    
    /// Esporta solo le esposizioni keeper
    func exportKeepers(context: ModelContext) async throws -> Data {
        isExporting = true
        defer { isExporting = false }
        
        let allExposures = try context.fetch(FetchDescriptor<Exposure>())
        let keepers = allExposures.filter { $0.keepers || $0.rating.stars >= 3 }
        
        let exposureIds = keepers.map { $0.id }
        
        let allPrints = try context.fetch(FetchDescriptor<Print>())
        let relatedPrints = allPrints.filter { print in
            guard let exposure = print.exposure else { return false }
            return exposureIds.contains(exposure.id)
        }
        
        // Ottieni rullini unici
        let rollIds = Set(keepers.compactMap { $0.roll?.id })
        let allRolls = try context.fetch(FetchDescriptor<Roll>())
        let relatedRolls = allRolls.filter { rollIds.contains($0.id) }
        
        let archive = ArchiveExport(
            exportDate: Date(),
            version: "1.0",
            rolls: relatedRolls.map { RollExport(from: $0) },
            exposures: keepers.map { ExposureExport(from: $0) },
            prints: relatedPrints.map { PrintExport(from: $0) }
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        return try encoder.encode(archive)
    }
    
    /// Salva export su file
    func exportToFile(context: ModelContext, directory: URL? = nil) async throws -> URL {
        let data = try await exportCompleteArchive(context: context)
        
        let fileName = "AnalogArchive_\(formatDateForFile(Date())).json"
        let destinationDir = directory ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = destinationDir.appendingPathComponent(fileName)
        
        try data.write(to: fileURL)
        return fileURL
    }
    
    // MARK: - Import Methods
    
    /// Importa dati da JSON
    func importFromJSON(_ data: Data, context: ModelContext, mergeStrategy: MergeStrategy = .skipExisting) async throws -> ImportResult {
        isImporting = true
        importProgress = 0
        defer { isImporting = false }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let archive = try decoder.decode(ArchiveExport.self, from: data)
        importProgress = 0.1
        
        var result = ImportResult()
        
        // Importa rullini
        for rollExport in archive.rolls {
            if let existing = try? fetchRoll(byId: rollExport.id, context: context) {
                switch mergeStrategy {
                case .skipExisting:
                    result.skippedRolls += 1
                    continue
                case .replaceExisting:
                    context.delete(existing)
                    result.replacedRolls += 1
                case .merge:
                    // Aggiorna dati esistenti
                    updateRoll(existing, from: rollExport)
                    result.mergedRolls += 1
                    continue
                }
            }
            
            let roll = createRoll(from: rollExport)
            context.insert(roll)
            result.importedRolls += 1
        }
        
        importProgress = 0.4
        
        // Importa esposizioni
        for exposureExport in archive.exposures {
            if let existing = try? fetchExposure(byId: exposureExport.id, context: context) {
                switch mergeStrategy {
                case .skipExisting:
                    result.skippedExposures += 1
                    continue
                case .replaceExisting:
                    context.delete(existing)
                    result.replacedExposures += 1
                case .merge:
                    updateExposure(existing, from: exposureExport)
                    result.mergedExposures += 1
                    continue
                }
            }
            
            // Trova rullino associato
            let roll = try? fetchRoll(byId: exposureExport.rollId, context: context)
            
            let exposure = createExposure(from: exposureExport, roll: roll)
            context.insert(exposure)
            roll?.addExposure(exposure)
            result.importedExposures += 1
        }
        
        importProgress = 0.7
        
        // Importa stampe
        for printExport in archive.prints {
            if let existing = try? fetchPrint(byId: printExport.id, context: context) {
                switch mergeStrategy {
                case .skipExisting:
                    result.skippedPrints += 1
                    continue
                case .replaceExisting:
                    context.delete(existing)
                    result.replacedPrints += 1
                case .merge:
                    updatePrint(existing, from: printExport)
                    result.mergedPrints += 1
                    continue
                }
            }
            
            // Trova esposizione associata
            let exposure = try? fetchExposure(byId: printExport.exposureId, context: context)
            
            let print = createPrint(from: printExport, exposure: exposure)
            context.insert(print)
            exposure?.addPrint(print)
            result.importedPrints += 1
        }
        
        importProgress = 0.9
        
        // Salva
        try context.save()
        importProgress = 1.0
        
        return result
    }
    
    /// Importa da file
    func importFromFile(_ fileURL: URL, context: ModelContext, mergeStrategy: MergeStrategy = .skipExisting) async throws -> ImportResult {
        let data = try Data(contentsOf: fileURL)
        return try await importFromJSON(data, context: context, mergeStrategy: mergeStrategy)
    }
    
    // MARK: - Helper Methods
    
    private func fetchRoll(byId id: UUID, context: ModelContext) throws -> Roll? {
        var descriptor = FetchDescriptor<Roll>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
    
    private func fetchExposure(byId id: UUID, context: ModelContext) throws -> Exposure? {
        var descriptor = FetchDescriptor<Exposure>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
    
    private func fetchPrint(byId id: UUID, context: ModelContext) throws -> Print? {
        var descriptor = FetchDescriptor<Print>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
    
    private func createRoll(from export: RollExport) -> Roll {
        Roll(
            id: export.id,
            name: export.name,
            filmManufacturer: FilmManufacturer(rawValue: export.filmManufacturer) ?? .other,
            filmName: export.filmName,
            nominalISO: export.nominalISO,
            effectiveISO: export.effectiveISO,
            format: FilmFormat(rawValue: export.format) ?? .mm35,
            filmType: FilmType(rawValue: export.filmType) ?? .blackWhite,
            dateLoaded: export.dateLoaded,
            dateDeveloped: export.dateDeveloped,
            developerName: export.developerName,
            dilution: export.dilution,
            developmentTime: export.developmentTime,
            developmentTemperature: export.developmentTemperature,
            developmentAgitation: AgitationType(rawValue: export.developmentAgitation) ?? .standard,
            developmentNotes: export.developmentNotes,
            status: RollStatus(rawValue: export.status) ?? .loaded,
            isPushPull: export.isPushPull,
            pushPullStops: export.pushPullStops,
            notes: export.notes,
            isFavorite: export.isFavorite,
            rating: export.rating,
            storageLocation: export.storageLocation,
            negativePage: export.negativePage,
            negativeSleeveNumber: export.negativeSleeveNumber
        )
    }
    
    private func updateRoll(_ roll: Roll, from export: RollExport) {
        roll.name = export.name
        roll.filmName = export.filmName
        roll.nominalISO = export.nominalISO
        roll.effectiveISO = export.effectiveISO
        roll.developerName = export.developerName
        roll.notes = export.notes
        roll.updateTimestamp()
    }
    
    private func createExposure(from export: ExposureExport, roll: Roll?) -> Exposure {
        Exposure(
            id: export.id,
            frameNumber: export.frameNumber,
            roll: roll,
            title: export.title,
            dateTaken: export.dateTaken,
            cameraBrand: export.cameraBrand,
            cameraModel: export.cameraModel,
            lensBrand: export.lensBrand,
            lensModel: export.lensModel,
            focalLength: export.focalLength,
            focalLength35mm: export.focalLength35mm,
            shutterSpeed: ShutterSpeed(seconds: export.shutterSpeed),
            aperture: Aperture(fStop: export.aperture),
            isoUsed: export.isoUsed,
            focusDistance: export.focusDistance,
            focusDistanceInFeet: export.focusDistanceInFeet,
            isHyperfocal: export.isHyperfocal,
            isInfinity: export.isInfinity,
            filterName: export.filterName,
            filterStops: export.filterStops,
            lightCondition: LightCondition(rawValue: export.lightCondition) ?? .other,
            meteringMode: MeteringMode(rawValue: export.meteringMode) ?? .matrix,
            meteredEV: export.meteredEV,
            latitude: export.latitude,
            longitude: export.longitude,
            altitude: export.altitude,
            locationName: export.locationName,
            locationNotes: export.locationNotes,
            rating: ExposureRating(rawValue: export.rating) ?? .unrated,
            keepers: export.keepers,
            needsReprint: export.needsReprint,
            zonePlacement: export.zonePlacement,
            subjectBrightnessRange: export.subjectBrightnessRange,
            reciprocityCorrection: export.reciprocityCorrection,
            linkedPhotoAssetId: export.linkedPhotoAssetId,
            scannedImagePath: export.scannedImagePath,
            thumbnailPath: export.thumbnailPath,
            notes: export.notes,
            isFavorite: export.isFavorite
        )
    }
    
    private func updateExposure(_ exposure: Exposure, from export: ExposureExport) {
        exposure.title = export.title
        exposure.notes = export.notes
        exposure.rating = ExposureRating(rawValue: export.rating) ?? .unrated
        exposure.keepers = export.keepers
        exposure.updateTimestamp()
    }
    
    private func createPrint(from export: PrintExport, exposure: Exposure?) -> Print {
        Print(
            id: export.id,
            printNumber: export.printNumber,
            exposure: exposure,
            title: export.title,
            datePrinted: export.datePrinted,
            enlargerBrand: export.enlargerBrand,
            enlargerModel: export.enlargerModel,
            enlargerLens: export.enlargerLens,
            magnification: export.magnification,
            paperBrand: export.paperBrand,
            paperModel: export.paperModel,
            paperType: PaperType(rawValue: export.paperType) ?? .rc,
            paperGrade: PaperGrade(rawValue: export.paperGrade) ?? .grade2,
            paperSize: PaperSize(rawValue: export.paperSize) ?? .a4,
            filterValues: export.filterValues,
            splitGrade: export.splitGrade,
            baseExposureTime: export.baseExposureTime,
            aperture: export.aperture,
            developerName: export.developerName,
            developerDilution: export.developerDilution,
            developmentTime: export.developmentTime,
            developmentTemperature: export.developmentTemperature,
            fixerName: export.fixerName,
            fixerTime: export.fixerTime,
            washTime: export.washTime,
            printRating: PrintRating(rawValue: export.printRating) ?? .workPrint,
            isFinalPrint: export.isFinalPrint,
            isToned: export.isToned,
            tonerName: export.tonerName,
            notes: export.notes
        )
    }
    
    private func updatePrint(_ print: Print, from export: PrintExport) {
        print.title = export.title
        print.notes = export.notes
        print.printRating = PrintRating(rawValue: export.printRating) ?? .workPrint
        print.updateTimestamp()
    }
    
    private func formatDateForFile(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmmss"
        return formatter.string(from: date)
    }
}

// MARK: - Export Structures
struct ArchiveExport: Codable {
    let exportDate: Date
    let version: String
    let rolls: [RollExport]
    let exposures: [ExposureExport]
    let prints: [PrintExport]
}

struct RollExport: Codable {
    let id: UUID
    let name: String
    let filmManufacturer: String
    let filmName: String
    let nominalISO: Int
    let effectiveISO: Int
    let format: String
    let filmType: String
    let dateLoaded: Date
    let dateDeveloped: Date?
    let developerName: String
    let dilution: String
    let developmentTime: TimeInterval?
    let developmentTemperature: Double?
    let developmentAgitation: String
    let developmentNotes: String
    let status: String
    let isPushPull: Bool
    let pushPullStops: Double
    let notes: String
    let isFavorite: Bool
    let rating: Int
    let storageLocation: String?
    let negativePage: Int?
    let negativeSleeveNumber: String?
    
    init(from roll: Roll) {
        self.id = roll.id
        self.name = roll.name
        self.filmManufacturer = roll.filmManufacturerRaw
        self.filmName = roll.filmName
        self.nominalISO = roll.nominalISO
        self.effectiveISO = roll.effectiveISO
        self.format = roll.formatRaw
        self.filmType = roll.filmTypeRaw
        self.dateLoaded = roll.dateLoaded
        self.dateDeveloped = roll.dateDeveloped
        self.developerName = roll.developerName
        self.dilution = roll.dilution
        self.developmentTime = roll.developmentTime
        self.developmentTemperature = roll.developmentTemperature
        self.developmentAgitation = roll.developmentAgitation.rawValue
        self.developmentNotes = roll.developmentNotes
        self.status = roll.status.rawValue
        self.isPushPull = roll.isPushPull
        self.pushPullStops = roll.pushPullStops
        self.notes = roll.notes
        self.isFavorite = roll.isFavorite
        self.rating = roll.rating
        self.storageLocation = roll.storageLocation
        self.negativePage = roll.negativePage
        self.negativeSleeveNumber = roll.negativeSleeveNumber
    }
}

struct ExposureExport: Codable {
    let id: UUID
    let rollId: UUID
    let frameNumber: Int
    let title: String
    let dateTaken: Date
    let cameraBrand: String
    let cameraModel: String
    let lensBrand: String
    let lensModel: String
    let focalLength: Int
    let focalLength35mm: Int?
    let shutterSpeed: Double
    let aperture: Double
    let isoUsed: Int
    let focusDistance: Double?
    let focusDistanceInFeet: Double?
    let isHyperfocal: Bool
    let isInfinity: Bool
    let filterName: String?
    let filterStops: Double
    let lightCondition: String
    let meteringMode: String
    let meteredEV: Double?
    let latitude: Double?
    let longitude: Double?
    let altitude: Double?
    let locationName: String?
    let locationNotes: String?
    let rating: String
    let keepers: Bool
    let needsReprint: Bool
    let zonePlacement: Int?
    let subjectBrightnessRange: String?
    let reciprocityCorrection: String?
    let linkedPhotoAssetId: String?
    let scannedImagePath: String?
    let thumbnailPath: String?
    let notes: String
    let isFavorite: Bool
    
    init(from exposure: Exposure) {
        self.id = exposure.id
        self.rollId = exposure.roll?.id ?? UUID()
        self.frameNumber = exposure.frameNumber
        self.title = exposure.title
        self.dateTaken = exposure.dateTaken
        self.cameraBrand = exposure.cameraBrand
        self.cameraModel = exposure.cameraModel
        self.lensBrand = exposure.lensBrand
        self.lensModel = exposure.lensModel
        self.focalLength = exposure.focalLength
        self.focalLength35mm = exposure.focalLength35mm
        self.shutterSpeed = exposure.shutterSpeedRaw
        self.aperture = exposure.apertureRaw
        self.isoUsed = exposure.isoUsed
        self.focusDistance = exposure.focusDistance
        self.focusDistanceInFeet = exposure.focusDistanceInFeet
        self.isHyperfocal = exposure.isHyperfocal
        self.isInfinity = exposure.isInfinity
        self.filterName = exposure.filterName
        self.filterStops = exposure.filterStops
        self.lightCondition = exposure.lightConditionRaw
        self.meteringMode = exposure.meteringMode.rawValue
        self.meteredEV = exposure.meteredEV
        self.latitude = exposure.latitude
        self.longitude = exposure.longitude
        self.altitude = exposure.altitude
        self.locationName = exposure.locationName
        self.locationNotes = exposure.locationNotes
        self.rating = exposure.rating.rawValue
        self.keepers = exposure.keepers
        self.needsReprint = exposure.needsReprint
        self.zonePlacement = exposure.zonePlacement
        self.subjectBrightnessRange = exposure.subjectBrightnessRange
        self.reciprocityCorrection = exposure.reciprocityCorrection
        self.linkedPhotoAssetId = exposure.linkedPhotoAssetId
        self.scannedImagePath = exposure.scannedImagePath
        self.thumbnailPath = exposure.thumbnailPath
        self.notes = exposure.notes
        self.isFavorite = exposure.isFavorite
    }
}

struct PrintExport: Codable {
    let id: UUID
    let exposureId: UUID
    let printNumber: String
    let title: String
    let datePrinted: Date
    let enlargerBrand: String
    let enlargerModel: String
    let enlargerLens: String
    let magnification: Double
    let paperBrand: String
    let paperModel: String
    let paperType: String
    let paperGrade: String
    let paperSize: String
    let filterValues: String?
    let splitGrade: Bool
    let baseExposureTime: TimeInterval
    let aperture: Double
    let developerName: String
    let developerDilution: String
    let developmentTime: TimeInterval
    let developmentTemperature: Double?
    let fixerName: String
    let fixerTime: TimeInterval
    let washTime: TimeInterval
    let printRating: String
    let isFinalPrint: Bool
    let isToned: Bool
    let tonerName: String?
    let notes: String
    
    init(from print: Print) {
        self.id = print.id
        self.exposureId = print.exposure?.id ?? UUID()
        self.printNumber = print.printNumber
        self.title = print.title
        self.datePrinted = print.datePrinted
        self.enlargerBrand = print.enlargerBrand
        self.enlargerModel = print.enlargerModel
        self.enlargerLens = print.enlargerLens
        self.magnification = print.magnification
        self.paperBrand = print.paperBrand
        self.paperModel = print.paperModel
        self.paperType = print.paperType.rawValue
        self.paperGrade = print.paperGrade.rawValue
        self.paperSize = print.paperSize.rawValue
        self.filterValues = print.filterValues
        self.splitGrade = print.splitGrade
        self.baseExposureTime = print.baseExposureTime
        self.aperture = print.aperture
        self.developerName = print.developerName
        self.developerDilution = print.developerDilution
        self.developmentTime = print.developmentTime
        self.developmentTemperature = print.developmentTemperature
        self.fixerName = print.fixerName
        self.fixerTime = print.fixerTime
        self.washTime = print.washTime
        self.printRating = print.printRating.rawValue
        self.isFinalPrint = print.isFinalPrint
        self.isToned = print.isToned
        self.tonerName = print.tonerName
        self.notes = print.notes
    }
}

// MARK: - Merge Strategy
enum MergeStrategy {
    case skipExisting      // Salta elementi esistenti
    case replaceExisting   // Sostituisce elementi esistenti
    case merge            // Unisce i dati
}

// MARK: - Import Result
struct ImportResult {
    var importedRolls = 0
    var importedExposures = 0
    var importedPrints = 0
    var skippedRolls = 0
    var skippedExposures = 0
    var skippedPrints = 0
    var replacedRolls = 0
    var replacedExposures = 0
    var replacedPrints = 0
    var mergedRolls = 0
    var mergedExposures = 0
    var mergedPrints = 0
    
    var totalImported: Int {
        importedRolls + importedExposures + importedPrints
    }
    
    var totalSkipped: Int {
        skippedRolls + skippedExposures + skippedPrints
    }
    
    var totalProcessed: Int {
        totalImported + totalSkipped + replacedRolls + replacedExposures + replacedPrints + mergedRolls + mergedExposures + mergedPrints
    }
    
    var summary: String {
        """
        Importazione completata:
        • Importati: \(totalImported)
        • Saltati: \(totalSkipped)
        • Sostituiti: \(replacedRolls + replacedExposures + replacedPrints)
        • Uniti: \(mergedRolls + mergedExposures + mergedPrints)
        """
    }
}

// MARK: - Errors
enum ImportExportError: Error, LocalizedError {
    case invalidJSON
    case incompatibleVersion
    case missingRequiredData
    case saveFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidJSON:
            return "File JSON non valido"
        case .incompatibleVersion:
            return "Versione file non compatibile"
        case .missingRequiredData:
            return "Dati richiesti mancanti"
        case .saveFailed(let error):
            return "Salvataggio fallito: \(error.localizedDescription)"
        }
    }
}
