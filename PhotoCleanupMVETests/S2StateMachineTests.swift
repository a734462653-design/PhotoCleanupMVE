import CoreGraphics
import XCTest
@testable import PhotoCleanupMVE

final class S2StateMachineTests: XCTestCase {
    // IC047-001：六个基础状态均可由正交变量与横栏事件到达。
    func testIC047_001AllSixStatesAreReachable() {
        for state in S2State.allCases {
            XCTAssertEqual(makeMachine(state: state).state, state)
        }
    }

    // IC047-002：迁移表的从 S1 进入事件仅可从页面外发生。
    func testIC047_002TransitionRowEnterFromS1() {
        assertTransitionRow(
            .enterFromS1,
            [conditionalDynamic, unavailable, unavailable, unavailable,
             unavailable, unavailable, unavailable]
        )
    }

    // IC058：迁移表的单击事件在 1x 与 Nx 均切换显隐。
    func testIC047_003TransitionRowSingleTap() {
        assertTransitionRow(
            .singleTapMainImage,
            [unavailable, availableState(.hiddenOneX), unavailable,
             availableState(.visibleOneXIdle), availableState(.hiddenNx),
             unavailable, availableState(.visibleNxIdle)]
        )

        let visible = makeMachine(state: .visibleOneXIdle)
        XCTAssertTrue(visible.handleSingleTap())
        XCTAssertEqual(visible.state, .hiddenOneX)

        let zoomed = makeMachine(state: .visibleNxIdle)
        XCTAssertTrue(zoomed.handleSingleTap())
        XCTAssertEqual(zoomed.state, .hiddenNx)
    }

    // IC047-004：迁移表的双击事件逐格进入或退出对应显隐层。
    func testIC047_004TransitionRowDoubleTap() {
        assertTransitionRow(
            .doubleTapMainImage,
            [unavailable, availableState(.visibleNxIdle), unavailable,
             availableState(.hiddenNx), availableState(.visibleOneXIdle),
             unavailable, availableState(.hiddenOneX)]
        )

        let machine = makeMachine(state: .visibleOneXIdle)
        XCTAssertTrue(doubleTap(machine))
        XCTAssertEqual(machine.state, .visibleNxIdle)
        XCTAssertTrue(doubleTap(machine))
        XCTAssertEqual(machine.state, .visibleOneXIdle)
    }

    // IC047-005：迁移表的捏合事件在四个非横栏状态按结束倍数动态迁移。
    func testIC047_005TransitionRowPinch() {
        assertTransitionRow(
            .pinchMainImage,
            [unavailable, conditionalDynamic, unavailable,
             conditionalDynamic, conditionalDynamic, unavailable,
             conditionalDynamic]
        )

        let machine = makeMachine(state: .hiddenOneX)
        XCTAssertTrue(machine.beginPinch())
        XCTAssertTrue(machine.updatePinch(
            magnification: 2,
            viewportSize: viewportSize,
            fittedSize: fittedSize
        ))
        XCTAssertTrue(machine.endPinch(
            viewportSize: viewportSize,
            fittedSize: fittedSize
        ))
        XCTAssertEqual(machine.state, .hiddenNx)
    }

    // IC059：迁移表的上滑事件在 1x 标记，并在 Nx 标记后归一。
    func testIC047_006TransitionRowSwipeUp() {
        assertTransitionRow(
            .swipeUpMainImage,
            [unavailable, conditionalSame, unavailable, conditionalSame,
             conditionalDynamic, unavailable, conditionalDynamic]
        )

        let machine = makeMachine(state: .visibleOneXIdle)
        XCTAssertTrue(machine.handleSwipeUp())
        XCTAssertTrue(machine.pendingDeletionAssetIDs.contains("asset-2"))
        XCTAssertEqual(machine.currentAssetID, "asset-3")
        XCTAssertEqual(machine.state, .visibleOneXIdle)
    }

    // IC047-007：迁移表的下滑事件只取消当前照片标记且不跳转。
    func testIC047_007TransitionRowSwipeDown() {
        assertTransitionRow(
            .swipeDownMainImage,
            [unavailable, conditionalSame, unavailable, conditionalSame,
             conditionalSame, unavailable, conditionalSame]
        )

        let machine = makeMachine(
            state: .hiddenOneX,
            pendingDeletionAssetIDs: ["asset-2"]
        )
        XCTAssertTrue(machine.handleSwipeDown())
        XCTAssertFalse(machine.pendingDeletionAssetIDs.contains("asset-2"))
        XCTAssertEqual(machine.currentAssetID, "asset-2")
        XCTAssertEqual(machine.state, .hiddenOneX)
    }

