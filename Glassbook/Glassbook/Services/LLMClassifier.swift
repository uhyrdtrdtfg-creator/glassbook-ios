import Foundation

/// Bulk categorize a set of OCR-parsed transactions via the user's chosen
/// BYO LLM (OpenAI / Claude / Qwen / DeepSeek / Ollama / ...). The local
/// `MerchantClassifier` is fast but rule-based and occasionally miscategorizes
/// long-tail merchants; LLM gives much better recall across "深圳市水务（集团）"
/// (home · 居家) vs "美团平台商户" (other) vs "津品汤包半里花海店" (food).
///
/// Spec v2 §6.1.4 · BYO LLM. Opt-in — the confirm screen shows a "AI 自动分类"
/// button that runs this against whichever engine is selected in AIEngineStore.
/// Failure paths (no API key / network / timeout / bad JSON) keep the existing
/// `MerchantClassifier` guesses and surface an error inline.
///
/// Item 18 · 服务层 DI — engines + client are init-injected, no `.shared` reads.
final class LLMClassifier {

    enum Failure: LocalizedError {
        case notConfigured
        case rateLimited
        case networkFailed(String)
        case malformedResponse

        var errorDescription: String? {
            switch self {
            case .notConfigured: return "当前 AI 引擎没配好 API Key · 去 我的 → AI 引擎 填一下"
            case .rateLimited:   return "对方限流了,等一分钟再点"
            case .networkFailed(let m): return "调用失败:\(m)"
            case .malformedResponse: return "模型没按格式回,换个更聪明的 model 试试"
            }
        }
    }

    private let engines: AIEngineStore
    private let client: LLMClient

    init(engines: AIEngineStore, client: LLMClient) {
        self.engines = engines
        self.client = client
    }

    /// Prompt design:
    /// - 系统提示固定所有可选分类,避免模型创造新类别。
    /// - 给出每个类别的日常例子,降低误判 (如"阿婆牛杂" → food 而不是 other)。
    /// - 严格要求 JSON 输出,禁止解释。
    /// - 对输入每条 merchant 用独立 id 编号,避免模型输出顺序错位。
    private static let systemPromptTemplate: String = """
    你是一个中文记账分类助手。我会给你一批刚从支付账单截屏 OCR 出来的\
    商户条目,你要把每一条归到下面 9 个类别之一,**绝对不允许**创造新类别。\

    类别说明(slug · 中文名 · 典型例子):
    - food · 餐饮 · 饭店 / 咖啡 / 外卖 / 超市买菜 / 711便利店 / 麦当劳 / 瑞幸
    - transport · 交通 · 地铁 / 高铁 / 出租车 / 滴滴 / 加油 / 停车费 / 共享单车
    - shopping · 购物 · 淘宝 / 京东 / 拼多多 / 服装 / 化妆品 / 电子产品
    - entertainment · 娱乐 · 电影 / KTV / 游戏充值 / 视频会员 / 音乐订阅
    - home · 居家 · 水电煤气 / 物业 / 房租 / 家具 / 家政 / 装修
    - health · 医疗 · 医院 / 药店 / 体检 / 牙科 / 挂号费
    - learning · 学习 · 书 / 网课 / 培训 / 资格考试 / 文具
    - kids · 孩子 · 奶粉 / 辅食 / 童装 / 早教 / 幼儿园
    - other · 其他 · 转账 / 红包 / 信用卡还款 / 理财 / 无法识别的商户

    输出 JSON 数组,严格按此格式,**不要写任何解释文字、markdown 代码块或前后空白**:
    [{"id":1,"slug":"food"},{"id":2,"slug":"transport"}, ...]

    数组长度 = 输入条目数,id 严格对应输入的 id,slug 必须从上面 9 个里选。
    """

    /// Main entry. Runs synchronously against the selected engine. Caller
    /// expected to show a spinner — bulk calls typically take 2-6 seconds.
    func categorize(_ rows: [PendingImportRow]) async throws -> [UUID: Category.Slug] {
        guard !rows.isEmpty else { return [:] }

        let engine = engines.selected

        // Apple Intelligence has no public text API yet, so it can't classify —
        // surface as `.notConfigured` to push users to a real BYO engine.
        // PhoneClaw DOES work: LLMClient.chat routes `.phoneclaw` through
        // PhoneClawClient (URL scheme + App Group), returns real text, so
        // we let it fall through to the normal dispatch below.
        if engine == .appleIntelligence {
            throw Failure.notConfigured
        }

        // Each row gets a small integer id so the model can line up its output
        // with the input even if it reorders.
        // §12 脱敏 · merchant 偶尔有「XX 外卖 · 13812345678」这种带手机号的串,
        // 或商户注册名里塞完整地址,发云端前过一遍。金额不过,本来就是数字。
        struct Item: Encodable { let id: Int; let merchant: String; let amount_yuan: Double }
        let items: [Item] = rows.enumerated().map { idx, row in
            Item(id: idx + 1, merchant: PIIRedactor.redact(row.merchant),
                 amount_yuan: Double(row.amountCents) / 100.0)
        }
        let payload = try JSONEncoder().encode(items)
        let payloadString = String(data: payload, encoding: .utf8) ?? "[]"

        // system prompt 也过 PII (item 12 余项) — 模板本身写死了类别,但保险起见过一遍,
        // 防御未来有人把用户商户名喂进 prompt 模板。
        let systemPrompt = PIIRedactor.redact(Self.systemPromptTemplate)

        let userPrompt = """
        请给下面这批商户分类,输出严格按系统提示要求的 JSON:
        \(payloadString)
        """

        let reply: String
        do {
            reply = try await client.chat(
                engine: engine,
                messages: [
                    .init(role: "system", content: systemPrompt),
                    .init(role: "user", content: userPrompt),
                ]
            )
        } catch LLMClient.ClientError.missingKey {
            throw Failure.notConfigured
        } catch LLMClient.ClientError.badStatus(let code, _) where code == 429 {
            throw Failure.rateLimited
        } catch let LLMClient.ClientError.badStatus(_, body) {
            throw Failure.networkFailed(body)
        } catch {
            throw Failure.networkFailed(error.localizedDescription)
        }

        return try Self.parse(reply: reply, rows: rows)
    }

