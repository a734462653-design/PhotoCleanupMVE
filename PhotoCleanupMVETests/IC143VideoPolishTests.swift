import AVFoundation
import SwiftUI
import UIKit
import XCTest
@testable import PhotoCleanupMVE

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

    // MARK: - 夹具

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

    /// 截取某个 `private func` 的函数体（到同缩进的收口括号为止）。
    private func functionBody(of name: String, in text: String) -> String {
        guard let start = text.range(of: "private func " + name) else {
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
