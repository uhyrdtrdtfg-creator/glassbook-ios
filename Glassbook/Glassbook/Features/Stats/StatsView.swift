import SwiftUI
import Charts

/// Spec §4.4 · 数据统计
struct StatsView: View {
    @Environment(AppStore.self) private var store
    @State private var period: Period = .month

    enum Period: String, CaseIterable {
        case week = "周"
        case month = "月"
        case quarter = "季"
        case year = "年"
    }

    private struct TrendPoint: Identifiable {
        let id = UUID()
        let label: String
        let value: Int
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                nav
                heroCard
                periodTabs
                donutCard
                trendCard
                insightsSection
                Spacer().frame(height: 110)
            }
            .padding(.horizontal, 18)
            .padding(.top, 6)
        }
        .scrollIndicators(.hidden)
        .safeAreaPadding(.top, 8)
    }

    private var nav: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("统计")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(AppColors.ink)
                Text(rangeDescription)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppColors.ink2)
            }

            Spacer()

            HStack(spacing: 8) {
                pillIcon("sparkles", tint: [AppColors.brandStart, AppColors.brandEnd])
                pillIcon("chart.xyaxis.line", tint: [AppColors.auroraAmber, AppColors.brandStart])
            }
        }
    }

    private func pillIcon(_ systemName: String, tint: [Color]) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(LinearGradient.gradient(tint))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
                )
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: 38, height: 38)
        .shadow(color: AppColors.surfaceShadow.opacity(0.45), radius: 10, x: 0, y: 6)
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(periodTitle)
                        .eyebrowStyle()
                    Text(Money.yuan(totalCents, showDecimals: false))
                        .font(.system(size: 34, weight: .light).monospacedDigit())
                        .foregroundStyle(AppColors.ink)
                    Text(comparisonText)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(comparisonTone)
                }

                Spacer(minLength: 10)

                VStack(alignment: .trailing, spacing: 8) {
                    badge(text: period == .month ? "本月默认视图" : "切换中 · \(period.rawValue)", tone: AppColors.ink2)
                    if let topCategory {
                        badge(text: "\(topCategory.name) 领先", tone: AppColors.ink)
                    }
                }
            }

            HStack(spacing: 10) {
                heroMetric(label: "交易", value: "\(expenseTransactions.count) 笔", tone: AppColors.ink)
                heroMetric(label: "均单", value: Money.yuan(averageTicketCents, showDecimals: false), tone: AppColors.ink)
                heroMetric(label: "分类", value: "\(categoryData.count) 类", tone: AppColors.ink)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                .fill(Color.clear)
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [AppColors.brandEnd.opacity(0.28), AppColors.brandAccent.opacity(0.18), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 190, height: 190)
                        .offset(x: 44, y: -88)
                }
        }
        .glassCard(radius: Radius.xl)
    }

    private func badge(text: String, tone: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(tone)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.white.opacity(0.34)))
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.36), lineWidth: 1))
    }

    private func heroMetric(label: String, value: String, tone: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(AppColors.ink3)
            Text(value)
                .font(.system(size: 15, weight: .semibold).monospacedDigit())
                .foregroundStyle(tone)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.28))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.34), lineWidth: 1)
                )
        )
    }

    private var periodTabs: some View {
        HStack(spacing: 6) {
            ForEach(Period.allCases, id: \.self) { value in
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                        period = value
                    }
                } label: {
                    Text(value.rawValue)
                        .font(.system(size: 11, weight: period == value ? .semibold : .medium))
                        .foregroundStyle(period == value ? AppColors.ink : AppColors.ink2)
                        .frame(maxWidth: .infinity, minHeight: 34)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(period == value ? Color.white.opacity(0.60) : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(period == value ? Color.white.opacity(0.72) : Color.clear, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(5)
        .glassCard(radius: 16)
    }

    private var donutCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("分类占比")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppColors.ink)
                    Text(topCategory == nil ? "暂无分类数据" : "看看钱都花在哪些地方")
                        .font(.system(size: 11))
                        .foregroundStyle(AppColors.ink3)
                }
                Spacer()
                if let topCategory, let topValue = categoryData.first?.1 {
                    badge(text: "\(topCategory.name) \(shareText(for: topValue))", tone: AppColors.ink)
                }
            }

            if categoryData.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "chart.pie")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(AppColors.ink3)
                    Text("当前周期暂无足够数据")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppColors.ink2)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 22)
            } else {
                HStack(spacing: 18) {
                    ZStack {
                        if #available(iOS 17, *) {
                            Chart(Array(categoryData.enumerated()), id: \.element.0.id) { _, item in
                                SectorMark(
                                    angle: .value("amt", item.1),
                                    innerRadius: .ratio(0.60),
                                    angularInset: 1.4
                                )
                                .foregroundStyle(LinearGradient.gradient(item.0.gradient))
                            }
                            .frame(width: 132, height: 132)
                        }

                        VStack(spacing: 4) {
                            Text(period.rawValue + "消费")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(AppColors.ink3)
                            Text(Money.yuan(totalCents, showDecimals: false))
                                .font(.system(size: 18, weight: .light).monospacedDigit())
                                .foregroundStyle(AppColors.ink)
                        }
                    }
                    .frame(width: 132, height: 132)

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(categoryData.prefix(6), id: \.0.id) { item in
                            HStack(spacing: 8) {
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(LinearGradient.gradient(item.0.gradient))
                                    .frame(width: 10, height: 10)
                                Text(item.0.name)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(AppColors.ink2)
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(Money.yuan(item.1, showDecimals: false))
                                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                                        .foregroundStyle(AppColors.ink)
                                    Text(shareText(for: item.1))
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundStyle(AppColors.ink3)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(20)
        .glassCard()
    }

    private var trendCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(trendTitle)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppColors.ink)
                    Text(trendSubtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(AppColors.ink3)
                }
                Spacer()
                badge(text: comparisonText, tone: comparisonTone)
            }

            HStack(alignment: .bottom, spacing: 10) {
                ForEach(Array(trendPoints.enumerated()), id: \.element.id) { idx, point in
                    VStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: idx == trendPoints.count - 1
                                        ? [AppColors.brandStart, AppColors.brandEnd]
                                        : [AppColors.auroraPink.opacity(0.58), AppColors.auroraPurple.opacity(0.46)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(height: max(12, CGFloat(point.value) / CGFloat(maxTrendValue) * 110))

                        Text(point.label)
                            .font(.system(size: 9, weight: .medium).monospacedDigit())
                            .foregroundStyle(AppColors.ink3)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 138)
        }
        .padding(20)
        .glassCard()
    }

    @ViewBuilder private var insightsSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("消费洞察")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppColors.ink)
                Text("基于本月行为自动生成")
                    .font(.system(size: 11))
                    .foregroundStyle(AppColors.ink3)
            }
            Spacer()
            badge(text: "AI 每日更新", tone: AppColors.ink2)
        }
        .padding(.horizontal, 4)
        .padding(.top, 2)

        InsightsView().environment(store)
    }

    private var scopedTransactions: [Transaction] {
        store.transactions.filter { contains($0.timestamp, in: period) }
    }

    private var expenseTransactions: [Transaction] {
        scopedTransactions
            .filter { $0.kind == .expense }
            .sorted { $0.timestamp > $1.timestamp }
    }

    private var incomeTransactions: [Transaction] {
        scopedTransactions.filter { $0.kind == .income }
    }

    private var categoryData: [(Category, Int)] {
        var buckets: [Category.Slug: Int] = [:]
        for tx in expenseTransactions {
            buckets[tx.categoryID, default: 0] += tx.amountCents
        }
        return Category.all.compactMap { category in
            guard let cents = buckets[category.id], cents > 0 else { return nil }
            return (category, cents)
        }
        .sorted { $0.1 > $1.1 }
    }

    private var totalCents: Int {
        expenseTransactions.reduce(0) { $0 + $1.amountCents }
    }

    private var comparisonTotalCents: Int {
        comparisonTransactions.filter { $0.kind == .expense }.reduce(0) { $0 + $1.amountCents }
    }

    private var averageTicketCents: Int {
        guard !expenseTransactions.isEmpty else { return 0 }
        return totalCents / expenseTransactions.count
    }

    private var topCategory: Category? {
        categoryData.first?.0
    }

    private var comparisonText: String {
        guard comparisonTotalCents > 0 else { return "暂无对比数据" }
        let pct = (Double(totalCents) - Double(comparisonTotalCents)) / Double(comparisonTotalCents) * 100
        if pct == 0 { return "与上一周期持平" }
        return "\(pct > 0 ? "较上一周期上升" : "较上一周期下降") \(String(format: "%.1f%%", abs(pct)))"
    }

    private var comparisonTone: Color {
        guard comparisonTotalCents > 0 else { return AppColors.ink3 }
        if totalCents == comparisonTotalCents { return AppColors.ink2 }
        return totalCents > comparisonTotalCents ? AppColors.expenseRed : AppColors.incomeGreen
    }

    private var rangeDescription: String {
        let calendar = Calendar.current
        switch period {
        case .week:
            return "近 7 天"
        case .month:
            return Self.monthFmt.string(from: Date())
        case .quarter:
            return "第 \(quarter(of: Date())) 季度"
        case .year:
            return "\(calendar.component(.year, from: Date())) 年"
        }
    }

    private var periodTitle: String {
        switch period {
        case .week: return "近 7 天支出"
        case .month: return "本月总支出"
        case .quarter: return "季度总支出"
        case .year: return "年度总支出"
        }
    }

    private var trendTitle: String {
        switch period {
        case .week: return "最近 7 天走势"
        case .month: return "本月周趋势"
        case .quarter: return "季度月份走势"
        case .year: return "年度月份走势"
        }
    }

    private var trendSubtitle: String {
        switch period {
        case .week: return "观察每天的消费波动"
        case .month: return "按周看清本月起伏"
        case .quarter: return "看看三个月里哪月最重"
        case .year: return "回看全年月份节奏"
        }
    }

    private var trendPoints: [TrendPoint] {
        let calendar = Calendar.current

        switch period {
        case .week:
            return (0..<7).reversed().map { offset in
                let day = calendar.date(byAdding: .day, value: -offset, to: calendar.startOfDay(for: Date())) ?? Date()
                let value = store.transactions
                    .filter { $0.kind == .expense && calendar.isDate($0.timestamp, inSameDayAs: day) }
                    .reduce(0) { $0 + $1.amountCents }
                return TrendPoint(label: Self.weekdayFmt.string(from: day), value: value)
            }

        case .month:
            let monthTransactions = store.transactionsInMonth(Date()).filter { $0.kind == .expense }
            var buckets: [Int: Int] = [:]
            for tx in monthTransactions {
                let week = calendar.component(.weekOfMonth, from: tx.timestamp)
                buckets[week, default: 0] += tx.amountCents
            }
            let weeks = (buckets.keys.min() ?? 1)...(buckets.keys.max() ?? 4)
            return weeks.map { week in
                TrendPoint(label: "W\(week)", value: buckets[week, default: 0])
            }

        case .quarter:
            let months = quarterMonths(containing: Date())
            return months.map { monthDate in
                let value = store.transactionsInMonth(monthDate)
                    .filter { $0.kind == .expense }
                    .reduce(0) { $0 + $1.amountCents }
                return TrendPoint(label: Self.shortMonthFmt.string(from: monthDate), value: value)
            }

        case .year:
            let currentMonth = calendar.component(.month, from: Date())
            return (1...currentMonth).map { monthValue in
                let components = DateComponents(year: calendar.component(.year, from: Date()), month: monthValue, day: 1)
                let date = calendar.date(from: components) ?? Date()
                let value = store.transactionsInMonth(date)
                    .filter { $0.kind == .expense }
                    .reduce(0) { $0 + $1.amountCents }
                return TrendPoint(label: "\(monthValue)", value: value)
            }
        }
    }

    private var maxTrendValue: Int {
        max(trendPoints.map(\.value).max() ?? 0, 1)
    }

    private func shareText(for cents: Int) -> String {
        guard totalCents > 0 else { return "0%" }
        let ratio = Double(cents) / Double(totalCents)
        return "\(Int(round(ratio * 100)))%"
    }

    private func contains(_ date: Date, in period: Period) -> Bool {
        let calendar = Calendar.current
        switch period {
        case .week:
            let today = calendar.startOfDay(for: Date())
            let start = calendar.date(byAdding: .day, value: -6, to: today) ?? today
            return date >= start && date <= Date()
        case .month:
            return calendar.isDate(date, equalTo: Date(), toGranularity: .month)
        case .quarter:
            return calendar.isDate(date, equalTo: Date(), toGranularity: .year)
                && quarter(of: date) == quarter(of: Date())
        case .year:
            return calendar.isDate(date, equalTo: Date(), toGranularity: .year)
        }
    }

    private var comparisonTransactions: [Transaction] {
        let calendar = Calendar.current
        switch period {
        case .week:
            let today = calendar.startOfDay(for: Date())
            let start = calendar.date(byAdding: .day, value: -13, to: today) ?? today
            let end = calendar.date(byAdding: .day, value: -6, to: today) ?? today
            return store.transactions.filter { $0.timestamp >= start && $0.timestamp < end }
        case .month:
            guard let previous = calendar.date(byAdding: .month, value: -1, to: Date()) else { return [] }
            return store.transactionsInMonth(previous)
        case .quarter:
            let currentQuarter = quarter(of: Date())
            var year = calendar.component(.year, from: Date())
            var targetQuarter = currentQuarter - 1
            if targetQuarter == 0 {
                targetQuarter = 4
                year -= 1
            }
            return store.transactions.filter {
                calendar.component(.year, from: $0.timestamp) == year
                    && quarter(of: $0.timestamp) == targetQuarter
            }
        case .year:
            let previousYear = calendar.component(.year, from: Date()) - 1
            return store.transactions.filter { calendar.component(.year, from: $0.timestamp) == previousYear }
        }
    }

    private func quarter(of date: Date) -> Int {
        let month = Calendar.current.component(.month, from: date)
        return ((month - 1) / 3) + 1
    }

    private func quarterMonths(containing date: Date) -> [Date] {
        let calendar = Calendar.current
        let currentQuarter = quarter(of: date)
        let startMonth = (currentQuarter - 1) * 3 + 1
        let year = calendar.component(.year, from: date)
        return (0..<3).compactMap { offset in
            calendar.date(from: DateComponents(year: year, month: startMonth + offset, day: 1))
        }
    }

    private static let monthFmt: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy 年 M 月"
        return formatter
    }()

    private static let shortMonthFmt: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月"
        return formatter
    }()

    private static let weekdayFmt: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "E"
        return formatter
    }()
}

#Preview {
    ZStack {
        AuroraBackground(palette: .stats)
        StatsView().environment(AppStore())
    }
}
