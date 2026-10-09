import SwiftUI
import UIKit
import XCTest
@testable import PhotoCleanupMVE

/// IC-182：教学引导二轮（Decision_log 第 211 条 ④）——首次标记那一下不自动翻页；S5 五步编号圆统一描边、正文单行按需缩放。
///
/// 断言 1 钉「标记后停留」开关的行为（默认关 = 既有自动翻页；开 = 停在刚标记那张且只吃一次；最后一张与
/// 隐藏态不受影响），3 钉源码落位（状态机、S2View 把协调器判据同步给状态机的六处、S5 新文件的统一描边与缩放），
/// 4 钉 v23 三句 key 已退役、第 2 步副句沿用原句。**IC-197 起**：v23 三句（`S2InlineHints.swift`）退役，判据改由
/// 引导 D 的 `S2GuideCoordinator` 给出（IC-195 测试 B 覆盖），原断言 1b（旧协调器判据）与断言 2（三句落位口径）随旧族整删。
/// 观感（停留那一瞬、S5 单行）归真机。
final class IC182TutorialRoundTwoTests: XCTestCase {
    private static let s2ViewPath = "PhotoCleanupMVE/Features/S2/S2View.swift"
    private static let machinePath = "PhotoCleanupMVE/Core/S2StateMachine.swift"
    private static let guidePath = "PhotoCleanupMVE/Features/Shared/S5GuideStepsView.swift"
    private static let catalogPath = "PhotoCleanupMVE/Localizable.xcstrings"
    private static let newline = String(Character(UnicodeScalar(UInt8(10))))
    private let viewportSize = CGSize(width: 300, height: 600)

    // MARK: - 断言 1：「本次标记后停留」开关

    func testIC182A_HoldAfterFirstMarkOnlyOnce() {
        // 默认关：既有行为——标记并翻到下一张（与 `testIC047_006` 同一口径）。
        let plain = makeMachine()
        XCTAssertFalse(plain.holdsPageAfterNextMark)
        XCTAssertTrue(plain.handleSwipeUp())
        XCTAssertTrue(plain.pendingDeletionAssetIDs.contains("asset-2"))
        XCTAssertEqual(plain.currentAssetID, "asset-3")

        // 开：标记成功但停在刚标记这张；开关吃掉一次；下一次上滑照旧翻页。
        let held = makeMachine()
        held.holdsPageAfterNextMark = true
        XCTAssertTrue(held.handleSwipeUp())
        XCTAssertTrue(held.pendingDeletionAssetIDs.contains("asset-2"))
        XCTAssertEqual(held.currentAssetID, "asset-2", "首次学习停在刚标记的这张")
        XCTAssertFalse(held.holdsPageAfterNextMark, "只吃一次")
        XCTAssertEqual(held.state, .visibleOneXIdle)
        XCTAssertNil(held.pendingUndecidedItem, "停留不是「最后一张」——不发未决项")
        // 停留后下滑当场可撤（第 2 句落在正确的照片上）。
        XCTAssertTrue(held.handleSwipeDown())
        XCTAssertFalse(held.pendingDeletionAssetIDs.contains("asset-2"))
        XCTAssertEqual(held.currentAssetID, "asset-2")
        // 再标记：开关已关，翻页。
        XCTAssertTrue(held.handleSwipeUp())
        XCTAssertEqual(held.currentAssetID, "asset-3")

        // 开着但上滑无效（已标记再上滑只脉冲）：开关不被吃掉。
        let alreadyMarked = makeMachine(pendingDeletionAssetIDs: ["asset-1", "asset-2"])
        alreadyMarked.holdsPageAfterNextMark = true
        XCTAssertFalse(alreadyMarked.handleSwipeUp())
        XCTAssertTrue(alreadyMarked.holdsPageAfterNextMark, "没标记成功就不算那一次")
        XCTAssertEqual(alreadyMarked.currentAssetID, "asset-2")

        // 隐藏态 1x 上滑完全无效果（IC-104 B）：开关同样不动。
        let hidden = makeMachine(visibility: .hidden)
        hidden.holdsPageAfterNextMark = true
        XCTAssertFalse(hidden.handleSwipeUp())
        XCTAssertTrue(hidden.holdsPageAfterNextMark)

        // 开着且已是最后一张：标记成功、停留、不发「最后一张」未决项（停留本来就不翻）。
        let last = makeMachine(currentAssetID: "asset-3")
        last.holdsPageAfterNextMark = true
        XCTAssertTrue(last.handleSwipeUp())
        XCTAssertEqual(last.currentAssetID, "asset-3")
        XCTAssertNil(last.pendingUndecidedItem)
        XCTAssertFalse(last.holdsPageAfterNextMark)
        // 关着的最后一张：照旧发 `.item02`（既有行为不变）。
        let lastPlain = makeMachine(currentAssetID: "asset-3")
        XCTAssertTrue(lastPlain.handleSwipeUp())
        XCTAssertEqual(lastPlain.pendingUndecidedItem, .item02)

        // 放大态（Nx）开着：停留只在 1x 生效——照旧标记并翻页（翻页归 1x），开关留待下一次 1x 标记。
        let zoomed = makeMachine(scale: 2)
        XCTAssertEqual(zoomed.state, .visibleNxIdle)
        zoomed.holdsPageAfterNextMark = true
        XCTAssertTrue(zoomed.handleSwipeUp())
        XCTAssertTrue(zoomed.pendingDeletionAssetIDs.contains("asset-2"))
        XCTAssertEqual(zoomed.currentAssetID, "asset-3", "Nx 不停留")
        XCTAssertEqual(zoomed.state, .visibleOneXIdle, "翻页归 1x（既有行为）")
        XCTAssertTrue(zoomed.holdsPageAfterNextMark, "开关留待 1x")
        XCTAssertTrue(zoomed.handleSwipeUp())
        XCTAssertEqual(zoomed.currentAssetID, "asset-3", "1x 上那一下才停")
        XCTAssertFalse(zoomed.holdsPageAfterNextMark)
    }

