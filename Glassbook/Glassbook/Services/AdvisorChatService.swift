import Foundation
import Observation

/// Spec v2 · AI 财务顾问 (V2.0 多轮对话).
/// Sends messages to the currently-selected BYO LLM endpoint. Scaffold uses
/// deterministic local responses when no API key is configured so the UI flow
/// still works in a simulator.
///
/// Item 18 · 服务层 DI — engines + client are init-injected. Tests/previews
/// that don't supply them get a default `AIEngineStore()` + `LLMClient(...)`
/// pair so the deterministic local-respond path works without env wiring.
@Observable
final class AdvisorChatService {

    struct Message: Identifiable, Hashable {
        enum Role: String { case user, assistant, tool }
        let id: UUID
        var role: Role
        var content: String
        var toolName: String?
        var toolResult: String?

        init(role: Role, content: String, toolName: String? = nil, toolResult: String? = nil) {
            self.id = UUID()
            self.role = role
            self.content = content
            self.toolName = toolName
            self.toolResult = toolResult
        }
    }

    var messages: [Message] = []
    var isThinking: Bool = false

    // Strong reference. Service is typically a @State-owned child of AdvisorView,
    // so lifetimes align naturally; keeping this strong also lets unit tests
    // pass a throwaway `AppStore()` without it being deallocated mid-call.
    private let store: AppStore
    private let engines: AIEngineStore
    private let client: LLMClient

    /// Designated init — caller (AppServices factory) supplies a shared engine
    /// store + client so the whole LLM stack agrees on which engine to dispatch.
    init(store: AppStore, engines: AIEngineStore, client: LLMClient) {
        self.store = store
        self.engines = engines
        self.client = client
        messages.append(.init(
            role: .assistant,
            content: "你好 Roger 👋 我可以回答本月预算、分类花费、订阅健康度之类的问题。试着问 **这个月我吃饭花了多少?** 或 **有哪些订阅建议取消?**"
        ))
    }

    /// Test/preview convenience: if no LLM stack is supplied, spin up a local
    /// pair so the deterministic offline router is still exercisable. Real
    /// app flow always goes through `AppServices.advisorChat(store)` which
    /// shares the env-bound engine store.
    convenience init(store: AppStore) {
        // why: wiring a self-contained pair for tests/previews avoids touching
        // `AIEngineStore.shared` from inside the service.
        let engines = AIEngineStore()
        let client = LLMClient(engines: engines)
        self.init(store: store, engines: engines, client: client)
    }

    // MARK: - Entry point

    func send(userInput: String) async {
        let trimmed = userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        await MainActor.run {
            messages.append(.init(role: .user, content: trimmed))
            isThinking = true
        }

        // 1. Route the question. If a real LLM is reachable, call it; otherwise
        //    fall back to the deterministic heuristic.
        //    - Apple Intelligence: no public text API → local
        //    - PhoneClaw: runs via URL scheme bridge, NO api key needed → remote
        //    - All BYO cloud engines: require an api key → local if missing
        let engine = engines.selected
        let hasKey = engines.apiKey(for: engine)?.isEmpty == false
        let useLocal: Bool
        switch engine {
        case .appleIntelligence:
            useLocal = true
        case .phoneclaw:
            useLocal = false
        default:
            useLocal = !hasKey
        }

        let reply: Message
        if useLocal {
            reply = await localRespond(to: trimmed)
        } else {
            do {
                reply = try await remoteRespond(to: trimmed, engine: engine)
            } catch {
                reply = .init(role: .assistant,
                              content: "⚠️ 调用 \(engine.displayName) 失败:\(error.localizedDescription)\n已降级到本地规则回答。")
                let fallback = await localRespond(to: trimmed)
                await MainActor.run {
                    messages.append(reply)
                    messages.append(fallback)
                    isThinking = false
                }
                return
            }
        }
        await MainActor.run {
            messages.append(reply)
            isThinking = false
        }
    }

    // MARK: - Local heuristic router (no network)

    private func localRespond(to q: String) async -> Message {
        try? await Task.sleep(nanoseconds: 400_000_000)

        // "吃饭 / 餐饮"
        if q.containsAny(of: ["吃饭", "餐饮", "吃的", "饮食"]) {
            let cents = categorySum(.food)
            return toolReply(
                toolName: "query_expenses",
                toolResult: "{ category: \"food\", period: \"this_month\", amount: \(cents) }",
                content: "本月餐饮支出 **\(Money.yuan(cents, showDecimals: false))**,占总支出 \(pctOfTotal(cents))。日均 \(Money.yuan(cents / max(1, dayOfMonth), showDecimals: false))。"
            )
        }
        // 预算
        if q.contains("预算") {
            let used = Int(store.budgetUsedPercent * 100)
            let remain = store.budgetRemainingCents
            return toolReply(
                toolName: "query_budget",
                toolResult: "{ used_pct: \(used), remaining: \(remain) }",
                content: "预算已用 **\(used)%**,剩余 \(Money.yuan(remain, showDecimals: false))。按当前日均,月底大约 \(projectedUsedText())。"
            )
        }
        // 订阅
        if q.containsAny(of: ["订阅", "续费", "subscription"]) {
            let count = store.subscriptions.filter(\.isActive).count
            let monthly = store.monthlySubscriptionTotalCents
            let idle = store.subscriptions.filter { $0.zombieLevel != .active }.count
            return toolReply(
                toolName: "list_subscriptions",
                toolResult: "{ active: \(count), monthly_cny: \(monthly), idle_30d: \(idle) }",
                content: "活跃订阅 **\(count) 项**,每月固定 \(Money.yuan(monthly, showDecimals: false))。其中 **\(idle) 项**闲置 30+ 天,建议点「沉没成本」页查看取消清单。"
            )
        }
        // 取消 / 闲置
        if q.containsAny(of: ["取消", "闲置", "沉没"]) {
            let idleSubs = store.subscriptions.filter { $0.zombieLevel != .active }
            let totalDrain = idleSubs.reduce(0) { $0 + $1.monthlyEquivalentCents }
            let names = idleSubs.prefix(3).map(\.name).joined(separator: "、")
            return .init(role: .assistant,
                         content: "优先可取消:**\(names)**。合计每月 \(Money.yuan(totalDrain, showDecimals: false)),年化 \(Money.yuan(totalDrain * 12, showDecimals: false))。")
        }
        // 这个月
        if q.containsAny(of: ["这个月", "本月", "月度"]) {
            return .init(role: .assistant,
                         content: "本月支出 **\(Money.yuan(store.thisMonthExpenseCents, showDecimals: false))** · 日均 \(Money.yuan(store.thisMonthDailyAverageCents, showDecimals: false)) · 较上月 \(pctChangeText())。最大头是 \(store.expensesByCategory(in: Date()).first?.0.name ?? "其他")。")
        }
        // fallback
        return .init(role: .assistant,
                     content: "我可以帮你查预算、分类、订阅、沉没成本。再问一次具体点?比如:\"这个月购物花了多少\"。")
    }

