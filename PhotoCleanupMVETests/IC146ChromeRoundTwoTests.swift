import SwiftUI
import UIKit
import XCTest
@testable import PhotoCleanupMVE

/// IC-146：S2 chrome 二轮——底排改组（相簿跑道圆 + 分享）、氛围底、
/// 「已标记 · 撤销」、退后台停用音频会话。
///
/// 几何断言走**布局模型** `S2OverlayLayoutSnapshot`，不走渲染帧：逐像素比对
/// 渲染结果需要给产品视图加测试专用探针，属「不为测试改产品」禁止项——
/// 该边界由 IC-100 B7 的 `testIC100B7SnapshotMatchesRenderDerivations` 注释
/// 立下并登记在案，本卡沿用同一口径（陷阱 13 的「不是对常量断言」由此满足：
/// 断言对象是布局模型算出的**帧**，不是常量本身）。
final class IC146ChromeRoundTwoTests: XCTestCase {

    // MARK: - 断言 1：底排中位的口径模型

    /// 四种情形：有最近相簿／无最近相簿 × 可用／禁用。
    func testIC146A_AlbumTrackPresentationCoversFourCases() {
        let trackEnabled = S2AlbumTrackPresentation(
            recentAlbumName: "旅行",
            recentAlbumEnabled: true,
            addAlbumEnabled: true
        )
        XCTAssertTrue(trackEnabled.isTrack)
        XCTAssertEqual(trackEnabled.separatorCount, 1)
        XCTAssertEqual(trackEnabled.actionBarButtonCount, 4)

        let trackDisabled = S2AlbumTrackPresentation(
            recentAlbumName: "旅行",
            recentAlbumEnabled: false,
            addAlbumEnabled: false
        )
        // 禁用不改变形态——仍是跑道圆、仍恰 1 条分隔线。
        XCTAssertTrue(trackDisabled.isTrack)
        XCTAssertEqual(trackDisabled.separatorCount, 1)
        XCTAssertEqual(trackDisabled.actionBarButtonCount, 4)

        let circleEnabled = S2AlbumTrackPresentation(
            recentAlbumName: nil,
            recentAlbumEnabled: true,
            addAlbumEnabled: true
        )
        // 规格第 3 条：无最近相簿 ⟹ 单一「+」圆钮，且不含分隔线。
        XCTAssertFalse(circleEnabled.isTrack)
        XCTAssertEqual(circleEnabled.separatorCount, 0)
        XCTAssertEqual(circleEnabled.actionBarButtonCount, 3)

        let circleDisabled = S2AlbumTrackPresentation(
            recentAlbumName: nil,
            recentAlbumEnabled: false,
            addAlbumEnabled: false
        )
        XCTAssertFalse(circleDisabled.isTrack)
        XCTAssertEqual(circleDisabled.separatorCount, 0)
        XCTAssertEqual(circleDisabled.actionBarButtonCount, 3)
    }

    /// 形态判定的权威仍是 `S2ActionBarPresentation.showsRecentAlbum`（A4）：
    /// 该字段为假时即便传进相簿名也退化为圆钮。
    func testIC146A_TrackFormFollowsActionBarPresentationAuthority() {
        let machine = makeStateMachine()
        let bar = S2ActionBarPresentation(machine: machine)
        XCTAssertFalse(bar.showsRecentAlbum, "夹具默认无最近相簿")

        let derived = S2AlbumTrackPresentation(
            presentation: bar,
            recentAlbumName: "不该被采纳"
        )
        XCTAssertNil(derived.recentAlbumName)
        XCTAssertFalse(derived.isTrack)

        // A4：三条既有启用规则零语义变化，新增的 shareEnabled 与整排同口径。
        XCTAssertTrue(bar.favoriteEnabled)
        XCTAssertTrue(bar.recentAlbumEnabled)
        XCTAssertTrue(bar.addAlbumEnabled)
        XCTAssertTrue(bar.shareEnabled)
    }

    // MARK: - 断言 2：命中区与按钮数

