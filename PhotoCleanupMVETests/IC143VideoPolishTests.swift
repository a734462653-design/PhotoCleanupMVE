import AVFoundation
import SwiftUI
import UIKit
import XCTest
@testable import PhotoCleanupMVE

/// 断言 12 的音频会话记录器。只记调用，不碰系统会话。
private final class AudioSessionRecorder: S2AudioSessionControlling {
    private(set) var calls: [String] = []

    func setPlaybackCategory() {
        calls.append("setCategory(.playback)")
    }

    func setActive(_ active: Bool) {
        calls.append(
            active
                ? "setActive(true)"
                : "setActive(false, notifyOthersOnDeactivation)"
        )
    }
}

/// IC-143：视频页三处修正 + 「有声」接音频会话。
///
/// **本卡只做视频页**：`S2LivePhotoPlayback.swift` 零改动。
/// 断言 1～3、11～13 是登记值／口径／源码扫描断言；断言 4～10 里凡走分页器
/// 与手势的都是夹具驱动，与真机事件序列不同源（陷阱 1），真机落点由 H66 五项兜底。
final class IC143VideoPolishTests: XCTestCase {
    private let physicalSize = CGSize(width: 300, height: 600)

    private var screenAspectRatio: CGFloat {
        physicalSize.width / physicalSize.height
    }

    // MARK: - 断言 1：登记值（带正对照）

    func testIC143A_VideoBarMetricsTakeTheNewRegisteredValues() {
        XCTAssertEqual(
            S2MediaMetrics.videoBarHorizontalMargin,
            S2OverlayLayout.chromeHorizontalMargin * 2
        )
        XCTAssertEqual(S2MediaMetrics.videoBarButtonIconPointSize, 20)
        XCTAssertEqual(S2MediaMetrics.videoBarMuteIconPointSize, 22)
        XCTAssertEqual(
            S2MediaMetrics.videoBarButtonHitWidth,
            S2OverlayLayout.minimumTouchTarget
        )

        // 不变量：带高与底缘锚是 H65 第 10 项已过的量，本卡不许动。
        XCTAssertEqual(S2MediaMetrics.videoBarHeight, 44)
        XCTAssertEqual(
            S2MediaMetrics.videoBarBottomToStripTop,
            S2OverlayLayout.stripToBottomRowSpacing
        )

        guard let text = sourceText(
            "PhotoCleanupMVE/Features/S2/S2View.swift"
        ) else {
            return XCTFail("读不到 S2View 源码")
        }
        let block = mediaMetricsBlock(in: text)
        XCTAssertFalse(block.isEmpty, "未截取到媒体常量容器")
        for symbol in [
            "videoBarHorizontalMargin",
            "videoBarButtonIconPointSize",
            "videoBarMuteIconPointSize",
            "videoBarButtonHitWidth"
        ] {
            XCTAssertEqual(
                occurrences(of: symbol, in: block),
                1,
                "\(symbol) 在容器里不是恰一处定义"
            )
        }

        // 边距与命中区宽都引用登记值，定义里不出现 16／32／44 的裸数；
        // 正对照：带高的定义就是裸数 44。
        let marginDefinition = definition(
            of: "videoBarHorizontalMargin",
            in: block
        )
        XCTAssertTrue(
            marginDefinition.contains("chromeHorizontalMargin"),
            "边距未引用 chrome 既有横向边距"
        )
        for bare in ["16", "32"] {
            XCTAssertFalse(
                marginDefinition.contains(bare),
                "边距定义写了裸数 \(bare)"
            )
        }
        let hitWidthDefinition = definition(
            of: "videoBarButtonHitWidth",
            in: block
        )
        XCTAssertTrue(
            hitWidthDefinition.contains("minimumTouchTarget"),
            "命中区宽未引用最小触控边长"
        )
        XCTAssertFalse(
            hitWidthDefinition.contains("44"),
            "命中区宽写了裸数 44"
        )
        XCTAssertTrue(
            definition(of: "videoBarHeight", in: block).contains("44"),
            "正对照失效：带高本就该是裸数 44"
        )
    }

    // MARK: - 断言 2：两键定宽，轨不吃两键的宽（源码扫描）

