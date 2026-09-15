import AVFoundation
import Foundation
import XCTest
@testable import PhotoCleanupMVE

/// IC-150 B 的会话记录器。回报一律成功——**真机上的抛错夹具模拟不出来**
/// （陷阱 1），可失败的那一侧由 `failing` 记录器单独钉。
private final class IC150AudioSessionRecorder: S2AudioSessionControlling {
    private(set) var calls: [String] = []
    /// 置 false 后所有调用都回报失败，用来钉「失败不改记账、留待重试」。
    var succeeds = true

    var activateCount: Int {
        calls.filter { $0 == "setActive(true)" }.count
    }

    var deactivateCount: Int {
        calls.filter {
            $0 == "setActive(false, notifyOthersOnDeactivation)"
        }.count
    }

    func setCategory(_ category: S2AudioSessionCategory) -> Bool {
        calls.append("setCategory(." + category.rawValue + ")")
        return succeeds
    }

    func setActive(
        _ active: Bool,
        notifyOthersOnDeactivation: Bool
    ) -> Bool {
        if active {
            calls.append("setActive(true)")
        } else if notifyOthersOnDeactivation {
            calls.append("setActive(false, notifyOthersOnDeactivation)")
        } else {
            calls.append("setActive(false)")
        }
        return succeeds
    }
}

/// IC-150 B：音频会话静音即打断、退后台不恢复（H69 第 5 项两个症状）。
///
/// **断言钉的是机制，不是真机行为**：静音态的类目与激活次数、停用是否穿过
/// 幂等守卫、会话调用的错误有没有去向。真机落点是 H72 第 3～5 项，
/// 执行端不代为下结论（陷阱 1）。
final class IC150AudioSessionTests: XCTestCase {
    // MARK: - 断言 5：静音播放零激活，且类目是可混音的 .ambient

    func testIC150BAssertion05MutedPlaybackNeverActivatesTheSession() {
        let recorder = IC150AudioSessionRecorder()
        let coordinator = S2VideoPlaybackCoordinator(audioSession: recorder)
        coordinator.enter(assetID: nil)
        coordinator.pageBecameCurrent(assetID: "B", neighbours: [])
        coordinator.pagingSettled()

        XCTAssertEqual(
            recorder.activateCount,
            0,
            "静音播放激活了音频会话"
        )
        // **这一条才是症状 1 的判据。** 只断言「零次激活」在改前就成立
        // ——改前静音态压根不调 `setActive(true)`，音乐照样被打断，因为
        // 会话停在 App 默认的 `.soloAmbient`（不混音）上，`AVPlayer.play()`
        // 会隐式激活它。故必须把类目本身钉住。
        XCTAssertEqual(
            recorder.calls,
            ["setCategory(.ambient)"],
            "静音态没有把类目置成可混音的 .ambient"
        )

        // 正对照：点「有声」后恰一次激活，且类目切到 .playback
        //（侧面静音拨片拨到静音时也出声，H65 第 8 项已判，不得回归）。
        coordinator.toggleMute()
        XCTAssertEqual(recorder.activateCount, 1, "点「有声」不是恰一次激活")
        XCTAssertEqual(
            Array(recorder.calls.suffix(2)),
            ["setCategory(.playback)", "setActive(true)"]
        )
    }

    // MARK: - 断言 6：退后台恰一次「停用且通知他人」，且不被幂等守卫短路

    func testIC150BAssertion06ResignActiveDeactivatesWithoutBeingShortCircuited() {
        let recorder = IC150AudioSessionRecorder()
        let coordinator = S2VideoPlaybackCoordinator(audioSession: recorder)
        coordinator.enter(assetID: nil)
        coordinator.pageBecameCurrent(assetID: "B", neighbours: [])
        coordinator.toggleMute()
        XCTAssertEqual(recorder.activateCount, 1, "前提不成立：会话没被激活")

        coordinator.applicationDidResignActive()
        XCTAssertEqual(
            recorder.deactivateCount,
            1,
            "失活未停用会话，别的应用的音频不会恢复"
        )
        XCTAssertEqual(
            recorder.calls.last,
            "setActive(false, notifyOthersOnDeactivation)",
            "停用没有通知其他应用可以恢复"
        )

        // 「守卫挡掉了停用」这个具体失效钉死：再失活一次零新增（幂等生效），
        // 但**第一次**必须真的穿过守卫——上面那条 deactivateCount == 1 即此。
        coordinator.applicationDidResignActive()
        XCTAssertEqual(recorder.deactivateCount, 1, "幂等守卫失效")

        // reducer 侧：失活时若还在播，必须**先停掉音频 I/O 再停用会话**。
        // 真机上播放器还在跑音频管线时 `setActive(false)` 抛 `!act`（busy），
        // 旧实装用 `try?` 吞掉，于是音乐永远不恢复（H69 第 5 项症状 2）。
        var machine = makeMachinePlaying(assetID: "B")
        _ = machine.handle(.userToggledMute)
        XCTAssertTrue(machine.isUnmutedByUser)
        let effects = machine.handle(.applicationDidResignActive)
        XCTAssertTrue(
            effects.contains(.setMuted(assetID: "B", muted: true)),
            "失活未静音"
        )
        XCTAssertTrue(
            effects.contains(.pause(assetID: "B")),
            "失活时还在播却没有暂停——停用会话会因 busy 抛错并被吞掉"
        )
        XCTAssertEqual(
            machine.state(for: "B"),
            .paused,
            "发了 pause 却没有把状态改成暂停"
        )

        // 正对照：本来就没在播（暂停态）时不多发 pause。
        var paused = makeMachinePlaying(assetID: "B")
        _ = paused.handle(.userToggledMute)
        _ = paused.handle(.userToggledPlayPause)
        XCTAssertEqual(paused.state(for: "B"), .paused)
        let pausedEffects = paused.handle(.applicationDidResignActive)
        XCTAssertFalse(
            pausedEffects.contains(.pause(assetID: "B")),
            "暂停态失活还多发了一次 pause"
        )
    }

