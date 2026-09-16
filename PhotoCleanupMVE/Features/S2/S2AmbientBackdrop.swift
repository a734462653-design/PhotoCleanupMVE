import SwiftUI
import UIKit

// MARK: - IC-151 B：氛围底（固定色配方）

/// 氛围底的视觉登记制常量，共 **12 个**。
///
/// **v2 配方：固定色。** IC-146 B 的「当前照片强模糊铺底」十个值随
/// Decision_log 第 175 条整体作废——④ Lynn 2026-09-15：底色恒定、与 logo
/// 的绿呼应，不再拿用户照片做底。决策 61「S2 侧引用不复制」沿用，故本 enum
/// 仍是 S2 与 S0 两页的**唯一**落点，视图代码一个裸数都不写。
///
/// 不进 `S2CalibrationConfiguration`、不上标定面板，因此 `schemaVersion` 不动。
enum S2AmbientMetrics {
    /// 幕底色 `#0B1A13`，恒定，不随系统外观。
    /// 取值出处：Decision_log 第 175／176 条、IC-151 卡
    /// （SPEC-S0 v2 晋级后改指第十四节第 2 部分）。
    ///
    /// 用 `sRGB` 显式构造而不是 asset 目录色：氛围底**恒为深色配方、
    /// 不随系统外观切换**，asset 色会跟着 trait 走。
    static let baseColor = Color(
        .sRGB,
        red: 11.0 / 255,
        green: 26.0 / 255,
        blue: 19.0 / 255,
        opacity: 1
    )

    /// 提亮与光晕共用的绿色相 `#7AC49E` = rgb(122, 196, 158)。
    /// 取值出处：Decision_log 第 175／176 条、IC-151 卡
    /// （SPEC-S0 v2 晋级后改指第十四节第 2 部分）。
    static let tintColor = Color(
        .sRGB,
        red: 122.0 / 255,
        green: 196.0 / 255,
        blue: 158.0 / 255,
        opacity: 1
    )

    /// 顶端绿色提亮的不透明度（视口顶端处）。
    /// 取值出处：Decision_log 第 175／176 条、IC-151 卡
    /// （SPEC-S0 v2 晋级后改指第十四节第 2 部分）。
    static let washTopOpacity: Double = 0.07

    /// 提亮收零的位置（视口高占比）。
    /// 取值出处：Decision_log 第 175／176 条、IC-151 卡
    /// （SPEC-S0 v2 晋级后改指第十四节第 2 部分）。
    static let washFadeLocation: Double = 0.42

    /// 底端黑色压暗的不透明度（视口底端处）。
    /// 取值出处：Decision_log 第 175／176 条、IC-151 卡
    /// （SPEC-S0 v2 晋级后改指第十四节第 2 部分）。
    static let washBottomOpacity: Double = 0.22

    /// 光晕中心横坐标（视口宽占比）。
    /// 取值出处：Decision_log 第 175／176 条、IC-151 卡
    /// （SPEC-S0 v2 晋级后改指第十四节第 2 部分）。
    static let glowCenterX: Double = 0.50

    /// 光晕中心纵坐标（视口高占比）。
    /// 取值出处：Decision_log 第 175／176 条、IC-151 卡
    /// （SPEC-S0 v2 晋级后改指第十四节第 2 部分）。
    static let glowCenterY: Double = 0.34

    /// 光晕横向半径（视口宽占比）。
    /// 取值出处：Decision_log 第 175／176 条、IC-151 卡
    /// （SPEC-S0 v2 晋级后改指第十四节第 2 部分）。
    static let glowRadiusX: Double = 0.92

    /// 光晕纵向半径（视口高占比）。
    /// 取值出处：Decision_log 第 175／176 条、IC-151 卡
    /// （SPEC-S0 v2 晋级后改指第十四节第 2 部分）。
    static let glowRadiusY: Double = 0.42

    /// 光晕中心不透明度（④ Decision_log 第 176 条第四节：三档看过后取中档）。
    /// 取值出处：Decision_log 第 175／176 条、IC-151 卡
    /// （SPEC-S0 v2 晋级后改指第十四节第 2 部分）。
    static let glowOpacity: Double = 0.10

    /// 光晕收零位置（半径占比）。
    /// 取值出处：Decision_log 第 175／176 条、IC-151 卡
    /// （SPEC-S0 v2 晋级后改指第十四节第 2 部分）。
    static let glowFadeStop: Double = 0.72

    /// 颗粒层不透明度（overlay 混合），沿用 v1 同值。
    /// 取值出处：Decision_log 第 175／176 条、IC-151 卡
    /// （SPEC-S0 v2 晋级后改指第十四节第 2 部分）。
    static let grainOpacity: Double = 0.90
}

