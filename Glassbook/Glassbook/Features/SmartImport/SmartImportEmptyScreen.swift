import SwiftUI

/// Shown when Vision OCR ran but either returned zero text lines OR the
/// platform parsers couldn't extract any transactions. No phantom data —
/// we tell the user exactly what happened and give them a retry path.
struct SmartImportEmptyScreen: View {
    let reason: String
    var onRetry: () -> Void
    var onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            nav
            Spacer()
            ZStack {
                Circle()
                    .fill(AppColors.expenseRed.opacity(0.12))
                    .frame(width: 112, height: 112)
                Image(systemName: "doc.viewfinder")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(AppColors.expenseRed)
            }
            VStack(spacing: 8) {
                Text("没识别出交易")
                    .font(.system(size: 20, weight: .medium))
                    .padding(.top, 16)
                Text(reason.isEmpty ? "Vision 没在这张图里找到任何可入账的记录。" : reason)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.ink2)
                    .lineSpacing(3)
                    .padding(.horizontal, 40)
            }
            Spacer()
            VStack(spacing: 10) {
                Button(action: onRetry) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                        Text("换一张再试").font(.system(size: 14, weight: .medium))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(RoundedRectangle(cornerRadius: 14).fill(AppColors.ink))
                }
                .buttonStyle(.plain)
                Button(action: onCancel) {
                    Text("取消")
                        .font(.system(size: 13))
                        .foregroundStyle(AppColors.ink2)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
        }
    }

    private var nav: some View {
        HStack {
            Button(action: onCancel) {
                Image(systemName: "xmark").font(.system(size: 13))
                    .frame(width: 34, height: 34)
                    .glassCard(radius: 12)
                    .foregroundStyle(AppColors.ink)
            }
            Spacer()
            Text("未识别").font(.system(size: 16, weight: .medium))
            Spacer()
            Spacer().frame(width: 34)
        }
        .padding(.horizontal, 18).padding(.vertical, 8)
    }
}
