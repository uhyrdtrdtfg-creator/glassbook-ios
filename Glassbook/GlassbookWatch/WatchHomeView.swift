import SwiftUI

/// Page 1 · month summary glance.
struct WatchHomeView: View {
    let snapshot: WatchSnapshot

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("本月支出")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(.secondary)

                Text(yuan(snapshot.monthExpenseCents))
                    .font(.system(size: 30, weight: .light).monospacedDigit())
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)

                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Text("预算进度")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(progress * 100))%")
                            .font(.system(size: 9, weight: .semibold).monospacedDigit())
                    }
                    progressBar
                }

                HStack(spacing: 8) {
                    statCard(title: "预算", value: yuan(snapshot.monthBudgetCents))
                    statCard(title: "日均", value: yuan(snapshot.dailyAverageCents))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("本月重点")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 6) {
                        Text(snapshot.topCategoryEmoji)
                            .font(.system(size: 14))
                        Text(snapshot.topCategoryName + " 占比最高")
                            .font(.system(size: 10, weight: .medium))
                            .lineLimit(1)
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.10))
                )
            }
            .padding(.horizontal, 4)
        }
    }

    private var progress: Double {
        min(1, Double(snapshot.monthExpenseCents) / Double(max(1, snapshot.monthBudgetCents)))
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.15))
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 1.0, green: 0.48, blue: 0.60), Color(red: 0.44, green: 0.67, blue: 1.0)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(10, geo.size.width * progress))
            }
        }
        .frame(height: 7)
    }

    private func statCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 11, weight: .semibold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.10))
        )
    }

    private func yuan(_ cents: Int) -> String {
        let yuan = cents / 100
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        let body = formatter.string(from: NSNumber(value: yuan)) ?? "\(yuan)"
        return "¥\(body)"
    }
}
