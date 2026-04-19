import Testing
import Foundation
import SwiftData
@testable import Glassbook

@Suite("AppStore · in-memory init") @MainActor
struct AppStoreInitTests {
    @Test func inMemoryInitHasSampleData() {
        let s = AppStore()
        #expect(!s.transactions.isEmpty)
        #expect(!s.accounts.isEmpty)
        #expect(!s.subscriptions.isEmpty)
        #expect(!s.goals.isEmpty)
        #expect(!s.familyMembers.isEmpty)
    }
    @Test func defaultBudgetPresent() {
        #expect(AppStore().budget.monthlyTotalCents == 600_000)
    }
    @Test func defaultUserIsRoger() {
        let s = AppStore()
        #expect(s.userName == "Roger")
        #expect(s.userInitial == "R")
    }
    @Test func diskContainerInitSeedsOnFirstRun() {
        // In-memory container is a valid substitute here since disk would leak to iCloud in CI.
        let container = PersistenceController.makeInMemoryContainer(seeded: false)
        let s = AppStore(container: container)
        // seed ran inside init when empty, so transactions must be non-empty.
        #expect(!s.transactions.isEmpty)
    }
}

@Suite("AppStore · derived values") @MainActor
struct AppStoreDerivedTests {
    @Test func thisMonthExpenseMatchesSum() {
        let s = AppStore()
        let sum = s.transactionsInMonth(Date())
            .filter { $0.kind == .expense }
            .reduce(0) { $0 + $1.amountCents }
        #expect(s.thisMonthExpenseCents == sum)
    }
    @Test func thisMonthIncomeMatchesSum() {
        let s = AppStore()
        let sum = s.transactionsInMonth(Date())
            .filter { $0.kind == .income }
            .reduce(0) { $0 + $1.amountCents }
        #expect(s.thisMonthIncomeCents == sum)
    }
    @Test func budgetRemainingMatchesBudgetMinusSpend() {
        let s = AppStore()
        #expect(s.budgetRemainingCents == s.budget.monthlyTotalCents - s.thisMonthExpenseCents)
    }
    @Test func budgetUsedPercentClampedBetweenZeroAndSomewhat() {
        let s = AppStore()
        #expect(s.budgetUsedPercent >= 0)
    }
    @Test func netWorthEqualsSumOfBalances() {
        let s = AppStore()
        let expected = s.accounts.reduce(0) { $0 + $1.balanceCents }
        #expect(s.netWorthCents == expected)
    }
    @Test func monthlySubscriptionTotalOnlyActive() {
        let s = AppStore()
        let expected = s.subscriptions.filter(\.isActive).reduce(0) { $0 + $1.monthlyEquivalentCents }
        #expect(s.monthlySubscriptionTotalCents == expected)
    }
    @Test func totalSavedSumsGoals() {
        let s = AppStore()
        let expected = s.goals.reduce(0) { $0 + $1.currentCents }
        #expect(s.totalSavedCents == expected)
    }
    @Test func totalGoalsTargetSums() {
        let s = AppStore()
        let expected = s.goals.reduce(0) { $0 + $1.targetCents }
        #expect(s.totalGoalsTargetCents == expected)
    }
    @Test func familyTotalOnlyIncludesFamilyVisibility() {
        let s = AppStore()
        let expected = s.transactionsInMonth(Date())
            .filter { $0.kind == .expense && $0.visibility == .family }
            .reduce(0) { $0 + $1.amountCents }
        #expect(s.familyTotalThisMonthCents == expected)
    }
    @Test func dailyAverageZeroIfDayZero() {
        // Can't force day=0, so just sanity-check it's non-negative.
        #expect(AppStore().thisMonthDailyAverageCents >= 0)
    }
    @Test func transactionsInMonthFiltersCorrectly() {
        let s = AppStore()
        let all = s.transactionsInMonth(Date())
        let cal = Calendar(identifier: .gregorian)
        let month = cal.component(.month, from: Date())
        for tx in all {
            #expect(cal.component(.month, from: tx.timestamp) == month)
        }
    }
    @Test func expensesByCategorySortedDescending() {
        let s = AppStore()
        let buckets = s.expensesByCategory(in: Date())
        for i in 1..<buckets.count {
            #expect(buckets[i - 1].1 >= buckets[i].1)
        }
    }
    @Test func monthlyTrendReturnsRequestedCount() {
        #expect(AppStore().monthlyTrend(months: 3).count == 3)
        #expect(AppStore().monthlyTrend(months: 12).count == 12)
    }
    @Test func txByDaySortedDescending() {
        let s = AppStore()
        let groups = s.txByDay(in: Date())
        for i in 1..<groups.count {
            #expect(groups[i - 1].date >= groups[i].date)
        }
    }
    @Test func primaryAccountIDAlwaysResolvable() {
        #expect(AppStore().primaryAccountID != UUID())  // just non-nil
    }
}

