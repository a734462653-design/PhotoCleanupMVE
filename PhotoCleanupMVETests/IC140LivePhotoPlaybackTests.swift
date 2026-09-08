import SwiftUI
import UIKit
import XCTest
@testable import PhotoCleanupMVE

/// IC-140：实况播放（到页短动效、长按全段、手势挂起）。
///
/// **本卡只做实况**：不引 `AVPlayer`，视频页零改动（IC-141）。
/// 断言 1～5 是纯 reducer 断言；断言 8、10 是分页器夹具断言，
/// 与真机手势序列不同源（陷阱 1），真机落点由 H64b 八项兜底。
final class IC140LivePhotoPlaybackTests: XCTestCase {
    private let physicalSize = CGSize(width: 300, height: 600)

    private var screenAspectRatio: CGFloat {
        physicalSize.width / physicalSize.height
    }

    // MARK: - 断言 1：入口那张不自动播

    func testIC140A_EntryAssetDoesNotAutoPlayUntilThePageHasChangedOnce() {
        var machine = S2LivePhotoPlaybackMachine()

        // 入口 A：停稳也不放短动效。
        XCTAssertTrue(machine.handle(.entered(assetID: "A")).isEmpty)
        XCTAssertTrue(
            hintPlays(machine.handle(.pagingSettled)).isEmpty,
            "入口那张在首次停稳就自动播了"
        )

        // 翻到 B：就绪后停稳恰放一次。
        let becameB = machine.handle(
            .becameCurrent(assetID: "B", neighbours: ["A"])
        )
        let generationB = requestGeneration(in: becameB, for: "B")
        XCTAssertNotNil(generationB, "换页未为新当前页发请求")
        XCTAssertTrue(
            machine.handle(
                .requestSucceeded(assetID: "B", generation: generationB ?? 0)
            ).isEmpty,
            "尚未停稳就起播了"
        )
        XCTAssertEqual(hintPlays(machine.handle(.pagingSettled)), ["B"])

        // 同页反复停稳不重播。
        XCTAssertTrue(hintPlays(machine.handle(.pagingSettled)).isEmpty)

        // 翻回入口那张也算「变更后」，照播。
        let becameA = machine.handle(
            .becameCurrent(assetID: "A", neighbours: ["B"])
        )
        let generationA = requestGeneration(in: becameA, for: "A")
        XCTAssertNotNil(generationA)
        _ = machine.handle(
            .requestSucceeded(assetID: "A", generation: generationA ?? 0)
        )
        XCTAssertEqual(hintPlays(machine.handle(.pagingSettled)), ["A"])
    }

    // MARK: - 断言 2：未就绪停稳与迟到回调

    func testIC140A_SettlingBeforeReadyDefersTheHintUntilTheResourceArrives() {
        var machine = S2LivePhotoPlaybackMachine()
        _ = machine.handle(.entered(assetID: "A"))
        let became = machine.handle(
            .becameCurrent(assetID: "B", neighbours: [])
        )
        let generation = requestGeneration(in: became, for: "B")
        XCTAssertNotNil(generation)

        // 停稳时资源未到 ⟹ 不播。
        XCTAssertTrue(hintPlays(machine.handle(.pagingSettled)).isEmpty)
        XCTAssertEqual(machine.state(for: "B"), .requesting)

        // 就绪即补播。
        XCTAssertEqual(
            hintPlays(
                machine.handle(
                    .requestSucceeded(assetID: "B", generation: generation ?? 0)
                )
            ),
            ["B"]
        )
    }

    func testIC140A_LateSucceededCallbackOfARetiredPageHasNoEffect() {
        var machine = S2LivePhotoPlaybackMachine()
        _ = machine.handle(.entered(assetID: "A"))
        let became = machine.handle(
            .becameCurrent(assetID: "B", neighbours: [])
        )
        let staleGeneration = requestGeneration(in: became, for: "B")
        XCTAssertNotNil(staleGeneration)

        // 回调到达之前已翻到 C，且 B 不在新半径内 ⟹ 取消在飞请求。
        let leftB = machine.handle(
            .becameCurrent(assetID: "C", neighbours: [])
        )
        XCTAssertTrue(
            leftB.contains { effect in
                if case let .cancelRequest(assetID, _) = effect {
                    return assetID == "B"
                }
                return false
            },
            "退离半径的在飞请求未取消"
        )
        XCTAssertEqual(machine.state(for: "B"), .idle)

        // 迟到的旧代次成功：无效果、B 状态不变。
        XCTAssertTrue(
            machine.handle(
                .requestSucceeded(
                    assetID: "B",
                    generation: staleGeneration ?? 0
                )
            ).isEmpty
        )
        XCTAssertEqual(machine.state(for: "B"), .idle)
    }

