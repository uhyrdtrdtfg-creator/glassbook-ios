import SwiftUI

/// Edit an already-committed transaction. Same shape as the smart-import
/// EditPendingRowSheet but writes through `AppStore.updateTransaction` so
/// changes survive relaunch + sync to CloudKit.
struct EditTransactionSheet: View {
    let txID: UUID
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var merchant: String = ""
    @State private var amountText: String = ""
    @State private var selectedCat: Category.Slug = .other
    @State private var date: Date = .now
    @State private var note: String = ""
    @State private var initialized: Bool = false

    private var currentTx: Transaction? {
        store.transactions.first(where: { $0.id == txID })
    }

    var body: some View {
        ZStack {
            AuroraBackground(palette: .add)
            ScrollView {
                VStack(spacing: 14) {
                    header
                    merchantCard
                    amountCard
                    categoryCard
                    dateCard
                    noteCard
                    Spacer().frame(height: 18)
                    saveButton
                    deleteButton
                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 18).padding(.top, 8)
            }
            .scrollIndicators(.hidden)
        }
        .onAppear {
            guard !initialized, let tx = currentTx else { return }
            merchant = tx.merchant
            amountText = String(format: "%.2f", Double(tx.amountCents) / 100.0)
            selectedCat = tx.categoryID
            date = tx.timestamp
            note = tx.note ?? ""
            initialized = true
        }
    }

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.system(size: 13))
                    .frame(width: 34, height: 34).glassCard(radius: 12)
                    .foregroundStyle(AppColors.ink)
            }
            Spacer()
            Text("编辑账单").font(.system(size: 16, weight: .medium))
            Spacer()
            Spacer().frame(width: 34)
        }
    }

    private var merchantCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("商户").eyebrowStyle()
            TextField("例如:瑞幸咖啡", text: $merchant)
                .font(.system(size: 14))
                .padding(.vertical, 10).padding(.horizontal, 12)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.55)))
        }
        .padding(14)
        .glassCard()
    }

    private var amountCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("金额").eyebrowStyle()
            HStack(spacing: 6) {
                Text("¥").font(.system(size: 22, weight: .light))
                    .foregroundStyle(AppColors.ink2)
                TextField("0.00", text: $amountText)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 24, weight: .light).monospacedDigit())
            }
            .padding(.vertical, 10).padding(.horizontal, 12)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.55)))
        }
        .padding(14)
        .glassCard()
    }

    private var categoryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("分类").eyebrowStyle()
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(Category.all, id: \.id) { cat in
                    Button { selectedCat = cat.id } label: {
                        VStack(spacing: 4) {
                            Text(cat.emoji).font(.system(size: 18))
                            Text(cat.name).font(.system(size: 9))
                                .foregroundStyle(selectedCat == cat.id ? AppColors.ink : AppColors.ink2)
                        }
                        .frame(maxWidth: .infinity)
                        .aspectRatio(1.1, contentMode: .fit)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(selectedCat == cat.id ? Color.white.opacity(0.75) : Color.white.opacity(0.25))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .strokeBorder(selectedCat == cat.id ? AppColors.ink : Color.clear, lineWidth: 1.2)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .glassCard()
    }

    private var dateCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("时间").eyebrowStyle()
            DatePicker("", selection: $date, displayedComponents: [.date, .hourAndMinute])
                .datePickerStyle(.compact)
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .glassCard()
    }

    private var noteCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("备注").eyebrowStyle()
            TextField("可选", text: $note)
                .font(.system(size: 13))
                .padding(.vertical, 10).padding(.horizontal, 12)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.55)))
        }
        .padding(14)
        .glassCard()
    }

    private var saveButton: some View {
        Button {
            let trimmed = merchant.trimmingCharacters(in: .whitespaces)
            let cents = parseCents(amountText)
            store.updateTransaction(
                id: txID,
                merchant: trimmed.isEmpty ? nil : trimmed,
                amountCents: cents,
                category: selectedCat,
                timestamp: date,
                note: note
            )
            dismiss()
        } label: {
            Text("保存")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(RoundedRectangle(cornerRadius: 14).fill(AppColors.ink))
        }
        .buttonStyle(.plain)
        .disabled(!isValid)
        .opacity(isValid ? 1 : 0.5)
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            store.delete(txID)
            dismiss()
        } label: {
            Text("删除这笔")
                .font(.system(size: 13))
                .foregroundStyle(AppColors.expenseRed)
                .frame(maxWidth: .infinity, minHeight: 40)
        }
        .buttonStyle(.plain)
    }

    private var isValid: Bool {
        guard !merchant.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        guard let c = parseCents(amountText), c > 0 else { return false }
        return true
    }

    private func parseCents(_ s: String) -> Int? {
        let clean = s.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "")
        guard let d = Double(clean) else { return nil }
        return Int((d * 100).rounded())
    }
}
