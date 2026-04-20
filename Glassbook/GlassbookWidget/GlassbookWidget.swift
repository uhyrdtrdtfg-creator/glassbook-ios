import WidgetKit
import SwiftUI

// Spec §6.2 / §8.2 · Spec explicitly calls out 桌面小组件 (WidgetKit) in V1.2.
//
// This scaffold ships three widget families (systemSmall / systemMedium /
// systemLarge) with a placeholder timeline provider. To wire real data:
//   1. Enable "App Groups" capability on both the main app target and this widget
//      (group: `group.app.glassbook.ios`).
//   2. In `AppStore`, on every mutation, write a `WidgetSnapshot` JSON to
//      `UserDefaults(suiteName: "group.app.glassbook.ios")`.
//   3. Replace `TimelineProvider.placeholderSnapshot` with a real load from the suite.
//   4. Call `WidgetCenter.shared.reloadAllTimelines()` after each mutation.

// MARK: - Entry

struct GlassbookEntry: TimelineEntry {
    let date: Date
    let monthExpenseCents: Int
    let monthBudgetCents: Int
    let dailyAverageCents: Int
    let recentTransactions: [RecentTx]
    let topCategory: String

    struct RecentTx: Hashable {
        let merchant: String
        let emoji: String
        let cents: Int
    }

    static let placeholder = GlassbookEntry(
        date: Date(),
        monthExpenseCents: 428_650,
        monthBudgetCents: 600_000,
        dailyAverageCents: 22_600,
        recentTransactions: [
            .init(merchant: "兰州牛肉面", emoji: "🍜", cents: 2800),
            .init(merchant: "地铁通勤",   emoji: "🚇", cents: 600),
            .init(merchant: "优衣库春装", emoji: "🛍", cents: 29900),
        ],
        topCategory: "餐饮"
    )
}

// MARK: - Provider

struct GlassbookProvider: TimelineProvider {
    func placeholder(in context: Context) -> GlassbookEntry { .placeholder }

    func getSnapshot(in context: Context, completion: @escaping (GlassbookEntry) -> Void) {
        completion(liveEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GlassbookEntry>) -> Void) {
        // Refresh every 30 min — widgets are budget-constrained by the system anyway.
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        completion(Timeline(entries: [liveEntry()], policy: .after(next)))
    }

    /// Try the shared App Group snapshot first; fall back to the placeholder
    /// when the user hasn't opened the iOS app since install.
    private func liveEntry() -> GlassbookEntry {
        guard let s = SharedStorage.read() else { return .placeholder }
        return GlassbookEntry(
            date: Date(),
            monthExpenseCents: s.monthExpenseCents,
            monthBudgetCents: max(s.monthBudgetCents, 1),
            dailyAverageCents: s.dailyAverageCents,
            recentTransactions: s.recentTransactions.prefix(5).map {
                .init(merchant: $0.merchant, emoji: $0.emoji, cents: $0.cents)
            },
            topCategory: s.topCategoryName
        )
    }
}

// MARK: - Views

struct SmallWidgetView: View {
    var entry: GlassbookEntry
    var body: some View {
        ZStack {
            widgetBackground

            VStack(alignment: .leading, spacing: 6) {
                Text("本月")
                    .font(.system(size: 10, weight: .medium))
                    .tracking(1.2)
                    .foregroundStyle(.secondary)

                Text(yuan(entry.monthExpenseCents, showDecimals: false))
                    .font(.system(size: 24, weight: .light).monospacedDigit())
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)

                Spacer()

                budgetBar(progress: Double(entry.monthExpenseCents) / Double(entry.monthBudgetCents))

                HStack {
                    Text("日均 \(yuan(entry.dailyAverageCents, showDecimals: false))")
                        .font(.system(size: 9, weight: .medium).monospacedDigit())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(LinearGradient.brand())
                }
            }
            .padding(14)
        }
    }
}

