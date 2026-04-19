import Foundation
import SwiftData
import SwiftUI
import UIKit

// SwiftData-backed persistence.
// Spec §8.2 recommends Core Data; SwiftData is the 2023 Swift wrapper on the same
// Core Data / SQLite substrate — pure-Swift API, `@Observable` friendly, one-line
// CloudKit integration. All deployment-target guarantees hold (iOS 17+).
//
// CloudKit compatibility rule: every non-optional @Model attribute must have a
// *literal* default value (string/int/bool/enum-case). UUID() and Date() are
// runtime initializers and are rejected — those attributes are declared optional
// here and always populated via the designated init. Round-trip `toStruct()`
// unwraps with sensible fallbacks.

// MARK: - Transaction

@Model
final class SDTransaction {
    var id: UUID?
    var kindRaw: String = "expense"
    var amountCents: Int = 0
    var categoryRaw: String = "other"
    var accountID: UUID?
    var timestamp: Date?
    var merchant: String = ""
    var note: String?
    var sourceRaw: String = "manual"
    var importBatchID: UUID?
    var moodRaw: String?
    var visibilityRaw: String = "family"
    var originalCurrencyRaw: String = "cny"
    var originalAmountCents: Int?

    init(id: UUID = UUID(),
         kind: Transaction.Kind,
         amountCents: Int,
         categoryID: Category.Slug,
         accountID: UUID,
         timestamp: Date = .now,
         merchant: String,
         note: String? = nil,
         source: Transaction.Source = .manual,
         importBatchID: UUID? = nil,
         mood: Mood? = nil,
         visibility: Visibility = .family,
         originalCurrency: Currency = .cny,
         originalAmountCents: Int? = nil) {
        self.id = id
        self.kindRaw = kind.rawValue
        self.amountCents = amountCents
        self.categoryRaw = categoryID.rawValue
        self.accountID = accountID
        self.timestamp = timestamp
        self.merchant = merchant
        self.note = note
        self.sourceRaw = source.rawValue
        self.importBatchID = importBatchID
        self.moodRaw = mood?.rawValue
        self.visibilityRaw = visibility.rawValue
        self.originalCurrencyRaw = originalCurrency.rawValue
        self.originalAmountCents = originalAmountCents
    }

    convenience init(from tx: Transaction) {
        self.init(
            id: tx.id, kind: tx.kind, amountCents: tx.amountCents,
            categoryID: tx.categoryID, accountID: tx.accountID,
            timestamp: tx.timestamp, merchant: tx.merchant, note: tx.note,
            source: tx.source, importBatchID: tx.importBatchID,
            mood: tx.mood, visibility: tx.visibility,
            originalCurrency: tx.originalCurrency,
            originalAmountCents: tx.originalAmountCents
        )
    }

    var kind: Transaction.Kind { .init(rawValue: kindRaw) ?? .expense }
    var categoryID: Category.Slug { .init(rawValue: categoryRaw) ?? .other }
    var source: Transaction.Source { .init(rawValue: sourceRaw) ?? .manual }
    var mood: Mood? { moodRaw.flatMap(Mood.init(rawValue:)) }
    var visibility: Visibility { Visibility(rawValue: visibilityRaw) ?? .family }
    var originalCurrency: Currency { Currency(rawValue: originalCurrencyRaw) ?? .cny }

    func toStruct() -> Transaction {
        Transaction(id: id ?? UUID(),
                    kind: kind,
                    amountCents: amountCents,
                    categoryID: categoryID,
                    accountID: accountID ?? UUID(),
                    timestamp: timestamp ?? .now,
                    merchant: merchant,
                    note: note,
                    source: source,
                    importBatchID: importBatchID,
                    mood: mood,
                    visibility: visibility,
                    originalCurrency: originalCurrency,
                    originalAmountCents: originalAmountCents)
    }
}

// MARK: - Account

