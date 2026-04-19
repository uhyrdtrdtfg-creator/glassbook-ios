import Testing
import Foundation
@testable import Glassbook

@Suite("CurrencyService") struct CurrencyServiceTests {
    @Test func cnyToCnyIdentity() {
        #expect(CurrencyService.shared.convertToCNY(amountCents: 1_000, from: .cny) == 1_000)
    }
    @Test func usdToCnyUsesRate() {
        let cny = CurrencyService.shared.convertToCNY(amountCents: 100, from: .usd)
        // ~7.26 rate → 100 USD cents ≈ 726 CNY cents
        #expect(cny > 600 && cny < 800)
    }
    @Test func cnyToForeign() {
        let usd = CurrencyService.shared.convertFromCNY(cnyCents: 7_260, to: .usd)
        #expect(usd > 900 && usd < 1_100)
    }
    @Test func allSupportedCurrenciesHaveRate() {
        for c in Currency.allCases where c != .cny {
            let rate = CurrencyService.shared.snapshot.rates[c.code]
            #expect(rate != nil, "\(c.code) has no rate")
            #expect((rate ?? 0) > 0)
        }
    }
    @Test func refreshUpdatesTimestamp() async {
        let before = CurrencyService.shared.snapshot.fetchedAt
        try? await Task.sleep(nanoseconds: 10_000_000)
        await CurrencyService.shared.refresh()
        #expect(CurrencyService.shared.snapshot.fetchedAt >= before)
    }
}

@Suite("ReceiptOCRService parser") struct ReceiptOCRServiceTests {
    @Test func fakeReceiptHasMerchantAndTotal() {
        let r = ReceiptOCRService.fakeReceipt()
        #expect(r.merchant?.contains("海底捞") == true)
        #expect(r.amountCents == 24_420) // "合计: ¥244.20"
        #expect(!r.items.isEmpty)
        #expect(r.date != nil)
    }
    @Test func suggestedCategoryMatchesMerchant() {
        let r = ReceiptOCRService.fakeReceipt()
        #expect(r.suggestedCategory == .food)
    }
    @Test func parseFindsTotalKeyword() {
        let r = ReceiptOCRService.parse(lines: [
            "Some Shop",
            "Item 1    ¥10.00",
            "Item 2    ¥20.00",
            "Total:    ¥30.00",
        ])
        #expect(r.amountCents == 3_000)
        #expect(r.items.count == 2)
    }
    @Test func parseFallsBackToLargestAmount() {
        let r = ReceiptOCRService.parse(lines: [
            "Shop",
            "A ¥5",
            "B ¥10",
            "C ¥3",
        ])
        #expect(r.amountCents == 1_000) // = ¥10
    }
    @Test func parseSkipsTooLongMerchantLines() {
        let r = ReceiptOCRService.parse(lines: [
            "This is a very very long header description that shouldn't be merchant name indeed",
            "实际商户",
            "Total: ¥100",
        ])
        #expect(r.merchant == "实际商户")
    }
    @Test func parseLineItemsExcludesTotal() {
        let r = ReceiptOCRService.parse(lines: [
            "Shop",
            "A ¥5",
            "Total: ¥50",
        ])
        // Total should NOT appear as a line item.
        #expect(r.items.allSatisfy { !$0.name.contains("Total") })
    }
    @Test func parseRawTextPreserved() {
        let lines = ["a", "b", "c"]
        #expect(ReceiptOCRService.parse(lines: lines).rawText == lines)
    }
}

@Suite("InsightEngine") @MainActor
struct InsightEngineTests {
    @Test func welcomeCardWhenNoTransactions() {
        let store = AppStore()
        store.transactions = []
        let insights = InsightEngine.generate(store: store)
        #expect(insights.count == 1)
        #expect(insights[0].kind == .persona)
    }
    @Test func generatesPersonaWithData() {
        let insights = InsightEngine.generate(store: AppStore())
        #expect(insights.contains { $0.kind == .persona })
    }
    @Test func generatesDailyAverage() {
        let insights = InsightEngine.generate(store: AppStore())
        #expect(insights.contains { $0.kind == .dailyAvg })
    }
    @Test func eachInsightHasBody() {
        for i in InsightEngine.generate(store: AppStore()) {
            #expect(!i.title.isEmpty)
            #expect(!i.body.isEmpty)
            #expect(!i.emoji.isEmpty)
            #expect(i.gradient.count == 2)
        }
    }
}