    func testIC146A_TrackHalvesAndShareCarryTouchTargets() throws {
        // 右半与整只跑道圆的高都不小于最小触控边长。
        XCTAssertGreaterThanOrEqual(
            S2MediaMetrics.albumTrackTrailingHalfWidth,
            S2OverlayLayout.minimumTouchTarget
        )
        XCTAssertGreaterThanOrEqual(
            S2ChromePillMetrics.pillHeight,
            S2OverlayLayout.minimumTouchTarget
        )

        let source = try XCTUnwrap(
            sourceText("PhotoCleanupMVE/Features/S2/S2View.swift")
        )
        let row = try XCTUnwrap(
            slice(
                source,
                from: "    private var actionBarRow: some View {",
                to: "    private var favoriteActionTitle: String {"
            )
        )
        // 四个动作各一只 Button（收藏、跑道左半、选择器、分享）；
        // 选择器那只由 `albumPickerButton(inTrack:)` 统一提供，
        // 跑道形态与退化形态共用同一个定义，故源码计数恰 4。
        XCTAssertEqual(occurrences(of: "Button {", in: row), 4)

        // 左半给了宽度下限，极短相簿名也不会把命中区挤到 44 以下。
        XCTAssertEqual(
            occurrences(
                of: ".frame(minWidth: S2OverlayLayout.minimumTouchTarget)",
                in: row
            ),
            1
        )
        // 两半与分享各自独立命中。
        XCTAssertGreaterThanOrEqual(
            occurrences(of: ".contentShape(Rectangle())", in: row),
            2
        )
        // 正对照：四个动作的文案 key 各出现恰 1 次，没有第五个动作混进底排。
        for key in [
            "s2.action.add_recent_album",
            "s2.action.add_album",
            "s2.action.share"
        ] {
            XCTAssertEqual(
                occurrences(of: "\"" + key + "\"", in: source),
                1,
                key + " 在 S2View.swift 内不是恰 1 处"
            )
        }
    }

    // MARK: - 断言 3：底排几何不变

    /// 行高、左右边距、底缘锚、`minimumSpacing` 四项逐个核对。
    /// 断言对象是布局模型算出的**帧**（见类注释的口径说明）。
    func testIC146A_ActionBandGeometryUnchanged() {
        let snapshot = overlaySnapshot(showsRecentAlbumAction: true)
        let frames = snapshot.bottomElementFrames
        XCTAssertEqual(frames.count, 4, "三件 + 横栏")
        let leading = frames[0]
        let middle = frames[1]
        let trailing = frames[2]
        let viewportBottom = overlayPhysicalSize.height

        // 行高 44。
        for frame in [leading, middle, trailing] {
            XCTAssertEqual(
                frame.height,
                S2OverlayLayout.chromeRowHeight,
                accuracy: 0.000_001
            )
        }
        // 左右边距 16。
        XCTAssertEqual(
            leading.minX - overlaySafeAreaInsets.leading,
            S2OverlayLayout.chromeHorizontalMargin,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            overlayPhysicalSize.width - overlaySafeAreaInsets.trailing -
                trailing.maxX,
            S2OverlayLayout.chromeHorizontalMargin,
            accuracy: 0.000_001
        )
        // 底缘锚：下缘距视口底 = 安全区底 + 8。
        for frame in [leading, middle, trailing] {
            XCTAssertEqual(
                viewportBottom - frame.maxY,
                S2OverlayLayout.actionBandBottomFromViewportBottom(
                    safeAreaBottom: overlaySafeAreaInsets.bottom
                ),
                accuracy: 0.000_001
            )
        }
        // 件间距 = minimumSpacing。
        XCTAssertEqual(
            middle.minX - leading.maxX,
            S2OverlayLayout.minimumSpacing,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            trailing.minX - middle.maxX,
            S2OverlayLayout.minimumSpacing,
            accuracy: 0.000_001
        )
        // 决策 33 的底部纵向顺序：横栏在底排上方。
        XCTAssertLessThan(frames[3].maxY, leading.minY)
    }

    // MARK: - 断言 5：残影落点 = 跑道圆左半中心

