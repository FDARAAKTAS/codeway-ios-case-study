import Foundation
import Photos
import UIKit
import Combine

class GroupDetailViewModel: ObservableObject {

    @Published var images: [UIImage?] = []
    @Published var assets: [PHAsset] = []

    let groupName: String
    private let group: PhotoGroup?
    private weak var scanViewModel: ScanViewModel?

    private let imageManager = PHCachingImageManager()
    private let targetSize = CGSize(width: 300, height: 300)
    
    private var imageRequests: [Int: PHImageRequestID] = [:]
    private let requestQueue = DispatchQueue(label: "image.request.queue")
    private var cancellables = Set<AnyCancellable>()

    init(scanViewModel: ScanViewModel, group: PhotoGroup?, groupName: String) {
        self.scanViewModel = scanViewModel
        self.group = group
        self.groupName = groupName
        if let group = group {
            self.assets = scanViewModel.groups[group] ?? []
        } else {
            self.assets = scanViewModel.others
        }
        
        self.images = Array(repeating: nil, count: assets.count)
        
        setupObservers()
        loadInitialImages()
    }

    private func setupObservers() {
        guard let scanViewModel = scanViewModel else { return }
        
        if let group = group {
            scanViewModel.$groups
                .map { $0[group] ?? [] }
                .removeDuplicates(by: areAssetsEqual)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] newAssets in
                    self?.updateAssets(newAssets)
                }
                .store(in: &cancellables)
        } else {
            scanViewModel.$others
                .removeDuplicates(by: areAssetsEqual)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] newAssets in
                    self?.updateAssets(newAssets)
                }
                .store(in: &cancellables)
        }
    }
    private func areAssetsEqual(_ old: [PHAsset], _ new: [PHAsset]) -> Bool {
        guard old.count == new.count else { return false }
        
        let oldIds = old.map { $0.localIdentifier }
        let newIds = new.map { $0.localIdentifier }
        
        return oldIds == newIds
    }
    
    private func updateAssets(_ newAssets: [PHAsset]) {
        let oldCount = assets.count
        assets = newAssets
        
        if newAssets.count > oldCount {
            let additionalCount = newAssets.count - oldCount
            images.append(contentsOf: Array(repeating: nil, count: additionalCount))
            for i in oldCount..<newAssets.count {
                loadImage(at: i)
            }
        } else if newAssets.count < oldCount {
            images = Array(images.prefix(newAssets.count))
        }
    }
    
    deinit {
        cancelAllRequests()
    }
    
    private func loadInitialImages() {
        let initialBatchSize = min(30, assets.count)
        for index in 0..<initialBatchSize {
            loadImage(at: index)
        }
    }
    
    func loadImageIfNeeded(at index: Int) {
        guard index < assets.count, index < images.count, images[index] == nil else { return }
        loadImage(at: index)
    }

    private func loadImage(at index: Int) {
        guard index < assets.count else { return }
        
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false
        
        let asset = assets[index]

        let requestID = imageManager.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        ) { [weak self] img, info in
            guard let self = self else { return }
            
            if let error = info?[PHImageErrorKey] as? Error {
                print("Failed to load image at index \(index): \(error)")
            }
            
            if let cancelled = info?[PHImageCancelledKey] as? Bool, cancelled {
                return
            }
            
            let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
            
            DispatchQueue.main.async {
                if index < self.images.count {
                    if !isDegraded || self.images[index] == nil {
                        self.images[index] = img
                    }
                }
                
                if !isDegraded {
                    self.requestQueue.async { [weak self] in
                        self?.imageRequests.removeValue(forKey: index)
                    }
                }
            }
        }
        
        requestQueue.async { [weak self] in
            self?.imageRequests[index] = requestID
        }
    }
    
    func cancelImageRequest(at index: Int) {
        requestQueue.sync {
            if let requestID = imageRequests[index] {
                imageManager.cancelImageRequest(requestID)
                imageRequests.removeValue(forKey: index)
            }
        }
    }
    
    private func cancelAllRequests() {
        requestQueue.sync {
            for requestID in imageRequests.values {
                imageManager.cancelImageRequest(requestID)
            }
            imageRequests.removeAll()
        }
    }
    
    func preloadImages(around visibleIndices: [Int]) {
        let preloadCount = 10
        
        guard let minIndex = visibleIndices.min(),
              let maxIndex = visibleIndices.max() else { return }
        
        let preloadStart = max(0, minIndex - preloadCount)
        let preloadEnd = min(assets.count - 1, maxIndex + preloadCount)
        guard preloadStart <= preloadEnd else { return }
        
        for index in preloadStart...preloadEnd {
            loadImageIfNeeded(at: index)
        }
        
        requestQueue.sync {
            let indicesToCancel = imageRequests.keys.filter { index in
                index < preloadStart || index > preloadEnd
            }
            
            for index in indicesToCancel {
                if let requestID = imageRequests[index] {
                    imageManager.cancelImageRequest(requestID)
                    imageRequests.removeValue(forKey: index)
                }
            }
        }
    }
    
    func startCaching(for indices: [Int]) {
        let assetsToCache = indices.compactMap { index in
            index < assets.count ? assets[index] : nil
        }
        
        imageManager.startCachingImages(
            for: assetsToCache,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: nil
        )
    }
    
    func stopCaching(for indices: [Int]) {
        let assetsToStop = indices.compactMap { index in
            index < assets.count ? assets[index] : nil
        }
        
        imageManager.stopCachingImages(
            for: assetsToStop,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: nil
        )
    }
}
