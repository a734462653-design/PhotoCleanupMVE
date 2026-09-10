import AVFoundation
import SwiftUI
import UIKit
import XCTest
@testable import PhotoCleanupMVE

/// IC-144：视频页双击回 1x 画面连续（借出的播放层不改尺寸）+ `park` 对
/// `.ready` 态补静音。
///
/// **本卡只做视频页**：`S2LivePhotoPlayback.swift` 零改动。
/// 断言 1～3 走分页器夹具，与真机事件序列不同源（陷阱 1）——夹具能钉的是
/// 「尺寸没被改过、落位仍重合、收口复位」这组几何事实，**钉不到**「用户眼里
/// 是否连续」，后者由 H67 第 1 项兜底。断言 4 是源码扫描，断言 6 是纯 reducer。
final class IC144VideoExitTransitionTests: XCTestCase {
    private let physicalSize = CGSize(width: 300, height: 600)
    /// 落位重合的容差（卡内规格第 1 条：0.5 pt 内）。
    private let placementAccuracy: CGFloat = 0.5

    private var screenAspectRatio: CGFloat {
        physicalSize.width / physicalSize.height
    }

    // MARK: - 断言 1：退出路径（Nx → 1x）借出层尺寸不变

    func testIC144A_ExitTransitionKeepsTheBorrowedLayerSize() {
        assertBorrowedLayerKeepsItsSize(enteringNx: false)
    }

    // MARK: - 断言 2：进入路径（1x → Nx）同一组量成立

    func testIC144A_EnterTransitionKeepsTheBorrowedLayerSize() {
        assertBorrowedLayerKeepsItsSize(enteringNx: true)
    }

