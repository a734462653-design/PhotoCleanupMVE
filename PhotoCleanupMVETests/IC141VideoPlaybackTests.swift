import AVFoundation
import SwiftUI
import UIKit
import XCTest
@testable import PhotoCleanupMVE

/// 断言 7 的哨兵：遵循快照排除协议，并在 `isHidden` 的 didSet 里记录每一次
/// 写入，好在捕获**期间**就看到它确实退场了。
private final class SnapshotSentinelView: UIView, S2SnapshotExcludedView {
    private(set) var hiddenLog: [Bool] = []

    override var isHidden: Bool {
        didSet {
            hiddenLog.append(isHidden)
        }
    }

    func resetLog() {
        hiddenLog = []
    }
}

/// IC-141：视频播放（自动静音循环、浮框接线、快照取封面帧）。
///
/// **本卡只做视频**：`S2LivePhotoPlayback.swift` 零改动，实况行为与 IC-140 相同。
/// 断言 1～4、10～13 是纯 reducer／口径断言；断言 7～9 是分页器夹具断言，
/// 与真机手势序列不同源（陷阱 1），真机落点由 H65 十项兜底。
final class IC141VideoPlaybackTests: XCTestCase {
    private let physicalSize = CGSize(width: 300, height: 600)

    private var screenAspectRatio: CGFloat {
        physicalSize.width / physicalSize.height
    }

    // MARK: - 断言 1：入口不自动播，停稳才播且先静音

    func testIC141A_EntryAssetDoesNotAutoPlayAndSettleMutesBeforePlaying() {
        var machine = S2VideoPlaybackMachine()

        // 入口 A：停稳也不起播。
        XCTAssertTrue(machine.handle(.entered(assetID: "A")).isEmpty)
        XCTAssertTrue(
            machine.handle(.pagingSettled).isEmpty,
            "入口那段在首次停稳就自动播了"
        )

        // 翻到 B：就绪后停稳恰起播一次。
        let becameB = machine.handle(
            .becameCurrent(assetID: "B", neighbours: ["A"])
        )
        let generationB = tryUnwrap(requestGeneration(in: becameB, for: "B"))
        XCTAssertTrue(
            machine.handle(
                .requestSucceeded(assetID: "B", generation: generationB)
            ).isEmpty,
            "尚未停稳就起播了"
        )

        let settled = machine.handle(.pagingSettled)
        XCTAssertEqual(plays(settled), ["B"], "停稳未恰起播一次")
        // 决策 58：声音恒关——静音必须排在起播之前，不留出声窗口。
        let muteIndex = tryUnwrap(
            settled.firstIndex(of: .setMuted(assetID: "B", muted: true))
        )
        let playIndex = tryUnwrap(
            settled.firstIndex(of: .play(assetID: "B"))
        )
        XCTAssertLessThan(muteIndex, playIndex, "起播早于静音")
        XCTAssertTrue(
            settled.contains(.seek(assetID: "B", fraction: 0)),
            "自动播放未从 0 开始"
        )

        // 同页反复停稳不重播。
        XCTAssertTrue(machine.handle(.pagingSettled).isEmpty)
        XCTAssertEqual(machine.state(for: "B"), .playing)
    }

    // MARK: - 断言 2：代次守卫、半径与持有上限

    func testIC141A_LateCallbackIsDroppedAndRadiusHoldsAtMostThreePlayers() {
        var machine = S2VideoPlaybackMachine()
        _ = machine.handle(.entered(assetID: nil))

        // 未就绪停稳 → 无播；就绪即补播。
        let becameB = machine.handle(
            .becameCurrent(assetID: "B", neighbours: [])
        )
        let generationB = tryUnwrap(requestGeneration(in: becameB, for: "B"))
        XCTAssertTrue(machine.handle(.pagingSettled).isEmpty, "未就绪就起播")
        XCTAssertEqual(
            plays(
                machine.handle(
                    .requestSucceeded(assetID: "B", generation: generationB)
                )
            ),
            ["B"],
            "就绪未补播"
        )

        // 旧代次：B 退出半径后迟到的成功回调无效果、状态不变。
        var stale = S2VideoPlaybackMachine()
        _ = stale.handle(.entered(assetID: nil))
        let staleBecameB = stale.handle(
            .becameCurrent(assetID: "B", neighbours: [])
        )
        let staleGeneration = tryUnwrap(
            requestGeneration(in: staleBecameB, for: "B")
        )
        let becameC = stale.handle(
            .becameCurrent(assetID: "C", neighbours: [])
        )
        XCTAssertTrue(
            becameC.contains(
                .cancelRequest(assetID: "B", generation: staleGeneration)
            ),
            "退出半径的在飞请求未取消"
        )
        XCTAssertTrue(
            stale.handle(
                .requestSucceeded(assetID: "B", generation: staleGeneration)
            ).isEmpty,
            "旧代次的迟到成功仍产生了效果"
        )
        XCTAssertEqual(stale.state(for: "B"), .idle, "旧代次改动了已退页的状态")

        // 半径与上限：连翻五页后持有集合 ≤ 3，且恰是当前页 + 两邻居。
        var rolling = S2VideoPlaybackMachine()
        _ = rolling.handle(.entered(assetID: nil))
        let order = ["A", "B", "C", "D", "E"]
        var cancelled: [String] = []
        for (index, assetID) in order.enumerated() {
            let neighbours = [index - 1, index + 1]
                .filter { order.indices.contains($0) }
                .map { order[$0] }
            let effects = rolling.handle(
                .becameCurrent(assetID: assetID, neighbours: neighbours)
            )
            cancelled.append(contentsOf: cancels(effects))
            XCTAssertLessThanOrEqual(
                rolling.heldAssetIDs.count,
                S2MediaMetrics.videoInstanceCap,
                "持有数超过上限"
            )
        }
        XCTAssertEqual(rolling.heldAssetIDs, ["D", "E"])
        XCTAssertEqual(cancelled, ["A", "B", "C"], "被退页未逐个取消在飞请求")
    }

