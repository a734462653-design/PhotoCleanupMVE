import Foundation
import XCTest
@testable import PhotoCleanupMVE

/// IC-157：批次 5.2c 长按进 S2——虚拟范围 `cat:<c.id>` 的进入与写回、类别页身份跨路由存活、
/// 返回类别页重算。
///
/// 依据 SPEC-S0 v2（SHA-256 `8A8E…6F44`）第六节、第十节第 1／2 部分、第十四节第 3 部分，
/// SPEC-S1 v9 第七节第 2 部分，SPEC-S2 v21 第七节第 1／3 部分，与任务卡 IC-20260917-157 的六条
/// 裁定。断言编号与任务卡一一对应：1～3 属子项 A，4～5 属子项 B，6～8 属子项 C。本文件随三个
/// 子项的提交逐段加入：A 建文件（断言在类末尾），B 插在类首，C 紧接 B 之后。可摘取单元是
/// A 单独、A→B、A→B→C；B、C 的断言都追加在 A 建的文件里，按提交不能脱离 A 单独摘取。
///
/// **夹具驱动，真机未覆盖**（陷阱 1）：长按手感、进出 S2 的过渡、回来落回类别页、网格消失与
/// 首页数字同步，只有 H78 能判。
final class IC157LongPressIntoS2Tests: XCTestCase {

    // MARK: - 断言 4：长按手势与提示行守页面纪律（子项 B）

    func testIC157B_LongPressGestureAndHintKeepDiscipline() throws {
        let pagePath = "PhotoCleanupMVE/Features/S0/S0CategoryPageView.swift"
        let page = try XCTUnwrap(strippedSource(pagePath))
        XCTAssertEqual(occurrences(of: "LongPressGesture()", in: page), 1)
        XCTAssertEqual(occurrences(of: ".simultaneousGesture(", in: page), 1)
        // 格仍是按钮：「全选」与格各一处尾随闭包写法（返回钮与主按钮是 `action:` 写法）。
        XCTAssertEqual(occurrences(of: "Button {", in: page), 2)
        XCTAssertEqual(occurrences(of: "onTapGesture", in: page), 0)
        // `onLongPressGesture` 含子串 `onLongPress`，故调用与形参各按带标点的写法计数。
        XCTAssertEqual(occurrences(of: "onLongPressGesture", in: page), 0)
        XCTAssertEqual(occurrences(of: "minimumDuration", in: page), 0)
        XCTAssertEqual(occurrences(of: "maximumDistance", in: page), 0)
        XCTAssertEqual(occurrences(of: "onLongPress(", in: page), 1)
        XCTAssertGreaterThanOrEqual(occurrences(of: "onLongPress:", in: page), 1)
        XCTAssertGreaterThanOrEqual(occurrences(of: "selection.items.map(", in: page), 1)

        let pageRaw = try XCTUnwrap(sourceText(pagePath))
        XCTAssertEqual(
            occurrences(of: "L10n.text(\"s0.categoryPage.longPressHint\"", in: pageRaw),
            1
        )

        // 提示行与左文同一字号与明度：两处明度写法都在常驻行切片里。
        let pinnedRow = try XCTUnwrap(
            slice(
                page,
                from: "private var pinnedRow: some View {",
                to: "private var gridScroll: some View {"
            ),
            "常驻行切片没切到——声明文本变了"
        )
        XCTAssertGreaterThanOrEqual(occurrences(of: "HStack", in: pinnedRow), 1)
        XCTAssertEqual(
            occurrences(
                of: "dimmedText(opacity: S0CategoryPageMetrics.pinnedRowOpacity)",
                in: pinnedRow
            ),
            2
        )
        XCTAssertEqual(
            occurrences(of: "S0CategoryPageMetrics.pinnedRowFontSize", in: pinnedRow),
            2
        )

        // IC-156 断言 6 钉住的几处照旧。
        XCTAssertEqual(occurrences(of: "S1ChromeTypography.titleFontSize", in: page), 1)
        XCTAssertEqual(occurrences(of: "Image(systemName: ", in: page), 3)
        let allowed: Set<String> = ["0", "1", "2"]
        let literals = numericLiterals(in: page)
        XCTAssertTrue(
            literals.isSubset(of: allowed),
            "出现了 0／1／2 之外的裸数：" + literals.subtracting(allowed).sorted().joined(separator: ",")
        )

        // 正对照：同一套剥离口径下，`onLongPressGesture` 在 S2 视图里确有命中，上面的 0 不是空转。
        let s2View = try XCTUnwrap(strippedSource("PhotoCleanupMVE/Features/S2/S2View.swift"))
        XCTAssertGreaterThan(occurrences(of: "onLongPressGesture", in: s2View), 0)
    }

