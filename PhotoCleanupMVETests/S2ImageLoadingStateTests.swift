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

    // IC-093 C0（纯函数）：只升不降的判定本身。
    // 无已显示图像（首次显示 / 资产切换）一律放行；否则按像素面积比较，
    // 候选不低于在显示的才放行。像素尺寸 = 点尺寸 × scale。
    func testIC093C0UpgradeDecisionComparesPixelArea() throws {
        // 无已显示图像：放行。
        XCTAssertTrue(S2ImageUpgradeDecision.shouldReplaceDisplayedImage(
            displayedPixelSize: nil,
            candidatePixelSize: CGSize(width: 90, height: 120)
        ))
        // 更小：拦。
        XCTAssertFalse(S2ImageUpgradeDecision.shouldReplaceDisplayedImage(
            displayedPixelSize: CGSize(width: 3_060, height: 4_080),
            candidatePixelSize: CGSize(width: 90, height: 120)
        ))
        // 相等：放行（边界不严格）。
        XCTAssertTrue(S2ImageUpgradeDecision.shouldReplaceDisplayedImage(
            displayedPixelSize: CGSize(width: 3_060, height: 4_080),
            candidatePixelSize: CGSize(width: 3_060, height: 4_080)
        ))
        // 更大：放行。
        XCTAssertTrue(S2ImageUpgradeDecision.shouldReplaceDisplayedImage(
            displayedPixelSize: CGSize(width: 3_060, height: 4_080),
            candidatePixelSize: CGSize(width: 4_080, height: 5_440)
        ))
        // 反例（CI #161 实测钉住）：4032×3024 = 12 192 768 像素，**小于**
        // 3060×4080 = 12 484 800——单边更宽不等于像素更多，按面积判定即被拦下。
        XCTAssertFalse(S2ImageUpgradeDecision.shouldReplaceDisplayedImage(
            displayedPixelSize: CGSize(width: 3_060, height: 4_080),
            candidatePixelSize: CGSize(width: 4_032, height: 3_024)
        ))
        // 判据是面积而不是逐边：宽变小但总面积更大 → 放行。
        XCTAssertTrue(S2ImageUpgradeDecision.shouldReplaceDisplayedImage(
            displayedPixelSize: CGSize(width: 100, height: 100),
            candidatePixelSize: CGSize(width: 50, height: 300)
        ))
        // 像素尺寸 = 点尺寸 × scale。
        let image = makeSizedImage(width: 90, height: 120)
        XCTAssertEqual(image.scale, 1, accuracy: 0.000_001)
        XCTAssertEqual(
            S2ImageUpgradeDecision.pixelSize(of: image),
            CGSize(width: 90, height: 120)
        )
        let doubled = UIImage(
            cgImage: try XCTUnwrap(image.cgImage),
            scale: 2,
            orientation: .up
        )
        XCTAssertEqual(
            S2ImageUpgradeDecision.pixelSize(of: doubled),
            CGSize(width: 90, height: 120),
            "点尺寸减半、scale 加倍，像素尺寸不变"
        )
    }

    // IC-093 C1（夹具驱动，真机未覆盖）：同资产已显示 3060×4080，再到达 90×120 降质结果。
    // 不上屏（无替换回调）、加载态仍 displayed、产生一条抑制读数且新旧像素尺寸正确。
    func testIC093C1LowerResolutionResultIsSuppressedForSameAsset() {
        let strategy = S2ScriptedImageStrategy()
        let host = makeUpgradeHost(strategy: strategy)
        defer { host.window.isHidden = true }
        let big = makeSizedImage(width: 3_060, height: 4_080)
        let small = makeSizedImage(width: 90, height: 120)

        strategy.deliver(.finalImage(big))
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        XCTAssertEqual(host.recorder.replaced.count, 1)
        XCTAssertEqual(host.recorder.states.last, .displayed)

        // 捏合松手后的新请求（`scaleChangePolicy == .pinchEnded`）。
        host.model.requestRevision += 1
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        XCTAssertEqual(strategy.requestCount, 2)

        strategy.deliver(.degradedPreview(small))
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        XCTAssertEqual(
            host.recorder.replaced.count,
            1,
            "降质结果不上屏：替换回调没有再发生"
        )
        XCTAssertEqual(host.recorder.suppressed.count, 1)
        let suppressed = host.recorder.suppressed.first
        XCTAssertEqual(
            suppressed?.displayedPixelSize,
            CGSize(width: 3_060, height: 4_080)
        )
        XCTAssertEqual(
            suppressed?.candidatePixelSize,
            CGSize(width: 90, height: 120)
        )
        XCTAssertEqual(suppressed?.result.diagnosticName, "degradedPreview")
        XCTAssertEqual(
            host.recorder.states.last,
            .displayed,
            "加载态不变"
        )
        XCTAssertFalse(host.recorder.states.contains(.failed))

        // 同一次请求随后到达的最终图（更大）照常上屏。
        strategy.deliver(.finalImage(big))
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        XCTAssertEqual(host.recorder.replaced.count, 2)
        XCTAssertEqual(host.recorder.suppressed.count, 1)
    }

    // IC-093 C2（夹具驱动，真机未覆盖）：未显示任何图时降质结果照常显示。
    // 决策 28 的首次加载行为不回归。
    func testIC093C2FirstDegradedPreviewStillDisplays() {
        let strategy = S2ScriptedImageStrategy()
        let host = makeUpgradeHost(strategy: strategy)
        defer { host.window.isHidden = true }

        strategy.deliver(.degradedPreview(makeSizedImage(width: 90, height: 120)))
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        XCTAssertEqual(host.recorder.replaced.count, 1)
        XCTAssertTrue(host.recorder.suppressed.isEmpty)
        XCTAssertEqual(host.recorder.states.last, .displayed)
    }

    // IC-093 C3（夹具驱动，真机未覆盖）：显示的是资产 X、请求资产 Y 返回降质图 → 照常替换。
    // 资产切换不受只升不降限制。
    func testIC093C3AssetChangeAllowsLowerResolutionPreview() {
        let strategy = S2ScriptedImageStrategy()
        let host = makeUpgradeHost(assetID: "asset-2", strategy: strategy)
        defer { host.window.isHidden = true }

        strategy.deliver(.finalImage(makeSizedImage(width: 3_060, height: 4_080)))
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        XCTAssertEqual(host.recorder.replaced.count, 1)

        host.model.assetID = "asset-3"
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        XCTAssertEqual(strategy.requestCount(for: "asset-3"), 1)

        strategy.deliver(
            .degradedPreview(makeSizedImage(width: 90, height: 120)),
            to: "asset-3"
        )
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        XCTAssertEqual(
            host.recorder.replaced.count,
            2,
            "换资产后降质预览照常先上屏"
        )
        XCTAssertTrue(host.recorder.suppressed.isEmpty)
    }

    // IC-093 C4（夹具驱动，真机未覆盖）：同资产等尺寸或更高尺寸照常替换。
    func testIC093C4EqualOrHigherResolutionReplaces() {
        let strategy = S2ScriptedImageStrategy()
        let host = makeUpgradeHost(strategy: strategy)
        defer { host.window.isHidden = true }

        strategy.deliver(.finalImage(makeSizedImage(width: 1_000, height: 1_000)))
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        XCTAssertEqual(host.recorder.replaced.count, 1)

        // 等尺寸。
        host.model.requestRevision += 1
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        strategy.deliver(.finalImage(makeSizedImage(width: 1_000, height: 1_000)))
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        XCTAssertEqual(host.recorder.replaced.count, 2)

        // 更高尺寸。
        host.model.requestRevision += 1
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        strategy.deliver(.finalImage(makeSizedImage(width: 2_000, height: 1_000)))
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        XCTAssertEqual(host.recorder.replaced.count, 3)
        XCTAssertTrue(host.recorder.suppressed.isEmpty)
    }

    // IC-093 C5（夹具驱动，真机未覆盖）：已显示图像时高分辨率请求失败不进失败态。
    // 该分支在只升不降判定之前，既有取定（IC-076/077 链、第 123 条）不变。
    func testIC093C5FailureWithDisplayedImageKeepsDisplayedState() {
        let strategy = S2ScriptedImageStrategy()
        let host = makeUpgradeHost(strategy: strategy)
        defer { host.window.isHidden = true }

        strategy.deliver(.finalImage(makeSizedImage(width: 1_000, height: 1_000)))
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        host.model.requestRevision += 1
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))

        strategy.deliver(.failure)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        XCTAssertEqual(host.recorder.states.last, .displayed)
        XCTAssertFalse(host.recorder.states.contains(.failed))
        XCTAssertEqual(host.recorder.replaced.count, 1)
        XCTAssertTrue(
            host.recorder.suppressed.isEmpty,
            "失败没有图像，不进入只升不降判定"
        )
    }

    // IC-093 C6（夹具驱动，真机未覆盖）：`finalImageOnly` 策略下行为与 main 一致——
    // 降质结果被既有 `shouldDisplay` 挡在前面，不进入只升不降判定、不产生抑制读数。
    func testIC093C6FinalImageOnlyPolicyIsUnaffected() {
        let strategy = S2ScriptedImageStrategy()
        let host = makeUpgradeHost(
            strategy: strategy,
            requestStrategy: S2ImageRequestStrategy(
                scaleChangePolicy: .pinchEnded,
                degradedPreviewPolicy: .finalImageOnly
            )
        )
        defer { host.window.isHidden = true }

        // 首次降质：既有策略就不上屏。
        strategy.deliver(.degradedPreview(makeSizedImage(width: 90, height: 120)))
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        XCTAssertTrue(host.recorder.replaced.isEmpty)
        XCTAssertTrue(host.recorder.suppressed.isEmpty)
        // `setLoadState` 只在加载态**变化**时回调，初始态即 `.loading`，
        // 因此「没离开过 loading」的判据是「从未回调过 displayed」而不是 `last == .loading`。
        XCTAssertFalse(host.recorder.states.contains(.displayed))
        XCTAssertFalse(host.recorder.states.contains(.failed))

        // 最终图照常上屏。
        strategy.deliver(.finalImage(makeSizedImage(width: 3_060, height: 4_080)))
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        XCTAssertEqual(host.recorder.replaced.count, 1)

        // 已显示后再来降质：仍由 `shouldDisplay` 挡下，抑制读数为 0。
        host.model.requestRevision += 1
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        strategy.deliver(.degradedPreview(makeSizedImage(width: 90, height: 120)))
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        XCTAssertEqual(host.recorder.replaced.count, 1)
        XCTAssertTrue(host.recorder.suppressed.isEmpty)
    }

    // MARK: - IC-093 夹具

    private final class UpgradeAssetModel: ObservableObject {
        @Published var assetID: String
        @Published var requestRevision: Int

        init(assetID: String, requestRevision: Int) {
            self.assetID = assetID
            self.requestRevision = requestRevision
        }
    }

    private final class UpgradeRecorder {
        var replaced: [S2ImageRequestResult] = []
        var suppressed: [S2ImageReplacementSuppressionReading] = []
        var states: [S2ImageLoadState] = []
    }

    private struct UpgradeHostView: View {
        @ObservedObject var model: UpgradeAssetModel
        let strategy: any S2PhotoImageRequesting
        let requestStrategy: S2ImageRequestStrategy
        let requestBaseSize: CGSize
        let recorder: UpgradeRecorder

        var body: some View {
            S2TemporaryPhotoImageView(
                strategy: strategy,
                assetID: model.assetID,
                requestBaseSize: requestBaseSize,
                requestedScale: 1,
                requestStrategy: requestStrategy,
                requestRevision: model.requestRevision,
                showsOpaqueLoadingBackground: true,
                onReading: { _ in },
                onLoadStateChange: { recorder.states.append($0) },
                onImageReplaced: { recorder.replaced.append($0) },
                onImageReplacementSuppressed: { recorder.suppressed.append($0) }
            )
        }
    }

    private struct UpgradeHost {
        let model: UpgradeAssetModel
        let recorder: UpgradeRecorder
        let window: UIWindow
    }

    /// IC-093：宿主一个真实的 `S2TemporaryPhotoImageView`，资产标识与请求版本可变，
    /// 因此能在同一个视图上驱动「资产切换」与「捏合松手后重新请求」两条真实路径。
    private func makeUpgradeHost(
        assetID: String = "asset-2",
        strategy: S2ScriptedImageStrategy,
        requestStrategy: S2ImageRequestStrategy =
            S2CalibrationConfiguration.factoryPlaceholder.imageRequestStrategy
    ) -> UpgradeHost {
        let model = UpgradeAssetModel(assetID: assetID, requestRevision: 0)
        let recorder = UpgradeRecorder()
        let controller = UIHostingController(
            rootView: UpgradeHostView(
                model: model,
                strategy: strategy,
                requestStrategy: requestStrategy,
                requestBaseSize: physicalSize,
                recorder: recorder
            )
        )
        let window = UIWindow(frame: CGRect(origin: .zero, size: physicalSize))
        window.rootViewController = controller
        window.isHidden = false
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
        XCTAssertEqual(strategy.requestCount, 1)
        return UpgradeHost(model: model, recorder: recorder, window: window)
    }

    /// 生成指定**像素**尺寸、`scale == 1` 的图（与 PhotoKit 返回的图同口径）。
    private func makeSizedImage(width: Int, height: Int) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: width, height: height),
            format: format
        )
        return renderer.image { context in
            UIColor.gray.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
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
        XCTAssertEqual(connections.count, 43)
        let statuses = Dictionary(uniqueKeysWithValues: connections.map {
            ($0.name, $0.specStatus)
        })
        XCTAssertEqual(statuses["degradedPreviewPolicy"], .decided)
        XCTAssertEqual(statuses["scaleChangeRequestPolicy"], .decided)
        XCTAssertEqual(connections.filter { $0.specStatus == .decided }.count, 34)
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
