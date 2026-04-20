import Photos
import UIKit

/// Pulls the user's most recent screenshot straight out of Photos so the
/// smart-import flow doesn't need a picker step. Relies on
/// `PHAssetMediaSubtype.photoScreenshot` which iOS sets automatically when
/// the user takes a screenshot — no OCR or heuristic needed to distinguish
/// screenshots from camera photos.
///
/// Spec v2 §6.1.3 · 零点击入账 (iOS 端 · 一键版,非后台自动).
enum LatestScreenshotService {

    struct Result {
        let image: UIImage
        let creationDate: Date
        /// Rough age label for the UI ("3 分钟前" / "今天 14:03" / "昨天").
        var ageLabel: String {
            let s = -creationDate.timeIntervalSinceNow
            if s < 60 { return "刚刚" }
            if s < 3600 { return "\(Int(s / 60)) 分钟前" }
            if Calendar.current.isDateInToday(creationDate) {
                let f = DateFormatter(); f.dateFormat = "HH:mm"
                return "今天 \(f.string(from: creationDate))"
            }
            if Calendar.current.isDateInYesterday(creationDate) { return "昨天" }
            let f = DateFormatter(); f.dateFormat = "M月d日"
            return f.string(from: creationDate)
        }
    }

    enum Failure: LocalizedError {
        case denied
        case none
        case loadFailed

        var errorDescription: String? {
            switch self {
            case .denied:     return "需要相册权限才能读最新截屏 · 设置 → Glassbook → 照片"
            case .none:       return "相册里还没有截屏 · 先按一下电源 + 音量上键"
            case .loadFailed: return "读取截屏失败,换个再试"
            }
        }
    }

    /// One-shot: ask permission (if needed) and return the latest screenshot.
    /// Caller presents `Failure` errors inline in the UI.
    static func fetchLatest() async throws -> Result {
        try await ensurePermission()
        guard let asset = latestScreenshotAsset() else { throw Failure.none }
        guard let image = await loadImage(from: asset) else { throw Failure.loadFailed }
        return Result(image: image, creationDate: asset.creationDate ?? .now)
    }

    // MARK: - Internals

    private static func ensurePermission() async throws {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch status {
        case .authorized, .limited:
            return
        case .denied, .restricted:
            throw Failure.denied
        case .notDetermined:
            let granted = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            if granted != .authorized && granted != .limited { throw Failure.denied }
        @unknown default:
            throw Failure.denied
        }
    }

    private static func latestScreenshotAsset() -> PHAsset? {
        let opts = PHFetchOptions()
        // Bitmask match — iOS sets `photoScreenshot` on any Screenshots album item.
        opts.predicate = NSPredicate(
            format: "(mediaSubtype & %d) != 0",
            PHAssetMediaSubtype.photoScreenshot.rawValue
        )
        opts.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        opts.fetchLimit = 1
        let result = PHAsset.fetchAssets(with: .image, options: opts)
        return result.firstObject
    }

    private static func loadImage(from asset: PHAsset) async -> UIImage? {
        await withCheckedContinuation { (continuation: CheckedContinuation<UIImage?, Never>) in
            let opts = PHImageRequestOptions()
            opts.deliveryMode = .highQualityFormat
            opts.isSynchronous = false
            opts.version = .current
            opts.resizeMode = .none
            opts.isNetworkAccessAllowed = true  // handle iCloud Photos originals

            var resumed = false
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: PHImageManagerMaximumSize,
                contentMode: .default,
                options: opts
            ) { image, info in
                // The progressive callback fires twice (thumbnail → original);
                // only resume once.
                if resumed { return }
                let degraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if degraded && image != nil { return }
                resumed = true
                continuation.resume(returning: image)
            }
        }
    }
}
