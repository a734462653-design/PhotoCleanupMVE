import Combine
import CoreGraphics
import Foundation
import Security

enum S2FitInsetScope: String, CaseIterable, Codable, Equatable {
    case screenAspectOnly
    case allPhotos
}

enum S2GestureExclusivityPolicy: String, CaseIterable, Codable, Equatable {
    case pinchBeforeSingleDrag
    case singleDragBeforePinch
}

struct S2CalibrationConfiguration: Codable, Equatable {
    static let schemaVersion = 1

    var pinchMaxScale: Double
    var zoomSnapBackThreshold: Double
    var minDoubleTapScale: Double
    var doubleTapAnchorStrategy: S2DoubleTapAnchorStrategy
    var edgePagingTriggerDistance: Double
    var edgePagingTriggerVelocity: Double
    var verticalSwipeDistance: Double
    var verticalSwipeVelocity: Double
    var verticalSwipeMaximumDurationMilliseconds: Double
    var horizontalSwipeDistance: Double
    var horizontalSwipeVelocity: Double
    var horizontalSwipeMaximumDurationMilliseconds: Double
    var pinchMinimumScaleDelta: Double
    var pinchMinimumVelocityPerSecond: Double
    var pinchMaximumDurationMilliseconds: Double
    var mainDragMinimumDistance: Double
    var mainDragMinimumVelocity: Double
    var mainDragMaximumDurationMilliseconds: Double
    var singleTapMaximumMovement: Double
    var singleTapMaximumDurationMilliseconds: Double
    var doubleTapDecisionWindowMilliseconds: Double
    var singleTapTouchCount: Int
    var doubleTapTouchCount: Int
    var singleDragTouchCount: Int
    var pinchTouchCount: Int
    var gestureExclusivityPolicy: S2GestureExclusivityPolicy
    var scaleChangeRequestPolicy: S2ScaleChangeImageRequestPolicy
    var degradedPreviewPolicy: S2DegradedPreviewPolicy
    var animationsEnabled: Bool
    var animationDurationMilliseconds: Double
    var fitInsetRatio: Double
    var fitCornerRadius: Double
    var fitInsetScope: S2FitInsetScope
    var screenshotImmersiveOnHide: Bool
    var pageSpacing: Double
    var hapticOnPhotoSwitch: Bool
    var bottomStripCurrentItemSize: Double
    var bottomStripNeighborItemWidth: Double
    var bottomStripNeighborItemHeight: Double
    var bottomStripItemSpacing: Double
    var bottomStripEdgeFadeWidth: Double
    var bottomStripDragMinimumDistance: Double
    var bottomStripSwitchDistance: Double

    // IC-063 全屏沉浸与原生退出项目判断默认值；全部数值延续 IC-061。
    static let factoryPlaceholder = S2CalibrationConfiguration(
        pinchMaxScale: 4,
        zoomSnapBackThreshold: 1.1,
        minDoubleTapScale: 2,
        doubleTapAnchorStrategy: .touchPoint,
        edgePagingTriggerDistance: 40,
        edgePagingTriggerVelocity: 300,
        verticalSwipeDistance: 40,
        verticalSwipeVelocity: 100,
        verticalSwipeMaximumDurationMilliseconds: 0,
        horizontalSwipeDistance: 40,
        horizontalSwipeVelocity: 100,
        horizontalSwipeMaximumDurationMilliseconds: 0,
        pinchMinimumScaleDelta: 0.01,
        pinchMinimumVelocityPerSecond: 0,
        pinchMaximumDurationMilliseconds: 0,
        mainDragMinimumDistance: 8,
        mainDragMinimumVelocity: 0,
        mainDragMaximumDurationMilliseconds: 0,
        singleTapMaximumMovement: 12,
        singleTapMaximumDurationMilliseconds: 280,
        doubleTapDecisionWindowMilliseconds: 200,
        singleTapTouchCount: 1,
        doubleTapTouchCount: 1,
        singleDragTouchCount: 1,
        pinchTouchCount: 2,
        gestureExclusivityPolicy: .pinchBeforeSingleDrag,
        scaleChangeRequestPolicy: .pinchEnded,
        degradedPreviewPolicy: .finalImageOnly,
        animationsEnabled: true,
        animationDurationMilliseconds: 180,
        fitInsetRatio: 0.30,
        fitCornerRadius: 28,
        fitInsetScope: .screenAspectOnly,
        screenshotImmersiveOnHide: true,
        pageSpacing: 20,
        hapticOnPhotoSwitch: true,
        bottomStripCurrentItemSize: 72,
        bottomStripNeighborItemWidth: 52,
        bottomStripNeighborItemHeight: 44,
        bottomStripItemSpacing: 8,
        bottomStripEdgeFadeWidth: 24,
        bottomStripDragMinimumDistance: 4,
        bottomStripSwitchDistance: 44
    )

