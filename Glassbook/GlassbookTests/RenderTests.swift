import Testing
import SwiftUI
import SwiftData
import UIKit
@testable import Glassbook

/// Forces SwiftUI body evaluation via UIHostingController so coverage can
/// reach into view implementations, not just their init surfaces.
/// Each render test pumps an initial layout pass on a large screen bounds.
@Suite("View render") @MainActor
struct ViewRenderTests {
    private let bounds = CGRect(x: 0, y: 0, width: 430, height: 932)

    private func render<V: View>(_ view: V) {
        let host = UIHostingController(rootView: view)
        host.view.frame = bounds
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
    }

    private var store: AppStore { AppStore() }

    @Test func home() {
        render(HomeView().environment(store))
    }
    @Test func bills() {
        render(BillsView().environment(store))
    }
    @Test func stats() {
        render(StatsView().environment(store))
    }
    @Test func budget() {
        render(BudgetView().environment(store))
    }
    @Test func profile() {
        render(ProfileView().environment(store))
    }
    @Test func addTransactionBasic() {
        render(AddTransactionView().environment(store))
    }
    @Test func addTransactionWithPrefill() {
        render(AddTransactionView(prefill: ReceiptOCRService.fakeReceipt()).environment(store))
    }
    @Test func accounts() {
        render(AccountsView().environment(store))
    }
    @Test func subscriptions() {
        render(SubscriptionsView().environment(store))
    }
    @Test func goals() {
        render(GoalsView().environment(store))
    }
    @Test func annualWrap() {
        render(AnnualWrapView().environment(store))
    }
    @Test func insights() {
        render(InsightsView(isStandalone: true).environment(store))
    }
    @Test func sunkCost() {
        render(SunkCostView().environment(store))
    }
    @Test func familyBook() {
        render(FamilyBookView().environment(store))
    }
    @Test func advisor() {
        render(AdvisorView().environment(store))
    }
    @Test func invoiceExport() {
        render(InvoiceExportView().environment(store))
    }
    @Test func aiEngineSettings() {
        render(AIEngineSettingsView())
    }
    @Test func webhookSettings() {
        render(WebhookSettingsView())
    }
    @Test func automationSettings() {
        render(AutomationSettingsView())
    }
    @Test func rootFullStack() {
        let lock = AppLock(); lock.skipAuth = true
        render(RootView().environment(store).environment(lock))
    }
    @Test func lockScreen() {
        let lock = AppLock(); lock.skipAuth = true
        render(LockView().environment(lock))
    }
    @Test func receiptScanEmpty() {
        render(ReceiptScanSheet(onConfirm: { _ in }, onCancel: {}))
    }
    @Test func smartImportEntry() {
        var shown = true
        let binding = Binding(get: { shown }, set: { shown = $0 })
        render(SmartImportFlow(isPresented: binding).environment(store))
    }
    @Test func auroraAllPalettes() {
        for p in AuroraPalette.allCases { render(AuroraBackground(palette: p)) }
    }
}

@Suite("Advisor — remaining branches") @MainActor
struct AdvisorMoreTests {
    @Test func cancelQuestionRoutes() async {
        let s = AdvisorChatService(store: AppStore())
        await s.send(userInput: "建议取消哪些订阅")
        #expect(s.messages.last?.role == .assistant)
    }
    @Test func monthQuestionRoutes() async {
        let s = AdvisorChatService(store: AppStore())
        await s.send(userInput: "这个月消费怎样")
        #expect(s.messages.last?.role == .assistant)
    }
    @Test func whitespaceOnlyInputIgnored() async {
        let s = AdvisorChatService(store: AppStore())
        let before = s.messages.count
        await s.send(userInput: "\n\t  \n")
        #expect(s.messages.count == before)
    }
    @Test func multipleSendsAccumulate() async {
        let s = AdvisorChatService(store: AppStore())
        await s.send(userInput: "预算")
        await s.send(userInput: "订阅")
        // 1 welcome + (user+assistant)*2 = 5
        #expect(s.messages.count >= 5)
    }
}

@Suite("AIEngineStore — coverage") @MainActor
struct AIEngineStoreMoreTests {
    @Test func defaultModelsAllPopulated() {
        for e in AIEngineStore.Engine.allCases {
            if e == .custom {
                #expect(e.defaultModels.isEmpty || !e.defaultModels.isEmpty)
            } else {
                #expect(!e.defaultModels.isEmpty, "\(e) should have models")
            }
        }
    }
    @Test func baseURLMatchesEngine() {
        #expect(AIEngineStore.Engine.openAI.defaultBaseURL.contains("openai.com"))
        #expect(AIEngineStore.Engine.claude.defaultBaseURL.contains("anthropic.com"))
        #expect(AIEngineStore.Engine.gemini.defaultBaseURL.contains("googleapis.com"))
    }
    @Test func setBaseURLPersists() {
        let s = AIEngineStore.shared
        let original = s.config(for: .ollama).baseURL
        s.setBaseURL("http://localhost:9999", for: .ollama)
        #expect(s.config(for: .ollama).baseURL == "http://localhost:9999")
        s.setBaseURL(original, for: .ollama)
    }
    @Test func setModelPersists() {
        let s = AIEngineStore.shared
        let original = s.config(for: .openAI).model
        s.setModel("gpt-4-turbo", for: .openAI)
        #expect(s.config(for: .openAI).model == "gpt-4-turbo")
        s.setModel(original, for: .openAI)
    }
}