    // MARK: - 断言 3：半径与持有上限

    func testIC140A_HeldResourcesStayWithinTheRadiusAndTheInstanceCap() {
        XCTAssertEqual(S2MediaMetrics.livePhotoPrefetchRadius, 1)
        XCTAssertEqual(S2MediaMetrics.livePhotoInstanceCap, 3)

        var machine = S2LivePhotoPlaybackMachine()
        _ = machine.handle(.entered(assetID: nil))
        let pages = ["A", "B", "C", "D", "E"]
        var cancelled: [String] = []
        for (index, assetID) in pages.enumerated() {
            var neighbours: [String] = []
            if pages.indices.contains(index - 1) {
                neighbours.append(pages[index - 1])
            }
            if pages.indices.contains(index + 1) {
                neighbours.append(pages[index + 1])
            }
            let effects = machine.handle(
                .becameCurrent(assetID: assetID, neighbours: neighbours)
            )
            for effect in effects {
                if case let .cancelRequest(cancelledID, _) = effect {
                    cancelled.append(cancelledID)
                }
            }
            XCTAssertLessThanOrEqual(
                machine.heldAssetIDs.count,
                S2MediaMetrics.livePhotoInstanceCap,
                "持有数超过上限（当前页 \(assetID)）"
            )
        }

        // 停在 E：当前页与仅有的一个邻居 D 在册，其余全退。
        XCTAssertEqual(machine.heldAssetIDs, ["D", "E"])
        // 退离的三页都在飞，故都产生了取消（顺序无关断言，陷阱 10）。
        XCTAssertEqual(Set(cancelled), ["A", "B", "C"])
    }

    func testIC140A_RetentionSetKeepsCurrentPageAndBothNeighbours() {
        var machine = S2LivePhotoPlaybackMachine()
        _ = machine.handle(.entered(assetID: nil))
        _ = machine.handle(.becameCurrent(assetID: "C", neighbours: ["B", "D"]))
        XCTAssertEqual(machine.heldAssetIDs, ["B", "C", "D"])

        // 超出上限时按距离升序截断——最远的那页不进保留集合。
        XCTAssertEqual(
            S2LivePhotoPlaybackMachine.retentionSet(
                current: "C",
                neighbours: ["B", "D", "E"]
            ),
            ["C", "B", "D"]
        )
    }

    // MARK: - 断言 4：翻走停播

    func testIC140A_FlippingAwayStopsPlaybackAndAtMostOnePageEverPlays() {
        for style in [S2LivePhotoPlaybackStyle.hint, .full] {
            var machine = S2LivePhotoPlaybackMachine()
            _ = machine.handle(.entered(assetID: "A"))
            let became = machine.handle(
                .becameCurrent(assetID: "B", neighbours: [])
            )
            let generation = requestGeneration(in: became, for: "B") ?? 0
            _ = machine.handle(
                .requestSucceeded(assetID: "B", generation: generation)
            )
            switch style {
            case .hint:
                XCTAssertEqual(hintPlays(machine.handle(.pagingSettled)), ["B"])
                XCTAssertEqual(machine.state(for: "B"), .playingHint)
            case .full:
                XCTAssertEqual(
                    fullPlays(machine.handle(.longPressBegan)),
                    ["B"]
                )
                XCTAssertEqual(machine.state(for: "B"), .playingFull)
            }
            XCTAssertEqual(machine.playingAssetIDs, ["B"])

            // 翻到 C：B 停播（B 仍在半径内，资源留着）。
            let leftB = machine.handle(
                .becameCurrent(assetID: "C", neighbours: ["B"])
            )
            XCTAssertEqual(stops(leftB), ["B"])
            XCTAssertEqual(machine.state(for: "B"), .ready)
            XCTAssertTrue(machine.playingAssetIDs.isEmpty)

            // C 就绪停稳后接着播，任一时刻至多一页在播。
            let generationC = requestGeneration(in: leftB, for: "C") ?? 0
            _ = machine.handle(
                .requestSucceeded(assetID: "C", generation: generationC)
            )
            XCTAssertEqual(hintPlays(machine.handle(.pagingSettled)), ["C"])
            XCTAssertEqual(machine.playingAssetIDs, ["C"])
        }
    }