    // IC047-008：迁移表的左右滑事件在 1x 翻页，在 Nx 受贴边条件约束。
    func testIC047_008TransitionRowHorizontalSwipe() {
        assertTransitionRow(
            .horizontalSwipeMainImage,
            [unavailable, conditionalSame, unavailable, conditionalSame,
             conditionalDynamic, unavailable, conditionalDynamic]
        )

        let oneX = makeMachine(state: .visibleOneXIdle)
        XCTAssertTrue(oneX.handleHorizontalSwipe(
            direction: .next,
            startedAtPagingEdge: false,
            distance: 0,
            velocity: 0
        ))
        XCTAssertEqual(oneX.currentAssetID, "asset-3")

        let nX = makeMachine(state: .visibleNxIdle)
        XCTAssertFalse(nX.handleHorizontalSwipe(
            direction: .next,
            startedAtPagingEdge: false,
            distance: 100,
            velocity: 1_000
        ))
        XCTAssertEqual(nX.currentAssetID, "asset-2")
    }

    // IC047-009：迁移表的未翻页拖动在 1x 不平移，在 Nx 只更新视口。
    func testIC047_009TransitionRowMainDragWithoutPaging() {
        assertTransitionRow(
            .dragMainImageWithoutPaging,
            [unavailable, availableSame, unavailable, availableSame,
             availableSame, unavailable, availableSame]
        )

        let oneX = makeMachine(state: .visibleOneXIdle)
        XCTAssertFalse(oneX.updateMainPan(
            from: .zero,
            translation: CGSize(width: 30, height: 20),
            viewportSize: viewportSize,
            fittedSize: fittedSize
        ))
        XCTAssertEqual(oneX.viewportOffset, .zero)

        let nX = makeMachine(state: .visibleNxIdle)
        XCTAssertTrue(nX.updateMainPan(
            from: .zero,
            translation: CGSize(width: 30, height: 20),
            viewportSize: viewportSize,
            fittedSize: fittedSize
        ))
        XCTAssertEqual(nX.viewportOffset, CGSize(width: 30, height: 20))
        XCTAssertEqual(nX.state, .visibleNxIdle)
    }

    // IC047-010：迁移表的开始横栏拖动事件只从两个显示静止态进入。
    func testIC047_010TransitionRowBeginBottomStripDrag() {
        assertTransitionRow(
            .beginBottomStripDrag,
            [unavailable, availableState(.visibleOneXStripDragging),
             unavailable, unavailable,
             availableState(.visibleNxStripDragging), unavailable,
             unavailable]
        )

        let oneX = makeMachine(state: .visibleOneXIdle)
        XCTAssertTrue(oneX.beginBottomStripDrag())
        XCTAssertEqual(oneX.state, .visibleOneXStripDragging)

        let hidden = makeMachine(state: .hiddenOneX)
        XCTAssertFalse(hidden.beginBottomStripDrag())
        XCTAssertEqual(hidden.state, .hiddenOneX)
    }

    // IC047-011：迁移表的横栏换片事件同步更新主图并把 Nx 重置为 1x。
    func testIC047_011TransitionRowChangePhotoDuringBottomStripDrag() {
        assertTransitionRow(
            .changeCurrentPhotoDuringBottomStripDrag,
            [unavailable, unavailable, availableSame, unavailable,
             unavailable, availableState(.visibleOneXStripDragging),
             unavailable]
        )

        let machine = makeMachine(state: .visibleNxStripDragging)
        XCTAssertTrue(machine.changeCurrentPhotoDuringBottomStripDrag(by: 1))
        XCTAssertEqual(machine.currentAssetID, "asset-3")
        XCTAssertEqual(machine.scale, 1)
        XCTAssertEqual(machine.state, .visibleOneXStripDragging)
    }

    // IC047-012：迁移表的结束横栏拖动事件回到相应静止态。
    func testIC047_012TransitionRowEndBottomStripDrag() {
        assertTransitionRow(
            .endBottomStripDrag,
            [unavailable, unavailable, availableState(.visibleOneXIdle),
             unavailable, unavailable, availableState(.visibleNxIdle),
             unavailable]
        )

        let machine = makeMachine(state: .visibleNxStripDragging)
        XCTAssertTrue(machine.endBottomStripDrag())
        XCTAssertEqual(machine.state, .visibleNxIdle)
    }

