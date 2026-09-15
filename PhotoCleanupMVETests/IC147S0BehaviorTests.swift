import Foundation
import SwiftUI
import XCTest
@testable import PhotoCleanupMVE

/// IC-147：S0 行为层——两 tab 容器、清理首页状态机与四态迁移、扫描数据源
/// 协议与桩实现。
///
/// 依据 SPEC-S0 v1（SHA-256 `F5D6…2282`）第二节状态与不变量、第三节四态
/// 四段式、第四节迁移表、第五节点击矩阵、第十四节文案登记；SPEC-S1 v9
/// （SHA-256 `1527…BBD6`）第二节会话层数据的唯一定义处。
///
/// 断言编号与任务卡一一对应，共十三条：1～3 属子项 A，4～8 属子项 B，
/// 9～11 属子项 C，12～13 属子项 D。
///
/// **本卡只做行为层。** 视图断言一律只钉「能看出是哪个态、能点到每个入口」
/// 这一层，不钉任何视觉取值——氛围底、玻璃卡、分段条、类别行版式、hero
/// 大字属 IC-148，届时另立视觉测试。
final class IC147S0BehaviorTests: XCTestCase {

    // MARK: - 断言 1：容器口径（两个 tab、顺序、初始选中）

    func testIC147AAssertion01TabContainerHasExactlyTwoTabsInOrder() throws {
        // 不设第三个 tab（Decision_log 第 159 条）。
        XCTAssertEqual(S0Tab.allCases, [.cleanup, .organize])
        XCTAssertEqual(S0Tab.allCases.count, 2)
        XCTAssertEqual(S0Tab.cleanup.rawValue, "cleanup")
        XCTAssertEqual(S0Tab.organize.rawValue, "organize")

        // 开屏后落在「空间清理」（第 159 条⑤）。
        let selection = S0TabSelectionModel()
        XCTAssertEqual(selection.selectedTab, .cleanup)
        XCTAssertEqual(selection.selectionCount, 0)

        // 源码口径：恰两个 tabItem、恰两个 tag，且两个 tab 名各取一次登记文案。
        let container = try XCTUnwrap(
            strippedSource("PhotoCleanupMVE/Features/S0/S0TabContainer.swift")
        )
        XCTAssertEqual(occurrences(of: ".tabItem", in: container), 2)
        XCTAssertEqual(occurrences(of: ".tag(S0Tab.", in: container), 2)
        XCTAssertEqual(occurrences(of: "TabView(", in: container), 1)

        let rawContainer = try XCTUnwrap(
            sourceText("PhotoCleanupMVE/Features/S0/S0TabContainer.swift")
        )
        XCTAssertEqual(
            occurrences(of: "L10n.text(\"s0.tab.cleanup\")", in: rawContainer),
            1
        )
        XCTAssertEqual(
            occurrences(of: "L10n.text(\"s0.tab.organize\")", in: rawContainer),
            1
        )
    }

    // MARK: - 断言 2：切 tab 无副作用（夹具驱动）

    /// 会话层五项（`sessionID`、`M`、`K`、`F`、`D_全部`）与 S1 的 `T`／`O`
    /// 在来回切 tab 十次后逐个不变。
    ///
    /// **夹具驱动，真机未覆盖**：本断言驱动的是 tab 选择态模型与 S1 状态机，
    /// 不是真实的 SwiftUI `TabView` 重建时序。S1View 的 `@State`（菜单展开态、
    /// 两个提示计数、本地反馈序号）与 `@StateObject` 反馈呈现器都是 `private`，
    /// 测试无法观察，只能由 H70 第 2 条人工判定兜底。
    func testIC147AAssertion02TabSwitchingLeavesSessionDataAndS1SortUntouched()
        throws {
        let store = try XCTUnwrap(
            SessionStore(
                sessionID: "session-147",
                pendingDeletionAssetIDsByRangeID: [
                    "range-a": ["asset-1", "asset-2"],
                    "range-b": ["asset-3"]
                ],
                continuationsByRangeID: [
                    "range-a": SessionStore.Continuation(
                        currentAssetID: "asset-2",
                        farthestAssetID: "asset-2",
                        recordedSortOrder: .newestFirst
                    )
                ],
                firstMarkedRangeIDByAssetID: [
                    "asset-1": "range-a",
                    "asset-2": "range-a",
                    "asset-3": "range-b"
                ]
            )
        )
        let machine = S1StateMachine(
            sessionStore: store,
            initialGroupingDimension: .album,
            initialSortOrder: .oldestFirst
        )
        let selection = S0TabSelectionModel()

        let snapshotBefore = machine.sessionSnapshot
        let badgeBefore = machine.badgeCount
        let mergedBefore = machine.sessionStore.allPendingDeletionAssetIDs
        // 前置非空，否则下面的「逐个不变」会在空集合上空转通过。
        XCTAssertEqual(badgeBefore, 3)
        XCTAssertFalse(mergedBefore.isEmpty)
        XCTAssertEqual(snapshotBefore.groupingDimension, .album)
        XCTAssertEqual(snapshotBefore.sortOrder, .oldestFirst)

        for index in 0..<10 {
            selection.select(index.isMultiple(of: 2) ? .organize : .cleanup)
        }
        XCTAssertEqual(selection.selectionCount, 10)
        XCTAssertEqual(selection.selectedTab, .cleanup)

        // 会话层五项 + `T` + `O` 一次性逐成员比对（`S1SessionSnapshot` 含
        // sessionID／T／O／M／K／F）。
        XCTAssertEqual(machine.sessionSnapshot, snapshotBefore)
        XCTAssertEqual(machine.sessionStore.sessionID, "session-147")
        XCTAssertEqual(
            machine.sessionStore.pendingDeletionAssetIDsByRangeID,
            snapshotBefore.pendingDeletionAssetIDsByRangeID
        )
        XCTAssertEqual(
            machine.sessionStore.continuationsByRangeID,
            snapshotBefore.continuationsByRangeID
        )
        XCTAssertEqual(
            machine.sessionStore.firstMarkedRangeIDByAssetID,
            snapshotBefore.firstMarkedRangeIDByAssetID
        )
        XCTAssertEqual(
            machine.sessionStore.allPendingDeletionAssetIDs,
            mergedBefore
        )
        XCTAssertEqual(machine.badgeCount, badgeBefore)
        XCTAssertEqual(machine.groupingDimension, .album)
        XCTAssertEqual(machine.sortOrder, .oldestFirst)

        // 容器不可能碰路由或会话层：源码内零引用协调器与 S1 状态机。
        let container = try XCTUnwrap(
            strippedSource("PhotoCleanupMVE/Features/S0/S0TabContainer.swift")
        )
        XCTAssertEqual(occurrences(of: "CleanupCoordinator", in: container), 0)
        XCTAssertEqual(occurrences(of: "S1StateMachine", in: container), 0)
        XCTAssertEqual(occurrences(of: "SessionStore", in: container), 0)
        // 正对照：扫描确实读到了内容。
        XCTAssertGreaterThan(occurrences(of: "S0Tab", in: container), 0)
    }