    // MARK: - 断言 5：目录加长按提示一条，四处既有计数同步（子项 B）

    func testIC157B_CatalogGainsLongPressHint() throws {
        let catalog = try loadCatalogValues()
        XCTAssertEqual(catalog.keys.filter { $0.hasPrefix("s0.") }.count, 38)
        XCTAssertEqual(catalog.keys.filter { $0.hasPrefix("s0.categoryPage.") }.count, 6)
        let hint = try XCTUnwrap(catalog["s0.categoryPage.longPressHint"])
        XCTAssertEqual(hint, "长按任一格逐张看")
        XCTAssertFalse(hint.contains("{"))

        // 既有测试的整句 needle（不写死行号）。IC-156 文件另有一处与文案无关的 `37)`，
        // 故不拿裸 `37)`／`38)` 计数。
        let behavior = try XCTUnwrap(sourceText("PhotoCleanupMVETests/IC147S0BehaviorTests.swift"))
        XCTAssertEqual(occurrences(of: "s0Values.count, 38)", in: behavior), 1)
        XCTAssertEqual(occurrences(of: "catalogS0Keys.count, 38)", in: behavior), 1)
        let visual = try XCTUnwrap(sourceText("PhotoCleanupMVETests/IC148S0VisualTests.swift"))
        XCTAssertEqual(occurrences(of: "catalogS0Keys.count, 38)", in: visual), 1)
        let categoryPage = try XCTUnwrap(
            sourceText("PhotoCleanupMVETests/IC156CategoryPageTests.swift")
        )
        XCTAssertEqual(
            occurrences(of: "hasPrefix(\"s0.\") }.count, 38)", in: categoryPage),
            1
        )
    }

    // MARK: - 子项 B 的 helper

    /// 数值字面量提取，口径同 IC-148／IC-156 `numericLiterals(in:)`。
    private func numericLiterals(in source: String) -> Set<String> {
        var literals: Set<String> = []
        let characters = Array(source)
        var index = 0
        while index < characters.count {
            guard characters[index].isNumber else {
                index += 1
                continue
            }
            let previous = index > 0 ? characters[index - 1] : " "
            if previous.isLetter || previous == "_" {
                // 标识符内的数字：跳过整个标识符。判据含数字，否则指针不前进、循环不终止。
                while index < characters.count,
                      characters[index].isLetter
                          || characters[index].isNumber
                          || characters[index] == "_" {
                    index += 1
                }
                continue
            }
            var end = index
            while end < characters.count,
                  characters[end].isNumber
                      || characters[end] == "."
                      || characters[end] == "_" {
                end += 1
            }
            if end < characters.count, characters[end].isLetter {
                index = end
                continue
            }
            var token = String(characters[index..<end])
            while token.hasSuffix(".") {
                token.removeLast()
            }
            token = token.replacingOccurrences(of: "_", with: "")
            if previous == "-" {
                token = "-" + token
            }
            if !token.isEmpty {
                literals.insert(token)
            }
            index = end
        }
        return literals
    }

    /// 目录 zh-Hans 取值，口径同 IC-147／IC-156。
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

    // MARK: - 断言 1：虚拟范围交接在任一加载态下可构造并登记名字（子项 A）

