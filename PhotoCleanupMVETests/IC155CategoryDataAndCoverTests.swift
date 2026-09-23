import Foundation
import SwiftUI
import UIKit
import XCTest
@testable import PhotoCleanupMVE

/// IC-155：批次 5.2a 类别数据接口与封面——`coverAssetID` 进模型、按类别取有序资产
/// 列表、首页类别行接真封面。
///
/// 依据 SPEC-S0 v2（SHA-256 `8A8E…6F44`）第三节第 2 部分（类别行单张封面取该类别
/// 按当前排序的第一项）、第六节（三列网格按 `SZ(a)` 降序）、第十四节封面几何，与
/// 任务卡 IC-20260916-155 的五条裁定。断言编号与任务卡一一对应：1～3 属子项 A，
/// 4～7 属子项 B，8～9 属子项 C；本文件随三个子项的提交逐段追加。
///
/// **夹具驱动，真机未覆盖**（陷阱 1）：封面是不是真机上最大的那一张、iCloud 优化
/// 储存时的空槽、滚动与切 tab 时封面不闪不串，只有 H76 能判。
final class IC155CategoryDataAndCoverTests: XCTestCase {

    // 子项 C 的两条断言排在最前：子项 B 追加在断言 3 之后与文件末尾，与之隔开，子项 C 的
    // 提交才能不经子项 B 直接摘到子项 A 上（任务卡摘取关系 A→C）。

    // MARK: - 断言 8：封面位委托共享缩略图视图，S0 侧零照片库符号（子项 C，源码扫描）

    func testIC155C_CoverSlotDelegatesToThumbnailViewWithoutPhotoKit() throws {
        // IC-165 C：v2 类别行与旧首页随之退役，S0 侧一段删去；卡片叠封面在
        // `Features/Shared/S0DeckCoverView.swift`，由 IC-165 断言 1／3 钉。下面只留共享缩略图视图
        // 与 S3 调用点一段。
        let thumbnailFilePath = "PhotoCleanupMVE/Features/Shared/ThumbnailView.swift"
        let gridFilePath = "PhotoCleanupMVE/Features/S3/S3View.swift"

        let thumbnail = try XCTUnwrap(strippedSource(thumbnailFilePath))
        XCTAssertEqual(occurrences(of: "showsPlaceholderGlyph: Bool = true", in: thumbnail), 1)
        XCTAssertEqual(occurrences(of: "isNetworkAccessAllowed = false", in: thumbnail), 1)
        XCTAssertGreaterThanOrEqual(occurrences(of: "Color.clear", in: thumbnail), 1)
        // 正对照（针对 needle 本身）：两个照片库 needle 在缩略图视图里命中非零。
        XCTAssertGreaterThan(occurrences(of: "import Photos", in: thumbnail), 0)
        XCTAssertGreaterThan(occurrences(of: "PHImageManager", in: thumbnail), 0)
        // 既有 S3 调用点仍是那一处，且没有传新参数（默认值兜住原行为）。
        let grid = try XCTUnwrap(strippedSource(gridFilePath))
        XCTAssertEqual(occurrences(of: "ThumbnailView(", in: grid), 1)
        XCTAssertEqual(occurrences(of: "showsPlaceholderGlyph", in: grid), 0)
    }

    // 断言 9（`testIC155C_RowBuildsForAllCoverStates`）随 IC-165 C 删去：v2 类别行 `S0CategoryRowView`
    // 随旧首页退役。

    // MARK: - 断言 1：封面 = 候选集中体积最大者，同体积取标识升序（子项 A）

