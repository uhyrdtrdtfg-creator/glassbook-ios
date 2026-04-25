import SwiftUI

/// Onboarding step 2 · Pitches the截屏 → 自动入账 flow.
/// Refers to the Shortcuts `ImportScreenshotIntent` — user builds the
/// automation in iOS 快捷指令 (Trigger: 每次截屏 → Action: Glassbook 识别截屏).
struct ScreenshotAutomationStep: View {
    var onNext: () -> Void
    var onSkip: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 18) {
                    hero
                    stepRow(num: "1", icon: "camera.viewfinder", title: "截屏账单", body: "支付宝 / 微信 / 招行账单详情页截一张")
                    stepRow(num: "2", icon: "wand.and.stars", title: "本地 OCR 识别", body: "图不出手机,金额 / 商户 / 分类自动填好")
                    stepRow(num: "3", icon: "checkmark.seal", title: "5 秒确认入账", body: "锁屏弹灵动岛,不点也会自动存")
                    shortcutTip
                }
                .padding(.horizontal, 24)
                .padding(.top, 4)
            }
            .scrollIndicators(.hidden)

            OnboardingButtonRow(
                primaryTitle: "下一步",
                onPrimary: onNext,
                secondaryTitle: "跳过",
                onSecondary: onSkip
            )
        }
    }

    private var hero: some View {
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 22)
                    .fill(LinearGradient.gradient([AppColors.auroraBlue, AppColors.auroraPurple]))
                    .frame(width: 72, height: 72)
                Image(systemName: "doc.text.viewfinder")
                    .font(.system(size: 30, weight: .regular))
                    .foregroundStyle(.white)
            }
            Text("截屏即入账").font(.system(size: 22, weight: .medium))
            Text("账单截图一拍,不用手输金额,记账最久 3 秒就结束")
                .font(.system(size: 13))
                .foregroundStyle(AppColors.ink2)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 8)
        }
        .padding(.top, 16)
    }

    private func stepRow(num: String, icon: String, title: String, body: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(AppColors.ink)
                Text(num).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
            }
            .frame(width: 28, height: 28)

            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(AppColors.ink)
                .frame(width: 36, height: 36)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.55)))

            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 13, weight: .medium))
                Text(body).font(.system(size: 10)).foregroundStyle(AppColors.ink3)
            }
            Spacer()
        }
        .padding(12)
        .glassCard(radius: 14)
    }

    private var shortcutTip: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "sparkle").font(.system(size: 11)).foregroundStyle(AppColors.ink3)
            Text("在「快捷指令」搜「Glassbook 识别截屏」配到每次截屏自动触发,完全零点击")
                .font(.system(size: 11))
                .foregroundStyle(AppColors.ink3)
                .lineSpacing(2)
            Spacer(minLength: 0)
        }
        .padding(.top, 4)
    }
}

#Preview {
    ZStack {
        AuroraBackground(palette: .bills)
        ScreenshotAutomationStep(onNext: {}, onSkip: {})
    }
}
