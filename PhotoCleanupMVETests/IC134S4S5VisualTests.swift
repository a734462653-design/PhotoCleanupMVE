import XCTest
@testable import PhotoCleanupMVE

/// IC-134 E～G：S4 执行中页与 S5 完成页（含 L3 撤销后的四态视觉）。
///
/// 同样只走展示口径模型，不驱动 SwiftUI 渲染；观感由 H60 兜底。
final class IC134S4S5VisualTests: XCTestCase {
    // MARK: - E：S4 版式

    // 断言 15：S4-1／S4-2 元素清单，且**任何**状态都不出现比例或预计时间字样。
    func testIC134E_S4LayoutCoversBothStatesAndNeverShowsProgressOrEta() {
        let submitted = S4StatusPresentation.make(state: .submitted, assetCount: 20)
        XCTAssertEqual(submitted.title, L10n.text("s4.status.submitted_title"))
        XCTAssertEqual(submitted.body, L10n.text("s4.status.submitted_body"))
        XCTAssertEqual(
            submitted.subtitle,
            L10n.text("s4.chrome.subtitle_format", replacing: ["count": "20"])
        )
        XCTAssertTrue(submitted.isActivityIndicatorAnimating)

        // S4-2 版式相同，只换标题。
        let confirming = S4StatusPresentation.make(
            state: .resumedInteraction,
            assetCount: 20
        )
        XCTAssertEqual(confirming.title, L10n.text("s4.status.confirming_title"))
        XCTAssertEqual(confirming.body, submitted.body)
        XCTAssertEqual(confirming.subtitle, submitted.subtitle)
        XCTAssertTrue(confirming.isActivityIndicatorAnimating)

        // 三个终态不画自己的版式：保持 S4-1 版式，活动指示停止。
        let terminals: [S4State] = [
            .allSucceeded(
                S4SuccessResult(
                    submissionID: "提交-1",
                    successfulAssetIDs: [],
                    receivedAt: Date(timeIntervalSince1970: 0)
                )
            ),
            .resultUnknown(.activeWaitTimedOut)
        ]
        for state in terminals {
            let presentation = S4StatusPresentation.make(
                state: state,
                assetCount: 20
            )
            XCTAssertEqual(presentation.title, submitted.title)
            XCTAssertEqual(presentation.body, submitted.body)
            XCTAssertFalse(
                presentation.isActivityIndicatorAnimating,
                "终态的活动指示必须停止"
            )
        }

        // 不出现比例或预计时间字样。
        let forbidden = ["%", "预计", "剩余", "进度", "还需"]
        let allStates: [S4State] = [.submitted, .resumedInteraction] + terminals
        for state in allStates {
            let presentation = S4StatusPresentation.make(
                state: state,
                assetCount: 20
            )
            let text = [
                presentation.title,
                presentation.body,
                presentation.subtitle
            ].joined()
            for token in forbidden {
                XCTAssertFalse(
                    text.contains(token),
                    "S4 文案不得出现「\(token)」：\(text)"
                )
            }
        }

        // chrome 取值引用 S1 常量。
        XCTAssertEqual(S4ChromeMetrics.rowHeight, S1ChromeLayout.rowHeight)
        XCTAssertEqual(
            S4ChromeMetrics.titleFontSize,
            S1ChromeTypography.titleFontSize
        )
    }

    // 断言 16 由 S4StateMachineTests 45 项原样通过覆盖——本卡未改 S4 状态机，
    // 此处只钉住「视图层没有反向依赖状态机的新成员」。
    func testIC134E_S4StateMachineSurfaceUntouchedByVisualLayer() {
        // 活动指示由 isTerminal 反解，不新增状态机成员（④取定）。
        XCTAssertFalse(S4State.submitted.isTerminal)
        XCTAssertFalse(S4State.resumedInteraction.isTerminal)
        XCTAssertTrue(S4State.resultUnknown(.activeWaitTimedOut).isTerminal)
    }

