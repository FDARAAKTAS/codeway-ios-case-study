import SwiftUI
import Photos
import UIKit

// MARK: - DetailImageLoader
struct DetailImageLoader: View {
    let asset: PHAsset
    @State private var image: UIImage? = nil
    @State private var isLoading = true
    
    private let imageManager = PHImageManager.default()

    var body: some View {
        ZStack {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else if isLoading {
  
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            } else {
                Text("Görüntü Yüklenemedi")
                    .foregroundColor(.white)
                    .font(.headline)
            }
        }
        .onAppear {
            loadImage()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
    
    private func loadImage() {
        guard isLoading else { return }

        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .exact

        let _ = imageManager.requestImage(
            for: asset,
            targetSize: PHImageManagerMaximumSize,
            contentMode: .default,
            options: options
        ) { resultImage, _ in
            DispatchQueue.main.async {
                
                if let image = resultImage {
                    self.image = image
                    self.isLoading = false
                } else {
                    self.isLoading = false
                }
            }
        }
    }
}

// MARK: - ImageDetailView

struct ImageDetailView: View {
    let assets: [PHAsset]
    @State var index: Int

    @Environment(\.dismiss) private var dismiss

    init(assets: [PHAsset], startIndex: Int) {
        self.assets = assets
        self._index = State(initialValue: startIndex)
    }

    var body: some View {
        TabView(selection: $index) {
            ForEach(assets.indices, id: \.self) { i in
                DetailImageLoader(asset: assets[i])
                    .tag(i)
            }
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
        .background(Color.black)
        .ignoresSafeArea()
        .onTapGesture { dismiss() }
    }
}
