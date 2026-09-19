import Combine
import Foundation
import XCTest
@testable import PhotoCleanupMVE

/// IC-160：类别页勾选跨 S2 往返保留（H78 第 2 条 Lynn 判「要改」）。
///
/// 保留集放在 App 持有的 `S0CleanupFlowModel` 里、不发布；页面每次勾选变化都同步过去，
/// 重建时按「保留集 ∩ 当前列表」播种（任务卡 IC-20260919-160 裁定 一～三）。断言编号与
/// 任务卡一一对应：1～3 属子项 A，4 属子项 B（追加在断言 3 之后、类末尾夹具之前）。
///
/// **夹具驱动，真机未覆盖**（陷阱 1）：「重建后 `@State` 取新初值」这件事模拟器夹具钉
/// 不住，由 H79 四条真机兜底。
final class IC160SelectionSurvivesS2Tests: XCTestCase {

    // MARK: - 断言 1：播种集与当前网格求交（子项 A）

    func testIC160A_PreselectIsIntersectedWithItems() {
        let items = Self.fixtureAssets

        // 默认值路径：IC-156 的既有行为一字不变。
        let fresh = S0CategoryPageSelection(items: items)
        XCTAssertTrue(fresh.selected.isEmpty)
        XCTAssertFalse(fresh.isSubmitEnabled)

        // 保留集全在网格里：原样播种。
        var seeded = S0CategoryPageSelection(items: items, preselected: ["a", "c"])
        XCTAssertEqual(seeded.selected, ["a", "c"])
        XCTAssertEqual(seeded.items.map { $0.id }, ["a", "b", "c", "d"])

        // 不在网格里的标识被丢（在 S2 里标记掉的那几张）。
        let partial = S0CategoryPageSelection(items: items, preselected: ["a", "z"])
        XCTAssertEqual(partial.selected, ["a"])

        // 空网格：交集为空，不留幽灵标识。
        let empty = S0CategoryPageSelection(items: [], preselected: ["a"])
        XCTAssertTrue(empty.selected.isEmpty)
        XCTAssertTrue(empty.items.isEmpty)

        // 常驻行与主按钮的取值由同一份已选集合算出。
        XCTAssertEqual(seeded.selectedByteCount, 1_400)
        XCTAssertTrue(seeded.isSubmitEnabled)
        XCTAssertEqual(seeded.selectedTextReplacements["count"], "2")
        XCTAssertEqual(
            seeded.selectedTextReplacements["bytes"],
            S0ByteCountText.string(forByteCount: 1_400)
        )

        // 播种之后，切换与移除仍是既有行为（正对照）。
        seeded.toggle("c")
        XCTAssertEqual(seeded.selected, ["a"])
        seeded.remove(ids: ["a"])
        XCTAssertTrue(seeded.selected.isEmpty)
        XCTAssertEqual(seeded.items.map { $0.id }, ["b", "c", "d"])
    }

    // MARK: - 断言 2：一次往返的模型层演练（子项 A）

    func testIC160A_RoundTripKeepsSurvivingSelection() {
        // 进 S2 之前勾了 a、b、c。
        let before: Set<String> = ["a", "b", "c"]

        // 在 S2 里标记了 b：回来后的列表少了 b，其余项相对顺序不变。
        let survivors = Self.fixtureAssets.filter { $0.id != "b" }
        XCTAssertEqual(survivors.map { $0.id }, ["a", "c", "d"])

        let restored = S0CategoryPageSelection(items: survivors, preselected: before)
        XCTAssertEqual(restored.selected, ["a", "c"])
        XCTAssertEqual(restored.items.map { $0.id }, ["a", "c", "d"])
        XCTAssertTrue(restored.isSubmitEnabled)
        XCTAssertEqual(restored.selectedTextReplacements["count"], "2")
        XCTAssertEqual(restored.selectedByteCount, 1_400)
        // 副行仍按网格全部项算（三项）。
        XCTAssertEqual(restored.subtitleTextReplacements["count"], "3")
    }

    // MARK: - 断言 3：保留集挂在流程模型上且不发布（子项 A）

    func testIC160A_FlowModelCarriesUnpublishedSelection() throws {
        let model = S0CleanupFlowModel()
        XCTAssertTrue(model.preservedSelection.isEmpty)

        var changeCount = 0
        let subscription = model.objectWillChange.sink { _ in
            changeCount += 1
        }

        // 写保留集不发布：类别页每次勾选变化都会写它，发布只会引发多余重绘。
        model.preservedSelection = ["a"]
        XCTAssertEqual(changeCount, 0)

        // 正对照：发布通道是活的，类别页身份照旧发布。
        model.presentedCategory = .screenshot
        XCTAssertEqual(changeCount, 1)

        subscription.cancel()
        XCTAssertEqual(model.preservedSelection, ["a"])

        let modelPath = "PhotoCleanupMVE/Features/S0/S0CleanupFlowModel.swift"
        let source = try XCTUnwrap(strippedSource(modelPath))
        XCTAssertEqual(occurrences(of: "@Published", in: source), 1)
        XCTAssertEqual(
            occurrences(of: "var preservedSelection: Set<String> = []", in: source),
            1
        )
        let importedModules = source
            .components(separatedBy: Self.newline)
            .filter { $0.hasPrefix("import ") }
            .map { String($0.dropFirst("import ".count)) }
        XCTAssertFalse(importedModules.isEmpty)
        XCTAssertTrue(
            Set(importedModules).isSubset(of: ["Combine", "Foundation"]),
            importedModules.joined(separator: ",")
        )
    }

    // MARK: - 夹具与 helper

    /// 四条资产，字节严格递减；数组顺序即网格顺序。
    private static let fixtureAssets = [
        S0CategoryAsset(id: "a", byteCount: 900, isVideo: true, duration: 761),
        S0CategoryAsset(id: "b", byteCount: 700, isVideo: true, duration: 62),
        S0CategoryAsset(id: "c", byteCount: 500, isVideo: false, duration: 0),
        S0CategoryAsset(id: "d", byteCount: 300, isVideo: false, duration: 0)
    ]

    private static let newline = String(Character(UnicodeScalar(UInt8(10))))

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