    // MARK: - 断言 3：路由边界（源码扫描带正对照）

    /// tab 容器只出现在 `.s1, .upstream, .finished` 分支内；其余四个路由分支
    /// 的构造与改前逐字相同。
    func testIC147AAssertion03RouteBranchesOtherThanS1AreByteIdentical() throws {
        let app = try XCTUnwrap(
            strippedSource("PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift")
        )

        // tab 容器只在那一个分支里被构造，且只有一处构造点。
        XCTAssertEqual(occurrences(of: "tabContainer(s1Machine: machine)", in: app), 1)
        XCTAssertEqual(occurrences(of: "S0TabContainer(", in: app), 1)

        // 其余四个分支逐字未动（改前为同一段文本）。
        let untouchedBranches = [
            "case .s2:\n                    if let machine = coordinator.s2Machine {\n                        s2Screen(machine: machine)\n                    } else {\n                        ProgressView()\n                    }",
            "case .confirmation:\n                    S3View(coordinator: coordinator)",
            "case .execution:\n                    S4View(coordinator: coordinator)",
            "case .completion:\n                    S5View(coordinator: coordinator)"
        ]
        for branch in untouchedBranches {
            XCTAssertEqual(
                occurrences(of: branch, in: app),
                1,
                "路由分支被改动或格式变了"
            )
        }

        // `.onAppear` 的启动守卫一字未动（E4 口径）。
        XCTAssertEqual(
            occurrences(
                of: "if ProcessInfo.processInfo.environment[\"XCTestConfigurationFilePath\"] == nil {\n                    coordinator.start()\n                }",
                in: try XCTUnwrap(
                    sourceText("PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift")
                )
            ),
            1
        )

        // 正对照：S1 的既有 builder 仍在，且仍只有一处被 tab 容器消费。
        XCTAssertEqual(occurrences(of: "private func s1Screen(machine:", in: app), 1)
        XCTAssertEqual(occurrences(of: "s1Screen(machine: s1Machine)", in: app), 1)
        XCTAssertEqual(occurrences(of: "private func s2Screen(machine:", in: app), 1)
    }

    // MARK: - 断言 4：四态判定（纯函数）

    /// 给定 `SC`、可清理量、`cat` 的各组合，解析出的状态正确；S0-2 与 S0-3
    /// 的分界恰在可清理量是否为零。
    func testIC147BAssertion04StateResolverCoversEveryInputCombination() {
        let scanStates: [S0ScanState] = [.scanning, .completed, .failed]
        let counts = [0, 1, 269]
        let categories: [S0FailureCategory?] = [nil, .authorization, .read]

        var combinationCount = 0
        for scanState in scanStates {
            for count in counts {
                for category in categories {
                    combinationCount += 1
                    let resolved = S0StateResolver.state(
                        for: S0StateInput(
                            scanState: scanState,
                            cleanableAssetCount: count,
                            failureCategory: category
                        )
                    )
                    switch scanState {
                    case .scanning:
                        XCTAssertEqual(resolved, .scanning)
                    case .failed:
                        // `cat` 只分版式、不分列：两种失败类别同落 S0-4。
                        XCTAssertEqual(resolved, .failed)
                    case .completed:
                        XCTAssertEqual(resolved, count == 0 ? .empty : .ready)
                    }
                }
            }
        }
        XCTAssertEqual(combinationCount, 27)

        // 分界恰在零：269 → 268 → … → 1 全是 S0-2，只有 0 是 S0-3。
        XCTAssertEqual(
            S0StateResolver.state(
                for: S0StateInput(
                    scanState: .completed,
                    cleanableAssetCount: 1,
                    failureCategory: nil
                )
            ),
            .ready
        )
        XCTAssertEqual(
            S0StateResolver.state(
                for: S0StateInput(
                    scanState: .completed,
                    cleanableAssetCount: 0,
                    failureCategory: nil
                )
            ),
            .empty
        )

        // 四个状态标识与规格逐字一致。
        XCTAssertEqual(S0State.scanning.rawValue, "S0-1")
        XCTAssertEqual(S0State.ready.rawValue, "S0-2")
        XCTAssertEqual(S0State.empty.rawValue, "S0-3")
        XCTAssertEqual(S0State.failed.rawValue, "S0-4")
    }

    // MARK: - 断言 5：迁移表逐行（SPEC-S0 v1 第四节，十三行）

