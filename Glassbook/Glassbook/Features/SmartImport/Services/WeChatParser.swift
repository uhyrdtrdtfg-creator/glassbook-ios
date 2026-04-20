import Foundation

struct WeChatParser: PlatformParser {
    let platform: ImportBatch.Platform = .wechat

    func score(lines: [String]) -> Int {
        let joined = lines.joined(separator: " ")
        var n = 0
        for k in ["微信支付", "WeChat Pay", "零钱", "微信", "财付通", "钱包"] where joined.contains(k) { n += 1 }
        return n
    }

    /// WeChat bill layout (real screenshots):
    ///   [merchant] → [amount] → [date "4月19日 19:13"]
    /// Uses the shared forward-scan helper so a stray "2026年4月" or status-bar
    /// time line doesn't yank the pairing out of alignment.
    func parse(lines: [String]) -> [PendingImportRow] {
        var rows: [PendingImportRow] = []
        let year = Calendar.current.component(.year, from: Date())
        let summaryIndices = ParserKit.summaryAmountIndices(lines)

        var i = 0
        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            if line.isEmpty || isPlatformNoise(line)
                || ParserKit.looksLikeStatusChip(line)
                || ParserKit.looksLikeDateOrTime(line) {
                i += 1; continue
            }
            if ParserKit.extractAmountCents(from: line) != nil || summaryIndices.contains(i) {
                i += 1; continue
            }

            guard let amountIdx = ParserKit.findAmountIndex(in: lines, from: i + 1,
                                                            maxLookAhead: 2,
                                                            excluding: summaryIndices) else {
                i += 1; continue
            }
            guard let amount = ParserKit.extractAmountCents(from: lines[amountIdx]) else {
                i += 1; continue
            }
            var date: Date?
            var dateIdx = amountIdx
            let dateStart = amountIdx + 1
            let dateEnd = min(amountIdx + 2, lines.count - 1)
            if dateStart <= dateEnd {
                for j in dateStart...dateEnd {
                    if let d = ParserKit.extractDate(from: lines[j], defaultYear: year) {
                        date = d; dateIdx = j; break
                    }
                }
            }

            let merchant = line
            let category = MerchantClassifier.shared.classify(merchant: merchant)

            rows.append(PendingImportRow(
                id: UUID(),
                merchant: merchant,
                amountCents: amount.cents,
                categoryID: category,
                timestamp: date ?? Date(),
                source: platform,
                isDuplicate: false,
                isSelected: true
            ))
            i = max(dateIdx + 1, amountIdx + 1)
        }
        return rows
    }

    private func isPlatformNoise(_ s: String) -> Bool {
        let noise = ["微信", "微信支付", "账单", "账单明细", "钱包", "零钱",
                     "月账单", "全部账单", "查找交易", "收支统计"]
        return noise.contains(s)
    }
}
