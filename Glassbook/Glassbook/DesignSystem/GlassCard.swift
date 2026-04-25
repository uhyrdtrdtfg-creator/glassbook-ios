import SwiftUI

/// Spec §7.1.2 · Glass card = frosted white fill + 1px highlight border + soft drop shadow.
struct GlassCardModifier: ViewModifier {
    var radius: CGFloat = Radius.lg
    var padding: CGFloat? = nil
    var strokeOpacity: Double = 0.6

    func body(content: Content) -> some View {
        content
            .padding(padding ?? 0)
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        AppColors.glassFillStrong,
                                        AppColors.glassTint,
                                        Color.white.opacity(0.08)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(alignment: .top) {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        AppColors.innerGlow,
                                        Color.white.opacity(0.08),
                                        .clear
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(height: max(44, radius * 1.35))
                            .mask(
                                RoundedRectangle(cornerRadius: radius, style: .continuous)
                            )
                    }
            }
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(min(1, strokeOpacity + 0.16)),
                                AppColors.glassBorderSoft.opacity(0.95),
                                Color.white.opacity(0.16)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: AppColors.surfaceShadow, radius: 24, x: 0, y: 14)
            .shadow(color: Color.white.opacity(0.18), radius: 1.5, x: 0, y: -1)
    }
}

extension View {
    /// Default glass card (radius 22, white-38% + ultraThinMaterial).
    func glassCard(radius: CGFloat = Radius.lg, padding: CGFloat? = nil) -> some View {
        modifier(GlassCardModifier(radius: radius, padding: padding))
    }
}

/// Dark glass variant (Spec §7.1.2 · glass-dark) for FAB / primary actions.
struct DarkGlassModifier: ViewModifier {
    var radius: CGFloat = Radius.lg
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [AppColors.ink, Color(hex: 0x303655)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                    )
            )
            .shadow(color: AppColors.surfaceShadowStrong, radius: 18, x: 0, y: 10)
    }
}

extension View {
    func darkCapsule(radius: CGFloat = Radius.full) -> some View {
        self.modifier(DarkGlassModifier(radius: radius))
    }
}
