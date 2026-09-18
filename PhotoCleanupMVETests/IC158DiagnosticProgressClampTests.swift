import Foundation
import SwiftUI
import UIKit
import XCTest
@testable import PhotoCleanupMVE

/// IC-158：几何诊断双击过渡的进度步长上限——宿主主线程停顿时，把「一步跳到终点」
/// 拉成「逐回调分步走完」，中间帧阈值一个不漏；产品双击路径逐字不变。
///
/// 依据：Decision_log 第 174 条（中间帧门禁就是帧数门禁，放宽测试侧断言治不了红）、
/// 第 178 条（硬下限 2、软目标 3／5）、第 183 条第四节第 1 条与第 184 条末段，
/// 与任务卡 IC-20260917-158 的四条裁定。断言编号与任务卡一一对应：1～4 属子项 A，
/// 5 属子项 B。本文件随两个子项的提交逐段加入：A 建文件（断言 1～4 与夹具），
/// B 把断言 5 插在断言 4 之后、夹具之前。可摘取单元是 A 单独、A→B；断言 5 追加在
/// A 建的文件里，按提交不能脱离 A 单独摘取。
///
/// **夹具驱动，真机未覆盖**（陷阱 1）：断言 2／3 用 `Thread.sleep` 确定性复现主线程
/// 停顿，复现不了 runner 上真实的调度抖动；真机导出诊断的落点由 H79 兜底。
final class IC158DiagnosticProgressClampTests: XCTestCase {
    private let physicalSize = CGSize(width: 300, height: 600)

    private var screenAspectRatio: CGFloat {
        physicalSize.width / physicalSize.height
    }

    /// 双击落点取视口左上区域，不取正中（理由见 `IC152DiagnosticPathTests`：正中落点
    /// 会让回报的视口偏移恒为 `.zero`，夹具触不到写入点）。
    private var offCenterFocusPoint: CGPoint {
        CGPoint(x: physicalSize.width * 0.1, y: physicalSize.height * 0.1)
    }

    // MARK: - 断言 1：步长 = 阈值间距的四分之一，缓动后增量不到一个间距

    /// 裁定 一的数值前提：线性步 1/(4(n+1)) 对应的**缓动后**增量在整个 [0, 1) 上都小于
    /// 阈值间距 1/(n+1)——这正是「每次回调至多跨一个阈值」（IC-152 G5）在停顿后仍成立
    /// 的理由。本机 Python 复算：n=3 → 0.107492（< 0.25），n=5 → 0.071761（< 0.1667）。
    func testIC158A_StepIsQuarterSpacingAndEasedIncrementStaysUnderOneSpacing() {
        XCTAssertEqual(
            S2DiagnosticDoubleTapTiming.maximumLinearProgressStep(
                minimumMiddleFrames: 3
            ),
            1.0 / 16,
            accuracy: 1e-9
        )
        XCTAssertEqual(
            S2DiagnosticDoubleTapTiming.maximumLinearProgressStep(
                minimumMiddleFrames: 5
            ),
            1.0 / 24,
            accuracy: 1e-9
        )
        // `max(1, n)` 与 `durationSeconds` 同口径。
        XCTAssertEqual(
            S2DiagnosticDoubleTapTiming.maximumLinearProgressStep(
                minimumMiddleFrames: 0
            ),
            1.0 / 8,
            accuracy: 1e-9
        )
        // 正对照：本卡不动的诊断时长照旧。
        XCTAssertEqual(
            S2DiagnosticDoubleTapTiming.durationSeconds(minimumMiddleFrames: 3),
            1.0,
            accuracy: 1e-9
        )
        XCTAssertEqual(
            S2DiagnosticDoubleTapTiming.durationSeconds(minimumMiddleFrames: 5),
            1.4,
            accuracy: 1e-9
        )

        for minimumMiddleFrames in [3, 5] {
            let step = S2DiagnosticDoubleTapTiming.maximumLinearProgressStep(
                minimumMiddleFrames: minimumMiddleFrames
            )
            let spacing = 1 / CGFloat(minimumMiddleFrames + 1)
            var worstIncrement: CGFloat = 0
            for tick in 0..<1_000 {
                let x = CGFloat(tick) / 1_000
                let increment =
                    S2DoubleTapTransitionTiming.easedProgress(min(1, x + step))
                        - S2DoubleTapTransitionTiming.easedProgress(x)
                XCTAssertGreaterThanOrEqual(
                    increment,
                    0,
                    "缓动不单调：n=\(minimumMiddleFrames) x=\(x)"
                )
                worstIncrement = max(worstIncrement, increment)
            }
            XCTAssertLessThan(
                worstIncrement,
                spacing,
                "n=\(minimumMiddleFrames)：一次回调可能跨过一个阈值"
            )
            // 余量：实测最大增量不到半个间距。
            XCTAssertLessThan(
                worstIncrement,
                spacing / 2,
                "n=\(minimumMiddleFrames)：余量不足半个间距"
            )
        }
    }