    func testIC155A_CoverIsLargestCandidateWithDeterministicTie() {
        let megabyte: Int64 = 1_000_000
        // IC-153 断言 2 同型夹具，外加两条同体积、且大于既有截图的截图。
        let recording = scannedAsset(
            "recording",
            mediaType: .video,
            pixelWidth: 886,
            pixelHeight: 1_920,
            videoFilename: "ScreenRecording_10-13-2025 15-42-39_1.mp4",
            byteCount: 150 * megabyte
        )
        let screenshot = scannedAsset(
            "screenshot",
            mediaType: .photo,
            isScreenshot: true,
            pixelWidth: 1_206,
            pixelHeight: 2_622,
            byteCount: 3 * megabyte
        )
        let plainPhoto = scannedAsset("plain-photo", mediaType: .photo, byteCount: 4 * megabyte)
        let pendingScreenshot = scannedAsset(
            "pending-screenshot",
            mediaType: .photo,
            isScreenshot: true,
            byteCount: 2 * megabyte
        )
        // 账本内的视频：它若没被排除，「视频」类的封面就会是它（录屏自 IC-163 起不计入视频类）。
        let ledgerVideo = scannedAsset(
            "ledger-video",
            mediaType: .video,
            pixelWidth: 3_840,
            pixelHeight: 2_160,
            videoFilename: "IMG_0009.MOV",
            byteCount: 200 * megabyte
        )
        let unresolvedVideo = scannedAsset(
            "unresolved-video",
            mediaType: .video,
            pixelWidth: 3_840,
            pixelHeight: 2_160,
            videoFilename: "IMG_0010.MOV",
            byteCount: 0,
            isUnresolved: true
        )
        // 先 b 后 a：并列时若按到达顺序取，封面会是 b。
        let shotB = scannedAsset(
            "shot-b",
            mediaType: .photo,
            isScreenshot: true,
            pixelWidth: 1_206,
            pixelHeight: 2_622,
            byteCount: 5 * megabyte
        )
        let shotA = scannedAsset(
            "shot-a",
            mediaType: .photo,
            isScreenshot: true,
            pixelWidth: 1_206,
            pixelHeight: 2_622,
            byteCount: 5 * megabyte
        )
        let fixture = [
            recording,
            screenshot,
            plainPhoto,
            pendingScreenshot,
            ledgerVideo,
            unresolvedVideo,
            shotB,
            shotA
        ]
        let assets = fixture.map { S0ScanClassifier.classified($0) }
        let pending: Set<String> = ["pending-screenshot", "not-scanned-yet"]

        let snapshot = S0ScanAggregator.snapshot(
            of: assets,
            context: aggregationContext(pending: pending, ledger: ["ledger-video"])
        )
        XCTAssertEqual(
            snapshot.categories.map { $0.id },
            [.bigVideo, .screenRecording, .screenshot]
        )
        // 视频与录屏互斥（IC-163 裁定 五）：唯一的普通视频在账本内，「视频」类无候选、封面为 nil。
        XCTAssertEqual(category(.bigVideo, in: snapshot)?.coverAssetID, nil)
        XCTAssertEqual(category(.screenRecording, in: snapshot)?.coverAssetID, "recording")
        XCTAssertEqual(category(.screenshot, in: snapshot)?.coverAssetID, "shot-a")
        // 候选集与 `candidateCount` 同源：截图三条（3 MB + 5 MB × 2）。
        XCTAssertEqual(category(.screenshot, in: snapshot)?.candidateCount, 3)
        XCTAssertEqual(
            category(.screenshot, in: snapshot)?.candidateByteCount,
            13 * megabyte
        )

        // 并列的首选进了待删篮：封面换成并列的另一条（排除规则与计数同源）。
        let withShotAPending = S0ScanAggregator.snapshot(
            of: assets,
            context: aggregationContext(
                pending: pending.union(["shot-a"]),
                ledger: ["ledger-video"]
            )
        )
        XCTAssertEqual(category(.screenshot, in: withShotAPending)?.coverAssetID, "shot-b")
        XCTAssertEqual(category(.screenshot, in: withShotAPending)?.candidateCount, 2)
        XCTAssertEqual(
            category(.bigVideo, in: withShotAPending)?.coverAssetID,
            nil
        )

        // 正对照：账本清空后，账本视频回到「视频」类别并成为封面。
        let withoutLedger = S0ScanAggregator.snapshot(
            of: assets,
            context: aggregationContext(pending: pending, ledger: [])
        )
        XCTAssertEqual(category(.bigVideo, in: withoutLedger)?.coverAssetID, "ledger-video")
        XCTAssertEqual(
            category(.screenRecording, in: withoutLedger)?.coverAssetID,
            "recording"
        )

        // 全部候选都未解析：三个类别都无项目，封面一律 nil。
        let allUnresolved = [recording, screenshot, shotB, shotA].map { asset in
            S0ScanClassifier.classified(
                S0ScannedAsset(
                    id: asset.id,
                    modificationDate: asset.modificationDate,
                    creationDate: asset.creationDate,
                    mediaType: asset.mediaType,
                    isScreenshot: asset.isScreenshot,
                    pixelWidth: asset.pixelWidth,
                    pixelHeight: asset.pixelHeight,
                    duration: asset.duration,
                    videoFilename: asset.videoFilename,
                    byteCount: 0,
                    isUnresolved: true
                )
            )
        }
        let empty = S0ScanAggregator.snapshot(
            of: allUnresolved,
            context: aggregationContext(pending: [], ledger: [])
        )
        XCTAssertEqual(empty.categories.count, 3)
        for emptyCategory in empty.categories {
            XCTAssertEqual(emptyCategory.candidateCount, 0)
            XCTAssertNil(emptyCategory.coverAssetID)
        }
    }

