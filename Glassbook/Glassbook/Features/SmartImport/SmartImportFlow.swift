import SwiftUI
import PhotosUI
import UIKit

/// Spec §5.3 · 4-screen smart-import coordinator.
struct SmartImportFlow: View {
    @Binding var isPresented: Bool
    @Environment(AppStore.self) private var store

    @State private var step: Step = .entry
    @State private var progress: Double = 0
    @State private var pendingRows: [PendingImportRow] = []
    @State private var platform: ImportBatch.Platform = .alipay
    @State private var committedBatchID: UUID?
    @State private var emptyReason: String = ""

    enum Step { case entry, scanning, confirm, done, empty }

    var body: some View {
        ZStack {
            AuroraBackground(palette: palette)
                .animation(.easeInOut(duration: 0.4), value: step)

            Group {
                switch step {
                case .entry:
                    SmartImportEntryScreen(
                        onCancel: { isPresented = false },
                        onDemo: { plat in
                            platform = plat
                            step = .scanning
                            runDemoScan()
                        },
                        onRealImage: { image, filterHint in
                            platform = filterHint ?? .alipay
                            step = .scanning
                            runRealScan(image: image)
                        },
                        onRealImages: { images, filterHint in
                            platform = filterHint ?? .alipay
                            step = .scanning
                            runRealScanBatch(images: images)
                        }
                    )
                case .scanning:
                    SmartImportScanningScreen(
                        platform: platform,
                        progress: progress,
                        processedCount: Int(progress * Double(pendingRows.count)),
                        totalCount: pendingRows.count,
                        onCancel: { step = .entry }
                    )
                case .confirm:
                    SmartImportConfirmScreen(
                        platform: platform,
                        rows: $pendingRows,
                        onCancel: { step = .entry },
                        onConfirm: { commitAndAdvance() }
                    )
                case .done:
                    SmartImportDoneScreen(
                        summary: .init(
                            selectedCount: pendingRows.filter(\.isSelected).count,
                            totalExpenseCents: pendingRows.filter { $0.isSelected }.reduce(0) { $0 + $1.amountCents },
                            totalIncomeCents: 0,
                            spanDays: spanDays,
                            duplicates: pendingRows.filter(\.isDuplicate).count
                        ),
                        onImportAnother: {
                            committedBatchID = nil
                            pendingRows = []
                            step = .entry
                        },
                        onViewBills: { isPresented = false },
                        onRollback: rollback
                    )
                case .empty:
                    SmartImportEmptyScreen(
                        reason: emptyReason,
                        onRetry: {
                            emptyReason = ""
                            pendingRows = []
                            step = .entry
                        },
                        onCancel: { isPresented = false }
                    )
                }
            }
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .move(edge: .trailing)),
                removal: .opacity.combined(with: .move(edge: .leading))
            ))
        }
    }

    private var palette: AuroraPalette {
        switch step {
        case .entry:    .importBlue
        case .scanning: .importPurple
        case .confirm:  .importAmber
        case .done:     .importMint
        case .empty:    .importBlue
        }
    }

    /// Demo path: user tapped a platform row. No image involved — we feed the
    /// hard-coded sample lines for that platform through the parser pipeline so
    /// the flow can be demoed end-to-end in the simulator.
    private func runDemoScan() {
        progress = 0
        Task {
            let lines: [String] = {
                switch platform {
                case .alipay:   return VisionOCRService.fakeAlipayBill()
                case .wechat:   return VisionOCRService.fakeWeChatBill()
                case .cmb:      return VisionOCRService.fakeCMBBill()
                default:        return VisionOCRService.fakeAlipayBill()
                }
            }()
            let parser = ParserRegistry.pick(for: lines)
            let parsed = parser.parse(lines: lines)
            let dedupChecked = DedupEngine.markDuplicates(parsed, against: store.transactions)

            for p in stride(from: 0.0, through: 1.0, by: 0.08) {
                try? await Task.sleep(nanoseconds: 140_000_000)
                await MainActor.run { withAnimation { progress = p } }
            }
            try? await Task.sleep(nanoseconds: 240_000_000)
            await MainActor.run { advance(after: dedupChecked, gotLines: lines.count) }
        }
    }

    /// Real path: user picked an image from Photos. Run Apple Vision OCR on the
    /// real pixels, then auto-detect platform from the recognized text.
    /// No fake data, no sample fallback — if nothing is found the flow goes to
    /// `.empty` so the user can retry instead of seeing phantom transactions.
    private func runRealScan(image: UIImage) {
        progress = 0
        Task {
            do {
                // Kick off the OCR immediately, run the progress animation in parallel.
                async let ocrTask = VisionOCRService.recognize(image: image)
                for p in stride(from: 0.0, through: 0.9, by: 0.08) {
                    try? await Task.sleep(nanoseconds: 120_000_000)
                    await MainActor.run { withAnimation { progress = p } }
                }
                let lines = try await ocrTask
                await MainActor.run { withAnimation { progress = 1.0 } }

                // Auto-detect the platform from OCR text so the parser picks the
                // best regex rules. `ParserRegistry.pick` falls back to Alipay if
                // nothing matches.
                let parser = ParserRegistry.pick(for: lines)
                platform = parser.platform
                let parsed = parser.parse(lines: lines)
                let dedupChecked = DedupEngine.markDuplicates(parsed, against: store.transactions)

                await MainActor.run { advance(after: dedupChecked, gotLines: lines.count) }
            } catch {
                await MainActor.run {
                    emptyReason = "Vision 识别失败:\(error.localizedDescription)"
                    withAnimation(.easeInOut) { step = .empty }
                }
            }
        }
    }

    /// Batch path: user picked N images at once. Run Vision OCR with capped
    /// concurrency — unrestricted fan-out with 10 high-res screenshots
    /// exhausts phone RAM and stalls the main thread. Each slot returns
    /// (index, lines) so we can reassemble in original order and keep
    /// progress honest.
    private static let maxOCRConcurrency = 3

    private func runRealScanBatch(images: [UIImage]) {
        progress = 0
        Task {
            do {
                let ocrResults: [(Int, [String])] = try await withThrowingTaskGroup(of: (Int, [String]).self) { group in
                    var nextIndex = 0
                    var inFlight = 0
                    var collected: [(Int, [String])] = []
                    var finished = 0
                    let total = images.count

                    // Prime the pipe with up to `maxOCRConcurrency` tasks.
                    while inFlight < Self.maxOCRConcurrency && nextIndex < total {
                        let i = nextIndex; nextIndex += 1; inFlight += 1
                        let img = images[i]
                        group.addTask {
                            let lines = try await VisionOCRService.recognize(image: img)
                            return (i, lines)
                        }
                    }

                    // For each completion, enqueue the next task. Maintains
                    // a moving window of at most `maxOCRConcurrency` active.
                    while let pair = try await group.next() {
                        collected.append(pair)
                        inFlight -= 1
                        finished += 1
                        let p = Double(finished) / Double(max(1, total)) * 0.9
                        await MainActor.run { withAnimation { progress = p } }
                        if nextIndex < total {
                            let i = nextIndex; nextIndex += 1; inFlight += 1
                            let img = images[i]
                            group.addTask {
                                let lines = try await VisionOCRService.recognize(image: img)
                                return (i, lines)
                            }
                        }
                    }
                    return collected.sorted { $0.0 < $1.0 }
                }

                var allParsed: [PendingImportRow] = []
                var lineSum = 0
                var detectedPlatform: ImportBatch.Platform? = nil
                for (_, lines) in ocrResults {
                    lineSum += lines.count
                    let parser = ParserRegistry.pick(for: lines)
                    if detectedPlatform == nil { detectedPlatform = parser.platform }
                    allParsed.append(contentsOf: parser.parse(lines: lines))
                }

                await MainActor.run { withAnimation { progress = 1.0 } }

                // Intra-batch dedup first (two screenshots of the same list
                // overlap), then compare against existing store transactions.
                let intra = intraBatchDedup(allParsed)
                let deduped = DedupEngine.markDuplicates(intra, against: store.transactions)
                platform = detectedPlatform ?? .alipay
                await MainActor.run { advance(after: deduped, gotLines: lineSum) }
            } catch {
                await MainActor.run {
                    emptyReason = "Vision 识别失败:\(error.localizedDescription)"
                    withAnimation(.easeInOut) { step = .empty }
                }
            }
        }
    }

    /// Mark later rows with the same (amountCents, merchant, timestamp to the
    /// minute) as duplicates of the first occurrence and auto-deselect them.
    /// User can still tick them back on in the confirm screen if they really
    /// are separate transactions that happened at the same moment.
    private func intraBatchDedup(_ rows: [PendingImportRow]) -> [PendingImportRow] {
        var seen: Set<String> = []
        var out: [PendingImportRow] = []
        for row in rows {
            let minuteBucket = Int(row.timestamp.timeIntervalSince1970 / 60)
            let key = "\(row.amountCents)|\(minuteBucket)|\(row.merchant)"
            if seen.contains(key) {
                var dup = row
                dup.isDuplicate = true
                dup.isSelected = false
                out.append(dup)
            } else {
                seen.insert(key)
                out.append(row)
            }
        }
        return out
    }

    /// Common post-parse branch: show confirm if we got rows, empty if not.
    private func advance(after rows: [PendingImportRow], gotLines: Int) {
        if rows.isEmpty {
            emptyReason = gotLines == 0
                ? "这张图里 Vision 一行字都没读到。图可能太模糊,或者不是账单截图。"
                : "读到了 \(gotLines) 行文本,但没有匹配上支付宝 / 微信 / 招行的账单格式。可以去记一笔手动录入。"
            pendingRows = []
            withAnimation(.easeInOut) { step = .empty }
        } else {
            pendingRows = rows
            withAnimation(.easeInOut) { step = .confirm }
        }
    }

    private func commitAndAdvance() {
        committedBatchID = store.importBatch(rows: pendingRows, platform: platform)
        // Persist any merchant→category overrides the user made during confirm.
        for row in pendingRows where row.isSelected {
            MerchantClassifier.shared.remember(merchant: row.merchant, as: row.categoryID)
        }
        withAnimation(.easeInOut) { step = .done }
    }

    private func rollback() {
        if let id = committedBatchID {
            store.rollbackBatch(id)
            committedBatchID = nil
        }
        isPresented = false
    }

    private var spanDays: Int {
        let sel = pendingRows.filter(\.isSelected)
        guard let minDate = sel.map(\.timestamp).min(),
              let maxDate = sel.map(\.timestamp).max() else { return 0 }
        return Calendar.current.dateComponents([.day], from: minDate, to: maxDate).day.map { $0 + 1 } ?? 1
    }
}

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

