import Foundation
import Photos
import UIKit

final class ScanViewModel: ObservableObject {
    
    // MARK: - Published State (UI Binding)
    
    @Published var groups: [PhotoGroup: [PHAsset]] = [:]
    @Published var others: [PHAsset] = []
    
    @Published var progress: Double = 0.0
    @Published var processed: Int = 0
    @Published var total: Int = 0
    @Published var isScanning = false
    
    // MARK: - Internal State
    
    private var lastSaveDate = Date.distantPast
    private let saveInterval: TimeInterval = 1.0
    private let scanQueue = DispatchQueue(
        label: "scan.queue",
        qos: .userInitiated,
        attributes: .concurrent
    )
    private let updateQueue = DispatchQueue(
        label: "scan.update.queue",
        qos: .utility
    )
    
    private var isCancelled = false
    private var lastUIUpdate = Date()
    private let uiUpdateInterval: TimeInterval = 0.1
    
    // MARK: - Init
    
    init() {
        loadSavedAsync()
    }
    
    // MARK: - Public API
    func startScan(resetExisting: Bool = false) {
        isScanning = true
        isCancelled = false
        lastUIUpdate = Date()
        
        let fetch = PHAsset.fetchAssets(with: .image, options: nil)
        total = fetch.count
        
        guard total > 0 else {
            isScanning = false
            return
        }
        if resetExisting || groups.isEmpty {
            groups = Dictionary(
                uniqueKeysWithValues: PhotoGroup.allCases.map { ($0, []) }
            )
            others = []
            processed = 0
            progress = 0
        }
        let existingIDs = Set(
            groups.values.flatMap { $0.map(\.localIdentifier) } +
            others.map(\.localIdentifier)
        )
        processed = existingIDs.count
        progress = total > 0 ? Double(processed) / Double(total) : 0

        var assetsToProcess: [PHAsset] = []
        fetch.enumerateObjects { asset, _, _ in
            if !existingIDs.contains(asset.localIdentifier) {
                assetsToProcess.append(asset)
            }
        }

        guard !assetsToProcess.isEmpty else {
            isScanning = false
            return
        }

        var tempGroups: [PhotoGroup: [PHAsset]] = groups
        var tempOthers: [PHAsset] = others
        var currentProcessed = processed
        
        let dispatchGroup = DispatchGroup()
        let batchSize = 100
        
        for batchStart in stride(from: 0, to: assetsToProcess.count, by: batchSize) {
            if isCancelled { break }
            
            let batchEnd = min(batchStart + batchSize, assetsToProcess.count)
            let batch = Array(assetsToProcess[batchStart..<batchEnd])
            
            dispatchGroup.enter()
            scanQueue.async { [weak self] in
                guard let self = self, !self.isCancelled else {
                    dispatchGroup.leave()
                    return
                }
                var batchGroups: [PhotoGroup: [PHAsset]] = [:]
                var batchOthers: [PHAsset] = []
                
                for asset in batch {
                    if self.isCancelled { break }
                    
                    let h = asset.reliableHash()
                    if let group = PhotoGroup.group(for: h) {
                        batchGroups[group, default: []].append(asset)
                    } else {
                        batchOthers.append(asset)
                    }
                }
                self.updateQueue.sync {
                    for (key, value) in batchGroups {
                        tempGroups[key, default: []].append(contentsOf: value)
                    }
                    tempOthers.append(contentsOf: batchOthers)
                    currentProcessed += batch.count
                    
                    let now = Date()

                    if now.timeIntervalSince(self.lastUIUpdate) >= self.uiUpdateInterval {
                        self.lastUIUpdate = now
                        let snapshotGroups = tempGroups
                        let snapshotOthers = tempOthers
                        let snapshotProcessed = currentProcessed
                        let snapshotTotal = self.total
                        
                        DispatchQueue.main.async {
                            self.groups = snapshotGroups
                            self.others = snapshotOthers
                            self.processed = snapshotProcessed
                            self.progress = snapshotTotal > 0
                                ? Double(snapshotProcessed) / Double(snapshotTotal)
                                : 0
                        }
                        if now.timeIntervalSince(self.lastSaveDate) >= self.saveInterval {
                            self.lastSaveDate = now
                            self.save()
                        }
                    }
                }
                
                dispatchGroup.leave()
            }
        }
        dispatchGroup.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            
            if !self.isCancelled {
                self.groups = tempGroups
                self.others = tempOthers
                self.processed = currentProcessed
                self.progress = self.total > 0
                    ? Double(currentProcessed) / Double(self.total)
                    : 0
                self.save()
            }
            
            self.isScanning = false
        }
    }

    func cancelScan() {
        isCancelled = true
        isScanning = false
    }
    
    // MARK: - Persistence
    
    private func save() {
        updateQueue.async { [weak self] in
            guard let self = self else { return }
            
            let model = SavedScanData(
                processed: self.processed,
                total: self.total,
                groups: self.groups.mapValues { $0.map { $0.localIdentifier } },
                others: self.others.map { $0.localIdentifier }
            )
            
            do {
                let data = try JSONEncoder().encode(model)
                try data.write(to: self.saveURL)
            } catch {
                print("Failed to save scan data: \(error)")
            }
        }
    }

    private func loadSavedAsync() {
        updateQueue.async { [weak self] in
            guard let self = self else { return }
            
            do {
                let data = try Data(contentsOf: self.saveURL)
                let saved = try JSONDecoder().decode(SavedScanData.self, from: data)
                var loadedGroups: [PhotoGroup: [PHAsset]] = [:]
                for (group, ids) in saved.groups {
                    let fetch = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
                    var assets: [PHAsset] = []
                    fetch.enumerateObjects { asset, _, _ in
                        assets.append(asset)
                    }
                    loadedGroups[group] = assets
                }
                
                var loadedOthers: [PHAsset] = []
                let othersFetch = PHAsset.fetchAssets(withLocalIdentifiers: saved.others, options: nil)
                othersFetch.enumerateObjects { asset, _, _ in
                    loadedOthers.append(asset)
                }
                
                DispatchQueue.main.async {
                    self.groups = loadedGroups
                    self.others = loadedOthers
                    self.processed = saved.processed
                    self.total = saved.total
                    self.progress = self.total > 0
                        ? Double(self.processed) / Double(self.total)
                        : 0
                }
            } catch {
                print("No saved data found or failed to load: \(error)")
            }
        }
    }
    
    private var saveURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("scanData.json")
    }
}

// MARK: - Persistence Model

struct SavedScanData: Codable {
    let processed: Int
    let total: Int
    let groups: [PhotoGroup: [String]]
    let others: [String]
}