    func testIC143A_BothBarButtonsTakeAFixedHitWidthAndTheTrackDoesNot() {
        guard let text = sourceText(
            "PhotoCleanupMVE/Features/S2/S2View.swift"
        ) else {
            return XCTFail("读不到 S2View 源码")
        }

        for name in ["playPauseButton", "muteButton"] {
            let body = functionBody(of: name, in: text)
            XCTAssertFalse(body.isEmpty, "未截取到 \(name) 函数体")
            XCTAssertEqual(
                occurrences(
                    of: "width: S2MediaMetrics.videoBarButtonHitWidth",
                    in: body
                ),
                1,
                "\(name) 的命中区未定宽"
            )
            XCTAssertEqual(
                occurrences(of: ".contentShape(Rectangle())", in: body),
                1,
                "\(name) 丢了命中形状"
            )
            XCTAssertEqual(
                occurrences(
                    of: "height: S2MediaMetrics.videoBarHeight",
                    in: body
                ),
                1,
                "\(name) 的命中区高不再取浮框带高"
            )
        }

        let track = functionBody(of: "progressTrack", in: text)
        XCTAssertFalse(track.isEmpty, "未截取到 progressTrack 函数体")
        XCTAssertEqual(
            occurrences(of: "videoBarButtonHitWidth", in: track),
            0,
            "进度轨吃掉了两键的宽"
        )
        // 轨仍是可拖区，起手位移不变（H65 第 4 项已过，本卡不动）。
        XCTAssertEqual(
            occurrences(of: "videoBarScrubMinimumDistance", in: track),
            1
        )
    }

    // MARK: - 断言 4：reducer 的异常终止与 scrubEnded 等价且幂等

    func testIC143B_CancellingAScrubRestoresPlaybackJustLikeReleasing() {
        // 在播时拖动：取消后续播，与正常松手效果一致。
        var cancelled = makeMachinePlaying(assetID: "B")
        let began = cancelled.handle(.scrubBegan)
        XCTAssertEqual(began, [.pause(assetID: "B")], "拖动开始未暂停在播的那段")
        XCTAssertTrue(cancelled.isScrubbing)
        let afterCancel = cancelled.handle(.scrubCancelled)
        XCTAssertEqual(afterCancel, [.play(assetID: "B")], "异常终止未续播")
        XCTAssertFalse(cancelled.isScrubbing, "异常终止后仍是拖动态")
        XCTAssertEqual(cancelled.state(for: "B"), .playing)

        // 正对照：正常松手的效果与之逐字相同。
        var released = makeMachinePlaying(assetID: "B")
        _ = released.handle(.scrubBegan)
        XCTAssertEqual(
            released.handle(.scrubEnded),
            afterCancel,
            "异常终止与正常松手的收口不一致"
        )

        // 暂停态拖动：取消后保持暂停，不 play。
        var paused = makeMachinePlaying(assetID: "B")
        _ = paused.handle(.userToggledPlayPause)
        XCTAssertEqual(paused.state(for: "B"), .paused)
        XCTAssertTrue(paused.handle(.scrubBegan).isEmpty, "暂停态拖动仍发了暂停")
        XCTAssertTrue(
            paused.handle(.scrubCancelled).isEmpty,
            "暂停态的异常终止把视频播起来了"
        )
        XCTAssertEqual(paused.state(for: "B"), .paused)

        // 幂等：非拖动态收到异常终止无效果，重复调用也无效果。
        var idle = makeMachinePlaying(assetID: "B")
        XCTAssertTrue(idle.handle(.scrubCancelled).isEmpty)
        XCTAssertTrue(idle.handle(.scrubCancelled).isEmpty)
        XCTAssertEqual(idle.state(for: "B"), .playing, "幂等调用改动了播放状态")

        // 当前页在拖动中被换掉：前页回起点，拖动态一并清掉。
        var switched = makeMachinePlaying(assetID: "B")
        _ = switched.handle(.scrubBegan)
        let becameC = switched.handle(
            .becameCurrent(assetID: "C", neighbours: ["B"])
        )
        XCTAssertTrue(becameC.contains(.seek(assetID: "B", fraction: 0)))
        XCTAssertTrue(becameC.contains(.setMuted(assetID: "B", muted: true)))
        XCTAssertFalse(switched.isScrubbing, "换页后仍是拖动态")
        XCTAssertTrue(
            switched.handle(.scrubCancelled).isEmpty,
            "换页后补发的异常终止不该再产生效果"
        )
    }

    // MARK: - 断言 5：状态机的无条件收口