    /// 落点等于左半中心；**且与相簿名长短无关**——跑道圆水平居中于可用区间，
    /// 内容驱动的左半宽在推导中约去。该恒等式不成立即说明居中前提被破坏。
    func testIC146A_AfterimageLandsOnTrackRecentHalfCenter() {
        let viewportSize = overlayPhysicalSize
        let insets = overlaySafeAreaInsets
        let landing = S2AlbumAfterimageFlight.bottomCapsuleCenter(
            viewportSize: viewportSize,
            safeAreaInsets: insets
        )

        // 可用区间 = 两圆钮之间，各留 minimumSpacing。
        let minX = insets.leading
        let maxX = viewportSize.width - insets.trailing
        let slotMinX = minX + S2OverlayLayout.chromeHorizontalMargin +
            S2OverlayLayout.chromeRowHeight + S2OverlayLayout.minimumSpacing
        let slotMaxX = maxX - S2OverlayLayout.chromeHorizontalMargin -
            S2OverlayLayout.chromeRowHeight - S2OverlayLayout.minimumSpacing
        let slotCenterX = (slotMinX + slotMaxX) / 2

        // 不变量：极短与极长相簿名给出同一个左半中心。
        let shortName = S2MediaMetrics.albumTrackRecentHalfCenterX(
            slotMinX: slotMinX,
            slotMaxX: slotMaxX,
            recentHalfWidth: S2OverlayLayout.minimumTouchTarget
        )
        let longName = S2MediaMetrics.albumTrackRecentHalfCenterX(
            slotMinX: slotMinX,
            slotMaxX: slotMaxX,
            recentHalfWidth: 300
        )
        XCTAssertEqual(
            shortName,
            longName,
            accuracy: 0.000_001,
            "落点随相簿名长短漂移 ⟹ 跑道圆的居中前提被破坏"
        )

        // 落点 = 左半中心。
        XCTAssertEqual(landing.x, shortName, accuracy: 0.000_001)
        XCTAssertEqual(
            landing.x,
            slotCenterX + S2MediaMetrics.albumTrackRecentHalfCenterOffsetX,
            accuracy: 0.000_001
        )
        // 正对照：不等于整只跑道圆中心。
        XCTAssertNotEqual(landing.x, slotCenterX, accuracy: 0.5)
        XCTAssertLessThan(landing.x, slotCenterX, "左半在整只中心之左")

        // 纵向锚不变：底排中心距视口底。
        XCTAssertEqual(
            viewportSize.height - landing.y,
            S2OverlayLayout.actionBandCenterFromViewportBottom(
                safeAreaBottom: insets.bottom
            ),
            accuracy: 0.000_001
        )
    }

    // MARK: - 断言 4：分享不改任何状态

    /// 分享呈现态是**视图层状态**，不碰状态机也不碰两台播放 reducer——
    /// 结构上就不可能改 `V`、`s`、`c`、`D` 或播放状态。本断言走完整序列
    /// （按下 → 取到 URL → 关闭）后逐项复核。
    ///
    /// 夹具驱动：真实的系统面板呈现与关闭由 H69 第 2 项兜底（陷阱 1）。
    func testIC146A_ShareLeavesEveryStateUntouched() throws {
        let machine = makeStateMachine()
        _ = machine.handleSwipeUp()
        let visibilityBefore = machine.interfaceVisibility
        let scaleBefore = machine.scale
        let indexBefore = machine.currentIndex
        let pendingBefore = machine.pendingDeletionAssetIDs
        let assetIDBefore = machine.currentAssetID

        let video = S2VideoPlaybackMachine()
        let live = S2LivePhotoPlaybackMachine()
        let videoStatesBefore = video.states
        let liveStatesBefore = live.states

        var preparation = S2SharePreparation()
        XCTAssertFalse(preparation.isResolving)
        XCTAssertFalse(preparation.isPresenting)

        XCTAssertTrue(preparation.begin(assetID: assetIDBefore))
        XCTAssertTrue(preparation.isResolving)
        // 不重入：取项途中再按一次无效。
        XCTAssertFalse(preparation.begin(assetID: assetIDBefore))

        let url = URL(fileURLWithPath: "/tmp/ic146-share-fixture.heic")
        preparation.resolved(assetID: assetIDBefore, url: url)
        XCTAssertTrue(preparation.isPresenting)
        XCTAssertEqual(preparation.payload?.url, url)
        XCTAssertEqual(preparation.payload?.assetID, assetIDBefore)

        preparation.dismiss()
        XCTAssertFalse(preparation.isPresenting)
        XCTAssertFalse(preparation.isResolving)

        // V、s、c、D 逐项不变。
        XCTAssertEqual(machine.interfaceVisibility, visibilityBefore)
        XCTAssertEqual(machine.scale, scaleBefore)
        XCTAssertEqual(machine.currentIndex, indexBefore)
        XCTAssertEqual(machine.pendingDeletionAssetIDs, pendingBefore)
        // 两台播放 reducer 无任何效果产生。
        XCTAssertEqual(video.states, videoStatesBefore)
        XCTAssertEqual(live.states, liveStatesBefore)
        XCTAssertFalse(video.isUnmutedByUser)
    }

