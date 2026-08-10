import XCTest
@testable import PhotoCleanupMVE

final class VolumeFormattingTests: XCTestCase {
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