    func testIC143B_CancelTransientHideZeroesDepthAndRestoresVisibility() {
        let machine = makeStateMachine()
        XCTAssertEqual(machine.interfaceVisibility, .visible)

        // 未进入时调用无效果（幂等）。
        machine.cancelTransientInterfaceHide()
        XCTAssertEqual(machine.interfaceVisibility, .visible)
        XCTAssertEqual(machine.transientInterfaceHideDepth, 0)
        XCTAssertNil(machine.recordedVisibilityBeforeTransientHide)

        // 进入一层：V 隐、深度 1、记住进入前的值。
        machine.beginTransientInterfaceHide()
        XCTAssertEqual(machine.interfaceVisibility, .hidden)
        XCTAssertEqual(machine.transientInterfaceHideDepth, 1)
        XCTAssertEqual(machine.recordedVisibilityBeforeTransientHide, .visible)

        machine.cancelTransientInterfaceHide()
        XCTAssertEqual(machine.interfaceVisibility, .visible)
        XCTAssertEqual(machine.transientInterfaceHideDepth, 0)
        XCTAssertNil(machine.recordedVisibilityBeforeTransientHide)

        // 深度 2 时一次收口也归 0（这正是 end 做不到的）。
        machine.beginTransientInterfaceHide()
        machine.beginTransientInterfaceHide()
        XCTAssertEqual(machine.transientInterfaceHideDepth, 2)
        machine.cancelTransientInterfaceHide()
        XCTAssertEqual(machine.transientInterfaceHideDepth, 0)
        XCTAssertEqual(machine.interfaceVisibility, .visible)
        XCTAssertNil(machine.recordedVisibilityBeforeTransientHide)

        // 正对照：同样深度 2 时，一次 end 不恢复。
        let paired = makeStateMachine()
        paired.beginTransientInterfaceHide()
        paired.beginTransientInterfaceHide()
        paired.endTransientInterfaceHide()
        XCTAssertEqual(paired.interfaceVisibility, .hidden, "一次 end 就恢复了")
        XCTAssertEqual(paired.transientInterfaceHideDepth, 1)

        // 进入前本就隐藏：收口后仍隐藏（恢复的是记住的值）。
        let hidden = makeStateMachine()
        hidden.handleSingleTap()
        XCTAssertEqual(hidden.interfaceVisibility, .hidden)
        hidden.beginTransientInterfaceHide()
        hidden.cancelTransientInterfaceHide()
        XCTAssertEqual(hidden.interfaceVisibility, .hidden)
    }

    // MARK: - 断言 6：三处异常入口共用同一个收口（源码扫描带正对照）

    func testIC143B_EveryAbnormalScrubExitGoesThroughOneCollector() {
        guard let text = sourceText(
            "PhotoCleanupMVE/Features/S2/S2View.swift"
        ) else {
            return XCTFail("读不到 S2View 源码")
        }

        // 收口闭包：1 处定义 + 3 处调用。
        XCTAssertEqual(
            occurrences(of: "cancelVideoScrub()", in: text),
            4,
            "异常终止的收口不是「一处定义 + 三处入口」"
        )
        XCTAssertEqual(
            occurrences(of: "private func cancelVideoScrub()", in: text),
            1
        )
        // 收口内部各调一次，写入点唯一（陷阱 19）。
        XCTAssertEqual(
            occurrences(of: "videoPlayback.scrubCancelled()", in: text),
            1
        )
        XCTAssertEqual(
            occurrences(
                of: "machine.cancelTransientInterfaceHide()",
                in: text
            ),
            1
        )

        // 三处入口各恰一次。
        XCTAssertEqual(
            occurrences(of: ".onChange(of: scenePhase)", in: text),
            1,
            "缺应用失活入口"
        )
        XCTAssertEqual(
            occurrences(of: ".onDisappear(perform: onScrubCancelled)", in: text),
            1,
            "缺浮框被移除入口"
        )
        let assetChange = onChangeBody(of: "machine.currentAssetID", in: text)
        XCTAssertFalse(assetChange.isEmpty, "未截取到翻页回调体")
        XCTAssertEqual(
            occurrences(of: "cancelVideoScrub()", in: assetChange),
            1,
            "缺换页入口"
        )

        // 正对照：正常松手那条路径一字未动，仍走 end 而不是 cancel。
        XCTAssertEqual(
            occurrences(of: "machine.endTransientInterfaceHide()", in: text),
            1
        )
        XCTAssertEqual(
            occurrences(of: "videoPlayback.scrubEnded()", in: text),
            1
        )
    }

    // MARK: - 断言 7：异常终止后 V 与播放都回位，单击照常（夹具驱动，真机未覆盖）

