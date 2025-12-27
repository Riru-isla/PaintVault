import SwiftUI
import SwiftData

@main
struct PrintVaultApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Paint.self, InventoryItem.self])
    }
}