    /// 第四节共 13 行，本测试逐行覆盖并以 `coveredRows` 对账。
    func testIC147BAssertion05TransitionTableEveryRowIsCovered() {
        var coveredRows: Set<Int> = []

        // 第 1 行：页面外 | 打开应用 | S0-1（不设「未开始」，进来即扫描中）。
        do {
            let machine = S0StateMachine()
            machine.ingest(readySnapshot())
            XCTAssertEqual(machine.handle(.applicationOpened), .home(.scanning))
            XCTAssertEqual(machine.scanState, .scanning)
            // 附带效果：缓存完整且无新增时随即到 S0-2／S0-3。
            XCTAssertEqual(machine.handle(.scanCompleted), .home(.ready))
            coveredRows.insert(1)
        }

        // 第 2 行：S0-1 | 扫描完成，可清理 > 0 | S0-2 | 一次性降序重排。
        do {
            let machine = scanningMachine(snapshot: readySnapshot())
            XCTAssertEqual(machine.categoryReorderCount, 0)
            XCTAssertEqual(machine.handle(.scanCompleted), .home(.ready))
            XCTAssertEqual(machine.state, .ready)
            XCTAssertEqual(machine.categoryReorderCount, 1)
            coveredRows.insert(2)
        }

        // 第 3 行：S0-1 | 扫描完成，可清理 = 0 | S0-3。
        do {
            let machine = scanningMachine(snapshot: emptySnapshot())
            XCTAssertEqual(machine.handle(.scanCompleted), .home(.empty))
            XCTAssertEqual(machine.state, .empty)
            coveredRows.insert(3)
        }

        // 第 4 行：S0-1 | 扫描失败 | S0-4 | 记 `cat`。
        for category in [S0FailureCategory.authorization, .read] {
            let machine = scanningMachine(snapshot: readySnapshot())
            XCTAssertEqual(machine.handle(.scanFailed(category)), .home(.failed))
            XCTAssertEqual(machine.state, .failed)
            XCTAssertEqual(machine.failureCategory, category)
            coveredRows.insert(4)
        }

        // 第 5 行：S0-1／S0-2 | 点击类别行 | 类别页 | 传类别标识。
        do {
            let ready = readyMachine(snapshot: readySnapshot())
            XCTAssertEqual(
                ready.handle(.categoryRowTapped(.bigVideo)),
                .categoryPage(.bigVideo)
            )
            // S0-1 下已开始统计的类别同样可进。
            let scanning = scanningMachine(snapshot: scanningSnapshot())
            XCTAssertEqual(
                scanning.handle(.categoryRowTapped(.screenshot)),
                .categoryPage(.screenshot)
            )
            coveredRows.insert(5)
        }

        // 第 6 行：S0-1／S0-2／S0-3 | 点击待删篮胶囊 | S3。
        do {
            for machine in [
                scanningMachine(snapshot: scanningSnapshot()),
                readyMachine(snapshot: readySnapshot()),
                readyMachine(snapshot: emptySnapshot())
            ] {
                machine.mergedPendingDeletionCountProvider = { 3 }
                XCTAssertEqual(machine.handle(.basketCapsuleTapped), .confirmation)
            }
            coveredRows.insert(6)
        }

        // 第 7 行：类别页 | 返回 | 原状态 | 重算后可清理为零即落 S0-3。
        do {
            let machine = readyMachine(snapshot: readySnapshot())
            XCTAssertEqual(machine.handle(.returnedFromCategoryPage), .home(.ready))
            machine.ingest(emptySnapshot())
            XCTAssertEqual(machine.handle(.returnedFromCategoryPage), .home(.empty))
            XCTAssertEqual(machine.scanState, .completed)
            coveredRows.insert(7)
        }

        // 第 8 行：S3 | 返回 | 原状态 | 重算后出现可清理项即回 S0-2。
        do {
            let machine = readyMachine(snapshot: emptySnapshot())
            XCTAssertEqual(machine.handle(.returnedFromConfirmation), .home(.empty))
            machine.ingest(readySnapshot())
            XCTAssertEqual(machine.handle(.returnedFromConfirmation), .home(.ready))
            coveredRows.insert(8)
        }

        // 第 9 行：S0-2 | 核对通过 | S0-2 | `Z += Y`、账本清零、`LG=空`。
        do {
            let machine = readyMachine(snapshot: ledgerSnapshot())
            XCTAssertEqual(machine.ledgerState, .nonEmpty)
            XCTAssertTrue(machine.beginVerification())
            XCTAssertEqual(machine.verificationState, .checking)
            XCTAssertEqual(
                machine.handle(.verificationPassed(releasedByteCount: 2_400_000_000)),
                .home(.ready)
            )
            XCTAssertEqual(machine.lastVerifiedReleasedByteCount, 2_400_000_000)
            XCTAssertEqual(machine.cumulativeReleasedByteCount, 2_400_000_000)
            XCTAssertEqual(machine.ledgerState, .empty)
            XCTAssertEqual(machine.verificationState, .passed)
            XCTAssertEqual(machine.state, .ready)
            // 「账本清零」不是只翻旗标：条目一并清掉，等待清空总量同步归零。
            XCTAssertTrue(machine.snapshot.ledgerEntries.isEmpty)
            XCTAssertEqual(machine.pendingClearanceByteCount, 0)

            // 第二轮核对：`Y` 只记本次，`Z` 才累加——二者混用会让
            // 「设备可用空间 +」读出两次之和（六个数字的措辞隔离）。
            machine.ingest(ledgerSnapshot())
            XCTAssertEqual(machine.ledgerState, .nonEmpty)
            XCTAssertTrue(machine.beginVerification())
            XCTAssertEqual(
                machine.handle(.verificationPassed(releasedByteCount: 1_000_000_000)),
                .home(.ready)
            )
            XCTAssertEqual(machine.lastVerifiedReleasedByteCount, 1_000_000_000)
            XCTAssertEqual(machine.cumulativeReleasedByteCount, 3_400_000_000)
            XCTAssertNotEqual(
                machine.lastVerifiedReleasedByteCount,
                machine.cumulativeReleasedByteCount
            )
            coveredRows.insert(9)
        }

        // 第 10 行：S0-2 | 核对未通过 | S0-2 | 账本不变。
        do {
            let machine = readyMachine(snapshot: ledgerSnapshot())
            XCTAssertTrue(machine.beginVerification())
            XCTAssertEqual(machine.handle(.verificationFailed), .home(.ready))
            XCTAssertEqual(machine.ledgerState, .nonEmpty)
            XCTAssertEqual(machine.verificationState, .failed)
            XCTAssertEqual(machine.cumulativeReleasedByteCount, 0)
            coveredRows.insert(10)
        }

        // 第 11 行：任一 | 前台恢复且有新增资产 | S0-1 | 增量续扫。
        do {
            for machine in [
                scanningMachine(snapshot: scanningSnapshot()),
                readyMachine(snapshot: readySnapshot()),
                readyMachine(snapshot: emptySnapshot()),
                failedMachine(category: .read)
            ] {
                XCTAssertEqual(
                    machine.handle(.foregroundRestored(hasNewAssets: true)),
                    .home(.scanning)
                )
                XCTAssertEqual(machine.scanState, .scanning)
            }
            coveredRows.insert(11)
        }

        // 第 12 行：任一 | 切换到「逐张整理」| SPEC-S1 v9 | 会话层数据不变。
        do {
            for machine in [
                scanningMachine(snapshot: scanningSnapshot()),
                readyMachine(snapshot: readySnapshot()),
                readyMachine(snapshot: emptySnapshot()),
                failedMachine(category: .authorization)
            ] {
                let stateBefore = machine.state
                let snapshotBefore = machine.snapshot
                XCTAssertEqual(machine.handle(.organizeTabSelected), .organizeTab)
                XCTAssertEqual(machine.state, stateBefore)
                XCTAssertEqual(machine.snapshot, snapshotBefore)
            }
            coveredRows.insert(12)
        }

        // 第 13 行：S0-4 | 重试成功 | S0-1。
        do {
            let machine = failedMachine(category: .read)
            XCTAssertEqual(machine.handle(.retrySucceeded), .home(.scanning))
            XCTAssertEqual(machine.scanState, .scanning)
            XCTAssertNil(machine.failureCategory)
            coveredRows.insert(13)
        }

        // 行数与断言数对账：第四节 13 行，逐行覆盖，不多不少。
        XCTAssertEqual(coveredRows, Set(1...13))
        XCTAssertEqual(coveredRows.count, 13)
    }