    // MARK: - 断言 2：封面与输入顺序无关（子项 A，陷阱 10）

    func testIC155A_CoverIsOrderIndependent() {
        let megabyte: Int64 = 1_000_000
        // 每个类别都安排并列，且标识最小的那一条都不在原序首位。
        let fixture = [
            scannedAsset(
                "big-c",
                mediaType: .video,
                pixelWidth: 3_840,
                pixelHeight: 2_160,
                videoFilename: "IMG_0101.MOV",
                byteCount: 300 * megabyte
            ),
            scannedAsset(
                "rec-z",
                mediaType: .video,
                pixelWidth: 886,
                pixelHeight: 1_920,
                videoFilename: "ScreenRecording_01-01-2026 10-00-00_1.mp4",
                byteCount: 40 * megabyte
            ),
            scannedAsset(
                "shot-b",
                mediaType: .photo,
                isScreenshot: true,
                pixelWidth: 1_206,
                pixelHeight: 2_622,
                byteCount: 5 * megabyte
            ),
            scannedAsset(
                "big-a",
                mediaType: .video,
                pixelWidth: 3_840,
                pixelHeight: 2_160,
                videoFilename: "IMG_0102.MOV",
                byteCount: 300 * megabyte
            ),
            scannedAsset("plain-photo", mediaType: .photo, byteCount: 4 * megabyte),
            scannedAsset(
                "rec-y",
                mediaType: .video,
                pixelWidth: 2_622,
                pixelHeight: 1_206,
                videoFilename: "IMG_0103.MP4",
                byteCount: 40 * megabyte
            ),
            scannedAsset(
                "big-b",
                mediaType: .video,
                pixelWidth: 3_840,
                pixelHeight: 2_160,
                videoFilename: "IMG_0104.MOV",
                byteCount: 300 * megabyte
            ),
            scannedAsset(
                "shot-a",
                mediaType: .photo,
                isScreenshot: true,
                pixelWidth: 1_206,
                pixelHeight: 2_622,
                byteCount: 5 * megabyte
            ),
            scannedAsset(
                "small-shot",
                mediaType: .photo,
                isScreenshot: true,
                byteCount: 1 * megabyte
            )
        ]
        let assets = fixture.map { S0ScanClassifier.classified($0) }
        let evens = assets.enumerated().filter { $0.offset % 2 == 0 }.map { $0.element }
        let odds = assets.enumerated().filter { $0.offset % 2 == 1 }.map { $0.element }
        let orders: [[S0ClassifiedAsset]] = [
            assets,
            Array(assets.reversed()),
            Array(assets.dropFirst(2)) + Array(assets.prefix(2)),
            Array(assets.dropFirst(5)) + Array(assets.prefix(5)),
            evens + odds
        ]
        // 前置：五种顺序确实两两不同，否则「逐次相同」会空转通过。
        XCTAssertEqual(Set(orders.map { order in order.map { $0.id } }).count, 5)

        let context = aggregationContext(pending: [], ledger: [])
        let reference = S0ScanAggregator.snapshot(of: orders[0], context: context)
        XCTAssertEqual(
            reference.categories.map { $0.coverAssetID },
            ["big-a", "rec-y", "shot-a"]
        )
        for order in orders {
            let snapshot = S0ScanAggregator.snapshot(of: order, context: context)
            XCTAssertEqual(
                snapshot.categories.map { $0.coverAssetID },
                reference.categories.map { $0.coverAssetID }
            )
            XCTAssertEqual(snapshot, reference)
        }
    }

    // MARK: - 断言 3：带默认值的字段不打红既有构造（子项 A）

