import Foundation

/// Cross-target toggles for automation channels. Lives in the App Group so the
/// iOS app, the AppIntent extension (which runs in its own process when
/// triggered by a Shortcut), and the Widget can all see the same value.
///
/// Spec v2 §6.1.3 · 零点击入账设置页.
enum AutomationSettings {
    private enum Keys {
        static let screenshotOn = "automation.screenshotOn"
        static let autoSaveDelay = "automation.autoSaveDelay"
    }

    /// Master switch for the `ImportScreenshotIntent`. When false the intent
    /// early-returns with an explanation — user wanted to pause auto-import
    /// but didn't want to uninstall the shortcut.
    static var screenshotOn: Bool {
        get {
            guard let d = SharedStorage.defaults else { return true }
            return (d.object(forKey: Keys.screenshotOn) as? Bool) ?? true
        }
        set {
            SharedStorage.defaults?.set(newValue, forKey: Keys.screenshotOn)
        }
    }

    /// Seconds the Live Activity shows before auto-committing. 0 = instant,
    /// -1 = never (stays until user taps). Default 5.
    static var autoSaveDelay: Int {
        get {
            guard let d = SharedStorage.defaults else { return 5 }
            return (d.object(forKey: Keys.autoSaveDelay) as? Int) ?? 5
        }
        set {
            SharedStorage.defaults?.set(newValue, forKey: Keys.autoSaveDelay)
        }
    }
}
