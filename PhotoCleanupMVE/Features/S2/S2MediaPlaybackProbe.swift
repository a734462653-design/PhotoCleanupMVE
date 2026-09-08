import AVFoundation
import Photos
import PhotosUI
import SwiftUI
import UIKit

// MARK: - IC-137 探针：播放状态机（纯值语义，无 UIKit / PhotoKit 依赖）
//
// 本卡是探针卡，分支不合并。状态机做成纯 reducer 是为了让「翻走复位」「翻走取消请求」
// 两条断言在夹具层可测——真机行为仍由 H62b 兜底（CLAUDE.md 陷阱 1）。
//
// 键取 assetID 而不是页索引：页控制器的 index 是 let，assetID 却会在存活的控制器上被
// 改写（删除或重排后同一个控制器代表另一张资产），按页索引记状态会让播放串到别的照片上。

enum S2ProbePlaybackState: Equatable {
    /// 照片页，或尚未轮到本页。
    case idle
    /// 已发起取资源请求，未回。
    case requesting
    /// 资源到手，未播。
    case ready
    case playing
    /// 播完、被暂停、或翻走后复位。
    case stopped
    case failed
    /// 请求在回来之前被翻走取消。
    case cancelled
}

enum S2ProbePlaybackEvent: Equatable {
    /// 外层开始拖动或滑行。拖动期间不起播——对齐系统行为 C1。
    case pagingBegan
    /// `currentIndex` 落到某页。**不直接起播**：起播只在 `pagingSettled` 发生，
    /// 因此「进入后的首张」不会自动播（系统行为 C2）。
    case becameCurrent(assetID: String, kind: S2AssetSizeProbeMediaKind)
    /// 翻页停稳。这是唯一的起播时机。
    case pagingSettled
    case resignedCurrent(assetID: String)
    /// 页控制器被销毁。
    case destroyed(assetID: String)
    case requestSucceeded(assetID: String)
    case requestFailed(assetID: String)
    case playbackStarted(assetID: String)
    case playbackStopped(assetID: String)
    /// 实况长按（探针里改派给播放）。
    case userRequestedPlay(assetID: String)
    /// 视频页单击（探针里临时兼作播放／暂停）。
    case userToggledPlayback(assetID: String)
}

enum S2ProbePlaybackEffect: Equatable {
    case startRequest(assetID: String, kind: S2AssetSizeProbeMediaKind)
    case cancelRequest(assetID: String)
    case play(assetID: String)
    case stop(assetID: String)
    case teardown(assetID: String)
}

struct S2ProbePlaybackMachine {
    private(set) var states: [String: S2ProbePlaybackState] = [:]
    private(set) var kinds: [String: S2AssetSizeProbeMediaKind] = [:]
    private(set) var currentAssetID: String?
    private(set) var isPaging = false

    func state(for assetID: String) -> S2ProbePlaybackState {
        states[assetID] ?? .idle
    }

    /// 是否可播：只有实况与视频进播放路径，照片页一律 `.idle` 且零效果。
    static func isPlayable(_ kind: S2AssetSizeProbeMediaKind) -> Bool {
        kind != .photo
    }