    // IC047-013：迁移表的收藏事件绑定点击时资产，成功不改变 D。
    func testIC047_013TransitionRowFavorite() {
        assertTransitionRow(
            .tapFavorite,
            [unavailable, conditionalSame, unavailable, unavailable,
             conditionalSame, unavailable, unavailable]
        )

        let machine = makeMachine(state: .visibleOneXIdle)
        let request = tryUnwrap(machine.makeFavoriteToggleRequest())
        XCTAssertTrue(machine.handleHorizontalSwipe(
            direction: .next,
            startedAtPagingEdge: false,
            distance: 0,
            velocity: 0
        ))
        let originalPending = machine.pendingDeletionAssetIDs
        XCTAssertTrue(machine.completeFavoriteToggle(request, succeeded: true))
        XCTAssertTrue(machine.favoriteAssetIDs.contains("asset-2"))
        XCTAssertEqual(machine.pendingDeletionAssetIDs, originalPending)
    }

    // IC047-014：迁移表的历史相簿事件绑定点击时资产并执行成功结果。
    func testIC047_014TransitionRowRecentAlbum() {
        assertTransitionRow(
            .tapRecentAlbum,
            [unavailable, conditionalSame, unavailable, unavailable,
             conditionalSame, unavailable, unavailable]
        )

        let album = S2AlbumReference(id: "album-1", name: "相簿一")
        let machine = makeMachine(
            state: .visibleOneXIdle,
            pendingDeletionAssetIDs: ["asset-2"],
            recentAlbum: album
        )
        let request = tryUnwrap(machine.makeRecentAlbumAdditionRequest())
        XCTAssertTrue(machine.handleHorizontalSwipe(
            direction: .next,
            startedAtPagingEdge: false,
            distance: 0,
            velocity: 0
        ))
        XCTAssertTrue(machine.completeRecentAlbumAddition(
            request,
            outcome: .success(alreadyContained: false)
        ))
        XCTAssertFalse(machine.pendingDeletionAssetIDs.contains("asset-2"))
        XCTAssertEqual(machine.addedAlbumsByAssetID["asset-2"], [album])
    }

    // IC047-015：迁移表的加入相簿点击保留基础状态并呈现遮挡层。
    func testIC047_015TransitionRowTapAddAlbum() {
        assertTransitionRow(
            .tapAddAlbum,
            [unavailable, availableSame, unavailable, unavailable,
             availableSame, unavailable, unavailable]
        )

        let machine = makeMachine(state: .visibleNxIdle)
        let originalState = machine.state
        let request = machine.presentAlbumPicker()
        XCTAssertEqual(request?.targetAssetID, "asset-2")
        XCTAssertEqual(machine.state, originalState)
        XCTAssertEqual(machine.sheetState, .presented)
    }

    // IC047-016：迁移表的 sheet 遮挡事件阻止全部底层 S2 输入。
    func testIC047_016TransitionRowUnderlyingInputWhileSheetPresented() {
        assertTransitionRow(
            .operateUnderlyingS2WhileSheetPresented,
            [unavailable, conditionalSame, unavailable, unavailable,
             conditionalSame, unavailable, unavailable]
        )

        let machine = makeMachine(state: .visibleOneXIdle)
        _ = machine.presentAlbumPicker()
        let originalPending = machine.pendingDeletionAssetIDs
        XCTAssertFalse(machine.handleSingleTap())
        XCTAssertFalse(machine.handleSwipeUp())
        XCTAssertFalse(machine.beginPinch())
        XCTAssertFalse(machine.beginBottomStripDrag())
        XCTAssertNil(machine.makeFavoriteToggleRequest())
        XCTAssertNil(machine.makeExitPayload())
        XCTAssertEqual(machine.pendingDeletionAssetIDs, originalPending)
        XCTAssertEqual(machine.state, .visibleOneXIdle)
    }

    // IC047-017：迁移表的 sheet 成功事件更新 H、G、D 并关闭遮挡层。
    func testIC047_017TransitionRowAlbumSheetSuccess() {
        assertTransitionRow(
            .selectAlbumAndWriteSucceeds,
            [unavailable, conditionalSame, unavailable, unavailable,
             conditionalSame, unavailable, unavailable]
        )

        let machine = makeMachine(
            state: .visibleOneXIdle,
            pendingDeletionAssetIDs: ["asset-2"]
        )
        let request = tryUnwrap(machine.presentAlbumPicker())
        let album = S2AlbumReference(id: "album-2", name: "相簿二")
        XCTAssertTrue(machine.completeAlbumPickerSelection(
            request,
            album: album
        ))
        XCTAssertEqual(machine.recentAlbum, album)
        XCTAssertEqual(machine.currentAddedAlbums, [album])
        XCTAssertFalse(machine.pendingDeletionAssetIDs.contains("asset-2"))
        XCTAssertEqual(machine.sheetState, .closed)
    }

