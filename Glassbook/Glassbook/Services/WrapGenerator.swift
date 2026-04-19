import Foundation

/// Spec §6.2 Hero 1 · 年度回顾. Data layer — `AnnualWrapView` renders these fields.
struct AnnualStats: Hashable {
    var year: Int
    var totalExpenseCents: Int
    var totalIncomeCents: Int
    var topDay: (date: Date, amountCents: Int)?
    var topCategory: Category?
    var topPersona: String
    var topMerchants: [(name: String, cents: Int)]
    var uniqueMerchants: Int
    var newMerchantsTried: Int
    var txCount: Int
    var busiestMonth: (label: String, cents: Int)?
    var quietestMonth: (label: String, cents: Int)?

    static func == (lhs: AnnualStats, rhs: AnnualStats) -> Bool { lhs.year == rhs.year }
    func hash(into h: inout Hasher) { h.combine(year) }
}

enum WrapGenerator {

    static func stats(for year: Int, transactions: [Transaction]) -> AnnualStats {
        let cal = Calendar(identifier: .gregorian)
        let yearTx = transactions.filter { cal.component(.year, from: $0.timestamp) == year }
        let expense = yearTx.filter { $0.kind == .expense }
        let income = yearTx.filter { $0.kind == .income }

        // Top day
        let byDay = Dictionary(grouping: expense) { cal.startOfDay(for: $0.timestamp) }
        let dayTotals: [(Date, Int)] = byDay.map { ($0.key, $0.value.reduce(0) { $0 + $1.amountCents }) }
        let topDay = dayTotals.max { $0.1 < $1.1 }

        // Top category
        var catSums = [Category.Slug: Int]()
        for t in expense { catSums[t.categoryID, default: 0] += t.amountCents }
        let topCatSlug = catSums.max { $0.value < $1.value }?.key
        let topCat = topCatSlug.map { Category.by($0) }

        // Top 5 merchants
        var merchantSums = [String: Int]()
        for t in expense { merchantSums[t.merchant, default: 0] += t.amountCents }
        let sortedMerchants = merchantSums.sorted { $0.value > $1.value }.prefix(5)
        let topMerchants = sortedMerchants.map { (name: $0.key, cents: $0.value) }

        // Monthly totals — busiest / quietest
        var monthTotals = [Int: Int]()  // month → cents
        for t in expense {
            let m = cal.component(.month, from: t.timestamp)
            monthTotals[m, default: 0] += t.amountCents
        }
        let busiest = monthTotals.max { $0.value < $1.value }
        let quietest = monthTotals.min { $0.value < $1.value }

        return AnnualStats(
            year: year,
            totalExpenseCents: expense.reduce(0) { $0 + $1.amountCents },
            totalIncomeCents: income.reduce(0) { $0 + $1.amountCents },
            topDay: topDay.map { (date: $0.0, amountCents: $0.1) },
            topCategory: topCat,
            topPersona: persona(for: topCat),
            topMerchants: Array(topMerchants),
            uniqueMerchants: Set(expense.map(\.merchant)).count,
            newMerchantsTried: Set(expense.map(\.merchant)).count,
            txCount: yearTx.count,
            busiestMonth: busiest.map { (label: "\($0.key) 月", cents: $0.value) },
            quietestMonth: quietest.map { (label: "\($0.key) 月", cents: $0.value) }
        )
    }

    private static func persona(for cat: Category?) -> String {
        guard let cat else { return "生活家" }
        switch cat.id {
        case .food:          return "美食探索家"
        case .transport:     return "城市游牧者"
        case .shopping:      return "生活装备官"
        case .entertainment: return "体验收藏家"
        case .home:          return "家居布道者"
        case .health:        return "健康管理员"
        case .learning:      return "终身学习者"
        case .kids:          return "家庭守护者"
        case .other:         return "多元主义者"
        }
    }
}
