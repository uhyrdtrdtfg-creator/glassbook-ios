import SwiftUI

/// Spec §6.2 · AI 消费洞察.
/// This is a rule-based engine over historical transactions. "AI" here means
/// observational heuristics — no LLM, no network egress, consistent with
/// the §8.4 privacy-first stance.
struct Insight: Identifiable, Hashable {
    enum Kind: String { case persona, trend, saving, dailyAvg, newMerchant, highSpendingDay, categoryWatch }
    let id = UUID()
    let kind: Kind
    let title: String
    let body: String
    let emoji: String
    let gradient: [Color]
}

enum InsightEngine {

    /// Produce the ordered list of insights a user should see on the Stats page.
    /// Heuristics fire only when there's enough signal — no empty-state chatter.
    static func generate(store: AppStore, now: Date = Date()) -> [Insight] {
        var out: [Insight] = []
        let thisMonth = store.transactionsInMonth(now).filter { $0.kind == .expense }
        guard !thisMonth.isEmpty else {
            return [welcome]
        }

        // 1 · Persona label based on top spend category.
        if let (cat, _) = store.expensesByCategory(in: now).first {
            out.append(Insight(
                kind: .persona,
                title: "消费人格",
                body: persona(for: cat),
                emoji: cat.emoji,
                gradient: cat.gradient
            ))
        }

        // 2 · Daily average
        out.append(Insight(
            kind: .dailyAvg,
            title: "日均消费",
            body: "本月平均每天 \(Money.yuan(store.thisMonthDailyAverageCents, showDecimals: false)),\(rhythmBlurb(avg: store.thisMonthDailyAverageCents))",
            emoji: "📊",
            gradient: [AppColors.brandStart, AppColors.brandEnd]
        ))

        // 3 · Trend alert — month-over-month swing
        let pctRaw = store.monthOverMonthChangePct * 100
        if abs(pctRaw) >= 10 {
            let rising = pctRaw > 0
            out.append(Insight(
                kind: .trend,
                title: rising ? "支出上升提醒" : "控制得不错",
                body: "本月较上月\(rising ? "上升" : "下降") \(String(format: "%.1f", abs(pctRaw)))%。\(rising ? "留意超预算分类。" : "继续保持这个节奏。")",
                emoji: rising ? "📈" : "📉",
                gradient: rising ? [AppColors.expenseRed, AppColors.auroraPink]
                                 : [AppColors.incomeGreen, AppColors.successGreen]
            ))
        }

        // 4 · Saving tip — a frequently-hit merchant where a plan/card would pay off
        let merchantGroups = Dictionary(grouping: thisMonth, by: { $0.merchant })
        if let topMerchant = merchantGroups.max(by: { $0.value.count < $1.value.count }),
           topMerchant.value.count >= 4 {
            let total = topMerchant.value.reduce(0) { $0 + $1.amountCents }
            out.append(Insight(
                kind: .saving,
                title: "省钱建议",
                body: "\(topMerchant.key) 本月去了 \(topMerchant.value.count) 次,共 \(Money.yuan(total, showDecimals: false))。如果有月卡,可能能省 15–30%。",
                emoji: "💡",
                gradient: [AppColors.auroraAmber, AppColors.auroraPink]
            ))
        }

        // 5 · Highest spending day
        let byDay = Dictionary(grouping: thisMonth, by: { Calendar.current.startOfDay(for: $0.timestamp) })
        let dayTotals = byDay.mapValues { rows in rows.reduce(0) { $0 + $1.amountCents } }
        if let top = dayTotals.max(by: { $0.value < $1.value }),
           top.value > store.thisMonthDailyAverageCents * 2 {
            let fmt = DateFormatter(); fmt.locale = .init(identifier: "zh_CN"); fmt.dateFormat = "M 月 d 日"
            out.append(Insight(
                kind: .highSpendingDay,
                title: "本月最贵的一天",
                body: "\(fmt.string(from: top.key)) 花了 \(Money.yuan(top.value, showDecimals: false)),是日均的 \(String(format: "%.1f", Double(top.value) / Double(max(1, store.thisMonthDailyAverageCents))))×。",
                emoji: "🎯",
                gradient: [AppColors.auroraPurple, AppColors.auroraBlue]
            ))
        }

        // 6 · New merchants — exploration signal
        let cal = Calendar.current
        let lastMonthDate = cal.date(byAdding: .month, value: -1, to: now) ?? now
        let lastMonthMerchants = Set(store.transactionsInMonth(lastMonthDate).map(\.merchant))
        let thisMonthMerchants = Set(thisMonth.map(\.merchant))
        let newOnes = thisMonthMerchants.subtracting(lastMonthMerchants)
        if newOnes.count >= 3 {
            out.append(Insight(
                kind: .newMerchant,
                title: "探索新店",
                body: "这个月尝试了 \(newOnes.count) 家新店铺,探索家本色。",
                emoji: "🗺",
                gradient: [AppColors.catLearning[0], AppColors.catLearning[1]]
            ))
        }

        // 7 · Category watch — any category used >50% of its cap
        for (slug, cap) in store.budget.perCategory {
            let used = thisMonth.filter { $0.categoryID == slug }.reduce(0) { $0 + $1.amountCents }
            let pct = cap > 0 ? Double(used) / Double(cap) : 0
            if pct >= 0.9 {
                let cat = Category.by(slug)
                out.append(Insight(
                    kind: .categoryWatch,
                    title: "预算提醒 · \(cat.name)",
                    body: "已用 \(Int(pct * 100))% · 剩余 \(Money.yuan(max(0, cap - used), showDecimals: false))。",
                    emoji: "⚠️",
                    gradient: [AppColors.expenseRed, AppColors.auroraPink]
                ))
                break   // surface at most one category-watch card
            }
        }

        return out
    }

    // MARK: - Helpers

    private static let welcome = Insight(
        kind: .persona,
        title: "开始记账",
        body: "记一笔开始你的第一个洞察。当数据足够时,这里会告诉你未察觉的消费习惯。",
        emoji: "🌱",
        gradient: [AppColors.brandStart, AppColors.brandEnd]
    )

    private static func persona(for cat: Category) -> String {
        switch cat.id {
        case .food:          return "美食探索家 · 餐饮上最舍得花,对味蕾诚实"
        case .transport:     return "城市游牧者 · 行程填满日历,生活在路上"
        case .shopping:      return "理想生活装备官 · 善于为自己添置"
        case .entertainment: return "体验收藏家 · 乐趣值得花钱"
        case .home:          return "家居布道者 · 把日子打理得很好"
        case .health:        return "健康管理员 · 在自己身上很舍得"
        case .learning:      return "终身学习者 · 知识最值得投资"
        case .kids:          return "家庭守护者 · 把孩子放在第一位"
        case .other:         return "多元主义者 · 消费节奏平衡"
        }
    }

    private static func rhythmBlurb(avg: Int) -> String {
        switch avg {
        case ..<10000:   return "过得很节制。"
        case ..<20000:   return "日常节奏。"
        case ..<40000:   return "生活很有品质。"
        default:         return "相当滋润。"
        }
    }
}
