import Foundation
import Photos
import XCTest
@testable import PhotoCleanupMVE

/// IC-170：S1 首次范围读取不再依赖「逐张整理」tab 出现（协调器对账兼任首读，裁定 一、四），
/// 清理 tab 待删篮入口收进协调器并在提交形成不了时出提示（裁定 二）。
///
/// 依据任务卡 IC-20260924-170 的五条裁定。断言 1～3 覆盖子项 A（首读兼任），断言 4～6 覆盖
/// 子项 B（清理 tab 入口）。集合断言期望值一律写成 `Set`（惯例 45）。**只钉本卡新增的行为
/// 与符号**：IC167 的 App 三个 needle 已在 IC167 断言 3 钉住、IC168 断言 5 的符号与 `.retry()`
/// 0 已被他处钉住，不重复（惯例 46）。协调器是主线程隔离，行为断言一律在 `MainActor.run` 里跑。
///
/// **夹具驱动，真机未覆盖**（陷阱 1）：首读耗时与冷启动观感只有 H89 能判。
final class IC170S1FirstReadTests: XCTestCase {

    // MARK: - 断言 1：受限标志与二次对账（子项 A）

    func testIC170A_CoordinatorReconcileCompletesFirstReadAndCarriesLimitedFlag() async {
        await MainActor.run {
            let box = IC127LibraryBox(
                assets: [
                    S1PhotoAssetSnapshot(identifier: "资产-3",
                                         creationDate: Date(timeIntervalSince1970: 1_786_000_000)),
                    S1PhotoAssetSnapshot(identifier: "资产-2",
                                         creationDate: Date(timeIntervalSince1970: 1_785_000_000)),
                    S1PhotoAssetSnapshot(identifier: "资产-1",
                                         creationDate: Date(timeIntervalSince1970: 1_784_000_000))
                ],
                status: .limited
            )
            let coordinator = CleanupCoordinator(
                photoLibrary: PhotoLibraryService(s1Source: box.source)
            )
            XCTAssertTrue(coordinator.enterS1(sessionID: "会话-170A-受限"))
            let machine = unwrap(coordinator.s1Machine)
            XCTAssertEqual(machine.state, .loading)
            XCTAssertEqual(machine.reconciliationCount, 0)
            XCTAssertFalse(machine.isLimitedAuthorization)

            XCTAssertTrue(coordinator.reconcileS1WithPhotoLibrary())
            XCTAssertEqual(machine.state, .ready)
            XCTAssertNil(machine.currentReadRequest)
            XCTAssertEqual(machine.reconciliationCount, 1)
            XCTAssertTrue(machine.isLimitedAuthorization)
            XCTAssertFalse(machine.ranges.isEmpty)
            XCTAssertEqual(coordinator.sessionStore, machine.sessionStore)
            XCTAssertEqual(coordinator.s1FeedbackEventCount, 0)
            XCTAssertNil(coordinator.message)

            // 再调一次：机器已就绪，走原 `reconcile` 分支。
            XCTAssertTrue(coordinator.reconcileS1WithPhotoLibrary())
            XCTAssertEqual(machine.reconciliationCount, 2)
            XCTAssertEqual(machine.state, .ready)
            XCTAssertTrue(machine.isLimitedAuthorization)
        }
    }

    // MARK: - 断言 2：授权失败落 `.failed`、不计入对账、不自动重读（子项 A；决策 26）