@Model
final class SDAccount {
    var id: UUID?
    var name: String = ""
    var typeRaw: String = "cash"
    var balanceCents: Int = 0
    var isPrimary: Bool = false

    init(id: UUID = UUID(), name: String, type: Account.Kind, balanceCents: Int, isPrimary: Bool) {
        self.id = id
        self.name = name
        self.typeRaw = type.rawValue
        self.balanceCents = balanceCents
        self.isPrimary = isPrimary
    }

    convenience init(from a: Account) {
        self.init(id: a.id, name: a.name, type: a.type, balanceCents: a.balanceCents, isPrimary: a.isPrimary)
    }

    var type: Account.Kind { .init(rawValue: typeRaw) ?? .cash }

    func toStruct() -> Account {
        Account(id: id ?? UUID(), name: name, type: type,
                balanceCents: balanceCents, isPrimary: isPrimary)
    }
}

// MARK: - Budget (single row; use first match)

@Model
final class SDBudget {
    var monthlyTotalCents: Int = 600_000
    /// Encoded as "slug:cents,slug:cents,…" string for simplicity.
    var perCategoryEncoded: String = ""

    init(monthlyTotalCents: Int, perCategory: [Category.Slug: Int]) {
        self.monthlyTotalCents = monthlyTotalCents
        self.perCategoryEncoded = Self.encode(perCategory)
    }

    convenience init(from b: Budget) {
        self.init(monthlyTotalCents: b.monthlyTotalCents, perCategory: b.perCategory)
    }

    static func encode(_ dict: [Category.Slug: Int]) -> String {
        dict.map { "\($0.key.rawValue):\($0.value)" }.joined(separator: ",")
    }
    static func decode(_ s: String) -> [Category.Slug: Int] {
        var out: [Category.Slug: Int] = [:]
        for pair in s.split(separator: ",") {
            let kv = pair.split(separator: ":")
            guard kv.count == 2,
                  let slug = Category.Slug(rawValue: String(kv[0])),
                  let cents = Int(kv[1]) else { continue }
            out[slug] = cents
        }
        return out
    }

    func toStruct() -> Budget {
        Budget(monthlyTotalCents: monthlyTotalCents, perCategory: Self.decode(perCategoryEncoded))
    }
}

// MARK: - Import Batch (for rollback · Spec §5.5)

@Model
final class SDImportBatch {
    var id: UUID?
    var platformRaw: String = "otherBank"
    var importedAt: Date?
    var totalTxCount: Int = 0
    var totalAmountCents: Int = 0
    var duplicatesSkipped: Int = 0

    init(id: UUID = UUID(),
         platform: ImportBatch.Platform,
         importedAt: Date = .now,
         totalTxCount: Int,
         totalAmountCents: Int,
         duplicatesSkipped: Int) {
        self.id = id
        self.platformRaw = platform.rawValue
        self.importedAt = importedAt
        self.totalTxCount = totalTxCount
        self.totalAmountCents = totalAmountCents
        self.duplicatesSkipped = duplicatesSkipped
    }

    var platform: ImportBatch.Platform { .init(rawValue: platformRaw) ?? .otherBank }
}

// MARK: - Subscription (Spec v2 §6.2 Hero 3)

@Model
final class SDSubscription {
    var id: UUID?
    var name: String = ""
    var emoji: String = "📱"
    var amountCents: Int = 0
    var periodRaw: String = "monthly"
    var nextRenewalDate: Date?
    var lastUsedDate: Date?
    var gradientStartHex: UInt32 = 0xFF6B9D
    var gradientEndHex: UInt32 = 0x7EA8FF
    var isActive: Bool = true

    init(id: UUID = UUID(), name: String, emoji: String, amountCents: Int,
         period: Subscription.Period, nextRenewalDate: Date, lastUsedDate: Date,
         gradientStart: UInt32, gradientEnd: UInt32, isActive: Bool = true) {
        self.id = id; self.name = name; self.emoji = emoji
        self.amountCents = amountCents; self.periodRaw = period.rawValue
        self.nextRenewalDate = nextRenewalDate; self.lastUsedDate = lastUsedDate
        self.gradientStartHex = gradientStart; self.gradientEndHex = gradientEnd
        self.isActive = isActive
    }

