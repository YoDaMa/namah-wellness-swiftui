import XCTest
@testable import NamahWellness

final class TimeParserTests: XCTestCase {

    // MARK: - minutesSinceMidnight(from: String)

    func testStandardAMTimes() {
        XCTAssertEqual(TimeParser.minutesSinceMidnight(from: "7:00am"), 420)
        XCTAssertEqual(TimeParser.minutesSinceMidnight(from: "9:30am"), 570)
        XCTAssertEqual(TimeParser.minutesSinceMidnight(from: "11:45am"), 705)
    }

    func testStandardPMTimes() {
        XCTAssertEqual(TimeParser.minutesSinceMidnight(from: "12:00pm"), 720)
        XCTAssertEqual(TimeParser.minutesSinceMidnight(from: "1:00pm"), 780)
        XCTAssertEqual(TimeParser.minutesSinceMidnight(from: "4:30pm"), 990)
        XCTAssertEqual(TimeParser.minutesSinceMidnight(from: "11:59pm"), 1439)
    }

    func testMidnightAndNoon() {
        XCTAssertEqual(TimeParser.minutesSinceMidnight(from: "12:00am"), 0)
        XCTAssertEqual(TimeParser.minutesSinceMidnight(from: "12:00pm"), 720)
    }

    func testCaseInsensitive() {
        XCTAssertEqual(TimeParser.minutesSinceMidnight(from: "7:00AM"), 420)
        XCTAssertEqual(TimeParser.minutesSinceMidnight(from: "4:00PM"), 960)
    }

    func testWhitespaceHandling() {
        XCTAssertEqual(TimeParser.minutesSinceMidnight(from: " 7:00am "), 420)
        XCTAssertEqual(TimeParser.minutesSinceMidnight(from: "7:00am"), 420)
    }

    func testNoMinutesGiven() {
        // "7am" → 7:00am = 420
        XCTAssertEqual(TimeParser.minutesSinceMidnight(from: "7am"), 420)
        XCTAssertEqual(TimeParser.minutesSinceMidnight(from: "12pm"), 720)
    }

    func testEmptyAndInvalidStrings() {
        XCTAssertNil(TimeParser.minutesSinceMidnight(from: ""))
        XCTAssertNil(TimeParser.minutesSinceMidnight(from: "   "))
        XCTAssertNil(TimeParser.minutesSinceMidnight(from: "not a time"))
    }

    func testNoAMPMFallback() {
        // "14:30" → 14*60 + 30 = 870 (24-hour format)
        XCTAssertEqual(TimeParser.minutesSinceMidnight(from: "14:30"), 870)
        XCTAssertEqual(TimeParser.minutesSinceMidnight(from: "0:00"), 0)
    }

    // MARK: - defaultMinutes(forMealType:)

    func testMealTypeDefaults() {
        XCTAssertEqual(TimeParser.defaultMinutes(forMealType: "Breakfast"), 420)
        XCTAssertEqual(TimeParser.defaultMinutes(forMealType: "Lunch"), 720)
        XCTAssertEqual(TimeParser.defaultMinutes(forMealType: "Dinner"), 1110)
        XCTAssertEqual(TimeParser.defaultMinutes(forMealType: "Snack"), 900)
    }

    func testMealTypeCaseInsensitive() {
        XCTAssertEqual(TimeParser.defaultMinutes(forMealType: "breakfast"), 420)
        XCTAssertEqual(TimeParser.defaultMinutes(forMealType: "LUNCH"), 720)
    }

    func testUnknownMealType() {
        XCTAssertEqual(TimeParser.defaultMinutes(forMealType: "Brunch"), 720)
    }

    // MARK: - defaultMinutes(forSupplementTime:)

    func testSupplementTimeDefaults() {
        // With default wake=360 (6am), sleep=1320 (10pm)
        XCTAssertEqual(TimeParser.defaultMinutes(forSupplementTime: "morning"), 390) // 6:30am
        XCTAssertEqual(TimeParser.defaultMinutes(forSupplementTime: "with_meals"), 720) // noon
        XCTAssertEqual(TimeParser.defaultMinutes(forSupplementTime: "evening"), 1260) // 9pm (sleep-60)
        XCTAssertEqual(TimeParser.defaultMinutes(forSupplementTime: "as_needed"), 720) // noon fallback
    }

    func testSupplementTimeWithCustomSchedule() {
        // Wake at 8am (480), sleep at midnight (1440 = 0 min)
        XCTAssertEqual(TimeParser.defaultMinutes(forSupplementTime: "morning", wakeMinutes: 480, sleepMinutes: 0), 510) // 8:30am
    }
}
