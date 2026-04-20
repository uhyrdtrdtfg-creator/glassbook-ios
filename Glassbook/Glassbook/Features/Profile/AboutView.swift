import SwiftUI

/// Lightweight about sheet — reads version + build from the bundle so it
/// doesn't drift when we ship new releases.
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }
    private var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }

    var body: some View {
        ZStack {
            AuroraBackground(palette: .profile)
            ScrollView {
                VStack(spacing: 14) {
                    header
                    heroCard
                    linksCard
                    creditsCard
                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 18).padding(.top, 8)
            }
            .scrollIndicators(.hidden)
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
            Text("关于 Glassbook").font(.system(size: 16, weight: .medium))
            Spacer()
            Spacer().frame(width: 34)
        }
    }

    private var heroCard: some View {
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 22)
                    .fill(LinearGradient.brand())
                    .frame(width: 72, height: 72)
                Text("G").font(.system(size: 36, weight: .light))
                    .foregroundStyle(.white)
            }
            Text("Glassbook").font(.system(size: 20, weight: .medium))
            Text("会呼吸的智能记账 · 本地优先")
                .font(.system(size: 11))
                .foregroundStyle(AppColors.ink3)
            HStack(spacing: 6) {
                Text("v\(version)").font(.system(size: 11, weight: .medium).monospacedDigit())
                Text("·").foregroundStyle(AppColors.ink4)
                Text("build \(build)").font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(AppColors.ink3)
            }
        }
        .padding(.vertical, 24).padding(.horizontal, 18)
        .frame(maxWidth: .infinity)
        .glassCard()
    }

    private var linksCard: some View {
        VStack(spacing: 0) {
            linkRow(icon: "lock.shield", label: "隐私政策", value: "本地优先 · 无服务器")
            Divider().background(AppColors.glassDivider).padding(.horizontal, 10)
            linkRow(icon: "doc.text", label: "开源致谢", value: "SwiftUI · Vision")
            Divider().background(AppColors.glassDivider).padding(.horizontal, 10)
            linkRow(icon: "envelope", label: "反馈 / 建议", value: "hello@glassbook.app")
        }
        .padding(4)
        .glassCard()
    }

    private func linkRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(AppColors.ink2)
                .frame(width: 30, height: 30)
                .background(RoundedRectangle(cornerRadius: 9).fill(Color.white.opacity(0.5)))
            Text(label).font(.system(size: 13))
            Spacer()
            Text(value).font(.system(size: 11))
                .foregroundStyle(AppColors.ink3)
        }
        .padding(.vertical, 12).padding(.horizontal, 10)
    }

    private var creditsCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Built with").eyebrowStyle()
            Text("SwiftUI · SwiftData · CloudKit · Vision · WidgetKit · ActivityKit · WatchKit")
                .font(.system(size: 11))
                .foregroundStyle(AppColors.ink2)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: 14)
    }
}

#Preview {
    AboutView()
}
