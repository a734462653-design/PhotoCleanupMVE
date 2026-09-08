import Photos
import SwiftUI
import UIKit

// MARK: - IC-140 A：实况播放状态机（纯值语义，无 UIKit / PhotoKit 依赖）
//
// v19 回写决策 55（实况播放）、58（长按分派）。键取 assetID 而不是页索引：
// 页控制器的 index 是 let，assetID 却会在存活的控制器上被改写（删除或重排后
// 同一个控制器代表另一张资产），按页索引记状态会让播放串到别的照片上。
//
// 状态机只认实况资产——照片页与视频页在 `S2View` 侧就不进事件（当前页非实况时
// `assetID` 传 nil），因此这里没有一处媒体类别判别，不会成为第二份分类实现。

/// 单张实况资产的播放态。
enum S2LivePhotoPlaybackState: Equatable {
    /// 未持有资源，也没有在飞的请求。
    case idle
    /// 取资源请求在飞。
    case requesting
    /// 资源到手，未播。
    case ready
    /// 到页短动效播放中（静音）。
    case playingHint
    /// 长按全段播放中（有声）。
    case playingFull
    /// 请求失败。
    case failed
}

/// 播放口径：到页短动效与长按全段两态。
///
/// `isMuted` 是**模型字段**，不是 UIKit 读数——规格第 9 条：hint 静音、full 有声。
enum S2LivePhotoPlaybackStyle: Equatable {
    case hint
    case full

    var isMuted: Bool {
        self == .hint
    }
}

enum S2LivePhotoPlaybackEvent: Equatable {
    /// 进入 S2。`assetID` = 入口页的实况资产（nil ⟹ 入口页不是实况）。
    /// 入口那张不自动播短动效，直到发生过至少一次页变更（规格第 3 条）。
    case entered(assetID: String?)
    /// 当前页变更。`assetID` = 新当前页的实况资产（nil ⟹ 当前页不是实况）；
    /// `neighbours` = 半径内其余实况资产，**按距当前页的距离升序**——
    /// 超出持有上限时按这个顺序退离最远的一页。
    case becameCurrent(assetID: String?, neighbours: [String])
    /// 翻页停稳。这是短动效唯一的起播时机（拖动进行中不播）。
    case pagingSettled
    case requestSucceeded(assetID: String, generation: Int)
    case requestFailed(assetID: String, generation: Int)
    /// 主图长按 0.8 s 落在实况页。作用于当前页，无载荷。
    case longPressBegan
    case longPressEnded
    /// 播放自然结束（宿主视图的代理回调）。**探针缺陷的修复点**：
    /// 不收这个事件，状态会永远停在「播放中」，第二次长按就成了空操作。
    case playbackEnded(assetID: String)
}

enum S2LivePhotoPlaybackEffect: Equatable {
    case request(assetID: String, generation: Int)
    case cancelRequest(assetID: String, generation: Int)
    case playHint(assetID: String)
    case playFull(assetID: String)
    case stop(assetID: String)
    case unload(assetID: String)
}

struct S2LivePhotoPlaybackMachine {
    private(set) var states: [String: S2LivePhotoPlaybackState] = [:]
    /// 每页每次请求的代次。迟到回调（代次不符或页已退）一律丢弃（规格第 2 条）。
    private(set) var generations: [String: Int] = [:]
    /// 当前页的实况资产。非实况页为 nil。
    private(set) var currentAssetID: String?
    private(set) var entryAssetID: String?
    /// 长按按住中。未就绪时长按记在这里，就绪即播（规格第 5 条）。
    private(set) var isPressing = false
    /// 当前页是否已停稳。停稳前不放短动效。
    private(set) var isSettled = false
    /// 进入 S2 后是否发生过至少一次页变更。入口那张的自动播守卫。
    private(set) var didChangePageSinceEntry = false
    /// 本次到达是否已放过短动效。同页反复停稳不重播；翻走再翻回重播。
    private(set) var didPlayHintOnThisArrival = false
    private var nextGeneration = 1

    func state(for assetID: String) -> S2LivePhotoPlaybackState {
        states[assetID] ?? .idle
    }

    /// 已请求或已到手的资产集合。持有上限 `livePhotoInstanceCap` 钉的就是它。
    var heldAssetIDs: Set<String> {
        Set(
            states
                .filter { Self.counts(asHeld: $0.value) }
                .keys
        )
    }

