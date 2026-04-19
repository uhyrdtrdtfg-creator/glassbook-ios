import SwiftUI
import SwiftData

@main
struct GlassbookApp: App {
    /// Disk-backed container is constructed once at launch.
    /// Flip `useCloudKit` to true after enabling the iCloud capability (Spec §8.2).
    private let container: ModelContainer = PersistenceController.makeDiskContainer(useCloudKit: true)

    @State private var store: AppStore
    @State private var lock = AppLock()

    init() {
        let c = PersistenceController.makeDiskContainer(useCloudKit: true)
        _store = State(initialValue: AppStore(container: c))
        // Route merchant learning through a sibling context (same container → same SQLite).
        MerchantClassifier.shared.attach(context: ModelContext(c))
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootView()
                    .environment(store)
                    .environment(lock)
                    .preferredColorScheme(.light)
                    .tint(AppColors.ink)

                if lock.isLocked {
                    LockView()
                        .environment(lock)
                        .transition(.opacity)
                        .zIndex(100)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: lock.isLocked)
        }
        .modelContainer(container)
    }
}