    func testIC143B_AfterAnAbnormalExitVisibilityAndTapsBehaveNormally() {
        let machine = makeStateMachine()
        let playback = S2VideoPlaybackCoordinator()

        // 进入拖动：与 `onScrubBegan` 的两步逐字一致。
        machine.beginTransientInterfaceHide()
        playback.scrubBegan()
        XCTAssertEqual(machine.interfaceVisibility, .hidden)
        XCTAssertEqual(machine.transientInterfaceHideDepth, 1)

        // 异常终止：与 `cancelVideoScrub()` 的两步逐字一致。
        playback.scrubCancelled()
        machine.cancelTransientInterfaceHide()

        XCTAssertEqual(machine.interfaceVisibility, .visible, "V 未回到拖动前")
        XCTAssertEqual(machine.transientInterfaceHideDepth, 0)
        XCTAssertNil(machine.recordedVisibilityBeforeTransientHide)

        // 此后单击主图照常翻转 V——这是「卡在隐藏态」的直接反面。
        XCTAssertTrue(machine.handleSingleTap())
        XCTAssertEqual(machine.interfaceVisibility, .hidden)
        XCTAssertTrue(machine.handleSingleTap())
        XCTAssertEqual(machine.interfaceVisibility, .visible)
    }

    // MARK: - 断言 8：过渡期间播放层归过渡视图，收口交还（夹具驱动，真机未覆盖）

    func testIC143C_PlaybackLayerRidesTheDoubleTapTransitionAndComesBack() {
        for enteringNx in [true, false] {
            let machine = makeStateMachine()
            let controller = makePagerController()
            applyPager(controller, machine: machine)
            let window = attachWindow(to: controller)
            defer { window.isHidden = true }
            let page = tryUnwrap(
                controller.pageControllers[machine.currentIndex]
            )
            let content = tryUnwrap(page.zoomScrollView.presentationContentView)

            let hostView = S2VideoHostView(assetID: machine.currentAssetID)
            hostView.frame = content.bounds
            content.addSubview(hostView)
            hostView.layoutIfNeeded()

            // 过渡前：播放层挂在宿主上，层序第 0。
            XCTAssertTrue(
                hostView.diagnosticPlaybackLayerSuperlayer === hostView.layer,
                "过渡前播放层就不在宿主上"
            )
            let indexBefore = hostView.diagnosticPlaybackLayerIndex
            XCTAssertEqual(indexBefore, 0)
            XCTAssertFalse(hostView.isLendingPlaybackLayer)

            if !enteringNx {
                page.zoomScrollView.applyNativeState(
                    scale: 2,
                    viewportOffset: .zero
                )
                page.view.setNeedsLayout()
                page.view.layoutIfNeeded()
            }

            // 时长给足，过渡留在进行中，好观察借出态。
            let started = page.startDoubleTapTransition(
                enteringNx: enteringNx,
                targetScale: enteringNx ? 2 : 1,
                at: CGPoint(
                    x: physicalSize.width / 2,
                    y: physicalSize.height / 2
                ),
                configuration: .factoryPlaceholder,
                durationOverrideSeconds: 1
            )
            XCTAssertTrue(started, "双击过渡未起飞（enteringNx=\(enteringNx)）")

            // 过渡中：承载者换成过渡视图，帧贴满它的 bounds。
            let superlayer = tryUnwrap(
                hostView.diagnosticPlaybackLayerSuperlayer
            )
            XCTAssertFalse(
                superlayer === hostView.layer,
                "过渡期间播放层仍留在被隐藏的页内容里（enteringNx=\(enteringNx)）"
            )
            XCTAssertTrue(hostView.isLendingPlaybackLayer)
            // 承载者必须是页控制器视图下的那个过渡视图。
            let transitionView = tryUnwrap(
                page.view.subviews.first { $0.layer === superlayer }
            )
            XCTAssertFalse(
                transitionView === hostView,
                "承载者仍是宿主视图"
            )
            XCTAssertEqual(
                hostView.diagnosticPlaybackLayerFrame,
                transitionView.bounds,
                "借出的播放层未贴满过渡视图"
            )

            // 收口：交还宿主、帧回宿主 bounds、层序与过渡前相同。
            page.finishActiveDoubleTapTransition()
            XCTAssertTrue(
                hostView.diagnosticPlaybackLayerSuperlayer === hostView.layer,
                "收口后播放层未交还宿主（enteringNx=\(enteringNx)）"
            )
            XCTAssertFalse(hostView.isLendingPlaybackLayer)
            XCTAssertEqual(
                hostView.diagnosticPlaybackLayerFrame,
                hostView.bounds,
                "交还后播放层的帧不等于宿主 bounds"
            )
            XCTAssertEqual(
                hostView.diagnosticPlaybackLayerIndex,
                indexBefore,
                "交还后层序变了"
            )
        }
    }

