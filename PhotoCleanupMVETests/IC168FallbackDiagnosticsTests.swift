import Foundation
import XCTest
@testable import PhotoCleanupMVE

/// IC-168：S2 → S3 回落的可见提示与可复制诊断、在途虚拟范围撤销、类别页进入失败提示。
///
/// 依据任务卡 IC-20260923-168 的六条裁定（Decision_log 第 195 条第二节第 3 条、第 184 条第四节
/// 第 1／2 条）。断言编号与任务卡子项 F 一一对应。口径同 IC-165／166／167：文案 key 与只可能落在
/// 字面量里的 needle 一律扫原文，其余扫剔过注释与字符串内容的源码；集合断言期望值一律写成
/// `Set`（惯例 45）。**只钉本卡新增的符号**：逐字不动类、比改前 +N 类与别处已钉的计数留在
/// 报告级证据里（惯例 46）。协调器是主线程隔离，行为断言一律在 `MainActor.run` 里跑。
///
/// **夹具驱动与源码扫描，真机未覆盖**（陷阱 1）：清理 tab 上的回落 toast 位置与观感、面板里
/// 复制出的诊断文本、冷启动下垃圾桶回落是否真是 `guard=M2`，只有 H88 能判。
final class IC168FallbackDiagnosticsTests: XCTestCase {

    // MARK: - 断言 1：撤销只删在途登记（子项 A）

    func testIC168A_CancelS2HandoffRemovesInflightRegistrationOnly() async throws {
        await MainActor.run {
            let machine = makeMachine(state: .ready)
            XCTAssertEqual(machine.state, .ready)
            XCTAssertTrue(
                machine.markPendingDeletion(
                    assetIDs: ["b"],
                    virtualRangeID: "cat:screenshot",
                    displayName: "屏幕截图"
                )
            )
            // 写出口在进篮之后才接上（IC-157 断言 1 的写法：接 sink 前不留基准）。
            var published: [S1SessionSnapshot] = []
            machine.persistenceSink = { published.append($0) }

            XCTAssertNotNil(
                machine.makeS2Handoff(virtualRangeID: "cat:screenshot",
                                      displayName: "屏幕截图",
                                      orderedAssetIDs: ["a", "b", "c"],
                                      currentAssetID: "a")
            )
            XCTAssertEqual(machine.activeVirtualRangeIDs, Set(["cat:screenshot"]))
            let publishedBeforeCancel = published.count
            let storeBeforeCancel = machine.sessionStore

            machine.cancelS2Handoff(virtualRangeID: "cat:screenshot")
            XCTAssertTrue(machine.activeVirtualRangeIDs.isEmpty)
            // 不在登记里的标识：无操作、不崩。
            machine.cancelS2Handoff(virtualRangeID: "cat:nothing")
            XCTAssertTrue(machine.activeVirtualRangeIDs.isEmpty)

            // 不写出、不动会话层、名字表留着；提交照常形成，组头仍是类别名。
            XCTAssertEqual(published.count, publishedBeforeCancel)
            XCTAssertEqual(machine.sessionStore, storeBeforeCancel)
            XCTAssertEqual(machine.sessionSnapshot.rangeNamesByID["cat:screenshot"], "屏幕截图")
            let submission = unwrap(machine.makeS3Submission())
            let group = submission.groups.first { $0.sourceRangeID == "cat:screenshot" }
            XCTAssertEqual(group?.name, "屏幕截图")
            XCTAssertEqual(group?.orderedAssetIDs, ["b"])
        }

        let s1Machine = try XCTUnwrap(strippedSource(Self.s1MachinePath))
        XCTAssertEqual(
            occurrences(of: "func cancelS2Handoff(virtualRangeID: String)", in: s1Machine),
            1
        )
        // 写回成功一处 + 撤销入口一处。
        XCTAssertEqual(occurrences(of: "activeVirtualRangeIDs.remove(", in: s1Machine), 2)
    }

