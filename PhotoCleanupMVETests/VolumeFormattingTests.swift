import XCTest
@testable import PhotoCleanupMVE

final class VolumeFormattingTests: XCTestCase {
    // MARK: - IC-099b P1：S2 单张资产占用空间口径（④ Lynn 2026-08-28 定案 2）

    /// 卡内八个用例逐条断言。三档边界全部向下截断，无四舍五入。
    /// 与 S3 合计口径并存——本节不触碰 `DecimalVolumeFormatter` 的任何断言。
    func testIC099bP1SingleAssetVolumeUsesKilobyteMegabyteGigabyteTiers() {
        let cases: [(Int64, String)] = [
            (0, "0 KB"),
            (324_846, "324 KB"),
            (999_999, "999 KB"),
            (1_000_000, "1.0 MB"),
            (2_466_000, "2.4 MB"),
            (999_949_999, "999.9 MB"),
            (1_000_000_000, "1.0 GB"),
            (25_480_000_000, "25.4 GB")
        ]
        for (byteCount, expected) in cases {
            XCTAssertEqual(
                S2AssetVolumeFormatter.string(forByteCount: byteCount),
                expected,
                "\(byteCount) 应显示为 \(expected)"
            )
        }
    }

    /// 档位切换恰好发生在 1_000_000 与 1_000_000_000，且两侧都不进位。
    func testIC099bP1TierBoundariesTruncateInsteadOfRounding() {
        XCTAssertEqual(
            S2AssetVolumeFormatter.string(forByteCount: 999_999),
            "999 KB"
        )
        XCTAssertEqual(
            S2AssetVolumeFormatter.string(forByteCount: 1_000_000),
            "1.0 MB"
        )
        XCTAssertEqual(
            S2AssetVolumeFormatter.string(forByteCount: 1_099_999),
            "1.0 MB"
        )
        XCTAssertEqual(
            S2AssetVolumeFormatter.string(forByteCount: 999_999_999),
            "999.9 MB"
        )
        XCTAssertEqual(
            S2AssetVolumeFormatter.string(forByteCount: 1_000_000_000),
            "1.0 GB"
        )
        XCTAssertEqual(
            S2AssetVolumeFormatter.string(forByteCount: 1_099_999_999),
            "1.0 GB"
        )
    }

    /// S2 口径与 S3 口径互不影响：同一字节数在两处给出各自档位的结果。
    func testIC099bP1SingleAssetTierDoesNotChangeAggregateTier() {
        XCTAssertEqual(
            S2AssetVolumeFormatter.string(forByteCount: 324_846),
            "324 KB"
        )
        XCTAssertEqual(
            DecimalVolumeFormatter.string(forByteCount: 324_846),
            "0 MB"
        )
        XCTAssertEqual(
            S2AssetVolumeFormatter.string(forByteCount: 2_466_000),
            "2.4 MB"
        )
        XCTAssertEqual(
            DecimalVolumeFormatter.string(forByteCount: 2_466_000),
            "2 MB"
        )
    }

    func testZeroBytesDisplaysAsZeroDecimalMegabytes() {
        XCTAssertEqual(DecimalVolumeFormatter.string(forByteCount: 0), "0 MB")
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
}
