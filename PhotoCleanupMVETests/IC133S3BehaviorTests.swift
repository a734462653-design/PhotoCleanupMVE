import Foundation
import XCTest
@testable import PhotoCleanupMVE

/// IC-133：S3 确认页行为层——空组即时消失、信息条口径、全部取消二次确认。
///
/// 三个子项的行为都落在 `S3View.swift` 内可测的展示口径类型上，不落在 SwiftUI
/// body 里，供 IC-134 整层重写视图时原样保留。
final class IC133S3BehaviorTests: XCTestCase {
    // MARK: - 子项 A · 空组即时消失、总数归零转空态（v8 决策 31）

    // 断言 1：三组各两张，移除第二组两张 → 输出恰两组、顺序为原第一、第三组，
    // 计数不变。
    func testIC133A_RemovingWholeSecondGroupDropsItAndKeepsOthersInPlace() {
        let groups = makeThreeGroupsOfTwo()
        let machine = S3StateMachine(assets: assets(for: groups))

        XCTAssertTrue(machine.removeAsset(identifier: "b-1"))
        XCTAssertTrue(machine.removeAsset(identifier: "b-2"))

        let presentation = S3GroupPresentation.make(
            groups: groups,
            currentAssets: machine.assets
        )

        XCTAssertEqual(presentation.groups.count, 2)
        XCTAssertEqual(
            presentation.groups.map(\.sourceRangeID),
            ["范围-A", "范围-C"]
        )
        XCTAssertEqual(presentation.groups.map(\.assetCount), [2, 2])
        XCTAssertEqual(
            presentation.groups.map { $0.orderedAssets.map(\.identifier) },
            [["a-1", "a-2"], ["c-1", "c-2"]]
        )
        // 协调器快照本身未被过滤改动。
        XCTAssertEqual(groups.map(\.assetCount), [2, 2, 2])
    }

    // 断言 2：移除到只剩一组一张 → 输出一组一张；再移除 → 状态机 `.empty`，
    // 输出为空列表。
    func testIC133A_RemovingDownToLastAssetThenEmptyYieldsEmptyPresentation() {
        let groups = makeThreeGroupsOfTwo()
        let machine = S3StateMachine(assets: assets(for: groups))

        for identifier in ["a-1", "a-2", "b-1", "b-2", "c-1"] {
            XCTAssertTrue(machine.removeAsset(identifier: identifier))
        }

        let oneLeft = S3GroupPresentation.make(
            groups: groups,
            currentAssets: machine.assets
        )
        XCTAssertNotEqual(machine.state, .empty)
        XCTAssertEqual(oneLeft.groups.count, 1)
        XCTAssertEqual(oneLeft.groups.first?.sourceRangeID, "范围-C")
        XCTAssertEqual(oneLeft.groups.first?.assetCount, 1)
        XCTAssertEqual(
            oneLeft.groups.first?.orderedAssets.map(\.identifier),
            ["c-2"]
        )

        XCTAssertTrue(machine.removeAsset(identifier: "c-2"))

        let none = S3GroupPresentation.make(
            groups: groups,
            currentAssets: machine.assets
        )
        XCTAssertEqual(machine.state, .empty)
        XCTAssertTrue(none.groups.isEmpty)
        XCTAssertEqual(none.nonEmptyRangeCount, 0)
        XCTAssertEqual(none.assetCount, 0)
    }

    // 断言 3：输出顺序等于输入 `s3Groups` 顺序——构造一个名字逆序的输入，
    // 断言未被重排（既不按名字、也不按范围标识）。
    func testIC133A_OutputOrderFollowsInputOrderNotName() {
        let groups = [
            SessionStore.S3Submission.Group(
                sourceRangeID: "范围-3",
                name: "丙",
                orderedAssetIDs: ["z-1"]
            ),
            SessionStore.S3Submission.Group(
                sourceRangeID: "范围-2",
                name: "乙",
                orderedAssetIDs: ["y-1"]
            ),
            SessionStore.S3Submission.Group(
                sourceRangeID: "范围-1",
                name: "甲",
                orderedAssetIDs: ["x-1"]
            )
        ]
        let machine = S3StateMachine(assets: assets(for: groups))

        let presentation = S3GroupPresentation.make(
            groups: groups,
            currentAssets: machine.assets
        )

        XCTAssertEqual(
            presentation.groups.map(\.sourceRangeID),
            groups.map(\.sourceRangeID)
        )
        XCTAssertEqual(presentation.groups.map(\.name), ["丙", "乙", "甲"])
        XCTAssertNotEqual(
            presentation.groups.map(\.name),
            presentation.groups.map(\.name).sorted()
        )
    }

