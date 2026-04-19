import Foundation

/// Lightweight HTTP client for BYO LLM endpoints. Speaks the OpenAI
/// Chat-Completions wire format, which OpenAI / Claude (via OpenRouter) /
/// Gemini / Ollama / LM Studio all accept (Claude has a native endpoint too,
/// but its `/v1/messages` layout is handled separately below).
enum LLMClient {

    enum ClientError: Error, LocalizedError {
        case missingKey, badStatus(Int, String), malformed
        var errorDescription: String? {
            switch self {
            case .missingKey:          return "未配置 API Key"
            case .badStatus(let c, let b): return "HTTP \(c): \(b.prefix(200))"
            case .malformed:           return "响应格式异常"
            }
        }
    }

    struct Message: Codable { let role: String; let content: String }

    /// Single-shot chat call. Returns the assistant's text reply.
    static func chat(engine: AIEngineStore.Engine,
                     messages: [Message]) async throws -> String {
        let store = AIEngineStore.shared
        let cfg = store.config(for: engine)
        guard let apiKey = store.apiKey(for: engine), !apiKey.isEmpty else {
            throw ClientError.missingKey
        }

        switch engine {
        case .claude:  return try await claudeCall(baseURL: cfg.baseURL, apiKey: apiKey,
                                                   model: cfg.model, messages: messages)
        default:       return try await openAICompatibleCall(baseURL: cfg.baseURL, apiKey: apiKey,
                                                             model: cfg.model, messages: messages)
        }
    }

    // MARK: - OpenAI / Gemini / Ollama / LM Studio / OpenAI-compatible

    private static func openAICompatibleCall(baseURL: String, apiKey: String,
                                             model: String, messages: [Message]) async throws -> String {
        guard var url = URL(string: baseURL) else { throw ClientError.malformed }
        url = url.appendingPathComponent("chat/completions")

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        struct Payload: Codable {
            let model: String
            let messages: [Message]
            let stream: Bool
            let max_tokens: Int
        }
        req.httpBody = try JSONEncoder().encode(
            Payload(model: model, messages: messages, stream: false, max_tokens: 600)
        )

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
            throw ClientError.badStatus(code, String(data: data, encoding: .utf8) ?? "")
        }

        struct Choice: Codable { let message: Message }
        struct Response: Codable { let choices: [Choice] }
        guard let decoded = try? JSONDecoder().decode(Response.self, from: data),
              let first = decoded.choices.first?.message.content else {
            throw ClientError.malformed
        }
        return first
    }

    // MARK: - Anthropic native /v1/messages

    private static func claudeCall(baseURL: String, apiKey: String,
                                   model: String, messages: [Message]) async throws -> String {
        guard var url = URL(string: baseURL) else { throw ClientError.malformed }
        url = url.appendingPathComponent("v1/messages")

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Claude uses its own payload shape — `system` as a string, user/assistant
        // as role-tagged messages. System prompts get peeled off the stream.
        var sys: String = ""
        var body: [Message] = []
        for m in messages {
            if m.role == "system" { sys = m.content } else { body.append(m) }
        }
        struct Payload: Codable {
            let model: String
            let max_tokens: Int
            let system: String
            let messages: [Message]
        }
        req.httpBody = try JSONEncoder().encode(
            Payload(model: model, max_tokens: 600, system: sys, messages: body)
        )

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
            throw ClientError.badStatus(code, String(data: data, encoding: .utf8) ?? "")
        }

        struct Block: Codable { let type: String; let text: String? }
        struct Response: Codable { let content: [Block] }
        guard let decoded = try? JSONDecoder().decode(Response.self, from: data) else {
            throw ClientError.malformed
        }
        let text = decoded.content.compactMap { $0.type == "text" ? $0.text : nil }.joined()
        guard !text.isEmpty else { throw ClientError.malformed }
        return text
    }
}
