import SwiftUI

/// Spec v2 · V2.0 · 发票抵扣 PDF 导出. Filter by date + category, generate PDF,
/// hand off via ShareLink.
struct InvoiceExportView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var startDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: .now) ?? .now
    @State private var endDate: Date = .now
    @State private var selectedCats: Set<Category.Slug> = []
    @State private var titleText: String = "Glassbook · 报销明细"
    @State private var authorText: String = "Roger Dupuis"
    @State private var generatedURL: URL?
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            AuroraBackground(palette: .bills)
            ScrollView {
                VStack(spacing: 14) {
                    header
                    previewStats
                    dateRangeCard
                    categoryPicker
                    metaCard
                    actionCard
                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left").font(.system(size: 13))
                    .frame(width: 34, height: 34).glassCard(radius: 12)
                    .foregroundStyle(AppColors.ink)
            }
            Spacer()
            Text("发票 PDF 导出").font(.system(size: 16, weight: .medium))
            Spacer()
            Spacer().frame(width: 34)
        }
    }

    // MARK: - Preview

    private var filtered: [Transaction] {
        store.transactions.filter { tx in
            guard tx.kind == .expense else { return false }
            guard tx.timestamp >= startDate && tx.timestamp <= endDate else { return false }
            if selectedCats.isEmpty { return true }
            return selectedCats.contains(tx.categoryID)
        }
    }
    private var filteredTotal: Int { filtered.reduce(0) { $0 + $1.amountCents } }

    private var previewStats: some View {
        HStack(spacing: 0) {
            stat("笔数", value: "\(filtered.count)")
            Divider().background(AppColors.glassDivider)
            stat("合计", value: Money.yuan(filteredTotal, showDecimals: false))
            Divider().background(AppColors.glassDivider)
            stat("分类", value: selectedCats.isEmpty ? "全部" : "\(selectedCats.count) 个")
        }
        .padding(.vertical, 16)
        .glassCard()
    }

    private func stat(_ label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(label).eyebrowStyle()
            Text(value).font(.system(size: 16, weight: .light).monospacedDigit())
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Date range

    private var dateRangeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("日期范围").eyebrowStyle()
            HStack {
                DatePicker("开始", selection: $startDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                Image(systemName: "arrow.right").foregroundStyle(AppColors.ink3)
                DatePicker("结束", selection: $endDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
            }
            HStack(spacing: 6) {
                quickRange("本月")  { rangeMonth(0) }
                quickRange("上月")  { rangeMonth(-1) }
                quickRange("近 30")  { rangeDays(30) }
                quickRange("近 90")  { rangeDays(90) }
            }
        }
        .padding(14)
        .glassCard(radius: 14)
    }

    private func quickRange(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label).font(.system(size: 10, weight: .medium))
                .foregroundStyle(AppColors.ink)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Capsule().fill(Color.white.opacity(0.6)))
                .overlay(Capsule().strokeBorder(AppColors.glassBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func rangeMonth(_ offset: Int) {
        let cal = Calendar.current
        let base = cal.date(byAdding: .month, value: offset, to: .now) ?? .now
        let start = cal.date(from: cal.dateComponents([.year, .month], from: base)) ?? base
        let end = cal.date(byAdding: .month, value: 1, to: start).map { cal.date(byAdding: .second, value: -1, to: $0) ?? $0 } ?? base
        startDate = start; endDate = end
    }
    private func rangeDays(_ n: Int) {
        startDate = Calendar.current.date(byAdding: .day, value: -n, to: .now) ?? .now
        endDate = .now
    }

    // MARK: - Category

    private var categoryPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("分类 (空 = 全部)").eyebrowStyle()
                Spacer()
                if !selectedCats.isEmpty {
                    Button("清除") { selectedCats.removeAll() }
                        .font(.system(size: 10))
                        .foregroundStyle(AppColors.ink3)
                }
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                ForEach(Category.all, id: \.id) { cat in
                    Button {
                        if selectedCats.contains(cat.id) { selectedCats.remove(cat.id) }
                        else { selectedCats.insert(cat.id) }
                    } label: {
                        HStack(spacing: 4) {
                            Text(cat.emoji).font(.system(size: 12))
                            Text(cat.name).font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(selectedCats.contains(cat.id) ? .white : AppColors.ink)
                        .frame(maxWidth: .infinity, minHeight: 32)
                        .background(
                            Capsule().fill(selectedCats.contains(cat.id) ? AppColors.ink : Color.white.opacity(0.55))
                        )
                        .overlay(Capsule().strokeBorder(AppColors.glassBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .glassCard(radius: 14)
    }

    // MARK: - Meta

    private var metaCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PDF 信息").eyebrowStyle()
            TextField("标题", text: $titleText)
                .font(.system(size: 13))
            Divider().background(AppColors.glassDivider)
            TextField("报销人", text: $authorText)
                .font(.system(size: 13))
        }
        .padding(14)
        .glassCard(radius: 14)
    }

    // MARK: - Action

    private var actionCard: some View {
        VStack(spacing: 10) {
            Button {
                generate()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "doc.badge.arrow.up")
                    Text("生成 PDF").font(.system(size: 14, weight: .medium))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(RoundedRectangle(cornerRadius: 14).fill(AppColors.ink))
            }
            .buttonStyle(.plain)
            .disabled(filtered.isEmpty)
            .opacity(filtered.isEmpty ? 0.5 : 1)

            if let url = generatedURL {
                ShareLink(item: url) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                        Text("分享 / 存储 PDF").font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(AppColors.ink)
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.6)))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(AppColors.glassBorder, lineWidth: 1))
                }
                Text("PDF 已生成在设备临时目录 · 未经任何服务器")
                    .font(.system(size: 10))
                    .foregroundStyle(AppColors.incomeGreen)
            }
            if let err = errorMessage {
                Text(err).font(.system(size: 11))
                    .foregroundStyle(AppColors.expenseRed)
            }
        }
    }

    private func generate() {
        errorMessage = nil
        do {
            let result = try PDFExporter.export(
                transactions: store.transactions,
                criteria: .init(
                    startDate: startDate, endDate: endDate,
                    categoryFilter: selectedCats,
                    title: titleText, author: authorText
                )
            )
            generatedURL = result.url
        } catch {
            errorMessage = "导出失败:\(error.localizedDescription)"
        }
    }
}

#Preview {
    InvoiceExportView().environment(AppStore())
}
