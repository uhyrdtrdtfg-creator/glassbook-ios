import Foundation

/// Spec §5.3 · Parse OCR'd lines from a platform screenshot into `PendingImportRow`s.
protocol PlatformParser {
    var platform: ImportBatch.Platform { get }
    /// Confidence score — count of platform-specific keyword hits in the OCR text.
    /// Higher = more likely to be this platform. 0 = no markers found.
    func score(lines: [String]) -> Int
    /// Extract structured rows from the OCR text.
    func parse(lines: [String]) -> [PendingImportRow]
}

extension PlatformParser {
    /// Default `canParse` derives from `score`. Parsers that need stricter
    /// gating can still override.
    func canParse(lines: [String]) -> Bool { score(lines: lines) > 0 }
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
    /// `looksLikeDateOrTime` is called from BOTH the parser line-scan (to skip
    /// date-header rows) AND from `extractAmountCents` (to reject amounts
    /// masquerading as dates). The two callers have different tolerances:
    /// "1.01" must parse as ¥1.01 for money, but "4.17" must skip as date
    /// header for CMB. Hence two sibling functions.
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
        let chips: Set<String> = [
            "未入账", "已入账", "待收货", "已完成", "待付款", "已退款",
            "分期", "分期付款", "待授权", "已授权", "交易成功", "支付成功",
            "已冲正", "退款", "转账", "收款", "付款", "账单日",
        ]
        return chips.contains(t)
    }

    /// CMB credit-card / debit-card tag lines like "信用卡1440 12:27",
    /// "储蓄卡1756 10:31". They sit between the transaction amount and
    /// the balance line, often confuse the merchant scan on subsequent
    /// iterations. Match prefix + any-digits + optional space + optional HH:MM.
    static let cardNoiseRegex = try! NSRegularExpression(
        pattern: #"^(信用卡|储蓄卡|一卡通|借记卡|尾号|卡号)\s*\d{2,}"#
    )
    static func looksLikeCardNoise(_ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespaces)
        return cardNoiseRegex.firstMatch(in: t, range: NSRange(t.startIndex..., in: t)) != nil
    }

    /// Balance-line noise like "余额:¥192,653.32" / "余额 ¥3,450.00" that
    /// appears after an entry on CMB 储蓄卡 rows. Matches any line starting
    /// with "余额" optionally followed by colon + amount.
    static func looksLikeBalanceLine(_ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespaces)
        return t.hasPrefix("余额") && (t.contains("¥") || t.range(of: #"\d"#, options: .regularExpression) != nil)
    }

    /// CMB transaction rows have a category icon (shopping bag / fork-and-spoon
    /// / microphone) in the left gutter. Vision sometimes misreads these
    /// rectangle-ish glyphs as single CJK characters that look like boxes:
    /// 日 口 田 目 回 曰 巳 已 己 or ASCII lookalikes O 0 ○ □ ● ■. Standing
    /// alone they're always icon noise, not merchant text.
    static func looksLikeIconGlyph(_ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespaces)
        guard t.count == 1 else { return false }
        let artifacts: Set<Character> = [
            "日", "口", "田", "目", "回", "曰", "巳", "已", "己", "吕", "品",
            "O", "0", "○", "●", "□", "■", "▢", "▣", "▪", "▫", "●", "◎", "㎡",
        ]
        return artifacts.contains(t.first!)
    }

    /// Same artifacts as `looksLikeIconGlyph`, but as a *prefix* of a longer
    /// line — happens when Vision merges an icon observation with the merchant
    /// name on the same row (e.g. "日深圳宜家家居有限公司"). Strip the stray
    /// first character and return the cleaned string. Only strips when the
    /// remainder is clearly a real merchant (≥2 chars starting with a non-icon
    /// CJK / Latin letter), so legit prefixes like "日本料理店" stay untouched.
    static func strippingIconPrefix(_ text: String) -> String {
        let t = text.trimmingCharacters(in: .whitespaces)
        guard t.count >= 3, let first = t.first else { return t }
        let artifacts: Set<Character> = [
            "日", "口", "田", "目", "回", "曰", "巳", "已", "己", "吕", "品",
            "O", "0", "○", "●", "□", "■",
        ]
        guard artifacts.contains(first) else { return t }
        let remainder = String(t.dropFirst()).trimmingCharacters(in: .whitespaces)
        // Guard: keep "日本料理" / "日清" / "回转寿司" etc. — the second char
        // after a legit 日/回 is usually another CJK that forms a word. Only
        // strip when the 2nd char starts a city / company prefix we know is
        // standalone (省/市/区/深圳/北京 etc.) or a Latin letter.
        let cityPrefixes = ["深圳", "北京", "上海", "广州", "成都", "杭州", "武汉", "西安", "南京", "重庆", "东莞"]
        if cityPrefixes.contains(where: { remainder.hasPrefix($0) }) { return remainder }
        if let second = remainder.first, second.isLetter && second.isASCII { return remainder }
        return t
    }

    /// Compute the set of line indices whose amount is a *summary* total —
    /// the one that follows a "支出 / 收入 / 本月合计 / 总计 / Total" label.
    /// Parsers use this to avoid minting phantom transactions from the top-of-
    /// screen stat block (e.g. Alipay shows "支出 ¥2,870.98" above the list).
    /// Also handles inline combined forms like "支出¥5197.04".
    static func summaryAmountIndices(_ lines: [String]) -> Set<Int> {
        let labels: Set<String> = [
            "支出", "收入", "总计", "小计", "汇总",
            "本月支出", "本月收入", "本月合计", "本月总计",
            "Total", "TOTAL", "总支出", "总收入",
        ]
        var out: Set<Int> = []
        for i in 0..<lines.count {
            let t = lines[i].trimmingCharacters(in: .whitespaces)
            // Exact-match label on its own line → next line is the summary amount.
            if labels.contains(t), i + 1 < lines.count { out.insert(i + 1) }
            // Inline summary: "支出¥5197.04" / "收入¥60.00" all on one line
            // — the amount is embedded so mark *this* index as summary.
            for label in ["支出", "收入", "本月支出", "本月收入", "总计", "小计"] {
                if t.hasPrefix(label) && t.count > label.count {
                    // look for a digit after the label; if present, it's inline summary
                    let rest = t.dropFirst(label.count).trimmingCharacters(in: .whitespaces)
                    if rest.contains("¥") || rest.range(of: #"\d"#, options: .regularExpression) != nil {
                        out.insert(i)
                    }
                }
            }
        }
        return out
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
    /// are skippable; any other non-amount line aborts the search. Indices
    /// in `excluding` (summary-total amounts) are always rejected.
    ///
    /// Why strict: in real bill layouts the merchant and amount sit on the
    /// same row visually, and Vision emits them as adjacent lines. Leniency
    /// would let the first "merchant-looking" UI label latch onto a distant
    /// month-total amount ("4月" + "¥ 2,870.98"), producing phantoms.
    static func findAmountIndex(in lines: [String], from start: Int,
                                maxLookAhead: Int = 2,
                                assumeExpense: Bool = true,
                                excluding: Set<Int> = []) -> Int? {
        let end = min(lines.count - 1, start + maxLookAhead)
        guard start <= end else { return nil }
        for i in start...end {
            let t = lines[i].trimmingCharacters(in: .whitespaces)
            if t.isEmpty
                || looksLikeStatusChip(t)
                || looksLikeCardNoise(t)
                || looksLikeBalanceLine(t)
                || looksLikeIconGlyph(t) { continue }
            if excluding.contains(i) { return nil }  // summary amount — bail
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

    /// Best-matching parser for a given OCR output. Scores every parser's
    /// keyword hits and picks the highest; ties stay stable (first defined
    /// wins). Falls back to Alipay only when EVERY parser scores 0 —
    /// previously Alipay won by list position even when WeChat / CMB had
    /// stronger matches.
    static func pick(for lines: [String]) -> PlatformParser {
        let scored = all.map { (parser: $0, score: $0.score(lines: lines)) }
        if let best = scored.max(by: { $0.score < $1.score }), best.score > 0 {
            return best.parser
        }
        return AlipayParser()
    }
}
