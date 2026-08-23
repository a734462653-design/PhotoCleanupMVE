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

    // IC-077 G126（宿主图片视图，夹具驱动）：pending → degraded → final 中降质图已显示；
    // pending → failure / assetUnavailable 进入失败态；cancelled 不记读数、不进入失败态。
    func testIC077G126HostedImageViewShowsDegradedThenFinalAndFailureStates() {
        let degraded = run(sequence: [.degradedPreview(UIImage()), .finalImage(UIImage())])
        XCTAssertEqual(
            degraded.readings,
            [.pending, .degradedPreview, .finalImage]
        )
        XCTAssertEqual(degraded.states, [.displayed])
        XCTAssertEqual(degraded.statesAfterFirstDelivery, [.displayed])

        let failed = run(sequence: [.failure])
        XCTAssertEqual(failed.readings, [.pending, .failure])
        XCTAssertEqual(failed.states, [.failed])

        let unavailable = run(sequence: [.assetUnavailable])
        XCTAssertEqual(unavailable.readings, [.pending, .assetUnavailable])
        XCTAssertEqual(unavailable.states, [.failed])

        let cancelled = run(sequence: [.cancelled])
        XCTAssertEqual(cancelled.readings, [.pending])
        XCTAssertEqual(cancelled.states, [])
    }

    // IC-077 G126（状态机层）：失败态读数存在时上滑标记仍生效，翻页、取消标记照常。
    func testIC077G126FailureStateKeepsSwipeUpMarkingAndPaging() {
        let machine = makeMachine()
        machine.recordImageRequestReading(
            S2ImageRequestReading(trigger: .initial, returnType: .failure)
        )
        XCTAssertEqual(machine.lastImageRequestReading?.returnType, .failure)
        let target = machine.currentAssetID
        XCTAssertTrue(machine.completeMainDrag(
            translation: CGSize(width: 0, height: -120),
            duration: 0.1,
            startedOffset: .zero,
            viewportSize: physicalSize,
            fittedSize: physicalSize
        ))
        XCTAssertTrue(machine.pendingDeletionAssetIDs.contains(target))
        XCTAssertEqual(machine.currentIndex, 2)

        machine.recordImageRequestReading(
            S2ImageRequestReading(trigger: .assetChange, returnType: .assetUnavailable)
        )
        XCTAssertTrue(machine.handleNativePageChange(to: 1))
        XCTAssertTrue(machine.handleSwipeDown())
        XCTAssertFalse(machine.pendingDeletionAssetIDs.contains(target))
    }

    // IC-077 R3（状态机层）：双击进入与退出各递增一次请求信号；everyScaleChange 策略下不递增。
    func testIC077R3DoubleTapBumpsImageRequestRevisionOncePerSettle() {
        let machine = makeMachine()
        XCTAssertEqual(machine.imageRequestRevision, 0)
        XCTAssertTrue(machine.handleNativeDoubleTap(targetScale: 2))
        XCTAssertEqual(machine.imageRequestRevision, 1)
        XCTAssertEqual(machine.imageRequestAssetID, machine.currentAssetID)
        XCTAssertTrue(machine.handleNativeDoubleTap(targetScale: 2))
        XCTAssertEqual(machine.imageRequestRevision, 2)
        XCTAssertTrue(machine.handleDoubleTap(
            at: CGPoint(x: 100, y: 200),
            viewportSize: physicalSize,
            assetAspectRatio: 0.5
        ))
        XCTAssertEqual(machine.imageRequestRevision, 3)

        var everyChange = S2CalibrationConfiguration.factoryPlaceholder
        everyChange.scaleChangeRequestPolicy = .everyScaleChange
        XCTAssertTrue(machine.applyCalibration(everyChange))
        XCTAssertTrue(machine.handleNativeDoubleTap(targetScale: 2))
        XCTAssertEqual(machine.imageRequestRevision, 3)
    }

    // IC-077 G128（R4）：`D ⊄ A` 的交接 → enterS2 返回 false、route 仍为 .s1、s2Machine 为 nil、
    // S1 状态机对象与会话存储同一；随后合法交接仍可进入 S2。
    @MainActor
    func testIC077G128HandoffValidationFailureStaysInS1() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let assets = (1...3).map { day in
            S1PhotoAssetSnapshot(
                identifier: "资产-\(day)",
                creationDate: calendar.date(
                    from: DateComponents(year: 2026, month: 8, day: day, hour: 12)
                )
            )
        }
        let coordinator = CleanupCoordinator(
            photoLibrary: PhotoLibraryService(
                s1Source: S1PhotoLibrarySource(
                    authorizationStatus: { .authorized },
                    fetchAssets: { assets },
                    fetchAssetCollections: { _, _ in [] }
                )
            ),
            assetActionService: FakeAssetActionService(albums: []),
            recentAlbumStore: S2InMemoryRecentAlbumStore()
        )
        XCTAssertTrue(coordinator.enterS1(sessionID: "会话-077"))
        let s1Machine = try XCTUnwrap(coordinator.s1Machine)
        let request = try XCTUnwrap(s1Machine.currentReadRequest)
        let ranges = try coordinator.readS1Ranges(groupedBy: .month).get()
        XCTAssertTrue(s1Machine.completeRangeRead(.success(ranges), for: request))
        let range = try XCTUnwrap(ranges.first)
        let valid = try XCTUnwrap(s1Machine.makeS2Handoff(for: range.id))
        let storeBefore = coordinator.sessionStore
        let s1StoreBefore = s1Machine.sessionStore

        let invalid = S1ToS2Handoff(
            sessionID: valid.sessionID,
            rangeDisplayInformation: valid.rangeDisplayInformation,
            orderedAssetIDs: valid.orderedAssetIDs,
            currentAssetID: valid.currentAssetID,
            pendingDeletionAssetIDs: ["资产-不在范围内"],
            sessionMergedPendingDeletionCountProvider: { 0 }
        )
        XCTAssertFalse(coordinator.enterS2(from: invalid))
        XCTAssertEqual(coordinator.route, .s1)
        XCTAssertNil(coordinator.s2Machine)
        XCTAssertTrue(coordinator.s1Machine === s1Machine)
        XCTAssertEqual(coordinator.sessionStore, storeBefore)
        XCTAssertEqual(s1Machine.sessionStore, s1StoreBefore)
        XCTAssertNil(coordinator.message)

        XCTAssertTrue(coordinator.enterS2(from: valid))
        XCTAssertEqual(coordinator.route, .s2)
        XCTAssertNotNil(coordinator.s2Machine)
    }

    private struct HostedRun {
        let readings: [S2ImageReturnType]
        let states: [S2ImageLoadState]
        let statesAfterFirstDelivery: [S2ImageLoadState]
    }

    private func run(sequence: [S2ImageRequestResult]) -> HostedRun {
        let strategy = S2ScriptedImageStrategy()
        let recorder = HostedRecorder()
        let view = S2TemporaryPhotoImageView(
            strategy: strategy,
            assetID: "asset-2",
            requestBaseSize: physicalSize,
            requestedScale: 1,
            requestStrategy: S2CalibrationConfiguration.factoryPlaceholder
                .imageRequestStrategy,
            requestRevision: 0,
            showsOpaqueLoadingBackground: true,
            onReading: { recorder.readings.append($0.returnType) },
            onLoadStateChange: { recorder.states.append($0) }
        )
        let controller = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(origin: .zero, size: physicalSize))
        window.rootViewController = controller
        window.isHidden = false
        defer { window.isHidden = true }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        XCTAssertEqual(strategy.requestCount, 1)

        var statesAfterFirstDelivery: [S2ImageLoadState] = []
        for (index, result) in sequence.enumerated() {
            if result == .cancelled {
                strategy.cancelImageRequest(strategy.requests[0].id)
            } else {
                strategy.deliver(result)
            }
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
            if index == 0 {
                statesAfterFirstDelivery = recorder.states
            }
        }
        return HostedRun(
            readings: recorder.readings,
            states: recorder.states,
            statesAfterFirstDelivery: statesAfterFirstDelivery
        )
    }

    private final class HostedRecorder {
        var readings: [S2ImageReturnType] = []
        var states: [S2ImageLoadState] = []
    }

    private let physicalSize = CGSize(width: 390, height: 844)

    private func makeMachine(
        orderedAssetIDs: [String] = ["asset-1", "asset-2", "asset-3"],
        currentIndex: Int = 1,
        scale: CGFloat = 1
    ) -> S2StateMachine {
        S2StateMachine(
            entry: S2EntryContext(
                sessionID: "session-077",
                rangeDisplayInformation: S2RangeDisplayInformation(
                    rangeID: "range-077",
                    displayName: "测试范围",
                    totalAssetCount: orderedAssetIDs.count
                ),
                orderedAssetIDs: orderedAssetIDs,
                currentAssetID: orderedAssetIDs[currentIndex],
                pendingDeletionAssetIDs: [],
                sessionMergedPendingDeletionCountProvider: { 0 }
            ),
            initialPresentation: S2InitialPresentation(
                interfaceVisibility: .visible,
                scale: scale,
                viewportOffset: .zero
            ),
            parameters: S2CalibrationConfiguration.factoryPlaceholder
                .resolvedParameters!,
            imageRequestStrategy: S2CalibrationConfiguration.factoryPlaceholder
                .imageRequestStrategy,
            initialFavoriteAssetIDs: [],
            initialRecentAlbum: nil,
            pendingDeletionDidChange: { _ in }
        )!
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
        // IC-085：横栏参数废止 1 项、新增 5 项并全部 decided：37 → 41，23 → 34，14 → 7；
        // R3 新增 placeholder 1 项：41 → 42，placeholder 7 → 8。
        // IC-088 合并：+ IC-081 乘数（placeholder）1 项：42 → 43，placeholder 8 → 9。
        // IC-090 R1：+ bottomStripCornerRadius（decided）：43 → 44，decided 34 → 35。
        XCTAssertEqual(connections.count, 44)
        let statuses = Dictionary(uniqueKeysWithValues: connections.map {
            ($0.name, $0.specStatus)
        })
        XCTAssertEqual(statuses["degradedPreviewPolicy"], .decided)
        XCTAssertEqual(statuses["scaleChangeRequestPolicy"], .decided)
        XCTAssertEqual(connections.filter { $0.specStatus == .decided }.count, 35)
        XCTAssertEqual(connections.filter { $0.specStatus == .placeholder }.count, 9)
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
