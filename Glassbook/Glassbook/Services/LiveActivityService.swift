import Foundation
import ActivityKit

/// Spec v2 §6.1.3 · Drives the "零点击入账" Live Activity from the main app.
/// - `start(pendingAmount:merchant:categoryEmoji:autoSaveSeconds:onCommit:)` kicks off a countdown.
/// - During the countdown the Live Activity is visible on Lock Screen / Dynamic Island.
/// - `commit(sessionID:)` ends the Activity and writes the transaction into AppStore.
/// - `cancel(sessionID:)` ends the Activity without saving.
@Observable
final class LiveActivityService {
    static let shared = LiveActivityService()

    struct Session: Identifiable {
        let id: UUID
        var activityID: String?
        var autoCommitTask: Task<Void, Never>?
    }

    private(set) var activeSessions: [Session] = []
    private init() {}

    // MARK: - Start

    /// Begin a capture flow. Returns the `sessionID`, or nil if Live Activities
    /// aren't authorized on this device.
    @discardableResult
    func start(
        pendingAmountCents: Int,
        merchant: String,
        categoryEmoji: String,
        autoSaveSeconds: Int,
        onAutoCommit: @escaping (UUID) -> Void,
        onDismiss: @escaping (UUID) -> Void = { _ in }
    ) -> UUID? {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("⚠️ Live Activities disabled by the user (Settings → Glassbook).")
            return nil
        }
        let sessionID = UUID()
        let attrs = GlassbookActivityAttributes(sessionID: sessionID, startedAt: .now)
        let initial = GlassbookActivityAttributes.ContentState(
            amountCents: pendingAmountCents,
            merchant: merchant,
            categoryEmoji: categoryEmoji,
            secondsRemaining: autoSaveSeconds,
            totalSeconds: autoSaveSeconds,
            phase: .confirming
        )

        do {
            let activity = try Activity.request(
                attributes: attrs,
                content: .init(state: initial, staleDate: .now.addingTimeInterval(TimeInterval(autoSaveSeconds + 5))),
                pushType: nil
            )
            var session = Session(id: sessionID, activityID: activity.id)
            session.autoCommitTask = Task { [weak self] in
                await self?.tickDown(activity: activity, total: autoSaveSeconds, sessionID: sessionID,
                                     onAutoCommit: onAutoCommit, onDismiss: onDismiss)
            }
            activeSessions.append(session)
            return sessionID
        } catch {
            print("⚠️ Failed to start Live Activity: \(error)")
            return nil
        }
    }

    // MARK: - Tick loop

    private func tickDown(
        activity: Activity<GlassbookActivityAttributes>,
        total: Int,
        sessionID: UUID,
        onAutoCommit: @escaping (UUID) -> Void,
        onDismiss: @escaping (UUID) -> Void
    ) async {
        for remaining in stride(from: total, through: 1, by: -1) {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            guard !Task.isCancelled else { return }
            let state = GlassbookActivityAttributes.ContentState(
                amountCents: activity.content.state.amountCents,
                merchant: activity.content.state.merchant,
                categoryEmoji: activity.content.state.categoryEmoji,
                secondsRemaining: remaining - 1,
                totalSeconds: total,
                phase: .confirming
            )
            await activity.update(.init(state: state, staleDate: .now.addingTimeInterval(10)))
        }
        guard !Task.isCancelled else { return }
        // Transition to .saved briefly so the UI shows a checkmark before dismissing.
        let saved = GlassbookActivityAttributes.ContentState(
            amountCents: activity.content.state.amountCents,
            merchant: activity.content.state.merchant,
            categoryEmoji: activity.content.state.categoryEmoji,
            secondsRemaining: 0,
            totalSeconds: total,
            phase: .saved
        )
        await activity.update(.init(state: saved, staleDate: .now.addingTimeInterval(5)))
        onAutoCommit(sessionID)
        try? await Task.sleep(nanoseconds: 900_000_000)
        await activity.end(nil, dismissalPolicy: .immediate)
        onDismiss(sessionID)
        await MainActor.run { self.activeSessions.removeAll { $0.id == sessionID } }
    }

    // MARK: - Manual commit / cancel

    func commit(sessionID: UUID) async {
        guard let session = activeSessions.first(where: { $0.id == sessionID }) else { return }
        session.autoCommitTask?.cancel()
        if let aid = session.activityID,
           let activity = Activity<GlassbookActivityAttributes>.activities.first(where: { $0.id == aid }) {
            let saved = GlassbookActivityAttributes.ContentState(
                amountCents: activity.content.state.amountCents,
                merchant: activity.content.state.merchant,
                categoryEmoji: activity.content.state.categoryEmoji,
                secondsRemaining: 0,
                totalSeconds: activity.content.state.totalSeconds,
                phase: .saved
            )
            await activity.update(.init(state: saved, staleDate: .now.addingTimeInterval(3)))
            try? await Task.sleep(nanoseconds: 700_000_000)
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        await MainActor.run { activeSessions.removeAll { $0.id == sessionID } }
    }

    func cancel(sessionID: UUID) async {
        guard let session = activeSessions.first(where: { $0.id == sessionID }) else { return }
        session.autoCommitTask?.cancel()
        if let aid = session.activityID,
           let activity = Activity<GlassbookActivityAttributes>.activities.first(where: { $0.id == aid }) {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        await MainActor.run { activeSessions.removeAll { $0.id == sessionID } }
    }
}
