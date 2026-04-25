import SwiftUI

// MARK: - Screen 3 · Confirm (the money screen)

struct SmartImportConfirmScreen: View {
    let platform: ImportBatch.Platform
    @Binding var rows: [PendingImportRow]
    var onCancel: () -> Void
    var onConfirm: () -> Void
    @State private var editingRowID: PendingImportRow.ID?
    @State private var aiClassifying: Bool = false
    @State private var aiError: String?
    @State private var aiAppliedCount: Int = 0
    @State private var pendingDiff: [AIClassifyDiffItem] = []
    @State private var showDiffSheet: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            nav
            summary
            batchBar
            ScrollView {
                VStack(spacing: 0) {
                    ForEach($rows) { $row in
                        confirmRow($row: $row)
                        if rows.last?.id != row.id {
                            Divider().background(AppColors.glassDivider).padding(.horizontal, 10)
                        }
                    }
                }
                .padding(6)
                .glassCard()
                .padding(.horizontal, 18)
            }
            .scrollIndicators(.hidden)

            confirmButton
        }
        .safeAreaPadding(.top, 8)
        .sheet(item: Binding(
            get: { editingRowID.flatMap { id in rows.first { $0.id == id } } },
            set: { new in editingRowID = new?.id }
        )) { row in
            if let idx = rows.firstIndex(where: { $0.id == row.id }) {
                EditPendingRowSheet(row: $rows[idx]) { editingRowID = nil }
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showDiffSheet) {
            AIClassifyDiffSheet(
                diff: pendingDiff,
                onApply: { approved in
                    applyDiff(approved)
                    showDiffSheet = false
                },
                onCancel: { showDiffSheet = false }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    private var nav: some View {
        HStack {
            Button(action: onCancel) {
                Image(systemName: "chevron.left").font(.system(size: 13))
                    .frame(width: 34, height: 34)
                    .glassCard(radius: 12)
                    .foregroundStyle(AppColors.ink)
            }
            Spacer()
            Text("确认导入").font(.system(size: 16, weight: .medium))
            Spacer()
            Spacer().frame(width: 34)
        }
        .padding(.horizontal, 18).padding(.vertical, 8)
    }

    private var summary: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(LinearGradient.gradient(platform.gradient))
                Text(platform.abbrev).font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text("识别到 \(rows.count) 笔  ·  \(platform.displayName)")
                    .font(.system(size: 12, weight: .medium))
                Text(Money.yuan(totalCents, showDecimals: true))
                    .font(.system(size: 20, weight: .light).monospacedDigit())
                    .foregroundStyle(AppColors.ink)
            }
            Spacer()
        }
        .padding(16)
        .glassCard()
        .padding(.horizontal, 18).padding(.vertical, 8)
    }

    private var totalCents: Int { rows.reduce(0) { $0 + $1.amountCents } }

    private var batchBar: some View {
        VStack(spacing: 6) {
            HStack {
                Text("已选 \(selectedCount)/\(rows.count)")
                    .font(.system(size: 11)).foregroundStyle(AppColors.ink2)
                Spacer()
                Button { Task { await runAIClassify() } } label: {
                    HStack(spacing: 4) {
                        if aiClassifying {
                            ProgressView().controlSize(.mini).tint(.white)
                        } else {
                            Image(systemName: "sparkles").font(.system(size: 10))
                        }
                        Text(aiClassifying ? "AI 分类中…" : "AI 自动分类")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Capsule().fill(LinearGradient.brand()))
                }
                .buttonStyle(.plain)
                .disabled(aiClassifying || rows.isEmpty)
                .opacity(aiClassifying ? 0.6 : 1)
                Button { toggleAll() } label: {
                    Text(selectedCount == rows.count ? "取消全选" : "全选")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppColors.ink)
                }
            }
            if let msg = aiError {
                Text(msg).font(.system(size: 10))
                    .foregroundStyle(AppColors.expenseRed)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            } else if aiAppliedCount > 0 {
                Text("✓ AI 重新分类了 \(aiAppliedCount) 笔")
                    .font(.system(size: 10))
                    .foregroundStyle(AppColors.successGreen)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 26).padding(.vertical, 8)
    }

    private func runAIClassify() async {
        aiClassifying = true
        aiError = nil
        aiAppliedCount = 0
        defer { aiClassifying = false }
        do {
            let assigned = try await LLMClassifier.categorize(rows)
            // Build diff: only rows whose category actually changed.
            var diff: [AIClassifyDiffItem] = []
            for row in rows {
                guard let newCat = assigned[row.id], newCat != row.categoryID else { continue }
                diff.append(AIClassifyDiffItem(
                    rowID: row.id,
                    merchant: row.merchant,
                    amountCents: row.amountCents,
                    current: row.categoryID,
                    suggested: newCat
                ))
            }
            if diff.isEmpty {
                aiError = assigned.isEmpty ? "AI 没返回有效结果 · 请换个模型" : "AI 觉得当前分类已经准了,没要改的"
                return
            }
            pendingDiff = diff
            showDiffSheet = true
        } catch let e as LLMClassifier.Failure {
            aiError = e.errorDescription
        } catch {
            aiError = error.localizedDescription
        }
    }

    private func applyDiff(_ approved: [AIClassifyDiffItem]) {
        var changed = 0
        for item in approved {
            guard let idx = rows.firstIndex(where: { $0.id == item.rowID }) else { continue }
            rows[idx].categoryID = item.suggested
            changed += 1
        }
        aiAppliedCount = changed
        pendingDiff = []
    }

    private var selectedCount: Int { rows.filter(\.isSelected).count }

    private func toggleAll() {
        let allSelected = selectedCount == rows.count
        for i in rows.indices { rows[i].isSelected = !allSelected }
    }

    private func confirmRow(@Binding row: PendingImportRow) -> some View {
        let cat = Category.by(row.categoryID)
        return HStack(spacing: 10) {
            Button {
                row.isSelected.toggle()
            } label: {
                Image(systemName: row.isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(row.isSelected ? AppColors.ink : AppColors.ink3)
            }
            .buttonStyle(.plain)

            Button {
                editingRowID = row.id
            } label: {
                HStack(spacing: 10) {
                    CategoryIconTile(category: cat, size: 30)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.merchant).font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppColors.ink)
                            .lineLimit(1)
                        HStack(spacing: 4) {
                            Text(cat.name).font(.system(size: 10))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Capsule().fill(LinearGradient.gradient(cat.gradient)))
                            if row.isDuplicate {
                                Text("已存在").font(.system(size: 9))
                                    .foregroundStyle(AppColors.expenseRed)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(Capsule().fill(AppColors.expenseRed.opacity(0.15)))
                            }
                            Text(Self.time.string(from: row.timestamp))
                                .font(.system(size: 9)).foregroundStyle(AppColors.ink3)
                        }
                    }
                    Spacer(minLength: 4)
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(Money.yuan(row.amountCents, showDecimals: false))
                            .font(.system(size: 13, weight: .medium).monospacedDigit())
                            .foregroundStyle(row.isDuplicate ? AppColors.ink3 : AppColors.ink)
                        Image(systemName: "pencil")
                            .font(.system(size: 9))
                            .foregroundStyle(AppColors.ink3)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 10).padding(.horizontal, 8)
        .opacity(row.isDuplicate && !row.isSelected ? 0.6 : 1)
    }

    private var confirmButton: some View {
        Button(action: onConfirm) {
            Text("导入选中交易  [ \(selectedCount) 笔 ]")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(RoundedRectangle(cornerRadius: 14).fill(AppColors.ink))
        }
        .buttonStyle(.plain)
        .padding(18)
    }

    private static let time: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M/d HH:mm"
        return f
    }()
}
