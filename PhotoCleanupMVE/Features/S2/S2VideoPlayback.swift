import AVFoundation
import Photos
import SwiftUI
import UIKit

// MARK: - IC-141 A：视频播放状态机（纯值语义，无 UIKit / AVFoundation 依赖）
//
// v19 回写决策 56（视频播放与浮框）、58（自动播放恒开、声音恒关、无开关）。
// 结构照 IC-140 的实况侧：按 assetID 记键（页控制器的 index 是 let，assetID 会
// 在存活的控制器上被改写，按页索引记状态会让播放串到别的资产上）、请求代次守卫、
// 效果只经协调器执行。
//
// 状态机只认视频资产——照片页与实况页在 `S2View` 侧就不进事件（当前页非视频时
// `assetID` 传 nil），因此这里没有一处媒体类别判别，不会成为第二份分类实现。

/// 单段视频的播放态。
enum S2VideoPlaybackState: Equatable {
    /// 未持有播放器，也没有在飞的请求。
    case idle
    /// 取 `AVPlayerItem` 的请求在飞。
    case requesting
    /// 播放器到手，未起播。
    case ready
    case playing
    case paused
    /// 请求失败。
    case failed
}

enum S2VideoPlaybackEvent: Equatable {
    /// 进入 S2。`assetID` = 入口页的视频资产（nil ⟹ 入口页不是视频）。
    /// 入口那张不自动播，直到发生过至少一次页变更（规格第 3 条）。
    case entered(assetID: String?)
    /// 当前页变更。`assetID` = 新当前页的视频资产（nil ⟹ 当前页不是视频）；
    /// `neighbours` = 半径内其余视频资产，**按距当前页的距离升序**。
    case becameCurrent(assetID: String?, neighbours: [String])
    /// 翻页停稳。这是自动播放唯一的起播时机（拖动进行中不播）。
    case pagingSettled
    case requestSucceeded(assetID: String, generation: Int)
    case requestFailed(assetID: String, generation: Int)
    /// 浮框左键。作用于当前页，无载荷。
    case userToggledPlayPause
    /// 浮框右键。只对当前播放生效，翻页后恢复静音（规格第 8 条）。
    case userToggledMute
    case scrubBegan
    case scrubMoved(fraction: Double)
    case scrubEnded
    /// IC-143 B：拖动**异常终止**——手势被系统取消、应用失活、当前页被换掉、
    /// 浮框视图被移除。收口与 `scrubEnded` 等价（回拖动前的播放状态），
    /// 非拖动态收到它无效果（幂等，可以随便多调）。
    case scrubCancelled
    /// 播到尾（`AVPlayerItemDidPlayToEndTime`）。循环的唯一驱动点。
    case reachedEnd(assetID: String)
}

enum S2VideoPlaybackEffect: Equatable {
    case request(assetID: String, generation: Int)
    case cancelRequest(assetID: String, generation: Int)
    case play(assetID: String)
    case pause(assetID: String)
    /// `fraction` ∈ [0, 1]，相对总时长。
    case seek(assetID: String, fraction: Double)
    case setMuted(assetID: String, muted: Bool)
    case unload(assetID: String)
}

struct S2VideoPlaybackMachine {
    private(set) var states: [String: S2VideoPlaybackState] = [:]
    /// 每页每次请求的代次。迟到回调（代次不符或页已退）一律丢弃（规格第 2 条）。
    private(set) var generations: [String: Int] = [:]
    /// 当前页的视频资产。非视频页为 nil。
    private(set) var currentAssetID: String?
    private(set) var entryAssetID: String?
    private(set) var isSettled = false
    private(set) var didChangePageSinceEntry = false
    /// 本次到达是否已自动起播过。同页反复停稳不重播；翻走再翻回重播。
    private(set) var didAutoPlayOnThisArrival = false
    private(set) var isScrubbing = false
    /// 用户在当前页点过「有声」。翻页即清（规格第 8 条：无开关、无记忆）。
    private(set) var isUnmutedByUser = false
    private var wasPlayingBeforeScrub = false
    private var nextGeneration = 1

    func state(for assetID: String) -> S2VideoPlaybackState {
        states[assetID] ?? .idle
    }

    /// 已请求或已持有播放器的资产集合。持有上限 `videoInstanceCap` 钉的就是它。
    var heldAssetIDs: Set<String> {
        Set(states.filter { Self.counts(asHeld: $0.value) }.keys)
    }

    /// 在播的资产集合。任何时刻至多一页（规格第 7 条）。
    var playingAssetIDs: Set<String> {
        Set(states.filter { $0.value == .playing }.keys)
    }

