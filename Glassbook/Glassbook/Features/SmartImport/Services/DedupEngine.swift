import Foundation

/// Spec §5.4 · 自动去重.
/// Rule: same merchant + same amount + ≤5 min window = duplicate.
enum DedupEngine {
    static let timeWindow: TimeInterval = 5 * 60

    /// Per-row check against already-stored transactions.
    static func isDuplicate(_ row: PendingImportRow, against existing: [Transaction]) -> Bool {
        existing.contains { tx in
            tx.amountCents == row.amountCents &&
            Self.similarMerchant(tx.merchant, row.merchant) &&
            abs(tx.timestamp.timeIntervalSince(row.timestamp)) < timeWindow
        }
    }

    /// Mutates a pending batch so that duplicates are flagged + deselected by default
    /// (the user can still opt-in — Spec §5.5 user-control requirement).
    static func markDuplicates(_ rows: [PendingImportRow],
                               against existing: [Transaction]) -> [PendingImportRow] {
        // Also de-dup within the batch itself (two platforms → same purchase).
        var seen: [(merchant: String, cents: Int, ts: Date)] = []
        return rows.map { row in
            var copy = row
            let dupOfExisting = isDuplicate(copy, against: existing)
            let dupOfBatch = seen.contains {
                $0.cents == copy.amountCents &&
                Self.similarMerchant($0.merchant, copy.merchant) &&
                abs($0.ts.timeIntervalSince(copy.timestamp)) < timeWindow
            }
            copy.isDuplicate = dupOfExisting || dupOfBatch
            copy.isSelected = !copy.isDuplicate
            seen.append((copy.merchant, copy.amountCents, copy.timestamp))
            return copy
        }
    }

    // MARK: - Merchant similarity
    // Two merchants are "the same" if the shorter one is a substring of the longer
    // after normalization (handles "美团" vs "美团外卖" vs "美团 · 麦当劳").
    private static func similarMerchant(_ a: String, _ b: String) -> Bool {
        let na = normalize(a); let nb = normalize(b)
        guard !na.isEmpty, !nb.isEmpty else { return false }
        return na.contains(nb) || nb.contains(na)
    }

    private static func normalize(_ s: String) -> String {
        s.lowercased()
         .replacingOccurrences(of: " ", with: "")
         .replacingOccurrences(of: "·", with: "")
         .replacingOccurrences(of: "-", with: "")
    }
}