    var resolvedParameters: S2ResolvedParameters? {
        S2ResolvedParameters(
            pinchMaxScale: CGFloat(pinchMaxScale),
            zoomSnapBackThreshold: CGFloat(zoomSnapBackThreshold),
            minDoubleTapScale: CGFloat(minDoubleTapScale),
            doubleTapAnchorStrategy: doubleTapAnchorStrategy,
            edgePagingTriggerDistance: CGFloat(edgePagingTriggerDistance),
            edgePagingTriggerVelocity: CGFloat(edgePagingTriggerVelocity),
            verticalSwipeDistance: CGFloat(verticalSwipeDistance),
            verticalSwipeVelocity: CGFloat(verticalSwipeVelocity),
            horizontalSwipeDistance: CGFloat(horizontalSwipeDistance),
            horizontalSwipeVelocity: CGFloat(horizontalSwipeVelocity),
            pinchMinimumScaleDelta: CGFloat(pinchMinimumScaleDelta),
            mainDragMinimumDistance: CGFloat(mainDragMinimumDistance),
            bottomStripMetrics: S2BottomStripMetrics(
                currentItemSize: CGFloat(bottomStripCurrentItemSize),
                neighborItemWidth: CGFloat(bottomStripNeighborItemWidth),
                neighborItemHeight: CGFloat(bottomStripNeighborItemHeight),
                itemSpacing: CGFloat(bottomStripItemSpacing),
                edgeFadeWidth: CGFloat(bottomStripEdgeFadeWidth),
                dragMinimumDistance: CGFloat(bottomStripDragMinimumDistance),
                switchDistance: CGFloat(bottomStripSwitchDistance)
            )
        )
    }

    var imageRequestStrategy: S2ImageRequestStrategy {
        S2ImageRequestStrategy(
            scaleChangePolicy: scaleChangeRequestPolicy,
            degradedPreviewPolicy: degradedPreviewPolicy
        )
    }

    var isValid: Bool {
        resolvedParameters != nil &&
            verticalSwipeMaximumDurationMilliseconds >= 0 &&
            horizontalSwipeMaximumDurationMilliseconds >= 0 &&
            pinchMinimumVelocityPerSecond >= 0 &&
            pinchMaximumDurationMilliseconds >= 0 &&
            mainDragMinimumVelocity >= 0 &&
            mainDragMaximumDurationMilliseconds >= 0 &&
            singleTapMaximumMovement >= 0 &&
            singleTapMaximumDurationMilliseconds >= 0 &&
            doubleTapDecisionWindowMilliseconds >= 0 &&
            singleTapTouchCount > 0 &&
            doubleTapTouchCount > 0 &&
            singleDragTouchCount > 0 &&
            pinchTouchCount > 0 &&
            animationDurationMilliseconds >= 0 &&
            fitInsetRatio >= 0 && fitInsetRatio < 0.5 &&
            fitCornerRadius >= 0 &&
            pageSpacing >= 0
    }

    func exportText() -> String {
        let values: [(String, String)] = [
            ("schemaVersion", String(Self.schemaVersion)),
            ("taskID", "IC-20260816-063-s2-immersive-and-doubletap-transition"),
            ("valueStatus", L10n.text("s2.calibration.value_status")),
            ("pinchMaxScale", formatted(pinchMaxScale)),
            ("zoomSnapBackThreshold", formatted(zoomSnapBackThreshold)),
            ("minDoubleTapScale", formatted(minDoubleTapScale)),
            ("doubleTapAnchorStrategy", doubleTapAnchorStrategy.rawValue),
            ("edgePagingTriggerDistance", formatted(edgePagingTriggerDistance)),
            ("edgePagingTriggerVelocity", formatted(edgePagingTriggerVelocity)),
            ("verticalSwipeDistance", formatted(verticalSwipeDistance)),
            ("verticalSwipeVelocity", formatted(verticalSwipeVelocity)),
            ("verticalSwipeMaximumDurationMilliseconds", formatted(verticalSwipeMaximumDurationMilliseconds)),
            ("horizontalSwipeDistance", formatted(horizontalSwipeDistance)),
            ("horizontalSwipeVelocity", formatted(horizontalSwipeVelocity)),
            ("horizontalSwipeMaximumDurationMilliseconds", formatted(horizontalSwipeMaximumDurationMilliseconds)),
            ("pinchMinimumScaleDelta", formatted(pinchMinimumScaleDelta)),
            ("pinchMinimumVelocityPerSecond", formatted(pinchMinimumVelocityPerSecond)),
            ("pinchMaximumDurationMilliseconds", formatted(pinchMaximumDurationMilliseconds)),
            ("mainDragMinimumDistance", formatted(mainDragMinimumDistance)),
            ("mainDragMinimumVelocity", formatted(mainDragMinimumVelocity)),
            ("mainDragMaximumDurationMilliseconds", formatted(mainDragMaximumDurationMilliseconds)),
            ("singleTapMaximumMovement", formatted(singleTapMaximumMovement)),
            ("singleTapMaximumDurationMilliseconds", formatted(singleTapMaximumDurationMilliseconds)),
            ("doubleTapDecisionWindowMilliseconds", formatted(doubleTapDecisionWindowMilliseconds)),
            ("singleTapTouchCount", String(singleTapTouchCount)),
            ("doubleTapTouchCount", String(doubleTapTouchCount)),
            ("singleDragTouchCount", String(singleDragTouchCount)),
            ("pinchTouchCount", String(pinchTouchCount)),
            ("gestureExclusivityPolicy", gestureExclusivityPolicy.rawValue),
            ("scaleChangeRequestPolicy", scaleChangeRequestPolicy.rawValue),
            ("degradedPreviewPolicy", degradedPreviewPolicy.rawValue),
            ("animationsEnabled", String(animationsEnabled)),
            ("animationDurationMilliseconds", formatted(animationDurationMilliseconds)),
            ("fitInsetRatio", formatted(fitInsetRatio)),
            ("fitCornerRadius", formatted(fitCornerRadius)),
            ("fitInsetScope", fitInsetScope.rawValue),
            ("screenshotImmersiveOnHide", String(screenshotImmersiveOnHide)),
            ("pageSpacing", formatted(pageSpacing)),
            ("hapticOnPhotoSwitch", String(hapticOnPhotoSwitch)),
            ("bottomStripCurrentItemSize", formatted(bottomStripCurrentItemSize)),
            ("bottomStripNeighborItemWidth", formatted(bottomStripNeighborItemWidth)),
            ("bottomStripNeighborItemHeight", formatted(bottomStripNeighborItemHeight)),
            ("bottomStripItemSpacing", formatted(bottomStripItemSpacing)),
            ("bottomStripEdgeFadeWidth", formatted(bottomStripEdgeFadeWidth)),
            ("bottomStripDragMinimumDistance", formatted(bottomStripDragMinimumDistance)),
            ("bottomStripSwitchDistance", formatted(bottomStripSwitchDistance))
        ]
        return values.map { "\($0.0)=\($0.1)" }.joined(separator: "\n")
    }