    /// 当前页与半径内邻居的保留集合，按距离升序并截到持有上限。
    static func retentionSet(
        current: String?,
        neighbours: [String]
    ) -> [String] {
        var ordered: [String] = []
        if let current {
            ordered.append(current)
        }
        for neighbour in neighbours where !ordered.contains(neighbour) {
            ordered.append(neighbour)
        }
        return Array(ordered.prefix(S2MediaMetrics.videoInstanceCap))
    }

    mutating func handle(
        _ event: S2VideoPlaybackEvent
    ) -> [S2VideoPlaybackEffect] {
        switch event {
        case let .entered(assetID):
            entryAssetID = assetID
            currentAssetID = assetID
            didChangePageSinceEntry = false
            didAutoPlayOnThisArrival = false
            isSettled = false
            isScrubbing = false
            isUnmutedByUser = false
            return []

        case let .becameCurrent(assetID, neighbours):
            return handleBecameCurrent(
                assetID: assetID,
                neighbours: neighbours
            )

        case .pagingSettled:
            isSettled = true
            guard let assetID = currentAssetID, canAutoPlay(assetID) else {
                return []
            }
            return startPlayback(assetID)

        case let .requestSucceeded(assetID, generation):
            guard isFreshCallback(generation: generation, of: assetID) else {
                return []
            }
            states[assetID] = .ready
            guard assetID == currentAssetID, canAutoPlay(assetID) else {
                return []
            }
            return startPlayback(assetID)

        case let .requestFailed(assetID, generation):
            guard isFreshCallback(generation: generation, of: assetID) else {
                return []
            }
            states[assetID] = .failed
            generations[assetID] = nil
            return []

        case .userToggledPlayPause:
            guard let assetID = currentAssetID else {
                return []
            }
            switch state(for: assetID) {
            case .playing:
                states[assetID] = .paused
                return [.pause(assetID: assetID)]
            case .ready, .paused:
                states[assetID] = .playing
                return [.play(assetID: assetID)]
            case .idle, .requesting, .failed:
                return []
            }

        case .userToggledMute:
            guard let assetID = currentAssetID else {
                return []
            }
            isUnmutedByUser.toggle()
            return [.setMuted(assetID: assetID, muted: !isUnmutedByUser)]

        case .scrubBegan:
            isScrubbing = true
            guard let assetID = currentAssetID else {
                wasPlayingBeforeScrub = false
                return []
            }
            wasPlayingBeforeScrub = state(for: assetID) == .playing
            guard wasPlayingBeforeScrub else {
                return []
            }
            states[assetID] = .paused
            return [.pause(assetID: assetID)]

        case let .scrubMoved(fraction):
            guard isScrubbing, let assetID = currentAssetID else {
                return []
            }
            return [
                .seek(assetID: assetID, fraction: Self.clamped(fraction))
            ]

        case .scrubEnded, .scrubCancelled:
            // 两者收口完全一致：正常松手与异常终止都回到拖动前的播放状态。
            // 差别只在调用方——异常终止那条还要把 `V` 无条件收回（S2View 侧）。
            guard isScrubbing else {
                return []
            }
            isScrubbing = false
            guard wasPlayingBeforeScrub, let assetID = currentAssetID else {
                return []
            }
            wasPlayingBeforeScrub = false
            states[assetID] = .playing
            return [.play(assetID: assetID)]

        case let .reachedEnd(assetID):
            // 循环：只有在播的那一段回 0 续播；暂停态收到尾事件不动
            // （用户暂停在末帧、或翻走后的迟到通知）。
            guard state(for: assetID) == .playing else {
                return []
            }
            return [
                .seek(assetID: assetID, fraction: 0),
                .play(assetID: assetID)
            ]
        }
    }

    // MARK: - 私有

    private static func counts(asHeld state: S2VideoPlaybackState) -> Bool {
        switch state {
        case .requesting, .ready, .playing, .paused:
            return true
        case .idle, .failed:
            return false
        }
    }

    private static func clamped(_ fraction: Double) -> Double {
        min(max(fraction, 0), 1)
    }

    /// 回调是否仍然有效：代次相符且该页确实还在等这次请求。
    private func isFreshCallback(generation: Int, of assetID: String) -> Bool {
        generations[assetID] == generation &&
            state(for: assetID) == .requesting
    }

    private func canAutoPlay(_ assetID: String) -> Bool {
        guard didChangePageSinceEntry,
              isSettled,
              !isScrubbing,
              !didAutoPlayOnThisArrival else {
            return false
        }
        switch state(for: assetID) {
        case .ready, .paused:
            return true
        case .idle, .requesting, .playing, .failed:
            return false
        }
    }

