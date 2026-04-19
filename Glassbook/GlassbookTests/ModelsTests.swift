import Testing
import Foundation
import SwiftUI
@testable import Glassbook

@Suite("Category") struct CategoryTests {
    @Test func allNineCategories() {
        #expect(Category.all.count == 9)
    }
    @Test func eachCategoryReachableByID() {
        for cat in Category.all {
            let got = Category.by(cat.id)
            #expect(got.id == cat.id)
            #expect(got.name == cat.name)
        }
    }
    @Test func eachHasTwoColorGradient() {
        for cat in Category.all {
            #expect(cat.gradient.count == 2)
        }
    }
    @Test func eachHasEmojiAndName() {
        for cat in Category.all {
            #expect(!cat.emoji.isEmpty)
            #expect(!cat.name.isEmpty)
        }
    }
    @Test func kidsCategoryIncluded() {
        #expect(Category.all.contains { $0.id == .kids })
    }
}

@Suite("Transaction") struct TransactionTests {
    private func make(_ kind: Glassbook.Transaction.Kind, cents: Int = 12_345) -> Glassbook.Transaction {
        Glassbook.Transaction(id: UUID(), kind: kind, amountCents: cents,
                              categoryID: .food, accountID: UUID(),
                              timestamp: Date(), merchant: "m", note: nil, source: .manual)
    }
    @Test func amountConvertsCentsToDecimal() {
        let tx = make(.expense, cents: 12_345)
        #expect(tx.amount == Decimal(string: "123.45"))
    }
    @Test func expenseSignedNegative() {
        #expect(make(.expense, cents: 10_000).signedAmount == Decimal(-100))
    }
    @Test func incomeSignedPositive() {
        #expect(make(.income, cents: 10_000).signedAmount == Decimal(100))
    }
    @Test func transferSignedNegative() {
        // Transfer behaves like expense in signedAmount (outbound).
        #expect(make(.transfer, cents: 10_000).signedAmount == Decimal(-100))
    }
}

@Suite("Subscription") struct SubscriptionTests {
    private func make(period: Subscription.Period, amount: Int, lastUsedDaysAgo: Int = 0,
                      renewInDays: Int = 7) -> Subscription {
        Subscription(id: UUID(), name: "n", emoji: "📱",
                     amountCents: amount, period: period,
                     nextRenewalDate: Date().addingTimeInterval(TimeInterval(renewInDays) * 86400),
                     lastUsedDate: Date().addingTimeInterval(TimeInterval(-lastUsedDaysAgo) * 86400),
                     gradient: [Color.red, Color.blue], isActive: true)
    }
    @Test func monthlyEquivalentForWeekly() {
        // 100 cents weekly → 100 * 52 / 12 = 433.33 → 433
        #expect(make(period: .weekly, amount: 100).monthlyEquivalentCents == 433)
    }
    @Test func monthlyEquivalentForMonthly() {
        #expect(make(period: .monthly, amount: 5_000).monthlyEquivalentCents == 5_000)
    }
    @Test func monthlyEquivalentForYearly() {
        #expect(make(period: .yearly, amount: 12_000).monthlyEquivalentCents == 1_000)
    }
    @Test func zombieLevelActiveRecent() {
        #expect(make(period: .monthly, amount: 1, lastUsedDaysAgo: 2).zombieLevel == .active)
    }
    @Test func zombieLevelIdle30Days() {
        #expect(make(period: .monthly, amount: 1, lastUsedDaysAgo: 45).zombieLevel == .idle)
    }
    @Test func zombieLevelDormant90Days() {
        #expect(make(period: .monthly, amount: 1, lastUsedDaysAgo: 95).zombieLevel == .dormant)
    }
    @Test func daysSinceLastUseNonNegative() {
        #expect(make(period: .monthly, amount: 1, lastUsedDaysAgo: 10).daysSinceLastUse >= 9)
    }
    @Test func daysToRenewalPositive() {
        // `dateComponents([.day], …)` floors to whole days, so capturing `now`
        // in the test and then again in `daysToRenewal` can yield 2 instead of 3.
        // Allow a 1-day tolerance for that boundary.
        let days = make(period: .monthly, amount: 1, renewInDays: 3).daysToRenewal
        #expect(days == 3 || days == 2)
    }
    @Test func periodMetadataPresent() {
        for p in Subscription.Period.allCases {
            #expect(!p.displayName.isEmpty)
            #expect(p.daysBetween > 0)
        }
    }
}

