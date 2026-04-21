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

    /// 两段式:Vision 拿原始文本行 → 若配了可用的 LLM 引擎就走 LLM 结构化抽取
    /// (上下文感知, 能纠 OCR 错字, 能处理多列对齐), 否则退回原来的正则 heuristic.
    /// Language correction 关掉,因为收据里 SKU / 专有名词多,iOS 语言模型会乱纠。
    static func recognize(image: UIImage) async throws -> Result {
        let lines = try await VisionOCRService.recognize(image: image, languageCorrection: false)

        if let aiResult = await tryLLMExtract(lines: lines) {
            return aiResult
        }
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

    // MARK: - LLM extraction

    /// Pipes Vision's raw text lines through the currently-selected LLM engine
    /// (PhoneClaw / OpenAI / Claude / …) for structured receipt extraction.
    /// Returns `nil` when:
    ///   - no engine is usable (e.g. Apple Intelligence, or BYO with no key)
    ///   - the model call throws (network / timeout / cancellation)
    ///   - the JSON response can't be decoded
    /// Caller falls back to the regex `parse(lines:)` path in any of those.
    private static func tryLLMExtract(lines: [String]) async -> Result? {
        guard !lines.isEmpty else { return nil }
        let engine = AIEngineStore.shared.selected

        // Same gate as LLMClient.chat — skip engines that don't have a working
        // dispatch (AppleIntelligence has no public text API yet; BYO cloud
        // engines need an api key).
        switch engine {
        case .appleIntelligence:
            return nil
        case .phoneclaw:
            break  // PhoneClawClient handles the rest
        default:
            guard AIEngineStore.shared.apiKey(for: engine)?.isEmpty == false else {
                return nil
            }
        }

        let year = Calendar.current.component(.year, from: Date())
        let rawJoined = lines.enumerated()
            .map { "\($0.offset + 1). \($0.element)" }
            .joined(separator: "\n")

        let systemPrompt = """
        你是收据结构化助手。输入是 Vision OCR 对一张中文/英文收据或账单的原始识别结果(每行一条)。
        识别结果可能有错字(例如"海底涝"应为"海底捞","夸辣锅"应为"麻辣锅"),结合上下文纠正。
        严格按下列 JSON 格式输出,不要任何解释文字,不要 markdown 代码块:
        {
          "merchant": "商户名(无则 null)",
          "total_cents": 金额(以分为单位的整数,无则 null),
          "date": "YYYY-MM-DD(无则 null, 年份缺失时按 \(year) 推断)",
          "items": [
            {"name": "条目名", "amount_cents": 分}
          ]
        }
        amount_cents 规则:¥12.00 → 1200, ¥6.5 → 650。items 不要包含合计/小计/服务费/税费这些汇总行。
        """

        let userPrompt = "OCR 原文:\n\(rawJoined)"

        let reply: String
        do {
            reply = try await LLMClient.chat(
                engine: engine,
                messages: [
                    .init(role: "system", content: systemPrompt),
                    .init(role: "user", content: userPrompt),
                ]
            )
        } catch {
            return nil
        }

        guard let payload = decodeLLMJSON(reply) else { return nil }

        // Assemble the public `Result` with local classifier + raw text preserved —
        // the UI still wants rawText so the user can inspect what Vision saw.
        let merchant = payload.merchant?.trimmingCharacters(in: .whitespacesAndNewlines)
        let items: [Result.LineItem] = (payload.items ?? []).compactMap { item in
            guard let name = item.name?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !name.isEmpty,
                  let cents = item.amount_cents, cents > 0 else { return nil }
            return Result.LineItem(name: name, amountCents: cents)
        }
        let date: Date = payload.date.flatMap(parseISODate) ?? Date()
        let category: Category.Slug? = merchant.flatMap {
            MerchantClassifier.shared.classify(merchant: $0)
        }

        return Result(
            merchant: (merchant?.isEmpty == true) ? nil : merchant,
            amountCents: payload.total_cents,
            date: date,
            items: items,
            suggestedCategory: category,
            rawText: lines
        )
    }

    private struct LLMPayload: Decodable {
        let merchant: String?
        let total_cents: Int?
        let date: String?
        let items: [LLMItem]?
    }

    private struct LLMItem: Decodable {
        let name: String?
        let amount_cents: Int?
    }

    /// Models sometimes wrap JSON in ``` fences or prefix it with "好的,这是..." —
    /// pull out the first {...} block before decoding.
    private static func decodeLLMJSON(_ raw: String) -> LLMPayload? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // Strip markdown code fences if present.
        let stripped: String = {
            if trimmed.hasPrefix("```") {
                let withoutFences = trimmed
                    .replacingOccurrences(of: "```json", with: "")
                    .replacingOccurrences(of: "```JSON", with: "")
                    .replacingOccurrences(of: "```", with: "")
                return withoutFences.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return trimmed
        }()
        // Isolate the outermost JSON object.
        guard let startIdx = stripped.firstIndex(of: "{"),
              let endIdx = stripped.lastIndex(of: "}"),
              startIdx < endIdx else { return nil }
        let jsonSubstring = String(stripped[startIdx...endIdx])
        guard let data = jsonSubstring.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(LLMPayload.self, from: data)
    }

    private static func parseISODate(_ raw: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        for format in ["yyyy-MM-dd HH:mm", "yyyy-MM-dd", "yyyy/MM/dd", "MM-dd"] {
            formatter.dateFormat = format
            if let d = formatter.date(from: raw) { return d }
        }
        return nil
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