    func testIC143C_EarlyCollapsedTransitionAlsoReturnsThePlaybackLayer() {
        let machine = makeStateMachine()
        let controller = makePagerController()
        applyPager(controller, machine: machine)
        let window = attachWindow(to: controller)
        defer { window.isHidden = true }
        let page = tryUnwrap(controller.pageControllers[machine.currentIndex])
        let content = tryUnwrap(page.zoomScrollView.presentationContentView)

        let hostView = S2VideoHostView(assetID: machine.currentAssetID)
        hostView.frame = content.bounds
        content.addSubview(hostView)
        hostView.layoutIfNeeded()

        // 时长 0 ⟹ 走 P4 早收口路径：起飞即收口，同样必须交还。
        let started = page.startDoubleTapTransition(
            enteringNx: true,
            targetScale: 2,
            at: CGPoint(x: physicalSize.width / 2, y: physicalSize.height / 2),
            configuration: .factoryPlaceholder,
            durationOverrideSeconds: 0
        )
        XCTAssertTrue(started, "零时长过渡未起飞")
        XCTAssertTrue(
            hostView.diagnosticPlaybackLayerSuperlayer === hostView.layer,
            "早收口路径没交还播放层"
        )
        XCTAssertFalse(hostView.isLendingPlaybackLayer)
        XCTAssertEqual(hostView.diagnosticPlaybackLayerFrame, hostView.bounds)
    }

    // MARK: - 断言 9：过渡全程不碰播放（扩展 IC-141 断言 9）

    func testIC143C_TheTransitionNeverTouchesPlaybackState() {
        let machine = makeStateMachine()
        let controller = makePagerController()
        applyPager(controller, machine: machine)
        let window = attachWindow(to: controller)
        defer { window.isHidden = true }
        let page = tryUnwrap(controller.pageControllers[machine.currentIndex])
        let content = tryUnwrap(page.zoomScrollView.presentationContentView)

        let playback = S2VideoPlaybackCoordinator()
        let hostView = S2VideoHostView(assetID: machine.currentAssetID)
        hostView.frame = content.bounds
        content.addSubview(hostView)
        playback.register(surface: hostView, for: machine.currentAssetID)
        XCTAssertEqual(playback.surfaceRegistrationCount, 1)

        page.zoomScrollView.applyNativeState(scale: 2, viewportOffset: .zero)
        page.view.setNeedsLayout()
        page.view.layoutIfNeeded()
        XCTAssertTrue(page.startDoubleTapTransition(
            enteringNx: false,
            targetScale: 1,
            at: CGPoint(x: physicalSize.width / 2, y: physicalSize.height / 2),
            configuration: .factoryPlaceholder,
            durationOverrideSeconds: 1
        ))
        // 过渡进行中就查一次——借出发生在这里，不该带出任何播放事件。
        XCTAssertEqual(playback.surfaceRegistrationCount, 1, "过渡中重复登记")
        XCTAssertEqual(playback.surfaceUnregistrationCount, 0, "过渡中注销了")
        page.finishActiveDoubleTapTransition()

        XCTAssertTrue(
            playback.registeredSurface(for: machine.currentAssetID)
                === hostView,
            "过渡换掉了播放层实例"
        )
        XCTAssertEqual(playback.surfaceRegistrationCount, 1)
        XCTAssertEqual(playback.surfaceUnregistrationCount, 0)
        XCTAssertEqual(hostView.rebindCount, 0, "过渡触发了改绑")
        XCTAssertEqual(
            playback.playbackState(for: machine.currentAssetID),
            .idle,
            "过渡改动了播放状态"
        )
    }

    // MARK: - 断言 10：照片页与残影快照零变化

