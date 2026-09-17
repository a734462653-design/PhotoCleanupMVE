import Foundation
import SwiftUI
import UIKit
import XCTest
@testable import PhotoCleanupMVE

/// IC-156：批次 5.2b 类别页——三列网格、多选、「移入待删篮」写会话层、返回重算；顶排借
/// S1 chrome、页面登记表新族 `S0CategoryPage`。
///
/// 依据 SPEC-S0 v2（SHA-256 `8A8E…6F44`）第六节、第二节第 3 部分、第四节、第十四节，
/// SPEC-S1 v9 第二节第 2 部分，SPEC-S3-S4 v8 分组呈现要求，与任务卡 IC-20260916-156 的
/// 六条裁定。断言编号与任务卡一一对应：1～2 属子项 A，3～4 属子项 B，5～9 属子项 C，
/// 10～11 属子项 D。本文件随四个子项的提交逐段加入：A 建文件，B 追加在类末尾，C 插在类首，
/// D 紧接 C 之后——各段互不相邻，A→C 不经 B 也能摘取。
///
/// **夹具驱动，真机未覆盖**（陷阱 1）：版式、勾选手感、滚动时的缩略图、toast 观感、
/// 进篮后首页数字同步与 S3 组头，只有 H77 能判。
final class IC156CategoryPageTests: XCTestCase {

    // MARK: - 断言 1：登记表恰 42 个常量、每个带出处（子项 A）

    func testIC156A_RegistryHasFortyTwoConstantsWithProvenance() throws {
        let raw = try XCTUnwrap(sourceText(Self.metricsPath))
        let body = try XCTUnwrap(
            slice(raw, from: "enum S0CategoryPageMetrics {", to: Self.topLevelClose),
            "登记表切片没切到——声明文本变了，下面的计数会静默放空"
        )
        XCTAssertEqual(occurrences(of: Self.newline + "    static let ", in: body), 42)
        XCTAssertGreaterThanOrEqual(occurrences(of: "取值出处：", in: body), 42)
        XCTAssertEqual(occurrences(of: "取值出处：SPEC-S0 v2 第十四节第 2 部分", in: body), 5)
        XCTAssertEqual(occurrences(of: "取值出处：画布 dark.py", in: body), 37)

        // 顶排不在此登记（借 S1 chrome）。扫剔过注释的源码：注释里解释这条规则不算。
        let stripped = try XCTUnwrap(strippedSource(Self.metricsPath))
        let strippedBody = try XCTUnwrap(
            slice(stripped, from: "enum S0CategoryPageMetrics {", to: Self.topLevelClose)
        )
        for chrome in ["S1ChromeLayout", "rowHeight", "horizontalMargin"] {
            XCTAssertEqual(occurrences(of: chrome, in: strippedBody), 0, chrome)
        }
        // 正对照：剔过的切片里常量声明仍是 42 个，扫描不是空转。
        XCTAssertEqual(
            occurrences(of: Self.newline + "    static let ", in: strippedBody),
            42
        )

        // 首页登记表一字不动：仍 52 个，且不含类别页网格。
        let home = try XCTUnwrap(sourceText(Self.homeMetricsPath))
        let homeBody = try XCTUnwrap(
            slice(home, from: "enum S0HomeMetrics {", to: Self.topLevelClose)
        )
        XCTAssertEqual(occurrences(of: Self.newline + "    static let ", in: homeBody), 52)
        XCTAssertEqual(occurrences(of: "gridColumns", in: homeBody), 0)
    }

    // MARK: - 断言 2：42 个值与画布最终稿、v2 登记值逐个相等（子项 A）

