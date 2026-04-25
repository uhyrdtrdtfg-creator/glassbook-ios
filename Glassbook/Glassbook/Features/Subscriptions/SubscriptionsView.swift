import SwiftUI

/// Spec §6.2 Hero 3 · 订阅管理. Routed from Profile → "订阅管理".
struct SubscriptionsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @State private var showAdd = false

    var body: some View {
        ZStack {
            AuroraBackground(palette: .budget)

            ScrollView {
                VStack(spacing: 14) {
                    header
                    heroCard
                    calendarStrip
                    Text("订阅列表").eyebrowStyle()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                        .padding(.top, 4)
                    subscriptionList
                    addButton
                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                // why: cap reading width on iPad / Mac.
                .frame(maxWidth: hSizeClass == .regular ? 720 : .infinity)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
        }
        .sheet(isPresented: $showAdd) {
            AddSubscriptionSheet().environment(store)
                .presentationDetents([.large])
        }
    }

    private var addButton: some View {
        Button { showAdd = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle").font(.system(size: 14))
                Text("添加订阅").font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(AppColors.ink)
            .frame(maxWidth: .infinity, minHeight: 48)
            .glassCard(radius: 14)
        }
        .buttonStyle(.plain)
    }

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left").font(.system(size: 13))
                    .frame(width: 34, height: 34)
                    .glassCard(radius: 12)
                    .foregroundStyle(AppColors.ink)
            }
            Spacer()
            Text("订阅管理").font(.system(size: 16, weight: .medium))
            Spacer()
            Button { showAdd = true } label: {
                Image(systemName: "plus").font(.system(size: 13, weight: .medium))
                    .frame(width: 34, height: 34)
                    .glassCard(radius: 12)
                    .foregroundStyle(AppColors.ink)
            }
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("每月固定支出").eyebrowStyle()
            HStack(alignment: .top, spacing: 4) {
                Text("¥").font(.system(size: 22)).foregroundStyle(AppColors.ink2).padding(.top, 6)
                Text(Money.yuan(store.monthlySubscriptionTotalCents, showDecimals: false)
                        .replacingOccurrences(of: "¥", with: ""))
                    .font(.system(size: 42, weight: .ultraLight).monospacedDigit())
            }

            Divider().background(AppColors.glassDivider)

            HStack {
                statBlock("活跃", count: active.count, color: AppColors.ink)
                Spacer()
                statBlock("闲置 30 天", count: zombie30.count,
                          color: zombie30.isEmpty ? AppColors.ink : AppColors.auroraAmber)
                Spacer()
                statBlock("闲置 90 天", count: zombie90.count,
                          color: zombie90.isEmpty ? AppColors.ink : AppColors.expenseRed)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private var active: [Subscription] { store.subscriptions.filter { $0.isActive } }
    private var zombie30: [Subscription] { active.filter { $0.zombieLevel == .idle } }
    private var zombie90: [Subscription] { active.filter { $0.zombieLevel == .dormant } }

    private func statBlock(_ label: String, count: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).eyebrowStyle()
            Text("\(count)").font(.system(size: 18, weight: .light).monospacedDigit())
                .foregroundStyle(color)
        }
    }

    private var calendarStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("未来 7 天").eyebrowStyle().padding(.horizontal, 4)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(0..<7, id: \.self) { offset in
                        let day = Calendar.current.date(byAdding: .day, value: offset, to: Date())!
                        let subsForDay = active.filter {
                            Calendar.current.isDate($0.nextRenewalDate, inSameDayAs: day)
                        }
                        dayChip(date: day, subs: subsForDay, isToday: offset == 0)
                    }
                }
            }
        }
    }

    private func dayChip(date: Date, subs: [Subscription], isToday: Bool) -> some View {
        VStack(spacing: 4) {
            Text(Self.dayFmt.string(from: date).uppercased())
                .font(.system(size: 9, weight: .medium))
                .tracking(0.8)
                .foregroundStyle(AppColors.ink3)
            Text(Self.dateFmt.string(from: date))
                .font(.system(size: 16, weight: .medium).monospacedDigit())
                .foregroundStyle(isToday ? .white : AppColors.ink)
            if subs.isEmpty {
                Text(" ").font(.system(size: 12))
            } else {
                HStack(spacing: 2) {
                    ForEach(subs.prefix(3)) { sub in
                        Circle().fill(LinearGradient.gradient(sub.gradient))
                            .frame(width: 5, height: 5)
                    }
                }
            }
        }
        .frame(width: 48, height: 68)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isToday ? AnyShapeStyle(LinearGradient.brand()) : AnyShapeStyle(Color.white.opacity(0.5)))
        )
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(AppColors.glassBorder, lineWidth: 1))
    }

    private var subscriptionList: some View {
        VStack(spacing: 0) {
            ForEach(Array(store.subscriptions.enumerated()), id: \.element.id) { idx, sub in
                if idx > 0 { Divider().background(AppColors.glassDivider).padding(.horizontal, 10) }
                subscriptionRow(sub)
            }
        }
        .padding(4)
        .glassCard()
    }

    private func subscriptionRow(_ sub: Subscription) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinearGradient.gradient(sub.gradient))
                Text(sub.emoji).font(.system(size: 18))
            }
            .frame(width: 40, height: 40)
            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(sub.name).font(.system(size: 13, weight: .medium))
                    zombieBadge(sub)
                }
                HStack(spacing: 6) {
                    Text(Money.yuan(sub.amountCents, showDecimals: false))
                    Text("·").foregroundStyle(AppColors.ink4)
                    Text(sub.period.displayName)
                    Text("·").foregroundStyle(AppColors.ink4)
                    Text(daysBlurb(sub))
                }
                .font(.system(size: 10))
                .foregroundStyle(AppColors.ink3)
                .tabularNumbers()
            }
            Spacer()
            Text("¥\(sub.monthlyEquivalentCents / 100)/月")
                .font(.system(size: 11, weight: .medium).monospacedDigit())
                .foregroundStyle(AppColors.ink2)
        }
        .padding(.vertical, 10).padding(.horizontal, 10)
    }

    @ViewBuilder private func zombieBadge(_ sub: Subscription) -> some View {
        switch sub.zombieLevel {
        case .active: EmptyView()
        case .idle:
            badgePill(text: "闲置 30 天", color: AppColors.auroraAmber)
        case .dormant:
            badgePill(text: "闲置 90 天 · 建议取消", color: AppColors.expenseRed)
        }
    }

    private func badgePill(text: String, color: Color) -> some View {
        Text(text).font(.system(size: 9, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Capsule().fill(color))
    }

    private func daysBlurb(_ sub: Subscription) -> String {
        let d = sub.daysToRenewal
        if d == 0 { return "今天续费" }
        if d == 1 { return "明天续费" }
        return "\(d) 天后续费"
    }

    private static let dayFmt: DateFormatter = {
        let f = DateFormatter(); f.locale = .init(identifier: "zh_CN"); f.dateFormat = "EEE"; return f
    }()
    private static let dateFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "d"; return f
    }()
}

#Preview {
    SubscriptionsView().environment(AppStore())
}
