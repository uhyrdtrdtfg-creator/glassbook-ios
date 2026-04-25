import SwiftUI

/// Spec §4.3 · 账单明细
struct BillsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @State private var month: Date = Date()
    @State private var filterCategory: Category.Slug? = nil
    @State private var showFilter = false
    @State private var editingTxID: UUID?
    @State private var searchText: String = ""
    @State private var isEditing: Bool = false
    @State private var selectedIDs: Set<UUID> = []
    @Environment(\.scenePhase) private var scenePhase

    private struct IDWrap: Identifiable { let id: UUID }

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if !isSearching {
                        nav
                        if !isEditing { summaryCard }
                    }

                    if isSearching {
                        if searchGroupedTransactions.isEmpty {
                            searchEmptyState
                        } else {
                            ForEach(searchGroupedTransactions, id: \.date) { group in
                                dayGroup(date: group.date, items: group.items)
                            }
                        }
                    } else if groupedTransactions.isEmpty {
                        emptyState
                    } else {
                        ForEach(groupedTransactions, id: \.date) { group in
                            dayGroup(date: group.date, items: group.items)
                        }
                    }

                    Spacer().frame(height: isEditing ? 160 : 110)
                }
                .padding(.horizontal, 18)
                .padding(.top, 6)
                // why: cap reading width on iPad / Mac so the day cards don't span the whole canvas.
                .frame(maxWidth: hSizeClass == .regular ? 760 : .infinity)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            .safeAreaPadding(.top, 8)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            // Hide search while editing — selection UI would clash with a live search field.
            .modifier(ConditionalSearchable(text: $searchText, enabled: !isEditing))
            .overlay(alignment: .bottom) { bulkDeleteBar }
            .overlay(alignment: .bottom) { undoToastOverlay }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: store.pendingDeletion)
            .animation(.easeInOut(duration: 0.2), value: selectedIDs.isEmpty)
            .sheet(isPresented: $showFilter) {
                FilterSheet(selected: $filterCategory)
                    .presentationDetents([.large, .medium])
            }
            .sheet(item: Binding(
                get: { editingTxID.map { IDWrap(id: $0) } },
                set: { editingTxID = $0?.id }
            )) { wrap in
                EditTransactionSheet(txID: wrap.id)
                    .environment(store)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .onChange(of: scenePhase) { _, newPhase in
                // Don't let the 5s timer outlive the app going to background —
                // commit immediately so the deletion survives a kill/relaunch.
                if newPhase == .background { store.commitPendingDeletionNow() }
            }
        }
    }

    @ViewBuilder
    private var bulkDeleteBar: some View {
        if isEditing && !selectedIDs.isEmpty {
            Button(role: .destructive) {
                let ids = Array(selectedIDs)
                selectedIDs.removeAll()
                isEditing = false
                store.deleteMany(ids: ids)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .semibold))
                    Text("删除选中 (\(selectedIDs.count))")
                        .font(.system(size: 15, weight: .semibold))
                }
                .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppColors.expenseRed)
            .padding(.horizontal, 20)
            .padding(.bottom, 86)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    @ViewBuilder
    private var undoToastOverlay: some View {
        if let pd = store.pendingDeletion {
            UndoToast(message: "已删除 \(pd.ids.count) 笔") {
                store.undoDelete()
            }
            .padding(.bottom, 80)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private var nav: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(isEditing ? "选择要删除的" : "账单")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(AppColors.ink)
                Text(isEditing ? "已选 \(selectedIDs.count) 笔" : Self.monthFmt.string(from: month))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppColors.ink2)
            }

            Spacer()

            HStack(spacing: 8) {
                if isEditing {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedIDs.removeAll()
                            isEditing = false
                        }
                    } label: {
                        Text("完成")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppColors.ink)
                            .padding(.horizontal, 14)
                            .frame(height: 36)
                            .glassCard(radius: 12)
                    }
                    .buttonStyle(.plain)
                } else {
                    navButton(icon: "chevron.left") { shiftMonth(-1) }
                    navButton(icon: "chevron.right") { shiftMonth(1) }
                    Button { showFilter = true } label: {
                        HStack(spacing: 6) {
                            Image(systemName: filterCategory == nil ? "line.3.horizontal.decrease" : "line.3.horizontal.decrease.circle.fill")
                                .font(.system(size: 12, weight: .semibold))
                            if filterCategory != nil {
                                Text(filterLabel)
                                    .font(.system(size: 11, weight: .semibold))
                                    .lineLimit(1)
                            }
                        }
                        .foregroundStyle(AppColors.ink)
                        .padding(.horizontal, filterCategory == nil ? 0 : 12)
                        .frame(width: filterCategory == nil ? 36 : nil, height: 36)
                        .glassCard(radius: 12)
                    }
                    .buttonStyle(.plain)
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { isEditing = true }
                    } label: {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppColors.ink)
                            .frame(width: 36, height: 36)
                            .glassCard(radius: 12)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func navButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppColors.ink)
                .frame(width: 36, height: 36)
                .glassCard(radius: 12)
        }
        .buttonStyle(.plain)
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(filterCategory == nil ? "月度支出" : "\(filterLabel) 支出")
                        .eyebrowStyle()
                    Text(Money.yuan(expenseCents, showDecimals: true))
                        .font(.system(size: 34, weight: .light).monospacedDigit())
                        .foregroundStyle(AppColors.ink)
                        .lineLimit(1)
                    Text(comparisonText)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(comparisonTone)
                }

                Spacer(minLength: 10)

                VStack(alignment: .trailing, spacing: 8) {
                    capsuleInfo(text: selectedScopeText, tone: AppColors.ink2, fill: Color.white.opacity(0.34))
                    if let topCategory {
                        capsuleInfo(
                            text: "\(topCategory.name) 最多",
                            tone: AppColors.ink,
                            fill: Color.white.opacity(0.28)
                        )
                    }
                }
            }

            HStack(spacing: 10) {
                summaryMetric(label: "收入", value: Money.yuan(incomeCents, showDecimals: false), tone: AppColors.incomeGreen)
                summaryMetric(label: "笔数", value: "\(filteredMonthTransactions.count) 笔", tone: AppColors.ink)
                summaryMetric(label: "日均", value: Money.yuan(dailyAverageCents, showDecimals: false), tone: AppColors.ink)
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("活跃日期")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppColors.ink2)
                    Spacer()
                    Text("\(groupedTransactions.count) 天有记账")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(AppColors.ink3)
                }

                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(Array(dayBars.enumerated()), id: \.offset) { idx, value in
                        VStack(spacing: 5) {
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: idx == dayBars.count - 1
                                            ? [AppColors.brandStart, AppColors.brandEnd]
                                            : [AppColors.auroraPink.opacity(0.58), AppColors.auroraPurple.opacity(0.48)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(height: max(12, CGFloat(value) / CGFloat(maxDayBarValue) * 70))
                            Text(dayBarLabels[safe: idx] ?? "")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(AppColors.ink3)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 92)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: Radius.xl, style: .continuous)
                .fill(Color.clear)
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [AppColors.brandEnd.opacity(0.24), AppColors.brandStart.opacity(0.14), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 170, height: 170)
                        .offset(x: 48, y: -80)
                }
        }
        .glassCard(radius: Radius.xl)
    }

    private func capsuleInfo(text: String, tone: Color, fill: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(tone)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(fill))
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.34), lineWidth: 1))
    }

    private func summaryMetric(label: String, value: String, tone: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(AppColors.ink3)
            Text(value)
                .font(.system(size: 15, weight: .semibold).monospacedDigit())
                .foregroundStyle(tone)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.28))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.34), lineWidth: 1)
                )
        )
    }

    private func dayGroup(date: Date, items: [Transaction]) -> some View {
        let expense = items.filter { $0.kind == .expense }.reduce(0) { $0 + $1.amountCents }

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(relativeTitle(for: date))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppColors.ink)
                    Text(Self.dayFmt.string(from: date))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppColors.ink3)
                }

                Spacer()

                Text("\(items.count) 笔")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(AppColors.ink2)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.white.opacity(0.28)))

                Text(Money.yuan(expense, showDecimals: false))
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                    .foregroundStyle(AppColors.ink)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.white.opacity(0.36)))
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.36), lineWidth: 1))
            }

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { idx, tx in
                    if idx > 0 {
                        Divider()
                            .background(AppColors.glassDivider)
                            .padding(.horizontal, 10)
                    }
                    Button {
                        if isEditing {
                            toggleSelection(for: tx.id)
                        } else {
                            editingTxID = tx.id
                        }
                    } label: {
                        HStack(spacing: 10) {
                            if isEditing {
                                Image(systemName: selectedIDs.contains(tx.id) ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 19, weight: .medium))
                                    .foregroundStyle(selectedIDs.contains(tx.id) ? AppColors.brandEnd : AppColors.ink3)
                                    .padding(.leading, 8)
                                    .transition(.scale.combined(with: .opacity))
                            }
                            TransactionRow(tx: tx, compact: true)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        if !isEditing {
                            Button {
                                editingTxID = tx.id
                            } label: {
                                Label("编辑", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                store.delete(tx.id)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                            Button {
                                UIPasteboard.general.string = "\(tx.merchant) \(Money.yuan(tx.amountCents, showDecimals: true))"
                            } label: {
                                Label("复制", systemImage: "doc.on.doc")
                            }
                        }
                    }
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.20))
            )
        }
        .padding(14)
        .glassCard(radius: 22)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(AppColors.ink3)
            Text(filterCategory == nil ? "这个月份还没有账单" : "当前筛选下没有记录")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppColors.ink2)
            Text(filterCategory == nil ? "切换月份看看，或者先记一笔新的交易。" : "换个分类试试，或者清除筛选查看更多记录。")
                .font(.system(size: 11))
                .foregroundStyle(AppColors.ink3)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 20)
        .glassCard(radius: 22)
    }

    private var searchEmptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(AppColors.ink3)
            Text("找不到「\(searchText.trimmingCharacters(in: .whitespaces))」")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppColors.ink2)
            Text("换个关键词试试，或者清空搜索框返回账单。")
                .font(.system(size: 11))
                .foregroundStyle(AppColors.ink3)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 20)
        .glassCard(radius: 22)
    }

    private func shiftMonth(_ by: Int) {
        if let next = Calendar.current.date(byAdding: .month, value: by, to: month) {
            month = next
        }
    }

    private func toggleSelection(for id: UUID) {
        withAnimation(.easeInOut(duration: 0.15)) {
            if selectedIDs.contains(id) {
                selectedIDs.remove(id)
            } else {
                selectedIDs.insert(id)
            }
        }
    }

    private func relativeTitle(for date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "今天" }
        if cal.isDateInYesterday(date) { return "昨天" }
        return Self.relativeFmt.string(from: date)
    }

    private var monthTransactions: [Transaction] {
        store.transactionsInMonth(month)
    }

    private var filteredMonthTransactions: [Transaction] {
        monthTransactions.filter { filterCategory == nil || $0.categoryID == filterCategory }
    }

    private var groupedTransactions: [(date: Date, items: [Transaction])] {
        store.txByDay(in: month).compactMap { group in
            let items = group.items.filter { filterCategory == nil || $0.categoryID == filterCategory }
            return items.isEmpty ? nil : (group.date, items)
        }
    }

    /// Full-text search across all transactions — bypasses month filter,
    /// keeps category filter applied on top so the filter chip stays meaningful.
    private var searchGroupedTransactions: [(date: Date, items: [Transaction])] {
        let q = searchText.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return [] }
        let matched = store.transactions.filter { tx in
            let merchantHit = tx.merchant.localizedCaseInsensitiveContains(q)
            let noteHit = tx.note?.localizedCaseInsensitiveContains(q) ?? false
            let categoryOK = filterCategory == nil || tx.categoryID == filterCategory
            return categoryOK && (merchantHit || noteHit)
        }
        let cal = Calendar(identifier: .gregorian)
        let grouped = Dictionary(grouping: matched) { cal.startOfDay(for: $0.timestamp) }
        return grouped.keys.sorted(by: >).map { key in
            (key, grouped[key]!.sorted { $0.timestamp > $1.timestamp })
        }
    }

    private var expenseCents: Int {
        filteredMonthTransactions
            .filter { $0.kind == .expense }
            .reduce(0) { $0 + $1.amountCents }
    }

    private var incomeCents: Int {
        filteredMonthTransactions
            .filter { $0.kind == .income }
            .reduce(0) { $0 + $1.amountCents }
    }

    private var dailyAverageCents: Int {
        let dayCount = max(1, groupedTransactions.count)
        return expenseCents / dayCount
    }

    private var filterLabel: String {
        filterCategory.map { Category.by($0).name } ?? "全部分类"
    }

    private var selectedScopeText: String {
        filterCategory == nil ? "全部分类" : "筛选中 · \(filterLabel)"
    }

    private var topCategory: Category? {
        categoryData.first?.0
    }

    private var categoryData: [(Category, Int)] {
        var buckets: [Category.Slug: Int] = [:]
        for tx in filteredMonthTransactions where tx.kind == .expense {
            buckets[tx.categoryID, default: 0] += tx.amountCents
        }
        return Category.all.compactMap { category in
            guard let cents = buckets[category.id], cents > 0 else { return nil }
            return (category, cents)
        }
        .sorted { $0.1 > $1.1 }
    }

    private var previousMonthExpenseCents: Int {
        guard let previous = Calendar.current.date(byAdding: .month, value: -1, to: month) else { return 0 }
        return store.transactionsInMonth(previous)
            .filter { filterCategory == nil || $0.categoryID == filterCategory }
            .filter { $0.kind == .expense }
            .reduce(0) { $0 + $1.amountCents }
    }

    private var comparisonText: String {
        guard previousMonthExpenseCents > 0 else { return "上个月暂无可比较数据" }
        let pct = (Double(expenseCents) - Double(previousMonthExpenseCents)) / Double(previousMonthExpenseCents) * 100
        if pct == 0 { return "较上月基本持平" }
        return "较上月\(pct > 0 ? "上升" : "下降") \(String(format: "%.1f%%", abs(pct)))"
    }

    private var comparisonTone: Color {
        guard previousMonthExpenseCents > 0 else { return AppColors.ink3 }
        if expenseCents == previousMonthExpenseCents { return AppColors.ink2 }
        return expenseCents > previousMonthExpenseCents ? AppColors.expenseRed : AppColors.incomeGreen
    }

    private var dayBars: [Int] {
        let sums = Array(groupedTransactions.prefix(7).reversed()).map { group in
            group.items.filter { $0.kind == .expense }.reduce(0) { $0 + $1.amountCents }
        }
        return sums.isEmpty ? [0, 0, 0, 0, 0, 0, 0] : sums
    }

    private var dayBarLabels: [String] {
        let formatter = Self.barFmt
        let labels = Array(groupedTransactions.prefix(7).reversed()).map { formatter.string(from: $0.date) }
        return labels.isEmpty ? ["", "", "", "", "", "", ""] : labels
    }

    private var maxDayBarValue: Int {
        max(dayBars.max() ?? 0, 1)
    }

    private static let monthFmt: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy 年 M 月"
        return f
    }()

    private static let dayFmt: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M 月 d 日 · EEEE"
        return f
    }()

    private static let relativeFmt: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M 月 d 日"
        return f
    }()

    private static let barFmt: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "d"
        return f
    }()
}

