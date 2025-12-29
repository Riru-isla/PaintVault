import SwiftUI
import SwiftData

struct WishlistView: View {
    @State private var showingAddPaint = false
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \InventoryItem.createdAt, order: .reverse)
    private var allItems: [InventoryItem]

    private var wishlistItems: [InventoryItem] {
        allItems.filter { $0.status == .wishlist }
    }

    var body: some View {
        NavigationStack {
            List {
                if wishlistItems.isEmpty {
                    ContentUnavailableView(
                        "Wishlist is empty",
                        systemImage: "heart",
                        description: Text("Tap + to add paints you want to buy.")
                    )
                } else {
                    ForEach(wishlistItems) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.paint.name)
                                .font(.headline)

                            Text("\(item.paint.brand.rawValue) • \(item.paint.range) • \(item.paint.manufacturerCode)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete(perform: deleteItems)
                }
            }
            .navigationTitle("Wishlist")
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
                AddPaintView(initialStatus: .wishlist)
            }
        }
    }

    private func deleteItems(at offsets: IndexSet) {
        let toDelete = offsets.map { wishlistItems[$0] }
        for item in toDelete {
            modelContext.delete(item)
        }
    }
}