    mutating func handle(
        _ event: S2ProbePlaybackEvent
    ) -> [S2ProbePlaybackEffect] {
        switch event {
        case .pagingBegan:
            isPaging = true
            return []

        case let .becameCurrent(assetID, kind):
            var effects: [S2ProbePlaybackEffect] = []
            if let previous = currentAssetID, previous != assetID {
                effects.append(contentsOf: retire(previous))
            }
            currentAssetID = assetID
            kinds[assetID] = kind
            if !Self.isPlayable(kind) {
                states[assetID] = .idle
            }
            // 拖动中不起播；停稳后由 pagingSettled 统一起播。
            return effects

        case .pagingSettled:
            isPaging = false
            guard let assetID = currentAssetID,
                  let kind = kinds[assetID],
                  Self.isPlayable(kind) else {
                return []
            }
            switch state(for: assetID) {
            case .idle, .stopped, .cancelled, .failed:
                states[assetID] = .requesting
                return [.startRequest(assetID: assetID, kind: kind)]
            case .ready:
                return [.play(assetID: assetID)]
            case .requesting, .playing:
                return []
            }

        case let .resignedCurrent(assetID):
            if currentAssetID == assetID {
                currentAssetID = nil
            }
            return retire(assetID)

        case let .destroyed(assetID):
            var effects = retire(assetID)
            if currentAssetID == assetID {
                currentAssetID = nil
            }
            states.removeValue(forKey: assetID)
            kinds.removeValue(forKey: assetID)
            effects.append(.teardown(assetID: assetID))
            return effects

        case let .requestSucceeded(assetID):
            guard state(for: assetID) == .requesting else {
                // 迟到的回调：本页已被翻走并取消，结论丢弃。
                return []
            }
            states[assetID] = .ready
            guard assetID == currentAssetID, !isPaging else {
                return []
            }
            return [.play(assetID: assetID)]

        case let .requestFailed(assetID):
            guard state(for: assetID) == .requesting else {
                return []
            }
            states[assetID] = .failed
            return []

        case let .playbackStarted(assetID):
            states[assetID] = .playing
            return []

        case let .playbackStopped(assetID):
            if states[assetID] == .playing {
                states[assetID] = .stopped
            }
            return []

        case let .userRequestedPlay(assetID):
            guard state(for: assetID) == .ready
                    || state(for: assetID) == .stopped else {
                return []
            }
            return [.play(assetID: assetID)]

        case let .userToggledPlayback(assetID):
            switch state(for: assetID) {
            case .playing:
                return [.stop(assetID: assetID)]
            case .ready, .stopped:
                return [.play(assetID: assetID)]
            case .idle, .requesting, .failed, .cancelled:
                return []
            }
        }
    }

    /// 翻走／销毁时的统一复位：请求中就取消，播放中就停。
    private mutating func retire(
        _ assetID: String
    ) -> [S2ProbePlaybackEffect] {
        switch state(for: assetID) {
        case .requesting:
            states[assetID] = .cancelled
            return [.cancelRequest(assetID: assetID)]
        case .playing:
            states[assetID] = .stopped
            return [.stop(assetID: assetID)]
        case .ready:
            states[assetID] = .stopped
            return [.stop(assetID: assetID)]
        case .idle, .stopped, .failed, .cancelled:
            return []
        }
    }
}

// MARK: - 探针叠层读数

struct S2MediaPlaybackProbeReadout: Equatable {
    var assetID = ""
    var kindLabel = "-"
    var stateLabel = "-"
    /// 本页从「成为当前页」到资源可播的毫秒数；nil = 尚未测到。
    var readyMilliseconds: Double?
    /// 取资源用的 deliveryMode 变体标签，两组轮换以便对照。
    var deliveryLabel = "-"
    var footprintMegabytes: Double?
    var peakFootprintMegabytes: Double?
    /// 主线程停顿（相邻帧间隔 > 100 ms）累计次数。
    var stallCount = 0
    var worstStallMilliseconds: Double = 0
    var pageTurnCount = 0
}

// MARK: - 探针协调器

/// 播放层与探针读数的持有者。
///
/// 只被 `S2View` 以 `@State` 持有——**不是** `@StateObject`：`@State` 不订阅
/// `objectWillChange`，因此 500 ms 的内存采样只会让叠层子树重算，不会把 `S2View` 的
/// body 卷进来。body 一旦每半秒重算就会连带 `apply()` → `layoutNativePages`，
/// 正好制造 CLAUDE.md 陷阱 5 说的「静止状态几何写入」。叠层自己用 `@ObservedObject`。
final class S2MediaPlaybackProbeCoordinator: NSObject, ObservableObject {
    /// 唯一实例。`@State` 的默认值表达式在 `S2View` 每次 init 时都会求值
    /// （`State.init(wrappedValue:)` 不是 @autoclosure，只有 `StateObject` 是），
    /// 每求一次就多一个永不停的 CADisplayLink——故只经 `shared` 构造一次。
    static let shared = S2MediaPlaybackProbeCoordinator()

    @Published private(set) var readout = S2MediaPlaybackProbeReadout()

