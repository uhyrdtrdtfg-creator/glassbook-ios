import SwiftUI

/// Spec v2 §6.3 · 沉没成本分析. Reuses the Subscription data for idle detection
/// and surfaces one-off purchases that have been gathering dust.
struct SunkCostView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AuroraBackground(palette: .importAmber)
            ScrollView {
                VStack(spacing: 14) {
                    header
                    savingsHero
                    idleSubscriptionsSection
                    dustyHardwareSection
                    aiSuggestion
                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left").font(.system(size: 13))
                    .frame(width: 34, height: 34).glassCard(radius: 12)
                    .foregroundStyle(AppColors.ink)
            }
            Spacer()
            Text("沉没成本").font(.system(size: 16, weight: .medium))
            Spacer()
            Spacer().frame(width: 34)
        }
    }

    /// Monthly drain from idle subs + amortized hardware dust.
    private var totalMonthlyDrainCents: Int {
        idleSubs.reduce(0) { $0 + $1.monthlyEquivalentCents } + dustyItems.reduce(0) { $0 + $1.monthlyDrainCents }
    }

    private var savingsHero: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("🎯 可省回 / 月").eyebrowStyle().foregroundStyle(AppColors.expenseRed)
                Spacer()
            }
            HStack(alignment: .top, spacing: 4) {
                Text("¥").font(.system(size: 22))
                    .foregroundStyle(AppColors.ink2).padding(.top, 6)
                Text(yuanFormat(totalMonthlyDrainCents))
                    .font(.system(size: 42, weight: .ultraLight).monospacedDigit())
            }
            Text("识别到 \(idleSubs.count) 项闲置订阅 + \(dustyItems.count) 项吃灰硬件")
                .font(.system(size: 12))
                .foregroundStyle(AppColors.ink2)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(AppColors.expenseRed.opacity(0.12))
                .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(AppColors.glassBorder, lineWidth: 1))
        )
    }

    // MARK: - Idle subscriptions

    private var idleSubs: [Subscription] {
        store.subscriptions.filter { $0.isActive && $0.zombieLevel != .active }
            .sorted { $0.monthlyEquivalentCents > $1.monthlyEquivalentCents }
    }

    private var idleSubscriptionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("闲置订阅 (30+ 天未使用)").eyebrowStyle()
                Spacer()
                Text("\(idleSubs.count) 项").font(.system(size: 10))
                    .foregroundStyle(AppColors.ink3)
            }
            if idleSubs.isEmpty {
                emptyPlaceholder(text: "所有订阅都是活跃状态 · 干净")
            } else {
                VStack(spacing: 6) {
                    ForEach(idleSubs) { sub in
                        sunkRow(
                            icon: sub.emoji,
                            gradient: sub.gradient,
                            name: sub.name,
                            meta: "\(sub.zombieLevel == .dormant ? "闲置 90+ 天" : "闲置 30+ 天") · \(rationale(for: sub))",
                            amountCents: sub.monthlyEquivalentCents
                        )
                    }
                }
            }
        }
    }

    private func rationale(for sub: Subscription) -> String {
        switch sub.zombieLevel {
        case .dormant: "建议取消"
        case .idle:    "留意使用率"
        case .active:  ""
        }
    }

    // MARK: - Dusty hardware (sample data)

    private let dustyItems: [SunkCostItem] = [
        .init(id: UUID(), kind: .hardware, name: "KINDLE Oasis",
              iconEmoji: "📖", monthlyDrainCents: 2_500, daysIdle: 120,
              rationale: "闲置 120 天 · 电池可能已循环"),
        .init(id: UUID(), kind: .hardware, name: "任天堂 Switch",
              iconEmoji: "🎮", monthlyDrainCents: 4_200, daysIdle: 98,
              rationale: "闲置 98 天 · 上次游玩 2025 Q4"),
        .init(id: UUID(), kind: .software, name: "Adobe CC 全家桶",
              iconEmoji: "🎨", monthlyDrainCents: 39_000, daysIdle: 45,
              rationale: "闲置 45 天 · 可仅订阅 PS 单品"),
    ]

    private var dustyHardwareSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("吃灰硬件 · 软件 (>90 天未用)").eyebrowStyle()
                Spacer()
                Text("\(dustyItems.count) 项").font(.system(size: 10))
                    .foregroundStyle(AppColors.ink3)
            }
            VStack(spacing: 6) {
                ForEach(dustyItems) { item in
                    sunkRow(
                        icon: item.iconEmoji,
                        gradient: [AppColors.expenseRed, AppColors.auroraPink],
                        name: item.name,
                        meta: item.rationale,
                        amountCents: item.monthlyDrainCents
                    )
                }
            }
        }
    }

    private func sunkRow(icon: String, gradient: [Color], name: String, meta: String, amountCents: Int) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(LinearGradient.gradient(gradient))
                Text(icon).font(.system(size: 14))
            }
            .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.system(size: 13, weight: .medium))
                Text(meta).font(.system(size: 10))
                    .foregroundStyle(AppColors.ink3)
                    .lineLimit(1)
            }
            Spacer()
            Text("\(Money.yuan(amountCents, showDecimals: false))/月")
                .font(.system(size: 12, weight: .medium).monospacedDigit())
                .foregroundStyle(AppColors.expenseRed)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(AppColors.expenseRed.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(AppColors.expenseRed.opacity(0.2), lineWidth: 1)
                )
        )
    }

    private var aiSuggestion: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle().fill(LinearGradient.brand())
                .frame(width: 36, height: 36)
                .overlay(Image(systemName: "sparkles")
                    .foregroundStyle(.white).font(.system(size: 14)))
            VStack(alignment: .leading, spacing: 4) {
                Text("AI 建议").eyebrowStyle()
                Text("按订阅使用率,优先取消 ChatGPT Plus (已被 Claude 替代 45 天)。每月省 ¥145,年化 ¥1740。")
                    .font(.system(size: 12))
                    .lineSpacing(3)
            }
            Spacer()
        }
        .padding(16)
        .glassCard()
    }

    private func emptyPlaceholder(text: String) -> some View {
        HStack {
            Spacer()
            Text(text).font(.system(size: 12))
                .foregroundStyle(AppColors.ink3)
            Spacer()
        }
        .padding(.vertical, 20)
        .glassCard()
    }

    private func yuanFormat(_ cents: Int) -> String {
        let y = cents / 100
        let fmt = NumberFormatter(); fmt.numberStyle = .decimal
        return fmt.string(from: NSNumber(value: y)) ?? "\(y)"
    }
}

#Preview {
    SunkCostView().environment(AppStore())
}
