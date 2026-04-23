import SwiftUI

struct ContentView: View {
    @StateObject private var store = DataStore()
    @StateObject private var nav   = NavState()

    var body: some View {
        TabView(selection: $nav.mainTab) {
            HomeView()
                .tabItem { Label("Home",    systemImage: "house.fill") }
                .tag("Home")
            SpendView()
                .tabItem { Label("Spend",   systemImage: "chart.line.uptrend.xyaxis") }
                .tag("Spend")
            ManagerView()
                .tabItem { Label("Manager", systemImage: "chart.pie.fill") }
                .tag("Manager")
            MoreView()
                .tabItem { Label("More",    systemImage: "ellipsis.circle.fill") }
                .tag("More")
        }
        .environmentObject(store)
        .environmentObject(nav)
    }
}

#Preview { ContentView() }
