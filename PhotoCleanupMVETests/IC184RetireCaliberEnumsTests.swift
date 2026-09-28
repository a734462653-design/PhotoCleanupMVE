import Foundation
import XCTest
@testable import PhotoCleanupMVE

/// IC-184：纯重构退役卡（二）（Decision_log 第 216 条第三节）——IC-178 旧列表层的口径枚举与状态机同页展开／收起 API 退役。
/// 零产品行为改动；本文件钉三件事：1 口径枚举已从 `S1View` 与整个产品源码退役、仍被卡片叠借用的两只函数与徽标样式留下；
/// 2 展开 API 已从状态机退役，且可见顺序、行投影与 S3 分组顺序在夹具上与退役前逐位相同（产品运行时收起集合恒空）；
/// 3 测试卫生（六个只测退役符号的函数整删、四个函数删部分断言、两个改名）。
final class IC184RetireCaliberEnumsTests: XCTestCase {
    private static let s1ViewPath = "PhotoCleanupMVE/Features/S1/S1View.swift"
    private static let machinePath = "PhotoCleanupMVE/Core/S1StateMachine.swift"
    private static let newline = String(Character(UnicodeScalar(UInt8(10))))

    // MARK: - 断言 1：口径枚举退役

    func testIC184B_CaliberEnumsRetired() throws {
        let s1 = try XCTUnwrap(strippedSource(Self.s1ViewPath))
        let s1Raw = try XCTUnwrap(sourceText(Self.s1ViewPath))
        for retired in [
            "S1RangeCardMetrics",
            "S1PendingBadgePresentation",
            "S1RangeCardPresentation",
            "S1YearStackStyle",
            "S1CoverImagePhase",
            "targetPixelSize",
            "cardRing",
            "isVisible(hasContinuation"
        ] {
            XCTAssertEqual(occurrences(of: retired, in: s1), 0, retired)
        }
        // 留下的三只：进度线只剩比例函数；封面策略只剩取图函数；徽标样式只剩垃圾桶描边（一只 `static var`）与六个定值。
        let progress = try XCTUnwrap(
            slice(s1, from: "enum S1ProgressLinePresentation {", to: Self.newline + "}" + Self.newline)
        )
        XCTAssertEqual(occurrences(of: "static func ", in: progress), 1)
        XCTAssertEqual(occurrences(of: "static func fillFraction(", in: progress), 1)
        let cover = try XCTUnwrap(
            slice(s1, from: "enum S1RangeCoverPolicy {", to: Self.newline + "}" + Self.newline)
        )
        XCTAssertEqual(occurrences(of: "static func ", in: cover), 1)
        XCTAssertEqual(occurrences(of: "static func coverAssetID(", in: cover), 1)
        let badge = try XCTUnwrap(
            slice(s1, from: "enum S1NotificationBadgeStyle {", to: Self.newline + "}" + Self.newline)
        )
        XCTAssertEqual(occurrences(of: "static var ", in: badge), 1)
        XCTAssertEqual(occurrences(of: "static var chromeRing:", in: badge), 1)
        XCTAssertEqual(occurrences(of: "static let ", in: badge), 6)
        // 页头、四态、菜单、玻璃 helper 一字不动（`cardRing` 那一处前景表引用消失：29 → 28）。
        XCTAssertEqual(occurrences(of: "S1ChromeForeground.", in: s1), 28)
        XCTAssertEqual(occurrences(of: "s1ChromeGlassBackground(", in: s1), 4)
        XCTAssertEqual(occurrences(of: "S1RangeCoverPolicy.coverAssetID(", in: s1), 1)
        XCTAssertEqual(occurrences(of: "S1DeckListView(", in: s1), 1)
        XCTAssertEqual(occurrences(of: "S1YearPageView(", in: s1), 1)
        // 两处注释已改写（原文含注释）。
        XCTAssertEqual(occurrences(of: "待删红点描边取卡片底色", in: s1Raw), 0)
        XCTAssertEqual(occurrences(of: "范围卡常量与展示口径", in: s1Raw), 0)

        var product = String()
        for relativePath in try swiftFiles(inDirectory: "PhotoCleanupMVE", recursive: true) {
            product += try XCTUnwrap(strippedSource(relativePath), relativePath)
        }
        XCTAssertGreaterThan(product.count, 0)
        for retired in [
            "S1RangeCardMetrics",
            "S1PendingBadgePresentation",
            "S1RangeCardPresentation",
            "S1YearStackStyle",
            "S1CoverImagePhase"
        ] {
            XCTAssertEqual(occurrences(of: retired, in: product), 0, retired)
        }
        // 正对照：卡片叠进度条仍借用比例函数；S0 篮入口与卡片叠胶囊仍借用徽标样式。
        XCTAssertGreaterThan(occurrences(of: "S1ProgressLinePresentation.fillFraction(", in: product), 0)
        XCTAssertGreaterThan(occurrences(of: "S1NotificationBadgeStyle.", in: product), 0)
    }