    // IC047-018：迁移表的 sheet 失败事件不改 H、D 或基础状态，并标记未定项 11。
    func testIC047_018TransitionRowAlbumSheetFailure() {
        assertTransitionRow(
            .selectAlbumAndWriteFails,
            [unavailable, conditionalSame, unavailable, unavailable,
             conditionalSame, unavailable, unavailable]
        )

        let machine = makeMachine(
            state: .visibleNxIdle,
            pendingDeletionAssetIDs: ["asset-2"]
        )
        let request = tryUnwrap(machine.presentAlbumPicker())
        let originalPending = machine.pendingDeletionAssetIDs
        XCTAssertTrue(machine.reportAlbumPickerFailure(request))
        XCTAssertEqual(machine.pendingDeletionAssetIDs, originalPending)
        XCTAssertNil(machine.recentAlbum)
        XCTAssertEqual(machine.state, .visibleNxIdle)
        XCTAssertEqual(machine.sheetState, .presented)
        XCTAssertEqual(machine.pendingUndecidedItem, .item11)
    }

    // IC047-019：迁移表的取消 sheet 事件只关闭 P，基础状态、视口和数据不变。
    func testIC047_019TransitionRowCancelAlbumSheet() {
        assertTransitionRow(
            .cancelAlbumSheet,
            [unavailable, conditionalSame, unavailable, unavailable,
             conditionalSame, unavailable, unavailable]
        )

        let machine = makeMachine(state: .visibleNxIdle)
        _ = machine.presentAlbumPicker()
        let originalScale = machine.scale
        let originalPending = machine.pendingDeletionAssetIDs
        XCTAssertTrue(machine.cancelAlbumPicker())
        XCTAssertEqual(machine.sheetState, .closed)
        XCTAssertEqual(machine.state, .visibleNxIdle)
        XCTAssertEqual(machine.scale, originalScale)
        XCTAssertEqual(machine.pendingDeletionAssetIDs, originalPending)
    }

    // IC047-020：迁移表的返回事件仅从两个显示静止态形成五字段返回及续接快照。
    func testIC047_020TransitionRowBack() {
        assertTransitionRow(
            .tapBack,
            [unavailable, availableOutside, unavailable, unavailable,
             availableOutside, unavailable, unavailable]
        )

        let machine = makeMachine(state: .visibleOneXIdle)
        let payload = tryUnwrap(machine.makeExitPayload())
        XCTAssertEqual(payload.upstreamReturn.sourceSessionID, "session-047")
        XCTAssertEqual(payload.upstreamReturn.sourceRangeID, "range-047")
        XCTAssertEqual(payload.upstreamReturn.currentAssetID, "asset-2")
        XCTAssertEqual(payload.upstreamReturn.farthestAssetID, "asset-2")
        XCTAssertEqual(
            payload.continuationSnapshot.pendingDeletionAssetIDs,
            machine.pendingDeletionAssetIDs
        )
    }

    // IC047-021：迁移表的确认入口只从两个显示静止态条件迁出。
    func testIC047_021TransitionRowConfirmation() {
        assertTransitionRow(
            .tapConfirmation,
            [unavailable, conditionalOutside, unavailable, unavailable,
             conditionalOutside, unavailable, unavailable]
        )

        XCTAssertNotNil(makeMachine(state: .visibleNxIdle).makeExitPayload())
        XCTAssertNil(makeMachine(state: .hiddenNx).makeExitPayload())
    }

    // IC047-022：迁移表的系统边缘右滑在六状态均被忽略且不得迁出。
    func testIC047_022TransitionRowSystemEdgeSwipeBack() {
        assertTransitionRow(
            .systemEdgeSwipeBack,
            [unavailable, ignoredSame, ignoredSame, ignoredSame,
             ignoredSame, ignoredSame, ignoredSame]
        )

        for state in S2State.allCases {
            let machine = makeMachine(state: state)
            XCTAssertFalse(machine.handleSystemEdgeSwipeBack())
            XCTAssertEqual(machine.state, state)
        }
    }

    // IC047-023：手势矩阵的单击行逐格覆盖 1x、Nx 与 sheet。
    func testIC047_023GestureMatrixSingleTapRow() {
        assertGestureRow(
            .singleTapMainImage,
            [gesture(.available, .toggleInterface),
             gesture(.available, .toggleInterface), blocked]
        )
    }

