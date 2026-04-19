import Foundation

struct CMBParser: PlatformParser {
    let platform: ImportBatch.Platform = .cmb

    func canParse(lines: [String]) -> Bool {
        let joined = lines.joined(separator: " ")
        return joined.contains("招商银行") || joined.contains("CMB")
            || joined.contains("收支明细") || joined.contains("信用卡账单")
    }

    /// CMB bill layout varies: status chips like "未入账" often sit between
    /// merchant and amount. Scan forward up to 3 lines when looking for the
    /// amount; skip chip labels so the merchant doesn't get overwritten.
    func parse(lines: [String]) -> [PendingImportRow] {
        var rows: [PendingImportRow] = []
        let year = Calendar.current.component(.year, from: Date())

        var i = 0
        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            if line.isEmpty || isPlatformNoise(line)
                || ParserKit.looksLikeStatusChip(line)
                || ParserKit.looksLikeDateOrTime(line) {
                i += 1; continue
            }

            guard let amountIdx = ParserKit.findAmountIndex(in: lines, from: i + 1,
                                                            maxLookAhead: 2,
                                                            assumeExpense: false) else {
                i += 1; continue
            }
            guard let amount = ParserKit.extractAmountCents(from: lines[amountIdx], assumeExpense: false) else {
                i += 1; continue
            }
            // Collect any status chips sitting between the merchant and amount
            // (CMB: "未入账") so we can preserve them in the transaction note —
            // user-facing signal that this charge hasn't settled on the card yet.
            var chips: [String] = []
            if amountIdx > i + 1 {
                for j in (i + 1)..<amountIdx {
                    let t = lines[j].trimmingCharacters(in: .whitespaces)
                    if ParserKit.looksLikeStatusChip(t) { chips.append(t) }
                }
            }

            // Date may sit right after the amount OR one line further when a
            // balance line follows. Guard the range for end-of-array cases.
            var date: Date?
            let dateStart = amountIdx + 1
            let dateEnd = min(amountIdx + 2, lines.count - 1)
            if dateStart <= dateEnd {
                for j in dateStart...dateEnd {
                    if let d = ParserKit.extractDate(from: lines[j], defaultYear: year) {
                        date = d; break
                    }
                }
            }

            let merchant = line
            let category = amount.isIncome ? .other : MerchantClassifier.shared.classify(merchant: merchant)

            rows.append(PendingImportRow(
                id: UUID(),
                merchant: merchant,
                amountCents: amount.cents,
                categoryID: category,
                timestamp: date ?? Date(),
                source: platform,
                isDuplicate: false,
                isSelected: true,
                note: chips.isEmpty ? nil : chips.joined(separator: " · ")
            ))
            i = amountIdx + 1
        }
        return rows
    }

    private func isPlatformNoise(_ s: String) -> Bool {
        let noise = ["招商银行", "CMB", "收支", "收支明细", "信用卡账单",
                     "当月支出", "当月收入", "昨天", "银行卡", "按金额", "筛选"]
        return noise.contains(where: { s == $0 })
    }
}
