import Testing
import Foundation
@testable import Glassbook

@Suite("DedupEngine") struct DedupEngineTests {
    private func tx(_ merchant: String, _ cents: Int, _ date: Date = Date(), source: Glassbook.Transaction.Source = .alipay) -> Glassbook.Transaction {
        Glassbook.Transaction(id: UUID(), kind: .expense, amountCents: cents,
                              categoryID: .other, accountID: UUID(), timestamp: date,
                              merchant: merchant, note: nil, source: source)
    }
    private func row(_ merchant: String, _ cents: Int, _ date: Date = Date()) -> PendingImportRow {
        PendingImportRow(id: UUID(), merchant: merchant, amountCents: cents,
                         categoryID: .food, timestamp: date, source: .alipay,
                         isDuplicate: false, isSelected: true)
    }
    @Test func dupSameMerchantAmountAndTime() {
        let now = Date()
        #expect(DedupEngine.isDuplicate(
            row("瑞幸咖啡", 2_800, now),
            against: [tx("瑞幸咖啡", 2_800, now)]
        ))
    }
    @Test func notDupIfAmountDiffers() {
        let now = Date()
        #expect(!DedupEngine.isDuplicate(
            row("瑞幸咖啡", 2_900, now),
            against: [tx("瑞幸咖啡", 2_800, now)]
        ))
    }
    @Test func notDupIfOutsideTimeWindow() {
        let now = Date()
        let tenMinEarlier = now.addingTimeInterval(-600)
        #expect(!DedupEngine.isDuplicate(
            row("M", 100, now),
            against: [tx("M", 100, tenMinEarlier)]
        ))
    }
    @Test func dupViaSubstringMerchantMatch() {
        let now = Date()
        // "瑞幸" stored, "瑞幸咖啡 · 国贸店" incoming → substring matches.
        #expect(DedupEngine.isDuplicate(
            row("瑞幸咖啡 · 国贸店", 2_800, now),
            against: [tx("瑞幸", 2_800, now)]
        ))
    }
    @Test func markDuplicatesFlagsAndDeselects() {
        let now = Date()
        let rows = [
            row("A", 100, now),
            row("B", 200, now),
        ]
        let marked = DedupEngine.markDuplicates(rows, against: [tx("A", 100, now)])
        #expect(marked[0].isDuplicate)
        #expect(!marked[0].isSelected)
        #expect(!marked[1].isDuplicate)
        #expect(marked[1].isSelected)
    }
    @Test func markDuplicatesDetectsWithinBatch() {
        let now = Date()
        let rows = [
            row("A", 100, now),
            row("A", 100, now.addingTimeInterval(60)), // same 1 min later, same amount
        ]
        let marked = DedupEngine.markDuplicates(rows, against: [])
        #expect(!marked[0].isDuplicate, "first occurrence shouldn't be flagged")
        #expect(marked[1].isDuplicate, "second occurrence within batch should be flagged")
    }
}

@Suite("MerchantClassifier") struct MerchantClassifierTests {
    @Test func foodKeywords() {
        let c = MerchantClassifier.shared
        #expect(c.classify(merchant: "美团外卖 · 麦当劳") == .food)
        #expect(c.classify(merchant: "瑞幸咖啡") == .food)
        #expect(c.classify(merchant: "星巴克 国贸店") == .food)
        #expect(c.classify(merchant: "海底捞") == .food)
    }
    @Test func transportKeywords() {
        #expect(MerchantClassifier.shared.classify(merchant: "滴滴出行") == .transport)
        #expect(MerchantClassifier.shared.classify(merchant: "高德打车") == .transport)
        #expect(MerchantClassifier.shared.classify(merchant: "12306 火车票") == .transport)
    }
    @Test func shoppingKeywords() {
        #expect(MerchantClassifier.shared.classify(merchant: "淘宝特价版") == .shopping)
        #expect(MerchantClassifier.shared.classify(merchant: "京东 · 家居") == .shopping)
    }
    @Test func entertainmentKeywords() {
        #expect(MerchantClassifier.shared.classify(merchant: "爱奇艺") == .entertainment)
        #expect(MerchantClassifier.shared.classify(merchant: "bilibili") == .entertainment)
    }
    @Test func unknownFallsBackToOther() {
        #expect(MerchantClassifier.shared.classify(merchant: "zz一个完全没见过的商户") == .other)
    }
    @Test func normalizeStripsSpacesAndDots() {
        // "Apple" hits via lowercasing.
        let got = MerchantClassifier.shared.classify(merchant: "Apple Music")
        #expect(got == .entertainment)
    }
}