    // MARK: - 断言 2：写回失败撤销在途登记，诊断定名 W8b（子项 A、B）

    /// 照 IC-157 断言 7 起一台真实协调器、经虚拟范围交接进 S2，再用 IC-131 的坏载荷（只换会话
    /// 标识）从返回键离开：W1～W7 全过、在途豁免放行 W8a，失败点落在会话档的会话标识判定上。
    func testIC168A_FailedWriteBackClearsInflightRegistrationAndNamesW8b() async {
        await MainActor.run {
            let coordinator = makeReadyCoordinatorInVirtualS2(sessionID: "会话-168A-写回失败")
            let machine = unwrap(coordinator.s1Machine)
            XCTAssertEqual(machine.activeVirtualRangeIDs, Set(["cat:screenshot"]))
            let payload = makeMismatchedSessionPayload(coordinator: coordinator)

            XCTAssertFalse(coordinator.leaveS2(with: payload))
            XCTAssertEqual(coordinator.route, .s1)
            XCTAssertNil(coordinator.s2Machine)
            XCTAssertEqual(coordinator.s1FeedbackEventCount, 1)
            XCTAssertEqual(coordinator.s1FeedbackEvent?.kind, .writeBackFailed)
            // 正对照在 IC-157 断言 7：好载荷写回成功后登记同样为空。
            XCTAssertTrue(machine.activeVirtualRangeIDs.isEmpty)

            let text = unwrap(coordinator.s2ExitDiagnosticsText)
            printDiagnostics(text, label: "A2")
            let lines = text.components(separatedBy: Self.newline)
            XCTAssertEqual(lines.first, "format=ic168-s2-exit-v1")
            for needle in [
                "entry=back",
                "outcome=writeBackFailed",
                "guard=W8b",
                "sessionMatch=false",
                "inflight=true",
                "rangeID=cat:screenshot"
            ] {
                XCTAssertTrue(text.contains(needle), needle)
            }
            // 测试宿主下读库结果不定，只钉这一项存在。
            XCTAssertTrue(
                text.contains("reconciled=true") || text.contains("reconciled=false")
            )
        }
    }

    // MARK: - 断言 3：垃圾桶路径成功也记一份诊断（子项 B）

    /// 照 `FullFlowRoutingTests.testIC048_004…` 的夹具（仓内唯一经 S2 垃圾桶成功进 S3 的先例）。
    func testIC168B_TrashPathSuccessRecordsOkDiagnostics() async {
        await MainActor.run {
            let coordinator = makeGroupedCoordinator(sessionID: "会话-168B-成功")
            openRange("范围-2", coordinator: coordinator)
            let payload = unwrap(coordinator.s2Machine?.makeExitPayload())

            XCTAssertTrue(coordinator.enterConfirmationFromS2(with: payload))
            XCTAssertEqual(coordinator.route, .confirmation)
            XCTAssertEqual(coordinator.s1FeedbackEventCount, 0)

            let text = unwrap(coordinator.s2ExitDiagnosticsText)
            printDiagnostics(text, label: "A3")
            XCTAssertEqual(
                text.components(separatedBy: Self.newline).first,
                "format=ic168-s2-exit-v1"
            )
            for needle in [
                "entry=trash",
                "outcome=ok",
                "guard=none",
                "loadingState=ready"
            ] {
                XCTAssertTrue(text.contains(needle), needle)
            }
            XCTAssertTrue(
                text.contains("reconciled=true") || text.contains("reconciled=false")
            )
        }
    }

    // MARK: - 断言 4：冷启动 S1 仍在加载时，垃圾桶路径由协调器完成首读后进入 S3（IC-170 A 改写为回归形态）

