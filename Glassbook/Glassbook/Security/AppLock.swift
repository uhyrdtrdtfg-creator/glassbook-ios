import Foundation
import LocalAuthentication
import Observation

/// Spec §8.4 · Face ID + 访客模式.
/// - `isLocked` = true whenever the app is cold-started or returns from deep background.
/// - `isGuestMode` masks all monetary values as "¥ •••" across the UI.
@Observable
final class AppLock {
    var isLocked: Bool = true
    var isGuestMode: Bool = false
    var lastError: String?

    /// Enable to skip Face ID in SwiftUI previews or unit tests.
    var skipAuth: Bool = false

    func unlock() async {
        if skipAuth {
            await MainActor.run { isLocked = false }
            return
        }
        let ctx = LAContext()
        ctx.localizedFallbackTitle = "使用系统密码"

        var error: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            // No biometrics and no passcode — e.g., simulator with no passcode configured.
            // Allow entry but flag it so the UI can prompt "请在系统中开启 Face ID".
            await MainActor.run {
                isLocked = false
                lastError = "当前设备无法使用 Face ID / 密码验证。已直接进入。"
            }
            return
        }

        do {
            try await ctx.evaluatePolicy(.deviceOwnerAuthentication,
                                         localizedReason: "解锁以打开 Glassbook")
            await MainActor.run {
                isLocked = false
                lastError = nil
            }
        } catch let e as LAError where e.code == .userCancel || e.code == .appCancel || e.code == .systemCancel {
            // User dismissed — stay locked, no error banner.
            await MainActor.run { lastError = nil }
        } catch {
            await MainActor.run { lastError = "验证失败,请重试" }
        }
    }

    func lock() {
        isLocked = true
    }

    func toggleGuestMode() {
        isGuestMode.toggle()
    }
}
