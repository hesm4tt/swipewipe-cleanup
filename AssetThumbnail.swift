import Photos
import SwiftUI
import UIKit

struct AssetThumbnail: View {
    let asset: PHAsset
    var contentMode: PHImageContentMode = .aspectFill
    var cornerRadius: CGFloat = 12
    @StateObject private var loader: AssetImageLoader

    init(asset: PHAsset, contentMode: PHImageContentMode = .aspectFill, cornerRadius: CGFloat = 12) {
        self.asset = asset
        self.contentMode = contentMode
        self.cornerRadius = cornerRadius
        _loader = StateObject(wrappedValue: AssetImageLoader())
    }

    var body: some View {
        GeometryReader { proxy in
            Group {
                if let image = loader.image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: contentMode == .aspectFit ? .fit : .fill)
                } else {
                    Rectangle().fill(Color.white.opacity(0.08))
                        .overlay { Image(systemName: "photo").foregroundStyle(.white.opacity(0.3)) }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        .onAppear { loader.load(asset: asset, size: CGSize(width: 900, height: 1200)) }
        .onChange(of: asset.localIdentifier) { _ in
            loader.load(asset: asset, size: CGSize(width: 900, height: 1200))
        }
    }
}

@MainActor
final class AssetImageLoader: ObservableObject {
    @Published var image: UIImage?
    private var requestID: PHImageRequestID = PHInvalidImageRequestID
    private var loadedAssetID: String?

    func load(asset: PHAsset, size: CGSize) {
        let assetID = asset.localIdentifier
        guard loadedAssetID != assetID else { return }

        if requestID != PHInvalidImageRequestID {
            PHImageManager.default().cancelImageRequest(requestID)
        }
        loadedAssetID = assetID
        image = nil

        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        requestID = PHImageManager.default().requestImage(for: asset, targetSize: size, contentMode: .aspectFit, options: options) { [weak self] image, _ in
            guard let image else { return }
            Task { @MainActor in
                guard let self, self.loadedAssetID == assetID else { return }
                self.image = image
            }
        }
    }

    deinit {
        if requestID != PHInvalidImageRequestID { PHImageManager.default().cancelImageRequest(requestID) }
    }
}