    /// 自动起播：静音、回 0、播。三步同批发出，`setMuted` 恒在 `play` 之前
    /// ——决策 58 的「声音恒关」不允许出现「先出声再静音」的窗口。
    private mutating func startPlayback(
        _ assetID: String
    ) -> [S2VideoPlaybackEffect] {
        states[assetID] = .playing
        didAutoPlayOnThisArrival = true
        isUnmutedByUser = false
        return [
            .setMuted(assetID: assetID, muted: true),
            .seek(assetID: assetID, fraction: 0),
            .play(assetID: assetID)
        ]
    }

    private mutating func handleBecameCurrent(
        assetID: String?,
        neighbours: [String]
    ) -> [S2VideoPlaybackEffect] {
        var effects: [S2VideoPlaybackEffect] = []
        let previous = currentAssetID
        if previous != assetID {
            didChangePageSinceEntry = true
            didAutoPlayOnThisArrival = false
            isScrubbing = false
            wasPlayingBeforeScrub = false
            isUnmutedByUser = false
        }
        currentAssetID = assetID
        isSettled = false

        let retained = Self.retentionSet(
            current: assetID,
            neighbours: neighbours
        )
        // 退离半径外：在飞的取消，已持有的卸载（顺序无关，排序只为可复现）。
        for held in heldAssetIDs.sorted() where !retained.contains(held) {
            effects.append(contentsOf: retire(held))
        }
        // 前页仍在半径内 ⟹ 暂停、回 0、静音，播放器留着（规格第 7 条）。
        if let previous,
           previous != assetID,
           retained.contains(previous) {
            effects.append(contentsOf: park(previous))
        }
        for target in retained where needsRequest(target) {
            effects.append(startRequest(target))
        }
        return effects
    }

    /// 翻走时把一页收回起点：暂停、seek 0、静音。声音随翻走关闭是默认口径
    /// （未定项 27b 若改判为「随位移衰减」另发补丁卡）。
    private mutating func park(
        _ assetID: String
    ) -> [S2VideoPlaybackEffect] {
        switch state(for: assetID) {
        case .playing, .paused:
            states[assetID] = .paused
            return [
                .pause(assetID: assetID),
                .seek(assetID: assetID, fraction: 0),
                .setMuted(assetID: assetID, muted: true)
            ]
        case .idle, .requesting, .ready, .failed:
            return []
        }
    }

    private func needsRequest(_ assetID: String) -> Bool {
        switch state(for: assetID) {
        case .idle, .failed:
            return true
        case .requesting, .ready, .playing, .paused:
            return false
        }
    }

    private mutating func startRequest(
        _ assetID: String
    ) -> S2VideoPlaybackEffect {
        let generation = nextGeneration
        nextGeneration += 1
        generations[assetID] = generation
        states[assetID] = .requesting
        return .request(assetID: assetID, generation: generation)
    }

    private mutating func retire(
        _ assetID: String
    ) -> [S2VideoPlaybackEffect] {
        var effects: [S2VideoPlaybackEffect] = []
        switch state(for: assetID) {
        case .requesting:
            if let generation = generations[assetID] {
                effects.append(
                    .cancelRequest(assetID: assetID, generation: generation)
                )
            }
        case .playing:
            effects.append(.pause(assetID: assetID))
            effects.append(.unload(assetID: assetID))
        case .ready, .paused:
            effects.append(.unload(assetID: assetID))
        case .idle, .failed:
            break
        }
        states[assetID] = nil
        generations[assetID] = nil
        return effects
    }
}

// MARK: - IC-141 A：浮框读数

/// 浮框与拖动态读数的状态快照。协调器算好后发布，视图层只读不判。
struct S2VideoPlaybackSnapshot: Equatable {
    let isPlaying: Bool
    let isMuted: Bool
    let isScrubbing: Bool
    let currentSeconds: Double
    let durationSeconds: Double

    static let idle = S2VideoPlaybackSnapshot(
        isPlaying: false,
        isMuted: true,
        isScrubbing: false,
        currentSeconds: 0,
        durationSeconds: 0
    )

    var progress: Double {
        guard durationSeconds > 0 else {
            return 0
        }
        return min(max(currentSeconds / durationSeconds, 0), 1)
    }
}

/// 逐 tick 变化的读数**单独成一个 ObservableObject**。
///
/// 协调器本身不发布任何变更（同 IC-140），否则 0.1 s 一次的进度 tick 会
/// 让整个 `S2View.body` 重算，连带 `updateUIViewController` 逐 tick 重进
/// 分页器（陷阱 5：静止态不得有几何写入）。只有浮框那两个视图观察它。
final class S2VideoPlaybackReadout: ObservableObject {
    @Published private(set) var snapshot = S2VideoPlaybackSnapshot.idle