    private var machine = S2ProbePlaybackMachine()
    private var hostViews: [String: S2ProbeMediaHostView] = [:]
    private var requestIDs: [String: PHImageRequestID] = [:]
    private var players: [String: AVPlayer] = [:]
    private var livePhotos: [String: PHLivePhoto] = [:]
    private var requestStartedAt: [String: CFTimeInterval] = [:]
    /// 读数按资产分开记：迟到的回调与翻页撞上时，不得把上一页的
    /// 读数挂到当前资产头上。
    private var readyMillisecondsByAsset: [String: Double] = [:]
    private var deliveryLabelByAsset: [String: String] = [:]
    private var resolvedKinds: [String: S2AssetSizeProbeMediaKind] = [:]
    private var pendingKindLookups: Set<String> = []

    /// 取消过的请求 id，供断言核对「翻走确实取消了」。
    private(set) var cancelledRequestIDs: [PHImageRequestID] = []

    private var displayLink: CADisplayLink?
    private var lastFrameTimestamp: CFTimeInterval = 0
    private var lastMemorySampleAt: CFTimeInterval = 0
    private var lastIndexChangeAt: CFTimeInterval = 0
    private var awaitingSettle = false
    /// 两组 deliveryMode 轮换：偶数次用 opportunistic 组，奇数次用 highQuality 组。
    private var requestCounter = 0

    private let kindQueue = DispatchQueue(
        label: "ic137.probe.mediakind",
        qos: .userInitiated
    )

    /// 翻页停稳的判定阈值。探针侧的去抖，**不是**分页器真正的
    /// `finishNativePaging`——报告里已注明这一点。
    private static let settleSeconds: CFTimeInterval = 0.25
    private static let memorySampleSeconds: CFTimeInterval = 0.5
    private static let stallSeconds: CFTimeInterval = 0.1

    override init() {
        super.init()
        start()
    }

    deinit {
        displayLink?.invalidate()
    }

    // MARK: 资产类别

    /// 已解析的类别；未解析时返回 `.photo` 并在后台补解析，避免在 body 里同步取
    /// `PHAsset`（主线程同步取图正是掉帧的来源之一）。
    func mediaKind(for assetID: String) -> S2AssetSizeProbeMediaKind {
        if let resolved = resolvedKinds[assetID] {
            return resolved
        }
        resolveKind(for: assetID)
        return .photo
    }

    private func resolveKind(for assetID: String) {
        guard !pendingKindLookups.contains(assetID) else {
            return
        }
        pendingKindLookups.insert(assetID)
        kindQueue.async { [weak self] in
            let fetched = PHAsset.fetchAssets(
                withLocalIdentifiers: [assetID],
                options: nil
            ).firstObject
            let kind = fetched.map(AssetSizeProbeService.mediaKind(of:))
                ?? .photo
            DispatchQueue.main.async {
                guard let self else {
                    return
                }
                self.pendingKindLookups.remove(assetID)
                self.resolvedKinds[assetID] = kind
                guard kind != .photo else {
                    return
                }
                // 首次到达本页时类别还没解析出来，机器里登记的是回退值
                // `.photo`。`kinds` 只由 becameCurrent 写入，不补这一次，
                // pagingSettled 读到的永远是那个陈旧值，第一趟绝不起播。
                if self.machine.currentAssetID == assetID {
                    self.apply(
                        self.machine.handle(
                            .becameCurrent(assetID: assetID, kind: kind)
                        )
                    )
                    self.lastIndexChangeAt = CACurrentMediaTime()
                    self.awaitingSettle = true
                }
                // 播放层只能从 UIKit 侧补：页内容版本没变，分页器不会重挂
                // rootView，发不发 objectWillChange 都一样。
                if let hostView = self.hostViews[assetID] {
                    hostView.configure(kind: kind)
                    if let livePhoto = self.livePhotos[assetID] {
                        hostView.attach(livePhoto: livePhoto)
                    }
                    if let player = self.players[assetID] {
                        hostView.attach(player: player)
                    }
                }
                self.refreshReadout()
            }
        }
    }

    // MARK: 页生命周期

    func pageBecameCurrent(assetID: String) {
        let kind = mediaKind(for: assetID)
        lastIndexChangeAt = CACurrentMediaTime()
        awaitingSettle = true
        if machine.currentAssetID != assetID {
            requestStartedAt[assetID] = CACurrentMediaTime()
        }
        apply(machine.handle(.becameCurrent(assetID: assetID, kind: kind)))
        readout.pageTurnCount += 1
        refreshReadout()
    }

