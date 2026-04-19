import Foundation

struct WeChatParser: PlatformParser {
    let platform: ImportBatch.Platform = .wechat

    func canParse(lines: [String]) -> Bool {
        let joined = lines.joined(separator: " ")
        return joined.contains("微信支付") || joined.contains("WeChat Pay") || joined.contains("零钱")
    }

    /// WeChat bill layout closely mirrors Alipay's — merchant / amount / short date.
    /// Dates are usually "MM-DD HH:mm" (year omitted).
    func parse(lines: [String]) -> [PendingImportRow] {
        var rows: [PendingImportRow] = []
        let year = Calendar.current.component(.year, from: Date())

        var i = 0
        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            if line.isEmpty || isPlatformNoise(line) { i += 1; continue }

            guard i + 1 < lines.count else { i += 1; continue }
            let amountLine = lines[i+1]
            guard let amount = ParserKit.extractAmountCents(from: amountLine, assumeExpense: true) else {
                i += 1; continue
            }
            let timeLine = i + 2 < lines.count ? lines[i+2] : ""
            let date = ParserKit.extractDate(from: timeLine, defaultYear: year) ?? Date()

            let merchant = line
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
            i += 3
        }
        return rows
    }

    private func isPlatformNoise(_ s: String) -> Bool {
        let noise = ["微信", "微信支付", "账单明细", "钱包", "零钱", "月账单"]
        return noise.contains(s)
    }
}
