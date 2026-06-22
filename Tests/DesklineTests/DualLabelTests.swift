import XCTest
@testable import Deskline

final class DualLabelTests: XCTestCase {
    func testBothSessionAndWeekly() {
        let u = ProviderUsage(sessionPct: 3, weeklyPct: 21)
        XCTAssertEqual(u.dualLabel, "S3 W21")
    }

    func testSessionOnly() {
        let u = ProviderUsage(sessionPct: 42, weeklyPct: nil)
        XCTAssertEqual(u.dualLabel, "S42")
    }

    func testWeeklyOnly() {
        let u = ProviderUsage(sessionPct: nil, weeklyPct: 60)
        XCTAssertEqual(u.dualLabel, "W60")
    }

    func testNeitherIsNil() {
        let u = ProviderUsage(sessionPct: nil, weeklyPct: nil)
        XCTAssertNil(u.dualLabel)
    }

    func testRoundsToWholePercent() {
        let u = ProviderUsage(sessionPct: 2.8, weeklyPct: 21.3)
        XCTAssertEqual(u.dualLabel, "S3 W21")
    }
}
