import XCTest
@testable import PhotoCleanupMVE

final class VolumeFormattingTests: XCTestCase {
    // IC-136 B：< 1 MB 改一位小数四舍五入；0 字节四舍五入后为 0.0，
    // 按④取定抬到 0.1（避免 0.0 MB 这种自相矛盾的读数）。
    func testZeroBytesDisplaysAsZeroDecimalMegabytes() {
        XCTAssertEqual(
            DecimalVolumeFormatter.string(forByteCount: 0),
            "0.1 MB"
        )
    }

    func testBelowOneGigabyteUsesWholeDecimalMegabytes() {
        XCTAssertEqual(
            DecimalVolumeFormatter.string(forByteCount: 999_999_999),
            "999 MB"
        )
    }

    func testMegabytesAlwaysTruncateInsteadOfRoundingUp() {
        XCTAssertEqual(
            DecimalVolumeFormatter.string(forByteCount: 42_999_999),
            "42 MB"
        )
    }

    func testExactlyOneGigabyteUsesOneDecimalPlace() {
        XCTAssertEqual(
            DecimalVolumeFormatter.string(forByteCount: 1_000_000_000),
            "1.0 GB"
        )
    }

    func testGigabytesAlwaysTruncateAtOneDecimalPlace() {
        XCTAssertEqual(
            DecimalVolumeFormatter.string(forByteCount: 1_199_999_999),
            "1.1 GB"
        )
    }

    func testLargeGigabyteValueKeepsOneTruncatedDecimalPlace() {
        XCTAssertEqual(
            DecimalVolumeFormatter.string(forByteCount: 12_999_999_999),
            "12.9 GB"
        )
    }

    // MARK: - IC-136 B：KB 级写法

    // 断言 5：④ 取定的档位表逐值比对。< 1 MB 一位小数四舍五入、≥ 1 MB 与
    // ≥ 1 GB 的既有截断口径不变。
    func testIC136B_ByteCountTableFollowsRoundedSubMegabyteTier() {
        let table: [(Int64, String)] = [
            (0, "0.1 MB"),
            (49_999, "0.1 MB"),
            (50_000, "0.1 MB"),
            (437_000, "0.4 MB"),
            (949_999, "0.9 MB"),
            (950_000, "1.0 MB"),
            (999_999, "1.0 MB"),
            (1_000_000, "1 MB"),
            (1_999_999, "1 MB"),
            (999_999_999, "999 MB"),
            (1_000_000_000, "1.0 GB"),
            (1_250_000_000, "1.2 GB")
        ]
        for (byteCount, expected) in table {
            XCTAssertEqual(
                DecimalVolumeFormatter.string(forByteCount: byteCount),
                expected,
                "\(byteCount) 字节"
            )
        }
    }

    // 断言 6：S3 格子、S3 操作条 L2、S5 L2 三处走同一个符号；产品源码里
    // 只有一处声明这个格式化器，S3／S5 视图内不存在第二个 MB 换算实现。
    func testIC136B_SingleFormatterServesS3CellBarAndS5() throws {
        let repoRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        func source(_ relativePath: String) throws -> String {
            try String(
                contentsOf: repoRoot.appendingPathComponent(relativePath),
                encoding: .utf8
            )
        }
        let callSite = "DecimalVolumeFormatter.string("
        let s3View = try source("PhotoCleanupMVE/Features/S3/S3View.swift")
        let s5View = try source("PhotoCleanupMVE/Features/S5/S5View.swift")
        let core = try source("PhotoCleanupMVE/Core/S3StateMachine.swift")

        // S3 两处（格子角标、操作条 L2）、S5 一处（L2）。
        XCTAssertEqual(s3View.components(separatedBy: callSite).count - 1, 2)
        XCTAssertEqual(s5View.components(separatedBy: callSite).count - 1, 1)

        // 唯一声明点。
        XCTAssertEqual(
            core.components(separatedBy: "enum DecimalVolumeFormatter").count - 1,
            1
        )
        // 两个视图自己不做换算，也不自己拼单位。
        for (path, text) in [
            ("S3View", s3View),
            ("S5View", s5View)
        ] {
            XCTAssertFalse(text.contains(" MB\""), path)
            XCTAssertFalse(text.contains(" GB\""), path)
            XCTAssertFalse(text.contains("1_000_000"), path)
        }
    }
}