    func testIC157A_VirtualHandoffBuildsInAnyStateAndRegistersName() {
        for state in [S1State.loading, .empty, .ready] {
            let label = String(describing: state)
            let machine = makeMachine(state: state)
            XCTAssertEqual(machine.state, state, label)
            XCTAssertTrue(
                machine.markPendingDeletion(
                    assetIDs: ["b"],
                    virtualRangeID: "cat:bigVideo",
                    displayName: "大视频"
                ),
                label
            )
            // 写出口在进篮之后才接上：进篮已把同名登记进名字表，此处名字表并不变化；
            // 接上后的第一次写出只证明构造里确有显式写出（名字单独变化的写出见循环后）。
            var published: [S1SessionSnapshot] = []
            machine.persistenceSink = { published.append($0) }

            let handoff = machine.makeS2Handoff(virtualRangeID: "cat:bigVideo",
                                                displayName: "大视频",
                                                orderedAssetIDs: ["a", "b", "c"],
                                                currentAssetID: "b")
            XCTAssertNotNil(handoff, label)
            XCTAssertEqual(
                handoff?.rangeDisplayInformation,
                S1RangeDisplayInformation(
                    rangeID: "cat:bigVideo",
                    displayName: "大视频",
                    totalAssetCount: 3
                ),
                label
            )
            XCTAssertEqual(handoff?.sessionID, machine.sessionStore.sessionID, label)
            XCTAssertEqual(handoff?.orderedAssetIDs, ["a", "b", "c"], label)
            XCTAssertEqual(handoff?.pendingDeletionAssetIDs, ["b"], label)
            XCTAssertEqual(handoff?.currentAssetID, "b", label)
            XCTAssertEqual(
                handoff?.sessionMergedPendingDeletionCount,
                machine.badgeCount,
                label
            )
            XCTAssertEqual(machine.activeVirtualRangeIDs, ["cat:bigVideo"], label)
            XCTAssertEqual(published.count, 1, label)
            XCTAssertEqual(published.last?.rangeNamesByID["cat:bigVideo"], "大视频", label)

            // 同参再构造：快照无变化，不再写出；在途集合不变。
            XCTAssertNotNil(
                machine.makeS2Handoff(virtualRangeID: "cat:bigVideo",
                                      displayName: "大视频",
                                      orderedAssetIDs: ["a", "b", "c"],
                                      currentAssetID: "b"),
                label
            )
            XCTAssertEqual(published.count, 1, label)
            XCTAssertEqual(machine.activeVirtualRangeIDs, ["cat:bigVideo"], label)

            // 对照：真实范围入口照旧拒绝虚拟范围。
            XCTAssertNil(machine.makeS2Handoff(for: "cat:bigVideo"), label)

            // 非法输入一律 nil，零副作用。
            let storeBefore = machine.sessionStore
            let invalidInputs: [(String, String, [String], String)] = [
                ("cat:screenshot", "屏幕截图", [], "a"),
                ("cat:screenshot", "屏幕截图", ["a", "a"], "a"),
                ("cat:screenshot", "屏幕截图", ["a", "b"], "z"),
                ("cat:screenshot", "", ["a", "b"], "a"),
                ("", "屏幕截图", ["a", "b"], "a")
            ]
            for (rangeID, name, assetIDs, currentAssetID) in invalidInputs {
                XCTAssertNil(
                    machine.makeS2Handoff(virtualRangeID: rangeID,
                                          displayName: name,
                                          orderedAssetIDs: assetIDs,
                                          currentAssetID: currentAssetID),
                    label + " " + rangeID + " " + name + " " + currentAssetID
                )
            }
            XCTAssertEqual(machine.activeVirtualRangeIDs, ["cat:bigVideo"], label)
            XCTAssertEqual(published.count, 1, label)
            XCTAssertEqual(machine.sessionStore, storeBefore, label)
            XCTAssertNil(machine.sessionSnapshot.rangeNamesByID["cat:screenshot"], label)

            if state == .ready {
                let submission = machine.makeS3Submission()
                XCTAssertNotNil(submission)
                let group = submission?.groups.first { $0.sourceRangeID == "cat:bigVideo" }
                XCTAssertEqual(group?.name, "大视频")
                XCTAssertEqual(group?.orderedAssetIDs, ["b"])
            }
        }

        // 名字表单独变化也经写出口落档：从未登记过名字、`M` 里也没有键的范围，构造后恰多写一次，
        // 写出的快照带着名字、`M` 不变。
        let machine = makeMachine(state: .loading)
        var published: [S1SessionSnapshot] = []
        machine.persistenceSink = { published.append($0) }
        XCTAssertTrue(
            machine.markPendingDeletion(
                assetIDs: ["x"],
                virtualRangeID: "cat:bigVideo",
                displayName: "大视频"
            )
        )
        XCTAssertEqual(published.count, 1)
        let storeBefore = machine.sessionStore
        XCTAssertNotNil(
            machine.makeS2Handoff(virtualRangeID: "cat:screenshot",
                                  displayName: "屏幕截图",
                                  orderedAssetIDs: ["s1", "s2"],
                                  currentAssetID: "s2")
        )
        XCTAssertEqual(published.count, 2)
        XCTAssertEqual(published.last?.rangeNamesByID["cat:screenshot"], "屏幕截图")
        XCTAssertNil(published.last?.pendingDeletionAssetIDsByRangeID["cat:screenshot"])
        XCTAssertEqual(machine.sessionStore, storeBefore)
    }

    // MARK: - 断言 2：虚拟范围的逐张镜像与整体写回绕过真实范围的守卫（子项 A）

