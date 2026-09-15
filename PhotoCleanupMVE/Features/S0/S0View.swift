import Foundation
import SwiftUI
import UIKit

/// S0 首页的数据源协议（**消费侧定义**，照 `S2AssetSizeProbing` 的既有样板：
/// 协议在消费侧、实现在 `Services/`、由 App 入口注入、测试注入桩）。
///
/// 本协议是 S0 与扫描实现之间的唯一接缝：首页只认识这三个问题，不认识
/// PhotoKit。真实扫描服务排批次 5.1（等 H68 真机数据），落地后只换实现。
protocol S0CleanupDataProviding: AnyObject {
    /// 扫没扫完、失败没失败。调用方据此决定发哪个迁移事件。
    func currentScanOutcome() -> S0ScanOutcome
    /// 当前一次取数结果：进度、可清理去重字节、类别列表、照片库总占用、账本。
    func currentSnapshot() -> S0CleanupSnapshot
    /// 推进扫描。桩按剧本走下一步；真实现按增量缓存续扫。
    func advanceScan()
}

/// IC-148 A（裁定 乙）：氛围底的图源协议。同样是消费侧定义、实现在 `Services/`、
/// 由 App 入口注入（照上面 `S0CleanupDataProviding` 的同一样板）。
///
/// 与 S2 侧的 `S2AmbientImageLoading` 形状不同：那只以**资产标识**为键，而 S0
/// 取的是「照片库中最近一张」，没有键可传，故另立一只协议而不是硬套。
protocol S0AmbientImageProviding: AnyObject {
    /// 取「最近一张」的缩略级图。取不到回 nil ⟹ 氛围底退化为幕底色纯色。
    func recentAmbientImage() async -> UIImage?
}

/// 字节量文本。SPEC-S0 v1 第十四节第 3 部分末句：字节量一律用系统
/// `ByteCountFormatter` 的 `.file` 口径，不自造单位字样拼接，格式化不进目录。
enum S0ByteCountText {
    static func string(forByteCount byteCount: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowsNonnumericFormatting = false
        return formatter.string(fromByteCount: max(0, byteCount))
    }
}

/// 类别显示名。取值以 SPEC-S0 v1 第十四节第 3 部分为唯一来源。
enum S0CategoryText {
    static func displayName(for identifier: S0CategoryIdentifier) -> String {
        switch identifier {
        case .bigVideo:
            return L10n.text("s0.category.bigVideo")
        case .screenshot:
            return L10n.text("s0.category.screenshot")
        case .screenRecording:
            return L10n.text("s0.category.screenRecording")
        case .duplicate:
            return L10n.text("s0.category.duplicate")
        case .similar:
            return L10n.text("s0.category.similar")
        }
    }
}

/// IC-148：S0 首页的视觉层。
///
/// **行为一行未改**——状态机、迁移、点击有效性、数据源协议与桩都是 IC-147 的
/// 交付物，由 `IC147S0BehaviorTests` 的 16 项钉住；本卡只换这六个 builder 的
/// 版式，并加上氛围底与玻璃卡。
///
/// 三条实装裁定（IC-148 卡内，待入 Decision_log 第 171 条）：
/// - **裁定 甲**：首页恒为深色氛围配方，不提供浅色版，不引用任何随 trait 解析
///   的色源（与 SPEC-S2 v20 决策 61 同制）。
/// - **裁定 乙**：氛围底图源取「照片库中最近一张」；取不到即纯色回落，
///   回落逻辑用 `S2AmbientBackdropReadout` 的既有行为，不另造。
/// - **裁定 丙**：氛围底实现**原地复用** `Features/S2/S2AmbientBackdrop.swift`
///   的 `S2AmbientMetrics`／`S2AmbientBackdropView`／`S2AmbientBackdropReadout`
///   ——那是决策 61「S2 侧引用不复制」的唯一落点。本卡对该文件**一行不改**，
///   不搬家、不改名、不在 S0 侧复制一份配方。名字带 `S2` 前缀而被 S0 使用是
///   已知的命名不协调，日后正名另开一张纯重构卡。
struct S0View: View {
    @ObservedObject var machine: S0StateMachine
    /// 氛围底读数。S0 **自持一只**，不经 `S2AmbientBackdropStore`——那只的
    /// `load(assetID:using:)` 以资产标识为键，与「最近一张」的取数形状不符。
    @StateObject private var ambientReadout = S2AmbientBackdropReadout()
    /// 只摄入一次。`TabView` 的 tab 每次被选中都会重发 `onAppear`，而
    /// `.applicationOpened` 会清 `VF` 与 `cat` 并把 `SC` 打回扫描中——
    /// 没有这道闸，来回切 tab 就会反复重置 S0 的状态（H70 第 2 条正是切十次）。
    @State private var hasBootstrapped = false
    /// 氛围底同理只取一次：取图是 PhotoKit 请求，反复切 tab 不该反复发。
    @State private var hasRequestedAmbient = false