    /// 两条路径共用的量：借出期间尺寸不变、落位与过渡视图重合、承载者是过渡
    /// 视图；收口后变换复位、帧回宿主 bounds、层序不变。
    private func assertBorrowedLayerKeepsItsSize(enteringNx: Bool) {
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

        let boundsBefore = hostView.diagnosticPlaybackLayerBounds
        let indexBefore = hostView.diagnosticPlaybackLayerIndex
        XCTAssertGreaterThan(boundsBefore.width, 0, "夹具里播放层未成形")
        XCTAssertTrue(
            hostView.diagnosticPlaybackLayerIsIdentityTransform,
            "借出前变换就不是恒等"
        )

        // 退出路径必须先进放大态，起始帧才会 ≠ 宿主 bounds——那正是改前
        // 「一写 frame 就改尺寸」的触发条件。
        if !enteringNx {
            page.zoomScrollView.applyNativeState(
                scale: 2,
                viewportOffset: .zero
            )
            page.view.setNeedsLayout()
            page.view.layoutIfNeeded()
        }

        let started = page.startDoubleTapTransition(
            enteringNx: enteringNx,
            targetScale: enteringNx ? 2 : 1,
            at: CGPoint(x: physicalSize.width / 2, y: physicalSize.height / 2),
            configuration: .factoryPlaceholder,
            durationOverrideSeconds: 1
        )
        XCTAssertTrue(started, "双击过渡未起飞（enteringNx=\(enteringNx)）")

        // 借出期间：尺寸一动不动。
        XCTAssertEqual(
            hostView.diagnosticPlaybackLayerBounds.size.width,
            boundsBefore.size.width,
            accuracy: 0.000_001,
            "借出改了播放层的宽（enteringNx=\(enteringNx)）"
        )
        XCTAssertEqual(
            hostView.diagnosticPlaybackLayerBounds.size.height,
            boundsBefore.size.height,
            accuracy: 0.000_001,
            "借出改了播放层的高（enteringNx=\(enteringNx)）"
        )

        // 承载者是过渡视图，且视觉落位仍与它重合（`frame` 含 transform）。
        let superlayer = tryUnwrap(hostView.diagnosticPlaybackLayerSuperlayer)
        XCTAssertFalse(superlayer === hostView.layer, "播放层没被借出去")
        let transitionView = tryUnwrap(
            page.view.subviews.first { $0.layer === superlayer }
        )
        assertRectsClose(
            hostView.diagnosticPlaybackLayerFrame,
            transitionView.bounds,
            message: "借出层的落位与过渡视图不重合（enteringNx=\(enteringNx)）"
        )
        // 退出路径上起始帧确实 ≠ 宿主 bounds，否则本断言测不到东西。
        if !enteringNx {
            XCTAssertGreaterThan(
                transitionView.bounds.width,
                boundsBefore.width + placementAccuracy,
                "退出路径的起始帧没有放大，正对照不成立"
            )
        }

        // 收口：变换复位、帧回宿主 bounds、承载者与层序回到借出前。
        page.finishActiveDoubleTapTransition()
        XCTAssertTrue(
            hostView.diagnosticPlaybackLayerIsIdentityTransform,
            "收口后变换未复位（enteringNx=\(enteringNx)）"
        )
        XCTAssertTrue(
            hostView.diagnosticPlaybackLayerSuperlayer === hostView.layer,
            "收口后播放层未交还宿主"
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

    // MARK: - 断言 3：借出期间布局回调对借出层无副作用

    func testIC144A_LayoutDuringLendingLeavesTheBorrowedLayerAlone() {
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

        let boundsDuring = hostView.diagnosticPlaybackLayerBounds
        let positionDuring = hostView.diagnosticPlaybackLayerPosition
        let frameDuring = hostView.diagnosticPlaybackLayerFrame

        // 借出期间来一次布局：三个量都不许动。
        hostView.setNeedsLayout()
        hostView.layoutIfNeeded()

        XCTAssertEqual(hostView.diagnosticPlaybackLayerBounds, boundsDuring)
        XCTAssertEqual(hostView.diagnosticPlaybackLayerPosition, positionDuring)
        XCTAssertEqual(
            hostView.diagnosticPlaybackLayerFrame,
            frameDuring,
            "借出期间的布局回调改了借出层的落位"
        )

        // 收回后仍能正常回位（守卫没把正常路径一起挡掉）。
        page.finishActiveDoubleTapTransition()
        XCTAssertEqual(
            hostView.diagnosticPlaybackLayerFrame,
            hostView.bounds
        )
        XCTAssertTrue(hostView.diagnosticPlaybackLayerIsIdentityTransform)
    }

    // MARK: - 断言 4：源码扫描（带正对照）

    func testIC144A_AttachPlacesTheLayerWithoutResizingIt() {
        guard let pager = sourceText(
            "PhotoCleanupMVE/Features/S2/S2NativePhotoPager.swift"
        ) else {
            return XCTFail("读不到分页器源码")
        }
        let attach = functionBody(
            of: "attachPlaybackLayer",
            in: pager,
            keyword: "func "
        )
        XCTAssertFalse(attach.isEmpty, "未截取到 attachPlaybackLayer 函数体")
        // 不改尺寸：函数体内不写 frame，也不写 bounds。
        XCTAssertEqual(
            occurrences(of: ".frame =", in: attach),
            0,
            "借层时仍在写 frame"
        )
        XCTAssertEqual(
            occurrences(of: ".bounds =", in: attach),
            0,
            "借层时仍在写 bounds"
        )
        // 正对照：改用变换与位置摆放。
        XCTAssertGreaterThanOrEqual(
            occurrences(of: "transform", in: attach),
            1,
            "借层未改用变换摆放"
        )
        XCTAssertGreaterThanOrEqual(
            occurrences(of: "position", in: attach),
            1,
            "借层未摆位置"
        )
        XCTAssertEqual(
            occurrences(of: "writePhotoGeometry", in: pager),
            5,
            "几何链的声明或调用点数量变了"
        )

        guard let video = sourceText(
            "PhotoCleanupMVE/Features/S2/S2VideoPlayback.swift"
        ) else {
            return XCTFail("读不到视频播放源码")
        }
        // IC-141 断言 5 的两族计数原样——收回不新增写入点。
        XCTAssertEqual(occurrences(of: ".frame = ", in: video), 1)
        XCTAssertEqual(
            occurrences(of: "CATransaction.setDisableActions(true)", in: video),
            1
        )
        // 借出期间的布局守卫在位。
        let layout = layoutSubviewsBody(in: video)
        XCTAssertFalse(layout.isEmpty, "未截取到 layoutSubviews 函数体")
        XCTAssertEqual(
            occurrences(of: "isLendingPlaybackLayer", in: layout),
            1,
            "布局回调没有借出期间的守卫"
        )
    }

    // MARK: - 夹具

    private func assertRectsClose(
        _ lhs: CGRect,
        _ rhs: CGRect,
        message: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(
            lhs.minX, rhs.minX, accuracy: placementAccuracy,
            message + "（minX）", file: file, line: line
        )
        XCTAssertEqual(
            lhs.minY, rhs.minY, accuracy: placementAccuracy,
            message + "（minY）", file: file, line: line
        )
        XCTAssertEqual(
            lhs.width, rhs.width, accuracy: placementAccuracy,
            message + "（width）", file: file, line: line
        )
        XCTAssertEqual(
            lhs.height, rhs.height, accuracy: placementAccuracy,
            message + "（height）", file: file, line: line
        )
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

    private func occurrences(of needle: String, in haystack: String) -> Int {
        haystack.components(separatedBy: needle).count - 1
    }

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

    private func sourceText(_ relativePath: String) -> String? {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = root.appendingPathComponent(relativePath)
        return try? String(contentsOf: url, encoding: .utf8)
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
                sessionID: "session-144",
                rangeDisplayInformation: S2RangeDisplayInformation(
                    rangeID: "range-144",
                    displayName: "IC-144",
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