    // MARK: - 断言 5：探针缺陷的回归防线

    func testIC140B_SecondLongPressPlaysAgainAfterPlaybackEnded() {
        var machine = readyCurrentPageMachine()

        XCTAssertEqual(fullPlays(machine.handle(.longPressBegan)), ["B"])
        XCTAssertEqual(stops(machine.handle(.longPressEnded)), ["B"])
        XCTAssertEqual(machine.state(for: "B"), .ready)

        // 播放自然结束的代理回调把状态收回「就绪」。IC-137 探针未设代理，
        // 状态停在 playing，长按（含放大后）因此恒为空操作。
        _ = machine.handle(.playbackEnded(assetID: "B"))
        XCTAssertEqual(machine.state(for: "B"), .ready)

        // 第二次长按必须能再播。
        XCTAssertEqual(fullPlays(machine.handle(.longPressBegan)), ["B"])
    }

    func testIC140B_PlaybackEndedDuringHintReturnsToReady() {
        var machine = readyCurrentPageMachine()
        XCTAssertEqual(hintPlays(machine.handle(.pagingSettled)), ["B"])
        XCTAssertEqual(machine.state(for: "B"), .playingHint)

        XCTAssertEqual(stops(machine.handle(.playbackEnded(assetID: "B"))), ["B"])
        XCTAssertEqual(machine.state(for: "B"), .ready)
        XCTAssertTrue(machine.playingAssetIDs.isEmpty)
    }

    func testIC140B_LongPressDuringHintSwitchesToFullImmediately() {
        var machine = readyCurrentPageMachine()
        XCTAssertEqual(hintPlays(machine.handle(.pagingSettled)), ["B"])
        XCTAssertEqual(fullPlays(machine.handle(.longPressBegan)), ["B"])
        XCTAssertEqual(machine.state(for: "B"), .playingFull)
    }

    func testIC140B_LongPressBeforeReadyPlaysFullAsSoonAsTheResourceArrives() {
        var machine = S2LivePhotoPlaybackMachine()
        _ = machine.handle(.entered(assetID: "A"))
        let became = machine.handle(
            .becameCurrent(assetID: "B", neighbours: [])
        )
        let generation = requestGeneration(in: became, for: "B") ?? 0

        // 未就绪长按：无效果，但「按住中」记下了。
        XCTAssertTrue(machine.handle(.longPressBegan).isEmpty)
        XCTAssertTrue(machine.isPressing)

        XCTAssertEqual(
            fullPlays(
                machine.handle(
                    .requestSucceeded(assetID: "B", generation: generation)
                )
            ),
            ["B"]
        )
    }

    func testIC140B_ReleasingBeforeReadyFallsBackToTheHintOnly() {
        var machine = S2LivePhotoPlaybackMachine()
        _ = machine.handle(.entered(assetID: "A"))
        let became = machine.handle(
            .becameCurrent(assetID: "B", neighbours: [])
        )
        let generation = requestGeneration(in: became, for: "B") ?? 0

        XCTAssertTrue(machine.handle(.longPressBegan).isEmpty)
        _ = machine.handle(.pagingSettled)
        XCTAssertTrue(machine.handle(.longPressEnded).isEmpty)
        XCTAssertFalse(machine.isPressing)

        let effects = machine.handle(
            .requestSucceeded(assetID: "B", generation: generation)
        )
        XCTAssertEqual(hintPlays(effects), ["B"])
        XCTAssertTrue(fullPlays(effects).isEmpty, "松手后仍走了全段播放")
    }

    // MARK: - 断言 6：几何纪律（源码扫描带正对照）