    // MARK: - 断言 2：展开 API 退役，可见顺序与 S3 分组顺序不变

    func testIC184C_ExpandAPIRetiredAndVisibleOrderUnchanged() throws {
        let machine = try XCTUnwrap(strippedSource(Self.machinePath))
        for retired in ["collapsedYearRangeIDs", "isYearExpanded", "toggleYearExpansion", "isExpanded"] {
            XCTAssertEqual(occurrences(of: retired, in: machine), 0, retired)
        }
        let visible = try XCTUnwrap(
            slice(machine, from: "var visibleRanges: [S1Range] {", to: Self.newline + "    }" + Self.newline)
        )
        XCTAssertEqual(occurrences(of: "continue", in: visible), 0, "收起守卫已删")
        XCTAssertEqual(occurrences(of: "childRanges(of: year.id)", in: visible), 1)
        XCTAssertEqual(occurrences(of: "visible.append(", in: visible), 2)
        let row = try XCTUnwrap(
            slice(machine, from: "struct S1RangeRow: Identifiable, Equatable, Sendable {", to: Self.newline + "}" + Self.newline)
        )
        XCTAssertEqual(occurrences(of: "let ", in: row), 7)
        // 年页身份与既有钉子不动（IC178D／IC157／IC169 的计数）。
        for (needle, expected) in [
            ("presentedYearRangeID", 5),
            ("func presentYearPage(", 1),
            ("func dismissYearPage()", 1),
            ("didSet", 4),
            ("publishSnapshotIfChanged()", 6),
            ("setMarked(", 3),
            ("applyPendingDeletionDiff(", 3)
        ] {
            XCTAssertEqual(occurrences(of: needle, in: machine), expected, needle)
        }
        let s1Raw = try XCTUnwrap(sourceText(Self.s1ViewPath))
        XCTAssertEqual(occurrences(of: "展开集合恒空", in: s1Raw), 0)

        // 夹具：删守卫后可见顺序、行投影与 S3 分组顺序与退役前逐位相同（两种 O，对账后亦然）。
        let tree = makeTreeMachine()
        XCTAssertEqual(tree.visibleRanges.map(\.id), ["y2026", "m2026-08", "m2026-03", "y2024", "m2024-01"])
        XCTAssertEqual(tree.rangeRows.map(\.id), ["y2026", "m2026-08", "m2026-03", "y2024", "m2024-01"])
        XCTAssertEqual(tree.rangeRows.map(\.childCount), [2, 0, 0, 1, 0])
        XCTAssertTrue(
            tree.applyS2PendingDeletionChange(
                ["a3a"],
                entryContext: SessionStore.S2EntryContext(
                    rangeID: "y2026",
                    orderedAssetIDs: ["a8", "a3b", "a3a"],
                    sortOrder: .newestFirst
                )
            )
        )
        XCTAssertTrue(
            tree.applyS2PendingDeletionChange(
                ["b1"],
                entryContext: SessionStore.S2EntryContext(
                    rangeID: "y2024",
                    orderedAssetIDs: ["b1"],
                    sortOrder: .newestFirst
                )
            )
        )
        XCTAssertEqual(tree.makeS3Submission()?.groups.map(\.sourceRangeID), ["y2026", "y2024"])
        XCTAssertTrue(tree.switchSortOrder(to: .oldestFirst))
        XCTAssertEqual(tree.visibleRanges.map(\.id), ["y2024", "m2024-01", "y2026", "m2026-03", "m2026-08"])
        XCTAssertEqual(tree.makeS3Submission()?.groups.map(\.sourceRangeID), ["y2024", "y2026"])
        XCTAssertTrue(tree.switchSortOrder(to: .newestFirst))
        XCTAssertTrue(tree.reconcile(with: .success(treeRanges())))
        XCTAssertEqual(tree.visibleRanges.map(\.id), ["y2026", "m2026-08", "m2026-03", "y2024", "m2024-01"])
        XCTAssertEqual(tree.rangeRows.map(\.pendingDeletionCount), [1, 0, 1, 1, 1])
        XCTAssertEqual(tree.state, .ready)
    }

    // MARK: - 断言 3：测试卫生

