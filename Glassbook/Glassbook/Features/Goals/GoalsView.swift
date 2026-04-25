import SwiftUI

/// Spec §6.2 Hero 2 · 储蓄目标. Routed from Profile → "储蓄目标".
struct GoalsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @State private var selected: SavingsGoal?
    @State private var showAdd = false

    var body: some View {
        ZStack {
            AuroraBackground(palette: .add)

            ScrollView {
                VStack(spacing: 14) {
                    header
                    totalCard
                    goalGrid
                    addButton
                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                // why: cap reading width on iPad / Mac so the 2-column grid stays compact.
                .frame(maxWidth: hSizeClass == .regular ? 760 : .infinity)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
        }
        .sheet(item: $selected) { goal in
            GoalDetailSheet(goal: goal)
                .environment(store)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showAdd) {
            AddGoalSheet().environment(store)
                .presentationDetents([.large])
        }
    }

    private var addButton: some View {
        Button { showAdd = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle").font(.system(size: 14))
                Text("新增储蓄目标").font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(AppColors.ink)
            .frame(maxWidth: .infinity, minHeight: 48)
            .glassCard(radius: 14)
        }
        .buttonStyle(.plain)
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
            Text("储蓄目标").font(.system(size: 16, weight: .medium))
            Spacer()
            Button { showAdd = true } label: {
                Image(systemName: "plus").font(.system(size: 13, weight: .medium))
                    .frame(width: 34, height: 34)
                    .glassCard(radius: 12)
                    .foregroundStyle(AppColors.ink)
            }
        }
    }

    private var totalCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("累计已存").eyebrowStyle()
            HStack(alignment: .top, spacing: 4) {
                Text("¥").font(.system(size: 22, weight: .light))
                    .foregroundStyle(AppColors.ink2).padding(.top, 8)
                Text(bigNumber(store.totalSavedCents))
                    .font(.system(size: 42, weight: .ultraLight).monospacedDigit())
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.5))
                    Capsule().fill(LinearGradient.brand())
                        .frame(width: geo.size.width * CGFloat(min(totalProgress, 1)))
                }
            }.frame(height: 6).padding(.top, 4)

            HStack {
                Text("目标 \(Money.yuan(store.totalGoalsTargetCents, showDecimals: false))")
                    .font(.system(size: 11)).foregroundStyle(AppColors.ink3)
                Spacer()
                Text("\(Int(totalProgress * 100))%")
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .foregroundStyle(AppColors.ink)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private var totalProgress: Double {
        guard store.totalGoalsTargetCents > 0 else { return 0 }
        return Double(store.totalSavedCents) / Double(store.totalGoalsTargetCents)
    }

    private var goalGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ForEach(store.goals) { goal in
                Button { selected = goal } label: {
                    goalCard(goal)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func goalCard(_ goal: SavingsGoal) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(goal.emoji).font(.system(size: 24))
                Spacer()
                Text("\(Int(goal.progress * 100))%")
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .foregroundStyle(AppColors.ink)
            }

            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.5), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: CGFloat(goal.progress))
                    .stroke(
                        LinearGradient.gradient(goal.gradient),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text(compact(goal.currentCents))
                        .font(.system(size: 14, weight: .medium).monospacedDigit())
                    Text("/ \(compact(goal.targetCents))")
                        .font(.system(size: 9).monospacedDigit())
                        .foregroundStyle(AppColors.ink3)
                }
            }
            .frame(height: 88)
            .padding(.vertical, 4)

            Text(goal.name).font(.system(size: 13, weight: .medium))
                .lineLimit(1)
            if let daily = goal.dailyTargetCents, daily > 0 {
                Text("建议 \(Money.yuan(daily, showDecimals: false))/天")
                    .font(.system(size: 10))
                    .foregroundStyle(AppColors.ink3)
            } else if goal.progress >= 1 {
                Text("已达成 🎉")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(AppColors.incomeGreen)
            } else {
                Text("未设截止").font(.system(size: 10))
                    .foregroundStyle(AppColors.ink3)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private func compact(_ cents: Int) -> String {
        let yuan = cents / 100
        if yuan >= 10_000 { return String(format: "¥%.1fw", Double(yuan) / 10_000) }
        if yuan >= 1000 { return String(format: "¥%.1fk", Double(yuan) / 1000) }
        return "¥\(yuan)"
    }
    private func bigNumber(_ cents: Int) -> String {
        let fmt = NumberFormatter(); fmt.numberStyle = .decimal
        return fmt.string(from: NSNumber(value: cents / 100)) ?? "\(cents / 100)"
    }
}

private struct GoalDetailSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let goal: SavingsGoal
    @State private var amountText = ""

    var body: some View {
        ZStack {
            AuroraBackground(palette: .add)
            VStack(spacing: 16) {
                HStack {
                    Text(goal.emoji).font(.system(size: 36))
                    VStack(alignment: .leading) {
                        Text(goal.name).font(.system(size: 18, weight: .medium))
                        Text("进度 \(Int(goal.progress * 100))%")
                            .font(.system(size: 12))
                            .foregroundStyle(AppColors.ink2)
                    }
                    Spacer()
                }
                .padding(.top, 8)

                ZStack {
                    Circle().stroke(Color.white.opacity(0.5), lineWidth: 14)
                    Circle().trim(from: 0, to: CGFloat(goal.progress))
                        .stroke(LinearGradient.gradient(goal.gradient),
                                style: StrokeStyle(lineWidth: 14, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 4) {
                        Text(Money.yuan(goal.currentCents, showDecimals: false))
                            .font(.system(size: 24, weight: .light).monospacedDigit())
                        Text("/ \(Money.yuan(goal.targetCents, showDecimals: false))")
                            .font(.system(size: 12))
                            .foregroundStyle(AppColors.ink3)
                    }
                }
                .frame(width: 180, height: 180)

                if let daily = goal.dailyTargetCents, daily > 0 {
                    Text("按此节奏,每天 \(Money.yuan(daily, showDecimals: false)) 即可按时达成")
                        .font(.system(size: 12))
                        .foregroundStyle(AppColors.ink2)
                }

                HStack {
                    TextField("添加存入金额", text: $amountText)
                        .keyboardType(.numberPad)
                        .padding(14).glassCard(radius: 12)
                    Button {
                        let cents = (Int(amountText) ?? 0) * 100
                        store.contribute(to: goal.id, cents: cents)
                        amountText = ""
                        dismiss()
                    } label: {
                        Text("存入")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(width: 72, height: 44)
                            .background(RoundedRectangle(cornerRadius: 12).fill(AppColors.ink))
                    }
                }

                Spacer()
            }
            .padding(20)
        }
    }
}

#Preview {
    GoalsView().environment(AppStore())
}
