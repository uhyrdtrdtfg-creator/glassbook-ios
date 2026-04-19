import Testing
import Foundation
@testable import GlassbookMCP

// MARK: - DataStore

@Suite("DataStore")
struct DataStoreTests {
    private func makeStore() -> DataStore {
        DataStore(url: URL(fileURLWithPath: "/tmp/glassbook-mcp-test-\(UUID()).json"))
    }

    @Test func seedsWhenFileMissing() {
        let s = makeStore()
        let summary = s.budgetSummary(category: nil)
        #expect(summary.totalCNY > 0)
    }

    @Test func addTransactionPrependsAndPersists() throws {
        let url = URL(fileURLWithPath: "/tmp/glassbook-mcp-persist-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: url) }
        do {
            let s = DataStore(url: url)
            let rec = s.addTransaction(amountCNY: 100, category: "food",
                                       merchant: "Test", kind: "expense", note: nil,
                                       timestamp: .now)
            #expect(rec.amount_cny == 100)
            #expect(rec.category == "food")
        }
        // Reopen, verify persistence
        let s2 = DataStore(url: url)
        let results = s2.findSimilar(merchant: "Test", limit: 10)
        #expect(results.count >= 1)
    }

    @Test func findSimilarCaseInsensitive() {
        let s = makeStore()
        _ = s.addTransaction(amountCNY: 28, category: "food",
                             merchant: "瑞幸咖啡", kind: "expense", note: nil, timestamp: .now)
        #expect(s.findSimilar(merchant: "瑞幸", limit: 5).count >= 1)
        #expect(s.findSimilar(merchant: "瑞幸咖啡", limit: 5).count >= 1)
    }

    @Test func listSubscriptionsFilters() {
        let s = makeStore()
        let all = s.listSubscriptions(filter: "all")
        let active = s.listSubscriptions(filter: "active")
        let idle30 = s.listSubscriptions(filter: "idle_30")
        let idle90 = s.listSubscriptions(filter: "idle_90")
        #expect(all.count == active.count + idle30.count)
        #expect(idle30.count >= idle90.count)
    }

    @Test func monthlySummaryForCurrentMonth() {
        let s = makeStore()
        _ = s.addTransaction(amountCNY: 42, category: "food",
                             merchant: "MonthTest", kind: "expense", note: nil, timestamp: .now)
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: .now)
        let summary = s.monthlySummary(year: comps.year!, month: comps.month!)
        #expect(summary.txCount >= 1)
        #expect(summary.totalCNY >= 42)
    }

    @Test func setBudgetTotalPersists() {
        let s = makeStore()
        s.setBudget(amountCNY: 8000, category: nil)
        #expect(s.budgetSummary(category: nil).totalCNY == 8000)
    }

    @Test func setBudgetPerCategory() {
        let s = makeStore()
        s.setBudget(amountCNY: 1500, category: "food")
        #expect(s.budgetSummary(category: "food").totalCNY == 1500)
    }

    @Test func budgetSummaryReportsRemaining() {
        let s = makeStore()
        s.setBudget(amountCNY: 1000, category: nil)
        _ = s.addTransaction(amountCNY: 200, category: "food",
                             merchant: "M", kind: "expense", note: nil, timestamp: .now)
        let summary = s.budgetSummary(category: nil)
        #expect(summary.remainingCNY <= 800)
    }
}

// MARK: - Tools

@Suite("Tools")
struct ToolExecutionTests {
    private func store() -> DataStore {
        DataStore(url: URL(fileURLWithPath: "/tmp/mcp-tool-\(UUID()).json"))
    }

