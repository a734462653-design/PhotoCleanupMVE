import AVFoundation
import SwiftUI
import UIKit
import XCTest
@testable import PhotoCleanupMVE

/// IC-141：视频播放（自动静音循环、浮框接线、快照取封面帧）。
///
/// **本卡只做视频**：`S2LivePhotoPlayback.swift` 零改动，实况行为与 IC-140 相同。
/// 断言 1～4、10～13 是纯 reducer／口径断言；断言 7～9 是分页器夹具断言，
/// 与真机手势序列不同源（陷阱 1），真机落点由 H65 十项兜底。
final class IC141VideoPlaybackTests: XCTestCase {
    private let physicalSize = CGSize(width: 300, height: 600)

    private var screenAspectRatio: CGFloat {
        physicalSize.width / physicalSize.height
    }

    // MARK: - 断言 1：入口不自动播，停稳才播且先静音

    func testIC141A_EntryAssetDoesNotAutoPlayAndSettleMutesBeforePlaying() {
        var machine = S2VideoPlaybackMachine()

        // 入口 A：停稳也不起播。
        XCTAssertTrue(machine.handle(.entered(assetID: "A")).isEmpty)
        XCTAssertTrue(
            machine.handle(.pagingSettled).isEmpty,
            "入口那段在首次停稳就自动播了"
        )

        // 翻到 B：就绪后停稳恰起播一次。
        let becameB = machine.handle(
            .becameCurrent(assetID: "B", neighbours: ["A"])
        )
        let generationB = tryUnwrap(requestGeneration(in: becameB, for: "B"))
        XCTAssertTrue(
            machine.handle(
                .requestSucceeded(assetID: "B", generation: generationB)
            ).isEmpty,
            "尚未停稳就起播了"
        )

        let settled = machine.handle(.pagingSettled)
        XCTAssertEqual(plays(settled), ["B"], "停稳未恰起播一次")
        // 决策 58：声音恒关——静音必须排在起播之前，不留出声窗口。
        let muteIndex = tryUnwrap(
            settled.firstIndex(of: .setMuted(assetID: "B", muted: true))
        )
        let playIndex = tryUnwrap(
            settled.firstIndex(of: .play(assetID: "B"))
        )
        XCTAssertLessThan(muteIndex, playIndex, "起播早于静音")
        XCTAssertTrue(
            settled.contains(.seek(assetID: "B", fraction: 0)),
            "自动播放未从 0 开始"
        )

        // 同页反复停稳不重播。
        XCTAssertTrue(machine.handle(.pagingSettled).isEmpty)
        XCTAssertEqual(machine.state(for: "B"), .playing)
    }

    // MARK: - 断言 2：代次守卫、半径与持有上限

    func testIC141A_LateCallbackIsDroppedAndRadiusHoldsAtMostThreePlayers() {
        var machine = S2VideoPlaybackMachine()
        _ = machine.handle(.entered(assetID: nil))

        // 未就绪停稳 → 无播；就绪即补播。
        let becameB = machine.handle(
            .becameCurrent(assetID: "B", neighbours: [])
        )
        let generationB = tryUnwrap(requestGeneration(in: becameB, for: "B"))
        XCTAssertTrue(machine.handle(.pagingSettled).isEmpty, "未就绪就起播")
        XCTAssertEqual(
            plays(
                machine.handle(
                    .requestSucceeded(assetID: "B", generation: generationB)
                )
            ),
            ["B"],
            "就绪未补播"
        )

        // 旧代次：B 退出半径后迟到的成功回调无效果、状态不变。
        var stale = S2VideoPlaybackMachine()
        _ = stale.handle(.entered(assetID: nil))
        let staleBecameB = stale.handle(
            .becameCurrent(assetID: "B", neighbours: [])
        )
        let staleGeneration = tryUnwrap(
            requestGeneration(in: staleBecameB, for: "B")
        )
        let becameC = stale.handle(
            .becameCurrent(assetID: "C", neighbours: [])
        )
        XCTAssertTrue(
            becameC.contains(
                .cancelRequest(assetID: "B", generation: staleGeneration)
            ),
            "退出半径的在飞请求未取消"
        )
        XCTAssertTrue(
            stale.handle(
                .requestSucceeded(assetID: "B", generation: staleGeneration)
            ).isEmpty,
            "旧代次的迟到成功仍产生了效果"
        )
        XCTAssertEqual(stale.state(for: "B"), .idle, "旧代次改动了已退页的状态")

        // 半径与上限：连翻五页后持有集合 ≤ 3，且恰是当前页 + 两邻居。
        var rolling = S2VideoPlaybackMachine()
        _ = rolling.handle(.entered(assetID: nil))
        let order = ["A", "B", "C", "D", "E"]
        var cancelled: [String] = []
        for (index, assetID) in order.enumerated() {
            let neighbours = [index - 1, index + 1]
                .filter { order.indices.contains($0) }
                .map { order[$0] }
            let effects = rolling.handle(
                .becameCurrent(assetID: assetID, neighbours: neighbours)
            )
            cancelled.append(contentsOf: cancels(effects))
            XCTAssertLessThanOrEqual(
                rolling.heldAssetIDs.count,
                S2MediaMetrics.videoInstanceCap,
                "持有数超过上限"
            )
        }
        XCTAssertEqual(rolling.heldAssetIDs, ["D", "E"])
        XCTAssertEqual(cancelled, ["A", "B", "C"], "被退页未逐个取消在飞请求")
    }