    func testIC155A_DefaultedFieldKeepsExistingConstructionsUntouched() throws {
        let model = try XCTUnwrap(strippedSource(Self.stateMachinePath))
        XCTAssertEqual(occurrences(of: "let coverAssetID: String?", in: model), 1)
        XCTAssertEqual(occurrences(of: "coverAssetID: String? = nil", in: model), 1)

        // IC-147／IC-148 的构造点一个标签都没加。IC-148 断言 14 的新 needle 是字符串
        // 字面量，剔过的源码里不留，故扫剔过的源码。
        let behavior = try XCTUnwrap(strippedSource(Self.behaviorTestsPath))
        let visual = try XCTUnwrap(strippedSource(Self.visualTestsPath))
        XCTAssertEqual(occurrences(of: "coverAssetID:", in: behavior), 0)
        XCTAssertEqual(occurrences(of: "coverAssetID:", in: visual), 0)
        // 正对照：两文件的构造点确实还在（15 + 3），扫描不是空转。
        XCTAssertEqual(occurrences(of: "S0CategorySnapshot(", in: behavior), 15)
        XCTAssertEqual(occurrences(of: "S0CategorySnapshot(", in: visual), 3)

        // 不带标签构造即为 nil（默认值生效）。
        let legacy = S0CategorySnapshot(
            id: .bigVideo,
            candidateCount: 12,
            candidateByteCount: 4_800_000_000,
            recognition: .settled
        )
        XCTAssertNil(legacy.coverAssetID)
        XCTAssertNotEqual(
            legacy,
            S0CategorySnapshot(
                id: .bigVideo,
                candidateCount: 12,
                candidateByteCount: 4_800_000_000,
                recognition: .settled,
                coverAssetID: "cover"
            )
        )

        // 桩：有项目的行封面为合成标识，无项目的行为 nil（A3 在子项 A 内定死）。
        let ready = S0CleanupDataStub(scenario: .readyWithItems).currentSnapshot()
        for readyCategory in ready.categories {
            XCTAssertEqual(
                readyCategory.coverAssetID,
                "stub." + readyCategory.id.rawValue + ".1"
            )
        }
        let readyEmpty = S0CleanupDataStub(scenario: .readyWithoutItems).currentSnapshot()
        XCTAssertEqual(readyEmpty.categories.count, 5)
        XCTAssertTrue(readyEmpty.categories.allSatisfy { $0.coverAssetID == nil })
        let scanningStart = S0CleanupDataStub(scenario: .scanning).currentSnapshot()
        XCTAssertTrue(scanningStart.categories.allSatisfy { $0.coverAssetID == nil })
    }

    // MARK: - 断言 4：读接口与快照同源、有序（子项 B）

    func testIC155B_CategoryAssetsMatchSnapshotAndOrder() {
        let megabyte: Int64 = 1_000_000
        let fixture = coverLibrary()
        let service = makeService(fixture)
        service.advanceScan()
        XCTAssertTrue(
            waitUntil {
                !service.isScanInFlight && service.currentScanOutcome() == .completed
            },
            "夹具扫描没有完成"
        )

        let snapshot = service.currentSnapshot()
        XCTAssertEqual(
            snapshot.categories.map { $0.id },
            [.bigVideo, .screenRecording, .screenshot]
        )
        let expectedOrders: [S0CategoryIdentifier: [String]] = [
            .bigVideo: ["v-big-1", "v-big-2", "v-big-3", "video-small"],
            .screenRecording: ["rec-big", "rec-a", "rec-b"],
            .screenshot: ["shot-1", "shot-2", "shot-3"]
        ]
        let metadataByID = fixture.metadataByIdentifier
        for category in snapshot.categories {
            let list = service.categoryAssets(category.id)
            let listByteCount = list.reduce(Int64(0)) { total, item in
                total + item.byteCount
            }
            XCTAssertEqual(list.map { $0.id }, expectedOrders[category.id])
            XCTAssertEqual(list.count, category.candidateCount)
            XCTAssertEqual(listByteCount, category.candidateByteCount)
            XCTAssertEqual(list.first?.id, category.coverAssetID)
            XCTAssertTrue(isOrderedBySizeThenIdentifier(list), category.id.rawValue)
            for item in list {
                let metadata = metadataByID[item.id]
                XCTAssertNotNil(metadata, item.id)
                XCTAssertEqual(item.isVideo, metadata?.mediaType == .video, item.id)
                XCTAssertEqual(item.duration, metadata?.duration, item.id)
            }
        }
        // 前置：并列确实存在，排序的第二键被走到；视频时长确实各不相同。
        XCTAssertEqual(
            service.categoryAssets(.bigVideo).prefix(2).map { $0.byteCount },
            [250 * megabyte, 250 * megabyte]
        )
        XCTAssertEqual(
            Set(service.categoryAssets(.bigVideo).map { $0.duration }).count,
            4
        )
        XCTAssertTrue(service.categoryAssets(.screenshot).allSatisfy { !$0.isVideo })
    }

