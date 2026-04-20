import Foundation
import UIKit

/// iOS's "smart" punctuation rewrites straight quotes / dashes into curly
/// variants as the user types — great for chat, fatal for JSON / URL / API-key
/// / regex input. Webhook BODY templates are the obvious break: one curly
/// quote and the payload fails to parse on Slack / 飞书 / 钉钉.
///
/// Two-layer defense:
///   1. Global appearance — `UITextField` + `UITextView` ship with smart
///      quotes / dashes / insert-delete disabled from launch. SwiftUI's
///      `TextField` / `TextEditor` both inherit.
///   2. `String.normalizingSmartPunctuation()` — belt-and-suspenders sweep on
///      save paths that carry structured text (webhook templates, base URLs,
///      api keys). Handles text that was already typed on a previous build
///      where smart punctuation was still on.
enum SmartPunctuation {

    /// Call once at app launch. Affects every text input in the app.
    static func disableGlobally() {
        UITextField.appearance().smartQuotesType = .no
        UITextField.appearance().smartDashesType = .no
        UITextField.appearance().smartInsertDeleteType = .no
        UITextView.appearance().smartQuotesType = .no
        UITextView.appearance().smartDashesType = .no
        UITextView.appearance().smartInsertDeleteType = .no
    }
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
