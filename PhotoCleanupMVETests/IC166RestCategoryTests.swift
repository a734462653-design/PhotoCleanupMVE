import CryptoKit
import Foundation
import XCTest
@testable import PhotoCleanupMVE

/// IC-166：「其余照片」升为可进入类别 `rest`、`LIB` 排除待删篮与账本、S0-3 判据改「无成员」、空态副句
/// （SPEC-S0 v3 实装第二张）。
///
/// 依据 SPEC-S0 v3（SHA-256 `F52F…83F6`）第二节第 2 部分（`LIB`／`N_成员`／`CAT`／归属去重／总条段与
/// 扫描中按张数进度缩放）、第三节 S0-2／S0-3，与任务卡 IC-20260923-166 的五条裁定。断言编号与任务卡
/// 子项 C 一一对应：1～4 钉数据层（子项 A），5～6 钉卡片叠层（子项 B）。
///
/// **夹具驱动，真机未覆盖**（陷阱 1）：聚合器与模型用真实类型直接构造，源码扫描口径同 IC-165——文案 key
/// 一律扫原文，其余扫剔过注释与字符串内容的源码。首页观感、总条随扫描变宽、空态副句只有 H85 能判。
final class IC166RestCategoryTests: XCTestCase {

    // MARK: - 断言 1：`LIB` 排除待删篮与账本，且等于各类别字节和（裁定 一、二）

    func testIC166A_LibraryExcludesPendingAndLedgerAndSumsToCategories() {
        let megabyte: Int64 = 1_000_000
        let snapshot = S0ScanAggregator.snapshot(
            of: libraryFixture(),
            context: aggregationContext(pending: ["pending-photo"], ledger: ["ledger-video"])
        )

        // 三类各一 + 两张普通照片：150 + 30 + 3 + 4 + 5。待删篮的 2 MB、账本的 200 MB、未解析的一律不计。
        XCTAssertEqual(snapshot.libraryTotalByteCount, 192 * megabyte)
        XCTAssertEqual(snapshot.cleanableByteCount, snapshot.libraryTotalByteCount)
        XCTAssertEqual(
            snapshot.categories.map(\.candidateByteCount).reduce(0, +),
            snapshot.libraryTotalByteCount
        )
        XCTAssertEqual(
            snapshot.cleanableAssetCount,
            snapshot.categories.map(\.candidateCount).reduce(0, +)
        )
        XCTAssertEqual(snapshot.cleanableAssetCount, 5)
        // 待删篮体积口径不变：仍计入篮内的已解析资产。
        XCTAssertEqual(snapshot.pendingDeletionByteCount, 2 * megabyte)
        XCTAssertEqual(
            snapshot.categories.map(\.id),
            [.bigVideo, .screenRecording, .screenshot, .rest]
        )
        // 「其余照片」= 两张普通照片（篮内那张不在）。
        let rest = snapshot.categories.first { $0.id == .rest }
        XCTAssertEqual(rest?.candidateCount, 2)
        XCTAssertEqual(rest?.candidateByteCount, 9 * megabyte)

        // 正对照：两个排除集清空后，篮内照片回到「其余照片」、账本视频回到「视频」，`LIB` 随之变大。
        let unfiltered = S0ScanAggregator.snapshot(
            of: libraryFixture(),
            context: aggregationContext(pending: [], ledger: [])
        )
        XCTAssertEqual(unfiltered.libraryTotalByteCount, 394 * megabyte)
        XCTAssertEqual(unfiltered.cleanableAssetCount, 7)
        XCTAssertEqual(
            unfiltered.categories.map(\.candidateByteCount).reduce(0, +),
            unfiltered.libraryTotalByteCount
        )
    }

    // MARK: - 断言 2：`rest` 是「无命中的归属」，各类别两两不交（裁定 一）

