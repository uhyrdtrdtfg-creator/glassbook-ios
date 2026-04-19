import Foundation

/// Spec §5.4 · 自动去重.
/// Rules:
///   1. Strict: same merchant + same amount + ≤5 min window = duplicate.
///   2. Cross-platform: same amount + same minute + different source ⇒ likely
///      the same purchase seen from two rails (e.g. WeChat "广东 ELEVEN 7"
///      and CMB "711便利店" at 12:27 · ¥5.90 are the same 7-Eleven tap).
enum DedupEngine {
    static let timeWindow: TimeInterval = 5 * 60
    static let crossPlatformWindow: TimeInterval = 90   // 1.5 min

    /// Per-row check against already-stored transactions.
    static func isDuplicate(_ row: PendingImportRow, against existing: [Transaction]) -> Bool {
        existing.contains { tx in
            let sameAmount = tx.amountCents == row.amountCents
            let dt = abs(tx.timestamp.timeIntervalSince(row.timestamp))
            // Strict path.
            if sameAmount && Self.similarMerchant(tx.merchant, row.merchant) && dt < timeWindow {
                return true
            }
            // Cross-platform: same minute, same amount, clearly different source.
            let rowPlatformSource = platformSource(row.source)
            if sameAmount && dt < crossPlatformWindow
               && tx.source != .manual
               && tx.source != rowPlatformSource {
                return true
            }
            return false
        }
    }

    static func markDuplicates(_ rows: [PendingImportRow],
                               against existing: [Transaction]) -> [PendingImportRow] {
        var seen: [(merchant: String, cents: Int, ts: Date, source: ImportBatch.Platform)] = []
        return rows.map { row in
            var copy = row
            let dupOfExisting = isDuplicate(copy, against: existing)
            let dupOfBatch = seen.contains { s in
                let sameAmount = s.cents == copy.amountCents
                let dt = abs(s.ts.timeIntervalSince(copy.timestamp))
                if sameAmount && Self.similarMerchant(s.merchant, copy.merchant) && dt < timeWindow {
                    return true
                }
                if sameAmount && dt < crossPlatformWindow && s.source != copy.source {
                    return true
                }
                return false
            }
            copy.isDuplicate = dupOfExisting || dupOfBatch
            copy.isSelected = !copy.isDuplicate
            seen.append((copy.merchant, copy.amountCents, copy.timestamp, copy.source))
            return copy
        }
    }

    // MARK: - Platform ↔ Source mapping

    private static func platformSource(_ p: ImportBatch.Platform) -> Transaction.Source {
        switch p {
        case .alipay:   .alipay
        case .wechat:   .wechat
        case .cmb:      .cmb
        case .jd:       .jd
        case .meituan:  .meituan
        case .douyin:   .douyin
        case .otherBank: .otherOCR
        }
    }

    // MARK: - Merchant similarity

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
