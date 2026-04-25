import Foundation
@preconcurrency import Vision
import UIKit
import ImageIO

/// Spec §8.4 · Local OCR via Vision Framework. No network egress.
enum VisionOCRService {

    enum OCRError: Error { case invalidImage, visionFailed(String) }

    /// A full 4032x3024 iPhone screenshot is overkill for text OCR and costs
    /// ~50 MB of VM just in the decoded CGImage. Bill text is still crisp at
    /// 2000 px long-edge and Vision is ~4× faster.
    private static let maxOCRPixelSize: CGFloat = 2000

    /// Returns lines in natural reading order (top-to-bottom, left-to-right).
    ///
    /// `languageCorrection` defaults to **true** — that's what bill screenshots
    /// (支付宝 / 微信 / 招行) want because their merchant names are regular
    /// Chinese words and Apple's language model cleans up legit OCR mistakes.
    ///
    /// Pass `false` for paper-receipt / menu scans where text is dense with
    /// proper nouns, SKUs, and loyalty-card numbers that the language model
    /// wrongly "corrects" into common words (earlier: 海底捞 → 海底劳). Those
    /// callers hand the raw output to `ReceiptOCRService` which pipes it
    /// through the selected BYO LLM for context-aware fixup instead.
    static func recognize(image: UIImage, languageCorrection: Bool = true) async throws -> [String] {
        // Downscale BEFORE handing to Vision. Two wins: decoded-pixel RAM goes
        // from ~50 MB to ~4 MB for a long-edge 2000 px image, and Vision's
        // accurate model runs ~4× faster. Critical when the user picks 10
        // screenshots — without this, parallel OCR runs exhaust app memory
        // and iOS sends a memory-pressure kill signal.
        guard let cg = downscaledCGImage(from: image, maxPixelSize: maxOCRPixelSize) else {
            throw OCRError.invalidImage
        }

        return try await withCheckedThrowingContinuation { cont in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    cont.resume(throwing: OCRError.visionFailed(error.localizedDescription))
                    return
                }
                let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
                // Sort by vertical position (Vision reports normalized bottom-left origin, so
                // `1 - boundingBox.midY` yields a natural top-to-bottom sort key).
                let ordered = observations.sorted { a, b in
                    (1 - a.boundingBox.midY) < (1 - b.boundingBox.midY)
                }
                let lines = ordered.compactMap { $0.topCandidates(1).first?.string }
                cont.resume(returning: lines)
            }
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["zh-Hans", "en-US"]
            request.usesLanguageCorrection = languageCorrection

            // Run `perform` on a background queue directly — earlier code
            // wrapped this in Task.detached which is a *second* detach on top
            // of the continuation's already-async context. That extra hop just
            // adds thread-hand-off latency under N-way parallel OCR.
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let handler = VNImageRequestHandler(cgImage: cg, options: [:])
                    try handler.perform([request])
                } catch {
                    cont.resume(throwing: OCRError.visionFailed(error.localizedDescription))
                }
            }
        }
    }

    /// Decode + downscale via `ImageIO` thumbnail API. Unlike UIImage's
    /// lazy-decoded CGImage this forces a real bitmap at the target size,
    /// so Vision's GPU path doesn't re-decode a 12 MP original.
    private static func downscaledCGImage(from uiImage: UIImage, maxPixelSize: CGFloat) -> CGImage? {
        // Short-circuit: if the image is already small, use its CGImage directly.
        if let cg = uiImage.cgImage,
           CGFloat(max(cg.width, cg.height)) <= maxPixelSize {
            return cg
        }
        // Re-encode through JPEG so ImageIO has a data source. (UIImage lazy
        // CGImages can't be fed directly into CGImageSourceCreateWithCGImage.)
        // 0.9 quality keeps OCR accuracy identical while shrinking memory.
        guard let data = uiImage.jpegData(compressionQuality: 0.9) else {
            return uiImage.cgImage
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let src = CGImageSourceCreateWithData(data as CFData, nil) else {
            return uiImage.cgImage
        }
        return CGImageSourceCreateThumbnailAtIndex(src, 0, options as CFDictionary)
    }

    // MARK: - Synthetic input (for scaffold demo & unit tests)

    /// Produces OCR-ish output that the platform parsers can chew on — lets the flow
    /// run end-to-end in the simulator without a real screenshot on disk.
    static func fakeAlipayBill() -> [String] {
        [
            "支付宝",
            "账单",
            "—",
            "美团外卖",
            "- ¥38.90",
            "2026-04-19 12:04:32",
            "滴滴出行",
            "- ¥26.50",
            "2026-04-19 11:12:09",
            "淘宝 · 家居用品",
            "- ¥149.00",
            "2026-04-19 08:41:17",
            "星巴克",
            "- ¥38.00",
            "2026-04-18 21:45:55",
            "Apple 订阅",
            "- ¥28.00",
            "2026-04-18 19:30:02",
        ]
    }

    static func fakeWeChatBill() -> [String] {
        [
            "微信支付",
            "账单明细",
            "楼下包子铺",
            "-8.50",
            "04-19 08:12",
            "盒马鲜生",
            "-86.40",
            "04-18 19:22",
            "滴滴快车",
            "-14.20",
            "04-18 18:51",
        ]
    }

    static func fakeCMBBill() -> [String] {
        [
            "招商银行",
            "收支明细",
            "京东商城",
            "-2999.00",
            "2026-04-18 21:22",
            "还款",
            "+1250.00",
            "2026-04-17 09:00",
            "美团酒店",
            "-680.00",
            "2026-04-16 22:04",
        ]
    }
}
