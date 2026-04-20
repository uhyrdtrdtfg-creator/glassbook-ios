import Foundation

/// Function-calling schemas + local executors for the BYO LLM advisor.
/// Mirrors the MCP server's 6 tools so a future unified registry can expose
/// the same surface to both Claude Desktop (via MCP) and the in-app Advisor
/// (via direct LLM tool use).
enum LLMTools {

    struct Tool {
        let name: String
        let description: String
        /// JSON-schema dictionary ready to drop into OpenAI `tools[]` or
        /// Anthropic `tools[]`. Both vendors accept the same shape.
        let inputSchema: [String: Any]
        /// Sync executor — takes decoded JSON args, returns a stringified JSON
        /// payload that becomes the tool_result content.
        let run: ([String: Any], AppStore) -> String
    }

    static func all() -> [Tool] {
        [queryMonthlySummary, queryCategoryExpense, listSubscriptions,
         querySavingsGoals, queryTrend, findMerchantTransactions]
    }

    // MARK: - query_monthly_summary

    static let queryMonthlySummary = Tool(
        name: "query_monthly_summary",
        description: "Return this month's total expense, budget usage %, daily average, top category and month-over-month change.",
        inputSchema: [
            "type": "object",
            "properties": [:] as [String: Any],
        ],
        run: { _, store in
            let topCat = store.expensesByCategory(in: Date()).first?.0.name ?? "—"
            let payload: [String: Any] = [
                "month_expense_cny":    Double(store.thisMonthExpenseCents) / 100,
                "budget_used_pct":      Int(store.budgetUsedPercent * 100),
                "budget_remaining_cny": Double(store.budgetRemainingCents) / 100,
                "daily_avg_cny":        Double(store.thisMonthDailyAverageCents) / 100,
                "top_category":         topCat,
                "mom_change_pct":       Int(store.monthOverMonthChangePct * 100),
                "tx_count":             store.thisMonthTransactionCount,
            ]
            return jsonString(payload)
        }
    )

    // MARK: - query_category_expense

    static let queryCategoryExpense = Tool(
        name: "query_category_expense",
        description: "Return this month's total for a single category (food / transport / shopping / entertainment / home / health / learning / kids / other).",
        inputSchema: [
            "type": "object",
            "required": ["category"],
            "properties": [
                "category": ["type": "string"] as [String: Any],
            ] as [String: Any],
        ],
        run: { args, store in
            guard let raw = args["category"] as? String,
                  let slug = Category.Slug(rawValue: raw) else {
                return jsonString(["error": "unknown category"])
            }
            let cents = store.transactionsInMonth(Date())
                .filter { $0.kind == .expense && $0.categoryID == slug }
                .reduce(0) { $0 + $1.amountCents }
            return jsonString([
                "category": raw,
                "amount_cny": Double(cents) / 100,
                "tx_count": store.transactionsInMonth(Date()).filter { $0.categoryID == slug }.count,
            ])
        }
    )

    // MARK: - list_subscriptions

    static let listSubscriptions = Tool(
        name: "list_subscriptions",
        description: "List active subscriptions. Optional filter: 'all' / 'idle_30' / 'idle_90'.",
        inputSchema: [
            "type": "object",
            "properties": [
                "filter": ["type": "string", "enum": ["all", "idle_30", "idle_90"]] as [String: Any],
            ] as [String: Any],
        ],
        run: { args, store in
            let filter = (args["filter"] as? String) ?? "all"
            let filtered: [Subscription] = {
                switch filter {
                case "idle_30": return store.subscriptions.filter { $0.zombieLevel != .active }
                case "idle_90": return store.subscriptions.filter { $0.zombieLevel == .dormant }
                default:        return store.subscriptions.filter(\.isActive)
                }
            }()
            return jsonString([
                "count": filtered.count,
                "monthly_total_cny": Double(filtered.reduce(0) { $0 + $1.monthlyEquivalentCents }) / 100,
                "items": filtered.map { [
                    "name": $0.name,
                    "monthly_cny": Double($0.monthlyEquivalentCents) / 100,
                    "days_idle": $0.daysSinceLastUse,
                ] },
            ])
        }
    )

    // MARK: - query_savings_goals

    static let querySavingsGoals = Tool(
        name: "query_savings_goals",
        description: "Return active savings goals with target / current / progress / suggested daily contribution.",
        inputSchema: ["type": "object", "properties": [:] as [String: Any]],
        run: { _, store in
            jsonString([
                "total_saved_cny": Double(store.totalSavedCents) / 100,
                "total_target_cny": Double(store.totalGoalsTargetCents) / 100,
                "goals": store.goals.map { [
                    "name": $0.name,
                    "current_cny": Double($0.currentCents) / 100,
                    "target_cny": Double($0.targetCents) / 100,
                    "progress_pct": Int($0.progress * 100),
                    "daily_target_cny": $0.dailyTargetCents.map { Double($0) / 100 } as Any,
                ] },
            ])
        }
    )

    // MARK: - query_trend

    static let queryTrend = Tool(
        name: "query_trend",
        description: "Return N-month expense trend (default 7).",
        inputSchema: [
            "type": "object",
            "properties": [
                "months": ["type": "integer"] as [String: Any],
            ] as [String: Any],
        ],
        run: { args, store in
            let n = (args["months"] as? Int) ?? 7
            let trend = store.monthlyTrend(months: n)
            return jsonString([
                "months": trend.map { [
                    "label": $0.label,
                    "expense_cny": Double($0.expenseCents) / 100,
                ] },
            ])
        }
    )

    // MARK: - find_merchant_transactions

    static let findMerchantTransactions = Tool(
        name: "find_merchant_transactions",
        description: "Find up to 10 transactions whose merchant contains the query string.",
        inputSchema: [
            "type": "object",
            "required": ["query"],
            "properties": [
                "query": ["type": "string"] as [String: Any],
                "limit": ["type": "integer"] as [String: Any],
            ] as [String: Any],
        ],
        run: { args, store in
            guard let q = args["query"] as? String, !q.isEmpty else {
                return jsonString(["error": "empty query"])
            }
            let limit = (args["limit"] as? Int) ?? 10
            let matches = store.transactions
                .filter { $0.merchant.lowercased().contains(q.lowercased()) }
                .prefix(limit)
            return jsonString([
                "count": matches.count,
                "items": matches.map { [
                    "merchant": $0.merchant,
                    "amount_cny": Double($0.amountCents) / 100,
                    "timestamp": ISO8601DateFormatter().string(from: $0.timestamp),
                    "category": $0.categoryID.rawValue,
                ] },
            ])
        }
    )

    // MARK: - Helpers

    private static func jsonString(_ payload: Any) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: payload) else {
            return "{}"
        }
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}
