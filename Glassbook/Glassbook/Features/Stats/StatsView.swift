import SwiftUI
import Charts

/// Spec §4.4 · 数据统计
struct StatsView: View {
    @Environment(AppStore.self) private var store
    @State private var period: Period = .month

    enum Period: String, CaseIterable { case week = "周", month = "月", quarter = "季", year = "年" }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                nav
                periodTabs
                donutCard
                trendCard
                insightsSection
                Spacer().frame(height: 100)
            }
            .padding(.horizontal, 18)
        }
        .scrollIndicators(.hidden)
        .safeAreaPadding(.top, 8)
    }

    @ViewBuilder private var insightsSection: some View {
        HStack {
            Text("消费洞察").font(.system(size: 13, weight: .medium))
            Spacer()
            Text("AI 每日更新").font(.system(size: 10))
                .foregroundStyle(AppColors.ink3)
        }
        .padding(.horizontal, 4)
        .padding(.top, 8)

        InsightsView().environment(store)
    }

    private var nav: some View {
        HStack {
            Spacer()
            Text("统计").font(.system(size: 18, weight: .medium))
            Spacer()
            Image(systemName: "square.and.arrow.up").font(.system(size: 13))
                .frame(width: 34, height: 34)
                .glassCard(radius: 12)
        }
        .padding(.top, 4).padding(.bottom, 4)
    }

    private var periodTabs: some View {
        HStack(spacing: 6) {
            ForEach(Period.allCases, id: \.self) { p in
                Button { period = p } label: {
                    Text(p.rawValue)
                        .font(.system(size: 11, weight: period == p ? .medium : .regular))
                        .foregroundStyle(period == p ? AppColors.ink : AppColors.ink2)
                        .frame(maxWidth: .infinity, minHeight: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(period == p ? Color.white : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .glassCard(radius: 12)
    }

    private var categoryData: [(Category, Int)] { store.expensesByCategory(in: Date()) }

    private var donutCard: some View {
        HStack(spacing: 18) {
            ZStack {
                if #available(iOS 17, *) {
                    Chart(Array(categoryData.enumerated()), id: \.element.0.id) { idx, item in
                        SectorMark(
                            angle: .value("amt", item.1),
                            innerRadius: .ratio(0.62),
                            angularInset: 1.2
                        )
                        .foregroundStyle(LinearGradient.gradient(item.0.gradient))
                    }
                    .frame(width: 110, height: 110)
                }
                VStack(spacing: 2) {
                    Text("本月总计").eyebrowStyle().font(.system(size: 9)).tracking(1.2)
                    Text(Money.yuan(totalCents, showDecimals: false))
                        .font(.system(size: 18, weight: .light).monospacedDigit())
                }
            }
            .frame(width: 110, height: 110)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(categoryData.prefix(6), id: \.0.id) { item in
                    HStack {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(LinearGradient.gradient(item.0.gradient))
                            .frame(width: 8, height: 8)
                        Text(item.0.name).font(.system(size: 11))
                            .foregroundStyle(AppColors.ink2)
                        Spacer()
                        Text(Money.yuan(item.1, showDecimals: false))
                            .font(.system(size: 11, weight: .medium).monospacedDigit())
                            .foregroundStyle(AppColors.ink)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(20)
        .glassCard()
    }

    private var totalCents: Int { categoryData.reduce(0) { $0 + $1.1 } }

    private var trendCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("近 7 个月趋势").font(.system(size: 13, weight: .medium))
            Text("本月较上月 \(monthOverMonth)").font(.system(size: 10))
                .foregroundStyle(AppColors.ink3)
                .padding(.bottom, 12)

            let trend = store.monthlyTrend(months: 7)
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(Array(trend.enumerated()), id: \.offset) { idx, item in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                idx == trend.count - 1
                                  ? AnyShapeStyle(LinearGradient(colors: [AppColors.brandStart, AppColors.brandEnd],
                                                                 startPoint: .top, endPoint: .bottom))
                                  : AnyShapeStyle(LinearGradient(colors: [AppColors.auroraPink, AppColors.auroraPurple],
                                                                 startPoint: .top, endPoint: .bottom).opacity(0.55))
                            )
                            .frame(width: 16, height: max(6, CGFloat(item.expenseCents) / CGFloat(maxTrend(trend)) * 80))
                        Text(item.label)
                            .font(.system(size: 9).monospacedDigit())
                            .foregroundStyle(AppColors.ink3)
                    }
                    .frame(maxWidth: .infinity)
                }
            }.frame(height: 110)
        }
        .padding(18)
        .glassCard()
    }

    private func maxTrend(_ t: [(String, Int, Int)]) -> Int {
        t.map(\.1).max() ?? 1
    }

    private var monthOverMonth: String {
        let pct = store.monthOverMonthChangePct * 100
        if pct == 0 { return "持平" }
        let dir = pct > 0 ? "上升" : "下降"
        return String(format: "\(dir) %.1f%%", abs(pct))
    }

}

#Preview {
    ZStack {
        AuroraBackground(palette: .stats)
        StatsView().environment(AppStore())
    }
}