    func update(_ snapshot: S2VideoPlaybackSnapshot) {
        guard self.snapshot != snapshot else {
            return
        }
        self.snapshot = snapshot
    }
}

// MARK: - 播放层接口

/// 协调器与播放层之间的唯一接口。
///
/// `AVPlayer` 由协调器持有并驱动（陷阱 19：播放动作只在效果执行处），
/// 宿主视图只负责把它接到 `AVPlayerLayer` 上。
protocol S2VideoPlaybackSurface: AnyObject {
    func attach(player: AVPlayer)
    func detachPlayer()
}

// MARK: - 协调器

/// 效果执行与 `PHImageManager`／`AVPlayer` 接线。**不做任何判定**
/// ——所有判定在状态机里。
///
/// 主线程限定：全部入口由 SwiftUI 与 UIKit 回调驱动，后台只有一次
/// `PHAsset.fetchAssets`，回调立刻跳回主线程（照 IC-137 探针）。
final class S2VideoPlaybackCoordinator: ObservableObject {
    /// 浮框读数。逐 tick 变化的量只在这里发布，协调器自身不发布。
    let readout = S2VideoPlaybackReadout()

    private var machine = S2VideoPlaybackMachine()
    private var surfaces: [String: SurfaceBox] = [:]
    private var players: [String: AVPlayer] = [:]
    private var requestIDs: [String: PHImageRequestID] = [:]
    private var endObservers: [String: NSObjectProtocol] = [:]
    private var timeObserver: Any?
    private var observedAssetID: String?
    /// 断言入口（仅供 XCTest）：播放层登记／注销次数。
    private(set) var surfaceRegistrationCount = 0
    private(set) var surfaceUnregistrationCount = 0
    private let imageManager: PHImageManager
    private let fetchQueue = DispatchQueue(
        label: "com.photocleanupmve.s2.video.fetch"
    )

    private final class SurfaceBox {
        weak var surface: (any S2VideoPlaybackSurface)?

        init(_ surface: any S2VideoPlaybackSurface) {
            self.surface = surface
        }
    }

    init(imageManager: PHImageManager = .default()) {
        self.imageManager = imageManager
    }

