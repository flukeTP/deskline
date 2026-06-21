import XCTest
@testable import Deskline

final class NasdaqGlanceTests: XCTestCase {
    func testEmptyMapIsNil() {
        XCTAssertNil(NasdaqGlance.from(stateMap: [:], asOf: nil))
    }

    func testCountsAndBullishTilt() {
        let map = ["NVDA": "up", "AMD": "up", "MSFT": "down", "AAPL": "flat"]
        let glance = NasdaqGlance.from(stateMap: map, asOf: nil)
        XCTAssertEqual(glance?.up, 2)
        XCTAssertEqual(glance?.down, 1)
        XCTAssertEqual(glance?.flat, 1)
        XCTAssertEqual(glance?.total, 4)
        XCTAssertEqual(glance?.tilt, .bullish)
    }

    func testBearishTilt() {
        let glance = NasdaqGlance.from(stateMap: ["A": "down", "B": "down", "C": "up"], asOf: nil)
        XCTAssertEqual(glance?.tilt, .bearish)
    }

    func testNeutralTiltWhenTied() {
        let glance = NasdaqGlance.from(stateMap: ["A": "up", "B": "down"], asOf: nil)
        XCTAssertEqual(glance?.tilt, .neutral)
    }

    func testUnknownSignalCountsAsFlat() {
        let glance = NasdaqGlance.from(stateMap: ["A": "sideways", "B": "UP"], asOf: nil)
        XCTAssertEqual(glance?.up, 1)   // case-insensitive
        XCTAssertEqual(glance?.flat, 1) // unknown -> flat
    }

    func testSummaryOmitsZeroes() {
        let glance = NasdaqGlance.from(stateMap: ["A": "up", "B": "up"], asOf: nil)
        XCTAssertEqual(glance?.summary, "2▲")
    }

    func testSummaryAllFlat() {
        let glance = NasdaqGlance.from(stateMap: ["A": "flat", "B": "flat"], asOf: nil)
        XCTAssertEqual(glance?.summary, "2•")
    }

    func testPerTickerCountMatchesMap() {
        let glance = NasdaqGlance.from(stateMap: ["NVDA": "up", "AAPL": "flat", "MSFT": "down"], asOf: nil)
        XCTAssertEqual(glance?.tickers.count, 3)
        XCTAssertEqual(glance?.tickers.first(where: { $0.symbol == "NVDA" })?.direction, .up)
    }

    func testNoFlipWithoutBaseline() {
        let glance = NasdaqGlance.from(stateMap: ["NVDA": "up"], baseline: [:], asOf: nil)
        XCTAssertEqual(glance?.flippedCount, 0)
    }

    func testFlipDetectedWhenDirectionChanges() {
        let glance = NasdaqGlance.from(
            stateMap: ["NVDA": "down", "AAPL": "up"],
            baseline: ["NVDA": "up", "AAPL": "up"], // NVDA up->down, AAPL unchanged
            asOf: nil
        )
        XCTAssertEqual(glance?.flippedCount, 1)
        XCTAssertEqual(glance?.tickers.first?.symbol, "NVDA") // flipped pulled to front
        XCTAssertTrue(glance?.tickers.first?.flipped ?? false)
    }

    func testNewTickerNotCountedAsFlip() {
        // A symbol absent from baseline is new, not a flip.
        let glance = NasdaqGlance.from(stateMap: ["TSM": "up"], baseline: ["NVDA": "up"], asOf: nil)
        XCTAssertEqual(glance?.flippedCount, 0)
    }
}
