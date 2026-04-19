import Foundation

/// Read / write Glassbook data sitting on iCloud Drive.
///
/// The iOS app persists SwiftData to the container at:
///   ~/Library/Mobile Documents/iCloud~app~glassbook~ios/Documents/glassbook.json
///
/// This Mac-side process opens the SAME file via the user's iCloud Drive mount.
/// When the iOS app runs SQLCipher (v1.0+) this layer will speak SQL instead of
/// JSON; keeping the surface the same lets the tool implementations stay stable.
///
/// For the V0 scaffold we fall back to a seeded in-memory dataset if no file
/// exists — this makes `glassbook-mcp --selftest` runnable on any machine.
final class DataStore {

    // MARK: - Models (matches iOS Transaction struct surface)

    struct TxRecord: Codable {
        var id: String
        var amount_cny: Double
        var category: String
        var merchant: String
        var kind: String
        var note: String?
        var timestamp: String
    }

    struct SubRecord: Codable {
        var name: String
        var monthlyCNY: Double
        var daysSinceUsed: Int
    }

    struct Snapshot: Codable {
        var transactions: [TxRecord]
        var subscriptions: [SubRecord]
        var budgetTotalCNY: Double
        var budgetByCategory: [String: Double]
    }

    // MARK: - Init / load

    private let url: URL
    private var snapshot: Snapshot

    static func `default`() -> DataStore {
        // Default path inside the iCloud Drive container for Glassbook.
        let home = FileManager.default.homeDirectoryForCurrentUser
        let url = home.appendingPathComponent("Library/Mobile Documents/iCloud~app~glassbook~ios/Documents/glassbook.json")
        return DataStore(url: url)
    }

    init(url: URL) {
        self.url = url
        self.snapshot = DataStore.loadOrSeed(url: url)
    }

    private static func loadOrSeed(url: URL) -> Snapshot {
        if let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode(Snapshot.self, from: data) {
            return decoded
        }
        FileHandle.standardError.write("ℹ️ glassbook.json not found at \(url.path), using seed.\n".data(using: .utf8) ?? Data())
        return seedSnapshot()
    }

    private static func seedSnapshot() -> Snapshot {
        let iso = ISO8601DateFormatter()
        return Snapshot(
            transactions: [
                .init(id: UUID().uuidString, amount_cny: 28.0,  category: "food",     merchant: "兰州牛肉面", kind: "expense", note: nil, timestamp: iso.string(from: .now.addingTimeInterval(-3600*2))),
                .init(id: UUID().uuidString, amount_cny: 299.0, category: "shopping", merchant: "优衣库",     kind: "expense", note: nil, timestamp: iso.string(from: .now.addingTimeInterval(-3600*18))),
                .init(id: UUID().uuidString, amount_cny: 86.0,  category: "transport", merchant: "滴滴出行", kind: "expense", note: nil, timestamp: iso.string(from: .now.addingTimeInterval(-3600*26))),
            ],
            subscriptions: [
                .init(name: "RackNerd KVM", monthlyCNY: 10.4,  daysSinceUsed: 1),
                .init(name: "Claude Pro",    monthlyCNY: 145.2, daysSinceUsed: 0),
                .init(name: "ChatGPT Plus",  monthlyCNY: 145.2, daysSinceUsed: 45),
                .init(name: "Netflix",        monthlyCNY: 128.0, daysSinceUsed: 38),
            ],
            budgetTotalCNY: 6000,
            budgetByCategory: [
                "food": 1500, "transport": 600, "shopping": 1200, "kids": 500,
            ]
        )
    }

    private func persist() {
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(snapshot) {
            try? data.write(to: url)
        }
    }

    // MARK: - Tool entry points

    func addTransaction(amountCNY: Double, category: String, merchant: String,
                        kind: String, note: String?, timestamp: Date) -> TxRecord {
        let rec = TxRecord(
            id: UUID().uuidString,
            amount_cny: amountCNY,
            category: category,
            merchant: merchant,
            kind: kind,
            note: note,
            timestamp: ISO8601DateFormatter().string(from: timestamp)
        )
        snapshot.transactions.insert(rec, at: 0)
        persist()
        return rec
    }

    struct BudgetSummary { let usedPct: Int; let remainingCNY: Double; let totalCNY: Double }

    func budgetSummary(category: String?) -> BudgetSummary {
        let cal = Calendar.current
        let now = Date()
        let iso = ISO8601DateFormatter()
        let inMonth = snapshot.transactions.filter { tx in
            guard let d = iso.date(from: tx.timestamp) else { return false }
            return cal.component(.year, from: d) == cal.component(.year, from: now)
                && cal.component(.month, from: d) == cal.component(.month, from: now)
                && tx.kind == "expense"
                && (category == nil || tx.category == category)
        }
        let spent = inMonth.reduce(0.0) { $0 + $1.amount_cny }
        let total = category.flatMap { snapshot.budgetByCategory[$0] } ?? snapshot.budgetTotalCNY
        let pct = total > 0 ? Int(spent / total * 100) : 0
        return BudgetSummary(usedPct: pct, remainingCNY: max(0, total - spent), totalCNY: total)
    }

    func listSubscriptions(filter: String) -> [SubRecord] {
        switch filter {
        case "idle_30": return snapshot.subscriptions.filter { $0.daysSinceUsed >= 30 }
        case "idle_90": return snapshot.subscriptions.filter { $0.daysSinceUsed >= 90 }
        case "active":  return snapshot.subscriptions.filter { $0.daysSinceUsed < 30 }
        default:        return snapshot.subscriptions
        }
    }

    struct MonthlySummary {
        let totalCNY: Double
        let txCount: Int
        let topCategory: String
        let byCategory: [String: Double]
    }

    func monthlySummary(year: Int, month: Int) -> MonthlySummary {
        let cal = Calendar.current
        let iso = ISO8601DateFormatter()
        let rows = snapshot.transactions.filter { tx in
            guard tx.kind == "expense", let d = iso.date(from: tx.timestamp) else { return false }
            return cal.component(.year, from: d) == year && cal.component(.month, from: d) == month
        }
        var by: [String: Double] = [:]
        for r in rows { by[r.category, default: 0] += r.amount_cny }
        let top = by.max { $0.value < $1.value }?.key ?? "—"
        return MonthlySummary(
            totalCNY: rows.reduce(0) { $0 + $1.amount_cny },
            txCount: rows.count,
            topCategory: top,
            byCategory: by
        )
    }

    func findSimilar(merchant: String, limit: Int) -> [[String: Any]] {
        let needle = merchant.lowercased()
        return snapshot.transactions
            .filter { $0.merchant.lowercased().contains(needle) }
            .prefix(limit)
            .map { [
                "id": $0.id,
                "amount_cny": $0.amount_cny,
                "category": $0.category,
                "merchant": $0.merchant,
                "timestamp": $0.timestamp,
            ] }
    }

    func setBudget(amountCNY: Double, category: String?) {
        if let cat = category {
            snapshot.budgetByCategory[cat] = amountCNY
        } else {
            snapshot.budgetTotalCNY = amountCNY
        }
        persist()
    }
}