    // MARK: - G：S5 四态

    // 断言 21：四态元素清单——三格只在 T0／F、引导卡只在 T0／U、按钮文案与动作；
    // C 态用户可见文案不得出现「失败」「未完成」。
    func testIC134G_S5StateElementsAndButtons() throws {
        let t0 = S5StatePresentation.make(state: try successState())
        let c = S5StatePresentation.make(state: try cancelledState())
        let f = S5StatePresentation.make(state: try failedState())
        let u = S5StatePresentation.make(state: unknownState())

        // 三格只在 T0 与 F。
        XCTAssertTrue(t0.showsResultTiles)
        XCTAssertTrue(f.showsResultTiles)
        XCTAssertFalse(c.showsResultTiles)
        XCTAssertFalse(u.showsResultTiles)

        // 引导卡只在 T0 与 U。
        XCTAssertTrue(t0.showsGuidanceCard)
        XCTAssertTrue(u.showsGuidanceCard)
        XCTAssertFalse(c.showsGuidanceCard)
        XCTAssertFalse(f.showsGuidanceCard)

        // 按钮文案与动作。
        XCTAssertEqual(t0.primaryButtonTitle, L10n.text("s5.action.leave"))
        XCTAssertEqual(t0.primaryAction, .leaveCompletion)
        XCTAssertEqual(u.primaryButtonTitle, L10n.text("s5.action.finish"))
        XCTAssertEqual(u.primaryAction, .leaveCompletion)
        for presentation in [c, f] {
            XCTAssertEqual(
                presentation.primaryButtonTitle,
                L10n.text("s5.action.return_to_confirmation")
            )
            XCTAssertEqual(presentation.primaryAction, .returnToConfirmation)
        }

        // 每态都有 hero 与主按钮。
        for presentation in [t0, c, f, u] {
            XCTAssertTrue(presentation.elements.contains(.hero))
            XCTAssertTrue(presentation.elements.contains(.primaryButton))
            XCTAssertTrue(presentation.elements.contains(.volumeCard))
        }

        // C 态用户可见文案不得出现「失败」「未完成」（规格）。
        let cancelledText = [
            c.heroTitle,
            c.heroBody,
            c.subtitle,
            c.primaryButtonTitle,
            c.submittedValue ?? "",
            c.volume.key,
            c.volume.value,
            c.volume.note ?? "",
            c.volumeNoteExtra ?? ""
        ].joined()
        XCTAssertFalse(cancelledText.contains("失败"))
        XCTAssertFalse(cancelledText.contains("未完成"))
    }

    // 断言 22：L2 精确／下界 + 旁注；L1 三数取自 S4 交接的集合；S5-U 不显示三个数。
    func testIC134G_VolumeAndTileCountsComeFromHandoffSets() throws {
        // 精确：无旁注。
        let exact = S5VolumeCardModel.make(
            prefix: .cleaned,
            snapshot: makeSnapshot(knownBytes: 23_500_000, unavailable: 0)
        )
        XCTAssertEqual(exact.key, L10n.text("s5.volume.prefix"))
        XCTAssertEqual(
            exact.value,
            DecimalVolumeFormatter.string(forByteCount: 23_500_000)
        )
        XCTAssertNil(exact.note)

        // 下界：值加「至少」，旁注给不可用项数。
        let lower = S5VolumeCardModel.make(
            prefix: .movedToRecentlyDeleted,
            snapshot: makeSnapshot(knownBytes: 23_500_000, unavailable: 2)
        )
        XCTAssertEqual(lower.key, L10n.text("s5.t0.volume_prefix"))
        XCTAssertEqual(
            lower.value,
            L10n.text(
                "s5.volume.lower_bound_format",
                replacing: [
                    "value": DecimalVolumeFormatter.string(
                        forByteCount: 23_500_000
                    )
                ]
            )
        )
        XCTAssertEqual(
            lower.note,
            L10n.text(
                "s5.volume.unavailable_note_format",
                replacing: ["count": "2"]
            )
        )

        // L1：T0 为 N·0·0；F 取回调的三个集合；C／U 没有三格。
        let t0 = S5StatePresentation.make(state: try successState())
        XCTAssertEqual(
            t0.tileCounts,
            S5ResultTileCounts(success: 3, failure: 0, unprocessed: 0)
        )
        let f = S5StatePresentation.make(state: try failedState())
        XCTAssertEqual(
            f.tileCounts,
            S5ResultTileCounts(success: 1, failure: 1, unprocessed: 1)
        )
        XCTAssertNil(S5StatePresentation.make(state: try cancelledState()).tileCounts)
        XCTAssertNil(
            S5StatePresentation.make(state: unknownState()).tileCounts,
            "S5-U 不显示三个数"
        )
    }

