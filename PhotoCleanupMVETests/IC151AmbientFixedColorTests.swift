import SwiftUI
import UIKit
import XCTest
@testable import PhotoCleanupMVE

/// IC-151 子项 A 的复刻件：`S0GlassSurface.frost` 那五个修饰符的原样组合，
/// 与 `S2AmbientBackdropView` 那一条「有框有裁」的组合，只差 `.frame` 与
/// `.clipped()` 两个修饰符。
///
/// **刻意放在测试目标里而不是引用产品代码**：产品侧那一层在子项 D 里被整个
/// 删掉，机制断言必须在删除之后仍然成立——它钉的是 SwiftUI 的布局机制，
/// 不是某一版产品代码。两个分支的模糊半径与饱和度写成字面量也是同一理由
/// （`cardBlurRadius`／`cardSaturation` 随子项 D 从登记表消失）。
private struct IC151FrostReplica: View {
    let image: UIImage
    let proposal: CGSize
    /// 真 = 复刻乙（M9 的组合，有框有裁）；假 = 复刻甲（S10 的组合，无框无裁）。
    let framesAndClips: Bool

    var body: some View {
        if framesAndClips {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: proposal.width, height: proposal.height)
                .clipped()
                .blur(radius: 30, opaque: true)
                .saturation(1.70)
                .clipShape(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                )
        } else {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .blur(radius: 30, opaque: true)
                .saturation(1.70)
                .clipShape(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                )
        }
    }
}

/// IC-151：氛围底改固定色（S2 与 S0 两处）+ 卡片区光晕 + H71 版式塌陷的
/// 归因与修复。
///
/// 依据：Decision_log 第 175 条（④ Lynn 2026-09-15 两条决策变更与 H71 判定
/// 原话）、第 176 条第四节（光晕 α 取中档）。**SPEC-S0 v2／SPEC-S2 v21 尚未
/// 晋级**，故新登记值的出处一律指 Decision_log 与本卡，不冒充 v1 的登记值。
///
/// 断言编号与任务卡一一对应：1～2 属子项 A，3～4 属子项 B，9 属子项 C，
/// 11／12／14 属子项 D。其余六条（5～8、10、13）是 IC-146／IC-148 两个既有
/// 文件内被本卡改写的断言，不在本文件。
final class IC151AmbientFixedColorTests: XCTestCase {

    // MARK: - 断言 1：无框的 scaledToFill 会溢出自己的提案（H71 归因机制）

    /// ③ 假设：H71 的「三张玻璃卡互相叠在一起」不是布局重叠，而是玻璃卡
    /// 磨砂副本的**视觉溢出**——`.scaledToFill()` 之后没有 `.frame(width:height:)`
    /// 与 `.clipped()`，正方形源图按宽填满后向上下各溢出，且 `blur(opaque: true)`
    /// 让那一层完全不透明，于是后画的卡从上一张的中间压过来。
    ///
    /// 本条验证的是**机制**：同一张图、同一提案，只差有没有框与裁。
    /// **它不是「修好了」的证据**（陷阱 13：尺寸断言不等于摆放断言）——
    /// 修好与否只有 H73 第 1 条能判。
    @MainActor
    func testIC151A_UnframedScaledToFillOverflowsItsProposal() {
        // 提案取真机上一张玻璃卡的量级：卡宽约 361、hero 卡高约 120。
        let proposal = CGSize(width: 361, height: 120)
        // 源图是 `sourceTargetEdge = 160` 的正方形缩略图。
        let image = Self.solidSquareImage(edge: 160)

        let unframed = UIHostingController(
            rootView: IC151FrostReplica(
                image: image,
                proposal: proposal,
                framesAndClips: false
            )
        ).sizeThatFits(in: proposal)
        let framed = UIHostingController(
            rootView: IC151FrostReplica(
                image: image,
                proposal: proposal,
                framesAndClips: true
            )
        ).sizeThatFits(in: proposal)

        // 实测值要进自验报告（G864），故无论成败都打进日志。
        print(
            "IC151A-MEASURED proposal="
                + Self.describe(proposal)
                + " unframed="
                + Self.describe(unframed)
                + " framed="
                + Self.describe(framed)
        )

        XCTAssertGreaterThan(
            unframed.height,
            proposal.height,
            "复刻甲没有溢出提案高——③ 假设被推翻，归因栏须写「未定」"
        )
        XCTAssertEqual(
            framed.width,
            proposal.width,
            accuracy: 0.5,
            "复刻乙的回报宽不等于提案宽"
        )
        XCTAssertEqual(
            framed.height,
            proposal.height,
            accuracy: 0.5,
            "复刻乙的回报高不等于提案高——有框有裁就不该溢出"
        )
    }

    // MARK: - 断言 2：玻璃卡不再有任何图层（子项 D 落地后转正式）

    /// 子项 D 把 `S0GlassSurface` 的磨砂副本整层删掉后，`S0View.swift` 里
    /// 不该再剩任何取图／模糊的痕迹。
    ///
    /// **本提交（子项 A）里以 `XCTSkip` 落地**：此刻产品侧那一层还在，正式
    /// 断言必红。子项 D 的提交把本函数体换成正式断言（change-list 逐条记）。
    func testIC151A_S0GlassSurfaceHasNoImageLayer() throws {
        throw XCTSkip(
            "子项 D 尚未落地：S0GlassSurface 仍持有磨砂图层，本条在 D 的提交里转为正式断言。"
        )
    }

    // MARK: - 夹具

    /// 一张纯色正方形图。内容无关紧要——机制只看尺寸与纵横比。
    @MainActor
    private static func solidSquareImage(edge: CGFloat) -> UIImage {
        let size = CGSize(width: edge, height: edge)
        return UIGraphicsImageRenderer(size: size).image { context in
            UIColor.gray.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    /// 尺寸的日志表示。不用字符串插值拼——保持与本仓既有扫描门禁同口径。
    private static func describe(_ size: CGSize) -> String {
        String(format: "%.2fx%.2f", size.width, size.height)
    }
}
