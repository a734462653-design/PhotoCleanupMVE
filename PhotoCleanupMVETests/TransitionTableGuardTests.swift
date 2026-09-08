import Foundation
import ObjectiveC
import XCTest
@testable import PhotoCleanupMVE

final class TransitionTableGuardTests: XCTestCase {
    /// IC-138 A：矩阵在判定理由里挂的「事件已撤销」标记。撤销事件的单元格既不能
    /// 提交事件、也不能断言拒绝——事件在类型层面已不存在——故按第三类处理，
    /// 由本常量从表里读出，不在代码里按事件名写特判。
    private static let retiredEventMark = "事件已撤销"

    private struct TransitionCell: Hashable {
        let clauseID: String
        let specification: String
        let event: String
        let sourceState: String
        let isUnreachable: Bool
        /// 该单元格的事件是否已随条款撤销（读表得出，不由代码判定）。
        let isRetiredEvent: Bool

        var coordinate: String {
            "\(specification)|\(event)|\(sourceState)"
        }

        var diagnostic: String {
            "\(clauseID)：事件“\(event)” × 起始状态“\(sourceState)”"
        }
    }

    private let fixedDate = Date(timeIntervalSince1970: 1_786_291_200)

    func testAll115TransitionCellsAndEveryUnreachableCombination() throws {
        let cells = try loadTransitionCells()

        XCTAssertEqual(cells.count, 115, "迁移矩阵必须恰好包含 115 个数据单元格")
        XCTAssertEqual(Set(cells.map(\.coordinate)).count, 115, "迁移矩阵坐标不得重复")
        XCTAssertEqual(Set(cells.map(\.clauseID)).count, 115, "迁移矩阵条款编号不得重复")
        // IC-138 A：行数不变（矩阵按 SPEC-S5 v5 行号编号，v6 晋级前编号保持稳定），
        // 但 L3 整层撤销后有 5 个单元格的事件已不存在，按第三类单独计数；
        // 其余 110 个照旧分可达 / 不可达两类。
        XCTAssertEqual(cells.filter(\.isRetiredEvent).count, 5, "已撤销事件的单元格数量发生变化")
        XCTAssertEqual(cells.filter(\.isUnreachable).count, 63, "不可达标记数量发生变化")
        XCTAssertEqual(
            cells.filter { $0.isUnreachable && !$0.isRetiredEvent }.count,
            59,
            "存续事件里的不可达标记数量发生变化"
        )
        XCTAssertEqual(
            cells.filter { !$0.isUnreachable && !$0.isRetiredEvent }.count,
            51,
            "存续事件里的可达标记数量发生变化"
        )
        XCTAssertEqual(
            Set(cells.map(\.specification)),
            ["SPEC-S3-S4-20260813.v7.md", "SPEC-S5-20260812.v5.md"]
        )

        var visited = Set<String>()
        for cell in cells {
            XCTAssertTrue(visited.insert(cell.coordinate).inserted, cell.diagnostic)
            guard !cell.isRetiredEvent else {
                continue
            }
            guard cell.isUnreachable else {
                continue
            }

            switch cell.specification {
            case "SPEC-S3-S4-20260813.v7.md":
                if cell.sourceState == "S3-2 外部源" {
                    try assertS4Unreachable(cell)
                } else if cell.sourceState.hasPrefix("S3-") || cell.sourceState == "页面外" {
                    try assertS3Unreachable(cell)
                } else {
                    try assertS4Unreachable(cell)
                }
            case "SPEC-S5-20260812.v5.md":
                try assertS5Unreachable(cell)
            default:
                XCTFail("出现范围外规格：\(cell.diagnostic)")
            }
        }

        XCTAssertEqual(visited, Set(cells.map(\.coordinate)), "未遍历全部迁移单元格")
    }

    /// IC-138 A／B 断言 2、3：追溯矩阵引用的每个 XCTest 方法名都必须真实存在。
    /// L3 整层撤销后矩阵里残留了 16 个已删方法名，正向矩阵、反向映射两处都有，
    /// 靠人读发现不了；本断言把它钉死，日后再删测试会当场变红。
    func testIC138EveryTraceabilityMethodNameStillExists() throws {
        let referenced = try loadReferencedMethodNames()
        let registered = loadRegisteredTestMethodNames()

        // 两个集合任一为空都会让下面的差集断言空转，先各钉一个下界。
        XCTAssertGreaterThan(referenced.count, 100, "矩阵方法名解析失败，断言会空转")
        XCTAssertGreaterThan(registered.count, 100, "测试方法枚举失败，断言会空转")

        let missing = referenced.subtracting(registered).sorted()
        XCTAssertEqual(missing, [], "追溯矩阵引用了不存在的测试方法")
    }