    // MARK: - Response parsing

    private struct Decision: Decodable {
        let id: Int
        let slug: String
    }

    /// Pull the JSON array out of the model reply. Some models wrap in
    /// ```json ... ``` fences or add a prose preamble; strip those before
    /// decoding. Any id the model skips leaves the row's existing category alone.
    private static func parse(reply: String, rows: [PendingImportRow]) throws -> [UUID: Category.Slug] {
        let stripped = extractJSONArray(from: reply)
        guard let data = stripped.data(using: .utf8),
              let decisions = try? JSONDecoder().decode([Decision].self, from: data) else {
            throw Failure.malformedResponse
        }
        var out: [UUID: Category.Slug] = [:]
        for d in decisions {
            let idx = d.id - 1
            guard rows.indices.contains(idx) else { continue }
            guard let slug = Category.Slug(rawValue: d.slug) else { continue }
            out[rows[idx].id] = slug
        }
        return out
    }

    // MARK: - Item 7 · 简化商户名

    /// Ask the selected BYO LLM to simplify an OCR-bloated merchant name
    /// (e.g. "深圳市兜点实业有限责任公司" → "兜点便利店"). Returns nil if:
    /// no engine configured / network fails / model misbehaves — caller
    /// silently keeps the original string.
    ///
    /// Kept on this type (not LLMClient) because the prompt is tuned and
    /// post-processing (quote/whitespace strip) lives here.
    func simplifyMerchantName(raw: String) async -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let engine = engines.selected
        if engine == .appleIntelligence { return nil }

        // §12 脱敏 · 用户可能手工把地址塞进了 merchant 字段 (比如「家附近
        // 便利店 · 朝阳区xxx号」),简化名字之前先把明显 PII 掩掉再发云端。
        let redacted = PIIRedactor.redact(trimmed)

        // 用三反引号包裹避免模型把商户名里的冒号/引号当成指令边界。
        let userPrompt = """
        把下面这个商户名简化成用户日常口头叫的版本,去掉"xxx有限公司"、"xx市xx区"、\
        "xx集团xx店"之类的冗余。**只输出简化后的名字**,不要加解释、不要加引号、\
        不要加标点。如果已经很简洁就原样返回。

        输入:
        ```
        \(redacted)
        ```
        """

        let reply: String
        do {
            reply = try await client.chat(
                engine: engine,
                messages: [.init(role: "user", content: userPrompt)]
            )
        } catch {
            return nil
        }

        // Strip whitespace, quotes, markdown fences, trailing period. Model
        // sometimes ignores the "no explanation" rule — take only the first line.
        var cleaned = reply.trimmingCharacters(in: .whitespacesAndNewlines)
        if let firstLine = cleaned.split(whereSeparator: { $0.isNewline }).first {
            cleaned = String(firstLine)
        }
        cleaned = cleaned
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: " \t\"'“”‘’`·「」【】"))

        guard !cleaned.isEmpty, cleaned != trimmed else { return nil }
        // 防御:模型可能返回一整段解释 (> 30 字),放弃。
        guard cleaned.count <= 30 else { return nil }
        return cleaned
    }

    /// Strip common wrappers from LLM output. Handles:
    ///   ```json\n[...]\n```   ```\n[...]\n```   "任何前缀文字 [...] 后缀"
    /// Falls back to the raw string if nothing matches — JSONDecoder will
    /// reject and the caller surfaces malformedResponse.
    private static func extractJSONArray(from text: String) -> String {
        // Fenced code block
        if let fenceRange = text.range(of: #"```(?:json)?\s*([\s\S]*?)\s*```"#,
                                        options: .regularExpression) {
            let inner = String(text[fenceRange])
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
            return inner.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        // First [ ... last ]
        if let start = text.firstIndex(of: "["),
           let end = text.lastIndex(of: "]"),
           start < end {
            return String(text[start...end])
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