    // MARK: - 断言 3：翻走回起点、翻回重播、至多一段在播

    func testIC141A_LeavingAPageParksItAndReturningPlaysFromTheStart() {
        var machine = S2VideoPlaybackMachine()
        _ = machine.handle(.entered(assetID: nil))
        let becameB = machine.handle(
            .becameCurrent(assetID: "B", neighbours: [])
        )
        let generationB = tryUnwrap(requestGeneration(in: becameB, for: "B"))
        _ = machine.handle(
            .requestSucceeded(assetID: "B", generation: generationB)
        )
        _ = machine.handle(.pagingSettled)
        XCTAssertEqual(machine.playingAssetIDs, ["B"])

        // 翻走：暂停、回 0、静音三件齐，且 B 仍在半径内故不卸载。
        let becameC = machine.handle(
            .becameCurrent(assetID: "C", neighbours: ["B"])
        )
        XCTAssertTrue(becameC.contains(.pause(assetID: "B")))
        XCTAssertTrue(becameC.contains(.seek(assetID: "B", fraction: 0)))
        XCTAssertTrue(becameC.contains(.setMuted(assetID: "B", muted: true)))
        XCTAssertTrue(machine.playingAssetIDs.isEmpty, "翻走后仍有段在播")

        // 翻回 B：停稳即从头再播。
        _ = machine.handle(.becameCurrent(assetID: "B", neighbours: ["C"]))
        let replayed = machine.handle(.pagingSettled)
        XCTAssertEqual(plays(replayed), ["B"], "翻回未重播")
        XCTAssertTrue(replayed.contains(.seek(assetID: "B", fraction: 0)))
        XCTAssertEqual(machine.playingAssetIDs.count, 1, "在播集合大于 1")
    }

    // MARK: - 断言 4：循环

    func testIC141A_ReachingTheEndLoopsOnlyWhilePlaying() {
        var machine = S2VideoPlaybackMachine()
        _ = machine.handle(.entered(assetID: nil))
        let becameB = machine.handle(
            .becameCurrent(assetID: "B", neighbours: [])
        )
        let generationB = tryUnwrap(requestGeneration(in: becameB, for: "B"))
        _ = machine.handle(
            .requestSucceeded(assetID: "B", generation: generationB)
        )
        _ = machine.handle(.pagingSettled)

        let looped = machine.handle(.reachedEnd(assetID: "B"))
        XCTAssertEqual(
            looped,
            [.seek(assetID: "B", fraction: 0), .play(assetID: "B")],
            "播到尾未回 0 续播"
        )
        XCTAssertEqual(machine.state(for: "B"), .playing, "循环后不再是在播态")

        // 暂停态收到尾事件不动（用户暂停在末帧、或翻走后的迟到通知）。
        _ = machine.handle(.userToggledPlayPause)
        XCTAssertEqual(machine.state(for: "B"), .paused)
        XCTAssertTrue(
            machine.handle(.reachedEnd(assetID: "B")).isEmpty,
            "暂停态被尾事件唤醒"
        )
    }

    // MARK: - 夹具

    private func plays(_ effects: [S2VideoPlaybackEffect]) -> [String] {
        effects.compactMap { (effect) -> String? in
            if case let .play(assetID) = effect {
                return assetID
            }
            return nil
        }
    }

    private func cancels(_ effects: [S2VideoPlaybackEffect]) -> [String] {
        effects.compactMap { (effect) -> String? in
            if case let .cancelRequest(assetID, _) = effect {
                return assetID
            }
            return nil
        }
    }

    private func requestGeneration(
        in effects: [S2VideoPlaybackEffect],
        for assetID: String
    ) -> Int? {
        effects.compactMap { (effect) -> Int? in
            if case let .request(identifier, generation) = effect,
               identifier == assetID {
                return generation
            }
            return nil
        }.first
    }

    private func occurrences(of needle: String, in haystack: String) -> Int {
        haystack.components(separatedBy: needle).count - 1
    }

    private func sourceText(_ relativePath: String) -> String? {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = root.appendingPathComponent(relativePath)
        return try? String(contentsOf: url, encoding: .utf8)
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