    /// 取项失败与「期间翻了页」两条边角：一律回闲置，不呈现面板。
    func testIC146A_ShareDiscardsFailedAndStaleResolutions() {
        var failed = S2SharePreparation()
        XCTAssertTrue(failed.begin(assetID: "asset-1"))
        failed.resolved(assetID: "asset-1", url: nil)
        XCTAssertFalse(failed.isPresenting)
        XCTAssertFalse(failed.isResolving, "取不到就回闲置，可以再按")
        XCTAssertTrue(failed.begin(assetID: "asset-1"))

        var stale = S2SharePreparation()
        XCTAssertTrue(stale.begin(assetID: "asset-1"))
        // 期间翻到了别的资产：迟到的结果一律丢弃，只分享当时那一张。
        stale.resolved(
            assetID: "asset-2",
            url: URL(fileURLWithPath: "/tmp/other.heic")
        )
        XCTAssertFalse(stale.isPresenting)
        XCTAssertTrue(stale.isResolving, "仍在等 asset-1 的结果")
    }

    // MARK: - 断言 6：层次与命中

    /// 氛围底在主图之下、`interfaceOverlay` 之上的次序不变；氛围底不接触控；
    /// 分页器各层仍 `.clear`。
    func testIC146B_AmbientSitsBelowPhotoAndTakesNoTouches() throws {
        let view = try XCTUnwrap(
            sourceText("PhotoCleanupMVE/Features/S2/S2View.swift")
        )
        let ambientIndex = try XCTUnwrap(
            view.range(of: "S2AmbientBackdropView(readout:")
        ).lowerBound
        let photoIndex = try XCTUnwrap(
            view.range(of: "mainPhoto(\n", range: ambientIndex..<view.endIndex)
        ).lowerBound
        let overlayIndex = try XCTUnwrap(
            view.range(
                of: "interfaceOverlay(\n",
                range: photoIndex..<view.endIndex
            )
        ).lowerBound
        // ZStack 内自下而上：氛围底 → 主图 → interfaceOverlay。
        XCTAssertLessThan(ambientIndex, photoIndex)
        XCTAssertLessThan(photoIndex, overlayIndex)
        // 旧的视口底色层已不在 ZStack 里（决策 61 的唯一落点已替换）。
        XCTAssertEqual(
            occurrences(of: "S2ViewportBackground.color\n", in: view),
            0
        )

        let ambient = try XCTUnwrap(
            sourceText("PhotoCleanupMVE/Features/S2/S2AmbientBackdrop.swift")
        )
        // 规格第 12 条：不接触控。
        XCTAssertEqual(
            occurrences(of: ".allowsHitTesting(false)", in: ambient),
            1
        )

        // 分页器各层仍 .clear，计数与改前相同（B3：本卡不得改这些）。
        let pager = try XCTUnwrap(
            sourceText("PhotoCleanupMVE/Features/S2/S2NativePhotoPager.swift")
        )
        XCTAssertEqual(
            occurrences(of: "backgroundColor = .clear", in: pager),
            7
        )
        XCTAssertEqual(occurrences(of: ".clear", in: pager), 8)
    }

    // MARK: - 断言 7：零几何写入