    private func formatted(_ value: Double) -> String {
        String(
            format: "%.6f",
            locale: Locale(identifier: "en_US_POSIX"),
            value
        )
    }
}

extension S2CalibrationConfiguration {
    private enum CodingKeys: String, CodingKey {
        case pinchMaxScale
        case zoomSnapBackThreshold
        case minDoubleTapScale
        case doubleTapAnchorStrategy
        case edgePagingTriggerDistance
        case edgePagingTriggerVelocity
        case verticalSwipeDistance
        case verticalSwipeVelocity
        case verticalSwipeMaximumDurationMilliseconds
        case horizontalSwipeDistance
        case horizontalSwipeVelocity
        case horizontalSwipeMaximumDurationMilliseconds
        case pinchMinimumScaleDelta
        case pinchMinimumVelocityPerSecond
        case pinchMaximumDurationMilliseconds
        case mainDragMinimumDistance
        case mainDragMinimumVelocity
        case mainDragMaximumDurationMilliseconds
        case singleTapMaximumMovement
        case singleTapMaximumDurationMilliseconds
        case doubleTapDecisionWindowMilliseconds
        case singleTapTouchCount
        case doubleTapTouchCount
        case singleDragTouchCount
        case pinchTouchCount
        case gestureExclusivityPolicy
        case scaleChangeRequestPolicy
        case degradedPreviewPolicy
        case animationsEnabled
        case animationDurationMilliseconds
        case fitInsetRatio
        case fitCornerRadius
        case fitInsetScope
        case screenshotImmersiveOnHide
        case pageSpacing
        case hapticOnPhotoSwitch
        case bottomStripCurrentItemSize
        case bottomStripNeighborItemWidth
        case bottomStripNeighborItemHeight
        case bottomStripItemSpacing
        case bottomStripEdgeFadeWidth
        case bottomStripDragMinimumDistance
        case bottomStripSwitchDistance
    }

