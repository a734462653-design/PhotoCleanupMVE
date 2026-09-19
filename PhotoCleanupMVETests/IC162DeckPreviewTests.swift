import Foundation
import XCTest
@testable import PhotoCleanupMVE

/// IC-162：「卡片叠」首页与新类别页的**真机预览**（探针分支，不合并进 `main`）。
///
/// 本卡是视觉预览不是实装：新旧并存、旧的一字不动、由 `S0DeckPreview.isEnabled` 切换，
/// 八份既有测试对旧文件的断言全部原样通过。因此这里**只测纯函数**——不构造视图、
/// 不碰 PhotoKit；版式、动画、过渡与手感一律留给 Lynn 真机判（H81 六条，陷阱 1）。
///
/// 断言编号与任务卡 IC-20260919-162 一一对应：1～4 属子项 A，5～6 属子项 B。
final class IC162DeckPreviewTests: XCTestCase {

    // MARK: - 断言 1：卡按入参序、丢空类、末尾补「其余照片」（子项 A）

    func testIC162A_CardsKeepOrderDropEmptyAndAppendRest() {
        let cards = S0DeckHomeModel.cards(
            categories: Self.fixtureCategories,
            restByteCount: 500,
            libraryTotalByteCount: 1_000
        )

        // 入参三类，中间那条 `candidateCount = 0` 被丢掉；「其余照片」垫底。
        XCTAssertEqual(
            cards.map { $0.id },
            [
                S0CategoryIdentifier.bigVideo.rawValue,
                S0CategoryIdentifier.screenRecording.rawValue,
                S0DeckHomeModel.restCardID
            ]
        )
        XCTAssertEqual(
            cards.map { $0.category },
            [.bigVideo, .screenRecording, nil]
        )
        XCTAssertEqual(cards.map { $0.byteCount }, [300, 120, 500])

        // 占比手算：300／1000、120／1000、500／1000。夹具取值避开 .5 边界——
        // 双精度下 `0.285 * 100` 是 28.499999999999996，`.rounded()` 会得 28。
        XCTAssertEqual(cards[0].fraction, 0.3, accuracy: 0.000_001)
        XCTAssertEqual(cards[1].fraction, 0.12, accuracy: 0.000_001)
        XCTAssertEqual(cards[2].fraction, 0.5, accuracy: 0.000_001)
        XCTAssertEqual(cards.map { $0.percent }, [30, 12, 50])

        // 可点性与 `S0CategoryRowPresentation.showsDisclosure` 同式；「其余照片」恒不可点。
        XCTAssertEqual(cards.map { $0.isEnterable }, [true, true, false])

        // `LIB` 取不到（扫描早期）：占比一律 0，不除零、不崩。
        let withoutLibrary = S0DeckHomeModel.cards(
            categories: Self.fixtureCategories,
            restByteCount: 500,
            libraryTotalByteCount: 0
        )
        XCTAssertEqual(withoutLibrary.count, 3)
        XCTAssertEqual(withoutLibrary.map { $0.fraction }, [0, 0, 0])
        XCTAssertEqual(withoutLibrary.map { $0.percent }, [0, 0, 0])
    }

    // MARK: - 断言 2：「其余照片」为零时不出这张卡（子项 A）

    func testIC162A_RestCardOmittedWhenZero() {
        let cards = S0DeckHomeModel.cards(
            categories: Self.fixtureCategories,
            restByteCount: 0,
            libraryTotalByteCount: 1_000
        )
        XCTAssertEqual(cards.count, 2)
        XCTAssertFalse(cards.contains { $0.id == S0DeckHomeModel.restCardID })
        XCTAssertFalse(cards.contains { $0.category == nil })
    }

    // MARK: - 断言 3：默认展开哪张、快照变了怎么回落（子项 A）

