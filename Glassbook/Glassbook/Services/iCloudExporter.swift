import Foundation

/// Spec v2 Diagram 01 · iOS app mirrors a JSON snapshot of the Glassbook
/// database into the user's iCloud Drive container so the Mac-side
/// `glassbook-mcp` process (spec Diagram 01) can read it without any
/// remote server. File path matches what DataStore.default() expects.
///
/// Write is best-effort — if the ubiquity container isn't available
/// (simulator without iCloud account, Mac offline), we silently skip so
/// normal app use is never blocked.
enum iCloudExporter {

    /// The ubiquity container identifier matches our iCloud capability.
    static let containerID = "iCloud.app.glassbook.ios"
    static let filename = "glassbook.json"

    struct Snapshot: Codable {
        var transactions: [TxRecord]
        var subscriptions: [SubRecord]
        var budgetTotalCNY: Double
        var budgetByCategory: [String: Double]
        var exportedAt: Date

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
    }

    /// Write the mirror. Returns the URL on success (handy for logging).
    @discardableResult
    static func export(transactions: [Transaction],
                       subscriptions: [Subscription],
                       budget: Budget) -> URL? {
        guard let containerURL = FileManager.default.url(forUbiquityContainerIdentifier: containerID) else {
            print("ℹ️ iCloudExporter · ubiquity container unavailable (no iCloud sign-in?)")
            return nil
        }
        let docs = containerURL.appendingPathComponent("Documents")
        do {
            try FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)
        } catch {
            print("⚠️ iCloudExporter · cannot create Documents: \(error)")
            return nil
        }
        let url = docs.appendingPathComponent(filename)

        let iso = ISO8601DateFormatter()
        let snapshot = Snapshot(
            transactions: transactions.map {
                .init(id: $0.id.uuidString,
                      amount_cny: Double($0.amountCents) / 100,
                      category: $0.categoryID.rawValue,
                      merchant: $0.merchant,
                      kind: $0.kind.rawValue,
                      note: $0.note,
                      timestamp: iso.string(from: $0.timestamp))
            },
            subscriptions: subscriptions.filter(\.isActive).map {
                .init(name: $0.name,
                      monthlyCNY: Double($0.monthlyEquivalentCents) / 100,
                      daysSinceUsed: $0.daysSinceLastUse)
            },
            budgetTotalCNY: Double(budget.monthlyTotalCents) / 100,
            budgetByCategory: Dictionary(uniqueKeysWithValues:
                budget.perCategory.map { ($0.key.rawValue, Double($0.value) / 100) }
            ),
            exportedAt: Date()
        )

        do {
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            print("⚠️ iCloudExporter · write failed: \(error)")
            return nil
        }
    }
}
