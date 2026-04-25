import SwiftUI
import PhotosUI
import UIKit

// MARK: - Screen 1 · Entry

struct SmartImportEntryScreen: View {
    var onCancel: () -> Void
    /// User tapped a specific platform's row — runs the hard-coded demo bill
    /// through that platform's parser. No real OCR.
    var onDemo: (ImportBatch.Platform) -> Void
    /// Single-image real OCR — still used by the "识别最新截屏" one-tap path,
    /// since there's only ever one "latest" screenshot.
    var onRealImage: (UIImage, ImportBatch.Platform?) -> Void
    /// Multi-image real OCR — PhotosPicker lets the user pick up to 10
    /// screenshots, each gets its own OCR pass, results merge into one
    /// confirm sheet with cross-image dedup.
    var onRealImages: ([UIImage], ImportBatch.Platform?) -> Void

    /// PhotosPicker accepts an array; we treat 0 / 1 / many uniformly by
    /// handing everything to `onRealImages`. Kept as `[PhotosPickerItem]`
    /// rather than `PhotosPickerItem?` so `maxSelectionCount > 1` works.
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var pickerError: String?
    @State private var pickerLoading: Bool = false
    @State private var latestPreview: LatestScreenshotService.Result?
    @State private var latestError: String?
    @State private var latestLoading: Bool = false

    @Environment(\.horizontalSizeClass) private var hSizeClass