    /// IC-168 时这条用例在 CI 上复现了第 195 条的回落（`guard=M2`，第 200 条真机证实）。IC-170 A 起
    /// 协调器的对账在首读未发生时兼任首读，同一条路径改为进入 S3。注入授权桩让首读落就绪态（贴近
    /// 真机）。诊断取样在写回与对账之前，所以同一份文本里既是加载态又已对上账，就是修法生效的签名。
    func testIC168B_ColdStartLoadingS1TrashPathCompletesFirstReadAndEntersConfirmation() async {
        await MainActor.run {
            let box = IC127LibraryBox(
                assets: [
                    S1PhotoAssetSnapshot(identifier: "资产-3",
                                         creationDate: Date(timeIntervalSince1970: 1_786_000_000)),
                    S1PhotoAssetSnapshot(identifier: "资产-2",
                                         creationDate: Date(timeIntervalSince1970: 1_785_000_000)),
                    S1PhotoAssetSnapshot(identifier: "资产-1",
                                         creationDate: Date(timeIntervalSince1970: 1_784_000_000))
                ]
            )
            let coordinator = CleanupCoordinator(
                photoLibrary: PhotoLibraryService(s1Source: box.source)
            )
            XCTAssertTrue(coordinator.enterS1(sessionID: "会话-168B-冷启动"))
            let machine = unwrap(coordinator.s1Machine)
            XCTAssertEqual(machine.state, .loading)
            XCTAssertEqual(machine.reconciliationCount, 0)

            let assets = ["截图-大", "截图-中", "截图-小"]
            let handoff = unwrap(
                machine.makeS2Handoff(virtualRangeID: "cat:screenshot",
                                      displayName: "屏幕截图",
                                      orderedAssetIDs: assets,
                                      currentAssetID: assets[0])
            )
            XCTAssertTrue(coordinator.enterS2(from: handoff))
            let s2Machine = unwrap(coordinator.s2Machine)
            XCTAssertTrue(s2Machine.handleSwipeUp())
            let payload = unwrap(s2Machine.makeExitPayload())

            XCTAssertTrue(coordinator.enterConfirmationFromS2(with: payload))
            XCTAssertEqual(coordinator.route, .confirmation)
            XCTAssertNil(coordinator.s2Machine)
            XCTAssertNotNil(coordinator.s3Machine)
            XCTAssertEqual(coordinator.s1FeedbackEventCount, 0)
            XCTAssertNil(coordinator.s1FeedbackEvent)
            XCTAssertEqual(coordinator.s3Groups.map(\.name), ["屏幕截图"])
            XCTAssertEqual(machine.state, .ready)
            XCTAssertNil(machine.currentReadRequest)
            XCTAssertEqual(machine.reconciliationCount, 1)

            let text = unwrap(coordinator.s2ExitDiagnosticsText)
            printDiagnostics(text, label: "A4")
            for needle in [
                "entry=trash",
                "loadingState=loading",
                "reconciled=true",
                "outcome=ok",
                "guard=none",
                "inflight=true"
            ] {
                XCTAssertTrue(text.contains(needle), needle)
            }
            XCTAssertFalse(text.contains("guard=M2"))

            // 写回已生效（在途豁免），在途登记随之移除。
            XCTAssertEqual(
                machine.sessionStore.pendingDeletionAssetIDsByRangeID["cat:screenshot"],
                Set([assets[0]])
            )
            XCTAssertTrue(machine.activeVirtualRangeIDs.isEmpty)
        }
    }

    // MARK: - 断言 5：本卡新增的符号都接上了（子项 B、C、D）

