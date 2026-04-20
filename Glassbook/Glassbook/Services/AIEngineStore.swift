import Foundation
import Observation

/// Spec v2 §6.1.4 · AI 引擎 (BYO LLM).
/// Five presets + custom OpenAI-compatible endpoint. Drives auto-categorization,
/// year-in-review, and the V2 multi-turn "问账" assistant.
@Observable
final class AIEngineStore {
    static let shared = AIEngineStore()

    enum Engine: String, CaseIterable, Codable, Identifiable, Hashable {
        case appleIntelligence, phoneclaw, openAI, claude, gemini, qwen, deepseek, ollama, custom
        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .appleIntelligence: "Apple Intelligence"
            case .phoneclaw: "PhoneClaw (本地 Gemma 4)"
            case .openAI: "OpenAI"
            case .claude: "Anthropic Claude"
            case .gemini: "Google Gemini"
            case .qwen: "阿里 · 通义千问"
            case .deepseek: "DeepSeek"
            case .ollama: "Ollama (本地)"
            case .custom: "自定义端点"
            }
        }
        var emoji: String {
            switch self {
            case .appleIntelligence: "🍎"
            case .phoneclaw: "🦾"
            case .openAI: "AI"
            case .claude: "Cl"
            case .gemini: "G"
            case .qwen: "通义"
            case .deepseek: "DS"
            case .ollama: "🦙"
            case .custom: "⚙"
            }
        }
        var tintHex: UInt32 {
            switch self {
            case .appleIntelligence: 0x4A8A5E
            case .phoneclaw:         0x6C4AA8
            case .openAI:            0x10A37F
            case .claude:            0xD97757
            case .gemini:            0x4285F4
            case .qwen:              0x615CED
            case .deepseek:          0x2F6BFF
            case .ollama:            0x15172A
            case .custom:            0x7EA8FF
            }
        }
        var defaultBaseURL: String {
            switch self {
            case .appleIntelligence: ""
            // PhoneClaw 不走 HTTP,通过 phoneclaw:// URL scheme + App Group 桥接,
            // baseURL 只用来展示,不实际拨号。
            case .phoneclaw: "phoneclaw://ask"
            case .openAI: "https://api.openai.com/v1"
            case .claude: "https://api.anthropic.com"
            case .gemini: "https://generativelanguage.googleapis.com/v1beta"
            // Qwen 官方 OpenAI 兼容端点:https://dashscope.aliyuncs.com/compatible-mode/v1
            case .qwen:   "https://dashscope.aliyuncs.com/compatible-mode/v1"
            // DeepSeek 官方 OpenAI 兼容端点:https://api.deepseek.com
            case .deepseek: "https://api.deepseek.com"
            case .ollama: "http://192.168.1.10:11434"
            case .custom: ""
            }
        }
        var defaultModels: [String] {
            switch self {
            case .appleIntelligence: ["on-device"]
            case .phoneclaw: ["gemma-4-e4b-it-4bit", "gemma-4-e2b-it-4bit"]
            case .openAI: ["gpt-4o", "gpt-4o-mini", "gpt-4-turbo"]
            case .claude: ["claude-opus-4-6", "claude-sonnet-4-6", "claude-haiku-4-5"]
            case .gemini: ["gemini-2.0-flash", "gemini-1.5-pro"]
            case .qwen: ["qwen-max", "qwen-plus", "qwen-turbo", "qwen-flash"]
            case .deepseek: ["deepseek-chat", "deepseek-reasoner"]
            case .ollama: ["llama3.2", "qwen2.5", "mistral"]
            case .custom: []
            }
        }
        /// Whether this engine speaks the OpenAI /v1/chat/completions dialect.
        /// Qwen / DeepSeek / Ollama / custom all do; claude uses /v1/messages,
        /// gemini / appleIntelligence / phoneclaw have their own shapes.
        var isOpenAICompatible: Bool {
            switch self {
            case .openAI, .qwen, .deepseek, .ollama, .custom: return true
            case .claude, .gemini, .appleIntelligence, .phoneclaw: return false
            }
        }
        /// Keychain account name used to store this engine's API key.
        var keychainAccount: String { "llm.\(rawValue).apiKey" }
    }

    struct Config: Codable {
        var engine: Engine
        var baseURL: String
        var model: String
        var monthlyCallCount: Int
        var monthlyCostUSD: Double
        var connected: Bool
    }

    private(set) var selected: Engine {
        didSet { persistSelected() }
    }
    private(set) var configs: [Engine: Config] {
        didSet { persistConfigs() }
    }

    private let selectedKey = "AIEngineStore.selected"
    private let configsKey = "AIEngineStore.configs"

    private init() {
        self.selected = .appleIntelligence
        self.configs = [:]
        restore()
        if configs.isEmpty {
            configs = Dictionary(uniqueKeysWithValues:
                Engine.allCases.map { engine in
                    (engine, Config(
                        engine: engine,
                        baseURL: engine.defaultBaseURL,
                        model: engine.defaultModels.first ?? "",
                        monthlyCallCount: engine == .claude ? 147 : 0,
                        monthlyCostUSD: engine == .claude ? 0.82 : 0,
                        connected: engine == .claude || engine == .appleIntelligence || engine == .phoneclaw
                    ))
                }
            )
        }
    }

    func config(for engine: Engine) -> Config {
        configs[engine] ?? Config(
            engine: engine, baseURL: engine.defaultBaseURL,
            model: engine.defaultModels.first ?? "",
            monthlyCallCount: 0, monthlyCostUSD: 0, connected: false
        )
    }

    func setModel(_ model: String, for engine: Engine) {
        var c = config(for: engine); c.model = model.normalizingSmartPunctuation()
        configs[engine] = c
    }
    func setBaseURL(_ url: String, for engine: Engine) {
        var c = config(for: engine); c.baseURL = url.normalizingSmartPunctuation()
        configs[engine] = c
    }
    func setAPIKey(_ key: String, for engine: Engine) {
        // API keys are hex / base64-ish — curly quotes or en-dashes in them
        // always mean auto-correct, never user intent.
        let normalized = key.normalizingSmartPunctuation()
        KeychainService.set(normalized, for: engine.keychainAccount)
        var c = config(for: engine); c.connected = !normalized.isEmpty
        configs[engine] = c
    }
    func apiKey(for engine: Engine) -> String? {
        KeychainService.get(engine.keychainAccount)
    }
    func selectEngine(_ engine: Engine) {
        selected = engine
    }

    // MARK: - Persist

    private func persistSelected() {
        UserDefaults.standard.set(selected.rawValue, forKey: selectedKey)
    }
    private func persistConfigs() {
        if let data = try? JSONEncoder().encode(configs) {
            UserDefaults.standard.set(data, forKey: configsKey)
        }
    }
    private func restore() {
        if let raw = UserDefaults.standard.string(forKey: selectedKey),
           let e = Engine(rawValue: raw) { selected = e }
        if let data = UserDefaults.standard.data(forKey: configsKey),
           let decoded = try? JSONDecoder().decode([Engine: Config].self, from: data) {
            configs = decoded
        }
    }
}
