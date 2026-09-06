import XCTest
@testable import PhotoCleanupMVE

/// IC-131 B（v8 回写决策 29）：从 S2 返回时写回校验失败——不阻断返回，回到 S1
/// 并以底部短 toast 反馈；该范围的 `M`、`K` 保持上一次有效值。
///
/// 修正对象：原实装校验失败只返回 false，App 层忽略返回值，`route` 停在 `.s2`，
/// 用户点了返回却没离开、也没有任何提示。
final class IC131S1WriteBackToastTests: XCTestCase {
    // 断言 4：坏 payload（sourceSessionID 不等于当前会话）走 leaveS2 →
    // 返回 false、route == .s1、s2Machine == nil、sessionStore 逐字节未变、
    // 事件通道恰好收到一条「写回失败」。
    func testIC131B_FailedWriteBackOnLeaveReturnsToS1AndEmitsOneEvent() async {
        await MainActor.run {
            let coordinator = makeCoordinatorInS2(sessionID: "会话-131B-返回")
            let machine = tryUnwrap(coordinator.s1Machine)
            let storeBefore = machine.sessionStore
            let payload = makeMismatchedSessionPayload(coordinator: coordinator)

            XCTAssertFalse(coordinator.leaveS2(with: payload))

            // 不阻断：确实离开了 S2。
            XCTAssertEqual(coordinator.route, .s1)
            XCTAssertNil(coordinator.s2Machine)
            // 不写回：M、K、F 保持上一次有效值。
            XCTAssertEqual(machine.sessionStore, storeBefore)
            // 恰好一条事件，且是写回失败。
            XCTAssertEqual(coordinator.s1FeedbackEventCount, 1)
            let event = tryUnwrap(coordinator.s1FeedbackEvent)
            XCTAssertEqual(event.kind, .writeBackFailed)
            XCTAssertEqual(event.id, 1)
            // 短 toast 与持久型 message 是两条通道，后者不被占用。
            XCTAssertNil(coordinator.message)
        }
    }

    // 断言 5：同样的坏 payload 走 enterConfirmationFromS2 →
    // 返回 false、route == .s1（不是 .s3）、未形成提交、收到一条事件。
    func testIC131B_FailedWriteBackOnTrashPathDoesNotEnterS3() async {
        await MainActor.run {
            let coordinator = makeCoordinatorInS2(sessionID: "会话-131B-垃圾桶")
            let machine = tryUnwrap(coordinator.s1Machine)
            let storeBefore = machine.sessionStore
            let payload = makeMismatchedSessionPayload(coordinator: coordinator)

            XCTAssertFalse(coordinator.enterConfirmationFromS2(with: payload))

            XCTAssertEqual(coordinator.route, .s1)
            XCTAssertNil(coordinator.s2Machine)
            // 不进入 S3、不形成提交。
            XCTAssertNil(coordinator.s3Machine)
            XCTAssertTrue(coordinator.s3Groups.isEmpty)
            XCTAssertEqual(machine.sessionStore, storeBefore)
            XCTAssertEqual(coordinator.s1FeedbackEventCount, 1)
            XCTAssertEqual(
                tryUnwrap(coordinator.s1FeedbackEvent).kind,
                .writeBackFailed
            )
        }
    }

    // 断言 6（成功路径回归）：合法 payload 走 leaveS2 → 返回 true、route == .s1、
    // M／K 已写回、事件通道为空（不误报）。
    func testIC131B_SuccessfulWriteBackEmitsNoEvent() async {
        await MainActor.run {
            let coordinator = makeCoordinatorInS2(sessionID: "会话-131B-成功")
            let s2Machine = tryUnwrap(coordinator.s2Machine)
            let payload = tryUnwrap(s2Machine.makeExitPayload())

            XCTAssertTrue(coordinator.leaveS2(with: payload))

            XCTAssertEqual(coordinator.route, .s1)
            let machine = tryUnwrap(coordinator.s1Machine)
            // M 已写回。
            XCTAssertEqual(
                machine.sessionStore.pendingDeletionAssetIDsByRangeID["范围-月"],
                payload.upstreamReturn.pendingDeletionAssetIDs
            )
            // K 已写回。
            XCTAssertEqual(
                machine.sessionStore.continuationsByRangeID["范围-月"],
                SessionStore.Continuation(
                    currentAssetID: payload.upstreamReturn.currentAssetID,
                    farthestAssetID: payload.upstreamReturn.farthestAssetID,
                    recordedSortOrder: machine.sortOrder.sessionSortOrder
                )
            )
            // 不误报。
            XCTAssertEqual(coordinator.s1FeedbackEventCount, 0)
            XCTAssertNil(coordinator.s1FeedbackEvent)
        }
    }