    func testIC143C_PhotoPageTransitionAndAfterimageSnapshotAreUnchanged() {
        let machine = makeStateMachine()
        let controller = makePagerController()
        applyPager(controller, machine: machine)
        let window = attachWindow(to: controller)
        defer { window.isHidden = true }
        let page = tryUnwrap(controller.pageControllers[machine.currentIndex])
        let content = tryUnwrap(page.zoomScrollView.presentationContentView)

        // 残影快照与 C 的借层路径互不相干：树里有没有可借出的播放层宿主，
        // P8 的结果都一样。
        //
        // **不断言非 nil**——离屏夹具里 `snapshotView(afterScreenUpdates:)`
        // 取不到已渲染内容，恒为 nil（IC-141 #279 实测已立此例，那条绿测
        // 因此也只钉不变性）。#282／#283 两次红都栽在这条上，本卡照 IC-141
        // 的先例改钉不变性；「快照确实是封面帧」那一半留给 H66 第 2 项真机判定。
        let withoutHost = page.makeMarkAfterimageSnapshot(in: controller.view)
        let hostView = S2VideoHostView(assetID: machine.currentAssetID)
        hostView.frame = content.bounds
        content.addSubview(hostView)
        let withHost = page.makeMarkAfterimageSnapshot(in: controller.view)
        XCTAssertEqual(
            withoutHost == nil,
            withHost == nil,
            "有无播放层宿主时残影快照的结果不一致"
        )
        hostView.removeFromSuperview()

        // 照片页：页内容树里没有遵循者，过渡的同步读数仍在既有阈值内。
        page.zoomScrollView.applyNativeState(scale: 2, viewportOffset: .zero)
        page.view.setNeedsLayout()
        page.view.layoutIfNeeded()
        XCTAssertTrue(page.startDoubleTapTransition(
            enteringNx: false,
            targetScale: 1,
            at: CGPoint(x: physicalSize.width / 2, y: physicalSize.height / 2),
            configuration: .factoryPlaceholder,
            durationOverrideSeconds: 0
        ))
        XCTAssertLessThanOrEqual(
            tryUnwrap(page.lastDoubleTapSynchronization).maximumDifference,
            0.5,
            "照片页双击过渡的同步读数越界"
        )

        guard let pager = sourceText(
            "PhotoCleanupMVE/Features/S2/S2NativePhotoPager.swift"
        ) else {
            return XCTFail("读不到分页器源码")
        }
        // P8 残影快照仍只经一次封面帧排除；几何链计数不变。
        let afterimage = functionBody(
            of: "makeMarkAfterimageSnapshot",
            in: pager,
            keyword: "func "
        )
        XCTAssertFalse(afterimage.isEmpty, "未截取到残影快照函数体")
        XCTAssertEqual(
            occurrences(of: "S2SnapshotExclusion.capturing", in: afterimage),
            1,
            "残影快照的封面帧排除不是恰一处"
        )
        XCTAssertEqual(
            occurrences(of: "lendPlaybackLayer", in: afterimage),
            0,
            "残影快照被卷进了借层路径"
        )
        XCTAssertEqual(occurrences(of: "writePhotoGeometry", in: pager), 5)
    }

    // MARK: - 断言 11：系统会话只在协调器的适配处出现

    func testIC143D_TheAudioSessionIsTouchedInExactlyOnePlace() {
        guard let video = sourceText(
            "PhotoCleanupMVE/Features/S2/S2VideoPlayback.swift"
        ) else {
            return XCTFail("读不到视频播放源码")
        }
        // 串按名字拼，免得本断言把自己所在文件的写法也算进去。
        let symbol = "AVAudio" + "Session"
        let adapter = typeBody(of: "S2SystemAudioSession", in: video)
        XCTAssertFalse(adapter.isEmpty, "未截取到音频会话适配器")
        XCTAssertGreaterThan(
            occurrences(of: symbol, in: adapter),
            0,
            "适配器里根本没碰系统会话"
        )
        XCTAssertEqual(
            occurrences(of: symbol, in: video),
            occurrences(of: symbol, in: adapter),
            "适配器之外还有地方碰系统会话"
        )

        // 其余三个文件零命中。
        for path in [
            "PhotoCleanupMVE/Features/S2/S2View.swift",
            "PhotoCleanupMVE/Features/S2/S2LivePhotoPlayback.swift",
            "PhotoCleanupMVE/Features/S2/S2NativePhotoPager.swift"
        ] {
            guard let text = sourceText(path) else {
                return XCTFail("读不到 \(path)")
            }
            XCTAssertEqual(
                occurrences(of: symbol, in: text),
                0,
                "\(path) 碰了系统会话"
            )
        }
    }

    // MARK: - 断言 12：出声才激活，收声即停用（可注入协议记录调用）