    // IC047-024：手势矩阵的双击行逐格覆盖 1x、Nx 与 sheet。
    func testIC047_024GestureMatrixDoubleTapRow() {
        assertGestureRow(
            .doubleTapMainImage,
            [gesture(.available, .toggleZoom),
             gesture(.available, .toggleZoom), blocked]
        )
    }

    // IC047-025：手势矩阵的捏合行逐格覆盖 1x、Nx 与 sheet。
    func testIC047_025GestureMatrixPinchRow() {
        assertGestureRow(
            .pinchMainImage,
            [gesture(.available, .continuousPinch),
             gesture(.available, .continuousPinch), blocked]
        )
    }

    // IC059：手势矩阵的上滑行在 1x 与 Nx 都执行标记语义。
    func testIC047_026GestureMatrixSwipeUpRow() {
        assertGestureRow(
            .swipeUpMainImage,
            [gesture(.available, .markCurrent),
             gesture(.available, .markCurrent), blocked]
        )
    }

    // IC047-027：手势矩阵的下滑行逐格覆盖取消标记、平移限定与遮挡。
    func testIC047_027GestureMatrixSwipeDownRow() {
        assertGestureRow(
            .swipeDownMainImage,
            [gesture(.available, .unmarkCurrent),
             gesture(.conditional, .panOnly), blocked]
        )
    }

    // IC047-028：手势矩阵的左右滑行逐格覆盖普通翻页、贴边翻页与遮挡。
    func testIC047_028GestureMatrixHorizontalSwipeRow() {
        assertGestureRow(
            .horizontalSwipeMainImage,
            [gesture(.available, .switchPhoto),
             gesture(.conditional, .panOrEdgePaging), blocked]
        )
    }

    // IC047-029：手势矩阵的任意拖动行逐格覆盖 1x 裁决、Nx 平移与遮挡。
    func testIC047_029GestureMatrixMainDragRow() {
        assertGestureRow(
            .dragMainImage,
            [gesture(.conditional, .routeOneXDrag),
             gesture(.available, .panOrEdgePaging), blocked]
        )
    }

    // IC047-030：手势矩阵的横栏拖动行逐格覆盖显隐条件与 sheet 遮挡。
    func testIC047_030GestureMatrixBottomStripDragRow() {
        assertGestureRow(
            .dragBottomStrip,
            [gesture(.conditional, .dragBottomStripWhenVisible),
             gesture(.conditional, .dragBottomStripWhenVisible), blocked]
        )
    }

    // IC047-031：手势矩阵的底层控件点击行逐格覆盖显示条件与 sheet 遮挡。
    func testIC047_031GestureMatrixUnderlyingControlRow() {
        assertGestureRow(
            .tapUnderlyingControl,
            [gesture(.conditional, .useVisibleControl),
             gesture(.conditional, .useVisibleControl), blocked]
        )
    }

    // IC047-032：手势矩阵的 sheet 控件行只在 sheet 呈现时可达。
    func testIC047_032GestureMatrixSheetControlRow() {
        assertGestureRow(
            .tapSheetControl,
            [gesture(.unavailable, .none), gesture(.unavailable, .none),
             gesture(.available, .sheetControl)]
        )
    }

    // IC047-033：手势矩阵的系统边缘右滑行在三列均不得返回。
    func testIC047_033GestureMatrixSystemEdgeSwipeRow() {
        assertGestureRow(
            .systemEdgeSwipe,
            [gesture(.blocked, .systemBackDisabled),
             gesture(.blocked, .systemBackDisabled), blocked]
        )
    }

    // IC047-034：手势矩阵的未定义手势行不绑定产品操作且不得穿透 sheet。
    func testIC047_034GestureMatrixUndefinedGestureRow() {
        assertGestureRow(
            .undefinedMainImageGesture,
            [gesture(.ignored, .none), gesture(.ignored, .none), blocked]
        )
    }