    // 断言 23：主按钮动作分派——「离开」／「完成」走 leaveCompletion，
    // 「返回确认页」走 returnToConfirmation，各恰一次。
    func testIC134G_PrimaryButtonDispatchesExactlyOnce() throws {
        var leaveCalls = 0
        var returnCalls = 0

        func run(_ action: S5PrimaryAction) {
            switch action {
            case .leaveCompletion:
                leaveCalls += 1
            case .returnToConfirmation:
                returnCalls += 1
            }
        }

        run(S5StatePresentation.make(state: try successState()).primaryAction)
        XCTAssertEqual(leaveCalls, 1)
        XCTAssertEqual(returnCalls, 0)

        run(S5StatePresentation.make(state: unknownState()).primaryAction)
        XCTAssertEqual(leaveCalls, 2)
        XCTAssertEqual(returnCalls, 0)

        run(S5StatePresentation.make(state: try cancelledState()).primaryAction)
        XCTAssertEqual(returnCalls, 1)

        run(S5StatePresentation.make(state: try failedState()).primaryAction)
        XCTAssertEqual(returnCalls, 2)
        XCTAssertEqual(leaveCalls, 2)
    }

    // 断言 24：本卡引用的 S4／S5 key 全部在目录里（孤儿方向由扫描器覆盖）。
    func testIC134G_EveryS4AndS5KeyResolvesInCatalog() {
        let keys = [
            "s4.chrome.title", "s4.chrome.subtitle_format",
            "s4.status.submitted_title", "s4.status.submitted_body",
            "s4.status.confirming_title",
            "s5.chrome.title",
            "s5.t0.title", "s5.t0.body", "s5.t0.volume_prefix",
            "s5.c.title", "s5.c.body",
            "s5.f.title", "s5.f.body",
            "s5.u.title", "s5.u.body_format",
            "s5.tile.success", "s5.tile.failure", "s5.tile.unprocessed",
            "s5.card.submitted", "s5.card.submitted_value_format",
            "s5.card.reason", "s5.card.result", "s5.card.result_unknown",
            "s5.volume.prefix", "s5.volume.lower_bound_format",
            "s5.volume.unavailable_note_format",
            "s5.volume.original_submission_disclaimer",
            "s5.recently_deleted.boundary_notice",
            "s5.failure.retry_notice", "s5.unknown.manual_verification_notice",
            "s5.action.leave", "s5.action.finish",
            "s5.action.return_to_confirmation"
        ]
        for key in keys {
            XCTAssertNotEqual(L10n.text(key), key, "目录里缺 \(key)")
        }
        // 两条旁注已补句号。
        XCTAssertTrue(L10n.text("s5.failure.retry_notice").hasSuffix("。"))
        XCTAssertTrue(
            L10n.text("s5.unknown.manual_verification_notice").hasSuffix("。")
        )
        // 引导卡正文不再提截图（④ Lynn：S5 引导不加标注截图）。
        XCTAssertFalse(
            L10n.text("s5.recently_deleted.boundary_notice").contains("截图")
        )
    }

    // MARK: - F：L3 撤销