    func testIC168BCD_NewSymbolsAreWired() throws {
        let coordinator = try XCTUnwrap(strippedSource(Self.coordinatorPath))
        for (needle, expected) in [
            ("@Published private(set) var s2ExitDiagnosticsText: String?", 1),
            ("private enum S2ExitDiagnosticGuard: String", 1),
            ("private struct S2ExitSample", 1),
            ("private func sampleS2Exit(", 1),
            // 定义 + 两条入口各一处。
            ("sampleS2Exit(", 3),
            ("private func s2ExitGuardFailure(", 1),
            // 定义 + 写回校验一处 + 取样一处。
            ("s2ExitGuardFailure(", 3),
            ("static func s3EntryGuardFailure(", 1),
            ("private var lastS3EntryGuardFailure: S2ExitDiagnosticGuard?", 1),
            ("private func recordS2ExitDiagnostics(", 1),
            // 定义 + 调用六处（E1 两路、E2、E3、两处成功）。
            ("recordS2ExitDiagnostics(", 7),
            ("private func returnToS1AfterFailedWriteBack() -> Bool", 1),
            ("cancelS2Handoff(virtualRangeID:", 1),
            // 分组派生内含 `precondition`，诊断不得读它。
            ("pendingDeletionGroupsByRangeID", 0)
        ] {
            XCTAssertEqual(occurrences(of: needle, in: coordinator), expected, needle)
        }
        let coordinatorRaw = try XCTUnwrap(sourceText(Self.coordinatorPath))
        XCTAssertEqual(occurrences(of: "format=ic168-s2-exit-v1", in: coordinatorRaw), 1)
        // 扫描器把 `return` 后紧跟的字面量判残留：协调器原文零处。正对照：S3 状态机确有。
        XCTAssertEqual(occurrences(of: "return \"", in: coordinatorRaw), 0)
        let s3MachineRaw = try XCTUnwrap(sourceText(Self.s3MachinePath))
        XCTAssertGreaterThanOrEqual(occurrences(of: "return \"", in: s3MachineRaw), 1)

        let s2View = try XCTUnwrap(strippedSource(Self.s2ViewPath))
        for (needle, expected) in [
            ("exitDiagnosticsText: String? = nil", 1),
            ("private let exitDiagnosticsText: String?", 1),
            ("self.exitDiagnosticsText = exitDiagnosticsText", 1),
            // 段序引用 + 定义。
            ("exitDiagnosticsSection", 2),
            ("ShareLink(item: exitDiagnosticsText)", 1),
            ("Text(verbatim: exitDiagnosticsText)", 1)
        ] {
            XCTAssertEqual(occurrences(of: needle, in: s2View), expected, needle)
        }
        let s2ViewRaw = try XCTUnwrap(sourceText(Self.s2ViewPath))
        XCTAssertEqual(occurrences(of: "s2.calibration.exit_diagnostics.title", in: s2ViewRaw), 1)
        XCTAssertEqual(occurrences(of: "s2.calibration.exit_diagnostics.share", in: s2ViewRaw), 1)
        XCTAssertEqual(occurrences(of: "s2.calibration.exit_diagnostics.empty", in: s2ViewRaw), 1)

        let page = try XCTUnwrap(strippedSource(Self.pagePath))
        XCTAssertEqual(occurrences(of: "struct S0FeedbackToastLabel: View", in: page), 1)
        XCTAssertEqual(occurrences(of: "S0FeedbackToastLabel(text: text)", in: page), 1)

        let app = try XCTUnwrap(strippedSource(Self.appPath))
        for (needle, expected) in [
            ("S1FeedbackToastPresenter()", 1),
            ("S0FeedbackToastLabel(text: S1FeedbackToastPresenter.text(for: event.kind))", 1),
            // 两只修饰符 + 定义。
            ("presentCleanupFeedbackEvent(", 3),
            // 「逐张整理」接线一处 + 清理 tab 一处。
            ("consumeS1FeedbackEvent()", 2),
            // 浮层一处 + 呈现函数一处。
            ("s0TabSelection.selectedTab == .cleanup", 2),
            ("s0FlowModel.presentedCategory == nil", 1),
            ("exitDiagnosticsText: coordinator.s2ExitDiagnosticsText", 1),
            ("cancelS2Handoff(virtualRangeID:", 1)
        ] {
            XCTAssertEqual(occurrences(of: needle, in: app), expected, needle)
        }

        let catalog = try loadCatalogValues()
        XCTAssertEqual(catalog["s2.calibration.exit_diagnostics.title"], "S2 退出诊断（IC-168）")
        XCTAssertEqual(catalog["s2.calibration.exit_diagnostics.share"], "复制或分享退出诊断")
        XCTAssertEqual(catalog["s2.calibration.exit_diagnostics.empty"], "本次启动尚未从 S2 退出")
    }

