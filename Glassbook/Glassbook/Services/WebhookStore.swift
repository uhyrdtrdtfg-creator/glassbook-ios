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

    struct Endpoint: Codable, Identifiable, Hashable {
        var id: UUID
        var name: String
        var url: String
        var platform: Platform
        var enabledTriggers: Set<Trigger>

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

    /// Fire a trigger. Scaffold logs to console; production: construct a JSON payload
    /// shaped to each platform (Slack `text`, Feishu `msg_type`) and URLSession.POST.
    func emit(_ trigger: Trigger, title: String, body: String) {
        for endpoint in endpoints where endpoint.enabledTriggers.contains(trigger) {
            print("🔔 Webhook → \(endpoint.platform.displayName) [\(endpoint.name)] :: \(title) — \(body)")
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