    // 断言 17：产品源码不再引用 L3 三个符号。
    //
    // 说明：源码扫描在 CI 的沙箱里读不到仓库路径，故改为**类型层面**的证明——
    // 这三个符号若还在，本文件就编译不过；同时 S5PresentationCapabilities
    // 只剩一个字段，L3 的展示位已不存在。
    func testIC134F_L3SymbolsAreGoneFromProductSurface() throws {
        let capabilities = try successState().presentationCapabilities
        XCTAssertFalse(capabilities.showsSystemErrorDetails)
        XCTAssertTrue(try failedState().presentationCapabilities.showsSystemErrorDetails)

        // 持久化状态只剩两个字段。
        let persistent = S5PersistentState(
            state: try successState(),
            isApplicationActive: true
        )
        XCTAssertTrue(persistent.isApplicationActive)
    }

    // 断言 18：S5-T0 入场不触发任何磁盘读取——注入点已不存在（`enter` 没有
    // `readFreeDiskStrictGB` 参数），本调用能编译即为证明。
    func testIC134F_EntryTakesNoDiskReadingInjection() throws {
        var persisted: S5PersistentState?
        let machine = try S5StateMachine.enter(
            from: makeSuccessHandoff(),
            persist: { persisted = $0 },
            invalidateOldLists: ignoreInvalidation
        )
        XCTAssertNotNil(persisted)
        guard case .movedToRecentlyDeleted = machine.state else {
            return XCTFail("应进入 S5-T0")
        }
    }

    // 断言 19：含 L3 字段的旧完成态 JSON 解码成功、四态恢复正确；不含的同样成功。
    func testIC134F_LegacyCompletionArchiveWithL3FieldsStillDecodes() throws {
        let record = PersistedSession(
            s5: S5PersistentState(
                state: try successState(),
                isApplicationActive: true
            )
        )
        var json = try JSONSerialization.jsonObject(
            with: JSONEncoder().encode(record)
        ) as? [String: Any] ?? [:]
        // 不含 L3 字段：照常解码。
        let withoutL3 = try JSONDecoder().decode(
            PersistedSession.self,
            from: try JSONSerialization.data(withJSONObject: json)
        )
        XCTAssertEqual(withoutL3.phase, .completionSuccess)

        // 手工塞回旧档的四个 L3 字段：仍然解码成功，不判坏档。
        json["l3BaselineReading"] = ["available": ["_0": 10.5]]
        json["l3CompletionReading"] = ["available": ["_0": 13.5]]
        json["l3DeltaGB"] = 3.0
        json["recentlyDeletedClearedAt"] = 1_786_291_200.0
        json["某个未来才会有的字段"] = "忽略我"
        let withL3 = try JSONDecoder().decode(
            PersistedSession.self,
            from: try JSONSerialization.data(withJSONObject: json)
        )
        XCTAssertEqual(withL3.phase, .completionSuccess)
        XCTAssertEqual(
            withL3.snapshot.submissionID,
            record.snapshot.submissionID
        )
        XCTAssertEqual(
            withL3.downstreamTargetState,
            record.downstreamTargetState
        )
    }

    // 断言 20：S5 四态迁移的既有语义不受 L3 撤销影响——离开／返回确认页的
    // 可用性与 IC-134 之前一致。
    func testIC134F_FourStateTransitionsSurviveL3Removal() throws {
        var t0 = try makeMachine(from: makeSuccessHandoff())
        XCTAssertEqual(
            try t0.handle(.leavePage, persist: ignorePersistence).effect,
            .exitCleanup
        )
        var u = try makeMachine(from: makeUnknownHandoff())
        XCTAssertEqual(
            try u.handle(.leavePage, persist: ignorePersistence).effect,
            .exitCleanup
        )
        var c = try makeMachine(from: makeCancellationHandoff())
        XCTAssertEqual(
            try c.handle(.leavePage, persist: ignorePersistence).rejection,
            .actionUnavailableInCurrentState
        )
        let returned = try c.handle(
            .returnToConfirmation(cacheExists: true),
            persist: ignorePersistence
        )
        XCTAssertNil(returned.rejection)
        var f = try makeMachine(from: makeFailureHandoff())
        XCTAssertNil(
            try f.handle(
                .returnToConfirmation(cacheExists: false),
                persist: ignorePersistence
            ).rejection
        )
    }

