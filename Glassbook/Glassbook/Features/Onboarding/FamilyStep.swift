import SwiftUI

/// Onboarding step 3 · Lets the user name their family book.
/// Writes through `AppStore.familyGroupName` (UserDefaults-backed) —
/// real CloudKit sharing happens later from "我 → 家庭账本".
struct FamilyStep: View {
    @Environment(AppStore.self) private var store
    var onFinish: () -> Void
    var onSkip: () -> Void

    @State private var name: String = "我的家"
    @FocusState private var nameFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 18) {
                    hero
                    nameCard
                    privacyBlurb
                }
                .padding(.horizontal, 24)
                .padding(.top, 4)
            }
            .scrollIndicators(.hidden)

            OnboardingButtonRow(
                primaryTitle: "完成",
                onPrimary: save,
                secondaryTitle: "稍后再说",
                onSecondary: onSkip
            )
        }
        .onAppear {
            // why: pre-fill with existing name in case user re-triggered onboarding.
            let stored = store.familyGroupName
            if !stored.isEmpty { name = stored }
        }
    }

    private var hero: some View {
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 22)
                    .fill(LinearGradient.gradient([AppColors.auroraPink, AppColors.auroraAmber]))
                    .frame(width: 72, height: 72)
                Image(systemName: "house.and.flag")
                    .font(.system(size: 28, weight: .regular))
                    .foregroundStyle(.white)
            }
            Text("给家一个名字").font(.system(size: 22, weight: .medium))
            Text("家庭账本 · CloudKit 端到端加密,伴侣 / 孩子日后一键邀请")
                .font(.system(size: 13))
                .foregroundStyle(AppColors.ink2)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 8)
        }
        .padding(.top, 16)
    }

    private var nameCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("家庭名").eyebrowStyle()
            TextField("例如:深圳小窝 / 咱俩的家", text: $name)
                .font(.system(size: 14))
                .focused($nameFocused)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .padding(.vertical, 12).padding(.horizontal, 14)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.55)))
            Text("可随时在「我 → 编辑资料」里改")
                .font(.system(size: 10))
                .foregroundStyle(AppColors.ink3)
        }
        .padding(16)
        .glassCard(radius: 14)
    }

    private var privacyBlurb: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "lock.shield").font(.system(size: 11)).foregroundStyle(AppColors.ink3)
            Text("三档隐私:家庭可见 / 仅伴侣 / 仅自己 · 每笔都可单独选")
                .font(.system(size: 11))
                .foregroundStyle(AppColors.ink3)
                .lineSpacing(2)
            Spacer(minLength: 0)
        }
        .padding(.top, 4)
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            store.familyGroupName = trimmed
        }
        onFinish()
    }
}

#Preview {
    ZStack {
        AuroraBackground(palette: .profile)
        FamilyStep(onFinish: {}, onSkip: {})
            .environment(AppStore())
    }
}
