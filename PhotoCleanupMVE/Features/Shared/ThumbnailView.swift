import Photos
import SwiftUI
import UIKit

struct ThumbnailView: View {
    let assetIdentifier: String
    /// IC-134 B：边长（点）。默认 72 与既有调用点行为一致。
    var sideLength: CGFloat = 72
    /// IC-134 B：请求像素倍率。默认 2 与既有「72 点请求 144 像素」一致。
    var displayScale: CGFloat = 2
    /// IC-134 B：裁切圆角。默认 0 与既有行为一致（直角 + clipped）。
    var cornerRadius: CGFloat = 0

    @State private var image: UIImage?
    @State private var requestID: PHImageRequestID?

    /// IC-134 B：请求像素尺寸 = 边长 × 倍率（断言 7 钉住 2×／3×）。
    static func targetPixelSize(
        sideLength: CGFloat,
        displayScale: CGFloat
    ) -> CGSize {
        CGSize(
            width: sideLength * displayScale,
            height: sideLength * displayScale
        )
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "photo")
                    .resizable()
                    .scaledToFit()
                    .padding()
            }
        }
        .frame(width: sideLength, height: sideLength)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .onAppear(perform: load)
        .onDisappear(perform: cancel)
    }

    private func load() {
        guard image == nil else {
            return
        }
        let fetch = PHAsset.fetchAssets(
            withLocalIdentifiers: [assetIdentifier],
            options: nil
        )
        guard let asset = fetch.firstObject else {
            return
        }
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = false
        requestID = PHImageManager.default().requestImage(
            for: asset,
            targetSize: Self.targetPixelSize(
                sideLength: sideLength,
                displayScale: displayScale
            ),
            contentMode: .aspectFill,
            options: options
        ) { value, _ in
            guard let value else {
                return
            }
            DispatchQueue.main.async {
                image = value
            }
        }
    }

    private func cancel() {
        guard let requestID else {
            return
        }
        PHImageManager.default().cancelImageRequest(requestID)
        self.requestID = nil
    }
}
