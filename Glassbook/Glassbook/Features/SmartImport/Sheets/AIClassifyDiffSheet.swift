import SwiftUI

// MARK: - Item 6 · AI classify preview diff

/// Single row in the AI-classification preview sheet. Only built for rows
/// where the LLM suggested a category different from the current one —
/// no-ops are filtered by the caller.
struct AIClassifyDiffItem: Identifiable, Hashable {
    let id = UUID()
    let rowID: PendingImportRow.ID
    let merchant: String
    let amountCents: Int
    let current: Category.Slug
    let suggested: Category.Slug
}

/// Preview the AI's suggested category changes before applying. User can
/// untick rows they disagree with, or cancel entirely. Only checked rows
/// are pushed back through `onApply`.
struct AIClassifyDiffSheet: View {
    let diff: [AIClassifyDiffItem]
    var onApply: ([AIClassifyDiffItem]) -> Void
    var onCancel: () -> Void

    @State private var checkedIDs: Set<AIClassifyDiffItem.ID> = []

    var body: some View {
        ZStack {
            AuroraBackground(palette: .importAmber)
            VStack(spacing: 0) {
                header
                list
                footer
            }
        }
        .onAppear { checkedIDs = Set(diff.map(\.id)) }  // 默认全选
    }

    private var header: some View {
        HStack {
            Button(action: onCancel) {
                Image(systemName: "chevron.left").font(.system(size: 13))
                    .frame(width: 34, height: 34)
                    .glassCard(radius: 12)
                    .foregroundStyle(AppColors.ink)
            }
            Spacer()
            VStack(spacing: 2) {
                Text("AI 建议的分类调整").font(.system(size: 15, weight: .medium))
                Text("勾选你同意的 · 其余保持不动")
                    .font(.system(size: 10))
                    .foregroundStyle(AppColors.ink2)
            }
            Spacer()
            Button {
                checkedIDs = checkedIDs.count == diff.count ? [] : Set(diff.map(\.id))
            } label: {
                Text(checkedIDs.count == diff.count ? "全不选" : "全选")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppColors.ink)
                    .frame(height: 34)
                    .padding(.horizontal, 10)
                    .glassCard(radius: 12)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18).padding(.top, 12).padding(.bottom, 8)
    }

    private var list: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(diff) { item in
                    row(item)
                    if diff.last?.id != item.id {
                        Divider().background(AppColors.glassDivider).padding(.horizontal, 10)
                    }
                }
            }
            .padding(6)
            .glassCard()
            .padding(.horizontal, 18)
        }
        .scrollIndicators(.hidden)
    }

    private func row(_ item: AIClassifyDiffItem) -> some View {
        let isChecked = checkedIDs.contains(item.id)
        let currentCat = Category.by(item.current)
        let suggestedCat = Category.by(item.suggested)
        return HStack(spacing: 10) {
            Button {
                if isChecked { checkedIDs.remove(item.id) }
                else         { checkedIDs.insert(item.id) }
            } label: {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isChecked ? AppColors.ink : AppColors.ink3)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(item.merchant)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppColors.ink)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(Money.yuan(item.amountCents, showDecimals: false))
                        .font(.system(size: 11).monospacedDigit())
                        .foregroundStyle(AppColors.ink3)
                }
                HStack(spacing: 6) {
                    categoryChip(currentCat, faded: true)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 9))
                        .foregroundStyle(AppColors.ink3)
                    categoryChip(suggestedCat, faded: false)
                }
            }
        }
        .padding(.vertical, 10).padding(.horizontal, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            if isChecked { checkedIDs.remove(item.id) }
            else         { checkedIDs.insert(item.id) }
        }
    }

    private func categoryChip(_ cat: Category, faded: Bool) -> some View {
        HStack(spacing: 3) {
            Text(cat.emoji).font(.system(size: 10))
            Text(cat.name).font(.system(size: 10))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 6).padding(.vertical, 2)
        .background(Capsule().fill(LinearGradient.gradient(cat.gradient)))
        .opacity(faded ? 0.55 : 1)
    }

    private var footer: some View {
        let approved = diff.filter { checkedIDs.contains($0.id) }
        return Button {
            onApply(approved)
        } label: {
            Text(approved.isEmpty ? "没勾选要改的" : "应用勾选的 \(approved.count) 项")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(RoundedRectangle(cornerRadius: 14).fill(AppColors.ink))
        }
        .buttonStyle(.plain)
        .disabled(approved.isEmpty)
        .opacity(approved.isEmpty ? 0.5 : 1)
        .padding(18)
    }
}
