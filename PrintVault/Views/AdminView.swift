import SwiftUI
import SwiftData

struct AdminView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var showingAddPaint = false
    @State private var confirmResetInventory = false
    @State private var confirmResetAll = false

    // Toast state
    @State private var toastMessage: String?
    @State private var toastTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Form {
                    Section("Catalog") {
                        Button {
                            showingAddPaint = true
                        } label: {
                            Label("Add paint to catalog", systemImage: "plus")
                        }

                        NavigationLink {
                            CatalogView()
                        } label: {
                            Label("View catalog", systemImage: "paintpalette")
                        }

                        NavigationLink {
                            ImportCSVView()
                        } label: {
                            Label("Import catalog CSV", systemImage: "square.and.arrow.down")
                        }
                    }

                    Section("Coming soon") {
                        Label("Scan barcodes (mapping mode)", systemImage: "barcode.viewfinder")
                            .foregroundStyle(.secondary)
                    }

                    Section("Danger Zone") {
                        Button("Reset inventory (keep catalog)", role: .destructive) {
                            confirmResetInventory = true
                        }

                        Button("Reset EVERYTHING (catalog + inventory)", role: .destructive) {
                            confirmResetAll = true
                        }
                    }
                }
                .navigationTitle("Admin")
                .sheet(isPresented: $showingAddPaint) {
                    // You mentioned you want unified AddPaintView — status doesn't matter here
                    AddPaintView(initialStatus: .owned)
                }
                .confirmationDialog(
                    "Reset inventory?",
                    isPresented: $confirmResetInventory,
                    titleVisibility: .visible
                ) {
                    Button("Reset inventory", role: .destructive) {
                        do {
                            try ResetService.reset(.inventoryOnly, modelContext: modelContext)
                            showToast("Inventory reset ✅")
                        } catch {
                            showToast("Failed to reset inventory")
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This will remove all Collection and Wishlist entries, but keep your paint catalog.")
                }
                .confirmationDialog(
                    "Reset EVERYTHING?",
                    isPresented: $confirmResetAll,
                    titleVisibility: .visible
                ) {
                    Button("Reset EVERYTHING", role: .destructive) {
                        do {
                            try ResetService.reset(.everything, modelContext: modelContext)
                            showToast("Catalog + inventory reset ✅")
                        } catch {
                            showToast("Failed to reset everything")
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This will delete your entire catalog and inventory. You will need to import CSV again.")
                }

                // Toast overlay
                if let toastMessage {
                    ToastView(message: toastMessage)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.easeInOut, value: toastMessage)
        }
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
