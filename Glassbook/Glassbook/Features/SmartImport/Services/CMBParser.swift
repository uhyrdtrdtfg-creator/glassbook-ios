import Foundation

struct CMBParser: PlatformParser {
    let platform: ImportBatch.Platform = .cmb

    func canParse(lines: [String]) -> Bool {
        let joined = lines.joined(separator: " ")
        return joined.contains("招商银行") || joined.contains("CMB")
            || joined.contains("收支明细") || joined.contains("信用卡账单")
    }

    /// CMB bill: merchant line, amount (+/- with explicit sign for credit vs debit),
    /// then a full YYYY-MM-DD HH:mm timestamp.
    func parse(lines: [String]) -> [PendingImportRow] {
        var rows: [PendingImportRow] = []
        let year = Calendar.current.component(.year, from: Date())

        var i = 0
        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            if line.isEmpty || isPlatformNoise(line) { i += 1; continue }

            guard i + 1 < lines.count else { i += 1; continue }
            let amountLine = lines[i+1]
            guard let amount = ParserKit.extractAmountCents(from: amountLine, assumeExpense: false) else {
                i += 1; continue
            }
            let timeLine = i + 2 < lines.count ? lines[i+2] : ""
            let date = ParserKit.extractDate(from: timeLine, defaultYear: year) ?? Date()

            let merchant = line
            let category = amount.isIncome ? .other : MerchantClassifier.shared.classify(merchant: merchant)

            rows.append(PendingImportRow(
                id: UUID(),
                merchant: merchant,
                amountCents: amount.cents,
                categoryID: category,
                timestamp: date,
                source: platform,
                isDuplicate: false,
                isSelected: true
            ))
            i += 3
        }
        return rows
    }

    private func isPlatformNoise(_ s: String) -> Bool {
        let noise = ["招商银行", "CMB", "收支明细", "信用卡账单", "当月支出", "当月收入"]
        return noise.contains(where: { s == $0 })
    }
}
