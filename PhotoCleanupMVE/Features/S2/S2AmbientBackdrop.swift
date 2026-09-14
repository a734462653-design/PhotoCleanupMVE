import Photos
import SwiftUI
import UIKit

// MARK: - IC-146 B：氛围底（决策 61）

/// 氛围底的视觉登记制常量。
///
/// **十个量的取值出处一律是 SPEC-S0 v1 第十四节第 2 部分 `S0Ambient` 族**
/// ——决策 61 明写「S2 侧引用不复制」，故本 enum 是 S2 侧的**唯一**落点，
/// 视图代码一个裸数都不写。不进 `S2CalibrationConfiguration`、不上标定面板，
/// 因此 `schemaVersion` 不动。
enum S2AmbientMetrics {
    /// 照片铺底的高斯模糊半径。取值出处：SPEC-S0 v1 第十四节 `S0Ambient`
    /// 的 `ambientBlurRadius`。
    static let blurRadius: CGFloat = 34

    /// 铺底饱和度。取值出处：SPEC-S0 v1 第十四节 `S0Ambient`
    /// 的 `ambientSaturation`。
    static let saturation: Double = 1.15

    /// 铺底不透明度。取值出处：SPEC-S0 v1 第十四节 `S0Ambient`
    /// 的 `ambientOpacity`。
    static let opacity: Double = 0.62

    /// 渐隐幕顶端黑不透明度。取值出处：SPEC-S0 v1 第十四节 `S0Ambient`
    /// 的 `ambientVeilTopOpacity`。
    static let veilTopOpacity: Double = 0.30

    /// 渐隐幕 42% 位置的黑不透明度。取值出处：SPEC-S0 v1 第十四节 `S0Ambient`
    /// 的 `ambientVeilMidOpacity`。
    static let veilMidOpacity: Double = 0.66

    /// 渐隐幕底端黑不透明度。取值出处：SPEC-S0 v1 第十四节 `S0Ambient`
    /// 的 `ambientVeilBottomOpacity`。
    static let veilBottomOpacity: Double = 0.94

    /// 顶部冷色光晕半径（视口高占比）。取值出处：SPEC-S0 v1 第十四节
    /// `S0Ambient` 的 `ambientTintRadius`。
    static let tintRadius: Double = 0.70

    /// 冷色光晕不透明度。取值出处：SPEC-S0 v1 第十四节 `S0Ambient`
    /// 的 `ambientTintOpacity`。
    static let tintOpacity: Double = 0.30

    /// 颗粒层不透明度（overlay 混合）。取值出处：SPEC-S0 v1 第十四节
    /// `S0Ambient` 的 `ambientGrainOpacity`。
    static let grainOpacity: Double = 0.90

    /// 幕底色 `#050507`。取值出处：SPEC-S0 v1 第十四节 `S0Ambient`
    /// 的 `ambientBaseColor`。
    ///
    /// 用 `sRGB` 显式构造而不是 asset 目录色：决策 61 明写氛围底**恒为深色配方、
    /// 不随系统外观切换**，asset 色会跟着 trait 走。
    static let baseColor = Color(
        .sRGB,
        red: 5.0 / 255,
        green: 5.0 / 255,
        blue: 7.0 / 255,
        opacity: 1
    )

    /// 渐隐幕中段的位置（42%）。取值出处：SPEC-S0 v1 第十四节 `S0Ambient`
    /// 中 `ambientVeilMidOpacity` 一行的注释「42% 位置」。
    static let veilMidLocation: Double = 0.42

    /// 顶部冷色光晕的**色相**。SPEC-S0 v1 只登记了该光晕的半径与不透明度
    /// （`ambientTintRadius` / `ambientTintOpacity`），未登记色相，
    /// 故这一项是**执行端取定**：一枚偏冷的浅蓝灰，与「冷色光晕」的措辞相符。
    /// 登记于此而不散落为裸数；日后决策会话若要定案，改这一处即可。
    static let tintHue = (red: 0.42, green: 0.52, blue: 0.72)

