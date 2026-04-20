import Foundation
import UIKit

/// Talks to the PhoneClaw app over a URL-scheme + App-Group-file RPC.
///
/// Protocol summary (see PhoneClaw's `AppGroupBridge` + `PhoneClawURLHandler`):
///
///   1. We write the prompt JSON to
///      `<group container>/phoneclaw-rpc/req/<id>.json`.
///   2. We open `phoneclaw://ask?id=<id>&x-success=glassbook%3A%2F%2Fphoneclaw-result`.
///      iOS foregrounds PhoneClaw which parses the URL, reads our request file,
///      runs the model, writes `res/<id>.json`, and opens our glassbook:// URL.
///   3. The app's `.onOpenURL` calls `resolve(id:url:)` to hand the response
///      back to the `Task` that was suspended on `ask(prompt:)`.
///
/// Nothing rides on URL query strings except the id — payloads of any size go
/// through the shared App Group container.
enum PhoneClawClient {

    static let appGroup = "group.app.glassbook.ios"
    static let callbackURL = URL(string: "glassbook://phoneclaw-result")!

    enum ClientError: Error, LocalizedError {
        case groupContainerUnavailable
        case phoneclawNotInstalled
        case launchFailed
        case remoteError(String)
        case malformedResponse

        var errorDescription: String? {
            switch self {
            case .groupContainerUnavailable:
                return "App Group 共享容器不可用，请确认 entitlements 里有 group.app.glassbook.ios"
            case .phoneclawNotInstalled:
                return "检测不到 PhoneClaw,请先在本机安装"
            case .launchFailed:
                return "无法唤起 PhoneClaw"
            case .remoteError(let message):
                return "PhoneClaw 返回错误:\(message)"
            case .malformedResponse:
                return "PhoneClaw 响应格式异常"
            }
        }
    }

    private struct Request: Codable {
        var prompt: String
    }

    private struct Response: Codable {
        var answer: String?
        var error: String?
    }

    // MARK: - Pending continuations

    private static let queue = DispatchQueue(label: "phoneclaw.rpc.pending")
    private static var pending: [String: CheckedContinuation<String, Error>] = [:]

    // MARK: - Caller API

    /// Ask PhoneClaw a question and await the answer. Suspends until PhoneClaw
    /// opens the `glassbook://phoneclaw-result?id=<id>` callback and the host
    /// app's `.onOpenURL` routes it back here via `resolve(url:)`.
    @MainActor
    static func ask(prompt: String) async throws -> String {
        guard let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroup) else {
            throw ClientError.groupContainerUnavailable
        }

        let id = UUID().uuidString
        let reqDir = container
            .appendingPathComponent("phoneclaw-rpc", isDirectory: true)
            .appendingPathComponent("req", isDirectory: true)
        try FileManager.default.createDirectory(at: reqDir, withIntermediateDirectories: true)

        let reqURL = reqDir.appendingPathComponent("\(id).json")
        let data = try JSONEncoder().encode(Request(prompt: prompt))
        try data.write(to: reqURL, options: .atomic)

        guard let cbEncoded = callbackURL.absoluteString
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw ClientError.launchFailed
        }
        guard let askURL = URL(string: "phoneclaw://ask?id=\(id)&x-success=\(cbEncoded)") else {
            throw ClientError.launchFailed
        }

        if !UIApplication.shared.canOpenURL(askURL) {
            throw ClientError.phoneclawNotInstalled
        }

        return try await withCheckedThrowingContinuation { cont in
            queue.sync { pending[id] = cont }
            UIApplication.shared.open(askURL, options: [:]) { ok in
                if !ok {
                    Self.fail(id: id, error: .launchFailed)
                }
            }
        }
    }

    /// Called from `GlassbookApp.onOpenURL` when `glassbook://phoneclaw-result?id=...`
    /// arrives. Reads the response file and resumes the matching continuation.
    static func resolve(url: URL) -> Bool {
        guard url.scheme == "glassbook",
              url.host == "phoneclaw-result" else { return false }

        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        guard let id = items.first(where: { $0.name == "id" })?.value else { return false }

        guard let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroup) else {
            fail(id: id, error: .groupContainerUnavailable)
            return true
        }

        let resURL = container
            .appendingPathComponent("phoneclaw-rpc", isDirectory: true)
            .appendingPathComponent("res", isDirectory: true)
            .appendingPathComponent("\(id).json")

        do {
            let data = try Data(contentsOf: resURL)
            let decoded = try JSONDecoder().decode(Response.self, from: data)
            try? FileManager.default.removeItem(at: resURL)
            try? FileManager.default.removeItem(at: container
                .appendingPathComponent("phoneclaw-rpc", isDirectory: true)
                .appendingPathComponent("req", isDirectory: true)
                .appendingPathComponent("\(id).json"))

            if let message = decoded.error {
                fail(id: id, error: .remoteError(message))
            } else if let answer = decoded.answer {
                succeed(id: id, answer: answer)
            } else {
                fail(id: id, error: .malformedResponse)
            }
        } catch {
            fail(id: id, error: .malformedResponse)
        }
        return true
    }

    // MARK: - helpers

    private static func succeed(id: String, answer: String) {
        var cont: CheckedContinuation<String, Error>?
        queue.sync {
            cont = pending.removeValue(forKey: id)
        }
        cont?.resume(returning: answer)
    }

    private static func fail(id: String, error: ClientError) {
        var cont: CheckedContinuation<String, Error>?
        queue.sync {
            cont = pending.removeValue(forKey: id)
        }
        cont?.resume(throwing: error)
    }
}