    deinit {
        if let timeObserver, let assetID = observedAssetID {
            players[assetID]?.removeTimeObserver(timeObserver)
        }
        for observer in endObservers.values {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: 事件入口（S2View 只经这些方法）

    func enter(assetID: String?) {
        send(.entered(assetID: assetID))
    }

    func pageBecameCurrent(assetID: String?, neighbours: [String]) {
        send(.becameCurrent(assetID: assetID, neighbours: neighbours))
    }

    func pagingSettled() {
        send(.pagingSettled)
    }

    func togglePlayPause() {
        send(.userToggledPlayPause)
    }

    func toggleMute() {
        send(.userToggledMute)
    }

    func scrubBegan() {
        send(.scrubBegan)
    }

    func scrubMoved(fraction: Double) {
        send(.scrubMoved(fraction: fraction))
    }

    func scrubEnded() {
        send(.scrubEnded)
    }

    /// IC-143 B：拖动异常终止。幂等——非拖动态调用不产生任何效果。
    func scrubCancelled() {
        send(.scrubCancelled)
    }

    /// 离开 S2：当前页与邻居都清空，等同于翻到一个没有视频的页。
    func leave() {
        send(.becameCurrent(assetID: nil, neighbours: []))
    }

    // MARK: 播放层登记

    func register(surface: any S2VideoPlaybackSurface, for assetID: String) {
        surfaces[assetID] = SurfaceBox(surface)
        surfaceRegistrationCount += 1
        // 播放器可能早于播放层到位（预取），登记时补挂一次。
        if let player = players[assetID] {
            surface.attach(player: player)
        }
    }

    func unregister(assetID: String) {
        guard surfaces.removeValue(forKey: assetID) != nil else {
            return
        }
        surfaceUnregistrationCount += 1
    }

    // MARK: 断言入口（仅供 XCTest）

    func playbackState(for assetID: String) -> S2VideoPlaybackState {
        machine.state(for: assetID)
    }

    /// 断言 9：缩放与双击过渡期间播放层不得被重建——比对对象身份。
    func registeredSurface(
        for assetID: String
    ) -> (any S2VideoPlaybackSurface)? {
        surfaces[assetID]?.surface
    }

    // MARK: 效果执行

    /// 事件的唯一入口：先归约，再执行，最后刷新读数。
    private func send(_ event: S2VideoPlaybackEvent) {
        let effects = machine.handle(event)
        apply(effects)
        refreshReadout()
    }

    private func apply(_ effects: [S2VideoPlaybackEffect]) {
        for effect in effects {
            switch effect {
            case let .request(assetID, generation):
                startRequest(assetID: assetID, generation: generation)
            case let .cancelRequest(assetID, _):
                cancelRequest(assetID: assetID)
            case let .play(assetID):
                guard let player = players[assetID] else {
                    break
                }
                observeTime(of: assetID)
                player.play()
            case let .pause(assetID):
                guard let player = players[assetID] else {
                    break
                }
                player.pause()
            case let .seek(assetID, fraction):
                seek(assetID: assetID, fraction: fraction)
            case let .setMuted(assetID, muted):
                players[assetID]?.isMuted = muted
            case let .unload(assetID):
                unload(assetID: assetID)
            }
        }
    }

    private func seek(assetID: String, fraction: Double) {
        guard let player = players[assetID],
              let seconds = durationSeconds(of: player) else {
            return
        }
        let target = CMTime(
            seconds: seconds * min(max(fraction, 0), 1),
            preferredTimescale: 600
        )
        player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    private func durationSeconds(of player: AVPlayer) -> Double? {
        guard let item = player.currentItem else {
            return nil
        }
        let seconds = item.duration.seconds
        guard seconds.isFinite, seconds > 0 else {
            return nil
        }
        return seconds
    }

    private func startRequest(assetID: String, generation: Int) {
        fetchQueue.async { [weak self] in
            let fetched = PHAsset.fetchAssets(
                withLocalIdentifiers: [assetID],
                options: nil
            ).firstObject
            DispatchQueue.main.async {
                guard let self else {
                    return
                }
                guard let asset = fetched else {
                    self.send(
                        .requestFailed(
                            assetID: assetID,
                            generation: generation
                        )
                    )
                    return
                }
                self.requestPlayerItem(
                    asset: asset,
                    assetID: assetID,
                    generation: generation
                )
            }
        }
    }

    private func requestPlayerItem(
        asset: PHAsset,
        assetID: String,
        generation: Int
    ) {
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.version = .current
        // `PHVideoRequestOptionsDeliveryMode` 没有 `opportunistic` 这一档，
        // 取 `automatic`（IC-137 报告已注明两类枚举不同名）。
        options.deliveryMode = .automatic
        let id = imageManager.requestPlayerItem(
            forVideo: asset,
            options: options
        ) { [weak self] item, info in
            DispatchQueue.main.async {
                self?.finishRequest(
                    assetID: assetID,
                    generation: generation,
                    item: item,
                    info: info
                )
            }
        }
        requestIDs[assetID] = id
    }

    private func finishRequest(
        assetID: String,
        generation: Int,
        item: AVPlayerItem?,
        info: [AnyHashable: Any]?
    ) {
        let cancelled = (info?[PHImageCancelledKey] as? Bool) ?? false
        guard !cancelled else {
            return
        }
        requestIDs.removeValue(forKey: assetID)
        guard let item else {
            send(.requestFailed(assetID: assetID, generation: generation))
            return
        }
        let player = AVPlayer(playerItem: item)
        // 决策 58：声音恒关，起手就静音；`.pause` 让播到尾停在末帧，
        // 由 `reachedEnd` 事件统一回 0 续播（循环只有这一条路径）。
        player.isMuted = true
        player.actionAtItemEnd = .pause
        players[assetID] = player
        surfaces[assetID]?.surface?.attach(player: player)
        endObservers[assetID] = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            self?.send(.reachedEnd(assetID: assetID))
        }
        send(.requestSucceeded(assetID: assetID, generation: generation))
    }

    private func cancelRequest(assetID: String) {
        if let id = requestIDs.removeValue(forKey: assetID) {
            imageManager.cancelImageRequest(id)
        }
    }

    /// 卸载。这里**不调 `pause()`**——状态机在 `unload` 之前已经发过 `pause`
    /// 效果，播放动作因此只有效果执行处那一个写入点（陷阱 19、断言 5）。
    private func unload(assetID: String) {
        cancelRequest(assetID: assetID)
        if let observer = endObservers.removeValue(forKey: assetID) {
            NotificationCenter.default.removeObserver(observer)
        }
        if observedAssetID == assetID {
            removeTimeObserver()
        }
        surfaces[assetID]?.surface?.detachPlayer()
        players.removeValue(forKey: assetID)?.replaceCurrentItem(with: nil)
    }

    // MARK: 读数

    /// 进度 tick 只挂在**当前在播的那一个**播放器上，翻页即改挂。
    private func observeTime(of assetID: String) {
        guard observedAssetID != assetID else {
            return
        }
        removeTimeObserver()
        guard let player = players[assetID] else {
            return
        }
        observedAssetID = assetID
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(
                seconds: S2MediaMetrics.videoProgressTickSeconds,
                preferredTimescale: 600
            ),
            queue: .main
        ) { [weak self] _ in
            self?.refreshReadout()
        }
    }

    private func removeTimeObserver() {
        if let timeObserver,
           let assetID = observedAssetID,
           let player = players[assetID] {
            player.removeTimeObserver(timeObserver)
        }
        timeObserver = nil
        observedAssetID = nil
    }

    private func refreshReadout() {
        guard let assetID = machine.currentAssetID,
              let player = players[assetID] else {
            // 拖动态要照发：拖动是界面状态，与播放器在不在手无关。
            // 少了这一条，尚未取到播放器时起拖会让拖动态浮框整层消失
            // ——手势随之被掐断，`V` 就卡在隐藏态回不来了。
            readout.update(
                S2VideoPlaybackSnapshot(
                    isPlaying: false,
                    isMuted: true,
                    isScrubbing: machine.isScrubbing,
                    currentSeconds: 0,
                    durationSeconds: 0
                )
            )
            return
        }
        let duration = durationSeconds(of: player) ?? 0
        let current = player.currentTime().seconds
        readout.update(
            S2VideoPlaybackSnapshot(
                isPlaying: machine.state(for: assetID) == .playing,
                isMuted: player.isMuted,
                isScrubbing: machine.isScrubbing,
                currentSeconds: current.isFinite ? max(0, current) : 0,
                durationSeconds: duration
            )
        )
    }
}

// MARK: - IC-141 B：快照排除

/// 快照捕获期间需要临时让位的视图。
///
/// 决策 56：视频页的双击过渡快照与标记残影快照取**封面帧**——
/// `AVPlayerLayer` 的内容不进 `snapshotView`，留在快照里的会是一块黑；
/// 捕获瞬间把播放层隐掉，露出底下那张静止图。实况页与照片页没有遵循者，
/// 两个快照函数的行为与基线逐字相同。
protocol S2SnapshotExcludedView: UIView {}

enum S2SnapshotExclusion {
    /// 捕获期间隐藏子树里的遵循者，捕获后逐个恢复**原值**。
    ///
    /// 恢复的是原值而不是一律置 `false`——调用前本来就隐着的层必须仍然隐着，
    /// 否则快照会把一个不该上屏的层放出来。
    static func capturing<T>(in root: UIView, _ capture: () -> T) -> T {
        let excluded = excludedViews(in: root)
        let wasHidden = excluded.map(\.isHidden)
        for view in excluded where !view.isHidden {
            view.isHidden = true
        }
        defer {
            for (view, original) in zip(excluded, wasHidden)
            where view.isHidden != original {
                view.isHidden = original
            }
        }
        return capture()
    }

