import SwiftUI

/// Shared rich editor used by both "新增记一笔" (AddTransactionView) and
/// the edit sheets (EditPendingRowSheet · EditTransactionSheet). Parity
/// means users get the SAME controls no matter how the entry arrived —
/// kind toggle, big amount display + custom keypad, visibility, category
/// grid, mood chips, merchant + note, and optional date picker for edit
/// contexts.
///
/// The form owns all its local state and pushes final values through
/// `onSave` when the user taps the save button. The caller decides
/// whether that means inserting a new transaction, updating an existing
/// one, or mutating a PendingImportRow.
struct RichTxFormView: View {

    @Environment(AIEngineStore.self) private var aiEngines
    // Item 18 服务层 · 通过 env 拿 LLMClassifier 实例做 AI 简化商户名。
    @Environment(AppServices.self) private var services

    struct Values {
        var kind: Transaction.Kind = .expense
        var amountCents: Int = 0
        var categoryID: Category.Slug = .food
        var merchant: String = ""
        var note: String = ""
        var mood: Mood? = nil
        var visibility: Visibility = .family
        var timestamp: Date = .now
    }

    // ---- inputs ----
    var title: String
    var saveLabel: String
    var initial: Values
    /// When true, show a DatePicker so edit flows can change the timestamp.
    /// New-entry flows usually hide it and use .now on save.
    var showDatePicker: Bool
    /// Optional secondary action (delete for existing tx). If nil, hidden.
    var destructiveAction: (label: String, handler: () -> Void)? = nil
    var onCancel: () -> Void
    var onSave: (Values) -> Void

    // ---- state ----
    @State private var values: Values
    @State private var amountEntry: String
    @State private var cursorBlink = true
    @State private var hasEditedValues = false
    @State private var showDiscardDialog = false
    @State private var isSimplifying = false

    init(title: String,
         saveLabel: String = "保存",
         initial: Values,
         showDatePicker: Bool = true,
         destructiveAction: (label: String, handler: () -> Void)? = nil,
         onCancel: @escaping () -> Void,
         onSave: @escaping (Values) -> Void) {
        self.title = title
        self.saveLabel = saveLabel
        self.initial = initial
        self.showDatePicker = showDatePicker
        self.destructiveAction = destructiveAction
        self.onCancel = onCancel
        self.onSave = onSave
        _values = State(initialValue: initial)
        _amountEntry = State(initialValue: Self.amountToEntry(initial.amountCents))
    }