    func pagingBegan() {
        apply(machine.handle(.pagingBegan))
    }

    /// 页内容被拆卸时的收口。带宿主视图身份校验：SwiftUI 可能先建新视图
    /// 再拆旧视图，旧视图的拆卸不得把刚登记的新视图一并删掉。
    func pageDestroyed(assetID: String, hostView: S2ProbeMediaHostView) {
        guard hostViews[assetID] === hostView else {
            return
        }
        apply(machine.handle(.destroyed(assetID: assetID)))
        hostViews.removeValue(forKey: assetID)
        refreshReadout()
    }

    /// 实况长按（探针把 0.8 s 长按改派给播放）。
    func userRequestedPlay(assetID: String) {
        apply(machine.handle(.userRequestedPlay(assetID: assetID)))
        refreshReadout()
    }

    /// 视频页单击（探针临时兼作播放／暂停；chrome 显隐照旧，冲突留待记录）。
    func userToggledPlayback(assetID: String) {
        apply(machine.handle(.userToggledPlayback(assetID: assetID)))
        refreshReadout()
    }

    // MARK: 宿主视图登记

    func register(hostView: S2ProbeMediaHostView, assetID: String) {
        hostViews[assetID] = hostView
        hostView.configure(kind: mediaKind(for: assetID))
        if let livePhoto = livePhotos[assetID] {
            hostView.attach(livePhoto: livePhoto)
        }
        if let player = players[assetID] {
            hostView.attach(player: player)
        }
    }

    func unregister(assetID: String) {
        guard hostViews[assetID] != nil else {
            return
        }
        hostViews.removeValue(forKey: assetID)
    }

    // MARK: 效果执行

    private func apply(_ effects: [S2ProbePlaybackEffect]) {
        for effect in effects {
            switch effect {
            case let .startRequest(assetID, kind):
                startRequest(assetID: assetID, kind: kind)
            case let .cancelRequest(assetID):
                cancelRequest(assetID: assetID)
            case let .play(assetID):
                play(assetID: assetID)
            case let .stop(assetID):
                stop(assetID: assetID)
            case let .teardown(assetID):
                teardown(assetID: assetID)
            }
        }
    }

    private func startRequest(
        assetID: String,
        kind: S2AssetSizeProbeMediaKind
    ) {
        requestStartedAt[assetID] = CACurrentMediaTime()
        requestCounter += 1
        let usesHighQuality = requestCounter % 2 == 0
        let label = usesHighQuality ? "highQuality" : "opportunistic"
        deliveryLabelByAsset[assetID] = label
        refreshReadout()

        kindQueue.async { [weak self] in
            let fetched = PHAsset.fetchAssets(
                withLocalIdentifiers: [assetID],
                options: nil
            ).firstObject
            DispatchQueue.main.async {
                guard let self, let asset = fetched else {
                    self?.finishRequest(assetID: assetID, succeeded: false)
                    return
                }
                switch kind {
                case .livePhoto:
                    self.requestLivePhoto(
                        asset: asset,
                        assetID: assetID,
                        usesHighQuality: usesHighQuality
                    )
                case .video:
                    self.requestPlayerItem(
                        asset: asset,
                        assetID: assetID,
                        usesHighQuality: usesHighQuality
                    )
                case .photo:
                    self.finishRequest(assetID: assetID, succeeded: false)
                }
            }
        }
    }

    private func requestLivePhoto(
        asset: PHAsset,
        assetID: String,
        usesHighQuality: Bool
    ) {
        let options = PHLivePhotoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.version = .current
        options.deliveryMode = usesHighQuality
            ? .highQualityFormat
            : .opportunistic
        let target = hostViews[assetID]?.bounds.size ?? PHImageManagerMaximumSize
        let id = PHImageManager.default().requestLivePhoto(
            for: asset,
            targetSize: target,
            contentMode: .aspectFit,
            options: options
        ) { [weak self] livePhoto, info in
            DispatchQueue.main.async {
                guard let self else {
                    return
                }
                let cancelled = (info?[PHImageCancelledKey] as? Bool) ?? false
                guard !cancelled else {
                    return
                }
                // opportunistic 先回一个降质件。降质件**非 nil**，若拿它当
                // 终值走 finishRequest，requestIDs 里的 id 会被提前释放，
                // 翻走时 cancelRequest 就找不到 id——真正在飞的那个请求反而
                // 取消不了，也进不了 cancelledRequestIDs。
                let degraded = (info?[PHImageResultIsDegradedKey] as? Bool)
                    ?? false
                guard let livePhoto else {
                    if !degraded {
                        self.finishRequest(assetID: assetID, succeeded: false)
                    }
                    return
                }
                self.livePhotos[assetID] = livePhoto
                self.hostViews[assetID]?.attach(livePhoto: livePhoto)
                guard !degraded else {
                    // 保留 requestIDs[assetID]，等终值回调来收口。
                    return
                }
                self.finishRequest(assetID: assetID, succeeded: true)
            }
        }
        requestIDs[assetID] = id
    }

