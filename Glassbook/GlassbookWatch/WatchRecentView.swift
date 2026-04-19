import SwiftUI

/// Page 2 · last 5 transactions.
struct WatchRecentView: View {
    let snapshot: WatchSnapshot

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                Text("最近交易")
                    .font(.system(size: 10, weight: .semibold)).tracking(0.8)
                    .foregroundStyle(.secondary)

                ForEach(snapshot.recentTransactions) { tx in
                    HStack(spacing: 8) {
                        Text(tx.emoji).font(.system(size: 14))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(tx.merchant)
                                .font(.system(size: 12, weight: .medium))
                                .lineLimit(1)
                            Text(tx.timeLabel)
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(yuan(tx.cents))
                            .font(.system(size: 12, weight: .medium).monospacedDigit())
                    }
                    .padding(.vertical, 5)
                    if tx != snapshot.recentTransactions.last {
                        Divider()
                    }
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private func yuan(_ cents: Int) -> String {
        let y = cents / 100
        let fmt = NumberFormatter(); fmt.numberStyle = .decimal
        let body = fmt.string(from: NSNumber(value: y)) ?? "\(y)"
        return "¥\(body)"
    }
}
