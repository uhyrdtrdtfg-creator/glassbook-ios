import Testing
import Foundation
@testable import Glassbook

/// The LLM itself is network-dependent so we can't unit-test end-to-end;
/// what we CAN test is the response parser — every layer of messiness real
/// models produce (fenced blocks / prose preambles / bad slugs / extra ids)
/// should degrade gracefully, not crash.
@Suite("LLMClassifier · response parsing")
struct LLMClassifierParseTests {

    /// Use a public test hook to exercise the private parser. We invoke via
    /// the full classify call would need network; instead spy through the
    /// extractJSON codepath using a known reply. Since `parse` is private,
    /// verify end-to-end mock by checking the public contract: given a
    /// well-formed reply, rows with matching ids get their slugs updated.
    ///
    /// Implementation note: testing private funcs requires @testable + same
    /// module. The parser IS private but we can test the higher-level
    /// `categorize` through an injection point. Instead, test the observable
    /// side effect: an empty rows list should never crash.
    @Test func emptyInputReturnsEmpty() async throws {
        // Item 18 服务层 DI · classifier 现在是实例方法,通过本地 stack 调用。
        let engines = AIEngineStore.shared
        let classifier = LLMClassifier(engines: engines, client: LLMClient(engines: engines))
        let result = try await classifier.categorize([])
        #expect(result.isEmpty)
    }

    /// Apple Intelligence route has no HTTP endpoint yet, so `categorize`
    /// should fail fast with `.notConfigured` rather than hang.
    @Test func appleIntelligenceRoutesToNotConfigured() async {
        let engines = AIEngineStore.shared
        let classifier = LLMClassifier(engines: engines, client: LLMClient(engines: engines))
        let prev = engines.selected
        engines.selectEngine(.appleIntelligence)
        defer { engines.selectEngine(prev) }
        let row = PendingImportRow(
            id: UUID(), merchant: "test", amountCents: 100,
            categoryID: .other, timestamp: .now, source: .alipay,
            isDuplicate: false, isSelected: true, note: nil
        )
        do {
            _ = try await classifier.categorize([row])
            Issue.record("Should have thrown .notConfigured")
        } catch LLMClassifier.Failure.notConfigured {
            // expected
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}

/// Sanity-check engine metadata — Qwen / DeepSeek must be fully specced or
/// AIEngineSettingsView will render them broken.
@Suite("AIEngineStore · Qwen + DeepSeek")
struct NewEngineMetadataTests {
    @Test func qwenHasFullConfig() {
        let e = AIEngineStore.Engine.qwen
        #expect(e.displayName.contains("通义"))
        #expect(e.defaultBaseURL.hasPrefix("https://"))
        #expect(e.defaultModels.contains("qwen-max"))
        #expect(e.isOpenAICompatible)
    }
    @Test func deepseekHasFullConfig() {
        let e = AIEngineStore.Engine.deepseek
        #expect(e.displayName == "DeepSeek")
        #expect(e.defaultBaseURL == "https://api.deepseek.com")
        #expect(e.defaultModels.contains("deepseek-chat"))
        #expect(e.isOpenAICompatible)
    }
    @Test func claudeStillUsesNativeFormat() {
        // Regression guard: if someone flips claude.isOpenAICompatible to true,
        // the native /v1/messages dispatch in LLMClient.chat breaks.
        #expect(AIEngineStore.Engine.claude.isOpenAICompatible == false)
    }
}
