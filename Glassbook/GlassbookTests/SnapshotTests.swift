import XCTest
import SwiftUI
import SnapshotTesting
@testable import Glassbook

/// Item 17 · Visual regression gate.
///
/// Why XCTest instead of Swift Testing: `assertSnapshot` is XCTest-native —
/// it records failures via `XCTFail()` and attaches diff artifacts to the
/// Xcode test report through `XCTContext.runActivity`. Wiring that through
/// Swift Testing's `#expect` would swallow the attachments and hide the
/// recorded-baseline signal on first run. Other test files in this target
/// stay on Swift Testing; per-file framework choice is supported.
///
/// First run writes PNGs into `__Snapshots__/SnapshotTests/` next to this
/// file and fails the test with "No reference was found on disk". Commit
/// the PNGs, re-run, and the tests pass as long as the rendered output
/// stays pixel-identical (within tolerance). Drift → test fails with a
/// side-by-side diff.
///
/// Determinism: HomeView / BillsView take an injectable `now` closure so
/// the greeting band, month badges, and "本月" filters all key off a pinned
/// date. SmartImportEntryScreen has no date-dependent rendering, so it
/// doesn't need a clock.
final class SnapshotTests: XCTestCase {

    /// Toggle to `true`, run once, revert to `false`, commit the PNGs.
    /// Leaving it at `false` in source means a rogue `git checkout .`
    /// doesn't silently switch baselines to a re-record.
    private let recordMode = false

    /// Pinned clock for the views under test. 2026-04-15T12:00:00Z —
    /// mid-month so "本月" filters surface real seeded data, and a Wednesday
    /// so the weekday string is stable. Far enough from any given test-run
    /// "today" to surface accidental `Date()` fall-through.
    private let frozenNow = Date(timeIntervalSince1970: 1_776_254_400)

    override func setUp() {
        super.setUp()
        // Apply per-test; SnapshotTesting's top-level `isRecording` is
        // module-global and would leak into parallel suites.
    }

    // MARK: - Home

    @MainActor
    func testHomeView_default() {
        let store = AppStore()
        let pinned = frozenNow
        let view = ZStack {
            AuroraBackground(palette: .home)
            HomeView(now: { pinned }).environment(store)
        }
        .frame(width: 390, height: 844)
        assertSnapshot(
            of: UIHostingController(rootView: view),
            as: .image(on: .iPhone13, precision: 0.98),
            record: recordMode
        )
    }

    // MARK: - Bills

    @MainActor
    func testBillsView_default() {
        let store = AppStore()
        let pinned = frozenNow
        let view = ZStack {
            AuroraBackground(palette: .bills)
            BillsView(now: { pinned }).environment(store)
        }
        .frame(width: 390, height: 844)
        assertSnapshot(
            of: UIHostingController(rootView: view),
            as: .image(on: .iPhone13, precision: 0.98),
            record: recordMode
        )
    }

    // MARK: - SmartImport entry

    @MainActor
    func testSmartImportEntryScreen_default() {
        let view = ZStack {
            AuroraBackground(palette: .importBlue)
            SmartImportEntryScreen(
                onCancel: {},
                onDemo: { _ in },
                onRealImage: { _, _ in },
                onRealImages: { _, _ in }
            )
        }
        .frame(width: 390, height: 844)
        assertSnapshot(
            of: UIHostingController(rootView: view),
            as: .image(on: .iPhone13, precision: 0.98),
            record: recordMode
        )
    }

    // MARK: - Profile

    @MainActor
    func testProfileView_default() {
        let store = AppStore()
        let lock = AppLock()
        lock.skipAuth = true
        let engines = AIEngineStore()
        let webhooks = WebhookStore()
        let pinned = frozenNow
        let view = ZStack {
            AuroraBackground(palette: .profile)
            ProfileView(now: { pinned })
                .environment(store)
                .environment(lock)
                .environment(engines)
                .environment(webhooks)
        }
        .frame(width: 390, height: 844)
        assertSnapshot(
            of: UIHostingController(rootView: view),
            as: .image(on: .iPhone13, precision: 0.98),
            record: recordMode
        )
    }

    // MARK: - AddTransaction (sheet)

    @MainActor
    func testAddTransactionView_default() {
        let store = AppStore()
        // why: AddTransactionView is normally presented as a sheet, but the
        // sheet wrapper isn't necessary for snapshotting the form chrome —
        // host the view directly so we capture the body without the sheet's
        // navigation stack interfering.
        let view = AddTransactionView()
            .environment(store)
            .frame(width: 390, height: 844)
        assertSnapshot(
            of: UIHostingController(rootView: view),
            as: .image(on: .iPhone13, precision: 0.98),
            record: recordMode
        )
    }

    // MARK: - Onboarding (3 steps)

    @MainActor
    func testOnboarding_aiEngineStep() {
        let view = ZStack {
            AuroraBackground(palette: .stats)
            AIEnginePickerStep(onNext: {}, onSkip: {})
        }
        .frame(width: 390, height: 844)
        assertSnapshot(
            of: UIHostingController(rootView: view),
            as: .image(on: .iPhone13, precision: 0.98),
            record: recordMode
        )
    }

    @MainActor
    func testOnboarding_screenshotStep() {
        let view = ZStack {
            AuroraBackground(palette: .bills)
            ScreenshotAutomationStep(onNext: {}, onSkip: {})
        }
        .frame(width: 390, height: 844)
        assertSnapshot(
            of: UIHostingController(rootView: view),
            as: .image(on: .iPhone13, precision: 0.98),
            record: recordMode
        )
    }

    @MainActor
    func testOnboarding_familyStep() {
        let store = AppStore()
        let view = ZStack {
            AuroraBackground(palette: .profile)
            FamilyStep(onFinish: {}, onSkip: {})
                .environment(store)
        }
        .frame(width: 390, height: 844)
        assertSnapshot(
            of: UIHostingController(rootView: view),
            as: .image(on: .iPhone13, precision: 0.98),
            record: recordMode
        )
    }
}
