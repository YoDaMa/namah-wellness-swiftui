import Foundation

struct Ingredient: Codable, Identifiable, Hashable {
    let name: String
    let quantity: String?
    let unit: String?

    var id: String { name }

    var displayQuantity: String {
        [quantity, unit].compactMap { $0 }.joined(separator: " ")
    }
}
