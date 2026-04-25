import SwiftUI

/// Single row in Home · 最近交易 / Bills · day group.
struct TransactionRow: View {
    let tx: Transaction
    var showDate: Bool = false
    var compact: Bool = false

    var body: some View {
        let cat = Category.by(tx.categoryID)

        HStack(spacing: compact ? 10 : 12) {
            CategoryIconTile(category: cat, size: compact ? 34 : 38)

            VStack(alignment: .leading, spacing: compact ? 3 : 5) {
                HStack(spacing: 6) {
                    Text(tx.merchant)
                        .font(.system(size: compact ? 12 : 14, weight: .medium))
                        .foregroundStyle(AppColors.ink)
                        .lineLimit(1)

                    if tx.source != .manual {
                        Text(sourceBadgeText(tx.source))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(AppColors.ink2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.white.opacity(0.36)))
                            .overlay(Capsule().strokeBorder(AppColors.glassBorderSoft, lineWidth: 1))
                    }
                }

                Text(metaText(for: cat))
                    .font(.system(size: compact ? 10 : 11))
                    .foregroundStyle(AppColors.ink3)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                Text(Money.yuan(tx.amountCents, showDecimals: false, showSign: tx.kind == .income))
                    .font(.system(size: compact ? 14 : 15, weight: .semibold).monospacedDigit())
                    .foregroundStyle(tx.kind == .income ? AppColors.incomeGreen : AppColors.ink)
                    .lineLimit(1)
                Text(showDate ? Self.dateRel.string(from: tx.timestamp) : Self.time.string(from: tx.timestamp))
                    .font(.system(size: 10).monospacedDigit())
                    .foregroundStyle(AppColors.ink3)
            }
        }
        .padding(.vertical, compact ? 9 : 11)
        .padding(.horizontal, compact ? 10 : 12)
    }

    private func metaText(for category: Category) -> String {
        var pieces = [category.name]
        if tx.kind == .income { pieces.append("收入") }
        if let note = tx.note?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
            pieces.append(note)
        } else if tx.source == .manual {
            pieces.append("手动记录")
        }
        return pieces.joined(separator: " · ")
    }

    private func sourceBadgeText(_ source: Transaction.Source) -> String {
        switch source {
        case .manual: return "手动"
        case .alipay: return "支付宝"
        case .wechat: return "微信"
        case .cmb: return "招行"
        case .jd: return "京东"
        case .meituan: return "美团"
        case .douyin: return "抖音"
        case .otherOCR: return "OCR"
        }
    }

    private static let time: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
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
            RoundedRectangle(cornerRadius: size * 0.34, style: .continuous)
                .fill(LinearGradient.gradient(category.gradient))
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.34, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.28), lineWidth: 1)
                )
            RoundedRectangle(cornerRadius: size * 0.34, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.22), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Text(category.emoji)
                .font(.system(size: size * 0.46))
        }
        .frame(width: size, height: size)
        .shadow(color: AppColors.surfaceShadow.opacity(0.45), radius: 10, x: 0, y: 6)
    }
}
