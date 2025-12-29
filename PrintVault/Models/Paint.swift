import Foundation
import SwiftData

enum PaintBrand: String, Codable, CaseIterable {
    case vallejo = "Vallejo"
    case citadel = "Citadel"
    case ak = "AK Interactive"
    case scale75 = "Scale75"
    case other = "Other"
}

enum PaintType: String, Codable, CaseIterable {
    case base = "Base"
    case layer = "Layer"
    case shade = "Shade"
    case contrast = "Contrast"
    case technical = "Technical"
    case metallic = "Metallic"
    case ink = "Ink"
    case primer = "Primer"
    case varnish = "Varnish"
    case airbrush = "Airbrush"
    case light = "Light"
    case other = "Other"
}

@Model
final class Paint {
    // Stored raw strings (safe + easy for SwiftData)
    var brandRaw: String
    var range: String
    var typeRaw: String

    var manufacturerCode: String
    var name: String
    var barcode: String?

    @Relationship(deleteRule: .cascade, inverse: \InventoryItem.paint)
    var inventoryItems: [InventoryItem] = []

    // Computed enum views (what the app uses)
    var brand: PaintBrand {
        get { PaintBrand(rawValue: brandRaw) ?? .other }
        set { brandRaw = newValue.rawValue }
    }

    var type: PaintType {
        get { PaintType(rawValue: typeRaw) ?? .other }
        set { typeRaw = newValue.rawValue }
    }

    init(
        brand: PaintBrand,
        range: String,
        type: PaintType,
        manufacturerCode: String,
        name: String,
        barcode: String? = nil
    ) {
        self.brandRaw = brand.rawValue
        self.range = range
        self.typeRaw = type.rawValue
        self.manufacturerCode = manufacturerCode
        self.name = name
        self.barcode = barcode
    }
}
