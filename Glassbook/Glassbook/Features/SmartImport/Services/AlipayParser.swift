import Foundation

struct AlipayParser: PlatformParser {
    let platform: ImportBatch.Platform = .alipay

    func canParse(lines: [String]) -> Bool {
        let joined = lines.joined(separator: " ")
        return joined.contains("支付宝") || joined.contains("Alipay") || joined.contains("余额宝")
    }

    /// Alipay bill screenshots typically show [merchant] → [amount] → [timestamp]
    /// as a repeating triple. We walk the OCR lines and glue together each triple
    /// that contains a parseable amount.
    func parse(lines: [String]) -> [PendingImportRow] {
        var rows: [PendingImportRow] = []
        let year = Calendar.current.component(.year, from: Date())

        var i = 0
        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            if line.isEmpty || isPlatformNoise(line) { i += 1; continue }

            // Try to find an amount within this line OR the next.
            let merchantLine = line
            var amountLine: String?
            var timeLine: String?
            var consumed = 1

            if i + 1 < lines.count, ParserKit.extractAmountCents(from: lines[i+1]) != nil {
                amountLine = lines[i+1]; consumed += 1
                if i + 2 < lines.count, ParserKit.extractDate(from: lines[i+2], defaultYear: year) != nil {
                    timeLine = lines[i+2]; consumed += 1
                }
            } else if ParserKit.extractAmountCents(from: merchantLine) != nil {
                // merchant and amount on the same line — can't happen for alipay typically, skip
                i += 1; continue
            } else {
                i += 1; continue
            }

            guard let amount = amountLine.flatMap({ ParserKit.extractAmountCents(from: $0) }) else {
                i += consumed; continue
            }

            let date = timeLine.flatMap { ParserKit.extractDate(from: $0, defaultYear: year) } ?? Date()
            let merchant = merchantLine
            let category = MerchantClassifier.shared.classify(merchant: merchant)

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
            i += consumed
        }
        return rows
    }

    private func isPlatformNoise(_ s: String) -> Bool {
        let noise = ["支付宝", "Alipay", "账单", "明细", "月报", "—", "总支出", "总收入"]
        return noise.contains(where: { s == $0 || s.hasPrefix($0) && s.count < $0.count + 3 })
    }
}
