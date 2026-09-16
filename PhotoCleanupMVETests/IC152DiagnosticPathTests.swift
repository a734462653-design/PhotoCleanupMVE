import Combine
import Foundation
import SwiftUI
import UIKit
import XCTest
@testable import PhotoCleanupMVE

/// IC-152：诊断路径两处——拆除期向状态机发布（真机可达的产品缺陷）与中间帧门禁阈值。
///
/// 依据：Decision_log 第 174 条（#292 attempt 1 的真实死因是宿主崩溃不是计时抖动：
/// SwiftUI 拆除分页器 → `resetInteractionState()` → 收尾在飞的双击过渡 → 完成回调
/// 报告视口 → 写 `@Published` → 视图图失效期间发布 → `Fatal access conflict`）。
///
/// 断言编号与任务卡一一对应：1～3 属子项 A，4～6 属子项 B（断言 7 沿用既有的
/// `testIC063AutomaticGeometryDiagnosticsExportsAllRequiredStages`，不在本文件）。
///
/// **子项 A 的夹具全部是夹具驱动，真机未覆盖**（陷阱 1）：它复现的是「拆除期间
/// 状态机被发布」这个缺陷的根，复现不了致命退出本身（那要撞上 SwiftUI 视图图
/// 失效的时机）。真机落点由 H74 四项兜底。
final class IC152DiagnosticPathTests: XCTestCase {
    private let physicalSize = CGSize(width: 300, height: 600)

    private var screenAspectRatio: CGFloat {
        physicalSize.width / physicalSize.height
    }

    /// 双击落点取视口**左上区域**，不取正中。
    ///
    /// 夹具几何是满视口的屏幕同比例截图：若落点取正中，放大后内容恰好居中，
    /// `reportedViewportOffset()` 回报 `.zero`，与状态机双击时写入的 `.zero`
    /// 相等，IC-095 R4「等值不发布」会把那次报告吞掉——夹具就触不到 K2 的
    /// 写入点（任务卡子项 A 第 4 步「夹具未触到链条」的情形）。左上落点让放大
    /// 后的偏移被钳到内容边缘，回报的视口偏移必不为零，这也正是真机上用户
    /// 随手双击时最常见的情形。`beginDiagnosticDoubleTap` 把落点写死在视口正中，
    /// 故夹具按它的同一套调用（先 `handleNativeDoubleTap`、再
    /// `startDoubleTapTransition` 带诊断时长）自行起飞，只换落点。
    private var offCenterFocusPoint: CGPoint {
        CGPoint(x: physicalSize.width * 0.1, y: physicalSize.height * 0.1)
    }

    // MARK: - 断言 1：拆除在飞的过渡，状态机零次发布，每一层都清干净