    // MARK: - 断言 3：翻走回起点、翻回重播、至多一段在播

    func testIC141A_LeavingAPageParksItAndReturningPlaysFromTheStart() {
        var machine = S2VideoPlaybackMachine()
        _ = machine.handle(.entered(assetID: nil))
        let becameB = machine.handle(
            .becameCurrent(assetID: "B", neighbours: [])
        )
        let generationB = tryUnwrap(requestGeneration(in: becameB, for: "B"))
        _ = machine.handle(
            .requestSucceeded(assetID: "B", generation: generationB)
        )
        _ = machine.handle(.pagingSettled)
        XCTAssertEqual(machine.playingAssetIDs, ["B"])

        // 翻走：暂停、回 0、静音三件齐，且 B 仍在半径内故不卸载。
        let becameC = machine.handle(
            .becameCurrent(assetID: "C", neighbours: ["B"])
        )
        XCTAssertTrue(becameC.contains(.pause(assetID: "B")))
        XCTAssertTrue(becameC.contains(.seek(assetID: "B", fraction: 0)))
        XCTAssertTrue(becameC.contains(.setMuted(assetID: "B", muted: true)))
        XCTAssertTrue(machine.playingAssetIDs.isEmpty, "翻走后仍有段在播")

        // 翻回 B：停稳即从头再播。
        _ = machine.handle(.becameCurrent(assetID: "B", neighbours: ["C"]))
        let replayed = machine.handle(.pagingSettled)
        XCTAssertEqual(plays(replayed), ["B"], "翻回未重播")
        XCTAssertTrue(replayed.contains(.seek(assetID: "B", fraction: 0)))
        XCTAssertEqual(machine.playingAssetIDs.count, 1, "在播集合大于 1")
    }

    // MARK: - 断言 4：循环

    func testIC141A_ReachingTheEndLoopsOnlyWhilePlaying() {
        var machine = S2VideoPlaybackMachine()
        _ = machine.handle(.entered(assetID: nil))
        let becameB = machine.handle(
            .becameCurrent(assetID: "B", neighbours: [])
        )
        let generationB = tryUnwrap(requestGeneration(in: becameB, for: "B"))
        _ = machine.handle(
            .requestSucceeded(assetID: "B", generation: generationB)
        )
        _ = machine.handle(.pagingSettled)

        let looped = machine.handle(.reachedEnd(assetID: "B"))
        XCTAssertEqual(
            looped,
            [.seek(assetID: "B", fraction: 0), .play(assetID: "B")],
            "播到尾未回 0 续播"
        )
        XCTAssertEqual(machine.state(for: "B"), .playing, "循环后不再是在播态")

        // 暂停态收到尾事件不动（用户暂停在末帧、或翻走后的迟到通知）。
        _ = machine.handle(.userToggledPlayPause)
        XCTAssertEqual(machine.state(for: "B"), .paused)
        XCTAssertTrue(
            machine.handle(.reachedEnd(assetID: "B")).isEmpty,
            "暂停态被尾事件唤醒"
        )
    }

    // MARK: - 断言 5：几何纪律与播放动作单一写入点（源码扫描带正对照）

    func testIC141B_PlaybackLayerWritesNoGeometryAndDrivesPlaybackFromOnePlace() {
        guard let text = sourceText(
            "PhotoCleanupMVE/Features/S2/S2VideoPlayback.swift"
        ) else {
            return XCTFail("读不到视频播放源码")
        }

        // 不设约束、不设自动尺寸掩码（串按名字拼，免得本断言抓到自己）。
        for banned in [
            "translatesAutoresizing" + "MaskIntoConstraints",
            "NSLayout" + "Constraint"
        ] {
            XCTAssertEqual(
                occurrences(of: banned, in: text),
                0,
                "播放层自己写了约束：\(banned)"
            )
        }

        // 唯一的几何写入是 `layoutSubviews` 里从 bounds 读的那一次。
        XCTAssertEqual(occurrences(of: ".frame = ", in: text), 1)
        XCTAssertEqual(occurrences(of: ".frame = bounds", in: text), 1)
        let layoutBody = layoutSubviewsBody(in: text)
        XCTAssertFalse(layoutBody.isEmpty, "未截取到 layoutSubviews 函数体")
        XCTAssertEqual(
            occurrences(of: "CATransaction.setDisableActions(true)", in: text),
            1
        )
        XCTAssertEqual(
            occurrences(
                of: "CATransaction.setDisableActions(true)",
                in: layoutBody
            ),
            1,
            "隐式动画开关不在 layoutSubviews 里"
        )
        XCTAssertEqual(occurrences(of: ".frame = bounds", in: layoutBody), 1)

        // 图层隐式动画三键各关一次（正对照：三键都在）。
        for key in ["\"bounds\"", "\"position\"", "\"frame\""] {
            XCTAssertEqual(
                occurrences(of: key, in: text),
                1,
                "图层隐式动画未关 \(key)"
            )
        }

        // 陷阱 19：播放动作只在协调器效果执行处，各一个写入点。
        XCTAssertEqual(occurrences(of: "player.play()", in: text), 1)
        XCTAssertEqual(occurrences(of: "player.pause()", in: text), 1)
        XCTAssertEqual(occurrences(of: "player.seek(", in: text), 1)

        guard let pager = sourceText(
            "PhotoCleanupMVE/Features/S2/S2NativePhotoPager.swift"
        ) else {
            return XCTFail("读不到分页器源码")
        }
        XCTAssertEqual(
            occurrences(of: "writePhotoGeometry", in: pager),
            5,
            "几何链的声明或调用点数量变了"
        )
    }

