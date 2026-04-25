import SwiftUI

/// Page 3 · Digital Crown amount picker + category tap → save to shared snapshot.
struct WatchQuickAddView: View {
    @State private var amount: Double = 28
    @State private var selectedCategory: Int = 0
    @State private var saved = false

    private let categories: [(name: String, emoji: String)] = [
        ("餐饮", "🍜"), ("交通", "🚇"), ("购物", "🛍"),
        ("娱乐", "🎬"), ("居家", "🏠"), ("孩子", "🧒"), ("其他", "✨")
    ]

    var body: some View {
        VStack(spacing: 8) {
            if saved {
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(red: 1.0, green: 0.48, blue: 0.60), Color(red: 0.44, green: 0.67, blue: 1.0)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 40, height: 40)

                    Text("已记一笔")
                        .font(.system(size: 12, weight: .semibold))
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
                HStack(spacing: 8) {
                    Text(categories[selectedCategory].emoji)
                        .font(.system(size: 22))
                        .frame(width: 34, height: 34)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white.opacity(0.10))
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text("快速记账")
                            .font(.system(size: 11, weight: .semibold))
                        Text(categories[selectedCategory].name)
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }

                amountDisplay

                #if !os(watchOS)
                Slider(value: $amount, in: 1...9999, step: 1)
                    .tint(Color(red: 0.44, green: 0.67, blue: 1.0))
                #endif

                Text(controlHint)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(categories.enumerated()), id: \.offset) { idx, category in
                            Button {
                                selectedCategory = idx
                            } label: {
                                VStack(spacing: 2) {
                                    Text(category.emoji)
                                        .font(.system(size: 14))
                                    Text(category.name)
                                        .font(.system(size: 8, weight: .medium))
                                        .foregroundStyle(selectedCategory == idx ? .primary : .secondary)
                                }
                                .frame(width: 38, height: 42)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(
                                            selectedCategory == idx
                                                ? Color.white.opacity(0.22)
                                                : Color.white.opacity(0.08)
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .frame(height: 48)

                Button {
                    save()
                } label: {
                    Text("记一笔")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 34)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color(red: 1.0, green: 0.48, blue: 0.60), Color(red: 0.44, green: 0.67, blue: 1.0)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 4)
    }

    @ViewBuilder private var amountDisplay: some View {
        #if os(watchOS)
        Text("¥\(Int(amount))")
            .font(.system(size: 38, weight: .light).monospacedDigit())
            .focusable(true)
            .digitalCrownRotation(
                $amount,
                from: 1,
                through: 9999,
                by: 1,
                sensitivity: .medium,
                isContinuous: false
            )
        #else
        Text("¥\(Int(amount))")
            .font(.system(size: 34, weight: .light).monospacedDigit())
        #endif
    }

    private var controlHint: String {
        #if os(watchOS)
        return "旋转表冠调整金额"
        #else
        return "拖动滑杆调整金额"
        #endif
    }

    private func save() {
        // Scaffold: in production, append to App Group UserDefaults so the iOS
        // app picks up the watch-initiated transaction on next launch.
        saved = true
    }
}
