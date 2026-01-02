import SwiftUI
import SwiftData

struct WishlistView: View {
    @Environment(\.modelContext) private var modelContext

    // Only wishlist items, sorted by paint name
    @Query(
        filter: #Predicate<InventoryItem> { item in
    // NOTE: Using string literal because SwiftData #Predicate sometimes fails with enum cases.
            item.statusRaw == "wishlist"
        },
        sort: [SortDescriptor(\InventoryItem.paint.name)]
    )
    private var wishlistItems: [InventoryItem]

    // Toast state
    @State private var toastMessage: String?
    @State private var toastTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {

                if wishlistItems.isEmpty {
                    ContentUnavailableView(
                        "Wishlist is empty",
                        systemImage: "heart",
                        description: Text("Add paints from Search or from the Paint detail screen.")
                    )
                } else {
                    List {
                        ForEach(wishlistItems) { item in
                            NavigationLink {
                                PaintDetailView(paint: item.paint)
                            } label: {
                                row(item)
                            }
                            // 👉 Swipe RIGHT: Bought it
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button {
                                    boughtIt(item)
                                } label: {
                                    Label("Bought it", systemImage: "checkmark.seal.fill")
                                }
                            }
                            // 👉 Swipe LEFT: Delete
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    delete(item)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                        .onDelete(perform: deleteAtOffsets)
                    }
                }

                // Toast overlay
                if let toastMessage {
                    ToastView(message: toastMessage)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.easeInOut, value: toastMessage)
            .navigationTitle("Wishlist")
        }
    }

    // MARK: - Row UI

    @ViewBuilder
    private func row(_ item: InventoryItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.paint.name)
                .font(.headline)

            Text("\(item.paint.brand.rawValue) • \(item.paint.range) • \(item.paint.type.rawValue)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack {
                Text(item.paint.manufacturerCode)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if item.quantity > 1 {
                    Text("x\(item.quantity)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Actions

    private func boughtIt(_ item: InventoryItem) {
        do {
            // 1) Remove from wishlist
            modelContext.delete(item)

            // 2) Add/increment in collection
            let outcome = try addOrIncrementInventoryItem(
                paint: item.paint,
                status: .owned,
                modelContext: modelContext
            )

            switch outcome {
            case .addedNew:
                showToast("Bought it → moved to Collection ✅")
            case .incremented(let qty):
                showToast("Bought it → Collection quantity: \(qty)")
            }
        } catch {
            showToast("Error moving item")
        }
    }

    private func delete(_ item: InventoryItem) {
        modelContext.delete(item)
        showToast("Removed from Wishlist 🗑️")
    }

    private func deleteAtOffsets(_ offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(wishlistItems[index])
        }
        showToast("Removed from Wishlist 🗑️")
    }

    private func showToast(_ message: String) {
        toastTask?.cancel()
        toastMessage = message

        toastTask = Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            if !Task.isCancelled {
                await MainActor.run { toastMessage = nil }
            }
        }
    }
}