    private func toolReply(toolName: String, toolResult: String, content: String) -> Message {
        .init(role: .assistant, content: content, toolName: toolName, toolResult: toolResult)
    }

    // MARK: - Remote (real LLM) — HTTP through LLMClient

    private func remoteRespond(to q: String, engine: AIEngineStore.Engine) async throws -> Message {
        // Build a compact system prompt with current financial snapshot so the
        // model has real numbers without needing tool calls.
        // §12 脱敏 · 用户名是从设置里来的真名,顶部分类的商户名也可能挂了用户
        // OCR 出的 PII (送货地址 / 卡尾号),发云端前先过 PIIRedactor。
        // system prompt 也过 PII (item 12 余项)。
        let userName = PIIRedactor.redact(store.userName)
        let topCategoriesLine = store.expensesByCategory(in: Date())
            .prefix(3)
            .map { "\(PIIRedactor.redact($0.0.name)) \(Money.yuan($0.1, showDecimals: false))" }
            .joined(separator: ", ")

        let rawSystemPrompt = """
        你是 Glassbook 用户 \(userName) 的记账助手。以下是本月实时数据:
        • 本月总支出: \(Money.yuan(store.thisMonthExpenseCents, showDecimals: false))
        • 预算剩余: \(Money.yuan(store.budgetRemainingCents, showDecimals: false)) (已用 \(Int(store.budgetUsedPercent * 100))%)
        • 日均支出: \(Money.yuan(store.thisMonthDailyAverageCents, showDecimals: false))
        • 订阅支出: \(Money.yuan(store.monthlySubscriptionTotalCents, showDecimals: false))/月, 其中 \(store.subscriptions.filter { $0.zombieLevel != .active }.count) 项闲置 30+ 天
        • 顶部分类: \(topCategoriesLine)
        • 较上月: \(String(format: "%.1f%%", store.monthOverMonthChangePct * 100))

        以中文回答,简短直接,给具体数字。不要加 emoji。
        """
        // 二次过一遍兜底:模板和拼接结果都通过同一脱敏入口,redact 幂等所以重复无害。
        let systemPrompt = PIIRedactor.redact(rawSystemPrompt)

        // §12 脱敏 · 用户可能直接问「我给 13800001111 转了 500 是什么」之类,
        // 或把 OCR 出来的收据原文粘进聊天框。本地 messages 数组仍存原文用于展示,
        // 只在发往云端那一瞬过一遍 PIIRedactor。
        let redactedQ = PIIRedactor.redact(q)

        let reply = try await client.chat(
            engine: engine,
            messages: [
                .init(role: "system", content: systemPrompt),
                .init(role: "user", content: redactedQ),
            ]
        )
        return .init(role: .assistant, content: reply)
    }

    // MARK: - Helpers

    private func categorySum(_ slug: Category.Slug) -> Int {
        store.transactionsInMonth(Date())
            .filter { $0.kind == .expense && $0.categoryID == slug }
            .reduce(0) { $0 + $1.amountCents }
    }

    private func pctOfTotal(_ cents: Int) -> String {
        let total = store.thisMonthExpenseCents
        guard total > 0 else { return "0%" }
        return String(format: "%.1f%%", Double(cents) / Double(total) * 100)
    }

    private var dayOfMonth: Int { Calendar.current.component(.day, from: Date()) }

    private func pctChangeText() -> String {
        let pct = store.monthOverMonthChangePct * 100
        if pct == 0 { return "持平" }
        return String(format: "\(pct > 0 ? "上升" : "下降") %.1f%%", abs(pct))
    }

    private func projectedUsedText() -> String {
        let daily = store.thisMonthDailyAverageCents
        let daysLeft = 30 - dayOfMonth
        let projected = store.thisMonthExpenseCents + daily * max(0, daysLeft)
        let pct = Int(Double(projected) / Double(max(1, store.budget.monthlyTotalCents)) * 100)
        return "用掉 \(pct)%"
    }
}

private extension String {
    func containsAny(of keys: [String]) -> Bool { keys.contains { self.contains($0) } }
}
