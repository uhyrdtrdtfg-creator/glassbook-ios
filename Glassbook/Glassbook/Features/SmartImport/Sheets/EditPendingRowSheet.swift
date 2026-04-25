import SwiftUI

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
