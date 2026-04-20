import SwiftUI

/// Spec §6.2 Hero 1 · 年度回顾 (Spotify Wrapped style).
/// 5 story cards, swipe left/right. Last card has share-as-poster (ImageRenderer).
struct AnnualWrapView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var currentPage = 0

    private var stats: AnnualStats {
        let year = Calendar.current.component(.year, from: Date())
        return WrapGenerator.stats(for: year, transactions: store.transactions)
    }

    var body: some View {
        ZStack {
            // Story background shifts subtly per page.
            AuroraBackground(palette: currentPage % 2 == 0 ? .importPurple : .importAmber)
                .animation(.easeInOut(duration: 0.5), value: currentPage)

            TabView(selection: $currentPage) {
                StoryCard(page: 0,
                          eyebrow: "\(stats.year) · Glassbook Wrapped",
                          headline: "你今年记了",
                          bigNumber:"\(stats.txCount) 笔",
                          subtitle: "跨 \(stats.uniqueMerchants) 家商户。每一笔都看见了。",
                          gradient: [AppColors.brandStart, AppColors.brandEnd])
                    .tag(0)

                StoryCard(page: 1,
                          eyebrow: "总支出",
                          headline: "\(stats.year) 年你花了",
                          bigNumber:Money.yuan(stats.totalExpenseCents, showDecimals: false),
                          subtitle: amountBlurb(stats.totalExpenseCents),
                          gradient: [Color(hex: 0xFF6B9D), Color(hex: 0xFFA87A)])
                    .tag(1)

                StoryCard(page: 2,
                          eyebrow: "最烧钱的一天",
                          headline: stats.topDay.map { Self.dayFmt.string(from: $0.date) } ?? "—",
                          bigNumber:Money.yuan(stats.topDay?.amountCents ?? 0, showDecimals: false),
                          subtitle: "那天你一定过得很精彩。",
                          gradient: [Color(hex: 0xC48AFF), Color(hex: 0x7EA8FF)])
                    .tag(2)

                PersonaCard(persona: stats.topPersona,
                            cat: stats.topCategory,
                            topMerchants: stats.topMerchants)
                    .tag(3)

                ShareCard(stats: stats, onDismiss: { dismiss() })
                    .tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AppColors.ink)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(.ultraThinMaterial))
                            .overlay(Circle().strokeBorder(AppColors.glassBorder, lineWidth: 1))
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
    }

    private func amountBlurb(_ cents: Int) -> String {
        let yuan = cents / 100
        switch yuan {
        case ..<50_000:  return "节制而清醒,值得肯定。"
        case ..<150_000: return "平衡且自洽,过了真实的一年。"
        case ..<300_000: return "你为生活投入了很多。"
        default:         return "过了相当丰盛的一年。"
        }
    }

    static let dayFmt: DateFormatter = {
        let f = DateFormatter()
        f.locale = .init(identifier: "zh_CN")
        f.dateFormat = "M 月 d 日"
        return f
    }()
}

// MARK: - Cards

private struct StoryCard: View {
    let page: Int
    let eyebrow: String
    let headline: String
    let bigNumber: String
    let subtitle: String
    let gradient: [Color]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer()
            Text(eyebrow).eyebrowStyle().tracking(1.8)
            Text(headline).font(.system(size: 22, weight: .light))
                .foregroundStyle(AppColors.ink2)
            Text(bigNumber)
                .font(.system(size: 76, weight: .ultraLight).monospacedDigit())
                .foregroundStyle(LinearGradient.gradient(gradient))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text(subtitle)
                .font(.system(size: 15))
                .foregroundStyle(AppColors.ink2)
                .lineSpacing(4)
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 28)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct PersonaCard: View {
    let persona: String
    let cat: Category?
    let topMerchants: [(name: String, cents: Int)]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Spacer()
            Text("消费人格").eyebrowStyle().tracking(1.8)

            if let cat {
                HStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 22).fill(LinearGradient.gradient(cat.gradient))
                        Text(cat.emoji).font(.system(size: 48))
                    }
                    .frame(width: 96, height: 96)
                    .shadow(color: .black.opacity(0.15), radius: 16, y: 8)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(persona).font(.system(size: 28, weight: .medium))
                        Text("你最爱的分类是 \(cat.name)")
                            .font(.system(size: 14))
                            .foregroundStyle(AppColors.ink2)
                    }
                }
            }

            if !topMerchants.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("最常光顾").eyebrowStyle()
                    ForEach(Array(topMerchants.enumerated()), id: \.element.name) { idx, m in
                        HStack {
                            Text("\(idx + 1).").foregroundStyle(AppColors.ink3)
                                .font(.system(size: 13, weight: .medium))
                                .frame(width: 24, alignment: .leading)
                            Text(m.name).font(.system(size: 14))
                            Spacer()
                            Text(Money.yuan(m.cents, showDecimals: false))
                                .font(.system(size: 13, weight: .medium).monospacedDigit())
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding(.top, 8)
            }
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 28)
    }
}