    func testIC156A_MetricsValuesMatchCanvas() {
        // v2 已登记 5（SPEC-S0 v2 第十四节第 2 部分）。列数是整数，精确比较。
        XCTAssertEqual(S0CategoryPageMetrics.gridColumns, 3)
        XCTAssertEqual(S0CategoryPageMetrics.gridItemSpacing, 4, accuracy: 0.000_001)
        XCTAssertEqual(S0CategoryPageMetrics.gridCellCornerRadius, 10, accuracy: 0.000_001)
        XCTAssertEqual(S0CategoryPageMetrics.gridSizeLabelFontSize, 11, accuracy: 0.000_001)
        XCTAssertEqual(S0CategoryPageMetrics.gridCheckSide, 22, accuracy: 0.000_001)

        // 页面边距 2
        XCTAssertEqual(S0CategoryPageMetrics.pageHorizontalInset, 20, accuracy: 0.000_001)
        XCTAssertEqual(S0CategoryPageMetrics.textHorizontalInset, 24, accuracy: 0.000_001)

        // 大标题 6
        XCTAssertEqual(S0CategoryPageMetrics.titleTopSpacing, 12, accuracy: 0.000_001)
        XCTAssertEqual(S0CategoryPageMetrics.titleFontSize, 30, accuracy: 0.000_001)
        XCTAssertEqual(S0CategoryPageMetrics.titleLetterSpacing, -0.7, accuracy: 0.000_001)
        XCTAssertEqual(S0CategoryPageMetrics.titleLineHeight, 34, accuracy: 0.000_001)
        XCTAssertEqual(S0CategoryPageMetrics.titleDotSide, 10, accuracy: 0.000_001)
        XCTAssertEqual(S0CategoryPageMetrics.titleDotSpacing, 10, accuracy: 0.000_001)

        // 副行 3
        XCTAssertEqual(S0CategoryPageMetrics.subtitleFontSize, 14, accuracy: 0.000_001)
        XCTAssertEqual(S0CategoryPageMetrics.subtitleOpacity, 0.55, accuracy: 0.000_001)
        XCTAssertEqual(S0CategoryPageMetrics.subtitleTopSpacing, 4, accuracy: 0.000_001)

        // 常驻行 3
        XCTAssertEqual(S0CategoryPageMetrics.pinnedRowTopSpacing, 12, accuracy: 0.000_001)
        XCTAssertEqual(S0CategoryPageMetrics.pinnedRowFontSize, 13, accuracy: 0.000_001)
        XCTAssertEqual(S0CategoryPageMetrics.pinnedRowOpacity, 0.60, accuracy: 0.000_001)

        // 网格位置 2
        XCTAssertEqual(S0CategoryPageMetrics.gridTopSpacing, 12, accuracy: 0.000_001)
        XCTAssertEqual(S0CategoryPageMetrics.gridBadgeInset, 6, accuracy: 0.000_001)

        // 体积标签 4
        XCTAssertEqual(
            S0CategoryPageMetrics.gridSizeLabelBackgroundOpacity,
            0.50,
            accuracy: 0.000_001
        )
        XCTAssertEqual(S0CategoryPageMetrics.gridSizeLabelCornerRadius, 7, accuracy: 0.000_001)
        XCTAssertEqual(
            S0CategoryPageMetrics.gridSizeLabelPaddingHorizontal,
            6,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            S0CategoryPageMetrics.gridSizeLabelPaddingVertical,
            2,
            accuracy: 0.000_001
        )

        // 时长角标 4
        XCTAssertEqual(S0CategoryPageMetrics.gridDurationFontSize, 11, accuracy: 0.000_001)
        XCTAssertEqual(S0CategoryPageMetrics.gridDurationGlyphSpacing, 3, accuracy: 0.000_001)
        XCTAssertEqual(S0CategoryPageMetrics.gridDurationShadowRadius, 4, accuracy: 0.000_001)
        XCTAssertEqual(
            S0CategoryPageMetrics.gridDurationShadowOpacity,
            0.70,
            accuracy: 0.000_001
        )

        // 勾 3 + 选中外圈 1
        XCTAssertEqual(S0CategoryPageMetrics.gridCheckRingWidth, 1.5, accuracy: 0.000_001)
        XCTAssertEqual(S0CategoryPageMetrics.gridCheckRingOpacity, 0.90, accuracy: 0.000_001)
        XCTAssertEqual(
            S0CategoryPageMetrics.gridCheckUnselectedFillOpacity,
            0.25,
            accuracy: 0.000_001
        )
        XCTAssertEqual(S0CategoryPageMetrics.gridSelectedRingWidth, 2, accuracy: 0.000_001)

        // 主按钮 8
        XCTAssertEqual(S0CategoryPageMetrics.ctaBottomInset, 42, accuracy: 0.000_001)
        XCTAssertEqual(S0CategoryPageMetrics.ctaHeight, 52, accuracy: 0.000_001)
        XCTAssertEqual(S0CategoryPageMetrics.ctaCornerRadius, 26, accuracy: 0.000_001)
        XCTAssertEqual(S0CategoryPageMetrics.ctaFontSize, 17, accuracy: 0.000_001)
        XCTAssertEqual(S0CategoryPageMetrics.ctaShadowYOffset, 10, accuracy: 0.000_001)
        XCTAssertEqual(S0CategoryPageMetrics.ctaShadowRadius, 30, accuracy: 0.000_001)
        XCTAssertEqual(S0CategoryPageMetrics.ctaShadowOpacity, 0.45, accuracy: 0.000_001)
        XCTAssertEqual(S0CategoryPageMetrics.ctaDisabledOpacity, 0.35, accuracy: 0.000_001)

        // 渐隐 1
        XCTAssertEqual(S0CategoryPageMetrics.fadeHeight, 190, accuracy: 0.000_001)

        // 前缀与三枚符号名。
        XCTAssertEqual(S0CategoryPageRange.prefix, "cat:")
        let symbols = [
            S0CategoryPageSymbol.back,
            S0CategoryPageSymbol.play,
            S0CategoryPageSymbol.check
        ]
        XCTAssertEqual(symbols, ["chevron.left", "play.fill", "checkmark"])
        for symbol in symbols {
            XCTAssertFalse(symbol.isEmpty)
            XCTAssertTrue(symbol.unicodeScalars.allSatisfy { $0.isASCII }, symbol)
        }
    }