    func testIC162A_DefaultAndResolvedOpenID() {
        // 首卡「尚未开始识别」不可点，次卡 `.counting` 可点（第 170 条裁定 1）。
        let awaitingFirst = [
            S0CategorySnapshot(
                id: .similar,
                candidateCount: 4,
                candidateByteCount: 400,
                recognition: .awaitingScanCompletion
            ),
            S0CategorySnapshot(
                id: .bigVideo,
                candidateCount: 3,
                candidateByteCount: 300,
                recognition: .counting
            )
        ]
        let cards = S0DeckHomeModel.cards(
            categories: awaitingFirst,
            restByteCount: 0,
            libraryTotalByteCount: 1_000
        )
        XCTAssertEqual(cards.map { $0.isEnterable }, [false, true])
        XCTAssertEqual(
            S0DeckHomeModel.defaultOpenID(cards),
            S0CategoryIdentifier.bigVideo.rawValue
        )

        // 展开的那张仍在且仍可点：原样返回。
        XCTAssertEqual(
            S0DeckHomeModel.resolvedOpenID(
                current: S0CategoryIdentifier.bigVideo.rawValue,
                cards: cards
            ),
            S0CategoryIdentifier.bigVideo.rawValue
        )
        // 展开的那张消失（整类进了待删篮）：回落到第一张可点的。
        XCTAssertEqual(
            S0DeckHomeModel.resolvedOpenID(
                current: S0CategoryIdentifier.screenshot.rawValue,
                cards: cards
            ),
            S0CategoryIdentifier.bigVideo.rawValue
        )
        // 展开的那张还在但不可点了：同样回落。
        XCTAssertEqual(
            S0DeckHomeModel.resolvedOpenID(
                current: S0CategoryIdentifier.similar.rawValue,
                cards: cards
            ),
            S0CategoryIdentifier.bigVideo.rawValue
        )
        // 未展开过：取默认。
        XCTAssertEqual(
            S0DeckHomeModel.resolvedOpenID(current: nil, cards: cards),
            S0CategoryIdentifier.bigVideo.rawValue
        )

        // 一张可点的都没有：不展开。
        let noneEnterable = S0DeckHomeModel.cards(
            categories: [awaitingFirst[0]],
            restByteCount: 100,
            libraryTotalByteCount: 1_000
        )
        XCTAssertEqual(noneEnterable.count, 2)
        XCTAssertNil(S0DeckHomeModel.defaultOpenID(noneEnterable))
        XCTAssertNil(
            S0DeckHomeModel.resolvedOpenID(
                current: S0CategoryIdentifier.similar.rawValue,
                cards: noneEnterable
            )
        )
    }

    // MARK: - 断言 4：「最大的 N 个」求和夹到实际项数（子项 A）

    func testIC162A_TopSumClampsToCount() {
        let three = Self.assets(count: 3)
        let threeSum = S0DeckHomeModel.topSum(three, limit: 10)
        XCTAssertEqual(threeSum.count, 3)
        XCTAssertEqual(threeSum.byteCount, 300 + 299 + 298)

        let twelve = Self.assets(count: 12)
        let twelveSum = S0DeckHomeModel.topSum(twelve, limit: 10)
        XCTAssertEqual(twelveSum.count, 10)
        XCTAssertEqual(
            twelveSum.byteCount,
            twelve.prefix(10).reduce(into: Int64(0)) { $0 += $1.byteCount }
        )
        // 正对照：前 10 项之和确实小于全部 12 项之和，求和不是空转。
        XCTAssertLessThan(
            twelveSum.byteCount,
            twelve.reduce(into: Int64(0)) { $0 += $1.byteCount }
        )

        let empty = S0DeckHomeModel.topSum([], limit: 10)
        XCTAssertEqual(empty.count, 0)
        XCTAssertEqual(empty.byteCount, 0)
    }

    // MARK: - 夹具

    /// 三条类别：第一条有项目、第二条无项目（应被丢掉）、第三条有项目。
    /// 字节量 300／0／120 对 `LIB = 1000` 都整除得尽，占比不落在 .5 边界上。
    private static let fixtureCategories = [
        S0CategorySnapshot(
            id: .bigVideo,
            candidateCount: 6,
            candidateByteCount: 300,
            recognition: .settled
        ),
        S0CategorySnapshot(
            id: .screenshot,
            candidateCount: 0,
            candidateByteCount: 0,
            recognition: .settled
        ),
        S0CategorySnapshot(
            id: .screenRecording,
            candidateCount: 2,
            candidateByteCount: 120,
            recognition: .settled
        )
    ]

    /// 体积严格递减的 N 条资产，顺序即类别页的网格顺序。
    private static func assets(count: Int) -> [S0CategoryAsset] {
        (0..<count).map { index in
            S0CategoryAsset(
                id: String(index),
                byteCount: Int64(300 - index),
                isVideo: true,
                duration: TimeInterval(index)
            )
        }
    }
}
