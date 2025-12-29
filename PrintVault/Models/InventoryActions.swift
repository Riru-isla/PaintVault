import Foundation
import SwiftData

enum AddInventoryOutcome {
    case addedNew
    case incremented(existingQuantity: Int)
}

func addOrIncrementInventoryItem(
    paint: Paint,
    status: InventoryStatus,
    modelContext: ModelContext
) throws -> AddInventoryOutcome {

    let brand = paint.brandRaw
    let range = paint.range
    let code = paint.manufacturerCode
    let statusRaw = status.rawValue

    // Find an existing InventoryItem for the same paint identity + same status
    let descriptor = FetchDescriptor<InventoryItem>(
        predicate: #Predicate { item in
            item.statusRaw == statusRaw &&
            item.paint.brandRaw == brand &&
            item.paint.range == range &&
            item.paint.manufacturerCode == code
        }
    )

    if let existing = try modelContext.fetch(descriptor).first {
        existing.quantity += 1
        return .incremented(existingQuantity: existing.quantity)
    } else {
        let item = InventoryItem(paint: paint, status: status, quantity: 1)
        modelContext.insert(item)
        return .addedNew
    }
}
