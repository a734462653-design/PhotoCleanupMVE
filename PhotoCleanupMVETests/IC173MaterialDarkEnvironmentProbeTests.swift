import SwiftUI
import UIKit
import XCTest
@testable import PhotoCleanupMVE

/// IC-173 探针（不合并）：系统材质加 `.environment(\.colorScheme, .dark)` 之后到底渲染成什么。
///
/// 背景（IC-172 #350／#351 ①）：iOS 26 玻璃加深色覆盖后与系统深色玻璃逐像素相同（78 = 78）；系统材质加同样的覆盖后
/// 两侧恒定（149 = 149），但不等于真正的深色（同一写法不加覆盖、系统深色时 104），反而更接近浅色（172）。
/// 本文件逐一量出各种写法在浅／深两种系统外观下的中心像素灰度，每组打一行 `IC173_PROBE`；**除夹具自检外不做
/// 判定**——数据交决策会话定子项 C 的修法。取样口径同 `IC172GlassAlwaysDarkTests`（`UIHostingController`、
/// `overrideUserInterfaceStyle`、`drawHierarchy`、中心像素 RGB 均值）。
final class IC173MaterialDarkEnvironmentProbeTests: XCTestCase {
    private static let canvasSize = CGSize(width: 240, height: 120)
    private static let glassSize = CGSize(width: 160, height: 60)

    private enum Backdrop: String {
        case gray
        case black
        case white

        var color: Color {
            switch self {
            case .gray:
                return Color(.sRGB, red: 0.5, green: 0.5, blue: 0.5, opacity: 1)
            case .black:
                return Color(.sRGB, red: 0, green: 0, blue: 0, opacity: 1)
            case .white:
                return Color(.sRGB, red: 1, green: 1, blue: 1, opacity: 1)
            }
        }
    }

    // MARK: - 夹具自检（唯一的判定）

    func testIC173A_HarnessSeesMaterialAppearance() {
        let control = grayPair("M01_bareUltraThin") {
            Color.clear
                .frame(width: Self.glassSize.width, height: Self.glassSize.height)
                .background(.ultraThinMaterial, in: Capsule())
        }
        XCTAssertGreaterThanOrEqual(abs(control.light - control.dark), 12, "夹具看不见材质的外观差，本探针无效")
    }

    // MARK: - SwiftUI 材质 × 覆盖位置