    /// 第三节 S0-2 迁出补充一条（不在第四节表内）：前台恢复但**无**新增资产时
    /// 留在原态，并一次性重排。
    func testIC147BForegroundRestorationWithoutNewAssetsStaysAndReordersOnce() {
        let machine = readyMachine(snapshot: readySnapshot())
        let reordersBefore = machine.categoryReorderCount
        XCTAssertEqual(
            machine.handle(.foregroundRestored(hasNewAssets: false)),
            .home(.ready)
        )
        XCTAssertEqual(machine.scanState, .completed)
        XCTAssertEqual(machine.categoryReorderCount, reordersBefore + 1)

        // 但扫描中回到前台**不得**重排：「扫描期间顺序冻结」优先。
        let scanning = scanningMachine(snapshot: scanningSnapshot())
        XCTAssertEqual(scanning.categoryReorderCount, 0)
        XCTAssertEqual(
            scanning.handle(.foregroundRestored(hasNewAssets: false)),
            .home(.scanning)
        )
        XCTAssertEqual(scanning.categoryReorderCount, 0)
    }

    // MARK: - S0-4 的显示元素清单（SPEC-S0 v1 第三节第 4 部分）

    /// 失败态不显示 hero 数值、分段条与类别行；等待清空行同样不显示。
    /// 失败不清空 `snapshot`（重试成功后要续用），所以「就绪过、随后一次
    /// 增量读取失败」这条路径下数据仍在，显隐必须由判定把关。
    func testIC147CFailedStateHidesCategoryRowsAndPendingRow() throws {
        let machine = readyMachine(snapshot: ledgerSnapshot())
        // 正对照：失败前两者都显示，否则下面的全否会空转通过。
        XCTAssertTrue(machine.showsCategoryRows)
        XCTAssertTrue(machine.showsPendingClearanceRow)
        XCTAssertFalse(machine.orderedCategories.isEmpty)

        machine.handle(.scanFailed(.read))
        XCTAssertEqual(machine.state, .failed)
        XCTAssertFalse(machine.showsCategoryRows)
        XCTAssertFalse(machine.showsPendingClearanceRow)
        // 数据本身保留（重试成功后续用），只是不呈现。
        XCTAssertFalse(machine.orderedCategories.isEmpty)
        XCTAssertFalse(machine.snapshot.ledgerEntries.isEmpty)

        // 重试成功后恢复显示。
        machine.handle(.retrySucceeded)
        XCTAssertTrue(machine.showsCategoryRows)
        XCTAssertTrue(machine.showsPendingClearanceRow)

        // 视图层确实经这两道判定，不自行看 `ledgerState` 或数据是否为空。
        let view = try XCTUnwrap(
            strippedSource("PhotoCleanupMVE/Features/S0/S0View.swift")
        )
        XCTAssertEqual(occurrences(of: "machine.showsPendingClearanceRow", in: view), 1)
        XCTAssertEqual(occurrences(of: "machine.showsCategoryRows", in: view), 1)
        // tab 反复选中不得重复摄入并重发 `.applicationOpened`（H70 第 2 条切十次）。
        XCTAssertEqual(occurrences(of: "hasBootstrapped", in: view), 3)
    }

    // MARK: - 断言 6：点击有效性矩阵（SPEC-S0 v1 第五节，七行四列）

    func testIC147BAssertion06ClickMatrixEveryCell() {
        // 行 1：点击有项目的类别行。S0-1 取「已开始统计」的那一格。
        assertMatrixRow(
            input: .categoryRow(hasItems: true, recognition: .counting),
            scanningExpectation: true,
            readyExpectation: false,
            emptyExpectation: false,
            failedExpectation: false
        )
        assertMatrixRow(
            input: .categoryRow(hasItems: true, recognition: .settled),
            scanningExpectation: true,
            readyExpectation: true,
            emptyExpectation: false,
            failedExpectation: false
        )

        // 行 2：点击无项目／未识别的类别行——四态全失效。
        assertMatrixRow(
            input: .categoryRow(hasItems: false, recognition: .settled),
            scanningExpectation: false,
            readyExpectation: false,
            emptyExpectation: false,
            failedExpectation: false
        )
        assertMatrixRow(
            input: .categoryRow(hasItems: true, recognition: .awaitingScanCompletion),
            scanningExpectation: false,
            readyExpectation: false,
            emptyExpectation: false,
            failedExpectation: false
        )

        // 行 3：点击待删篮胶囊——`D_全部` 非空时前三态有效，S0-4 失效。
        assertMatrixRow(
            input: .basketCapsule,
            scanningExpectation: true,
            readyExpectation: true,
            emptyExpectation: true,
            failedExpectation: false,
            mergedPendingDeletionCount: 3
        )
        // `D_全部` 为空时四态全失效。
        assertMatrixRow(
            input: .basketCapsule,
            scanningExpectation: false,
            readyExpectation: false,
            emptyExpectation: false,
            failedExpectation: false,
            mergedPendingDeletionCount: 0
        )

        // 行 4：点击人像圆钮——四态全有效。
        assertMatrixRow(
            input: .profileButton,
            scanningExpectation: true,
            readyExpectation: true,
            emptyExpectation: true,
            failedExpectation: true
        )

        // 行 5：点击「我已清空」——`LG=非空` 时前三态有效，S0-4 失效。
        assertMatrixRow(
            input: .ledgerCleared,
            scanningExpectation: true,
            readyExpectation: true,
            emptyExpectation: true,
            failedExpectation: false,
            includesLedgerEntry: true
        )
        assertMatrixRow(
            input: .ledgerCleared,
            scanningExpectation: false,
            readyExpectation: false,
            emptyExpectation: false,
            failedExpectation: false,
            includesLedgerEntry: false
        )

        // 行 6：切换 tab——四态全有效。
        assertMatrixRow(
            input: .tabSwitch,
            scanningExpectation: true,
            readyExpectation: true,
            emptyExpectation: true,
            failedExpectation: true
        )

        // 行 7：「打开系统设置」／「重试」——只有 S0-4 有此项且有效。
        assertMatrixRow(
            input: .failureRecovery,
            scanningExpectation: false,
            readyExpectation: false,
            emptyExpectation: false,
            failedExpectation: true
        )
    }

