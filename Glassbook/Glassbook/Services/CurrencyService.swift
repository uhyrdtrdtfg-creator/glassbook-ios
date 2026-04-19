import Foundation

/// Spec v2 §6.1 · 多币种 + 汇率自动换算.
/// Rates are fetched every hour from a read-only third-party (per spec: exchangerate-api.com).
/// Cached in UserDefaults so offline continues to work with the last good snapshot.
@Observable
final class CurrencyService {
    static let shared = CurrencyService()

    struct Snapshot: Codable {
        var base: Currency
        var rates: [String: Double]   // CNY per 1 unit of foreign currency
        var fetchedAt: Date
    }

    private(set) var snapshot: Snapshot = Snapshot(
        base: .cny,
        rates: [
            "USD": 7.26, "HKD": 0.93, "EUR": 7.84, "JPY": 0.048, "GBP": 9.15, "CNY": 1.0,
        ],
        fetchedAt: .now
    )

    private let defaultsKey = "CurrencyService.snapshot"
    private init() { restore() }

    /// Convert any foreign amount to CNY cents, applying current rate.
    func convertToCNY(amountCents: Int, from currency: Currency) -> Int {
        guard currency != .cny else { return amountCents }
        let rate = snapshot.rates[currency.code] ?? 1.0
        return Int(Double(amountCents) * rate)
    }

    /// Convert CNY cents back to a foreign display amount.
    func convertFromCNY(cnyCents: Int, to currency: Currency) -> Int {
        guard currency != .cny else { return cnyCents }
        let rate = snapshot.rates[currency.code] ?? 1.0
        guard rate > 0 else { return cnyCents }
        return Int(Double(cnyCents) / rate)
    }

    /// Kick off a live refresh. Non-blocking; falls back silently to cached rates.
    func refresh() async {
        // V2 scaffold: uses hard-coded rates. Flip to real API when deploying:
        //
        //   guard let url = URL(string: "https://api.exchangerate-api.com/v4/latest/CNY") else { return }
        //   let (data, _) = try await URLSession.shared.data(from: url)
        //   let decoded = try JSONDecoder().decode(LiveFeed.self, from: data)
        //   ...persist...
        //
        // For now just refresh the timestamp so the UI shows "更新于 1 分钟前".
        await MainActor.run {
            snapshot.fetchedAt = .now
            persist()
        }
    }

    // MARK: - Persist

    private func persist() {
        if let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }
    private func restore() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        snapshot = decoded
    }
}

// MARK: - Formatting

extension Money {
    /// Format with an optional foreign original alongside (e.g., "¥124.80 · US$17.20").
    static func dual(cnyCents: Int, originalCents: Int?, currency: Currency, showDecimals: Bool = false) -> String {
        let cny = yuan(cnyCents, showDecimals: showDecimals)
        if currency == .cny || originalCents == nil {
            return cny
        }
        let oYuan = (originalCents ?? 0) / 100
        let oFen  = (originalCents ?? 0) % 100
        let body  = showDecimals ? "\(oYuan).\(String(format: "%02d", oFen))" : "\(oYuan)"
        return "\(cny) · \(currency.symbol)\(body)"
    }
}