    // MARK: - 源码扫描 helper（口径与 IC-147／IC-148／IC-155 一致）

    private static let metricsPath = "PhotoCleanupMVE/Features/S0/S0CategoryPageMetrics.swift"
    private static let homeMetricsPath = "PhotoCleanupMVE/Features/S0/S0HomeMetrics.swift"
    /// 换行符用 `UnicodeScalar` 拼、不写转义字面量（IC-148 #294 的 heredoc 教训）。
    private static let newline = String(Character(UnicodeScalar(UInt8(10))))
    /// 顶层类型的收口：换行 + 右花括号 + 换行。
    private static let topLevelClose = newline + "}" + newline

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

    // MARK: - 断言 3：进篮一次原子写入并登记类别名（子项 B）

    func testIC156B_MarkPendingDeletionWritesAtomicallyAndRegistersName() {
        let machine = makeReadyMachine(sessionID: "session-156B-atomic")
        var published: [S1SessionSnapshot] = []
        machine.persistenceSink = { published.append($0) }
        XCTAssertEqual(published.count, 0)

        XCTAssertTrue(
            machine.markPendingDeletion(
                assetIDs: ["a", "b", "c"],
                virtualRangeID: "cat:bigVideo",
                displayName: "大视频"
            )
        )
        let store = machine.sessionStore
        XCTAssertEqual(store.pendingDeletionAssetIDsByRangeID["cat:bigVideo"], ["a", "b", "c"])
        for assetID in ["a", "b", "c"] {
            XCTAssertEqual(store.firstMarkedRangeIDByAssetID[assetID], "cat:bigVideo", assetID)
        }
        XCTAssertEqual(store.allPendingDeletionAssetIDs, ["a", "b", "c"])
        XCTAssertEqual(machine.badgeCount, 3)
        // 单一写出口恰写一次，且写出的快照里名字与 `M` 同步。
        XCTAssertEqual(published.count, 1)
        XCTAssertEqual(published.last?.rangeNamesByID["cat:bigVideo"], "大视频")
        XCTAssertEqual(
            published.last?.pendingDeletionAssetIDsByRangeID["cat:bigVideo"],
            ["a", "b", "c"]
        )

        // 提交能形成，类别来源的组名即登记的类别名。
        let submission = machine.makeS3Submission()
        XCTAssertNotNil(submission)
        let group = submission?.groups.first { $0.sourceRangeID == "cat:bigVideo" }
        XCTAssertEqual(group?.name, "大视频")
        XCTAssertEqual(group?.orderedAssetIDs, ["a", "b", "c"])
        XCTAssertEqual(submission?.assetCount, 3)

        // 空输入一律拒绝、零副作用。
        XCTAssertFalse(
            machine.markPendingDeletion(
                assetIDs: [],
                virtualRangeID: "cat:screenshot",
                displayName: "屏幕截图"
            )
        )
        XCTAssertFalse(
            machine.markPendingDeletion(
                assetIDs: ["d"],
                virtualRangeID: "",
                displayName: "屏幕截图"
            )
        )
        XCTAssertFalse(
            machine.markPendingDeletion(
                assetIDs: ["d"],
                virtualRangeID: "cat:screenshot",
                displayName: ""
            )
        )
        XCTAssertEqual(machine.sessionStore, store)
        XCTAssertEqual(published.count, 1)
    }