    func testIC140B_PlaybackLayerWritesNoGeometryOfItsOwn() {
        guard let text = sourceText(
            "PhotoCleanupMVE/Features/S2/S2LivePhotoPlayback.swift"
        ) else {
            return XCTFail("读不到播放层源码")
        }

        // 名字拼接构造，否则本断言会抓到自己所在文件里的这几行。
        for banned in [
            "translatesAutoresizingMask" + "IntoConstraints",
            "NSLayout" + "Constraint",
            "autoresizing" + "Mask",
        ] {
            XCTAssertEqual(
                occurrences(of: banned, in: text),
                0,
                "播放层自设了几何：\(banned)"
            )
        }

        // 唯一允许的几何写入是 layoutSubviews 里对子视图的 frame = bounds。
        let frameWrites = occurrences(of: ".frame = ", in: text)
        XCTAssertEqual(frameWrites, 1, "播放层出现了额外的 frame 写入")
        XCTAssertEqual(
            occurrences(of: ".frame = bounds", in: text),
            frameWrites,
            "存在不是取 bounds 的 frame 写入"
        )
        // 正对照：隐式动画关闭恰出现 1 次，且与那次写入在同一个函数体里。
        XCTAssertEqual(
            occurrences(of: "CATransaction.setDisableActions(true)", in: text),
            1
        )
        XCTAssertTrue(
            layoutSubviewsBody(in: text)
                .contains("CATransaction.setDisableActions(true)"),
            "layoutSubviews 里没有关闭隐式动画"
        )
        XCTAssertTrue(
            layoutSubviewsBody(in: text).contains(".frame = bounds"),
            "frame = bounds 不在 layoutSubviews 里"
        )

        // 陷阱 19：起播只出现在效果执行那一处，宿主视图不自行起播。
        XCTAssertEqual(
            occurrences(of: "startPlayback(", in: text),
            1,
            "播放层出现了第二个起播点"
        )

        // 分页器那条几何链一字未动。
        guard let pager = sourceText(
            "PhotoCleanupMVE/Features/S2/S2NativePhotoPager.swift"
        ) else {
            return XCTFail("读不到分页器源码")
        }
        XCTAssertEqual(occurrences(of: "writePhotoGeometry", in: pager), 5)
    }

    // MARK: - 断言 7：挂载口径

    func testIC140B_OnlyLivePagesCarryAPlaybackLayer() {
        XCTAssertNotNil(S2LivePhotoLayerPresentation.make(mediaKind: .live))
        XCTAssertNil(S2LivePhotoLayerPresentation.make(mediaKind: .photo))
        XCTAssertNil(S2LivePhotoLayerPresentation.make(mediaKind: .video))
        XCTAssertEqual(
            S2LivePhotoLayerPresentation.make(mediaKind: .live)?.acceptsHits,
            false
        )

        // 声音口径是模型字段，不是 UIKit 读数（规格第 9 条）。
        XCTAssertTrue(S2LivePhotoPlaybackStyle.hint.isMuted)
        XCTAssertFalse(S2LivePhotoPlaybackStyle.full.isMuted)
    }

    // MARK: - 断言 8：长按挂起与恢复

    func testIC140C_LongPressSuspendsPagingVerticalSwipeAndZoomPan() {
        let machine = makeMachine()
        let controller = makePagerController()
        var beganCount = 0
        var endedCount = 0
        applyPager(
            controller,
            machine: machine,
            onLongPressBegan: {
                beganCount += 1
                return true
            },
            onLongPressEnded: { endedCount += 1 }
        )
        let page = tryUnwrap(controller.pageControllers[machine.currentIndex])

        XCTAssertTrue(controller.pagingScrollView.isScrollEnabled)
        XCTAssertTrue(page.verticalSwipeRecognizer.isEnabled)

        XCTAssertTrue(controller.beginLongPressSuspensionIfNeeded())
        XCTAssertEqual(beganCount, 1)
        XCTAssertTrue(controller.isLongPressSuspending)
        XCTAssertFalse(controller.pagingScrollView.isScrollEnabled)
        XCTAssertFalse(page.verticalSwipeRecognizer.isEnabled)
        XCTAssertFalse(page.zoomScrollView.panGestureRecognizer.isEnabled)

        // 恢复：1x 时 Nx 平移**仍禁**（P7 规则，不得直接写 true）。
        controller.endLongPressSuspension()
        XCTAssertEqual(endedCount, 1)
        XCTAssertFalse(controller.isLongPressSuspending)
        XCTAssertTrue(controller.pagingScrollView.isScrollEnabled)
        XCTAssertTrue(page.verticalSwipeRecognizer.isEnabled)
        XCTAssertEqual(
            page.zoomScrollView.zoomScale,
            page.zoomScrollView.minimumZoomScale,
            accuracy: 0.000_001
        )
        XCTAssertFalse(
            page.zoomScrollView.panGestureRecognizer.isEnabled,
            "1x 时 Nx 平移被直接写成了 true"
        )

        // 正对照：放大后恢复，Nx 平移才开。
        XCTAssertGreaterThan(
            page.zoomScrollView.maximumZoomScale,
            page.zoomScrollView.minimumZoomScale,
            "夹具的最大缩放不大于最小缩放，放大态正对照无法成立"
        )
        page.zoomScrollView.zoomScale = page.zoomScrollView.maximumZoomScale
        XCTAssertTrue(controller.beginLongPressSuspensionIfNeeded())
        XCTAssertFalse(page.zoomScrollView.panGestureRecognizer.isEnabled)
        controller.endLongPressSuspension()
        XCTAssertTrue(
            page.zoomScrollView.panGestureRecognizer.isEnabled,
            "放大态恢复后 Nx 平移仍被禁"
        )
    }

