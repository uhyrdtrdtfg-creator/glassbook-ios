import SwiftUI

/// Spec v2 §6.5 · 家庭账本 + CKShare 分级隐私.
/// Mirrors Diagram 05 left panel: 3 roles + monthly family total with per-member
/// split + 神兽专项 (kids) sub-category breakdown.
struct FamilyBookView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @State private var showAddMember = false
    @State private var sharing = FamilySharingService.shared
    @State private var showLeaveConfirm = false
    @State private var showDissolveConfirm = false
    @State private var isWorking = false
    @State private var toastMessage: String?
    @State private var showErrorAlert = false

    var body: some View {
        ZStack {
            AuroraBackground(palette: .home)
            ScrollView {
                VStack(spacing: 14) {
                    header
                    membersCard
                    addMemberButton
                    familyHero
                    kidsSection
                    privacyExplainer
                    dangerZone
                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                // why: keep cards in a comfortable reading column on iPad / Mac.
                .frame(maxWidth: hSizeClass == .regular ? 720 : .infinity)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            if let toastMessage {
                VStack {
                    Spacer()
                    Text(toastMessage)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18).padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(AppColors.ink.opacity(0.92)))
                        .padding(.bottom, 40)
                }
                .transition(.opacity)
            }
        }
        .sheet(isPresented: $showAddMember) {
            AddFamilyMemberSheet().environment(store)
                .presentationDetents([.large])
        }
        .confirmationDialog(
            "退出此家庭账本?",
            isPresented: $showLeaveConfirm,
            titleVisibility: .visible
        ) {
            Button("退出", role: .destructive) { Task { await performLeave() } }
            Button("取消", role: .cancel) {}
        } message: {
            Text("退出后你的设备上不再同步家庭数据, 其他成员看不到你, 你的已有记录保留在本地。确定退出?")
        }
        .confirmationDialog(
            "解散家庭账本?",
            isPresented: $showDissolveConfirm,
            titleVisibility: .visible
        ) {
            Button("解散", role: .destructive) { Task { await performDissolve() } }
            Button("取消", role: .cancel) {}
        } message: {
            Text("解散后所有成员将失去访问, 云端共享数据全部删除, 此操作不可撤销。")
        }
        .alert("操作失败", isPresented: $showErrorAlert) {
            Button("知道了", role: .cancel) { sharing.lastError = nil }
        } message: {
            Text(sharing.lastError ?? "请稍后重试")
        }
        .task { await sharing.refreshOwnership() }
    }

    private var addMemberButton: some View {
        VStack(spacing: 10) {
            Button { showAddMember = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: "person.badge.plus").font(.system(size: 14))
                    Text("手动添加成员").font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(AppColors.ink)
                .frame(maxWidth: .infinity, minHeight: 44)
                .glassCard(radius: 14)
            }
            .buttonStyle(.plain)
            Button {
                Task { await openCloudKitInvite() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "icloud.and.arrow.up").font(.system(size: 14))
                    Text("iCloud 邀请 · CKShare").font(.system(size: 13, weight: .medium))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(RoundedRectangle(cornerRadius: 14).fill(AppColors.ink))
            }
            .buttonStyle(.plain)
        }
    }

    @MainActor
    private func openCloudKitInvite() async {
        guard let host = UIKitHost.rootViewController else { return }
        await FamilySharingService.presentInvite(from: host)
    }

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left").font(.system(size: 13))
                    .frame(width: 34, height: 34).glassCard(radius: 12)
                    .foregroundStyle(AppColors.ink)
            }
            VStack(alignment: .center, spacing: 2) {
                Text("深圳之家").eyebrowStyle().tracking(1.4)
                Text("家庭账本").font(.system(size: 16, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            Button { showAddMember = true } label: {
                Image(systemName: "person.badge.plus").font(.system(size: 13))
                    .frame(width: 34, height: 34).glassCard(radius: 12)
                    .foregroundStyle(AppColors.ink)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Members

    private var membersCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(store.familyMembers.enumerated()), id: \.element.id) { idx, m in
                if idx > 0 { Divider().background(AppColors.glassDivider).padding(.horizontal, 10) }
                memberRow(m)
            }
        }
        .padding(6)
        .glassCard()
    }

    private func memberRow(_ m: FamilyMember) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color(hex: m.avatarColorHex))
                Text(m.initial)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(m.name).font(.system(size: 13, weight: .medium))
                Text(m.role.displayName).font(.system(size: 10))
                    .foregroundStyle(AppColors.ink3)
            }
            Spacer()
            Text(m.role.lockEmoji).font(.system(size: 16))
        }
        .padding(.vertical, 10).padding(.horizontal, 10)
    }

    // MARK: - Monthly family total hero

    private var familyHero: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("本月家庭总支出").eyebrowStyle()
            HStack(alignment: .top, spacing: 4) {
                Text("¥").font(.system(size: 22, weight: .light))
                    .foregroundStyle(AppColors.ink2).padding(.top, 8)
                Text(compact(store.familyTotalThisMonthCents))
                    .font(.system(size: 42, weight: .ultraLight).monospacedDigit())
            }
            Divider().background(AppColors.glassDivider)
            // Per-member split bars
            VStack(spacing: 10) {
                ForEach(store.familyMembers) { m in
                    memberSplitRow(m)
                }
            }
            Text("不含任一方的「仅自己」私房钱")
                .font(.system(size: 10))
                .foregroundStyle(AppColors.ink3)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private func memberSplitRow(_ m: FamilyMember) -> some View {
        let total = max(1, store.familyTotalThisMonthCents)
        let pct = Double(m.monthlyContributionCents) / Double(total)
        return HStack(spacing: 10) {
            Text(m.avatar).font(.system(size: 14))
                .frame(width: 20)
            Text(m.name.prefix(3))
                .font(.system(size: 11))
                .foregroundStyle(AppColors.ink2)
                .frame(width: 40, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.45))
                    Capsule().fill(Color(hex: m.avatarColorHex))
                        .frame(width: geo.size.width * CGFloat(min(pct, 1.0)))
                }
            }.frame(height: 6)
            Text(Money.yuan(m.monthlyContributionCents, showDecimals: false))
                .font(.system(size: 11, weight: .medium).monospacedDigit())
                .frame(width: 64, alignment: .trailing)
        }
    }

    // MARK: - Kids

    private var kidsSection: some View {
        let kidTx = store.transactionsInMonth(Date()).filter { $0.categoryID == .kids }
        let totalCents = kidTx.filter { $0.kind == .expense }.reduce(0) { $0 + $1.amountCents }
        let byBucket = kidsBuckets(kidTx)

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("🧒 小朋友专项 · 本月").eyebrowStyle()
                Spacer()
                Text(Money.yuan(totalCents, showDecimals: false))
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
            }
            VStack(spacing: 0) {
                ForEach(Array(byBucket.enumerated()), id: \.offset) { idx, bucket in
                    if idx > 0 { Divider().background(AppColors.glassDivider).padding(.horizontal, 10) }
                    HStack {
                        Text(bucket.icon).font(.system(size: 14)).frame(width: 28)
                        Text(bucket.name).font(.system(size: 13))
                        Spacer()
                        Text(Money.yuan(bucket.cents, showDecimals: false))
                            .font(.system(size: 13, weight: .medium).monospacedDigit())
                    }
                    .padding(.vertical, 10).padding(.horizontal, 10)
                }
                if byBucket.isEmpty {
                    Text("本月没有孩子专项支出").font(.system(size: 11))
                        .foregroundStyle(AppColors.ink3)
                        .padding(16)
                }
            }
            .padding(4)
            .glassCard()
        }
    }

    /// 5 default kid buckets inferred by merchant keyword.
    private func kidsBuckets(_ tx: [Transaction]) -> [(name: String, icon: String, cents: Int)] {
        let defs: [(String, String, [String])] = [
            ("兴趣班",    "🎨", ["兴趣班", "美术", "钢琴", "舞蹈", "英语", "乐高", "编程"]),
            ("绘本 · 玩具", "🧸", ["绘本", "玩具", "积木", "娃娃", "拼图", "文具", "书"]),
            ("医疗 · 保健", "💊", ["医院", "药", "维生素", "疫苗", "保健", "口腔"]),
            ("教育培训",   "📚", ["学费", "补习", "课程", "培训"]),
            ("日用",       "🧴", ["尿不湿", "奶粉", "日用", "清洁"]),
        ]
        return defs.compactMap { (name, icon, kws) in
            let cents = tx.filter { t in kws.contains { t.merchant.contains($0) || (t.note ?? "").contains($0) } }
                          .filter { $0.kind == .expense }
                          .reduce(0) { $0 + $1.amountCents }
            return cents > 0 ? (name, icon, cents) : nil
        }
    }

    // MARK: - Privacy explainer

    private var privacyExplainer: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("三档隐私 · 按笔选择").eyebrowStyle()
            HStack(alignment: .top, spacing: 10) {
                privacyBox(emoji: "👨‍👩‍👧", title: "家庭可见", body: "进入家庭总支出和任一方查询")
                privacyBox(emoji: "💞", title: "仅伴侣",  body: "双人可见 · 孩子不可见")
                privacyBox(emoji: "🔒", title: "仅自己",  body: "私房钱 · 家庭首页完全不见")
            }
            Text("基于 CloudKit CKShare · 苹果原生端到端加密 · 数据永不离开 Apple 生态")
                .font(.system(size: 10))
                .foregroundStyle(AppColors.ink3)
                .padding(.top, 4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: 14)
    }

    private func privacyBox(emoji: String, title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(emoji).font(.system(size: 18))
            Text(title).font(.system(size: 12, weight: .medium))
            Text(body).font(.system(size: 10))
                .foregroundStyle(AppColors.ink3)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.55))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(AppColors.glassBorder, lineWidth: 1))
        )
    }

    private func compact(_ cents: Int) -> String {
        let y = cents / 100
        let fmt = NumberFormatter(); fmt.numberStyle = .decimal
        return fmt.string(from: NSNumber(value: y)) ?? "\(y)"
    }

    // MARK: - Danger zone (leave / dissolve)

    @ViewBuilder
    private var dangerZone: some View {
        // why: hide both actions when ownership is unknown or no share exists —
        // showing destructive buttons for state the user can't actually affect is worse than nothing.
        if sharing.ownership == .participant || sharing.ownership == .owner {
            VStack(alignment: .leading, spacing: 10) {
                Text("危险操作").eyebrowStyle()
                if sharing.ownership == .participant {
                    dangerButton(
                        icon: "rectangle.portrait.and.arrow.right",
                        title: "退出此家庭账本",
                        subtitle: "从云端共享中移除本设备"
                    ) { showLeaveConfirm = true }
                }
                if sharing.ownership == .owner {
                    dangerButton(
                        icon: "trash",
                        title: "解散家庭账本",
                        subtitle: "删除全部云端共享数据 · 不可撤销"
                    ) { showDissolveConfirm = true }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(radius: 14)
        }
    }

    private func dangerButton(
        icon: String,
        title: String,
        subtitle: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.system(size: 14))
                    .foregroundStyle(Color.red)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.red.opacity(0.12)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.red)
                    Text(subtitle).font(.system(size: 10))
                        .foregroundStyle(AppColors.ink3)
                }
                Spacer()
                if isWorking {
                    ProgressView().scaleEffect(0.7)
                } else {
                    Image(systemName: "chevron.right").font(.system(size: 11))
                        .foregroundStyle(AppColors.ink3)
                }
            }
            .padding(.vertical, 10).padding(.horizontal, 12)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.55)))
        }
        .buttonStyle(.plain)
        .disabled(isWorking)
        .opacity(isWorking ? 0.5 : 1)
    }

    @MainActor
    private func performLeave() async {
        isWorking = true
        defer { isWorking = false }
        do {
            try await sharing.leaveShare()
            showToast("已退出家庭账本")
        } catch {
            if sharing.lastError == nil { sharing.lastError = error.localizedDescription }
            showErrorAlert = true
        }
    }

    @MainActor
    private func performDissolve() async {
        isWorking = true
        defer { isWorking = false }
        do {
            try await sharing.dissolveShare()
            showToast("家庭账本已解散")
        } catch {
            if sharing.lastError == nil { sharing.lastError = error.localizedDescription }
            showErrorAlert = true
        }
    }

    private func showToast(_ msg: String) {
        withAnimation(.easeInOut(duration: 0.2)) { toastMessage = msg }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            withAnimation(.easeInOut(duration: 0.3)) { toastMessage = nil }
        }
    }
}

#Preview {
    FamilyBookView().environment(AppStore())
}
