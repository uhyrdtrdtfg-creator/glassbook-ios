import SwiftUI

/// iOS doesn't expose a programmatic "add widget" entry point — we can only
/// explain the gesture. Three short steps beat a dead menu row.
struct WidgetHelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AuroraBackground(palette: .profile)
            ScrollView {
                VStack(spacing: 14) {
                    header
                    heroCard
                    stepsCard
                    sizesCard
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
            Text("桌面小组件").font(.system(size: 16, weight: .medium))
            Spacer()
            Spacer().frame(width: 34)
        }
    }

    private var heroCard: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 16).fill(LinearGradient.brand())
                Image(systemName: "rectangle.on.rectangle")
                    .font(.system(size: 22)).foregroundStyle(.white)
            }
            .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 3) {
                Text("主屏 / 锁屏").font(.system(size: 13, weight: .medium))
                Text("长按桌面空白处 → 左上 + → 搜 Glassbook")
                    .font(.system(size: 11))
                    .foregroundStyle(AppColors.ink3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(16)
        .glassCard()
    }

    private var stepsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("三步加好").eyebrowStyle()
            stepRow(num: "1", text: "长按主屏空白处,等图标开始抖动")
            stepRow(num: "2", text: "左上角 +,在列表里搜 Glassbook")
            stepRow(num: "3", text: "挑一个尺寸,拖到想放的位置 · 松手即加")
        }
        .padding(16)
        .glassCard(radius: 14)
    }

    private var sizesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("三种尺寸").eyebrowStyle()
            sizeRow(icon: "square", title: "Small", detail: "本月花了多少 · 剩多少预算")
            sizeRow(icon: "rectangle", title: "Medium", detail: "上面 + 最近三笔列表")
            sizeRow(icon: "rectangle.portrait", title: "Large", detail: "上面 + 7 天柱状图 + Top 3 分类")
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

    private func sizeRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).font(.system(size: 14))
                .foregroundStyle(AppColors.ink2)
                .frame(width: 26, height: 26)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.5)))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 12, weight: .medium))
                Text(detail).font(.system(size: 10))
                    .foregroundStyle(AppColors.ink3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
    }
}

#Preview {
    WidgetHelpView()
}