// MARK: - Screen 3 · Confirm (the money screen)

struct SmartImportConfirmScreen: View {
    let platform: ImportBatch.Platform
    @Binding var rows: [PendingImportRow]
    var onCancel: () -> Void
    var onConfirm: () -> Void
    @State private var editingRowID: PendingImportRow.ID?
    @State private var aiClassifying: Bool = false
    @State private var aiError: String?
    @State private var aiAppliedCount: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            nav
            summary
            batchBar
            ScrollView {
                VStack(spacing: 0) {
                    ForEach($rows) { $row in
                        confirmRow($row: $row)
                        if rows.last?.id != row.id {
                            Divider().background(AppColors.glassDivider).padding(.horizontal, 10)
                        }
                    }
                }
                .padding(6)
                .glassCard()
                .padding(.horizontal, 18)
            }
            .scrollIndicators(.hidden)

            confirmButton
        }
        .safeAreaPadding(.top, 8)
        .sheet(item: Binding(
            get: { editingRowID.flatMap { id in rows.first { $0.id == id } } },
            set: { new in editingRowID = new?.id }
        )) { row in
            if let idx = rows.firstIndex(where: { $0.id == row.id }) {
                EditPendingRowSheet(row: $rows[idx]) { editingRowID = nil }
            }
        }
    }

    private var nav: some View {
        HStack {
            Button(action: onCancel) {
                Image(systemName: "chevron.left").font(.system(size: 13))
                    .frame(width: 34, height: 34)
                    .glassCard(radius: 12)
                    .foregroundStyle(AppColors.ink)
            }
            Spacer()
            Text("确认导入").font(.system(size: 16, weight: .medium))
            Spacer()
            Spacer().frame(width: 34)
        }
        .padding(.horizontal, 18).padding(.vertical, 8)
    }

    private var summary: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(LinearGradient.gradient(platform.gradient))
                Text(platform.abbrev).font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text("识别到 \(rows.count) 笔  ·  \(platform.displayName)")
                    .font(.system(size: 12, weight: .medium))
                Text(Money.yuan(totalCents, showDecimals: true))
                    .font(.system(size: 20, weight: .light).monospacedDigit())
                    .foregroundStyle(AppColors.ink)
            }
            Spacer()
        }
        .padding(16)
        .glassCard()
        .padding(.horizontal, 18).padding(.vertical, 8)
    }

    private var totalCents: Int { rows.reduce(0) { $0 + $1.amountCents } }

    private var batchBar: some View {
        VStack(spacing: 6) {
            HStack {
                Text("已选 \(selectedCount)/\(rows.count)")
                    .font(.system(size: 11)).foregroundStyle(AppColors.ink2)
                Spacer()
                Button { Task { await runAIClassify() } } label: {
                    HStack(spacing: 4) {
                        if aiClassifying {
                            ProgressView().controlSize(.mini).tint(.white)
                        } else {
                            Image(systemName: "sparkles").font(.system(size: 10))
                        }
                        Text(aiClassifying ? "AI 分类中…" : "AI 自动分类")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Capsule().fill(LinearGradient.brand()))
                }
                .buttonStyle(.plain)
                .disabled(aiClassifying || rows.isEmpty)
                .opacity(aiClassifying ? 0.6 : 1)
                Button { toggleAll() } label: {
                    Text(selectedCount == rows.count ? "取消全选" : "全选")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(AppColors.ink)
                }
            }
            if let msg = aiError {
                Text(msg).font(.system(size: 10))
                    .foregroundStyle(AppColors.expenseRed)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            } else if aiAppliedCount > 0 {
                Text("✓ AI 重新分类了 \(aiAppliedCount) 笔")
                    .font(.system(size: 10))
                    .foregroundStyle(AppColors.successGreen)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 26).padding(.vertical, 8)
    }

    private func runAIClassify() async {
        aiClassifying = true
        aiError = nil
        aiAppliedCount = 0
        defer { aiClassifying = false }
        do {
            let assigned = try await LLMClassifier.categorize(rows)
            var changed = 0
            for i in rows.indices {
                if let newCat = assigned[rows[i].id], newCat != rows[i].categoryID {
                    rows[i].categoryID = newCat
                    changed += 1
                }
            }
            aiAppliedCount = changed
            if changed == 0 && assigned.isEmpty {
                aiError = "AI 没返回有效结果 · 请换个模型"
            }
        } catch let e as LLMClassifier.Failure {
            aiError = e.errorDescription
        } catch {
            aiError = error.localizedDescription
        }
    }

    private var selectedCount: Int { rows.filter(\.isSelected).count }

    private func toggleAll() {
        let allSelected = selectedCount == rows.count
        for i in rows.indices { rows[i].isSelected = !allSelected }
    }

    private func confirmRow(@Binding row: PendingImportRow) -> some View {
        let cat = Category.by(row.categoryID)
        return HStack(spacing: 10) {
            Button {
                row.isSelected.toggle()
            } label: {
                Image(systemName: row.isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(row.isSelected ? AppColors.ink : AppColors.ink3)
            }
            .buttonStyle(.plain)

            Button {
                editingRowID = row.id
            } label: {
                HStack(spacing: 10) {
                    CategoryIconTile(category: cat, size: 30)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.merchant).font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppColors.ink)
                            .lineLimit(1)
                        HStack(spacing: 4) {
                            Text(cat.name).font(.system(size: 10))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Capsule().fill(LinearGradient.gradient(cat.gradient)))
                            if row.isDuplicate {
                                Text("已存在").font(.system(size: 9))
                                    .foregroundStyle(AppColors.expenseRed)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(Capsule().fill(AppColors.expenseRed.opacity(0.15)))
                            }
                            Text(Self.time.string(from: row.timestamp))
                                .font(.system(size: 9)).foregroundStyle(AppColors.ink3)
                        }
                    }
                    Spacer(minLength: 4)
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(Money.yuan(row.amountCents, showDecimals: false))
                            .font(.system(size: 13, weight: .medium).monospacedDigit())
                            .foregroundStyle(row.isDuplicate ? AppColors.ink3 : AppColors.ink)
                        Image(systemName: "pencil")
                            .font(.system(size: 9))
                            .foregroundStyle(AppColors.ink3)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 10).padding(.horizontal, 8)
        .opacity(row.isDuplicate && !row.isSelected ? 0.6 : 1)
    }

    private var confirmButton: some View {
        Button(action: onConfirm) {
            Text("导入选中交易  [ \(selectedCount) 笔 ]")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(RoundedRectangle(cornerRadius: 14).fill(AppColors.ink))
        }
        .buttonStyle(.plain)
        .padding(18)
    }

    private static let time: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M/d HH:mm"
        return f
    }()
}

