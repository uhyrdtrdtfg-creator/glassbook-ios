import SwiftUI

/// Page 2 · last 5 transactions.
struct WatchRecentView: View {
    let snapshot: WatchSnapshot

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("最近交易")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(.secondary)

                ForEach(snapshot.recentTransactions) { tx in
                    HStack(spacing: 8) {
                        Text(tx.emoji)
                            .font(.system(size: 16))
                            .frame(width: 24, height: 24)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.white.opacity(0.10))
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(tx.merchant)
                                .font(.system(size: 12, weight: .medium))
                                .lineLimit(1)
                            Text(tx.timeLabel)
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(yuan(tx.cents))
                            .font(.system(size: 12, weight: .semibold).monospacedDigit())
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                    )
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private func yuan(_ cents: Int) -> String {
        let yuan = cents / 100
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        let body = formatter.string(from: NSNumber(value: yuan)) ?? "\(yuan)"
        return "¥\(body)"
    }
}