    // MARK: - 断言 5：排除规则同源、随待删篮与库内变化（子项 B）

    func testIC155B_CategoryAssetsExcludePendingAndUnresolvedAndTrackRevision() {
        let fixture = coverLibrary()
        let service = makeService(fixture)
        var pending: Set<String> = []
        service.pendingDeletionAssetIDs = {
            pending
        }
        service.advanceScan()
        XCTAssertTrue(
            waitUntil {
                !service.isScanInFlight && service.currentScanOutcome() == .completed
            },
            "夹具扫描没有完成"
        )
        assertListsMatchSnapshot(service)

        // 未解析的截图不在任何列表里，也不计入候选数（计入的话截图会是 4 条）。
        let listed = [S0CategoryIdentifier.bigVideo, .screenRecording, .screenshot]
            .flatMap { identifier in
                service.categoryAssets(identifier).map { $0.id }
            }
        XCTAssertFalse(listed.contains("shot-unresolved"))
        XCTAssertEqual(snapshotCategory(.screenshot, of: service)?.candidateCount, 3)

        // 进待删篮：从列表消失，快照候选数同步减一，封面顺延到并列的另一条。
        pending.insert("v-big-1")
        XCTAssertFalse(service.categoryAssets(.bigVideo).contains { $0.id == "v-big-1" })
        XCTAssertEqual(snapshotCategory(.bigVideo, of: service)?.candidateCount, 3)
        XCTAssertEqual(snapshotCategory(.bigVideo, of: service)?.coverAssetID, "v-big-2")
        XCTAssertEqual(service.categoryAssets(.bigVideo).first?.id, "v-big-2")
        assertListsMatchSnapshot(service)

        // 录屏进篮：视频与录屏互斥（IC-163 裁定 五），只有录屏列表少它，「视频」列表不变。
        pending.insert("rec-big")
        XCTAssertEqual(
            service.categoryAssets(.bigVideo).map { $0.id },
            ["v-big-2", "v-big-3", "video-small"]
        )
        XCTAssertEqual(
            service.categoryAssets(.screenRecording).map { $0.id },
            ["rec-a", "rec-b"]
        )
        assertListsMatchSnapshot(service)

        // 移出待删篮：回到原位。
        pending.remove("v-big-1")
        XCTAssertEqual(service.categoryAssets(.bigVideo).first?.id, "v-big-1")
        assertListsMatchSnapshot(service)

        // 本服务不识别的两个类别恒为空。
        XCTAssertEqual(service.categoryAssets(.duplicate), [])
        XCTAssertEqual(service.categoryAssets(.similar), [])

        // 库内删掉一条后再扫一遍：列表与快照一起少它。
        fixture.removeAsset("shot-2")
        service.advanceScan()
        XCTAssertTrue(waitUntil { !service.isScanInFlight }, "第二遍没有结束")
        XCTAssertEqual(
            service.categoryAssets(.screenshot).map { $0.id },
            ["shot-1", "shot-3"]
        )
        XCTAssertEqual(snapshotCategory(.screenshot, of: service)?.candidateCount, 2)
        assertListsMatchSnapshot(service)
    }

    // MARK: - 断言 6：桩的合成列表确定且与快照一致（子项 B）