    // 旧版持久化数据没有本卡新增字段；其余字段仍按原契约严格解码。
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            pinchMaxScale: try values.decode(Double.self, forKey: .pinchMaxScale),
            zoomSnapBackThreshold: try values.decode(Double.self, forKey: .zoomSnapBackThreshold),
            minDoubleTapScale: try values.decode(Double.self, forKey: .minDoubleTapScale),
            doubleTapAnchorStrategy: try values.decode(S2DoubleTapAnchorStrategy.self, forKey: .doubleTapAnchorStrategy),
            edgePagingTriggerDistance: try values.decode(Double.self, forKey: .edgePagingTriggerDistance),
            edgePagingTriggerVelocity: try values.decode(Double.self, forKey: .edgePagingTriggerVelocity),
            verticalSwipeDistance: try values.decode(Double.self, forKey: .verticalSwipeDistance),
            verticalSwipeVelocity: try values.decode(Double.self, forKey: .verticalSwipeVelocity),
            verticalSwipeMaximumDurationMilliseconds: try values.decode(Double.self, forKey: .verticalSwipeMaximumDurationMilliseconds),
            horizontalSwipeDistance: try values.decode(Double.self, forKey: .horizontalSwipeDistance),
            horizontalSwipeVelocity: try values.decode(Double.self, forKey: .horizontalSwipeVelocity),
            horizontalSwipeMaximumDurationMilliseconds: try values.decode(Double.self, forKey: .horizontalSwipeMaximumDurationMilliseconds),
            pinchMinimumScaleDelta: try values.decode(Double.self, forKey: .pinchMinimumScaleDelta),
            pinchMinimumVelocityPerSecond: try values.decode(Double.self, forKey: .pinchMinimumVelocityPerSecond),
            pinchMaximumDurationMilliseconds: try values.decode(Double.self, forKey: .pinchMaximumDurationMilliseconds),
            mainDragMinimumDistance: try values.decode(Double.self, forKey: .mainDragMinimumDistance),
            mainDragMinimumVelocity: try values.decode(Double.self, forKey: .mainDragMinimumVelocity),
            mainDragMaximumDurationMilliseconds: try values.decode(Double.self, forKey: .mainDragMaximumDurationMilliseconds),
            singleTapMaximumMovement: try values.decode(Double.self, forKey: .singleTapMaximumMovement),
            singleTapMaximumDurationMilliseconds: try values.decode(Double.self, forKey: .singleTapMaximumDurationMilliseconds),
            doubleTapDecisionWindowMilliseconds: try values.decode(Double.self, forKey: .doubleTapDecisionWindowMilliseconds),
            singleTapTouchCount: try values.decode(Int.self, forKey: .singleTapTouchCount),
            doubleTapTouchCount: try values.decode(Int.self, forKey: .doubleTapTouchCount),
            singleDragTouchCount: try values.decode(Int.self, forKey: .singleDragTouchCount),
            pinchTouchCount: try values.decode(Int.self, forKey: .pinchTouchCount),
            gestureExclusivityPolicy: try values.decode(S2GestureExclusivityPolicy.self, forKey: .gestureExclusivityPolicy),
            scaleChangeRequestPolicy: try values.decode(S2ScaleChangeImageRequestPolicy.self, forKey: .scaleChangeRequestPolicy),
            degradedPreviewPolicy: try values.decode(S2DegradedPreviewPolicy.self, forKey: .degradedPreviewPolicy),
            animationsEnabled: try values.decode(Bool.self, forKey: .animationsEnabled),
            animationDurationMilliseconds: try values.decode(Double.self, forKey: .animationDurationMilliseconds),
            fitInsetRatio: try values.decode(Double.self, forKey: .fitInsetRatio),
            fitCornerRadius: try values.decodeIfPresent(Double.self, forKey: .fitCornerRadius) ?? 28,
            fitInsetScope: try values.decode(S2FitInsetScope.self, forKey: .fitInsetScope),
            screenshotImmersiveOnHide: try values.decodeIfPresent(Bool.self, forKey: .screenshotImmersiveOnHide) ?? true,
            pageSpacing: try values.decodeIfPresent(Double.self, forKey: .pageSpacing) ?? 20,
            hapticOnPhotoSwitch: try values.decodeIfPresent(Bool.self, forKey: .hapticOnPhotoSwitch) ?? true,
            bottomStripCurrentItemSize: try values.decode(Double.self, forKey: .bottomStripCurrentItemSize),
            bottomStripNeighborItemWidth: try values.decode(Double.self, forKey: .bottomStripNeighborItemWidth),
            bottomStripNeighborItemHeight: try values.decode(Double.self, forKey: .bottomStripNeighborItemHeight),
            bottomStripItemSpacing: try values.decode(Double.self, forKey: .bottomStripItemSpacing),
            bottomStripEdgeFadeWidth: try values.decode(Double.self, forKey: .bottomStripEdgeFadeWidth),
            bottomStripDragMinimumDistance: try values.decode(Double.self, forKey: .bottomStripDragMinimumDistance),
            bottomStripSwitchDistance: try values.decode(Double.self, forKey: .bottomStripSwitchDistance)
        )
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(pinchMaxScale, forKey: .pinchMaxScale)
        try values.encode(zoomSnapBackThreshold, forKey: .zoomSnapBackThreshold)
        try values.encode(minDoubleTapScale, forKey: .minDoubleTapScale)
        try values.encode(doubleTapAnchorStrategy, forKey: .doubleTapAnchorStrategy)
        try values.encode(edgePagingTriggerDistance, forKey: .edgePagingTriggerDistance)
        try values.encode(edgePagingTriggerVelocity, forKey: .edgePagingTriggerVelocity)
        try values.encode(verticalSwipeDistance, forKey: .verticalSwipeDistance)
        try values.encode(verticalSwipeVelocity, forKey: .verticalSwipeVelocity)
        try values.encode(verticalSwipeMaximumDurationMilliseconds, forKey: .verticalSwipeMaximumDurationMilliseconds)
        try values.encode(horizontalSwipeDistance, forKey: .horizontalSwipeDistance)
        try values.encode(horizontalSwipeVelocity, forKey: .horizontalSwipeVelocity)
        try values.encode(horizontalSwipeMaximumDurationMilliseconds, forKey: .horizontalSwipeMaximumDurationMilliseconds)
        try values.encode(pinchMinimumScaleDelta, forKey: .pinchMinimumScaleDelta)
        try values.encode(pinchMinimumVelocityPerSecond, forKey: .pinchMinimumVelocityPerSecond)
        try values.encode(pinchMaximumDurationMilliseconds, forKey: .pinchMaximumDurationMilliseconds)
        try values.encode(mainDragMinimumDistance, forKey: .mainDragMinimumDistance)
        try values.encode(mainDragMinimumVelocity, forKey: .mainDragMinimumVelocity)
        try values.encode(mainDragMaximumDurationMilliseconds, forKey: .mainDragMaximumDurationMilliseconds)
        try values.encode(singleTapMaximumMovement, forKey: .singleTapMaximumMovement)
        try values.encode(singleTapMaximumDurationMilliseconds, forKey: .singleTapMaximumDurationMilliseconds)
        try values.encode(doubleTapDecisionWindowMilliseconds, forKey: .doubleTapDecisionWindowMilliseconds)
        try values.encode(singleTapTouchCount, forKey: .singleTapTouchCount)
        try values.encode(doubleTapTouchCount, forKey: .doubleTapTouchCount)
        try values.encode(singleDragTouchCount, forKey: .singleDragTouchCount)
        try values.encode(pinchTouchCount, forKey: .pinchTouchCount)
        try values.encode(gestureExclusivityPolicy, forKey: .gestureExclusivityPolicy)
        try values.encode(scaleChangeRequestPolicy, forKey: .scaleChangeRequestPolicy)
        try values.encode(degradedPreviewPolicy, forKey: .degradedPreviewPolicy)
        try values.encode(animationsEnabled, forKey: .animationsEnabled)
        try values.encode(animationDurationMilliseconds, forKey: .animationDurationMilliseconds)
        try values.encode(fitInsetRatio, forKey: .fitInsetRatio)
        try values.encode(fitCornerRadius, forKey: .fitCornerRadius)
        try values.encode(fitInsetScope, forKey: .fitInsetScope)
        try values.encode(screenshotImmersiveOnHide, forKey: .screenshotImmersiveOnHide)
        try values.encode(pageSpacing, forKey: .pageSpacing)
        try values.encode(hapticOnPhotoSwitch, forKey: .hapticOnPhotoSwitch)
        try values.encode(bottomStripCurrentItemSize, forKey: .bottomStripCurrentItemSize)
        try values.encode(bottomStripNeighborItemWidth, forKey: .bottomStripNeighborItemWidth)
        try values.encode(bottomStripNeighborItemHeight, forKey: .bottomStripNeighborItemHeight)
        try values.encode(bottomStripItemSpacing, forKey: .bottomStripItemSpacing)
        try values.encode(bottomStripEdgeFadeWidth, forKey: .bottomStripEdgeFadeWidth)
        try values.encode(bottomStripDragMinimumDistance, forKey: .bottomStripDragMinimumDistance)
        try values.encode(bottomStripSwitchDistance, forKey: .bottomStripSwitchDistance)
    }
}

