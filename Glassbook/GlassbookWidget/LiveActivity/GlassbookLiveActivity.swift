import ActivityKit
import WidgetKit
import SwiftUI

/// Lock Screen + Dynamic Island UI for the "零点击入账" Live Activity.
/// Matches Diagram 03 in the advanced-features HTML.
struct GlassbookLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: GlassbookActivityAttributes.self) { context in
            // Lock Screen / Banner view
            LockScreenActivityView(state: context.state)
                .activityBackgroundTint(Color(hex: 0x15172A))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded
                DynamicIslandExpandedRegion(.leading) {
                    CategoryBubble(emoji: context.state.categoryEmoji)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    countdownBadge(state: context.state)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(yuan(context.state.amountCents))
                            .font(.system(size: 18, weight: .medium).monospacedDigit())
                        Text(context.state.merchant)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    progressBar(state: context.state)
                }
            } compactLeading: {
                Text(context.state.categoryEmoji).font(.system(size: 14))
            } compactTrailing: {
                Text(compactTrailingText(state: context.state))
                    .font(.system(size: 11, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.white)
            } minimal: {
                Text(context.state.phase == .saved ? "✓" : "\(context.state.secondsRemaining)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
    }

    private func compactTrailingText(state: GlassbookActivityAttributes.ContentState) -> String {
        switch state.phase {
        case .saved:      return "✓"
        case .capturing:  return "···"
        case .confirming: return "\(state.secondsRemaining)s"
        }
    }

    @ViewBuilder private func countdownBadge(state: GlassbookActivityAttributes.ContentState) -> some View {
        switch state.phase {
        case .saved:
            Text("已保存").font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Capsule().fill(Color(hex: 0x4A8A5E)))
        case .capturing:
            Text("识别中").font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Capsule().fill(Color.white.opacity(0.25)))
        case .confirming:
            Text("\(state.secondsRemaining)s").font(.system(size: 11, weight: .semibold).monospacedDigit())
                .foregroundStyle(.white)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(Capsule().fill(Color.white.opacity(0.25)))
        }
    }

    @ViewBuilder private func progressBar(state: GlassbookActivityAttributes.ContentState) -> some View {
        let total = max(1, state.totalSeconds)
        let progress = 1.0 - (Double(state.secondsRemaining) / Double(total))
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.18))
                Capsule()
                    .fill(LinearGradient(colors: [Color(hex: 0xFFB5C8), Color(hex: 0xB8D6FF)],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: geo.size.width * progress)
            }
        }
        .frame(height: 3)
        .padding(.horizontal, 4).padding(.top, 2)
    }

    private func yuan(_ cents: Int) -> String {
        let y = cents / 100; let f = cents % 100
        return f == 0 ? "¥\(y)" : "¥\(y).\(String(format: "%02d", f))"
    }
}

// MARK: - Lock Screen banner

private struct LockScreenActivityView: View {
    let state: GlassbookActivityAttributes.ContentState

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            CategoryBubble(emoji: state.categoryEmoji, large: true)

            VStack(alignment: .leading, spacing: 4) {
                Text("GLASSBOOK")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(.white.opacity(0.7))

                switch state.phase {
                case .capturing:
                    Text("识别到 \(yuan(state.amountCents)) \(categoryName(state.categoryEmoji))")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("\(state.merchant) · 正在识别…")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.7))
                case .confirming:
                    Text("识别到 \(yuan(state.amountCents)) \(categoryName(state.categoryEmoji))")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("\(state.merchant) · \(state.secondsRemaining) 秒后自动保存")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.7))
                case .saved:
                    Text("已保存 \(yuan(state.amountCents)) \(categoryName(state.categoryEmoji))")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("\(state.merchant) · 轻触查看详情")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }

            Spacer()

            Text(state.phase == .saved ? "✓" : "\(state.secondsRemaining)")
                .font(.system(size: 14, weight: .semibold).monospacedDigit())
                .foregroundStyle(.white)
                .frame(width: 34, height: 30)
                .background(Capsule().fill(Color.white.opacity(0.18)))
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(
            LinearGradient(colors: [Color(hex: 0x15172A), Color(hex: 0x24264A)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .overlay(alignment: .bottom) { progressStrip }
    }

    private var progressStrip: some View {
        let total = max(1, state.totalSeconds)
        let progress = 1.0 - (Double(state.secondsRemaining) / Double(total))
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(Color.white.opacity(0.08))
                Rectangle()
                    .fill(LinearGradient(colors: [Color(hex: 0xFFB5C8), Color(hex: 0xB8D6FF)],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: geo.size.width * progress)
            }
        }
        .frame(height: 3)
    }

    private func yuan(_ cents: Int) -> String {
        let y = cents / 100; let f = cents % 100
        return f == 0 ? "¥\(y)" : "¥\(y).\(String(format: "%02d", f))"
    }

    private func categoryName(_ emoji: String) -> String {
        switch emoji {
        case "🍜": "餐饮"
        case "🚇": "交通"
        case "🛍": "购物"
        case "🎬": "娱乐"
        case "🏠": "居家"
        case "💊": "医疗"
        case "📚": "学习"
        case "🧒": "孩子"
        default:  "支出"
        }
    }
}

// MARK: - Category bubble

private struct CategoryBubble: View {
    let emoji: String
    var large: Bool = false

    var body: some View {
        Text(emoji).font(.system(size: large ? 22 : 16))
            .frame(width: large ? 42 : 32, height: large ? 42 : 32)
            .background(
                RoundedRectangle(cornerRadius: large ? 12 : 10, style: .continuous)
                    .fill(LinearGradient(colors: [Color(hex: 0xFFB5C8), Color(hex: 0xB8D6FF)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
            )
    }
}