    func testIC143D_UnmutingActivatesTheSessionAndEveryMutePathDeactivates() {
        // 自动起播（静音）全程零调用——不打断别的应用在放的音频。
        let autoplay = AudioSessionRecorder()
        let autoplayCoordinator = makeCoordinator(audioSession: autoplay)
        autoplayCoordinator.enter(assetID: nil)
        autoplayCoordinator.pageBecameCurrent(assetID: "B", neighbours: [])
        autoplayCoordinator.pagingSettled()
        XCTAssertEqual(autoplay.calls, [], "静音自动播放动了音频会话")

        // 路径一：用户再点一次静音。
        let retap = AudioSessionRecorder()
        let retapCoordinator = makeCoordinator(audioSession: retap)
        retapCoordinator.enter(assetID: nil)
        retapCoordinator.pageBecameCurrent(assetID: "B", neighbours: [])
        retapCoordinator.toggleMute()
        XCTAssertEqual(
            retap.calls,
            ["setCategory(.playback)", "setActive(true)"],
            "点「有声」未按「先置类别再激活」备好会话"
        )
        retapCoordinator.toggleMute()
        XCTAssertEqual(
            retap.calls.last,
            "setActive(false, notifyOthersOnDeactivation)",
            "再点静音未停用会话"
        )
        XCTAssertEqual(retap.calls.count, 3)

        // 路径二：翻页（`becameCurrent` 把「有声」清掉）。
        let pageChange = AudioSessionRecorder()
        let pageCoordinator = makeCoordinator(audioSession: pageChange)
        pageCoordinator.enter(assetID: nil)
        pageCoordinator.pageBecameCurrent(assetID: "B", neighbours: [])
        pageCoordinator.toggleMute()
        pageCoordinator.pageBecameCurrent(assetID: "C", neighbours: ["B"])
        XCTAssertEqual(
            pageChange.calls,
            [
                "setCategory(.playback)",
                "setActive(true)",
                "setActive(false, notifyOthersOnDeactivation)"
            ],
            "翻走后未停用会话，别的应用的音频不会恢复"
        )

        // 路径三：翻出半径把播放器卸掉。这条路径上 reducer **不发** setMuted
        // ——先在 reducer 层把这个缺口钉住，正是它决定了会话不能挂在效果上。
        var reducer = makeMachinePlaying(assetID: "B")
        _ = reducer.handle(.userToggledMute)
        let retired = reducer.handle(
            .becameCurrent(assetID: "C", neighbours: [])
        )
        XCTAssertTrue(
            retired.contains(.unload(assetID: "B")),
            "翻出半径未卸播放器"
        )
        XCTAssertFalse(
            retired.contains(.setMuted(assetID: "B", muted: true)),
            "退页路径已经发 setMuted 了，本断言的前提要重写"
        )
        // 协调器仍然收声：会话跟的是 `isUnmutedByUser`，不是效果。
        let unload = AudioSessionRecorder()
        let unloadCoordinator = makeCoordinator(audioSession: unload)
        unloadCoordinator.enter(assetID: nil)
        unloadCoordinator.pageBecameCurrent(assetID: "B", neighbours: [])
        unloadCoordinator.toggleMute()
        unloadCoordinator.pageBecameCurrent(assetID: "C", neighbours: [])
        XCTAssertEqual(
            unload.calls.last,
            "setActive(false, notifyOthersOnDeactivation)",
            "卸播放器这条路径漏掉了会话停用"
        )

        // 离开 S2 同样收声。
        let leaving = AudioSessionRecorder()
        let leaveCoordinator = makeCoordinator(audioSession: leaving)
        leaveCoordinator.enter(assetID: nil)
        leaveCoordinator.pageBecameCurrent(assetID: "B", neighbours: [])
        leaveCoordinator.toggleMute()
        leaveCoordinator.leave()
        XCTAssertEqual(
            leaving.calls.last,
            "setActive(false, notifyOthersOnDeactivation)",
            "离开 S2 未停用会话"
        )

        // 幂等：重复「有声」不重复激活，重复「静音」不重复停用。
        let repeated = AudioSessionRecorder()
        let repeatCoordinator = makeCoordinator(audioSession: repeated)
        repeatCoordinator.enter(assetID: nil)
        repeatCoordinator.pageBecameCurrent(assetID: "B", neighbours: [])
        repeatCoordinator.toggleMute()
        let afterFirstUnmute = repeated.calls.count
        repeatCoordinator.pagingSettled()
        repeatCoordinator.togglePlayPause()
        XCTAssertEqual(
            repeated.calls.count,
            afterFirstUnmute,
            "出声期间的其他事件重复激活了会话"
        )
        repeatCoordinator.toggleMute()
        repeatCoordinator.leave()
        XCTAssertEqual(
            repeated.calls.count,
            afterFirstUnmute + 1,
            "重复收声重复停用了会话"
        )
    }

    // MARK: - 断言 13：IC-141 的「有声只作用当前页」口径不变

