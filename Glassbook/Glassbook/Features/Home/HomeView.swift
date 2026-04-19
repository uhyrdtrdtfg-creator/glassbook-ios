import SwiftUI

/// Spec §4.1 · 首页 · 本月总览
struct HomeView: View {
    @Environment(AppStore.self) private var store
    @State private var showReceiptScan = false
    @State private var showSmartImport = false
    @State private var pendingEdit: PendingReceipt?

    private struct PendingReceipt: Identifiable {
        let id = UUID()
        let result: ReceiptOCRService.Result
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                greeting
                heroCard
                quickRow
                sectionHeader
                recentList
                Spacer().frame(height: 100)
            }
            .padding(.horizontal, 18)
            .padding(.top, 4)
        }
        .scrollIndicators(.hidden)
        .safeAreaPadding(.top, 8)
        .sheet(isPresented: $showReceiptScan) {
            ReceiptScanSheet(
                onConfirm: { result in
                    // Close the scan sheet, then hand off to the editable form.
                    showReceiptScan = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        pendingEdit = PendingReceipt(result: result)
                    }
                },
                onCancel: { showReceiptScan = false }
            )
            .presentationDetents([.large])
        }
        .sheet(item: $pendingEdit) { item in
            AddTransactionView(prefill: item.result)
                .environment(store)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $showSmartImport) {
            SmartImportFlow(isPresented: $showSmartImport)
        }
    }

    // MARK: - Parts

    private var greeting: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Self.greetingText())
                    .font(.system(size: 13))
                    .foregroundStyle(AppColors.ink2)
                Text(store.userName)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(AppColors.ink)
            }
            Spacer()
            scanMenu
            avatar
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 2)
    }

    /// Discoverable OCR / import entry point.
    /// One tap reveals a two-option menu: 扫描收据 (single receipt) or 导入账单截图 (batch).
    private var scanMenu: some View {
        Menu {
            Button { showReceiptScan = true } label: {
                Label("扫描收据", systemImage: "doc.text.viewfinder")
            }
            Button { showSmartImport = true } label: {
                Label("导入账单截图", systemImage: "viewfinder")
            }
        } label: {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(AppColors.ink)
                .frame(width: 36, height: 36)
                .background {
                    Circle().fill(.ultraThinMaterial)
                        .overlay(Circle().fill(Color.white.opacity(0.18)))
                }
                .overlay(Circle().strokeBorder(AppColors.glassBorder, lineWidth: 1))
                .shadow(color: Color(hex: 0x503C78).opacity(0.1), radius: 10, y: 4)
        }
        .accessibilityLabel("OCR 识别")
    }

    private var avatar: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [AppColors.auroraPink, AppColors.auroraPurple],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
            Text(store.userInitial)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
        }
        .frame(width: 36, height: 36)
    }


    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("本月支出")
                .eyebrowStyle()
                .padding(.bottom, 10)

            HStack(alignment: .top, spacing: 2) {
                Text("¥").font(.system(size: 18, weight: .light))
                    .foregroundStyle(AppColors.ink2)
                    .padding(.top, 4)
                Text(yuanPart)
                    .font(.system(size: 42, weight: .ultraLight).monospacedDigit())
                    .foregroundStyle(AppColors.ink)
                Text(".\(centsPart)")
                    .font(.system(size: 20).monospacedDigit())
                    .foregroundStyle(AppColors.ink3)
                    .padding(.top, 4)
            }
            .lineLimit(1)

            Divider()
                .background(AppColors.glassDivider)
                .padding(.top, 14)
                .padding(.bottom, 12)

            HStack(alignment: .top) {
                heroSub(label: "预算剩余",
                        value: Money.yuan(store.budgetRemainingCents, showDecimals: false),
                        color: store.budgetRemainingCents < 0 ? AppColors.expenseRed : AppColors.incomeGreen)
                Spacer()
                heroSub(label: "较上月", value: monthOverMonth,
                        color: store.monthOverMonthChangePct > 0 ? AppColors.expenseRed : AppColors.incomeGreen)
                Spacer()
                heroSub(label: "日均",
                        value: Money.yuan(store.thisMonthDailyAverageCents, showDecimals: false),
                        color: AppColors.ink)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private func heroSub(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).eyebrowStyle()
            Text(value)
                .font(.system(size: 14, weight: .medium).monospacedDigit())
                .foregroundStyle(color)
        }
    }

    private var quickRow: some View {
        HStack(spacing: 8) {
            ForEach([Category.by(.food), Category.by(.transport),
                     Category.by(.shopping), Category.by(.other)], id: \.id) { cat in
                VStack(spacing: 6) {
                    CategoryIconTile(category: cat)
                    Text(cat.name)
                        .font(.system(size: 10))
                        .foregroundStyle(AppColors.ink2)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .glassCard(radius: 18)
            }
        }
    }

    private var sectionHeader: some View {
        HStack {
            Text("最近交易").font(.system(size: 13, weight: .medium))
            Spacer()
            Text("查看全部 ›").font(.system(size: 11))
                .foregroundStyle(AppColors.ink3)
        }
        .padding(.horizontal, 4)
        .padding(.top, 6)
    }

    private var recentList: some View {
        VStack(spacing: 0) {
            let recent = Array(store.transactionsInMonth(Date()).prefix(3))
            ForEach(Array(recent.enumerated()), id: \.element.id) { idx, tx in
                if idx > 0 { Divider().background(AppColors.glassDivider).padding(.horizontal, 12) }
                TransactionRow(tx: tx)
            }
            if recent.isEmpty {
                Text("还没有记账").font(.system(size: 12))
                    .foregroundStyle(AppColors.ink3).padding()
            }
        }
        .padding(8)
        .glassCard()
    }

    // MARK: - Formatters

    private var yuanPart: String {
        let yuan = store.thisMonthExpenseCents / 100
        let fmt = NumberFormatter(); fmt.numberStyle = .decimal
        return fmt.string(from: NSNumber(value: yuan)) ?? "\(yuan)"
    }
    private var centsPart: String {
        String(format: "%02d", store.thisMonthExpenseCents % 100)
    }
    private var monthOverMonth: String {
        let pct = store.monthOverMonthChangePct * 100
        let arrow = pct > 0 ? "↑" : (pct < 0 ? "↓" : "—")
        return "\(arrow) \(String(format: "%.1f%%", abs(pct)))"
    }

    static func greetingText(now: Date = Date()) -> String {
        let h = Calendar.current.component(.hour, from: now)
        switch h {
        case 0..<6:    return "凌晨好"
        case 6..<11:   return "早上好"
        case 11..<13:  return "中午好"
        case 13..<18:  return "下午好"
        case 18..<22:  return "晚上好"
        default:       return "夜深了"
        }
    }
}

#Preview {
    ZStack {
        AuroraBackground(palette: .home)
        HomeView().environment(AppStore())
    }
}