struct MediumWidgetView: View {
    var entry: GlassbookEntry
    var body: some View {
        ZStack {
            widgetBackground

            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("本月支出")
                        .font(.system(size: 10, weight: .medium))
                        .tracking(1.2)
                        .foregroundStyle(.secondary)
                    Text(yuan(entry.monthExpenseCents, showDecimals: false))
                        .font(.system(size: 28, weight: .light).monospacedDigit())
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Text(entry.topCategory + " 占比最高")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Spacer()
                    budgetBar(progress: Double(entry.monthExpenseCents) / Double(entry.monthBudgetCents))
                    Text("预算 \(yuan(entry.monthBudgetCents, showDecimals: false)) · 剩 \(yuan(max(0, entry.monthBudgetCents - entry.monthExpenseCents), showDecimals: false))")
                        .font(.system(size: 9, weight: .medium).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("最近").font(.system(size: 10, weight: .medium)).tracking(1.2).foregroundStyle(.secondary)
                    ForEach(entry.recentTransactions.prefix(3), id: \.self) { tx in
                        HStack(spacing: 6) {
                            Text(tx.emoji).font(.system(size: 12))
                            Text(tx.merchant).font(.system(size: 11)).lineLimit(1)
                            Spacer()
                            Text(yuan(tx.cents, showDecimals: false))
                                .font(.system(size: 11, weight: .medium).monospacedDigit())
                        }
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
        }
    }
}

struct LargeWidgetView: View {
    var entry: GlassbookEntry
    var body: some View {
        ZStack {
            widgetBackground

            VStack(alignment: .leading, spacing: 10) {
                Text("本月概览").font(.system(size: 11, weight: .medium)).tracking(1.2).foregroundStyle(.secondary)
                Text(yuan(entry.monthExpenseCents, showDecimals: false))
                    .font(.system(size: 38, weight: .ultraLight).monospacedDigit())

                budgetBar(progress: Double(entry.monthExpenseCents) / Double(entry.monthBudgetCents))

                Divider().padding(.vertical, 4)

                Text("最近交易").font(.system(size: 10, weight: .medium)).tracking(1.2).foregroundStyle(.secondary)
                ForEach(entry.recentTransactions, id: \.self) { tx in
                    HStack(spacing: 10) {
                        Text(tx.emoji).font(.system(size: 16))
                        Text(tx.merchant).font(.system(size: 13))
                        Spacer()
                        Text(yuan(tx.cents, showDecimals: false))
                            .font(.system(size: 13, weight: .medium).monospacedDigit())
                    }
                }
                Spacer()
            }
            .padding(18)
        }
    }
}

// MARK: - Shared bits

private var widgetBackground: some View {
    LinearGradient(colors: [Color(hex: 0xFDE4D0), Color(hex: 0xE8E2FF)],
                   startPoint: .topLeading, endPoint: .bottomTrailing)
}

@ViewBuilder
private func budgetBar(progress: Double) -> some View {
    GeometryReader { geo in
        ZStack(alignment: .leading) {
            Capsule().fill(Color.white.opacity(0.5))
            Capsule().fill(LinearGradient.brand())
                .frame(width: geo.size.width * CGFloat(min(1.0, max(0, progress))))
        }
    }
    .frame(height: 5)
}

private func yuan(_ cents: Int, showDecimals: Bool = false) -> String {
    let y = cents / 100
    let f = NumberFormatter(); f.numberStyle = .decimal
    let body = f.string(from: NSNumber(value: y)) ?? "\(y)"
    return "¥\(body)"
}

extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >>  8) & 0xFF) / 255
        let b = Double( hex        & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b)
    }
}

extension LinearGradient {
    static func brand() -> LinearGradient {
        LinearGradient(colors: [Color(hex: 0xFF6B9D), Color(hex: 0x7EA8FF)],
                       startPoint: .leading, endPoint: .trailing)
    }
}

// MARK: - Widget declarations

struct GlassbookWidget: Widget {
    let kind = "GlassbookWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: GlassbookProvider()) { entry in
            switch entry {
            case let e:
                Group {
                    if #available(iOSApplicationExtension 17, *) {
                        routedView(entry: e)
                            .containerBackground(.clear, for: .widget)
                    } else {
                        routedView(entry: e)
                    }
                }
            }
        }
        .configurationDisplayName("Glassbook · 本月")
        .description("一眼看清本月支出、预算进度和最近交易。")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }

    @ViewBuilder
    private func routedView(entry: GlassbookEntry) -> some View {
        WidgetRouter(entry: entry)
    }
}

private struct WidgetRouter: View {
    @Environment(\.widgetFamily) var family
    let entry: GlassbookEntry

    var body: some View {
        switch family {
        case .systemSmall:   SmallWidgetView(entry: entry)
        case .systemMedium:  MediumWidgetView(entry: entry)
        case .systemLarge:   LargeWidgetView(entry: entry)
        default:             SmallWidgetView(entry: entry)
        }
    }
}

// MARK: - Bundle (the @main)

@main
struct GlassbookWidgetBundle: WidgetBundle {
    var body: some Widget {
        GlassbookWidget()
        GlassbookLiveActivity()
    }
}

#Preview(as: .systemSmall) {
    GlassbookWidget()
} timeline: {
    GlassbookEntry.placeholder
}
#Preview(as: .systemMedium) {
    GlassbookWidget()
} timeline: {
    GlassbookEntry.placeholder
}
#Preview(as: .systemLarge) {
    GlassbookWidget()
} timeline: {
    GlassbookEntry.placeholder
}