    /// `Q=呈现` 时首页全部输入不接收；关闭后恢复其覆盖前的基础状态，
    /// 全部数据不变。
    func testIC147BAssertion06ObscuringRejectsEveryInputAndRestoresState() {
        let machine = readyMachine(snapshot: ledgerSnapshot())
        machine.mergedPendingDeletionCountProvider = { 3 }
        let stateBefore = machine.state
        let snapshotBefore = machine.snapshot
        let ledgerBefore = machine.ledgerState
        let orderBefore = machine.orderedCategoryIDs

        let everyInput: [S0Input] = [
            .categoryRow(hasItems: true, recognition: .settled),
            .categoryRow(hasItems: false, recognition: .settled),
            .basketCapsule,
            .profileButton,
            .ledgerCleared,
            .tabSwitch,
            .failureRecovery
        ]
        // 正对照：遮挡前至少有一个输入是接收的，否则下面的全否会空转通过。
        XCTAssertTrue(everyInput.contains { machine.accepts($0) })

        machine.setObscuring(.presented)
        for input in everyInput {
            XCTAssertFalse(machine.accepts(input), "Q=呈现 仍接收了输入")
        }
        XCTAssertFalse(machine.beginVerification())
        XCTAssertEqual(
            machine.handle(.categoryRowTapped(.bigVideo)),
            .home(stateBefore)
        )
        XCTAssertEqual(machine.handle(.basketCapsuleTapped), .home(stateBefore))

        machine.setObscuring(.closed)
        XCTAssertEqual(machine.state, stateBefore)
        XCTAssertEqual(machine.snapshot, snapshotBefore)
        XCTAssertEqual(machine.ledgerState, ledgerBefore)
        XCTAssertEqual(machine.orderedCategoryIDs, orderBefore)
        XCTAssertEqual(machine.verificationState, .none)
        XCTAssertTrue(machine.accepts(.profileButton))
    }

    // MARK: - 断言 7：状态量汇集口（陷阱 19，源码扫描带正对照）

    /// `SC`、`LG`、`VF` 三个状态量的直写点数量各恰 1，即只经汇集口写入。
    func testIC147BAssertion07EachStateVariableHasExactlyOneDirectWrite() throws {
        let machineSource = try XCTUnwrap(
            strippedSource("PhotoCleanupMVE/Core/S0StateMachine.swift")
        )
        let funnels = [
            ("scanState = ", "private func setScanState("),
            ("ledgerState = ", "private func setLedgerState("),
            ("verificationState = ", "private func setVerificationState(")
        ]
        for (assignment, funnel) in funnels {
            // 正对照：汇集口存在且唯一。
            XCTAssertEqual(
                occurrences(of: funnel, in: machineSource),
                1,
                funnel + " 不存在或不唯一"
            )
            XCTAssertEqual(
                occurrences(of: assignment, in: machineSource),
                1,
                assignment + " 的直写点不是恰一处"
            )
        }

        // 视图层与容器层一处都不许直写这三个状态量。
        for relativePath in [
            "PhotoCleanupMVE/Features/S0/S0View.swift",
            "PhotoCleanupMVE/Features/S0/S0TabContainer.swift",
            "PhotoCleanupMVE/Services/S0CleanupDataStub.swift",
            "PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift"
        ] {
            let source = try XCTUnwrap(strippedSource(relativePath))
            for (assignment, _) in funnels {
                XCTAssertEqual(
                    occurrences(of: assignment, in: source),
                    0,
                    relativePath + " 直写了 " + assignment
                )
            }
        }
    }

    // MARK: - 断言 8：扫描中不重排（第 165 条第 1 条）

    func testIC147BAssertion08OrderFreezesWhileScanningAndReordersOnceOnCompletion() {
        let machine = S0StateMachine()
        machine.handle(.applicationOpened)

        // 扫描中连摄入三次，顺序恒为数据源的到达顺序，一次都不重排。
        let arrivalOrder: [S0CategoryIdentifier] = [
            .screenshot, .bigVideo, .screenRecording, .duplicate, .similar
        ]
        for step in 1...3 {
            machine.ingest(scanningSnapshot(step: step))
            XCTAssertEqual(machine.orderedCategoryIDs, arrivalOrder)
            XCTAssertEqual(machine.categoryReorderCount, 0, "扫描中发生了重排")
        }

        // 转已完成：恰重排一次，按 `c.bytes` 降序，无项目的沉底。
        machine.ingest(mixedSnapshot())
        XCTAssertEqual(machine.orderedCategoryIDs, arrivalOrder)
        XCTAssertEqual(machine.categoryReorderCount, 0)
        machine.handle(.scanCompleted)
        XCTAssertEqual(machine.categoryReorderCount, 1)
        XCTAssertEqual(
            machine.orderedCategoryIDs,
            [.bigVideo, .screenRecording, .screenshot, .duplicate, .similar]
        )
        // 沉底的两项确实无项目。
        XCTAssertEqual(machine.category(.similar)?.candidateCount, 0)
        XCTAssertEqual(machine.category(.duplicate)?.candidateCount, 0)

        // 已完成后再摄入不会再次重排（「一次性」）。
        machine.ingest(mixedSnapshot())
        XCTAssertEqual(machine.categoryReorderCount, 1)
    }

    // MARK: - 断言 9：协议边界（源码扫描，Features/S0 内 PhotoKit 零命中）

