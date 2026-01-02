import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext

    // All paints from the catalog
    @Query(sort: [SortDescriptor(\Paint.name)])
    private var allPaints: [Paint]

    @Query private var inventoryItems: [InventoryItem]
    
    // UI state
    @State private var searchText: String = ""
    @State private var showingAddPaint = false

    // Toast state (no extra taps)
    @State private var toastMessage: String?
    @State private var toastTask: Task<Void, Never>?

    // Search logic: ONLY name + manufacturer code
    private var filteredPaints: [Paint] {
        let q = searchText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard !q.isEmpty else { return [] }

        return allPaints.filter { paint in
            paint.name.lowercased().contains(q) ||
            paint.manufacturerCode.lowercased().contains(q)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {

                VStack(spacing: 12) {

                    // 🔍 Search row (search field + camera button)
                    HStack {
                        TextField("Search paint name or code", text: $searchText)
                            .textFieldStyle(.roundedBorder)
                            .submitLabel(.search)

                        Button {
                            // Barcode scanning later
                        } label: {
                            Image(systemName: "camera")
                                .font(.title2)
                        }
                        .disabled(true) // placeholder for now
                    }
                    .padding(.horizontal)

                    // 📋 Results / empty states
                    if searchText.isEmpty {
                        Spacer()
                        ContentUnavailableView(
                            "Search for a paint",
                            systemImage: "magnifyingglass",
                            description: Text("Type a paint name or manufacturer code.")
                        )
                        Spacer()

                    } else if filteredPaints.isEmpty {
                        Spacer()
                        ContentUnavailableView(
                            "No results",
                            systemImage: "xmark.circle",
                            description: Text("No paints match your search.")
                        )
                        Spacer()

                    } else {
                        List(filteredPaints) { paint in
                            NavigationLink {
                                PaintDetailView(paint: paint)
                            } label: {
                                let flags = inventoryFlags(for: paint)

                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(paint.name)
                                            .font(.headline)

                                        Text("\(paint.brand.rawValue) • \(paint.range) • \(paint.type.rawValue)")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)

                                        Text(paint.manufacturerCode)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    HStack(spacing: 6) {
                                        if flags.inCollection {
                                            Image(systemName: "checkmark.square.fill")
                                                .foregroundStyle(.green)
                                        }
                                        if flags.inWishlist {
                                            Image(systemName: "heart.fill")
                                                .foregroundStyle(.red)
                                        }
                                    }
                                    .imageScale(.large)
                                }
                                .padding(.vertical, 4)
                            }

                            // 👉 Swipe RIGHT → Add to Collection
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button {
                                    quickAdd(paint: paint, status: .owned)
                                } label: {
                                    Label("Collection", systemImage: "paintbrush")
                                }
                            }
                            // 👉 Swipe LEFT → Add to Wishlist
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button {
                                    quickAdd(paint: paint, status: .wishlist)
                                } label: {
                                    Label("Wishlist", systemImage: "heart")
                                }
                            }
                        }
                    }
                }
                .navigationTitle("Paint Vault")
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

                // ✅ Toast overlay (no taps)
                if let toastMessage {
                    ToastView(message: toastMessage)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.easeInOut, value: toastMessage)
        }
    }

    
    private struct PaintInventoryFlags {
        let inCollection: Bool
        let inWishlist: Bool
    }

    private func inventoryFlags(for paint: Paint) -> PaintInventoryFlags {
        // Match inventory items to this paint using the same identity fields we use elsewhere
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

    // MARK: - Quick add logic (used by swipe actions)

    private func quickAdd(paint: Paint, status: InventoryStatus) {
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
}
