import Foundation
import Observation

/// Spec v2 §6.2.7 · 设备端 Webhook.
/// When a budget over-runs / subscription renews / high-ticket spend lands,
/// the phone itself POSTs JSON to the user's Slack / 飞书 / n8n URL. No relay.
@Observable
final class WebhookStore {
    static let shared = WebhookStore()

    enum Trigger: String, CaseIterable, Codable {
        case budgetOverrun = "budget_overrun"
        case subscriptionRenewal = "subscription_renewal_t3"
        case largeSpend = "large_spend"
        case weeklyDigest = "weekly_digest"

        var displayName: String {
            switch self {
            case .budgetOverrun: "预算超支"
            case .subscriptionRenewal: "订阅 T-3 到期"
            case .largeSpend: "单笔 >¥500"
            case .weeklyDigest: "周度摘要"
            }
        }
        var emoji: String {
            switch self {
            case .budgetOverrun: "⚠️"
            case .subscriptionRenewal: "⏰"
            case .largeSpend: "💸"
            case .weeklyDigest: "📬"
            }
        }
    }

    enum HTTPMethod: String, Codable, CaseIterable {
        case post = "POST"
        case put = "PUT"
        case get = "GET"
    }

    struct Endpoint: Codable, Identifiable, Hashable {
        var id: UUID
        var name: String
        var url: String
        var platform: Platform
        var enabledTriggers: Set<Trigger>
        var isEnabled: Bool = true
        var httpMethod: HTTPMethod = .post
        var useCustomBody: Bool = false
        var contentType: String = "application/json; charset=utf-8"
        var bodyTemplate: String = ""

        enum Platform: String, Codable, CaseIterable {
            case slack, feishu, dingtalk, n8n, custom
            var displayName: String {
                switch self {
                case .slack: "Slack"
                case .feishu: "飞书"
                case .dingtalk: "钉钉"
                case .n8n: "n8n"
                case .custom: "自定义"
                }
            }
            var tintHex: UInt32 {
                switch self {
                case .slack: 0x611F69
                case .feishu: 0x00D6B9
                case .dingtalk: 0x1677FF
                case .n8n: 0xEA4B71
                case .custom: 0x7EA8FF
                }
            }
        }
    }

    private(set) var endpoints: [Endpoint] {
        didSet { persist() }
    }
    private let storageKey = "WebhookStore.endpoints"

    private init() {
        self.endpoints = []
        restore()
        if endpoints.isEmpty {
            // Seed with one canonical Slack target so the settings page has content.
            endpoints = [
                Endpoint(id: UUID(),
                         name: "#fin-alerts",
                         url: "https://hooks.slack.com/services/T00/B00/…",
                         platform: .slack,
                         enabledTriggers: [.budgetOverrun, .largeSpend]),
                Endpoint(id: UUID(),
                         name: "飞书 · 家庭群",
                         url: "https://open.feishu.cn/open-apis/bot/v2/hook/…",
                         platform: .feishu,
                         enabledTriggers: [.subscriptionRenewal]),
            ]
        }
    }

    func add(_ endpoint: Endpoint) { endpoints.append(endpoint) }
    func delete(id: UUID) { endpoints.removeAll { $0.id == id } }
    func update(_ endpoint: Endpoint) {
        if let idx = endpoints.firstIndex(where: { $0.id == endpoint.id }) {
            endpoints[idx] = endpoint
        }
    }

    /// Fire a trigger. Real POST: each matching endpoint gets a platform-shaped
    /// JSON body posted in the background. Network failures are logged, not
    /// surfaced to the UI — these are best-effort notifications.
    func emit(_ trigger: Trigger, title: String, body: String) {
        for endpoint in endpoints where endpoint.isEnabled
            && endpoint.enabledTriggers.contains(trigger) {
            let ctx = TemplateContext(
                trigger: trigger, title: title, body: body,
                endpointName: endpoint.name
            )
            Task.detached(priority: .utility) {
                await Self.send(endpoint: endpoint, context: ctx)
            }
        }
    }

    private static func send(endpoint: Endpoint, context: TemplateContext) async {
        guard let url = URL(string: endpoint.url) else {
            print("⚠️ Webhook [\(endpoint.name)] bad URL: \(endpoint.url)")
            return
        }
        var req = URLRequest(url: url)
        req.httpMethod = endpoint.httpMethod.rawValue
        req.setValue("Glassbook/1.0 (iOS)", forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 8

        if endpoint.httpMethod != .get {
            let contentType = endpoint.useCustomBody
                ? endpoint.contentType
                : "application/json; charset=utf-8"
            req.setValue(contentType, forHTTPHeaderField: "Content-Type")
            req.httpBody = bodyData(for: endpoint, context: context)
        }

        do {
            let (_, resp) = try await URLSession.shared.data(for: req)
            let code = (resp as? HTTPURLResponse)?.statusCode ?? -1
            print("🔔 Webhook → \(endpoint.platform.displayName) [\(endpoint.name)] HTTP \(code)")
        } catch {
            print("⚠️ Webhook [\(endpoint.name)] failed: \(error.localizedDescription)")
        }
    }

    private static func bodyData(for endpoint: Endpoint,
                                 context: TemplateContext) -> Data? {
        if endpoint.useCustomBody && !endpoint.bodyTemplate.isEmpty {
            let rendered = WebhookTemplate.render(endpoint.bodyTemplate, context: context)
            return rendered.data(using: .utf8)
        }
        let payload = defaultPayload(platform: endpoint.platform, context: context)
        return try? JSONSerialization.data(withJSONObject: payload)
    }

    /// Platform-specific body shapes. Slack & Feishu each expect their own
    /// JSON schema; n8n / custom receive a generic envelope they can adapt.
    private static func defaultPayload(platform: Endpoint.Platform,
                                       context: TemplateContext) -> [String: Any] {
        let title = context.title, body = context.body
        switch platform {
        case .slack:
            return ["text": "*\(title)*\n\(body)"]
        case .feishu:
            return ["msg_type": "text", "content": ["text": "\(title)\n\(body)"]]
        case .dingtalk:
            return ["msgtype": "text", "text": ["content": "\(title)\n\(body)"]]
        case .n8n, .custom:
            return [
                "source": "glassbook-ios",
                "title": title,
                "body": body,
                "trigger": context.trigger.rawValue,
                "timestamp": context.timestamp,
            ]
        }
    }

    // MARK: - Persist

    private func persist() {
        if let data = try? JSONEncoder().encode(endpoints) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
    private func restore() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([Endpoint].self, from: data) else { return }
        endpoints = decoded
    }
}

// MARK: - Body template

struct TemplateContext {
    let trigger: WebhookStore.Trigger
    let title: String
    let body: String
    let timestamp: String
    let endpointName: String