    func testIC147CAssertion09NoPhotoKitSymbolInS0() throws {
        let photoKitSymbols = [
            "PHAsset",
            "PHAssetResource",
            "PHImageManager",
            "PHPhotoLibrary"
        ]
        for relativePath in [
            "PhotoCleanupMVE/Features/S0/S0View.swift",
            "PhotoCleanupMVE/Features/S0/S0TabContainer.swift",
            // 正对照口径：桩实现同样零命中；真实现才会有，而真实现不在本卡。
            "PhotoCleanupMVE/Services/S0CleanupDataStub.swift"
        ] {
            let source = try XCTUnwrap(strippedSource(relativePath))
            XCTAssertGreaterThan(source.count, 0)
            for symbol in photoKitSymbols {
                XCTAssertEqual(
                    occurrences(of: symbol, in: source),
                    0,
                    relativePath + " 出现了 " + symbol
                )
            }
            XCTAssertEqual(occurrences(of: "import Photos", in: source), 0)
        }

        // 正对照：同一套扫描在真实 PhotoKit 服务上命中非零，证明扫描是活的。
        let scanner = try XCTUnwrap(
            strippedSource("PhotoCleanupMVE/Services/AssetSizeScanner.swift")
        )
        XCTAssertGreaterThan(occurrences(of: "PHAsset", in: scanner), 0)
        XCTAssertGreaterThan(occurrences(of: "import Photos", in: scanner), 0)

        // 协议在消费侧定义、实现在 Services（照 `S2AssetSizeProbing` 样板）。
        let view = try XCTUnwrap(
            sourceText("PhotoCleanupMVE/Features/S0/S0View.swift")
        )
        XCTAssertEqual(
            occurrences(of: "protocol S0CleanupDataProviding: AnyObject {", in: view),
            1
        )
        let stub = try XCTUnwrap(
            sourceText("PhotoCleanupMVE/Services/S0CleanupDataStub.swift")
        )
        XCTAssertEqual(
            occurrences(of: "final class S0CleanupDataStub: S0CleanupDataProviding", in: stub),
            1
        )
    }

    // MARK: - 断言 10：六个数字的措辞隔离（SPEC-S0 v1 第二节第 3 部分）

    func testIC147CAssertion10ForbiddenWordingNeverAppears() throws {
        // 「已释放」「已清理」「已节省」——把未清空说成已释放的三种措辞。
        let forbidden = ["已释放", "已清理", "已节省"]

        // (a) Features/S0 源码（**不剔注释**：措辞漂移常先出现在注释里）。
        for relativePath in [
            "PhotoCleanupMVE/Features/S0/S0View.swift",
            "PhotoCleanupMVE/Features/S0/S0TabContainer.swift"
        ] {
            let source = try XCTUnwrap(sourceText(relativePath))
            XCTAssertGreaterThan(source.count, 0)
            for wording in forbidden {
                XCTAssertEqual(
                    occurrences(of: wording, in: source),
                    0,
                    relativePath + " 出现了禁用措辞 " + wording
                )
            }
        }

        // (b) 目录里 `s0.` 全部条目的取值同样零命中。
        let catalog = try loadCatalogValues()
        let s0Values = catalog.filter { $0.key.hasPrefix("s0.") }
        // IC-148 C 新增两条图例 key（`s0.home.legend.rest`／`.unscanned`）。
        XCTAssertEqual(s0Values.count, 32)
        for (key, value) in s0Values {
            for wording in forbidden {
                XCTAssertFalse(
                    value.contains(wording),
                    key + " 出现了禁用措辞 " + wording
                )
            }
        }

        // 正对照：已登记的两句措辞确实在目录里，扫描不是空转。
        XCTAssertEqual(catalog["s0.home.hero.label"], "可清理约")
        XCTAssertEqual(
            catalog["s0.home.pending.label"],
            "在「最近删除」中等待清空 {total}"
        )
    }

    // MARK: - 断言 11：文案登记（key 与 SPEC-S0 v1 第十四节第 3 部分逐条对应）

    func testIC147CAssertion11EveryS0StringGoesThroughTheCatalog() throws {
        let catalog = try loadCatalogValues()
        let catalogS0Keys = Set(catalog.keys.filter { $0.hasPrefix("s0.") })

        var referenced: Set<String> = []
        for relativePath in [
            "PhotoCleanupMVE/Features/S0/S0View.swift",
            "PhotoCleanupMVE/Features/S0/S0TabContainer.swift",
            // IC-148 C：两条图例 key 的引用点在分段条文件里，不加进来
            // 「不多不少」那条会因为少扫一个文件而假红。
            "PhotoCleanupMVE/Features/S0/S0SegmentBar.swift"
        ] {
            let source = try XCTUnwrap(sourceText(relativePath))
            referenced.formUnion(localizationKeys(in: source))

            // 无裸字面量：`Text(` 的实参一律是变量或 `L10n.text(`。
            XCTAssertEqual(
                occurrences(of: "Text(\"", in: source),
                0,
                relativePath + " 出现了裸字面量 Text"
            )
        }

        XCTAssertGreaterThan(referenced.count, 20)
        // 不多不少：目录里的 s0. key 集合恰等于 S0 源码引用的 s0. 集合。
        XCTAssertEqual(referenced.filter { $0.hasPrefix("s0.") }, catalogS0Keys)
        XCTAssertEqual(catalogS0Keys.count, 32)
        // 跨前缀引用只允许一条：受限提示条。
        //
        // IC-148 B 第 6 条要求 S0 画受限提示条，而 SPEC-S0 v1 第十四节第 3 部分
        // **没有登记任何 `s0.` 受限提示条文案**（该缺口 IC-147 报告已登记）。
        // 「未登记的文案不得出现」与「必须画这条」二者只能取其一，取了复用
        // SPEC-S1 v9 已登记的同义文案，并在此把这唯一一条跨前缀引用钉死——
        // 再多一条就是自造文案，判红。
        XCTAssertEqual(
            referenced.filter { !$0.hasPrefix("s0.") },
            ["s1.limited.banner"]
        )
    }

    // MARK: - 断言 12：桩的确定性

    func testIC147DAssertion12StubIsDeterministic() {
        for scenario in S0CleanupDataStubScenario.allCases {
            let stub = S0CleanupDataStub(
                scenario: scenario,
                includesLedgerEntry: true,
                pendingDeletionByteCount: 1_000
            )
            XCTAssertEqual(stub.currentSnapshot(), stub.currentSnapshot())
            XCTAssertEqual(stub.currentScanOutcome(), stub.currentScanOutcome())

            // 两台同参数的桩逐字段相等——不依赖当前时间、不依赖调用次数。
            let twin = S0CleanupDataStub(
                scenario: scenario,
                includesLedgerEntry: true,
                pendingDeletionByteCount: 1_000
            )
            XCTAssertEqual(stub.currentSnapshot(), twin.currentSnapshot())
        }

        // 推进后仍确定：同一步数恒同一结果。
        let a = S0CleanupDataStub(scenario: .scanning)
        let b = S0CleanupDataStub(scenario: .scanning)
        for _ in 0..<S0CleanupDataStub.scanStepCount {
            a.advanceScan()
            b.advanceScan()
            XCTAssertEqual(a.scanStep, b.scanStep)
            XCTAssertEqual(a.currentSnapshot(), b.currentSnapshot())
        }
        // 走到头后不再变化。
        a.advanceScan()
        XCTAssertEqual(a.scanStep, S0CleanupDataStub.scanStepCount)
    }

