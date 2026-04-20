import Foundation

/// Queue of transactions captured by a Shortcut-triggered AppIntent that the
/// main app should persist on next foreground. Lives in the App Group so the
/// intent (possibly running without a full app context) and the app both see
/// the same storage.
enum PendingImportQueue {

    struct Entry: Codable, Hashable, Identifiable {
        var id: UUID
        let merchant: String
        let amountCents: Int
        let categorySlug: String
        let platform: String          // ImportBatch.Platform rawValue
        let timestamp: Date
        let createdAt: Date
        init(merchant: String, amountCents: Int, categorySlug: String,
             platform: String, timestamp: Date, createdAt: Date = .now) {
            self.id = UUID()
            self.merchant = merchant
            self.amountCents = amountCents
            self.categorySlug = categorySlug
            self.platform = platform
            self.timestamp = timestamp
            self.createdAt = createdAt
        }
    }

    static let key = "glassbook.pending.imports"

    static func enqueue(_ entry: Entry) {
        var items = all()
        items.append(entry)
        save(items)
    }

    /// Pop and return everything, leaving the queue empty. Called by AppStore
    /// on reload/foreground.
    static func drain() -> [Entry] {
        let items = all()
        save([])
        return items
    }

    static func all() -> [Entry] {
        guard let d = SharedStorage.defaults,
              let data = d.data(forKey: key),
              let decoded = try? JSONDecoder().decode([Entry].self, from: data) else {
            return []
        }
        return decoded
    }

    private static func save(_ entries: [Entry]) {
        guard let d = SharedStorage.defaults else { return }
        if let data = try? JSONEncoder().encode(entries) {
            d.set(data, forKey: key)
        }
    }
}