private struct FilterSheet: View {
    @Binding var selected: Category.Slug?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AuroraBackground(palette: .bills)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("按分类筛选")
                            .font(AppFont.h2)
                            .foregroundStyle(AppColors.ink)
                        Text(selected == nil ? "当前显示全部分类" : "当前筛选：\(Category.by(selected!).name)")
                            .font(.system(size: 11))
                            .foregroundStyle(AppColors.ink3)
                    }
                    .padding(.top, 4)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                        chip(nil, label: "全部")
                        ForEach(Category.all, id: \.id) { category in
                            chip(category.id, label: category.name, emoji: category.emoji)
                        }
                    }

                    Button { dismiss() } label: {
                        Text("完成筛选")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [AppColors.brandStart, AppColors.brandEnd],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 6)
                }
                .padding(20)
            }
        }
    }

    private func chip(_ slug: Category.Slug?, label: String, emoji: String = "✨") -> some View {
        let isSelected = selected == slug

        return Button {
            selected = slug
        } label: {
            VStack(spacing: 6) {
                Text(slug == nil ? "◌" : emoji)
                    .font(.system(size: 17))
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(isSelected ? .white : AppColors.ink)
            .frame(maxWidth: .infinity, minHeight: 78)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        isSelected
                            ? AnyShapeStyle(
                                LinearGradient(
                                    colors: [AppColors.brandStart, AppColors.brandEnd],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            : AnyShapeStyle(Color.white.opacity(0.40))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(isSelected ? Color.white.opacity(0.28) : AppColors.glassBorderSoft, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

/// Apply `.searchable` only when `enabled`. Hides the search field during
/// multi-select so the nav area stays clean and predictable.
private struct ConditionalSearchable: ViewModifier {
    @Binding var text: String
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content.searchable(text: $text, prompt: "搜索商户 / 备注")
        } else {
            content
        }
    }
}

#Preview {
    ZStack {
        AuroraBackground(palette: .bills)
        BillsView().environment(AppStore())
    }
}
