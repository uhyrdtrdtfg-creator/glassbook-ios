import SwiftUI
import SwiftData

@main
struct GlassbookApp: App {
    /// Disk-backed container is constructed once at launch.
    /// Flip `useCloudKit` to true after enabling the iCloud capability (Spec §8.2).
    private let container: ModelContainer = PersistenceController.makeDiskContainer(useCloudKit: true)

    @State private var store: AppStore
    @State private var lock = AppLock()
    // Item 18 · 去单例 — reuse the same instance as `.shared` so the env-injected
    // store and the service-layer fallback share UserDefaults / Keychain state.
    @State private var aiEngines = AIEngineStore.shared
    @State private var webhooks = WebhookStore.shared
    @Environment(\.scenePhase) private var scenePhase

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
                    .environment(aiEngines)
                    .environment(webhooks)
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
            .onOpenURL { url in
                // PhoneClaw RPC callback — 唤回 Glassbook 时 URL 形如
                // glassbook://phoneclaw-result?id=<uuid>
                _ = PhoneClawClient.resolve(url: url)
            }
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .background: lock.handleBackground()
                case .active:
                    lock.handleForeground()
                    // Pick up anything the AppIntent shortcut dropped in the
                    // App Group queue while we were backgrounded so "最近交易"
                    // shows the new entry the moment user returns.
                    store.drainPendingImports()
                    Task { await CurrencyService.shared.refreshIfStale() }
                default: break
                }
            }
        }
        .modelContainer(container)
    }
}
