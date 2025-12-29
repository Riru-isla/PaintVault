import SwiftUI
import SwiftData

struct CatalogView: View {
    @Query(sort: [SortDescriptor(\Paint.brandRaw), SortDescriptor(\Paint.range), SortDescriptor(\Paint.manufacturerCode)])
    private var paints: [Paint]

    @State private var searchText: String = ""

    private var filtered: [Paint] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return paints }

        return paints.filter { p in
            p.name.lowercased().contains(q) ||
            p.manufacturerCode.lowercased().contains(q) ||
            p.brandRaw.lowercased().contains(q) ||
            p.range.lowercased().contains(q) ||
            p.typeRaw.lowercased().contains(q) ||
            ((p.barcode ?? "").lowercased().contains(q))
        }
    }

    var body: some View {
        List {
            if filtered.isEmpty {
                ContentUnavailableView(
                    "No paints found",
                    systemImage: "magnifyingglass",
                    description: Text("Try another search, or add paints from Admin.")
                )
            } else {
                ForEach(filtered) { paint in
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
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Catalog")
        .searchable(text: $searchText, prompt: "Search code, name, brand…")
    }
}
