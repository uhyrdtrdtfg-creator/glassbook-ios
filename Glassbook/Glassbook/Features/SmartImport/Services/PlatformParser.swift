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

    /// Matches `2026-04-19 12:04:32` / `2026/04/19 12:04` / `04-19 08:12` / `04/19 8:12`.
    static let timeRegex = try! NSRegularExpression(
        pattern: #"(?<y>\d{4})?[\-/]?\s?(?<m>\d{1,2})[\-/](?<d>\d{1,2})\s+(?<h>\d{1,2}):(?<mm>\d{2})(?::(?<s>\d{2}))?"#
    )

    static func extractAmountCents(from text: String, assumeExpense: Bool = true) -> (cents: Int, isIncome: Bool)? {
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

        let isIncome: Bool = {
            if sign == "+" { return true }
            if sign == "-" || sign == "−" { return false }
            // Context clues — "退款 / 返现 / 收入 / 入账 / 转入"
            if text.containsAny(of: ["退款", "返现", "收入", "入账", "转入", "工资", "奖金"]) { return true }
            return !assumeExpense ? true : false
        }()
        return (cents, isIncome)
    }

    static func extractDate(from text: String, defaultYear: Int) -> Date? {
        let range = NSRange(text.startIndex..., in: text)
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
