import SwiftUI

/// Spec §4.6 · 个人中心 — entry point for all V1.1 / V1.2 Hero features.
struct ProfileView: View {
    @Environment(AppStore.self) private var store
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

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                profileCard
                statRow

                menuGroup(title: "Hero 功能", rows: [
                    .init(icon: "target", label: "储蓄目标",
                          value: "\(store.goals.count) 个 · 累计 \(Money.yuan(store.totalSavedCents, showDecimals: false))",
                          action: { showGoals = true }),
                    .init(icon: "repeat", label: "订阅管理",
                          value: "¥\(store.monthlySubscriptionTotalCents / 100)/月",
                          action: { showSubscriptions = true }),
                    .init(icon: "sparkles", label: "\(Calendar.current.component(.year, from: Date())) 年度回顾",
                          value: "Glassbook Wrapped",
                          action: { showAnnualWrap = true }),
                    .init(icon: "lightbulb", label: "消费洞察",
                          value: "AI 每日更新",
                          action: { showInsights = true }),
                ])

                menuGroup(title: "家庭", rows: [
                    .init(icon: "house", label: "家庭账本 (深圳之家)",
                          value: "\(store.familyMembers.count) 人 · " + Money.yuan(store.familyTotalThisMonthCents, showDecimals: false),
                          action: { showFamily = true }),
                ])

                menuGroup(title: "资金", rows: [
                    .init(icon: "creditcard", label: "账户与净资产",
                          value: "\(store.accounts.count) 个账户",
                          action: { showAccounts = true }),
                    .init(icon: "target", label: "预算设置",
                          value: Money.yuan(store.budget.monthlyTotalCents, showDecimals: false),
                          action: { showBudget = true }),
                    .init(icon: "square.grid.3x3", label: "分类管理", value: "8 个"),
                ])

                menuGroup(title: "数据", rows: [
                    .init(icon: "viewfinder", label: "智能识别",
                          value: "支付宝 · 微信 · 招行",
                          action: { showSmartImport = true }),
                    .init(icon: "clock.arrow.circlepath", label: "历史导入", value: "可回滚 7 天"),
                    .init(icon: "arrow.down.doc", label: "数据导出", value: "CSV / PDF"),
                    .init(icon: "externaldrive.badge.minus", label: "清除数据 / 重置演示",
                          value: "\(store.transactions.count) 笔交易",
                          action: { showDataManagement = true }),
                ])

                menuGroup(title: "开发者 · Pro", rows: [
                    .init(icon: "bubble.left.and.bubble.right", label: "问账 · AI 财务顾问",
                          value: "多轮对话",
                          action: { showAdvisor = true }),
                    .init(icon: "doc.badge.arrow.up", label: "发票 / 报销导出",
                          value: "PDF",
                          action: { showExport = true }),
                    .init(icon: "brain", label: "AI 引擎 · BYO LLM",
                          value: AIEngineStore.shared.selected.displayName,
                          action: { showAIEngine = true }),
                    .init(icon: "bell.and.waves.left.and.right", label: "Webhook · 设备直出",
                          value: "\(WebhookStore.shared.endpoints.count) 端点",
                          action: { showWebhooks = true }),
                    .init(icon: "bolt.horizontal", label: "自动化记账",
                          value: "截屏 · 短信 · MCP",
                          action: { showAutomation = true }),
                    .init(icon: "exclamationmark.arrow.triangle.2.circlepath", label: "沉没成本分析",
                          value: "闲置订阅 + 吃灰硬件",
                          action: { showSunkCost = true }),
                ])

