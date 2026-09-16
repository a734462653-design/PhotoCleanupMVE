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
final class IC148S0VisualTests: XCTestCase {

    /// IC-148 新增的产品文件。第四个 `Services/S0RecentPhotoAmbientLoader.swift`
    /// 随 IC-151 裁定 五 整条删除（氛围底改固定色，不再取图），从名单移除——
    /// 文件不存在则 `strippedSource` 解不开，断言 2 的循环会直接失败。
    private static let newProductFiles = [
        "PhotoCleanupMVE/Features/S0/S0HomeMetrics.swift",
        "PhotoCleanupMVE/Features/S0/S0SegmentBar.swift",
        "PhotoCleanupMVE/Features/S0/S0CategoryRow.swift"
    ]

    /// 三个**视图**文件（PhotoKit／造假／文案扫描的扫描面）。`S0View.swift` 是
    /// IC-147 建的、本卡改版式的那一个，也算在内。
    private static let viewFiles = [
        "PhotoCleanupMVE/Features/S0/S0View.swift",
        "PhotoCleanupMVE/Features/S0/S0SegmentBar.swift",
        "PhotoCleanupMVE/Features/S0/S0CategoryRow.swift"
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
    /// 「三个视图体内」）。逐个列出六个视图／布局类型的声明锚点。
    private static let viewBodyAnchors: [(path: String, anchor: String)] = [
        (
            "PhotoCleanupMVE/Features/S0/S0View.swift",
            "struct S0View: View {"
        ),
        (
            "PhotoCleanupMVE/Features/S0/S0View.swift",
            "struct S0GlassSurface<S: InsettableShape>: ViewModifier {"
        ),
        (
            "PhotoCleanupMVE/Features/S0/S0SegmentBar.swift",
            "struct S0SegmentBarView: View {"
        ),
        (
            "PhotoCleanupMVE/Features/S0/S0SegmentBar.swift",
            "struct S0SegmentHatch: View {"
        ),
        (
            "PhotoCleanupMVE/Features/S0/S0SegmentBar.swift",
            "struct S0SegmentLegendView: View {"
        ),
        (
            "PhotoCleanupMVE/Features/S0/S0CategoryRow.swift",
            "struct S0CategoryRowView: View {"
        )
    ]

    // MARK: - 断言 1：52 个登记常量与 SPEC-S0 第十四节第 2 部分逐条对账

    func testIC148AAssertion01RegistryMatchesSpecSection14() throws {
        // 玻璃卡（8）。IC-151 裁定 三：`cardBlurRadius` 30 与 `cardSaturation`
        // 1.70 两个磨砂值随氛围底改固定色作废（卡后面没有可折射的对象了），
        // 换成 `cardFillTopOpacity` 0.10 与 `cardFillBottomOpacity` 0.045
        // 两个填充值；段内仍 8 个、全表仍 52 个。
        XCTAssertEqual(
            S0HomeMetrics.cardFillTopOpacity,
            0.10,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            S0HomeMetrics.cardFillBottomOpacity,
            0.045,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            S0HomeMetrics.cardInnerTopOpacity,
            0.42,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            S0HomeMetrics.cardInnerBottomOpacity,
            0.06,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            S0HomeMetrics.cardOuterRingOpacity,
            0.10,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            S0HomeMetrics.cardShadowOpacity,
            0.42,
            accuracy: 0.000_001
        )
        XCTAssertEqual(S0HomeMetrics.cardShadowRadius, 40, accuracy: 0.000_001)
        XCTAssertEqual(S0HomeMetrics.cardShadowYOffset, 14, accuracy: 0.000_001)

        // 分段条（14）
        XCTAssertEqual(S0HomeMetrics.segmentBarHeight, 8, accuracy: 0.000_001)
        XCTAssertEqual(
            S0HomeMetrics.segmentBarCornerRadius,
            4,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            S0HomeMetrics.segmentBarItemSpacing,
            3,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            S0HomeMetrics.segmentBarInnerHighlightOpacity,
            0.35,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            S0HomeMetrics.segmentHatchAngleDegrees,
            135,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            S0HomeMetrics.segmentHatchStripeWidth,
            3,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            S0HomeMetrics.segmentHatchGapWidth,
            3,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            S0HomeMetrics.segmentRestOpacity,
            0.22,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            S0HomeMetrics.segmentUnscannedOpacity,
            0.10,
            accuracy: 0.000_001
        )
        XCTAssertEqual(S0HomeMetrics.legendDotSide, 8, accuracy: 0.000_001)
        XCTAssertEqual(
            S0HomeMetrics.legendDotCornerRadius,
            2.5,
            accuracy: 0.000_001
        )
        XCTAssertEqual(S0HomeMetrics.legendFontSize, 12, accuracy: 0.000_001)
        XCTAssertEqual(
            S0HomeMetrics.legendItemSpacingH,
            14,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            S0HomeMetrics.legendItemSpacingV,
            6,
            accuracy: 0.000_001
        )

        // 等待清空行（7）
        XCTAssertEqual(S0HomeMetrics.pendingRowHeight, 40, accuracy: 0.000_001)
        XCTAssertEqual(
            S0HomeMetrics.pendingRowCornerRadius,
            20,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            S0HomeMetrics.pendingRowLeadingInset,
            14,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            S0HomeMetrics.pendingRowFontSize,
            13,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            S0HomeMetrics.pendingButtonHeight,
            28,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            S0HomeMetrics.pendingButtonCornerRadius,
            14,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            S0HomeMetrics.pendingButtonFontSize,
            12.5,
            accuracy: 0.000_001
        )

        // 类别行（12）
        XCTAssertEqual(
            S0HomeMetrics.categoryRowHeight,
            78,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            S0HomeMetrics.categoryRowCornerRadius,
            24,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            S0HomeMetrics.categoryRowSpacing,
            8,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            S0HomeMetrics.categoryCoverSide,
            60,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            S0HomeMetrics.categoryCoverCornerRadius,
            16,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            S0HomeMetrics.categoryColorDotSide,
            8,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            S0HomeMetrics.categoryNameFontSize,
            17,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            S0HomeMetrics.categorySubFontSize,
            12.5,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            S0HomeMetrics.categorySubOpacity,
            0.52,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            S0HomeMetrics.categoryValueFontSize,
            24,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            S0HomeMetrics.categoryValueUnitFontSize,
            12,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            S0HomeMetrics.categoryDisabledOpacity,
            0.45,
            accuracy: 0.000_001
        )

        // hero（6）
        XCTAssertEqual(
            S0HomeMetrics.heroLabelFontSize,
            15,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            S0HomeMetrics.heroValueFontSize,
            96,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            S0HomeMetrics.heroValueLetterSpacing,
            -5.5,
            accuracy: 0.000_001
        )
        XCTAssertEqual(S0HomeMetrics.heroUnitFontSize, 26, accuracy: 0.000_001)
        XCTAssertEqual(S0HomeMetrics.heroSubFontSize, 14, accuracy: 0.000_001)
        XCTAssertEqual(S0HomeMetrics.heroSubOpacity, 0.50, accuracy: 0.000_001)

        // 类别色（5）：逐个解析 RGB 与规格的十六进制比对。
        assertColor(S0HomeMetrics.colorBigVideo, red: 110, green: 155, blue: 255)
        assertColor(S0HomeMetrics.colorSimilar, red: 63, green: 209, blue: 176)
        assertColor(S0HomeMetrics.colorScreenshot, red: 255, green: 181, blue: 74)
        assertColor(
            S0HomeMetrics.colorScreenRecording,
            red: 200,
            green: 155,
            blue: 255
        )
        assertColor(S0HomeMetrics.colorDuplicate, red: 255, green: 143, blue: 163)

        // 恰 52 个常量，且每个定义处都写明出处。
        let metrics = try XCTUnwrap(
            sourceText("PhotoCleanupMVE/Features/S0/S0HomeMetrics.swift")
        )
        let body = try XCTUnwrap(
            slice(metrics, from: "enum S0HomeMetrics {", to: "\n}\n")
        )
        XCTAssertEqual(
            occurrences(of: "\n    static let ", in: body),
            52,
            "S0HomeMetrics 的登记常量不是恰 52 个"
        )
        XCTAssertGreaterThanOrEqual(
            occurrences(of: "取值出处：", in: body),
            52
        )
        // IC-151：只有玻璃卡那两个新值改指 Decision_log 与 IC-151 卡
        // （裁定 四：SPEC-S0 v2 未晋级，新值不得冒充 v1 的登记值），
        // 其余 50 个仍指 v1 第十四节。
        XCTAssertEqual(
            occurrences(of: "取值出处：SPEC-S0 v1 第十四节", in: body),
            50
        )
        XCTAssertEqual(
            occurrences(of: "取值出处：Decision_log 第 175／176 条", in: body),
            2
        )
        // 两个磨砂值删干净，不留死值（陷阱 12 的同类）。
        XCTAssertEqual(occurrences(of: "cardBlurRadius", in: body), 0)
        XCTAssertEqual(occurrences(of: "cardSaturation", in: body), 0)
        // `S0Ambient` 的十个值不在此登记（裁定 丙：引用 S2AmbientMetrics）。
        XCTAssertEqual(occurrences(of: "ambientBlurRadius", in: body), 0)
        XCTAssertEqual(occurrences(of: "ambientBaseColor", in: body), 0)
        // 类别页网格与组视图（批次 5.2）同样不在此登记。
        XCTAssertEqual(occurrences(of: "gridColumns", in: body), 0)
        XCTAssertEqual(occurrences(of: "groupCardCornerRadius", in: body), 0)
    }

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
        for relativePath in Self.newProductFiles + [
            "PhotoCleanupMVE/Features/S0/S0View.swift"
        ] {
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
            strippedSource("PhotoCleanupMVE/Features/S0/S0HomeMetrics.swift")
        )
        XCTAssertGreaterThanOrEqual(
            occurrences(of: "enum S0HomeMetrics", in: metrics),
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
        // 五个类别色同样与 trait 无关。
        for color in [
            S0HomeMetrics.colorBigVideo,
            S0HomeMetrics.colorSimilar,
            S0HomeMetrics.colorScreenshot,
            S0HomeMetrics.colorScreenRecording,
            S0HomeMetrics.colorDuplicate
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
    /// 取值**；登记取值一律经 `S0HomeMetrics`。
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
                occurrences(of: "S0HomeMetrics.", in: body),
                0,
                anchor + " 一处登记值都没引用，扫描口径可疑"
            )
        }

        // 视图体之外唯一的非允许字面量是「写在规格正文而非登记表」的那一个
        // （`S0CategoryRowProse.awaitingRecognitionOpacity` = 0.55，
        // SPEC-S0 v1 第三节第 1 部分「整行降为 55% 不透明」）。钉死它只有这一个，
        // 再多一个就是实现自填。
        let rowFile = try XCTUnwrap(
            strippedSource("PhotoCleanupMVE/Features/S0/S0CategoryRow.swift")
        )
        XCTAssertEqual(
            numericLiterals(in: rowFile).subtracting(allowed),
            ["0.55"]
        )
        XCTAssertEqual(
            S0CategoryRowProse.awaitingRecognitionOpacity,
            0.55,
            accuracy: 0.000_001
        )
        for relativePath in [
            "PhotoCleanupMVE/Features/S0/S0View.swift",
            "PhotoCleanupMVE/Features/S0/S0SegmentBar.swift"
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
        // `Features/S0/` 四个文件 + 登记表：PhotoKit 零命中。
        for relativePath in Self.viewFiles + [
            "PhotoCleanupMVE/Features/S0/S0HomeMetrics.swift",
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

        // 复用：S0 视图引用 S2 侧的氛围底视图，且不自造配方。
        let view = try XCTUnwrap(
            strippedSource("PhotoCleanupMVE/Features/S0/S0View.swift")
        )
        // IC-151 子项 C／D：氛围底视图改无参，读数类型随取图链整条删除。
        XCTAssertGreaterThan(
            occurrences(of: "S2AmbientBackdropView()", in: view),
            0
        )
        XCTAssertEqual(
            occurrences(of: "S2AmbientBackdropReadout", in: view),
            0
        )
        // 原有的「`S2AmbientMetrics.` ≥ 1」一条随子项 D 删除：卡下不再铺幕底色
        // 是本卡要达成的结果之一（断言 12），该条在正确实现后必然失效
        // ——「某计数不变」类断言先核可用性（惯例 37）。
        XCTAssertEqual(
            occurrences(of: "S2AmbientBackdropStore", in: view),
            0
        )
    }

    // MARK: - 断言 5：四态显示元素清单逐条（源码扫描 + 夹具）

    /// **源码扫描 + 夹具驱动，真机未覆盖**：SwiftUI 的 `@ViewBuilder` 分支不能
    /// 在单元测试里渲染比对，故此处钉的是「显隐判据写对了没有」加上机器侧的
    /// 显隐谓词。真机逐条看由 H71 第 3 条兜底。
    func testIC148BAssertion05FourStateElementLists() throws {
        let view = try XCTUnwrap(
            strippedSource("PhotoCleanupMVE/Features/S0/S0View.swift")
        )

        // S0-4：hero 数值、分段条、类别行三不显示。
        let hero = try XCTUnwrap(
            slice(view, from: "private var heroCard: some View {", to: "\n    }")
        )
        XCTAssertGreaterThan(occurrences(of: "case .failed:", in: hero), 0)
        XCTAssertGreaterThan(occurrences(of: "EmptyView()", in: hero), 0)
        XCTAssertGreaterThan(
            occurrences(of: "if homeState != .failed {", in: view),
            0,
            "分段条没有按 S0-4 收起"
        )
        XCTAssertGreaterThan(
            occurrences(of: "if machine.showsCategoryRows {", in: view),
            0,
            "类别行没有走机器侧的显隐谓词"
        )
        XCTAssertGreaterThan(
            occurrences(of: "if homeState == .failed {", in: view),
            0,
            "失败说明没有只在 S0-4 出现"
        )

        // 机器侧谓词（IC-147 交付，本卡只复核口径没被改坏）。
        let failed = machineInFailedState()
        XCTAssertFalse(failed.showsCategoryRows)
        XCTAssertFalse(failed.showsPendingClearanceRow)

        // S0-3：没有类别段可进，但有「去逐张整理」入口。
        //
        // **文案 key 一律扫原文**：key 写在字符串字面量里，而 `strippedSource`
        // 把字面量内容整个剔掉，拿剔过的源码找 key 恒为 0——#295 就是这样
        // 假红的。凡 needle 本身是 key 或中文措辞，一律用 `sourceText`。
        let rawView = try XCTUnwrap(
            sourceText("PhotoCleanupMVE/Features/S0/S0View.swift")
        )
        XCTAssertGreaterThan(
            occurrences(of: "s0.home.hero.empty.action", in: rawView),
            0
        )

        // S0-1：未扫描段 + 统计中副行。
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
        XCTAssertGreaterThan(
            occurrences(of: "s0.home.category.counting", in: rawView),
            0
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
        let view = try XCTUnwrap(
            strippedSource("PhotoCleanupMVE/Features/S0/S0View.swift")
        )
        let hero = try XCTUnwrap(
            slice(
                view,
                from: "private var scanningHero: some View {",
                to: "\n    }"
            )
        )
        // 判据是**可清理字节为零**，不是已扫张数。
        XCTAssertGreaterThan(
            occurrences(of: "machine.snapshot.cleanableByteCount == 0", in: hero),
            0
        )
        XCTAssertEqual(
            occurrences(of: "progress.scannedAssetCount == 0", in: hero),
            0,
            "首帧判据退回了按张数判"
        )
        // 首帧未到走「正在扫描…」；到了才走字节量大字。
        // key 扫**原文**切片（理由同断言 5）。
        let rawHero = try XCTUnwrap(
            slice(
                try XCTUnwrap(
                    sourceText("PhotoCleanupMVE/Features/S0/S0View.swift")
                ),
                from: "private var scanningHero: some View {",
                to: Self.memberClose
            )
        )
        XCTAssertGreaterThan(
            occurrences(of: "s0.home.hero.scanning", in: rawHero),
            0
        )
        XCTAssertGreaterThan(occurrences(of: "heroValue(", in: hero), 0)

        // 正对照：字节量文本本身是活的。
        XCTAssertFalse(S0ByteCountText.string(forByteCount: 7_900_000_000).isEmpty)
    }

    // MARK: - 断言 7：不自造 chrome

    func testIC148BAssertion07DoesNotInventChromeVocabulary() throws {
        let view = try XCTUnwrap(
            strippedSource("PhotoCleanupMVE/Features/S0/S0View.swift")
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

        // 本卡四个新文件内**不定义**任何新的 chrome 常量族。
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
        // (a) 全为零。
        let zero = S0SegmentBarModel.make(
            categories: [settledCategory(bytes: 0)],
            ledgerEntries: [],
            libraryTotalByteCount: 48_000_000_000,
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

        // (c) 多类别 + 未扫。
        let mixed = S0SegmentBarModel.make(
            categories: [
                settledCategory(id: .bigVideo, bytes: 4_800_000_000),
                settledCategory(id: .screenshot, bytes: 560_000_000)
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
        // 类别段宽 = c.bytes / LIB。
        let bigVideo = mixed.segments.first { $0.kind == .category(.bigVideo) }
        XCTAssertEqual(bigVideo?.widthFraction ?? 0, 0.1, accuracy: 0.000_001)

        // `LIB` 为零：整条归其余照片，总和仍为 1。
        let noLibrary = S0SegmentBarModel.make(
            categories: [settledCategory(bytes: 1_000)],
            ledgerEntries: [],
            libraryTotalByteCount: 0,
            progress: S0ScanProgress(),
            isScanning: false
        )
        XCTAssertEqual(noLibrary.totalWidthFraction, 1, accuracy: 0.000_001)

        // 各类别之和超过 LIB（`c.bytes` 不去重）时仍夹到 1，其余段不为负。
        let overflow = S0SegmentBarModel.make(
            categories: [
                settledCategory(id: .bigVideo, bytes: 40_000_000_000),
                settledCategory(id: .similar, bytes: 40_000_000_000)
            ],
            ledgerEntries: [],
            libraryTotalByteCount: 48_000_000_000,
            progress: S0ScanProgress(scannedAssetCount: 10, totalAssetCount: 10),
            isScanning: false
        )
        XCTAssertEqual(overflow.totalWidthFraction, 1, accuracy: 0.000_001)
        for segment in overflow.segments {
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
        XCTAssertEqual(catalogS0Keys.count, 32)

        var referenced: Set<String> = []
        for relativePath in Self.viewFiles + [
            "PhotoCleanupMVE/Features/S0/S0TabContainer.swift"
        ] {
            let source = try XCTUnwrap(sourceText(relativePath))
            referenced.formUnion(localizationKeys(in: source))
        }
        // 互为子集（s0. 部分）。
        XCTAssertEqual(referenced.filter { $0.hasPrefix("s0.") }, catalogS0Keys)

        // 新增两条各被引用 ≥ 1 次，且取值与 SPEC-S0 第十四节第 3 部分一致。
        let legend = try XCTUnwrap(
            sourceText("PhotoCleanupMVE/Features/S0/S0SegmentBar.swift")
        )
        XCTAssertGreaterThanOrEqual(
            occurrences(of: "s0.home.legend.rest", in: legend),
            1
        )
        XCTAssertGreaterThanOrEqual(
            occurrences(of: "s0.home.legend.unscanned", in: legend),
            1
        )
        XCTAssertEqual(catalog["s0.home.legend.rest"], "其余照片")
        XCTAssertEqual(catalog["s0.home.legend.unscanned"], "未扫描")
    }

    // MARK: - 断言 11：`VF` 不自造（裁定 3）

    func testIC148CAssertion11NeverAdvancesOrResetsVerification() throws {
        // 本卡三个**新**文件内不出现任何推进或复位 `VF` 的调用。
        for relativePath in [
            "PhotoCleanupMVE/Features/S0/S0HomeMetrics.swift",
            "PhotoCleanupMVE/Features/S0/S0SegmentBar.swift",
            "PhotoCleanupMVE/Features/S0/S0CategoryRow.swift"
        ] {
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

        // `S0View` 的**行为**调用点与 IC-147 交付时完全相同：
        // `handle(` 4 处 + `beginVerification` 1 处 + `ingest` 1 处 = 6。
        //
        // 任务卡断言 11 原文要求「`machine.` 调用点数量完全相同」，但同一张卡的
        // 子项 B 第 6 条又要求新画受限提示条（必须读 `lim`），子项 C 又要求分段条
        // （必须读账本与照片库总占用）。两条不可同时满足，故此处钉**行为**调用点
        // 不变，并在自验报告逐项列出只读访问的增减。
        let view = try XCTUnwrap(
            strippedSource("PhotoCleanupMVE/Features/S0/S0View.swift")
        )
        XCTAssertEqual(occurrences(of: "machine.handle(", in: view), 4)
        XCTAssertEqual(occurrences(of: "machine.beginVerification", in: view), 1)
        XCTAssertEqual(occurrences(of: "machine.ingest", in: view), 1)
        // 不含任何定时器／延时——「已通过」读数不许自己消失。
        for timer in ["Timer", "asyncAfter", "sleep(", "withAnimation("] {
            XCTAssertEqual(
                occurrences(of: timer, in: view),
                0,
                "视图里出现了可能让 VF 读数自行消失的 " + timer
            )
        }
    }

    // MARK: - 断言 12：排序与沉底

    func testIC148DAssertion12SortsByBytesAndSinksEmptyCategories() {
        let shuffled = [
            settledCategory(id: .screenshot, bytes: 560_000_000),
            settledCategory(id: .duplicate, bytes: 0),
            settledCategory(id: .bigVideo, bytes: 4_800_000_000),
            settledCategory(id: .similar, bytes: 0),
            settledCategory(id: .screenRecording, bytes: 1_920_000_000)
        ]
        let sorted = S0CategoryRowPresentation.sorted(shuffled)
        XCTAssertEqual(
            sorted.map(\.id),
            [.bigVideo, .screenRecording, .screenshot, .duplicate, .similar]
        )
        // 全部无项目的沉在末尾。
        let tail = sorted.suffix(2)
        XCTAssertTrue(tail.allSatisfy { !$0.hasItems })
        XCTAssertTrue(sorted.prefix(3).allSatisfy(\.hasItems))
    }

    // MARK: - 断言 13：可点外观与第 170 条裁定 1 一致

    func testIC148DAssertion13TappableAppearanceMatchesClickMatrix() {
        let counting = countingCategory(bytes: 1_000)
        let awaiting = awaitingCategory()
        let empty = settledCategory(bytes: 0)

        // 裁定 1：S0-1 下 `.counting` 可点 ⟹ 不压暗、有进入指示。
        XCTAssertEqual(
            S0CategoryRowPresentation.rowOpacity(for: counting),
            1,
            accuracy: 0.000_001
        )
        XCTAssertTrue(S0CategoryRowPresentation.showsDisclosure(for: counting))
        XCTAssertFalse(
            S0CategoryRowPresentation.showsUnavailableValue(for: counting)
        )

        // `.awaitingScanCompletion` 不可点 ⟹ 55% 暗、数值「—」、无进入指示。
        XCTAssertEqual(
            S0CategoryRowPresentation.rowOpacity(for: awaiting),
            0.55,
            accuracy: 0.000_001
        )
        XCTAssertFalse(S0CategoryRowPresentation.showsDisclosure(for: awaiting))
        XCTAssertTrue(
            S0CategoryRowPresentation.showsUnavailableValue(for: awaiting)
        )

        // 「无项目」⟹ 灰显 0.45、无进入指示。
        XCTAssertEqual(
            S0CategoryRowPresentation.rowOpacity(for: empty),
            0.45,
            accuracy: 0.000_001
        )
        XCTAssertFalse(S0CategoryRowPresentation.showsDisclosure(for: empty))

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
        // 三个视图文件内不出现任何图片资源名或取图调用。
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
        // 数据模型里没有 `coverAssetID`——本卡不加没有生产者的字段。
        let snapshot = try XCTUnwrap(
            strippedSource("PhotoCleanupMVE/Core/S0StateMachine.swift")
        )
        XCTAssertEqual(occurrences(of: "coverAssetID", in: snapshot), 0)

        // 封面位是几何 + 空槽：引用了登记的边长与圆角，且只描边不填色。
        let row = try XCTUnwrap(
            strippedSource("PhotoCleanupMVE/Features/S0/S0CategoryRow.swift")
        )
        let cover = try XCTUnwrap(
            slice(row, from: "private var cover: some View {", to: "\n    }")
        )
        XCTAssertGreaterThan(
            occurrences(of: "S0HomeMetrics.categoryCoverSide", in: cover),
            0
        )
        XCTAssertGreaterThan(
            occurrences(of: "S0HomeMetrics.categoryCoverCornerRadius", in: cover),
            0
        )
        XCTAssertGreaterThan(occurrences(of: "strokeBorder", in: cover), 0)
        XCTAssertEqual(occurrences(of: ".fill(", in: cover), 0)
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