    private let dataProvider: (any S0CleanupDataProviding)?
    private let ambientImageProvider: (any S0AmbientImageProviding)?
    private let onEnterCategoryPage: (S0CategoryIdentifier) -> Void
    private let onEnterConfirmation: () -> Void
    private let onOpenAccountSheet: () -> Void
    private let onSwitchToOrganizeTab: () -> Void
    private let onOpenSystemSettings: () -> Void
    private let onRetry: () -> Void

    init(
        machine: S0StateMachine,
        dataProvider: (any S0CleanupDataProviding)? = nil,
        ambientImageProvider: (any S0AmbientImageProviding)? = nil,
        onEnterCategoryPage: @escaping (S0CategoryIdentifier) -> Void = { _ in },
        onEnterConfirmation: @escaping () -> Void = {},
        onOpenAccountSheet: @escaping () -> Void = {},
        onSwitchToOrganizeTab: @escaping () -> Void = {},
        onOpenSystemSettings: @escaping () -> Void = {},
        onRetry: @escaping () -> Void = {}
    ) {
        self.machine = machine
        self.dataProvider = dataProvider
        self.ambientImageProvider = ambientImageProvider
        self.onEnterCategoryPage = onEnterCategoryPage
        self.onEnterConfirmation = onEnterConfirmation
        self.onOpenAccountSheet = onOpenAccountSheet
        self.onSwitchToOrganizeTab = onSwitchToOrganizeTab
        self.onOpenSystemSettings = onOpenSystemSettings
        self.onRetry = onRetry
    }

    var body: some View {
        ZStack {
            // 氛围底：最底一层，不参与布局、不接触控、不产生几何写入
            // （由 `S2AmbientBackdropView` 自身的 `allowsHitTesting(false)` 与
            // `accessibilityHidden(true)` 保证，IC-146 的两条断言已钉住）。
            S2AmbientBackdropView(readout: ambientReadout)
                .ignoresSafeArea()
            scrollingContent
        }
        .onAppear {
            bootstrapIfNeeded()
            requestAmbientImageIfNeeded()
        }
    }

    private var scrollingContent: some View {
        ScrollView {
            VStack(
                alignment: .leading,
                spacing: S1ChromeLayout.chromeToOverlaySpacing
            ) {
                topRow
                limitedBanner
                heroCard
                segmentCard
                pendingRow
                categoryCard
                failureCard
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, S1ChromeLayout.horizontalMargin)
            .padding(.top, S1ChromeLayout.topRowTopInset)
        }
    }

    /// 页面当前态。取一次，下面各处复用——**不改任何取数语义**。
    private var homeState: S0State {
        machine.state
    }

    // MARK: - 顶部两件（chrome 一律引用 S1 的登记常量与玻璃 helper）

