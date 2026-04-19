import SwiftUI

/// Spec §4.3 · 账单明细
struct BillsView: View {
    @Environment(AppStore.self) private var store
    @State private var month: Date = Date()
    @State private var filterCategory: Category.Slug? = nil
    @State private var showFilter = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                nav
                summary
                ForEach(store.txByDay(in: month), id: \.date) { group in
                    dayGroup(date: group.date, items: group.items)
                }
                Spacer().frame(height: 100)
            }
            .padding(.horizontal, 18)
        }
        .scrollIndicators(.hidden)
        .safeAreaPadding(.top, 8)
        .sheet(isPresented: $showFilter) {
            FilterSheet(selected: $filterCategory)
                .presentationDetents([.medium])
        }
    }

    private var nav: some View {
        HStack {
            Button { shiftMonth(-1) } label: {
                Image(systemName: "chevron.left").font(.system(size: 13))
                    .frame(width: 34, height: 34)
                    .glassCard(radius: 12)
                    .foregroundStyle(AppColors.ink)
            }
            Spacer()
            Text(Self.monthFmt.string(from: month))
                .font(.system(size: 18, weight: .medium))
            Spacer()
            Button { showFilter = true } label: {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 13))
                    .frame(width: 34, height: 34)
                    .glassCard(radius: 12)
                    .foregroundStyle(AppColors.ink)
            }
        }
        .padding(.vertical, 4)
    }

    private func shiftMonth(_ by: Int) {
        if let next = Calendar.current.date(byAdding: .month, value: by, to: month) {
            month = next
        }
    }

    private var summary: some View {
        let monthTx = store.transactionsInMonth(month)
        let cents = monthTx.filter { $0.kind == .expense }.reduce(0) { $0 + $1.amountCents }
        let count = monthTx.count
        return HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text("本月支出").eyebrowStyle()
                Text(Money.yuan(cents, showDecimals: true))
                    .font(.system(size: 26, weight: .light).monospacedDigit())
                    .foregroundStyle(AppColors.ink)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                Text("共 \(count) 笔")
                    .font(.system(size: 10)).foregroundStyle(AppColors.ink3)
                HStack(alignment: .bottom, spacing: 2) {
                    ForEach(barHeights, id: \.self) { h in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(LinearGradient(
                                colors: [AppColors.auroraPink, AppColors.auroraPurple],
                                startPoint: .top, endPoint: .bottom))
                            .opacity(0.7)
                            .frame(width: 4, height: h)
                    }
                }.frame(height: 24)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .glassCard()
    }

    private var barHeights: [CGFloat] {
        [40, 70, 50, 90, 30, 65, 80].map { CGFloat($0 * 0.28 + 4) }
    }

    private func dayGroup(date: Date, items: [Transaction]) -> some View {
        let filtered = items.filter { filterCategory == nil || $0.categoryID == filterCategory }
        let sum = filtered.filter { $0.kind == .expense }.reduce(0) { $0 + $1.amountCents }
        return Group {
            if !filtered.isEmpty {
                VStack(spacing: 0) {
                    HStack {
                        Text(Self.dayFmt.string(from: date))
                            .font(.system(size: 11)).foregroundStyle(AppColors.ink2)
                            .tracking(0.5)
                        Spacer()
                        Text(Money.yuan(sum, showDecimals: false))
                            .font(.system(size: 11, weight: .regular).monospacedDigit())
                            .foregroundStyle(AppColors.ink3)
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 6)
                    VStack(spacing: 0) {
                        ForEach(Array(filtered.enumerated()), id: \.element.id) { idx, tx in
                            if idx > 0 { Divider().background(AppColors.glassDivider).padding(.horizontal, 10) }
                            TransactionRow(tx: tx, compact: true)
                        }
                    }
                    .padding(8)
                    .glassCard()
                }
            }
        }
    }

    private static let monthFmt: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M 月账单"
        return f
    }()
    private static let dayFmt: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日 EEEE"
        return f
    }()
}

private struct FilterSheet: View {
    @Binding var selected: Category.Slug?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AuroraBackground(palette: .bills)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("按分类筛选").font(AppFont.h2).padding(.top, 4)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                        chip(nil, label: "全部")
                        ForEach(Category.all, id: \.id) { cat in
                            chip(cat.id, label: cat.name, emoji: cat.emoji)
                        }
                    }
                    Spacer()
                    Button { dismiss() } label: {
                        Text("应用筛选")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(RoundedRectangle(cornerRadius: 14).fill(AppColors.ink))
                    }
                }
                .padding(20)
            }
        }
    }

    private func chip(_ slug: Category.Slug?, label: String, emoji: String = "✨") -> some View {
        Button {
            selected = slug
        } label: {
            HStack(spacing: 6) {
                if slug != nil { Text(emoji) }
                Text(label).font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(selected == slug ? .white : AppColors.ink)
            .frame(maxWidth: .infinity, minHeight: 38)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(selected == slug ? AppColors.ink : Color.white.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12).strokeBorder(AppColors.glassBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack {
        AuroraBackground(palette: .bills)
        BillsView().environment(AppStore())
    }
}