    /// 播放中的资产集合。任何时刻至多一页（规格第 8 条）。
    var playingAssetIDs: Set<String> {
        Set(
            states
                .filter { $0.value == .playingHint || $0.value == .playingFull }
                .keys
        )
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
        return Array(ordered.prefix(S2MediaMetrics.livePhotoInstanceCap))
    }

    mutating func handle(
        _ event: S2LivePhotoPlaybackEvent
    ) -> [S2LivePhotoPlaybackEffect] {
        switch event {
        case let .entered(assetID):
            entryAssetID = assetID
            currentAssetID = assetID
            didChangePageSinceEntry = false
            didPlayHintOnThisArrival = false
            isSettled = false
            isPressing = false
            return []

        case let .becameCurrent(assetID, neighbours):
            return handleBecameCurrent(
                assetID: assetID,
                neighbours: neighbours
            )

        case .pagingSettled:
            isSettled = true
            guard let assetID = currentAssetID, canPlayHint(assetID) else {
                return []
            }
            return [startHint(assetID)]

        case let .requestSucceeded(assetID, generation):
            guard isFreshCallback(generation: generation, of: assetID) else {
                return []
            }
            states[assetID] = .ready
            guard assetID == currentAssetID else {
                return []
            }
            if isPressing {
                states[assetID] = .playingFull
                return [.playFull(assetID: assetID)]
            }
            guard canPlayHint(assetID) else {
                return []
            }
            return [startHint(assetID)]

        case let .requestFailed(assetID, generation):
            guard isFreshCallback(generation: generation, of: assetID) else {
                return []
            }
            states[assetID] = .failed
            generations[assetID] = nil
            return []

        case .longPressBegan:
            isPressing = true
            guard let assetID = currentAssetID else {
                return []
            }
            switch state(for: assetID) {
            case .ready, .playingHint:
                // 短动效播放中长按 ⟹ 立即转全段（规格第 5 条）。
                states[assetID] = .playingFull
                return [.playFull(assetID: assetID)]
            case .idle, .requesting, .playingFull, .failed:
                // 未就绪只记「按住中」，就绪即播。
                return []
            }

        case .longPressEnded:
            isPressing = false
            guard let assetID = currentAssetID,
                  state(for: assetID) == .playingFull else {
                return []
            }
            states[assetID] = .ready
            return [.stop(assetID: assetID)]

        case let .playbackEnded(assetID):
            guard playingAssetIDs.contains(assetID) else {
                return []
            }
            states[assetID] = .ready
            // 回静态帧同样走效果口，宿主视图不自行收口（陷阱 19）。
            return [.stop(assetID: assetID)]
        }
    }

    // MARK: - 私有

    private static func counts(
        asHeld state: S2LivePhotoPlaybackState
    ) -> Bool {
        switch state {
        case .requesting, .ready, .playingHint, .playingFull:
            return true
        case .idle, .failed:
            return false
        }
    }

    /// 回调是否仍然有效：代次相符且该页确实还在等这次请求。
    private func isFreshCallback(generation: Int, of assetID: String) -> Bool {
        generations[assetID] == generation &&
            state(for: assetID) == .requesting
    }

    private func canPlayHint(_ assetID: String) -> Bool {
        didChangePageSinceEntry &&
            isSettled &&
            !isPressing &&
            !didPlayHintOnThisArrival &&
            state(for: assetID) == .ready
    }

    private mutating func startHint(
        _ assetID: String
    ) -> S2LivePhotoPlaybackEffect {
        states[assetID] = .playingHint
        didPlayHintOnThisArrival = true
        return .playHint(assetID: assetID)
    }

    private mutating func handleBecameCurrent(
        assetID: String?,
        neighbours: [String]
    ) -> [S2LivePhotoPlaybackEffect] {
        var effects: [S2LivePhotoPlaybackEffect] = []
        let previous = currentAssetID
        if previous != assetID {
            didChangePageSinceEntry = true
            didPlayHintOnThisArrival = false
            // 挂起期间翻不了页（规格第 7 条），真走到这里说明按住态已失效。
            isPressing = false
        }
        currentAssetID = assetID
        isSettled = false

        let retained = Self.retentionSet(
            current: assetID,
            neighbours: neighbours
        )
        // 退离半径外：在飞的取消，已到手的卸载（顺序无关，排序只为可复现）。
        for held in heldAssetIDs.sorted() where !retained.contains(held) {
            effects.append(contentsOf: retire(held))
        }
        // 前页仍在半径内但在播 ⟹ 停回静态帧，资源留着（规格第 8 条）。
        if let previous,
           previous != assetID,
           retained.contains(previous),
           playingAssetIDs.contains(previous) {
            states[previous] = .ready
            effects.append(.stop(assetID: previous))
        }
        for target in retained where needsRequest(target) {
            effects.append(startRequest(target))
        }
        return effects
    }