    private func requestPlayerItem(
        asset: PHAsset,
        assetID: String,
        usesHighQuality: Bool
    ) {
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.version = .current
        // PHVideoRequestOptionsDeliveryMode 没有 opportunistic 这一档，
        // 对照组取 automatic——报告里已注明两类枚举不同名。
        options.deliveryMode = usesHighQuality
            ? .highQualityFormat
            : .automatic
        let id = PHImageManager.default().requestPlayerItem(
            forVideo: asset,
            options: options
        ) { [weak self] item, info in
            DispatchQueue.main.async {
                guard let self else {
                    return
                }
                let cancelled = (info?[PHImageCancelledKey] as? Bool) ?? false
                guard !cancelled else {
                    return
                }
                guard let item else {
                    self.finishRequest(assetID: assetID, succeeded: false)
                    return
                }
                let player = AVPlayer(playerItem: item)
                player.isMuted = true
                self.players[assetID] = player
                self.hostViews[assetID]?.attach(player: player)
                self.finishRequest(assetID: assetID, succeeded: true)
            }
        }
        requestIDs[assetID] = id
    }

    private func finishRequest(assetID: String, succeeded: Bool) {
        if succeeded, let startedAt = requestStartedAt[assetID] {
            let elapsed = (CACurrentMediaTime() - startedAt) * 1_000
            readyMillisecondsByAsset[assetID] = elapsed
        }
        requestIDs.removeValue(forKey: assetID)
        let event: S2ProbePlaybackEvent = succeeded
            ? .requestSucceeded(assetID: assetID)
            : .requestFailed(assetID: assetID)
        apply(machine.handle(event))
        refreshReadout()
    }

    private func cancelRequest(assetID: String) {
        guard let id = requestIDs.removeValue(forKey: assetID),
              id != PHInvalidImageRequestID else {
            return
        }
        PHImageManager.default().cancelImageRequest(id)
        cancelledRequestIDs.append(id)
    }

    private func play(assetID: String) {
        guard let host = hostViews[assetID] else {
            return
        }
        host.play()
        apply(machine.handle(.playbackStarted(assetID: assetID)))
        refreshReadout()
    }

    private func stop(assetID: String) {
        hostViews[assetID]?.stop()
        apply(machine.handle(.playbackStopped(assetID: assetID)))
        refreshReadout()
    }

    private func teardown(assetID: String) {
        cancelRequest(assetID: assetID)
        players[assetID]?.pause()
        players.removeValue(forKey: assetID)
        livePhotos.removeValue(forKey: assetID)
        requestStartedAt.removeValue(forKey: assetID)
        readyMillisecondsByAsset.removeValue(forKey: assetID)
        deliveryLabelByAsset.removeValue(forKey: assetID)
        hostViews[assetID]?.detach()
    }

    // MARK: 采样

