import Photos
import SwiftUI

struct AssetThumbnail: View {
    let asset: PHAsset
    var contentMode: PHImageContentMode = .aspectFill
    var cornerRadius: CGFloat = 12
    @StateObject private var loader: AssetImageLoader

    init(asset: PHAsset, contentMode: PHImageContentMode = .aspectFill, cornerRadius: CGFloat = 12) {
        self.asset = asset
        self.contentMode = contentMode
        self.cornerRadius = cornerRadius
        _loader = StateObject(wrappedValue: AssetImageLoader(asset: asset))
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
        .onAppear { loader.load(size: CGSize(width: 900, height: 1200)) }
    }
}

@MainActor
final class AssetImageLoader: ObservableObject {
    @Published var image: UIImage?
    private let asset: PHAsset
    private var requestID: PHImageRequestID = PHInvalidImageRequestID

    init(asset: PHAsset) { self.asset = asset }

    func load(size: CGSize) {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        requestID = PHImageManager.default().requestImage(for: asset, targetSize: size, contentMode: .aspectFit, options: options) { [weak self] image, _ in
            guard let image else { return }
            Task { @MainActor in self?.image = image }
        }
    }

    deinit {
        if requestID != PHInvalidImageRequestID { PHImageManager.default().cancelImageRequest(requestID) }
    }
}