    func testIC170A_FirstReadAuthorizationFailureLandsFailedAndIsNotReconciled() async {
        await MainActor.run {
            let box = IC127LibraryBox(
                assets: [
                    S1PhotoAssetSnapshot(identifier: "资产-3",
                                         creationDate: Date(timeIntervalSince1970: 1_786_000_000)),
                    S1PhotoAssetSnapshot(identifier: "资产-2",
                                         creationDate: Date(timeIntervalSince1970: 1_785_000_000)),
                    S1PhotoAssetSnapshot(identifier: "资产-1",
                                         creationDate: Date(timeIntervalSince1970: 1_784_000_000))
                ],
                status: .denied
            )
            let coordinator = CleanupCoordinator(
                photoLibrary: PhotoLibraryService(s1Source: box.source)
            )
            XCTAssertTrue(coordinator.enterS1(sessionID: "会话-170A-拒绝"))
            let machine = unwrap(coordinator.s1Machine)
            XCTAssertEqual(machine.state, .loading)

            XCTAssertFalse(coordinator.reconcileS1WithPhotoLibrary())
            XCTAssertEqual(machine.state, .failed)
            XCTAssertEqual(machine.readFailure?.category, .authorization)
            XCTAssertNil(machine.currentReadRequest)
            XCTAssertEqual(machine.reconciliationCount, 0)
            XCTAssertEqual(coordinator.s1FeedbackEventCount, 0)
            XCTAssertNil(coordinator.message)

            // 不自动重读：再调一次走对账分支，守卫前 +1、守卫内 `.ready` 不成立返回 false。
            XCTAssertFalse(coordinator.reconcileS1WithPhotoLibrary())
            XCTAssertEqual(machine.state, .failed)
            XCTAssertEqual(machine.reconciliationCount, 1)
        }
    }

    // MARK: - 断言 3：返回键路径也完成首读（子项 A）