    convenience init(from s: Subscription) {
        let (a, b) = SDHex.pair(from: s.gradient)
        self.init(id: s.id, name: s.name, emoji: s.emoji, amountCents: s.amountCents,
                  period: s.period, nextRenewalDate: s.nextRenewalDate, lastUsedDate: s.lastUsedDate,
                  gradientStart: a, gradientEnd: b, isActive: s.isActive)
    }

    func toStruct() -> Subscription {
        Subscription(id: id ?? UUID(), name: name, emoji: emoji, amountCents: amountCents,
                     period: Subscription.Period(rawValue: periodRaw) ?? .monthly,
                     nextRenewalDate: nextRenewalDate ?? .now,
                     lastUsedDate: lastUsedDate ?? .now,
                     gradient: [Color(hex: gradientStartHex), Color(hex: gradientEndHex)],
                     isActive: isActive)
    }
}

// MARK: - Savings Goal (Spec v2 §6.2 Hero 2)

@Model
final class SDSavingsGoal {
    var id: UUID?
    var name: String = ""
    var emoji: String = "🎯"
    var targetCents: Int = 0
    var currentCents: Int = 0
    var deadline: Date?
    var createdAt: Date?
    var gradientStartHex: UInt32 = 0xFF6B9D
    var gradientEndHex: UInt32 = 0x7EA8FF

    init(id: UUID = UUID(), name: String, emoji: String, targetCents: Int,
         currentCents: Int, deadline: Date?, createdAt: Date,
         gradientStart: UInt32, gradientEnd: UInt32) {
        self.id = id; self.name = name; self.emoji = emoji
        self.targetCents = targetCents; self.currentCents = currentCents
        self.deadline = deadline; self.createdAt = createdAt
        self.gradientStartHex = gradientStart; self.gradientEndHex = gradientEnd
    }

    convenience init(from g: SavingsGoal) {
        let (a, b) = SDHex.pair(from: g.gradient)
        self.init(id: g.id, name: g.name, emoji: g.emoji, targetCents: g.targetCents,
                  currentCents: g.currentCents, deadline: g.deadline, createdAt: g.createdAt,
                  gradientStart: a, gradientEnd: b)
    }

    func toStruct() -> SavingsGoal {
        SavingsGoal(id: id ?? UUID(), name: name, emoji: emoji, targetCents: targetCents,
                    currentCents: currentCents, deadline: deadline,
                    createdAt: createdAt ?? .now,
                    gradient: [Color(hex: gradientStartHex), Color(hex: gradientEndHex)])
    }
}

// Helper for color ↔ UInt32 round-trip in SwiftData.
private enum SDHex {
    static func pair(from colors: [Color]) -> (UInt32, UInt32) {
        let first = colors.first.flatMap(encode(_:)) ?? 0xFF6B9D
        let last  = colors.last.flatMap(encode(_:))  ?? 0x7EA8FF
        return (first, last)
    }
    static func encode(_ color: Color) -> UInt32? {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        return (UInt32(max(0, min(255, r * 255))) << 16)
             | (UInt32(max(0, min(255, g * 255))) <<  8)
             |  UInt32(max(0, min(255, b * 255)))
    }
}

// MARK: - Learned merchant→category mapping (§5.4 学习能力)

@Model
final class SDMerchantLearning {
    var merchantKey: String = ""   // lowercased
    var categoryRaw: String = "other"
    var lastTouched: Date?

    init(merchantKey: String, category: Category.Slug, lastTouched: Date = .now) {
        self.merchantKey = merchantKey.lowercased()
        self.categoryRaw = category.rawValue
        self.lastTouched = lastTouched
    }

    var category: Category.Slug { .init(rawValue: categoryRaw) ?? .other }
}