    func testIC157A_VirtualRangeLiveMirrorAndReturnBypassRangeGates() throws {
        let machine = makeMachine(state: .empty)
        XCTAssertEqual(machine.state, .empty)
        XCTAssertTrue(
            machine.markPendingDeletion(
                assetIDs: ["b"],
                virtualRangeID: "cat:bigVideo",
                displayName: "大视频"
            )
        )
        let handoff = try XCTUnwrap(
            machine.makeS2Handoff(virtualRangeID: "cat:bigVideo",
                                  displayName: "大视频",
                                  orderedAssetIDs: ["a", "b", "c"],
                                  currentAssetID: "b")
        )
        XCTAssertEqual(handoff.pendingDeletionAssetIDs, ["b"])

        var published: [S1SessionSnapshot] = []
        machine.persistenceSink = { published.append($0) }
        let entry = SessionStore.S2EntryContext(
            rangeID: "cat:bigVideo",
            orderedAssetIDs: ["a", "b", "c"],
            sortOrder: .newestFirst
        )

        // 负对照：待删集合越出交接列表，虚拟路径同样拒绝。
        let storeBeforeInvalid = machine.sessionStore
        XCTAssertFalse(machine.applyS2PendingDeletionChange(["a", "z"], entryContext: entry))
        XCTAssertEqual(machine.sessionStore, storeBeforeInvalid)
        XCTAssertEqual(published.count, 0)

        // S2 回报的是全集：交接时已带 b，新标 a。
        XCTAssertTrue(machine.applyS2PendingDeletionChange(["a", "b"], entryContext: entry))
        XCTAssertEqual(machine.sessionStore.pendingDeletionAssetIDsByRangeID["cat:bigVideo"], ["a", "b"])
        XCTAssertEqual(machine.sessionStore.firstMarkedRangeIDByAssetID["a"], "cat:bigVideo")
        XCTAssertEqual(machine.sessionStore.firstMarkedRangeIDByAssetID["b"], "cat:bigVideo")
        XCTAssertEqual(published.count, 1)

        // S2 内撤销 b：差分路径的取消标记同步删 `F` 键。
        XCTAssertTrue(machine.applyS2PendingDeletionChange(["a"], entryContext: entry))
        XCTAssertEqual(machine.sessionStore.pendingDeletionAssetIDsByRangeID["cat:bigVideo"], ["a"])
        XCTAssertEqual(machine.sessionStore.firstMarkedRangeIDByAssetID["a"], "cat:bigVideo")
        XCTAssertNil(machine.sessionStore.firstMarkedRangeIDByAssetID["b"])
        XCTAssertEqual(published.count, 2)

        // 整体写回：`M` 按返回值替换、`K` 记 `O_记录`，在途登记移除。
        XCTAssertTrue(
            machine.applyS2Return(
                SessionStore.S2Return(
                    sourceSessionID: machine.sessionStore.sessionID,
                    sourceRangeID: "cat:bigVideo",
                    pendingDeletionAssetIDs: ["a"],
                    currentAssetID: "c",
                    farthestAssetID: "c"
                ),
                entryContext: entry
            )
        )
        XCTAssertEqual(machine.sessionStore.pendingDeletionAssetIDsByRangeID["cat:bigVideo"], ["a"])
        XCTAssertEqual(
            machine.sessionStore.continuationsByRangeID["cat:bigVideo"],
            SessionStore.Continuation(
                currentAssetID: "c",
                farthestAssetID: "c",
                recordedSortOrder: .newestFirst
            )
        )
        XCTAssertTrue(machine.activeVirtualRangeIDs.isEmpty)
        XCTAssertEqual(published.count, 3)

        // 负对照：同一台 `.empty` 机器上，真实范围的两个入口仍被既有守卫拒绝。
        let storeAfterReturn = machine.sessionStore
        let realEntry = SessionStore.S2EntryContext(
            rangeID: "range-month",
            orderedAssetIDs: ["asset-3", "asset-2", "asset-1"],
            sortOrder: .newestFirst
        )
        XCTAssertFalse(
            machine.applyS2PendingDeletionChange(["asset-3"], entryContext: realEntry)
        )
        XCTAssertFalse(
            machine.applyS2Return(
                SessionStore.S2Return(
                    sourceSessionID: machine.sessionStore.sessionID,
                    sourceRangeID: "range-month",
                    pendingDeletionAssetIDs: ["asset-3"],
                    currentAssetID: "asset-3",
                    farthestAssetID: "asset-3"
                ),
                entryContext: realEntry
            )
        )
        // 写回后不再在途：同一虚拟范围再逐张写入落回既有守卫，被拒。
        XCTAssertFalse(machine.applyS2PendingDeletionChange(["a", "c"], entryContext: entry))
        XCTAssertEqual(machine.sessionStore, storeAfterReturn)
        XCTAssertEqual(published.count, 3)
    }

