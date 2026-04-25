import SwiftUI

// MARK: - Screen 4 · Done

struct SmartImportDoneScreen: View {
    struct Summary {
        let selectedCount: Int
        let totalExpenseCents: Int
        let totalIncomeCents: Int
        let spanDays: Int
        let duplicates: Int
    }
    let summary: Summary
    var onImportAnother: () -> Void
    var onViewBills: () -> Void
    var onRollback: (() -> Void)? = nil

    @State private var checkScale: CGFloat = 0.3
    @State private var glow: CGFloat = 0

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle().fill(AppColors.successGreen.opacity(0.25))
                    .frame(width: 160, height: 160).blur(radius: 25)
                    .scaleEffect(glow)
                Circle().fill(AppColors.successGreen.opacity(0.2))
                    .frame(width: 110, height: 110)
                Circle().fill(AppColors.successGreen)
                    .frame(width: 78, height: 78)
                Image(systemName: "checkmark")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(.white)
                    .scaleEffect(checkScale)
            }
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.5)) { checkScale = 1 }
                withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) { glow = 1.2 }
            }

            VStack(spacing: 6) {
                Text("成功导入 \(summary.selectedCount) 笔")
                    .font(.system(size: 22, weight: .medium))
                Text("已自动去重 \(summary.duplicates) 笔")
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.ink2)
            }

            summaryCard
                .padding(.horizontal, 18)

            if let onRollback {
                Button(action: onRollback) {
                    Text("撤销整批 (7 天内可恢复)")
                        .font(.system(size: 11))
                        .foregroundStyle(AppColors.ink3)
                        .underline()
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }

            Spacer()

            HStack(spacing: 10) {
                Button(action: onImportAnother) {
                    Text("再导一批")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppColors.ink)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.6)))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(AppColors.glassBorder, lineWidth: 1))
                }
                Button(action: onViewBills) {
                    Text("查看账单")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(RoundedRectangle(cornerRadius: 14).fill(AppColors.ink))
                }
            }
            .buttonStyle(.plain)
            .padding(18)
        }
    }

    private var summaryCard: some View {
        HStack(spacing: 0) {
            cell("合计支出", Money.yuan(summary.totalExpenseCents, showDecimals: false))
            Divider().background(AppColors.glassDivider)
            cell("跨越日期", "\(summary.spanDays) 天")
            Divider().background(AppColors.glassDivider)
            cell("去重", "\(summary.duplicates) 笔")
        }
        .padding(.vertical, 16)
        .glassCard()
    }

    private func cell(_ label: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(label).eyebrowStyle()
            Text(value).font(.system(size: 14, weight: .medium).monospacedDigit())
        }
        .frame(maxWidth: .infinity)
    }
}