    func testIC184D_TestHygiene() throws {
        let ic128 = try XCTUnwrap(strippedSource("PhotoCleanupMVETests/IC128S1VisualTests.swift"))
        for deleted in [
            "testIC128B_CoverTargetPixelSizeFollowsDisplayScale",
            "testIC128B_CoverReplacementNeverDowngrades",
            "testIC128B_PendingBadgeHiddenAtZero",
            "testIC128B_YearRowHasSeparateExpandAndEnterTargets"
        ] {
            XCTAssertEqual(occurrences(of: "func " + deleted + "(", in: ic128), 0, deleted)
        }
        XCTAssertEqual(occurrences(of: "S1ProgressLinePresentation.isVisible(", in: ic128), 0, "受限提示条的 `S1LimitedBannerPresentation.isVisible(` 另计、仍在")
        XCTAssertEqual(occurrences(of: "func testIC128B_ProgressLineFractionAndVisibility(", in: ic128), 0, "删掉显隐断言后改名")
        XCTAssertEqual(occurrences(of: "func testIC128B_ProgressLineFraction(", in: ic128), 1)
        XCTAssertEqual(occurrences(of: "S1ProgressLinePresentation.fillFraction(", in: ic128), 5)
        XCTAssertEqual(occurrences(of: "func testIC128B_CoverFollowsCurrentSortOrderAndFlips(", in: ic128), 1)

        let stateMachineTests = try XCTUnwrap(strippedSource("PhotoCleanupMVETests/S1StateMachineTests.swift"))
        for deleted in [
            "testIC127A_CollapsingYearHidesMonthRowsButKeepsRangeData",
            "testIC127A_ExpandAndEnterAreDistinctTargets"
        ] {
            XCTAssertEqual(occurrences(of: "func " + deleted + "(", in: stateMachineTests), 0, deleted)
        }
        XCTAssertEqual(occurrences(of: "toggleYearExpansion", in: stateMachineTests), 0)
        XCTAssertEqual(occurrences(of: "func testIC127A_SortFlipReversesYearOrderAndMonthOrderTogether(", in: stateMachineTests), 1)

        let ic177 = try XCTUnwrap(strippedSource("PhotoCleanupMVETests/IC177UnifiedBackgroundTests.swift"))
        XCTAssertEqual(occurrences(of: "cardRing", in: ic177), 0)
        XCTAssertEqual(occurrences(of: "S1YearStackStyle", in: ic177), 0)
        XCTAssertEqual(occurrences(of: "S1NotificationBadgeStyle.chromeRing", in: ic177), 1)
        XCTAssertEqual(occurrences(of: "func testIC177B_YearStackHeroPaletteAndAmbientBaseAreFixed(", in: ic177), 0)
        XCTAssertEqual(occurrences(of: "func testIC177B_HeroPaletteAndAmbientBaseAreFixed(", in: ic177), 1)

        let ic178 = try XCTUnwrap(strippedSource("PhotoCleanupMVETests/IC178DeckListTests.swift"))
        XCTAssertEqual(occurrences(of: "toggleYearExpansion", in: ic178), 0, "IC178B 的两处调用已删；断言 4 的 needle 是字符串字面量、不计")
        XCTAssertEqual(occurrences(of: "func testIC178B_YearPageIdentityLivesInMachineWithGuards(", in: ic178), 1)

        let ic183 = try XCTUnwrap(strippedSource("PhotoCleanupMVETests/IC183RetireRenderChainTests.swift"))
        XCTAssertEqual(occurrences(of: "let metrics", in: ic183), 0, "三值切片已随整族退役删除")
        XCTAssertEqual(occurrences(of: "func testIC183A_RenderChainRetired(", in: ic183), 1)
    }

    // MARK: - 夹具（与 S1StateMachineTests 同一棵树）

    private func makeTreeMachine() -> S1StateMachine {
        let machine = S1StateMachine(
            sessionStore: SessionStore(sessionID: "session-tree-184"),
            initialGroupingDimension: .date,
            initialSortOrder: .newestFirst
        )
        if let request = machine.currentReadRequest {
            XCTAssertTrue(machine.completeRangeRead(.success(treeRanges()), for: request))
        } else {
            XCTFail("首次读取请求缺失")
        }
        return machine
    }

    private func treeRanges() -> [S1Range] {
        [
            S1Range(
                id: "y2026",
                displayName: "2026",
                assetIDsNewestFirst: ["a8", "a3b", "a3a"]
            ),
            S1Range(
                id: "m2026-08",
                displayName: "2026-08",
                assetIDsNewestFirst: ["a8"],
                parentRangeID: "y2026"
            ),
            S1Range(
                id: "m2026-03",
                displayName: "2026-03",
                assetIDsNewestFirst: ["a3b", "a3a"],
                parentRangeID: "y2026"
            ),
            S1Range(
                id: "y2024",
                displayName: "2024",
                assetIDsNewestFirst: ["b1"]
            ),
            S1Range(
                id: "m2024-01",
                displayName: "2024-01",
                assetIDsNewestFirst: ["b1"],
                parentRangeID: "y2024"
            )
        ]
    }

    // MARK: - 工具（与既有测试同口径）

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

    private func swiftFiles(inDirectory relativeDirectory: String, recursive: Bool = false) throws -> [String] {
        let directory = repoRoot().appendingPathComponent(relativeDirectory)
        let names: [String]
        if recursive {
            let enumerator = try XCTUnwrap(FileManager.default.enumerator(atPath: directory.path))
            names = enumerator.compactMap { $0 as? String }
        } else {
            names = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        }
        return names
            .filter { $0.hasSuffix(".swift") }
            .sorted()
            .map { relativeDirectory + "/" + $0 }
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
