import AppIntents
import Foundation
import UIKit

/// Spec v2 Diagram 03 · 零点击入账 via iOS Shortcuts.
/// User builds automation in Shortcuts app:
///     [Trigger: 每次截屏]  →  [Action: 用 Glassbook 识别截屏]
/// We OCR with Vision, pick the best platform parser, enqueue the first row
/// into the App Group queue, and start a Live Activity with 5-second auto-save.
/// Main app drains the queue next foreground (see AppStore.drainPendingImports).
@available(iOS 17, *)
struct ImportScreenshotIntent: AppIntent {
    static var title: LocalizedStringResource = "识别截屏记账"
    static var description = IntentDescription(
        "本地 OCR 识别支付截屏,自动填充金额 / 商户 / 分类,并在锁屏弹出 5 秒确认条。"
    )
    static var openAppWhenRun: Bool = false

    @Parameter(title: "截图",
               description: "支付宝 / 微信 / 招行账单截图",
               supportedTypeIdentifiers: ["public.image"])
    var screenshot: IntentFile

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        // User-level kill switch — lets them pause auto-import without
        // uninstalling their Shortcut automation.
        guard AutomationSettings.screenshotOn else {
            return .result(value: "截屏自动识别已在 Glassbook 里关闭 · 打开 App → 自动化记账 → 开启")
        }
        guard let image = UIImage(data: screenshot.data) else {
            return .result(value: "图片读取失败")
        }
        let lines: [String]
        do {
            lines = try await VisionOCRService.recognize(image: image)
        } catch {
            return .result(value: "OCR 失败:\(error.localizedDescription)")
        }
        guard !lines.isEmpty else {
            return .result(value: "图片里没有识别到文字,试试换一张清晰的截图")
        }

        let parser = ParserRegistry.pick(for: lines)
        let parsed = parser.parse(lines: lines)
        guard let first = parsed.first else {
            return .result(value: "识别到 \(lines.count) 行文字,但没匹配上支付宝 / 微信 / 招行的账单格式")
        }

        // Queue for the main app to persist on next foreground.
        PendingImportQueue.enqueue(.init(
            merchant: first.merchant,
            amountCents: first.amountCents,
            categorySlug: first.categoryID.rawValue,
            platform: parser.platform.rawValue,
            timestamp: first.timestamp
        ))

        // Start Live Activity (best-effort — some states don't allow background starts).
        let categoryEmoji = Category.by(first.categoryID).emoji
        let delay = AutomationSettings.autoSaveDelay
        let autoSave = delay == -1 ? 5 : max(1, delay)  // -1 "never" falls back to a short window
        _ = await MainActor.run {
            LiveActivityService.shared.start(
                pendingAmountCents: first.amountCents,
                merchant: first.merchant,
                categoryEmoji: categoryEmoji,
                autoSaveSeconds: autoSave,
                onAutoCommit: { _ in /* main app drains the queue */ }
            )
        }

        let msg = parsed.count == 1
            ? "✓ 识别 \(first.merchant) \(Money.yuan(first.amountCents, showDecimals: false)) · 已加入待入账"
            : "✓ 识别 \(parsed.count) 笔 · 首条已加入待入账 · 打开 App 完成其余"
        return .result(value: msg)
    }
}

/// Surfaces the intent as a Shortcut phrase so users don't have to hand-build
/// the automation — Siri / Shortcuts can autocomplete "用 Glassbook 识别这张图"
/// and suggest it under the app in the Shortcuts library.
@available(iOS 17, *)
struct GlassbookShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ImportScreenshotIntent(),
            phrases: [
                "用 \(.applicationName) 记一笔",
                "用 \(.applicationName) 识别截屏",
                "Glassbook 识别这张图",
            ],
            shortTitle: "识别截屏",
            systemImageName: "doc.text.viewfinder"
        )
    }
}
