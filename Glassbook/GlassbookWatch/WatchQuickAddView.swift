import SwiftUI

/// Page 3 · Digital Crown amount picker + category tap → save to shared snapshot.
struct WatchQuickAddView: View {
    @State private var amount: Double = 28
    @State private var selectedCategory: Int = 0
    @State private var saved = false

    private let categories: [(name: String, emoji: String)] = [
        ("餐饮", "🍜"), ("交通", "🚇"), ("购物", "🛍"),
        ("娱乐", "🎬"), ("居家", "🏠"), ("孩子", "🧒"), ("其他", "✨"),
    ]

    var body: some View {
        VStack(spacing: 6) {
            if saved {
                VStack(spacing: 8) {
                    Text("✓").font(.system(size: 44))
                    Text("已记一笔").font(.system(size: 12, weight: .medium))
                    Text("¥\(Int(amount)) · \(categories[selectedCategory].name)")
                        .font(.system(size: 11, weight: .medium).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .task {
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    await MainActor.run {
                        saved = false
                        amount = 28
                    }
                }
            } else {
                Text(categories[selectedCategory].emoji)
                    .font(.system(size: 26))

                Text("¥\(Int(amount))")
                    .font(.system(size: 40, weight: .light).monospacedDigit())
                    .focusable(true)
                    .digitalCrownRotation(
                        $amount, from: 1, through: 9999,
                        by: 1, sensitivity: .medium, isContinuous: false
                    )

                Text("旋转表冠调整金额")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)

                // Category selector (horizontal scroll)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(categories.enumerated()), id: \.offset) { idx, c in
                            Button { selectedCategory = idx } label: {
                                VStack(spacing: 2) {
                                    Text(c.emoji).font(.system(size: 14))
                                    Text(c.name)
                                        .font(.system(size: 8))
                                        .foregroundStyle(selectedCategory == idx ? .primary : .secondary)
                                }
                                .frame(width: 34, height: 38)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(selectedCategory == idx
                                              ? Color.white.opacity(0.22)
                                              : Color.white.opacity(0.08))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 6)
                }
                .frame(height: 44)

                Button {
                    save()
                } label: {
                    Text("记一笔")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 32)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.75)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 4)
    }

    private func save() {
        // Scaffold: in production, append to App Group UserDefaults so the iOS
        // app picks up the watch-initiated transaction on next launch.
        saved = true
    }
}