    /// 氛围底是 ZStack 里的一层兄弟，**不碰几何链**：几何链的声明与调用点
    /// 数量仍为 5（口径沿 IC-141 断言 5）。
    ///
    /// 结构性保证：氛围底的读数是独立的 `ObservableObject`，只有氛围底视图
    /// 观察它——协调器自身不发布任何变更，故换图不会让 `S2View.body` 重算，
    /// 也就不会经 `updateUIViewController` 重进分页器（陷阱 5）。
    func testIC146B_AmbientAddsNoGeometryWrite() throws {
        let pager = try XCTUnwrap(
            sourceText("PhotoCleanupMVE/Features/S2/S2NativePhotoPager.swift")
        )
        XCTAssertEqual(
            occurrences(of: "writePhotoGeometry", in: pager),
            5,
            "几何链的声明或调用点数量变了"
        )

        let ambient = try XCTUnwrap(
            sourceText("PhotoCleanupMVE/Features/S2/S2AmbientBackdrop.swift")
        )
        // 氛围底一侧不得出现任何几何写入或分页器引用。
        XCTAssertEqual(occurrences(of: "writePhotoGeometry", in: ambient), 0)
        XCTAssertEqual(occurrences(of: "S2NativePager", in: ambient), 0)
        // 协调器自身不发布：`@Published` 只出现在读数类型里，恰 1 处。
        XCTAssertEqual(occurrences(of: "@Published", in: ambient), 1)
    }

    // MARK: - 断言 8：取值引用 SPEC-S0 v1 S0Ambient

    func testIC146B_AmbientMetricsMatchS0AmbientRegistry() throws {
        XCTAssertEqual(S2AmbientMetrics.blurRadius, 34, accuracy: 0.000_001)
        XCTAssertEqual(S2AmbientMetrics.saturation, 1.15, accuracy: 0.000_001)
        XCTAssertEqual(S2AmbientMetrics.opacity, 0.62, accuracy: 0.000_001)
        XCTAssertEqual(
            S2AmbientMetrics.veilTopOpacity,
            0.30,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            S2AmbientMetrics.veilMidOpacity,
            0.66,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            S2AmbientMetrics.veilBottomOpacity,
            0.94,
            accuracy: 0.000_001
        )
        XCTAssertEqual(S2AmbientMetrics.tintRadius, 0.70, accuracy: 0.000_001)
        XCTAssertEqual(S2AmbientMetrics.tintOpacity, 0.30, accuracy: 0.000_001)
        XCTAssertEqual(S2AmbientMetrics.grainOpacity, 0.90, accuracy: 0.000_001)
        // ambientBaseColor = #050507。
        let base = UIColor(S2AmbientMetrics.baseColor)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        XCTAssertTrue(base.getRed(&red, green: &green, blue: &blue, alpha: &alpha))
        XCTAssertEqual(red * 255, 5, accuracy: 0.6)
        XCTAssertEqual(green * 255, 5, accuracy: 0.6)
        XCTAssertEqual(blue * 255, 7, accuracy: 0.6)
        XCTAssertEqual(alpha, 1, accuracy: 0.000_001)

        let ambient = try XCTUnwrap(
            sourceText("PhotoCleanupMVE/Features/S2/S2AmbientBackdrop.swift")
        )
        // 每个常量的定义处都写明出处（十个量 + 幕底色共十处以上）。
        XCTAssertGreaterThanOrEqual(
            occurrences(of: "取值出处：SPEC-S0 v1 第十四节", in: ambient),
            10
        )
        // 正对照：视图体内一个裸数都不写，全部经 `S2AmbientMetrics`。
        let viewBody = try XCTUnwrap(
            slice(
                ambient,
                from: "struct S2AmbientBackdropView: View {",
                to: "\n}\n"
            )
        )
        for bare in ["34", "1.15", "0.62", "0.66", "0.94", "0.70", "0.90"] {
            XCTAssertEqual(
                occurrences(of: bare, in: viewBody),
                0,
                "氛围底视图体内出现裸数 " + bare
            )
        }
    }

    // MARK: - 断言 9：外观不跟随

    /// 决策 61：氛围底恒为深色配方，不随系统外观切换。
    func testIC146B_AmbientRecipeIsIdenticalInBothColorSchemes() throws {
        let base = UIColor(S2AmbientMetrics.baseColor)
        let dark = base.resolvedColor(
            with: UITraitCollection(userInterfaceStyle: .dark)
        )
        let light = base.resolvedColor(
            with: UITraitCollection(userInterfaceStyle: .light)
        )
        XCTAssertEqual(dark, light, "幕底色随外观解析出了两个值")

        let ambient = try XCTUnwrap(
            sourceText("PhotoCleanupMVE/Features/S2/S2AmbientBackdrop.swift")
        )
        // 配方里不得出现任何随外观解析的色源。
        for dynamic in [
            "colorScheme",
            "systemBackground",
            "UIColor.label",
            ".primary",
            "S2ChromeForeground"
        ] {
            XCTAssertEqual(
                occurrences(of: dynamic, in: ambient),
                0,
                "氛围底引用了随外观变化的 " + dynamic
            )
        }
    }

