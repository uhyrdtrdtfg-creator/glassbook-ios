import Foundation

// MARK: - Tool protocol

struct ToolResult {
    /// Human-readable summary (fed to Claude as `content[type=text]`).
    let humanSummary: String
    /// Structured JSON payload surfaced in `structuredContent`.
    let json: [String: Any]
}

protocol Tool {
    var name: String { get }
    var description: String { get }
    var inputSchema: [String: Any] { get }
    func execute(arguments: [String: Any]) throws -> ToolResult
}

// MARK: - Registry · 6 tools mirroring Diagram 01

enum ToolRegistry {
    static func all(store: DataStore) -> [Tool] {
        [
            AddTransactionTool(store: store),
            QueryBudgetTool(store: store),
            ListSubscriptionsTool(store: store),
            GetMonthlySummaryTool(store: store),
            FindSimilarTxnsTool(store: store),
            SetBudgetTool(store: store),
        ]
    }
}

// MARK: - 1 · add_transaction

struct AddTransactionTool: Tool {
    let store: DataStore
    let name = "add_transaction"
    let description = "Append a new expense / income row to the Glassbook database."
    var inputSchema: [String: Any] {
        [
            "type": "object",
            "required": ["amount", "category"],
            "properties": [
                "amount":   ["type": "number", "description": "CNY amount (positive)"],
                "category": ["type": "string", "description": "food / transport / shopping / entertainment / home / health / learning / kids / other"],
                "merchant": ["type": "string"],
                "note":     ["type": "string"],
                "kind":     ["type": "string", "enum": ["expense", "income", "transfer"]],
                "timestamp": ["type": "string", "description": "ISO-8601; defaults to now"],
            ],
        ]
    }
    func execute(arguments args: [String: Any]) throws -> ToolResult {
        guard let amount = (args["amount"] as? NSNumber)?.doubleValue, amount > 0 else {
            throw MCPError(code: -32602, message: "amount must be > 0")
        }
        let category = (args["category"] as? String) ?? "other"
        let merchant = (args["merchant"] as? String) ?? category
        let kindRaw  = (args["kind"] as? String) ?? "expense"
        let note     = args["note"] as? String
        let ts: Date
        if let s = args["timestamp"] as? String, let d = ISO8601DateFormatter().date(from: s) { ts = d }
        else { ts = .now }

        let tx = store.addTransaction(amountCNY: amount, category: category,
                                      merchant: merchant, kind: kindRaw,
                                      note: note, timestamp: ts)
        return ToolResult(
            humanSummary: "已记一笔 \(String(format: "¥%.2f", amount)) \(merchant) (\(category)).",
            json: [
                "id": tx.id,
                "amount_cny": amount,
                "category": category,
                "merchant": merchant,
                "timestamp": ISO8601DateFormatter().string(from: ts),
            ]
        )
    }
}

// MARK: - 2 · query_budget

struct QueryBudgetTool: Tool {
    let store: DataStore
    let name = "query_budget"
    let description = "Return current month's budget utilization overall or per-category."
    var inputSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "category": ["type": "string", "description": "Optional — omit for overall total"],
            ],
        ]
    }
    func execute(arguments args: [String: Any]) throws -> ToolResult {
        let category = args["category"] as? String
        let summary = store.budgetSummary(category: category)
        let line = category.map { cat in
            "分类『\(cat)』本月已用 \(summary.usedPct)%，剩余 ¥\(summary.remainingCNY)。"
        } ?? "本月预算已用 \(summary.usedPct)%，剩余 ¥\(summary.remainingCNY)。"
        return ToolResult(
            humanSummary: line,
            json: [
                "used_pct": summary.usedPct,
                "remaining_cny": summary.remainingCNY,
                "total_cny": summary.totalCNY,
                "category": category ?? NSNull(),
            ]
        )
    }
}

// MARK: - 3 · list_subscriptions

