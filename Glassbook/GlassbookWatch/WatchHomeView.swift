import SwiftUI

/// Page 1 · month summary glance.
struct WatchHomeView: View {
    let snapshot: WatchSnapshot

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("本月支出")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(.secondary)
                Text(yuan(snapshot.monthExpenseCents))
                    .font(.system(size: 28, weight: .light).monospacedDigit())
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                progressBar
                HStack {
                    Text("预算")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(yuan(snapshot.monthBudgetCents))
                        .font(.system(size: 10, weight: .medium).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 2)
                Divider().padding(.vertical, 4)
                HStack(spacing: 4) {
                    Text(snapshot.topCategoryEmoji).font(.system(size: 14))
                    Text(snapshot.topCategoryName + " 占比最高")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 4) {
                    Image(systemName: "calendar").font(.system(size: 10))
                    Text("日均 \(yuan(snapshot.dailyAverageCents))")
                        .font(.system(size: 10, weight: .medium).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private var progressBar: some View {
        let pct = Double(snapshot.monthExpenseCents) / Double(max(1, snapshot.monthBudgetCents))
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.2))
                Capsule()
                    .fill(LinearGradient(colors: [Color(red: 1, green: 0.42, blue: 0.62),
                                                  Color(red: 0.49, green: 0.66, blue: 1.0)],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: geo.size.width * CGFloat(min(pct, 1.0)))
            }
        }
        .frame(height: 6)
    }

    private func yuan(_ cents: Int) -> String {
        let y = cents / 100
        let fmt = NumberFormatter(); fmt.numberStyle = .decimal
        let body = fmt.string(from: NSNumber(value: y)) ?? "\(y)"
        return "¥\(body)"
    }
}
