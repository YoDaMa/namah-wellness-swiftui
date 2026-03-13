import XCTest
@testable import NamahWellness

final class SexualActivityLogTests: XCTestCase {

    // MARK: - ProtectionType

    func testProtectionTypeDisplayNames() {
        XCTAssertEqual(ProtectionType.protected.displayName, "Protected")
        XCTAssertEqual(ProtectionType.unprotected.displayName, "Unprotected")
        XCTAssertEqual(ProtectionType.withdrawal.displayName, "Withdrawal")
        XCTAssertEqual(ProtectionType.insemination.displayName, "Insemination")
    }

    func testProtectionTypeIcons() {
        XCTAssertEqual(ProtectionType.protected.icon, "shield.fill")
        XCTAssertEqual(ProtectionType.unprotected.icon, "shield.slash")
        XCTAssertEqual(ProtectionType.withdrawal.icon, "shield.lefthalf.filled")
        XCTAssertEqual(ProtectionType.insemination.icon, "heart.fill")
    }

    func testProtectionTypeRawValues() {
        XCTAssertEqual(ProtectionType.protected.rawValue, "protected")
        XCTAssertEqual(ProtectionType.unprotected.rawValue, "unprotected")
        XCTAssertEqual(ProtectionType.withdrawal.rawValue, "withdrawal")
        XCTAssertEqual(ProtectionType.insemination.rawValue, "insemination")
    }

    func testProtectionTypeAllCases() {
        XCTAssertEqual(ProtectionType.allCases.count, 4)
    }

    func testProtectionTypeFromRawValue() {
        XCTAssertEqual(ProtectionType(rawValue: "protected"), .protected)
        XCTAssertEqual(ProtectionType(rawValue: "withdrawal"), .withdrawal)
        XCTAssertNil(ProtectionType(rawValue: "invalid"))
    }

    // MARK: - SexualActivityLog

    func testDefaultProtectionType() {
        let log = SexualActivityLog(date: "2026-03-12")
        XCTAssertEqual(log.protectionType, .protected)
        XCTAssertEqual(log.protectionTypeRaw, "protected")
    }

    func testCustomProtectionType() {
        let log = SexualActivityLog(date: "2026-03-12", protectionType: .insemination)
        XCTAssertEqual(log.protectionType, .insemination)
        XCTAssertEqual(log.protectionTypeRaw, "insemination")
    }

    func testProtectionTypeSetter() {
        let log = SexualActivityLog(date: "2026-03-12")
        log.protectionType = .unprotected
        XCTAssertEqual(log.protectionTypeRaw, "unprotected")
        XCTAssertEqual(log.protectionType, .unprotected)
    }

    func testOptionalFields() {
        let log = SexualActivityLog(date: "2026-03-12")
        XCTAssertNil(log.time)
        XCTAssertNil(log.notes)
    }

    func testWithAllFields() {
        let now = Date()
        let log = SexualActivityLog(
            date: "2026-03-12",
            time: now,
            protectionType: .withdrawal,
            notes: "Test note"
        )
        XCTAssertEqual(log.date, "2026-03-12")
        XCTAssertEqual(log.time, now)
        XCTAssertEqual(log.protectionType, .withdrawal)
        XCTAssertEqual(log.notes, "Test note")
    }

    func testUniqueIds() {
        let log1 = SexualActivityLog(date: "2026-03-12")
        let log2 = SexualActivityLog(date: "2026-03-12")
        XCTAssertNotEqual(log1.id, log2.id)
    }
}
