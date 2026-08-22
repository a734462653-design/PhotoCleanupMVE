import Photos
import SwiftUI
import UIKit
import XCTest
@testable import PhotoCleanupMVE

final class S2ImageLoadingStateTests: XCTestCase {
    // IC-077 R1：协议层假实现覆盖五种结果；结果到图像/降质标记的映射；PhotoKit 回调映射。
    func testIC077R1RequestResultCoversFiveOutcomes() {
        let degraded = UIImage()
        let final = UIImage()
        let strategy = S2ScriptedImageStrategy()
        var received: [S2ImageRequestResult] = []
        let outcomes: [S2ImageRequestResult] = [
            .degradedPreview(degraded),
            .finalImage(final),
            .failure,
            .cancelled,
            .assetUnavailable
        ]
        for outcome in outcomes {
            strategy.requestImage(
                assetID: "asset-1",
                targetSize: CGSize(width: 10, height: 10),
                requestStrategy: S2CalibrationConfiguration.factoryPlaceholder
                    .imageRequestStrategy
            ) { received.append($0) }
            strategy.deliver(outcome)
            if outcome.isDegraded {
                strategy.deliver(.finalImage(final))
                received.removeLast()
            }
        }
        XCTAssertEqual(received, outcomes)
        XCTAssertEqual(strategy.requestCount, 5)

        XCTAssertTrue(S2ImageRequestResult.degradedPreview(degraded).image === degraded)
        XCTAssertTrue(S2ImageRequestResult.degradedPreview(degraded).isDegraded)
        XCTAssertTrue(S2ImageRequestResult.finalImage(final).image === final)
        XCTAssertFalse(S2ImageRequestResult.finalImage(final).isDegraded)
        for outcome in [S2ImageRequestResult.failure, .cancelled, .assetUnavailable] {
            XCTAssertNil(outcome.image)
            XCTAssertFalse(outcome.isDegraded)
        }

        XCTAssertEqual(
            S2TemporaryPhotoKitImageStrategy.result(
                image: nil,
                information: [PHImageCancelledKey: true]
            ),
            .cancelled
        )
        XCTAssertEqual(
            S2TemporaryPhotoKitImageStrategy.result(image: nil, information: nil),
            .failure
        )
        XCTAssertEqual(
            S2TemporaryPhotoKitImageStrategy.result(
                image: nil,
                information: [PHImageErrorKey: NSError(domain: "t", code: 1)]
            ),
            .failure
        )
        XCTAssertEqual(
            S2TemporaryPhotoKitImageStrategy.result(
                image: degraded,
                information: [PHImageResultIsDegradedKey: true]
            ),
            .degradedPreview(degraded)
        )
        XCTAssertEqual(
            S2TemporaryPhotoKitImageStrategy.result(
                image: final,
                information: [PHImageResultIsDegradedKey: false]
            ),
            .finalImage(final)
        )
    }

    // IC-077 G124：出厂 degradedPreviewPolicy=.display、scaleChangeRequestPolicy=.pinchEnded；
    // 两项规格状态 decided；登记表 36（decided 21 / placeholder 15）。
    func testIC077G124FactoryImageStrategyAndRegistry() {
        let factory = S2CalibrationConfiguration.factoryPlaceholder
        XCTAssertEqual(factory.degradedPreviewPolicy, .display)
        XCTAssertEqual(factory.scaleChangeRequestPolicy, .pinchEnded)
        XCTAssertEqual(
            factory.imageRequestStrategy,
            S2ImageRequestStrategy(
                scaleChangePolicy: .pinchEnded,
                degradedPreviewPolicy: .display
            )
        )
        XCTAssertTrue(factory.exportText().contains("degradedPreviewPolicy=display"))

        let connections = S2CalibrationConfiguration.parameterConnections
        XCTAssertEqual(connections.count, 36)
        let statuses = Dictionary(uniqueKeysWithValues: connections.map {
            ($0.name, $0.specStatus)
        })
        XCTAssertEqual(statuses["degradedPreviewPolicy"], .decided)
        XCTAssertEqual(statuses["scaleChangeRequestPolicy"], .decided)
        XCTAssertEqual(connections.filter { $0.specStatus == .decided }.count, 21)
        XCTAssertEqual(connections.filter { $0.specStatus == .placeholder }.count, 15)
    }
}

/// 测试用脚本化策略：记录请求，按调用方安排逐个交付结果；返回递增的请求标识，
/// 记录被取消的有效标识。
final class S2ScriptedImageStrategy: S2PhotoImageRequesting {
    struct Request {
        let id: PHImageRequestID
        let assetID: String
        let targetSize: CGSize
        let handler: (S2ImageRequestResult) -> Void
    }

    private(set) var requests: [Request] = []
    private(set) var cancelledIDs: [PHImageRequestID] = []
    private var pending: [Request] = []
    private var nextID: PHImageRequestID = 1

    var requestCount: Int {
        requests.count
    }

    func requestCount(for assetID: String) -> Int {
        requests.filter { $0.assetID == assetID }.count
    }

    var pendingAssetIDs: [String] {
        pending.map(\.assetID)
    }

    @discardableResult
    func requestImage(
        assetID: String,
        targetSize: CGSize,
        requestStrategy: S2ImageRequestStrategy,
        resultHandler: @escaping (S2ImageRequestResult) -> Void
    ) -> PHImageRequestID {
        let request = Request(
            id: nextID,
            assetID: assetID,
            targetSize: targetSize,
            handler: resultHandler
        )
        nextID += 1
        requests.append(request)
        pending.append(request)
        return request.id
    }

    func cancelImageRequest(_ requestID: PHImageRequestID) {
        guard requestID != PHInvalidImageRequestID else {
            return
        }
        cancelledIDs.append(requestID)
        if let index = pending.firstIndex(where: { $0.id == requestID }) {
            let request = pending.remove(at: index)
            request.handler(.cancelled)
        }
    }

    /// 交付给最早一个未完成请求；最终图、失败、失效与取消结束该请求，
    /// 降质预览保持请求未完成（可继续交付最终图）。
    func deliver(_ result: S2ImageRequestResult) {
        guard let request = pending.first else {
            return XCTFail("没有未完成的图片请求")
        }
        if !result.isDegraded {
            pending.removeFirst()
        }
        request.handler(result)
    }

    /// 交付给指定资产最早一个未完成请求。
    func deliver(_ result: S2ImageRequestResult, to assetID: String) {
        guard let index = pending.firstIndex(where: { $0.assetID == assetID }) else {
            return XCTFail("资产 \(assetID) 没有未完成的图片请求")
        }
        let request = pending[index]
        if !result.isDegraded {
            pending.remove(at: index)
        }
        request.handler(result)
    }

    func reset() {
        requests.removeAll()
        cancelledIDs.removeAll()
    }
}
