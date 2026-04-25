import SwiftUI

/// 3-step first-launch walkthrough. Presented from RootView as an
/// `.interactiveDismissDisabled()` sheet when `hasCompletedOnboarding == false`.
struct OnboardingFlow: View {
    @Binding var isPresented: Bool
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @State private var step: Int = 0

    var body: some View {
        ZStack {
            AuroraBackground(palette: stepPalette)
                .animation(.easeInOut(duration: 0.45), value: step)

            VStack(spacing: 0) {
                progressBar
                    .padding(.horizontal, 24)
                    .padding(.top, 28)
                    .padding(.bottom, 14)

                Group {
                    switch step {
                    case 0:
                        AIEnginePickerStep(onNext: advance, onSkip: skipToEnd)
                    case 1:
                        ScreenshotAutomationStep(onNext: advance, onSkip: skipToEnd)
                    default:
                        FamilyStep(onFinish: finish, onSkip: finish)
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))

                Spacer(minLength: 0)
            }
            // why: keep the walkthrough centered on iPad / Mac instead of edge-to-edge.
            .frame(maxWidth: hSizeClass == .regular ? 560 : .infinity)
        }
        .interactiveDismissDisabled()
    }

    private var stepPalette: AuroraPalette {
        switch step {
        case 0: .stats
        case 1: .bills
        default: .profile
        }
    }

    private var progressBar: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { i in
                Capsule()
                    .fill(i <= step ? AppColors.ink : Color.white.opacity(0.45))
                    .frame(height: 3)
                    .animation(.easeInOut(duration: 0.3), value: step)
            }
        }
    }

    private func advance() {
        withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
            step = min(step + 1, 2)
        }
    }

    private func skipToEnd() {
        withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
            step = 2
        }
    }

    private func finish() {
        hasCompletedOnboarding = true
        isPresented = false
    }
}

// MARK: - Shared bottom button row

/// Used by steps 1–3 so the next/skip pair looks identical.
struct OnboardingButtonRow: View {
    var primaryTitle: String
    var onPrimary: () -> Void
    var secondaryTitle: String? = "跳过"
    var onSecondary: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 10) {
            Button(action: onPrimary) {
                Text(primaryTitle)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(RoundedRectangle(cornerRadius: 16).fill(AppColors.ink))
            }
            .buttonStyle(.plain)

            if let title = secondaryTitle, let onSecondary {
                Button(action: onSecondary) {
                    Text(title)
                        .font(.system(size: 13))
                        .foregroundStyle(AppColors.ink2)
                        .frame(maxWidth: .infinity, minHeight: 38)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 28)
    }
}

#Preview {
    OnboardingFlow(isPresented: .constant(true))
}