    // MARK: - 断言 2：带上限的过渡穿过一次主线程停顿，阈值一个不漏

    func testIC158A_ClampedTransitionWalksThroughAMainThreadStall() {
        let machine = makeStateMachine()
        let controller = makePagerController()
        applyPager(controller, machine: machine)
        let window = attachWindow(to: controller)
        defer { window.isHidden = true }
        let page = tryUnwrap(controller.pageControllers[machine.currentIndex])

        var progressValues: [CGFloat] = []
        var completedCount = 0
        let started = startEntryTransition(
            on: page,
            machine: machine,
            durationSeconds: 1,
            maximumLinearProgressStep: 1.0 / 16
        ) { event in
            switch event {
            case .started:
                break
            case let .progressed(_, value):
                progressValues.append(value)
            case .completed:
                completedCount += 1
            }
        }
        XCTAssertTrue(started, "双击过渡未起飞")

        // 硬前置：停顿之前确已有回调在走。起始时刻是**第一次**回调才落的，第一次回调
        // 进度恒 0、不进样本数组；样本 ≥ 1 即至少两次回调已到。
        let stallPrecondition = Date(timeIntervalSinceNow: 1)
        while page.doubleTapTransitionProgressSamples.isEmpty,
              page.isDoubleTapTransitionActive,
              Date() < stallPrecondition {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
        }
        guard !page.doubleTapTransitionProgressSamples.isEmpty else {
            XCTFail("停顿前无回调，本条复现不成立")
            return
        }
        let beforeStallCount = progressValues.count
        XCTAssertGreaterThanOrEqual(
            progressValues.filter { $0 < 1 }.count,
            1,
            "停顿前一次进度<1 的回调都没有"
        )

        // 主线程停顿，长于过渡时长：醒来后第一次回调的墙钟进度已越过终点。
        Thread.sleep(forTimeInterval: 1.2)

        let finishDeadline = Date(timeIntervalSinceNow: 5)
        while page.isDoubleTapTransitionActive, Date() < finishDeadline {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
        }
        XCTAssertFalse(page.isDoubleTapTransitionActive, "过渡未在期限内收口")
        XCTAssertEqual(completedCount, 1, "自然收口应恰发一次 .completed")
        XCTAssertGreaterThanOrEqual(
            page.doubleTapClampedCallbackCount,
            1,
            "步长上限一次都没触发——停顿没有被夹紧"
        )

        let afterStall = Array(progressValues[beforeStallCount...])
        XCTAssertGreaterThanOrEqual(
            afterStall.filter { $0 < 1 }.count,
            8,
            "停顿后没有分步走完：进度<1 的回调只有 "
                + String(afterStall.filter { $0 < 1 }.count) + " 次"
        )

        // 逐个非递减，且相邻增量不超过缓动后的上界（断言 1 实测 0.107492）。
        var previous: CGFloat = 0
        for value in progressValues {
            XCTAssertGreaterThanOrEqual(value, previous - 1e-9)
            XCTAssertLessThanOrEqual(value - previous, 0.1075 + 1e-6)
            previous = value
        }

        // 用与产品同一条规则重算阈值消费：阈值 (1…3)/4、每次回调最多消费一个、
        // 且只在 progress < 1 时消费（`:4494-4496` 三个条件一个不少）。
        XCTAssertEqual(
            consumedThresholds(in: progressValues, minimumMiddleFrames: 3),
            3,
            "停顿后仍有中间帧阈值没采到"
        )

        XCTAssertEqual(tryUnwrap(progressValues.last), 1, accuracy: 1e-9)
        XCTAssertNotNil(page.lastDoubleTapSynchronization)
    }

    // MARK: - 断言 3：负对照——不带上限（产品路径）停顿后一步跳到终点