struct S2AnimationPolicy: Equatable {
    let animationsEnabled: Bool
    let durationMilliseconds: Double

    init(configuration: S2CalibrationConfiguration) {
        animationsEnabled = configuration.animationsEnabled
        durationMilliseconds = configuration.animationDurationMilliseconds
    }

    var shouldAnimate: Bool {
        animationsEnabled && durationMilliseconds > 0
    }

    var durationSeconds: TimeInterval {
        shouldAnimate ? durationMilliseconds / 1_000 : 0
    }
}

struct S2StatusBarAppearance: Equatable {
    let isHidden: Bool
    let transitionDuration: TimeInterval

    init(
        interfaceVisibility: S2InterfaceVisibility,
        configuration: S2CalibrationConfiguration
    ) {
        isHidden = interfaceVisibility == .hidden
        transitionDuration = S2AnimationPolicy(
            configuration: configuration
        ).durationSeconds
    }
}

struct S2TapDecisionReading: Equatable {
    let latencyMilliseconds: Double
    let targetMilliseconds: Double
    let metConfiguredTarget: Bool
}

struct S2TapDecisionDiagnosticPolicy: Equatable {
    let targetMilliseconds: Double

    init(configuration: S2CalibrationConfiguration) {
        targetMilliseconds = max(
            0,
            configuration.doubleTapDecisionWindowMilliseconds
        )
    }

    func reading(latencyMilliseconds: Double) -> S2TapDecisionReading {
        let latency = max(0, latencyMilliseconds)
        return S2TapDecisionReading(
            latencyMilliseconds: latency,
            targetMilliseconds: targetMilliseconds,
            metConfiguredTarget: latency <= targetMilliseconds
        )
    }
}

protocol S2CalibrationPersisting {
    func load() throws -> Data?
    func save(_ data: Data) throws
}

struct S2KeychainCalibrationPersistence: S2CalibrationPersisting {
    private let service = "com.iphonephotomanagement.PhotoCleanupMVE.s2-calibration"
    private let account = "current-parameters"