    func testIC166A_RestIsAttributionOfNoHitAndCategoriesArePairwiseDisjoint() {
        XCTAssertEqual(S0ScanClassifier.attributedCategory(for: []), .rest)
        XCTAssertEqual(S0ScanClassifier.attributedCategory(for: [.screenshot]), .screenshot)
        XCTAssertEqual(
            S0ScanClassifier.attributedCategory(for: [.screenshot, .screenRecording]),
            .screenRecording
        )
        // 优先序原值不动（顺序断言），快照顺序 = 优先序 + 「其余照片」。
        XCTAssertEqual(
            S0ScanClassifier.attributionPriority,
            [.bigVideo, .screenRecording, .screenshot]
        )
        XCTAssertEqual(
            S0ScanClassifier.snapshotOrder,
            S0ScanClassifier.attributionPriority + [.rest]
        )
        // 命中集合从不产出 `rest`：普通照片的命中为空。
        let plain = S0ScanClassifier.classified(
            scannedAsset("plain", mediaType: .photo, byteCount: 1_000)
        )
        XCTAssertEqual(plain.hits, Set<S0CategoryIdentifier>())

        // 数据源侧：桩就绪剧本逐类取列表，任两类不交，并集恰为成员总数（集合运算一律 `Set`，惯例 45）。
        let stub = S0CleanupDataStub(scenario: .readyWithItems)
        let snapshot = stub.currentSnapshot()
        var lists: [S0CategoryIdentifier: Set<String>] = [:]
        for identifier in S0CategoryIdentifier.allCases {
            lists[identifier] = Set(stub.categoryAssets(identifier).map(\.id))
        }
        for lhs in S0CategoryIdentifier.allCases {
            for rhs in S0CategoryIdentifier.allCases where lhs != rhs {
                XCTAssertTrue(
                    lists[lhs, default: []].isDisjoint(with: lists[rhs, default: []]),
                    lhs.rawValue + " 与 " + rhs.rawValue + " 相交"
                )
            }
        }
        var union: Set<String> = []
        for identifier in S0CategoryIdentifier.allCases {
            union.formUnion(lists[identifier, default: []])
        }
        XCTAssertEqual(union.count, snapshot.cleanableAssetCount)
        XCTAssertGreaterThan(lists[.rest, default: []].count, 0)
    }

    // MARK: - 断言 3：「其余照片」封面同口径、扫描完成后恒垫底（裁定 一）

    func testIC166A_RestCoverIsLargestAndRestSinksToBottom() {
        let megabyte: Int64 = 1_000_000
        // 两张 6 MB 普通照片并列（先 b 后 a），另有一张更大的截图——它不属「其余照片」。
        let fixture = [
            scannedAsset("plain-b", mediaType: .photo, byteCount: 6 * megabyte),
            scannedAsset("plain-small", mediaType: .photo, byteCount: 1 * megabyte),
            scannedAsset(
                "shot-big",
                mediaType: .photo,
                isScreenshot: true,
                pixelWidth: 1_206,
                pixelHeight: 2_622,
                byteCount: 7 * megabyte
            ),
            scannedAsset("plain-a", mediaType: .photo, byteCount: 6 * megabyte)
        ].map { S0ScanClassifier.classified($0) }
        let context = aggregationContext(pending: [], ledger: [])
        for order in [fixture, Array(fixture.reversed())] {
            let rest = S0ScanAggregator.snapshot(of: order, context: context)
                .categories.first { $0.id == .rest }
            XCTAssertEqual(rest?.coverAssetID, "plain-a")
            XCTAssertEqual(rest?.candidateCount, 3)
        }
        // 并列的首选进了待删篮：封面换成并列的另一条。
        let withPending = S0ScanAggregator.snapshot(
            of: fixture,
            context: aggregationContext(pending: ["plain-a"], ledger: [])
        )
        XCTAssertEqual(
            withPending.categories.first { $0.id == .rest }?.coverAssetID,
            "plain-b"
        )

        // 状态机：照 IC-147 断言 8 的序列。「其余照片」字节最大且最先到达；另有一个无项目的类别。
        let machine = S0StateMachine()
        machine.handle(.applicationOpened)
        machine.ingest(orderSnapshot(recognition: .counting))
        XCTAssertEqual(
            machine.orderedCategoryIDs,
            [.rest, .screenshot, .bigVideo, .screenRecording, .duplicate]
        )
        machine.ingest(orderSnapshot(recognition: .settled))
        XCTAssertEqual(machine.categoryReorderCount, 0, "扫描中发生了重排")
        machine.handle(.scanCompleted)
        XCTAssertEqual(machine.categoryReorderCount, 1)
        XCTAssertEqual(machine.orderedCategories.last?.id, .rest)
        // 其余按 `c.bytes` 降序，无项目的沉底，「其余照片」垫在它之下。
        XCTAssertEqual(
            machine.orderedCategoryIDs,
            [.bigVideo, .screenRecording, .screenshot, .duplicate, .rest]
        )
        let others = machine.orderedCategories.dropLast().filter(\.hasItems)
            .map(\.candidateByteCount)
        XCTAssertEqual(others, others.sorted(by: >))
    }

