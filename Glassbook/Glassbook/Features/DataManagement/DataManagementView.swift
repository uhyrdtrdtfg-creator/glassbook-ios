import SwiftUI

/// 数据管理 · show counts + give the user a way to wipe or reset demo data.
/// Every destructive action goes through an alert. Wipe is persistent — it
/// hits SwiftData and survives restart.
struct DataManagementView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var pendingAction: Action?

    enum Action: Identifiable {
        case wipeAll, resetDemo
        case wipeTransactions, wipeSubscriptions, wipeGoals
        var id: String {
            switch self {
            case .wipeAll: "wipeAll"
            case .resetDemo: "resetDemo"
            case .wipeTransactions: "wipeTx"
            case .wipeSubscriptions: "wipeSub"
            case .wipeGoals: "wipeGoal"
            }
        }
        var title: String {
            switch self {
            case .wipeAll: "清除所有数据?"
            case .resetDemo: "重置为演示数据?"
            case .wipeTransactions: "清空交易记录?"
            case .wipeSubscriptions: "清空订阅列表?"
            case .wipeGoals: "清空储蓄目标?"
            }
        }
        var message: String {
            switch self {
            case .wipeAll:
                "交易 / 账户 / 订阅 / 目标 / 预算 全部删除,无法撤销。\n你在 Keychain 里的 LLM API Key 不受影响。"
            case .resetDemo:
                "先清空当前数据,然后重新灌入 62 笔示例交易 + 3 账户 + 7 订阅 + 4 目标。适合回到 scaffold 原始状态。"
            case .wipeTransactions:
                "只删除交易历史(含导入批次)。账户余额、订阅、目标不动。"
            case .wipeSubscriptions:
                "只清空订阅列表。交易不动。"
            case .wipeGoals:
                "只清空储蓄目标。交易和存入金额历史不动。"
            }
        }
        var confirmLabel: String {
            switch self {
            case .resetDemo: "重置演示数据"
            default: "确认删除"
            }
        }
    }

    var body: some View {
        ZStack {
            AuroraBackground(palette: .profile)
            ScrollView {
                VStack(spacing: 14) {
                    header
                    countsCard
                    destructiveSection
                    demoSection
                    privacyNote
                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
            }
            .scrollIndicators(.hidden)
        }
        .alert(pendingAction?.title ?? "", isPresented: binding(), presenting: pendingAction) { action in
            Button("取消", role: .cancel) {}
            Button(action.confirmLabel, role: .destructive) { perform(action) }
        } message: { action in
            Text(action.message)
        }
    }

    // MARK: - Alert binding

    private func binding() -> Binding<Bool> {
        .init(get: { pendingAction != nil },
              set: { if !$0 { pendingAction = nil } })
    }

    private func perform(_ action: Action) {
        switch action {
        case .wipeAll:           store.wipeAll()
        case .resetDemo:         store.resetToDemo()
        case .wipeTransactions:  store.wipeTransactions()
        case .wipeSubscriptions: store.wipeSubscriptions()
        case .wipeGoals:         store.wipeGoals()
        }
        pendingAction = nil
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left").font(.system(size: 13))
                    .frame(width: 34, height: 34)
                    .glassCard(radius: 12)
                    .foregroundStyle(AppColors.ink)
            }
            Spacer()
            Text("数据管理").font(.system(size: 16, weight: .medium))
            Spacer()
            Spacer().frame(width: 34)
        }
    }

    // MARK: - Counts

    private var countsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("当前数据").eyebrowStyle()
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                statCell(label: "交易", count: store.transactions.count)
                statCell(label: "账户", count: store.accounts.count)
                statCell(label: "订阅", count: store.subscriptions.count)
                statCell(label: "储蓄目标", count: store.goals.count)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private func statCell(label: String, count: Int) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.system(size: 11))
                    .foregroundStyle(AppColors.ink3)
                Text("\(count)")
                    .font(.system(size: 22, weight: .light).monospacedDigit())
            }
            Spacer()
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.55)))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(AppColors.glassBorder, lineWidth: 1))
    }

    // MARK: - Destructive

    private var destructiveSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("按类型清除").eyebrowStyle().padding(.leading, 4)
            VStack(spacing: 0) {
                actionRow(title: "清空交易记录", subtitle: "保留账户、订阅、目标",
                          icon: "text.badge.xmark") { pendingAction = .wipeTransactions }
                Divider().background(AppColors.glassDivider).padding(.horizontal, 10)
                actionRow(title: "清空订阅列表", subtitle: "不影响交易",
                          icon: "arrow.clockwise") { pendingAction = .wipeSubscriptions }
                Divider().background(AppColors.glassDivider).padding(.horizontal, 10)
                actionRow(title: "清空储蓄目标", subtitle: "不影响交易",
                          icon: "target") { pendingAction = .wipeGoals }
            }
            .padding(4)
            .glassCard()

            Button { pendingAction = .wipeAll } label: {
                HStack(spacing: 8) {
                    Image(systemName: "trash.fill")
                    Text("清除所有数据").font(.system(size: 14, weight: .medium))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(RoundedRectangle(cornerRadius: 14).fill(AppColors.expenseRed))
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
        }
    }

    // MARK: - Demo

    private var demoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("演示数据").eyebrowStyle().padding(.leading, 4)
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(LinearGradient.brand()))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("重置为演示数据")
                            .font(.system(size: 13, weight: .medium))
                        Text("先清空,再灌入 62 笔示例交易 + 3 账户 + 7 订阅 + 4 目标")
                            .font(.system(size: 11))
                            .foregroundStyle(AppColors.ink3)
                            .lineSpacing(2)
                    }
                }
                Button { pendingAction = .resetDemo } label: {
                    Text("一键重置")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppColors.ink)
                        .frame(maxWidth: .infinity, minHeight: 42)
                        .glassCard(radius: 12)
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard()
        }
    }

    private func actionRow(title: String, subtitle: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(AppColors.expenseRed)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(AppColors.expenseRed.opacity(0.12)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppColors.ink)
                    Text(subtitle).font(.system(size: 10))
                        .foregroundStyle(AppColors.ink3)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 11))
                    .foregroundStyle(AppColors.ink4)
            }
            .padding(.vertical, 12).padding(.horizontal, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Privacy note

    private var privacyNote: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lock.shield").font(.system(size: 13))
                .foregroundStyle(AppColors.ink2)
                .frame(width: 26, height: 26)
                .background(Circle().fill(Color.white.opacity(0.55)))
            VStack(alignment: .leading, spacing: 4) {
                Text("隐私说明").eyebrowStyle()
                Text("清除操作只删本设备数据。开了 iCloud 同步时会级联删除其他已登录同一 Apple ID 的设备。BYO LLM 的 API Key 存 iOS Keychain,本页不会动。")
                    .font(.system(size: 10))
                    .foregroundStyle(AppColors.ink2)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .glassCard(radius: 14)
    }
}

#Preview {
    DataManagementView().environment(AppStore())
}
