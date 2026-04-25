import SwiftUI

/// Spec §4.6 · 个人中心 — entry point for all V1.1 / V1.2 Hero features.
struct ProfileView: View {
    @Environment(AppStore.self) private var store
    @Environment(AppLock.self) private var lock
    @Environment(AIEngineStore.self) private var aiEngines
    @Environment(WebhookStore.self) private var webhooks

    /// Time source — defaulted so existing call sites compile unchanged; tests pin it for determinism.
    private let now: () -> Date

    init(now: @escaping () -> Date = { .now }) {
        self.now = now
    }

    @State private var showBudget = false
    @State private var showSmartImport = false
    @State private var showAccounts = false
    @State private var showSubscriptions = false
    @State private var showGoals = false
    @State private var showAnnualWrap = false
    @State private var showInsights = false
    @State private var showAIEngine = false
    @State private var showWebhooks = false
    @State private var showAutomation = false
    @State private var showSunkCost = false
    @State private var showFamily = false
    @State private var showAdvisor = false
    @State private var showExport = false
    @State private var showDataManagement = false
    @State private var showLockSettings = false
    @State private var showAbout = false
    @State private var showWidgetHelp = false
    @State private var showEditProfile = false

    private let overviewColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                profileHero
                overviewGrid
                spotlightStrip
                menuGroup(title: "Hero 功能", subtitle: "围绕记账之外的目标、洞察和年度体验") { heroRows }
                menuGroup(title: "家庭与资金", subtitle: "账户、预算和家庭账本集中管理") { financeRows }
                menuGroup(title: "数据与自动化", subtitle: "导入、导出、自动化和系统接入") { dataRows }
                menuGroup(title: "设置与关于", subtitle: "安全、组件和应用信息") { settingsRows }
                Spacer().frame(height: 110)
            }
            .padding(.horizontal, 18)
            .padding(.top, 6)
        }
        .scrollIndicators(.hidden)
        .safeAreaPadding(.top, 8)
        .sheet(isPresented: $showBudget) { sheet { BudgetView() } }
        .sheet(isPresented: $showAccounts) { sheet { AccountsView() } }
        .sheet(isPresented: $showSubscriptions) { sheet { SubscriptionsView() } }
        .sheet(isPresented: $showGoals) { sheet { GoalsView() } }
        .sheet(isPresented: $showInsights) { sheet { InsightsView(isStandalone: true) } }
        .sheet(isPresented: $showAIEngine) { AIEngineSettingsView() }
        .sheet(isPresented: $showWebhooks) { WebhookSettingsView() }
        .sheet(isPresented: $showAutomation) { AutomationSettingsView() }
        .sheet(isPresented: $showSunkCost) { sheet { SunkCostView() } }
        .sheet(isPresented: $showFamily) { sheet { FamilyBookView() } }
        .fullScreenCover(isPresented: $showAdvisor) {
            AdvisorView().environment(store)
        }
        .sheet(isPresented: $showExport) { sheet { InvoiceExportView() } }
        .sheet(isPresented: $showDataManagement) { sheet { DataManagementView() } }
        .sheet(isPresented: $showLockSettings) { sheet { LockSettingsView() }.environment(lock) }
        .sheet(isPresented: $showAbout) { AboutView() }
        .sheet(isPresented: $showWidgetHelp) { WidgetHelpView() }
        .sheet(isPresented: $showEditProfile) { sheet { EditProfileSheet() } }
        .fullScreenCover(isPresented: $showSmartImport) {
            SmartImportFlow(isPresented: $showSmartImport)
        }
        .fullScreenCover(isPresented: $showAnnualWrap) {
            AnnualWrapView()
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        return "v\(version)"
    }

    private var lockStatus: String {
        guard lock.faceIDEnabled else { return "已关闭" }
        switch lock.gracePeriodSeconds {
        case 0:    return "每次刷脸"
        case -1:   return "信任设备"
        case 60:   return "1 分钟"
        case 300:  return "5 分钟"
        case 1800: return "30 分钟"
        case 7200: return "2 小时"
        default:   return "\(max(1, lock.gracePeriodSeconds / 60)) 分钟"
        }
    }

    private var streakDisplay: String {
        let count = store.dailyStreak
        return count == 0 ? "未开始" : "\(count) 天"
    }

    private var autoImportSummary: String {
        store.autoImportedCountThisMonth == 0 ? "本月暂无智能导入" : "本月 \(store.autoImportedCountThisMonth) 笔自动导入"
    }

    @ViewBuilder
    private func sheet<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack {
            AuroraBackground(palette: .profile)
            content()
        }
        .environment(store)
    }

    private var profileHero: some View {
        Button { showEditProfile = true } label: {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [AppColors.auroraPink, AppColors.brandEnd],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        Circle().strokeBorder(Color.white.opacity(0.34), lineWidth: 1)
                        Text(store.userInitial)
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 68, height: 68)
                    .shadow(color: AppColors.surfaceShadow.opacity(0.55), radius: 12, x: 0, y: 8)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text(store.userName)
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(AppColors.ink)
                            if store.isPro {
                                Text("PRO")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Capsule().fill(LinearGradient.brand()))
                            }
                        }

                        Text(store.familyGroupName)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppColors.ink2)

                        Text("点这里编辑昵称、家庭名和个人资料")
                            .font(.system(size: 11))
                            .foregroundStyle(AppColors.ink3)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppColors.ink4)
                }

                HStack(spacing: 8) {
                    heroPill(icon: "person.2.fill", text: "\(store.familyMembers.count) 位家人")
                    heroPill(icon: "sparkles", text: autoImportSummary)
                    heroPill(icon: "flame.fill", text: streakDisplay)
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
                                    colors: [AppColors.brandEnd.opacity(0.28), AppColors.brandStart.opacity(0.18), .clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 190, height: 190)
                            .offset(x: 56, y: -86)
                    }
            }
        }
        .buttonStyle(.plain)
        .glassCard(radius: Radius.xl)
    }

    private func heroPill(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(text)
                .font(.system(size: 10, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .foregroundStyle(AppColors.ink2)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Capsule().fill(Color.white.opacity(0.30)))
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.34), lineWidth: 1))
    }

    private var overviewGrid: some View {
        LazyVGrid(columns: overviewColumns, spacing: 10) {
            overviewCard(
                title: "净资产",
                value: Money.yuan(store.netWorthCents, showDecimals: false),
                subtitle: "\(store.accounts.count) 个账户",
                gradient: [AppColors.brandStart, AppColors.brandEnd]
            )
            overviewCard(
                title: "订阅支出",
                value: Money.yuan(store.monthlySubscriptionTotalCents, showDecimals: false),
                subtitle: "每月固定开支",
                gradient: [AppColors.auroraAmber, AppColors.brandStart]
            )
            overviewCard(
                title: "累计记账",
                value: "\(store.transactions.count) 笔",
                subtitle: "连续打卡 \(streakDisplay)",
                gradient: [AppColors.brandEnd, AppColors.brandAccent]
            )
            overviewCard(
                title: "储蓄目标",
                value: "\(store.goals.count) 个",
                subtitle: "已存 \(Money.yuan(store.totalSavedCents, showDecimals: false))",
                gradient: [AppColors.auroraPurple, AppColors.auroraPink]
            )
        }
    }

    private func overviewCard(title: String, value: String, subtitle: String, gradient: [Color]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(LinearGradient.gradient(gradient))
                .frame(width: 38, height: 38)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
                )

            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppColors.ink3)
            Text(value)
                .font(.system(size: 19, weight: .semibold).monospacedDigit())
                .foregroundStyle(AppColors.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(subtitle)
                .font(.system(size: 11))
                .foregroundStyle(AppColors.ink3)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 142, alignment: .leading)
        .padding(16)
        .glassCard(radius: 20)
    }

    private var spotlightStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                spotlightCard(
                    title: "储蓄目标",
                    subtitle: "\(store.goals.count) 个目标 · 已存 \(Money.yuan(store.totalSavedCents, showDecimals: false))",
                    icon: "target",
                    gradient: [AppColors.brandStart, AppColors.auroraAmber]
                ) {
                    showGoals = true
                }

                spotlightCard(
                    title: "智能识别",
                    subtitle: "支付宝、微信、招行账单一键导入",
                    icon: "sparkles.rectangle.stack.fill",
                    gradient: [AppColors.brandEnd, AppColors.brandAccent]
                ) {
                    showSmartImport = true
                }

                spotlightCard(
                    title: "年度回顾",
                    subtitle: "\(Calendar.current.component(.year, from: now())) 年消费故事已准备好",
                    icon: "sparkles",
                    gradient: [AppColors.auroraPurple, AppColors.brandStart]
                ) {
                    showAnnualWrap = true
                }

                spotlightCard(
                    title: "AI 财务顾问",
                    subtitle: "用自然语言直接问账和预算",
                    icon: "bubble.left.and.bubble.right.fill",
                    gradient: [AppColors.auroraAmber, AppColors.brandEnd]
                ) {
                    showAdvisor = true
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private func spotlightCard(
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
            .frame(width: 228)
            .frame(minHeight: 138, alignment: .leading)
            .padding(16)
            .glassCard(radius: 20)
        }
        .buttonStyle(.plain)
    }

    private var heroRows: [MenuRow] {
        [
            .init(icon: "target", label: "储蓄目标", value: "\(store.goals.count) 个 · 累计 \(Money.yuan(store.totalSavedCents, showDecimals: false))", action: { showGoals = true }),
            .init(icon: "repeat", label: "订阅管理", value: "\(Money.yuan(store.monthlySubscriptionTotalCents, showDecimals: false))/月", action: { showSubscriptions = true }),
            .init(icon: "sparkles", label: "\(Calendar.current.component(.year, from: now())) 年度回顾", value: "Glassbook Wrapped", action: { showAnnualWrap = true }),
            .init(icon: "lightbulb", label: "消费洞察", value: "AI 每日更新", action: { showInsights = true }),
            .init(icon: "bubble.left.and.bubble.right", label: "问账 · AI 财务顾问", value: "多轮对话", action: { showAdvisor = true }),
            .init(icon: "exclamationmark.arrow.triangle.2.circlepath", label: "沉没成本分析", value: "闲置订阅 + 吃灰硬件", action: { showSunkCost = true })
        ]
    }

    private var financeRows: [MenuRow] {
        [
            .init(icon: "house", label: "家庭账本 (\(store.familyGroupName))", value: "\(store.familyMembers.count) 人 · \(Money.yuan(store.familyTotalThisMonthCents, showDecimals: false))", action: { showFamily = true }),
            .init(icon: "creditcard", label: "账户与净资产", value: "\(store.accounts.count) 个账户", action: { showAccounts = true }),
            .init(icon: "target", label: "预算设置", value: Money.yuan(store.budget.monthlyTotalCents, showDecimals: false), action: { showBudget = true })
        ]
    }

    private var dataRows: [MenuRow] {
        [
            .init(icon: "viewfinder", label: "智能识别", value: "支付宝 · 微信 · 招行", action: { showSmartImport = true }),
            .init(icon: "arrow.down.doc", label: "数据导出", value: "PDF · 发票", action: { showExport = true }),
            .init(icon: "brain", label: "AI 引擎 · BYO LLM", value: aiEngines.selected.displayName, action: { showAIEngine = true }),
            .init(icon: "bell.and.waves.left.and.right", label: "Webhook · 设备直出", value: "\(webhooks.endpoints.count) 端点", action: { showWebhooks = true }),
            .init(icon: "bolt.horizontal", label: "自动化记账", value: "截屏 · 快捷指令", action: { showAutomation = true }),
            .init(icon: "externaldrive.badge.minus", label: "清除数据 / 重置演示", value: "\(store.transactions.count) 笔交易", action: { showDataManagement = true })
        ]
    }

    private var settingsRows: [MenuRow] {
        [
            .init(icon: "lock.shield", label: "Face ID 解锁", value: lockStatus, action: { showLockSettings = true }),
            .init(icon: "rectangle.on.rectangle", label: "桌面小组件", value: "怎么添加", action: { showWidgetHelp = true }),
            .init(icon: "info.circle", label: "关于 Glassbook", value: appVersion, action: { showAbout = true })
        ]
    }

    struct MenuRow: Identifiable {
        let id = UUID()
        let icon: String
        let label: String
        let value: String
        var action: (() -> Void)? = nil
    }

    private func menuGroup(title: String, subtitle: String, rows: () -> [MenuRow]) -> some View {
        let items = rows()

        return VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppColors.ink)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(AppColors.ink3)
            }
            .padding(.horizontal, 4)

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { idx, row in
                    if idx > 0 {
                        Divider()
                            .background(AppColors.glassDivider)
                            .padding(.horizontal, 10)
                    }
                    Button {
                        row.action?()
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(LinearGradient.gradient(iconGradient(for: row.icon)))
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
                                Image(systemName: row.icon)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                            .frame(width: 36, height: 36)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(row.label)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(AppColors.ink)
                                Text(row.value)
                                    .font(.system(size: 11))
                                    .foregroundStyle(AppColors.ink3)
                                    .lineLimit(1)
                            }

                            Spacer(minLength: 8)

                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(AppColors.ink4)
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .glassCard(radius: 22)
        }
    }

    private func iconGradient(for icon: String) -> [Color] {
        switch icon {
        case "target":
            return [AppColors.brandStart, AppColors.auroraAmber]
        case "repeat":
            return [AppColors.auroraAmber, AppColors.brandStart]
        case "sparkles", "lightbulb":
            return [AppColors.auroraPurple, AppColors.brandStart]
        case "bubble.left.and.bubble.right", "bubble.left.and.bubble.right.fill":
            return [AppColors.brandEnd, AppColors.brandAccent]
        case "house":
            return [AppColors.brandAccent, AppColors.brandEnd]
        case "creditcard":
            return [AppColors.brandEnd, AppColors.auroraPurple]
        case "viewfinder":
            return [AppColors.brandEnd, AppColors.brandAccent]
        case "arrow.down.doc", "doc.badge.arrow.up":
            return [AppColors.auroraAmber, AppColors.brandEnd]
        case "brain":
            return [AppColors.auroraPurple, AppColors.brandEnd]
        case "bell.and.waves.left.and.right", "bolt.horizontal":
            return [AppColors.brandStart, AppColors.brandEnd]
        case "externaldrive.badge.minus":
            return [AppColors.expenseRed, AppColors.auroraPink]
        case "lock.shield":
            return [AppColors.ink2, AppColors.ink]
        case "rectangle.on.rectangle":
            return [AppColors.brandAccent, AppColors.auroraAmber]
        case "info.circle":
            return [AppColors.brandEnd, AppColors.auroraPurple]
        case "exclamationmark.arrow.triangle.2.circlepath":
            return [AppColors.expenseRed, AppColors.auroraAmber]
        default:
            return [AppColors.brandStart, AppColors.brandEnd]
        }
    }
}

#Preview {
    let lock = AppLock()
    lock.skipAuth = true
    return ZStack {
        AuroraBackground(palette: .profile)
        ProfileView().environment(AppStore()).environment(lock)
    }
}
