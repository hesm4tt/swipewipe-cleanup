import Photos
import SwiftUI
import UIKit

struct AssetThumbnail: View {
    let asset: PHAsset
    var contentMode: PHImageContentMode = .aspectFill
    var cornerRadius: CGFloat = 12
    var diagnosticContext: String? = nil
    @StateObject private var loader: AssetImageLoader

    init(asset: PHAsset, contentMode: PHImageContentMode = .aspectFill, cornerRadius: CGFloat = 12, diagnosticContext: String? = nil) {
        self.asset = asset
        self.contentMode = contentMode
        self.cornerRadius = cornerRadius
        self.diagnosticContext = diagnosticContext
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
        .onAppear { loader.load(asset: asset, size: CGSize(width: 900, height: 1200), context: diagnosticContext) }
        .onChange(of: asset.localIdentifier) { _ in
            loader.load(asset: asset, size: CGSize(width: 900, height: 1200), context: diagnosticContext)
        }
    }
}

@MainActor
final class AssetImageLoader: ObservableObject {
    @Published var image: UIImage?
    private var requestID: PHImageRequestID = PHInvalidImageRequestID
    private var loadedAssetID: String?
    private let loaderTag = UUID().uuidString

    func load(asset: PHAsset, size: CGSize, context: String? = nil) {
        let assetID = asset.localIdentifier
        guard loadedAssetID != assetID else { return }

        if requestID != PHInvalidImageRequestID {
            PHImageManager.default().cancelImageRequest(requestID)
        }
        loadedAssetID = assetID
        image = nil
        if let context {
            DiagnosticLog.shared.record("thumbnail.request", details: [
                "asset": DiagnosticLog.shared.assetTag(for: assetID),
                "context": context,
                "loader": String(loaderTag.prefix(8))
            ])
        }

        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        requestID = PHImageManager.default().requestImage(for: asset, targetSize: size, contentMode: .aspectFit, options: options) { [weak self] image, info in
            let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
            let wasCancelled = (info?[PHImageCancelledKey] as? Bool) ?? false
            let hadError = info?[PHImageErrorKey] != nil
            Task { @MainActor in
                guard let self else { return }
                let isCurrent = self.loadedAssetID == assetID
                if context != nil {
                    DiagnosticLog.shared.record("thumbnail.callback", details: [
                        "asset": DiagnosticLog.shared.assetTag(for: assetID),
                        "context": context ?? "",
                        "current": String(isCurrent),
                        "degraded": String(isDegraded),
                        "cancelled": String(wasCancelled),
                        "error": String(hadError),
                        "image": String(image != nil),
                        "loader": String(self.loaderTag.prefix(8))
                    ])
                }
                guard isCurrent, !wasCancelled, !hadError, let image else { return }
                self.image = image
            }
        }
    }

    deinit {
        if requestID != PHInvalidImageRequestID { PHImageManager.default().cancelImageRequest(requestID) }
    }
}
