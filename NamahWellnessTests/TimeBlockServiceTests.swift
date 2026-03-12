import XCTest
@testable import NamahWellness

final class TimeBlockServiceTests: XCTestCase {

    // MARK: - computeBlocks

    func testDefaultBlockComputation() {
        // Default: wake 6am (360), sleep 10pm (1320) → 16 hours awake
        let blocks = TimeBlockService.computeBlocks(wakeMinutes: 360, sleepMinutes: 1320)

        XCTAssertEqual(blocks.count, 4)
        XCTAssertEqual(blocks[0].kind, .morning)
        XCTAssertEqual(blocks[1].kind, .midday)
        XCTAssertEqual(blocks[2].kind, .afternoon)
        XCTAssertEqual(blocks[3].kind, .evening)

        // Morning starts at wake
        XCTAssertEqual(blocks[0].startMinutes, 360)
        // Evening ends at sleep
        XCTAssertEqual(blocks[3].endMinutes, 1320)

        // Blocks should be contiguous
        XCTAssertEqual(blocks[0].endMinutes, blocks[1].startMinutes)
        XCTAssertEqual(blocks[1].endMinutes, blocks[2].startMinutes)
        XCTAssertEqual(blocks[2].endMinutes, blocks[3].startMinutes)
    }

    func testBlockContainment() {
        let blocks = TimeBlockService.computeBlocks(wakeMinutes: 360, sleepMinutes: 1320)
        let morning = blocks[0]

        // Wake time should be in morning
        XCTAssertTrue(morning.contains(minutes: 360))
        // Just before morning end should be in morning
        XCTAssertTrue(morning.contains(minutes: morning.endMinutes - 1))
        // Morning end minute should NOT be in morning (exclusive)
        XCTAssertFalse(morning.contains(minutes: morning.endMinutes))
    }

    func testLateWakeEarlySleep() {
        // Night shift: wake 2pm (840), sleep 6am (360)
        let blocks = TimeBlockService.computeBlocks(wakeMinutes: 840, sleepMinutes: 360)

        XCTAssertEqual(blocks.count, 4)
        XCTAssertEqual(blocks[0].startMinutes, 840) // Morning starts at 2pm
    }

    func testContiguousBlocks() {
        // Various schedules should always produce contiguous blocks
        let schedules: [(Int, Int)] = [
            (360, 1320),  // 6am - 10pm
            (480, 1380),  // 8am - 11pm
            (300, 1260),  // 5am - 9pm
            (420, 1440),  // 7am - midnight
        ]

        for (wake, sleep) in schedules {
            let blocks = TimeBlockService.computeBlocks(wakeMinutes: wake, sleepMinutes: sleep)
            for i in 0..<(blocks.count - 1) {
                XCTAssertEqual(blocks[i].endMinutes, blocks[i + 1].startMinutes,
                               "Blocks not contiguous for wake=\(wake) sleep=\(sleep)")
            }
        }
    }

    // MARK: - TimeBlock label formatting

    func testTimeLabels() {
        let blocks = TimeBlockService.computeBlocks(wakeMinutes: 360, sleepMinutes: 1320)
        // Morning should start at "6am"
        XCTAssertEqual(blocks[0].startTimeLabel, "6am")
        // Evening should end at "10pm"
        XCTAssertEqual(blocks[3].endTimeLabel, "10pm")
    }

    // MARK: - TimeBlockService meal assignment

    func testMealBlockAssignment() {
        let service = TimeBlockService()
        // Default schedule: wake 6am, sleep 10pm

        // Breakfast at 7am → morning
        XCTAssertEqual(service.blockForMeal(time: "7:00am", mealType: "Breakfast"), .morning)
        // Lunch at 12pm → midday
        XCTAssertEqual(service.blockForMeal(time: "12:00pm", mealType: "Lunch"), .midday)
        // Dinner at 7pm → evening
        XCTAssertEqual(service.blockForMeal(time: "7:00pm", mealType: "Dinner"), .evening)
    }

    func testMealBlockFallbackOnBadTime() {
        let service = TimeBlockService()
        // Empty time string → falls back to mealType default
        let block = service.blockForMeal(time: "", mealType: "Breakfast")
        XCTAssertEqual(block, .morning)
    }

    // MARK: - Supplement assignment

    func testSupplementBlockAssignment() {
        let service = TimeBlockService()

        XCTAssertEqual(service.blockForSupplement(timeOfDay: "morning"), .morning)
        XCTAssertEqual(service.blockForSupplement(timeOfDay: "evening"), .evening)
    }

    // MARK: - Workout assignment

    func testWorkoutBlockAssignment() {
        let service = TimeBlockService()

        XCTAssertEqual(service.blockForWorkoutSession(timeSlot: "9:00am"), .morning)
        XCTAssertEqual(service.blockForWorkoutSession(timeSlot: "4:00pm"), .afternoon)
    }

    // MARK: - Display names and icons

    func testBlockKindProperties() {
        XCTAssertEqual(TimeBlockKind.morning.displayName, "Morning")
        XCTAssertEqual(TimeBlockKind.midday.displayName, "Midday")
        XCTAssertEqual(TimeBlockKind.afternoon.displayName, "Afternoon")
        XCTAssertEqual(TimeBlockKind.evening.displayName, "Evening")

        XCTAssertEqual(TimeBlockKind.morning.icon, "sunrise.fill")
        XCTAssertEqual(TimeBlockKind.evening.icon, "moon.fill")
    }
}