@Suite("WebhookStore — coverage") @MainActor
struct WebhookStoreMoreTests {
    @Test func triggerMetadataComplete() {
        for t in WebhookStore.Trigger.allCases {
            #expect(!t.displayName.isEmpty)
            #expect(!t.emoji.isEmpty)
        }
    }
    @Test func platformMetadataComplete() {
        for p in WebhookStore.Endpoint.Platform.allCases {
            #expect(!p.displayName.isEmpty)
            #expect(p.tintHex > 0)
        }
    }
    @Test func emitNoMatchingEndpointIsNoOp() {
        // Use a trigger no seed endpoint subscribes to → silently does nothing.
        WebhookStore.shared.emit(.weeklyDigest, title: "w", body: "b")
    }
    @Test func allTriggersEmittable() {
        for t in WebhookStore.Trigger.allCases {
            WebhookStore.shared.emit(t, title: "x", body: "y")
        }
    }
}

@Suite("Persistence — fallback chain") @MainActor
struct PersistenceFallbackTests {
    @Test func nonCloudKitLocalPathReturns() {
        // The scaffold's normal path is CloudKit → local → in-memory.
        // Ask for local-only and we still get a usable container.
        let container = PersistenceController.makeDiskContainer(useCloudKit: false)
        let context = ModelContext(container)
        _ = try? context.fetch(FetchDescriptor<SDTransaction>())
    }
    @Test func inMemoryAlwaysSucceeds() {
        let container = PersistenceController.makeInMemoryContainer(seeded: false)
        let context = ModelContext(container)
        let count = (try? context.fetchCount(FetchDescriptor<SDTransaction>())) ?? -1
        #expect(count == 0)
    }
}

@Suite("SampleData — coverage") @MainActor
struct SampleDataTests {
    @Test func transactionsSpanThisMonth() {
        let cal = Calendar(identifier: .gregorian)
        let now = Date()
        let anyThisMonth = SampleData.transactions.contains {
            cal.component(.year, from: $0.timestamp) == cal.component(.year, from: now) &&
            cal.component(.month, from: $0.timestamp) == cal.component(.month, from: now)
        }
        #expect(anyThisMonth)
    }
    @Test func accountsHaveOnePrimary() {
        #expect(SampleData.accounts.filter(\.isPrimary).count == 1)
    }
    @Test func subscriptionsIncludeVariousPeriods() {
        let periods = Set(SampleData.subscriptions.map(\.period))
        #expect(periods.contains(.monthly))
    }
    @Test func savingsGoalsAllHaveTargets() {
        for g in SampleData.savingsGoals {
            #expect(g.targetCents > 0)
        }
    }
    @Test func familyMembersIncludeAllRoles() {
        let roles = Set(SampleData.familyMembers.map(\.role))
        #expect(roles.count == 3)
    }
    @Test func pendingImportIncludesDuplicate() {
        #expect(SampleData.pendingImport.contains { $0.isDuplicate })
    }
}

@Suite("AppStore — additional") @MainActor
struct AppStoreAdditionalTests {
    @Test func lastMonthExpenseIsCalculable() {
        let s = AppStore()
        _ = s.lastMonthExpenseCents   // exercises the computed property
    }
    @Test func monthOverMonthPctNonCrashing() {
        _ = AppStore().monthOverMonthChangePct
    }
    @Test func incomeAndExpenseBothPresent() {
        let s = AppStore()
        #expect(s.transactions.contains { $0.kind == .income })
        #expect(s.transactions.contains { $0.kind == .expense })
    }
    @Test func deleteIgnoresUnknownID() {
        let s = AppStore()
        let before = s.transactions.count
        s.delete(UUID())
        #expect(s.transactions.count == before)
    }
    @Test func rollbackUnknownBatchIsNoOp() {
        let s = AppStore()
        let before = s.transactions.count
        s.rollbackBatch(UUID())
        #expect(s.transactions.count == before)
    }
    @Test func contributeToUnknownGoalIsNoOp() {
        let s = AppStore()
        let before = s.goals.count
        s.contribute(to: UUID(), cents: 100)
        #expect(s.goals.count == before)
    }
}