    // IC047-035：捏合开始后独占当前触摸序列，其他主图语义与横栏均不接收。
    func testIC047_035PinchExclusivelyOwnsTouchSequence() {
        let machine = makeMachine(state: .visibleOneXIdle)
        let originalPending = machine.pendingDeletionAssetIDs

        XCTAssertTrue(machine.beginPinch())
        XCTAssertEqual(machine.touchSequenceOwner, .pinch)
        XCTAssertFalse(machine.handleSingleTap())
        XCTAssertFalse(doubleTap(machine))
        XCTAssertFalse(machine.handleSwipeUp())
        XCTAssertFalse(machine.handleSwipeDown())
        XCTAssertFalse(machine.handleHorizontalSwipe(
            direction: .next,
            startedAtPagingEdge: true,
            distance: 100,
            velocity: 1_000
        ))
        XCTAssertFalse(machine.beginBottomStripDrag())
        XCTAssertNil(machine.makeFavoriteToggleRequest())
        XCTAssertEqual(machine.pendingDeletionAssetIDs, originalPending)
        XCTAssertTrue(machine.updatePinch(
            magnification: 2,
            viewportSize: viewportSize,
            fittedSize: fittedSize
        ))
        XCTAssertTrue(machine.endPinch(
            viewportSize: viewportSize,
            fittedSize: fittedSize
        ))
        XCTAssertEqual(machine.touchSequenceOwner, .none)
        XCTAssertEqual(machine.state, .visibleNxIdle)
    }

    // IC047-036：捏合连续调节受上下限约束，松手吸附到严格 1 且不改变 V。
    func testIC047_036PinchHardClampSnapBackAndVisibilityPreservation() {
        let machine = makeMachine(state: .hiddenOneX)

        XCTAssertTrue(machine.beginPinch())
        XCTAssertTrue(machine.updatePinch(
            magnification: 0.1,
            viewportSize: viewportSize,
            fittedSize: fittedSize
        ))
        XCTAssertEqual(machine.scale, 1)
        XCTAssertTrue(machine.endPinch(
            viewportSize: viewportSize,
            fittedSize: fittedSize
        ))
        XCTAssertEqual(machine.state, .hiddenOneX)

        XCTAssertTrue(machine.beginPinch())
        XCTAssertTrue(machine.updatePinch(
            magnification: 1.1,
            viewportSize: viewportSize,
            fittedSize: fittedSize
        ))
        XCTAssertEqual(machine.scale, 1.1, accuracy: 0.000_001)
        XCTAssertTrue(machine.endPinch(
            viewportSize: viewportSize,
            fittedSize: fittedSize
        ))
        XCTAssertEqual(machine.scale, 1)
        XCTAssertEqual(machine.interfaceVisibility, .hidden)

        XCTAssertTrue(machine.beginPinch())
        XCTAssertTrue(machine.updatePinch(
            magnification: 100,
            viewportSize: viewportSize,
            fittedSize: fittedSize
        ))
        XCTAssertEqual(machine.scale, parameters.pinchMaxScale)
        XCTAssertEqual(machine.interfaceVisibility, .hidden)
    }

    // IC047-037：双击从 1x 进入并从 Nx 退出时恢复进入前的显示或隐藏状态。
    func testIC047_037DoubleTapEnterAndExitRestoresVisibility() {
        let visible = makeMachine(state: .visibleOneXIdle)
        XCTAssertTrue(doubleTap(visible))
        XCTAssertEqual(visible.state, .visibleNxIdle)
        XCTAssertTrue(doubleTap(visible))
        XCTAssertEqual(visible.scale, 1)
        XCTAssertEqual(visible.state, .visibleOneXIdle)

        let hidden = makeMachine(state: .hiddenOneX)
        XCTAssertTrue(doubleTap(hidden))
        XCTAssertEqual(hidden.state, .hiddenNx)
        XCTAssertTrue(doubleTap(hidden))
        XCTAssertEqual(hidden.scale, 1)
        XCTAssertEqual(hidden.state, .hiddenOneX)
    }

    // IC047-038：普通翻页、Nx 贴边翻页与横栏换片均把新照片 s 重置为 1。
    func testIC047_038EveryPagingPathResetsScaleToOne() {
        let edgePaging = makeMachine(state: .visibleNxIdle)
        XCTAssertTrue(edgePaging.handleHorizontalSwipe(
            direction: .next,
            startedAtPagingEdge: true,
            distance: parameters.edgePagingTriggerDistance,
            velocity: parameters.edgePagingTriggerVelocity
        ))
        XCTAssertEqual(edgePaging.currentAssetID, "asset-3")
        XCTAssertEqual(edgePaging.scale, 1)
        XCTAssertEqual(edgePaging.viewportOffset, .zero)
        XCTAssertEqual(edgePaging.state, .visibleOneXIdle)

        let stripPaging = makeMachine(state: .visibleNxStripDragging)
        XCTAssertTrue(stripPaging.changeCurrentPhotoDuringBottomStripDrag(by: 1))
        XCTAssertEqual(stripPaging.scale, 1)
        XCTAssertEqual(stripPaging.state, .visibleOneXStripDragging)
    }