    /// R1（拆除窗口内 `objectWillChange` 0 次）、R2（六层逐项）、R5（诊断观察者
    /// 收不到 `.completed`）。
    ///
    /// **改前复现（本机读码结论，未单独推 CI——任务卡明令）**：改前
    /// `resetInteractionState()` 对每页调的就是 `finishActiveDoubleTapTransition()`，
    /// 与显示链接自然跑完时调的是**同一个函数**、同一组守卫；因此改前拆除窗口内
    /// 的发布次数 = 自然收口时的发布次数，后者由断言 2 在同一夹具里实测 ≥ 1。
    ///
    /// 拆除直接调 `S2NativePhotoPager.dismantleUIViewController(_:coordinator:)`
    /// ——即 #292a1 崩溃栈第 22 帧、SwiftUI 拆除时调用的那个产品入口。不经 SwiftUI
    /// 触发拆除的理由见本卡自验报告：计数窗口可精确对齐到拆除调用本身；且若修复
    /// 不完整，SwiftUI 驱动的拆除会在视图图失效期间发布、把整个测试宿主打崩，
    /// 直调则把残留的发布变成一条干净的断言失败。
    func testIC152A_DismantleMidTransitionPublishesNothing() {
        let machine = makeStateMachine()
        let controller = makePagerController()
        applyPager(controller, machine: machine)
        let window = attachWindow(to: controller)
        defer { window.isHidden = true }
        let page = tryUnwrap(controller.pageControllers[machine.currentIndex])
        let content = tryUnwrap(page.zoomScrollView.presentationContentView)

        // R2 第 4 层的观测点：一只真实的视频宿主，过渡起飞时它的播放层会被借走。
        let hostView = S2VideoHostView(assetID: machine.currentAssetID)
        hostView.frame = content.bounds
        content.addSubview(hostView)
        hostView.layoutIfNeeded()

        // R2 第 1 层的观测点：丝滑度探针在**每一次**显示链接回调里记一帧，
        // 而取消不记「结束」，事件保持在途——显示链接若没停，帧数会继续涨。
        let probe = S2DoubleTapSmoothnessProbeCoordinator()
        controller.doubleTapProbe = probe
        probe.start()

        let subviewsBefore = Set(page.view.subviews.map { ObjectIdentifier($0) })
        var progressedCount = 0
        var completedCount = 0
        // 时长给到 3 s：只需停在飞行中，越长越不怕 runner 卡顿让过渡在拆除前自然
        // 跑完。该参数只存在于诊断路径，产品双击时长不经此处。
        let started = startEntryTransition(
            on: page,
            machine: machine,
            durationSeconds: 3
        ) { event in
            switch event {
            case .started:
                break
            case .progressed:
                progressedCount += 1
            case .completed:
                completedCount += 1
            }
        }
        XCTAssertTrue(started, "双击过渡未起飞")
        XCTAssertGreaterThan(machine.scale, 1, "完成回调的 scale>1 守卫在夹具里不成立")

        let deadline = Date(timeIntervalSinceNow: 2)
        while progressedCount == 0,
              page.isDoubleTapTransitionActive,
              Date() < deadline {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
        }

        // 前置：确在飞行中，且六层都处于「借出／隐藏／挂着」的在途态。
        XCTAssertTrue(
            page.isDoubleTapTransitionActive,
            "过渡在拆除前就已收口——夹具没停在飞行中"
        )
        XCTAssertGreaterThan(progressedCount, 0, "拆除前一次进度回调都没有")
        XCTAssertTrue(content.isHidden, "在途时页内容应被隐藏")
        XCTAssertFalse(page.zoomScrollView.isUserInteractionEnabled)
        XCTAssertTrue(hostView.isLendingPlaybackLayer, "在途时播放层应借给过渡视图")
        let addedSubviews = page.view.subviews.filter {
            !subviewsBefore.contains(ObjectIdentifier($0))
        }
        XCTAssertEqual(addedSubviews.count, 1, "过渡视图没有挂到页视图上")
        let transitionView = addedSubviews.first
        let framesAtDismantle = probe.events.last?.totalFrameCount ?? 0
        XCTAssertGreaterThan(framesAtDismantle, 0, "探针一帧都没记，显示链接那一层的观测是空转")

        // 拆除窗口：只数这一段。
        var publishCount = 0
        let subscription = machine.objectWillChange.sink { _ in
            publishCount += 1
        }
        S2NativePhotoPager.dismantleUIViewController(controller, coordinator: ())
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.3))
        subscription.cancel()

        // R1
        XCTAssertEqual(
            publishCount,
            0,
            "拆除路径上状态机被发布了 " + String(publishCount) + " 次"
        )
        // R5：诊断观察者在拆除时收不到 `.completed`，也就不会去等稳定态。
        XCTAssertEqual(completedCount, 0, "拆除时仍向观察者发了 .completed")
        XCTAssertNil(controller.diagnosticsRun)

        // R2 六层
        XCTAssertEqual(
            probe.events.last?.totalFrameCount ?? 0,
            framesAtDismantle,
            "显示链接在拆除后仍在回调"
        )
        XCTAssertNil(transitionView?.superview, "过渡视图没有移走")
        XCTAssertEqual(
            Set(page.view.subviews.map { ObjectIdentifier($0) }),
            subviewsBefore,
            "页视图的子视图没有回到起飞前"
        )
        XCTAssertFalse(content.isHidden, "页内容仍被隐藏")
        XCTAssertFalse(hostView.isLendingPlaybackLayer, "播放层没有交还")
        XCTAssertTrue(
            hostView.diagnosticPlaybackLayerSuperlayer === hostView.layer,
            "播放层没有挂回宿主"
        )
        XCTAssertFalse(page.isDoubleTapTransitionActive, "在途标志没有清")
        XCTAssertTrue(page.zoomScrollView.isUserInteractionEnabled, "滚动视图交互没有恢复")
    }

    // MARK: - 断言 2：正对照——不拆除，自然收口照常报告视口

    /// R3：同一夹具不拆除、让过渡跑到 `.completed`，计数器 ≥ 1——证明计数器与
    /// D3 → D4 → D5 → K2 这条链在夹具里都是活的，断言 1 的「0」因此不是空转。
    ///
    /// 计数窗口从过渡起飞之后开始（双击本身对状态机的写入不计），此后显示链接
    /// 的进度回调不碰状态机，能发布的只有收口时那次视口报告。
    func testIC152A_NormalCompletionStillReportsViewport() {
        let machine = makeStateMachine()
        let controller = makePagerController()
        applyPager(controller, machine: machine)
        let window = attachWindow(to: controller)
        defer { window.isHidden = true }
        let page = tryUnwrap(controller.pageControllers[machine.currentIndex])

        var completedCount = 0
        let started = startEntryTransition(
            on: page,
            machine: machine,
            durationSeconds: S2DiagnosticDoubleTapTiming.durationSeconds(
                minimumMiddleFrames: 3
            )
        ) { event in
            if case .completed = event {
                completedCount += 1
            }
        }
        XCTAssertTrue(started, "双击过渡未起飞")

        var publishCount = 0
        let subscription = machine.objectWillChange.sink { _ in
            publishCount += 1
        }
        let deadline = Date(timeIntervalSinceNow: 5)
        while page.isDoubleTapTransitionActive, Date() < deadline {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
        }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        subscription.cancel()

        XCTAssertFalse(page.isDoubleTapTransitionActive, "过渡未在期限内自然收口")
        XCTAssertNotNil(page.lastDoubleTapSynchronization)
        XCTAssertEqual(completedCount, 1, "自然收口应恰向观察者发一次 .completed")
        XCTAssertGreaterThanOrEqual(
            publishCount,
            1,
            "自然收口没有向状态机报告视口——计数器或链条是死的，断言 1 的 0 不可信"
        )
    }

    // MARK: - 断言 3：视口几何进状态机的唯一入口不变

    /// R4：K2 `S2StateMachine.reportNativeViewport(scale:viewportOffset:)` 仍是视口
    /// 几何进状态机的唯一入口（陷阱 19）；分页器内它的调用点数量与改前相同。
    ///
    /// 改前实读（IC-152 开工时对 `0bedaea` 剔注释计数）：`machine.reportNativeViewport(`
    /// 恰 **1** 处。`Core/S2StateMachine.swift` 不在本卡 diff 内由自验报告的
    /// `git diff` 实证（XCTest 读不到 git 历史）。
    func testIC152A_ViewportReportEntryUnchanged() throws {
        let pager = try XCTUnwrap(sourceWithoutComments(Self.pagerPath))
        XCTAssertEqual(
            occurrences(of: "machine.reportNativeViewport(", in: pager),
            1,
            "分页器向状态机报告视口的调用点数量变了"
        )

        // 取消路径不落几何、不回调所有者、不发事件——拆除零发布的结构性保证。
        let cancelBody = try XCTUnwrap(
            slice(
                pager,
                from: "func cancelActiveDoubleTapTransition() {",
                to: Self.memberClose
            ),
            "取消函数没切到——声明文本变了，断言会静默放空"
        )
        for forbidden in [
            "reportNativeViewport",
            "doubleTapTransitionDidComplete",
            "doubleTapTransitionObserver",
            "applyDoubleTapTarget",
            "applyNativeState",
            "applyPageImmediately",
            "setContentOffset",
            "setZoomScale"
        ] {
            XCTAssertEqual(
                occurrences(of: forbidden, in: cancelBody),
                0,
                "取消路径里出现了 " + forbidden
            )
        }
        // 正对照：切到的确实是那段清理代码。
        XCTAssertEqual(occurrences(of: "reclaimPlaybackLayer()", in: cancelBody), 1)
        XCTAssertEqual(occurrences(of: "removeFromSuperview()", in: cancelBody), 1)

        // 拆除入口不再收尾，且顺序是「诊断退场 → 摘观察者 → 取消」。
        let resetBody = try XCTUnwrap(
            slice(
                pager,
                from: "func resetInteractionState() {",
                to: Self.memberClose
            )
        )
        XCTAssertEqual(
            occurrences(of: "finishActiveDoubleTapTransition", in: resetBody),
            0,
            "拆除入口仍在收尾"
        )
        let cancelRun = try XCTUnwrap(resetBody.range(of: "diagnosticsRun?.cancel()"))
        let clearObserver = try XCTUnwrap(
            resetBody.range(of: "doubleTapTransitionObserver = nil")
        )
        let cancelTransition = try XCTUnwrap(
            resetBody.range(of: "cancelActiveDoubleTapTransition()")
        )
        XCTAssertLessThan(cancelRun.lowerBound, cancelTransition.lowerBound)
        XCTAssertLessThan(clearObserver.lowerBound, cancelTransition.lowerBound)

        // 正对照：K2 在状态机里确实存在且只有一处声明。
        let machineSource = try XCTUnwrap(
            sourceWithoutComments("PhotoCleanupMVE/Core/S2StateMachine.swift")
        )
        XCTAssertEqual(
            occurrences(of: "func reportNativeViewport(", in: machineSource),
            1
        )
    }

    // MARK: - 夹具

    private static let pagerPath =
        "PhotoCleanupMVE/Features/S2/S2NativePhotoPager.swift"

    /// 成员级收口：换行 + 四空格缩进的右花括号 + 换行。用 `UnicodeScalar` 拼而不写
    /// 转义字面量（本机 heredoc 会吞反斜杠，IC-148 #294 实例）。
    private static let memberClose =
        String(Character(UnicodeScalar(UInt8(10)))) + "    }"
            + String(Character(UnicodeScalar(UInt8(10))))

    /// 照 `S2NativePagerViewController.beginDiagnosticDoubleTap` 的同一套调用起飞一次
    /// 进入 Nx 的双击过渡，只把落点换成左上区域（理由见 `offCenterFocusPoint`）。
    private func startEntryTransition(
        on page: S2NativeZoomPageController,
        machine: S2StateMachine,
        durationSeconds: TimeInterval,
        observer: @escaping (S2DoubleTapTransitionEvent) -> Void
    ) -> Bool {
        guard machine.handleNativeDoubleTap(
            targetScale: page.doubleTapTargetScale
        ) else {
            return false
        }
        var configuration = S2CalibrationConfiguration.factoryPlaceholder
        configuration.animationsEnabled = true
        page.doubleTapTransitionObserver = observer
        return page.startDoubleTapTransition(
            enteringNx: true,
            targetScale: machine.scale,
            at: offCenterFocusPoint,
            configuration: configuration,
            durationOverrideSeconds: durationSeconds
        )
    }

    private func makeStateMachine(
        orderedAssetIDs: [String] = ["asset-1", "asset-2", "asset-3"],
        currentIndex: Int = 1
    ) -> S2StateMachine {
        let configuration = S2CalibrationConfiguration.factoryPlaceholder
        let resolvedIndex = min(max(0, currentIndex), orderedAssetIDs.count - 1)
        return tryUnwrap(S2StateMachine(
            entry: S2EntryContext(
                sessionID: "session-152",
                rangeDisplayInformation: S2RangeDisplayInformation(
                    rangeID: "range-152",
                    displayName: "IC-152",
                    totalAssetCount: orderedAssetIDs.count
                ),
                orderedAssetIDs: orderedAssetIDs,
                currentAssetID: orderedAssetIDs[resolvedIndex],
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
        ))
    }

    /// 与 `S2CalibrationHarnessTests.makeNativePagerController` 同源的构造（那个夹具
    /// 是 private，跨测试类调不到，故按同一形状复刻；IC-140／141／143 同做）。
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

    /// 与既有分页器夹具同源：挂窗口、跑一次布局与 runloop，页控制器才成形；
    /// 挂上窗口后双击过渡才会真的起一只显示链接（无窗口时走零时长早收口）。
    private func attachWindow(
        to controller: S2NativePagerViewController
    ) -> UIWindow {
        let window = UIWindow(frame: CGRect(origin: .zero, size: physicalSize))
        window.rootViewController = controller
        window.isHidden = false
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.03))
        return window
    }

    // MARK: - 源码扫描 helper

    private func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func sourceText(_ relativePath: String) -> String? {
        try? String(
            contentsOf: repoRoot().appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }

    /// 读源码并**只**剔掉 `//` 注释，**保留**字符串字面量（含引号）。
    ///
    /// 与 IC146／IC148 的 `strippedSource` 不同：那一只连字面量内容一并剔掉，
    /// 拿它去找只可能出现在字面量里的 needle（本卡断言 6 的正对照
    /// `中间帧软目标未达：`）恒为 0——正是 IC-149 门禁二要抓的 #295 那类病。
    /// 这里照样跟踪字符串状态，字面量里的 `//` 不会被误当成注释起点。
    private func sourceWithoutComments(_ relativePath: String) -> String? {
        guard let source = sourceText(relativePath) else {
            return nil
        }
        let newline = Character(UnicodeScalar(UInt8(10)))
        var output = ""
        var iterator = source.startIndex
        var inString = false
        while iterator < source.endIndex {
            let character = source[iterator]
            let next = source.index(after: iterator)
            if inString {
                output.append(character)
                if character == "\\", next < source.endIndex {
                    output.append(source[next])
                    iterator = source.index(after: next)
                    continue
                }
                if character == "\"" {
                    inString = false
                }
                iterator = next
                continue
            }
            if character == "\"" {
                inString = true
                output.append(character)
                iterator = next
                continue
            }
            if character == "/", next < source.endIndex, source[next] == "/" {
                while iterator < source.endIndex,
                      source[iterator] != newline {
                    iterator = source.index(after: iterator)
                }
                output.append(newline)
                continue
            }
            output.append(character)
            iterator = next
        }
        return output
    }

    private func occurrences(of needle: String, in haystack: String) -> Int {
        guard !needle.isEmpty else {
            return 0
        }
        var count = 0
        var searchStart = haystack.startIndex
        while let found = haystack.range(
            of: needle,
            range: searchStart..<haystack.endIndex
        ) {
            count += 1
            searchStart = found.upperBound
        }
        return count
    }

    private func slice(
        _ source: String,
        from start: String,
        to end: String
    ) -> String? {
        guard let startRange = source.range(of: start),
              let endRange = source.range(
                  of: end,
                  range: startRange.upperBound..<source.endIndex
              ) else {
            return nil
        }
        return String(source[startRange.lowerBound..<endRange.lowerBound])
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
