import SwiftUI
import PhotosUI

/// Receipt OCR flow — picker → scanning → editable result.
/// Result bubbles back via the `onConfirm` callback so the caller (AddTransaction)
/// can prefill its form.
struct ReceiptScanSheet: View {
    var onConfirm: (ReceiptOCRService.Result) -> Void
    var onCancel: () -> Void

    @State private var step: Step = .entry
    @State private var pickerItem: PhotosPickerItem?
    @State private var image: UIImage?
    @State private var result: ReceiptOCRService.Result?
    @State private var errorMessage: String?

    enum Step { case entry, scanning, review }

    var body: some View {
        ZStack {
            AuroraBackground(palette: .add)

            Group {
                switch step {
                case .entry:    entryView
                case .scanning: scanningView
                case .review:   reviewView
                }
            }
            .transition(.opacity.combined(with: .move(edge: .trailing)))
        }
    }

    // MARK: - Entry

    private var entryView: some View {
        VStack(spacing: 16) {
            header(title: "扫描收据", closeAction: onCancel)
            Spacer().frame(height: 8)

            ZStack {
                Circle()
                    .fill(LinearGradient.brand())
                    .frame(width: 88, height: 88)
                    .shadow(color: AppColors.brandStart.opacity(0.35), radius: 20, y: 10)
                Image(systemName: "doc.text.viewfinder")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(.white)
            }
            .padding(.vertical, 12)

            Text("从相册挑张收据截图").font(.system(size: 18, weight: .medium))
            Text("Vision 本地识别 · 提取金额 / 商户 / 明细\n图片不上传任何服务器")
                .multilineTextAlignment(.center)
                .font(.system(size: 12))
                .foregroundStyle(AppColors.ink2)
                .lineSpacing(3)

            Spacer()

            PhotosPicker(selection: $pickerItem, matching: .images) {
                Label("从相册选择", systemImage: "photo.on.rectangle")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AppColors.ink)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .glassCard(radius: 14)
            }
            .onChange(of: pickerItem) { _, item in
                Task { await handlePick(item) }
            }

            Button {
                result = ReceiptOCRService.fakeReceipt()
                withAnimation { step = .review }
            } label: {
                VStack(spacing: 2) {
                    Text("使用示例收据 · 跳过 Vision")
                        .font(.system(size: 13))
                        .foregroundStyle(AppColors.ink2)
                    Text("(不调用 OCR,仅用于演示流程)")
                        .font(.system(size: 10))
                        .foregroundStyle(AppColors.ink3)
                }
                .padding(.top, 4)
            }
            .padding(.bottom, 24)

            if let err = errorMessage {
                Text(err).font(.system(size: 11))
                    .foregroundStyle(AppColors.expenseRed)
                    .padding(.bottom, 8)
            }
        }
        .padding(.horizontal, 24)
    }

    private func handlePick(_ item: PhotosPickerItem?) async {
        guard let item,
              let data = try? await item.loadTransferable(type: Data.self),
              let ui = UIImage(data: data) else {
            errorMessage = "无法读取照片。"
            return
        }
        image = ui
        errorMessage = nil
        withAnimation { step = .scanning }
        do {
            let r = try await ReceiptOCRService.recognize(image: ui)
            await MainActor.run {
                self.result = r
                withAnimation { self.step = .review }
            }
        } catch {
            await MainActor.run {
                errorMessage = "识别失败:\(error.localizedDescription)"
                withAnimation { step = .entry }
            }
        }
    }

    // MARK: - Scanning

    private var scanningView: some View {
        VStack(spacing: 24) {
            header(title: "识别中", closeAction: { withAnimation { step = .entry } })
            Spacer()

            if let image {
                ZStack {
                    Image(uiImage: image)
                        .resizable().aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 240, maxHeight: 360)
                        .clipShape(RoundedRectangle(cornerRadius: 22))
                        .shadow(color: .black.opacity(0.15), radius: 20, y: 12)
                    Rectangle().fill(.white.opacity(0.85))
                        .frame(height: 3).blur(radius: 4)
                        .shadow(color: .white, radius: 8)
                        .offset(y: scanOffset)
                        .onAppear {
                            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                                scanOffset = 150
                            }
                        }
                }
            } else {
                ProgressView()
            }

            HStack(spacing: 10) {
                Circle().fill(AppColors.brandStart).frame(width: 10, height: 10)
                Text("Vision 本地识别中…").font(.system(size: 14, weight: .medium))
            }
            .padding(.horizontal, 20).padding(.vertical, 12)
            .glassCard(radius: 14)

            Spacer()
        }
        .padding(.horizontal, 24)
    }
    @State private var scanOffset: CGFloat = -150

    // MARK: - Review

    private var reviewView: some View {
        VStack(spacing: 14) {
            header(title: result?.isEmpty == true ? "未识别到内容" : "确认识别",
                   closeAction: { withAnimation { step = .entry } })
            ScrollView {
                VStack(spacing: 12) {
                    if result?.isEmpty == true {
                        emptyStateCard
                        rawTextCard   // still show OCR text so the user can see what was detected
                    } else {
                        partialWarning
                        amountCard
                        merchantCard
                        itemsCard
                        rawTextCard
                    }
                    Spacer().frame(height: 12)
                }
                .padding(.horizontal, 18)
            }
            confirmButton
        }
    }

    /// Shown when OCR returned nothing usable. Tells the user plainly what
    /// happened and offers a path forward instead of a confusing ¥0.00 page.
    private var emptyStateCard: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppColors.expenseRed.opacity(0.12))
                    .frame(width: 88, height: 88)
                Image(systemName: "questionmark.viewfinder")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(AppColors.expenseRed)
            }
            VStack(spacing: 6) {
                Text("这张图里没找到金额")
                    .font(.system(size: 17, weight: .medium))
                Text("可能是图片太模糊、被裁剪,或者不是收据。\n试试换一张更清晰 / 更完整的图。")
                    .multilineTextAlignment(.center)
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.ink2)
                    .lineSpacing(3)
            }
            Button {
                result = nil
                errorMessage = nil
                withAnimation { step = .entry }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                    Text("换一张再扫").font(.system(size: 14, weight: .medium))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(RoundedRectangle(cornerRadius: 14).fill(AppColors.ink))
            }
            .buttonStyle(.plain)
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .glassCard()
    }

    /// Banner shown when amount was recognized but some fields are missing —
    /// partial success, not empty. User still needs to fill gaps.
    @ViewBuilder private var partialWarning: some View {
        if let r = result, r.amountCents != nil, r.merchant == nil || r.merchant?.isEmpty == true {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(AppColors.auroraAmber)
                Text("识别不完整 · 金额找到了,但商户需要你手动填")
                    .font(.system(size: 11))
                    .foregroundStyle(AppColors.ink2)
                Spacer()
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .glassCard(radius: 12)
        }
    }

    private var amountCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("合计金额").eyebrowStyle()
            HStack(alignment: .top, spacing: 4) {
                Text("¥").font(.system(size: 22)).foregroundStyle(AppColors.ink2).padding(.top, 6)
                Text(formatYuan(result?.amountCents ?? 0))
                    .font(.system(size: 42, weight: .ultraLight).monospacedDigit())
            }
            if let d = result?.date {
                Text(Self.dateFmt.string(from: d))
                    .font(.system(size: 11)).foregroundStyle(AppColors.ink3)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private var merchantCard: some View {
        HStack(spacing: 12) {
            if let slug = result?.suggestedCategory {
                CategoryIconTile(category: Category.by(slug), size: 40)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("商户").eyebrowStyle()
                Text(result?.merchant ?? "—")
                    .font(.system(size: 14, weight: .medium))
                if let slug = result?.suggestedCategory {
                    Text("归入 \(Category.by(slug).name)")
                        .font(.system(size: 10))
                        .foregroundStyle(AppColors.ink3)
                }
            }
            Spacer()
        }
        .padding(16)
        .glassCard()
    }

    @ViewBuilder private var itemsCard: some View {
        if let items = result?.items, !items.isEmpty {
            VStack(spacing: 0) {
                HStack {
                    Text("明细 · \(items.count) 项").eyebrowStyle()
                    Spacer()
                }
                .padding(.horizontal, 14).padding(.top, 14).padding(.bottom, 8)
                ForEach(items) { item in
                    HStack {
                        Text(item.name).font(.system(size: 13))
                        Spacer()
                        Text(Money.yuan(item.amountCents, showDecimals: true))
                            .font(.system(size: 12, weight: .medium).monospacedDigit())
                    }
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    if items.last != item {
                        Divider().background(AppColors.glassDivider).padding(.horizontal, 14)
                    }
                }
                Spacer().frame(height: 10)
            }
            .glassCard()
        }
    }

    @ViewBuilder private var rawTextCard: some View {
        let text = result?.rawText ?? []
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: text.isEmpty ? "eye.slash" : "eye")
                    .font(.system(size: 11))
                    .foregroundStyle(text.isEmpty ? AppColors.expenseRed : AppColors.incomeGreen)
                Text("Apple Vision 识别结果 · \(text.count) 行").eyebrowStyle()
            }
            if text.isEmpty {
                Text("这张图里 Vision 一行字都没读到。通常是图片太模糊、光线太暗、或者不是文字图片。")
                    .font(.system(size: 11))
                    .foregroundStyle(AppColors.ink2)
                    .lineSpacing(2)
                    .padding(.top, 2)
            } else {
                Text(text.joined(separator: "\n"))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(AppColors.ink3)
                    .lineSpacing(2)
                    .textSelection(.enabled)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: 14)
    }

    @ViewBuilder private var confirmButton: some View {
        // Hide the "use result" button entirely in the empty state — the retry
        // button inside the empty card is the right affordance.
        if result?.isEmpty != true {
            let enabled = (result?.amountCents ?? 0) > 0
            Button {
                guard let r = result else { return }
                onConfirm(r)
            } label: {
                Text(enabled ? "使用识别结果" : "金额未识别 · 无法继续")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(enabled ? AppColors.ink : AppColors.ink.opacity(0.35))
                    )
            }
            .buttonStyle(.plain)
            .disabled(!enabled)
            .padding(.horizontal, 18)
            .padding(.bottom, 14)
        }
    }

    // MARK: - Shared

    private func header(title: String, closeAction: @escaping () -> Void) -> some View {
        HStack {
            Button(action: closeAction) {
                Image(systemName: "xmark").font(.system(size: 13))
                    .frame(width: 34, height: 34)
                    .glassCard(radius: 12)
                    .foregroundStyle(AppColors.ink)
            }
            Spacer()
            Text(title).font(.system(size: 16, weight: .medium))
            Spacer()
            Spacer().frame(width: 34)
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
    }

    private func formatYuan(_ cents: Int) -> String {
        let y = cents / 100; let f = cents % 100
        let fmt = NumberFormatter(); fmt.numberStyle = .decimal
        let body = fmt.string(from: NSNumber(value: y)) ?? "\(y)"
        return "\(body).\(String(format: "%02d", f))"
    }

    private static let dateFmt: DateFormatter = {
        let f = DateFormatter()
        f.locale = .init(identifier: "zh_CN")
        f.dateFormat = "yyyy年M月d日 HH:mm"
        return f
    }()
}

#Preview {
    ReceiptScanSheet(onConfirm: { _ in }, onCancel: {})
}
