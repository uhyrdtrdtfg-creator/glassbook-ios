import Foundation

struct AlipayParser: PlatformParser {
    let platform: ImportBatch.Platform = .alipay

    func score(lines: [String]) -> Int {
        let joined = lines.joined(separator: " ")
        var n = 0
        for k in ["支付宝", "Alipay", "余额宝", "花呗", "蚂蚁", "账单详情"] where joined.contains(k) { n += 1 }
        return n
    }

    /// Alipay bill layout (real screenshots):
    ///   [merchant] → [amount] → [category label] → [date]
    /// The category line (日用百货 / 投资理财 / 转账红包) would otherwise be
    /// picked up on the next iteration and paired with the *following* row's
    /// time, producing phantoms. We consume all four lines once we've matched.
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

            // Merchants with digits alone don't exist in Alipay — if the line
            // is an amount itself, skip it (not a merchant). Also skip lines
            // flagged as summary totals (the "支出 ¥2,870.98" row above the list).
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

            // Scan forward up to 2 lines for a date after the amount. Lines
            // between amount and date are usually the category label. Guard
            // the range — last parsed row may have nothing after the amount.
            var date: Date?
            var dateIdx = amountIdx
            let dateStart = amountIdx + 1
            let dateEnd = min(amountIdx + 3, lines.count - 1)
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
            // Consume up through the date line so the next iteration doesn't
            // re-interpret the category label as a merchant.
            i = max(dateIdx + 1, amountIdx + 1)
        }
        return rows
    }

    private func isPlatformNoise(_ s: String) -> Bool {
        let exact = ["支付宝", "Alipay", "账单", "明细", "月报", "—", "总支出", "总收入",
                     "全部", "支出", "收入", "转账", "退款", "订单", "筛选",
                     "搜索", "搜索交易记录", "贴纸新功能", "复盘本周收支",
                     "设置支出预算", "收支分析",
                     // Alipay header chrome from screenshots
                     "4月", "5月", "6月", "7月", "8月", "9月",
                     "10月", "11月", "12月", "1月", "2月", "3月"]
        return exact.contains(s)
    }
}
