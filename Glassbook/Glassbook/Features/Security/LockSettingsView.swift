import SwiftUI

/// Settings for the Face ID gate. User addresses the "每次重新进入都要刷脸太烦"
/// pain by picking a grace period or turning biometrics off entirely.
struct LockSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppLock.self) private var lock
    @State private var reauthError: String?

    private let graceOptions: [(label: String, seconds: Int)] = [
        ("立即 · 每次都刷脸",  0),
        ("1 分钟",            60),
        ("5 分钟 · 推荐",      300),
        ("30 分钟",           1800),
        ("2 小时",            7200),
        ("永不 · 信任设备",   -1),
    ]

    var body: some View {
        ZStack {
            AuroraBackground(palette: .profile)
            ScrollView {
                VStack(spacing: 14) {
                    header
                    gatedToggleCard
                    if lock.faceIDEnabled {
                        graceCard
                        explainerCard
                    } else {
                        offExplainerCard
                    }
                    if let err = reauthError {
                        Text(err).font(.system(size: 11))
                            .foregroundStyle(AppColors.expenseRed)
                            .padding(.horizontal, 8)
                    }
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
                    .frame(width: 34, height: 34)
                    .glassCard(radius: 12)
                    .foregroundStyle(AppColors.ink)
            }
            Spacer()
            Text("锁定设置").font(.system(size: 16, weight: .medium))
            Spacer()
            Spacer().frame(width: 34)
        }
    }

    /// Toggle is visually a Toggle but interaction is gated by a Face ID
    /// re-auth — otherwise an unlocked phone in someone else's hand could
    /// disable biometrics with one tap and own the account forever.
    /// Only the ACTUAL change path runs auth; the Toggle reflects the
    /// committed state synchronously.
    private var gatedToggleCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(LinearGradient.brand())
                Image(systemName: "faceid").font(.system(size: 18))
                    .foregroundStyle(.white)
            }
            .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text("Face ID 解锁").font(.system(size: 14, weight: .medium))
                Text("改动需要再次 Face ID / 密码确认")
                    .font(.system(size: 11))
                    .foregroundStyle(AppColors.ink3)
            }
            Spacer()
            Toggle("", isOn: Binding(
                get: { lock.faceIDEnabled },
                set: { new in Task { await changeFaceIDEnabled(to: new) } }
            ))
            .labelsHidden().tint(AppColors.ink)
        }
        .padding(16)
        .glassCard()
    }

    private func changeFaceIDEnabled(to new: Bool) async {
        guard new != lock.faceIDEnabled else { return }
        let reason = new ? "开启 Face ID 锁" : "关闭 Face ID 锁"
        let ok = await lock.confirmIdentity(reason: reason)
        await MainActor.run {
            if ok {
                lock.faceIDEnabled = new
                reauthError = nil
            } else {
                reauthError = "验证未通过 · 设置未改动"
            }
        }
    }

    private func changeGrace(to seconds: Int) async {
        guard seconds != lock.gracePeriodSeconds else { return }
        let ok = await lock.confirmIdentity(reason: "修改重锁时间")
        await MainActor.run {
            if ok {
                lock.gracePeriodSeconds = seconds
                reauthError = nil
            } else {
                reauthError = "验证未通过 · 设置未改动"
            }
        }
    }

    private var graceCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("多久后重锁").eyebrowStyle()
            VStack(spacing: 0) {
                ForEach(Array(graceOptions.enumerated()), id: \.offset) { idx, opt in
                    Button {
                        Task { await changeGrace(to: opt.seconds) }
                    } label: {
                        HStack {
                            Text(opt.label)
                                .font(.system(size: 13, weight: selected(opt.seconds) ? .medium : .regular))
                                .foregroundStyle(AppColors.ink)
                            Spacer()
                            if selected(opt.seconds) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(AppColors.ink)
                            }
                        }
                        .padding(.vertical, 12).padding(.horizontal, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if idx < graceOptions.count - 1 {
                        Divider().background(AppColors.glassDivider).padding(.horizontal, 10)
                    }
                }
            }
            .padding(4)
            .glassCard()
        }
    }

    private func selected(_ seconds: Int) -> Bool { lock.gracePeriodSeconds == seconds }

    private var explainerCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "clock.badge.checkmark")
                .font(.system(size: 13)).foregroundStyle(AppColors.ink2)
                .frame(width: 26, height: 26)
                .background(Circle().fill(Color.white.opacity(0.55)))
            VStack(alignment: .leading, spacing: 4) {
                Text("怎么算").eyebrowStyle()
                Text("上次解锁或退到后台算起,超过选定时间再打开就重新要 Face ID。iOS 经常后台杀 App,默认 5 分钟够用也不烦。")
                    .font(.system(size: 10))
                    .foregroundStyle(AppColors.ink2)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .glassCard(radius: 14)
    }

    private var offExplainerCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 13)).foregroundStyle(AppColors.auroraAmber)
                .frame(width: 26, height: 26)
                .background(Circle().fill(Color.white.opacity(0.55)))
            VStack(alignment: .leading, spacing: 4) {
                Text("锁已关闭").eyebrowStyle().foregroundStyle(AppColors.auroraAmber)
                Text("任何人拿到你的解锁手机都能看账本。只在信任场景这么设。出门/工作场合建议留着。")
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
    let lock = AppLock(); lock.skipAuth = true
    return LockSettingsView().environment(lock)
}