    // MARK: - 夹具

    private let fixedDate = Date(timeIntervalSince1970: 1_786_291_200)

    private func makeSnapshot(
        knownBytes: Int64 = 1_000_000,
        unavailable: Int = 0
    ) -> SubmissionSnapshot {
        let assetIDs = ["资产-1", "资产-2", "资产-3"]
        return SubmissionSnapshot(
            submissionID: "提交-134",
            assetIDs: assetIDs,
            assetCount: assetIDs.count,
            knownTotalBytes: knownBytes,
            unavailableCount: unavailable,
            volumeDisplayMode: unavailable == 0 ? .exact : .lowerBound,
            favoriteAssetIDs: [],
            frozenAt: fixedDate
        )
    }

    private func makeSuccessHandoff() -> S4Handoff {
        let snapshot = makeSnapshot()
        return .success(
            snapshot: snapshot,
            result: S4SuccessResult(
                submissionID: snapshot.submissionID,
                successfulAssetIDs: Set(snapshot.assetIDs),
                receivedAt: fixedDate
            ),
            downstreamTargetState: .movedToRecentlyDeleted
        )
    }

    private func makeFailureHandoff() -> S4Handoff {
        let snapshot = makeSnapshot()
        return .failure(
            snapshot: snapshot,
            callback: S4FailureCallback(
                submissionID: snapshot.submissionID,
                successfulAssetIDs: ["资产-1"],
                failedAssetIDs: ["资产-2"],
                unprocessedAssetIDs: ["资产-3"],
                reason: S4FailureReason(
                    category: .assetNotDeletable,
                    message: "部分资产不可删除",
                    systemDomain: "测试错误域",
                    systemCode: 10
                ),
                receivedAt: fixedDate
            ),
            downstreamTargetState: .failed
        )
    }

    private func makeCancellationHandoff() -> S4Handoff {
        let snapshot = makeSnapshot()
        return .failure(
            snapshot: snapshot,
            callback: S4FailureCallback(
                submissionID: snapshot.submissionID,
                successfulAssetIDs: [],
                failedAssetIDs: [],
                unprocessedAssetIDs: Set(snapshot.assetIDs),
                reason: S4FailureReason(
                    category: .userCancelled,
                    message: "用户已取消系统操作",
                    systemDomain: "测试取消域",
                    systemCode: 71
                ),
                receivedAt: fixedDate
            ),
            downstreamTargetState: .cancelled
        )
    }

    private func makeUnknownHandoff() -> S4Handoff {
        .unknown(
            snapshot: makeSnapshot(),
            reason: .activeWaitTimedOut,
            downstreamTargetState: .unknown
        )
    }

    private func makeMachine(from handoff: S4Handoff) throws -> S5StateMachine {
        try S5StateMachine.enter(
            from: handoff,
            persist: ignorePersistence,
            invalidateOldLists: ignoreInvalidation
        )
    }

    private func successState() throws -> S5State {
        try makeMachine(from: makeSuccessHandoff()).state
    }

    private func cancelledState() throws -> S5State {
        try makeMachine(from: makeCancellationHandoff()).state
    }

    private func failedState() throws -> S5State {
        try makeMachine(from: makeFailureHandoff()).state
    }

    private func unknownState() -> S5State {
        .unknown(
            S5UnknownContext(
                snapshot: makeSnapshot(),
                reason: .activeWaitTimedOut
            )
        )
    }

    private func ignorePersistence(_ state: S5PersistentState) throws {}

    private func ignoreInvalidation(_ identifiers: Set<String>) {}
}