    private static func excludedViews(in root: UIView) -> [UIView] {
        var found: [UIView] = []
        if root is any S2SnapshotExcludedView {
            found.append(root)
        }
        for subview in root.subviews {
            found.append(contentsOf: excludedViews(in: subview))
        }
        return found
    }
}

// MARK: - IC-143 C：双击过渡期间把活的播放层借出去

/// 过渡期间可以把播放层交给过渡视图承载的播放层。
///
/// 决策 56 让双击过渡的快照取封面帧（`S2SnapshotExcludedView`），而过渡期间
/// 页内容整棵树是隐藏的——于是视频页在那 0.3 s 里看到的是一张不动的封面帧，
/// 收口时播放层带着已前进的进度重新出现，观感即 H65 第 6 项的「卡顿暂停一会
/// 再播放」。把活的图层借给过渡视图，封面帧快照留在其下作兜底，画面就连续了。
protocol S2TransitionLendableView: UIView {
    /// 交出播放层（调用方负责摆放）。已借出或无可借时返回 nil。
    func lendPlaybackLayer() -> CALayer?
    /// 收回播放层：挂回自身，几何仍由 `layoutSubviews` 那唯一一处写。
    func reclaimPlaybackLayer()
}

enum S2PlaybackLayerLending {
    /// 子树里所有可借出的播放层宿主。照片页与实况页没有遵循者，返回空。
    static func lendableViews(
        in root: UIView
    ) -> [any S2TransitionLendableView] {
        var found: [any S2TransitionLendableView] = []
        if let lendable = root as? any S2TransitionLendableView {
            found.append(lendable)
        }
        for subview in root.subviews {
            found.append(contentsOf: lendableViews(in: subview))
        }
        return found
    }
}

// MARK: - IC-141 B：宿主视图

/// 承载 `AVPlayerLayer` 的页内播放层。
///
/// 几何纪律（同 IC-140）：**不设约束、不设自动尺寸掩码、不写自己的几何**。
/// 子层尺寸只在 `layoutSubviews` 里从 `bounds` 读——`bounds` 是几何链
/// （`writePhotoGeometry`）写进来的，1x 与 Nx 两套尺寸都由那条链给。
/// 子层的隐式动画一律关掉，否则链上每次写入都会带一段动画，与外层的
/// 无动画提交错拍。
///
/// 本视图**不驱动播放**（陷阱 19）：`AVPlayer` 由协调器持有并驱动，
/// 这里只把它接到图层上。
final class S2VideoHostView: UIView,
    S2VideoPlaybackSurface,
    S2SnapshotExcludedView,
    S2TransitionLendableView {
    private let playerLayer = AVPlayerLayer()
    private(set) var assetID: String
    /// 断言入口（仅供 XCTest）：页控制器复用到别的资产时的改绑次数。
    private(set) var rebindCount = 0
    /// IC-143 C：播放层是否正借给双击过渡视图。
    private(set) var isLendingPlaybackLayer = false

    init(assetID: String) {
        self.assetID = assetID
        super.init(frame: .zero)
        backgroundColor = .clear
        // 浮框是唯一的播放控件（决策 56），播放层不接触控。
        isUserInteractionEnabled = false
        playerLayer.videoGravity = .resizeAspect
        playerLayer.actions = [
            "bounds": NSNull(),
            "position": NSNull(),
            "frame": NSNull()
        ]
        layer.addSublayer(playerLayer)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    /// 页控制器被复用到另一段视频时改绑。旧资产的播放器不在这里卸——
    /// 卸载是协调器按半径决定的效果，本视图只换身份。
    func rebind(assetID: String) {
        self.assetID = assetID
        rebindCount += 1
        detachPlayer()
    }

    // MARK: S2VideoPlaybackSurface

    func attach(player: AVPlayer) {
        playerLayer.player = player
    }

    func detachPlayer() {
        playerLayer.player = nil
    }

    // MARK: S2TransitionLendableView

    func lendPlaybackLayer() -> CALayer? {
        guard !isLendingPlaybackLayer else {
            return nil
        }
        isLendingPlaybackLayer = true
        return playerLayer
    }

    func reclaimPlaybackLayer() {
        guard isLendingPlaybackLayer else {
            return
        }
        isLendingPlaybackLayer = false
        layer.addSublayer(playerLayer)
        // 几何**不在这里写**：挂回来后强制走一次 `layoutSubviews`，
        // 播放层的帧因此仍只有那一个写入点（IC-141 断言 5）。
        setNeedsLayout()
        layoutIfNeeded()
    }

    // MARK: 断言入口（仅供 XCTest）

    var diagnosticPlaybackLayerSuperlayer: CALayer? {
        playerLayer.superlayer
    }

    var diagnosticPlaybackLayerFrame: CGRect {
        playerLayer.frame
    }

    var diagnosticPlaybackLayerIndex: Int? {
        layer.sublayers?.firstIndex(of: playerLayer)
    }

    // MARK: 布局

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        playerLayer.frame = bounds
        CATransaction.commit()
    }
}

// MARK: - IC-141 B：页内容里的播放层

/// 页内容树里的视频播放层包装。挂在既有页内容的 `.overlay` 上，因此自动坐在
/// 缩放容器内、随 1x／Nx 变换——一行几何都不用自己写（IC-137 报告第二节）。
struct S2VideoPlaybackContentView: UIViewRepresentable {
    let playback: S2VideoPlaybackCoordinator
    let assetID: String