    var body: some View {
        ZStack {
            AuroraBackground(palette: .add)
            ScrollView {
                VStack(spacing: 14) {
                    topBar
                    kindToggle
                    amountCard
                    visibilityRow
                    categoryGrid
                    moodRow
                    merchantNoteCard
                    if showDatePicker { dateCard }
                    keypad
                    if let d = destructiveAction {
                        Button(role: .destructive, action: d.handler) {
                            Text(d.label)
                                .font(.system(size: 13))
                                .foregroundStyle(AppColors.expenseRed)
                                .frame(maxWidth: .infinity, minHeight: 40)
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer().frame(height: 32)
                }
                .padding(.horizontal, 18).padding(.top, 16)
            }
            .scrollIndicators(.hidden)
        }
        .confirmationDialog("确定放弃修改?", isPresented: $showDiscardDialog, titleVisibility: .visible) {
            Button("放弃", role: .destructive) { onCancel() }
            Button("继续编辑", role: .cancel) { }
        }
    }

    private func attemptCancel() {
        if hasEditedValues { showDiscardDialog = true } else { onCancel() }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(spacing: 10) {
            Button(action: attemptCancel) {
                Text("取消").font(.system(size: 12))
                    .foregroundStyle(AppColors.ink2)
                    .frame(width: 56, height: 28)
                    .background(Capsule().fill(Color.white.opacity(0.5)))
                    .overlay(Capsule().strokeBorder(AppColors.glassBorder, lineWidth: 1))
            }
            Spacer()
            Text(title).font(.system(size: 14, weight: .medium))
            Spacer()
            Button {
                values.amountCents = amountCentsFromEntry
                onSave(values)
            } label: {
                Text(saveLabel).font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 28)
                    .background(Capsule().fill(AppColors.ink))
            }
            .disabled(amountCentsFromEntry == 0)
            .opacity(amountCentsFromEntry == 0 ? 0.4 : 1)
        }
    }

    // MARK: - Kind toggle

    private var kindToggle: some View {
        HStack(spacing: 4) {
            ForEach(Transaction.Kind.allCases, id: \.self) { k in
                Button { values.kind = k; hasEditedValues = true } label: {
                    Text(label(for: k))
                        .font(.system(size: 12, weight: values.kind == k ? .medium : .regular))
                        .foregroundStyle(values.kind == k ? .white : AppColors.ink2)
                        .frame(maxWidth: .infinity, minHeight: 32)
                        .background(RoundedRectangle(cornerRadius: 10).fill(values.kind == k ? AppColors.ink : Color.clear))
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
    private var amountCentsFromEntry: Int {
        guard let d = Decimal(string: amountEntry.isEmpty ? "0" : amountEntry) else { return 0 }
        return (d * 100 as NSDecimalNumber).intValue
    }

    private static func amountToEntry(_ cents: Int) -> String {
        if cents == 0 { return "" }
        let yuan = cents / 100
        let fen = cents % 100
        return fen > 0 ? "\(yuan).\(String(format: "%02d", fen))" : "\(yuan)"
    }

    // MARK: - Visibility

    private var visibilityRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("👁 可见范围 · 按笔隐私").eyebrowStyle()
            HStack(spacing: 6) {
                ForEach(Visibility.allCases, id: \.self) { v in
                    Button { values.visibility = v; hasEditedValues = true } label: {
                        HStack(spacing: 6) {
                            Text(v.emoji).font(.system(size: 12))
                            Text(v.displayName)
                                .font(.system(size: 11, weight: values.visibility == v ? .medium : .regular))
                                .foregroundStyle(values.visibility == v ? .white : AppColors.ink)
                        }
                        .frame(maxWidth: .infinity, minHeight: 34)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(values.visibility == v ? AppColors.ink : Color.white.opacity(0.55))
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

    // MARK: - Category

    private var categoryGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
            ForEach(Category.all, id: \.id) { cat in
                Button { values.categoryID = cat.id; hasEditedValues = true } label: {
                    VStack(spacing: 5) {
                        Text(cat.emoji).font(.system(size: 20))
                        Text(cat.name).font(.system(size: 10))
                            .foregroundStyle(values.categoryID == cat.id ? AppColors.ink : AppColors.ink2)
                    }
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1.1, contentMode: .fit)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(values.categoryID == cat.id ? Color.white.opacity(0.75) : Color.white.opacity(0.25))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(values.categoryID == cat.id ? AppColors.ink : Color.clear, lineWidth: 1.2)
                    )
                    .fontWeight(values.categoryID == cat.id ? .medium : .regular)
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
                if values.mood != nil {
                    Button("清除") { values.mood = nil; hasEditedValues = true }
                        .font(.system(size: 10))
                        .foregroundStyle(AppColors.ink3)
                }
            }
            HStack(spacing: 6) {
                ForEach(Mood.allCases, id: \.self) { m in
                    Button { values.mood = (values.mood == m ? nil : m); hasEditedValues = true } label: {
                        HStack(spacing: 4) {
                            Text(m.emoji).font(.system(size: 11))
                            Text(m.displayName)
                                .font(.system(size: 10, weight: values.mood == m ? .medium : .regular))
                                .foregroundStyle(values.mood == m ? .white : AppColors.ink)
                        }
                        .frame(maxWidth: .infinity, minHeight: 32)
                        .background(
                            Capsule().fill(values.mood == m ? Color(hex: m.tintHex) : Color.white.opacity(0.55))
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
                TextField("商户名 (例:海底捞)", text: $values.merchant)
                    .font(.system(size: 13))
                    .foregroundStyle(AppColors.ink)
                    .autocorrectionDisabled()
                    .onChange(of: values.merchant) { _, _ in hasEditedValues = true }
                if llmAvailable, !values.merchant.isEmpty {
                    simplifyButton
                }
                if !values.merchant.isEmpty {
                    Button { values.merchant = ""; hasEditedValues = true } label: {
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
                TextField("添加备注", text: $values.note, axis: .vertical)
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.ink)
                    .lineLimit(1...3)
                    .onChange(of: values.note) { _, _ in hasEditedValues = true }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
        }
        .glassCard(radius: 14)
    }

    // MARK: - AI simplify merchant name (Item 7)

    /// Only show the button if the current AI engine can actually serve
    /// the call. Apple Intelligence has no public text API so we hide there
    /// too — same rule as LLMClassifier.
    private var llmAvailable: Bool {
        let engine = aiEngines.selected
        if engine == .appleIntelligence { return false }
        if engine == .phoneclaw { return true }  // 本地不需要 API key
        if let key = aiEngines.apiKey(for: engine), !key.isEmpty { return true }
        return false
    }

    private var simplifyButton: some View {
        Button {
            let raw = values.merchant
            isSimplifying = true
            Task {
                let simplified = await services.classifier.simplifyMerchantName(raw: raw)
                await MainActor.run {
                    if let s = simplified {
                        values.merchant = s
                        hasEditedValues = true
                    }
                    isSimplifying = false
                }
            }
        } label: {
            HStack(spacing: 3) {
                if isSimplifying {
                    ProgressView().controlSize(.mini).tint(AppColors.ink2)
                } else {
                    Image(systemName: "sparkles").font(.system(size: 9))
                }
                Text(isSimplifying ? "简化中" : "AI 简化")
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Capsule().fill(LinearGradient.brand()))
        }
        .buttonStyle(.plain)
        .disabled(isSimplifying)
        .opacity(isSimplifying ? 0.6 : 1)
    }

    // MARK: - Date (edit-only)

    private var dateCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("时间").eyebrowStyle()
            DatePicker("", selection: $values.timestamp, displayedComponents: [.date, .hourAndMinute])
                .datePickerStyle(.compact)
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
                .onChange(of: values.timestamp) { _, _ in hasEditedValues = true }
        }
        .padding(14)
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
        hasEditedValues = true
    }
}