    // MARK: - 断言 4：S0-3 判据 = `N_成员 = 0`，桩守 `N_成员 = 0 ⟺ LIB = 0`（裁定 三）

    func testIC166A_EmptyStateFollowsMemberCount() {
        // 正对照：判据式不变。
        XCTAssertEqual(
            S0StateResolver.state(
                for: S0StateInput(scanState: .completed, cleanableAssetCount: 0, failureCategory: nil)
            ),
            .empty
        )
        XCTAssertEqual(
            S0StateResolver.state(
                for: S0StateInput(scanState: .completed, cleanableAssetCount: 1, failureCategory: nil)
            ),
            .ready
        )

        let emptyStub = S0CleanupDataStub(scenario: .readyWithoutItems).currentSnapshot()
        XCTAssertEqual(emptyStub.libraryTotalByteCount, 0)
        XCTAssertEqual(emptyStub.cleanableAssetCount, 0)
        let readyStub = S0CleanupDataStub(scenario: .readyWithItems).currentSnapshot()
        XCTAssertTrue(readyStub.categories.contains { $0.id == .rest && $0.hasItems })
        XCTAssertEqual(
            readyStub.categories.map(\.candidateByteCount).reduce(0, +),
            readyStub.libraryTotalByteCount
        )
        XCTAssertEqual(
            readyStub.categories.map(\.candidateCount).reduce(0, +),
            readyStub.cleanableAssetCount
        )

        // 只有普通照片的库：旧口径下成员数为 0、落 S0-3；v3 下它们是「其余照片」，落 S0-2。
        let plainOnly = S0ScanAggregator.snapshot(
            of: [
                scannedAsset("plain-1", mediaType: .photo, byteCount: 1_000),
                scannedAsset("plain-2", mediaType: .photo, byteCount: 2_000)
            ].map { S0ScanClassifier.classified($0) },
            context: aggregationContext(pending: [], ledger: [])
        )
        XCTAssertEqual(settledMachine(ingesting: plainOnly).state, .ready)

        // 全库已在待删篮：成员数与 `LIB` 同时为零，落 S0-3。
        let allPending = S0ScanAggregator.snapshot(
            of: libraryFixture(),
            context: aggregationContext(
                pending: Set(libraryFixture().map(\.id)),
                ledger: []
            )
        )
        XCTAssertEqual(allPending.cleanableAssetCount, 0)
        XCTAssertEqual(allPending.libraryTotalByteCount, 0)
        XCTAssertGreaterThan(allPending.pendingDeletionByteCount, 0)
        XCTAssertEqual(settledMachine(ingesting: allPending).state, .empty)
    }

    // MARK: - 断言 5：卡片叠与总条把「其余照片」当普通类别（裁定 四、五）

