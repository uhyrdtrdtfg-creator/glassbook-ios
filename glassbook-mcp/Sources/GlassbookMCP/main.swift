import Foundation

// MARK: - Entry point
//
// glassbook-mcp reads newline-delimited JSON-RPC 2.0 from stdin, dispatches
// each request to the correct tool handler, and writes the response to stdout.
//
// The MCP spec (model-context-protocol) defines three core methods we implement:
//   - initialize        → declare server capabilities
//   - tools/list        → describe available tools
//   - tools/call        → execute one tool and return structured JSON result
//
// Bigger TODO for real deployment:
//   - Content-Length framing (optional, but Claude Desktop supports newline too)
//   - tools/call result streaming for long-running jobs
//   - Resource and prompt endpoints (tools are enough for bookkeeping)
//
// Install:
//   swift build -c release
//   sudo cp .build/release/glassbook-mcp /usr/local/bin/
//
// Claude Desktop config (~/Library/Application Support/Claude/claude_desktop_config.json):
//   { "mcpServers": { "glassbook": { "command": "/usr/local/bin/glassbook-mcp" } } }

FileHandle.standardError.write("glassbook-mcp v0.1 · listening on stdio\n".data(using: .utf8) ?? Data())

let server = MCPServer(store: DataStore.default())
server.runStdioLoop()