    // add_transaction
    @Test func addTransactionRejectsNegativeAmount() {
        let t = AddTransactionTool(store: store())
        #expect(throws: (any Error).self) {
            _ = try t.execute(arguments: ["amount": -10])
        }
    }
    @Test func addTransactionAcceptsMinimalArgs() throws {
        let t = AddTransactionTool(store: store())
        let r = try t.execute(arguments: ["amount": 50])
        #expect(r.json["amount_cny"] as? Double == 50)
    }
    @Test func addTransactionRespectsISODate() throws {
        let t = AddTransactionTool(store: store())
        let r = try t.execute(arguments: [
            "amount": 10, "timestamp": "2026-01-01T12:00:00Z",
        ])
        #expect((r.json["timestamp"] as? String)?.hasPrefix("2026-01-01") == true)
    }

    // query_budget
    @Test func queryBudgetReturnsSummary() throws {
        let t = QueryBudgetTool(store: store())
        let r = try t.execute(arguments: [:])
        #expect(r.humanSummary.contains("预算"))
        #expect(r.json["used_pct"] is Int)
    }
    @Test func queryBudgetWithCategory() throws {
        let t = QueryBudgetTool(store: store())
        let r = try t.execute(arguments: ["category": "food"])
        #expect((r.json["category"] as? String) == "food")
    }

    // list_subscriptions
    @Test func listSubscriptionsDefaultsToAll() throws {
        let t = ListSubscriptionsTool(store: store())
        let r = try t.execute(arguments: [:])
        #expect((r.json["count"] as? Int) ?? 0 > 0)
    }
    @Test func listSubscriptionsFiltered() throws {
        let t = ListSubscriptionsTool(store: store())
        let all = try t.execute(arguments: ["filter": "all"])
        let idle30 = try t.execute(arguments: ["filter": "idle_30"])
        #expect((all.json["count"] as? Int) ?? 0 >= (idle30.json["count"] as? Int) ?? 0)
    }

    // get_monthly_summary
    @Test func monthlySummaryDefaultsToCurrent() throws {
        let t = GetMonthlySummaryTool(store: store())
        let r = try t.execute(arguments: [:])
        #expect(r.json["year"] as? Int != nil)
    }
    @Test func monthlySummaryExplicit() throws {
        let t = GetMonthlySummaryTool(store: store())
        let r = try t.execute(arguments: ["year": 2026, "month": 4])
        #expect(r.json["year"] as? Int == 2026)
        #expect(r.json["month"] as? Int == 4)
    }

    // find_similar_txns
    @Test func findSimilarRequiresMerchant() {
        let t = FindSimilarTxnsTool(store: store())
        #expect(throws: (any Error).self) {
            _ = try t.execute(arguments: [:])
        }
    }
    @Test func findSimilarAcceptsLimit() throws {
        let t = FindSimilarTxnsTool(store: store())
        let r = try t.execute(arguments: ["merchant": "Test", "limit": 3])
        #expect(r.json["count"] != nil)
    }

    // set_budget
    @Test func setBudgetRejectsZero() {
        let t = SetBudgetTool(store: store())
        #expect(throws: (any Error).self) {
            _ = try t.execute(arguments: ["amount": 0])
        }
    }
    @Test func setBudgetOverall() throws {
        let t = SetBudgetTool(store: store())
        let r = try t.execute(arguments: ["amount": 9000])
        #expect((r.json["amount_cny"] as? Double) == 9000)
    }
    @Test func setBudgetPerCategory() throws {
        let t = SetBudgetTool(store: store())
        let r = try t.execute(arguments: ["amount": 2000, "category": "food"])
        #expect((r.json["category"] as? String) == "food")
    }

    // Schema / metadata
    @Test func allToolsHaveSchema() {
        let tools = ToolRegistry.all(store: store())
        #expect(tools.count == 6)
        for tool in tools {
            #expect(!tool.name.isEmpty)
            #expect(!tool.description.isEmpty)
            #expect(tool.inputSchema["type"] as? String == "object")
        }
    }
    @Test func toolNamesAreUnique() {
        let names = ToolRegistry.all(store: store()).map(\.name)
        #expect(Set(names).count == names.count)
    }
    @Test func exactToolNamesMatchSpec() {
        let names = Set(ToolRegistry.all(store: store()).map(\.name))
        #expect(names == [
            "add_transaction", "query_budget", "list_subscriptions",
            "get_monthly_summary", "find_similar_txns", "set_budget",
        ])
    }
}
