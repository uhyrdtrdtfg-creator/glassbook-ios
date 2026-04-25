import SwiftUI

/// Floating "已删除 · 撤销" bar shown while a deletion is in the 5-second pending
/// window. Parent owns visibility; this view is purely visual.
struct UndoToast: View {
    let message: String
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "trash")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppColors.ink2)

            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppColors.ink)
                .lineLimit(1)

            Spacer(minLength: 12)

            Button(action: onUndo) {
                Text("撤销")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(
                        Capsule().fill(
                            LinearGradient(
                                colors: [AppColors.brandStart, AppColors.brandEnd],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                        .strokeBorder(AppColors.glassBorderSoft, lineWidth: 1)
                )
        )
        .shadow(color: AppColors.surfaceShadow, radius: 18, x: 0, y: 10)
        .padding(.horizontal, 20)
    }
}

#Preview {
    ZStack {
        AuroraBackground(palette: .bills)
        UndoToast(message: "已删除 3 笔") {}
    }
}