    // MARK: - 断言 4：首标范围不被改写，既有范围与对账照旧（子项 B）

    func testIC156B_FirstMarkerWinsAndExistingRangesUntouched() {
        let machine = makeReadyMachine(sessionID: "session-156B-first")
        // 先经既有路径（S2 写回）把 a 标进普通范围 range-x。
        XCTAssertTrue(
            machine.applyS2PendingDeletionChange(
                ["a"],
                entryContext: SessionStore.S2EntryContext(
                    rangeID: "range-x",
                    orderedAssetIDs: ["a", "x2"],
                    sortOrder: machine.sortOrder.sessionSortOrder
                )
            )
        )
        XCTAssertEqual(machine.sessionStore.firstMarkedRangeIDByAssetID["a"], "range-x")

        XCTAssertTrue(
            machine.markPendingDeletion(
                assetIDs: ["a", "d"],
                virtualRangeID: "cat:screenshot",
                displayName: "屏幕截图"
            )
        )
        let store = machine.sessionStore
        XCTAssertEqual(store.firstMarkedRangeIDByAssetID["a"], "range-x")
        XCTAssertEqual(store.firstMarkedRangeIDByAssetID["d"], "cat:screenshot")
        XCTAssertEqual(store.pendingDeletionAssetIDsByRangeID["range-x"], ["a"])
        XCTAssertEqual(store.pendingDeletionAssetIDsByRangeID["cat:screenshot"], ["a", "d"])
        let groups = store.pendingDeletionGroupsByRangeID
        let groupedCount = groups.values.reduce(0) { total, members in
            total + members.count
        }
        XCTAssertEqual(groupedCount, store.allPendingDeletionAssetIDs.count)
        XCTAssertEqual(groups["range-x"], ["a"])
        XCTAssertEqual(groups["cat:screenshot"], ["d"])
        // 已知后果（裁定 三）：虚拟范围不在 `R(T)` 里，排序走兜底分支。
        XCTAssertGreaterThanOrEqual(machine.s3SubmissionOrderingFallback().rangesOutsideOrder, 1)

        // 存在性对账经公开入口：d 已不存在，从 `M`／`F` 剔除，类别组消失，提交仍能形成。
        machine.assetExistenceProbe = { $0.subtracting(["d"]) }
        XCTAssertTrue(machine.reconcile(with: .success(Self.fixtureRanges)))
        let reconciled = machine.sessionStore
        XCTAssertFalse(reconciled.allPendingDeletionAssetIDs.contains("d"))
        XCTAssertNil(reconciled.firstMarkedRangeIDByAssetID["d"])
        XCTAssertNil(reconciled.pendingDeletionGroupsByRangeID["cat:screenshot"])
        XCTAssertEqual(reconciled.pendingDeletionAssetIDsByRangeID["cat:screenshot"], ["a"])
        XCTAssertEqual(reconciled.firstMarkedRangeIDByAssetID["a"], "range-x")
        XCTAssertNotNil(machine.makeS3Submission())
    }

    /// 相册维度读到一个范围、进入就绪态的 S1 状态机（照 IC-132 的构造）。
    private func makeReadyMachine(sessionID: String) -> S1StateMachine {
        let machine = S1StateMachine(
            sessionStore: SessionStore(sessionID: sessionID),
            initialGroupingDimension: .album,
            initialSortOrder: .newestFirst
        )
        guard let request = machine.currentReadRequest else {
            XCTFail("新建状态机没有读取请求")
            return machine
        }
        XCTAssertTrue(machine.completeRangeRead(.success(Self.fixtureRanges), for: request))
        XCTAssertEqual(machine.state, .ready)
        return machine
    }

    private static let fixtureRanges = [
        S1Range(
            id: "range-x",
            displayName: "range-x-name",
            assetIDsNewestFirst: ["a", "x2"]
        )
    ]
}
