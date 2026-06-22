import XCTest
@testable import Deskline

final class TokenQuotaTests: XCTestCase {
    func testTotalCountsEverything() {
        let u = TokenUsage(input: 100, output: 50, cacheWrite: 200, cacheRead: 9000)
        XCTAssertEqual(u.total, 9350)
        XCTAssertEqual(u.billed, 150)
    }

    func testQuotaDiscountsCacheReads() {
        // cache reads weighted 0.1x so heavy cache reuse doesn't inflate quota %.
        let u = TokenUsage(input: 100, output: 50, cacheWrite: 200, cacheRead: 9000)
        // 100 + 50 + 200 + 900 = 1250
        XCTAssertEqual(u.quota, 1250)
    }

    func testQuotaWithoutCacheReadsEqualsBilledPlusCacheWrite() {
        let u = TokenUsage(input: 10, output: 20, cacheWrite: 5, cacheRead: 0)
        XCTAssertEqual(u.quota, 35)
    }

    func testQuotaMuchSmallerThanTotalForCacheHeavyTurn() {
        // A typical agent turn re-reads a big cached context.
        let u = TokenUsage(input: 500, output: 300, cacheWrite: 0, cacheRead: 1_000_000)
        XCTAssertEqual(u.total, 1_000_800)
        XCTAssertEqual(u.quota, 100_800) // ~10x smaller, closer to real limit weighting
    }
}