    func testIC155B_StubListsAreDeterministicAndConsistent() {
        var hookCount = 0
        var nonEmptyListCount = 0
        for scenario in S0CleanupDataStubScenario.allCases {
            for step in 0...S0CleanupDataStub.scanStepCount {
                let stub = S0CleanupDataStub(
                    scenario: scenario,
                    includesLedgerEntry: true,
                    pendingDeletionByteCount: 1_000,
                    scanStep: step
                )
                let twin = S0CleanupDataStub(
                    scenario: scenario,
                    includesLedgerEntry: true,
                    pendingDeletionByteCount: 1_000,
                    scanStep: step
                )
                stub.onSnapshotDidChange = {
                    hookCount += 1
                }
                // 经协议取：桩确实满足加了读接口的协议。
                let provider: any S0CleanupDataProviding = stub
                let snapshot = provider.currentSnapshot()
                for identifier in S0CategoryIdentifier.allCases {
                    let label = [scenario.rawValue, String(step), identifier.rawValue]
                        .joined(separator: "/")
                    let list = provider.categoryAssets(identifier)
                    XCTAssertEqual(list, twin.categoryAssets(identifier), label)
                    XCTAssertEqual(list, provider.categoryAssets(identifier), label)
                    guard let category = snapshot.categories.first(where: { $0.id == identifier }),
                          category.hasItems else {
                        XCTAssertEqual(list, [], label)
                        continue
                    }
                    nonEmptyListCount += 1
                    let listByteCount = list.reduce(Int64(0)) { total, item in
                        total + item.byteCount
                    }
                    XCTAssertEqual(list.count, category.candidateCount, label)
                    XCTAssertEqual(listByteCount, category.candidateByteCount, label)
                    XCTAssertEqual(list.first?.id, category.coverAssetID, label)
                    XCTAssertTrue(isOrderedBySizeThenIdentifier(list), label)
                    XCTAssertEqual(Set(list.map { $0.id }).count, list.count, label)
                    let expectsVideo = identifier == .bigVideo || identifier == .screenRecording
                    XCTAssertTrue(list.allSatisfy { $0.isVideo == expectsVideo }, label)
                }
            }
        }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        XCTAssertEqual(hookCount, 0, "桩调用了快照钩子")
        // 正对照：就绪剧本 5 类 × 5 步 + 扫描剧本第 1～4 步各 3 类，确有非空列表被核过。
        XCTAssertEqual(nonEmptyListCount, 37)
        // 失败剧本：五个类别全空。
        let failure = S0CleanupDataStub(scenario: .readFailure)
        XCTAssertTrue(
            S0CategoryIdentifier.allCases.allSatisfy { failure.categoryAssets($0).isEmpty }
        )
    }

    // MARK: - 断言 7：协议只多一个要求，钩子行不动（子项 B，源码扫描）

    func testIC155B_ProtocolGainsOneRequirementAndKeepsHookLine() throws {
        let requirement = "func categoryAssets(_ id: S0CategoryIdentifier) -> [S0CategoryAsset]"
        let view = try XCTUnwrap(strippedSource(Self.s0ViewPath))
        XCTAssertEqual(occurrences(of: requirement, in: view), 1)
        XCTAssertEqual(occurrences(of: "onSnapshotDidChange", in: view), 1)
        XCTAssertEqual(
            occurrences(of: "var onSnapshotDidChange: (() -> Void)? { get set }", in: view),
            1
        )
        XCTAssertEqual(
            occurrences(of: "protocol S0CleanupDataProviding: AnyObject {", in: view),
            1
        )

        // 读接口不碰 PhotoKit：服务文件的取数调用仍只有那一处全库枚举。
        let service = try XCTUnwrap(strippedSource(Self.servicePath))
        XCTAssertEqual(occurrences(of: "PHAsset.fetchAssets(with: nil)", in: service), 1)
        XCTAssertEqual(occurrences(of: "fetchAssets(withLocalIdentifiers", in: service), 0)
        // 上一条 needle 遇到「左括号后换行再写实参标签」的写法会空转（缩略图视图正是这样
        // 写的），故再按实参标签本身扫一遍。
        XCTAssertEqual(occurrences(of: "withLocalIdentifiers", in: service), 0)
        // 正对照：两处实现都在；实参标签 needle 在确实按标识取数的既有文件里命中非零。
        XCTAssertEqual(occurrences(of: requirement, in: service), 1)
        let stub = try XCTUnwrap(strippedSource(Self.stubPath))
        XCTAssertEqual(occurrences(of: requirement, in: stub), 1)
        let thumbnail = try XCTUnwrap(strippedSource(Self.thumbnailPath))
        XCTAssertGreaterThan(occurrences(of: "withLocalIdentifiers", in: thumbnail), 0)
    }

    // MARK: - 夹具

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

    private func category(
        _ identifier: S0CategoryIdentifier,
        in snapshot: S0CleanupSnapshot
    ) -> S0CategorySnapshot? {
        snapshot.categories.first { $0.id == identifier }
    }