/// IC-146 B：颗粒层的噪点贴图。**确定性生成**（固定种子的线性同余），
/// 与系统外观无关。
///
/// 刻意不用 `.ultraThinMaterial` 一类系统材质：那些材质随 trait 变，
/// 与决策 61「恒为深色配方、不随系统外观切换」直接相悖
/// （#289 的 `testIC067G39…` 就是被这一层的外观差打红的）。
///
/// 噪点以**中灰**为均值：中灰在 `overlay` 混合下近似恒等元，
/// 故这一层只加颗粒感，不整体提亮或压暗底下的幕色。
enum S2AmbientGrain {
    /// 贴图边长。平铺用，取 2 的幂。
    static let tileEdge = 64

    /// 噪点幅度：中灰 128 上下各 24 级。
    static let amplitude = 24

    static let tile: UIImage? = makeTile()

    private static func makeTile() -> UIImage? {
        let edge = tileEdge
        let span = amplitude * 2 + 1
        var bytes = [UInt8](repeating: 0, count: edge * edge * 4)
        var seed: UInt32 = 0x9E37_79B9
        for pixel in 0..<(edge * edge) {
            seed = seed &* 1_664_525 &+ 1_013_904_223
            let level = UInt8(
                clamping: 128 - amplitude + Int((seed >> 24) % UInt32(span))
            )
            let offset = pixel * 4
            bytes[offset] = level
            bytes[offset + 1] = level
            bytes[offset + 2] = level
            bytes[offset + 3] = 255
        }
        guard let provider = CGDataProvider(data: Data(bytes) as CFData),
              let image = CGImage(
                  width: edge,
                  height: edge,
                  bitsPerComponent: 8,
                  bitsPerPixel: 32,
                  bytesPerRow: edge * 4,
                  space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGBitmapInfo(
                      rawValue: CGImageAlphaInfo.premultipliedLast.rawValue
                  ),
                  provider: provider,
                  decode: nil,
                  shouldInterpolate: false,
                  intent: .defaultIntent
              ) else {
            return nil
        }
        return UIImage(cgImage: image)
    }
}

/// IC-151 B：氛围底视图。主图**之下**的一层，不参与布局、不接触控。
///
/// 四层自下而上：幕底色 → 竖向提亮压暗（wash）→ 卡片区光晕（glow）→ 颗粒层。
/// **视图无参数、不观察任何 `ObservableObject`、不挂动画**——固定色没有
/// 「切换」，决策 61「氛围底随当前张切换、切换时长与 chrome 显隐过渡同值」
/// 随 Decision_log 第 175 条作废。
///
/// 恒为深色配方，`colorScheme` 不参与任何一层的取值。
struct S2AmbientBackdropView: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                S2AmbientMetrics.baseColor
                wash
                glow(viewportSize: geometry.size)
                grain
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        // 规格第 12 条：不参与布局、不接触控。
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// 竖向提亮压暗：顶端绿色提亮 → 中途收零 → 底端黑色压暗。
    private var wash: some View {
        LinearGradient(
            stops: [
                Gradient.Stop(
                    color: S2AmbientMetrics.tintColor.opacity(
                        S2AmbientMetrics.washTopOpacity
                    ),
                    location: 0
                ),
                Gradient.Stop(
                    color: S2AmbientMetrics.tintColor.opacity(0),
                    location: S2AmbientMetrics.washFadeLocation
                ),
                Gradient.Stop(
                    color: .black.opacity(
                        S2AmbientMetrics.washBottomOpacity
                    ),
                    location: 1
                )
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// 卡片区光晕：椭圆径向渐变，中心偏上。
    ///
    /// `EllipticalGradient` 的中心与半径定义在**单位正方形**里，再拉伸去填满
    /// 自己的框：半值即触到框边。故框取「半径占比 × 视口边长」的两倍、收零
    /// 位置取 `glowFadeStop` 的一半——两处折半是同一条换算，不是新取值。
    private func glow(viewportSize: CGSize) -> some View {
        EllipticalGradient(
            colors: [
                S2AmbientMetrics.tintColor.opacity(
                    S2AmbientMetrics.glowOpacity
                ),
                S2AmbientMetrics.tintColor.opacity(0)
            ],
            center: .center,
            startRadiusFraction: 0,
            endRadiusFraction: S2AmbientMetrics.glowFadeStop / 2
        )
        .frame(
            width: viewportSize.width * S2AmbientMetrics.glowRadiusX * 2,
            height: viewportSize.height * S2AmbientMetrics.glowRadiusY * 2
        )
        .position(
            x: viewportSize.width * S2AmbientMetrics.glowCenterX,
            y: viewportSize.height * S2AmbientMetrics.glowCenterY
        )
    }

    /// 颗粒层。平铺确定性噪点贴图，`overlay` 混合，
    /// 避免大片纯色区域的带状断层。
    @ViewBuilder
    private var grain: some View {
        if let tile = S2AmbientGrain.tile {
            Image(uiImage: tile)
                .resizable(resizingMode: .tile)
                .opacity(S2AmbientMetrics.grainOpacity)
                .blendMode(.overlay)
        }
    }
}