    // MARK: - 断言 7：会话调用的错误有可观察的去向

    func testIC150BAssertion07SessionErrorsHaveAnObservableDestination() throws {
        let adapter = try XCTUnwrap(audioSessionAdapterBody())

        // 适配器里不再有裸 `try?`——错误必须走 catch 并落进 lastFailure。
        XCTAssertEqual(
            occurrences(of: "try?", in: adapter),
            0,
            "会话适配器仍有裸 try? 直接把错误丢掉"
        )
        XCTAssertGreaterThan(
            occurrences(of: "catch", in: adapter),
            0,
            "没有任何 catch，错误无处可去"
        )
        XCTAssertGreaterThan(
            occurrences(of: "lastFailure", in: adapter),
            0,
            "错误没有记录去向"
        )

        // 正对照（needle 允许清单）：`try?` 这个 needle 确实能命中——
        // `S2View.swift` 里删临时目录那一处是**允许**的裸 try?：目录本就可能
        // 不存在，失败无害，真正的错误由随后的建目录与写出回报。
        let view = try XCTUnwrap(
            strippedSource("PhotoCleanupMVE/Features/S2/S2View.swift")
        )
        XCTAssertEqual(
            occurrences(of: "try? FileManager.default.removeItem", in: view),
            1,
            "允许清单里那一处没了，本断言的 needle 失去正对照"
        )

        // 协调器侧把成败用起来了：失败不改记账、留待下次重试。
        let failing = IC150AudioSessionRecorder()
        failing.succeeds = false
        let coordinator = S2VideoPlaybackCoordinator(audioSession: failing)
        coordinator.enter(assetID: nil)
        coordinator.pageBecameCurrent(assetID: "B", neighbours: [])
        coordinator.toggleMute()
        XCTAssertGreaterThan(
            coordinator.audioSessionFailureCount,
            0,
            "会话调用失败没有任何可观察的去向"
        )
        // 激活失败没被记成「已激活」，所以再点一次还会重试。
        let firstAttempt = failing.activateCount
        coordinator.toggleMute()
        coordinator.toggleMute()
        XCTAssertGreaterThan(
            failing.activateCount,
            firstAttempt,
            "激活失败被记成成功，幂等守卫此后永远挡着不再重试"
        )
    }

    // MARK: - 断言 8：回归——再回 S2 仍是静音

    func testIC150BAssertion08ReturningToS2StaysMuted() {
        var machine = makeMachinePlaying(assetID: "B")
        _ = machine.handle(.userToggledMute)
        XCTAssertTrue(machine.isUnmutedByUser)

        _ = machine.handle(.applicationDidResignActive)
        XCTAssertFalse(
            machine.isUnmutedByUser,
            "失活未清掉「用户要出声」的意图"
        )

        // 回到 active 不发事件；再翻到本页也仍是静音——要再点「有声」才出声。
        _ = machine.handle(.becameCurrent(assetID: "B", neighbours: []))
        XCTAssertFalse(machine.isUnmutedByUser, "回 S2 自动出声了")
        _ = machine.handle(.userToggledMute)
        XCTAssertTrue(machine.isUnmutedByUser, "再点「有声」没能出声")
    }

    // MARK: - 夹具

    private func makeMachinePlaying(
        assetID: String
    ) -> S2VideoPlaybackMachine {
        var machine = S2VideoPlaybackMachine()
        _ = machine.handle(.entered(assetID: nil))
        let became = machine.handle(
            .becameCurrent(assetID: assetID, neighbours: [])
        )
        let generation = became.compactMap { (effect) -> Int? in
            if case let .request(identifier, value) = effect,
               identifier == assetID {
                return value
            }
            return nil
        }.first
        _ = machine.handle(
            .requestSucceeded(
                assetID: assetID,
                generation: generation ?? 0
            )
        )
        _ = machine.handle(.pagingSettled)
        return machine
    }

    private func audioSessionAdapterBody() -> String? {
        guard let playback = strippedSource(
            "PhotoCleanupMVE/Features/S2/S2VideoPlayback.swift"
        ) else {
            return nil
        }
        return slice(
            playback,
            from: "final class S2SystemAudioSession: S2AudioSessionControlling {",
            to: "\n}\n"
        )
    }

    private func sourceText(_ relativePath: String) -> String? {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = root.appendingPathComponent(relativePath)
        return try? String(contentsOf: url, encoding: .utf8)
    }

    /// 剔掉注释与字符串字面量内容的源码。**needle 若只可能出现在字面量里，
    /// 就不能拿它来扫这份**（IC-149 门禁二防的正是这条）。
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
                while iterator < source.endIndex, source[iterator] != newline {
                    iterator = source.index(after: iterator)
                }
                continue
            }
            output.append(character)
            iterator = next
        }
        return output
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
