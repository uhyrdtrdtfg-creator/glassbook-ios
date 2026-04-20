import SwiftUI

/// Spec v2 §6.1.3 · 零点击入账设置页 (iOS Shortcuts / SMS / MCP).
/// Matches Diagram 03 right panel: three automation channel toggles + auto-save
/// delay chips + "省时可视化" stat card.
struct AutomationSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var store
    @State private var screenshotOn: Bool = AutomationSettings.screenshotOn
    @AppStorage("automation.autoSaveDelay") private var autoSaveDelay: Int = 5
    private var monthAutoCount: Int { store.autoImportedCountThisMonth }
    private var monthAutoCentsSaved: Int { store.autoImportedCentsThisMonth }

    var body: some View {
        ZStack {
            AuroraBackground(palette: .add)
            ScrollView {
                VStack(spacing: 14) {
                    header
                    livePreviewCard
                    channelCard(
                        icon: "viewfinder",
                        title: "截屏自动识别",
                        detail: "iOS 快捷指令监听截屏相册 · 非支付截图会被自动忽略",
                        isOn: Binding(
                            get: { screenshotOn },
                            set: { new in screenshotOn = new; AutomationSettings.screenshotOn = new }
                        )
                    )
                    comingSoonRow(
                        icon: "message.badge",
                        title: "短信入账 (招行 / 建行 / 工行)",
                        detail: "iOS 限制第三方 App 读短信,需等 Messages Filter 扩展支持",
                        badge: "即将支持"
                    )
                    infoRow(
                        icon: "bolt.horizontal.circle",
                        title: "MCP 对话入账",
                        detail: "独立 Mac 进程 · Claude Desktop / Cline / Zed 连接,常开",
                        badge: "Mac 进程"
                    )
                    delayCard
                    savingsCard
                    howToCard
                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
            }
            .scrollIndicators(.hidden)
        }
        .onChange(of: autoSaveDelay) { _, new in
            AutomationSettings.autoSaveDelay = new
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
            Text("自动化记账").font(.system(size: 16, weight: .medium))
            Spacer()
            Spacer().frame(width: 34)
        }
    }

    private var livePreviewCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "viewfinder.circle")
                    .font(.system(size: 18))
                    .foregroundStyle(LinearGradient.brand())
                Text("模拟一次截屏识别").font(.system(size: 13, weight: .medium))
                Spacer()
            }
            Text("触发 Live Activity 流程:识别 → 5 秒倒计时 → 自动入账。需在真机测试,模拟器会降级为日志。")
                .font(.system(size: 11))
                .foregroundStyle(AppColors.ink3)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                triggerPreview()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "play.fill").font(.system(size: 11))
                    Text("预览 Live Activity").font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 38)
                .background(RoundedRectangle(cornerRadius: 12).fill(AppColors.ink))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .glassCard()
    }

    private func triggerPreview() {
        // Seed the preview with the user's most recent expense so the Live
        // Activity looks like their real data, not stock coffee.
        let sample = store.transactions.filter { $0.kind == .expense }.first
        let amount = sample?.amountCents ?? 2800
        let merchant = sample?.merchant ?? "瑞幸咖啡"
        let emoji = sample.map { Category.by($0.categoryID).emoji } ?? "🍜"
        _ = LiveActivityService.shared.start(
            pendingAmountCents: amount,
            merchant: merchant,
            categoryEmoji: emoji,
            autoSaveSeconds: autoSaveDelay == -1 ? 5 : max(1, autoSaveDelay),
            onAutoCommit: { _ in
                print("🔔 Live Activity → auto-committed")
            }
        )
    }

    private func channelCard(icon: String, title: String, detail: String, isOn: Binding<Bool>) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(AppColors.ink2)
                .frame(width: 36, height: 36)
                .background(RoundedRectangle(cornerRadius: 11).fill(Color.white.opacity(0.55)))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 13, weight: .medium))
                Text(detail).font(.system(size: 10))
                    .foregroundStyle(AppColors.ink3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(AppColors.ink)
        }
        .padding(14)
        .glassCard()
    }

    /// Disabled channel row — shows the feature but flags it as not yet
    /// wired so users don't flip an ornament.
    private func comingSoonRow(icon: String, title: String, detail: String, badge: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(AppColors.ink3)
                .frame(width: 36, height: 36)
                .background(RoundedRectangle(cornerRadius: 11).fill(Color.white.opacity(0.35)))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppColors.ink2)
                Text(detail).font(.system(size: 10))
                    .foregroundStyle(AppColors.ink3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Text(badge).font(.system(size: 9, weight: .medium))
                .foregroundStyle(AppColors.auroraAmber)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Capsule().fill(AppColors.auroraAmber.opacity(0.18)))
        }
        .padding(14)
        .glassCard()
        .opacity(0.75)
    }

    /// Informational channel row — the feature exists but runs out of band
    /// (e.g. MCP Server on Mac), so there's nothing to toggle from iOS.
    private func infoRow(icon: String, title: String, detail: String, badge: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(AppColors.ink2)
                .frame(width: 36, height: 36)
                .background(RoundedRectangle(cornerRadius: 11).fill(Color.white.opacity(0.55)))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 13, weight: .medium))
                Text(detail).font(.system(size: 10))
                    .foregroundStyle(AppColors.ink3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Text(badge).font(.system(size: 9, weight: .medium))
                .foregroundStyle(AppColors.successGreen)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Capsule().fill(AppColors.successGreen.opacity(0.18)))
        }
        .padding(14)
        .glassCard()
    }

    private var delayCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("自动保存延迟").eyebrowStyle()
            HStack(spacing: 6) {
                ForEach([0, 5, 10, -1], id: \.self) { v in
                    Button { autoSaveDelay = v } label: {
                        Text(label(for: v))
                            .font(.system(size: 11, weight: autoSaveDelay == v ? .medium : .regular))
                            .foregroundStyle(autoSaveDelay == v ? .white : AppColors.ink)
                            .frame(maxWidth: .infinity, minHeight: 34)
                            .background(
                                Capsule().fill(autoSaveDelay == v ? AppColors.ink : Color.white.opacity(0.55))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            Text("Live Activity 在顶部悬浮 \(autoSaveDelayText) · 期间轻触保存或滑动编辑")
                .font(.system(size: 10))
                .foregroundStyle(AppColors.ink3)
        }
        .padding(14)
        .glassCard(radius: 14)
    }

    private var autoSaveDelayText: String {
        switch autoSaveDelay {
        case 0:  "立即自动保存"
        case -1: "不自动保存"
        default: "\(autoSaveDelay) 秒内自动保存"
        }
    }
    private func label(for v: Int) -> String {
        switch v {
        case 0:  "立即"
        case 5:  "5 秒"
        case 10: "10 秒"
        case -1: "关闭"
        default: "\(v)"
        }
    }

    private var savingsCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("本月自动识别").eyebrowStyle().foregroundStyle(Color(hex: 0x8A6D1F))
            if monthAutoCount > 0 {
                Text("\(monthAutoCount) 笔 · \(Money.yuan(monthAutoCentsSaved, showDecimals: false))")
                    .font(.system(size: 24, weight: .medium).monospacedDigit())
                    .foregroundStyle(Color(hex: 0x8A6D1F))
                Text("比手动记账节省约 \(max(1, monthAutoCount / 3)) 分钟")
                    .font(.system(size: 10))
                    .foregroundStyle(Color(hex: 0x8A6D1F).opacity(0.85))
            } else {
                Text("还没有自动识别")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color(hex: 0x8A6D1F))
                Text("配好快捷指令后,截屏一次就会出现在这里")
                    .font(.system(size: 10))
                    .foregroundStyle(Color(hex: 0x8A6D1F).opacity(0.85))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(Color(hex: 0xF4DFA8).opacity(0.55))
                .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(AppColors.glassBorder, lineWidth: 1))
        )
    }

    private var howToCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("怎么接入").eyebrowStyle()
            stepRow(num: "1", text: "打开「快捷指令」App → 自动化 → 新建")
            stepRow(num: "2", text: "触发选「每次截屏」→ 操作搜索「识别截屏记账」")
            stepRow(num: "3", text: "或对 Siri 说「用 Glassbook 识别这张图」")
            Text("App Intent 已内置,快捷指令库里会自动出现。识别后会进入「待入账」,下次打开 Glassbook 就一键确认。")
                .font(.system(size: 10))
                .foregroundStyle(AppColors.ink3)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
        .padding(16)
        .glassCard(radius: 14)
    }

    private func stepRow(num: String, text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(num)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(AppColors.ink))
            Text(text).font(.system(size: 12))
                .foregroundStyle(AppColors.ink)
        }
    }
}

#Preview {
    AutomationSettingsView().environment(AppStore())
}
