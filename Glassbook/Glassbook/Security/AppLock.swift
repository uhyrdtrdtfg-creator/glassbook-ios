import Foundation
import LocalAuthentication
import Observation

/// Spec §8.4 · Face ID + 访客模式 + 宽限期.
/// - Cold start: if the user unlocked within `gracePeriodSeconds`, skip Face ID.
/// - Scene background → foreground: same rule applies from the time we backgrounded.
/// - User can turn biometrics off entirely in LockSettingsView.
@Observable
final class AppLock {
    var isLocked: Bool = true
    var isGuestMode: Bool = false
    var lastError: String?

    /// Settings toggle — when false, the app never prompts Face ID (useful on
    /// a trusted personal device where iCloud Keychain already gates access).
    var faceIDEnabled: Bool {
        didSet { UserDefaults.standard.set(faceIDEnabled, forKey: Keys.faceIDEnabled) }
    }

    /// How long after an unlock (or after the scene backgrounded) we still
    /// consider the session fresh and skip the next Face ID prompt.
    /// Default 5 minutes. 0 = always require Face ID. -1 = never.
    var gracePeriodSeconds: Int {
        didSet { UserDefaults.standard.set(gracePeriodSeconds, forKey: Keys.graceSeconds) }
    }

    /// Set to true by unit tests / previews to skip LAContext entirely.
    var skipAuth: Bool = false

    private enum Keys {
        static let faceIDEnabled  = "applock.faceid.enabled"
        static let graceSeconds   = "applock.grace.seconds"
        static let lastUnlockedAt = "applock.last.unlocked"
        static let backgroundedAt = "applock.last.backgrounded"
    }

    init() {
        self.faceIDEnabled = (UserDefaults.standard.object(forKey: Keys.faceIDEnabled) as? Bool) ?? true
        self.gracePeriodSeconds = (UserDefaults.standard.object(forKey: Keys.graceSeconds) as? Int) ?? 300
        self.isLocked = Self.computeInitialLockState(
            faceIDEnabled: faceIDEnabled,
            graceSeconds: gracePeriodSeconds
        )
    }

    private static func computeInitialLockState(faceIDEnabled: Bool, graceSeconds: Int) -> Bool {
        if !faceIDEnabled { return false }
        if graceSeconds < 0 { return false }   // "never" escape hatch
        if graceSeconds == 0 { return true }

        // Prefer the most recent of (last unlock) vs (last backgrounded) as our
        // "session still warm" marker. Either means the user was in the app
        // recently; only a long gap deserves a fresh Face ID.
        let last = [UserDefaults.standard.object(forKey: Keys.lastUnlockedAt) as? Date,
                    UserDefaults.standard.object(forKey: Keys.backgroundedAt) as? Date]
            .compactMap { $0 }
            .max()
        guard let ts = last else { return true }
        return Date().timeIntervalSince(ts) > TimeInterval(graceSeconds)
    }

    // MARK: - Auth

    func unlock() async {
        if skipAuth || !faceIDEnabled {
            await MainActor.run { isLocked = false; recordUnlock() }
            return
        }
        let ctx = LAContext()
        ctx.localizedFallbackTitle = "使用系统密码"

        var error: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            await MainActor.run {
                isLocked = false
                lastError = "当前设备无法使用 Face ID / 密码验证。已直接进入。"
                recordUnlock()
            }
            return
        }
        do {
            try await ctx.evaluatePolicy(.deviceOwnerAuthentication,
                                         localizedReason: "解锁以打开 Glassbook")
            await MainActor.run {
                isLocked = false
                lastError = nil
                recordUnlock()
            }
        } catch let e as LAError where e.code == .userCancel || e.code == .appCancel || e.code == .systemCancel {
            await MainActor.run { lastError = nil }
        } catch {
            await MainActor.run { lastError = "验证失败,请重试" }
        }
    }

    func lock() {
        isLocked = true
        UserDefaults.standard.removeObject(forKey: Keys.lastUnlockedAt)
    }

    func toggleGuestMode() { isGuestMode.toggle() }

    /// Prompt Face ID / device passcode purely to confirm identity, without
    /// touching `isLocked`. Used by LockSettingsView to gate the Face ID
    /// on/off toggle and grace period changes — otherwise a thief with the
    /// unlocked phone could disable biometrics and keep access forever.
    /// Spec §8.4 · 防止"拿到解锁手机就能改策略".
    func confirmIdentity(reason: String) async -> Bool {
        if skipAuth { return true }
        let ctx = LAContext()
        ctx.localizedFallbackTitle = "使用系统密码"
        var error: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            // No biometrics / passcode on device → let the change through so
            // users without a device passcode aren't permanently locked out
            // of their own settings.
            return true
        }
        do {
            return try await ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
        } catch {
            return false
        }
    }

    // MARK: - Scene lifecycle hook

    /// Called by RootView's scene-phase observer. Writes the backgrounded time
    /// and decides whether to re-lock on foreground based on how long we were
    /// out.
    func handleBackground() {
        UserDefaults.standard.set(Date(), forKey: Keys.backgroundedAt)
    }

    func handleForeground() {
        guard faceIDEnabled, gracePeriodSeconds >= 0 else {
            isLocked = false
            return
        }
        // Match computeInitialLockState — use the MOST RECENT of "last unlocked"
        // and "last backgrounded", whichever is more recent. If user killed the
        // app (swipe-up) without emitting a background event, `backgroundedAt`
        // can be stale while `lastUnlockedAt` is fresh; only looking at `bg`
        // mis-locks a just-unlocked session on the next foreground.
        let last = [
            UserDefaults.standard.object(forKey: Keys.lastUnlockedAt) as? Date,
            UserDefaults.standard.object(forKey: Keys.backgroundedAt) as? Date
        ].compactMap { $0 }.max()
        guard let ts = last else { return }
        if Date().timeIntervalSince(ts) > TimeInterval(gracePeriodSeconds) {
            isLocked = true
        }
    }

    // MARK: - Private

    private func recordUnlock() {
        UserDefaults.standard.set(Date(), forKey: Keys.lastUnlockedAt)
    }
}