// MARK: - Edit sheet · 改识别结果

/// Lets the user correct OCR slips using the SAME form as "新增记一笔"
/// (kind / keypad / visibility / category / mood / merchant+note / date).
/// Writes back into the @Binding — SmartImportConfirmScreen re-reads totals
/// + checkbox state automatically.
struct EditPendingRowSheet: View {
    @Binding var row: PendingImportRow
    var onDone: () -> Void

    var body: some View {
        RichTxFormView(
            title: "编辑识别结果",
            saveLabel: "保存",
            initial: .init(
                kind: row.kind,
                amountCents: row.amountCents,
                categoryID: row.categoryID,
                merchant: row.merchant,
                note: row.note ?? "",
                mood: row.mood,
                visibility: row.visibility,
                timestamp: row.timestamp
            ),
            showDatePicker: true,
            onCancel: { onDone() },
            onSave: { v in
                row.kind = v.kind
                row.amountCents = v.amountCents
                row.categoryID = v.categoryID
                let trimmed = v.merchant.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty { row.merchant = trimmed }
                row.note = v.note.isEmpty ? nil : v.note
                row.mood = v.mood
                row.visibility = v.visibility
                row.timestamp = v.timestamp
                onDone()
            }
        )
    }
}

// MARK: - Screen 4 · Done