    func testIC173B_SwiftUIMaterialWithColorSchemeOverride() {
        grayPair("M02_bareUltraThin_envDarkOutside") {
            Color.clear
                .frame(width: Self.glassSize.width, height: Self.glassSize.height)
                .background(.ultraThinMaterial, in: Capsule())
                .environment(\.colorScheme, .dark)
        }
        grayPair("M03_bareUltraThin_envLightOutside") {
            Color.clear
                .frame(width: Self.glassSize.width, height: Self.glassSize.height)
                .background(.ultraThinMaterial, in: Capsule())
                .environment(\.colorScheme, .light)
        }
        grayPair("M04_fillUltraThin") {
            Color.clear
                .frame(width: Self.glassSize.width, height: Self.glassSize.height)
                .background {
                    Capsule().fill(.ultraThinMaterial)
                }
        }
        grayPair("M05_fillUltraThin_envDarkOutside") {
            Color.clear
                .frame(width: Self.glassSize.width, height: Self.glassSize.height)
                .background {
                    Capsule().fill(.ultraThinMaterial)
                }
                .environment(\.colorScheme, .dark)
        }
        grayPair("M06_fillUltraThin_envDarkInsideBackground") {
            Color.clear
                .frame(width: Self.glassSize.width, height: Self.glassSize.height)
                .background {
                    Capsule().fill(.ultraThinMaterial)
                        .environment(\.colorScheme, .dark)
                }
        }
        grayPair("M07_bareRegular") {
            Color.clear
                .frame(width: Self.glassSize.width, height: Self.glassSize.height)
                .background(.regularMaterial, in: Capsule())
        }
        grayPair("M08_bareRegular_envDarkOutside") {
            Color.clear
                .frame(width: Self.glassSize.width, height: Self.glassSize.height)
                .background(.regularMaterial, in: Capsule())
                .environment(\.colorScheme, .dark)
        }
        grayPair("M09_productLegacyRecipe") {
            Color.clear
                .frame(width: Self.glassSize.width, height: Self.glassSize.height)
                .s1LegacyChromeGlassBackground(in: Capsule())
        }
        grayPair("M10_menuRecipe") {
            Color.clear
                .frame(width: Self.glassSize.width, height: Self.glassSize.height)
                .background {
                    RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(uiColor: .systemBackground).opacity(0.93))
                }
        }
        grayPair("M11_menuRecipe_envDarkOutside") {
            Color.clear
                .frame(width: Self.glassSize.width, height: Self.glassSize.height)
                .background {
                    RoundedRectangle(cornerRadius: 12).fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(uiColor: .systemBackground).opacity(0.93))
                }
                .environment(\.colorScheme, .dark)
        }
    }

    // MARK: - 动态色本身（不含材质）是否随覆盖解析

    func testIC173C_DynamicColorsWithColorSchemeOverride() {
        grayPair("C01_systemBackground") {
            Color(uiColor: .systemBackground)
                .frame(width: Self.glassSize.width, height: Self.glassSize.height)
        }
        grayPair("C02_systemBackground_envDark") {
            Color(uiColor: .systemBackground)
                .frame(width: Self.glassSize.width, height: Self.glassSize.height)
                .environment(\.colorScheme, .dark)
        }
        grayPair("C03_primary") {
            Color.primary
                .frame(width: Self.glassSize.width, height: Self.glassSize.height)
        }
        grayPair("C04_primary_envDark") {
            Color.primary
                .frame(width: Self.glassSize.width, height: Self.glassSize.height)
                .environment(\.colorScheme, .dark)
        }
    }

    // MARK: - 覆盖后还取不取背后的内容（换底色看同一写法变不变）

    func testIC173D_BackdropSamplingUnderOverride() {
        for backdrop in [Backdrop.black, .white] {
            grayPair("B_" + backdrop.rawValue + "_bareUltraThin", backdrop: backdrop) {
                Color.clear
                    .frame(width: Self.glassSize.width, height: Self.glassSize.height)
                    .background(.ultraThinMaterial, in: Capsule())
            }
            grayPair("B_" + backdrop.rawValue + "_bareUltraThin_envDark", backdrop: backdrop) {
                Color.clear
                    .frame(width: Self.glassSize.width, height: Self.glassSize.height)
                    .background(.ultraThinMaterial, in: Capsule())
                    .environment(\.colorScheme, .dark)
            }
            grayPair("B_" + backdrop.rawValue + "_uikitUltraThinDark", backdrop: backdrop) {
                FixedBlurView(style: .systemUltraThinMaterialDark)
                    .frame(width: Self.glassSize.width, height: Self.glassSize.height)
                    .clipShape(Capsule())
            }
        }
    }

    // MARK: - 覆盖放在含背景的整棵树上

    func testIC173E_OverrideAtRootIncludingBackdrop() {
        grayPair("R01_bareUltraThin_envDarkAtRoot", rootOverride: true) {
            Color.clear
                .frame(width: Self.glassSize.width, height: Self.glassSize.height)
                .background(.ultraThinMaterial, in: Capsule())
        }
        grayPair("R02_bareRegular_envDarkAtRoot", rootOverride: true) {
            Color.clear
                .frame(width: Self.glassSize.width, height: Self.glassSize.height)
                .background(.regularMaterial, in: Capsule())
        }
    }

    // MARK: - 候选修法：UIKit 固定深色模糊样式（按名字恒深，不随外观变）

    func testIC173F_UIKitFixedDarkBlurStyles() {
        grayPair("U01_uikitUltraThinDark") {
            FixedBlurView(style: .systemUltraThinMaterialDark)
                .frame(width: Self.glassSize.width, height: Self.glassSize.height)
                .clipShape(Capsule())
        }
        grayPair("U02_uikitUltraThinAdaptive") {
            FixedBlurView(style: .systemUltraThinMaterial)
                .frame(width: Self.glassSize.width, height: Self.glassSize.height)
                .clipShape(Capsule())
        }
        grayPair("U03_uikitMaterialDark") {
            FixedBlurView(style: .systemMaterialDark)
                .frame(width: Self.glassSize.width, height: Self.glassSize.height)
                .clipShape(Capsule())
        }
        grayPair("U04_uikitMaterialAdaptive") {
            FixedBlurView(style: .systemMaterial)
                .frame(width: Self.glassSize.width, height: Self.glassSize.height)
                .clipShape(Capsule())
        }
    }

    // MARK: - 取样

    @discardableResult
    private func grayPair<Content: View>(
        _ arm: String,
        backdrop: Backdrop = .gray,
        rootOverride: Bool = false,
        @ViewBuilder content: () -> Content
    ) -> (light: Int, dark: Int) {
        let view = content()
        let light = centerGray(of: view, backdrop: backdrop, rootOverride: rootOverride, style: .light)
        let dark = centerGray(of: view, backdrop: backdrop, rootOverride: rootOverride, style: .dark)
        print("IC173_PROBE arm=" + arm + " light=" + String(light) + " dark=" + String(dark))
        return (light, dark)
    }

    private func centerGray<Content: View>(
        of content: Content,
        backdrop: Backdrop,
        rootOverride: Bool,
        style: UIUserInterfaceStyle
    ) -> Int {
        let tree = ZStack {
            backdrop.color
            content
        }
        .frame(width: Self.canvasSize.width, height: Self.canvasSize.height)
        let controller: UIViewController
        if rootOverride {
            controller = UIHostingController(rootView: tree.environment(\.colorScheme, .dark))
        } else {
            controller = UIHostingController(rootView: tree)
        }
        let window = UIWindow(frame: CGRect(origin: .zero, size: Self.canvasSize))
        window.rootViewController = controller
        window.isHidden = false
        defer { window.isHidden = true }

        controller.overrideUserInterfaceStyle = style
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.2))
        controller.view.frame = CGRect(origin: .zero, size: Self.canvasSize)
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 3
        format.opaque = true
        let image = UIGraphicsImageRenderer(
            bounds: controller.view.bounds,
            format: format
        ).image { _ in
            _ = controller.view.drawHierarchy(
                in: controller.view.bounds,
                afterScreenUpdates: true
            )
        }
        return pixelGray(
            image: image,
            point: CGPoint(x: Self.canvasSize.width / 2, y: Self.canvasSize.height / 2)
        )
    }

    private func pixelGray(image: UIImage, point: CGPoint) -> Int {
        guard let source = image.cgImage else {
            XCTFail("截图缺少像素数据")
            return -1
        }
        let x = min(source.width - 1, max(0, Int(point.x * image.scale)))
        let y = min(source.height - 1, max(0, Int(point.y * image.scale)))
        guard let cropped = source.cropping(to: CGRect(x: x, y: y, width: 1, height: 1)) else {
            XCTFail("无法裁取像素")
            return -1
        }
        var pixel = [UInt8](repeating: 0, count: 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let didDraw = pixel.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(
                data: bytes.baseAddress,
                width: 1,
                height: 1,
                bitsPerComponent: 8,
                bytesPerRow: 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else {
                return false
            }
            context.draw(cropped, in: CGRect(x: 0, y: 0, width: 1, height: 1))
            return true
        }
        guard didDraw else {
            XCTFail("无法创建像素取样上下文")
            return -1
        }
        return (Int(pixel[0]) + Int(pixel[1]) + Int(pixel[2])) / 3
    }
}

/// 探针用：UIKit 固定样式模糊视图（`systemUltraThinMaterialDark` 等按名字恒深）。
private struct FixedBlurView: UIViewRepresentable {
    let style: UIBlurEffect.Style

    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
    }
}