    // MARK: - 断言 13：桩能驱动出四个态与两种失败类别

    func testIC147DAssertion13StubDrivesEveryStateAndBothFailureCategories() {
        XCTAssertEqual(S0CleanupDataStubScenario.allCases.count, 5)

        // S0-1：扫描中，且进度确实推进。
        let scanning = S0CleanupDataStub(scenario: .scanning)
        let progressMachine = S0StateMachine()
        progressMachine.handle(.applicationOpened)
        progressMachine.ingest(scanning.currentSnapshot())
        XCTAssertEqual(progressMachine.state, .scanning)
        XCTAssertEqual(scanning.currentScanOutcome(), .scanning)
        XCTAssertEqual(progressMachine.snapshot.progress.scannedAssetCount, 0)
        scanning.advanceScan()
        progressMachine.ingest(scanning.currentSnapshot())
        XCTAssertGreaterThan(progressMachine.snapshot.progress.scannedAssetCount, 0)
        XCTAssertGreaterThan(progressMachine.snapshot.cleanableByteCount, 0)

        // 走完全程后桩回报已完成。
        while scanning.scanStep < S0CleanupDataStub.scanStepCount {
            scanning.advanceScan()
        }
        XCTAssertEqual(scanning.currentScanOutcome(), .completed)

        // S0-2：就绪且有可清理项。
        let withItems = S0CleanupDataStub(scenario: .readyWithItems)
        let readyMachineFromStub = machineDriven(by: withItems)
        XCTAssertEqual(readyMachineFromStub.state, .ready)
        XCTAssertGreaterThan(readyMachineFromStub.snapshot.cleanableAssetCount, 0)

        // S0-3：就绪但可清理为零。
        let withoutItems = S0CleanupDataStub(scenario: .readyWithoutItems)
        let emptyMachineFromStub = machineDriven(by: withoutItems)
        XCTAssertEqual(emptyMachineFromStub.state, .empty)
        XCTAssertEqual(emptyMachineFromStub.snapshot.cleanableAssetCount, 0)

        // S0-4：两种失败类别。
        for (scenario, expected) in [
            (S0CleanupDataStubScenario.authorizationFailure, S0FailureCategory.authorization),
            (S0CleanupDataStubScenario.readFailure, S0FailureCategory.read)
        ] {
            let stub = S0CleanupDataStub(scenario: scenario)
            let failed = machineDriven(by: stub)
            XCTAssertEqual(failed.state, .failed)
            XCTAssertEqual(failed.failureCategory, expected)
            XCTAssertEqual(stub.currentScanOutcome(), .failed(expected))
        }

        // `LG` 由账本条目驱动。
        let ledgerStub = S0CleanupDataStub(
            scenario: .readyWithItems,
            includesLedgerEntry: true
        )
        XCTAssertEqual(machineDriven(by: ledgerStub).ledgerState, .nonEmpty)
        XCTAssertEqual(
            machineDriven(by: S0CleanupDataStub(scenario: .readyWithItems)).ledgerState,
            .empty
        )
    }

    // MARK: - 夹具

    private func machineDriven(by stub: S0CleanupDataStub) -> S0StateMachine {
        let machine = S0StateMachine()
        machine.ingest(stub.currentSnapshot())
        switch stub.currentScanOutcome() {
        case .scanning:
            machine.handle(.applicationOpened)
        case .completed:
            machine.handle(.scanCompleted)
        case let .failed(category):
            machine.handle(.scanFailed(category))
        }
        return machine
    }

    private func scanningMachine(snapshot: S0CleanupSnapshot) -> S0StateMachine {
        let machine = S0StateMachine()
        machine.handle(.applicationOpened)
        machine.ingest(snapshot)
        return machine
    }

    private func readyMachine(snapshot: S0CleanupSnapshot) -> S0StateMachine {
        let machine = S0StateMachine()
        machine.ingest(snapshot)
        machine.handle(.scanCompleted)
        return machine
    }

    private func failedMachine(category: S0FailureCategory) -> S0StateMachine {
        let machine = S0StateMachine()
        machine.handle(.scanFailed(category))
        return machine
    }

    private func assertMatrixRow(
        input: S0Input,
        scanningExpectation: Bool,
        readyExpectation: Bool,
        emptyExpectation: Bool,
        failedExpectation: Bool,
        mergedPendingDeletionCount: Int = 0,
        includesLedgerEntry: Bool = false,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let snapshotWithItems = includesLedgerEntry
            ? ledgerSnapshot()
            : readySnapshot()
        let snapshotWithoutItems = emptySnapshot(
            includesLedgerEntry: includesLedgerEntry
        )
        let cases: [(S0State, S0StateMachine, Bool)] = [
            (.scanning, scanningMachine(snapshot: snapshotWithItems), scanningExpectation),
            (.ready, readyMachine(snapshot: snapshotWithItems), readyExpectation),
            (.empty, readyMachine(snapshot: snapshotWithoutItems), emptyExpectation),
            (.failed, failedMachine(category: .authorization), failedExpectation)
        ]
        for (expectedState, machine, expectation) in cases {
            machine.mergedPendingDeletionCountProvider = {
                mergedPendingDeletionCount
            }
            XCTAssertEqual(machine.state, expectedState, file: file, line: line)
            XCTAssertEqual(
                machine.accepts(input),
                expectation,
                "矩阵单元格不符：" + expectedState.rawValue,
                file: file,
                line: line
            )
        }
    }

