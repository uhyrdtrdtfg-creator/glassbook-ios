import SwiftUI

@main
struct GlassbookWatchApp: App {
    @State private var sharedSnapshot = WatchSnapshot.load()

    var body: some Scene {
        WindowGroup {
            WatchRoot(snapshot: $sharedSnapshot)
                .onAppear {
                    // Re-read whenever the watch app comes foreground — the
                    // iOS companion may have written a fresher snapshot.
                    sharedSnapshot = WatchSnapshot.load()
                }
        }
    }
}

/// Minimal state shape shared within the watch app.
/// Production: populate via App Group (`UserDefaults(suiteName: "group.app.glassbook.ios")`).
struct WatchSnapshot: Codable, Hashable {
    var monthExpenseCents: Int
    var monthBudgetCents: Int
    var dailyAverageCents: Int
    var topCategoryName: String
    var topCategoryEmoji: String
    var recentTransactions: [WatchRecentTx]

    struct WatchRecentTx: Codable, Hashable, Identifiable {
        var id: String { "\(merchant)-\(cents)-\(timeLabel)" }
        var merchant: String
        var emoji: String
        var cents: Int
        var timeLabel: String
    }

    static let placeholder = WatchSnapshot(
        monthExpenseCents: 428_650,
        monthBudgetCents: 600_000,
        dailyAverageCents: 22_600,
        topCategoryName: "餐饮",
        topCategoryEmoji: "🍜",
        recentTransactions: [
            .init(merchant: "兰州牛肉面", emoji: "🍜", cents: 2800, timeLabel: "今天 12:40"),
            .init(merchant: "地铁通勤",   emoji: "🚇", cents: 600,  timeLabel: "今天 9:12"),
            .init(merchant: "优衣库春装", emoji: "🛍", cents: 29900, timeLabel: "昨天 19:30"),
            .init(merchant: "盒马鲜生",   emoji: "🍜", cents: 8640, timeLabel: "昨天 18:22"),
            .init(merchant: "打车回家",   emoji: "🚇", cents: 4200, timeLabel: "前天 22:05"),
        ]
    )

    /// Read the App Group snapshot the iOS companion writes after each
    /// mutation. Falls back to the placeholder on first install.
    static func load() -> WatchSnapshot {
        guard let shared = SharedStorage.read() else { return .placeholder }
        return WatchSnapshot(
            monthExpenseCents: shared.monthExpenseCents,
            monthBudgetCents: max(shared.monthBudgetCents, 1),
            dailyAverageCents: shared.dailyAverageCents,
            topCategoryName: shared.topCategoryName,
            topCategoryEmoji: shared.topCategoryEmoji,
            recentTransactions: shared.recentTransactions.map {
                .init(merchant: $0.merchant, emoji: $0.emoji, cents: $0.cents, timeLabel: $0.timeLabel)
            }
        )
    }
}
