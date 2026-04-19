import Foundation

/// Spec §5.3 · Parse OCR'd lines from a platform screenshot into `PendingImportRow`s.
protocol PlatformParser {
    var platform: ImportBatch.Platform { get }
    /// Heuristic: does this parser recognize any platform-specific marker in the OCR text?
    func canParse(lines: [String]) -> Bool
    /// Extract structured rows from the OCR text.
    func parse(lines: [String]) -> [PendingImportRow]
}

// MARK: - Shared helpers

enum ParserKit {

    /// Matches `+¥12.34`, `-12.34`, `¥1,234.56`, `1234` etc.
    /// The comma-grouped alternative uses `+` (not `*`) on the comma group so
    /// plain numbers like `2999.00` fall through to the unconstrained
    /// `\d+(?:\.\d{1,2})?` branch instead of being truncated to `299`.
    static let amountRegex = try! NSRegularExpression(
        pattern: #"(?<sign>[+\-−])?\s*¥?\s*(?<num>\d{1,3}(?:,\d{3})+(?:\.\d{1,2})?|\d+(?:\.\d{1,2})?)"#
    )

    /// True when the text is a date / time / card-number label and should NOT
    /// be fed to `extractAmountCents`. Real bill screenshots pack lots of
    /// digits into these labels (signal bar "21:19", card "信用卡1440 12:27",
    /// "4月19日 18:25", …) which otherwise get misread as ¥ amounts.
    static func looksLikeDateOrTime(_ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespaces)
        if t.isEmpty { return false }
        // "2026.04", "2026-04-18"
        if t.range(of: #"^\d{4}[.\-/]\d{1,2}"#, options: .regularExpression) != nil { return true }
        // HH:MM at start (status bar time)
        if t.range(of: #"^\d{1,2}:\d{2}"#, options: .regularExpression) != nil { return true }
        // Chinese date: X月Y日
        if t.contains("月") && t.contains("日") { return true }
        // Relative date prefix
        if t.hasPrefix("今天") || t.hasPrefix("昨天") || t.hasPrefix("前天") { return true }
        // Short month-day: "04-17" / "4.17" / "04/17"
        // Short month-day with - or / separator: "04-17" standalone, or
        // "04-17 05:14" where the month-day is followed by a time. Matches the
        // separator but NOT a bare decimal like "1.01" (which is an amount).
        if t.range(of: #"^\d{1,2}[-/]\d{1,2}(\s|$)"#, options: .regularExpression) != nil { return true }
        // Card identifiers: "信用卡1440 12:27", "储蓄卡1756 10:31"
        if t.contains("卡") && t.range(of: #"\d{4}"#, options: .regularExpression) != nil { return true }
        // "余额:¥192,653.32" — balance line; has ¥ but is NOT a transaction amount.
        // Must NOT match "余额宝-..." (Alipay's money-market fund merchant) so
        // we anchor on the colon that only appears in the balance form.
        if t.range(of: #"^余额[:：]"#, options: .regularExpression) != nil { return true }
        return false
    }

    /// Side-indicator tags sometimes sit between merchant and amount in real
    /// bill layouts (CMB's "未入账", Alipay's "待收货"). Treated as skippable
    /// when a parser scans forward looking for the amount line.
    static func looksLikeStatusChip(_ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespaces)
        let chips = ["未入账", "已入账", "待收货", "已完成", "待付款", "已退款"]
        return chips.contains(t)
    }

    /// Matches `2026-04-19 12:04:32` / `2026/04/19 12:04` / `04-19 08:12` / `04/19 8:12`
    /// plus the Chinese form `4月19日 19:13` and `4月19日 19:13:00`.
    static let timeRegex = try! NSRegularExpression(
        pattern: #"(?<y>\d{4})?[\-/]?\s?(?<m>\d{1,2})[\-/](?<d>\d{1,2})\s+(?<h>\d{1,2}):(?<mm>\d{2})(?::(?<s>\d{2}))?"#
    )
    static let chineseDateRegex = try! NSRegularExpression(
        pattern: #"(?<m>\d{1,2})月(?<d>\d{1,2})日(?:\s+(?<h>\d{1,2}):(?<mm>\d{2})(?::(?<s>\d{2}))?)?"#
    )

    static func extractAmountCents(from text: String, assumeExpense: Bool = true) -> (cents: Int, isIncome: Bool)? {
        // Reject date / time / card labels up front — they frequently contain
        // digit sequences that the regex would otherwise misread as currency.
        if looksLikeDateOrTime(text) { return nil }

        let range = NSRange(text.startIndex..., in: text)
        guard let match = amountRegex.firstMatch(in: text, range: range) else { return nil }
        let nsText = text as NSString
        let signRange = match.range(withName: "sign")
        let numRange = match.range(withName: "num")
        guard numRange.location != NSNotFound else { return nil }

        let sign: Character? = signRange.location == NSNotFound ? nil : nsText.substring(with: signRange).first
        let numStr = nsText.substring(with: numRange).replacingOccurrences(of: ",", with: "")
        guard let decimal = Decimal(string: numStr) else { return nil }
        let cents = (decimal * 100 as NSDecimalNumber).intValue
        if cents <= 0 { return nil }

        // Require either a currency symbol in the input, a decimal point in
        // the number, OR an explicit income keyword ("工资", "退款"). Bare
        // integers like "1440" (card number) or "16" (from "16:21") must not
        // masquerade as amounts.
        let hasCurrency = text.contains("¥") || text.contains("$") || text.contains("€")
        let hasDecimal = numStr.contains(".")
        let hasIncomeKeyword = text.containsAny(of: [
            "退款", "返现", "收入", "入账", "转入", "工资", "奖金",
        ])
        guard hasCurrency || hasDecimal || hasIncomeKeyword else { return nil }

        let isIncome: Bool = {
            if sign == "+" { return true }
            if sign == "-" || sign == "−" { return false }
            // Context clues — "退款 / 返现 / 收入 / 入账 / 转入"
            if text.containsAny(of: ["退款", "返现", "收入", "入账", "转入", "工资", "奖金"]) { return true }
            return !assumeExpense ? true : false
        }()
        return (cents, isIncome)
    }

    /// Scan `lines[start…]` up to `maxLookAhead` ahead for the first line that
    /// yields a parseable amount. STRICT: only empty lines and status chips
    /// are skippable; any other non-amount line aborts the search.
    ///
    /// Why strict: in real bill layouts the merchant and amount sit on the
    /// same row visually, and Vision emits them as adjacent lines. Leniency
    /// would let the first "merchant-looking" UI label latch onto a distant
    /// month-total amount ("4月" + "¥ 2,870.98"), producing phantoms.
    static func findAmountIndex(in lines: [String], from start: Int,
                                maxLookAhead: Int = 2,
                                assumeExpense: Bool = true) -> Int? {
        let end = min(lines.count - 1, start + maxLookAhead)
        guard start <= end else { return nil }
        for i in start...end {
            let t = lines[i].trimmingCharacters(in: .whitespaces)
            if t.isEmpty || looksLikeStatusChip(t) { continue }
            if extractAmountCents(from: t, assumeExpense: assumeExpense) != nil {
                return i
            }
            // Non-amount, non-skippable line between merchant and where we
            // expected amount — pairing isn't real. Abort.
            return nil
        }
        return nil
    }

    static func extractDate(from text: String, defaultYear: Int) -> Date? {
        // Try Chinese form first — "4月19日 19:13" — since it'd otherwise only
        // match the weaker mm:hh portion of the western regex.
        let range = NSRange(text.startIndex..., in: text)
        if let match = chineseDateRegex.firstMatch(in: text, range: range) {
            let ns = text as NSString
            func cap(_ name: String) -> String? {
                let r = match.range(withName: name)
                return r.location == NSNotFound ? nil : ns.substring(with: r)
            }
            guard let m = cap("m").flatMap(Int.init),
                  let d = cap("d").flatMap(Int.init) else { return nil }
            let h  = cap("h").flatMap(Int.init) ?? 0
            let mm = cap("mm").flatMap(Int.init) ?? 0
            let s  = cap("s").flatMap(Int.init) ?? 0
            var comps = DateComponents()
            comps.year = defaultYear; comps.month = m; comps.day = d
            comps.hour = h; comps.minute = mm; comps.second = s
            return Calendar(identifier: .gregorian).date(from: comps)
        }

        guard let match = timeRegex.firstMatch(in: text, range: range) else { return nil }
        let nsText = text as NSString

        func capture(_ name: String) -> String? {
            let r = match.range(withName: name)
            return r.location == NSNotFound ? nil : nsText.substring(with: r)
        }

        let y = capture("y").flatMap(Int.init) ?? defaultYear
        guard let m  = capture("m").flatMap(Int.init),
              let d  = capture("d").flatMap(Int.init),
              let h  = capture("h").flatMap(Int.init),
              let mm = capture("mm").flatMap(Int.init) else { return nil }
        let s = capture("s").flatMap(Int.init) ?? 0

        var comps = DateComponents()
        comps.year = y; comps.month = m; comps.day = d
        comps.hour = h; comps.minute = mm; comps.second = s
        return Calendar(identifier: .gregorian).date(from: comps)
    }
}

extension String {
    fileprivate func containsAny(of needles: [String]) -> Bool {
        needles.contains { self.contains($0) }
    }
}

// MARK: - Parser registry

enum ParserRegistry {
    static let all: [PlatformParser] = [
        AlipayParser(),
        WeChatParser(),
        CMBParser(),
    ]

    /// Best-matching parser for a given OCR output. Falls back to Alipay as a safe default.
    static func pick(for lines: [String]) -> PlatformParser {
        all.first(where: { $0.canParse(lines: lines) }) ?? AlipayParser()
    }
}