    // MARK: - 断言 6：类别页进入 S2 失败出页内提示（子项 E）

    func testIC168E_CategoryPageShowsToastWhenEnteringS2Fails() throws {
        let page = try XCTUnwrap(strippedSource(Self.pagePath))
        // 属性一处 + 构造形参一处（形参里夹着 `@escaping`）。
        XCTAssertEqual(occurrences(of: "([String], String) -> Bool", in: page), 2)
        XCTAssertEqual(occurrences(of: "onLongPress(", in: page), 1)
        // 进篮成功一处 + 进入失败一处。
        XCTAssertEqual(occurrences(of: "toast.present(", in: page), 2)

        let flow = try XCTUnwrap(strippedSource(Self.flowPath))
        XCTAssertEqual(occurrences(of: "_ = onEnterS2(", in: flow), 0)
        XCTAssertEqual(
            occurrences(of: "onEnterS2(identifier, orderedAssetIDs, currentAssetID)", in: flow),
            1
        )

        let expectedText = "暂时无法逐张查看，请重试。"
        let catalog = try loadCatalogValues()
        XCTAssertEqual(catalog["s0.categoryPage.toast.enterFailed"], expectedText)

        // 呈现器按文案呈现：注入调度器，不依赖真实时钟（IC-156 断言 8 的写法）。
        var scheduled: [(delay: TimeInterval, action: () -> Void)] = []
        let presenter = S0FeedbackToastPresenter(scheduler: { delay, action in
            scheduled.append((delay: delay, action: action))
        })
        XCTAssertNil(presenter.activeText)
        presenter.present(
            text: L10n.text("s0.categoryPage.toast.enterFailed"),
            durationMilliseconds: 2_000
        )
        XCTAssertEqual(presenter.activeText, expectedText)
        XCTAssertEqual(scheduled.count, 1)
        scheduled[0].action()
        XCTAssertNil(presenter.activeText)
    }

    // MARK: - 夹具（照抄各文件的私有 helper：它们是文件私有，不能跨文件调用）

    /// 照 IC-157 断言 7：S1 读到一个真实范围、就绪；类别页长按同一条接线进 S2 并标记当前张。
    @MainActor
    private func makeReadyCoordinatorInVirtualS2(sessionID: String) -> CleanupCoordinator {
        let coordinator = CleanupCoordinator()
        XCTAssertTrue(coordinator.enterS1(sessionID: sessionID))
        let machine = unwrap(coordinator.s1Machine)
        let request = unwrap(machine.currentReadRequest)
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
        XCTAssertEqual(machine.state, .ready)
        let assets = ["截图-大", "截图-中", "截图-小"]
        let handoff = unwrap(
            machine.makeS2Handoff(virtualRangeID: "cat:screenshot",
                                  displayName: "屏幕截图",
                                  orderedAssetIDs: assets,
                                  currentAssetID: assets[1])
        )
        XCTAssertTrue(coordinator.enterS2(from: handoff))
        let s2Machine = unwrap(coordinator.s2Machine)
        XCTAssertTrue(s2Machine.handleSwipeUp())
        return coordinator
    }

    /// 照抄 `IC131S1WriteBackToastTests` 的私有同名 helper：取当前合法载荷，只把
    /// `sourceSessionID` 换成别的会话。
    @MainActor
    private func makeMismatchedSessionPayload(
        coordinator: CleanupCoordinator
    ) -> S2ExitPayload {
        let s2Machine = unwrap(coordinator.s2Machine)
        let good = unwrap(s2Machine.makeExitPayload())
        return S2ExitPayload(
            upstreamReturn: SessionStore.S2Return(
                sourceSessionID: "别的会话-168A",
                sourceRangeID: good.upstreamReturn.sourceRangeID,
                pendingDeletionAssetIDs:
                    good.upstreamReturn.pendingDeletionAssetIDs,
                currentAssetID: good.upstreamReturn.currentAssetID,
                farthestAssetID: good.upstreamReturn.farthestAssetID
            ),
            continuationSnapshot: good.continuationSnapshot
        )
    }