    func load() throws -> Data? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw S2CalibrationPersistenceError.keychain(status)
        }
        return result as? Data
    }

    func save(_ data: Data) throws {
        let updateStatus = SecItemUpdate(
            baseQuery as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )
        if updateStatus == errSecSuccess {
            return
        }
        guard updateStatus == errSecItemNotFound else {
            throw S2CalibrationPersistenceError.keychain(updateStatus)
        }

        var insertion = baseQuery
        insertion[kSecValueData as String] = data
        insertion[kSecAttrAccessible as String] =
            kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let insertionStatus = SecItemAdd(insertion as CFDictionary, nil)
        guard insertionStatus == errSecSuccess else {
            throw S2CalibrationPersistenceError.keychain(insertionStatus)
        }
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

struct S2DiscardingCalibrationPersistence: S2CalibrationPersisting {
    func load() throws -> Data? {
        nil
    }

    func save(_ data: Data) throws {}
}

enum S2CalibrationPersistenceError: Error {
    case keychain(OSStatus)
}

final class S2CalibrationModel: ObservableObject {
    @Published private(set) var configuration: S2CalibrationConfiguration
    @Published private(set) var persistenceFailed = false

    private let persistence: any S2CalibrationPersisting

    init(
        persistence: any S2CalibrationPersisting =
            S2KeychainCalibrationPersistence()
    ) {
        self.persistence = persistence
        if let data = try? persistence.load(),
           let decoded = try? JSONDecoder().decode(
               S2CalibrationConfiguration.self,
               from: data
           ),
           decoded.isValid {
            configuration = decoded
        } else {
            configuration = .factoryPlaceholder
        }
    }

    @discardableResult
    func update(
        _ mutation: (inout S2CalibrationConfiguration) -> Void
    ) -> Bool {
        var next = configuration
        mutation(&next)
        guard next.isValid else {
            return false
        }
        configuration = next
        persist()
        return true
    }

    func restoreFactoryPlaceholder() {
        configuration = .factoryPlaceholder
        persist()
    }

    func exportText() -> String {
        configuration.exportText()
    }

    private func persist() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            try persistence.save(encoder.encode(configuration))
            persistenceFailed = false
        } catch {
            persistenceFailed = true
        }
    }
}

struct S2OverlaySafeAreaInsets: Equatable {
    let top: CGFloat
    let leading: CGFloat
    let bottom: CGFloat
    let trailing: CGFloat

    static let zero = S2OverlaySafeAreaInsets(
        top: 0,
        leading: 0,
        bottom: 0,
        trailing: 0
    )
}

struct S2CalibrationOverlayState: Equatable {
    var controlsVisible: Bool
    var parameterPanelVisible: Bool
    var readingsVisible: Bool

    static let initial = S2CalibrationOverlayState(
        controlsVisible: false,
        parameterPanelVisible: false,
        readingsVisible: false
    )

    mutating func toggleAccessControls() {
        if controlsVisible {
            self = .initial
        } else {
            controlsVisible = true
        }
    }

    mutating func toggleParameterPanel() {
        guard controlsVisible else {
            return
        }
        parameterPanelVisible.toggle()
        if parameterPanelVisible {
            readingsVisible = false
        }
    }

    mutating func toggleReadings() {
        guard controlsVisible else {
            return
        }
        readingsVisible.toggle()
        if readingsVisible {
            parameterPanelVisible = false
        }
    }
}

struct S2OverlayLayoutSnapshot: Equatable {
    let viewportFrame: CGRect
    let topElementFrames: [CGRect]
    let bottomElementFrames: [CGRect]
    let clickableControlFrames: [CGRect]
    let calibrationEntryFrame: CGRect?
}

enum S2OverlayLayout {
    static let minimumTouchTarget: CGFloat = 44
    static let minimumSpacing: CGFloat = 8
    static let horizontalPadding: CGFloat = 8
    static let topBarHeight: CGFloat = 48
    static let topLeadingControlWidth: CGFloat = 88
    static let topTextLineHeight: CGFloat = 22
    static let calibrationTopClearance: CGFloat = 108