    /// 断言 4／5 的样本库：三个类别各有并列，含一条大体积录屏（IC-163 起只归录屏）、一条未解析的
    /// 截图、一条小视频（IC-163 起归「视频」类）与一张普通照片。视频时长各不相同。
    private func coverLibrary() -> IC155LibraryFixture {
        let megabyte: Int64 = 1_000_000
        var assets: [S0AssetMetadata] = []
        var readings: [String: IC155Reading] = [:]
        func add(
            _ identifier: String,
            mediaType: S0ScannedMediaType,
            isScreenshot: Bool = false,
            pixelWidth: Int = 4_032,
            pixelHeight: Int = 3_024,
            duration: TimeInterval = 0,
            videoFilename: String? = nil,
            byteCount: Int64?
        ) {
            assets.append(
                S0AssetMetadata(
                    localIdentifier: identifier,
                    modificationDate: IC155CategoryDataAndCoverTests.fixtureDate,
                    creationDate: IC155CategoryDataAndCoverTests.fixtureDate
                        .addingTimeInterval(TimeInterval(assets.count * 60)),
                    mediaType: mediaType,
                    isScreenshot: isScreenshot,
                    pixelWidth: pixelWidth,
                    pixelHeight: pixelHeight,
                    duration: duration
                )
            )
            readings[identifier] = IC155Reading(
                videoFilename: videoFilename,
                byteCount: byteCount
            )
        }
        add(
            "v-big-2",
            mediaType: .video,
            pixelWidth: 3_840,
            pixelHeight: 2_160,
            duration: 61.5,
            videoFilename: "IMG_2001.MOV",
            byteCount: 250 * megabyte
        )
        add(
            "v-big-1",
            mediaType: .video,
            pixelWidth: 3_840,
            pixelHeight: 2_160,
            duration: 42.25,
            videoFilename: "IMG_2002.MOV",
            byteCount: 250 * megabyte
        )
        add(
            "v-big-3",
            mediaType: .video,
            pixelWidth: 3_840,
            pixelHeight: 2_160,
            duration: 30,
            videoFilename: "IMG_2003.MOV",
            byteCount: 180 * megabyte
        )
        add(
            "rec-big",
            mediaType: .video,
            pixelWidth: 886,
            pixelHeight: 1_920,
            duration: 95.5,
            videoFilename: "ScreenRecording_02-02-2026 09-00-00_1.mp4",
            byteCount: 120 * megabyte
        )
        add(
            "rec-b",
            mediaType: .video,
            pixelWidth: 1_206,
            pixelHeight: 2_622,
            duration: 20,
            videoFilename: "IMG_2004.MP4",
            byteCount: 30 * megabyte
        )
        add(
            "rec-a",
            mediaType: .video,
            pixelWidth: 886,
            pixelHeight: 1_920,
            duration: 21.75,
            videoFilename: "ScreenRecording_02-02-2026 09-10-00_1.mp4",
            byteCount: 30 * megabyte
        )
        add(
            "shot-2",
            mediaType: .photo,
            isScreenshot: true,
            pixelWidth: 1_206,
            pixelHeight: 2_622,
            byteCount: 4 * megabyte
        )
        add(
            "shot-1",
            mediaType: .photo,
            isScreenshot: true,
            pixelWidth: 1_206,
            pixelHeight: 2_622,
            byteCount: 4 * megabyte
        )
        add(
            "shot-3",
            mediaType: .photo,
            isScreenshot: true,
            pixelWidth: 1_206,
            pixelHeight: 2_622,
            byteCount: 2 * megabyte
        )
        add("photo-plain", mediaType: .photo, byteCount: 3 * megabyte)
        add(
            "shot-unresolved",
            mediaType: .photo,
            isScreenshot: true,
            pixelWidth: 1_206,
            pixelHeight: 2_622,
            byteCount: nil
        )
        add(
            "video-small",
            mediaType: .video,
            pixelWidth: 1_920,
            pixelHeight: 1_080,
            duration: 8,
            videoFilename: "IMG_2005.MOV",
            byteCount: 50 * megabyte
        )
        return IC155LibraryFixture(assets: assets, readings: readings)
    }

    private func makeService(_ fixture: IC155LibraryFixture) -> S0LibraryScanService {
        S0LibraryScanService(
            source: fixture.makeSource(),
            cacheStore: S0ScanCacheStore(directoryURL: makeTemporaryDirectory())
        )
    }

    private func snapshotCategory(
        _ identifier: S0CategoryIdentifier,
        of service: S0LibraryScanService
    ) -> S0CategorySnapshot? {
        service.currentSnapshot().categories.first { $0.id == identifier }
    }

    /// 三个类别各核一遍：项数、总字节、首项与封面、顺序。
    private func assertListsMatchSnapshot(
        _ service: S0LibraryScanService,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let snapshot = service.currentSnapshot()
        XCTAssertEqual(snapshot.categories.count, 3, file: file, line: line)
        for category in snapshot.categories {
            let list = service.categoryAssets(category.id)
            let listByteCount = list.reduce(Int64(0)) { total, item in
                total + item.byteCount
            }
            XCTAssertEqual(list.count, category.candidateCount, file: file, line: line)
            XCTAssertEqual(
                listByteCount,
                category.candidateByteCount,
                file: file,
                line: line
            )
            XCTAssertEqual(list.first?.id, category.coverAssetID, file: file, line: line)
            XCTAssertTrue(
                isOrderedBySizeThenIdentifier(list),
                file: file,
                line: line
            )
        }
    }