    func testIC166B_DeckCardsTreatRestAsOrdinaryCategory() {
        let snapshot = S0ScanAggregator.snapshot(
            of: libraryFixture(),
            context: aggregationContext(pending: ["pending-photo"], ledger: ["ledger-video"])
        )
        let library = snapshot.libraryTotalByteCount
        XCTAssertGreaterThan(library, 0)

        let cards = S0DeckHomeModel.cards(
            categories: snapshot.categories,
            libraryTotalByteCount: library
        )
        XCTAssertEqual(cards.count, 4)
        XCTAssertEqual(cards.last?.id, "rest")
        XCTAssertEqual(cards.last?.category, .rest)
        XCTAssertEqual(cards.last?.isEnterable, true)
        XCTAssertEqual(cards.map(\.fraction).reduce(0, +), 1, accuracy: 1e-9)

        // 就绪（p = 1）：四个类别段，没有兜底段、没有未扫段，宽之和为 1。
        let settledBar = S0SegmentBarModel.make(
            categories: snapshot.categories,
            ledgerEntries: [],
            libraryTotalByteCount: library,
            progress: S0ScanProgress(scannedAssetCount: 10, totalAssetCount: 10),
            isScanning: false
        )
        XCTAssertEqual(
            settledBar.segments.map(\.kind),
            [
                .category(.bigVideo),
                .category(.screenRecording),
                .category(.screenshot),
                .category(.rest)
            ]
        )
        XCTAssertFalse(settledBar.segments.contains { $0.kind == .rest })
        XCTAssertFalse(settledBar.segments.contains { $0.kind == .unscanned })
        XCTAssertEqual(settledBar.totalWidthFraction, 1, accuracy: 1e-9)

        // 扫描中（p = 0.3）：各类别段 = 占比 × 0.3，末段未扫 0.7，和为 1。
        let scanningBar = S0SegmentBarModel.make(
            categories: snapshot.categories,
            ledgerEntries: [],
            libraryTotalByteCount: library,
            progress: S0ScanProgress(scannedAssetCount: 3, totalAssetCount: 10),
            isScanning: true
        )
        XCTAssertEqual(scanningBar.segments.count, snapshot.categories.count + 1)
        for (segment, category) in zip(scanningBar.segments, snapshot.categories) {
            XCTAssertEqual(segment.kind, .category(category.id))
            XCTAssertEqual(
                segment.widthFraction,
                Double(category.candidateByteCount) / Double(library) * 0.3,
                accuracy: 1e-9
            )
        }
        XCTAssertEqual(scanningBar.segments.last?.kind, .unscanned)
        XCTAssertEqual(scanningBar.segments.last?.widthFraction ?? 0, 0.7, accuracy: 1e-9)
        XCTAssertEqual(scanningBar.totalWidthFraction, 1, accuracy: 1e-9)

        // 正对照：`LIB ≤ 0` 时恰一段兜底段。
        let noLibrary = S0SegmentBarModel.make(
            categories: snapshot.categories,
            ledgerEntries: [],
            libraryTotalByteCount: 0,
            progress: S0ScanProgress(),
            isScanning: false
        )
        XCTAssertEqual(noLibrary.segments.map(\.kind), [.rest])
        XCTAssertEqual(noLibrary.totalWidthFraction, 1, accuracy: 1e-9)
    }

    // MARK: - 断言 6：源码纪律（裁定 一～五；源码扫描，真机未覆盖）

    func testIC166B_SourceDiscipline() throws {
        let model = try XCTUnwrap(strippedSource(Self.modelPath))
        XCTAssertEqual(occurrences(of: "restCardID", in: model), 0)
        XCTAssertEqual(occurrences(of: "S0CategoryIdentifier?", in: model), 0)
        XCTAssertEqual(occurrences(of: "restByteCount", in: model), 0)

        let home = try XCTUnwrap(strippedSource(Self.homePath))
        XCTAssertEqual(occurrences(of: "guard let identifier = card.category", in: home), 0)
        XCTAssertEqual(occurrences(of: "cardColor(", in: home), 0)
        XCTAssertEqual(occurrences(of: "private func centeredBlock(", in: home), 1)
        XCTAssertEqual(occurrences(of: "restCardID", in: home), 0)
        XCTAssertGreaterThanOrEqual(occurrences(of: "categoryColor(for:", in: home), 2)
        // 空态副句取既有进度字段（裁定 三）：四态分派段内恰一处。
        let dispatch = try XCTUnwrap(
            slice(
                home,
                from: "private var content: some View {",
                to: Self.newline + "    }" + Self.newline
            ),
            "首页四态分派 `content` 没切到"
        )
        XCTAssertEqual(occurrences(of: "progress.scannedAssetCount", in: dispatch), 1)
        let homeRaw = try XCTUnwrap(sourceText(Self.homePath))
        XCTAssertEqual(occurrences(of: "s0.home.hero.empty.subtitle", in: homeRaw), 1)
        XCTAssertEqual(occurrences(of: "s0.category.rest", in: homeRaw), 0)

        let textRaw = try XCTUnwrap(sourceText(Self.textPath))
        XCTAssertEqual(occurrences(of: "s0.category.rest", in: textRaw), 1)
        let text = try XCTUnwrap(strippedSource(Self.textPath))
        XCTAssertEqual(occurrences(of: "case .rest:", in: text), 1)

        let metrics = try XCTUnwrap(strippedSource(Self.metricsPath))
        XCTAssertEqual(occurrences(of: "case .rest:", in: metrics), 1)
        XCTAssertEqual(occurrences(of: "func cardColor", in: metrics), 0)
        let registry = try XCTUnwrap(
            slice(metrics, from: "enum S0DeckMetrics {", to: Self.topLevelClose),
            "登记表切片没切到"
        )
        XCTAssertEqual(occurrences(of: Self.newline + "    static let ", in: registry), 198)

        let segment = try XCTUnwrap(strippedSource(Self.segmentPath))
        XCTAssertEqual(occurrences(of: "kind: .rest", in: segment), 1)
        XCTAssertEqual(occurrences(of: "restByteCount", in: segment), 0)
        XCTAssertEqual(occurrences(of: "budget", in: segment), 0)

        let classifier = try XCTUnwrap(strippedSource(Self.classifierPath))
        XCTAssertEqual(occurrences(of: "func attributedCategory", in: classifier), 1)
        XCTAssertGreaterThanOrEqual(occurrences(of: "snapshotOrder", in: classifier), 2)
        XCTAssertEqual(occurrences(of: "attributionPriority.first", in: classifier), 1)
        let allowed: Set<String> = ["0", "1"]
        let literals = numericLiterals(in: classifier)
        XCTAssertTrue(
            literals.isSubset(of: allowed),
            "分类与聚合代码出现了裸数：" + literals.subtracting(allowed).sorted().joined(separator: ",")
        )

        let service = try XCTUnwrap(strippedSource(Self.servicePath))
        XCTAssertEqual(occurrences(of: "hits.contains(", in: service), 0)
        XCTAssertEqual(occurrences(of: "attributedCategory(", in: service), 1)

        // 协议文件与 `6bc51be` 逐字节相同（git blob 标识相同）；App 入口的 blob 钉自 IC-167 起按惯例 46 撤下。
        XCTAssertEqual(
            try gitBlobID(Self.providerPath),
            "b9e4a57c3133bf189ed3db21b1ff995547faa40f"
        )

        let catalog = try loadCatalogValues()
        // IC-168 E：类别页进入失败提示一条，`s0.` 40 → 41。
        XCTAssertEqual(catalog.keys.filter { $0.hasPrefix("s0.") }.count, 41)
        XCTAssertEqual(catalog["s0.home.hero.empty.subtitle"], "已扫描 {count} 项")
        XCTAssertEqual(catalog["s0.category.rest"], "其余照片")
    }

