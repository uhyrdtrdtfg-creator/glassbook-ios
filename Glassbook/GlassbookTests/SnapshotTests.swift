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
/// Dynamic content caveat: HomeView / BillsView pull from `AppStore()`'s
/// in-memory seed (SampleData) which is deterministic, BUT their greeting
/// includes "今天是 <date>" and month filters key off `Date()`. Expect the
/// greeting band and month headers to shift day-to-day — the baseline
/// captures the state at record time. If CI flakes, tighten by injecting
/// a fixed date into the views (requires production changes, deferred).
final class SnapshotTests: XCTestCase {

    /// Toggle to `true`, run once, revert to `false`, commit the PNGs.
    /// Leaving it at `false` in source means a rogue `git checkout .`
    /// doesn't silently switch baselines to a re-record.
    private let recordMode = false

    override func setUp() {
        super.setUp()
        // Apply per-test; SnapshotTesting's top-level `isRecording` is
        // module-global and would leak into parallel suites.
    }

    // MARK: - Home

    @MainActor
    func testHomeView_default() {
        let store = AppStore()
        let view = ZStack {
            AuroraBackground(palette: .home)
            HomeView().environment(store)
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
        let view = ZStack {
            AuroraBackground(palette: .bills)
            BillsView().environment(store)
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
}