    /// 体积降序、同体积标识升序（裁定 二）。
    private func isOrderedBySizeThenIdentifier(_ list: [S0CategoryAsset]) -> Bool {
        zip(list, list.dropFirst()).allSatisfy { pair in
            pair.0.byteCount > pair.1.byteCount
                || (pair.0.byteCount == pair.1.byteCount && pair.0.id < pair.1.id)
        }
    }

    private var temporaryDirectories: [URL] = []

    override func tearDown() {
        for directory in temporaryDirectories {
            try? FileManager.default.removeItem(at: directory)
        }
        temporaryDirectories = []
        super.tearDown()
    }

    /// 只给出路径、不建目录：缓存仓库第一次写入时才建。
    private func makeTemporaryDirectory() -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("IC155-" + UUID().uuidString, isDirectory: true)
        temporaryDirectories.append(directory)
        return directory
    }

    /// 转主线程 run loop 直到条件成立或超时（服务的回调经主队列送达）。
    @discardableResult
    private func waitUntil(
        timeout: TimeInterval = 10,
        _ condition: () -> Bool
    ) -> Bool {
        let deadline = Date(timeIntervalSinceNow: timeout)
        while !condition() {
            if Date() >= deadline {
                return false
            }
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.01))
        }
        return true
    }

    private static let fixtureDate = Date(timeIntervalSinceReferenceDate: 780_000_000.25)
    private static let stateMachinePath = "PhotoCleanupMVE/Core/S0StateMachine.swift"
    private static let behaviorTestsPath = "PhotoCleanupMVETests/IC147S0BehaviorTests.swift"
    private static let visualTestsPath = "PhotoCleanupMVETests/IC148S0VisualTests.swift"
    /// IC-165 C：数据源协议从退役的旧首页原样搬进自己的文件。
    private static let s0ViewPath = "PhotoCleanupMVE/Features/S0/S0CleanupDataProviding.swift"
    private static let servicePath = "PhotoCleanupMVE/Services/S0LibraryScanService.swift"
    private static let stubPath = "PhotoCleanupMVE/Services/S0CleanupDataStub.swift"
    private static let thumbnailPath = "PhotoCleanupMVE/Features/Shared/ThumbnailView.swift"

    // MARK: - 源码扫描 helper（口径与 IC-147／IC-148／IC-153 一致）

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
}

/// 夹具读数：一次资源枚举给出的视频文件名与字节（字节为 nil 即取不到）。
private struct IC155Reading {
    let videoFilename: String?
    let byteCount: Int64?
}

/// 断言 4／5 的夹具源。三个闭包在非主线程上被调，库内元数据可在两遍扫描之间删减，
/// 读写一律经锁（陷阱 10：并发驱动的 helper 必须并发安全）。
private final class IC155LibraryFixture {
    private let lock = NSLock()
    private var assets: [S0AssetMetadata]
    private let readings: [String: IC155Reading]

    init(assets: [S0AssetMetadata], readings: [String: IC155Reading]) {
        self.assets = assets
        self.readings = readings
    }

    var metadataByIdentifier: [String: S0AssetMetadata] {
        locked {
            Dictionary(
                assets.map { ($0.localIdentifier, $0) },
                uniquingKeysWith: { first, _ in first }
            )
        }
    }

    func removeAsset(_ identifier: String) {
        locked { () -> Void in
            assets.removeAll { $0.localIdentifier == identifier }
        }
    }

    func makeSource() -> S0LibraryScanSource {
        S0LibraryScanSource(
            authorizationState: {
                .authorized
            },
            enumerateAssets: { [self] in
                self.currentAssets()
            },
            fetchResourcesAndBytes: { [self] identifier in
                let reading = self.reading(for: identifier)
                return (videoFilename: reading.videoFilename, byteCount: reading.byteCount)
            }
        )
    }

    private func currentAssets() -> [S0AssetMetadata] {
        locked {
            assets
        }
    }

    private func reading(for identifier: String) -> IC155Reading {
        locked {
            readings[identifier] ?? IC155Reading(videoFilename: nil, byteCount: nil)
        }
    }

    private func locked<T>(_ body: () throws -> T) rethrows -> T {
        lock.lock()
        defer {
            lock.unlock()
        }
        return try body()
    }
}
