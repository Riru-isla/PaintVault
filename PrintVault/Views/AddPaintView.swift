import SwiftUI
import SwiftData

struct AddPaintView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    // Default status comes from where you opened the sheet (Collection/Wishlist)
    let initialStatus: InventoryStatus

    // ✅ New dropdown-backed fields
    @State private var brand: PaintBrand = .vallejo
    @State private var type: PaintType = .base

    // Existing fields
    @State private var range: String = ""
    @State private var manufacturerCode: String = ""
    @State private var name: String = ""
    @State private var barcode: String = ""

    @State private var status: InventoryStatus
    @State private var quantity: Int = 1
    @State private var notes: String = ""

    @State private var errorMessage: String?

    init(initialStatus: InventoryStatus) {
        self.initialStatus = initialStatus
        _status = State(initialValue: initialStatus)
    }

    var body: some View {
        NavigationStack {
            Form {
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }

                Section("Paint") {
                    // ✅ Brand picker
                    Picker("Brand", selection: $brand) {
                        ForEach(PaintBrand.allCases, id: \.self) { b in
                            Text(b.rawValue).tag(b)
                        }
                    }

                    TextField("Range (e.g. Game Color, Model Color, Contrast)", text: $range)
                        .textInputAutocapitalization(.words)

                    // ✅ Type picker
                    Picker("Type", selection: $type) {
                        ForEach(PaintType.allCases, id: \.self) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }

                    TextField("Manufacturer code (e.g. 72.001 / AK11187)", text: $manufacturerCode)
                        .textInputAutocapitalization(.characters)

                    TextField("Name (e.g. Dead White)", text: $name)
                        .textInputAutocapitalization(.words)

                    TextField("Barcode (optional)", text: $barcode)
                        .keyboardType(.numberPad)
                }

                Section("Inventory") {
                    Picker("Add to", selection: $status) {
                        ForEach(InventoryStatus.allCases, id: \.self) { s in
                            Text(s.title).tag(s)
                        }
                    }

                    Stepper("Quantity: \(quantity)", value: $quantity, in: 1...99)

                    TextField("Notes (optional)", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .navigationTitle("Add Paint")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
        }
    }

    private var canSave: Bool {
        !range.trimmed.isEmpty &&
        !manufacturerCode.trimmed.isEmpty &&
        !name.trimmed.isEmpty
    }

    private func save() {
        errorMessage = nil

        let rangeN = range.trimmed
        let codeN = manufacturerCode.trimmed.uppercased()
        let nameN = name.trimmed
        let barcodeN = barcode.trimmed
        let notesN = notes.trimmed

        // Try to reuse existing Paint by (brand, range, manufacturerCode)
        let existingPaint = findPaint(brand: brand, range: rangeN, manufacturerCode: codeN)

        let paint: Paint
        if let existingPaint {
            paint = existingPaint

            // Keep catalog info up to date (safe defaults)
            paint.type = type
            paint.name = nameN

            if !barcodeN.isEmpty, (paint.barcode ?? "").isEmpty {
                paint.barcode = barcodeN
            }
        } else {
            paint = Paint(
                brand: brand,
                range: rangeN,
                type: type,
                manufacturerCode: codeN,
                name: nameN,
                barcode: barcodeN.isEmpty ? nil : barcodeN
            )
            modelContext.insert(paint)
        }

        let item = InventoryItem(
            paint: paint,
            status: status,
            quantity: quantity,
            notes: notesN.isEmpty ? nil : notesN
        )
        modelContext.insert(item)

        dismiss()
    }

    private func findPaint(brand: PaintBrand, range: String, manufacturerCode: String) -> Paint? {
        let descriptor = FetchDescriptor<Paint>(
            predicate: #Predicate { p in
                p.brandRaw == brand.rawValue &&
                p.range == range &&
                p.manufacturerCode == manufacturerCode
            }
        )

        do {
            return try modelContext.fetch(descriptor).first
        } catch {
            errorMessage = "Could not check existing paints. Try again."
            return nil
        }
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
