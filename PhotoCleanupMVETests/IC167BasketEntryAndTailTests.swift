import Foundation
import XCTest
@testable import PhotoCleanupMVE

/// IC-167：首页待删篮入口改「垃圾桶圆钮 + 徽标」并接 S3、展开末卡延伸到底、类别页排序加「从小到大」、
/// 类别页顶排待删篮入口（SPEC-S0 v4 实装第一张）。
///
/// 依据 SPEC-S0 v4（Decision_log 第 197 条晋级）第三、四、六、十、十四节与任务卡 IC-20260923-167 的
/// 五条裁定。断言编号与任务卡子项 E 一一对应。口径同 IC-165／166：文案 key 一律扫原文，其余扫剔过
/// 注释与字符串内容的源码；集合断言期望值一律写成 `Set`（惯例 45）。**不重复钉**别处已钉的计数
/// （登记表 198、`s0.` 40、`s0.categoryPage.` 10），**不钉任何 blob**（惯例 46）。
///
/// **夹具驱动与源码扫描，真机未覆盖**（陷阱 1）：展开末卡有没有黑边、徽标会不会被玻璃盖住、
/// 收起导航条会不会挤截断标题、冷启动直接点入口进不进 S3，只有 H87 能判。
final class IC167BasketEntryAndTailTests: XCTestCase {

    // MARK: - 断言 1：展开末卡延伸到 tail 高（裁定 一）

    /// `cardExtension` 是 `View` 成员，随 `View` 的主线程隔离推断为主线程隔离（惯例 37），
    /// 故本函数标主线程。
    @MainActor
    func testIC167A_OpenTailCardExtendsToTailHeight() throws {
        XCTAssertEqual(
            S0DeckHomeView.cardExtension(index: 0, count: 3),
            S0DeckMetrics.cardOverhang
        )
        XCTAssertEqual(
            S0DeckHomeView.cardExtension(index: 2, count: 3),
            S0DeckMetrics.lastCardTailHeight
        )
        // 只有一张卡时它就是末张：展开与否都取 tail 高。
        XCTAssertEqual(
            S0DeckHomeView.cardExtension(index: 0, count: 1),
            S0DeckMetrics.lastCardTailHeight
        )
        // 正对照：两值不同，上面三条才分得出末张与非末张。
        XCTAssertNotEqual(S0DeckMetrics.cardOverhang, S0DeckMetrics.lastCardTailHeight)

        let home = try XCTUnwrap(strippedSource(Self.homePath))
        XCTAssertEqual(occurrences(of: "isTail", in: home), 0)
        XCTAssertEqual(
            occurrences(of: "Self.cardExtension(index: index, count: cards.count)", in: home),
            1
        )
        // 文字块、「去清理」的底距与压暗第二层的高，三处都按「卡高 − 可见高」取。
        XCTAssertEqual(occurrences(of: "height - visibleHeight", in: home), 3)
        XCTAssertEqual(
            occurrences(of: "S0DeckMetrics.cardOverhang + S0DeckMetrics.openTextBottomInset", in: home),
            0
        )
        XCTAssertEqual(
            occurrences(of: "S0DeckMetrics.cardOverhang + S0DeckMetrics.openActionBottomInset", in: home),
            0
        )
        // 渐变末档一处 + 可见区之下的纯色一层。
        XCTAssertEqual(occurrences(of: "S0DeckMetrics.openShadeBottomOpacity", in: home), 2)
    }

    // MARK: - 断言 2：入口是圆钮 + 徽标，首页四态都有顶排（裁定 二、三）

