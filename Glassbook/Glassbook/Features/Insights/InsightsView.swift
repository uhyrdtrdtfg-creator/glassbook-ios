import SwiftUI

/// Spec §6.2 · AI 消费洞察. Embedded in Stats + standalone fullScreen from Profile.
struct InsightsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var isStandalone = false

    var body: some View {
        Group {
            if isStandalone {
                ZStack {
                    AuroraBackground(palette: .stats)
                    ScrollView {
                        VStack(spacing: 16) {
                            header
                            introCard
                            cardsStack
                            Spacer().frame(height: 44)
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 8)
                    }
                    .scrollIndicators(.hidden)
                }
            } else {
                VStack(spacing: 12) {
                    compactIntro
                    cardsStack
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 36, height: 36)
                    .glassCard(radius: 12)
                    .foregroundStyle(AppColors.ink)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text("消费洞察")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(AppColors.ink)
                Text("把最近的消费行为整理成一句句可执行观察")
                    .font(.system(size: 11))
                    .foregroundStyle(AppColors.ink3)
            }

            Spacer()
        }
    }

    private var introCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AI 消费观察")
                .eyebrowStyle()
            Text("这些结论来自你本月的交易、预算和消费节奏。它们不会替你做决定，但会帮你更快看到习惯。")
                .font(.system(size: 14))
                .foregroundStyle(AppColors.ink)
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .glassCard(radius: 22)
    }

    private var compactIntro: some View {
        HStack {
            Text("AI 读了你最近的账本，下面是值得注意的几个瞬间。")
                .font(.system(size: 12))
                .foregroundStyle(AppColors.ink2)
            Spacer()
        }
        .padding(.horizontal, 4)
    }

    private var insights: [Insight] {
        InsightEngine.generate(store: store)
    }

    private var cardsStack: some View {
        VStack(spacing: 12) {
            ForEach(Array(insights.enumerated()), id: \.element.id) { idx, insight in
                InsightCard(insight: insight, index: idx)
            }
        }
    }
}

struct InsightCard: View {
    let insight: Insight
    let index: Int

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(LinearGradient.gradient(insight.gradient))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.24), lineWidth: 1)
                    )
                Text(insight.emoji)
                    .font(.system(size: 22))
            }
            .frame(width: 50, height: 50)
            .shadow(color: AppColors.surfaceShadow.opacity(0.45), radius: 10, x: 0, y: 6)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(kindLabel)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AppColors.ink2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.white.opacity(0.34)))
                    Spacer()
                    Text(String(format: "#%02d", index + 1))
                        .font(.system(size: 10, weight: .semibold).monospacedDigit())
                        .foregroundStyle(AppColors.ink3)
                }

                Text(insight.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppColors.ink)

                Text(insight.body)
                    .font(.system(size: 13))
                    .foregroundStyle(AppColors.ink2)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 4)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: 22)
    }

    private var kindLabel: String {
        switch insight.kind {
        case .persona: return "消费人格"
        case .trend: return "趋势提醒"
        case .saving: return "省钱建议"
        case .dailyAvg: return "日均节奏"
        case .newMerchant: return "探索行为"
        case .highSpendingDay: return "峰值时刻"
        case .categoryWatch: return "预算提醒"
        }
    }
}

#Preview("Embedded") {
    ZStack {
        AuroraBackground(palette: .stats)
        ScrollView {
            InsightsView().environment(AppStore()).padding()
        }
    }
}

#Preview("Standalone") {
    InsightsView(isStandalone: true).environment(AppStore())
}