    // MARK: - 夹具

    private static let fixtureDate = Date(timeIntervalSince1970: 1_789_344_000)

    /// 三类各一、两张普通照片、一张篮内普通照片（2 MB）、一张账本内视频（200 MB）、一张未解析照片。
    private func libraryFixture() -> [S0ClassifiedAsset] {
        let megabyte: Int64 = 1_000_000
        return [
            scannedAsset(
                "video",
                mediaType: .video,
                pixelWidth: 3_840,
                pixelHeight: 2_160,
                videoFilename: "IMG_0001.MOV",
                byteCount: 150 * megabyte
            ),
            scannedAsset(
                "recording",
                mediaType: .video,
                pixelWidth: 886,
                pixelHeight: 1_920,
                videoFilename: "ScreenRecording_10-13-2025 15-42-39_1.mp4",
                byteCount: 30 * megabyte
            ),
            scannedAsset(
                "screenshot",
                mediaType: .photo,
                isScreenshot: true,
                pixelWidth: 1_206,
                pixelHeight: 2_622,
                byteCount: 3 * megabyte
            ),
            scannedAsset("photo-a", mediaType: .photo, byteCount: 4 * megabyte),
            scannedAsset("photo-b", mediaType: .photo, byteCount: 5 * megabyte),
            scannedAsset("pending-photo", mediaType: .photo, byteCount: 2 * megabyte),
            scannedAsset(
                "ledger-video",
                mediaType: .video,
                pixelWidth: 3_840,
                pixelHeight: 2_160,
                videoFilename: "IMG_0009.MOV",
                byteCount: 200 * megabyte
            ),
            scannedAsset(
                "unresolved-photo",
                mediaType: .photo,
                byteCount: 0,
                isUnresolved: true
            )
        ].map { S0ScanClassifier.classified($0) }
    }

    private func scannedAsset(
        _ id: String,
        mediaType: S0ScannedMediaType,
        isScreenshot: Bool = false,
        pixelWidth: Int = 4_032,
        pixelHeight: Int = 3_024,
        videoFilename: String? = nil,
        byteCount: Int64,
        isUnresolved: Bool = false
    ) -> S0ScannedAsset {
        S0ScannedAsset(
            id: id,
            modificationDate: Self.fixtureDate,
            creationDate: Self.fixtureDate,
            mediaType: mediaType,
            isScreenshot: isScreenshot,
            pixelWidth: pixelWidth,
            pixelHeight: pixelHeight,
            duration: mediaType == .video ? 12 : 0,
            videoFilename: videoFilename,
            byteCount: byteCount,
            isUnresolved: isUnresolved
        )
    }