    // MARK: - 断言 10：取图失败回落

    /// 取不到源图 ⟹ 氛围底为 `ambientBaseColor` 纯色（读数为 nil），
    /// 且**主图呈现不被延迟**——`load` 同步返回，取图在独立任务里做。
    @MainActor
    func testIC146B_AmbientFallsBackToBaseColorWhenLoadFails() async {
        let store = S2AmbientBackdropStore()
        let loader = S2AmbientLoaderStub(image: nil)

        XCTAssertNil(store.readout.image, "关闭态零副作用：未取图前就是纯色")
        XCTAssertEqual(loader.requestCount, 0, "init 不得发请求")

        store.load(assetID: "asset-1", using: loader)
        // 同步返回，读数仍是纯色——主图呈现不等氛围底。
        XCTAssertNil(store.readout.image)
        XCTAssertEqual(store.loadedAssetID, "asset-1")

        let settled = await waitUntil { store.failureCount == 1 }
        XCTAssertTrue(settled, "取图任务未在期限内收口")
        XCTAssertEqual(loader.requestCount, 1)
        XCTAssertNil(store.readout.image, "取图失败后仍是纯色回落")

        // 同一张不重复取图。
        store.load(assetID: "asset-1", using: loader)
        XCTAssertEqual(loader.requestCount, 1)

        // 换张即重新取；取到图则读数变为该图。
        let image = UIImage()
        let second = S2AmbientLoaderStub(image: image)
        store.load(assetID: "asset-2", using: second)
        XCTAssertNil(store.readout.image, "切换瞬间先回落，不留上一张的图")
        let arrived = await waitUntil { store.readout.image != nil }
        XCTAssertTrue(arrived, "第二张的氛围底未在期限内到达")
        XCTAssertTrue(store.readout.image === image)
        XCTAssertEqual(store.failureCount, 1, "成功一次不计失败")
    }

    // MARK: - 断言 11：`.marked` 形态

    /// 决策 62：`.marked` 由正圆单图标改为胶囊——图标、「已标记」、分隔线、
    /// 「撤销」四件齐全，与 `.addedToAlbum` 同构。
    func testIC146C_MarkedBecomesCapsuleWithUndo() throws {
        XCTAssertTrue(S2CenterIndicatorView.showsUndoControl(for: .marked))
        XCTAssertTrue(
            S2CenterIndicatorView.showsUndoControl(
                for: .addedToAlbum(albumName: "旅行")
            )
        )
        // 正对照：`.removed` 仍为单段文本、无撤销钮。
        XCTAssertFalse(
            S2CenterIndicatorView.showsUndoControl(
                for: .removed(albumName: "旅行")
            )
        )

        let view = try XCTUnwrap(
            sourceText("PhotoCleanupMVE/Features/S2/S2View.swift")
        )
        // 锚点取 `content` 的声明行：`        case .marked:` 会被分派处
        // 那只缩进更深的 switch 抢先命中（它把前者整个包含为子串）。
        let markedCase = try XCTUnwrap(
            slice(
                view,
                from: "    private var content: some View {",
                to: "        case let .addedToAlbum(albumName):"
            )
        )
        for piece in [
            "solidCircle(systemName: \"trash.fill\")",
            "\"s2.center.marked\"",
            "Self.separator(color: Self.separatorColor)",
            "\"s2.center.undo\"",
            "Capsule().fill(Self.backgroundColor)"
        ] {
            XCTAssertTrue(
                markedCase.contains(piece),
                ".marked 形态缺 " + piece
            )
        }

        // 正对照：`.removed` 分支既无分隔线也无撤销钮。
        let removedCase = try XCTUnwrap(
            slice(
                view,
                from: "        case let .removed(albumName):",
                to: "\n        }\n    }\n}"
            )
        )
        XCTAssertFalse(removedCase.contains("Self.separator("))
        XCTAssertFalse(removedCase.contains("\"s2.center.undo\""))
    }

    // MARK: - 断言 12：撤销走下滑取消的同一入口

