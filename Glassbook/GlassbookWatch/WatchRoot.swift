import SwiftUI

struct WatchRoot: View {
    @Binding var snapshot: WatchSnapshot

    var body: some View {
        TabView {
            WatchHomeView(snapshot: snapshot)
                .tag(0)
            WatchRecentView(snapshot: snapshot)
                .tag(1)
            WatchQuickAddView()
                .tag(2)
        }
        .tabViewStyle(.page)
    }
}
