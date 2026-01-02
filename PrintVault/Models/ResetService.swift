import Foundation
import SwiftData

enum ResetScope {
    case inventoryOnly
    case everything
}

enum ResetService {
    static func reset(_ scope: ResetScope, modelContext: ModelContext) throws {
        // Always delete inventory first
        let items = try modelContext.fetch(FetchDescriptor<InventoryItem>())
        for item in items {
            modelContext.delete(item)
        }

        guard scope == .everything else { return }

        // Then delete paints
        let paints = try modelContext.fetch(FetchDescriptor<Paint>())
        for paint in paints {
            modelContext.delete(paint)
        }
    }
}