    private func needsRequest(_ assetID: String) -> Bool {
        switch state(for: assetID) {
        case .idle, .failed:
            return true
        case .requesting, .ready, .playingHint, .playingFull:
            return false
        }
    }

    private mutating func startRequest(
        _ assetID: String
    ) -> S2LivePhotoPlaybackEffect {
        let generation = nextGeneration
        nextGeneration += 1
        generations[assetID] = generation
        states[assetID] = .requesting
        return .request(assetID: assetID, generation: generation)
    }

    private mutating func retire(
        _ assetID: String
    ) -> [S2LivePhotoPlaybackEffect] {
        var effects: [S2LivePhotoPlaybackEffect] = []
        switch state(for: assetID) {
        case .requesting:
            if let generation = generations[assetID] {
                effects.append(
                    .cancelRequest(assetID: assetID, generation: generation)
                )
            }
        case .playingHint, .playingFull:
            effects.append(.stop(assetID: assetID))
            effects.append(.unload(assetID: assetID))
        case .ready:
            effects.append(.unload(assetID: assetID))
        case .idle, .failed:
            break
        }
        states[assetID] = nil
        generations[assetID] = nil
        return effects
    }
}

// MARK: - 播放层接口

/// 协调器与播放层之间的唯一接口。
///
/// 协调器只经这四个方法碰播放层——把 `PHLivePhotoView` 关在宿主视图里，
/// 状态机与效果执行因此不依赖 PhotosUI。
protocol S2LivePhotoPlaybackSurface: AnyObject {
    func attach(livePhoto: PHLivePhoto)
    func detachLivePhoto()
    func play(style: S2LivePhotoPlaybackStyle)
    func stop()
}

// MARK: - 协调器

/// 效果执行与 `PHImageManager` 接线。**不做任何判定**——所有判定在状态机里。
///
/// 主线程限定：全部入口由 SwiftUI 与 UIKit 回调驱动，后台只有一次
/// `PHAsset.fetchAssets`，回调立刻跳回主线程（照 IC-137 探针）。
final class S2LivePhotoPlaybackCoordinator: ObservableObject {
    private var machine = S2LivePhotoPlaybackMachine()
    private var surfaces: [String: SurfaceBox] = [:]
    private var livePhotos: [String: PHLivePhoto] = [:]
    private var requestIDs: [String: PHImageRequestID] = [:]
    /// 取资源的目标尺寸（像素）。任一播放层登记时更新——各页都在同一视口内，
    /// 用哪一页的基准尺寸都是同一量级；尚无登记时退化为最大尺寸。
    private var targetSize: CGSize?
    private let imageManager: PHImageManager
    private let fetchQueue = DispatchQueue(
        label: "com.photocleanupmve.s2.livephoto.fetch"
    )

    private final class SurfaceBox {
        weak var surface: (any S2LivePhotoPlaybackSurface)?

        init(_ surface: any S2LivePhotoPlaybackSurface) {
            self.surface = surface
        }
    }

    init(imageManager: PHImageManager = .default()) {
        self.imageManager = imageManager
    }

    // MARK: 事件入口（S2View 与分页器只经这些方法）

    func enter(assetID: String?) {
        apply(machine.handle(.entered(assetID: assetID)))
    }

    func pageBecameCurrent(assetID: String?, neighbours: [String]) {
        apply(
            machine.handle(
                .becameCurrent(assetID: assetID, neighbours: neighbours)
            )
        )
    }

    func pagingSettled() {
        apply(machine.handle(.pagingSettled))
    }

    /// 返回值 = 是否挂起手势。当前页非实况时为 false，分页器据此不挂起。
    func longPressBegan() -> Bool {
        let suspends = machine.currentAssetID != nil
        apply(machine.handle(.longPressBegan))
        return suspends
    }

    func longPressEnded() {
        apply(machine.handle(.longPressEnded))
    }

