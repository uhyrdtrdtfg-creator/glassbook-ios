import Foundation
import Observation

/// Spec v2 §6.1.4 · AI 引擎 (BYO LLM).
/// Five presets + custom OpenAI-compatible endpoint. Drives auto-categorization,
/// year-in-review, and the V2 multi-turn "问账" assistant.
@Observable
final class AIEngineStore {
    static let shared = AIEngineStore()

    enum Engine: String, CaseIterable, Codable, Identifiable, Hashable {
        case appleIntelligence, openAI, claude, gemini, ollama, custom
        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .appleIntelligence: "Apple Intelligence"
            case .openAI: "OpenAI"
            case .claude: "Anthropic Claude"
            case .gemini: "Google Gemini"
            case .ollama: "Ollama (本地)"
            case .custom: "自定义端点"
            }
        }
        var emoji: String {
            switch self {
            case .appleIntelligence: "🍎"
            case .openAI: "AI"
            case .claude: "Cl"
            case .gemini: "G"
            case .ollama: "🦙"
            case .custom: "⚙"
            }
        }
        var tintHex: UInt32 {
            switch self {
            case .appleIntelligence: 0x4A8A5E
            case .openAI:            0x10A37F
            case .claude:            0xD97757
            case .gemini:            0x4285F4
            case .ollama:            0x15172A
            case .custom:            0x7EA8FF
            }
        }
        var defaultBaseURL: String {
            switch self {
            case .appleIntelligence: ""
            case .openAI: "https://api.openai.com/v1"
            case .claude: "https://api.anthropic.com"
            case .gemini: "https://generativelanguage.googleapis.com/v1beta"
            case .ollama: "http://192.168.1.10:11434"
            case .custom: ""
            }
        }
        var defaultModels: [String] {
            switch self {
            case .appleIntelligence: ["on-device"]
            case .openAI: ["gpt-4o", "gpt-4o-mini", "gpt-4-turbo"]
            case .claude: ["claude-opus-4-6", "claude-sonnet-4-6", "claude-haiku-4-5"]
            case .gemini: ["gemini-2.0-flash", "gemini-1.5-pro"]
            case .ollama: ["llama3.2", "qwen2.5", "mistral"]
            case .custom: []
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
                        connected: engine == .claude || engine == .appleIntelligence
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
        var c = config(for: engine); c.model = model
        configs[engine] = c
    }
    func setBaseURL(_ url: String, for engine: Engine) {
        var c = config(for: engine); c.baseURL = url
        configs[engine] = c
    }
    func setAPIKey(_ key: String, for engine: Engine) {
        KeychainService.set(key, for: engine.keychainAccount)
        var c = config(for: engine); c.connected = !key.isEmpty
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