    func testIC146C_MarkedUndoCallsTheSameSwipeDownEntry() throws {
        let view = try XCTUnwrap(
            sourceText("PhotoCleanupMVE/Features/S2/S2View.swift")
        )
        let undoMark = try XCTUnwrap(
            slice(
                view,
                from: "    private func undoMarkFromCenterIndicator() {",
                to: "    /// IC-113 B：点撤回"
            )
        )
        // 调的就是下滑那条路径的同一个入口函数，恰 1 处。
        XCTAssertEqual(
            occurrences(of: "machine.handleSwipeDown()", in: undoMark),
            1
        )
        // 正对照：相簿撤回不得出现在 `.marked` 路径里。
        XCTAssertEqual(
            occurrences(
                of: "undoAlbumAdditionFromCenterIndicator",
                in: undoMark
            ),
            0
        )

        // 手势侧的下滑取消也只调那一个函数，且该入口全仓唯一一个。
        let machineSource = try XCTUnwrap(
            sourceText("PhotoCleanupMVE/Core/S2StateMachine.swift")
        )
        XCTAssertEqual(
            occurrences(of: "? handleSwipeDown()", in: machineSource),
            1
        )
        XCTAssertEqual(
            occurrences(of: "func handleSwipeDown()", in: machineSource),
            1,
            "下滑取消的入口函数不是唯一一个"
        )
    }

    // MARK: - 断言 13：撤销后行为

    /// 撤销成功 ⟹ 当前张的标记已取消、`D` 减一、指示复算为 nil（整块消失），
    /// **不产生 `.removed` 态**。
    func testIC146C_MarkedUndoClearsMarkAndProducesNoRemovedNotice() throws {
        // 停在最后一张：上滑标记后翻不动，当前张即被标记那张。
        let machine = makeStateMachine(currentIndex: 2)
        XCTAssertTrue(machine.handleSwipeUp())
        let markedAssetID = machine.currentAssetID
        XCTAssertTrue(machine.currentIsMarked)
        XCTAssertTrue(machine.pendingDeletionAssetIDs.contains(markedAssetID))
        let countBefore = machine.pendingDeletionAssetIDs.count

        XCTAssertEqual(
            S2CenterIndicatorResolver.state(
                interfaceVisibility: machine.interfaceVisibility,
                isMarked: machine.currentIsMarked,
                addedAlbumName: nil,
                lastAction: .mark
            ),
            .marked
        )

        // 点「撤销」= 下滑取消（同一个入口函数）。
        XCTAssertTrue(machine.handleSwipeDown())
        XCTAssertFalse(machine.currentIsMarked)
        XCTAssertFalse(machine.pendingDeletionAssetIDs.contains(markedAssetID))
        XCTAssertEqual(machine.pendingDeletionAssetIDs.count, countBefore - 1)
        // 整块消失：复算为 nil，而不是 `.removed`。
        XCTAssertNil(
            S2CenterIndicatorResolver.state(
                interfaceVisibility: machine.interfaceVisibility,
                isMarked: machine.currentIsMarked,
                addedAlbumName: nil,
                lastAction: nil
            )
        )

        let view = try XCTUnwrap(
            sourceText("PhotoCleanupMVE/Features/S2/S2View.swift")
        )
        let undoMark = try XCTUnwrap(
            slice(
                view,
                from: "    private func undoMarkFromCenterIndicator() {",
                to: "    /// IC-113 B：点撤回"
            )
        )
        XCTAssertEqual(occurrences(of: ".removed(", in: undoMark), 0)

        // 正对照：相簿撤回仍产生 `.removed` 短提示。
        let undoAlbum = try XCTUnwrap(
            slice(
                view,
                from: "    private func undoAlbumAdditionFromCenterIndicator() {",
                to: "    private func refreshCenterIndicator"
            )
        )
        XCTAssertGreaterThanOrEqual(
            occurrences(of: ".removed(albumName:", in: undoAlbum),
            1
        )
    }

    // MARK: - 断言 14：既有口径不变