    @ViewBuilder
    private var topRow: some View {
        HStack(spacing: S1ChromeLayout.itemSpacing) {
            Text(L10n.text("s0.home.title"))
                .font(
                    .system(
                        size: S1ChromeTypography.titleFontSize,
                        weight: .semibold
                    )
                )
                .foregroundStyle(S0HomePalette.text)
            Spacer(minLength: 0)
            if showsBasketCapsule {
                Button(action: onEnterConfirmation) {
                    Text(basketCapsuleText)
                        .font(.system(size: S1ChromeTypography.titleFontSize))
                        .foregroundStyle(S0HomePalette.text)
                        .padding(.horizontal, S1ChromeLayout.itemSpacing)
                        .frame(height: S1ChromeLayout.rowHeight)
                        .s1ChromeGlassBackground(in: Capsule(), interactive: true)
                }
            }
            Button(action: onOpenAccountSheet) {
                Image(systemName: S0HomeSymbol.account)
                    .foregroundStyle(S0HomePalette.text)
                    .s1ChromeCircleGlass()
            }
            .accessibilityLabel(L10n.text("s0.account.title"))
        }
        .frame(height: S1ChromeLayout.rowHeight)
    }

    /// 待删篮胶囊 V1 的显隐：**只按 SPEC-S0 v1 第三节「`D_全部` 为空时不
    /// 显示」与第五节矩阵第 3 行**，不加规格没有的与项。
    ///
    /// 体积位的真实来源要等批次 5.1 的扫描服务；在那之前注入的桩回报零，
    /// 胶囊会读出「N · 零字节」。这是数据欠账、不是措辞越界（口径仍是
    /// 「待删篮 N 项 · X GB」那一条），已在 IC-147／IC-148 自验报告登记。
    private var showsBasketCapsule: Bool {
        machine.accepts(.basketCapsule)
    }

    private var basketCapsuleText: String {
        L10n.text(
            "s0.basket.capsule",
            replacing: [
                "count": String(machine.mergedPendingDeletionCount),
                "volume": S0ByteCountText.string(
                    forByteCount: machine.pendingDeletionByteCount
                )
            ]
        )
    }

    /// 受限提示条。几何取 `S1LimitedBannerStyle`（S0 不自造 chrome 语汇）。
    ///
    /// 显隐**不能**用 `S1LimitedBannerPresentation.isVisible(...)`：那只的形参是
    /// `S1State`，与 S0 的四态不是同一枚举。此处按 SPEC-S0 v1 第三节的显示元素
    /// 清单——S0-1／S0-2／S0-3 都列了受限提示条，S0-4 没列。
    @ViewBuilder
    private var limitedBanner: some View {
        if machine.isLimitedAuthorization, homeState != .failed {
            Text(L10n.text("s1.limited.banner"))
                .font(.system(size: S1LimitedBannerStyle.textFontSize))
                .foregroundStyle(S0HomePalette.text)
                .padding(.horizontal, S1LimitedBannerStyle.horizontalPadding)
                .frame(
                    maxWidth: .infinity,
                    minHeight: S1LimitedBannerStyle.height,
                    alignment: .leading
                )
                .s0GlassSurface(
                    cornerRadius: S1LimitedBannerStyle.cornerRadius,
                    ambientImage: ambientReadout.image
                )
        }
    }

    // MARK: - hero

    @ViewBuilder
    private var heroCard: some View {
        switch homeState {
        case .scanning:
            glassCard {
                scanningHero
            }
        case .ready:
            glassCard {
                readyHero
            }
        case .empty:
            glassCard {
                emptyHero
            }
        case .failed:
            EmptyView()
        }
    }

