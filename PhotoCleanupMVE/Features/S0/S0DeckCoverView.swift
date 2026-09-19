import Photos
import SwiftUI
import UIKit

/// IC-162 A（裁定 三）：卡片叠与类别页页头的**宽幅**封面。
///
/// 共享的 `ThumbnailView` 按正方形边长取图并裁成正方形，卡片叠的封面是宽幅
/// （约 381×200），直接用它会糊、构图也不对，故本卡另起一只，取图骨架照
/// `ThumbnailView.load()`，只是不裁正方形：`targetSize` 按宽高分别乘屏幕倍率。
///
/// **两道换图防护**（`ThumbnailView` 自己没有——它 `load()` 开头就
/// `guard image == nil`，同一视图身份下换了标识永不重取，`main` 靠调用点
/// `.id(...)` 兜）：
/// 1. 本视图内部 `.onChange(of: assetIdentifier)` 清图、取消旧请求、重取，
///    回调里比对请求代次，代次不对的结果丢弃；
/// 2. 每个构造点再挂 `.id(assetIdentifier)`。
/// 少了任何一道，把最大的那张移入待删篮后回首页，展开卡仍会显示已进篮那张。
///
/// 取图禁网络（`isNetworkAccessAllowed = false`），取不到图时显示纯色底、
/// 不放占位图标。图层先 `.frame(width:height:)` 后 `.clipped()`（陷阱 24）。
struct S0DeckCoverView: View {
    let assetIdentifier: String?
    let width: CGFloat
    let height: CGFloat

    @Environment(\.displayScale) private var displayScale

    @State private var image: UIImage?
    @State private var requestID: PHImageRequestID?
    /// 请求代次。换标识即自增，旧请求的回调据此丢弃。
    @State private var generation = 0

    /// 请求像素尺寸 = 点尺寸 × 屏幕倍率（与 `ThumbnailView.targetPixelSize` 同口径，
    /// 只是宽高分开）。
    static func targetPixelSize(
        width: CGFloat,
        height: CGFloat,
        displayScale: CGFloat
    ) -> CGSize {
        CGSize(width: width * displayScale, height: height * displayScale)
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                S0DeckMetrics.cardBase
            }
        }
        .frame(width: width, height: height)
        .clipped()
        .accessibilityHidden(true)
        .onAppear(perform: load)
        .onDisappear(perform: cancel)
        .onChange(of: assetIdentifier) { _, _ in
            reload()
        }
    }

    private func load() {
        guard image == nil, let assetIdentifier else {
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
        let currentGeneration = generation
        requestID = PHImageManager.default().requestImage(
            for: asset,
            targetSize: Self.targetPixelSize(
                width: width,
                height: height,
                displayScale: displayScale
            ),
            contentMode: .aspectFill,
            options: options
        ) { value, _ in
            guard let value else {
                return
            }
            DispatchQueue.main.async {
                guard currentGeneration == generation else {
                    return
                }
                image = value
            }
        }
    }

    /// 换标识：先把旧请求取消、代次推进、图清掉，再按新标识取一次。
    private func reload() {
        cancel()
        generation += 1
        image = nil
        load()
    }

    private func cancel() {
        guard let requestID else {
            return
        }
        PHImageManager.default().cancelImageRequest(requestID)
        self.requestID = nil
    }
}
