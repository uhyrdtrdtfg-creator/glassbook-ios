import Foundation
import Vision
import UIKit

/// Spec v2 §V2.0 · 收据 OCR (also listed in V1.3 roadmap).
/// Different pipeline from `VisionOCRService.recognize(image:)` which handles
/// *payment bill screenshots*. This one targets paper / digital receipts with
/// line items + a total. All inference happens on-device.
enum ReceiptOCRService {

    enum Error: Swift.Error { case invalidImage, visionFailed(String) }

    struct Result: Hashable {
        var merchant: String?
        var amountCents: Int?
        var date: Date?
        var items: [LineItem]
        var suggestedCategory: Category.Slug?
        var rawText: [String]

        struct LineItem: Identifiable, Hashable {
            let id = UUID()
            let name: String
            let amountCents: Int
        }

        /// True when OCR extracted nothing usable — no total, no line items, no
        /// merchant guess. The UI shows an error state instead of a fake-success
        /// review screen in this case.
        var isEmpty: Bool {
            amountCents == nil && items.isEmpty &&
                (merchant == nil || merchant?.isEmpty == true)
        }
    }

    // MARK: - Public

    static func recognize(image: UIImage) async throws -> Result {
        let lines = try await VisionOCRService.recognize(image: image)
        return parse(lines: lines)
    }

    /// Scaffold-friendly synthetic receipt for simulator demos.
    static func fakeReceipt() -> Result {
        parse(lines: [
            "海底捞 · 国贸店",
            "POS: 001234",
            "2026-04-18 20:45",
            "麻辣鸳鸯锅         ¥58.00",
            "肥牛双拼           ¥128.00",
            "手工面筋           ¥12.00",
            "油麦菜             ¥18.00",
            "加饭加面           ¥6.00",
            "—————————————",
            "小计: ¥222.00",
            "服务费: ¥22.20",
            "合计: ¥244.20",
            "谢谢惠顾 欢迎再来",
        ])
    }

    // MARK: - Parse

    static func parse(lines: [String]) -> Result {
        let year = Calendar.current.component(.year, from: Date())

        // 1. Merchant candidate — first short line, no digits, no separators.
        let merchant = lines.first(where: { isMerchantCandidate($0) })

        // 2. Grand total — line containing a total keyword wins.
        var totalCents: Int?
        for (i, line) in lines.enumerated() {
            guard looksLikeTotal(line) else { continue }
            if let a = ParserKit.extractAmountCents(from: line)?.cents {
                totalCents = a; break
            }
            if i + 1 < lines.count,
               let a = ParserKit.extractAmountCents(from: lines[i+1])?.cents {
                totalCents = a; break
            }
        }
        // Fallback — largest amount anywhere.
        if totalCents == nil {
            totalCents = lines.compactMap { ParserKit.extractAmountCents(from: $0)?.cents }.max()
        }

        // 3. Date — first parseable timestamp.
        let date = lines.compactMap { ParserKit.extractDate(from: $0, defaultYear: year) }.first ?? Date()

        // 4. Line items — every line with an amount, excluding total-ish rows.
        var items: [Result.LineItem] = []
        for line in lines {
            if looksLikeTotal(line) { continue }
            guard let amt = ParserKit.extractAmountCents(from: line) else { continue }
            let name = extractItemName(from: line)
            guard !name.isEmpty else { continue }
            if amt.cents <= 0 { continue }
            if let grand = totalCents, amt.cents >= grand { continue }
            items.append(.init(name: name, amountCents: amt.cents))
        }

        let category: Category.Slug? = merchant.flatMap {
            MerchantClassifier.shared.classify(merchant: $0)
        }

        return Result(
            merchant: merchant,
            amountCents: totalCents,
            date: date,
            items: items,
            suggestedCategory: category,
            rawText: lines
        )
    }

    // MARK: - Heuristics

    private static let totalKeywords = [
        "合计", "总计", "应付", "总额", "付款", "实付",
        "Total", "TOTAL", "total", "Amount Due", "AMOUNT",
    ]

    private static func looksLikeTotal(_ s: String) -> Bool {
        totalKeywords.contains { s.contains($0) }
    }

    private static func isMerchantCandidate(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return false }
        if trimmed.count > 22 { return false }
        if trimmed.rangeOfCharacter(from: .decimalDigits) != nil { return false }
        if trimmed.contains("—") || trimmed.contains("---") { return false }
        return true
    }

    private static func extractItemName(from line: String) -> String {
        let range = NSRange(line.startIndex..., in: line)
        let stripped = ParserKit.amountRegex.stringByReplacingMatches(
            in: line, range: range, withTemplate: "")
        return stripped
            .replacingOccurrences(of: ":", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