    static func snapshot(
        physicalSize: CGSize,
        safeAreaInsets: S2OverlaySafeAreaInsets,
        bottomStripHeight: CGFloat,
        showsRecentAlbumAction: Bool,
        calibrationState: S2CalibrationOverlayState
    ) -> S2OverlayLayoutSnapshot {
        let viewportFrame = CGRect(origin: .zero, size: physicalSize)
        let safeFrame = CGRect(
            x: safeAreaInsets.leading,
            y: safeAreaInsets.top,
            width: max(
                0,
                physicalSize.width - safeAreaInsets.leading -
                    safeAreaInsets.trailing
            ),
            height: max(
                0,
                physicalSize.height - safeAreaInsets.top -
                    safeAreaInsets.bottom
            )
        )
        let topBounds = CGRect(
            x: safeFrame.minX,
            y: safeFrame.minY,
            width: safeFrame.width,
            height: topBarHeight
        )
        let topFrames = topElementFrames(in: topBounds)

        let stripHeight = max(minimumTouchTarget, bottomStripHeight)
        let stripFrame = CGRect(
            x: safeFrame.minX,
            y: safeFrame.maxY - stripHeight,
            width: safeFrame.width,
            height: stripHeight
        )
        let actionCount = showsRecentAlbumAction ? 3 : 2
        let actionContentWidth = max(
            0,
            safeFrame.width - 2 * horizontalPadding
        )
        let actionWidth = max(
            minimumTouchTarget,
            (actionContentWidth -
                CGFloat(actionCount - 1) * minimumSpacing) /
                CGFloat(actionCount)
        )
        let actionY = stripFrame.minY - minimumSpacing - minimumTouchTarget
        let actionFrames = (0..<actionCount).map { index in
            CGRect(
                x: safeFrame.minX + horizontalPadding +
                    CGFloat(index) * (actionWidth + minimumSpacing),
                y: actionY,
                width: actionWidth,
                height: minimumTouchTarget
            )
        }
        let bottomFrames = actionFrames + [stripFrame]

        var clickableFrames = [topFrames[0], topFrames[3]] +
            actionFrames + [stripFrame]
        if calibrationState.controlsVisible {
            let secondX = safeFrame.maxX - horizontalPadding -
                minimumTouchTarget
            let firstX = secondX - minimumSpacing - minimumTouchTarget
            let controlY = safeFrame.minY + calibrationTopClearance
            clickableFrames.append(contentsOf: [
                CGRect(
                    x: firstX,
                    y: controlY,
                    width: minimumTouchTarget,
                    height: minimumTouchTarget
                ),
                CGRect(
                    x: secondX,
                    y: controlY,
                    width: minimumTouchTarget,
                    height: minimumTouchTarget
                )
            ])
        }

        return S2OverlayLayoutSnapshot(
            viewportFrame: viewportFrame,
            topElementFrames: topFrames,
            bottomElementFrames: bottomFrames,
            clickableControlFrames: clickableFrames,
            calibrationEntryFrame: nil
        )
    }

    static func topElementFrames(in bounds: CGRect) -> [CGRect] {
        let controlY = bounds.minY +
            (topBarHeight - minimumTouchTarget) / 2
        let leadingFrame = CGRect(
            x: bounds.minX + horizontalPadding,
            y: controlY,
            width: topLeadingControlWidth,
            height: minimumTouchTarget
        )
        let trailingFrame = CGRect(
            x: bounds.maxX - horizontalPadding - minimumTouchTarget,
            y: controlY,
            width: minimumTouchTarget,
            height: minimumTouchTarget
        )
        let textX = leadingFrame.maxX + minimumSpacing
        let textWidth = max(
            0,
            trailingFrame.minX - minimumSpacing - textX
        )
        let rangeFrame = CGRect(
            x: textX,
            y: bounds.minY,
            width: textWidth,
            height: topTextLineHeight
        )
        let statusFrame = CGRect(
            x: textX,
            y: rangeFrame.maxY + 4,
            width: textWidth,
            height: topTextLineHeight
        )
        return [leadingFrame, rangeFrame, statusFrame, trailingFrame]
    }
}

struct S2ViewportPresentationState: Equatable {
    let interfaceVisibility: S2InterfaceVisibility
    let bottomStripState: S2BottomStripState
    let sheetState: S2SheetState
    let calibrationState: S2CalibrationOverlayState

    init(
        interfaceVisibility: S2InterfaceVisibility,
        bottomStripState: S2BottomStripState,
        sheetState: S2SheetState,
        calibrationState: S2CalibrationOverlayState = .initial
    ) {
        self.interfaceVisibility = interfaceVisibility
        self.bottomStripState = bottomStripState
        self.sheetState = sheetState
        self.calibrationState = calibrationState
    }
}

struct S2ViewportMetrics: Equatable {
    let viewportSize: CGSize
    let assetAspectRatio: CGFloat
    let viewportAspectRatio: CGFloat
    let aspectFitSize: CGSize
    let nativeZoomBaseSize: CGSize
    let isFramedPhoto: Bool
    let oneXDisplaySize: CGSize
    let oneXCornerRadius: CGFloat
    let aspectFillMultiplier: CGFloat
    let doubleTapTargetScale: CGFloat
    let bottomStripHeight: CGFloat
}