                menuGroup(title: "其他", rows: [
                    .init(icon: "lock.shield", label: "Face ID 解锁", value: "已开启"),
                    .init(icon: "rectangle.on.rectangle", label: "桌面小组件", value: "长按主屏添加"),
                    .init(icon: "paintpalette", label: "外观与主题", value: "玻璃 · 亮色"),
                    .init(icon: "info.circle", label: "关于 Glassbook", value: "V1.2.0"),
                ])
                Spacer().frame(height: 100)
            }
            .padding(.horizontal, 18)
            .padding(.top, 6)
        }
        .scrollIndicators(.hidden)
        .safeAreaPadding(.top, 8)
        .sheet(isPresented: $showBudget)        { sheet { BudgetView() } }
        .sheet(isPresented: $showAccounts)      { sheet { AccountsView() } }
        .sheet(isPresented: $showSubscriptions) { sheet { SubscriptionsView() } }
        .sheet(isPresented: $showGoals)         { sheet { GoalsView() } }
        .sheet(isPresented: $showInsights)      { sheet { InsightsView(isStandalone: true) } }
        .sheet(isPresented: $showAIEngine)      { AIEngineSettingsView() }
        .sheet(isPresented: $showWebhooks)      { WebhookSettingsView() }
        .sheet(isPresented: $showAutomation)    { AutomationSettingsView() }
        .sheet(isPresented: $showSunkCost)      { sheet { SunkCostView() } }
        .sheet(isPresented: $showFamily)        { sheet { FamilyBookView() } }
        .fullScreenCover(isPresented: $showAdvisor) {
            AdvisorView().environment(store)
        }
        .sheet(isPresented: $showExport)        { sheet { InvoiceExportView() } }
        .sheet(isPresented: $showDataManagement) { sheet { DataManagementView() } }
        .fullScreenCover(isPresented: $showSmartImport) {
            SmartImportFlow(isPresented: $showSmartImport)
        }
        .fullScreenCover(isPresented: $showAnnualWrap) {
            AnnualWrapView()
        }
    }

    @ViewBuilder
    private func sheet<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack {
            AuroraBackground(palette: .profile)
            content()
        }
        .environment(store)
    }

    private var profileCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(LinearGradient(
                    colors: [AppColors.auroraPink, AppColors.auroraPurple],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
                Text(store.userInitial)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.white)
            }
            .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 4) {
                Text(store.userName).font(.system(size: 16, weight: .medium))
                Text("hello@glassbook.app").font(.system(size: 11))
                    .foregroundStyle(AppColors.ink3)
                if store.isPro {
                    Text("PRO 会员")
                        .font(.system(size: 10)).tracking(0.8)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 3)
                        .background(Capsule().fill(LinearGradient.brand()))
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundStyle(AppColors.ink4)
        }
        .padding(22)
        .glassCard()
    }

    private var statRow: some View {
        HStack(spacing: 0) {
            stat("已记笔数", value: "\(store.transactions.count)")
            Divider().background(AppColors.glassDivider)
            stat("连续打卡", value: "28 天")
            Divider().background(AppColors.glassDivider)
            stat("累计存款", value: Money.yuan(store.totalSavedCents, showDecimals: false))
        }
        .padding(.vertical, 14)
        .glassCard()
    }

    private func stat(_ label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(label).eyebrowStyle()
            Text(value).font(.system(size: 16, weight: .light).monospacedDigit())
                .minimumScaleFactor(0.7).lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    struct MenuRow: Identifiable {
        let id = UUID()
        let icon: String
        let label: String
        let value: String
        var action: (() -> Void)? = nil
    }

    private func menuGroup(title: String, rows: [MenuRow]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).eyebrowStyle().padding(.leading, 4)
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { idx, row in
                    if idx > 0 { Divider().background(AppColors.glassDivider).padding(.horizontal, 10) }
                    Button {
                        row.action?()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: row.icon)
                                .font(.system(size: 13))
                                .foregroundStyle(AppColors.ink2)
                                .frame(width: 30, height: 30)
                                .background(RoundedRectangle(cornerRadius: 9).fill(Color.white.opacity(0.5)))
                            Text(row.label).font(.system(size: 13))
                                .foregroundStyle(AppColors.ink)
                            Spacer()
                            Text(row.value).font(.system(size: 11))
                                .foregroundStyle(AppColors.ink3)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11))
                                .foregroundStyle(AppColors.ink4)
                        }
                        .padding(.vertical, 12).padding(.horizontal, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .glassCard()
        }
    }
}

#Preview {
    ZStack {
        AuroraBackground(palette: .profile)
        ProfileView().environment(AppStore())
    }
}
