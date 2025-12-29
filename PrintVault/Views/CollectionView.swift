import SwiftUI
import SwiftData

struct CollectionView: View {
    @State private var showingAddPaint = false
    @Environment(\.modelContext) private var modelContext

    // Pull everything; we’ll filter owned for now (simple + reliable)
    @Query(sort: \InventoryItem.createdAt, order: .reverse)
    private var allItems: [InventoryItem]

    private var ownedItems: [InventoryItem] {
        allItems.filter { $0.status == .owned }
    }

    var body: some View {
        NavigationStack {
            List {
                if ownedItems.isEmpty {
                    ContentUnavailableView(
                        "No paints yet",
                        systemImage: "paintbrush",
                        description: Text("Tap + to add your first paint.")
                    )
                } else {
                    ForEach(ownedItems) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.paint.name)
                                .font(.headline)

                            Text("\(item.paint.brand.rawValue) • \(item.paint.range) • \(item.paint.manufacturerCode)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            if let barcode = item.paint.barcode, !barcode.isEmpty {
                                Text("Barcode: \(barcode)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete(perform: deleteItems)
                }
            }
            .navigationTitle("Collection")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddPaint = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddPaint) {
                AddPaintView(initialStatus: .owned)
            }
        }
    }

    private func deleteItems(at offsets: IndexSet) {
        let toDelete = offsets.map { ownedItems[$0] }
        for item in toDelete {
            modelContext.delete(item)
        }
    }
}
