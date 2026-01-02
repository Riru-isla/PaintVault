import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ImportCSVView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var showingImporter = false

    // Sample CSV exporter
    @State private var showingSampleExporter = false
    @State private var sampleDocument = CSVDocument(text: "")

    @State private var statusMessage: String = "Choose a CSV file to import."
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Import") {
                    Text(statusMessage)

                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }

                    Button {
                        showingImporter = true
                    } label: {
                        Label("Select CSV file…", systemImage: "doc")
                    }
                }

                Section("Expected columns") {
                    Text("brand, range, type, manufacturerCode, name, barcode, collectionQuantity")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Button {
                        sampleDocument = CSVDocument(text: sampleCSVText())
                        showingSampleExporter = true
                    } label: {
                        Label("Download sample CSV", systemImage: "arrow.down.doc")
                    }
                }

                Section("Rules") {
                    Text("• Always creates/updates the paint in the catalog.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Text("• If collectionQuantity > 0, creates/updates an Owned inventory entry with that exact quantity.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Import CSV")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: [.commaSeparatedText, .plainText],
                allowsMultipleSelection: false
            ) { result in
                handleImportResult(result)
            }
            .fileExporter(
                isPresented: $showingSampleExporter,
                document: sampleDocument,
                contentType: .commaSeparatedText,
                defaultFilename: "PrintVault_Sample"
            ) { _ in
                // No-op. User chooses where to save/share.
            }
        }
    }

    private func sampleCSVText() -> String {
        """
        brand,range,type,manufacturerCode,name,barcode,collectionQuantity
        Vallejo,Game Color,Base,72.001,Dead White,,1
        AK Interactive,3rd Gen,Acrylic Color,AK11187,Strong Dark Blue,,1
        """
    }

    private func handleImportResult(_ result: Result<[URL], Error>) {
        errorMessage = nil

        do {
            guard let url = try result.get().first else { return }

            // Needed for Files app access
            guard url.startAccessingSecurityScopedResource() else {
                errorMessage = "Could not access the selected file."
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            let data = try Data(contentsOf: url)
            guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
                errorMessage = "Could not read the file as text."
                return
            }

            let report = try importCatalogCSV(text)
            statusMessage = "Imported \(report.paintsUpserted) paints, updated \(report.collectionUpdated) collection entries."
        } catch {
            errorMessage = "Import failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Import logic

    private func importCatalogCSV(_ csv: String) throws -> ImportReport {
        let lines = csv
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map(String.init)

        guard !lines.isEmpty else {
            return ImportReport(paintsUpserted: 0, collectionUpdated: 0)
        }

        // Strip BOM that may appear at the start of UTF-8 files
        let headerLineRaw = lines[0].replacingOccurrences(of: "\u{FEFF}", with: "")
        // Detect delimiter from the header line (favor ';' if commas are absent)
        let delimiter: Character = {
            if headerLineRaw.contains(";") && !headerLineRaw.contains(",") { return ";" }
            return ","
        }()

        let header = parseCSVLine(headerLineRaw, delimiter: delimiter)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let index = indexMap(header)

        // Required columns
        for key in ["brand", "range", "type", "manufacturercode", "name"] {
            if index[key] == nil {
                throw ImportError.missingColumn(key)
            }
        }

        var paintsUpserted = 0
        var collectionUpdated = 0

        for line in lines.dropFirst() {
            let cols = parseCSVLine(line, delimiter: delimiter)

            let brandStr = value(cols, index, "brand")
            let range = value(cols, index, "range")
            let typeStr = value(cols, index, "type")
            let code = value(cols, index, "manufacturercode").uppercased()
            let name = value(cols, index, "name")

            let barcode = optionalValue(cols, index, "barcode")
            let qtyStr = optionalValue(cols, index, "collectionquantity")

            let brand = PaintBrand(rawValue: brandStr) ?? .other
            let type = PaintType(rawValue: typeStr) ?? .other

            // Upsert Paint
            let paint = try findPaint(brand: brand, range: range, manufacturerCode: code)
                ?? Paint(brand: brand, range: range, type: type, manufacturerCode: code, name: name, barcode: nil)

            // If new, insert
            if paint.persistentModelID == nil {
                modelContext.insert(paint)
            }

            // Update fields (MVP behavior: overwrite with import)
            paint.brand = brand
            paint.range = range
            paint.type = type
            paint.manufacturerCode = code
            paint.name = name
            if let barcode, !barcode.isEmpty {
                paint.barcode = barcode
            }

            paintsUpserted += 1

            // Upsert collection quantity if > 0
            if let qtyStr,
               let qty = Int(qtyStr.trimmingCharacters(in: .whitespacesAndNewlines)),
               qty > 0 {
                let updated = try upsertOwnedQuantity(paint: paint, quantity: qty)
                if updated { collectionUpdated += 1 }
            }
        }

        return ImportReport(paintsUpserted: paintsUpserted, collectionUpdated: collectionUpdated)
    }

    private func findPaint(brand: PaintBrand, range: String, manufacturerCode: String) throws -> Paint? {
        let b = brand.rawValue
        let r = range
        let c = manufacturerCode

        let descriptor = FetchDescriptor<Paint>(
            predicate: #Predicate { p in
                p.brandRaw == b && p.range == r && p.manufacturerCode == c
            }
        )
        return try modelContext.fetch(descriptor).first
    }

    /// Sets Owned quantity to exactly `quantity` (creates the InventoryItem if needed).
    private func upsertOwnedQuantity(paint: Paint, quantity: Int) throws -> Bool {
        let brand = paint.brandRaw
        let range = paint.range
        let code = paint.manufacturerCode
        let statusRaw = InventoryStatus.owned.rawValue

        let descriptor = FetchDescriptor<InventoryItem>(
            predicate: #Predicate { item in
                item.statusRaw == statusRaw &&
                item.paint.brandRaw == brand &&
                item.paint.range == range &&
                item.paint.manufacturerCode == code
            }
        )

        if let existing = try modelContext.fetch(descriptor).first {
            existing.quantity = quantity
            return true
        } else {
            let item = InventoryItem(paint: paint, status: .owned, quantity: quantity)
            modelContext.insert(item)
            return true
        }
    }

    // MARK: - CSV helpers

    private func indexMap(_ header: [String]) -> [String: Int] {
        var map: [String: Int] = [:]
        for (i, h) in header.enumerated() {
            map[h.lowercased()] = i
        }
        return map
    }

    private func value(_ cols: [String], _ index: [String: Int], _ key: String) -> String {
        let k = key.lowercased()
        guard let i = index[k], i < cols.count else { return "" }
        return cols[i].trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func optionalValue(_ cols: [String], _ index: [String: Int], _ key: String) -> String? {
        let v = value(cols, index, key)
        return v.isEmpty ? nil : v
    }

    /// Minimal CSV line parser supporting quoted fields and a configurable delimiter.
    private func parseCSVLine(_ line: String, delimiter: Character = ",") -> [String] {
        var result: [String] = []
        var current = ""
        var inQuotes = false

        let chars = Array(line)
        var i = 0

        while i < chars.count {
            let ch = chars[i]

            if ch == "\"" {
                if inQuotes, i + 1 < chars.count, chars[i + 1] == "\"" {
                    // Escaped quote ""
                    current.append("\"")
                    i += 2
                    continue
                } else {
                    inQuotes.toggle()
                    i += 1
                    continue
                }
            }

            if ch == delimiter && !inQuotes {
                result.append(current)
                current = ""
                i += 1
                continue
            }

            current.append(ch)
            i += 1
        }

        result.append(current)
        return result
    }
}

// MARK: - Support types

struct ImportReport {
    let paintsUpserted: Int
    let collectionUpdated: Int
}

enum ImportError: LocalizedError {
    case missingColumn(String)

    var errorDescription: String? {
        switch self {
        case .missingColumn(let col):
            return "Missing required column: \(col)"
        }
    }
}

struct CSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText, .plainText] }

    var text: String

    init(text: String) {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents,
           let str = String(data: data, encoding: .utf8) {
            self.text = str
        } else {
            self.text = ""
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

