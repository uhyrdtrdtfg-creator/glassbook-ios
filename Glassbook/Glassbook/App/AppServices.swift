import Foundation
import Observation

/// Spec v2 · Item 18 (服务层 DI) · Apr 2026.
///
/// 一个轻量服务容器,解耦 LLM 栈对 `AIEngineStore.shared` 的硬依赖。所有
/// 跑在请求路径上的服务 (LLMClient / LLMClassifier / ReceiptOCRService /
/// AdvisorChatService) 现在都通过 init 注入 engines / webhooks,容器在 App
/// 根处用 `.environment(...)` 派发给视图。`AIEngineStore.shared` 仍存在,
/// 仅作为 Watch / Widget 等无 SwiftUI environment 的入口存活,业务代码不
/// 应再读它。
@Observable
final class AppServices {
    let engines: AIEngineStore
    let webhooks: WebhookStore
    let llmClient: LLMClient
    let classifier: LLMClassifier
    let receiptOCR: ReceiptOCRService
    let advisorChat: (AppStore) -> AdvisorChatService

    init(engines: AIEngineStore, webhooks: WebhookStore) {
        self.engines = engines
        self.webhooks = webhooks
        // why: LLMClient must come first — classifier / receiptOCR / advisor wrap it.
        let client = LLMClient(engines: engines)
        self.llmClient = client
        self.classifier = LLMClassifier(engines: engines, client: client)
        self.receiptOCR = ReceiptOCRService(engines: engines, client: client)
        // why: AdvisorChatService still needs a per-conversation `AppStore` so
        // each AdvisorView gets its own message buffer; container exposes a
        // factory rather than a singleton instance.
        self.advisorChat = { store in
            AdvisorChatService(store: store, engines: engines, client: client)
        }
    }
}
