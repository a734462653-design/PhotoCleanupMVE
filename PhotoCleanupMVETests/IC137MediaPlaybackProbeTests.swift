import XCTest
@testable import PhotoCleanupMVE

/// IC-137 探针分支的断言。**本分支不合并。**
///
/// 全部为夹具驱动的纯 reducer 断言：它证明状态机的口径，**不证明**真机上的拆卸时序、
/// 手势仲裁与 `AVPlayerLayer` 行为（CLAUDE.md 陷阱 1，且 XCUITest 模拟手势为明令禁止）。
/// 播放观感与手势共存一律留给 H62b 由 Lynn 真机判定。
final class IC137MediaPlaybackProbeTests: XCTestCase {

    // 断言 A：照片页路径零改动——照片不可播，任何事件都不产生效果。
    func testIC137PhotoPagesProduceNoPlaybackEffects() {
        XCTAssertFalse(S2ProbePlaybackMachine.isPlayable(.photo))
        XCTAssertTrue(S2ProbePlaybackMachine.isPlayable(.livePhoto))
        XCTAssertTrue(S2ProbePlaybackMachine.isPlayable(.video))

        var machine = S2ProbePlaybackMachine()
        XCTAssertTrue(
            machine.handle(.becameCurrent(assetID: "p", kind: .photo)).isEmpty
        )
        XCTAssertTrue(machine.handle(.pagingSettled).isEmpty)
        XCTAssertEqual(machine.state(for: "p"), .idle)
    }

    // 断言 B：进入后的首张不自动播（系统 C2）；起播只发生在翻页停稳之后。
    func testIC137FirstAssetDoesNotAutoPlayUntilSettled() {
        var machine = S2ProbePlaybackMachine()
        let onArrival = machine.handle(
            .becameCurrent(assetID: "v1", kind: .video)
        )
        XCTAssertTrue(onArrival.isEmpty, "刚成为当前页不得直接起请求")
        XCTAssertEqual(machine.state(for: "v1"), .idle)

        let onSettle = machine.handle(.pagingSettled)
        XCTAssertEqual(onSettle, [.startRequest(assetID: "v1", kind: .video)])
        XCTAssertEqual(machine.state(for: "v1"), .requesting)
    }

    // 断言 C：翻走即复位——请求中取消、播放中停止，三种「翻走」各验一次。
    func testIC137PageAwayResetsStateForAllThreeAwayMoments() {
        // C-1 请求中翻走：状态转 cancelled，且发出取消效果。
        var requesting = S2ProbePlaybackMachine()
        _ = requesting.handle(.becameCurrent(assetID: "a", kind: .livePhoto))
        _ = requesting.handle(.pagingSettled)
        XCTAssertEqual(requesting.state(for: "a"), .requesting)
        let resigned = requesting.handle(.resignedCurrent(assetID: "a"))
        XCTAssertEqual(resigned, [.cancelRequest(assetID: "a")])
        XCTAssertEqual(requesting.state(for: "a"), .cancelled)

        // C-2 播放中翻走：状态转 stopped，且发出停止效果。
        var playing = S2ProbePlaybackMachine()
        _ = playing.handle(.becameCurrent(assetID: "b", kind: .video))
        _ = playing.handle(.pagingSettled)
        _ = playing.handle(.requestSucceeded(assetID: "b"))
        _ = playing.handle(.playbackStarted(assetID: "b"))
        XCTAssertEqual(playing.state(for: "b"), .playing)
        let away = playing.handle(.resignedCurrent(assetID: "b"))
        XCTAssertEqual(away, [.stop(assetID: "b")])
        XCTAssertEqual(playing.state(for: "b"), .stopped)

        // C-3 页控制器销毁：取消 + 拆卸，且状态表里不再留残项。
        var destroyed = S2ProbePlaybackMachine()
        _ = destroyed.handle(.becameCurrent(assetID: "c", kind: .video))
        _ = destroyed.handle(.pagingSettled)
        let teardown = destroyed.handle(.destroyed(assetID: "c"))
        XCTAssertEqual(
            teardown,
            [.cancelRequest(assetID: "c"), .teardown(assetID: "c")]
        )
        XCTAssertEqual(destroyed.state(for: "c"), .idle, "销毁后不得留残留状态")
    }

    // 断言 D：连续快速翻页不串页、不堆请求——10 次跨页只在停稳后起 1 次请求，
    // 且上一页在离开时就被取消。
    func testIC137FlingIssuesAtMostOneRequestAndCancelsPredecessors() {
        var machine = S2ProbePlaybackMachine()
        _ = machine.handle(.pagingBegan)

        var startRequests = 0
        var cancels = 0
        for index in 0..<10 {
            let id = "v" + String(index)
            for effect in machine.handle(
                .becameCurrent(assetID: id, kind: .video)
            ) {
                switch effect {
                case .startRequest:
                    startRequests += 1
                case .cancelRequest:
                    cancels += 1
                default:
                    break
                }
            }
        }
        XCTAssertEqual(startRequests, 0, "拖动期间一次都不许起播")

        let settled = machine.handle(.pagingSettled)
        XCTAssertEqual(settled, [.startRequest(assetID: "v9", kind: .video)])

        // 中途经过的 9 页都没起过请求，故无可取消；状态一律为 idle，不残留。
        XCTAssertEqual(cancels, 0)
        for index in 0..<9 {
            let id = "v" + String(index)
            XCTAssertEqual(machine.state(for: id), .idle, id)
        }
    }

    // 断言 E：取消之后迟到的成功回调不得把播放拉起来（串页声音的典型来源）。
    func testIC137LateCallbackAfterCancelDoesNotStartPlayback() {
        var machine = S2ProbePlaybackMachine()
        _ = machine.handle(.becameCurrent(assetID: "a", kind: .livePhoto))
        _ = machine.handle(.pagingSettled)
        _ = machine.handle(.resignedCurrent(assetID: "a"))
        XCTAssertEqual(machine.state(for: "a"), .cancelled)

        let late = machine.handle(.requestSucceeded(assetID: "a"))
        XCTAssertTrue(late.isEmpty, "已取消的请求回来后不得起播")
        XCTAssertEqual(machine.state(for: "a"), .cancelled)
    }

    // 断言 F：切页时先把上一页收干净，再接管新页——A 页的播放不得活到 B 页。
    func testIC137SwitchingCurrentAssetRetiresThePreviousOne() {
        var machine = S2ProbePlaybackMachine()
        _ = machine.handle(.becameCurrent(assetID: "a", kind: .video))
        _ = machine.handle(.pagingSettled)
        _ = machine.handle(.requestSucceeded(assetID: "a"))
        _ = machine.handle(.playbackStarted(assetID: "a"))

        let switching = machine.handle(
            .becameCurrent(assetID: "b", kind: .video)
        )
        XCTAssertEqual(switching, [.stop(assetID: "a")])
        XCTAssertEqual(machine.state(for: "a"), .stopped)
        XCTAssertEqual(machine.state(for: "b"), .idle)
    }
}