struct ListSubscriptionsTool: Tool {
    let store: DataStore
    let name = "list_subscriptions"
    let description = "Return active subscriptions, optionally filtered by category (vps / ai / domain / streaming)."
    var inputSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "filter": ["type": "string", "enum": ["all", "active", "idle_30", "idle_90"]],
            ],
        ]
    }
    func execute(arguments args: [String: Any]) throws -> ToolResult {
        let filter = args["filter"] as? String ?? "all"
        let subs = store.listSubscriptions(filter: filter)
        let total = subs.reduce(0.0) { $0 + $1.monthlyCNY }
        let line = "匹配到 \(subs.count) 项，每月合计 ¥\(String(format: "%.0f", total))。"
        return ToolResult(
            humanSummary: line,
            json: [
                "count": subs.count,
                "monthly_total_cny": total,
                "items": subs.map { [
                    "name": $0.name,
                    "monthly_cny": $0.monthlyCNY,
                    "last_used_days": $0.daysSinceUsed,
                ]},
            ]
        )
    }
}

// MARK: - 4 · get_monthly_summary

struct GetMonthlySummaryTool: Tool {
    let store: DataStore
    let name = "get_monthly_summary"
    let description = "Return this-month total spend, top categories and day-over-day breakdown."
    var inputSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "year":  ["type": "integer"],
                "month": ["type": "integer"],
            ],
        ]
    }
    func execute(arguments args: [String: Any]) throws -> ToolResult {
        let now = Calendar.current.dateComponents([.year, .month], from: .now)
        let year = (args["year"] as? NSNumber)?.intValue ?? now.year ?? 2026
        let month = (args["month"] as? NSNumber)?.intValue ?? now.month ?? 4
        let summary = store.monthlySummary(year: year, month: month)
        return ToolResult(
            humanSummary: "\(year) 年 \(month) 月总支出 ¥\(String(format: "%.0f", summary.totalCNY))，最大分类 \(summary.topCategory)。",
            json: [
                "year": year,
                "month": month,
                "total_cny": summary.totalCNY,
                "tx_count": summary.txCount,
                "top_category": summary.topCategory,
                "by_category": summary.byCategory,
            ]
        )
    }
}

// MARK: - 5 · find_similar_txns

struct FindSimilarTxnsTool: Tool {
    let store: DataStore
    let name = "find_similar_txns"
    let description = "Return up to N transactions whose merchant matches the query (substring, case-insensitive)."
    var inputSchema: [String: Any] {
        [
            "type": "object",
            "required": ["merchant"],
            "properties": [
                "merchant": ["type": "string"],
                "limit":    ["type": "integer", "default": 10],
            ],
        ]
    }
    func execute(arguments args: [String: Any]) throws -> ToolResult {
        guard let merchant = args["merchant"] as? String, !merchant.isEmpty else {
            throw MCPError(code: -32602, message: "merchant required")
        }
        let limit = (args["limit"] as? NSNumber)?.intValue ?? 10
        let results = store.findSimilar(merchant: merchant, limit: limit)
        return ToolResult(
            humanSummary: "找到 \(results.count) 笔匹配 \(merchant) 的交易。",
            json: [
                "count": results.count,
                "transactions": results,
            ]
        )
    }
}

// MARK: - 6 · set_budget

struct SetBudgetTool: Tool {
    let store: DataStore
    let name = "set_budget"
    let description = "Set monthly budget cap, overall or per-category."
    var inputSchema: [String: Any] {
        [
            "type": "object",
            "required": ["amount"],
            "properties": [
                "amount":   ["type": "number"],
                "category": ["type": "string"],
            ],
        ]
    }
    func execute(arguments args: [String: Any]) throws -> ToolResult {
        guard let amount = (args["amount"] as? NSNumber)?.doubleValue, amount > 0 else {
            throw MCPError(code: -32602, message: "amount must be > 0")
        }
        let cat = args["category"] as? String
        store.setBudget(amountCNY: amount, category: cat)
        return ToolResult(
            humanSummary: cat.map { "已将『\($0)』月度预算设为 ¥\(String(format: "%.0f", amount))" } ?? "已将整体月度预算设为 ¥\(String(format: "%.0f", amount))",
            json: [
                "amount_cny": amount,
                "category": cat ?? NSNull(),
            ]
        )
    }
}
