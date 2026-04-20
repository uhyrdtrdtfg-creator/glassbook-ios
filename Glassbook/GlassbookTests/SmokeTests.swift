import Testing
import SwiftUI
@testable import Glassbook

/// Smoke tests — just construct each top-level view so any dependency/protocol
/// regression surfaces at test time, not at runtime.
@Suite("View smoke") @MainActor
struct ViewSmokeTests {
    private var store: AppStore { AppStore() }
    private var lock: AppLock { let l = AppLock(); l.skipAuth = true; return l }

    @Test func rootViewBuilds() {
        _ = RootView().environment(store).environment(lock)
    }
    @Test func homeViewBuilds() {
        _ = HomeView().environment(store)
    }
    @Test func billsViewBuilds() {
        _ = BillsView().environment(store)
    }
    @Test func statsViewBuilds() {
        _ = StatsView().environment(store)
    }
    @Test func budgetViewBuilds() {
        _ = BudgetView().environment(store)
    }
    @Test func profileViewBuilds() {
        _ = ProfileView().environment(store)
    }
    @Test func addTransactionBuildsWithoutPrefill() {
        _ = AddTransactionView().environment(store)
    }
    @Test func addTransactionBuildsWithPrefill() {
        let result = ReceiptOCRService.fakeReceipt()
        _ = AddTransactionView(prefill: result).environment(store)
    }
    @Test func subscriptionsViewBuilds() {
        _ = SubscriptionsView().environment(store)
    }
    @Test func goalsViewBuilds() {
        _ = GoalsView().environment(store)
    }
    @Test func accountsViewBuilds() {
        _ = AccountsView().environment(store)
    }
    @Test func annualWrapViewBuilds() {
        _ = AnnualWrapView().environment(store)
    }
    @Test func insightsViewBuilds() {
        _ = InsightsView().environment(store)
    }
    @Test func sunkCostViewBuilds() {
        _ = SunkCostView().environment(store)
    }
    @Test func familyBookViewBuilds() {
        _ = FamilyBookView().environment(store)
    }
    @Test func advisorViewBuilds() {
        _ = AdvisorView().environment(store)
    }
    @Test func invoiceExportViewBuilds() {
        _ = InvoiceExportView().environment(store)
    }
    @Test func aiEngineSettingsBuilds() {
        _ = AIEngineSettingsView()
    }
    @Test func webhookSettingsBuilds() {
        _ = WebhookSettingsView()
    }
    @Test func automationSettingsBuilds() {
        _ = AutomationSettingsView()
    }
    @Test func lockViewBuilds() {
        _ = LockView().environment(lock)
    }
    @Test func receiptScanSheetBuilds() {
        _ = ReceiptScanSheet(onConfirm: { _ in }, onCancel: {})
    }
    @Test func smartImportFlowBuilds() {
        var presented = true
        let binding = Binding(get: { presented }, set: { presented = $0 })
        _ = SmartImportFlow(isPresented: binding).environment(store)
    }
    @Test func auroraBackgroundBuildsAllPalettes() {
        for p in AuroraPalette.allCases {
            _ = AuroraBackground(palette: p)
        }
    }
}

@Suite("AppLock") @MainActor
struct AppLockTests {
    @Test func initialStateIsLocked() {
        UserDefaults.standard.removeObject(forKey: "applock.last.unlocked")
        UserDefaults.standard.removeObject(forKey: "applock.last.backgrounded")
        #expect(AppLock().isLocked == true)
    }
    @Test func skipAuthUnlocksWithoutBiometrics() async {
        let lock = AppLock()
        lock.skipAuth = true
        await lock.unlock()
        #expect(lock.isLocked == false)
    }
    @Test func lockResetsState() async {
        let lock = AppLock()
        lock.skipAuth = true
        await lock.unlock()
        lock.lock()
        #expect(lock.isLocked == true)
    }
    @Test func guestModeToggle() {
        let lock = AppLock()
        #expect(lock.isGuestMode == false)
        lock.toggleGuestMode()
        #expect(lock.isGuestMode == true)
    }

    /// Spec §8.4 · faceIDEnabled=false → app never locks at launch.
    @Test func disablingFaceIDStartsUnlocked() {
        let d = UserDefaults.standard
        d.set(false, forKey: "applock.faceid.enabled")
        d.set(300,   forKey: "applock.grace.seconds")
        defer {
            d.removeObject(forKey: "applock.faceid.enabled")
            d.removeObject(forKey: "applock.grace.seconds")
        }
        #expect(AppLock().isLocked == false)
    }