    // MARK: - 断言 3：源码落位

    func testIC182C_SourceWiring() throws {
        // 状态机：开关默认关、只在 `handleSwipeUp` 标记成功后读、读一次即清。
        let machine = try XCTUnwrap(strippedSource(Self.machinePath))
        XCTAssertEqual(occurrences(of: "holdsPageAfterNextMark", in: machine), 3, "声明、判、清")
        XCTAssertEqual(occurrences(of: "var holdsPageAfterNextMark = false", in: machine), 1)
        let swipeUp = try XCTUnwrap(slice(machine, from: "func handleSwipeUp() -> Bool {", to: "func handleSwipeDown() -> Bool {"))
        XCTAssertEqual(occurrences(of: "if holdsPageAfterNextMark && zoomState == .oneX {", in: swipeUp), 1, "停留只在 1x")
        XCTAssertEqual(occurrences(of: "resetZoomAfterPhotoChange()", in: swipeUp), 0, "停留不碰倍率（分页器只在翻页后同步）")
        XCTAssertEqual(occurrences(of: "holdsPageAfterNextMark = false", in: swipeUp), 1)
        XCTAssertEqual(occurrences(of: "switchPhoto(by: 1)", in: swipeUp), 1, "自动翻页仍是同一处")
        let holdRange = try XCTUnwrap(swipeUp.range(of: "if holdsPageAfterNextMark && zoomState == .oneX {"))
        let markRange = try XCTUnwrap(swipeUp.range(of: "replacePendingDeletionAssetIDs(with: nextPending)"))
        let switchRange = try XCTUnwrap(swipeUp.range(of: "switchPhoto(by: 1)"))
        XCTAssertLessThan(markRange.lowerBound, holdRange.lowerBound, "先写 D 再判停留")
        XCTAssertLessThan(holdRange.lowerBound, switchRange.lowerBound, "停留分支挡在翻页之前")
        XCTAssertEqual(occurrences(of: "pendingUndecidedItem = .item02", in: swipeUp), 1)

        // S2View（IC-197 起）：进门、撤标回调末、当前张变化回调末、在显一项变化、「重看教程」、「跳过教程」六处
        // 把引导 D 协调器的判据同步给状态机；判据只在协调器。
        let s2 = try XCTUnwrap(strippedSource(Self.s2ViewPath))
        let s2Raw = try XCTUnwrap(sourceText(Self.s2ViewPath))
        XCTAssertEqual(occurrences(of: "machine.holdsPageAfterNextMark", in: s2), 6)
        XCTAssertEqual(occurrences(of: "machine.holdsPageAfterNextMark = guide.holdsPageOnNextMark", in: s2), 6, "判据只在协调器，视图只同步")
        XCTAssertEqual(occurrences(of: "machine.holdsPageAfterNextMark = true", in: s2), 0)
        XCTAssertEqual(occurrences(of: "machine.holdsPageAfterNextMark = false", in: s2), 0)
        XCTAssertEqual(occurrences(of: ".onChange(of: guide.display) {", in: s2), 1)
        let startRange = try XCTUnwrap(s2.range(of: "guide.start(mergedCount:"))
        let holdSetRange = try XCTUnwrap(s2.range(of: "machine.holdsPageAfterNextMark = guide.holdsPageOnNextMark"))
        XCTAssertLessThan(startRange.lowerBound, holdSetRange.lowerBound, "先开引导再同步开关（同一 onAppear）")
        for call in ["guide.reset()", "guide.skip()", "guide.assetDidBecomeUnmarked(", "guide.currentAssetDidChange("] {
            XCTAssertEqual(occurrences(of: call, in: s2), 1, call)
            let callRange = try XCTUnwrap(s2.range(of: call), call)
            let after = s2[callRange.upperBound...]
            let sync = try XCTUnwrap(after.range(of: "machine.holdsPageAfterNextMark = guide.holdsPageOnNextMark"), call)
            XCTAssertLessThan(after.distance(from: after.startIndex, to: sync.lowerBound), 200, call + " 之后紧跟同步")
        }
        // IC172／IC168 正对照不变。
        XCTAssertEqual(occurrences(of: "colorScheme, .dark)", in: s2Raw), 6)
        XCTAssertEqual(occurrences(of: ".background(.regularMaterial)", in: s2), 3)

        // S5：五步统一描边、正文单行按需缩放、登记 13。
        let guide = try XCTUnwrap(strippedSource(Self.guidePath))
        XCTAssertEqual(occurrences(of: "isLeadStep", in: guide), 0)
        XCTAssertEqual(occurrences(of: "in: Circle())", in: guide), 0)
        XCTAssertEqual(occurrences(of: "strokeBorder(", in: guide), 1)
        XCTAssertEqual(occurrences(of: ".lineLimit(1)", in: guide), 1)
        XCTAssertEqual(occurrences(of: ".minimumScaleFactor(S5GuideMetrics.textMinimumScaleFactor)", in: guide), 1)
        XCTAssertEqual(occurrences(of: "S1ChromeForeground.", in: guide), 4)
        XCTAssertEqual(occurrences(of: "@ViewBuilder", in: guide), 0, "编号圆不再分支")
        let guideMetrics = try XCTUnwrap(slice(guide, from: "enum S5GuideMetrics {", to: Self.newline + "}" + Self.newline))
        XCTAssertEqual(occurrences(of: "static let ", in: guideMetrics), 13)
        XCTAssertEqual(S5GuideMetrics.textMinimumScaleFactor, 0.8)
    }

