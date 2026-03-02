// PrintJobManager.swift
// Zone System Master - Instax BLE Integration
// Gestione coda stampe e tracking progresso

import Foundation
import Combine
import UIKit

// MARK: - PrintJobManager

@MainActor
public final class PrintJobManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public private(set) var queue: [InstaxPrintJob] = []
    @Published public private(set) var currentJob: InstaxPrintJob?
    @Published public private(set) var isProcessing = false
    @Published public private(set) var totalPrinted = 0
    @Published public private(set) var totalFailed = 0
    
    // MARK: - Private Properties
    
    private let bleManager: InstaxBLEManager
    private var cancellables = Set<AnyCancellable>()
    private var printTask: Task<Void, Never>?
    
    /// Abilita stampa (disabilitata di default per sicurezza)
    public var printEnabled = false
    
    /// Numero massimo di retry
    public var maxRetries = 3
    
    /// Callback per eventi di stampa
    public var onPrintStarted: ((InstaxPrintJob) -> Void)?
    public var onPrintProgress: ((InstaxPrintJob, Double) -> Void)?
    public var onPrintCompleted: ((InstaxPrintJob) -> Void)?
    public var onPrintFailed: ((InstaxPrintJob, InstaxError) -> Void)?
    
    // MARK: - Initialization
    
    public init(bleManager: InstaxBLEManager = InstaxBLEManager()) {
        self.bleManager = bleManager
        setupBindings()
    }
    
    // MARK: - Public Methods
    
    /// Aggiunge un job alla coda
    @discardableResult
    public func addJob(image: UIImage, model: InstaxPrinterModel) -> InstaxPrintJob {
        let job = InstaxPrintJob(image: image, model: model)
        queue.append(job)
        processQueueIfNeeded()
        return job
    }
    
    /// Aggiunge un job alla coda con stato iniziale
    public func addJob(_ job: InstaxPrintJob) {
        queue.append(job)
        processQueueIfNeeded()
    }
    
    /// Rimuove un job dalla coda
    public func removeJob(id: UUID) {
        queue.removeAll { $0.id == id }
    }
    
    /// Rimuove tutti i job dalla coda
    public func clearQueue() {
        queue.removeAll()
        currentJob = nil
        printTask?.cancel()
    }
    
    /// Cancella il job corrente
    public func cancelCurrentJob() {
        printTask?.cancel()
        if var job = currentJob {
            job.state = .cancelled
            currentJob = job
        }
    }
    
    /// Processa la coda se necessario
    public func processQueueIfNeeded() {
        guard !isProcessing, !queue.isEmpty else { return }
        
        printTask = Task { @MainActor [weak self] in
            await self?.processNextJob()
        }
    }
    
    /// Stampa un'immagine immediatamente (bypassa la coda)
    public func printImmediately(image: UIImage, model: InstaxPrinterModel) async throws {
        guard bleManager.connectionState == .connected else {
            throw InstaxError.notConnected
        }
        
        guard printEnabled else {
            throw InstaxError.printCancelled
        }
        
        let job = InstaxPrintJob(image: image, model: model)
        try await executePrintJob(job)
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // Monitora stato connessione
        bleManager.$connectionState
            .sink { [weak self] state in
                if case .connected = state {
                    self?.processQueueIfNeeded()
                }
            }
            .store(in: &cancellables)
    }
    
    private func processNextJob() async {
        guard !queue.isEmpty else {
            isProcessing = false
            currentJob = nil
            return
        }
        
        isProcessing = true
        
        // Prendi il primo job
        var job = queue.removeFirst()
        currentJob = job
        
        do {
            try await executePrintJob(job)
            job.state = .completed
            totalPrinted += 1
            onPrintCompleted?(job)
        } catch {
            job.retryCount += 1
            
            if job.retryCount < maxRetries {
                // Rimetti in coda per retry
                queue.insert(job, at: 0)
                job.state = .error(.unknown)
                try? await Task.sleep(nanoseconds: UInt64(InstaxConstants.retryDelay * 1_000_000_000))
            } else {
                job.state = .error(error as? InstaxError ?? .unknown)
                totalFailed += 1
                onPrintFailed?(job, error as? InstaxError ?? .unknown)
            }
        }
        
        currentJob = job
        
        // Processa il prossimo job
        if !Task.isCancelled {
            await processNextJob()
        }
    }
    
    private func executePrintJob(_ job: InstaxPrintJob) async throws {
        guard printEnabled else {
            throw InstaxError.printCancelled
        }
        
        var mutableJob = job
        mutableJob.state = .preparing
        currentJob = mutableJob
        onPrintStarted?(mutableJob)
        
        // 1. Preprocessa l'immagine
        let preprocessedData = try await ImagePreprocessor.shared.preprocessImage(
            job.image,
            for: job.model
        )
        
        guard printEnabled else {
            throw InstaxError.printCancelled
        }
        
        // 2. Invia comando inizio download
        mutableJob.state = .sending(progress: 0)
        currentJob = mutableJob
        
        let startPacket = InstaxPacket(
            eventType: .printImageDownloadStart,
            subCode: 0x00,
            payload: Data()
        )
        
        _ = try await bleManager.sendPacket(startPacket, waitForResponse: true)
        
        // 3. Invia dati immagine in chunk
        let chunkSize = job.model.chunkSize
        let totalChunks = Int(ceil(Double(preprocessedData.count) / Double(chunkSize)))
        
        for (index, chunk) in preprocessedData.chunks(ofCount: chunkSize).enumerated() {
            guard printEnabled else {
                throw InstaxError.printCancelled
            }
            
            guard !Task.isCancelled else {
                throw InstaxError.printCancelled
            }
            
            let dataPacket = InstaxPacket(
                eventType: .printImageDownloadData,
                subCode: 0x00,
                payload: chunk
            )
            
            _ = try await bleManager.sendPacket(dataPacket, waitForResponse: true)
            
            // Aggiorna progresso
            let progress = Double(index + 1) / Double(totalChunks)
            mutableJob.state = .sending(progress: progress)
            currentJob = mutableJob
            onPrintProgress?(mutableJob, progress)
        }
        
        // 4. Invia comando fine download
        let endPacket = InstaxPacket(
            eventType: .printImageDownloadEnd,
            subCode: 0x00,
            payload: Data()
        )
        
        _ = try await bleManager.sendPacket(endPacket, waitForResponse: true)
        
        // 5. Invia comando stampa
        guard printEnabled else {
            throw InstaxError.printCancelled
        }
        
        mutableJob.state = .printing
        currentJob = mutableJob
        
        let printPacket = InstaxPacket(
            eventType: .printImage,
            subCode: 0x80,
            payload: Data()
        )
        
        _ = try await bleManager.sendPacket(printPacket, waitForResponse: true)
        
        // Attendi completamento stampa
        try await waitForPrintCompletion()
    }
    
    private func waitForPrintCompletion() async throws {
        // Attendi che la stampa sia completata
        // La stampante invierà notifiche durante il processo
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(InstaxConstants.printTimeout * 1_000_000_000))
            }
            
            group.addTask { [weak self] in
                // Attendi che lo stato cambi o timeout
                while let self = self {
                    if case .completed = self.currentJob?.state {
                        return
                    }
                    try await Task.sleep(nanoseconds: 500_000_000) // 500ms
                }
            }
            
            try await group.next()!
            group.cancelAll()
        }
    }
}

// MARK: - Data Extension

extension Data {
    /// Divide i dati in chunk di dimensione specificata
    func chunks(ofCount chunkSize: Int) -> [Data] {
        var chunks: [Data] = []
        var offset = 0
        
        while offset < count {
            let length = min(chunkSize, count - offset)
            let chunk = subdata(in: offset..<(offset + length))
            chunks.append(chunk)
            offset += length
        }
        
        return chunks
    }
}

// MARK: - InstaxError Extension

extension InstaxError {
    static var notConnected: InstaxError {
        .connectionFailed
    }
}