    func testIC158A_UnclampedPathStillJumpsToCompletionAfterAStall() {
        let machine = makeStateMachine()
        let controller = makePagerController()
        applyPager(controller, machine: machine)
        let window = attachWindow(to: controller)
        defer { window.isHidden = true }
        let page = tryUnwrap(controller.pageControllers[machine.currentIndex])

        var progressValues: [CGFloat] = []
        var completedCount = 0
        let started = startEntryTransition(
            on: page,
            machine: machine,
            durationSeconds: 1,
            maximumLinearProgressStep: nil
        ) { event in
            switch event {
            case .started:
                break
            case let .progressed(_, value):
                progressValues.append(value)
            case .completed:
                completedCount += 1
            }
        }
        XCTAssertTrue(started, "双击过渡未起飞")

        let stallPrecondition = Date(timeIntervalSinceNow: 1)
        while page.doubleTapTransitionProgressSamples.isEmpty,
              page.isDoubleTapTransitionActive,
              Date() < stallPrecondition {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
        }
        guard !page.doubleTapTransitionProgressSamples.isEmpty else {
            XCTFail("停顿前无回调，本条复现不成立")
            return
        }
        let beforeStallCount = progressValues.count

        Thread.sleep(forTimeInterval: 1.2)

        let finishDeadline = Date(timeIntervalSinceNow: 5)
        while page.isDoubleTapTransitionActive, Date() < finishDeadline {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
        }
        XCTAssertFalse(page.isDoubleTapTransitionActive, "过渡未在期限内收口")
        XCTAssertEqual(completedCount, 1)
        XCTAssertEqual(
            page.doubleTapClampedCallbackCount,
            0,
            "默认路径不该夹紧"
        )

        let afterStall = Array(progressValues[beforeStallCount...])
        XCTAssertEqual(
            tryUnwrap(afterStall.first),
            1,
            accuracy: 1e-9,
            "停顿后的第一次回调没有一步跳到终点——停顿复现不成立"
        )
        XCTAssertEqual(
            afterStall.filter { $0 < 1 }.count,
            0,
            "停顿后不该再有进度<1 的回调"
        )
        // 同一条三条件规则重算：停顿前进度太小，阈值远远采不满。
        XCTAssertLessThan(
            consumedThresholds(in: progressValues, minimumMiddleFrames: 3),
            3,
            "不夹紧却把三个阈值都采到了——停顿复现不成立"
        )
    }

    // MARK: - 断言 4：只有诊断入口传上限，IC-152 的钉一处不动