    /// 照抄 `FullFlowRoutingTests` 的私有同名 helper（下同）。
    @MainActor
    private func makeReadyCoordinator(
        sessionID: String,
        ranges: [S1Range]
    ) -> CleanupCoordinator {
        let coordinator = CleanupCoordinator()
        XCTAssertTrue(coordinator.enterS1(sessionID: sessionID))
        completeRead(coordinator: coordinator, ranges: ranges)
        return coordinator
    }

    @MainActor
    private func completeRead(
        coordinator: CleanupCoordinator,
        ranges: [S1Range]
    ) {
        guard let machine = coordinator.s1Machine,
              let request = machine.currentReadRequest else {
            return XCTFail("S1 应持有读取请求")
        }
        XCTAssertTrue(machine.completeRangeRead(.success(ranges), for: request))
    }

    @MainActor
    private func makeGroupedCoordinator(
        sessionID: String
    ) -> CleanupCoordinator {
        let coordinator = makeReadyCoordinator(
            sessionID: sessionID,
            ranges: [
                S1Range(
                    id: "范围-1",
                    displayName: "月份范围",
                    assetIDsNewestFirst: ["资产-S", "资产-A"]
                ),
                S1Range(
                    id: "范围-2",
                    displayName: "相册范围",
                    assetIDsNewestFirst: ["资产-B", "资产-S"]
                )
            ]
        )
        mark(
            ["资产-A", "资产-S"],
            in: "范围-1",
            coordinator: coordinator
        )
        mark(
            ["资产-B", "资产-S"],
            in: "范围-2",
            coordinator: coordinator
        )
        return coordinator
    }

    @MainActor
    private func mark(
        _ assetIDs: Set<String>,
        in rangeID: String,
        coordinator: CleanupCoordinator
    ) {
        guard let machine = coordinator.s1Machine,
              let range = machine.ranges.first(where: { $0.id == rangeID }) else {
            return XCTFail("应找到待标记范围")
        }
        XCTAssertTrue(
            machine.applyS2PendingDeletionChange(
                assetIDs,
                entryContext: SessionStore.S2EntryContext(
                    rangeID: rangeID,
                    orderedAssetIDs: range.orderedAssetIDs(
                        for: machine.sortOrder
                    ),
                    sortOrder: machine.sortOrder.sessionSortOrder
                )
            )
        )
    }

    @MainActor
    private func openRange(
        _ rangeID: String,
        coordinator: CleanupCoordinator
    ) {
        guard let handoff = coordinator.s1Machine?.makeS2Handoff(
            for: rangeID
        ) else {
            return XCTFail("应形成 S1 到 S2 的交接")
        }
        XCTAssertTrue(coordinator.enterS2(from: handoff))
    }

    /// 照抄 `IC157LongPressIntoS2Tests`（它又照抄 `S1StateMachineTests`）的私有同名 helper。
    private func makeMachine(
        state: S1State,
        store: SessionStore = SessionStore(sessionID: "session-default"),
        groupingDimension: S1GroupingDimension = .date,
        ranges: [S1Range]? = nil
    ) -> S1StateMachine {
        let machine = S1StateMachine(
            sessionStore: store,
            initialGroupingDimension: groupingDimension,
            initialSortOrder: .newestFirst
        )
        guard state != .loading,
              let request = machine.currentReadRequest else {
            return machine
        }

        switch state {
        case .loading:
            break
        case .ready:
            precondition(
                machine.completeRangeRead(
                    .success(ranges ?? [makeRange()]),
                    for: request
                )
            )
        case .empty:
            precondition(machine.completeRangeRead(.success([]), for: request))
        case .failed:
            precondition(
                machine.completeRangeRead(
                    .failure(
                        S1RangeReadFailure(
                            groupingDimension: groupingDimension,
                            reason: .invalidResponse
                        )
                    ),
                    for: request
                )
            )
        }
        return machine
    }