    func testIC140C_LongPressOnANonLivePageChangesNoGestureSwitch() {
        let machine = makeMachine()
        let controller = makePagerController()
        applyPager(
            controller,
            machine: machine,
            onLongPressBegan: { false },
            onLongPressEnded: {}
        )
        let page = tryUnwrap(controller.pageControllers[machine.currentIndex])
        let pagingBefore = controller.pagingScrollView.isScrollEnabled
        let verticalBefore = page.verticalSwipeRecognizer.isEnabled
        let panBefore = page.zoomScrollView.panGestureRecognizer.isEnabled

        XCTAssertFalse(controller.beginLongPressSuspensionIfNeeded())
        XCTAssertFalse(controller.isLongPressSuspending)
        XCTAssertEqual(controller.pagingScrollView.isScrollEnabled, pagingBefore)
        XCTAssertEqual(page.verticalSwipeRecognizer.isEnabled, verticalBefore)
        XCTAssertEqual(
            page.zoomScrollView.panGestureRecognizer.isEnabled,
            panBefore
        )
    }

    // MARK: - 断言 9：长按时长常量归一

    func testIC140C_LongPressDurationIsRegisteredOnceAndSharedByBothRecognizers() {
        guard let pager = sourceText(
            "PhotoCleanupMVE/Features/S2/S2NativePhotoPager.swift"
        ) else {
            return XCTFail("读不到分页器源码")
        }
        XCTAssertEqual(
            occurrences(
                of: "minimumPressDuration = S2MediaMetrics" +
                    ".longPressMinimumDuration",
                in: pager
            ),
            1
        )
        XCTAssertEqual(
            occurrences(of: "minimumPressDuration = 0.8", in: pager),
            0,
            "分页器仍写着字面量 0.8"
        )
        XCTAssertEqual(S2MediaMetrics.longPressMinimumDuration, 0.8)
    }

    // MARK: - 断言 10：停稳钩子