    func testIC143D_UnmutingStillAppliesOnlyToTheCurrentPage() {
        // B 必须真的在播：`park` 只对 `.playing`／`.paused` 发 setMuted，
        // 尚在请求中的页没有播放器可静音（#282 实测暴露的夹具前提）。
        var machine = makeMachinePlaying(assetID: "B")
        XCTAssertEqual(
            machine.handle(.userToggledMute),
            [.setMuted(assetID: "B", muted: false)]
        )
        XCTAssertTrue(machine.isUnmutedByUser)

        let becameC = machine.handle(
            .becameCurrent(assetID: "C", neighbours: ["B"])
        )
        XCTAssertTrue(
            becameC.contains(.setMuted(assetID: "B", muted: true)),
            "翻走未把前页收回静音"
        )
        XCTAssertFalse(machine.isUnmutedByUser, "「有声」被记住了")
    }

    // MARK: - 夹具

    private func makeCoordinator(
        audioSession: any S2AudioSessionControlling
    ) -> S2VideoPlaybackCoordinator {
        S2VideoPlaybackCoordinator(audioSession: audioSession)
    }

    /// 截取某个类型的正文（到列首的收口括号为止）。
    private func typeBody(of name: String, in text: String) -> String {
        guard let start = text.range(of: "final class " + name) else {
            return ""
        }
        let rest = text[start.upperBound...]
        guard let end = rest.range(of: "\n}\n") else {
            return String(rest)
        }
        return String(rest[..<end.lowerBound])
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

    /// 与 `S2CalibrationHarnessTests.makeNativePagerController` 同源的构造
    /// （那个夹具是 private，跨测试类调不到，故按同一形状复刻；IC-140／141 同做）。
    private func makePagerController() -> S2NativePagerViewController {
        let controller = S2NativePagerViewController()
        controller.loadViewIfNeeded()
        controller.view.frame = CGRect(origin: .zero, size: physicalSize)
        return controller
    }

    private func applyPager(
        _ controller: S2NativePagerViewController,
        machine: S2StateMachine
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
            onPagingSettled: {}
        )
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
    }

    /// 造一个「B 在播」的 reducer：入口非视频 → 翻到 B → 就绪 → 停稳起播。
    private func makeMachinePlaying(assetID: String) -> S2VideoPlaybackMachine {
        var machine = S2VideoPlaybackMachine()
        _ = machine.handle(.entered(assetID: nil))
        let became = machine.handle(
            .becameCurrent(assetID: assetID, neighbours: [])
        )
        let generation = became.compactMap { (effect) -> Int? in
            if case let .request(identifier, value) = effect,
               identifier == assetID {
                return value
            }
            return nil
        }.first
        _ = machine.handle(
            .requestSucceeded(
                assetID: assetID,
                generation: generation ?? 0
            )
        )
        _ = machine.handle(.pagingSettled)
        return machine
    }

    private func makeStateMachine(
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
                sessionID: "session-143",
                rangeDisplayInformation: S2RangeDisplayInformation(
                    rangeID: "range-143",
                    displayName: "IC-143",
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

    /// 截取 `.onChange(of: <key>)` 的回调体（到下一个 `.onChange(` 为止）。
    private func onChangeBody(of key: String, in text: String) -> String {
        guard let start = text.range(of: ".onChange(of: " + key + ")") else {
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

    /// 截取 `S2MediaMetrics` 容器正文（与 IC-139 夹具同形）。
    private func mediaMetricsBlock(in text: String) -> String {
        guard let start = text.range(of: "enum S2MediaMetrics {") else {
            return ""
        }
        let rest = text[start.upperBound...]
        guard let end = rest.range(of: "\n}\n") else {
            return String(rest)
        }
        return String(rest[..<end.lowerBound])
    }

    /// 截取某个 `static let` 的定义（含续行，到下一个非续行为止）。
    private func definition(of symbol: String, in block: String) -> String {
        let lines = block.components(separatedBy: "\n")
        guard let index = lines.firstIndex(
            where: { $0.contains("static let " + symbol) }
        ) else {
            return ""
        }
        var collected = lines[index]
        var cursor = index + 1
        while cursor < lines.count {
            let line = lines[cursor]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix(".") || trimmed.hasPrefix("?") else {
                break
            }
            collected += "\n" + line
            cursor += 1
        }
        return collected
    }

    /// 截取某个函数的函数体（到同缩进的收口括号为止）。
    private func functionBody(
        of name: String,
        in text: String,
        keyword: String = "private func "
    ) -> String {
        guard let start = text.range(of: keyword + name) else {
            return ""
        }
        let rest = text[start.upperBound...]
        guard let end = rest.range(of: "\n    }\n") else {
            return String(rest)
        }
        return String(rest[..<end.lowerBound])
    }

    private func sourceText(_ relativePath: String) -> String? {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = root.appendingPathComponent(relativePath)
        return try? String(contentsOf: url, encoding: .utf8)
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
