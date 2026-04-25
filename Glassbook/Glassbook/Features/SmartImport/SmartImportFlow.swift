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
