import XCTest
@testable import Deskline

final class CursorQuotaParseTests: XCTestCase {
    func testParseUsageExposesTotalAutoAndAPIBars() {
        let json: [String: Any] = [
            "billingCycleEnd": "2026-07-02T14:11:55.000Z",
            "membershipType": "pro",
            "individualUsage": [
                "plan": [
                    "enabled": true,
                    "used": 350,
                    "limit": 1000,
                    "totalPercentUsed": 35,
                    "autoPercentUsed": 29,
                    "apiPercentUsed": 53,
                ] as [String: Any],
            ] as [String: Any],
        ]

        let usage = CursorQuotaEngine.parseUsage(json)
        XCTAssertEqual(usage?.sessionPct, 35)
        XCTAssertNil(usage?.weeklyPct)
        XCTAssertEqual(usage?.quotaLanes?.map(\.label), ["Auto + Composer", "API"])
        XCTAssertEqual(usage?.quotaLanes?.map(\.pct), [29, 53])
        XCTAssertEqual(usage?.glancePct, 35)
    }

    func testParseUsageSupportsPlanUsageRootShape() {
        let json: [String: Any] = [
            "billingCycleEnd": "1771077734000",
            "planUsage": [
                "totalPercentUsed": 15.48,
                "autoPercentUsed": 0,
                "apiPercentUsed": 46.444,
                "includedSpend": 23222,
                "limit": 40000,
            ] as [String: Any],
        ]

        let usage = CursorQuotaEngine.parseUsage(json)
        XCTAssertEqual(usage?.sessionPct, 15.48)
        XCTAssertEqual(usage?.quotaLanes?.count, 2)
        XCTAssertEqual(usage?.quotaLanes?.first?.label, "Auto + Composer")
        XCTAssertEqual(usage?.quotaLanes?.last?.label, "API")
    }

    func testSnapshotRendersThreeCursorBars() {
        let json: [String: Any] = [
            "individualUsage": [
                "plan": [
                    "enabled": true,
                    "totalPercentUsed": 35,
                    "autoPercentUsed": 29,
                    "apiPercentUsed": 53,
                ] as [String: Any],
            ] as [String: Any],
        ]
        guard let usage = CursorQuotaEngine.parseUsage(json) else {
            return XCTFail("expected usage")
        }
        let snap = QuotaSnapshot.fromAPI(.cursor, usage: usage)
        XCTAssertEqual(snap.allBarVMs.map(\.label), ["Total", "Auto + Composer", "API"])
        XCTAssertEqual(snap.allBarVMs.map(\.usedText), ["35.00%", "29.00%", "53.00%"])
    }
}
