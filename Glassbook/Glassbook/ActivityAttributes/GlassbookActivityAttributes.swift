import ActivityKit
import Foundation

/// Spec v2 §6.1.3 · Live Activity attributes for "零点击入账".
/// Shared between the main app (start / update / end) and the widget extension
/// (renders Lock Screen banner + Dynamic Island).
struct GlassbookActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        /// Expense amount in CNY cents (displayed as ¥X.XX).
        public var amountCents: Int
        /// Merchant label as OCR'd / Shortcut-provided.
        public var merchant: String
        /// Emoji of the suggested category.
        public var categoryEmoji: String
        /// Countdown in seconds until auto-save commits (0 = saved).
        public var secondsRemaining: Int
        /// Total duration of this countdown (for progress ring math).
        public var totalSeconds: Int
        /// Tri-state: .capturing while OCR runs, .confirming during countdown,
        /// .saved once committed.
        public var phaseRaw: String

        public enum Phase: String, Codable, Hashable {
            case capturing, confirming, saved
        }
        public var phase: Phase { Phase(rawValue: phaseRaw) ?? .confirming }

        public init(amountCents: Int, merchant: String, categoryEmoji: String,
                    secondsRemaining: Int, totalSeconds: Int, phase: Phase) {
            self.amountCents = amountCents
            self.merchant = merchant
            self.categoryEmoji = categoryEmoji
            self.secondsRemaining = secondsRemaining
            self.totalSeconds = totalSeconds
            self.phaseRaw = phase.rawValue
        }
    }

    /// Session-level constant. Used as the Activity key.
    public var sessionID: UUID
    public var startedAt: Date

    public init(sessionID: UUID = UUID(), startedAt: Date = .now) {
        self.sessionID = sessionID
        self.startedAt = startedAt
    }
}