    private func aggregationContext(
        pending: Set<String>,
        ledger: Set<String>
    ) -> S0ScanAggregationContext {
        S0ScanAggregationContext(
            progress: S0ScanProgress(scannedAssetCount: 8, totalAssetCount: 8),
            recognition: .settled,
            pendingDeletionAssetIDs: pending,
            ledgerAssetIDs: ledger,
            ledgerEntries: [],
            isLimitedAuthorization: false
        )
    }

    /// 断言 3 的排序夹具：到达顺序为「其余照片」、截图、视频、录屏、重复（无项目）。
    private func orderSnapshot(recognition: S0CategoryRecognition) -> S0CleanupSnapshot {
        let categories = [
            S0CategorySnapshot(
                id: .rest,
                candidateCount: 400,
                candidateByteCount: 40_000_000_000,
                recognition: recognition
            ),
            S0CategorySnapshot(
                id: .screenshot,
                candidateCount: 50,
                candidateByteCount: 1_000_000_000,
                recognition: recognition
            ),
            S0CategorySnapshot(
                id: .bigVideo,
                candidateCount: 10,
                candidateByteCount: 5_000_000_000,
                recognition: recognition
            ),
            S0CategorySnapshot(
                id: .screenRecording,
                candidateCount: 4,
                candidateByteCount: 2_000_000_000,
                recognition: recognition
            ),
            S0CategorySnapshot(
                id: .duplicate,
                candidateCount: 0,
                candidateByteCount: 0,
                recognition: recognition
            )
        ]
        let byteSum = categories.map(\.candidateByteCount).reduce(0, +)
        return S0CleanupSnapshot(
            progress: S0ScanProgress(scannedAssetCount: 464, totalAssetCount: 464),
            cleanableAssetCount: categories.map(\.candidateCount).reduce(0, +),
            cleanableByteCount: byteSum,
            libraryTotalByteCount: byteSum,
            categories: categories
        )
    }

    /// 开屏 → 摄入 → 扫描完成，照 IC-147 的迁移序列。
    private func settledMachine(ingesting snapshot: S0CleanupSnapshot) -> S0StateMachine {
        let machine = S0StateMachine()
        machine.handle(.applicationOpened)
        machine.ingest(snapshot)
        machine.handle(.scanCompleted)
        return machine
    }

    // MARK: - 路径

    private static let modelPath = "PhotoCleanupMVE/Features/S0/S0DeckHomeModel.swift"
    private static let homePath = "PhotoCleanupMVE/Features/S0/S0DeckHomeView.swift"
    private static let textPath = "PhotoCleanupMVE/Features/S0/S0Text.swift"
    private static let metricsPath = "PhotoCleanupMVE/Features/S0/S0DeckMetrics.swift"
    private static let segmentPath = "PhotoCleanupMVE/Features/S0/S0SegmentBarModel.swift"
    private static let providerPath = "PhotoCleanupMVE/Features/S0/S0CleanupDataProviding.swift"
    private static let classifierPath = "PhotoCleanupMVE/Services/S0ScanClassifier.swift"
    private static let servicePath = "PhotoCleanupMVE/Services/S0LibraryScanService.swift"
    private static let appPath = "PhotoCleanupMVE/App/PhotoCleanupMVEApp.swift"

    // MARK: - 源码扫描 helper（口径与 IC-165 一致）

    /// 换行符用 `UnicodeScalar` 拼、不写转义字面量（IC-148 #294 的 heredoc 教训）。
    private static let newline = String(Character(UnicodeScalar(UInt8(10))))
    /// 顶层类型的收口：换行 + 右花括号 + 换行。
    private static let topLevelClose = newline + "}" + newline

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

    /// git blob 标识：`SHA-1("blob <字节数>" + NUL + 内容)`。`.gitattributes` 把 `*.swift` 钉为 LF，
    /// 检出内容即仓库内容，故与 `git rev-parse <提交>:<路径>` 同值。
    private func gitBlobID(_ relativePath: String) throws -> String {
        let content = try Data(contentsOf: repoRoot().appendingPathComponent(relativePath))
        var payload = Data(("blob " + String(content.count)).utf8)
        payload.append(contentsOf: [UInt8(0)])
        payload.append(content)
        return Insecure.SHA1.hash(data: payload)
            .map { String(format: "%02x", $0) }
            .joined()
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

    /// 数值字面量提取，口径同 IC-148／IC-153／IC-165 `numericLiterals(in:)`。
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
}