struct SmartImportDoneScreen: View {
    struct Summary {
        let selectedCount: Int
        let totalExpenseCents: Int
        let totalIncomeCents: Int
        let spanDays: Int
        let duplicates: Int
    }
    let summary: Summary
    var onImportAnother: () -> Void
    var onViewBills: () -> Void
    var onRollback: (() -> Void)? = nil

    @State private var checkScale: CGFloat = 0.3
    @State private var glow: CGFloat = 0

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle().fill(AppColors.successGreen.opacity(0.25))
                    .frame(width: 160, height: 160).blur(radius: 25)
                    .scaleEffect(glow)
                Circle().fill(AppColors.successGreen.opacity(0.2))
                    .frame(width: 110, height: 110)
                Circle().fill(AppColors.successGreen)
                    .frame(width: 78, height: 78)
                Image(systemName: "checkmark")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(.white)
                    .scaleEffect(checkScale)
            }
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.5)) { checkScale = 1 }
                withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) { glow = 1.2 }
            }

            VStack(spacing: 6) {
                Text("成功导入 \(summary.selectedCount) 笔")
                    .font(.system(size: 22, weight: .medium))
                Text("已自动去重 \(summary.duplicates) 笔")
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.ink2)
            }

            summaryCard
                .padding(.horizontal, 18)

            if let onRollback {
                Button(action: onRollback) {
                    Text("撤销整批 (7 天内可恢复)")
                        .font(.system(size: 11))
                        .foregroundStyle(AppColors.ink3)
                        .underline()
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }

            Spacer()

            HStack(spacing: 10) {
                Button(action: onImportAnother) {
                    Text("再导一批")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppColors.ink)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.6)))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(AppColors.glassBorder, lineWidth: 1))
                }
                Button(action: onViewBills) {
                    Text("查看账单")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(RoundedRectangle(cornerRadius: 14).fill(AppColors.ink))
                }
            }
            .buttonStyle(.plain)
            .padding(18)
        }
    }

    private var summaryCard: some View {
        HStack(spacing: 0) {
            cell("合计支出", Money.yuan(summary.totalExpenseCents, showDecimals: false))
            Divider().background(AppColors.glassDivider)
            cell("跨越日期", "\(summary.spanDays) 天")
            Divider().background(AppColors.glassDivider)
            cell("去重", "\(summary.duplicates) 笔")
        }
        .padding(.vertical, 16)
        .glassCard()
    }

    private func cell(_ label: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(label).eyebrowStyle()
            Text(value).font(.system(size: 14, weight: .medium).monospacedDigit())
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview("Entry") {
    ZStack {
        AuroraBackground(palette: .importBlue)
        SmartImportEntryScreen(onCancel: {},
                               onDemo: { _ in },
                               onRealImage: { _, _ in },
                               onRealImages: { _, _ in })
    }
}
#Preview("Empty") {
    ZStack {
        AuroraBackground(palette: .importBlue)
        SmartImportEmptyScreen(reason: "Vision 没读到文字", onRetry: {}, onCancel: {})
    }
}
#Preview("Scanning") {
    ZStack {
        AuroraBackground(palette: .importPurple)
        SmartImportScanningScreen(platform: .alipay, progress: 0.67, processedCount: 5, totalCount: 8, onCancel: {})
    }
}
#Preview("Confirm") {
    StatefulPreview()
}
#Preview("Done") {
    ZStack {
        AuroraBackground(palette: .importMint)
        SmartImportDoneScreen(summary: .init(selectedCount: 7, totalExpenseCents: 42800, totalIncomeCents: 0, spanDays: 3, duplicates: 1), onImportAnother: {}, onViewBills: {}, onRollback: {})
    }
}

private struct StatefulPreview: View {
    @State var rows: [PendingImportRow] = SampleData.pendingImport
    var body: some View {
        ZStack {
            AuroraBackground(palette: .importAmber)
            SmartImportConfirmScreen(platform: .alipay, rows: $rows, onCancel: {}, onConfirm: {})
        }
    }
}
