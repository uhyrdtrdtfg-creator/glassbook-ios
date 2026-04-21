import Foundation

/// iOS's "smart" punctuation rewrites straight quotes / dashes into curly
/// variants as the user types — great for chat, fatal for JSON / URL / API-key
/// / regex input. Webhook BODY templates are the obvious break: one curly
/// quote and the payload fails to parse on Slack / 飞书 / 钉钉.
///
/// We used to also call `UITextField.appearance().smartQuotesType = .no` at
/// app launch, but that threw on some iOS versions when state-restored text
/// fields were already in the responder chain before `GlassbookApp.init()`
/// finished — classic SIGABRT in `-setSmartQuotesType:` on a concrete
/// UITextField. Ripped that out. Two remaining layers:
///
///   1. Per-field SwiftUI modifiers (`.autocorrectionDisabled()`) on structured
///      inputs — webhook template editor, API key / base URL fields. Kills
///      autocorrect and, side-effect, most curly-quote substitutions.
///   2. `String.normalizingSmartPunctuation()` — belt-and-suspenders sweep on
///      save paths. Runs on any already-typed text that still carries curly
///      quotes, so historical data self-heals the first time you edit + save.
enum SmartPunctuation {
    /// No-op placeholder — the global appearance hack is gone. Left as a stub
    /// so old call sites compile while we migrate callers to per-field modifiers.
    static func disableGlobally() {}
}

extension String {
    /// Replace curly quotes / dashes / ellipsis back to their ASCII equivalents
    /// so text that round-trips through iOS's auto-punctuation still produces
    /// valid JSON / URLs.
    func normalizingSmartPunctuation() -> String {
        var out = self
        let pairs: [(String, String)] = [
            ("\u{201C}", "\""),   // "  left double
            ("\u{201D}", "\""),   // "  right double
            ("\u{2018}", "'"),    // '  left single
            ("\u{2019}", "'"),    // '  right single + apostrophe
            ("\u{2013}", "-"),    // –  en dash
            ("\u{2014}", "-"),    // —  em dash
            ("\u{2026}", "..."),  // …  horizontal ellipsis
            ("\u{00A0}", " "),    // non-breaking space
        ]
        for (from, to) in pairs {
            out = out.replacingOccurrences(of: from, with: to)
        }
        return out
    }
}