    /// 全文扫描：凡以 `test` 开头的标识符 token 都算一次引用。比只读方法名列更严，
    /// 反向映射、未命中测试清单与散文里的引用一并覆盖。
    private func loadReferencedMethodNames() throws -> Set<String> {
        let text = try loadTraceabilityText()
        let wordCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        var names = Set<String>()
        let tokens = text.components(separatedBy: wordCharacters.inverted)
        for token in tokens {
            guard token.hasPrefix("test"), token.count > 4 else {
                continue
            }
            names.insert(token)
        }
        return names
    }

    /// 只枚举本测试包这一个 image 里的类，不扫全进程类表。
    private func loadRegisteredTestMethodNames() -> Set<String> {
        var names = Set<String>()
        guard let imagePath = class_getImageName(Self.self) else {
            return names
        }
        var classCount: UInt32 = 0
        guard let classNames = objc_copyClassNamesForImage(imagePath, &classCount) else {
            return names
        }
        defer { free(UnsafeMutableRawPointer(classNames)) }

        for classIndex in 0..<Int(classCount) {
            let className = String(cString: classNames[classIndex])
            guard let candidate = objc_getClass(className) as? AnyClass else {
                continue
            }
            var walker: AnyClass? = candidate
            var isTestCase = false
            while let current = walker {
                if ObjectIdentifier(current) == ObjectIdentifier(XCTestCase.self) {
                    isTestCase = true
                    break
                }
                walker = class_getSuperclass(current)
            }
            guard isTestCase else {
                continue
            }

            var methodCount: UInt32 = 0
            guard let methods = class_copyMethodList(candidate, &methodCount) else {
                continue
            }
            defer { free(UnsafeMutableRawPointer(methods)) }
            for methodIndex in 0..<Int(methodCount) {
                let selectorName = NSStringFromSelector(method_getName(methods[methodIndex]))
                if selectorName.hasPrefix("test") {
                    names.insert(selectorName)
                }
            }
        }
        return names
    }