    /// 首帧数据到达前显示「正在扫描…」，不显示零字节大数字（第 165 条第 3 条）。
    ///
    /// 判据取**可清理字节是否为零**而不是已扫张数：扫描早期「已扫几千张、
    /// 一个大视频都还没命中」是常态，此时按张数判会画出「零字节」，正是该条
    /// 要避免的读数。
    @ViewBuilder
    private var scanningHero: some View {
        heroLabel
        if machine.snapshot.cleanableByteCount == 0 {
            // 占位句用 hero 单位字号：登记表没给该句字号，取同族里最接近的
            // 一个（96 的大数字位放不下这句话）。已登记为登记表缺口。
            Text(L10n.text("s0.home.hero.scanning"))
                .font(.system(size: S0HomeMetrics.heroUnitFontSize))
                .foregroundStyle(S0HomePalette.text)
        } else {
            heroValue(
                byteCount: machine.snapshot.cleanableByteCount
            )
        }
        HStack(spacing: S0HomeMetrics.legendItemSpacingV) {
            ProgressView()
                .controlSize(.mini)
            heroSubText(scanProgressText)
        }
        heroSubText(L10n.text("s0.home.hero.growing"))
    }

    @ViewBuilder
    private var readyHero: some View {
        heroLabel
        heroValue(byteCount: machine.snapshot.cleanableByteCount)
        heroSubText(
            L10n.text(
                "s0.home.hero.library",
                replacing: [
                    "total": S0ByteCountText.string(
                        forByteCount: machine.snapshot.libraryTotalByteCount
                    )
                ]
            )
        )
        heroSubText(L10n.text("s0.home.hero.overlap"))
    }

    /// 空态：主句 + 已扫描资产总数的副句 + 指向「逐张整理」tab 的入口
    /// （第 165 条第 17 条）。副句取已登记的进度文案，不自造措辞。
    /// **不显示零字节大数字。**
    @ViewBuilder
    private var emptyHero: some View {
        Text(L10n.text("s0.home.hero.empty.title"))
            .font(.system(size: S0HomeMetrics.heroUnitFontSize))
            .foregroundStyle(S0HomePalette.text)
        heroSubText(scanProgressText)
        capsuleButton(
            title: L10n.text("s0.home.hero.empty.action"),
            action: onSwitchToOrganizeTab
        )
    }

    private var heroLabel: some View {
        Text(L10n.text("s0.home.hero.label"))
            .font(.system(size: S0HomeMetrics.heroLabelFontSize))
            .foregroundStyle(
                S0HomePalette.dimmedText(opacity: S0HomeMetrics.heroSubOpacity)
            )
    }

    /// hero 大字：值与单位分两个登记字号，字距取 `heroValueLetterSpacing`。
    private func heroValue(byteCount: Int64) -> some View {
        let parts = S0ByteCountSplit.split(
            S0ByteCountText.string(forByteCount: byteCount)
        )
        return HStack(alignment: .lastTextBaseline, spacing: 0) {
            Text(parts.value)
                .font(
                    .system(
                        size: S0HomeMetrics.heroValueFontSize,
                        weight: .semibold
                    )
                )
                .tracking(S0HomeMetrics.heroValueLetterSpacing)
                .foregroundStyle(S0HomePalette.text)
            Text(parts.unit)
                .font(.system(size: S0HomeMetrics.heroUnitFontSize))
                .foregroundStyle(S0HomePalette.text)
        }
    }

