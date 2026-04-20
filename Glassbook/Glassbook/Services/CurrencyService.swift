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

    /// Kick off a live refresh. Hits exchangerate-api.com (free read-only API,
    /// no key needed) and falls back silently to cached rates on failure.
    /// The endpoint returns `rates[CODE] = foreign units per 1 CNY`; we
    /// invert so our in-app rates map `CODE → CNY per 1 foreign unit`.
    func refresh() async {
        guard let url = URL(string: "https://api.exchangerate-api.com/v4/latest/CNY") else { return }
        struct Feed: Codable { let rates: [String: Double]; let time_last_updated: Int? }

        do {
            let (data, resp) = try await URLSession.shared.data(from: url)
            guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw URLError(.badServerResponse)
            }
            let feed = try JSONDecoder().decode(Feed.self, from: data)
            var inverted: [String: Double] = ["CNY": 1.0]
            for (code, r) in feed.rates where r > 0 && code != "CNY" {
                inverted[code] = 1.0 / r
            }
            await MainActor.run {
                // Merge rather than replace — keeps any codes the server didn't return.
                var merged = snapshot.rates
                for (k, v) in inverted { merged[k] = v }
                snapshot = Snapshot(base: .cny, rates: merged, fetchedAt: .now)
                persist()
                print("💱 CurrencyService · refreshed \(inverted.count) rates from exchangerate-api.com")
            }
        } catch {
            print("⚠️ CurrencyService refresh failed: \(error.localizedDescription) · keeping cached rates")
            await MainActor.run {
                snapshot.fetchedAt = .now   // record that we tried, even if it failed
                persist()
            }
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