@Suite("SavingsGoal") struct SavingsGoalTests {
    private func make(target: Int, current: Int, deadlineInDays: Int? = 100) -> SavingsGoal {
        let deadline = deadlineInDays.flatMap {
            Calendar.current.date(byAdding: .day, value: $0, to: .now)
        }
        return SavingsGoal(id: UUID(), name: "n", emoji: "🎯",
                           targetCents: target, currentCents: current,
                           deadline: deadline, createdAt: Date(),
                           gradient: [Color.red, Color.blue])
    }
    @Test func progressQuarterWay() {
        #expect(make(target: 1_000, current: 250).progress == 0.25)
    }
    @Test func progressClampedAtOne() {
        #expect(make(target: 1_000, current: 5_000).progress == 1.0)
    }
    @Test func progressZeroWhenTargetZero() {
        #expect(make(target: 0, current: 100).progress == 0)
    }
    @Test func dailyTargetWithDeadline() {
        let g = make(target: 10_000, current: 0, deadlineInDays: 100)
        let daily = g.dailyTargetCents
        #expect(daily != nil)
        #expect(daily! >= 95 && daily! <= 105) // allow for day-boundary rounding
    }
    @Test func dailyTargetNilWhenNoDeadline() {
        #expect(make(target: 1_000, current: 0, deadlineInDays: nil).dailyTargetCents == nil)
    }
    @Test func daysRemainingBound() {
        let g = make(target: 100, current: 0, deadlineInDays: 30)
        #expect((g.daysRemaining ?? 0) >= 29)
    }
}

@Suite("Budget") struct BudgetTests {
    @Test func defaultHasPerCategory() {
        let b = Budget.default
        #expect(b.monthlyTotalCents == 600_000)
        #expect(b.perCategory.count >= 5)
        #expect(b.perCategory[.food] != nil)
    }
}

@Suite("Mood enum") struct MoodTests {
    @Test func allHaveDisplayAndEmoji() {
        for m in Mood.allCases {
            #expect(!m.displayName.isEmpty)
            #expect(!m.emoji.isEmpty)
            #expect(m.tintHex > 0)
        }
    }
    @Test func fiveMoods() { #expect(Mood.allCases.count == 5) }
    @Test func rawRoundtrip() {
        for m in Mood.allCases {
            #expect(Mood(rawValue: m.rawValue) == m)
        }
    }
}

@Suite("Visibility enum") struct VisibilityTests {
    @Test func threeLevels() { #expect(Glassbook.Visibility.allCases.count == 3) }
    @Test func eachHasDisplayAndEmoji() {
        for v in Glassbook.Visibility.allCases {
            #expect(!v.displayName.isEmpty)
            #expect(!v.emoji.isEmpty)
        }
    }
}

@Suite("FamilyMember") struct FamilyMemberTests {
    @Test func roleMetadata() {
        for r in [FamilyMember.Role.admin, .member, .childPassive] {
            #expect(!r.displayName.isEmpty)
            #expect(!r.lockEmoji.isEmpty)
        }
    }
    @Test func adminIsUnlocked() {
        #expect(FamilyMember.Role.admin.lockEmoji == "🔓")
    }
    @Test func memberIsLocked() {
        #expect(FamilyMember.Role.member.lockEmoji == "🔒")
    }
    @Test func childPassiveHasEye() {
        #expect(FamilyMember.Role.childPassive.lockEmoji == "👀")
    }
}

@Suite("ImportBatch Platform") struct ImportBatchPlatformTests {
    @Test func allPlatformsHaveMetadata() {
        for p in ImportBatch.Platform.allCases {
            #expect(!p.displayName.isEmpty)
            #expect(!p.abbrev.isEmpty)
            #expect(p.gradient.count == 2)
            #expect(!p.supportedFormats.isEmpty)
        }
    }
}
