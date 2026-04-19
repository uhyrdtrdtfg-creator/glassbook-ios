import SwiftUI

/// Single row in Home · 最近交易 / Bills · day group.
struct TransactionRow: View {
    let tx: Transaction
    var showDate: Bool = false
    var compact: Bool = false

    var body: some View {
        let cat = Category.by(tx.categoryID)
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(LinearGradient.gradient(cat.gradient))
                    .frame(width: compact ? 32 : 34, height: compact ? 32 : 34)
                Text(cat.emoji)
                    .font(.system(size: 15))
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(tx.merchant)
                    .font(.system(size: compact ? 12 : 13, weight: .medium))
                    .foregroundStyle(AppColors.ink)
                HStack(spacing: 6) {
                    Text(showDate ? Self.dateRel.string(for: tx.timestamp) ?? "" : Self.time.string(from: tx.timestamp))
                    Text("·")
                    Text(cat.name)
                    if tx.source != .manual {
                        Text("·")
                        Text("AI 导入")
                            .foregroundStyle(AppColors.ink3)
                    }
                }
                .font(.system(size: 10))
                .foregroundStyle(AppColors.ink3)
                .tracking(0.2)
            }
            Spacer(minLength: 4)
            Text(Money.yuan(tx.amountCents, showDecimals: false, showSign: false))
                .font(.system(size: 14, weight: .medium).monospacedDigit())
                .foregroundStyle(tx.kind == .income ? AppColors.incomeGreen : AppColors.ink)
        }
        .padding(.vertical, compact ? 8 : 10)
        .padding(.horizontal, 8)
    }

    private static let time: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f
    }()
    private static let dateRel: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日 HH:mm"
        f.doesRelativeDateFormatting = true
        return f
    }()
}

struct CategoryIconTile: View {
    let category: Category
    var size: CGFloat = 34
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.35, style: .continuous)
                .fill(LinearGradient.gradient(category.gradient))
            Text(category.emoji)
                .font(.system(size: size * 0.48))
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
    }
}