    /// 只为把 assetID 带进 `dismantleUIView`——它是 static，
    /// `Coordinator == Void` 时拿不到任何页身份，拆卸就无处收口。
    final class Coordinator {
        let playback: S2VideoPlaybackCoordinator
        var assetID: String

        init(playback: S2VideoPlaybackCoordinator, assetID: String) {
            self.playback = playback
            self.assetID = assetID
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(playback: playback, assetID: assetID)
    }

    func makeUIView(context: Context) -> S2VideoHostView {
        let view = S2VideoHostView(assetID: assetID)
        context.coordinator.assetID = assetID
        playback.register(surface: view, for: assetID)
        return view
    }

    func updateUIView(_ view: S2VideoHostView, context: Context) {
        guard view.assetID != assetID else {
            return
        }
        playback.unregister(assetID: view.assetID)
        view.rebind(assetID: assetID)
        context.coordinator.assetID = assetID
        playback.register(surface: view, for: assetID)
    }

    static func dismantleUIView(
        _ view: S2VideoHostView,
        coordinator: Coordinator
    ) {
        coordinator.playback.unregister(assetID: view.assetID)
    }
}

// MARK: - IC-141 B：挂载口径

/// 页内视频播放层的挂载口径。`nil` = 该页不构造播放层。
///
/// 决策 56：只有 `m=视频` 的页携带视频播放层；照片页与实况页不构造
/// （实况播放层属 IC-140，另建）。
struct S2VideoLayerPresentation: Equatable {
    /// 播放层不接触控——播放动作只经浮框三件。
    let acceptsHits: Bool

