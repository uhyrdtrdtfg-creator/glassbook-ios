import Foundation

struct CMBParser: PlatformParser {
    let platform: ImportBatch.Platform = .cmb

    func score(lines: [String]) -> Int {
        let joined = lines.joined(separator: " ")
        var n = 0
        for k in [
            "招商银行", "CMB", "收支明细", "信用卡账单",
            "一卡通", "尾号", "本期账单", "未入账", "招行"
        ] where joined.contains(k) { n += 1 }
        return n
    }

    /// CMB bill layout varies: status chips like "未入账" often sit between
    /// merchant and amount. Scan forward up to 3 lines when looking for the
    /// amount; skip chip labels so the merchant doesn't get overwritten.
    /// CMB groups rows by day — short headers ("昨天", "4.17") sit above a
    /// block of transactions. We track the current day as we iterate so
    /// a card-tail line that only carries HH:MM (e.g. "信用卡1440 12:27")
    /// still yields a correctly-dated Date.
    func parse(lines: [String]) -> [PendingImportRow] {
        var rows: [PendingImportRow] = []
        let today = Date()
        let cal = Calendar(identifier: .gregorian)
        let year = cal.component(.year, from: today)
        let summaryIndices = ParserKit.summaryAmountIndices(lines)
        var currentDayAnchor: Date? = nil   // last day header we saw

        var i = 0
        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)

            // Section headers: update the current-day anchor before we skip.
            if let anchor = dayHeader(line, today: today, cal: cal, year: year) {
                currentDayAnchor = anchor
                i += 1; continue
            }

            if line.isEmpty || isPlatformNoise(line)
                || ParserKit.looksLikeStatusChip(line)
                || ParserKit.looksLikeDateOrTime(line)
                || ParserKit.looksLikeCardNoise(line)
                || ParserKit.looksLikeBalanceLine(line) {
                i += 1; continue
            }

            guard let amountIdx = ParserKit.findAmountIndex(in: lines, from: i + 1,
                                                            maxLookAhead: 2,
                                                            assumeExpense: false,
                                                            excluding: summaryIndices) else {
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

            // Date can come from three places, in priority order:
            //  1. A full date in the card-tail line (rare).
            //  2. The HH:MM in the card-tail line combined with the current
            //     day-header anchor we've been tracking.
            //  3. The day-header anchor alone (no time).
            var date: Date?
            let dateStart = amountIdx + 1
            let dateEnd = min(amountIdx + 2, lines.count - 1)
            if dateStart <= dateEnd {
                for j in dateStart...dateEnd {
                    let raw = lines[j].trimmingCharacters(in: .whitespaces)
                    if let d = ParserKit.extractDate(from: raw, defaultYear: year) {
                        date = d; break
                    }
                    if let anchor = currentDayAnchor,
                       let hm = extractHourMinute(from: raw),
                       let merged = mergeTime(hm, into: anchor, cal: cal) {
                        date = merged; break
                    }
                }
            }
            if date == nil { date = currentDayAnchor }

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

    /// Parse the CMB day-header labels into concrete dates:
    ///   "昨天" → yesterday, "今天" → today, "前天" → two days ago,
    ///   "4.17" / "12-30" → month.day of current year.
    private func dayHeader(_ text: String, today: Date, cal: Calendar, year: Int) -> Date? {
        if text == "今天" { return cal.startOfDay(for: today) }
        if text == "昨天" { return cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: today)) }
        if text == "前天" { return cal.date(byAdding: .day, value: -2, to: cal.startOfDay(for: today)) }
        // Short month.day: "4.17", "12-30", "3/5"
        if let match = text.range(of: #"^(\d{1,2})[.\-/](\d{1,2})$"#, options: .regularExpression) {
            let parts = text[match].split(whereSeparator: { ".-/".contains($0) })
            if parts.count == 2,
               let m = Int(parts[0]), let d = Int(parts[1]),
               (1...12).contains(m), (1...31).contains(d) {
                var comps = DateComponents()
                comps.year = year; comps.month = m; comps.day = d
                return cal.date(from: comps)
            }
        }
        return nil
    }

    /// Pull HH:MM out of a card-tail line like "信用卡1440 12:27".
    private func extractHourMinute(from text: String) -> (h: Int, m: Int)? {
        guard let match = text.range(of: #"(\d{1,2}):(\d{2})"#, options: .regularExpression) else { return nil }
        let parts = text[match].split(separator: ":")
        guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]),
              (0...23).contains(h), (0...59).contains(m) else { return nil }
        return (h, m)
    }

    private func mergeTime(_ hm: (h: Int, m: Int), into anchor: Date, cal: Calendar) -> Date? {
        var comps = cal.dateComponents([.year, .month, .day], from: anchor)
        comps.hour = hm.h; comps.minute = hm.m
        return cal.date(from: comps)
    }

    private func isPlatformNoise(_ s: String) -> Bool {
        let noise = ["招商银行", "CMB", "收支", "收支明细", "信用卡账单",
                     "当月支出", "当月收入", "昨天", "银行卡", "按金额", "筛选"]
        return noise.contains(where: { s == $0 })
    }
}
