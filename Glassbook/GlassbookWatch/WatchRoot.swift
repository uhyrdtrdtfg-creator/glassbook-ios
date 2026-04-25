import SwiftUI

struct WatchRoot: View {
    @Binding var snapshot: WatchSnapshot

    var body: some View {
        TabView {
            watchPage {
                WatchHomeView(snapshot: snapshot)
            }
            .tag(0)

            watchPage {
                WatchRecentView(snapshot: snapshot)
            }
            .tag(1)

            watchPage {
                WatchQuickAddView()
            }
            .tag(2)
        }
        .tabViewStyle(.page)
    }

    private func watchPage<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.13, green: 0.14, blue: 0.21), Color(red: 0.09, green: 0.11, blue: 0.17)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            content()
                .padding(8)
        }
    }
}
