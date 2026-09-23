import Foundation
import SwiftUI
import UIKit
import XCTest
@testable import PhotoCleanupMVE

/// IC-148：S0 视觉层——氛围底与玻璃卡、hero 与四态版式、分段条
/// `S0SegmentBar`、类别行 `S0CategoryRow`。
///
/// 依据 SPEC-S0 v1（SHA-256 `F5D6…2282`）第三节四态的**显示元素清单**、
/// 第十四节第 2 部分**视觉登记制常量**（52 值）、第十四节第 3 部分文案登记；
/// SPEC-S2 v20 决策 61（氛围底配方与恒深色）；Decision_log 第 170 条裁定 1
/// （`.counting` 在 S0-1 可点）与裁定 3（`VF=已通过` 复位路径未定，不得自造）。
///
/// **本卡不改行为。** 状态机、迁移、点击有效性、数据源协议与桩都是 IC-147 的
/// 交付物，由 `IC147S0BehaviorTests` 的 16 项钉住；本文件只钉视觉层。
///
/// 断言编号与任务卡一一对应，共十四条：1～4 属子项 A，5～7 属子项 B，
/// 8～11 属子项 C，12～14 属子项 D。
///
/// IC-165 C：v2 的首页三族登记（`S0HomeMetrics`／`S0SegmentBar` 视图层／`S0CategoryRow`）随旧首页
/// 退役，断言 1 与 12 随之删去；其余各条改扫「卡片叠」两页与 SPEC-S0 v3 的对应物。
final class IC148S0VisualTests: XCTestCase {

    /// S0 的**非视图**产品文件（IC-165 C：登记表、卡片叠呈现口径、分段条模型、zoom 过渡）。
    /// 两只视图不在此列——类别页收起导航的排序圆钮借 S1 的圆钮图标字号（断言 7 的名单）。
    private static let newProductFiles = [
        "PhotoCleanupMVE/Features/S0/S0DeckMetrics.swift",
        "PhotoCleanupMVE/Features/S0/S0DeckHomeModel.swift",
        "PhotoCleanupMVE/Features/S0/S0SegmentBarModel.swift",
        "PhotoCleanupMVE/Features/S0/S0DeckZoomTransition.swift"
    ]

    /// **视图**文件（PhotoKit／造假／文案扫描的扫描面）：「卡片叠」两页与 zoom 过渡。取图的
    /// `S0DeckCoverView` 与取日期的 `S0DeckAssetDates` 在 `Features/Shared/`，不在此列。
    private static let viewFiles = [
        "PhotoCleanupMVE/Features/S0/S0DeckHomeView.swift",
        "PhotoCleanupMVE/Features/S0/S0DeckCategoryPageView.swift",
        "PhotoCleanupMVE/Features/S0/S0DeckZoomTransition.swift"
    ]

    /// 顶层类型的收口：换行 + 右花括号 + 换行。
    ///
    /// 用 `UnicodeScalar` 拼而不写转义字面量：本机（Windows／Git Bash）用 heredoc
    /// 打补丁时会把反斜杠吞掉，`"\n}\n"` 会被写成一个**真换行**，编译直接报
    /// unterminated string literal（IC-148 #294 实例，白费一次 CI）。
    private static let topLevelClose =
        String(Character(UnicodeScalar(UInt8(10)))) + "}"
            + String(Character(UnicodeScalar(UInt8(10))))

    /// 成员级收口：换行 + 四空格缩进的右花括号。同样不写转义字面量。
    private static let memberClose =
        String(Character(UnicodeScalar(UInt8(10)))) + "    }"

    /// 零裸数断言的扫描面是**视图体**，不是整个文件（任务卡断言 3 原文：
    /// 「三个视图体内」）。IC-165 C：逐个列出「卡片叠」两页与宽幅封面的声明锚点。
    private static let viewBodyAnchors: [(path: String, anchor: String)] = [
        (
            "PhotoCleanupMVE/Features/S0/S0DeckHomeView.swift",
            "struct S0DeckHomeView: View {"
        ),
        (
            "PhotoCleanupMVE/Features/S0/S0DeckCategoryPageView.swift",
            "struct S0DeckCategoryPageView: View {"
        ),
        (
            "PhotoCleanupMVE/Features/Shared/S0DeckCoverView.swift",
            "struct S0DeckCoverView: View {"
        )
    ]

    // 断言 1（`testIC148AAssertion01RegistryMatchesSpecSection14`）随 IC-165 C 删去：v2 的 52 个
    // 首页登记值随旧首页退役；卡片叠一族的 198 值由 IC-165 断言 6 与 IC-156 断言 6 钉住。

    // MARK: - 断言 2：恒深色（裁定 甲，源码扫描带正对照）