    func playbackEnded(assetID: String) {
        apply(machine.handle(.playbackEnded(assetID: assetID)))
    }

    /// 离开 S2：当前页与邻居都清空，等同于翻到一个没有实况的页。
    func leave() {
        apply(machine.handle(.becameCurrent(assetID: nil, neighbours: [])))
    }

    // MARK: 播放层登记

    func register(
        surface: any S2LivePhotoPlaybackSurface,
        for assetID: String,
        targetSize: CGSize
    ) {
        surfaces[assetID] = SurfaceBox(surface)
        if targetSize.width > 0, targetSize.height > 0 {
            self.targetSize = targetSize
        }
        // 资源可能早于播放层到位（预取），登记时补挂一次。
        if let livePhoto = livePhotos[assetID] {
            surface.attach(livePhoto: livePhoto)
        }
    }

    func unregister(assetID: String) {
        surfaces.removeValue(forKey: assetID)
    }

    // MARK: 断言入口（仅供 XCTest）

    func playbackState(for assetID: String) -> S2LivePhotoPlaybackState {
        machine.state(for: assetID)
    }

    // MARK: 效果执行

    private func apply(_ effects: [S2LivePhotoPlaybackEffect]) {
        for effect in effects {
            switch effect {
            case let .request(assetID, generation):
                startRequest(assetID: assetID, generation: generation)
            case let .cancelRequest(assetID, _):
                cancelRequest(assetID: assetID)
            case let .playHint(assetID):
                surface(for: assetID)?.play(style: .hint)
            case let .playFull(assetID):
                surface(for: assetID)?.play(style: .full)
            case let .stop(assetID):
                surface(for: assetID)?.stop()
            case let .unload(assetID):
                unload(assetID: assetID)
            }
        }
    }

    private func surface(
        for assetID: String
    ) -> (any S2LivePhotoPlaybackSurface)? {
        surfaces[assetID]?.surface
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
                    self.apply(
                        self.machine.handle(
                            .requestFailed(
                                assetID: assetID,
                                generation: generation
                            )
                        )
                    )
                    return
                }
                self.requestLivePhoto(
                    asset: asset,
                    assetID: assetID,
                    generation: generation
                )
            }
        }
    }

    private func requestLivePhoto(
        asset: PHAsset,
        assetID: String,
        generation: Int
    ) {
        let options = PHLivePhotoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.version = .current
        options.deliveryMode = .opportunistic
        let id = imageManager.requestLivePhoto(
            for: asset,
            targetSize: targetSize ?? PHImageManagerMaximumSize,
            contentMode: .aspectFit,
            options: options
        ) { [weak self] livePhoto, info in
            DispatchQueue.main.async {
                self?.finishRequest(
                    assetID: assetID,
                    generation: generation,
                    livePhoto: livePhoto,
                    info: info
                )
            }
        }
        requestIDs[assetID] = id
    }

    /// `opportunistic` 先回一个降质件。降质件**非 nil**，若拿它当终值收口，
    /// `requestIDs` 里的 id 会被提前释放——翻走时真正在飞的那个请求反而取消不了
    /// （IC-137 探针 455-505 ①实测）。故降质件只挂图，不动 id、不发事件。
    private func finishRequest(
        assetID: String,
        generation: Int,
        livePhoto: PHLivePhoto?,
        info: [AnyHashable: Any]?
    ) {
        let cancelled = (info?[PHImageCancelledKey] as? Bool) ?? false
        guard !cancelled else {
            return
        }
        let degraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
        guard let livePhoto else {
            guard !degraded else {
                return
            }
            requestIDs.removeValue(forKey: assetID)
            apply(
                machine.handle(
                    .requestFailed(assetID: assetID, generation: generation)
                )
            )
            return
        }
        livePhotos[assetID] = livePhoto
        surface(for: assetID)?.attach(livePhoto: livePhoto)
        guard !degraded else {
            return
        }
        requestIDs.removeValue(forKey: assetID)
        apply(
            machine.handle(
                .requestSucceeded(assetID: assetID, generation: generation)
            )
        )
    }

    private func cancelRequest(assetID: String) {
        if let id = requestIDs.removeValue(forKey: assetID) {
            imageManager.cancelImageRequest(id)
        }
    }

    private func unload(assetID: String) {
        cancelRequest(assetID: assetID)
        livePhotos.removeValue(forKey: assetID)
        surface(for: assetID)?.detachLivePhoto()
    }
}