    // MARK: - 断言 3：真实范围路径逐字不变，差分只有一份（子项 A）

    func testIC157A_RealRangePathsByteIdentical() throws {
        let raw = try XCTUnwrap(sourceText(Self.s1MachinePath))
        let body = try XCTUnwrap(
            slice(
                raw,
                from: Self.realHandoffBodyLines[0],
                to: Self.newline + "    }" + Self.newline
            ),
            "真实范围交接构造的声明行没切到——声明文本变了"
        )
        XCTAssertEqual(
            body + Self.newline + "    }",
            Self.realHandoffBodyLines.joined(separator: Self.newline),
            "makeS2Handoff(for:) 的函数体与 e97f394 不再逐字相同"
        )

        let source = try XCTUnwrap(strippedSource(Self.s1MachinePath))
        XCTAssertEqual(
            occurrences(of: "private(set) var activeVirtualRangeIDs: Set<String> = []", in: source),
            1
        )
        XCTAssertEqual(occurrences(of: "func makeS2Handoff(virtualRangeID:", in: source), 1)
        // `e97f394` 为 5（三个 didSet、对账后补写一处、写出口声明本身）；新构造入口加一处。
        XCTAssertEqual(occurrences(of: "publishSnapshotIfChanged()", in: source), 6)
        XCTAssertEqual(occurrences(of: "private func applyPendingDeletionDiff(", in: source), 1)
        // 声明 1 + 真实范围路径与虚拟范围路径各调用 1。
        XCTAssertEqual(occurrences(of: "applyPendingDeletionDiff(", in: source), 3)
        // `e97f394` 为 3（进篮一处 + 差分循环两处）；循环整段搬进 helper，不另造第三份。
        XCTAssertEqual(occurrences(of: "setMarked(", in: source), 3)
    }

    // MARK: - 子项 A 的夹具与 helper

    private static let s1MachinePath = "PhotoCleanupMVE/Core/S1StateMachine.swift"

    /// `e97f394` 上 `makeS2Handoff(for:)` 的原文（声明行到闭合花括号），逐行。
    private static let realHandoffBodyLines = [
        "    func makeS2Handoff(for rangeID: String) -> S1ToS2Handoff? {",
        "        guard !isObscured,",
        "              state == .ready,",
        "              let range = ranges.first(where: { $0.id == rangeID }) else {",
        "            return nil",
        "        }",
        "",
        "        let orderedAssetIDs = range.orderedAssetIDs(for: sortOrder)",
        "        let assetIDSet = Set(orderedAssetIDs)",
        "        let pendingDeletionAssetIDs =",
        "            sessionStore.pendingDeletionAssetIDsByRangeID[range.id] ?? []",
        "        let currentAssetID = sessionStore.continuationsByRangeID[range.id]?",
        "            .currentAssetID ?? orderedAssetIDs.first",
        "",
        "        guard !orderedAssetIDs.isEmpty,",
        "              assetIDSet.count == orderedAssetIDs.count,",
        "              pendingDeletionAssetIDs.isSubset(of: assetIDSet),",
        "              let currentAssetID,",
        "              assetIDSet.contains(currentAssetID) else {",
        "            return nil",
        "        }",
        "",
        "        return S1ToS2Handoff(",
        "            sessionID: sessionStore.sessionID,",
        "            rangeDisplayInformation: S1RangeDisplayInformation(",
        "                rangeID: range.id,",
        "                displayName: range.displayName,",
        "                totalAssetCount: range.totalAssetCount",
        "            ),",
        "            orderedAssetIDs: orderedAssetIDs,",
        "            currentAssetID: currentAssetID,",
        "            pendingDeletionAssetIDs: pendingDeletionAssetIDs,",
        "            sessionMergedPendingDeletionCountProvider: { self.badgeCount }",
        "        )",
        "    }"
    ]

    /// 照抄 `S1StateMachineTests` 的私有同名 helper（该 helper 为文件私有，不能跨文件调用）。
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

    // MARK: - 源码扫描 helper（口径与 IC-147／IC-148／IC-155／IC-156 一致）

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
}