private struct ShareCard: View {
    let stats: AnnualStats
    let onDismiss: () -> Void
    @State private var sharedPosterURL: URL?
    @State private var isRendering = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            posterThumbnail
                .frame(width: 220, height: 360)
                .shadow(color: .black.opacity(0.2), radius: 24, y: 12)

            Text("你的 \(stats.year) 年度海报")
                .font(.system(size: 18, weight: .medium))
            Text("一键生成竖版海报,带 #GlassbookWrapped 分享给朋友")
                .font(.system(size: 12))
                .foregroundStyle(AppColors.ink2)
                .multilineTextAlignment(.center)

            if let url = sharedPosterURL {
                // Real rendered PNG — ShareLink picks up the file URL and
                // presents the system sheet for AirDrop / Messages / WeChat.
                ShareLink(
                    item: url,
                    subject: Text("我的 Glassbook \(stats.year) 年度回顾"),
                    message: Text("#GlassbookWrapped — 我是\(stats.topPersona)!")
                ) {
                    shareButtonLabel
                }
                .padding(.horizontal, 28)
            } else {
                Button {
                    Task { await renderPoster() }
                } label: {
                    if isRendering {
                        ProgressView().tint(.white)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(RoundedRectangle(cornerRadius: 14).fill(AppColors.ink))
                    } else {
                        shareButtonLabel
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 28)
            }

            Spacer()
            Spacer()
        }
    }

    private var shareButtonLabel: some View {
        HStack(spacing: 8) {
            Image(systemName: "square.and.arrow.up")
            Text(sharedPosterURL == nil ? "生成分享海报" : "分享海报")
                .font(.system(size: 14, weight: .medium))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, minHeight: 50)
        .background(RoundedRectangle(cornerRadius: 14).fill(AppColors.ink))
    }

    /// Renders the full 1080×1920 poster (3x resolution) via ImageRenderer and
    /// writes it to a temp file so ShareLink can hand it off.
    @MainActor
    private func renderPoster() async {
        isRendering = true
        defer { isRendering = false }

        let posterView = posterThumbnail.frame(width: 360, height: 640)
        let renderer = ImageRenderer(content: posterView)
        renderer.scale = 3.0  // 1080 × 1920 final pixel count

        guard let ui = renderer.uiImage,
              let data = ui.pngData() else {
            print("⚠️ AnnualWrap poster render failed")
            return
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Glassbook-Wrapped-\(stats.year).png")
        do {
            try data.write(to: url)
            sharedPosterURL = url
        } catch {
            print("⚠️ AnnualWrap poster write failed: \(error)")
        }
    }

    private var posterThumbnail: some View {
        ZStack {
            LinearGradient(colors: [AppColors.brandStart, AppColors.brandEnd, AppColors.auroraPurple],
                           startPoint: .topLeading, endPoint: .bottomTrailing)

            VStack(spacing: 20) {
                Spacer()
                Text("\(stats.year)")
                    .font(.system(size: 20, weight: .light)).tracking(4)
                    .foregroundStyle(.white.opacity(0.7))
                Text("WRAPPED").font(.system(size: 36, weight: .medium)).tracking(2)
                    .foregroundStyle(.white)
                Text(stats.topPersona)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 5)
                    .background(Capsule().fill(.white.opacity(0.25)))
                Spacer()
                Text(Money.yuan(stats.totalExpenseCents, showDecimals: false))
                    .font(.system(size: 36, weight: .ultraLight).monospacedDigit())
                    .foregroundStyle(.white)
                Text("年度总支出").font(.system(size: 11, weight: .medium)).tracking(1.6)
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
                Text("Glassbook").font(.system(size: 10, weight: .medium)).tracking(2)
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.bottom, 20)
            }
            .padding(.horizontal, 24)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }
}

#Preview {
    AnnualWrapView().environment(AppStore())
}