    func testIC167B_BasketEntryIsCircleWithBadge() throws {
        let entry = try XCTUnwrap(strippedSource(Self.entryPath))
        XCTAssertGreaterThan(entry.count, 0)
        for (needle, expected) in [
            ("Image(systemName: S0DeckSymbol.trash)", 2),
            ("S1NotificationBadgeStyle.", 7),
            ("S0DeckMetrics.", 7),
            ("S1ChromeTypography.circleIconPointSize", 1),
            ("s1ChromeCircleGlass()", 1),
            ("Button(action: action)", 1),
            (".disabled(count == 0)", 1),
            ("count > 0", 1),
            (".allowsHitTesting(false)", 1),
            (".monospacedDigit()", 1),
            ("overlay(alignment: .topTrailing)", 1),
            ("offset(", 0)
        ] {
            XCTAssertEqual(occurrences(of: needle, in: entry), expected, needle)
        }
        // 零 PhotoKit、恒深色（新文件的纪律由本断言自己钉：既有的动态外观扫描只扫各自点名的文件）。
        for forbidden in [
            "import Photos",
            "PHAsset",
            "PHImageManager",
            "PHFetch",
            "colorScheme",
            "systemBackground",
            "UIColor.label",
            ".primary",
            "S2ChromeForeground",
            "Material",
            "ultraThin",
            "#available"
        ] {
            XCTAssertEqual(occurrences(of: forbidden, in: entry), 0, forbidden)
        }
        XCTAssertEqual(numericLiterals(in: entry), Set(["0"]))
        let entryRaw = try XCTUnwrap(sourceText(Self.entryPath))
        XCTAssertEqual(occurrences(of: "s1.trash.accessibility", in: entryRaw), 1)
        XCTAssertEqual(occurrences(of: "Text(\"", in: entryRaw), 0)

        // 首页：胶囊退役，顶排换成共享入口；入口不经状态机的门控。
        let home = try XCTUnwrap(strippedSource(Self.homePath))
        XCTAssertEqual(occurrences(of: "S0BasketEntryView(style: .glass", in: home), 1)
        XCTAssertEqual(occurrences(of: "basketCapsule", in: home), 0)
        XCTAssertEqual(occurrences(of: "pendingDeletionByteCount", in: home), 0)
        XCTAssertEqual(occurrences(of: "machine.accepts(.basketCapsule", in: home), 0)
        // 剩下的一处是等待清空行的「我已清空」。
        XCTAssertEqual(occurrences(of: "machine.accepts(", in: home), 1)
        // S0-3／S0-4 两支各包一层顶排：四态分派段内 `topRow` 两处，case 行不复制。
        let dispatch = try XCTUnwrap(
            slice(
                home,
                from: "private var content: some View {",
                to: Self.newline + "    }" + Self.newline
            ),
            "首页四态分派 `content` 没切到"
        )
        XCTAssertEqual(occurrences(of: "topRow", in: dispatch), 2)
        XCTAssertEqual(occurrences(of: "case .empty:", in: dispatch), 1)
        XCTAssertEqual(occurrences(of: "case .failed:", in: dispatch), 1)
        let homeRaw = try XCTUnwrap(sourceText(Self.homePath))
        XCTAssertEqual(occurrences(of: "s0.basket.capsule", in: homeRaw), 0)

        // 目录：胶囊格式串退役；无障碍标签借的那一条仍在、取值不变。
        let catalog = try loadCatalogValues()
        XCTAssertNil(catalog["s0.basket.capsule"])
        XCTAssertEqual(catalog["s1.trash.accessibility"], "会话待删总数 {count}")
    }

    // MARK: - 断言 3：S0-4 下入口可达 S3，App 先对账再提交（裁定 三）

    func testIC167B_BasketEntryReachesConfirmationAndFailedStateAccepts() throws {
        // 失败态机器照 IC-147 夹具的写法：新机器直接收一次扫描失败。
        let failed = S0StateMachine()
        failed.handle(.scanFailed(.authorization))
        XCTAssertEqual(failed.state, .failed)
        failed.mergedPendingDeletionCountProvider = { 3 }
        XCTAssertTrue(failed.accepts(.basketCapsule))
        XCTAssertEqual(failed.handle(.basketCapsuleTapped), .confirmation)

        // 负对照：`D_全部` 为空时四态都不接收、点了也不迁移。
        for machine in [
            scanningMachine(),
            settledMachine(assetCount: 3),
            settledMachine(assetCount: 0),
            failedMachine()
        ] {
            machine.mergedPendingDeletionCountProvider = { 0 }
            XCTAssertFalse(machine.accepts(.basketCapsule), machine.state.rawValue)
            XCTAssertEqual(
                machine.handle(.basketCapsuleTapped),
                .home(machine.state),
                machine.state.rawValue
            )
        }
        // 夹具覆盖四态各一。
        XCTAssertEqual(
            Set([
                scanningMachine().state,
                settledMachine(assetCount: 3).state,
                settledMachine(assetCount: 0).state,
                failedMachine().state
            ]),
            Set([S0State.scanning, S0State.ready, S0State.empty, S0State.failed])
        )

        let flow = try XCTUnwrap(strippedSource(Self.flowPath))
        XCTAssertEqual(
            occurrences(of: "onEnterConfirmation: @escaping () -> Void = {}", in: flow),
            1
        )
        XCTAssertEqual(occurrences(of: "onEnterConfirmation: onEnterConfirmation", in: flow), 2)

        let app = try XCTUnwrap(strippedSource(Self.appPath))
        XCTAssertEqual(occurrences(of: "onEnterConfirmation: {", in: app), 1)
        // IC-170 B：对账与提交形成收进协调器，App 闭包只调协调器入口。
        XCTAssertEqual(occurrences(of: "reconcileS1WithPhotoLibrary()", in: app), 0)
        XCTAssertEqual(occurrences(of: "makeS3Submission()", in: app), 0)
        // 只剩「逐张整理」tab 的既有一处。
        XCTAssertEqual(occurrences(of: "enterConfirmationFromS1(", in: app), 1)
    }