    /// 取图的目标边长。模糊半径 34 之后分辨率没有意义，缩略级即可
    /// （规格第 14 条：不得为等氛围底而延迟主图呈现）。
    static let sourceTargetEdge: CGFloat = 160
}

/// IC-146 B：氛围底的取图接口。生产实现走 PhotoKit 缩略级请求；
/// 测试注入桩（含**恒失败**的桩，用于规格第 14 条的回落）。
protocol S2AmbientImageLoading: AnyObject {
    /// 取一张缩略级图。取不到回 nil ⟹ 氛围底退化为 `baseColor` 纯色。
    func ambientImage(assetID: String) async -> UIImage?
}

/// 生产实现。只发**缩略级**请求，禁网络；`deliveryMode` 取 `.fastFormat`
/// ——氛围底要的是颜色不是细节，等高清会把翻页拖慢（规格第 14 条）。
final class S2PhotoKitAmbientImageLoader: S2AmbientImageLoading {
    private let imageManager: PHImageManager

    init(imageManager: PHImageManager = .default()) {
        self.imageManager = imageManager
    }

    func ambientImage(assetID: String) async -> UIImage? {
        guard let asset = PHAsset.fetchAssets(
            withLocalIdentifiers: [assetID],
            options: nil
        ).firstObject else {
            return nil
        }
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = false
        options.deliveryMode = .fastFormat
        options.resizeMode = .fast
        options.isSynchronous = false
        let edge = S2AmbientMetrics.sourceTargetEdge
        return await withCheckedContinuation { continuation in
            let resumer = S2AmbientContinuationResumer()
            imageManager.requestImage(
                for: asset,
                targetSize: CGSize(width: edge, height: edge),
                contentMode: .aspectFill,
                options: options
            ) { image, info in
                // `.fastFormat` 也可能先回一张退化图再回终图；
                // 只认第一次回调，多回的一律丢弃（氛围底不需要终图）。
                let isDegraded =
                    (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                guard image != nil || !isDegraded else {
                    return
                }
                guard resumer.claim() else {
                    return
                }
                continuation.resume(returning: image)
            }
        }
    }
}

/// 系统回调可能多次触发时保证 `CheckedContinuation` 只 resume 一次。
private final class S2AmbientContinuationResumer {
    private let lock = NSLock()
    private var claimed = false

    func claim() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !claimed else {
            return false
        }
        claimed = true
        return true
    }
}

/// IC-146 B：氛围底的读数。**只有氛围底视图观察它**。
///
/// 单列一个 `ObservableObject` 而不是把 `@Published` 挂在协调器上，是陷阱 5 的
/// 直接后果：协调器由 `S2View` 以 `@StateObject` 持有，它一发布变更整个
/// `S2View.body` 就重算，连带 `updateUIViewController` 重进分页器，
/// 静止态就会多出几何写入。同一手法见 IC-141 的 `S2VideoPlaybackReadout`。
@MainActor
final class S2AmbientBackdropReadout: ObservableObject {
    /// 当前张的氛围底源图。nil ⟹ `baseColor` 纯色回落。
    @Published private(set) var image: UIImage?

    func update(_ image: UIImage?) {
        guard self.image !== image else {
            return
        }
        self.image = image
    }
}

/// IC-146 B：氛围底的取图协调器。**关闭态零副作用**：`init` 不取图、
/// 不注册观察者；只有视图显式调 `load(assetID:using:)` 才发请求。
///
/// **本类型自身不发布任何变更**（见 `S2AmbientBackdropReadout` 的理由）。
///
/// 主图呈现**不等**氛围底（规格第 14 条）：取图是独立的异步任务，
/// 取到之前氛围底就是纯色，主图那一层一帧都不被它挡住。
@MainActor
final class S2AmbientBackdropStore: ObservableObject {
    let readout = S2AmbientBackdropReadout()

