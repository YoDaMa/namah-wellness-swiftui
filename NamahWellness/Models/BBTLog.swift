import Foundation
import SwiftData

enum TemperatureUnit: String, Codable, CaseIterable {
    case fahrenheit = "fahrenheit"
    case celsius = "celsius"

    var symbol: String {
        switch self {
        case .fahrenheit: return "°F"
        case .celsius: return "°C"
        }
    }

    /// Convert a temperature value to Fahrenheit for canonical storage comparison
    static func toFahrenheit(_ value: Double, from unit: TemperatureUnit) -> Double {
        switch unit {
        case .fahrenheit: return value
        case .celsius: return value * 9.0 / 5.0 + 32.0
        }
    }

    /// Convert a Fahrenheit value to this unit for display
    func fromFahrenheit(_ fahrenheit: Double) -> Double {
        switch self {
        case .fahrenheit: return fahrenheit
        case .celsius: return (fahrenheit - 32.0) * 5.0 / 9.0
        }
    }
}

@Model
final class BBTLog {
    @Attribute(.unique) var id: String
    var userId: String = ""
    var date: String                     // "YYYY-MM-DD"
    var temperature: Double              // stored in user's preferred unit
    var unitRaw: String                  // TemperatureUnit raw value
    var timeOfMeasurement: Date?
    var notes: String?
    var createdAt: Date

    var unit: TemperatureUnit {
        get { TemperatureUnit(rawValue: unitRaw) ?? .fahrenheit }
        set { unitRaw = newValue.rawValue }
    }

    /// Temperature in Fahrenheit (for charting consistency)
    var temperatureInFahrenheit: Double {
        TemperatureUnit.toFahrenheit(temperature, from: unit)
    }

    init(
        id: String = UUID().uuidString,
        userId: String = "",
        date: String,
        temperature: Double,
        unit: TemperatureUnit = .fahrenheit,
        timeOfMeasurement: Date? = nil,
        notes: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.date = date
        self.temperature = temperature
        self.unitRaw = unit.rawValue
        self.timeOfMeasurement = timeOfMeasurement
        self.notes = notes
        self.createdAt = createdAt
    }
}
