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
                        VStack(spacing: 14) {
                            header
                            cardsStack
                            Spacer().frame(height: 40)
                        }
                        .padding(.horizontal, 18)
                        .padding(.top, 8)
                    }
                    .scrollIndicators(.hidden)
                }
            } else {
                cardsStack
            }
        }
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
            Text("消费洞察").font(.system(size: 16, weight: .medium))
            Spacer()
            Spacer().frame(width: 34)
        }
    }

    private var insights: [Insight] { InsightEngine.generate(store: store) }

    private var cardsStack: some View {
        VStack(spacing: 10) {
            ForEach(insights) { insight in
                InsightCard(insight: insight)
            }
        }
    }
}

struct InsightCard: View {
    let insight: Insight

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle().fill(LinearGradient.gradient(insight.gradient))
                Text(insight.emoji).font(.system(size: 20))
            }
            .frame(width: 44, height: 44)
            .shadow(color: .black.opacity(0.08), radius: 6, y: 3)

            VStack(alignment: .leading, spacing: 4) {
                Text(insight.title).eyebrowStyle()
                Text(insight.body)
                    .font(.system(size: 13))
                    .foregroundStyle(AppColors.ink)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
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
