import Testing
import Foundation
import SwiftData
import SwiftUI
@testable import Glassbook

@Suite("PersistenceController") @MainActor
struct PersistenceControllerTests {
    @Test func inMemorySeededHasRows() {
        let container = PersistenceController.makeInMemoryContainer(seeded: true)
        let context = ModelContext(container)
        let rows = (try? context.fetch(FetchDescriptor<SDTransaction>())) ?? []
        #expect(!rows.isEmpty)
    }
    @Test func inMemoryUnseededIsEmpty() {
        let container = PersistenceController.makeInMemoryContainer(seeded: false)
        let context = ModelContext(container)
        let rows = (try? context.fetch(FetchDescriptor<SDTransaction>())) ?? []
        #expect(rows.isEmpty)
    }
    @Test func schemaIncludesAllSevenModels() {
        #expect(PersistenceController.schema.entities.count >= 7)
    }
    @Test func cloudKitContainerIdentifierIsStable() {
        #expect(PersistenceController.cloudKitContainer == "iCloud.app.glassbook.ios")
    }
}

@Suite("AppSeed idempotence") @MainActor
struct AppSeedTests {
    @Test func seedNoOpsIfRowsExist() {
        let container = PersistenceController.makeInMemoryContainer(seeded: true)
        let context = ModelContext(container)
        let before = (try? context.fetchCount(FetchDescriptor<SDTransaction>())) ?? 0
        AppSeed.seed(context: context)
        let after = (try? context.fetchCount(FetchDescriptor<SDTransaction>())) ?? 0
        #expect(before == after, "seed should no-op on populated context")
    }
    @Test func seedPopulatesSubscriptionsAndGoals() {
        let container = PersistenceController.makeInMemoryContainer(seeded: true)
        let context = ModelContext(container)
        let subCount = (try? context.fetchCount(FetchDescriptor<SDSubscription>())) ?? 0
        let goalCount = (try? context.fetchCount(FetchDescriptor<SDSavingsGoal>())) ?? 0
        #expect(subCount > 0)
        #expect(goalCount > 0)
    }
    @Test func seedWritesBudget() {
        let container = PersistenceController.makeInMemoryContainer(seeded: true)
        let context = ModelContext(container)
        let budgets = (try? context.fetch(FetchDescriptor<SDBudget>())) ?? []
        #expect(!budgets.isEmpty)
        #expect(budgets.first?.monthlyTotalCents == 600_000)
    }
}

@Suite("SDTransaction roundtrip") @MainActor
struct SDTransactionRoundtripTests {
    @Test func fullFidelityRoundtrip() {
        let id = UUID(); let accID = UUID(); let batchID = UUID()
        let ts = Date(timeIntervalSince1970: 1_800_000_000)
        let original = Transaction(
            id: id, kind: .income, amountCents: 12_345,
            categoryID: .shopping, accountID: accID, timestamp: ts,
            merchant: "Roundtrip", note: "note",
            source: .wechat, importBatchID: batchID,
            mood: .reward, visibility: .partner,
            originalCurrency: .usd, originalAmountCents: 1_700
        )
        let sd = SDTransaction(from: original)
        let back = sd.toStruct()
        #expect(back.id == id)
        #expect(back.kind == .income)
        #expect(back.amountCents == 12_345)
        #expect(back.categoryID == .shopping)
        #expect(back.accountID == accID)
        #expect(back.timestamp == ts)
        #expect(back.merchant == "Roundtrip")
        #expect(back.note == "note")
        #expect(back.source == .wechat)
        #expect(back.importBatchID == batchID)
        #expect(back.mood == .reward)
        #expect(back.visibility == .partner)
        #expect(back.originalCurrency == .usd)
        #expect(back.originalAmountCents == 1_700)
    }
    @Test func nilOptionalsRoundtrip() {
        let orig = Transaction(
            id: UUID(), kind: .expense, amountCents: 100,
            categoryID: .food, accountID: UUID(), timestamp: Date(),
            merchant: "M", note: nil, source: .manual, importBatchID: nil,
            mood: nil, visibility: .family,
            originalCurrency: .cny, originalAmountCents: nil
        )
        let back = SDTransaction(from: orig).toStruct()
        #expect(back.note == nil)
        #expect(back.importBatchID == nil)
        #expect(back.mood == nil)
        #expect(back.originalAmountCents == nil)
    }
    @Test func invalidRawValueFallsBack() {
        let sd = SDTransaction(
            id: UUID(), kind: .expense, amountCents: 0,
            categoryID: .other, accountID: UUID(),
            merchant: "m")
        sd.kindRaw = "invalid"
        sd.categoryRaw = "invalid"
        sd.sourceRaw = "invalid"
        sd.visibilityRaw = "invalid"
        sd.originalCurrencyRaw = "invalid"
        #expect(sd.kind == .expense)
        #expect(sd.categoryID == .other)
        #expect(sd.source == .manual)
        #expect(sd.visibility == .family)
        #expect(sd.originalCurrency == .cny)
    }
}

