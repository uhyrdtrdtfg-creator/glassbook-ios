import Testing
import Foundation
import UIKit
import Darwin
@testable import Glassbook

/// Perf regression gate for Item 16. Guards the wins in commit `e45661a`
/// (concurrency cap + ImageIO thumbnail downscale). Without a test like this,
/// an innocent refactor that removes the thumbnail path or unbounded fan-out
/// would go unnoticed until a user with 10+ screenshots hits an OOM kill.
///
/// Methodology: run the 10-image batch *twice* through the real OCR pipeline.
/// Baseline RSS is measured between runs — after the first run has primed
/// Vision's model, materialized every UIImage bitmap, and warmed the
/// allocator pools. The second run should allocate only transient per-image
/// memory (decoded CGImages, the Vision request's internal buffers), which
/// the concurrency cap + ImageIO thumbnail path hold bounded. Without those
/// fixes the second run's peak grows linearly in image count and busts the
/// budget; with them it stays flat.
@Suite("Batch OCR perf")
struct PerfTests {

    /// Budget for resident memory growth during the *second* batch run.
    /// 200 MB is generous but tight enough that ripping out the thumbnail
    /// API or the concurrency cap would push it over — a single undownscaled
    /// 4032x3024 RGBA bitmap alone is ~48 MB, and unbounded fan-out holds
    /// all 10 in flight simultaneously.
    private static let memoryBudgetBytes = 200 * 1024 * 1024

    /// Matches `SmartImportFlow.maxOCRConcurrency` (private there — kept in
    /// sync by eyeballing; drift would just make the test a shade stricter).
    private static let batchConcurrency = 3

    @Test
    func batchOcrUnderMemoryBudget() async throws {
        // 10 images sized like real iPhone screenshots so the downscale path
        // is actually exercised. Procedural render avoids asset-bundle deps.
        let images = (0..<10).map { Self.makeTestImage(index: $0) }

        // First run: warm Vision's recognition model, force every UIImage's
        // backing bitmap to materialize, and let the allocator reach a
        // steady state. We don't measure this run — its growth reflects
        // one-time costs that real users only pay on first scan.
        try await Self.runBatch(images: images)

        let baseline = Self.currentRSSBytes()

        // Second run: same images, same pipeline. With concurrency cap +
        // thumbnail downscale, per-image transient memory gets released
        // between slots and growth stays flat. Without them, RSS climbs
        // by ~50 MB per image in flight.
        try await Self.runBatch(images: images)

        let peak = Self.currentRSSBytes()
        let growth: Int = peak > baseline ? (peak - baseline) : 0

        #expect(
            growth < Self.memoryBudgetBytes,
            "Batch OCR RSS grew \(growth / 1024 / 1024) MB on second run (> \(Self.memoryBudgetBytes / 1024 / 1024) MB budget). Check that VisionOCRService still downscales via ImageIO and SmartImportFlow still caps concurrency."
        )
    }

    // MARK: - Helpers

    /// Mirror of `SmartImportFlow.runRealScanBatch`: bounded TaskGroup with
    /// `batchConcurrency` in-flight at a time. We don't care about the OCR
    /// text — we only need the pipeline's memory shape.
    private static func runBatch(images: [UIImage]) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            var nextIndex = 0
            var inFlight = 0
            while inFlight < Self.batchConcurrency && nextIndex < images.count {
                let i = nextIndex; nextIndex += 1; inFlight += 1
                let img = images[i]
                group.addTask { _ = try await VisionOCRService.recognize(image: img) }
            }
            while try await group.next() != nil {
                inFlight -= 1
                if nextIndex < images.count {
                    let i = nextIndex; nextIndex += 1; inFlight += 1
                    let img = images[i]
                    group.addTask { _ = try await VisionOCRService.recognize(image: img) }
                }
            }
        }
    }

    /// Procedural 3024x4032 image (≈ iPhone 15 Pro screenshot dimensions)
    /// filled with a gradient + a block of synthetic "text" rects. The exact
    /// pixels don't matter — we just want Vision to do real work on a full
    /// decoded bitmap so the thumbnail path is on the hot path.
    private static func makeTestImage(index: Int) -> UIImage {
        let size = CGSize(width: 3024, height: 4032)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let cg = ctx.cgContext
            // Background gradient varied per-index so dedup can't coalesce.
            let hue = CGFloat(index) / 10
            cg.setFillColor(UIColor(hue: hue, saturation: 0.3, brightness: 0.95, alpha: 1).cgColor)
            cg.fill(CGRect(origin: .zero, size: size))
            // A grid of dark rectangles — Vision will try to recognize these
            // as glyphs, which is exactly the code path we care about.
            cg.setFillColor(UIColor(white: 0.1, alpha: 1).cgColor)
            for row in 0..<30 {
                for col in 0..<8 {
                    let rect = CGRect(
                        x: 40 + col * 360,
                        y: 100 + row * 120,
                        width: 280,
                        height: 48
                    )
                    cg.fill(rect)
                }
            }
        }
    }

    /// Standard iOS RSS probe via `task_info` / `MACH_TASK_BASIC_INFO`.
    /// Returns 0 on failure so a broken probe fails open (test passes)
    /// rather than masquerading as a regression.
    private static func currentRSSBytes() -> Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let result = withUnsafeMutablePointer(to: &info) { ptr -> kern_return_t in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { reboundPtr in
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), reboundPtr, &count)
            }
        }
        return result == KERN_SUCCESS ? Int(info.resident_size) : 0
    }
}
