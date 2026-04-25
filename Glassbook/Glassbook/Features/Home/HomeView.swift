import SwiftUI

/// Spec §4.1 · 首页 · 本月总览
struct HomeView: View {
    @Environment(AppStore.self) private var store
    @State private var showReceiptScan = false
    @State private var showSmartImport = false
    @State private var pendingEdit: PendingReceipt?

    private let twoColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    private struct PendingReceipt: Identifiable {
        let id = UUID()
        let result: ReceiptOCRService.Result
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                greeting
                heroCard
                quickActions
                spotlightSection
                recentSectionHeader
                recentList
                Spacer().frame(height: 110)
            }
            .padding(.horizontal, 18)
            .padding(.top, 6)
        }
        .scrollIndicators(.hidden)
        .safeAreaPadding(.top, 8)
        .sheet(isPresented: $showReceiptScan) {
            ReceiptScanSheet(
                onConfirm: { result in
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
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(Self.greetingText())
                    .font(.system(size: 13))
                    .foregroundStyle(AppColors.ink2)

                HStack(spacing: 8) {
                    Text(store.userName)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(AppColors.ink)
                    monthBadge
                }

                Text("今天是 \(Self.dateFmt.string(from: Date()))")
                    .font(.system(size: 11))
                    .foregroundStyle(AppColors.ink3)
            }

            Spacer(minLength: 12)
            scanMenu
            avatar
        }
        .padding(.horizontal, 4)
    }

    private var monthBadge: some View {
        Text(Self.monthFmt.string(from: Date()))
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(AppColors.ink2)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(Color.white.opacity(0.42)))
            .overlay(Capsule().strokeBorder(AppColors.glassBorderSoft, lineWidth: 1))
    }

    /// Discoverable OCR / import entry point.
    private var scanMenu: some View {
        Menu {
            Button { showReceiptScan = true } label: {
                Label("扫描收据", systemImage: "doc.text.viewfinder")
            }
            Button { showSmartImport = true } label: {
                Label("导入账单截图", systemImage: "sparkles.rectangle.stack")
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 13, weight: .semibold))
                Text("识别")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(AppColors.ink)
            .padding(.horizontal, 12)
            .frame(height: 38)
            .background(Capsule().fill(Color.white.opacity(0.42)))
            .overlay(Capsule().strokeBorder(AppColors.glassBorderSoft, lineWidth: 1))
            .shadow(color: AppColors.surfaceShadow.opacity(0.55), radius: 10, x: 0, y: 6)
        }
        .accessibilityLabel("OCR 识别")
    }

    private var avatar: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [AppColors.auroraPink, AppColors.auroraPurple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Circle().strokeBorder(Color.white.opacity(0.42), lineWidth: 1)
            Text(store.userInitial)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: 40, height: 40)
        .shadow(color: AppColors.surfaceShadow.opacity(0.65), radius: 12, x: 0, y: 6)
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("本月支出").eyebrowStyle()

                    HStack(alignment: .top, spacing: 4) {
                        Text("¥")
                            .font(.system(size: 18, weight: .light))
                            .foregroundStyle(AppColors.ink2)
                            .padding(.top, 6)
                        Text(yuanPart)
                            .font(.system(size: 42, weight: .ultraLight).monospacedDigit())
                            .foregroundStyle(AppColors.ink)
                            .lineLimit(1)
                        Text(".\(centsPart)")
                            .font(.system(size: 20).monospacedDigit())
                            .foregroundStyle(AppColors.ink3)
                            .padding(.top, 6)
                    }

                    monthOverMonthLine
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 8) {
                    Text(budgetUsageText)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(budgetToneColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(budgetToneColor.opacity(0.14)))

                    Text(trendText)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppColors.ink2)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("预算进度")
                        .font(.system(size: 11, weight: .medium))
                    Spacer()
                    Text("\(Int(store.budgetUsedPercent * 100))%")
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                }
                .foregroundStyle(AppColors.ink2)

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.24))
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [AppColors.brandStart, AppColors.brandEnd, AppColors.brandAccent],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(24, proxy.size.width * budgetProgress))
                    }
                }
                .frame(height: 10)
            }

            HStack(spacing: 10) {
                metricPanel(
                    label: "预算剩余",
                    value: Money.yuan(store.budgetRemainingCents, showDecimals: false),
                    accent: store.budgetRemainingCents < 0 ? AppColors.expenseRed : AppColors.incomeGreen
                )
                metricPanel(
                    label: "日均支出",
                    value: Money.yuan(store.thisMonthDailyAverageCents, showDecimals: false),
                    accent: AppColors.ink
                )
                metricPanel(
                    label: "记账笔数",
                    value: "\(store.thisMonthTransactionCount) 笔",
                    accent: AppColors.ink
                )
            }

            HStack(spacing: 8) {
                footerPill(icon: "sparkles", text: importedSummary)
                footerPill(icon: "wallet.pass", text: "净资产 \(Money.yuan(store.netWorthCents, showDecimals: false))")
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
                                colors: [
                                    AppColors.brandEnd.opacity(0.30),
                                    AppColors.brandStart.opacity(0.18),
                                    .clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 170, height: 170)
                        .offset(x: 46, y: -78)
                        .blur(radius: 4)
                }
                .overlay(alignment: .bottomLeading) {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    AppColors.auroraAmber.opacity(0.20),
                                    AppColors.auroraPink.opacity(0.14),
                                    .clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 140, height: 140)
                        .offset(x: -34, y: 58)
                }
                .clipShape(RoundedRectangle(cornerRadius: Radius.xl, style: .continuous))
        }
        .glassCard(radius: Radius.xl)
    }

    private func metricPanel(label: String, value: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(AppColors.ink3)
            Text(value)
                .font(.system(size: 15, weight: .semibold).monospacedDigit())
                .foregroundStyle(accent)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.28))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.36), lineWidth: 1)
                )
        )
    }

    private func footerPill(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(text)
                .font(.system(size: 10, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .foregroundStyle(AppColors.ink2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Capsule().fill(Color.white.opacity(0.30)))
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.36), lineWidth: 1))
    }

    private var quickActions: some View {
        LazyVGrid(columns: twoColumns, spacing: 10) {
            actionCard(
                title: "扫描收据",
                subtitle: "拍一张小票，自动补全金额与商户",
                icon: "doc.text.viewfinder",
                gradient: [AppColors.auroraAmber, AppColors.brandStart]
            ) {
                showReceiptScan = true
            }

            actionCard(
                title: "导入截图",
                subtitle: "支付宝、微信、招行账单一键识别",
                icon: "sparkles.rectangle.stack.fill",
                gradient: [AppColors.brandEnd, AppColors.brandAccent]
            ) {
                showSmartImport = true
            }
        }
    }

    private func actionCard(
        title: String,
        subtitle: String,
        icon: String,
        gradient: [Color],
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(LinearGradient.gradient(gradient))
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppColors.ink)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(AppColors.ink3)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 134, alignment: .leading)
            .padding(16)
            .glassCard(radius: 20)
        }
        .buttonStyle(.plain)
    }

    private var spotlightSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("支出热点")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColors.ink)
                Spacer()
                Text("本月前 4 类")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppColors.ink3)
            }
            .padding(.horizontal, 4)

            if topCategories.isEmpty {
                Text("还没有足够的交易记录来生成热点分类")
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.ink3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .glassCard(radius: 20)
            } else {
                LazyVGrid(columns: twoColumns, spacing: 10) {
                    ForEach(topCategories, id: \.0.id) { item in
                        categorySpotlight(item.0, cents: item.1)
                    }
                }
            }
        }
    }

    private func categorySpotlight(_ category: Category, cents: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                CategoryIconTile(category: category, size: 36)
                Spacer(minLength: 8)
                Text(categoryShare(cents))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppColors.ink2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.white.opacity(0.34)))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(category.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppColors.ink)
                Text(Money.yuan(cents, showDecimals: false))
                    .font(.system(size: 18, weight: .semibold).monospacedDigit())
                    .foregroundStyle(AppColors.ink)
                    .lineLimit(1)
                Text("占本月支出的 \(categoryShare(cents))")
                    .font(.system(size: 11))
                    .foregroundStyle(AppColors.ink3)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
        .padding(16)
        .glassCard(radius: 20)
    }

    private var recentSectionHeader: some View {
        HStack {
            Text("最近交易")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppColors.ink)
            Spacer()
            Text("本月 \(store.thisMonthTransactionCount) 笔")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppColors.ink2)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.white.opacity(0.34)))
        }
        .padding(.horizontal, 4)
        .padding(.top, 2)
    }

    private var recentList: some View {
        VStack(spacing: 0) {
            let recent = Array(store.transactionsInMonth(Date()).prefix(4))
            ForEach(Array(recent.enumerated()), id: \.element.id) { idx, tx in
                if idx > 0 {
                    Divider()
                        .background(AppColors.glassDivider)
                        .padding(.horizontal, 12)
                }
                TransactionRow(tx: tx)
            }

            if recent.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(AppColors.ink3)
                    Text("还没有记账")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppColors.ink2)
                    Text("点底部加号开始记录第一笔")
                        .font(.system(size: 11))
                        .foregroundStyle(AppColors.ink3)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            }
        }
        .padding(8)
        .glassCard()
    }

    // MARK: - Derived

    private var topCategories: [(Category, Int)] {
        Array(store.expensesByCategory(in: Date()).prefix(4))
    }

    private var budgetProgress: CGFloat {
        CGFloat(min(max(store.budgetUsedPercent, 0), 1))
    }

    private var budgetToneColor: Color {
        if store.budgetRemainingCents < 0 { return AppColors.expenseRed }
        if store.budgetUsedPercent >= 0.85 { return AppColors.auroraAmber }
        return AppColors.incomeGreen
    }

    private var budgetUsageText: String {
        if store.budgetRemainingCents < 0 {
            return "已超 \(Money.yuan(-store.budgetRemainingCents, showDecimals: false))"
        }
        return "\(Int(store.budgetUsedPercent * 100))% 已用"
    }

    private var importedSummary: String {
        store.autoImportedCountThisMonth == 0 ? "暂无 AI 导入" : "\(store.autoImportedCountThisMonth) 笔 AI 导入"
    }

    private var trendText: String {
        let pct = store.monthOverMonthChangePct * 100
        if store.lastMonthExpenseCents == 0 { return "本月首次生成趋势" }
        if pct == 0 { return "较上月基本持平" }
        let direction = pct > 0 ? "较上月上升" : "较上月下降"
        return "\(direction) \(String(format: "%.1f%%", abs(pct)))"
    }

    private var monthOverMonthPercent: Double? {
        guard store.lastMonthExpenseCents > 0 else { return nil }
        return (Double(store.thisMonthExpenseCents) - Double(store.lastMonthExpenseCents))
            / Double(store.lastMonthExpenseCents) * 100
    }

    private var previousMonthLabel: String {
        let cal = Calendar(identifier: .gregorian)
        let prev = cal.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        return Self.prevMonthFmt.string(from: prev)
    }

    @ViewBuilder
    private var monthOverMonthLine: some View {
        if store.lastMonthExpenseCents == 0 {
            if store.thisMonthExpenseCents > 0 {
                Text("本月首次支出")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppColors.ink3)
            }
        } else if let pct = monthOverMonthPercent {
            let rising = pct > 0
            let color: Color = rising ? AppColors.expenseRed : AppColors.incomeGreen
            let sign = rising ? "+" : "-"
            let emoji: String = abs(pct) > 50 ? (rising ? "📈 " : "📉 ") : ""
            Text("\(emoji)vs. \(previousMonthLabel):\(sign)\(String(format: "%.0f%%", abs(pct)))")
                .font(.system(size: 11, weight: .semibold).monospacedDigit())
                .foregroundStyle(color)
        }
    }

    private func categoryShare(_ cents: Int) -> String {
        guard store.thisMonthExpenseCents > 0 else { return "0%" }
        let ratio = Double(cents) / Double(store.thisMonthExpenseCents)
        return "\(Int(round(ratio * 100)))%"
    }

    // MARK: - Formatters

    private var yuanPart: String {
        let yuan = store.thisMonthExpenseCents / 100
        let fmt = NumberFormatter()
        fmt.numberStyle = .decimal
        return fmt.string(from: NSNumber(value: yuan)) ?? "\(yuan)"
    }

    private var centsPart: String {
        String(format: "%02d", store.thisMonthExpenseCents % 100)
    }

    private static let monthFmt: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M 月总览"
        return f
    }()

    private static let prevMonthFmt: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale.autoupdatingCurrent
        f.setLocalizedDateFormatFromTemplate("MMM")
        return f
    }()

    private static let dateFmt: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M 月 d 日 EEEE"
        return f
    }()

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
