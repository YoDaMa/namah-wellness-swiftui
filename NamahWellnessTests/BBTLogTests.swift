import XCTest
@testable import NamahWellness

final class BBTLogTests: XCTestCase {

    // MARK: - TemperatureUnit

    func testFahrenheitSymbol() {
        XCTAssertEqual(TemperatureUnit.fahrenheit.symbol, "°F")
    }

    func testCelsiusSymbol() {
        XCTAssertEqual(TemperatureUnit.celsius.symbol, "°C")
    }

    func testFahrenheitToFahrenheitConversion() {
        let result = TemperatureUnit.toFahrenheit(98.6, from: .fahrenheit)
        XCTAssertEqual(result, 98.6, accuracy: 0.01)
    }

    func testCelsiusToFahrenheitConversion() {
        // 37°C = 98.6°F
        let result = TemperatureUnit.toFahrenheit(37.0, from: .celsius)
        XCTAssertEqual(result, 98.6, accuracy: 0.01)
    }

    func testFahrenheitFromFahrenheit() {
        let result = TemperatureUnit.fahrenheit.fromFahrenheit(98.6)
        XCTAssertEqual(result, 98.6, accuracy: 0.01)
    }

    func testCelsiusFromFahrenheit() {
        // 98.6°F = 37°C
        let result = TemperatureUnit.celsius.fromFahrenheit(98.6)
        XCTAssertEqual(result, 37.0, accuracy: 0.01)
    }

    func testRoundTripConversion() {
        // Fahrenheit → Celsius → Fahrenheit
        let original = 97.8
        let celsius = TemperatureUnit.celsius.fromFahrenheit(original)
        let backToF = TemperatureUnit.toFahrenheit(celsius, from: .celsius)
        XCTAssertEqual(backToF, original, accuracy: 0.01)
    }

    // MARK: - BBTLog

    func testBBTLogDefaultUnit() {
        let log = BBTLog(date: "2026-03-12", temperature: 97.8)
        XCTAssertEqual(log.unitRaw, "fahrenheit")
        XCTAssertEqual(log.unit, .fahrenheit)
    }

    func testBBTLogCelsiusUnit() {
        let log = BBTLog(date: "2026-03-12", temperature: 36.5, unit: .celsius)
        XCTAssertEqual(log.unit, .celsius)
        XCTAssertEqual(log.unitRaw, "celsius")
    }

    func testBBTLogTemperatureInFahrenheit() {
        // Store as Celsius, read as Fahrenheit
        let log = BBTLog(date: "2026-03-12", temperature: 37.0, unit: .celsius)
        XCTAssertEqual(log.temperatureInFahrenheit, 98.6, accuracy: 0.01)
    }

    func testBBTLogFahrenheitTemperatureInFahrenheit() {
        let log = BBTLog(date: "2026-03-12", temperature: 98.6, unit: .fahrenheit)
        XCTAssertEqual(log.temperatureInFahrenheit, 98.6, accuracy: 0.01)
    }

    func testBBTLogUnitSetter() {
        let log = BBTLog(date: "2026-03-12", temperature: 97.8)
        log.unit = .celsius
        XCTAssertEqual(log.unitRaw, "celsius")
        XCTAssertEqual(log.unit, .celsius)
    }

    func testBBTLogOptionalFields() {
        let log = BBTLog(date: "2026-03-12", temperature: 97.8)
        XCTAssertNil(log.timeOfMeasurement)
        XCTAssertNil(log.notes)
    }

    func testBBTLogWithAllFields() {
        let now = Date()
        let log = BBTLog(
            date: "2026-03-12",
            temperature: 97.8,
            unit: .fahrenheit,
            timeOfMeasurement: now,
            notes: "Measured on waking"
        )
        XCTAssertEqual(log.temperature, 97.8)
        XCTAssertEqual(log.timeOfMeasurement, now)
        XCTAssertEqual(log.notes, "Measured on waking")
    }
}