    func testIC140C_PagingSettledFiresOncePerSettleAndNotOnInitialLayout() {
        let machine = makeMachine(
            orderedAssetIDs: (1...4).map { "asset-\($0)" },
            currentIndex: 0
        )
        let controller = makePagerController()
        var settledCount = 0
        applyPager(
            controller,
            machine: machine,
            onLongPressBegan: { false },
            onLongPressEnded: {},
            onPagingSettled: { settledCount += 1 }
        )
        let window = UIWindow(
            frame: CGRect(origin: .zero, size: physicalSize)
        )
        window.rootViewController = controller
        window.isHidden = false
        defer { window.isHidden = true }
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.03))

        // 初始布局不触发。
        XCTAssertEqual(settledCount, 0, "进场首帧就报了停稳")

        let paging = controller.pagingScrollView
        controller.scrollViewWillBeginDragging(paging)
        paging.setContentOffset(
            paging.contentOffsetForPage(at: 1),
            animated: false
        )
        controller.scrollViewDidEndDecelerating(paging)

        XCTAssertEqual(settledCount, 1, "一次停稳未恰报一次")
        XCTAssertEqual(machine.currentIndex, 1)
    }

    // MARK: - 断言 12：S2View 接线（源码扫描带正对照）

    func testIC140D_ViewWiringReplacesTheRecorderAndKeepsTheDispatchInPlace() {
        guard let text = sourceText(
            "PhotoCleanupMVE/Features/S2/S2View.swift"
        ) else {
            return XCTFail("读不到 S2View 源码")
        }

        // 记录器已删（名字拼接构造，避免抓到本文件自身之外的注释）。
        for removed in [
            "S2LivePhotoLongPress" + "Recorder",
            "livePhotoLongPress" + ".record(",
        ] {
            XCTAssertEqual(
                occurrences(of: removed, in: text),
                0,
                "S2View 仍引用 \(removed)"
            )
        }

        // 三个新闭包各恰一处接线。
        for label in ["onLongPressBegan:", "onLongPressEnded:", "onPagingSettled:"] {
            XCTAssertEqual(
                occurrences(of: label, in: text),
                1,
                "\(label) 不是恰一处接线"
            )
        }

        // IC-139 断言 9 的分派落点仍在位。
        XCTAssertTrue(text.contains("handleMainPhotoLongPress()"))

        // 播放层只在实况分支构造。
        XCTAssertEqual(
            occurrences(of: "assetMediaKind(assetID) == .live", in: text),
            1,
            "播放层的构造条件不是恰一处"
        )

        // 规格第 4 条：上滑标记、下滑取消不向协调器发任何事件。
        // 协调器调用点全集恰这六处，多一处就说明有别的路径在发事件。
        let calls = [
            "livePlayback.enter(",
            "livePlayback.leave()",
            "livePlayback.longPressBegan()",
            "livePlayback.longPressEnded()",
            "livePlayback.pagingSettled()",
            "livePlayback.pageBecameCurrent(",
        ]
        for call in calls {
            XCTAssertEqual(
                occurrences(of: call, in: text),
                1,
                "\(call) 不是恰一处"
            )
        }
        XCTAssertEqual(
            occurrences(of: "livePlayback.", in: text),
            calls.count,
            "S2View 里出现了清单之外的协调器调用点"
        )
    }

    // MARK: - 夹具

    private func readyCurrentPageMachine() -> S2LivePhotoPlaybackMachine {
        var machine = S2LivePhotoPlaybackMachine()
        _ = machine.handle(.entered(assetID: "A"))
        let became = machine.handle(
            .becameCurrent(assetID: "B", neighbours: [])
        )
        let generation = requestGeneration(in: became, for: "B") ?? 0
        _ = machine.handle(
            .requestSucceeded(assetID: "B", generation: generation)
        )
        return machine
    }

    private func requestGeneration(
        in effects: [S2LivePhotoPlaybackEffect],
        for assetID: String
    ) -> Int? {
        for effect in effects {
            if case let .request(requestedID, generation) = effect,
               requestedID == assetID {
                return generation
            }
        }
        return nil
    }

    private func hintPlays(_ effects: [S2LivePhotoPlaybackEffect]) -> [String] {
        effects.compactMap { effect in
            if case let .playHint(assetID) = effect {
                return assetID
            }
            return nil
        }
    }

    private func fullPlays(_ effects: [S2LivePhotoPlaybackEffect]) -> [String] {
        effects.compactMap { effect in
            if case let .playFull(assetID) = effect {
                return assetID
            }
            return nil
        }
    }

    private func stops(_ effects: [S2LivePhotoPlaybackEffect]) -> [String] {
        effects.compactMap { effect in
            if case let .stop(assetID) = effect {
                return assetID
            }
            return nil
        }
    }

    private func occurrences(of needle: String, in haystack: String) -> Int {
        haystack.components(separatedBy: needle).count - 1
    }

    /// 截取宿主视图 `layoutSubviews` 的函数体，供几何纪律的同函数体断言用。
    private func layoutSubviewsBody(in text: String) -> String {
        guard let start = text.range(of: "override func layoutSubviews() {") else {
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
                sessionID: "session-140",
                rangeDisplayInformation: S2RangeDisplayInformation(
                    rangeID: "range-140",
                    displayName: "IC-140",
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

    /// 与 `S2CalibrationHarnessTests.makeNativePagerController` 同源的构造：
    /// 直接建控制器、给视口尺寸，再走 `apply`。那个夹具是 private，
    /// 跨测试类调不到，故在这里按同一形状复刻。
    private func makePagerController() -> S2NativePagerViewController {
        let controller = S2NativePagerViewController()
        controller.loadViewIfNeeded()
        controller.view.frame = CGRect(origin: .zero, size: physicalSize)
        return controller
    }

    private func applyPager(
        _ controller: S2NativePagerViewController,
        machine: S2StateMachine,
        onLongPressBegan: @escaping () -> Bool,
        onLongPressEnded: @escaping () -> Void,
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
            onLongPressBegan: onLongPressBegan,
            onLongPressEnded: onLongPressEnded,
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
