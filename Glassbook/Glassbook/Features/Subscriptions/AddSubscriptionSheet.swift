import SwiftUI

/// Add-a-subscription form. Opened from SubscriptionsView's "+" button.
/// Writes through AppStore (which persists via SwiftData).
struct AddSubscriptionSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var emoji = "📱"
    @State private var amountYuan = ""
    @State private var period: Subscription.Period = .monthly
    @State private var renewInDays: Int = 30
    @State private var lastUsedDaysAgo: Int = 0
    @State private var selectedPalette = 0

    private let palettes: [(label: String, gradient: [Color])] = [
        ("粉紫",   [Color(hex: 0xFF6B9D), Color(hex: 0xC48AFF)]),
        ("蓝绿",   [Color(hex: 0x07C160), Color(hex: 0x4ED88C)]),
        ("金橙",   [Color(hex: 0xFFB84D), Color(hex: 0xFFD46B)]),
        ("科技蓝", [Color(hex: 0x4A9EFF), Color(hex: 0x7EA8FF)]),
        ("暗夜",   [Color(hex: 0x15172A), Color(hex: 0x4A3A6A)]),
    ]

    var body: some View {
        ZStack {
            AuroraBackground(palette: .budget)
            ScrollView {
                VStack(spacing: 14) {
                    header
                    previewCard
                    nameField
                    amountField
                    periodPicker
                    paletteRow
                    timingCard
                    saveButton
                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
            }
            .scrollIndicators(.hidden)
        }
    }

    // MARK: - Sections

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.system(size: 13))
                    .frame(width: 34, height: 34)
                    .glassCard(radius: 12)
                    .foregroundStyle(AppColors.ink)
            }
            Spacer()
            Text("新增订阅").font(.system(size: 16, weight: .medium))
            Spacer()
            Spacer().frame(width: 34)
        }
    }

    private var previewCard: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(LinearGradient.gradient(palettes[selectedPalette].gradient))
                Text(emoji).font(.system(size: 22))
            }
            .frame(width: 48, height: 48)
            .shadow(color: .black.opacity(0.1), radius: 6, y: 3)

            VStack(alignment: .leading, spacing: 3) {
                Text(name.isEmpty ? "订阅名称" : name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(name.isEmpty ? AppColors.ink3 : AppColors.ink)
                Text("\(monthlyEquivalentText) · \(period.displayName)")
                    .font(.system(size: 11))
                    .foregroundStyle(AppColors.ink3)
            }
            Spacer()
        }
        .padding(16)
        .glassCard()
    }

    private var monthlyEquivalentText: String {
        let amount = Double(amountYuan) ?? 0
        let monthly: Double
        switch period {
        case .weekly:  monthly = amount * 52 / 12
        case .monthly: monthly = amount
        case .yearly:  monthly = amount / 12
        }
        return "¥\(Int(monthly))/月"
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("名称 · emoji").eyebrowStyle()
            HStack(spacing: 8) {
                TextField("Emoji", text: $emoji)
                    .font(.system(size: 22))
                    .frame(width: 52, height: 44)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.55)))
                    .multilineTextAlignment(.center)
                TextField("Claude Pro / 网易云黑胶 / ...", text: $name)
                    .font(.system(size: 14))
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .glassCard(radius: 12)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: 14)
    }

    private var amountField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("金额 (每次扣费)").eyebrowStyle()
            HStack(spacing: 6) {
                Text("¥").font(.system(size: 18)).foregroundStyle(AppColors.ink3)
                TextField("145", text: $amountYuan)
                    .font(.system(size: 18, weight: .medium).monospacedDigit())
                    .keyboardType(.decimalPad)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .glassCard(radius: 12)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: 14)
    }

    private var periodPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("周期").eyebrowStyle()
            HStack(spacing: 6) {
                ForEach(Subscription.Period.allCases, id: \.self) { p in
                    Button { period = p; renewInDays = p.daysBetween } label: {
                        Text(p.displayName)
                            .font(.system(size: 12, weight: period == p ? .medium : .regular))
                            .foregroundStyle(period == p ? .white : AppColors.ink)
                            .frame(maxWidth: .infinity, minHeight: 36)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(period == p ? AppColors.ink : Color.white.opacity(0.55))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .glassCard(radius: 14)
    }

    private var paletteRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("配色").eyebrowStyle()
            HStack(spacing: 8) {
                ForEach(Array(palettes.enumerated()), id: \.offset) { idx, p in
                    Button { selectedPalette = idx } label: {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(LinearGradient.gradient(p.gradient))
                            .frame(height: 36)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .strokeBorder(selectedPalette == idx ? AppColors.ink : Color.clear, lineWidth: 2)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .glassCard(radius: 14)
    }

    private var timingCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("时间").eyebrowStyle()
            HStack {
                Text("下次续费").font(.system(size: 12))
                Spacer()
                Stepper("\(renewInDays) 天后", value: $renewInDays, in: 1...365)
                    .font(.system(size: 12))
            }
            HStack {
                Text("上次使用").font(.system(size: 12))
                Spacer()
                Stepper("\(lastUsedDaysAgo) 天前", value: $lastUsedDaysAgo, in: 0...365)
                    .font(.system(size: 12))
            }
        }
        .padding(14)
        .glassCard(radius: 14)
    }

    private var saveButton: some View {
        Button {
            save()
        } label: {
            Text("保存订阅")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(RoundedRectangle(cornerRadius: 14).fill(AppColors.ink))
        }
        .buttonStyle(.plain)
        .disabled(name.isEmpty || (Double(amountYuan) ?? 0) <= 0)
        .opacity((name.isEmpty || (Double(amountYuan) ?? 0) <= 0) ? 0.4 : 1)
    }

    private func save() {
        let amount = Double(amountYuan) ?? 0
        let cents = Int(amount * 100)
        let sub = Subscription(
            id: UUID(),
            name: name,
            emoji: emoji.isEmpty ? "📱" : emoji,
            amountCents: cents,
            period: period,
            nextRenewalDate: Date().addingTimeInterval(TimeInterval(renewInDays) * 86400),
            lastUsedDate: Date().addingTimeInterval(TimeInterval(-lastUsedDaysAgo) * 86400),
            gradient: palettes[selectedPalette].gradient,
            isActive: true
        )
        store.addSubscription(sub)
        dismiss()
    }
}

#Preview {
    AddSubscriptionSheet().environment(AppStore())
}