enum S2ViewportLayout {
    static func metrics(
        physicalSize: CGSize,
        presentationState: S2ViewportPresentationState,
        assetAspectRatio: CGFloat,
        configuration: S2CalibrationConfiguration
    ) -> S2ViewportMetrics {
        let viewportAspectRatio = physicalSize.height > 0
            ? physicalSize.width / physicalSize.height
            : 0
        let fitSize = S2Geometry.aspectFitSize(
            viewportSize: physicalSize,
            assetAspectRatio: assetAspectRatio
        )
        let applies = insetApplies(
            assetAspectRatio: assetAspectRatio,
            viewportAspectRatio: viewportAspectRatio,
            scope: configuration.fitInsetScope
        )
        let fillsViewport = applies &&
            presentationState.interfaceVisibility == .hidden &&
                configuration.screenshotImmersiveOnHide
        let keepsFrame = applies && !fillsViewport
        let insetScale = keepsFrame
            ? max(0, 1 - CGFloat(configuration.fitInsetRatio))
            : 1
        let displaySize = fillsViewport
            ? physicalSize
            : CGSize(
                width: fitSize.width * insetScale,
                height: fitSize.height * insetScale
            )
        let fillMultiplier = S2Geometry.aspectFillMultiplier(
            viewportSize: physicalSize,
            assetAspectRatio: assetAspectRatio
        ) ?? 1
        return S2ViewportMetrics(
            viewportSize: physicalSize,
            assetAspectRatio: assetAspectRatio,
            viewportAspectRatio: viewportAspectRatio,
            aspectFitSize: fitSize,
            nativeZoomBaseSize: applies ? physicalSize : fitSize,
            isFramedPhoto: applies,
            oneXDisplaySize: displaySize,
            oneXCornerRadius: keepsFrame
                ? CGFloat(configuration.fitCornerRadius)
                : 0,
            aspectFillMultiplier: fillMultiplier,
            doubleTapTargetScale: applies
                ? CGFloat(configuration.minDoubleTapScale)
                : fillMultiplier,
            bottomStripHeight: max(
                CGFloat(configuration.bottomStripCurrentItemSize),
                CGFloat(configuration.bottomStripNeighborItemHeight)
            )
        )
    }

    static func insetApplies(
        assetAspectRatio: CGFloat,
        viewportAspectRatio: CGFloat,
        scope: S2FitInsetScope
    ) -> Bool {
        switch scope {
        case .allPhotos:
            return true
        case .screenAspectOnly:
            return S2Geometry.isScreenAspectMatch(
                assetAspectRatio: assetAspectRatio,
                viewportAspectRatio: viewportAspectRatio
            )
        }
    }
}

enum S2AssetAspectCategory: String, CaseIterable, Codable, Equatable {
    case screenAspect
    case portrait
    case landscape
    case square
    case extreme

    func matches(
        assetAspectRatio: CGFloat,
        viewportAspectRatio: CGFloat
    ) -> Bool {
        guard assetAspectRatio > 0, viewportAspectRatio > 0 else {
            return false
        }
        let screenDifference = abs(assetAspectRatio - viewportAspectRatio) /
            viewportAspectRatio
        switch self {
        case .screenAspect:
            return screenDifference <= 0.01
        case .portrait:
            return assetAspectRatio < 1 && screenDifference > 0.01
        case .landscape:
            return assetAspectRatio > 1
        case .square:
            return abs(assetAspectRatio - 1) <= 0.01
        case .extreme:
            return max(assetAspectRatio, 1 / assetAspectRatio) >= 2.5
        }
    }
}

enum S2AssetNavigationResult: Equatable {
    case found(index: Int, assetID: String)
    case empty
}

enum S2AssetAspectNavigator {
    static func next(
        in orderedAssetIDs: [String],
        after currentIndex: Int,
        category: S2AssetAspectCategory,
        viewportAspectRatio: CGFloat,
        assetAspectRatio: (String) -> CGFloat
    ) -> S2AssetNavigationResult {
        guard !orderedAssetIDs.isEmpty,
              orderedAssetIDs.indices.contains(currentIndex) else {
            return .empty
        }
        for distance in 1...orderedAssetIDs.count {
            let index = (currentIndex + distance) % orderedAssetIDs.count
            let assetID = orderedAssetIDs[index]
            if category.matches(
                assetAspectRatio: assetAspectRatio(assetID),
                viewportAspectRatio: viewportAspectRatio
            ) {
                return .found(index: index, assetID: assetID)
            }
        }
        return .empty
    }
}

struct S2GestureReading: Equatable {
    let displacementDistance: CGFloat
    let peakVelocity: CGFloat
    let duration: TimeInterval
}

enum S2ImageRequestTrigger: String, Equatable {
    case initial
    case assetChange
    case viewportChange
    case scaleChange
    case pinchEnded
    case strategyChange
}

enum S2ImageReturnType: String, Equatable {
    case pending
    case degradedPreview
    case finalImage
    case failure
}

struct S2ImageRequestReading: Equatable {
    let trigger: S2ImageRequestTrigger
    let returnType: S2ImageReturnType
}

enum S2ImageRequestDecision {
    static func shouldRequest(
        for trigger: S2ImageRequestTrigger,
        strategy: S2ImageRequestStrategy
    ) -> Bool {
        switch trigger {
        case .scaleChange:
            return strategy.scaleChangePolicy == .everyScaleChange
        case .pinchEnded:
            return strategy.scaleChangePolicy == .pinchEnded
        case .initial, .assetChange, .viewportChange, .strategyChange:
            return true
        }
    }

    static func shouldDisplay(
        isDegraded: Bool,
        strategy: S2ImageRequestStrategy
    ) -> Bool {
        !isDegraded || strategy.degradedPreviewPolicy == .display
    }
}
