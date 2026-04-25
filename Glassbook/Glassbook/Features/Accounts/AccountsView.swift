import SwiftUI

/// Spec §6.1 P0 · 多账户 + 净资产. Routed from Profile → "账户与同步".
struct AccountsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var showAddSheet = false

    var body: some View {
        ZStack {
            AuroraBackground(palette: .profile)

            ScrollView {
                VStack(spacing: 14) {
                    header
                    netWorthCard
                    ForEach(Account.Kind.allCases, id: \.self) { kind in
                        let accs = store.accounts.filter { $0.type == kind }
                        if !accs.isEmpty {
                            groupSection(title: kind.displayName, items: accs)
                        }
                    }
                    addAccountButton
                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
            }
            .scrollIndicators(.hidden)
        }
        .sheet(isPresented: $showAddSheet) {
            AddAccountSheet()
                .environment(store)
                .presentationDetents([.large, .medium])
                .presentationDragIndicator(.visible)
        }
    }

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13))
                    .frame(width: 34, height: 34)
                    .glassCard(radius: 12)
                    .foregroundStyle(AppColors.ink)
            }
            Spacer()
            Text("账户与净资产")
                .font(.system(size: 16, weight: .medium))
            Spacer()
            Spacer().frame(width: 34)
        }
    }

    private var netWorthCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("净资产").eyebrowStyle()
            HStack(alignment: .top, spacing: 4) {
                Text("¥").font(.system(size: 22, weight: .light))
                    .foregroundStyle(AppColors.ink2).padding(.top, 8)
                Text(yuanFormat(store.netWorthCents))
                    .font(.system(size: 44, weight: .ultraLight).monospacedDigit())
                    .foregroundStyle(AppColors.ink)
            }
            Divider().background(AppColors.glassDivider).padding(.top, 4)
            HStack {
                metric("资产", cents: positiveAssets, color: AppColors.incomeGreen)
                Spacer()
                metric("负债", cents: abs(negativeDebt), color: AppColors.expenseRed)
                Spacer()
                metric("账户数", text: "\(store.accounts.count)", color: AppColors.ink)
            }
            .padding(.top, 8)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private var positiveAssets: Int {
        store.accounts.filter { $0.balanceCents > 0 }.reduce(0) { $0 + $1.balanceCents }
    }
    private var negativeDebt: Int {
        store.accounts.filter { $0.balanceCents < 0 }.reduce(0) { $0 + $1.balanceCents }
    }

    private func metric(_ label: String, cents: Int? = nil, text: String? = nil, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).eyebrowStyle()
            Text(text ?? Money.yuan(cents ?? 0, showDecimals: false))
                .font(.system(size: 14, weight: .medium).monospacedDigit())
                .foregroundStyle(color)
        }
    }

    private func groupSection(title: String, items: [Account]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).eyebrowStyle().padding(.leading, 4)
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { idx, acc in
                    if idx > 0 { Divider().background(AppColors.glassDivider).padding(.horizontal, 10) }
                    accountRow(acc)
                }
            }
            .padding(4)
            .glassCard()
        }
    }

    private func accountRow(_ acc: Account) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 11)
                    .fill(LinearGradient.gradient(acc.type.gradient))
                Image(systemName: acc.type.iconName)
                    .foregroundStyle(.white)
                    .font(.system(size: 13, weight: .medium))
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(acc.name).font(.system(size: 13, weight: .medium))
                Text(acc.type.displayName).font(.system(size: 10))
                    .foregroundStyle(AppColors.ink3)
            }
            Spacer()
            Text(Money.yuan(acc.balanceCents, showDecimals: false))
                .font(.system(size: 14, weight: .medium).monospacedDigit())
                .foregroundStyle(acc.balanceCents < 0 ? AppColors.expenseRed : AppColors.ink)
            if acc.isPrimary {
                Text("主").font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Capsule().fill(AppColors.ink))
            }
        }
        .padding(.vertical, 10).padding(.horizontal, 10)
    }

    private var addAccountButton: some View {
        Button { showAddSheet = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle").font(.system(size: 15))
                Text("添加账户").font(.system(size: 14, weight: .medium))
            }
            .foregroundStyle(AppColors.ink)
            .frame(maxWidth: .infinity, minHeight: 48)
            .glassCard(radius: 14)
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }

    private func yuanFormat(_ cents: Int) -> String {
        let yuan = cents / 100
        let fmt = NumberFormatter(); fmt.numberStyle = .decimal
        return fmt.string(from: NSNumber(value: yuan)) ?? "\(yuan)"
    }
}

extension Account.Kind {
    var displayName: String {
        switch self {
        case .cash: "现金 / 储蓄卡"
        case .savings: "储蓄账户"
        case .credit: "信用卡"
        case .fund: "基金 / 理财"
        case .virtual: "虚拟账户"
        }
    }
    var iconName: String {
        switch self {
        case .cash: "banknote"
        case .savings: "building.columns"
        case .credit: "creditcard"
        case .fund: "chart.line.uptrend.xyaxis"
        case .virtual: "wallet.pass"
        }
    }
    var gradient: [Color] {
        switch self {
        case .cash:    return [Color(hex: 0x7ACFA5), Color(hex: 0xA8E4D2)]
        case .savings: return [Color(hex: 0x7EA8FF), Color(hex: 0x9CC0FF)]
        case .credit:  return [Color(hex: 0xD04A7A), Color(hex: 0xFF6B9D)]
        case .fund:    return [Color(hex: 0xC48AFF), Color(hex: 0xD4A5FF)]
        case .virtual: return [Color(hex: 0xFFA87A), Color(hex: 0xFFD46B)]
        }
    }
    static let allCases: [Account.Kind] = [.cash, .savings, .credit, .fund, .virtual]
}

private struct AddAccountSheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var kind: Account.Kind = .cash
    @State private var balanceText = ""

    var body: some View {
        ZStack {
            AuroraBackground(palette: .profile)
            VStack(spacing: 16) {
                Text("新增账户").font(AppFont.h2).padding(.top, 8)

                TextField("账户名称 (如「招行储蓄卡」)", text: $name)
                    .padding(14)
                    .glassCard(radius: 12)

                Picker("类型", selection: $kind) {
                    ForEach(Account.Kind.allCases, id: \.self) { k in
                        Text(k.displayName).tag(k)
                    }
                }
                .pickerStyle(.segmented)

                TextField("初始余额 (¥)", text: $balanceText)
                    .keyboardType(.numberPad)
                    .padding(14)
                    .glassCard(radius: 12)

                Spacer()

                Button {
                    let cents = (Int(balanceText) ?? 0) * 100 * (kind == .credit ? -1 : 1)
                    let acc = Account(id: UUID(), name: name.isEmpty ? kind.displayName : name,
                                      type: kind, balanceCents: cents, isPrimary: false)
                    // Persist via AppStore so SwiftData receives the insert and
                    // the account survives restart (was lost in scaffold v1).
                    store.addAccount(acc)
                    dismiss()
                } label: {
                    Text("保存账户")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(RoundedRectangle(cornerRadius: 14).fill(AppColors.ink))
                }
                .disabled(name.isEmpty)
                .opacity(name.isEmpty ? 0.5 : 1)
            }
            .padding(20)
        }
    }
}

#Preview {
    AccountsView().environment(AppStore())
}