@Suite("WrapGenerator") struct WrapGeneratorTests {
    private func tx(year: Int, month: Int = 6, day: Int = 15,
                    cents: Int, merchant: String = "M", cat: Glassbook.Category.Slug = .food) -> Glassbook.Transaction {
        var c = DateComponents(); c.year = year; c.month = month; c.day = day
        let d = Calendar(identifier: .gregorian).date(from: c) ?? Date()
        return Glassbook.Transaction(id: UUID(), kind: .expense, amountCents: cents,
                                     categoryID: cat, accountID: UUID(), timestamp: d,
                                     merchant: merchant, note: nil, source: .manual)
    }
    @Test func emptyYearProducesZeros() {
        let s = WrapGenerator.stats(for: 2026, transactions: [])
        #expect(s.totalExpenseCents == 0)
        #expect(s.txCount == 0)
        #expect(s.topDay == nil)
        #expect(s.topCategory == nil)
    }
    @Test func filtersByYear() {
        let rows = [
            tx(year: 2025, cents: 100),
            tx(year: 2026, cents: 200),
            tx(year: 2027, cents: 500),
        ]
        let s = WrapGenerator.stats(for: 2026, transactions: rows)
        #expect(s.totalExpenseCents == 200)
        #expect(s.txCount == 1)
    }
    @Test func findsTopDay() {
        let rows = [
            tx(year: 2026, month: 1, day: 1, cents: 1_000),
            tx(year: 2026, month: 1, day: 2, cents: 5_000),  // top
            tx(year: 2026, month: 1, day: 3, cents: 2_000),
        ]
        let s = WrapGenerator.stats(for: 2026, transactions: rows)
        #expect(s.topDay?.amountCents == 5_000)
    }
    @Test func findsTopCategory() {
        let rows = [
            tx(year: 2026, cents: 100, cat: .food),
            tx(year: 2026, cents: 1_000, cat: .transport),
            tx(year: 2026, cents: 500, cat: .shopping),
        ]
        let s = WrapGenerator.stats(for: 2026, transactions: rows)
        #expect(s.topCategory?.id == .transport)
    }
    @Test func topMerchantsLimitedToFive() {
        let rows = (0..<10).map { i in
            tx(year: 2026, cents: 100 * (i + 1), merchant: "M\(i)")
        }
        let s = WrapGenerator.stats(for: 2026, transactions: rows)
        #expect(s.topMerchants.count <= 5)
    }
    @Test func personaLabelForFood() {
        let rows = [tx(year: 2026, cents: 1_000, cat: .food)]
        let s = WrapGenerator.stats(for: 2026, transactions: rows)
        #expect(s.topPersona == "美食探索家")
    }
}

@Suite("AdvisorChatService") @MainActor
struct AdvisorChatServiceTests {
    @Test func welcomeMessageOnInit() {
        let s = AdvisorChatService(store: AppStore())
        #expect(s.messages.count == 1)
        #expect(s.messages[0].role == .assistant)
    }
    @Test func emptyInputIsIgnored() async {
        let s = AdvisorChatService(store: AppStore())
        await s.send(userInput: "   ")
        #expect(s.messages.count == 1) // unchanged
    }
    @Test func foodQuestionUsesQueryExpensesTool() async {
        let s = AdvisorChatService(store: AppStore())
        await s.send(userInput: "这个月吃饭花了多少")
        #expect(s.messages.last?.role == .assistant)
        #expect(s.messages.last?.toolName == "query_expenses")
    }
    @Test func budgetQuestionUsesQueryBudgetTool() async {
        let s = AdvisorChatService(store: AppStore())
        await s.send(userInput: "预算还剩多少")
        #expect(s.messages.last?.toolName == "query_budget")
    }
    @Test func subscriptionQuestionUsesListTool() async {
        let s = AdvisorChatService(store: AppStore())
        await s.send(userInput: "订阅有哪些")
        #expect(s.messages.last?.toolName == "list_subscriptions")
    }
    @Test func fallbackHandlesUnknownQuery() async {
        let s = AdvisorChatService(store: AppStore())
        await s.send(userInput: "完全无关的随机问题")
        #expect(s.messages.last?.role == .assistant)
    }
    @Test func thinkingIndicatorClearsAfterSend() async {
        let s = AdvisorChatService(store: AppStore())
        await s.send(userInput: "这个月吃饭花了多少")
        #expect(s.isThinking == false)
    }
}

