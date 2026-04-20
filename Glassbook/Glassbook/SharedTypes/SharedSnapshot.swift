import Foundation

/// Cross-target home-screen summary — small enough to JSON-encode and stash
/// in the App Group `UserDefaults` on every AppStore mutation, then decoded
/// by the Widget provider and the Watch app.
///
/// Scope: intentionally narrow. Only the numbers the non-iOS surfaces actually
/// render. Keeping the struct tiny minimizes serialization cost on hot paths.
struct SharedSnapshot: Codable, Hashable {
    var monthExpenseCents: Int
    var monthBudgetCents: Int
    var dailyAverageCents: Int
    var topCategoryName: String
    var topCategoryEmoji: String
    var recentTransactions: [RecentTx]
    var updatedAt: Date

    struct RecentTx: Codable, Hashable, Identifiable {
        var id: String { "\(merchant)-\(cents)-\(timeLabel)" }
        let merchant: String
        let emoji: String
        let cents: Int
        let timeLabel: String
    }

    static let empty = SharedSnapshot(
        monthExpenseCents: 0,
        monthBudgetCents: 0,
        dailyAverageCents: 0,
        topCategoryName: "—",
        topCategoryEmoji: "✨",
        recentTransactions: [],
        updatedAt: .now
    )
}

/// App Group-backed storage. All three targets (iOS app, Widget extension,
/// watchOS app) declare the same app-group entitlement so this suite is
/// visible everywhere.
enum SharedStorage {
    static let suiteName = "group.app.glassbook.ios"
    static let snapshotKey = "glassbook.home.snapshot"

    static var defaults: UserDefaults? {
        UserDefaults(suiteName: suiteName)
    }

    static func write(_ snapshot: SharedSnapshot) {
        guard let d = defaults else { return }
        if let data = try? JSONEncoder().encode(snapshot) {
            d.set(data, forKey: snapshotKey)
        }
    }

    static func read() -> SharedSnapshot? {
        guard let d = defaults, let data = d.data(forKey: snapshotKey) else { return nil }
        return try? JSONDecoder().decode(SharedSnapshot.self, from: data)
    }
}
