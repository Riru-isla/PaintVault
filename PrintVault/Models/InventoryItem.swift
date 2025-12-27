import Foundation
import SwiftData

enum InventoryStatus: String, Codable, CaseIterable {
    case owned
    case wishlist

    var title: String {
        switch self {
        case .owned: return "Owned"
        case .wishlist: return "Wishlist"
        }
    }
}

@Model
final class InventoryItem {
    var statusRaw: String
    var quantity: Int
    var notes: String?
    var createdAt: Date

    // Relationship to the catalog paint
    var paint: Paint

    var status: InventoryStatus {
        get { InventoryStatus(rawValue: statusRaw) ?? .owned }
        set { statusRaw = newValue.rawValue }
    }

    init(
        paint: Paint,
        status: InventoryStatus,
        quantity: Int = 1,
        notes: String? = nil,
        createdAt: Date = .now
    ) {
        self.paint = paint
        self.statusRaw = status.rawValue
        self.quantity = quantity
        self.notes = notes
        self.createdAt = createdAt
    }
}