    func testIC170A_ColdStartBackRouteCompletesFirstRead() async {
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
            XCTAssertTrue(coordinator.enterS1(sessionID: "会话-170A-返回"))
            let machine = unwrap(coordinator.s1Machine)
            XCTAssertEqual(machine.state, .loading)

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

            XCTAssertTrue(coordinator.leaveS2(with: payload))
            XCTAssertEqual(coordinator.route, .s1)
            XCTAssertEqual(coordinator.s1FeedbackEventCount, 0)
            XCTAssertEqual(machine.state, .ready)
            XCTAssertNil(machine.currentReadRequest)
            XCTAssertEqual(machine.reconciliationCount, 1)
            XCTAssertEqual(
                machine.sessionStore.pendingDeletionAssetIDsByRangeID["cat:screenshot"],
                Set([assets[0]])
            )
            XCTAssertTrue(machine.activeVirtualRangeIDs.isEmpty)

            let text = unwrap(coordinator.s2ExitDiagnosticsText)
            printDiagnostics(text, label: "C3")
            for needle in [
                "entry=back",
                "loadingState=loading",
                "reconciled=true",
                "outcome=ok",
                "guard=none"
            ] {
                XCTAssertTrue(text.contains(needle), needle)
            }
        }
    }

    // MARK: - 断言 4：清理 tab 入口在冷启动下直接进入 S3（子项 B）

    func testIC170B_CleanupEntryReachesConfirmationFromColdStart() async {
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
            XCTAssertTrue(coordinator.enterS1(sessionID: "会话-170B-冷启动"))
            let machine = unwrap(coordinator.s1Machine)
            XCTAssertEqual(machine.state, .loading)

            XCTAssertTrue(
                machine.markPendingDeletion(
                    assetIDs: Set(["截图-大"]),
                    virtualRangeID: "cat:screenshot",
                    displayName: "屏幕截图"
                )
            )

            XCTAssertTrue(coordinator.enterConfirmationFromS0())
            XCTAssertEqual(coordinator.route, .confirmation)
            XCTAssertNotNil(coordinator.s3Machine)
            XCTAssertEqual(coordinator.s1FeedbackEventCount, 0)
            XCTAssertNil(coordinator.s1FeedbackEvent)
            XCTAssertEqual(coordinator.s3Groups.map(\.name), ["屏幕截图"])
            XCTAssertEqual(machine.state, .ready)
            XCTAssertEqual(machine.reconciliationCount, 1)
        }
    }

    // MARK: - 断言 5：清理 tab 入口在提交形成不了时发事件、不改路由（子项 B；IC-132 无名档情形）

    func testIC170B_CleanupEntryPublishesEventWhenSubmissionUnavailable() async {
        await MainActor.run {
            let box = IC127LibraryBox(
                assets: [
                    S1PhotoAssetSnapshot(identifier: "资产-1",
                                         creationDate: Date(timeIntervalSince1970: 1_784_000_000)),
                    S1PhotoAssetSnapshot(identifier: "资产-2",
                                         creationDate: Date(timeIntervalSince1970: 1_785_000_000)),
                    S1PhotoAssetSnapshot(identifier: "资产-3",
                                         creationDate: Date(timeIntervalSince1970: 1_786_000_000))
                ]
            )
            let coordinator = CleanupCoordinator(
                photoLibrary: PhotoLibraryService(s1Source: box.source)
            )
            let unnamedSnapshot = S1SessionSnapshot(
                sessionID: "会话-170B-无名",
                groupingDimension: .date,
                sortOrder: .newestFirst,
                pendingDeletionAssetIDsByRangeID: ["相册-未知": Set(["资产-1"])],
                continuationsByRangeID: [:],
                firstMarkedRangeIDByAssetID: ["资产-1": "相册-未知"],
                rangeNamesByID: [:]
            )
            XCTAssertTrue(coordinator.enterS1(restoring: unnamedSnapshot))
            let machine = unwrap(coordinator.s1Machine)
            XCTAssertEqual(machine.state, .loading)
            XCTAssertEqual(coordinator.route, .s1)

            XCTAssertFalse(coordinator.enterConfirmationFromS0())
            XCTAssertEqual(coordinator.route, .s1)
            XCTAssertNil(coordinator.s3Machine)
            XCTAssertEqual(coordinator.s1FeedbackEventCount, 1)
            XCTAssertEqual(coordinator.s1FeedbackEvent?.kind, .submissionUnavailable)
            // 首读已完成——nil 不是因为加载态（M3：名字表缺 `相册-未知`）。
            XCTAssertEqual(machine.state, .ready)
            XCTAssertNil(machine.makeS3Submission())

            XCTAssertFalse(coordinator.enterConfirmationFromS0())
            XCTAssertEqual(coordinator.s1FeedbackEventCount, 2)
        }
    }

    // MARK: - 断言 6：源码接线（子项 A、B）

    func testIC170AB_SourceWiring() throws {
        let coordinator = try XCTUnwrap(strippedSource(Self.coordinatorPath))
        XCTAssertEqual(occurrences(of: "completeRangeRead(", in: coordinator), 1)
        XCTAssertEqual(occurrences(of: "currentReadRequest", in: coordinator), 1)
        XCTAssertEqual(
            occurrences(
                of: "isLimitedAuthorization: response.isLimitedAuthorization",
                in: coordinator
            ),
            2
        )
        XCTAssertEqual(
            occurrences(of: "s1Machine.loadingState == .ready", in: coordinator),
            1
        )
        XCTAssertEqual(occurrences(of: "photoLibrary.s1RangeRead(", in: coordinator), 2)
        XCTAssertEqual(
            occurrences(of: "func enterConfirmationFromS0() -> Bool", in: coordinator),
            1
        )
        XCTAssertEqual(
            occurrences(of: "publishS1FeedbackEvent(.submissionUnavailable)", in: coordinator),
            4
        )

        let app = try XCTUnwrap(strippedSource(Self.appPath))
        XCTAssertEqual(occurrences(of: "coordinator.enterConfirmationFromS0()", in: app), 1)
    }

    // MARK: - 源码扫描 helper（口径与 IC-165／166／167／168 一致）

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

    /// 诊断文本原文在 CI 日志里打一次，报告贴出（任务卡「报告」节）。
    private func printDiagnostics(_ text: String, label: String) {
        print("IC170_DIAGNOSTICS_" + label + "_BEGIN")
        print(text)
        print("IC170_DIAGNOSTICS_" + label + "_END")
    }

    // MARK: - 路径

    private static let coordinatorPath = "PhotoCleanupMVE/App/CleanupCoordinator.swift"
    private static let appPath = "PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift"
}