    // IC059：Nx 上滑标记当前照片，切到下一张后按决策归一为 1x。
    func testIC059NxSwipeUpMarksAndResetsAfterPhotoChange() {
        let machine = makeMachine(state: .visibleNxIdle)

        XCTAssertTrue(machine.handleSwipeUp())
        XCTAssertTrue(machine.pendingDeletionAssetIDs.contains("asset-2"))
        XCTAssertEqual(machine.currentAssetID, "asset-3")
        XCTAssertEqual(machine.scale, 1)
        XCTAssertEqual(machine.viewportOffset, .zero)
        XCTAssertEqual(machine.state, .visibleOneXIdle)
    }

    // IC047-040 已由决策 17 改写：Nx 单击切换显隐，但不改变视口、c 或 D。
    func testIC058NxSingleTapTogglesVisibilityWithoutViewportOrDataChanges() {
        let machine = makeMachine(state: .hiddenNx)
        let originalScale = machine.scale
        let originalOffset = machine.viewportOffset
        let originalCurrent = machine.currentAssetID
        let originalPending = machine.pendingDeletionAssetIDs

        XCTAssertTrue(machine.handleSingleTap())
        XCTAssertEqual(machine.interfaceVisibility, .visible)
        XCTAssertEqual(machine.scale, originalScale)
        XCTAssertEqual(machine.viewportOffset, originalOffset)
        XCTAssertEqual(machine.currentAssetID, originalCurrent)
        XCTAssertEqual(machine.pendingDeletionAssetIDs, originalPending)
    }

    // IC047-041：五个 Demo 几何函数保持原公式，且 panLimits 没有余量。
    func testIC047_041MigratedGeometryFunctionsKeepVerifiedFormulas() {
        XCTAssertEqual(
            S2Geometry.aspectFitSize(
                viewportSize: CGSize(width: 300, height: 600),
                assetAspectRatio: 1
            ),
            CGSize(width: 300, height: 300)
        )
        XCTAssertEqual(
            S2Geometry.aspectFitSize(
                viewportSize: CGSize(width: 600, height: 300),
                assetAspectRatio: 1
            ),
            CGSize(width: 300, height: 300)
        )
        XCTAssertEqual(
            S2Geometry.aspectFillMultiplier(
                viewportSize: CGSize(width: 300, height: 600),
                assetAspectRatio: 1
            ),
            2
        )

        let anchorViewport = CGSize(width: 200, height: 100)
        let location = CGPoint(x: 50, y: 25)
        XCTAssertEqual(
            S2Geometry.doubleTapAnchorOffset(
                strategy: .touchPoint,
                location: location,
                viewportSize: anchorViewport,
                zoomScale: 3
            ),
            CGSize(width: 100, height: 50)
        )

        XCTAssertEqual(
            S2Geometry.panLimits(
                viewportSize: viewportSize,
                fittedSize: fittedSize,
                zoomScale: 1
            ),
            .zero
        )
        XCTAssertEqual(
            S2Geometry.panLimits(
                viewportSize: viewportSize,
                fittedSize: fittedSize,
                zoomScale: 2
            ),
            CGSize(width: 150, height: 300)
        )
        XCTAssertEqual(
            S2Geometry.clampedOffset(
                CGSize(width: 999, height: -999),
                viewportSize: viewportSize,
                fittedSize: fittedSize,
                zoomScale: 2
            ),
            CGSize(width: 150, height: -300)
        )
    }

    private let viewportSize = CGSize(width: 300, height: 600)
    private let fittedSize = CGSize(width: 300, height: 600)

    private var parameters: S2ResolvedParameters {
        S2ResolvedParameters(
            pinchMaxScale: 4,
            zoomSnapBackThreshold: 1.2,
            minDoubleTapScale: 2.5,
            doubleTapAnchorStrategy: .touchPoint,
            edgePagingTriggerDistance: 40,
            edgePagingTriggerVelocity: 300,
            verticalSwipeDistance: 40,
            verticalSwipeVelocity: 100,
            horizontalSwipeDistance: 40,
            horizontalSwipeVelocity: 100,
            pinchMinimumScaleDelta: 0.01,
            mainDragMinimumDistance: 8,
            bottomStripMetrics: S2BottomStripMetrics(
                currentItemSize: 72,
                neighborItemWidth: 52,
                neighborItemHeight: 44,
                itemSpacing: 8,
                edgeFadeWidth: 24,
                dragMinimumDistance: 4,
                switchDistance: 44
            )
        )!
    }

