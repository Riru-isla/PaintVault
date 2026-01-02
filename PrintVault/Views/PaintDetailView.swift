import SwiftUI
import SwiftData

struct PaintDetailView: View {
    @Environment(\.modelContext) private var modelContext
    
    @Query private var inventoryItems: [InventoryItem]
    
    let paint: Paint

    // Toast state (no extra taps)
    @State private var toastMessage: String?
    @State private var toastTask: Task<Void, Never>?

    var body: some View {
        ZStack(alignment: .top) {

            Form {
                Section("Paint") {
                    Text(paint.name).font(.headline)
                    Text(paint.manufacturerCode)
                        .foregroundStyle(.secondary)
                }

                Section("Details") {
                    Text("Brand: \(paint.brand.rawValue)")
                    Text("Range: \(paint.range)")
                    Text("Type: \(paint.type.rawValue)")

                    if let barcode = paint.barcode, !barcode.isEmpty {
                        Text("Barcode: \(barcode)")
                    }
                }

                Section("Status") {
                    if flags.inCollection {
                        Label("In collection", systemImage: "checkmark.square.fill")
                            .foregroundStyle(.green)
                    }
                    if flags.inWishlist {
                        Label("In wishlist", systemImage: "heart.fill")
                            .foregroundStyle(.red)
                    }

                    if !flags.inCollection && !flags.inWishlist {
                        Text("Not in collection or wishlist")
                            .foregroundStyle(.secondary)
                    }
                }

                
                Section("Actions") {
                    Button {
                        addToInventory(status: .owned)
                    } label: {
                        Label("Add to Collection", systemImage: "paintbrush")
                    }

                    Button {
                        addToInventory(status: .wishlist)
                    } label: {
                        Label("Add to Wishlist", systemImage: "heart")
                    }
                }
            }
            .navigationTitle("Paint")

            // ✅ Toast overlay (no taps)
            if let toastMessage {
                ToastView(message: toastMessage)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut, value: toastMessage)
    }

    private func addToInventory(status: InventoryStatus) {
        do {
            let outcome = try addOrIncrementInventoryItem(
                paint: paint,
                status: status,
                modelContext: modelContext
            )

            switch outcome {
            case .addedNew:
                showToast(status == .owned ? "Added to Collection ✅" : "Added to Wishlist ❤️")
            case .incremented(let qty):
                showToast("Already there — quantity: \(qty)")
            }
        } catch {
            showToast("Error updating inventory")
        }
    }

    private func showToast(_ message: String) {
        toastTask?.cancel()
        toastMessage = message

        toastTask = Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000) // 1.2 seconds
            if !Task.isCancelled {
                await MainActor.run {
                    toastMessage = nil
                }
            }
        }
    }
    
    private struct PaintInventoryFlags {
        let inCollection: Bool
        let inWishlist: Bool
    }

    private var flags: PaintInventoryFlags {
        let brand = paint.brandRaw
        let range = paint.range
        let code = paint.manufacturerCode

        let itemsForPaint = inventoryItems.filter { item in
            item.paint.brandRaw == brand &&
            item.paint.range == range &&
            item.paint.manufacturerCode == code
        }

        return PaintInventoryFlags(
            inCollection: itemsForPaint.contains { $0.status == .owned },
            inWishlist: itemsForPaint.contains { $0.status == .wishlist }
        )
    }

}