    func testIC148AAssertion02AlwaysDarkRecipe() throws {
        // 与 `testIC146B_AmbientRecipeIsIdenticalInBothColorSchemes` 同一名单，
        // 一项不减。
        let forbidden = [
            "colorScheme",
            "systemBackground",
            "UIColor.label",
            ".primary",
            "S2ChromeForeground",
            "Material",
            "ultraThin"
        ]
        for relativePath in Self.newProductFiles + Self.viewFiles {
            let source = try XCTUnwrap(strippedSource(relativePath))
            XCTAssertGreaterThan(source.count, 0)
            for dynamic in forbidden {
                XCTAssertEqual(
                    occurrences(of: dynamic, in: source),
                    0,
                    relativePath + " 引用了随外观变化的 " + dynamic
                )
            }
        }

        // 正对照其一：扫描不是空转——登记表文件里确实读到了自己的定义。
        let metrics = try XCTUnwrap(
            strippedSource("PhotoCleanupMVE/Features/S0/S0DeckMetrics.swift")
        )
        XCTAssertGreaterThanOrEqual(
            occurrences(of: "enum S0DeckMetrics", in: metrics),
            1
        )

        // 正对照其二（**针对 needle 本身**）：同一套禁用词扫在**确实含有它们**
        // 的既有文件上必须命中非零。`S1View.swift` 的 chrome 玻璃 helper 用了
        // `.ultraThinMaterial`，同时含 `Material` 与 `ultraThin` 两个词。
        // 没有这一条，上面那组「各为 0」有可能是 needle 写错导致的空转。
        let s1View = try XCTUnwrap(
            strippedSource("PhotoCleanupMVE/Features/S1/S1View.swift")
        )
        XCTAssertGreaterThan(occurrences(of: "Material", in: s1View), 0)
        XCTAssertGreaterThan(occurrences(of: "ultraThin", in: s1View), 0)
        XCTAssertGreaterThan(occurrences(of: ".primary", in: s1View), 0)

        // 幕底色两种 trait 解析同值（照 T2 口径）。
        let base = UIColor(S2AmbientMetrics.baseColor)
        XCTAssertEqual(
            base.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark)),
            base.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light)),
            "幕底色随外观解析出了两个值"
        )
        // 类别色同样与 trait 无关（IC-165 C：v3 的卡片叠类别色，含「其余照片」）。
        for color in [
            S0DeckMetrics.colorVideo,
            S0DeckMetrics.colorSimilar,
            S0DeckMetrics.colorScreenshot,
            S0DeckMetrics.colorScreenRecording,
            S0DeckMetrics.colorDuplicate,
            S0DeckMetrics.colorRest
        ] {
            let resolved = UIColor(color)
            XCTAssertEqual(
                resolved.resolvedColor(
                    with: UITraitCollection(userInterfaceStyle: .dark)
                ),
                resolved.resolvedColor(
                    with: UITraitCollection(userInterfaceStyle: .light)
                ),
                "类别色随外观解析出了两个值"
            )
        }
    }

    // MARK: - 断言 3：零裸数（照 T1 正对照口径）

    /// 三个视图文件剔注释与字符串后，**数值字面量只允许 `0`／`1`／`2`**。
    ///
    /// 允许清单的理由：`0` 用于 `spacing: 0`／`minLength: 0`／
    /// `Color.white.opacity(0)`（渐变收零）；`1` 用于 `lineWidth: 1` 与
    /// `count - 1`；`2` 用于 `size.width / 2` 与 `span * 2`（斜纹画布的对中与
    /// 跨度加倍）。这三个都是 SwiftUI 结构性参数或纯几何推导，**不是任何登记
    /// 取值**；登记取值一律经 `S0DeckMetrics`。
    func testIC148AAssertion03NoBareNumbersInViewBodies() throws {
        let allowed: Set<String> = ["0", "1", "2"]
        for (relativePath, anchor) in Self.viewBodyAnchors {
            let source = try XCTUnwrap(strippedSource(relativePath))
            let body = try XCTUnwrap(
                slice(source, from: anchor, to: Self.topLevelClose),
                anchor + " 没切到——声明文本变了，断言会静默放空"
            )
            let literals = numericLiterals(in: body)
            XCTAssertTrue(
                literals.isSubset(of: allowed),
                anchor + " 出现了登记值之外的裸数："
                    + literals.subtracting(allowed).sorted().joined(
                        separator: ","
                    )
            )
            // 正对照：该视图体确实在经登记表取值。
            XCTAssertGreaterThan(
                occurrences(of: "S0DeckMetrics.", in: body),
                0,
                anchor + " 一处登记值都没引用，扫描口径可疑"
            )
        }

        // 两只页面文件级同样只有 0／1／2（IC-165 C：系统版本判定抽到 zoom 过渡文件后成立）。
        for relativePath in [
            "PhotoCleanupMVE/Features/S0/S0DeckHomeView.swift",
            "PhotoCleanupMVE/Features/S0/S0DeckCategoryPageView.swift"
        ] {
            let source = try XCTUnwrap(strippedSource(relativePath))
            XCTAssertTrue(
                numericLiterals(in: source).isSubset(of: allowed),
                relativePath + " 文件级出现了登记值之外的裸数"
            )
        }
    }

    // MARK: - 断言 4：复用不复制（裁定 丙）

    func testIC148AAssertion04ReusesAmbientWithoutCopyingOrTouchingPhotoKit() throws {
        let photoKitSymbols = [
            "import Photos",
            "PHAsset",
            "PHPhotoLibrary",
            "PHImageManager",
            "PHFetch",
            "PHCachingImageManager",
            "PHAssetResource"
        ]
        // 视图文件 + 登记表 + tab 容器：PhotoKit 零命中（取图与取日期的两只在 `Features/Shared/`）。
        for relativePath in Self.viewFiles + [
            "PhotoCleanupMVE/Features/S0/S0DeckMetrics.swift",
            "PhotoCleanupMVE/Features/S0/S0TabContainer.swift"
        ] {
            let source = try XCTUnwrap(strippedSource(relativePath))
            for symbol in photoKitSymbols {
                XCTAssertEqual(
                    occurrences(of: symbol, in: source),
                    0,
                    relativePath + " 出现了 " + symbol
                )
            }
        }
        // 正对照：**针对 needle 本身**。原先读的是 S0 侧的取图实现，那个文件
        // 随 IC-151 裁定 五 整条删除，改读一个确实用 PhotoKit 且本卡不动的
        // 既有文件；没有这一条，上面那组「各为 0」有可能是 needle 写错的空转。
        let scanner = try XCTUnwrap(
            strippedSource("PhotoCleanupMVE/Services/AssetSizeScanner.swift")
        )
        XCTAssertGreaterThan(occurrences(of: "PHAsset", in: scanner), 0)
        XCTAssertGreaterThan(occurrences(of: "import Photos", in: scanner), 0)

        // 原「复用 S2 氛围底视图」一段随 IC-165 C 删去：SPEC-S0 v3 首页底色为平涂 `#0B0F0D`，
        // 不用氛围底（`S2AmbientBackdropView` 在两只视图里 0 处由 IC-165 断言 4 钉住）。
    }

    // MARK: - 断言 5：四态显示元素清单逐条（源码扫描 + 夹具）

    /// **源码扫描 + 夹具驱动，真机未覆盖**：SwiftUI 的 `@ViewBuilder` 分支不能
    /// 在单元测试里渲染比对，故此处钉的是「显隐判据写对了没有」加上机器侧的
    /// 显隐谓词。真机逐条看由 H71 第 3 条兜底。
    func testIC148BAssertion05FourStateElementLists() throws {
        // IC-165 C：首页改为「卡片叠」。四态由 `switch machine.state` 分派（IC-147 断言 C 钉）：
        // 就绪／扫描中走整套版式，S0-3 与 S0-4 走同一只居中块。
        let view = try XCTUnwrap(
            strippedSource("PhotoCleanupMVE/Features/S0/S0DeckHomeView.swift")
        )
        XCTAssertEqual(occurrences(of: "private var deckScreen: some View {", in: view), 1)
        XCTAssertEqual(occurrences(of: "private var failureBlock: some View {", in: view), 1)
        XCTAssertEqual(occurrences(of: "private func centeredBlock(", in: view), 1)
        // 总条（含扫描中「未扫描」段）只在整套版式里画，取同一份段模型。
        XCTAssertEqual(occurrences(of: "S0SegmentBarModel.make", in: view), 1)

        // 机器侧谓词（IC-147 交付，本卡只复核口径没被改坏）。
        let failed = machineInFailedState()
        XCTAssertFalse(failed.showsCategoryRows)
        XCTAssertFalse(failed.showsPendingClearanceRow)

        // S0-3 与 S0-4 的文案。**文案 key 一律扫原文**：key 写在字符串字面量里，而
        // `strippedSource` 把字面量内容整个剔掉，拿剔过的源码找 key 恒为 0。
        let rawView = try XCTUnwrap(
            sourceText("PhotoCleanupMVE/Features/S0/S0DeckHomeView.swift")
        )
        for key in [
            "s0.home.failed.auth.title",
            "s0.home.failed.auth.action",
            "s0.home.failed.read.title",
            "s0.home.failed.read.action",
            "s0.home.hero.empty.title",
            "s0.home.hero.empty.action"
        ] {
            XCTAssertEqual(occurrences(of: key, in: rawView), 1, key)
        }

        // S0-1：未扫描段。
        let scanning = S0SegmentBarModel.make(
            categories: [countingCategory(bytes: 1_000)],
            ledgerEntries: [],
            libraryTotalByteCount: 10_000,
            progress: S0ScanProgress(scannedAssetCount: 2, totalAssetCount: 10),
            isScanning: true
        )
        XCTAssertTrue(
            scanning.segments.contains { $0.kind == .unscanned },
            "S0-1 的分段条没有未扫描段"
        )
        // S0-2／S0-3 不画未扫描段。
        let settled = S0SegmentBarModel.make(
            categories: [settledCategory(bytes: 1_000)],
            ledgerEntries: [],
            libraryTotalByteCount: 10_000,
            progress: S0ScanProgress(scannedAssetCount: 10, totalAssetCount: 10),
            isScanning: false
        )
        XCTAssertFalse(settled.segments.contains { $0.kind == .unscanned })
    }

    // MARK: - 断言 6：首帧口径

    func testIC148BAssertion06ScanningHeroHidesZeroByteValue() throws {
        // IC-165 C（裁定 四）：hero 是照片库总占用 `LIB`，首帧判据改为「扫描中且 `LIB` 为零」，
        // 不再看可清理字节。
        let view = try XCTUnwrap(
            strippedSource("PhotoCleanupMVE/Features/S0/S0DeckHomeView.swift")
        )
        let hero = try XCTUnwrap(
            slice(
                view,
                from: "private var heroValue: some View {",
                to: Self.memberClose
            )
        )
        XCTAssertGreaterThanOrEqual(
            occurrences(of: "libraryTotalByteCount == 0", in: hero),
            1
        )
        XCTAssertEqual(occurrences(of: "cleanableByteCount", in: view), 0)
        XCTAssertEqual(
            occurrences(of: "progress.scannedAssetCount == 0", in: hero),
            0,
            "首帧判据退回了按张数判"
        )
        // 首帧未到走「正在扫描…」；key 扫**原文**切片（理由同断言 5）。
        let rawHero = try XCTUnwrap(
            slice(
                try XCTUnwrap(
                    sourceText("PhotoCleanupMVE/Features/S0/S0DeckHomeView.swift")
                ),
                from: "private var heroValue: some View {",
                to: Self.memberClose
            )
        )
        XCTAssertGreaterThanOrEqual(
            occurrences(of: "s0.home.hero.scanning", in: rawHero),
            1
        )

        // 正对照：字节量文本本身是活的。
        XCTAssertFalse(S0ByteCountText.string(forByteCount: 7_900_000_000).isEmpty)
    }

    // MARK: - 断言 7：不自造 chrome

    func testIC148BAssertion07DoesNotInventChromeVocabulary() throws {
        let view = try XCTUnwrap(
            strippedSource("PhotoCleanupMVE/Features/S0/S0DeckHomeView.swift")
        )
        // 圆钮与胶囊各自命中 S1 的 helper。
        XCTAssertGreaterThan(
            occurrences(of: "s1ChromeCircleGlass()", in: view),
            0,
            "人像圆钮没走 S1 的圆钮玻璃 helper"
        )
        XCTAssertGreaterThan(
            occurrences(of: "s1ChromeGlassBackground(", in: view),
            0,
            "跑道胶囊没走 S1 的玻璃 helper"
        )
        // chrome 几何与字号一律引用 S1 的登记常量。
        XCTAssertGreaterThan(occurrences(of: "S1ChromeLayout.", in: view), 0)
        XCTAssertGreaterThan(occurrences(of: "S1ChromeTypography.", in: view), 0)
        XCTAssertGreaterThan(
            occurrences(of: "S1LimitedBannerStyle.", in: view),
            0,
            "受限提示条没有引用 S1 的登记几何"
        )

        // S0 的非视图文件内**不定义**任何新的 chrome 常量族。
        for relativePath in Self.newProductFiles {
            let source = try XCTUnwrap(strippedSource(relativePath))
            for invented in [
                "enum S0ChromeGlass",
                "enum S0ChromeLayout",
                "enum S0ChromeTypography",
                "chromeRowHeight",
                "circleIconPointSize"
            ] {
                XCTAssertEqual(
                    occurrences(of: invented, in: source),
                    0,
                    relativePath + " 自造了 chrome 语汇 " + invented
                )
            }
        }
    }

    // MARK: - 断言 8：宽度分配

    func testIC148CAssertion08SegmentWidthsAlwaysSumToOne() {
        // (a) 全为零。IC-166 裁定 五：v3 下类别全零即 `LIB = 0`（`Σ c.bytes = LIB`），走零 LIB 分支。
        let zero = S0SegmentBarModel.make(
            categories: [settledCategory(bytes: 0)],
            ledgerEntries: [],
            libraryTotalByteCount: 0,
            progress: S0ScanProgress(scannedAssetCount: 10, totalAssetCount: 10),
            isScanning: false
        )
        XCTAssertEqual(zero.totalWidthFraction, 1, accuracy: 0.000_001)
        XCTAssertEqual(zero.segments.count, 1)
        XCTAssertEqual(zero.segments.first?.kind, .rest)

        // (b) 单类别占满。
        let full = S0SegmentBarModel.make(
            categories: [settledCategory(bytes: 48_000_000_000)],
            ledgerEntries: [],
            libraryTotalByteCount: 48_000_000_000,
            progress: S0ScanProgress(scannedAssetCount: 10, totalAssetCount: 10),
            isScanning: false
        )
        XCTAssertEqual(full.totalWidthFraction, 1, accuracy: 0.000_001)
        XCTAssertEqual(
            full.segments.first?.widthFraction ?? 0,
            1,
            accuracy: 0.000_001
        )

        // (c) 多类别 + 未扫。IC-166 裁定 五：加「其余照片」行使 `Σ c.bytes = LIB`
        // （4.8 + 0.56 + 42.64 = 48 GB）。
        let mixed = S0SegmentBarModel.make(
            categories: [
                settledCategory(id: .bigVideo, bytes: 4_800_000_000),
                settledCategory(id: .screenshot, bytes: 560_000_000),
                settledCategory(id: .rest, bytes: 42_640_000_000)
            ],
            ledgerEntries: [],
            libraryTotalByteCount: 48_000_000_000,
            progress: S0ScanProgress(scannedAssetCount: 3, totalAssetCount: 10),
            isScanning: true
        )
        XCTAssertEqual(mixed.totalWidthFraction, 1, accuracy: 0.000_001)
        // 未扫段 = 1 − 已扫占比。
        let unscanned = mixed.segments.first { $0.kind == .unscanned }
        XCTAssertEqual(unscanned?.widthFraction ?? 0, 0.7, accuracy: 0.000_001)
        // 类别段宽 = c.bytes / LIB × 已扫占比（v3 张数进度缩放）：0.1 × 0.3、
        // 0.56／48 × 0.3、42.64／48 × 0.3。
        let bigVideo = mixed.segments.first { $0.kind == .category(.bigVideo) }
        XCTAssertEqual(bigVideo?.widthFraction ?? 0, 0.03, accuracy: 0.000_001)
        let screenshot = mixed.segments.first { $0.kind == .category(.screenshot) }
        XCTAssertEqual(screenshot?.widthFraction ?? 0, 0.0035, accuracy: 0.000_001)
        let rest = mixed.segments.first { $0.kind == .category(.rest) }
        XCTAssertEqual(rest?.widthFraction ?? 0, 0.2665, accuracy: 0.000_001)

        // `LIB` 为零：整条归其余照片，总和仍为 1。
        let noLibrary = S0SegmentBarModel.make(
            categories: [settledCategory(bytes: 1_000)],
            ledgerEntries: [],
            libraryTotalByteCount: 0,
            progress: S0ScanProgress(),
            isScanning: false
        )
        XCTAssertEqual(noLibrary.totalWidthFraction, 1, accuracy: 0.000_001)

        // (e) IC-166 裁定 五：原「各类别之和超过 LIB 时夹到 1」随 v3 归属去重作废，改为扫描中缩放——
        // `Σ c.bytes = LIB`、已扫 3／10：首段占比大于已扫占比也不吃掉后面的段（旧预算式在此只剩
        // 首段 0.3 + 未扫 0.7），各段 = 占比 × 0.3，非零 LIB 时没有兜底段。
        let scaled = S0SegmentBarModel.make(
            categories: [
                settledCategory(id: .bigVideo, bytes: 40_000_000_000),
                settledCategory(id: .similar, bytes: 8_000_000_000)
            ],
            ledgerEntries: [],
            libraryTotalByteCount: 48_000_000_000,
            progress: S0ScanProgress(scannedAssetCount: 3, totalAssetCount: 10),
            isScanning: true
        )
        XCTAssertEqual(scaled.totalWidthFraction, 1, accuracy: 0.000_001)
        XCTAssertEqual(
            scaled.segments.first { $0.kind == .category(.bigVideo) }?.widthFraction ?? 0,
            0.25,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            scaled.segments.first { $0.kind == .category(.similar) }?.widthFraction ?? 0,
            0.05,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            scaled.segments.first { $0.kind == .unscanned }?.widthFraction ?? 0,
            0.7,
            accuracy: 0.000_001
        )
        XCTAssertEqual(scaled.segments.filter { $0.kind == .rest }.count, 0)
        for segment in scaled.segments {
            XCTAssertGreaterThanOrEqual(segment.widthFraction, 0)
        }
    }

    // MARK: - 断言 9：斜纹

    func testIC148CAssertion09HatchOnlyOnPendingSegments() {
        let ledger = [
            S0LedgerEntry(
                categoryID: .bigVideo,
                byteCount: 2_400_000_000,
                committedAt: Date(timeIntervalSince1970: 1_789_344_000),
                availableCapacityBaseline: 6_000_000_000
            )
        ]
        let model = S0SegmentBarModel.make(
            categories: [
                settledCategory(id: .bigVideo, bytes: 4_800_000_000),
                settledCategory(id: .screenshot, bytes: 560_000_000)
            ],
            ledgerEntries: ledger,
            libraryTotalByteCount: 48_000_000_000,
            progress: S0ScanProgress(scannedAssetCount: 10, totalAssetCount: 10),
            isScanning: false
        )
        XCTAssertEqual(model.hatchedSegmentCount, 1, "斜纹画到了不该画的段上")
        let bigVideo = model.segments.first { $0.kind == .category(.bigVideo) }
        // 斜纹宽 = 等待清空(c) / LIB = 2.4 / 48 = 0.05。
        XCTAssertEqual(
            bigVideo?.hatchFraction ?? 0,
            0.05,
            accuracy: 0.000_001
        )
        let screenshot = model.segments.first {
            $0.kind == .category(.screenshot)
        }
        XCTAssertEqual(screenshot?.hatchFraction ?? -1, 0, accuracy: 0.000_001)

        // `LG=空`：零个段带斜纹。
        let clean = S0SegmentBarModel.make(
            categories: [settledCategory(id: .bigVideo, bytes: 4_800_000_000)],
            ledgerEntries: [],
            libraryTotalByteCount: 48_000_000_000,
            progress: S0ScanProgress(scannedAssetCount: 10, totalAssetCount: 10),
            isScanning: false
        )
        XCTAssertEqual(clean.hatchedSegmentCount, 0)

        // 斜纹不超过所在段宽。
        for segment in model.segments {
            XCTAssertLessThanOrEqual(
                segment.hatchFraction,
                segment.widthFraction + 0.000_001
            )
        }
    }

    // MARK: - 断言 10：文案门禁

    func testIC148CAssertion10CatalogHasExactlyThirtyTwoS0Keys() throws {
        let catalog = try loadCatalogValues()
        let catalogS0Keys = Set(catalog.keys.filter { $0.hasPrefix("s0.") })
        // IC-156 C：32 → 37；IC-157 B：→ 38；IC-165 C：→ 39；IC-166 B：S0-3 副句一条 → 40。
        // IC-168 E：类别页进入失败提示一条 → 41。
        XCTAssertEqual(catalogS0Keys.count, 41)

        // IC-165 C：与 IC-147 断言 11 同一份四文件名单（`s0.category.*` 五条在文本 helper 里）。
        var referenced: Set<String> = []
        for relativePath in [
            "PhotoCleanupMVE/Features/S0/S0DeckHomeView.swift",
            "PhotoCleanupMVE/Features/S0/S0DeckCategoryPageView.swift",
            "PhotoCleanupMVE/Features/S0/S0TabContainer.swift",
            "PhotoCleanupMVE/Features/S0/S0Text.swift"
        ] {
            let source = try XCTUnwrap(sourceText(relativePath))
            referenced.formUnion(localizationKeys(in: source))
        }
        // 互为子集（s0. 部分）。
        XCTAssertEqual(referenced.filter { $0.hasPrefix("s0.") }, catalogS0Keys)

        // 原「两条图例 key」一段随 IC-165 C 删去：SPEC-S0 v3 作废两条图例 key（「其余照片」改
        // `s0.category.rest`，未扫段无图例）。
    }

    // MARK: - 断言 11：`VF` 不自造（裁定 3）

    func testIC148CAssertion11NeverAdvancesOrResetsVerification() throws {
        // S0 的非视图文件内不出现任何推进或复位 `VF` 的调用。
        for relativePath in Self.newProductFiles {
            let source = try XCTUnwrap(strippedSource(relativePath))
            for call in [
                "beginVerification",
                "setVerification",
                "machine.handle(",
                "verificationPassed",
                "verificationFailed"
            ] {
                XCTAssertEqual(
                    occurrences(of: call, in: source),
                    0,
                    relativePath + " 出现了推进／复位 VF 的调用 " + call
                )
            }
        }

        // 首页的**行为**调用点与 IC-147 交付时完全相同（IC-165 C：首页为 `S0DeckHomeView`）：
        // `handle(` 4 处 + `beginVerification` 1 处 + `ingest` 1 处 = 6。
        //
        // 任务卡断言 11 原文要求「`machine.` 调用点数量完全相同」，但同一张卡的
        // 子项 B 第 6 条又要求新画受限提示条（必须读 `lim`），子项 C 又要求分段条
        // （必须读账本与照片库总占用）。两条不可同时满足，故此处钉**行为**调用点
        // 不变，并在自验报告逐项列出只读访问的增减。
        let view = try XCTUnwrap(
            strippedSource("PhotoCleanupMVE/Features/S0/S0DeckHomeView.swift")
        )
        XCTAssertEqual(occurrences(of: "machine.handle(", in: view), 4)
        XCTAssertEqual(occurrences(of: "machine.beginVerification", in: view), 1)
        XCTAssertEqual(occurrences(of: "machine.ingest", in: view), 1)
        // 不含任何定时器／延时——「已通过」读数不许自己消失。
        for timer in ["Timer", "asyncAfter", "sleep("] {
            XCTAssertEqual(
                occurrences(of: timer, in: view),
                0,
                "视图里出现了可能让 VF 读数自行消失的 " + timer
            )
        }
        // IC-165 C（裁定 五）：`withAnimation(` 恰一处，且是展开／收起那一次 spring——
        // 实参取登记的两值，不是核对流程的动画。
        XCTAssertEqual(occurrences(of: "withAnimation(", in: view), 1)
        let animation = try XCTUnwrap(
            slice(view, from: "withAnimation(", to: ") {")
        )
        XCTAssertGreaterThan(occurrences(of: "expandAnimationResponse", in: animation), 0)
        XCTAssertGreaterThan(occurrences(of: "expandAnimationDamping", in: animation), 0)
    }

    // 断言 12（`testIC148DAssertion12SortsByBytesAndSinksEmptyCategories`）随 IC-165 C 删去：
    // v2 类别行的排序口径随旧首页退役；卡片叠的出卡与次序由 IC162 与 IC147 断言 8 钉住。

    // MARK: - 断言 13：可点外观与第 170 条裁定 1 一致

    func testIC148DAssertion13TappableAppearanceMatchesClickMatrix() {
        let counting = countingCategory(bytes: 1_000)
        let awaiting = awaitingCategory()

        // IC-165 C：v2 类别行的外观口径（压暗、「—」、进入指示）随旧首页退役，只留行为层一半。
        // 裁定 1：S0-1 下 `.counting` 可点。
        // 与行为层同口径：S0-1 下机器侧也是 counting 可点、awaiting 不可点。
        let machine = S0StateMachine()
        machine.handle(.applicationOpened)
        machine.ingest(
            S0CleanupSnapshot(
                progress: S0ScanProgress(
                    scannedAssetCount: 3_000,
                    totalAssetCount: 12_000
                ),
                cleanableAssetCount: 26,
                cleanableByteCount: 1_700_000_000,
                libraryTotalByteCount: 48_000_000_000,
                categories: [counting, awaiting]
            )
        )
        XCTAssertEqual(machine.state, .scanning)
        XCTAssertTrue(machine.acceptsCategoryRowTap(counting.id))
        XCTAssertFalse(machine.acceptsCategoryRowTap(awaiting.id))
    }

    // MARK: - 断言 14：占位不造假

    func testIC148DAssertion14CoverSlotIsEmptyNotFaked() throws {
        // 视图文件内不出现任何图片资源名或取图调用（取图只在 `Features/Shared/`）。
        //
        // 扫的是**原文**不是剔过的源码：资源名与扩展名都写在字符串字面量里，
        // 而 `strippedSource` 会把字面量内容连同引号一起剔掉——拿剔过的源码去找
        // `Image("` 或 `.png` 恒为 0，断言会**空转通过**（#295 上就是这样过的，
        // 过得没有意义）。
        for relativePath in Self.viewFiles {
            let source = try XCTUnwrap(sourceText(relativePath))
            for faking in [
                "Image(\"",
                "UIImage(named",
                "requestImage",
                "PHImageManager",
                "placeholder.png",
                ".jpg",
                ".png"
            ] {
                XCTAssertEqual(
                    occurrences(of: faking, in: source),
                    0,
                    relativePath + " 封面位造假了：" + faking
                )
            }
        }
        // 正对照：同一套 needle 在**确实放图**的既有视图上命中非零，
        // 证明这组扫描不是空转。
        let thumbnail = try XCTUnwrap(
            sourceText("PhotoCleanupMVE/Features/Shared/ThumbnailView.swift")
        )
        XCTAssertGreaterThan(
            occurrences(of: "Image(", in: thumbnail),
            0,
            "正对照失效：缩略图视图里都没有 Image("
        )
        // 数据模型里的 `coverAssetID`：生产者已在（IC-155 裁定 一）。按声明行
        // 计数——裸符号在 init 形参与赋值处还会各出现一次。
        let snapshot = try XCTUnwrap(
            strippedSource("PhotoCleanupMVE/Core/S0StateMachine.swift")
        )
        XCTAssertEqual(
            occurrences(of: "let coverAssetID: String?", in: snapshot),
            1
        )

        // 原「类别行封面位空槽」一段随 IC-165 C 删去（类别行退役）；卡片叠封面在
        // `Features/Shared/S0DeckCoverView.swift`，由 IC-165 断言 3 钉「先框后裁、命中区」。
    }

    // MARK: - 夹具

    private func settledCategory(
        id: S0CategoryIdentifier = .bigVideo,
        bytes: Int64
    ) -> S0CategorySnapshot {
        S0CategorySnapshot(
            id: id,
            candidateCount: bytes > 0 ? 1 : 0,
            candidateByteCount: bytes,
            recognition: .settled
        )
    }

    private func countingCategory(bytes: Int64) -> S0CategorySnapshot {
        S0CategorySnapshot(
            id: .screenshot,
            candidateCount: 1,
            candidateByteCount: bytes,
            recognition: .counting
        )
    }

    private func awaitingCategory() -> S0CategorySnapshot {
        S0CategorySnapshot(
            id: .duplicate,
            candidateCount: 1,
            candidateByteCount: 0,
            recognition: .awaitingScanCompletion
        )
    }

    private func machineInFailedState() -> S0StateMachine {
        let machine = S0StateMachine()
        machine.handle(.scanFailed(.read))
        return machine
    }

    private func assertColor(
        _ color: Color,
        red: CGFloat,
        green: CGFloat,
        blue: CGFloat,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        var resolvedRed: CGFloat = 0
        var resolvedGreen: CGFloat = 0
        var resolvedBlue: CGFloat = 0
        var alpha: CGFloat = 0
        XCTAssertTrue(
            UIColor(color).getRed(
                &resolvedRed,
                green: &resolvedGreen,
                blue: &resolvedBlue,
                alpha: &alpha
            ),
            file: file,
            line: line
        )
        XCTAssertEqual(resolvedRed * 255, red, accuracy: 0.6, file: file, line: line)
        XCTAssertEqual(
            resolvedGreen * 255,
            green,
            accuracy: 0.6,
            file: file,
            line: line
        )
        XCTAssertEqual(
            resolvedBlue * 255,
            blue,
            accuracy: 0.6,
            file: file,
            line: line
        )
        XCTAssertEqual(alpha, 1, accuracy: 0.000_001, file: file, line: line)
    }

    // MARK: - 源码与目录读取（与 IC-146／IC-147 同口径）

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

    /// 取出源码里所有**独立的**数值字面量。
    ///
    /// 「独立」= 紧邻的前后字符都不是标识符字符，因此 `S0HomeMetrics` 里的
    /// `0` 不会被算成一个数（它前面是字母 `S`）。数字内允许小数点与前导负号。
    private func numericLiterals(in source: String) -> Set<String> {
        var literals: Set<String> = []
        let characters = Array(source)
        var index = 0
        while index < characters.count {
            guard characters[index].isNumber else {
                index += 1
                continue
            }
            // 起点必须不紧跟标识符字符。
            let previous = index > 0 ? characters[index - 1] : " "
            if isIdentifierCharacter(previous) {
                // 这串数字是标识符的一部分（如 `S0HomeMetrics` 里的 `0`）。
                // 跳过整个标识符——**判据必须含数字**，否则当前字符是数字时
                // 指针不前进，循环不终止（会把测试挂死）。
                while index < characters.count,
                      isIdentifierBodyCharacter(characters[index]) {
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
            // 终点后面若紧跟字母，说明这是标识符的一部分，跳过。
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

    /// 标识符的**起始**字符：字母或下划线（数字不能开头）。
    private func isIdentifierCharacter(_ character: Character) -> Bool {
        character.isLetter || character == "_"
    }

    /// 标识符的**内部**字符：字母、数字或下划线。
    private func isIdentifierBodyCharacter(_ character: Character) -> Bool {
        character.isLetter || character.isNumber || character == "_"
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

    /// 与 IC-147 同口径：允许 `L10n.text(` 与引号之间有换行与缩进。
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