    private var allOrigins: [S2TransitionOrigin] {
        [.pageOutside] + S2State.allCases.map(S2TransitionOrigin.state)
    }

    private var allGestureContexts: [S2GestureContext] {
        [.oneX, .nX, .albumSheetPresented]
    }

    private var unavailable: S2TransitionRule {
        .unavailable
    }

    private var availableSame: S2TransitionRule {
        .available(.sameState)
    }

    private var conditionalSame: S2TransitionRule {
        .conditional(.sameState)
    }

    private var ignoredSame: S2TransitionRule {
        .ignored(.sameState)
    }

    private var conditionalDynamic: S2TransitionRule {
        .conditional(.dynamic)
    }

    private var availableOutside: S2TransitionRule {
        .available(.pageOutside)
    }

    private var conditionalOutside: S2TransitionRule {
        .conditional(.pageOutside)
    }

    private var blocked: S2GestureRule {
        gesture(.blocked, .none)
    }

    private func availableState(_ state: S2State) -> S2TransitionRule {
        .available(.state(state))
    }

    private func gesture(
        _ availability: S2GestureAvailability,
        _ effect: S2GestureEffect
    ) -> S2GestureRule {
        S2GestureRule(availability: availability, effect: effect)
    }

    private func assertTransitionRow(
        _ event: S2TransitionEvent,
        _ expected: [S2TransitionRule],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(expected.count, allOrigins.count, file: file, line: line)
        for (origin, expectedRule) in zip(allOrigins, expected) {
            XCTAssertEqual(
                S2StateMachine.transitionRule(for: event, from: origin),
                expectedRule,
                file: file,
                line: line
            )
        }
    }

    private func assertGestureRow(
        _ input: S2GestureInput,
        _ expected: [S2GestureRule],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(
            expected.count,
            allGestureContexts.count,
            file: file,
            line: line
        )
        for (context, expectedRule) in zip(allGestureContexts, expected) {
            XCTAssertEqual(
                S2StateMachine.gestureRule(for: input, context: context),
                expectedRule,
                file: file,
                line: line
            )
        }
    }

    private func makeMachine(
        state: S2State,
        pendingDeletionAssetIDs: Set<String> = ["asset-1"],
        currentAssetID: String = "asset-2",
        recentAlbum: S2AlbumReference? = nil
    ) -> S2StateMachine {
        let visibility: S2InterfaceVisibility
        switch state {
        case .hiddenOneX, .hiddenNx:
            visibility = .hidden
        default:
            visibility = .visible
        }
        let scale: CGFloat
        switch state {
        case .visibleNxIdle, .visibleNxStripDragging, .hiddenNx:
            scale = 2
        default:
            scale = 1
        }
        let countBox = CountBox(value: pendingDeletionAssetIDs.count)
        let entry = S2EntryContext(
            sessionID: "session-047",
            rangeDisplayInformation: S2RangeDisplayInformation(
                rangeID: "range-047",
                displayName: "测试范围",
                totalAssetCount: 3
            ),
            orderedAssetIDs: ["asset-1", "asset-2", "asset-3"],
            currentAssetID: currentAssetID,
            pendingDeletionAssetIDs: pendingDeletionAssetIDs,
            sessionMergedPendingDeletionCountProvider: { countBox.value }
        )
        let machine = S2StateMachine(
            entry: entry,
            initialPresentation: S2InitialPresentation(
                interfaceVisibility: visibility,
                scale: scale,
                viewportOffset: .zero
            ),
            parameters: parameters,
            imageRequestStrategy: nil,
            initialFavoriteAssetIDs: [],
            initialRecentAlbum: recentAlbum,
            pendingDeletionDidChange: { countBox.value = $0.count }
        )!
        if state == .visibleOneXStripDragging ||
            state == .visibleNxStripDragging {
            precondition(machine.beginBottomStripDrag())
        }
        return machine
    }

    private func doubleTap(_ machine: S2StateMachine) -> Bool {
        machine.handleDoubleTap(
            at: CGPoint(x: 120, y: 240),
            viewportSize: viewportSize,
            assetAspectRatio: 1
        )
    }

    private func tryUnwrap<T>(
        _ value: T?,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> T {
        guard let value else {
            XCTFail("预期值不应为空", file: file, line: line)
            fatalError("测试无法继续")
        }
        return value
    }
}

private final class CountBox {
    var value: Int

    init(value: Int) {
        self.value = value
    }
}
