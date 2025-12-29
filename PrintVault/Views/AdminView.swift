import SwiftUI
import SwiftData

struct AdminView: View {
    @State private var showingAddPaint = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ContentUnavailableView(
                        "Admin tools",
                        systemImage: "gearshape",
                        description: Text("Add paints to your catalog and prepare barcode scanning later.")
                    )
                    .frame(maxWidth: .infinity)
                    .listRowInsets(EdgeInsets())
                    .padding(.vertical, 12)
                }

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
                }

                Section("Import / Export") {
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
            }
            .navigationTitle("Admin")
            .sheet(isPresented: $showingAddPaint) {
                // We keep the unified view, but default to "owned" or "wishlist" doesn’t matter here.
                // Use owned as default; you can change it inside the picker.
                AddPaintView(initialStatus: .owned)
            }
        }
    }
}
