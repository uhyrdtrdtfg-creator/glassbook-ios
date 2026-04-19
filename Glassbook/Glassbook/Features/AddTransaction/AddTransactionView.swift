import SwiftUI

/// Spec §4.2 · 快速记账 + Spec v2 §6.3 § §5 (mood chips + per-tx privacy).
struct AddTransactionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var store

    var onPresentSmartImport: () -> Void = {}
    /// Opening with a receipt result auto-populates the form (amount / merchant
    /// / category / note / timestamp) so the user can review + edit before save.
    var prefill: ReceiptOCRService.Result? = nil

    @State private var kind: Transaction.Kind = .expense
    @State private var amountEntry = ""
    @State private var selectedCat: Category.Slug = .food
    @State private var merchant = ""
    @State private var note = ""
    @State private var selectedMood: Mood? = nil
    @State private var visibility: Visibility = .family
    @State private var scannedTimestamp: Date? = nil
    @State private var showConfetti = false
    @State private var showReceiptSheet = false
    @State private var cursorBlink = true
    @State private var didApplyPrefill = false
    @State private var prefillBannerVisible = false

    var body: some View {
        ZStack {
            AuroraBackground(palette: .add)

            ScrollView {
                VStack(spacing: 14) {
                    topBar
                    if prefillBannerVisible { prefillBanner }
                    kindToggle
                    amountCard
                    visibilityRow
                    categoryGrid
                    moodRow
                    merchantNoteCard
                    keypad
                    Spacer().frame(height: 16)
                }
                .padding(.horizontal, 18)
                .padding(.top, 16)
            }
            .scrollIndicators(.hidden)
            .onAppear {
                if !didApplyPrefill, let r = prefill {
                    applyReceipt(r)
                    didApplyPrefill = true
                    withAnimation(.easeInOut(duration: 0.3)) { prefillBannerVisible = true }
                }
            }

            if showConfetti {
                VStack {
                    Spacer()
                    Text("已记一笔 \(Money.yuan(amountCents, showDecimals: false))")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20).padding(.vertical, 12)
                        .background(Capsule().fill(AppColors.ink))
                        .padding(.bottom, 40)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sheet(isPresented: $showReceiptSheet) {
            ReceiptScanSheet(
                onConfirm: applyReceipt,
                onCancel: { showReceiptSheet = false }
            )
            .presentationDetents([.large])
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: 10) {
            Button { dismiss() } label: {
                Text("取消").font(.system(size: 12))
                    .foregroundStyle(AppColors.ink2)
                    .frame(width: 56, height: 28)
                    .background(Capsule().fill(Color.white.opacity(0.5)))
                    .overlay(Capsule().strokeBorder(AppColors.glassBorder, lineWidth: 1))
            }
            Spacer()
            Text("记一笔").font(.system(size: 14, weight: .medium))
            Spacer()
            HStack(spacing: 6) {
                Button { showReceiptSheet = true } label: {
                    Image(systemName: "doc.text.viewfinder")
                        .font(.system(size: 14))
                        .foregroundStyle(AppColors.ink)
                        .frame(width: 32, height: 28)
                        .background(Capsule().fill(Color.white.opacity(0.55)))
                        .overlay(Capsule().strokeBorder(AppColors.glassBorder, lineWidth: 1))
                }
                .accessibilityLabel("扫描收据")
                Button { onPresentSmartImport() } label: {
                    Image(systemName: "viewfinder")
                        .font(.system(size: 14))
                        .foregroundStyle(AppColors.ink)
                        .frame(width: 32, height: 28)
                        .background(Capsule().fill(Color.white.opacity(0.55)))
                        .overlay(Capsule().strokeBorder(AppColors.glassBorder, lineWidth: 1))
                }
                .accessibilityLabel("扫描账单截图")
                Button { save() } label: {
                    Text("保存").font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 28)
                        .background(Capsule().fill(AppColors.ink))
                }
                .disabled(amountCents == 0)
                .opacity(amountCents == 0 ? 0.4 : 1)
            }
        }
    }

    // MARK: - Prefill banner

    private var prefillBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.text.viewfinder")
                .font(.system(size: 13))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(Circle().fill(LinearGradient.brand()))
            VStack(alignment: .leading, spacing: 1) {
                Text("已从收据识别").font(.system(size: 11, weight: .medium))
                Text("\(prefill?.items.count ?? 0) 项明细 · 下方字段都可改").font(.system(size: 10))
                    .foregroundStyle(AppColors.ink3)
            }
            Spacer()
            Button { withAnimation { prefillBannerVisible = false } } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(AppColors.ink3)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .glassCard(radius: 14)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Kind toggle

    private var kindToggle: some View {
        HStack(spacing: 4) {
            ForEach(Transaction.Kind.allCases, id: \.self) { k in
                Button { kind = k } label: {
                    Text(label(for: k))
                        .font(.system(size: 12, weight: kind == k ? .medium : .regular))
                        .foregroundStyle(kind == k ? .white : AppColors.ink2)
                        .frame(maxWidth: .infinity, minHeight: 32)
                        .background(RoundedRectangle(cornerRadius: 10).fill(kind == k ? AppColors.ink : Color.clear))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .glassCard(radius: 14)
    }
    private func label(for k: Transaction.Kind) -> String {
        switch k { case .expense: "支出"; case .income: "收入"; case .transfer: "转账" }
    }

    // MARK: - Amount

    private var amountCard: some View {
        VStack(spacing: 10) {
            Text("金额").eyebrowStyle()
            HStack(alignment: .top, spacing: 4) {
                Text("¥").font(.system(size: 22))
                    .foregroundStyle(AppColors.ink3).padding(.top, 10)
                Text(amountDisplay)
                    .font(.system(size: 54, weight: .ultraLight).monospacedDigit())
                    .foregroundStyle(AppColors.ink)
                Rectangle()
                    .fill(AppColors.brandStart)
                    .frame(width: 2, height: 42)
                    .opacity(cursorBlink ? 1 : 0)
            }
        }
        .padding(.vertical, 22).padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .glassCard()
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6).repeatForever()) { cursorBlink.toggle() }
        }
    }

    private var amountDisplay: String { amountEntry.isEmpty ? "0" : amountEntry }
    private var amountCents: Int {
        guard let d = Decimal(string: amountEntry.isEmpty ? "0" : amountEntry) else { return 0 }
        return (d * 100 as NSDecimalNumber).intValue
    }

    // MARK: - Visibility (CKShare per-tx privacy)

    private var visibilityRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("👁 可见范围 · 按笔隐私").eyebrowStyle()
            HStack(spacing: 6) {
                ForEach(Visibility.allCases, id: \.self) { v in
                    Button { visibility = v } label: {
                        HStack(spacing: 6) {
                            Text(v.emoji).font(.system(size: 12))
                            Text(v.displayName)
                                .font(.system(size: 11, weight: visibility == v ? .medium : .regular))
                                .foregroundStyle(visibility == v ? .white : AppColors.ink)
                        }
                        .frame(maxWidth: .infinity, minHeight: 34)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(visibility == v ? AppColors.ink : Color.white.opacity(0.55))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(AppColors.glassBorder, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .glassCard(radius: 14)
    }

    // MARK: - Category grid (9 cats → 3×3)

    private var categoryGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
            ForEach(Category.all, id: \.id) { cat in
                Button { selectedCat = cat.id } label: {
                    VStack(spacing: 5) {
                        Text(cat.emoji).font(.system(size: 20))
                        Text(cat.name).font(.system(size: 10))
                            .foregroundStyle(selectedCat == cat.id ? AppColors.ink : AppColors.ink2)
                    }
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1.1, contentMode: .fit)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(selectedCat == cat.id ? Color.white.opacity(0.75) : Color.white.opacity(0.25))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(selectedCat == cat.id ? AppColors.ink : Color.clear, lineWidth: 1.2)
                    )
                    .fontWeight(selectedCat == cat.id ? .medium : .regular)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .glassCard()
    }

    // MARK: - Mood

    private var moodRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("😊 情绪").eyebrowStyle()
                Spacer()
                if selectedMood != nil {
                    Button("清除") { selectedMood = nil }
                        .font(.system(size: 10))
                        .foregroundStyle(AppColors.ink3)
                }
            }
            HStack(spacing: 6) {
                ForEach(Mood.allCases, id: \.self) { m in
                    Button { selectedMood = (selectedMood == m ? nil : m) } label: {
                        HStack(spacing: 4) {
                            Text(m.emoji).font(.system(size: 11))
                            Text(m.displayName)
                                .font(.system(size: 10, weight: selectedMood == m ? .medium : .regular))
                                .foregroundStyle(selectedMood == m ? .white : AppColors.ink)
                        }
                        .frame(maxWidth: .infinity, minHeight: 32)
                        .background(
                            Capsule().fill(selectedMood == m ? Color(hex: m.tintHex) : Color.white.opacity(0.55))
                        )
                        .overlay(Capsule().strokeBorder(AppColors.glassBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .glassCard(radius: 14)
    }

    // MARK: - Merchant + Note

    private var merchantNoteCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "storefront")
                    .foregroundStyle(AppColors.ink3)
                    .font(.system(size: 13))
                TextField("商户名 (例:海底捞)", text: $merchant)
                    .font(.system(size: 13))
                    .foregroundStyle(AppColors.ink)
                    .autocorrectionDisabled()
                if !merchant.isEmpty {
                    Button { merchant = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(AppColors.ink3)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)

            Divider().background(AppColors.glassDivider).padding(.horizontal, 12)

            HStack(spacing: 10) {
                Image(systemName: "pencil")
                    .foregroundStyle(AppColors.ink3)
                    .font(.system(size: 13))
                TextField("添加备注 (自动填入收据明细)", text: $note, axis: .vertical)
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.ink)
                    .lineLimit(1...3)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
        }
        .glassCard(radius: 14)
    }

    // MARK: - Keypad

    private var keypad: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
            ForEach(["1","2","3","4","5","6","7","8","9",".","0","⌫"], id: \.self) { key in
                Button { tap(key) } label: {
                    Text(key)
                        .font(.system(size: 22, weight: .light))
                        .foregroundStyle(AppColors.ink)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Color.white.opacity(0.35))
                        .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .glassCard(radius: 14)
    }
    private func tap(_ key: String) {
        if key == "⌫" {
            if !amountEntry.isEmpty { amountEntry.removeLast() }
        } else if key == "." {
            if !amountEntry.contains(".") { amountEntry = amountEntry.isEmpty ? "0." : amountEntry + "." }
        } else {
            if let dot = amountEntry.firstIndex(of: "."),
               amountEntry.distance(from: dot, to: amountEntry.endIndex) > 2 { return }
            if amountEntry == "0" { amountEntry = key } else { amountEntry.append(key) }
        }
    }

    // MARK: - Receipt handoff

    private func applyReceipt(_ result: ReceiptOCRService.Result) {
        if let cents = result.amountCents {
            let yuan = cents / 100
            let fen = cents % 100
            amountEntry = fen > 0 ? "\(yuan).\(String(format: "%02d", fen))" : "\(yuan)"
        }
        if let slug = result.suggestedCategory { selectedCat = slug }
        if let m = result.merchant { merchant = m }
        if let d = result.date { scannedTimestamp = d }
        if !result.items.isEmpty {
            let preview = result.items.prefix(3).map { $0.name }.joined(separator: ", ")
            note = preview + (result.items.count > 3 ? " 等 \(result.items.count) 项" : "")
        }
        showReceiptSheet = false
    }

    // MARK: - Save

    private func save() {
        let cents = amountCents
        guard cents > 0 else { return }
        store.addExpense(
            amountCents: cents,
            category: selectedCat,
            merchant: merchant,
            note: note,
            mood: selectedMood,
            visibility: visibility,
            timestamp: scannedTimestamp ?? Date()
        )
        withAnimation(.spring()) { showConfetti = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) { dismiss() }
    }
}

#Preview {
    AddTransactionView().environment(AppStore())
}
