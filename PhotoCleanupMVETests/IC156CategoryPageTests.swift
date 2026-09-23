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

    // MARK: - 断言 5：选择模型的不变量（子项 C）

    func testIC156C_SelectionModelInvariants() {
        let items = Self.fixtureAssets
        let fresh = S0CategoryPageSelection(items: items)
        XCTAssertEqual(fresh.items, items)
        XCTAssertTrue(fresh.selected.isEmpty)
        XCTAssertFalse(fresh.isSubmitEnabled)
        XCTAssertEqual(fresh.selectedByteCount, 0)
        XCTAssertEqual(fresh.totalByteCount, 3_000)
        // 零选中时主按钮文案仍走同一条 key，项数为「0」（裁定 五）。
        XCTAssertEqual(fresh.selectedTextReplacements["count"], "0")
        XCTAssertEqual(
            fresh.selectedTextReplacements["bytes"],
            S0ByteCountText.string(forByteCount: 0)
        )
        XCTAssertEqual(fresh.subtitleTextReplacements["count"], "6")
        XCTAssertEqual(
            fresh.subtitleTextReplacements["bytes"],
            S0ByteCountText.string(forByteCount: 3_000)
        )

        // 点两次回原状；不在网格里的标识不理会。
        var toggled = fresh
        toggled.toggle("c")
        XCTAssertEqual(toggled.selected, ["c"])
        XCTAssertTrue(toggled.isSubmitEnabled)
        toggled.toggle("c")
        XCTAssertEqual(toggled, fresh)
        toggled.toggle("not-in-grid")
        XCTAssertEqual(toggled, fresh)

        // 「全选」：一次全选、再一次全空；部分选中时点也是全空（规格「再点为全不选」）。
        var all = fresh
        all.selectAllOrNone()
        XCTAssertEqual(all.selected, Set(items.map { $0.id }))
        XCTAssertEqual(all.selectedByteCount, all.totalByteCount)
        all.selectAllOrNone()
        XCTAssertTrue(all.selected.isEmpty)
        var partial = fresh
        partial.toggle("a")
        partial.selectAllOrNone()
        XCTAssertTrue(partial.selected.isEmpty)

        // 已选字节恒等于所选 byteCount 之和，常驻行与主按钮共用同一组取值。20 组子集取自
        // 固定种子的线性同余序列（高 6 位作六条资产的掩码）：可复现、不依赖系统随机源。
        var seed: UInt64 = 156
        for _ in 0..<20 {
            seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            let mask = Int(seed >> 58)
            var subset = fresh
            var expectedIDs: Set<String> = []
            var expectedBytes: Int64 = 0
            for (offset, item) in items.enumerated() where mask & (1 << offset) != 0 {
                subset.toggle(item.id)
                expectedIDs.insert(item.id)
                expectedBytes += item.byteCount
            }
            XCTAssertEqual(subset.selected, expectedIDs, String(mask))
            XCTAssertEqual(subset.selectedByteCount, expectedBytes, String(mask))
            XCTAssertEqual(subset.isSubmitEnabled, !expectedIDs.isEmpty, String(mask))
            XCTAssertEqual(
                subset.selectedTextReplacements["count"],
                String(expectedIDs.count)
            )
            XCTAssertEqual(
                subset.selectedTextReplacements["bytes"],
                S0ByteCountText.string(forByteCount: expectedBytes)
            )
        }

        // 移入成功后删项：其余项相对顺序不变，已选里不再有被删的。
        var removal = fresh
        for id in ["b", "d", "e"] {
            removal.toggle(id)
        }
        removal.remove(ids: ["b", "d"])
        XCTAssertEqual(removal.items.map { $0.id }, ["a", "c", "e", "f"])
        XCTAssertTrue(removal.selected.isDisjoint(with: Set(["b", "d"])))
        XCTAssertEqual(removal.selected, ["e"])
        // 页面提交路径：移走的正是全部已选 → 已选清空、主按钮回到禁用、项数回到「0」。
        let chosen = removal.selected
        removal.remove(ids: chosen)
        XCTAssertEqual(removal.items.map { $0.id }, ["a", "c", "f"])
        XCTAssertTrue(removal.selected.isEmpty)
        XCTAssertFalse(removal.isSubmitEnabled)
        XCTAssertEqual(removal.selectedTextReplacements["count"], "0")
    }

    // MARK: - 断言 6：页面文件守 S0 纪律（子项 C；子项 D 把流程文件加进逐文件名单）

    func testIC156C_PageFilesKeepS0Discipline() throws {
        let allowed: Set<String> = ["0", "1", "2"]
        for relativePath in Self.disciplineFiles {
            let raw = try XCTUnwrap(sourceText(relativePath), relativePath)
            let stripped = try XCTUnwrap(strippedSource(relativePath), relativePath)
            XCTAssertGreaterThan(stripped.count, 0)
            let literals = numericLiterals(in: stripped)
            XCTAssertTrue(
                literals.isSubset(of: allowed),
                relativePath + " 出现了 0／1／2 之外的裸数："
                    + literals.subtracting(allowed).sorted().joined(separator: ",")
            )
            for needle in Self.photoKitNeedles + Self.dynamicAppearanceNeedles {
                XCTAssertEqual(
                    occurrences(of: needle, in: stripped),
                    0,
                    relativePath + " 出现了 " + needle
                )
            }
            XCTAssertEqual(
                occurrences(of: "Text(\"", in: raw),
                0,
                relativePath + " 出现了裸字面量 Text"
            )
        }

        // 以下只对类别页文件：纯呈现 + 回调，chrome 全借 S1，页面取值只经登记表。
        let page = try XCTUnwrap(strippedSource(Self.pagePath))
        XCTAssertEqual(occurrences(of: "machine.handle(", in: page), 0)
        XCTAssertEqual(occurrences(of: "beginVerification", in: page), 0)
        XCTAssertGreaterThanOrEqual(occurrences(of: "s1ChromeCircleGlass()", in: page), 1)
        XCTAssertGreaterThanOrEqual(occurrences(of: "s1ChromeGlassBackground(", in: page), 1)
        XCTAssertGreaterThanOrEqual(occurrences(of: "S1ChromeLayout.", in: page), 3)
        for member in ["rowHeight", "horizontalMargin", "itemSpacing", "topRowTopInset"] {
            XCTAssertGreaterThanOrEqual(
                occurrences(of: "S1ChromeLayout." + member, in: page),
                1,
                member
            )
        }
        // 卡面写「S1ChromeTypography. ≥ 2」。按裁定 四的公式，返回圆钮 = 符号 +
        // `s1ChromeCircleGlass()`，圆钮字号 `circleIconPointSize` 在 helper 内部取，页面文件里
        // 只剩「全选」胶囊一处（偏离登记于 IC-156 自验报告）。改钉两件事：胶囊字号在页面里
        // 取自 S1，圆钮字号确在 helper 里取自 S1。
        XCTAssertEqual(occurrences(of: "S1ChromeTypography.titleFontSize", in: page), 1)
        let s1View = try XCTUnwrap(strippedSource(Self.s1ViewPath))
        let circleHelper = try XCTUnwrap(
            slice(
                s1View,
                from: "func s1ChromeCircleGlass() -> some View {",
                to: Self.newline + "    }" + Self.newline
            ),
            "圆钮 helper 没切到——声明文本变了"
        )
        XCTAssertEqual(
            occurrences(of: "S1ChromeTypography.circleIconPointSize", in: circleHelper),
            1
        )
        // 登记表引用：按实装数写死（IC-165 C：类别页改为「卡片叠」，取值只经 `S0DeckMetrics`）。
        XCTAssertEqual(occurrences(of: "S0DeckMetrics.", in: page), 153)
        // SPEC-S0 v3 第十四节第 2 部分的卡片叠一族逐个有人用：在两只页面、zoom 过渡与宽幅封面里
        // 以 `S0DeckMetrics.<名>` 出现，或在登记表文件内被别的登记值／派生函数以裸名引用
        // （定义之外至少再一次——五个类别色走这条）。只有两个 v3 登记而现行无人用的值豁免。
        let metrics = try XCTUnwrap(strippedSource(Self.metricsPath))
        let metricsBody = try XCTUnwrap(
            slice(metrics, from: "enum S0DeckMetrics {", to: Self.topLevelClose)
        )
        let registeredNames = metricsBody
            .components(separatedBy: Self.newline)
            .compactMap { line -> String? in
                guard let declaration = line.range(of: "    static let ") else {
                    return nil
                }
                let name = String(
                    line[declaration.upperBound...].prefix {
                        $0.isLetter || $0.isNumber || $0 == "_"
                    }
                )
                return name.isEmpty ? nil : name
            }
        XCTAssertEqual(registeredNames.count, 198)
        var usageScope = String()
        for relativePath in [
            Self.pagePath,
            "PhotoCleanupMVE/Features/S0/S0DeckHomeView.swift",
            "PhotoCleanupMVE/Features/S0/S0DeckZoomTransition.swift",
            "PhotoCleanupMVE/Features/Shared/S0DeckCoverView.swift"
        ] {
            usageScope += try XCTUnwrap(strippedSource(relativePath), relativePath)
        }
        var unused: Set<String> = []
        for name in registeredNames
        where occurrences(of: "S0DeckMetrics." + name, in: usageScope) == 0
            && occurrences(of: name, in: metrics) < 2 {
            unused.insert(name)
        }
        XCTAssertEqual(unused, ["cellLabelFill", "pageTitleTopSpacing"])
        // 封面在 `Features/Shared/S0DeckCoverView.swift` 里取（`ThumbnailView` 是正方形取图）。
        XCTAssertEqual(occurrences(of: "ThumbnailView(", in: page), 0)
        XCTAssertEqual(occurrences(of: "showsPlaceholderGlyph: false", in: page), 0)
        XCTAssertEqual(occurrences(of: "S2AmbientBackdropView()", in: page), 0)
        // 时长格式化器在文本 helper 文件里（IC-165 C 从退役的旧类别页原样搬出）。
        let texts = try XCTUnwrap(strippedSource("PhotoCleanupMVE/Features/S0/S0Text.swift"))
        XCTAssertGreaterThanOrEqual(occurrences(of: "DateComponentsFormatter", in: texts), 1)
        // 符号名只从 `S0DeckSymbol` 取（陷阱 18：不写返回字符串的 helper）。
        XCTAssertEqual(occurrences(of: "Image(systemName: ", in: page), 7)
        XCTAssertEqual(
            occurrences(of: "Image(systemName: S0DeckSymbol.", in: page),
            7
        )

        // 正对照：同一套剥离口径与 needle 在既有文件上确实命中，上面各为 0 不是空转。
        XCTAssertGreaterThan(occurrences(of: "Material", in: s1View), 0)
        let thumbnail = try XCTUnwrap(strippedSource(Self.thumbnailPath))
        XCTAssertGreaterThan(occurrences(of: "PHAsset", in: thumbnail), 0)
        XCTAssertGreaterThan(occurrences(of: "import Photos", in: thumbnail), 0)
    }

    // MARK: - 断言 7：目录加五条 key，两处既有门禁的名单已更新（子项 C）

    func testIC156C_CatalogGainsFiveKeysAndBothGatesAreUpdated() throws {
        // IC-165 C（裁定 六）：`s0.` 38 → 39、`s0.categoryPage.` 6 → 9（删长按提示，加返回、
        // 排序名、月份计数、未知日期；副行、已选、主按钮三条改值）。IC-166 B：S0-3 副句一条，`s0.` → 40。
        // IC-167：B 删首页胶囊一条、C 加排序「从小到大」一条，`s0.` 仍 40；`s0.categoryPage.` 9 → 10。
        // IC-168 E：类别页进入失败提示一条，`s0.` 40 → 41、`s0.categoryPage.` 10 → 11。
        let catalog = try loadCatalogValues()
        XCTAssertEqual(catalog.keys.filter { $0.hasPrefix("s0.") }.count, 41)
        XCTAssertEqual(catalog.keys.filter { $0.hasPrefix("s0.categoryPage.") }.count, 11)

        let expected: [String: String] = [
            "s0.categoryPage.back": "返回",
            "s0.categoryPage.subtitle": "{count} 项 · {order}",
            "s0.categoryPage.sort.size": "从大到小",
            "s0.categoryPage.sort.sizeAscending": "从小到大",
            "s0.categoryPage.selectAll": "全选",
            "s0.categoryPage.selected": "已选 {count} 项",
            "s0.categoryPage.submit": "移入待删篮",
            "s0.categoryPage.toast": "已移入待删篮",
            "s0.categoryPage.toast.enterFailed": "暂时无法逐张查看，请重试。",
            "s0.categoryPage.month.count": "{count} 项",
            "s0.categoryPage.undated": "未知日期"
        ]
        let pageRaw = try XCTUnwrap(sourceText(Self.pagePath))
        // 按 key 提取器取（多行 `L10n.text(` 调用的 key 写在下一行，连写的 needle 会空转）。
        let pageKeys = localizationKeys(in: pageRaw)
        for (key, value) in expected {
            XCTAssertEqual(catalog[key], value, key)
            XCTAssertTrue(pageKeys.contains(key), key)
        }
        // 页面引用的 `s0.categoryPage.` 恰是上面映射里的这些条；全部 key 另有占比角标一条与借用的排序三条。
        XCTAssertEqual(
            pageKeys.filter { $0.hasPrefix("s0.categoryPage.") },
            Set(expected.keys)
        )
        XCTAssertEqual(
            pageKeys,
            Set(expected.keys).union([
                "s0.home.share",
                "s1.sort.accessibility",
                "s1.sort.newest_first",
                "s1.sort.oldest_first"
            ])
        )

        // 占位符：项数在副行、已选、月份计数三条；排序名只在副行；字节量不进任何一条
        // （体积由格式化器单独排）。
        let withCount: Set<String> = [
            "s0.categoryPage.subtitle",
            "s0.categoryPage.selected",
            "s0.categoryPage.month.count"
        ]
        for key in expected.keys {
            let value = try XCTUnwrap(catalog[key], key)
            XCTAssertEqual(occurrences(of: "{count}", in: value), withCount.contains(key) ? 1 : 0, key)
            XCTAssertEqual(
                occurrences(of: "{order}", in: value),
                key == "s0.categoryPage.subtitle" ? 1 : 0,
                key
            )
            XCTAssertEqual(occurrences(of: "{bytes}", in: value), 0, key)
        }

        // 裁定 六：IC-147 断言 11 与 IC-148 断言 10 的文件名单已加类别页。
        for gate in [
            "PhotoCleanupMVETests/IC147S0BehaviorTests.swift",
            "PhotoCleanupMVETests/IC148S0VisualTests.swift"
        ] {
            let source = try XCTUnwrap(sourceText(gate), gate)
            XCTAssertGreaterThanOrEqual(
                occurrences(of: "S0DeckCategoryPageView.swift", in: source),
                1,
                gate
            )
        }
    }

    // MARK: - 断言 8：toast 新替旧、按代际到期（子项 C）

    func testIC156C_ToastPresenterReplacesAndExpiresByGeneration() throws {
        var scheduled: [(delay: TimeInterval, action: () -> Void)] = []
        let presenter = S0FeedbackToastPresenter(scheduler: { delay, action in
            scheduled.append((delay: delay, action: action))
        })
        XCTAssertNil(presenter.activeText)
        XCTAssertEqual(presenter.presentedCount, 0)

        presenter.present(text: "first", durationMilliseconds: 2_000)
        XCTAssertEqual(presenter.activeText, "first")
        presenter.present(text: "second", durationMilliseconds: 2_000)
        XCTAssertEqual(presenter.activeText, "second")
        XCTAssertEqual(presenter.presentedCount, 2)
        XCTAssertEqual(scheduled.count, 2)

        // 旧的一条到期不清除新的一条；新的一条到期才清空。
        scheduled[0].action()
        XCTAssertEqual(presenter.activeText, "second")
        scheduled[1].action()
        XCTAssertNil(presenter.activeText)

        // 毫秒换秒：2000 ms = 2 s，交给调度器的延时同值；负时长按 0。
        XCTAssertEqual(
            try XCTUnwrap(presenter.lastScheduledDurationSeconds),
            2,
            accuracy: 0.000_001
        )
        for entry in scheduled {
            XCTAssertEqual(entry.delay, 2, accuracy: 0.000_001)
        }
        presenter.present(text: "third", durationMilliseconds: -1)
        XCTAssertEqual(
            try XCTUnwrap(presenter.lastScheduledDurationSeconds),
            0,
            accuracy: 0.000_001
        )
    }

    // MARK: - 断言 9：时长与字节量文本走系统格式化器（子项 C）

    func testIC156C_DurationAndByteTextsAreFormatterDriven() throws {
        XCTAssertEqual(S0CategoryPageDurationText.string(for: 761), "12:41")
        XCTAssertEqual(S0CategoryPageDurationText.string(for: 62), "01:02")
        XCTAssertEqual(S0CategoryPageDurationText.string(for: 0), "00:00")
        XCTAssertEqual(S0CategoryPageDurationText.string(for: -5), "00:00")

        // 不自拼单位与分隔符。
        let pageRaw = try XCTUnwrap(sourceText(Self.pagePath))
        for spliced in ["\" GB\"", "\" MB\"", "\":\""] {
            XCTAssertEqual(occurrences(of: spliced, in: pageRaw), 0, spliced)
        }
        // IC-165 C：「卡片叠」类别页的字节量调用是多行写法（`forByteCount:` 在下一行），按调用名
        // 计：副行体积、收起导航体积、格底体积、底栏已选体积四处。
        XCTAssertEqual(occurrences(of: "S0ByteCountText.string(", in: pageRaw), 4)
        XCTAssertEqual(
            occurrences(of: "S0CategoryPageDurationText.string(for:", in: pageRaw),
            1
        )
    }

    // MARK: - 子项 C 的夹具与 helper

    /// IC-165 C：类别页改为「卡片叠」`S0DeckCategoryPageView`（旧类别页退役）。
    private static let pagePath = "PhotoCleanupMVE/Features/S0/S0DeckCategoryPageView.swift"
    private static let s1ViewPath = "PhotoCleanupMVE/Features/S1/S1View.swift"
    private static let thumbnailPath = "PhotoCleanupMVE/Features/Shared/ThumbnailView.swift"

    /// 断言 6 逐文件纪律的名单。
    private static let disciplineFiles = [
        pagePath,
        // IC-156 D：流程容器同守 S0 纪律。
        flowPath
    ]

    /// 与 IC-148 断言 4 同一名单。
    private static let photoKitNeedles = [
        "import Photos",
        "PHAsset",
        "PHImageManager",
        "PHFetch",
        "PHAssetResource",
        "PHCachingImageManager",
        "PHPhotoLibrary"
    ]

    /// 与 IC-148 断言 2 同一名单（裁定 一：恒深色）。
    private static let dynamicAppearanceNeedles = [
        "colorScheme",
        "systemBackground",
        "UIColor.label",
        ".primary",
        "Material",
        "ultraThin",
        "S2ChromeForeground"
    ]

    /// 六条资产，含两条同字节（c、d），体积降序、同体积按标识升序。
    private static let fixtureAssets = [
        S0CategoryAsset(id: "a", byteCount: 900, isVideo: true, duration: 761),
        S0CategoryAsset(id: "b", byteCount: 700, isVideo: true, duration: 62),
        S0CategoryAsset(id: "c", byteCount: 500, isVideo: false, duration: 0),
        S0CategoryAsset(id: "d", byteCount: 500, isVideo: false, duration: 0),
        S0CategoryAsset(id: "e", byteCount: 300, isVideo: true, duration: 5),
        S0CategoryAsset(id: "f", byteCount: 100, isVideo: false, duration: 0)
    ]

    /// 数值字面量提取，口径同 IC-148 `numericLiterals(in:)`。
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
                // 标识符内的数字（如 `S0HomePalette` 的 `0`）：跳过整个标识符。判据含数字，
                // 否则指针不前进、循环不终止。
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

    /// `L10n.text(` 后跳过空白取紧跟的字符串字面量，口径同 IC-147。
    private func localizationKeys(in source: String) -> Set<String> {
        var keys: Set<String> = []
        let opening = "L10n.text("
        var searchStart = source.startIndex
        while let found = source.range(
            of: opening,
            range: searchStart..<source.endIndex
        ) {
            searchStart = found.upperBound
            var cursor = found.upperBound
            while cursor < source.endIndex, source[cursor].isWhitespace {
                cursor = source.index(after: cursor)
            }
            guard cursor < source.endIndex, source[cursor] == "\"" else {
                continue
            }
            let keyStart = source.index(after: cursor)
            guard let closing = source.range(
                of: "\"",
                range: keyStart..<source.endIndex
            ) else {
                break
            }
            keys.insert(String(source[keyStart..<closing.lowerBound]))
            searchStart = closing.upperBound
        }
        return keys
    }

    /// 目录 zh-Hans 取值，口径同 IC-147。
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

    // MARK: - 断言 10：流程容器承载首页与类别页，App 只换构造点（子项 D）

    func testIC156D_FlowHostsHomeAndPageAndAppOnlySwapsBuilder() throws {
        let flow = try XCTUnwrap(strippedSource(Self.flowPath))
        // IC-165 B：旧首页退役，首页构造点只剩「卡片叠」首页。
        XCTAssertEqual(occurrences(of: "S0DeckHomeView(", in: flow), 1)
        XCTAssertGreaterThanOrEqual(occurrences(of: "NavigationStack", in: flow), 1)
        XCTAssertEqual(occurrences(of: "navigationDestination(item:", in: flow), 1)
        XCTAssertEqual(occurrences(of: ".returnedFromCategoryPage", in: flow), 1)
        // 进篮成功后一处、返回首页一处、从 S2 回到类别页一处（IC-157 裁定 一）；首页自己的摄入
        // 在 `S0DeckHomeView.swift`，不在此数。
        XCTAssertEqual(occurrences(of: "machine.ingest(", in: flow), 3)
        // IC-165 B：类别页的两层 `.toolbar` 由 `S0DeckCategoryPageView` 自己挂，流程文件只剩根页
        // 隐藏空导航栏那一处（留着它会占去顶部安全区、把首页整体下推一个导航栏高度）。
        XCTAssertEqual(occurrences(of: ".toolbar(.hidden, for: .tabBar)", in: flow), 0)
        XCTAssertEqual(occurrences(of: ".toolbar(.hidden, for: .navigationBar)", in: flow), 1)
        XCTAssertEqual(occurrences(of: "S0DeckCategoryPageView(", in: flow), 1)
        // 协调器与会话层只经 App 传闭包。
        for forbidden in ["CleanupCoordinator", "SessionStore", "S1StateMachine"] {
            XCTAssertEqual(occurrences(of: forbidden, in: flow), 0, forbidden)
        }

        let app = try XCTUnwrap(strippedSource(Self.appPath))
        XCTAssertEqual(occurrences(of: "S0CleanupFlowView(", in: app), 1)
        XCTAssertEqual(occurrences(of: "S0View(", in: app), 0)
        XCTAssertEqual(occurrences(of: "markPendingDeletion(", in: app), 1)
        XCTAssertEqual(occurrences(of: "S0CategoryPageRange.prefix", in: app), 2) // IC-157：进 S2 闭包一处
        XCTAssertGreaterThanOrEqual(occurrences(of: "S0CategoryText.displayName(for:", in: app), 1)
        // `cc686d9` 为 2（S1 接线的形参标签与实参各一处），本卡加一处实参。
        // IC-168 D：清理 tab 回落 toast 的呈现器再读一处，3 → 4。
        XCTAssertEqual(occurrences(of: "feedbackToastDurationMilliseconds", in: app), 4)
        XCTAssertEqual(occurrences(of: "s0Screen(s1Machine: s1Machine)", in: app), 1)
        // IC-147 断言 2／3 与 IC-153 断言 11 钉住的接线照旧。
        XCTAssertEqual(occurrences(of: "advanceScan()", in: app), 2)
        XCTAssertEqual(occurrences(of: "onSnapshotDidChange", in: app), 1)
        XCTAssertEqual(occurrences(of: "S0ScanOutcomeTransition.events(", in: app), 1)
        XCTAssertEqual(occurrences(of: "S0TabContainer(", in: app), 1)
        XCTAssertEqual(occurrences(of: "tabContainer(s1Machine: machine)", in: app), 1)

        // 构造签名照卡面 D1 的形参与顺序：编译期即核；只构造、不渲染（陷阱 23）。
        // IC-157 C：加 `flowModel:` 与 `onEnterS2:`，顺序照其声明顺序（陷阱 16）。
        _ = S0CleanupFlowView(
            machine: S0StateMachine(),
            dataProvider: S0CleanupDataStub(scenario: .readyWithItems),
            flowModel: S0CleanupFlowModel(),
            onSwitchToOrganizeTab: {},
            onMoveToBasket: { _, _ in true },
            onEnterS2: { _, _, _ in false },
            toastDurationMilliseconds: 2_000
        )
    }

    // MARK: - 断言 11：进篮 → 返回 → 可落 S0-3，返回不重排（子项 D）

    func testIC156D_ReturnRecomputesAndCanLandOnEmpty() {
        let ready = S0CleanupDataStub(scenario: .readyWithItems)
        let emptied = S0CleanupDataStub(scenario: .readyWithoutItems)

        let machine = S0StateMachine()
        machine.handle(.applicationOpened)
        machine.ingest(ready.currentSnapshot())
        machine.handle(.scanCompleted)
        XCTAssertEqual(machine.state, .ready)
        let reorderCount = machine.categoryReorderCount
        XCTAssertEqual(reorderCount, 1)

        XCTAssertEqual(
            machine.handle(.categoryRowTapped(.bigVideo)),
            .categoryPage(.bigVideo)
        )
        // 进篮后可清理量归零（模拟）：流程容器先摄入新快照，再发返回事件。
        machine.ingest(emptied.currentSnapshot())
        XCTAssertEqual(machine.handle(.returnedFromCategoryPage), .home(.empty))
        XCTAssertEqual(machine.state, .empty)
        XCTAssertEqual(machine.categoryReorderCount, reorderCount, "返回首页发生了重排")

        // 对照：没进篮就返回，数据与进去前一致、仍是就绪。
        let untouched = S0StateMachine()
        untouched.handle(.applicationOpened)
        untouched.ingest(ready.currentSnapshot())
        untouched.handle(.scanCompleted)
        let before = untouched.snapshot
        XCTAssertEqual(
            untouched.handle(.categoryRowTapped(.bigVideo)),
            .categoryPage(.bigVideo)
        )
        untouched.ingest(ready.currentSnapshot())
        XCTAssertEqual(untouched.handle(.returnedFromCategoryPage), .home(.ready))
        XCTAssertEqual(untouched.snapshot, before)
        XCTAssertEqual(untouched.categoryReorderCount, 1)
    }

    // MARK: - 子项 D 的路径

    private static let flowPath = "PhotoCleanupMVE/Features/S0/S0CleanupFlowView.swift"
    private static let appPath = "PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift"

    // 断言 1（`testIC156A_RegistryHasFortyTwoConstantsWithProvenance`）与断言 2
    // （`testIC156A_MetricsValuesMatchCanvas`）随 IC-165 C 删去：v2 的 42 值类别页登记表随旧类别页
    // 退役；卡片叠一族的 198 值由 IC-165 断言 6 与本文件断言 6 钉住。

    // MARK: - 源码扫描 helper（口径与 IC-147／IC-148／IC-155 一致）

    /// IC-165 C：类别页与首页共用卡片叠一族登记表（v2 的两份登记表随旧页退役）。
    private static let metricsPath = "PhotoCleanupMVE/Features/S0/S0DeckMetrics.swift"
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
