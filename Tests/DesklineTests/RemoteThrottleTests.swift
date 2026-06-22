import XCTest
@testable import Deskline

final class RemoteThrottleTests: XCTestCase {
    private let now = Date()

    func testForceAlwaysDue() {
        XCTAssertTrue(QuotaCoordinator.remoteIsDue(
            forceRemote: true, lastRemoteFetchedAt: now, now: now, interval: 300))
    }

    func testNeverFetchedIsDue() {
        XCTAssertTrue(QuotaCoordinator.remoteIsDue(
            forceRemote: false, lastRemoteFetchedAt: nil, now: now, interval: 300))
    }

    func testWithinIntervalNotDue() {
        let last = now.addingTimeInterval(-120) // 2 min ago, interval 5 min
        XCTAssertFalse(QuotaCoordinator.remoteIsDue(
            forceRemote: false, lastRemoteFetchedAt: last, now: now, interval: 300))
    }

    func testAtIntervalIsDue() {
        let last = now.addingTimeInterval(-300) // exactly 5 min ago
        XCTAssertTrue(QuotaCoordinator.remoteIsDue(
            forceRemote: false, lastRemoteFetchedAt: last, now: now, interval: 300))
    }

    func testPastIntervalIsDue() {
        let last = now.addingTimeInterval(-301)
        XCTAssertTrue(QuotaCoordinator.remoteIsDue(
            forceRemote: false, lastRemoteFetchedAt: last, now: now, interval: 300))
    }
}