    /// 已发起加载（或已判定取不到）的资产标识。
    private(set) var loadedAssetID: String?
    /// 取图失败次数（测试用；规格第 14 条的回落由它佐证）。
    private(set) var failureCount = 0
    private var loadTask: Task<Void, Never>?

    func load(assetID: String, using loader: any S2AmbientImageLoading) {
        guard loadedAssetID != assetID else {
            return
        }
        loadedAssetID = assetID
        loadTask?.cancel()
        // 立即回落到纯色，**不留上一张的图**——否则翻页瞬间会闪上一张的颜色。
        readout.update(nil)
        loadTask = Task { @MainActor [weak self] in
            let loaded = await loader.ambientImage(assetID: assetID)
            guard let self, !Task.isCancelled else {
                return
            }
            // 期间又翻了页：迟到的图一律丢弃。
            guard self.loadedAssetID == assetID else {
                return
            }
            if loaded == nil {
                self.failureCount += 1
            }
            self.readout.update(loaded)
        }
    }
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

/// IC-146 B：氛围底视图。主图**之下**的一层，不参与布局、不接触控。
///
/// 三层自下而上：模糊铺底 → 深色渐隐幕 → 颗粒层。取不到源图时只剩
/// `baseColor` 纯色（规格第 14 条）。恒为深色配方，`colorScheme` 不参与
/// 任何一层的取值（规格第 11 条）。
struct S2AmbientBackdropView: View {
    @ObservedObject var readout: S2AmbientBackdropReadout

    var body: some View {
        content(image: readout.image)
            // 规格第 9 条：切换时长与 chrome 显隐过渡同值（决策 45）——
            // **引用既有量，不复制数值**。
            .animation(
                .easeInOut(
                    duration: S2ChromeVisibilityTransition.durationSeconds
                ),
                value: readout.image
            )
    }

    private func content(image: UIImage?) -> some View {
        GeometryReader { geometry in
            ZStack {
                S2AmbientMetrics.baseColor
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(
                            width: geometry.size.width,
                            height: geometry.size.height
                        )
                        .clipped()
                        .blur(
                            radius: S2AmbientMetrics.blurRadius,
                            opaque: true
                        )
                        .saturation(S2AmbientMetrics.saturation)
                        .opacity(S2AmbientMetrics.opacity)
                }
                veil
                tint(viewportHeight: geometry.size.height)
                grain
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        // 规格第 12 条：不参与布局、不接触控。
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// 深色渐隐幕：顶 30% → 42% 处 66% → 底 94%。
    private var veil: some View {
        LinearGradient(
            stops: [
                Gradient.Stop(
                    color: .black.opacity(S2AmbientMetrics.veilTopOpacity),
                    location: 0
                ),
                Gradient.Stop(
                    color: .black.opacity(S2AmbientMetrics.veilMidOpacity),
                    location: S2AmbientMetrics.veilMidLocation
                ),
                Gradient.Stop(
                    color: .black.opacity(S2AmbientMetrics.veilBottomOpacity),
                    location: 1
                )
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// 顶部冷色光晕。半径按视口高占比给（`ambientTintRadius`）。
    private func tint(viewportHeight: CGFloat) -> some View {
        RadialGradient(
            colors: [
                Self.tintColor(opacity: S2AmbientMetrics.tintOpacity),
                Self.tintColor(opacity: 0)
            ],
            center: .top,
            startRadius: 0,
            endRadius: max(1, viewportHeight * S2AmbientMetrics.tintRadius)
        )
    }

    /// 冷色光晕的色。色相登记在 `S2AmbientMetrics.tintHue`，不透明度由调用方给。
    private static func tintColor(opacity: Double) -> Color {
        Color(
            .sRGB,
            red: S2AmbientMetrics.tintHue.red,
            green: S2AmbientMetrics.tintHue.green,
            blue: S2AmbientMetrics.tintHue.blue,
            opacity: opacity
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
