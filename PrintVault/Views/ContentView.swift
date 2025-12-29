import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
            
            CollectionView()
                .tabItem { Label("Collection", systemImage: "paintbrush") }

            WishlistView()
                .tabItem { Label("Wishlist", systemImage: "heart") }

            AdminView()
                .tabItem { Label("Admin", systemImage: "barcode.viewfinder") }
        }
    }
}