    // MARK: - 断言 7：两个快照都取封面帧

    func testIC141B_SnapshotsHideExcludedLayersAndRestoreTheirOriginalValue() {
        let machine = makeMachine()
        let controller = makePagerController()
        applyPager(controller, machine: machine)
        let window = attachWindow(to: controller)
        defer { window.isHidden = true }
        let page = tryUnwrap(controller.pageControllers[machine.currentIndex])
        let content = tryUnwrap(page.zoomScrollView.presentationContentView)

        let sentinel = SnapshotSentinelView()
        sentinel.frame = CGRect(x: 0, y: 0, width: 10, height: 10)
        content.addSubview(sentinel)
        sentinel.resetLog()

        // P1 残影快照：捕获期间隐藏，捕获后恢复调用前的值（false）。
        //
        // **不断言快照非 nil**：离屏夹具里 `snapshotView(afterScreenUpdates:)`
        // 取不到已渲染内容，有无播放层都返回 nil（#279 实测）。那一半留给
        // H65 第 6 项真机判定；这里钉的是「退场与恢复」本身，以及下面那条
        // 「有无播放层结果一致」的不变性。
        let withLayer = page.makeMarkAfterimageSnapshot(in: controller.view)
        XCTAssertEqual(
            sentinel.hiddenLog,
            [true, false],
            "残影快照期间播放层未退场或未恢复原值"
        )
        XCTAssertFalse(sentinel.isHidden)

        // P2 双击快照：同样的一进一出。
        sentinel.resetLog()
        _ = page.makeDoubleTapSnapshot()
        XCTAssertEqual(
            sentinel.hiddenLog,
            [true, false],
            "双击快照期间播放层未退场或未恢复原值"
        )
        XCTAssertFalse(sentinel.isHidden)

        // 正对照：调用前本来就隐着的层，结束后仍然隐着（恢复的是原值，
        // 不是一律置 false）。此时两次快照都不该再写 isHidden。
        sentinel.isHidden = true
        sentinel.resetLog()
        _ = page.makeMarkAfterimageSnapshot(in: controller.view)
        _ = page.makeDoubleTapSnapshot()
        XCTAssertTrue(sentinel.isHidden, "快照把本来隐着的层放出来了")
        XCTAssertEqual(sentinel.hiddenLog, [], "对已隐藏的层做了多余写入")

        // 照片页路径（无遵循者）：行为与基线相同。夹具取不到快照内容，
        // 故钉**不变性**——带播放层与不带播放层的结果一致，说明这层包裹
        // 没有改变快照本身的成败。
        sentinel.removeFromSuperview()
        let withoutLayer = page.makeMarkAfterimageSnapshot(in: controller.view)
        XCTAssertEqual(
            withLayer == nil,
            withoutLayer == nil,
            "播放层的有无改变了残影快照的取到与否"
        )
        XCTAssertEqual(
            sentinel.hiddenLog,
            [],
            "已移出子树的层仍被快照写了 isHidden"
        )
    }

    // MARK: - 断言 8：挂起中一律禁 Nx 平移

    func testIC141B_PanStaysDisabledWhileSuspendedEvenWhenZoomedIn() {
        let machine = makeMachine()
        let controller = makePagerController()
        applyPager(controller, machine: machine)
        let window = attachWindow(to: controller)
        defer { window.isHidden = true }
        let page = tryUnwrap(controller.pageControllers[machine.currentIndex])
        let zoom = page.zoomScrollView
        XCTAssertGreaterThan(
            zoom.maximumZoomScale,
            zoom.minimumZoomScale,
            "夹具的最大缩放不大于最小缩放，放大态正对照无法成立"
        )

        // 未挂起时按 P3 原规则：1x 禁、Nx 开（正对照两种缩放各一）。
        zoom.isPanSuspended = false
        zoom.updatePanAvailability()
        XCTAssertFalse(zoom.panGestureRecognizer.isEnabled, "1x 时平移未禁")

        zoom.applyNativeState(scale: 2, viewportOffset: .zero)
        XCTAssertGreaterThan(
            zoom.zoomScale,
            zoom.minimumZoomScale + 0.000_001,
            "夹具未真正进入放大态"
        )
        zoom.updatePanAvailability()
        XCTAssertTrue(zoom.panGestureRecognizer.isEnabled, "Nx 时平移未开")

        // 挂起中：即便在放大态也一律禁（IC-140 上报 (a) 的修复点）。
        zoom.isPanSuspended = true
        zoom.updatePanAvailability()
        XCTAssertFalse(
            zoom.panGestureRecognizer.isEnabled,
            "挂起中放大态的平移仍被打开"
        )

        // 清除后回到 P3 原规则。
        zoom.isPanSuspended = false
        zoom.updatePanAvailability()
        XCTAssertTrue(zoom.panGestureRecognizer.isEnabled)

        zoom.applyNativeState(scale: 1, viewportOffset: .zero)
        zoom.isPanSuspended = true
        zoom.updatePanAvailability()
        XCTAssertFalse(zoom.panGestureRecognizer.isEnabled)
    }

