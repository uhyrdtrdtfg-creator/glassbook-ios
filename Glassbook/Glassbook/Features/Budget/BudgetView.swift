import SwiftUI

/// Spec §4.5 · 预算管理
struct BudgetView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @State private var showEdit = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                nav
                ringCard
                categoryCard
                Spacer().frame(height: 100)
            }
            .padding(.horizontal, 18)
            // why: keep the budget readout in a comfortable column on iPad / Mac.
            .frame(maxWidth: hSizeClass == .regular ? 640 : .infinity)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .safeAreaPadding(.top, 8)
        .sheet(isPresented: $showEdit) {
            EditBudgetSheet().environment(store)
                .presentationDetents([.large])
        }
    }

    private var nav: some View {
        HStack {
            Spacer()
            Text("预算").font(.system(size: 18, weight: .medium))
            Spacer()
            Button { showEdit = true } label: {
                Image(systemName: "pencil").font(.system(size: 13))
                    .frame(width: 34, height: 34)
                    .glassCard(radius: 12)
                    .foregroundStyle(AppColors.ink)
            }
            .buttonStyle(.plain)
        }
    }

    private var ringCard: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.45), lineWidth: 12)
                Circle()
                    .trim(from: 0, to: CGFloat(min(store.budgetUsedPercent, 1.0)))
                    .stroke(
                        LinearGradient(colors: [AppColors.brandStart, AppColors.brandEnd],
                                       startPoint: .leading, endPoint: .trailing),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 4) {
                    Text(String(format: "%.0f%%", store.budgetUsedPercent * 100))
                        .font(.system(size: 30, weight: .ultraLight).monospacedDigit())
                    Text("已使用").eyebrowStyle().font(.system(size: 10)).tracking(1.5)
                }
            }
            .frame(width: 150, height: 150)

            HStack(spacing: 0) {
                info("已花", Money.yuan(store.thisMonthExpenseCents, showDecimals: false))
                Divider().background(AppColors.glassDivider)
                info("剩余", Money.yuan(max(0, store.budgetRemainingCents), showDecimals: false),
                     color: store.budgetRemainingCents < 0 ? AppColors.expenseRed : AppColors.ink)
                Divider().background(AppColors.glassDivider)
                info("预算", Money.yuan(store.budget.monthlyTotalCents, showDecimals: false))
            }
            .padding(.top, 4)
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .glassCard()
    }

    private func info(_ label: String, _ value: String, color: Color = AppColors.ink) -> some View {
        VStack(spacing: 4) {
            Text(label).eyebrowStyle()
            Text(value)
                .font(.system(size: 14, weight: .medium).monospacedDigit())
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
    }

    private var categoryCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.cat.id) { idx, row in
                if idx > 0 { Divider().background(AppColors.glassDivider).padding(.horizontal, 10) }
                catRow(row)
            }
        }
        .padding(10)
        .glassCard()
    }

    private var rows: [BudgetRow] {
        let spent = Dictionary(
            uniqueKeysWithValues:
                store.expensesByCategory(in: Date()).map { ($0.0.id, $0.1) }
        )
        return Category.all.compactMap { cat in
            guard let cap = store.budget.perCategory[cat.id], cap > 0 else { return nil }
            return BudgetRow(cat: cat, used: spent[cat.id] ?? 0, cap: cap)
        }
        .sorted { $0.percent > $1.percent }
    }

    private func catRow(_ row: BudgetRow) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                CategoryIconTile(category: row.cat, size: 30)
                Text(row.cat.name)
                    .font(.system(size: 12, weight: .medium))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Group {
                    Text(Money.yuan(row.used, showDecimals: false))
                        .foregroundStyle(row.percent > 0.9 ? AppColors.expenseRed : AppColors.ink) +
                    Text(" / \(Money.yuan(row.cap, showDecimals: false))")
                        .foregroundStyle(AppColors.ink3)
                }
                .font(.system(size: 11).monospacedDigit())
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.45))
                    Capsule().fill(LinearGradient.gradient(row.cat.gradient))
                        .frame(width: geo.size.width * CGFloat(min(row.percent, 1.0)))
                }
            }.frame(height: 5)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
    }
}

private struct BudgetRow {
    let cat: Category; let used: Int; let cap: Int
    var percent: Double { cap == 0 ? 0 : Double(used) / Double(cap) }
}

#Preview {
    ZStack {
        AuroraBackground(palette: .budget)
        BudgetView().environment(AppStore())
    }
}