@Suite("PDFExporter") @MainActor
struct PDFExporterTests {
    @Test func exportProducesValidPDF() throws {
        let store = AppStore()
        // Include everything by using a wide date range.
        let criteria = PDFExporter.ExportCriteria(
            startDate: Date().addingTimeInterval(-365 * 86400),
            endDate: Date().addingTimeInterval(86400),
            categoryFilter: [],
            title: "Test", author: "Tester"
        )
        let result = try PDFExporter.export(transactions: store.transactions, criteria: criteria)
        defer { try? FileManager.default.removeItem(at: result.url) }

        let data = try Data(contentsOf: result.url)
        #expect(data.count > 100)
        // PDF starts with "%PDF-"
        let prefix = String(data: data.prefix(5), encoding: .utf8)
        #expect(prefix == "%PDF-")
        #expect(result.txCount > 0)
        #expect(result.totalCents > 0)
    }
    @Test func categoryFilterReducesRows() throws {
        let store = AppStore()
        let criteria = PDFExporter.ExportCriteria(
            startDate: Date().addingTimeInterval(-365 * 86400),
            endDate: Date().addingTimeInterval(86400),
            categoryFilter: [.food],
            title: "食", author: "T"
        )
        let result = try PDFExporter.export(transactions: store.transactions, criteria: criteria)
        defer { try? FileManager.default.removeItem(at: result.url) }
        let foodOnly = store.transactions.filter { $0.categoryID == .food && $0.kind == .expense }
        #expect(result.txCount == foodOnly.count)
    }
    @Test func emptyRangeProducesEmptyButValidPDF() throws {
        let future = Date().addingTimeInterval(365 * 86400)
        let criteria = PDFExporter.ExportCriteria(
            startDate: future, endDate: future.addingTimeInterval(86400),
            categoryFilter: [], title: "T", author: "T"
        )
        let result = try PDFExporter.export(transactions: [], criteria: criteria)
        defer { try? FileManager.default.removeItem(at: result.url) }
        #expect(result.txCount == 0)
        let data = try Data(contentsOf: result.url)
        #expect(String(data: data.prefix(5), encoding: .utf8) == "%PDF-")
    }
}

@Suite("KeychainService") struct KeychainServiceTests {
    @Test func setGetRoundtrip() {
        let key = "test.roundtrip.\(UUID())"
        defer { KeychainService.delete(key) }
        #expect(KeychainService.set("hello-world", for: key))
        #expect(KeychainService.get(key) == "hello-world")
        #expect(KeychainService.has(key))
    }
    @Test func deleteRemoves() {
        let key = "test.delete.\(UUID())"
        _ = KeychainService.set("a", for: key)
        _ = KeychainService.delete(key)
        #expect(KeychainService.get(key) == nil)
    }
    @Test func missingKeyReturnsNil() {
        #expect(KeychainService.get("nonexistent.\(UUID())") == nil)
    }
    @Test func updateOverwrites() {
        let key = "test.update.\(UUID())"
        defer { KeychainService.delete(key) }
        _ = KeychainService.set("one", for: key)
        _ = KeychainService.set("two", for: key)
        #expect(KeychainService.get(key) == "two")
    }
}