    // MARK: - 断言 4：「从小到大」按字节升序、同体积按标识升序（裁定 四）

    func testIC167C_SizeAscendingSortsByBytesThenID() throws {
        // 五项：两对同体积，标识逆序给入。
        let items = [
            S0CategoryAsset(id: "e", byteCount: 9, isVideo: false, duration: 0),
            S0CategoryAsset(id: "c", byteCount: 3, isVideo: false, duration: 0),
            S0CategoryAsset(id: "b", byteCount: 3, isVideo: false, duration: 0),
            S0CategoryAsset(id: "a", byteCount: 1, isVideo: false, duration: 0),
            S0CategoryAsset(id: "d", byteCount: 9, isVideo: true, duration: 12)
        ]
        XCTAssertEqual(
            S0DeckHomeModel.sorted(items, by: .sizeAscending, dates: [:]).map(\.id),
            ["a", "b", "c", "d", "e"]
        )
        // 正对照：「从大到小」原样返回入参顺序（数据源已排好）。
        XCTAssertEqual(
            S0DeckHomeModel.sorted(items, by: .size, dates: [:]).map(\.id),
            ["e", "c", "b", "a", "d"]
        )
        // 有日期也不影响升序（「从小到大」与拍摄日期无关）。
        let dates: [String: Date] = [
            "a": Date(timeIntervalSince1970: 2_000),
            "e": Date(timeIntervalSince1970: 1_000)
        ]
        XCTAssertEqual(
            S0DeckHomeModel.sorted(items, by: .sizeAscending, dates: dates).map(\.id),
            ["a", "b", "c", "d", "e"]
        )

        // 页面：菜单一项 + 副行排序名一处；网格与「从大到小」同一分支。
        let pageRaw = try XCTUnwrap(sourceText(Self.pagePath))
        XCTAssertEqual(occurrences(of: "s0.categoryPage.sort.sizeAscending", in: pageRaw), 2)
        let page = try XCTUnwrap(strippedSource(Self.pagePath))
        XCTAssertEqual(occurrences(of: "case .size, .sizeAscending:", in: page), 1)
        XCTAssertEqual(occurrences(of: "case .sizeAscending:", in: page), 1)

        let catalog = try loadCatalogValues()
        XCTAssertEqual(catalog["s0.categoryPage.sort.sizeAscending"], "从小到大")
    }

    // MARK: - 断言 5：类别页两处入口都在排序钮左侧（裁定 五）

    func testIC167D_CategoryPageHasTwoBasketEntriesLeftOfSort() throws {
        let page = try XCTUnwrap(strippedSource(Self.pagePath))
        XCTAssertEqual(occurrences(of: "S0BasketEntryView(style: .glass", in: page), 1)
        XCTAssertEqual(occurrences(of: "S0BasketEntryView(style: .flat", in: page), 1)
        XCTAssertEqual(occurrences(of: "machine.mergedPendingDeletionCount", in: page), 2)
        // 按钮、图标、登记值与玻璃都在共享视图里，页面被钉死的计数一个不动。
        XCTAssertEqual(occurrences(of: "Button {", in: page), 3)
        XCTAssertEqual(occurrences(of: "Image(systemName: ", in: page), 7)
        XCTAssertEqual(occurrences(of: "S0DeckMetrics.", in: page), 147)
        XCTAssertEqual(occurrences(of: "s1ChromeGlassBackground(", in: page), 5)

        // 页头：待删篮入口 · 排序 · 「全选」自左至右。
        let top = try XCTUnwrap(
            slice(
                page,
                from: "private var topRow: some View {",
                to: Self.newline + "    }" + Self.newline
            ),
            "类别页页头 `topRow` 没切到"
        )
        let glassEntry = try XCTUnwrap(top.range(of: "S0BasketEntryView(style: .glass"))
        let sortButton = try XCTUnwrap(top.range(of: "sortMenu {"))
        let selectAll = try XCTUnwrap(top.range(of: "selectAllButton"))
        XCTAssertLessThan(glassEntry.upperBound, sortButton.lowerBound)
        XCTAssertLessThan(sortButton.upperBound, selectAll.lowerBound)

        // 收起导航条：待删篮入口在排序钮之前。
        let nav = try XCTUnwrap(
            slice(
                page,
                from: "private var compactNav: some View {",
                to: Self.newline + "    }" + Self.newline
            ),
            "收起导航条 `compactNav` 没切到"
        )
        let flatEntry = try XCTUnwrap(nav.range(of: "S0BasketEntryView(style: .flat"))
        let navSort = try XCTUnwrap(nav.range(of: "compactNavSort"))
        XCTAssertLessThan(flatEntry.upperBound, navSort.lowerBound)
    }