    var body: some View {
        VStack(spacing: 0) {
            nav
            ScrollView {
                VStack(spacing: 14) {
                    hero
                    Text("演示模式 · 点击平台试跑").eyebrowStyle()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 8).padding(.top, 4)
                    platformList
                    realOCRSection
                    tipCard
                    Spacer().frame(height: 20)
                }
                .padding(.horizontal, 18)
                // why: keep the import column readable on iPad / Mac.
                .frame(maxWidth: hSizeClass == .regular ? 640 : .infinity)
                .frame(maxWidth: .infinity)
            }
        }
        .safeAreaPadding(.top, 8)
        .onChange(of: pickerItems) { _, items in
            guard !items.isEmpty else { return }
            Task { await handle(items: items, hint: nil) }
        }
    }

    /// Load every picked image with capped concurrency (full HEIC decode of
    /// 10 iPhone screenshots at once was pinning a 6-core phone and stalling
    /// the main thread). One failed image is surfaced inline but doesn't
    /// abort the rest — better to scan 9 of 10 than fail the whole pick.
    private static let maxImageLoadConcurrency = 3

    private func handle(items: [PhotosPickerItem], hint: ImportBatch.Platform?) async {
        await MainActor.run { pickerLoading = true; pickerError = nil }
        defer { Task { @MainActor in pickerLoading = false; pickerItems = [] } }

        var loaded: [UIImage] = []
        var failures: Int = 0
        await withTaskGroup(of: UIImage?.self) { group in
            var nextIndex = 0
            var inFlight = 0
            let total = items.count

            while inFlight < Self.maxImageLoadConcurrency && nextIndex < total {
                let item = items[nextIndex]; nextIndex += 1; inFlight += 1
                group.addTask { await Self.loadImage(from: item) }
            }
            while let img = await group.next() {
                if let img { loaded.append(img) } else { failures += 1 }
                inFlight -= 1
                if nextIndex < total {
                    let item = items[nextIndex]; nextIndex += 1; inFlight += 1
                    group.addTask { await Self.loadImage(from: item) }
                }
            }
        }

        await MainActor.run {
            if loaded.isEmpty {
                pickerError = "这些图片都读不出来,换一批再试"
                return
            }
            if failures > 0 {
                pickerError = "其中 \(failures) 张读取失败,跳过继续扫描剩下 \(loaded.count) 张"
            }
            onRealImages(loaded, hint)
        }
    }

    /// One `PhotosPickerItem` → `UIImage`, nil on failure. Shared by the
    /// capped loader above. Uses a task-local autoreleasepool so decoded
    /// JPEG/HEIC data isn't held past this one item.
    private static func loadImage(from item: PhotosPickerItem) async -> UIImage? {
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { return nil }
            return autoreleasepool { UIImage(data: data) }
        } catch {
            return nil
        }
    }

    private var nav: some View {
        HStack {
            Button(action: onCancel) {
                Image(systemName: "xmark").font(.system(size: 13))
                    .frame(width: 34, height: 34)
                    .glassCard(radius: 12)
                    .foregroundStyle(AppColors.ink)
            }
            Spacer()
            Text("智能识别").font(.system(size: 16, weight: .medium))
            Spacer()
            Spacer().frame(width: 34)
        }
        .padding(.horizontal, 18).padding(.vertical, 8)
    }

    private var hero: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [Color(hex: 0x1677FF), Color(hex: 0xC48AFF), Color(hex: 0x07C160)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 68, height: 68)
                    .shadow(color: Color(hex: 0x6450C8).opacity(0.35), radius: 16, y: 8)
                Image(systemName: "viewfinder").font(.system(size: 28))
                    .foregroundStyle(.white)
            }
            Text("从截图一键导入").font(.system(size: 18, weight: .medium))
            Text("Vision 本地识别  ·  自动去重  ·  导入后 7 天可撤销")
                .font(.system(size: 12)).foregroundStyle(AppColors.ink2)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 22).padding(.horizontal, 18)
        .frame(maxWidth: .infinity)
        .glassCard()
    }

    private var platformList: some View {
        VStack(spacing: 0) {
            ForEach(Array(ImportBatch.Platform.allCases.enumerated()), id: \.element) { idx, plat in
                if idx > 0 { Divider().background(AppColors.glassDivider).padding(.horizontal, 10) }
                Button {
                    onDemo(plat)
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 11).fill(LinearGradient.gradient(plat.gradient))
                            Text(plat.abbrev).font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        .frame(width: 36, height: 36)
                        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)

                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(plat.displayName).font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(AppColors.ink)
                                Text("演示").font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 5).padding(.vertical, 1)
                                    .background(Capsule().fill(AppColors.ink.opacity(0.5)))
                            }
                            Text(plat.supportedFormats).font(.system(size: 10))
                                .foregroundStyle(AppColors.ink3)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 12))
                            .foregroundStyle(AppColors.ink4)
                    }
                    .padding(.vertical, 11).padding(.horizontal, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .glassCard()
    }

    /// Real OCR — two entry points:
    ///   1. `latestScreenshotButton` pulls the most recent Screenshot asset
    ///      directly from Photos (one tap, no picker).
    ///   2. `PhotosPicker` fallback if the user wants to pick manually.
    private var realOCRSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("用真实截图识别 · 本地 Vision OCR").eyebrowStyle()
                .padding(.horizontal, 8)
                .padding(.top, 10)

            latestScreenshotButton
            pickerButton

            if let err = pickerError ?? latestError {
                Text(err).font(.system(size: 11)).foregroundStyle(AppColors.expenseRed)
            }
        }
        .task {
            // Show a preview of the latest screenshot the moment the sheet
            // opens, so the user knows what "识别最新截屏" will process.
            await refreshLatestPreview()
        }
    }

    private var latestScreenshotButton: some View {
        Button {
            Task { await tapLatestScreenshot() }
        } label: {
            HStack(spacing: 12) {
                thumbnail
                VStack(alignment: .leading, spacing: 2) {
                    Text("识别最新截屏").font(.system(size: 14, weight: .medium))
                    Text(latestSubtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.78))
                }
                Spacer()
                if latestLoading {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "sparkles").font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 62)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(LinearGradient(colors: [
                        Color(hex: 0x1677FF), Color(hex: 0x6450C8)
                    ], startPoint: .topLeading, endPoint: .bottomTrailing))
            )
        }
        .buttonStyle(.plain)
        .disabled(latestLoading)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let preview = latestPreview {
            Image(uiImage: preview.image)
                .resizable().scaledToFill()
                .frame(width: 38, height: 38)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.white.opacity(0.35), lineWidth: 0.8)
                )
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.18))
                Image(systemName: "rectangle.dashed").font(.system(size: 16))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .frame(width: 38, height: 38)
        }
    }

    private var latestSubtitle: String {
        if let preview = latestPreview { return preview.ageLabel + " · 点一下就开始 OCR" }
        if latestLoading               { return "正在读相册…" }
        return "点一下从相册自动拿最近一张截屏"
    }

    private var pickerButton: some View {
        PhotosPicker(selection: $pickerItems,
                     maxSelectionCount: 10,
                     matching: .images) {
            HStack(spacing: 10) {
                ZStack {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 14))
                        .foregroundStyle(AppColors.ink2)
                    if pickerLoading {
                        Circle().trim(from: 0, to: 0.65)
                            .stroke(AppColors.ink, lineWidth: 1.5)
                            .frame(width: 22, height: 22)
                            .rotationEffect(.degrees(pickerLoading ? 360 : 0))
                            .animation(.linear(duration: 0.9).repeatForever(autoreverses: false),
                                       value: pickerLoading)
                    }
                }
                .frame(width: 28, height: 28)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.55)))
                VStack(alignment: .leading, spacing: 2) {
                    Text("从相册批量选图").font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppColors.ink)
                    Text("最多 10 张 · 一次 OCR + 跨图去重 + 合并确认")
                        .font(.system(size: 10))
                        .foregroundStyle(AppColors.ink3)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundStyle(AppColors.ink3)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .glassCard(radius: 14)
        .disabled(pickerLoading)
    }

    private func refreshLatestPreview() async {
        latestLoading = true
        defer { latestLoading = false }
        do {
            let result = try await LatestScreenshotService.fetchLatest()
            await MainActor.run {
                latestPreview = result
                latestError = nil
            }
        } catch let e as LatestScreenshotService.Failure {
            await MainActor.run { latestError = e.errorDescription; latestPreview = nil }
        } catch {
            await MainActor.run { latestError = error.localizedDescription }
        }
    }

    private func tapLatestScreenshot() async {
        // If we already have a fresh preview, skip re-fetching and fire OCR now.
        if let preview = latestPreview {
            onRealImage(preview.image, nil)
            return
        }
        await refreshLatestPreview()
        if let preview = latestPreview {
            onRealImage(preview.image, nil)
        }
    }

    private var tipCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lock.shield").font(.system(size: 16))
                .foregroundStyle(AppColors.ink2)
                .frame(width: 30, height: 30)
                .background(Circle().fill(Color.white.opacity(0.5)))
            VStack(alignment: .leading, spacing: 4) {
                Text("端到端隐私").font(.system(size: 12, weight: .medium))
                Text("所有 OCR 识别在本设备完成,图片原图不上传服务器。")
                    .font(.system(size: 11)).foregroundStyle(AppColors.ink2)
                    .lineSpacing(2)
            }
        }
        .padding(16)
        .glassCard(radius: 14)
    }
}