    static func make(mediaKind: S2MediaKind) -> S2VideoLayerPresentation? {
        guard mediaKind == .video else {
            return nil
        }
        return S2VideoLayerPresentation(acceptsHits: false)
    }
}

// MARK: - IC-141 C：浮框口径

/// 进度读数格式化。`m:ss`，超 1 小时 `h:mm:ss`；秒数向下取整
/// （59.4 s 读作 0:59，不四舍五入到 1:00）。
enum S2VideoTimeFormatter {
    static func text(seconds: Double) -> String {
        let bounded = seconds.isFinite && seconds > 0 ? seconds : 0
        let total = Int(bounded)
        let hours = total / 3_600
        let minutes = (total % 3_600) / 60
        let remainder = total % 60
        guard hours > 0 else {
            return String(format: "%d:%02d", minutes, remainder)
        }
        return String(format: "%d:%02d:%02d", hours, minutes, remainder)
    }
}

/// IC-139 B → IC-141 C：视频浮框口径模型。`nil` = 该页不构造常态浮框。
///
/// IC-139 时三件恒为「播放」「进度 0」「静音」且不接点击；本卡改为**状态驱动**
/// ——符号、进度与可点性全部来自播放快照（决策 56）。拖动态由
/// `S2VideoScrubPresentation` 另出一份口径，两者互斥。
struct S2VideoBarPresentation: Equatable {
    let playSymbolName: String
    let muteSymbolName: String
    let progress: Double
    let acceptsHits: Bool
    let isPlaying: Bool
    let isMuted: Bool

    static func make(
        mediaKind: S2MediaKind,
        interfaceVisibility: S2InterfaceVisibility,
        playback: S2VideoPlaybackSnapshot
    ) -> S2VideoBarPresentation? {
        guard mediaKind == .video,
              interfaceVisibility == .visible,
              !playback.isScrubbing else {
            return nil
        }
        return S2VideoBarPresentation(
            playSymbolName: playback.isPlaying
                ? S2MediaMetrics.videoBarPauseSymbol
                : S2MediaMetrics.videoBarPlaySymbol,
            muteSymbolName: playback.isMuted
                ? S2MediaMetrics.videoBarMutedSymbol
                : S2MediaMetrics.videoBarUnmutedSymbol,
            progress: playback.progress,
            acceptsHits: true,
            isPlaying: playback.isPlaying,
            isMuted: playback.isMuted
        )
    }
}

/// IC-141 C：拖动态浮框口径。`nil` = 当前不在拖动。
///
/// 决策 56：拖动期间只剩两端读数与圆点，无播放键、无静音键；
/// 且**不随 `V` 隐藏**——它是 `V=隐藏` 期间唯一可见的 chrome，
/// 故这份口径不看 `interfaceVisibility`。
struct S2VideoScrubPresentation: Equatable {
    let currentText: String
    let durationText: String
    let progress: Double
    let fontSize: CGFloat
    /// 左端白、右端白 72%（v19 §11.2 原文）。
    let trailingOpacity: Double

    static func make(
        mediaKind: S2MediaKind,
        playback: S2VideoPlaybackSnapshot
    ) -> S2VideoScrubPresentation? {
        guard mediaKind == .video, playback.isScrubbing else {
            return nil
        }
        return S2VideoScrubPresentation(
            currentText: S2VideoTimeFormatter.text(
                seconds: playback.currentSeconds
            ),
            durationText: S2VideoTimeFormatter.text(
                seconds: playback.durationSeconds
            ),
            progress: playback.progress,
            fontSize: S2MediaMetrics.videoBarTimeFontSize,
            trailingOpacity: S2MediaMetrics.videoBarTimeTrailingOpacity
        )
    }
}