    // MARK: - 断言 4：目录（IC-197 起 v23 七条 `s2.hint.*` 退役）

    func testIC182D_CatalogHintKeysRetired() throws {
        let catalog = try XCTUnwrap(sourceText(Self.catalogPath))
        for key in ["s2.hint.swipe_up", "s2.hint.swipe_up.sub", "s2.hint.marked", "s2.hint.marked.sub", "s2.hint.confirm", "s2.hint.confirm.sub", "s2.hint.dismiss"] {
            XCTAssertEqual(occurrences(of: "\"" + key + "\" : {", in: catalog), 0, key)
        }
        XCTAssertEqual(L10n.text("s2.guide.marked.sub"), "标错了？下滑放回来。", "停留后这句才落在正确的照片上——第 2 步副句沿用原句")
        for key in ["s5.guide.step1", "s5.guide.step2", "s5.guide.step3", "s5.guide.step4", "s5.guide.step5"] {
            XCTAssertEqual(occurrences(of: "\"" + key + "\" : {", in: catalog), 1, key)
        }
    }

    // MARK: - 夹具（照抄 `S2StateMachineTests.makeMachine` 的三张范围）

    private func makeMachine(
        pendingDeletionAssetIDs: Set<String> = ["asset-1"],
        currentAssetID: String = "asset-2",
        visibility: S2InterfaceVisibility = .visible,
        scale: CGFloat = 1
    ) -> S2StateMachine {
        let countBox = IC182CountBox(value: pendingDeletionAssetIDs.count)
        let entry = S2EntryContext(
            sessionID: "session-182",
            rangeDisplayInformation: S2RangeDisplayInformation(
                rangeID: "range-182",
                displayName: "测试范围",
                totalAssetCount: 3
            ),
            orderedAssetIDs: ["asset-1", "asset-2", "asset-3"],
            currentAssetID: currentAssetID,
            pendingDeletionAssetIDs: pendingDeletionAssetIDs,
            sessionMergedPendingDeletionCountProvider: { countBox.value }
        )
        return S2StateMachine(
            entry: entry,
            initialPresentation: S2InitialPresentation(
                interfaceVisibility: visibility,
                scale: scale,
                viewportOffset: .zero
            ),
            parameters: parameters,
            imageRequestStrategy: nil,
            initialFavoriteAssetIDs: [],
            initialRecentAlbum: nil,
            pendingDeletionDidChange: { countBox.value = $0.count },
            recentAlbumDidChange: { _ in }
        )!
    }