    private func heroSubText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: S0HomeMetrics.heroSubFontSize))
            .foregroundStyle(
                S0HomePalette.dimmedText(opacity: S0HomeMetrics.heroSubOpacity)
            )
    }

    private var scanProgressText: String {
        L10n.text(
            "s0.home.hero.progress",
            replacing: [
                "scanned": String(machine.snapshot.progress.scannedAssetCount),
                "total": String(machine.snapshot.progress.totalAssetCount)
            ]
        )
    }

    // MARK: - 分段条与图例

    /// 分段条呈现照片库总占用 `LIB` 的构成；S0-4 不画（第三节第 4 部分）。
    @ViewBuilder
    private var segmentCard: some View {
        if homeState != .failed {
            glassCard {
                S0SegmentBarView(model: segmentBarModel)
                S0SegmentLegendView(model: segmentBarModel)
            }
        }
    }

    /// 分段条模型。**一次**读快照，宽度与斜纹全在纯函数里算。
    private var segmentBarModel: S0SegmentBarModel {
        let snapshot = machine.snapshot
        return S0SegmentBarModel.make(
            categories: machine.orderedCategories,
            ledgerEntries: snapshot.ledgerEntries,
            libraryTotalByteCount: snapshot.libraryTotalByteCount,
            progress: snapshot.progress,
            isScanning: homeState == .scanning
        )
    }

    // MARK: - 等待清空行

    @ViewBuilder
    private var pendingRow: some View {
        if machine.showsPendingClearanceRow {
            HStack(spacing: S0HomeMetrics.legendItemSpacingV) {
                pendingSwatch
                Text(
                    L10n.text(
                        "s0.home.pending.label",
                        replacing: [
                            "total": S0ByteCountText.string(
                                forByteCount: machine.pendingClearanceByteCount
                            )
                        ]
                    )
                )
                .font(.system(size: S0HomeMetrics.pendingRowFontSize))
                .foregroundStyle(S0HomePalette.text)
                Spacer(minLength: 0)
                if machine.accepts(.ledgerCleared) {
                    pendingActionButton
                }
            }
            .padding(.horizontal, S0HomeMetrics.pendingRowLeadingInset)
            .frame(
                maxWidth: .infinity,
                minHeight: S0HomeMetrics.pendingRowHeight,
                alignment: .leading
            )
            .s0GlassSurface(
                cornerRadius: S0HomeMetrics.pendingRowCornerRadius,
                ambientImage: ambientReadout.image
            )
        }
        verificationRow
    }

    /// 等待清空行左侧的斜纹色块。同一套斜纹几何（角度、纹宽、间隔）。
    private var pendingSwatch: some View {
        S0SegmentHatch(
            color: Color.white.opacity(S0HomeMetrics.segmentRestOpacity)
        )
        .frame(
            width: S0HomeMetrics.legendDotSide,
            height: S0HomeMetrics.legendDotSide
        )
        .clipShape(
            RoundedRectangle(
                cornerRadius: S0HomeMetrics.legendDotCornerRadius,
                style: .continuous
            )
        )
    }

    private var pendingActionButton: some View {
        Button {
            machine.beginVerification()
        } label: {
            Text(L10n.text("s0.home.pending.action"))
                .font(.system(size: S0HomeMetrics.pendingButtonFontSize))
                .foregroundStyle(S0HomePalette.text)
                .padding(.horizontal, S0HomeMetrics.legendItemSpacingH)
                .frame(height: S0HomeMetrics.pendingButtonHeight)
                .s1ChromeGlassBackground(
                    in: RoundedRectangle(
                        cornerRadius: S0HomeMetrics.pendingButtonCornerRadius,
                        style: .continuous
                    ),
                    interactive: true
                )
        }
    }

    /// `VF` 的呈现**只反映状态机给出的值**。
    ///
    /// **不自造「已通过」读数的淡出、计时或自动清除**——第 170 条裁定 3：
    /// `VF=已通过` 的复位路径未定，归批次 5.3。本视图因此不含任何定时器、
    /// 不含任何把 `VF` 推进或复位的调用。
    @ViewBuilder
    private var verificationRow: some View {
        switch machine.verificationState {
        case .none:
            EmptyView()
        case .checking:
            pendingStatusText(L10n.text("s0.home.pending.checking"))
        case .passed:
            pendingStatusText(
                L10n.text(
                    "s0.home.pending.passed",
                    replacing: [
                        "released": S0ByteCountText.string(
                            forByteCount: machine.lastVerifiedReleasedByteCount
                        )
                    ]
                )
            )
        case .failed:
            pendingStatusText(L10n.text("s0.home.pending.failed"))
        }
    }

    private func pendingStatusText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: S0HomeMetrics.pendingRowFontSize))
            .foregroundStyle(
                S0HomePalette.dimmedText(opacity: S0HomeMetrics.heroSubOpacity)
            )
            .padding(.horizontal, S0HomeMetrics.pendingRowLeadingInset)
    }

    // MARK: - 类别行

    @ViewBuilder
    private var categoryCard: some View {
        if machine.showsCategoryRows {
            glassCard {
                ForEach(machine.orderedCategories) { category in
                    Button {
                        // 迁移由状态机判定；只有判定为「迁至类别页」才回调容器。
                        if case let .categoryPage(identifier) =
                            machine.handle(.categoryRowTapped(category.id)) {
                            onEnterCategoryPage(identifier)
                        }
                    } label: {
                        S0CategoryRowView(
                            category: category,
                            subtitle: categorySubtitle(for: category)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!machine.acceptsCategoryRowTap(category.id))
                }
            }
        }
    }

    /// 副行文案。
    ///
    /// 已就绪且有项目的类别回 **nil**：其体积读数在类别行右侧的值位
    /// （`categoryValueFontSize` 24 / `categoryValueUnitFontSize` 12），
    /// 而第十四节第 3 部分**没有登记该情形的副行文案**，不重复画同一个数字。
    /// 其余三种情形的副行文案都是已登记的 key。
    private func categorySubtitle(for category: S0CategorySnapshot) -> String? {
        switch category.recognition {
        case .awaitingScanCompletion:
            return L10n.text("s0.home.category.waiting")
        case .counting:
            return L10n.text(
                "s0.home.category.counting",
                replacing: [
                    "scanned": String(machine.snapshot.progress.scannedAssetCount),
                    "total": String(machine.snapshot.progress.totalAssetCount)
                ]
            )
        case .settled:
            guard category.hasItems else {
                return L10n.text("s0.home.category.empty")
            }
            return nil
        }
    }

    // MARK: - 失败态

    /// S0-4：只有大标题、人像圆钮与中央失败说明；**不显示 hero 数值、
    /// 不显示分段条、不显示类别行**（第三节第 4 部分）。
    @ViewBuilder
    private var failureCard: some View {
        if homeState == .failed {
            glassCard {
                if machine.failureCategory == .authorization {
                    failureBody(
                        title: L10n.text("s0.home.failed.auth.title"),
                        action: L10n.text("s0.home.failed.auth.action"),
                        handler: onOpenSystemSettings
                    )
                } else {
                    failureBody(
                        title: L10n.text("s0.home.failed.read.title"),
                        action: L10n.text("s0.home.failed.read.action"),
                        handler: onRetry
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func failureBody(
        title: String,
        action: String,
        handler: @escaping () -> Void
    ) -> some View {
        Text(title)
            .font(.system(size: S0HomeMetrics.heroUnitFontSize))
            .foregroundStyle(S0HomePalette.text)
        capsuleButton(title: action, action: handler)
    }

    // MARK: - 玻璃卡与跑道胶囊按钮

    /// 内容玻璃卡。**不复用 chrome 玻璃 helper**——登记表把内容卡另立一族
    /// （`card*` 八个值），与 chrome 玻璃数值不同（G1）。
    @ViewBuilder
    private func glassCard<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: S0HomeMetrics.categoryRowSpacing) {
            content()
        }
        .padding(S1ChromeLayout.horizontalMargin)
        .frame(maxWidth: .infinity, alignment: .leading)
        .s0GlassSurface(
            cornerRadius: S0HomeMetrics.categoryRowCornerRadius,
            ambientImage: ambientReadout.image
        )
    }

    /// 跑道胶囊按钮：高与圆角取 chrome 登记几何，底走 chrome 玻璃 helper
    /// （S0 不自造 chrome 语汇）。
    private func capsuleButton(
        title: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: S1ChromeTypography.titleFontSize))
                .foregroundStyle(S0HomePalette.text)
                .padding(.horizontal, S1ChromeLayout.horizontalMargin)
                .frame(height: S1ChromeLayout.rowHeight)
                .s1ChromeGlassBackground(in: Capsule(), interactive: true)
        }
    }

    // MARK: - 取数

    /// 遵循 E4 口径：测试宿主下不自动启动任何活动。真机与模拟器上首次出现时
    /// 摄入一次数据源的当前结果，并按其回报发一次迁移事件。
    private func bootstrapIfNeeded() {
        guard !hasBootstrapped,
              ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil,
              let provider = dataProvider else {
            return
        }
        hasBootstrapped = true
        machine.ingest(provider.currentSnapshot())
        switch provider.currentScanOutcome() {
        case .scanning:
            machine.handle(.applicationOpened)
        case .completed:
            machine.handle(.scanCompleted)
        case let .failed(category):
            machine.handle(.scanFailed(category))
        }
    }

    /// 氛围底取图。同样遵循 E4 口径（测试宿主下不发 PhotoKit 请求），
    /// 且**一次只取一次**。取不到即纯色回落，不另造回落。
    private func requestAmbientImageIfNeeded() {
        guard !hasRequestedAmbient,
              ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil,
              let provider = ambientImageProvider else {
            return
        }
        hasRequestedAmbient = true
        Task { @MainActor in
            ambientReadout.update(await provider.recentAmbientImage())
        }
    }
}

