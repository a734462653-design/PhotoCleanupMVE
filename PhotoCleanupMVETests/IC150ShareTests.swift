import Foundation
import XCTest
@testable import PhotoCleanupMVE

/// IC-150 A 的取项桩。不碰真实相册，只按资产标识回一个本地文件 URL。
private final class IC150ShareResolverStub: S2ShareItemResolving {
    var urls: [String: URL] = [:]
    private(set) var requested: [String] = []

    func shareItemURL(assetID: String) async -> URL? {
        requested.append(assetID)
        return urls[assetID]
    }
}

/// IC-150 A：分享只对视频有效（H69 第 2 项）。
///
/// **断言钉的是机制，不是真机行为**：四类资产各有取项路径、取项失败不呈现空
/// 面板、四条路径全程禁网络、旧的「直接交出 PhotoKit 容器路径」口径已废。
/// 真机落点是 H72 第 1／2 项，执行端不代为下结论（陷阱 1）。
///
/// 断言 2（只分享当前这一张）与断言 3（状态零影响）**沿用既有**
/// `testIC146A_ShareDiscardsFailedAndStaleResolutions` 与
/// `testIC146A_ShareLeavesEveryStateUntouched`，口径未放宽，本文件不复制。
final class IC150ShareTests: XCTestCase {
    // MARK: - 断言 1：四类资产各有一条可分享路径

    func testIC150AAssertion01EveryMediaKindResolvesToAShareableItem() async {
        let stub = IC150ShareResolverStub()
        let kinds = ["photo", "livePhoto", "screenshot", "video"]
        for kind in kinds {
            stub.urls[kind] = FileManager.default.temporaryDirectory
                .appendingPathComponent("S2Share", isDirectory: true)
                .appendingPathComponent(kind + ".dat")
        }

        for kind in kinds {
            var preparation = S2SharePreparation()
            XCTAssertTrue(
                preparation.begin(assetID: kind),
                kind + " 没能进入取项态"
            )
            XCTAssertTrue(preparation.isResolving)
            let url = await stub.shareItemURL(assetID: kind)
            XCTAssertNotNil(url, kind + " 取不到可分享项")
            preparation.resolved(assetID: kind, url: url)
            XCTAssertTrue(
                preparation.isPresenting,
                kind + " 取到了项却没能呈现面板"
            )
        }
        XCTAssertEqual(stub.requested, kinds, "取项没有逐类各走一次")

        // 正对照：取不到就回闲置，**不呈现空面板**（规格既有行为，不得放宽）。
        var missing = S2SharePreparation()
        XCTAssertTrue(missing.begin(assetID: "absent"))
        let absent = await stub.shareItemURL(assetID: "absent")
        XCTAssertNil(absent)
        missing.resolved(assetID: "absent", url: absent)
        XCTAssertFalse(missing.isPresenting, "取项失败仍呈现了空面板")
        XCTAssertFalse(missing.isResolving, "取项失败未回闲置")
    }

    // MARK: - 断言 4：四条路径全程禁网络（源码扫描带正对照）

    func testIC150AAssertion04NetworkAccessStaysDisabledOnEveryPath() throws {
        let resolver = try XCTUnwrap(shareResolverBody())

        // 两处请求选项（资源写出、视频），四类资产共走这两条路径。
        XCTAssertEqual(
            occurrences(of: "isNetworkAccessAllowed = false", in: resolver),
            2,
            "取项选项不是恰两处且都禁网络"
        )
        XCTAssertEqual(
            occurrences(of: "isNetworkAccessAllowed = true", in: resolver),
            0,
            "取项路径上开了网络"
        )
        // 正对照（针对 needle 本身）：这个符号确实能在剔过的源码里命中，
        // 否则上面那条「为 0」永远成立、什么都没测。
        XCTAssertGreaterThan(
            occurrences(of: "isNetworkAccessAllowed", in: resolver),
            0,
            "needle 写错了，两条计数断言都是空转"
        )
    }

    // MARK: - 断言 1 补充：旧的容器路径口径已废

    /// H69 第 2 项的死因钉死：不再把 PhotoKit 容器里的原文件 URL 直接交出去。
    func testIC150AAssertion01bResolverNoLongerHandsOutTheLibraryContainerURL()
        throws {
        let resolver = try XCTUnwrap(shareResolverBody())
        XCTAssertEqual(
            occurrences(of: "fullSizeImageURL", in: resolver),
            0,
            "仍在直接交出 PhotoKit 容器里的原文件路径"
        )
        XCTAssertEqual(
            occurrences(of: "requestContentEditingInput", in: resolver),
            0,
            "仍在走内容编辑输入那条带生命周期约束的路"
        )
        // 改成把原始字节写进自己的容器；视频那条（本来能用）口径不变。
        XCTAssertGreaterThan(
            occurrences(of: "PHAssetResourceManager", in: resolver),
            0,
            "没有改用资源写出"
        )
        XCTAssertGreaterThan(
            occurrences(of: "temporaryDirectory", in: resolver),
            0,
            "写出目标不在自己的容器里"
        )
        XCTAssertGreaterThan(
            occurrences(of: "AVURLAsset", in: resolver),
            0,
            "视频那条能用的路径被改坏了"
        )
    }

    // MARK: - 夹具

    private func shareResolverBody() -> String? {
        guard let view = strippedSource(
            "PhotoCleanupMVE/Features/S2/S2View.swift"
        ) else {
            return nil
        }
        return slice(
            view,
            from: "final class S2PhotoKitShareItemResolver: S2ShareItemResolving {",
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
