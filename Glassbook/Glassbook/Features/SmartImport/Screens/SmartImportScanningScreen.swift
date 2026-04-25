import SwiftUI

// MARK: - Screen 2 · Scanning

struct SmartImportScanningScreen: View {
    let platform: ImportBatch.Platform
    let progress: Double
    let processedCount: Int
    let totalCount: Int
    var onCancel: () -> Void

    @State private var scanOffset: CGFloat = 0

    var body: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 40)

            ZStack {
                // Fake thumbnail
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(LinearGradient.gradient(platform.gradient))
                    .frame(width: 220, height: 340)
                    .shadow(color: .black.opacity(0.15), radius: 20, y: 12)
                    .overlay(thumbOverlay)

                // Scanning line
                Rectangle()
                    .fill(LinearGradient(colors: [Color.white.opacity(0), Color.white, Color.white.opacity(0)],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: 220, height: 3)
                    .shadow(color: .white, radius: 8)
                    .offset(y: scanOffset)

                // AI focus corners
                focusCorners
            }
            .frame(width: 260, height: 380)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                    scanOffset = -150
                }
            }

            statusCard

            HStack(spacing: 8) {
                miniStat("已识别", value: "\(processedCount) 笔")
                miniStat("金额", value: Money.yuan(processedCount * 4800, showDecimals: false))
                miniStat("已分类", value: String(format: "%.0f%%", min(1.0, progress) * 100))
            }
            .padding(.horizontal, 18)

            Spacer()

            Button(action: onCancel) {
                Text("取消扫描").font(.system(size: 13))
                    .foregroundStyle(AppColors.ink2)
                    .frame(width: 120, height: 42)
                    .background(Capsule().fill(Color.white.opacity(0.45)))
                    .overlay(Capsule().strokeBorder(AppColors.glassBorder, lineWidth: 1))
            }
            .padding(.bottom, 30)
        }
    }

    private var thumbOverlay: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(platform.displayName).font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
            ForEach(0..<6) { _ in
                Rectangle().fill(Color.white.opacity(0.35))
                    .frame(height: 10).cornerRadius(4)
            }
            Spacer()
        }
        .padding(18)
        .frame(width: 220, height: 340, alignment: .topLeading)
    }

    private var focusCorners: some View {
        ZStack {
            ForEach(0..<4, id: \.self) { idx in
                cornerMark
                    .rotationEffect(.degrees(Double(idx) * 90))
                    .offset(x: idx == 1 || idx == 2 ? 110 : -110,
                            y: idx >= 2 ? 170 : -170)
            }
        }
        .frame(width: 260, height: 380)
    }

    private var cornerMark: some View {
        Path { p in
            p.move(to: .init(x: 0, y: 20))
            p.addLine(to: .init(x: 0, y: 0))
            p.addLine(to: .init(x: 20, y: 0))
        }
        .stroke(Color.white, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
        .frame(width: 20, height: 20)
    }

    private var statusCard: some View {
        HStack(spacing: 12) {
            Circle().fill(AppColors.brandStart)
                .frame(width: 10, height: 10)
                .modifier(Pulse())
            Text("AI 正在识别…").font(.system(size: 13, weight: .medium))
            Spacer()
            Text(String(format: "%.0f%%", min(1.0, progress) * 100))
                .font(.system(size: 13, weight: .medium).monospacedDigit())
                .foregroundStyle(AppColors.ink2)
        }
        .padding(.horizontal, 18).padding(.vertical, 14)
        .glassCard(radius: 14)
        .padding(.horizontal, 18)
    }

    private func miniStat(_ label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(label).eyebrowStyle().font(.system(size: 9)).tracking(1.2)
            Text(value).font(.system(size: 13, weight: .medium).monospacedDigit())
        }
        .frame(maxWidth: .infinity, minHeight: 58)
        .glassCard(radius: 14)
    }
}

private struct Pulse: ViewModifier {
    @State private var scale: CGFloat = 1
    func body(content: Content) -> some View {
        content.scaleEffect(scale).onAppear {
            withAnimation(.easeInOut(duration: 0.9).repeatForever()) { scale = 1.4 }
        }
    }
}