    func testIC158A_OnlyTheDiagnosticsEntryPassesTheStepAndIC152PinsHold() throws {
        let pager = try XCTUnwrap(sourceWithoutComments(Self.pagerPath))
        XCTAssertEqual(
            occurrences(of: "maximumLinearProgressStep: CGFloat? = nil", in: pager),
            1,
            "起飞签名的新形参不是恰一处"
        )
        // 形参一处 + 诊断入口实参一处，别处不传。
        XCTAssertEqual(occurrences(of: "maximumLinearProgressStep:", in: pager), 2)
        XCTAssertEqual(
            occurrences(
                of: "static func maximumLinearProgressStep(minimumMiddleFrames: Int) -> CGFloat",
                in: pager
            ),
            1
        )
        XCTAssertEqual(occurrences(of: "page.startDoubleTapTransition(", in: pager), 3)

        let diagnosticEntry = try XCTUnwrap(
            slice(
                pager,
                from: "func beginDiagnosticDoubleTap(",
                to: Self.memberClose
            ),
            "诊断入口没切到——声明文本变了，断言会静默放空"
        )
        XCTAssertEqual(
            occurrences(
                of: "S2DiagnosticDoubleTapTiming.maximumLinearProgressStep(",
                in: diagnosticEntry
            ),
            1
        )
        XCTAssertEqual(
            occurrences(of: "durationOverrideSeconds:", in: diagnosticEntry),
            1
        )

        // 三个状态量：声明、清零、读写。
        XCTAssertGreaterThanOrEqual(
            occurrences(of: "doubleTapClampedCallbackCount", in: pager),
            3
        )
        XCTAssertGreaterThanOrEqual(
            occurrences(of: "doubleTapLastLinearProgress", in: pager),
            3
        )
        // 声明跨三行，needle 不带 ` {`（带了会切空）。
        let advanceBody = try XCTUnwrap(
            slice(
                pager,
                from: "func advanceDoubleTapTransition(",
                to: Self.memberClose
            ),
            "推进函数没切到——声明文本变了，断言会静默放空"
        )
        XCTAssertGreaterThanOrEqual(
            occurrences(of: "doubleTapMaximumLinearProgressStep", in: advanceBody),
            1
        )
        XCTAssertEqual(occurrences(of: "easedProgress(", in: advanceBody), 1)

        // 取消路径不加行（IC-152 断言 3 的同一段）。
        let cancelBody = try XCTUnwrap(
            slice(
                pager,
                from: "func cancelActiveDoubleTapTransition() {",
                to: Self.memberClose
            ),
            "取消函数没切到——声明文本变了，断言会静默放空"
        )
        for symbol in [
            "doubleTapMaximumLinearProgressStep",
            "doubleTapLastLinearProgress",
            "doubleTapClampedCallbackCount"
        ] {
            XCTAssertEqual(occurrences(of: symbol, in: cancelBody), 0, symbol)
        }
        // 正对照：切到的确实是那段清理代码（口径同 IC-152 断言 3）。
        XCTAssertEqual(occurrences(of: "reclaimPlaybackLayer()", in: cancelBody), 1)

        // IC-152 断言 6 的六个 needle 原样重申：本卡一处不动。
        XCTAssertEqual(occurrences(of: "errors.append(", in: pager), 2)
        XCTAssertEqual(
            occurrences(of: "secondsPerThreshold: TimeInterval = 0.2", in: pager),
            1
        )
        XCTAssertEqual(occurrences(of: "minimumMiddleFrames: 3", in: pager), 1)
        XCTAssertEqual(occurrences(of: "minimumMiddleFrames: 5", in: pager), 1)
        XCTAssertEqual(
            occurrences(
                of: "CGFloat($0) / CGFloat(minimumMiddleFrames + 1)",
                in: pager
            ),
            1
        )
        XCTAssertEqual(
            occurrences(of: "self.middleThresholds.removeFirst()", in: pager),
            1
        )
        // 产品双击时长与硬下限也不动。
        XCTAssertEqual(
            occurrences(of: "durationSeconds: TimeInterval = 0.3", in: pager),
            1
        )
        XCTAssertEqual(occurrences(of: "static let hardFloor = 2", in: pager), 1)
        XCTAssertEqual(
            occurrences(of: "machine.reportNativeViewport(", in: pager),
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

    /// 按产品门禁的同一条规则重算阈值消费：阈值 (1…n)/(n+1)，每次回调最多消费一个，
    /// 且只在 `progress < 1` 时消费。
    private func consumedThresholds(
        in progressValues: [CGFloat],
        minimumMiddleFrames: Int
    ) -> Int {
        var thresholds = (1...minimumMiddleFrames).map {
            CGFloat($0) / CGFloat(minimumMiddleFrames + 1)
        }
        var hits = 0
        for value in progressValues {
            if let threshold = thresholds.first,
               value >= threshold,
               value < 1 {
                hits += 1
                thresholds.removeFirst()
            }
        }
        return hits
    }

    /// 照 `beginDiagnosticDoubleTap` 的同一套调用起飞一次进入 Nx 的双击过渡（照
    /// `IC152DiagnosticPathTests` 的同名夹具，多带一个步长上限形参透传），只换落点。
    private func startEntryTransition(
        on page: S2NativeZoomPageController,
        machine: S2StateMachine,
        durationSeconds: TimeInterval,
        maximumLinearProgressStep: CGFloat?,
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
            durationOverrideSeconds: durationSeconds,
            maximumLinearProgressStep: maximumLinearProgressStep
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
                sessionID: "session-158",
                rangeDisplayInformation: S2RangeDisplayInformation(
                    rangeID: "range-158",
                    displayName: "IC-158",
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
    /// 是 private，跨测试类调不到，故按同一形状复刻；IC-140／141／143／152 同做）。
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

    /// 挂窗口、跑一次布局与 runloop：挂上窗口后双击过渡才会真起一只显示链接
    /// （无窗口时走零时长早收口）。
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

    // MARK: - 源码扫描 helper（口径同 IC-152：只剔注释，保留字符串字面量）

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

    /// 读源码并**只**剔掉 `//` 注释，**保留**字符串字面量（含引号）：本文件的 needle
    /// 里有只可能出现在字面量里的串，喂给连字面量一并剔掉的变体会恒为 0。
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