    // MARK: - 夹具

    private func readySnapshot(assetCount: Int) -> S0CleanupSnapshot {
        let byteCount = Int64(assetCount) * 1_000
        return S0CleanupSnapshot(
            progress: S0ScanProgress(scannedAssetCount: assetCount, totalAssetCount: assetCount),
            cleanableAssetCount: assetCount,
            cleanableByteCount: byteCount,
            libraryTotalByteCount: byteCount,
            categories: [
                S0CategorySnapshot(
                    id: .screenshot,
                    candidateCount: assetCount,
                    candidateByteCount: byteCount,
                    recognition: .settled
                )
            ]
        )
    }

    private func scanningMachine() -> S0StateMachine {
        let machine = S0StateMachine()
        machine.handle(.applicationOpened)
        machine.ingest(readySnapshot(assetCount: 3))
        return machine
    }

    /// 扫描完成：有成员落 S0-2，无成员落 S0-3。
    private func settledMachine(assetCount: Int) -> S0StateMachine {
        let machine = S0StateMachine()
        machine.handle(.applicationOpened)
        machine.ingest(readySnapshot(assetCount: assetCount))
        machine.handle(.scanCompleted)
        return machine
    }

    private func failedMachine() -> S0StateMachine {
        let machine = S0StateMachine()
        machine.handle(.scanFailed(.authorization))
        return machine
    }

    // MARK: - 路径

    private static let homePath = "PhotoCleanupMVE/Features/S0/S0DeckHomeView.swift"
    private static let entryPath = "PhotoCleanupMVE/Features/S0/S0BasketEntryView.swift"
    private static let pagePath = "PhotoCleanupMVE/Features/S0/S0DeckCategoryPageView.swift"
    private static let flowPath = "PhotoCleanupMVE/Features/S0/S0CleanupFlowView.swift"
    private static let appPath = "PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift"

    // MARK: - 源码扫描 helper（口径与 IC-165／166 一致）

    /// 换行符用 `UnicodeScalar` 拼、不写转义字面量（IC-148 #294 的 heredoc 教训）。
    private static let newline = String(Character(UnicodeScalar(UInt8(10))))

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

    /// 数值字面量提取，口径同 IC-148／IC-165／IC-166 `numericLiterals(in:)`。
    private func numericLiterals(in source: String) -> Set<String> {
        var literals: Set<String> = []
        let characters = Array(source)
        var index = 0
        while index < characters.count {
            guard characters[index].isNumber else {
                index += 1
                continue
            }
            let previous = index > 0 ? characters[index - 1] : " "
            if previous.isLetter || previous == "_" {
                // 标识符内的数字：跳过整个标识符。判据含数字，否则指针不前进、循环不终止。
                while index < characters.count,
                      characters[index].isLetter
                          || characters[index].isNumber
                          || characters[index] == "_" {
                    index += 1
                }
                continue
            }
            var end = index
            while end < characters.count,
                  characters[end].isNumber
                      || characters[end] == "."
                      || characters[end] == "_" {
                end += 1
            }
            if end < characters.count, characters[end].isLetter {
                index = end
                continue
            }
            var token = String(characters[index..<end])
            while token.hasSuffix(".") {
                token.removeLast()
            }
            token = token.replacingOccurrences(of: "_", with: "")
            if previous == "-" {
                token = "-" + token
            }
            if !token.isEmpty {
                literals.insert(token)
            }
            index = end
        }
        return literals
    }

    private func loadCatalogValues() throws -> [String: String] {
        let url = repoRoot()
            .appendingPathComponent("PhotoCleanupMVE/Localizable.xcstrings")
        let data = try Data(contentsOf: url)
        let object = try JSONSerialization.jsonObject(with: data)
        let root = try XCTUnwrap(object as? [String: Any])
        let strings = try XCTUnwrap(root["strings"] as? [String: Any])
        var values: [String: String] = [:]
        for (key, entry) in strings {
            guard let entry = entry as? [String: Any],
                  let localizations = entry["localizations"] as? [String: Any],
                  let chinese = localizations["zh-Hans"] as? [String: Any],
                  let unit = chinese["stringUnit"] as? [String: Any],
                  let value = unit["value"] as? String else {
                continue
            }
            values[key] = value
        }
        XCTAssertGreaterThan(values.count, 100)
        return values
    }
}