    func testIC146C_ExistingIndicatorValuesAreUntouched() {
        XCTAssertEqual(
            S2CenterIndicatorResolver.transitionSeconds,
            0.2,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            S2CenterIndicatorResolver.hiddenScale,
            0.9,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            S2CenterIndicatorResolver.removedNoticeSeconds,
            1.2,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            S2CenterIndicatorResolver.albumIndicatorDelaySeconds,
            0.42,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            S2CenterIndicatorView.containerHeight,
            46,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            S2CenterIndicatorView.horizontalPadding,
            12,
            accuracy: 0.000_001
        )
        // 分隔线白 30%；底色与前景仍取待删标记的同源常量。
        XCTAssertEqual(
            UIColor(S2CenterIndicatorView.separatorColor),
            UIColor(Color.white.opacity(0.3))
        )
        XCTAssertEqual(
            UIColor(S2CenterIndicatorView.backgroundColor),
            UIColor(S2PendingDeletionMark.circleColor)
        )
        XCTAssertEqual(
            UIColor(S2CenterIndicatorView.foregroundColor),
            UIColor(S2PendingDeletionMark.symbolColor)
        )
        // 决策 46 既有规则：V=隐藏 一律不显示。
        XCTAssertNil(
            S2CenterIndicatorResolver.state(
                interfaceVisibility: .hidden,
                isMarked: true,
                addedAlbumName: nil,
                lastAction: .mark
            )
        )
    }

    // MARK: - 夹具

    private let overlayPhysicalSize = CGSize(width: 393, height: 852)
    private let overlaySafeAreaInsets = S2OverlaySafeAreaInsets(
        top: 59,
        leading: 0,
        bottom: 34,
        trailing: 0
    )

    private func overlaySnapshot(
        showsRecentAlbumAction: Bool
    ) -> S2OverlayLayoutSnapshot {
        S2OverlayLayout.snapshot(
            physicalSize: overlayPhysicalSize,
            safeAreaInsets: overlaySafeAreaInsets,
            bottomStripHeight: 64,
            showsRecentAlbumAction: showsRecentAlbumAction,
            calibrationState: S2CalibrationOverlayState.initial
        )
    }

    private func makeStateMachine(
        orderedAssetIDs: [String] = ["asset-1", "asset-2", "asset-3"],
        currentIndex: Int = 1
    ) -> S2StateMachine {
        let configuration = S2CalibrationConfiguration.factoryPlaceholder
        let resolvedIndex = min(max(0, currentIndex), orderedAssetIDs.count - 1)
        return S2StateMachine(
            entry: S2EntryContext(
                sessionID: "session-146",
                rangeDisplayInformation: S2RangeDisplayInformation(
                    rangeID: "range-146",
                    displayName: "IC-146",
                    totalAssetCount: orderedAssetIDs.count
                ),
                orderedAssetIDs: orderedAssetIDs,
                currentAssetID: orderedAssetIDs[resolvedIndex],
                pendingDeletionAssetIDs: [],
                sessionMergedPendingDeletionCountProvider: { 0 }
            ),
            initialPresentation: S2InitialPresentation(
                interfaceVisibility: .visible,
                scale: 1,
                viewportOffset: .zero
            ),
            parameters: configuration.resolvedParameters!,
            imageRequestStrategy: configuration.imageRequestStrategy,
            initialFavoriteAssetIDs: [],
            initialRecentAlbum: nil,
            pendingDeletionDidChange: { _ in }
        )!
    }

    /// 氛围底取图桩。计数用锁保护——`load` 的取图调用不保证落在主线程
    /// （陷阱 10：并发驱动的 helper 必须并发安全）。
    private final class S2AmbientLoaderStub: S2AmbientImageLoading {
        private let image: UIImage?
        private let lock = NSLock()
        private var count = 0

        init(image: UIImage?) {
            self.image = image
        }

        var requestCount: Int {
            lock.lock()
            defer { lock.unlock() }
            return count
        }

        func ambientImage(assetID _: String) async -> UIImage? {
            lock.lock()
            count += 1
            lock.unlock()
            return image
        }
    }

    /// 有界轮询等待。异步收口的到达时机不由测试掌控，故给期限而不是数让出次数。
    private func waitUntil(
        timeout: TimeInterval = 2,
        _ condition: @escaping () -> Bool
    ) async -> Bool {
        let deadline = Date(timeIntervalSinceNow: timeout)
        while Date() < deadline {
            if condition() {
                return true
            }
            await Task.yield()
        }
        return condition()
    }

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
}
