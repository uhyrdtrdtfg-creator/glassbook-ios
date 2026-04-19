import Foundation

/// JSON-RPC 2.0 envelope + MCP dispatch loop.
final class MCPServer {
    private let store: DataStore
    private let tools: [Tool]

    init(store: DataStore) {
        self.store = store
        self.tools = ToolRegistry.all(store: store)
    }

    // MARK: - stdio loop

    func runStdioLoop() {
        while let line = readLine(), !line.isEmpty {
            guard let data = line.data(using: .utf8) else { continue }
            do {
                guard let raw = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let method = raw["method"] as? String else {
                    continue
                }
                let id = raw["id"]
                let params = raw["params"] as? [String: Any] ?? [:]

                let result: Result<Any?, MCPError>
                switch method {
                case "initialize":
                    result = .success(handleInitialize(params: params))
                case "initialized", "notifications/initialized":
                    // Notifications have no response.
                    continue
                case "tools/list":
                    result = .success(handleToolsList())
                case "tools/call":
                    result = handleToolsCall(params: params)
                case "ping":
                    result = .success([:] as [String: Any])
                default:
                    result = .failure(MCPError(code: -32601, message: "Method not found: \(method)"))
                }

                writeResponse(id: id, result: result)
            } catch {
                writeResponse(id: nil, result: .failure(MCPError(code: -32700, message: "Parse error: \(error.localizedDescription)")))
            }
        }
    }

    // MARK: - Handlers

    private func handleInitialize(params: [String: Any]) -> [String: Any] {
        [
            "protocolVersion": "2025-03-26",
            "serverInfo": [
                "name": "glassbook-mcp",
                "version": "0.1.0",
            ],
            "capabilities": [
                "tools": ["listChanged": false],
            ],
        ]
    }

    private func handleToolsList() -> [String: Any] {
        [
            "tools": tools.map { tool in
                [
                    "name": tool.name,
                    "description": tool.description,
                    "inputSchema": tool.inputSchema,
                ] as [String: Any]
            },
        ]
    }

    private func handleToolsCall(params: [String: Any]) -> Result<Any?, MCPError> {
        guard let name = params["name"] as? String else {
            return .failure(MCPError(code: -32602, message: "tools/call missing 'name'"))
        }
        let args = params["arguments"] as? [String: Any] ?? [:]
        guard let tool = tools.first(where: { $0.name == name }) else {
            return .failure(MCPError(code: -32601, message: "Unknown tool: \(name)"))
        }
        do {
            let result = try tool.execute(arguments: args)
            return .success([
                "content": [["type": "text", "text": result.humanSummary]],
                "structuredContent": result.json,
            ] as [String: Any])
        } catch {
            return .failure(MCPError(code: -32000, message: "Tool error: \(error.localizedDescription)"))
        }
    }

    // MARK: - Response writer

    private func writeResponse(id: Any?, result: Result<Any?, MCPError>) {
        var response: [String: Any] = ["jsonrpc": "2.0"]
        if let id { response["id"] = id }
        switch result {
        case .success(let value):
            if let value { response["result"] = value }
            else { response["result"] = NSNull() }
        case .failure(let err):
            response["error"] = ["code": err.code, "message": err.message]
        }
        guard let data = try? JSONSerialization.data(withJSONObject: response),
              let line = String(data: data, encoding: .utf8) else { return }
        print(line)
        fflush(stdout)
    }
}

struct MCPError: Error {
    let code: Int
    let message: String
}

