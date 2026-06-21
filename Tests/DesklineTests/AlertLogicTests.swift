import XCTest
@testable import Deskline

final class AlertLevelClassifyTests: XCTestCase {
    func testNilPercentIsNone() {
        XCTAssertEqual(AlertLevel.classify(percent: nil, enabled: true, warn: 80, critical: 95), .none)
    }

    func testDisabledIsAlwaysNone() {
        XCTAssertEqual(AlertLevel.classify(percent: 99, enabled: false, warn: 80, critical: 95), .none)
    }

    func testBelowWarnIsNone() {
        XCTAssertEqual(AlertLevel.classify(percent: 79.9, enabled: true, warn: 80, critical: 95), .none)
    }

    func testWarnBoundaryIsInclusive() {
        XCTAssertEqual(AlertLevel.classify(percent: 80, enabled: true, warn: 80, critical: 95), .warn)
    }

    func testBetweenWarnAndCriticalIsWarn() {
        XCTAssertEqual(AlertLevel.classify(percent: 88, enabled: true, warn: 80, critical: 95), .warn)
    }

    func testCriticalBoundaryIsInclusive() {
        XCTAssertEqual(AlertLevel.classify(percent: 95, enabled: true, warn: 80, critical: 95), .critical)
    }

    func testAboveCriticalIsCritical() {
        XCTAssertEqual(AlertLevel.classify(percent: 100, enabled: true, warn: 80, critical: 95), .critical)
    }
}

final class AlertEscalationTests: XCTestCase {
    func testNoneToWarnEscalates() {
        XCTAssertTrue(AlertEngine.didEscalate(from: .none, to: .warn))
    }

    func testWarnToCriticalEscalates() {
        XCTAssertTrue(AlertEngine.didEscalate(from: .warn, to: .critical))
    }

    func testNoneToCriticalEscalates() {
        XCTAssertTrue(AlertEngine.didEscalate(from: .none, to: .critical))
    }

    func testSameLevelDoesNotEscalate() {
        // Provider parked at 88% across refreshes must not re-fire.
        XCTAssertFalse(AlertEngine.didEscalate(from: .warn, to: .warn))
        XCTAssertFalse(AlertEngine.didEscalate(from: .critical, to: .critical))
    }

    func testCoolingDownDoesNotEscalate() {
        XCTAssertFalse(AlertEngine.didEscalate(from: .critical, to: .warn))
        XCTAssertFalse(AlertEngine.didEscalate(from: .warn, to: .none))
    }

    func testReArmAfterDropThenRise() {
        // Drop to none (re-arm), then rise again → escalates once more.
        XCTAssertFalse(AlertEngine.didEscalate(from: .warn, to: .none))
        XCTAssertTrue(AlertEngine.didEscalate(from: .none, to: .warn))
    }
}
