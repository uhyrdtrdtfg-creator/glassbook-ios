import SwiftUI

/// Onboarding step 1 · Teases the BYO AI engine config.
/// We don't duplicate AIEngineSettingsView here — just point users to
/// "我 → AI 引擎" for after they finish the walkthrough.
struct AIEnginePickerStep: View {
    var onNext: () -> Void
    var onSkip: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 18) {
                    hero
                    engineRow(icon: "cpu", title: "本地 · 端上引擎", body: "零配置 · 默认开启 · 隐私最好")
                    engineRow(icon: "sparkles", title: "OpenAI / Claude / Gemini", body: "填自家 API Key · 分类更准")
                    engineRow(icon: "server.rack", title: "Ollama / 自建网关", body: "跑自己的模型 · 全端本地")
                    hint
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
                    .fill(LinearGradient.brand())
                    .frame(width: 72, height: 72)
                Image(systemName: "brain")
                    .font(.system(size: 32, weight: .regular))
                    .foregroundStyle(.white)
            }
            Text("AI 帮你分类").font(.system(size: 22, weight: .medium))
            Text("自动识别吃饭 / 打车 / 购物,不用手点 · 支持自带模型")
                .font(.system(size: 13))
                .foregroundStyle(AppColors.ink2)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 8)
        }
        .padding(.top, 16)
    }

    private func engineRow(icon: String, title: String, body: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(AppColors.ink)
                .frame(width: 40, height: 40)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.55)))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 14, weight: .medium))
                Text(body).font(.system(size: 11)).foregroundStyle(AppColors.ink3)
            }
            Spacer()
        }
        .padding(14)
        .glassCard(radius: 14)
    }

    private var hint: some View {
        Text("完成引导后,去「我 → AI 引擎」随时切换")
            .font(.system(size: 11))
            .foregroundStyle(AppColors.ink3)
            .padding(.top, 4)
    }
}

#Preview {
    ZStack {
        AuroraBackground(palette: .stats)
        AIEnginePickerStep(onNext: {}, onSkip: {})
    }
}
