import SwiftUI

/// Edit a committed transaction using the SAME rich form as "新增记一笔"
/// (kind / keypad / visibility / category / mood / merchant+note / date).
/// Under the hood calls `AppStore.updateTransaction` so changes flow to
/// SwiftData + CloudKit.
struct EditTransactionSheet: View {
    let txID: UUID
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    private var currentTx: Transaction? {
        store.transactions.first(where: { $0.id == txID })
    }

    var body: some View {
        if let tx = currentTx {
            RichTxFormView(
                title: "编辑账单",
                saveLabel: "保存",
                initial: .init(
                    kind: tx.kind,
                    amountCents: tx.amountCents,
                    categoryID: tx.categoryID,
                    merchant: tx.merchant,
                    note: tx.note ?? "",
                    mood: tx.mood,
                    visibility: tx.visibility,
                    timestamp: tx.timestamp
                ),
                showDatePicker: true,
                destructiveAction: (
                    label: "删除这笔",
                    handler: {
                        store.delete(txID)
                        dismiss()
                    }
                ),
                onCancel: { dismiss() },
                onSave: { v in
                    store.updateTransaction(
                        id: txID,
                        kind: v.kind,
                        merchant: v.merchant,
                        amountCents: v.amountCents,
                        category: v.categoryID,
                        timestamp: v.timestamp,
                        note: v.note,
                        mood: .some(v.mood),
                        visibility: v.visibility
                    )
                    dismiss()
                }
            )
        } else {
            Text("找不到这笔账单").font(.system(size: 13))
                .foregroundStyle(AppColors.ink3)
                .padding()
        }
    }
}
