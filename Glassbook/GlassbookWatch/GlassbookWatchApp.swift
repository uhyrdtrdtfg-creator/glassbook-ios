import SwiftUI

@main
struct GlassbookWatchApp: App {
    @State private var sharedSnapshot = WatchSnapshot.placeholder

    var body: some Scene {
        WindowGroup {
            WatchRoot(snapshot: $sharedSnapshot)
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
}