    // 断言 4：各组输出计数之和 = 状态机 `assetCount`（分组等式，v8 第六节第 5 部分）
    // ——初始、逐张移除、整组移除三个时刻都成立。
    func testIC133A_GroupCountsSumEqualsMachineAssetCountAtEveryStep() {
        let groups = makeThreeGroupsOfTwo()
        let machine = S3StateMachine(assets: assets(for: groups))

        func assertGroupEquation(file: StaticString = #filePath, line: UInt = #line) {
            let presentation = S3GroupPresentation.make(
                groups: groups,
                currentAssets: machine.assets
            )
            XCTAssertEqual(
                presentation.groups.reduce(0) { $0 + $1.assetCount },
                machine.assetCount,
                file: file,
                line: line
            )
            XCTAssertEqual(presentation.assetCount, machine.assetCount, file: file, line: line)
        }

        assertGroupEquation()
        XCTAssertEqual(machine.assetCount, 6)

        XCTAssertTrue(machine.removeAsset(identifier: "a-2"))
        assertGroupEquation()
        XCTAssertEqual(machine.assetCount, 5)

        XCTAssertTrue(machine.removeAsset(identifier: "c-1"))
        XCTAssertTrue(machine.removeAsset(identifier: "c-2"))
        assertGroupEquation()
        XCTAssertEqual(machine.assetCount, 3)

        XCTAssertTrue(machine.cancelAll())
        assertGroupEquation()
        XCTAssertEqual(machine.assetCount, 0)
    }

    // MARK: - 子项 B · 信息条口径与「最近删除」提示句（决策单 D1、D2）

    // 断言 5：三组各两张 → 副行「6 张 · 来自 3 个范围」；移除一组两张后 →
    // 「4 张 · 来自 2 个范围」（`ranges` 随非空组数变，不是 `s3Groups.count`）。
    func testIC133B_HeaderSubtitleTracksAssetCountAndNonEmptyRangeCount() {
        let groups = makeThreeGroupsOfTwo()
        let machine = S3StateMachine(assets: assets(for: groups))

        func subtitle() -> String {
            let presentation = S3GroupPresentation.make(
                groups: groups,
                currentAssets: machine.assets
            )
            return S3HeaderSubtitle.text(
                assetCount: machine.assetCount,
                rangeCount: presentation.nonEmptyRangeCount
            )
        }

        XCTAssertEqual(subtitle(), "6 张 · 来自 3 个范围")

        XCTAssertTrue(machine.removeAsset(identifier: "b-1"))
        XCTAssertTrue(machine.removeAsset(identifier: "b-2"))

        // 协调器快照仍是 3 组，副行按非空组数报 2。
        XCTAssertEqual(groups.count, 3)
        XCTAssertEqual(subtitle(), "4 张 · 来自 2 个范围")
    }

    // 断言 6：文案经 `L10n.text` 取得（NSLocalizedString 找不到时原样返回 key），
    // 目录值逐字等于卡内登记原文；目录无孤儿 key 与源码无中文字面量另由
    // Scripts/scan-hardcoded-user-visible-strings.ps1 覆盖。
    func testIC133B_HeaderSubtitleAndNoticeComeFromStringCatalog() {
        let subtitleKey = "s3.chrome.subtitle_format"
        let subtitleFormat = L10n.text(subtitleKey)
        XCTAssertNotEqual(subtitleFormat, subtitleKey)
        XCTAssertEqual(subtitleFormat, "{count} 张 · 来自 {ranges} 个范围")
        XCTAssertEqual(
            S3HeaderSubtitle.text(assetCount: 6, rangeCount: 3),
            L10n.text(subtitleKey, replacing: ["count": "6", "ranges": "3"])
        )

        let noticeKey = "s3.confirmation.recently_deleted_notice"
        let notice = L10n.text(noticeKey)
        XCTAssertNotEqual(notice, noticeKey)
        XCTAssertEqual(notice, "删除后会移入系统「最近删除」，30 天内可恢复。")

        // 旧占位 key 已删除：目录查不到时原样返回 key。
        let removedKey = "s3.scope.source_summary.placeholder"
        XCTAssertEqual(L10n.text(removedKey), removedKey)
    }

    // MARK: - 夹具

    /// 三组各两张：范围-A{a-1,a-2}、范围-B{b-1,b-2}、范围-C{c-1,c-2}。
    private func makeThreeGroupsOfTwo() -> [SessionStore.S3Submission.Group] {
        [
            SessionStore.S3Submission.Group(
                sourceRangeID: "范围-A",
                name: "相册甲",
                orderedAssetIDs: ["a-1", "a-2"]
            ),
            SessionStore.S3Submission.Group(
                sourceRangeID: "范围-B",
                name: "相册乙",
                orderedAssetIDs: ["b-1", "b-2"]
            ),
            SessionStore.S3Submission.Group(
                sourceRangeID: "范围-C",
                name: "相册丙",
                orderedAssetIDs: ["c-1", "c-2"]
            )
        ]
    }

    /// 按分组顺序拼出状态机的资产描述（与 `S3Submission.orderedAssetIDs` 同构）。
    private func assets(
        for groups: [SessionStore.S3Submission.Group]
    ) -> [AssetDescriptor] {
        groups.flatMap { group in
            group.orderedAssetIDs.map {
                AssetDescriptor(identifier: $0, isFavorite: false)
            }
        }
    }
}
