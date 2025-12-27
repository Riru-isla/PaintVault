import Foundation
import SwiftData

@Model
final class Paint {
    // MARK: - Identity (catalog)
    var brand: String
    var range: String
    var manufacturerCode: String  // e.g. "72.001", "AK11187"
    var name: String              // e.g. "Dead White"

    // Optional: may be missing for many paints at first
    var barcode: String?

    // MARK: - Relationships
    // One paint can appear in many inventory entries (owned + wishlist, or future multi-collections)
    @Relationship(deleteRule: .cascade, inverse: \InventoryItem.paint)
    var inventoryItems: [InventoryItem] = []

    init(
        brand: String,
        range: String,
        manufacturerCode: String,
        name: String,
        barcode: String? = nil
    ) {
        self.brand = brand
        self.range = range
        self.manufacturerCode = manufacturerCode
        self.name = name
        self.barcode = barcode
    }
}