    // MARK: - 断言 9：缩放与双击过渡不重建播放层

    func testIC141B_RepeatedContentMountDoesNotRebindThePlaybackLayer() {
        let playback = S2VideoPlaybackCoordinator()
        let host = UIHostingController(
            rootView: AnyView(
                S2VideoPlaybackContentView(
                    playback: playback,
                    assetID: "asset-2"
                )
                .id("asset-2")
            )
        )
        let window = UIWindow(
            frame: CGRect(origin: .zero, size: physicalSize)
        )
        window.rootViewController = host
        window.isHidden = false
        defer { window.isHidden = true }
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.03))

        let surface = tryUnwrap(playback.registeredSurface(for: "asset-2"))
        let hostView = tryUnwrap(surface as? S2VideoHostView)
        XCTAssertEqual(playback.surfaceRegistrationCount, 1)
        XCTAssertEqual(playback.surfaceUnregistrationCount, 0)

        // 同一资产重挂内容树（`applyPhotoContent` 在缩放路径上做的就是这件事）：
        // 走 `updateUIView` 的同资产分支，既不注销也不改绑。
        host.rootView = AnyView(
            S2VideoPlaybackContentView(
                playback: playback,
                assetID: "asset-2"
            )
            .id("asset-2")
        )
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.03))

        XCTAssertTrue(
            playback.registeredSurface(for: "asset-2") === surface,
            "重挂内容树换掉了播放层实例"
        )
        XCTAssertEqual(playback.surfaceRegistrationCount, 1, "播放层被重复登记")
        XCTAssertEqual(playback.surfaceUnregistrationCount, 0, "播放层被注销")
        XCTAssertEqual(hostView.rebindCount, 0, "同资产重挂触发了改绑")
    }

    func testIC141B_ZoomAndDoubleTapTransitionKeepThePlaybackLayerAlive() {
        let machine = makeMachine()
        let controller = makePagerController()
        applyPager(controller, machine: machine)
        let window = attachWindow(to: controller)
        defer { window.isHidden = true }
        let page = tryUnwrap(controller.pageControllers[machine.currentIndex])
        let content = tryUnwrap(page.zoomScrollView.presentationContentView)

        // 播放层按产品口径登记，再放进页内容子树里。
        let playback = S2VideoPlaybackCoordinator()
        let hostView = S2VideoHostView(assetID: machine.currentAssetID)
        hostView.frame = content.bounds
        content.addSubview(hostView)
        playback.register(surface: hostView, for: machine.currentAssetID)
        XCTAssertEqual(playback.surfaceRegistrationCount, 1)

        // 放大：走既有的原生状态下发路径，不直写 zoomScale。
        page.zoomScrollView.applyNativeState(scale: 2, viewportOffset: .zero)
        page.view.setNeedsLayout()
        page.view.layoutIfNeeded()

        // 双击过渡：开始与收口都走既有 harness 路径。
        let started = page.startDoubleTapTransition(
            enteringNx: false,
            targetScale: 1,
            at: CGPoint(x: physicalSize.width / 2, y: physicalSize.height / 2),
            configuration: .factoryPlaceholder,
            durationOverrideSeconds: 0
        )
        XCTAssertTrue(started, "双击过渡未起飞，断言 9 无从成立")
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))

        XCTAssertTrue(
            playback.registeredSurface(for: machine.currentAssetID)
                === hostView,
            "缩放或双击过渡换掉了播放层实例"
        )
        XCTAssertEqual(playback.surfaceRegistrationCount, 1, "播放层被重复登记")
        XCTAssertEqual(playback.surfaceUnregistrationCount, 0, "播放层被注销")
        XCTAssertEqual(hostView.rebindCount, 0, "缩放触发了改绑")
        // 缩放不进状态机：不产生 pause／unload，状态原样。
        XCTAssertEqual(
            playback.playbackState(for: machine.currentAssetID),
            .idle,
            "缩放路径改动了播放状态"
        )
    }

    // MARK: - 断言 10：浮框改为状态驱动

    func testIC141C_VideoBarModelFollowsPlaybackStateOnVideoPagesOnly() {
        let playing = S2VideoPlaybackSnapshot(
            isPlaying: true,
            isMuted: true,
            isScrubbing: false,
            currentSeconds: 5,
            durationSeconds: 20
        )
        let bar = tryUnwrap(
            S2VideoBarPresentation.make(
                mediaKind: .video,
                interfaceVisibility: .visible,
                playback: playing
            )
        )
        XCTAssertEqual(bar.playSymbolName, S2MediaMetrics.videoBarPauseSymbol)
        XCTAssertEqual(bar.muteSymbolName, S2MediaMetrics.videoBarMutedSymbol)
        XCTAssertEqual(bar.progress, 0.25, accuracy: 0.000_001)
        XCTAssertTrue(bar.acceptsHits, "浮框仍不接点击")

        // 暂停 + 有声：两个符号一起换。
        let paused = S2VideoPlaybackSnapshot(
            isPlaying: false,
            isMuted: false,
            isScrubbing: false,
            currentSeconds: 0,
            durationSeconds: 20
        )
        let pausedBar = tryUnwrap(
            S2VideoBarPresentation.make(
                mediaKind: .video,
                interfaceVisibility: .visible,
                playback: paused
            )
        )
        XCTAssertEqual(
            pausedBar.playSymbolName,
            S2MediaMetrics.videoBarPlaySymbol
        )
        XCTAssertEqual(
            pausedBar.muteSymbolName,
            S2MediaMetrics.videoBarUnmutedSymbol
        )

        // 照片页、实况页、隐藏态都不构造常态浮框。
        for kind in [S2MediaKind.photo, .live] {
            XCTAssertNil(
                S2VideoBarPresentation.make(
                    mediaKind: kind,
                    interfaceVisibility: .visible,
                    playback: playing
                ),
                "\(kind) 构造了视频浮框"
            )
        }
        XCTAssertNil(
            S2VideoBarPresentation.make(
                mediaKind: .video,
                interfaceVisibility: .hidden,
                playback: playing
            )
        )

        // 拖动中常态浮框让位给拖动态（断言 11）。
        let scrubbing = S2VideoPlaybackSnapshot(
            isPlaying: false,
            isMuted: true,
            isScrubbing: true,
            currentSeconds: 5,
            durationSeconds: 20
        )
        XCTAssertNil(
            S2VideoBarPresentation.make(
                mediaKind: .video,
                interfaceVisibility: .visible,
                playback: scrubbing
            ),
            "拖动态仍构造了常态浮框"
        )
    }

    // MARK: - 断言 11：拖动态

    func testIC141C_ScrubbingHidesChromeTransientlyAndRestoresOnRelease() {
        // 状态机侧：进入前 `.visible` → 进入 `.hidden` → 结束回 `.visible`。
        let machine = makeMachine()
        XCTAssertEqual(machine.interfaceVisibility, .visible)
        machine.beginTransientInterfaceHide()
        XCTAssertEqual(machine.interfaceVisibility, .hidden)
        XCTAssertEqual(machine.recordedVisibilityBeforeTransientHide, .visible)
        machine.endTransientInterfaceHide()
        XCTAssertEqual(machine.interfaceVisibility, .visible)
        XCTAssertNil(machine.recordedVisibilityBeforeTransientHide)

        // 进入前本来就隐着：结束后仍然隐着。
        XCTAssertTrue(machine.handleSingleTap())
        XCTAssertEqual(machine.interfaceVisibility, .hidden)
        machine.beginTransientInterfaceHide()
        XCTAssertEqual(machine.interfaceVisibility, .hidden)
        machine.endTransientInterfaceHide()
        XCTAssertEqual(machine.interfaceVisibility, .hidden, "临时隐藏把 V 放了出来")

        // 重入：begin 两次要 end 两次才恢复。
        XCTAssertTrue(machine.handleSingleTap())
        XCTAssertEqual(machine.interfaceVisibility, .visible)
        machine.beginTransientInterfaceHide()
        machine.beginTransientInterfaceHide()
        XCTAssertEqual(machine.transientInterfaceHideDepth, 2)
        machine.endTransientInterfaceHide()
        XCTAssertEqual(machine.interfaceVisibility, .hidden, "第一次 end 就恢复了")
        machine.endTransientInterfaceHide()
        XCTAssertEqual(machine.interfaceVisibility, .visible)
        XCTAssertEqual(machine.transientInterfaceHideDepth, 0)

        // 拖动态口径：只有两端读数与圆点，无播放键无静音键。
        let scrubbing = S2VideoPlaybackSnapshot(
            isPlaying: false,
            isMuted: true,
            isScrubbing: true,
            currentSeconds: 61,
            durationSeconds: 125
        )
        let scrub = tryUnwrap(
            S2VideoScrubPresentation.make(
                mediaKind: .video,
                playback: scrubbing
            )
        )
        XCTAssertEqual(scrub.currentText, "1:01")
        XCTAssertEqual(scrub.durationText, "2:05")
        XCTAssertEqual(scrub.fontSize, S2MediaMetrics.videoBarTimeFontSize)
        XCTAssertEqual(scrub.trailingOpacity, 0.72, accuracy: 0.000_001)
        XCTAssertEqual(
            scrub.trailingOpacity,
            S2MediaMetrics.videoBarTimeTrailingOpacity
        )
        // 不看 `V`——拖动态是 `V=隐藏` 期间唯一可见的 chrome。
        XCTAssertNotNil(
            S2VideoScrubPresentation.make(
                mediaKind: .video,
                playback: scrubbing
            )
        )
        XCTAssertNil(
            S2VideoScrubPresentation.make(
                mediaKind: .photo,
                playback: scrubbing
            )
        )

        // reducer 侧：拖动开始暂停，结束回拖动前状态。
        var playback = S2VideoPlaybackMachine()
        _ = playback.handle(.entered(assetID: nil))
        let became = playback.handle(
            .becameCurrent(assetID: "B", neighbours: [])
        )
        let generation = tryUnwrap(requestGeneration(in: became, for: "B"))
        _ = playback.handle(
            .requestSucceeded(assetID: "B", generation: generation)
        )
        _ = playback.handle(.pagingSettled)
        XCTAssertEqual(playback.state(for: "B"), .playing)

        XCTAssertEqual(
            playback.handle(.scrubBegan),
            [.pause(assetID: "B")],
            "拖动开始未暂停"
        )
        XCTAssertEqual(
            playback.handle(.scrubMoved(fraction: 0.5)),
            [.seek(assetID: "B", fraction: 0.5)]
        )
        // 越界的 fraction 被夹到 [0, 1]。
        XCTAssertEqual(
            playback.handle(.scrubMoved(fraction: 1.4)),
            [.seek(assetID: "B", fraction: 1)]
        )
        XCTAssertEqual(
            playback.handle(.scrubEnded),
            [.play(assetID: "B")],
            "拖动前在播，松手未续播"
        )

        // 拖动前是暂停：松手保持暂停。
        _ = playback.handle(.userToggledPlayPause)
        XCTAssertEqual(playback.state(for: "B"), .paused)
        XCTAssertTrue(playback.handle(.scrubBegan).isEmpty, "暂停态拖动仍发了暂停")
        XCTAssertTrue(playback.handle(.scrubEnded).isEmpty, "暂停态松手自己播了")
        XCTAssertEqual(playback.state(for: "B"), .paused)
    }

    func testIC141C_ScrubHandlersAreTheOnlyTransientHideCallSites() {
        guard let text = sourceText(
            "PhotoCleanupMVE/Features/S2/S2View.swift"
        ) else {
            return XCTFail("读不到 S2View 源码")
        }
        XCTAssertEqual(
            occurrences(of: "machine.beginTransientInterfaceHide()", in: text),
            1,
            "临时隐藏的调用点不止拖动开始一处"
        )
        XCTAssertEqual(
            occurrences(of: "machine.endTransientInterfaceHide()", in: text),
            1,
            "临时隐藏的恢复点不止拖动结束一处"
        )
        // IC-143 B 起多出**一个**收口点：异常终止的无条件归零。
        // 三个写入点各恰一处，仍然「只有拖动路径碰临时隐藏」。
        XCTAssertEqual(
            occurrences(
                of: "machine.cancelTransientInterfaceHide()",
                in: text
            ),
            1,
            "异常终止的收口点不止一处"
        )
    }

    // MARK: - 断言 12：读数格式

    func testIC141C_TimeFormatterUsesMinuteSecondAndHourWhenNeeded() {
        XCTAssertEqual(S2VideoTimeFormatter.text(seconds: 0), "0:00")
        XCTAssertEqual(S2VideoTimeFormatter.text(seconds: 59.4), "0:59")
        XCTAssertEqual(S2VideoTimeFormatter.text(seconds: 60), "1:00")
        XCTAssertEqual(S2VideoTimeFormatter.text(seconds: 3_599), "59:59")
        XCTAssertEqual(S2VideoTimeFormatter.text(seconds: 3_600), "1:00:00")
        // 非法值退化为 0，不产生负号或 NaN 文本。
        XCTAssertEqual(S2VideoTimeFormatter.text(seconds: -3), "0:00")
        XCTAssertEqual(
            S2VideoTimeFormatter.text(seconds: .nan),
            "0:00"
        )

        guard let text = sourceText(
            "PhotoCleanupMVE/Features/S2/S2View.swift"
        ) else {
            return XCTFail("读不到 S2View 源码")
        }
        // 两端读数用等宽数字，拖动中位数跳动不会让浮框宽度抖。
        // 按「取拖动态字号的那处」计数，避开顶部信息区既有的那一处。
        XCTAssertEqual(
            occurrences(
                of: ".system(size: scrub.fontSize).monospacedDigit()",
                in: text
            ),
            2,
            "拖动态两端读数未各用一次等宽数字"
        )
    }

    // MARK: - 断言 13：有声只作用于当前页

    func testIC141C_UnmutingAppliesToTheCurrentPageAndResetsOnPageChange() {
        var machine = S2VideoPlaybackMachine()
        _ = machine.handle(.entered(assetID: nil))
        let became = machine.handle(
            .becameCurrent(assetID: "B", neighbours: [])
        )
        let generation = tryUnwrap(requestGeneration(in: became, for: "B"))
        _ = machine.handle(
            .requestSucceeded(assetID: "B", generation: generation)
        )
        _ = machine.handle(.pagingSettled)

        XCTAssertEqual(
            machine.handle(.userToggledMute),
            [.setMuted(assetID: "B", muted: false)],
            "点「有声」未解除静音"
        )
        XCTAssertTrue(machine.isUnmutedByUser)
        // 再点一次回到静音。
        XCTAssertEqual(
            machine.handle(.userToggledMute),
            [.setMuted(assetID: "B", muted: true)]
        )
        _ = machine.handle(.userToggledMute)

        // 翻页：前页恢复静音，新页起播也静音（决策 58：无开关、无记忆）。
        let becameC = machine.handle(
            .becameCurrent(assetID: "C", neighbours: ["B"])
        )
        XCTAssertTrue(
            becameC.contains(.setMuted(assetID: "B", muted: true)),
            "翻走未把前页恢复静音"
        )
        XCTAssertFalse(machine.isUnmutedByUser, "有声跟着翻到了下一页")
        let generationC = tryUnwrap(requestGeneration(in: becameC, for: "C"))
        _ = machine.handle(
            .requestSucceeded(assetID: "C", generation: generationC)
        )
        let settled = machine.handle(.pagingSettled)
        XCTAssertTrue(
            settled.contains(.setMuted(assetID: "C", muted: true)),
            "新页起播未静音"
        )
    }

    // MARK: - 断言 6：挂载口径 + 单击不碰播放

    func testIC141B_OnlyVideoPagesCarryALayerAndSingleTapNeverTouchesPlayback() {
        XCTAssertNotNil(S2VideoLayerPresentation.make(mediaKind: .video))
        XCTAssertNil(S2VideoLayerPresentation.make(mediaKind: .photo))
        XCTAssertNil(S2VideoLayerPresentation.make(mediaKind: .live))
        XCTAssertFalse(
            tryUnwrap(S2VideoLayerPresentation.make(mediaKind: .video))
                .acceptsHits,
            "播放层接了触控"
        )

        guard let text = sourceText(
            "PhotoCleanupMVE/Features/S2/S2View.swift"
        ) else {
            return XCTFail("读不到 S2View 源码")
        }

        // 决策 56：单击只切 `V`，播放状态不变——`V` 的落点里不得有视频协调器，
        // 直调与经夹具调都不行（两种大小写各扫一遍）。
        let visibilityBody = onChangeBody(
            of: "machine.interfaceVisibility",
            in: text
        )
        XCTAssertFalse(visibilityBody.isEmpty, "未截取到 V 变化的闭包体")
        for needle in ["videoPlayback", "VideoPlayback"] {
            XCTAssertEqual(
                occurrences(of: needle, in: visibilityBody),
                0,
                "单击切 V 的落点里出现了视频协调器（\(needle)）"
            )
        }

        // 正对照：页变更的落点里恰调一次视频侧的夹具。
        let assetBody = onChangeBody(of: "machine.currentAssetID", in: text)
        XCTAssertFalse(assetBody.isEmpty, "未截取到页变更的闭包体")
        XCTAssertEqual(
            occurrences(
                of: "notifyVideoPlaybackOfCurrentPage()",
                in: assetBody
            ),
            1,
            "页变更的落点未恰调一次视频协调器"
        )
        // 同一处也仍在喂实况侧（IC-140 未被本卡挤掉）。
        XCTAssertEqual(
            occurrences(
                of: "notifyLivePlaybackOfCurrentPage()",
                in: assetBody
            ),
            1,
            "页变更的落点丢了实况侧的接线"
        )
    }

    // MARK: - 断言 14：S2View 接线（源码扫描带正对照）

    func testIC141D_VideoWiringSitsBesideTheLivePhotoWiring() {
        guard let text = sourceText(
            "PhotoCleanupMVE/Features/S2/S2View.swift"
        ) else {
            return XCTFail("读不到 S2View 源码")
        }

        // 视频侧三处接线各恰一次，且与实况侧同名调用并列（正对照）。
        for needle in [
            "videoPlayback.pageBecameCurrent(",
            "videoPlayback.pagingSettled()",
            "livePlayback.pageBecameCurrent(",
            "livePlayback.pagingSettled()"
        ] {
            XCTAssertEqual(
                occurrences(of: needle, in: text),
                1,
                "\(needle) 的调用点不是恰一处"
            )
        }

        // 播放层只在各自的类别分支里构造。
        XCTAssertEqual(
            occurrences(of: "assetMediaKind(assetID) == .video", in: text),
            1,
            "视频播放层的构造条件不是恰一处"
        )
        XCTAssertEqual(
            occurrences(of: "assetMediaKind(assetID) == .live", in: text),
            1,
            "实况播放层的构造条件不是恰一处"
        )
        XCTAssertEqual(
            occurrences(of: "S2VideoPlaybackContentView(", in: text),
            1
        )
        XCTAssertEqual(
            occurrences(of: "S2LivePhotoPlaybackContentView(", in: text),
            1
        )

        // 实况侧零改动：本卡不引用实况协调器的任何新方法。
        guard let live = sourceText(
            "PhotoCleanupMVE/Features/S2/S2LivePhotoPlayback.swift"
        ) else {
            return XCTFail("读不到实况播放源码")
        }
        XCTAssertEqual(
            occurrences(of: "S2Video", in: live),
            0,
            "实况文件里出现了视频侧符号"
        )
    }

    // MARK: - 夹具

    private func plays(_ effects: [S2VideoPlaybackEffect]) -> [String] {
        effects.compactMap { (effect) -> String? in
            if case let .play(assetID) = effect {
                return assetID
            }
            return nil
        }
    }

    private func cancels(_ effects: [S2VideoPlaybackEffect]) -> [String] {
        effects.compactMap { (effect) -> String? in
            if case let .cancelRequest(assetID, _) = effect {
                return assetID
            }
            return nil
        }
    }

    private func requestGeneration(
        in effects: [S2VideoPlaybackEffect],
        for assetID: String
    ) -> Int? {
        effects.compactMap { (effect) -> Int? in
            if case let .request(identifier, generation) = effect,
               identifier == assetID {
                return generation
            }
            return nil
        }.first
    }

    /// 截取某个 `.onChange(of:)` 的闭包体（截到下一个 `.onChange(` 为止）。
    private func onChangeBody(of expression: String, in text: String) -> String {
        let head = ".onChange(of: " + expression + ") {"
        guard let start = text.range(of: head) else {
            return ""
        }
        let rest = text[start.upperBound...]
        guard let end = rest.range(of: ".onChange(") else {
            return String(rest)
        }
        return String(rest[..<end.lowerBound])
    }

    private func occurrences(of needle: String, in haystack: String) -> Int {
        haystack.components(separatedBy: needle).count - 1
    }

    private func sourceText(_ relativePath: String) -> String? {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = root.appendingPathComponent(relativePath)
        return try? String(contentsOf: url, encoding: .utf8)
    }

    /// 截取宿主视图 `layoutSubviews` 的函数体，供几何纪律的同函数体断言用。
    private func layoutSubviewsBody(in text: String) -> String {
        guard let start = text.range(
            of: "override func layoutSubviews() {"
        ) else {
            return ""
        }
        let rest = text[start.upperBound...]
        guard let end = rest.range(of: "\n    }\n") else {
            return String(rest)
        }
        return String(rest[..<end.lowerBound])
    }

    private func makeMachine(
        orderedAssetIDs: [String] = ["asset-1", "asset-2", "asset-3"],
        currentIndex: Int = 1
    ) -> S2StateMachine {
        let configuration = S2CalibrationConfiguration.factoryPlaceholder
        let resolvedCurrentIndex = min(
            max(0, currentIndex),
            orderedAssetIDs.count - 1
        )
        return S2StateMachine(
            entry: S2EntryContext(
                sessionID: "session-141",
                rangeDisplayInformation: S2RangeDisplayInformation(
                    rangeID: "range-141",
                    displayName: "IC-141",
                    totalAssetCount: orderedAssetIDs.count
                ),
                orderedAssetIDs: orderedAssetIDs,
                currentAssetID: orderedAssetIDs[resolvedCurrentIndex],
                pendingDeletionAssetIDs: [],
                sessionMergedPendingDeletionCountProvider: { 0 }
            ),
            initialPresentation: S2InitialPresentation(
                interfaceVisibility: .visible,
                scale: 1,
                viewportOffset: .zero
            ),
            parameters: tryUnwrap(configuration.resolvedParameters),
            imageRequestStrategy: configuration.imageRequestStrategy,
            initialFavoriteAssetIDs: [],
            initialRecentAlbum: nil,
            pendingDeletionDidChange: { _ in }
        )!
    }

    /// 与既有分页器夹具同源：挂窗口、跑一次布局与 runloop，页控制器才成形。
    private func attachWindow(
        to controller: S2NativePagerViewController
    ) -> UIWindow {
        let window = UIWindow(
            frame: CGRect(origin: .zero, size: physicalSize)
        )
        window.rootViewController = controller
        window.isHidden = false
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.03))
        return window
    }

    /// 与 `S2CalibrationHarnessTests.makeNativePagerController` 同源的构造：
    /// 直接建控制器、给视口尺寸，再走 `apply`。那个夹具是 private，
    /// 跨测试类调不到，故在这里按同一形状复刻（IC-140 同做）。
    private func makePagerController() -> S2NativePagerViewController {
        let controller = S2NativePagerViewController()
        controller.loadViewIfNeeded()
        controller.view.frame = CGRect(origin: .zero, size: physicalSize)
        return controller
    }

    private func applyPager(
        _ controller: S2NativePagerViewController,
        machine: S2StateMachine,
        onPagingSettled: @escaping () -> Void = {}
    ) {
        let configuration = S2CalibrationConfiguration.factoryPlaceholder
        let state = S2ViewportPresentationState(
            interfaceVisibility: machine.interfaceVisibility,
            bottomStripState: machine.bottomStripState,
            sheetState: machine.sheetState
        )
        let pages = machine.orderedAssetIDs.enumerated().map { index, assetID in
            let value = S2ViewportLayout.metrics(
                physicalSize: physicalSize,
                presentationState: state,
                assetAspectRatio: screenAspectRatio,
                isScreenshot: true,
                configuration: configuration
            )
            return S2NativePageContent(
                index: index,
                assetID: assetID,
                interfaceVisibility: machine.interfaceVisibility,
                isFramedPhoto: value.isFramedPhoto,
                fittedSize: value.oneXDisplaySize,
                fittedCenterY: value.oneXDisplayCenterY,
                nativeZoomBaseSize: value.nativeZoomBaseSize,
                cornerRadius: value.oneXCornerRadius,
                doubleTapTargetScale: value.doubleTapTargetScale,
                assetPixelSize: CGSize(
                    width: screenAspectRatio * 1_000,
                    height: 1_000
                ),
                contentVersion: S2NativePhotoContentVersion(
                    requestedScale: index == machine.currentIndex
                        ? machine.imageRequestScale
                        : 1,
                    requestStrategy: configuration.imageRequestStrategy,
                    requestRevision: 0
                ),
                content: AnyView(
                    Color.clear.frame(
                        width: value.oneXDisplaySize.width,
                        height: value.oneXDisplaySize.height
                    )
                ),
                zoomGeometry: nil
            )
        }
        controller.apply(
            machine: machine,
            configuration: configuration,
            viewportSize: physicalSize,
            pages: pages,
            onLongPressBegan: { false },
            onLongPressEnded: {},
            onPagingSettled: onPagingSettled
        )
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
    }

    private func tryUnwrap<T>(
        _ value: T?,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> T {
        guard let value else {
            XCTFail("预期值不应为空", file: file, line: line)
            fatalError("测试无法继续")
        }
        return value
    }
}