    private func start() {
        let link = CADisplayLink(
            target: self,
            selector: #selector(handleFrame(_:))
        )
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    @objc private func handleFrame(_ link: CADisplayLink) {
        let now = link.timestamp
        if lastFrameTimestamp > 0 {
            let delta = now - lastFrameTimestamp
            if delta > Self.stallSeconds {
                readout.stallCount += 1
                let milliseconds = delta * 1_000
                if milliseconds > readout.worstStallMilliseconds {
                    readout.worstStallMilliseconds = milliseconds
                }
            }
        }
        lastFrameTimestamp = now

        if awaitingSettle,
           now - lastIndexChangeAt >= Self.settleSeconds {
            awaitingSettle = false
            apply(machine.handle(.pagingSettled))
            refreshReadout()
        }

        if now - lastMemorySampleAt >= Self.memorySampleSeconds {
            lastMemorySampleAt = now
            sampleMemory()
        }
    }

    private func sampleMemory() {
        guard let bytes = Self.footprintBytes() else {
            return
        }
        let megabytes = Double(bytes) / (1_024 * 1_024)
        readout.footprintMegabytes = megabytes
        if megabytes > (readout.peakFootprintMegabytes ?? 0) {
            readout.peakFootprintMegabytes = megabytes
        }
    }

    private static func footprintBytes() -> UInt64? {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size
        )
        let status = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(
                to: integer_t.self,
                capacity: Int(count)
            ) { rebound in
                task_info(
                    mach_task_self_,
                    task_flavor_t(TASK_VM_INFO),
                    rebound,
                    &count
                )
            }
        }
        guard status == KERN_SUCCESS else {
            return nil
        }
        return UInt64(info.phys_footprint)
    }

    private func refreshReadout() {
        let assetID = machine.currentAssetID ?? ""
        readout.assetID = String(assetID.prefix(8))
        let kind = resolvedKinds[assetID] ?? .photo
        readout.kindLabel = Self.label(for: kind)
        readout.stateLabel = Self.label(for: machine.state(for: assetID))
        readout.readyMilliseconds = readyMillisecondsByAsset[assetID]
        readout.deliveryLabel = deliveryLabelByAsset[assetID] ?? "-"
    }

    private static func label(for kind: S2AssetSizeProbeMediaKind) -> String {
        let text: String
        switch kind {
        case .photo:
            text = "photo"
        case .livePhoto:
            text = "live"
        case .video:
            text = "video"
        }
        return text
    }

    private static func label(for state: S2ProbePlaybackState) -> String {
        let text: String
        switch state {
        case .idle:
            text = "idle"
        case .requesting:
            text = "requesting"
        case .ready:
            text = "ready"
        case .playing:
            text = "playing"
        case .stopped:
            text = "stopped"
        case .failed:
            text = "failed"
        case .cancelled:
            text = "cancelled"
        }
        return text
    }

    // MARK: 断言入口（仅供 XCTest）

    func probeState(for assetID: String) -> S2ProbePlaybackState {
        machine.state(for: assetID)
    }
}

// MARK: - 宿主视图

/// 承载 `PHLivePhotoView` 或 `AVPlayerLayer` 的内容视图。
///
/// 几何纪律：**不设约束、不设 autoresizingMask、不写自己的 frame**。尺寸只在
/// `layoutSubviews` 里从 `bounds` 读——`bounds` 是几何链（`writePhotoGeometry`）写进来的，
/// 1x 与 Nx 两套尺寸都由那条链给。子层的隐式动画一律关掉，照 `fitBorderLayer` 的先例，
/// 否则每次链上写入都会带一段动画，与外层的无动画提交错拍。
final class S2ProbeMediaHostView: UIView {
    private var livePhotoView: PHLivePhotoView?
    private var playerLayer: AVPlayerLayer?
    private var kind: S2AssetSizeProbeMediaKind = .photo

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    func configure(kind: S2AssetSizeProbeMediaKind) {
        guard self.kind != kind else {
            return
        }
        self.kind = kind
        detach()
        switch kind {
        case .livePhoto:
            let view = PHLivePhotoView(frame: bounds)
            // 本卡不做手势改派实验的对照组：PHLivePhotoView 自带的长按播放
            // 保持开启，好让 H62b 直接看到它与既有长按（标定面板入口）同时触发。
            view.isUserInteractionEnabled = false
            view.contentMode = .scaleAspectFit
            addSubview(view)
            livePhotoView = view
        case .video:
            let layer = AVPlayerLayer()
            layer.videoGravity = .resizeAspect
            layer.actions = [
                "bounds": NSNull(),
                "position": NSNull(),
                "frame": NSNull()
            ]
            self.layer.addSublayer(layer)
            playerLayer = layer
        case .photo:
            break
        }
        setNeedsLayout()
    }

    func attach(livePhoto: PHLivePhoto) {
        livePhotoView?.livePhoto = livePhoto
    }