    private func makeRange(
        id: String = "range-month",
        displayName: String = "2026-08"
    ) -> S1Range {
        S1Range(
            id: id,
            displayName: displayName,
            assetIDsNewestFirst: ["asset-3", "asset-2", "asset-1"]
        )
    }

    private func unwrap<T>(
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

    /// 诊断文本原文在 CI 日志里各打一次，报告贴出（任务卡「报告」节）。
    private func printDiagnostics(_ text: String, label: String) {
        print("IC168_DIAGNOSTICS_" + label + "_BEGIN")
        print(text)
        print("IC168_DIAGNOSTICS_" + label + "_END")
    }

    // MARK: - 路径

    private static let s1MachinePath = "PhotoCleanupMVE/Core/S1StateMachine.swift"
    private static let s3MachinePath = "PhotoCleanupMVE/Core/S3StateMachine.swift"
    private static let coordinatorPath = "PhotoCleanupMVE/App/CleanupCoordinator.swift"
    private static let appPath = "PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift"
    private static let s2ViewPath = "PhotoCleanupMVE/Features/S2/S2View.swift"
    private static let pagePath = "PhotoCleanupMVE/Features/S0/S0DeckCategoryPageView.swift"
    private static let flowPath = "PhotoCleanupMVE/Features/S0/S0CleanupFlowView.swift"

    // MARK: - 源码扫描 helper（口径与 IC-165／166／167 一致）

    /// 换行符用 `UnicodeScalar` 拼、不写转义字面量（IC-148 #294 的 heredoc 教训）。
    private static let newline = String(Character(UnicodeScalar(UInt8(10))))

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

    /// 读源码并剔掉 `//` 注释与字符串字面量内容。
    private func strippedSource(_ relativePath: String) -> String? {
        guard let source = sourceText(relativePath) else {
            return nil
        }
        let newline = Character(UnicodeScalar(UInt8(10)))
        var output = ""
        var iterator = source.startIndex
        var inString = false
        while iterator < source.endIndex {
            let character = source[iterator]
            let next = source.index(after: iterator)
            if inString {
                if character == "\\" {
                    iterator = next < source.endIndex
                        ? source.index(after: next)
                        : source.endIndex
                    continue
                }
                if character == "\"" {
                    inString = false
                }
                iterator = next
                continue
            }
            if character == "\"" {
                inString = true
                iterator = next
                continue
            }
            if character == "/", next < source.endIndex, source[next] == "/" {
                while iterator < source.endIndex,
                      source[iterator] != newline {
                    iterator = source.index(after: iterator)
                }
                output.append(newline)
                continue
            }
            output.append(character)
            iterator = next
        }
        return output
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

    private func loadCatalogValues() throws -> [String: String] {
        let url = repoRoot()
            .appendingPathComponent("PhotoCleanupMVE/Localizable.xcstrings")
        let data = try Data(contentsOf: url)
        let object = try JSONSerialization.jsonObject(with: data)
        let root = try XCTUnwrap(object as? [String: Any])
        let strings = try XCTUnwrap(root["strings"] as? [String: Any])
        var values: [String: String] = [:]
        for (key, entry) in strings {
            guard let entry = entry as? [String: Any],
                  let localizations = entry["localizations"] as? [String: Any],
                  let chinese = localizations["zh-Hans"] as? [String: Any],
                  let unit = chinese["stringUnit"] as? [String: Any],
                  let value = unit["value"] as? String else {
                continue
            }
            values[key] = value
        }
        XCTAssertGreaterThan(values.count, 100)
        return values
    }
}