    private var parameters: S2ResolvedParameters {
        S2ResolvedParameters(
            pinchMaxScaleFloor: 4,
            pinchMaxScaleCeiling: 40,
            pinchMaxScaleOneToOneMultiplier: 6,
            zoomSnapBackThreshold: 1.2,
            minDoubleTapScale: 2.5,
            doubleTapAnchorStrategy: .touchPoint,
            edgePagingTriggerDistance: 40,
            edgePagingTriggerVelocity: 300,
            verticalSwipeDistance: 40,
            verticalSwipeVelocity: 100,
            bottomStripMetrics: S2BottomStripMetrics(
                currentItemSize: 30,
                neighborItemWidth: 20,
                neighborItemHeight: 30,
                itemSpacing: 3,
                currentItemGap: 13,
                edgeFadeWidth: 18.7,
                leadingInset: 20.3,
                switchDistance: 23,
                decelerationRate: 0.998,
                expandDurationMilliseconds: 600,
                collapseDurationMilliseconds: 100,
                flickVelocityThreshold: 300,
                cornerRadius: 8.0 / 3.0
            )
        )!
    }

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

    /// 读源码并剔掉 `//` 注释与字符串字面量内容。
    private func strippedSource(_ relativePath: String) -> String? {
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
                if character == "\\" {
                    iterator = next < source.endIndex
                        ? source.index(after: next)
                        : source.endIndex
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

    private func slice(_ text: String, from start: String, to end: String) -> String? {
        guard let startRange = text.range(of: start) else {
            return nil
        }
        let rest = text[startRange.upperBound...]
        guard let endRange = rest.range(of: end) else {
            return nil
        }
        return String(rest[..<endRange.lowerBound])
    }

    private func occurrences(of needle: String, in haystack: String) -> Int {
        guard !needle.isEmpty else {
            return 0
        }
        var count = 0
        var searchRange = haystack.startIndex..<haystack.endIndex
        while let found = haystack.range(of: needle, range: searchRange) {
            count += 1
            searchRange = found.upperBound..<haystack.endIndex
        }
        return count
    }
}

private final class IC182CountBox {
    var value: Int

    init(value: Int) {
        self.value = value
    }
}