/// 顶排人像圆钮的系统符号名。集中一处，不散落字面量。
enum S0HomeSymbol {
    static let account = "person.crop.circle"
}

/// 内容玻璃卡的表面：幕底色 + 氛围图的磨砂副本 + 三层高光 + 投影。
///
/// 为什么自己搭而不用系统材质：IC-148 裁定 甲 禁用系统材质（随 trait 变），
/// 而登记表给的 `cardBlurRadius`／`cardSaturation` 正是一层背景磨砂。用同一张
/// 氛围图做磨砂副本，既落实了这两个登记值，又与「恒为深色」不冲突。
/// 取不到图时只剩幕底色——与氛围底同一条回落，不另造。
private struct S0GlassSurface<S: InsettableShape>: ViewModifier {
    let shape: S
    let ambientImage: UIImage?

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    shape.fill(S2AmbientMetrics.baseColor)
                    frost
                }
            }
            .overlay {
                shape.strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(
                                S0HomeMetrics.cardInnerTopOpacity
                            ),
                            Color.white.opacity(
                                S0HomeMetrics.cardInnerBottomOpacity
                            )
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
            }
            .overlay {
                shape.strokeBorder(
                    Color.white.opacity(S0HomeMetrics.cardOuterRingOpacity),
                    lineWidth: 1
                )
            }
            .shadow(
                color: Color.black.opacity(S0HomeMetrics.cardShadowOpacity),
                radius: S0HomeMetrics.cardShadowRadius,
                y: S0HomeMetrics.cardShadowYOffset
            )
    }

    @ViewBuilder
    private var frost: some View {
        if let ambientImage {
            Image(uiImage: ambientImage)
                .resizable()
                .scaledToFill()
                .blur(radius: S0HomeMetrics.cardBlurRadius, opaque: true)
                .saturation(S0HomeMetrics.cardSaturation)
                .clipShape(shape)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

extension View {
    /// 玻璃卡表面。圆角由调用方给（卡、等待清空行、受限提示条各有自己的圆角）。
    func s0GlassSurface(
        cornerRadius: CGFloat,
        ambientImage: UIImage?
    ) -> some View {
        modifier(
            S0GlassSurface(
                shape: RoundedRectangle(
                    cornerRadius: cornerRadius,
                    style: .continuous
                ),
                ambientImage: ambientImage
            )
        )
    }
}
