import SwiftUI

/// Add-a-savings-goal form. Opened from GoalsView's "+" button.
struct AddGoalSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var emoji = "🎯"
    @State private var targetYuan = ""
    @State private var currentYuan = ""
    @State private var deadlineOffsetDays: Double = 90
    @State private var selectedPalette = 0
    @State private var hasDeadline = true

    private let palettes: [(label: String, gradient: [Color])] = [
        ("粉紫",   [Color(hex: 0xFF6B9D), Color(hex: 0xC48AFF)]),
        ("金橙",   [Color(hex: 0xFFA87A), Color(hex: 0xFFD46B)]),
        ("天蓝",   [Color(hex: 0x7EA8FF), Color(hex: 0xA8C0FF)]),
        ("薄荷",   [Color(hex: 0x7ACFA5), Color(hex: 0xA8E4D2)]),
        ("紫蓝",   [Color(hex: 0xC8B5FF), Color(hex: 0x7EA8FF)]),
    ]

    var body: some View {
        ZStack {
            AuroraBackground(palette: .add)
            ScrollView {
                VStack(spacing: 14) {
                    header
                    previewCard
                    nameField
                    amountFields
                    paletteRow
                    deadlineCard
                    saveButton
                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.system(size: 13))
                    .frame(width: 34, height: 34).glassCard(radius: 12)
                    .foregroundStyle(AppColors.ink)
            }
            Spacer()
            Text("新增储蓄目标").font(.system(size: 16, weight: .medium))
            Spacer()
            Spacer().frame(width: 34)
        }
    }

    private var previewCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(LinearGradient.gradient(palettes[selectedPalette].gradient))
                Text(emoji).font(.system(size: 28))
            }
            .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 4) {
                Text(name.isEmpty ? "目标名称" : name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(name.isEmpty ? AppColors.ink3 : AppColors.ink)
                HStack(spacing: 6) {
                    Text("¥\(Int(Double(currentYuan) ?? 0))")
                        .font(.system(size: 12, weight: .medium).monospacedDigit())
                    Text("/ ¥\(Int(Double(targetYuan) ?? 0))")
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundStyle(AppColors.ink3)
                }
                if hasDeadline {
                    Text(formatDeadline()).font(.system(size: 10))
                        .foregroundStyle(AppColors.ink3)
                }
            }
            Spacer()
        }
        .padding(16)
        .glassCard()
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("名称 · emoji").eyebrowStyle()
            HStack(spacing: 8) {
                TextField("🎯", text: $emoji)
                    .font(.system(size: 22))
                    .frame(width: 52, height: 44)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.55)))
                    .multilineTextAlignment(.center)
                TextField("相机 / 日本旅行 / 应急金 / ...", text: $name)
                    .font(.system(size: 14))
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .glassCard(radius: 12)
            }
        }
        .padding(14)
        .glassCard(radius: 14)
    }

    private var amountFields: some View {
        VStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                Text("目标金额").eyebrowStyle()
                HStack {
                    Text("¥").foregroundStyle(AppColors.ink3)
                    TextField("12000", text: $targetYuan)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 18, weight: .medium).monospacedDigit())
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .glassCard(radius: 12)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("当前已存").eyebrowStyle()
                HStack {
                    Text("¥").foregroundStyle(AppColors.ink3)
                    TextField("0", text: $currentYuan)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 16, weight: .medium).monospacedDigit())
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .glassCard(radius: 12)
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

    private var deadlineCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("截止时间").eyebrowStyle()
                Spacer()
                Toggle("", isOn: $hasDeadline).labelsHidden().tint(AppColors.ink)
            }
            if hasDeadline {
                HStack {
                    Text("\(Int(deadlineOffsetDays)) 天后 · \(formatDeadline())")
                        .font(.system(size: 12))
                        .foregroundStyle(AppColors.ink2)
                    Spacer()
                }
                Slider(value: $deadlineOffsetDays, in: 7...365, step: 1)
                    .tint(AppColors.ink)
            } else {
                Text("无截止 · 随性攒").font(.system(size: 11)).foregroundStyle(AppColors.ink3)
            }
        }
        .padding(14)
        .glassCard(radius: 14)
    }

    private var saveButton: some View {
        Button {
            save()
        } label: {
            Text("保存目标")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(RoundedRectangle(cornerRadius: 14).fill(AppColors.ink))
        }
        .buttonStyle(.plain)
        .disabled(!isValid)
        .opacity(isValid ? 1 : 0.4)
    }

    private var isValid: Bool {
        !name.isEmpty && (Double(targetYuan) ?? 0) > 0
    }

    private func formatDeadline() -> String {
        let deadline = Date().addingTimeInterval(deadlineOffsetDays * 86400)
        let f = DateFormatter(); f.locale = .init(identifier: "zh_CN")
        f.dateFormat = "yyyy年M月d日"
        return f.string(from: deadline)
    }

    private func save() {
        let goal = SavingsGoal(
            id: UUID(),
            name: name,
            emoji: emoji.isEmpty ? "🎯" : emoji,
            targetCents: Int((Double(targetYuan) ?? 0) * 100),
            currentCents: Int((Double(currentYuan) ?? 0) * 100),
            deadline: hasDeadline ? Date().addingTimeInterval(deadlineOffsetDays * 86400) : nil,
            createdAt: Date(),
            gradient: palettes[selectedPalette].gradient
        )
        store.addGoal(goal)
        dismiss()
    }
}

#Preview {
    AddGoalSheet().environment(AppStore())
}
