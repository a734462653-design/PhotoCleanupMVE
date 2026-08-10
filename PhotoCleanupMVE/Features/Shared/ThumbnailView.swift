import Photos
import SwiftUI
import UIKit

struct ThumbnailView: View {
    let assetIdentifier: String

    @State private var image: UIImage?
    @State private var requestID: PHImageRequestID?

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
        .frame(width: 72, height: 72)
        .clipped()
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
            targetSize: CGSize(width: 144, height: 144),
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