    /// Grace period -1 ("信任设备 · 永不重锁") skips lock.
    @Test func neverGraceStartsUnlocked() {
        let d = UserDefaults.standard
        d.set(true, forKey: "applock.faceid.enabled")
        d.set(-1,   forKey: "applock.grace.seconds")
        defer {
            d.removeObject(forKey: "applock.faceid.enabled")
            d.removeObject(forKey: "applock.grace.seconds")
        }
        #expect(AppLock().isLocked == false)
    }

    /// Recent unlock within grace period keeps session warm on cold start.
    @Test func recentUnlockWithinGraceSkipsLock() {
        let d = UserDefaults.standard
        d.set(true, forKey: "applock.faceid.enabled")
        d.set(300,  forKey: "applock.grace.seconds")
        d.set(Date(), forKey: "applock.last.unlocked")
        defer {
            d.removeObject(forKey: "applock.faceid.enabled")
            d.removeObject(forKey: "applock.grace.seconds")
            d.removeObject(forKey: "applock.last.unlocked")
        }
        #expect(AppLock().isLocked == false)
    }

    /// Stale unlock older than grace → must re-authenticate.
    @Test func staleUnlockBeyondGraceLocks() {
        let d = UserDefaults.standard
        d.set(true, forKey: "applock.faceid.enabled")
        d.set(60,   forKey: "applock.grace.seconds")
        d.set(Date().addingTimeInterval(-600), forKey: "applock.last.unlocked")
        d.removeObject(forKey: "applock.last.backgrounded")
        defer {
            d.removeObject(forKey: "applock.faceid.enabled")
            d.removeObject(forKey: "applock.grace.seconds")
            d.removeObject(forKey: "applock.last.unlocked")
        }
        #expect(AppLock().isLocked == true)
    }

    @Test func foregroundAfterShortBackgroundKeepsUnlocked() async {
        let lock = AppLock()
        lock.skipAuth = true
        await lock.unlock()
        lock.handleBackground()
        lock.gracePeriodSeconds = 300
        lock.handleForeground()
        #expect(lock.isLocked == false)
    }
}

@Suite("AIEngineStore") @MainActor
struct AIEngineStoreTests {
    @Test func engineMetadataPresent() {
        for e in AIEngineStore.Engine.allCases {
            #expect(!e.displayName.isEmpty)
            #expect(!e.emoji.isEmpty)
            #expect(e.tintHex > 0)
            #expect(!e.keychainAccount.isEmpty)
        }
    }
    @Test func configForEngineReturnsDefaults() {
        let s = AIEngineStore.shared
        let cfg = s.config(for: .openAI)
        #expect(cfg.engine == .openAI)
        #expect(cfg.baseURL == AIEngineStore.Engine.openAI.defaultBaseURL)
    }
    @Test func setAPIKeyRoundtrip() {
        let s = AIEngineStore.shared
        let key = "sk-test-\(UUID())"
        s.setAPIKey(key, for: .openAI)
        #expect(s.apiKey(for: .openAI) == key)
        s.setAPIKey("", for: .openAI)
    }
    @Test func selectEngineUpdates() {
        let s = AIEngineStore.shared
        let before = s.selected
        s.selectEngine(.gemini)
        #expect(s.selected == .gemini)
        s.selectEngine(before)
    }
}

@Suite("WebhookStore") @MainActor
struct WebhookStoreTests {
    @Test func hasInitialEndpoints() {
        #expect(WebhookStore.shared.endpoints.count > 0)
    }
    @Test func addAndDelete() {
        let store = WebhookStore.shared
        let before = store.endpoints.count
        let e = WebhookStore.Endpoint(
            id: UUID(), name: "Test-\(UUID())",
            url: "https://hooks.example.com/x",
            platform: .slack, enabledTriggers: [.budgetOverrun]
        )
        store.add(e)
        #expect(store.endpoints.count == before + 1)
        store.delete(id: e.id)
        #expect(store.endpoints.count == before)
    }
    @Test func updateMutates() {
        let store = WebhookStore.shared
        let e = WebhookStore.Endpoint(
            id: UUID(), name: "before",
            url: "https://hooks.example.com/",
            platform: .slack, enabledTriggers: []
        )
        store.add(e)
        var updated = e; updated.name = "after"
        store.update(updated)
        #expect(store.endpoints.first { $0.id == e.id }?.name == "after")
        store.delete(id: e.id)
    }
    @Test func emitLogsForMatchingTrigger() {
        // Signal-only; we just verify it doesn't throw.
        WebhookStore.shared.emit(.budgetOverrun, title: "t", body: "b")
    }
}