    init(trigger: WebhookStore.Trigger,
         title: String,
         body: String,
         endpointName: String = "",
         timestamp: String = ISO8601DateFormatter().string(from: Date())) {
        self.trigger = trigger
        self.title = title
        self.body = body
        self.endpointName = endpointName
        self.timestamp = timestamp
    }

    /// Flat map for `{{key}}` / `{{dotted.key}}` substitution.
    var variables: [String: String] {
        [
            "title": title,
            "body": body,
            "trigger": trigger.rawValue,
            "trigger.name": trigger.displayName,
            "trigger.emoji": trigger.emoji,
            "timestamp": timestamp,
            "endpoint.name": endpointName,
        ]
    }

    static var sample: TemplateContext {
        TemplateContext(
            trigger: .budgetOverrun,
            title: "餐饮预算超支 108%",
            body: "本月已花 ¥2,160 · 预算 ¥2,000 · 剩 3 天",
            endpointName: "#fin-alerts",
            timestamp: "2025-04-20T12:00:00Z"
        )
    }
}

enum WebhookTemplate {
    /// The placeholder names the UI surfaces to the user.
    static let knownVariables: [(key: String, example: String)] = [
        ("title", "事件标题"),
        ("body", "事件描述"),
        ("trigger", "触发器 ID · budget_overrun 等"),
        ("trigger.name", "触发器中文名"),
        ("trigger.emoji", "触发器 emoji"),
        ("timestamp", "ISO 8601 时间戳"),
        ("endpoint.name", "当前端点名称"),
    ]

    struct Preset: Identifiable {
        let id = UUID()
        let label: String
        let detail: String
        let body: String
    }

    static let presets: [Preset] = [
        Preset(label: "Slack · 纯文本",
               detail: "{{trigger.emoji}} + 标题加粗 + 正文",
               body: """
               {
                 "text": "{{trigger.emoji}} *{{title}}*\\n{{body}}"
               }
               """),
        Preset(label: "飞书 · 文本机器人",
               detail: "msg_type=text · 单段文本",
               body: """
               {
                 "msg_type": "text",
                 "content": {
                   "text": "{{title}}\\n{{body}}"
                 }
               }
               """),
        Preset(label: "钉钉 · 文本机器人",
               detail: "msgtype=text · 单段文本",
               body: """
               {
                 "msgtype": "text",
                 "text": {
                   "content": "{{title}}\\n{{body}}"
                 }
               }
               """),
        Preset(label: "Discord · content",
               detail: "**标题** + 正文",
               body: """
               {
                 "content": "**{{title}}**\\n{{body}}"
               }
               """),
        Preset(label: "通用 JSON · 全字段",
               detail: "title / body / trigger / timestamp",
               body: """
               {
                 "source": "glassbook-ios",
                 "title": "{{title}}",
                 "body": "{{body}}",
                 "trigger": "{{trigger}}",
                 "trigger_name": "{{trigger.name}}",
                 "timestamp": "{{timestamp}}"
               }
               """),
    ]

    /// Replace every `{{key}}` with the matching value. Unknown keys render as
    /// empty strings so a half-configured template doesn't ship `{{foo}}`
    /// literals. Values are JSON-string-escaped so a title containing `"` or
    /// `\n` still produces valid JSON.
    static func render(_ template: String, context: TemplateContext) -> String {
        let vars = context.variables
        var out = ""
        out.reserveCapacity(template.count)
        var i = template.startIndex
        while i < template.endIndex {
            if template[i...].hasPrefix("{{"),
               let end = template.range(of: "}}", range: i..<template.endIndex) {
                let keyStart = template.index(i, offsetBy: 2)
                let key = template[keyStart..<end.lowerBound]
                    .trimmingCharacters(in: .whitespaces)
                let raw = vars[key] ?? ""
                out += jsonEscape(raw)
                i = end.upperBound
            } else {
                out.append(template[i])
                i = template.index(after: i)
            }
        }
        return out
    }

    private static func jsonEscape(_ s: String) -> String {
        var out = ""
        out.reserveCapacity(s.count)
        for ch in s {
            switch ch {
            case "\\": out += "\\\\"
            case "\"": out += "\\\""
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            default:
                if let scalar = ch.unicodeScalars.first, scalar.value < 0x20 {
                    out += String(format: "\\u%04x", scalar.value)
                } else {
                    out.append(ch)
                }
            }
        }
        return out
    }
}