    private func scanningSnapshot(step: Int = 1) -> S0CleanupSnapshot {
        let multiplier = Int64(step)
        return S0CleanupSnapshot(
            progress: S0ScanProgress(
                scannedAssetCount: 3_000 * step,
                totalAssetCount: 12_000
            ),
            cleanableAssetCount: 26 * step,
            cleanableByteCount: 1_700_000_000 * multiplier,
            libraryTotalByteCount: 48_000_000_000,
            categories: [
                S0CategorySnapshot(
                    id: .screenshot,
                    candidateCount: 21 * step,
                    candidateByteCount: 140_000_000 * multiplier,
                    recognition: .counting
                ),
                S0CategorySnapshot(
                    id: .bigVideo,
                    candidateCount: 3 * step,
                    candidateByteCount: 1_200_000_000 * multiplier,
                    recognition: .counting
                ),
                S0CategorySnapshot(
                    id: .screenRecording,
                    candidateCount: 2 * step,
                    candidateByteCount: 480_000_000 * multiplier,
                    recognition: .counting
                ),
                S0CategorySnapshot(
                    id: .duplicate,
                    candidateCount: 0,
                    candidateByteCount: 0,
                    recognition: .awaitingScanCompletion
                ),
                S0CategorySnapshot(
                    id: .similar,
                    candidateCount: 0,
                    candidateByteCount: 0,
                    recognition: .awaitingScanCompletion
                )
            ]
        )
    }

    /// 已完成的混合数据：三个有项目、两个无项目，用于验证降序 + 沉底。
    private func mixedSnapshot() -> S0CleanupSnapshot {
        S0CleanupSnapshot(
            progress: S0ScanProgress(
                scannedAssetCount: 12_000,
                totalAssetCount: 12_000
            ),
            cleanableAssetCount: 105,
            cleanableByteCount: 6_000_000_000,
            libraryTotalByteCount: 48_000_000_000,
            categories: [
                S0CategorySnapshot(
                    id: .screenshot,
                    candidateCount: 84,
                    candidateByteCount: 560_000_000,
                    recognition: .settled
                ),
                S0CategorySnapshot(
                    id: .bigVideo,
                    candidateCount: 12,
                    candidateByteCount: 4_800_000_000,
                    recognition: .settled
                ),
                S0CategorySnapshot(
                    id: .screenRecording,
                    candidateCount: 9,
                    candidateByteCount: 1_920_000_000,
                    recognition: .settled
                ),
                // 两个无项目的类别：沉底，且并列时按标识排序，结果确定。
                S0CategorySnapshot(
                    id: .duplicate,
                    candidateCount: 0,
                    candidateByteCount: 0,
                    recognition: .settled
                ),
                S0CategorySnapshot(
                    id: .similar,
                    candidateCount: 0,
                    candidateByteCount: 0,
                    recognition: .settled
                )
            ]
        )
    }

    private func readySnapshot() -> S0CleanupSnapshot {
        S0CleanupSnapshot(
            progress: S0ScanProgress(
                scannedAssetCount: 12_000,
                totalAssetCount: 12_000
            ),
            cleanableAssetCount: 269,
            cleanableByteCount: 7_900_000_000,
            libraryTotalByteCount: 48_000_000_000,
            categories: [
                S0CategorySnapshot(
                    id: .bigVideo,
                    candidateCount: 12,
                    candidateByteCount: 4_800_000_000,
                    recognition: .settled
                ),
                S0CategorySnapshot(
                    id: .screenshot,
                    candidateCount: 84,
                    candidateByteCount: 560_000_000,
                    recognition: .settled
                )
            ]
        )
    }

    private func emptySnapshot(
        includesLedgerEntry: Bool = false
    ) -> S0CleanupSnapshot {
        S0CleanupSnapshot(
            progress: S0ScanProgress(
                scannedAssetCount: 12_000,
                totalAssetCount: 12_000
            ),
            cleanableAssetCount: 0,
            cleanableByteCount: 0,
            libraryTotalByteCount: 48_000_000_000,
            categories: [
                S0CategorySnapshot(
                    id: .bigVideo,
                    candidateCount: 0,
                    candidateByteCount: 0,
                    recognition: .settled
                )
            ],
            ledgerEntries: includesLedgerEntry ? [sampleLedgerEntry()] : []
        )
    }

    private func ledgerSnapshot() -> S0CleanupSnapshot {
        S0CleanupSnapshot(
            progress: S0ScanProgress(
                scannedAssetCount: 12_000,
                totalAssetCount: 12_000
            ),
            cleanableAssetCount: 269,
            cleanableByteCount: 7_900_000_000,
            libraryTotalByteCount: 48_000_000_000,
            categories: [
                S0CategorySnapshot(
                    id: .bigVideo,
                    candidateCount: 12,
                    candidateByteCount: 4_800_000_000,
                    recognition: .settled
                ),
                S0CategorySnapshot(
                    id: .screenshot,
                    candidateCount: 84,
                    candidateByteCount: 560_000_000,
                    recognition: .settled
                )
            ],
            ledgerEntries: [sampleLedgerEntry()]
        )
    }

    private func sampleLedgerEntry() -> S0LedgerEntry {
        S0LedgerEntry(
            categoryID: .bigVideo,
            byteCount: 2_400_000_000,
            committedAt: Date(timeIntervalSince1970: 1_789_344_000),
            availableCapacityBaseline: 6_000_000_000
        )
    }

    // MARK: - 源码与目录读取

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

    /// 读源码并剔掉 `//` 注释与字符串字面量内容（与 IC-146 同口径）。
    /// 「有没有用到某个符号」只该看代码；注释里解释该符号会被当成命中。
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

    /// 取出源码里全部 `L10n.text("…")` 的 key。与硬编码扫描器同一口径
    /// （其正则为 `L10n\\.text\\(\\s*"([^"]+)"`）：左括号与引号之间允许换行与
    /// 缩进，key 必须是字面量、不得插值拼接。
    ///
    /// 带 `replacing:` 的调用点是多行写法，`L10n.text(` 与 `"` 之间隔着换行；
    /// 早先按 `L10n.text("` 整串匹配会漏掉全部六个带占位符的 key（本机模拟
    /// 扫描实测 24／30），故此处必须跳空白后再取引号。
    private func localizationKeys(in source: String) -> Set<String> {
        var keys: Set<String> = []
        let opening = "L10n.text("
        var searchStart = source.startIndex
        while let found = source.range(
            of: opening,
            range: searchStart..<source.endIndex
        ) {
            searchStart = found.upperBound
            var cursor = found.upperBound
            while cursor < source.endIndex, source[cursor].isWhitespace {
                cursor = source.index(after: cursor)
            }
            guard cursor < source.endIndex, source[cursor] == "\"" else {
                continue
            }
            let keyStart = source.index(after: cursor)
            guard let closing = source.range(
                of: "\"",
                range: keyStart..<source.endIndex
            ) else {
                break
            }
            keys.insert(String(source[keyStart..<closing.lowerBound]))
            searchStart = closing.upperBound
        }
        return keys
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