    // 断言 7（呈现器层）：连续两条事件，同一时刻只一条且为后者；旧事件到期不
    // 清除新事件；新事件到期才清除。时长经注入的调度器驱动，不真等 2 秒、不
    // 依赖主线程逐帧推进。
    func testIC131B_ToastPresenterKeepsLatestEventAndExpiresOnSchedule() {
        var scheduled: [(seconds: TimeInterval, fire: () -> Void)] = []
        let presenter = S1FeedbackToastPresenter { seconds, action in
            scheduled.append((seconds, action))
        }
        // 时长取标定参数，不写死 2000。
        let durationMilliseconds = S2CalibrationConfiguration
            .factoryPlaceholder
            .feedbackToastDurationMilliseconds

        let first = S1FeedbackEvent(id: 1, kind: .writeBackFailed)
        let second = S1FeedbackEvent(id: 2, kind: .writeBackFailed)

        presenter.present(first, durationMilliseconds: durationMilliseconds)
        XCTAssertEqual(presenter.activeEvent, first)
        XCTAssertEqual(presenter.presentedCount, 1)
        XCTAssertEqual(
            presenter.lastScheduledDurationSeconds,
            durationMilliseconds / 1_000
        )

        presenter.present(second, durationMilliseconds: durationMilliseconds)
        XCTAssertEqual(presenter.activeEvent, second)
        XCTAssertEqual(presenter.presentedCount, 2)

        XCTAssertEqual(scheduled.count, 2)
        // 旧事件到期：不得清除已经替换上来的新事件。
        scheduled[0].fire()
        XCTAssertEqual(presenter.activeEvent, second)
        // 新事件到期：清除。
        scheduled[1].fire()
        XCTAssertNil(presenter.activeEvent)
    }

    // 断言 8：toast 文案取自 String Catalog，不是源码里的中文字面量。
    // key 与目录的一致性另由 Scripts/scan-hardcoded-user-visible-strings.ps1 覆盖。
    func testIC131B_ToastTextComesFromStringCatalog() {
        let key = "s1.toast.writeback_failed"
        let resolved = L10n.text(key)

        // 目录里确实有这条（NSLocalizedString 找不到时原样返回 key）。
        XCTAssertNotEqual(resolved, key)
        // 逐字等于 v8 第十一节第 3 部分登记原文。
        XCTAssertEqual(resolved, "未能保存这次整理的进度。")
        // 呈现器经目录取值，而不是自带一份字面量。
        XCTAssertEqual(
            S1FeedbackToastPresenter.text(for: .writeBackFailed),
            resolved
        )
    }

    // MARK: - 夹具

    /// 建一个已进入 S2 的协调器：S1 读到一个范围 → 打开该范围 → 在 S2 里标记一张。
    @MainActor
    private func makeCoordinatorInS2(sessionID: String) -> CleanupCoordinator {
        let coordinator = CleanupCoordinator()
        XCTAssertTrue(coordinator.enterS1(sessionID: sessionID))
        let machine = tryUnwrap(coordinator.s1Machine)
        let request = tryUnwrap(machine.currentReadRequest)
        XCTAssertTrue(
            machine.completeRangeRead(
                .success([
                    S1Range(
                        id: "范围-月",
                        displayName: "2026 年 8 月",
                        assetIDsNewestFirst: ["资产-C", "资产-B", "资产-A"]
                    )
                ]),
                for: request
            )
        )
        let handoff = tryUnwrap(machine.makeS2Handoff(for: "范围-月"))
        XCTAssertTrue(coordinator.enterS2(from: handoff))
        let s2Machine = tryUnwrap(coordinator.s2Machine)
        // 标记一张，好让成功路径确有 M 可写回。
        XCTAssertTrue(s2Machine.handleSwipeUp())
        return coordinator
    }

    /// 取当前合法载荷，只把 `sourceSessionID` 换成别的会话——写回校验必失败，
    /// 且失败点落在 `SessionStore.applyS2Return` 的会话标识判定上。
    @MainActor
    private func makeMismatchedSessionPayload(
        coordinator: CleanupCoordinator
    ) -> S2ExitPayload {
        let s2Machine = tryUnwrap(coordinator.s2Machine)
        let good = tryUnwrap(s2Machine.makeExitPayload())
        return S2ExitPayload(
            upstreamReturn: SessionStore.S2Return(
                sourceSessionID: "别的会话-131B",
                sourceRangeID: good.upstreamReturn.sourceRangeID,
                pendingDeletionAssetIDs:
                    good.upstreamReturn.pendingDeletionAssetIDs,
                currentAssetID: good.upstreamReturn.currentAssetID,
                farthestAssetID: good.upstreamReturn.farthestAssetID
            ),
            continuationSnapshot: good.continuationSnapshot
        )
    }

    private func tryUnwrap<T>(
        _ value: T?,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> T {
        guard let value else {
            XCTFail("期望非空值", file: file, line: line)
            fatalError("期望非空值")
        }
        return value
    }
}