    func attach(player: AVPlayer) {
        playerLayer?.player = player
    }

    func detach() {
        // 必须同时清 `kind`：`configure` 以 `self.kind != kind` 为守卫，
        // 不清就永远重建不了播放层。
        kind = .photo
        livePhotoView?.stopPlayback()
        livePhotoView?.removeFromSuperview()
        livePhotoView = nil
        playerLayer?.player?.pause()
        playerLayer?.player = nil
        playerLayer?.removeFromSuperlayer()
        playerLayer = nil
    }

    func play() {
        livePhotoView?.startPlayback(with: .full)
        if let player = playerLayer?.player {
            player.seek(to: .zero)
            player.play()
        }
    }

    func stop() {
        livePhotoView?.stopPlayback()
        if let player = playerLayer?.player {
            player.pause()
            player.seek(to: .zero)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        livePhotoView?.frame = bounds
        playerLayer?.frame = bounds
        CATransaction.commit()
    }
}

// MARK: - 页内容里的播放层

struct S2MediaPlaybackProbeContentView: UIViewRepresentable {
    let probe: S2MediaPlaybackProbeCoordinator
    let assetID: String

    /// 只为把 assetID 带进 `dismantleUIView`——它是 static，
    /// `Coordinator == Void` 时拿不到任何页身份，拆卸就无处收口。
    final class Coordinator {
        let probe: S2MediaPlaybackProbeCoordinator
        var assetID: String

        init(probe: S2MediaPlaybackProbeCoordinator, assetID: String) {
            self.probe = probe
            self.assetID = assetID
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(probe: probe, assetID: assetID)
    }

    func makeUIView(context: Context) -> S2ProbeMediaHostView {
        let view = S2ProbeMediaHostView(frame: .zero)
        context.coordinator.assetID = assetID
        probe.register(hostView: view, assetID: assetID)
        return view
    }

    func updateUIView(_ uiView: S2ProbeMediaHostView, context: Context) {
        context.coordinator.assetID = assetID
        probe.register(hostView: uiView, assetID: assetID)
    }

    static func dismantleUIView(
        _ uiView: S2ProbeMediaHostView,
        coordinator: Coordinator
    ) {
        coordinator.probe.pageDestroyed(
            assetID: coordinator.assetID,
            hostView: uiView
        )
    }
}

// MARK: - 探针叠层

/// 读数卡。放在 `S2View` 的 ZStack 里、**缩放容器之外**——放进页内容会随捏合一起缩放、
/// 会被几何链改写 bounds，双击过渡期间还会被整块隐藏，正好在最需要读数的时候看不见。
struct S2MediaPlaybackProbeOverlay: View {
    @ObservedObject var probe: S2MediaPlaybackProbeCoordinator
    let topInset: CGFloat

    var body: some View {
        let readout = probe.readout
        let typeLine = "type " + readout.kindLabel + " / " + readout.stateLabel
        let readyLine = "ready "
            + Self.format(readout.readyMilliseconds, suffix: "ms")
            + " [" + readout.deliveryLabel + "]"
        let memoryLine = "mem "
            + Self.format(readout.footprintMegabytes, suffix: "MB")
            + " peak "
            + Self.format(readout.peakFootprintMegabytes, suffix: "MB")
        let stallLine = "stall " + String(readout.stallCount)
            + " worst " + Self.format(readout.worstStallMilliseconds, suffix: "ms")
            + " / turns " + String(readout.pageTurnCount)
        let idLine = "id " + readout.assetID

        return VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: typeLine)
            Text(verbatim: readyLine)
            Text(verbatim: memoryLine)
            Text(verbatim: stallLine)
            Text(verbatim: idLine)
        }
        .font(.system(size: 10, design: .monospaced))
        .foregroundStyle(Color.white)
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.black.opacity(0.55))
        )
        .padding(.leading, 8)
        .padding(.top, topInset + 8)
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: .topLeading
        )
        .allowsHitTesting(false)
    }

    private static func format(_ value: Double?, suffix: String) -> String {
        guard let value else {
            let placeholder = "-"
            return placeholder
        }
        let rounded = (value * 10).rounded() / 10
        let text = String(rounded) + suffix
        return text
    }
}