@Suite("SDAccount roundtrip") @MainActor
struct SDAccountTests {
    @Test func roundtrip() {
        let a = Account(id: UUID(), name: "My Bank", type: .credit,
                        balanceCents: -250_000, isPrimary: false)
        let back = SDAccount(from: a).toStruct()
        #expect(back.id == a.id)
        #expect(back.name == "My Bank")
        #expect(back.type == .credit)
        #expect(back.balanceCents == -250_000)
        #expect(back.isPrimary == false)
    }
}

@Suite("SDBudget encoding") @MainActor
struct SDBudgetTests {
    @Test func encodeDecodeDict() {
        let dict: [Glassbook.Category.Slug: Int] = [
            .food: 1_500_00, .transport: 600_00, .kids: 300_00,
        ]
        let s = SDBudget.encode(dict)
        let back = SDBudget.decode(s)
        #expect(back[.food] == 150_000)
        #expect(back[.transport] == 60_000)
        #expect(back[.kids] == 30_000)
    }
    @Test func emptyStringDecodesEmpty() {
        #expect(SDBudget.decode("").isEmpty)
    }
    @Test func malformedPairIgnored() {
        let back = SDBudget.decode("food:100,notapair,transport:200")
        #expect(back[.food] == 100)
        #expect(back[.transport] == 200)
    }
    @Test func fromBudgetRoundtrip() {
        let b = Budget.default
        let sd = SDBudget(from: b)
        let back = sd.toStruct()
        #expect(back.monthlyTotalCents == b.monthlyTotalCents)
        #expect(back.perCategory[.food] == b.perCategory[.food])
    }
}

@Suite("SDSubscription roundtrip") @MainActor
struct SDSubscriptionTests {
    @Test func roundtripPreservesFields() {
        let orig = Subscription(
            id: UUID(), name: "Claude Pro", emoji: "🤖",
            amountCents: 14_520, period: .monthly,
            nextRenewalDate: Date(), lastUsedDate: Date(),
            gradient: [Color(hex: 0xFF0000), Color(hex: 0x00FF00)], isActive: true
        )
        let back = SDSubscription(from: orig).toStruct()
        #expect(back.id == orig.id)
        #expect(back.name == "Claude Pro")
        #expect(back.amountCents == 14_520)
        #expect(back.period == .monthly)
        #expect(back.isActive == true)
    }
}

@Suite("SDSavingsGoal roundtrip") @MainActor
struct SDSavingsGoalTests {
    @Test func roundtripPreservesFields() {
        let orig = SavingsGoal(
            id: UUID(), name: "Tokyo", emoji: "🗾",
            targetCents: 800_000, currentCents: 120_000,
            deadline: Date(), createdAt: Date(),
            gradient: [Color(hex: 0xFFB5C8), Color(hex: 0xB8D6FF)]
        )
        let back = SDSavingsGoal(from: orig).toStruct()
        #expect(back.id == orig.id)
        #expect(back.name == "Tokyo")
        #expect(back.targetCents == 800_000)
        #expect(back.currentCents == 120_000)
    }
}

@Suite("SDMerchantLearning") @MainActor
struct SDMerchantLearningTests {
    @Test func storesCategoryRawAndReadsBack() {
        let learning = SDMerchantLearning(merchantKey: "美团外卖", category: .food)
        #expect(learning.category == .food)
    }
    @Test func invalidRawFallsBackToOther() {
        let learning = SDMerchantLearning(merchantKey: "m", category: .food)
        learning.categoryRaw = "invalid"
        #expect(learning.category == .other)
    }
    @Test func lowercasesKeyOnInit() {
        let learning = SDMerchantLearning(merchantKey: "MixedCASE", category: .food)
        #expect(learning.merchantKey == "mixedcase")
    }
}

@Suite("SDImportBatch") @MainActor
struct SDImportBatchTests {
    @Test func defaultsAndPlatformRawRoundtrip() {
        let b = SDImportBatch(platform: .alipay, totalTxCount: 3,
                              totalAmountCents: 300, duplicatesSkipped: 1)
        #expect(b.platform == .alipay)
        #expect(b.totalTxCount == 3)
        #expect(b.duplicatesSkipped == 1)
    }
}
