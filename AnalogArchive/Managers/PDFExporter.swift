import Foundation
import SwiftUI
import PDFKit

// MARK: - PDF Exporter
/// Gestisce l'esportazione dell'archivio in formato PDF
@MainActor
final class PDFExporter {
    
    // MARK: - Singleton
    static let shared = PDFExporter()
    
    // MARK: - Properties
    private let pageWidth: CGFloat = 595.2 // A4 in punti (72 dpi)
    private let pageHeight: CGFloat = 841.8
    private let margin: CGFloat = 36 // 0.5 inch
    
    private init() {}
    
    // MARK: - Export Methods
    
    /// Esporta un rullino completo in PDF
    func exportRoll(_ roll: Roll, includePrints: Bool = true) async throws -> Data {
        let pdfMetaData = [
            kCGPDFContextCreator: "Zone System Master",
            kCGPDFContextAuthor: "Analog Archive Manager",
            kCGPDFContextTitle: "Registro: \(roll.displayName)",
            kCGPDFContextSubject: "Archivio Fotografico Analogico"
        ]
        
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        
        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight),
            format: format
        )
        
        return renderer.pdfData { context in
            // Pagina 1: Copertina e info rullino
            self.drawRollCoverPage(context: context, roll: roll)
            
            // Pagina 2: Dettagli sviluppo
            context.beginPage()
            self.drawDevelopmentDetailsPage(context: context, roll: roll)
            
            // Pagine esposizioni
            let exposures = roll.sortedExposures()
            if !exposures.isEmpty {
                context.beginPage()
                self.drawExposuresHeader(context: context)
                
                var currentY: CGFloat = 120
                for exposure in exposures {
                    let neededHeight = includePrints ? 140 : 80
                    if currentY + neededHeight > pageHeight - margin {
                        context.beginPage()
                        self.drawExposuresHeader(context: context)
                        currentY = 120
                    }
                    self.drawExposureRow(context: context, exposure: exposure, y: &currentY, includePrints: includePrints)
                }
            }
        }
    }
    
    /// Esporta registro completo di tutti i rullini
    func exportCompleteArchive(rolls: [Roll]) async throws -> Data {
        let pdfMetaData = [
            kCGPDFContextCreator: "Zone System Master",
            kCGPDFContextAuthor: "Analog Archive Manager",
            kCGPDFContextTitle: "Registro Completo Archivio Analogico",
            kCGPDFContextSubject: "Archivio Fotografico Analogico"
        ]
        
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        
        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight),
            format: format
        )
        
        return renderer.pdfData { context in
            // Pagina copertina
            self.drawArchiveCoverPage(context: context, rollCount: rolls.count)
            
            // Indice rullini
            context.beginPage()
            self.drawRollIndexPage(context: context, rolls: rolls)
            
            // Dettagli per ogni rullino
            for roll in rolls.sorted(by: { $0.dateLoaded > $1.dateLoaded }) {
                context.beginPage()
                self.drawRollSummaryPage(context: context, roll: roll)
            }
        }
    }
    
    /// Esporta solo le esposizioni keeper
    func exportKeepers(exposures: [Exposure]) async throws -> Data {
        let pdfMetaData = [
            kCGPDFContextCreator: "Zone System Master",
            kCGPDFContextAuthor: "Analog Archive Manager",
            kCGPDFContextTitle: "Best Of - Esposizioni Selezionate",
            kCGPDFContextSubject: "Archivio Fotografico Analogico"
        ]
        
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        
        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight),
            format: format
        )
        
        return renderer.pdfData { context in
            // Copertina
            self.drawKeepersCoverPage(context: context, count: exposures.count)
            
            // Dettagli esposizioni
            var pageCount = 0
            for exposure in exposures.sorted(by: { $0.dateTaken > $1.dateTaken }) {
                if pageCount > 0 {
                    context.beginPage()
                }
                self.drawExposureDetailPage(context: context, exposure: exposure)
                pageCount += 1
            }
        }
    }
    
    /// Esporta statistiche
    func exportStatistics(_ statistics: ArchiveStatistics) async throws -> Data {
        let pdfMetaData = [
            kCGPDFContextCreator: "Zone System Master",
            kCGPDFContextAuthor: "Analog Archive Manager",
            kCGPDFContextTitle: "Statistiche Archivio",
            kCGPDFContextSubject: "Analisi Archivio Fotografico Analogico"
        ]
        
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        
        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight),
            format: format
        )
        
        return renderer.pdfData { context in
            self.drawStatisticsPage(context: context, statistics: statistics)
        }
    }
    
    // MARK: - Drawing Methods
    
    private func drawRollCoverPage(context: UIGraphicsPDFRendererContext, roll: Roll) {
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 28),
            .foregroundColor: UIColor.black
        ]
        
        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 16),
            .foregroundColor: UIColor.darkGray
        ]
        
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 12),
            .foregroundColor: UIColor.black
        ]
        
        let valueAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.black
        ]
        
        // Titolo
        let title = "REGISTRO FOTOGRAFICO"
        title.draw(at: CGPoint(x: margin, y: 60), withAttributes: titleAttributes)
        
        // Nome rullino
        let rollName = roll.displayName
        rollName.draw(at: CGPoint(x: margin, y: 100), withAttributes: subtitleAttributes)
        
        // Linea separatrice
        drawLine(context: context, from: CGPoint(x: margin, y: 130), to: CGPoint(x: pageWidth - margin, y: 130))
        
        // Informazioni pellicola
        var y: CGFloat = 160
        let col2X: CGFloat = 200
        
        drawLabel("Pellicola:", at: CGPoint(x: margin, y: y), attributes: labelAttributes)
        drawValue(roll.fullFilmName, at: CGPoint(x: col2X, y: y), attributes: valueAttributes)
        y += 25
        
        drawLabel("Formato:", at: CGPoint(x: margin, y: y), attributes: labelAttributes)
        drawValue(roll.format.rawValue, at: CGPoint(x: col2X, y: y), attributes: valueAttributes)
        y += 25
        
        drawLabel("ISO Nominale:", at: CGPoint(x: margin, y: y), attributes: labelAttributes)
        drawValue("\(roll.nominalISO)", at: CGPoint(x: col2X, y: y), attributes: valueAttributes)
        y += 25
        
        drawLabel("ISO Effettiva:", at: CGPoint(x: margin, y: y), attributes: labelAttributes)
        drawValue("\(roll.effectiveISO) (\(roll.pushPullDescription))", at: CGPoint(x: col2X, y: y), attributes: valueAttributes)
        y += 25
        
        drawLabel("Data caricamento:", at: CGPoint(x: margin, y: y), attributes: labelAttributes)
        drawValue(formatDate(roll.dateLoaded), at: CGPoint(x: col2X, y: y), attributes: valueAttributes)
        y += 25
        
        if let dateDeveloped = roll.dateDeveloped {
            drawLabel("Data sviluppo:", at: CGPoint(x: margin, y: y), attributes: labelAttributes)
            drawValue(formatDate(dateDeveloped), at: CGPoint(x: col2X, y: y), attributes: valueAttributes)
            y += 25
        }
        
        drawLabel("Esposizioni:", at: CGPoint(x: margin, y: y), attributes: labelAttributes)
        drawValue("\(roll.exposureCount) / \(roll.expectedFrameCount)", at: CGPoint(x: col2X, y: y), attributes: valueAttributes)
        y += 25
        
        drawLabel("Stato:", at: CGPoint(x: margin, y: y), attributes: labelAttributes)
        drawValue(roll.status.rawValue, at: CGPoint(x: col2X, y: y), attributes: valueAttributes)
        y += 40
        
        // Note
        if !roll.notes.isEmpty {
            drawLabel("Note:", at: CGPoint(x: margin, y: y), attributes: labelAttributes)
            y += 20
            drawWrappedText(roll.notes, at: CGPoint(x: margin, y: y), width: pageWidth - margin * 2, attributes: valueAttributes)
        }
        
        // Footer
        drawFooter(context: context, pageNumber: 1)
    }
    
    private func drawDevelopmentDetailsPage(context: UIGraphicsPDFRendererContext, roll: Roll) {
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 20),
            .foregroundColor: UIColor.black
        ]
        
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 12),
            .foregroundColor: UIColor.black
        ]
        
        let valueAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor.black
        ]
        
        // Titolo
        "DETTAGLI SVILUPPO".draw(at: CGPoint(x: margin, y: 60), withAttributes: titleAttributes)
        drawLine(context: context, from: CGPoint(x: margin, y: 90), to: CGPoint(x: pageWidth - margin, y: 90))
        
        var y: CGFloat = 120
        let col2X: CGFloat = 200
        
        drawLabel("Sviluppatore:", at: CGPoint(x: margin, y: y), attributes: labelAttributes)
        drawValue(roll.developerName.isEmpty ? "Non specificato" : roll.developerName, at: CGPoint(x: col2X, y: y), attributes: valueAttributes)
        y += 25
        
        drawLabel("Diluizione:", at: CGPoint(x: margin, y: y), attributes: labelAttributes)
        drawValue(roll.dilution, at: CGPoint(x: col2X, y: y), attributes: valueAttributes)
        y += 25
        
        drawLabel("Tempo:", at: CGPoint(x: margin, y: y), attributes: labelAttributes)
        drawValue(roll.developmentTimeFormatted, at: CGPoint(x: col2X, y: y), attributes: valueAttributes)
        y += 25
        
        drawLabel("Temperatura:", at: CGPoint(x: margin, y: y), attributes: labelAttributes)
        drawValue(roll.temperatureFormatted, at: CGPoint(x: col2X, y: y), attributes: valueAttributes)
        y += 25
        
        drawLabel("Agitazione:", at: CGPoint(x: margin, y: y), attributes: labelAttributes)
        drawValue(roll.developmentAgitation.rawValue, at: CGPoint(x: col2X, y: y), attributes: valueAttributes)
        y += 40
        
        // Note sviluppo
        if !roll.developmentNotes.isEmpty {
            drawLabel("Note sviluppo:", at: CGPoint(x: margin, y: y), attributes: labelAttributes)
            y += 20
            drawWrappedText(roll.developmentNotes, at: CGPoint(x: margin, y: y), width: pageWidth - margin * 2, attributes: valueAttributes)
        }
        
        // Archiviazione
        y = 400
        drawLine(context: context, from: CGPoint(x: margin, y: y), to: CGPoint(x: pageWidth - margin, y: y))
        y += 20
        
        drawLabel("ARCHIVIAZIONE", at: CGPoint(x: margin, y: y), attributes: titleAttributes)
        y += 40
        
        drawLabel("Posizione:", at: CGPoint(x: margin, y: y), attributes: labelAttributes)
        drawValue(roll.storageLocation ?? "Non specificata", at: CGPoint(x: col2X, y: y), attributes: valueAttributes)
        y += 25
        
        drawLabel("Pagina negativi:", at: CGPoint(x: margin, y: y), attributes: labelAttributes)
        drawValue(roll.negativePage.map { "\($0)" } ?? "Non specificata", at: CGPoint(x: col2X, y: y), attributes: valueAttributes)
        y += 25
        
        drawLabel("Busta:", at: CGPoint(x: margin, y: y), attributes: labelAttributes)
        drawValue(roll.negativeSleeveNumber ?? "Non specificata", at: CGPoint(x: col2X, y: y), attributes: valueAttributes)
        
        drawFooter(context: context, pageNumber: 2)
    }
    
    private func drawExposuresHeader(context: UIGraphicsPDFRendererContext) {
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 18),
            .foregroundColor: UIColor.black
        ]
        
        let headerAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 10),
            .foregroundColor: UIColor.white
        ]
        
        // Titolo
        "ESPOSIZIONI".draw(at: CGPoint(x: margin, y: 50), withAttributes: titleAttributes)
        
        // Header tabella
        let headerY: CGFloat = 85
        let headerRect = CGRect(x: margin, y: headerY, width: pageWidth - margin * 2, height: 25)
        UIColor.darkGray.setFill()
        context.cgContext.fill(headerRect)
        
        // Colonne
        let colWidths: [CGFloat] = [35, 60, 80, 80, 70, 60, 80, 80]
        let colXPositions = calculateColumnPositions(startX: margin, widths: colWidths)
        let headers = ["N.", "Data", "Camera", "Obiettivo", "Esposizione", "Diafr.", "Filtro", "Valutazione"]
        
        for (index, header) in headers.enumerated() {
            header.draw(at: CGPoint(x: colXPositions[index] + 3, y: headerY + 5), withAttributes: headerAttributes)
        }
    }
    
    private func drawExposureRow(context: UIGraphicsPDFRendererContext, exposure: Exposure, y: inout CGFloat, includePrints: Bool) {
        let rowHeight: CGFloat = includePrints ? 120 : 70
        let altRowColor = (exposure.frameNumber % 2 == 0)
        
        // Sfondo riga alternata
        if altRowColor {
            let rowRect = CGRect(x: margin, y: y, width: pageWidth - margin * 2, height: rowHeight)
            UIColor(white: 0.95, alpha: 1).setFill()
            context.cgContext.fill(rowRect)
        }
        
        // Bordo riga
        let borderRect = CGRect(x: margin, y: y, width: pageWidth - margin * 2, height: rowHeight)
        UIColor.lightGray.setStroke()
        context.cgContext.stroke(borderRect)
        
        let valueAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9),
            .foregroundColor: UIColor.black
        ]
        
        let smallAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8),
            .foregroundColor: UIColor.darkGray
        ]
        
        // Colonne
        let colWidths: [CGFloat] = [35, 60, 80, 80, 70, 60, 80, 80]
        let colXPositions = calculateColumnPositions(startX: margin, widths: colWidths)
        
        // Frame number
        "\(exposure.frameNumber)".draw(at: CGPoint(x: colXPositions[0] + 10, y: y + 5), withAttributes: valueAttributes)
        
        // Data
        let dateStr = formatShortDate(exposure.dateTaken)
        dateStr.draw(at: CGPoint(x: colXPositions[1] + 3, y: y + 5), withAttributes: valueAttributes)
        
        // Camera
        exposure.cameraModel.draw(at: CGPoint(x: colXPositions[2] + 3, y: y + 5), withAttributes: valueAttributes)
        
        // Obiettivo
        "\(exposure.focalLength)mm".draw(at: CGPoint(x: colXPositions[3] + 3, y: y + 5), withAttributes: valueAttributes)
        
        // Esposizione
        exposure.shutterSpeed.displayString.draw(at: CGPoint(x: colXPositions[4] + 3, y: y + 5), withAttributes: valueAttributes)
        
        // Diaframma
        "f/\(exposure.aperture.displayString)".draw(at: CGPoint(x: colXPositions[5] + 3, y: y + 5), withAttributes: valueAttributes)
        
        // Filtro
        let filterText = exposure.filterName ?? "-"
        filterText.draw(at: CGPoint(x: colXPositions[6] + 3, y: y + 5), withAttributes: valueAttributes)
        
        // Valutazione
        exposure.rating.rawValue.draw(at: CGPoint(x: colXPositions[7] + 3, y: y + 5), withAttributes: valueAttributes)
        
        // Titolo e note
        if !exposure.title.isEmpty {
            exposure.title.draw(at: CGPoint(x: margin + 5, y: y + 25), withAttributes: valueAttributes)
        }
        
        if !exposure.notes.isEmpty {
            let noteText = exposure.notes.prefix(100)
            String(noteText).draw(at: CGPoint(x: margin + 5, y: y + 40), withAttributes: smallAttributes)
        }
        
        // Stampe associate
        if includePrints, let prints = exposure.prints, !prints.isEmpty {
            var printY = y + 60
            for print in prints {
                let printInfo = "Stampa \(print.printNumber): \(print.paperBrand) \(print.paperModel) Grado \(print.paperGrade.displayName) - \(print.baseExposureFormatted)"
                printInfo.draw(at: CGPoint(x: margin + 15, y: printY), withAttributes: smallAttributes)
                printY += 12
            }
        }
        
        y += rowHeight
    }
    
    private func drawArchiveCoverPage(context: UIGraphicsPDFRendererContext, rollCount: Int) {
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 32),
            .foregroundColor: UIColor.black
        ]
        
        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 18),
            .foregroundColor: UIColor.darkGray
        ]
        
        let infoAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14),
            .foregroundColor: UIColor.black
        ]
        
        // Titolo centrato
        let title = "ARCHIVIO FOTOGRAFICO ANALOGICO"
        let titleSize = title.size(withAttributes: titleAttributes)
        let titleX = (pageWidth - titleSize.width) / 2
        title.draw(at: CGPoint(x: titleX, y: 200), withAttributes: titleAttributes)
        
        // Sottotitolo
        let subtitle = "Registro Completo"
        let subtitleSize = subtitle.size(withAttributes: subtitleAttributes)
        let subtitleX = (pageWidth - subtitleSize.width) / 2
        subtitle.draw(at: CGPoint(x: subtitleX, y: 250), withAttributes: subtitleAttributes)
        
        // Info
        let dateStr = formatDate(Date())
        "Data esportazione: \(dateStr)".draw(at: CGPoint(x: margin, y: 400), withAttributes: infoAttributes)
        "Totale rullini: \(rollCount)".draw(at: CGPoint(x: margin, y: 430), withAttributes: infoAttributes)
        
        drawFooter(context: context, pageNumber: 1)
    }
    
    private func drawRollIndexPage(context: UIGraphicsPDFRendererContext, rolls: [Roll]) {
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 18),
            .foregroundColor: UIColor.black
        ]
        
        let headerAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 10),
            .foregroundColor: UIColor.white
        ]
        
        let valueAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9),
            .foregroundColor: UIColor.black
        ]
        
        // Titolo
        "INDICE RULLINI".draw(at: CGPoint(x: margin, y: 50), withAttributes: titleAttributes)
        
        // Header tabella
        let headerY: CGFloat = 85
        let headerRect = CGRect(x: margin, y: headerY, width: pageWidth - margin * 2, height: 25)
        UIColor.darkGray.setFill()
        context.cgContext.fill(headerRect)
        
        let colWidths: [CGFloat] = [40, 150, 80, 50, 50, 80, 80]
        let colXPositions = calculateColumnPositions(startX: margin, widths: colWidths)
        let headers = ["#", "Pellicola", "Formato", "ISO", "Esp.", "Caricato", "Stato"]
        
        for (index, header) in headers.enumerated() {
            header.draw(at: CGPoint(x: colXPositions[index] + 3, y: headerY + 5), withAttributes: headerAttributes)
        }
        
        // Righe
        var y: CGFloat = 110
        let rowHeight: CGFloat = 20
        
        for (index, roll) in rolls.sorted(by: { $0.dateLoaded > $1.dateLoaded }).enumerated() {
            if y + rowHeight > pageHeight - margin {
                context.beginPage()
                y = margin
            }
            
            // Sfondo alternato
            if index % 2 == 0 {
                let rowRect = CGRect(x: margin, y: y, width: pageWidth - margin * 2, height: rowHeight)
                UIColor(white: 0.95, alpha: 1).setFill()
                context.cgContext.fill(rowRect)
            }
            
            "\(index + 1)".draw(at: CGPoint(x: colXPositions[0] + 10, y: y + 3), withAttributes: valueAttributes)
            roll.fullFilmName.draw(at: CGPoint(x: colXPositions[1] + 3, y: y + 3), withAttributes: valueAttributes)
            roll.format.rawValue.draw(at: CGPoint(x: colXPositions[2] + 3, y: y + 3), withAttributes: valueAttributes)
            "\(roll.nominalISO)".draw(at: CGPoint(x: colXPositions[3] + 10, y: y + 3), withAttributes: valueAttributes)
            "\(roll.exposureCount)".draw(at: CGPoint(x: colXPositions[4] + 15, y: y + 3), withAttributes: valueAttributes)
            formatShortDate(roll.dateLoaded).draw(at: CGPoint(x: colXPositions[5] + 3, y: y + 3), withAttributes: valueAttributes)
            roll.status.rawValue.draw(at: CGPoint(x: colXPositions[6] + 3, y: y + 3), withAttributes: valueAttributes)
            
            y += rowHeight
        }
        
        drawFooter(context: context, pageNumber: 2)
    }
    
    private func drawRollSummaryPage(context: UIGraphicsPDFRendererContext, roll: Roll) {
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 16),
            .foregroundColor: UIColor.black
        ]
        
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 10),
            .foregroundColor: UIColor.black
        ]
        
        let valueAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: UIColor.black
        ]
        
        // Titolo
        roll.displayName.draw(at: CGPoint(x: margin, y: 50), withAttributes: titleAttributes)
        drawLine(context: context, from: CGPoint(x: margin, y: 75), to: CGPoint(x: pageWidth - margin, y: 75))
        
        var y: CGFloat = 95
        let col2X: CGFloat = 180
        
        // Info base
        drawLabel("Pellicola:", at: CGPoint(x: margin, y: y), attributes: labelAttributes)
        drawValue(roll.fullFilmName, at: CGPoint(x: col2X, y: y), attributes: valueAttributes)
        y += 20
        
        drawLabel("Formato:", at: CGPoint(x: margin, y: y), attributes: labelAttributes)
        drawValue("\(roll.format.rawValue) (\(roll.format.frameSize))", at: CGPoint(x: col2X, y: y), attributes: valueAttributes)
        y += 20
        
        drawLabel("ISO:", at: CGPoint(x: margin, y: y), attributes: labelAttributes)
        drawValue("\(roll.nominalISO) / \(roll.effectiveISO)", at: CGPoint(x: col2X, y: y), attributes: valueAttributes)
        y += 20
        
        drawLabel("Data caricamento:", at: CGPoint(x: margin, y: y), attributes: labelAttributes)
        drawValue(formatDate(roll.dateLoaded), at: CGPoint(x: col2X, y: y), attributes: valueAttributes)
        y += 20
        
        if let dateDeveloped = roll.dateDeveloped {
            drawLabel("Data sviluppo:", at: CGPoint(x: margin, y: y), attributes: labelAttributes)
            drawValue(formatDate(dateDeveloped), at: CGPoint(x: col2X, y: y), attributes: valueAttributes)
            y += 20
        }
        
        y += 10
        
        // Sviluppo
        drawLabel("Sviluppatore:", at: CGPoint(x: margin, y: y), attributes: labelAttributes)
        drawValue("\(roll.developerName) \(roll.dilution)", at: CGPoint(x: col2X, y: y), attributes: valueAttributes)
        y += 20
        
        drawLabel("Tempo:", at: CGPoint(x: margin, y: y), attributes: labelAttributes)
        drawValue(roll.developmentTimeFormatted, at: CGPoint(x: col2X, y: y), attributes: valueAttributes)
        y += 20
        
        drawLabel("Temperatura:", at: CGPoint(x: margin, y: y), attributes: labelAttributes)
        drawValue(roll.temperatureFormatted, at: CGPoint(x: col2X, y: y), attributes: valueAttributes)
        y += 30
        
        // Esposizioni
        drawLine(context: context, from: CGPoint(x: margin, y: y), to: CGPoint(x: pageWidth - margin, y: y))
        y += 15
        
        "Esposizioni (\(roll.exposureCount))".draw(at: CGPoint(x: margin, y: y), withAttributes: labelAttributes)
        y += 25
        
        // Lista esposizioni compatta
        let exposures = roll.sortedExposures()
        for exposure in exposures {
            let exposureLine = "#\(exposure.frameNumber) | \(formatShortDate(exposure.dateTaken)) | \(exposure.cameraModel) | \(exposure.exposureSettings) | \(exposure.rating.rawValue)"
            exposureLine.draw(at: CGPoint(x: margin, y: y), withAttributes: valueAttributes)
            y += 15
            
            if y > pageHeight - margin - 30 {
                drawFooter(context: context, pageNumber: 0)
                context.beginPage()
                y = margin
            }
        }
        
        drawFooter(context: context, pageNumber: 0)
    }
    
    private func drawKeepersCoverPage(context: UIGraphicsPDFRendererContext, count: Int) {
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 32),
            .foregroundColor: UIColor.black
        ]
        
        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 18),
            .foregroundColor: UIColor.darkGray
        ]
        
        let infoAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14),
            .foregroundColor: UIColor.black
        ]
        
        let title = "BEST OF"
        let titleSize = title.size(withAttributes: titleAttributes)
        let titleX = (pageWidth - titleSize.width) / 2
        title.draw(at: CGPoint(x: titleX, y: 200), withAttributes: titleAttributes)
        
        let subtitle = "Esposizioni Selezionate"
        let subtitleSize = subtitle.size(withAttributes: subtitleAttributes)
        let subtitleX = (pageWidth - subtitleSize.width) / 2
        subtitle.draw(at: CGPoint(x: subtitleX, y: 250), withAttributes: subtitleAttributes)
        
        "Totale fotografie: \(count)".draw(at: CGPoint(x: margin, y: 350), withAttributes: infoAttributes)
        "Data: \(formatDate(Date()))".draw(at: CGPoint(x: margin, y: 380), withAttributes: infoAttributes)
        
        drawFooter(context: context, pageNumber: 1)
    }
    
    private func drawExposureDetailPage(context: UIGraphicsPDFRendererContext, exposure: Exposure) {
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 18),
            .foregroundColor: UIColor.black
        ]
        
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 11),
            .foregroundColor: UIColor.black
        ]
        
        let valueAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11),
            .foregroundColor: UIColor.black
        ]
        
        // Titolo
        let title = exposure.title.isEmpty ? "Foto #\(exposure.frameNumber)" : exposure.title
        title.draw(at: CGPoint(x: margin, y: 50), withAttributes: titleAttributes)
        
        if let roll = exposure.roll {
            "Rullino: \(roll.displayName)".draw(at: CGPoint(x: margin, y: 80), withAttributes: valueAttributes)
        }
        
        drawLine(context: context, from: CGPoint(x: margin, y: 105), to: CGPoint(x: pageWidth - margin, y: 105))
        
        var y: CGFloat = 130
        let col2X: CGFloat = 200
        
        // Data e ora
        drawLabel("Data:", at: CGPoint(x: margin, y: y), attributes: labelAttributes)
        drawValue(formatDate(exposure.dateTaken), at: CGPoint(x: col2X, y: y), attributes: valueAttributes)
        y += 22
        
        // Camera
        drawLabel("Camera:", at: CGPoint(x: margin, y: y), attributes: labelAttributes)
        drawValue(exposure.cameraDisplayName, at: CGPoint(x: col2X, y: y), attributes: valueAttributes)
        y += 22
        
        // Obiettivo
        drawLabel("Obiettivo:", at: CGPoint(x: margin, y: y), attributes: labelAttributes)
        drawValue(exposure.lensDisplayName, at: CGPoint(x: col2X, y: y), attributes: valueAttributes)
        y += 22
        
        // Esposizione
        drawLabel("Esposizione:", at: CGPoint(x: margin, y: y), attributes: labelAttributes)
        drawValue(exposure.exposureSettings, at: CGPoint(x: col2X, y: y), attributes: valueAttributes)
        y += 22
        
        // ISO
        drawLabel("ISO usata:", at: CGPoint(x: margin, y: y), attributes: labelAttributes)
        drawValue("\(exposure.isoUsed)", at: CGPoint(x: col2X, y: y), attributes: valueAttributes)
        y += 22
        
        // Messa a fuoco
        drawLabel("Messa a fuoco:", at: CGPoint(x: margin, y: y), attributes: labelAttributes)
        drawValue(exposure.focusDistanceDisplay, at: CGPoint(x: col2X, y: y), attributes: valueAttributes)
        y += 22
        
        // Filtro
        if let filterName = exposure.filterName {
            drawLabel("Filtro:", at: CGPoint(x: margin, y: y), attributes: labelAttributes)
            drawValue(filterName, at: CGPoint(x: col2X, y: y), attributes: valueAttributes)
            y += 22
        }
        
        // Luce
        drawLabel("Condizioni luce:", at: CGPoint(x: margin, y: y), attributes: labelAttributes)
        drawValue(exposure.lightCondition.rawValue, at: CGPoint(x: col2X, y: y), attributes: valueAttributes)
        y += 22
        
        // Sistema zona
        if let zone = exposure.zonePlacement {
            drawLabel("Sistema Zona:", at: CGPoint(x: margin, y: y), attributes: labelAttributes)
            drawValue("Zona \(zone)", at: CGPoint(x: col2X, y: y), attributes: valueAttributes)
            y += 22
        }
        
        // Location
        if let location = exposure.locationName {
            drawLabel("Luogo:", at: CGPoint(x: margin, y: y), attributes: labelAttributes)
            drawValue(location, at: CGPoint(x: col2X, y: y), attributes: valueAttributes)
            y += 22
        }
        
        // Valutazione
        drawLabel("Valutazione:", at: CGPoint(x: margin, y: y), attributes: labelAttributes)
        drawValue(exposure.rating.rawValue, at: CGPoint(x: col2X, y: y), attributes: valueAttributes)
        y += 30
        
        // Note
        if !exposure.notes.isEmpty {
            drawLabel("Note:", at: CGPoint(x: margin, y: y), attributes: labelAttributes)
            y += 18
            drawWrappedText(exposure.notes, at: CGPoint(x: margin, y: y), width: pageWidth - margin * 2, attributes: valueAttributes)
        }
        
        // Stampe
        if let prints = exposure.prints, !prints.isEmpty {
            y = 550
            drawLine(context: context, from: CGPoint(x: margin, y: y), to: CGPoint(x: pageWidth - margin, y: y))
            y += 15
            
            "Stampe (\(prints.count))".draw(at: CGPoint(x: margin, y: y), withAttributes: labelAttributes)
            y += 20
            
            for print in prints {
                let printInfo = "• \(print.printNumber): \(print.paperBrand) \(print.paperModel) Gr.\(print.paperGrade.displayName) - \(print.baseExposureFormatted)"
                printInfo.draw(at: CGPoint(x: margin + 10, y: y), withAttributes: valueAttributes)
                y += 16
            }
        }
        
        drawFooter(context: context, pageNumber: 0)
    }
    
    private func drawStatisticsPage(context: UIGraphicsPDFRendererContext, statistics: ArchiveStatistics) {
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 24),
            .foregroundColor: UIColor.black
        ]
        
        let sectionAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 14),
            .foregroundColor: UIColor.black
        ]
        
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11),
            .foregroundColor: UIColor.darkGray
        ]
        
        let valueAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 18),
            .foregroundColor: UIColor.black
        ]
        
        // Titolo
        "STATISTICHE ARCHIVIO".draw(at: CGPoint(x: margin, y: 50), withAttributes: titleAttributes)
        drawLine(context: context, from: CGPoint(x: margin, y: 85), to: CGPoint(x: pageWidth - margin, y: 85))
        
        var y: CGFloat = 110
        
        // Numeri principali
        let stats: [(String, Int)] = [
            ("Rullini", statistics.totalRolls),
            ("Esposizioni", statistics.totalExposures),
            ("Stampe", statistics.totalPrints),
            ("Keepers", statistics.keepersCount)
        ]
        
        let boxWidth: CGFloat = (pageWidth - margin * 2 - 30) / 4
        
        for (index, stat) in stats.enumerated() {
            let x = margin + CGFloat(index) * (boxWidth + 10)
            
            // Box
            let boxRect = CGRect(x: x, y: y, width: boxWidth, height: 70)
            UIColor(white: 0.95, alpha: 1).setFill()
            context.cgContext.fill(boxRect)
            UIColor.lightGray.setStroke()
            context.cgContext.stroke(boxRect)
            
            // Label
            stat.0.draw(at: CGPoint(x: x + 10, y: y + 10), withAttributes: labelAttributes)
            
            // Value
            let valueStr = "\(stat.1)"
            let valueSize = valueStr.size(withAttributes: valueAttributes)
            valueStr.draw(at: CGPoint(x: x + (boxWidth - valueSize.width) / 2, y: y + 30), withAttributes: valueAttributes)
        }
        
        y += 100
        
        // Percentuali
        "Keeper Rate: \(String(format: "%.1f", statistics.keeperRate))%".draw(at: CGPoint(x: margin, y: y), withAttributes: sectionAttributes)
        y += 25
        "Media esposizioni per rullino: \(String(format: "%.1f", statistics.averageExposuresPerRoll))".draw(at: CGPoint(x: margin, y: y), withAttributes: sectionAttributes)
        y += 25
        "Stampe per esposizione: \(String(format: "%.2f", statistics.printsPerExposure))".draw(at: CGPoint(x: margin, y: y), withAttributes: sectionAttributes)
        
        y += 40
        
        // Rullini per stato
        if !statistics.rollsByStatus.isEmpty {
            drawLine(context: context, from: CGPoint(x: margin, y: y), to: CGPoint(x: pageWidth - margin, y: y))
            y += 15
            "Rullini per stato:".draw(at: CGPoint(x: margin, y: y), withAttributes: sectionAttributes)
            y += 25
            
            for (status, count) in statistics.rollsByStatus.sorted(by: { $0.value > $1.value }) {
                "• \(status.rawValue): \(count)".draw(at: CGPoint(x: margin + 10, y: y), withAttributes: labelAttributes)
                y += 18
            }
        }
        
        y += 20
        
        // Per produttore
        if !statistics.rollsByFilmManufacturer.isEmpty {
            drawLine(context: context, from: CGPoint(x: margin, y: y), to: CGPoint(x: pageWidth - margin, y: y))
            y += 15
            "Rullini per produttore:".draw(at: CGPoint(x: margin, y: y), withAttributes: sectionAttributes)
            y += 25
            
            for (manufacturer, count) in statistics.rollsByFilmManufacturer.sorted(by: { $0.value > $1.value }) {
                "• \(manufacturer.rawValue): \(count)".draw(at: CGPoint(x: margin + 10, y: y), withAttributes: labelAttributes)
                y += 18
            }
        }
        
        drawFooter(context: context, pageNumber: 1)
    }
    
    // MARK: - Helper Methods
    
    private func drawLabel(_ text: String, at point: CGPoint, attributes: [NSAttributedString.Key: Any]) {
        text.draw(at: point, withAttributes: attributes)
    }
    
    private func drawValue(_ text: String, at point: CGPoint, attributes: [NSAttributedString.Key: Any]) {
        text.draw(at: point, withAttributes: attributes)
    }
    
    private func drawLine(context: UIGraphicsPDFRendererContext, from: CGPoint, to: CGPoint) {
        context.cgContext.move(to: from)
        context.cgContext.addLine(to: to)
        context.cgContext.strokePath()
    }
    
    private func drawWrappedText(_ text: String, at point: CGPoint, width: CGFloat, attributes: [NSAttributedString.Key: Any]) {
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let framesetter = CTFramesetterCreateWithAttributedString(attributedString)
        
        let path = CGPath(rect: CGRect(x: point.x, y: point.y, width: width, height: 200), transform: nil)
        let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), path, nil)
        CTFrameDraw(frame, context.cgContext)
    }
    
    private func drawFooter(context: UIGraphicsPDFRendererContext, pageNumber: Int) {
        let footerAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8),
            .foregroundColor: UIColor.gray
        ]
        
        let footerText = "Zone System Master - Archivio Analogico"
        footerText.draw(at: CGPoint(x: margin, y: pageHeight - 30), withAttributes: footerAttributes)
        
        if pageNumber > 0 {
            let pageText = "Pag. \(pageNumber)"
            let pageSize = pageText.size(withAttributes: footerAttributes)
            pageText.draw(at: CGPoint(x: pageWidth - margin - pageSize.width, y: pageHeight - 30), withAttributes: footerAttributes)
        }
    }
    
    private func calculateColumnPositions(startX: CGFloat, widths: [CGFloat]) -> [CGFloat] {
        var positions: [CGFloat] = [startX]
        var currentX = startX
        for width in widths.dropLast() {
            currentX += width
            positions.append(currentX)
        }
        return positions
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "it_IT")
        return formatter.string(from: date)
    }
    
    private func formatShortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yy"
        return formatter.string(from: date)
    }
    
    // MARK: - Export to File
    
    func exportRollToFile(_ roll: Roll, directory: URL) async throws -> URL {
        let pdfData = try await exportRoll(roll)
        let fileName = "\(roll.displayName.replacingOccurrences(of: " ", with: "_"))_\(formatDateForFile(roll.dateLoaded)).pdf"
        let fileURL = directory.appendingPathComponent(fileName)
        try pdfData.write(to: fileURL)
        return fileURL
    }
    
    func exportArchiveToFile(rolls: [Roll], directory: URL) async throws -> URL {
        let pdfData = try await exportCompleteArchive(rolls: rolls)
        let fileName = "Archivio_Analogico_\(formatDateForFile(Date())).pdf"
        let fileURL = directory.appendingPathComponent(fileName)
        try pdfData.write(to: fileURL)
        return fileURL
    }
    
    private func formatDateForFile(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

// MARK: - PDF Preview View
struct PDFPreviewView: View {
    let pdfData: Data
    @Environment(\.dismiss) private var dismiss
    @State private var shareSheetPresented = false
    
    var body: some View {
        NavigationStack {
            PDFKitView(data: pdfData)
                .navigationTitle("Anteprima PDF")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Chiudi") {
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button(action: { shareSheetPresented = true }) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
                .sheet(isPresented: $shareSheetPresented) {
                    ShareSheet(items: [pdfData])
                }
        }
    }
}

// MARK: - PDFKit View
struct PDFKitView: UIViewRepresentable {
    let data: Data
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = PDFDocument(data: data)
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        return pdfView
    }
    
    func updateUIView(_ uiView: PDFView, context: Context) {
        uiView.document = PDFDocument(data: data)
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