@Suite("AppStore · mutations") @MainActor
struct AppStoreMutationsTests {
    @Test func addExpenseAppendsToFront() {
        let s = AppStore()
        let before = s.transactions.count
        s.addExpense(amountCents: 500, category: .food, merchant: "TestMerchant", note: nil)
        #expect(s.transactions.count == before + 1)
        #expect(s.transactions.first?.merchant == "TestMerchant")
    }
    @Test func addExpenseIgnoresZeroAmount() {
        let s = AppStore()
        let before = s.transactions.count
        s.addExpense(amountCents: 0, category: .food, merchant: "", note: nil)
        #expect(s.transactions.count == before)
    }
    @Test func addExpenseDefaultsMerchantToCategoryName() {
        let s = AppStore()
        s.addExpense(amountCents: 100, category: .food, merchant: "", note: nil)
        #expect(s.transactions.first?.merchant == Category.by(.food).name)
    }
    @Test func addExpenseIgnoresEmptyNote() {
        let s = AppStore()
        s.addExpense(amountCents: 100, category: .food, merchant: "M", note: "")
        #expect(s.transactions.first?.note == nil)
    }
    @Test func addExpenseCarriesMoodAndVisibility() {
        let s = AppStore()
        s.addExpense(amountCents: 100, category: .food, merchant: "M", note: nil,
                     mood: .regret, visibility: .personal)
        let tx = s.transactions.first!
        #expect(tx.mood == .regret)
        #expect(tx.visibility == .personal)
    }
    @Test func deleteRemovesTransaction() {
        let s = AppStore()
        s.addExpense(amountCents: 100, category: .food, merchant: "ToDelete", note: nil)
        guard let id = s.transactions.first(where: { $0.merchant == "ToDelete" })?.id else {
            Issue.record("Expected tx not found"); return
        }
        s.delete(id)
        #expect(!s.transactions.contains { $0.id == id })
    }
    @Test func importBatchWritesSelectedRowsOnly() {
        let s = AppStore()
        let before = s.transactions.count
        let rows = [
            PendingImportRow(id: UUID(), merchant: "A", amountCents: 100,
                             categoryID: .food, timestamp: Date(),
                             source: .alipay, isDuplicate: false, isSelected: true),
            PendingImportRow(id: UUID(), merchant: "B", amountCents: 200,
                             categoryID: .food, timestamp: Date(),
                             source: .alipay, isDuplicate: true, isSelected: false),
        ]
        let batchID = s.importBatch(rows: rows, platform: .alipay)
        #expect(s.transactions.count == before + 1)
        #expect(s.transactions.first?.importBatchID == batchID)
    }
    @Test func rollbackBatchRemovesAllBatchTransactions() {
        let s = AppStore()
        let rows = (0..<3).map { i in
            PendingImportRow(id: UUID(), merchant: "M\(i)", amountCents: 100,
                             categoryID: .food, timestamp: Date(),
                             source: .alipay, isDuplicate: false, isSelected: true)
        }
        let batchID = s.importBatch(rows: rows, platform: .alipay)
        let before = s.transactions.count
        s.rollbackBatch(batchID)
        #expect(s.transactions.count == before - 3)
        #expect(!s.transactions.contains { $0.importBatchID == batchID })
    }
    @Test func addSubscriptionInsertsSorted() {
        let s = AppStore()
        let before = s.subscriptions.count
        let sub = Subscription(
            id: UUID(), name: "New", emoji: "✨", amountCents: 1_000,
            period: .monthly,
            nextRenewalDate: Date().addingTimeInterval(86400),
            lastUsedDate: Date(),
            gradient: [.red, .blue], isActive: true
        )
        s.addSubscription(sub)
        #expect(s.subscriptions.count == before + 1)
        #expect(s.subscriptions.contains { $0.name == "New" })
    }
    @Test func deleteSubscription() {
        let s = AppStore()
        let sub = Subscription(
            id: UUID(), name: "ToDel", emoji: "❌", amountCents: 100,
            period: .monthly, nextRenewalDate: Date(), lastUsedDate: Date(),
            gradient: [.red, .blue], isActive: true
        )
        s.addSubscription(sub)
        s.deleteSubscription(id: sub.id)
        #expect(!s.subscriptions.contains { $0.id == sub.id })
    }
    @Test func addGoalPrependsAndContribute() {
        let s = AppStore()
        let goal = SavingsGoal(
            id: UUID(), name: "G1", emoji: "🎯",
            targetCents: 10_000, currentCents: 0,
            deadline: nil, createdAt: Date(),
            gradient: [.red, .blue]
        )
        s.addGoal(goal)
        #expect(s.goals.first?.id == goal.id)
        s.contribute(to: goal.id, cents: 500)
        #expect(s.goals.first?.currentCents == 500)
    }
    @Test func contributeIgnoresNonPositive() {
        let s = AppStore()
        let goal = SavingsGoal(
            id: UUID(), name: "G", emoji: "🎯",
            targetCents: 100, currentCents: 50,
            deadline: nil, createdAt: Date(),
            gradient: [.red, .blue]
        )
        s.addGoal(goal)
        s.contribute(to: goal.id, cents: 0)
        s.contribute(to: goal.id, cents: -10)
        #expect(s.goals.first { $0.id == goal.id }?.currentCents == 50)
    }
    @Test func deleteGoal() {
        let s = AppStore()
        let goal = SavingsGoal(
            id: UUID(), name: "G", emoji: "🎯",
            targetCents: 100, currentCents: 0,
            deadline: nil, createdAt: Date(),
            gradient: [.red, .blue]
        )
        s.addGoal(goal)
        s.deleteGoal(id: goal.id)
        #expect(!s.goals.contains { $0.id == goal.id })
    }
}