    private func loadTraceabilityText() throws -> String {
        guard let url = Bundle(for: Self.self).url(
            forResource: "TRACEABILITY-S3-S5",
            withExtension: "md"
        ) else {
            throw TestError.missingTraceabilityResource
        }
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func loadTransitionCells() throws -> [TransitionCell] {
        let text = try loadTraceabilityText()
        return text.split(separator: "\n", omittingEmptySubsequences: false).compactMap { line in
            let fields = line.split(
                separator: "\t",
                maxSplits: 6,
                omittingEmptySubsequences: false
            ).map(String.init)
            guard fields.count == 7 else {
                return nil
            }

            let reason = fields[6]
            let reachablePrefix = "可达单元格（事件“"
            let unreachablePrefix = "断言型条款（事件“"
            let prefix: String
            let isUnreachable: Bool
            if reason.hasPrefix(reachablePrefix) {
                prefix = reachablePrefix
                isUnreachable = false
            } else if reason.hasPrefix(unreachablePrefix) {
                prefix = unreachablePrefix
                isUnreachable = true
            } else {
                return nil
            }
            let coordinateText = reason.dropFirst(prefix.count)
            let separator = "” × 起始状态“"
            guard let separatorRange = coordinateText.range(of: separator),
                  let closingQuote = coordinateText[separatorRange.upperBound...]
                    .firstIndex(of: "”") else {
                return nil
            }
            let event = coordinateText[..<separatorRange.lowerBound]
            let sourceState = coordinateText[separatorRange.upperBound..<closingQuote]

            return TransitionCell(
                clauseID: fields[0],
                specification: fields[1],
                event: String(event),
                sourceState: String(sourceState),
                isUnreachable: isUnreachable,
                isRetiredEvent: reason.contains(Self.retiredEventMark)
            )
        }
    }

    private func assertS3Unreachable(_ cell: TransitionCell) throws {
        if cell.sourceState == "页面外" {
            XCTAssertFalse(
                [S3State.scanning.rawValue, S3State.ready.rawValue, S3State.empty.rawValue]
                    .contains(cell.sourceState),
                cell.diagnostic
            )
            return
        }

        let machine = try makeS3Machine(for: cell.sourceState)
        switch cell.event {
        case "进入页面":
            XCTAssertEqual(machine.state.rawValue, stateCode(in: cell.sourceState), cell.diagnostic)
        case "扫描完成", "扫描中移除项":
            XCTAssertNotEqual(machine.state, .scanning, cell.diagnostic)
            XCTAssertTrue(machine.pendingScanAssetIDs.isEmpty, cell.diagnostic)
        case "移除单项":
            XCTAssertFalse(machine.removeAsset(identifier: "不存在"), cell.diagnostic)
        case "全部取消":
            XCTAssertFalse(machine.cancelAll(), cell.diagnostic)
        case "集合变为空":
            XCTAssertFalse(machine.collectionBecameEmpty(), cell.diagnostic)
        case "点击提交":
            guard case let .rejected(.invalidState(rejectedState)) =
                    machine.freezeSubmissionSnapshot() else {
                return XCTFail("状态机未拒绝不可达提交：\(cell.diagnostic)")
            }
            XCTAssertEqual(rejectedState, machine.state, cell.diagnostic)
        default:
            XCTFail("未识别的 S3 不可达事件：\(cell.diagnostic)")
        }
    }

    private func assertS4Unreachable(_ cell: TransitionCell) throws {
        if cell.sourceState == "S3-2 外部源" {
            XCTAssertFalse(
                [
                    "S4-1 已提交",
                    "S4-2 已恢复交互",
                    "S4-E1 全批成功",
                    "S4-E2 整批失败",
                    "S4-E3 结果未知"
                ].contains(cell.sourceState),
                cell.diagnostic
            )
            return
        }

        var machine = try makeS4Machine(for: cell.sourceState)
        let transition: S4Transition
        switch cell.event {
        case "提交发起":
            transition = try machine.handle(
                .duplicateSubmissionAttempt,
                persist: ignoreS4Persistence
            )
            XCTAssertEqual(transition.rejection, .duplicateSubmission, cell.diagnostic)
        case "收到成功回调":
            transition = try machine.handle(
                .successCallback(
                    submissionID: machine.snapshot.submissionID,
                    receivedAt: fixedDate
                ),
                persist: ignoreS4Persistence
            )
            XCTAssertEqual(transition.rejection, .terminalAlreadyClosed, cell.diagnostic)
        case "收到失败回调":
            transition = try machine.handle(
                .failureCallback(makeFailureCallback()),
                persist: ignoreS4Persistence
            )
            XCTAssertEqual(transition.rejection, .terminalAlreadyClosed, cell.diagnostic)
        case "超时触发":
            transition = try machine.handle(
                .activeTimeAdvanced(S4StateMachine.timeoutLimitSeconds),
                persist: ignoreS4Persistence
            )
            XCTAssertEqual(transition.rejection, .terminalAlreadyClosed, cell.diagnostic)
        default:
            XCTFail("未识别的 S4 不可达事件：\(cell.diagnostic)")
        }
    }

    private func assertS5Unreachable(_ cell: TransitionCell) throws {
        if cell.sourceState == "外部源" {
            XCTAssertFalse(
                ["S5-T0", "S5-C", "S5-F", "S5-U"].contains(cell.sourceState),
                cell.diagnostic
            )
            return
        }

        if cell.event.hasPrefix("从 S4-") {
            let machine = try makeS5Machine(for: cell.sourceState)
            XCTAssertEqual(machine.state.downstreamTargetState.rawValue, stateCode(in: cell.sourceState))
            return
        }

        var machine = try makeS5Machine(for: cell.sourceState)
        let transition: S5Transition
        switch cell.event {
        case "用户点击“返回确认页”":
            transition = try machine.handle(
                .returnToConfirmation(cacheExists: true),
                persist: ignoreS5Persistence
            )
        case "用户离开页面":
            transition = try machine.handle(.leavePage, persist: ignoreS5Persistence)
        default:
            return XCTFail("未识别的 S5 不可达事件：\(cell.diagnostic)")
        }

        XCTAssertEqual(
            transition.rejection,
            .actionUnavailableInCurrentState,
            cell.diagnostic
        )
        XCTAssertEqual(transition.effect, .none, cell.diagnostic)
    }

    private func makeS3Machine(for state: String) throws -> S3StateMachine {
        switch state {
        case "S3-1 扫描中":
            return S3StateMachine(
                assets: [AssetDescriptor(identifier: "资产-A", isFavorite: false)]
            )
        case "S3-2 就绪":
            return S3StateMachine(
                assets: [AssetDescriptor(identifier: "资产-A", isFavorite: false)],
                cachedConclusions: ["资产-A": .knownBytes(1)]
            )
        case "S3-4 空集":
            return S3StateMachine(assets: [])
        default:
            throw TestError.unknownState(state)
        }
    }

    private func makeS4Machine(for state: String) throws -> S4StateMachine {
        var machine = try S4StateMachine.start(
            snapshot: makeSnapshot(),
            claimAndPersist: { _ in true }
        )
        switch state {
        case "S4-1 已提交":
            return machine
        case "S4-2 已恢复交互":
            _ = try machine.handle(.applicationBecameInactive, persist: ignoreS4Persistence)
            _ = try machine.handle(.applicationBecameActive, persist: ignoreS4Persistence)
        case "S4-E1 全批成功":
            _ = try machine.handle(
                .successCallback(
                    submissionID: machine.snapshot.submissionID,
                    receivedAt: fixedDate
                ),
                persist: ignoreS4Persistence
            )
        case "S4-E2 整批失败":
            _ = try machine.handle(
                .failureCallback(makeFailureCallback()),
                persist: ignoreS4Persistence
            )
        case "S4-E3 结果未知":
            _ = try machine.handle(
                .activeTimeAdvanced(S4StateMachine.timeoutLimitSeconds),
                persist: ignoreS4Persistence
            )
        default:
            throw TestError.unknownState(state)
        }
        return machine
    }

    private func makeS5Machine(for state: String) throws -> S5StateMachine {
        let handoff: S4Handoff
        switch state {
        case "S5-T0":
            let snapshot = makeSnapshot()
            handoff = .success(
                snapshot: snapshot,
                result: S4SuccessResult(
                    submissionID: snapshot.submissionID,
                    successfulAssetIDs: Set(snapshot.assetIDs),
                    receivedAt: fixedDate
                ),
                downstreamTargetState: .movedToRecentlyDeleted
            )
        case "S5-C":
            handoff = .failure(
                snapshot: makeSnapshot(),
                callback: makeCancellationCallback(),
                downstreamTargetState: .cancelled
            )
        case "S5-F":
            handoff = .failure(
                snapshot: makeSnapshot(),
                callback: makeFailureCallback(),
                downstreamTargetState: .failed
            )
        case "S5-U":
            handoff = .unknown(
                snapshot: makeSnapshot(),
                reason: .activeWaitTimedOut,
                downstreamTargetState: .unknown
            )
        default:
            throw TestError.unknownState(state)
        }

        return try S5StateMachine.enter(
            from: handoff,
            persist: ignoreS5Persistence,
            invalidateOldLists: { _ in }
        )
    }

    private func makeSnapshot() -> SubmissionSnapshot {
        SubmissionSnapshot(
            submissionID: "提交-守卫",
            assetIDs: ["资产-A", "资产-B"],
            assetCount: 2,
            knownTotalBytes: 2,
            unavailableCount: 0,
            volumeDisplayMode: .exact,
            favoriteAssetIDs: [],
            frozenAt: fixedDate
        )
    }

    private func makeFailureCallback() -> S4FailureCallback {
        S4FailureCallback(
            submissionID: makeSnapshot().submissionID,
            successfulAssetIDs: ["资产-A"],
            failedAssetIDs: ["资产-B"],
            unprocessedAssetIDs: [],
            reason: S4FailureReason(
                category: .assetNotDeletable,
                message: "测试失败",
                systemDomain: "测试域",
                systemCode: 1
            ),
            receivedAt: fixedDate
        )
    }

    private func makeCancellationCallback() -> S4FailureCallback {
        S4FailureCallback(
            submissionID: makeSnapshot().submissionID,
            successfulAssetIDs: [],
            failedAssetIDs: [],
            unprocessedAssetIDs: Set(makeSnapshot().assetIDs),
            reason: S4FailureReason(
                category: .userCancelled,
                message: "用户取消",
                systemDomain: "测试域",
                systemCode: 2
            ),
            receivedAt: fixedDate
        )
    }

    private func stateCode(in state: String) -> String {
        String(state.split(separator: " ", maxSplits: 1).first ?? "")
    }

    private func ignoreS4Persistence(_ state: S4PersistentState) throws {
        _ = state
    }

    private func ignoreS5Persistence(_ state: S5PersistentState) throws {
        _ = state
    }

    private enum TestError: Error {
        case missingTraceabilityResource
        case unknownState(String)
    }
}
