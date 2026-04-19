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
                            .fill(Color.white.opacity(0.18))
                    )
            }
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Color.white.opacity(strokeOpacity), lineWidth: 1)
            )
            .shadow(color: Color(hex: 0x503C78).opacity(0.10), radius: 16, x: 0, y: 8)
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
                    .fill(AppColors.ink)
            )
    }
}

extension View {
    func darkCapsule(radius: CGFloat = Radius.full) -> some View {
        self.modifier(DarkGlassModifier(radius: radius))
    }
}
