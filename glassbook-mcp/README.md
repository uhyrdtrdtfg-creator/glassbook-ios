# glassbook-mcp

> Spec v2 · Diagram 01 · **对话即记账 · Mac 端 MCP (零云端)**

Local MCP server that lets Claude Desktop / Cline / Zed talk to your Glassbook database — without any remote server. Runs as a plain macOS executable; the iOS Glassbook app and this process share the same iCloud Drive file.

## 架构

```
┌────────────────┐   stdio JSON-RPC   ┌───────────────────┐   iCloud Drive  ┌────────────┐
│ Claude Desktop │◄──────────────────►│ glassbook-mcp     │◄───────────────►│  iPhone    │
│ Cline · Zed    │  tools/list        │ (你的 Mac 本地进程) │  ~/.../         │  Glassbook │
└────────────────┘  tools/call        └───────────────────┘  glassbook.json └────────────┘
```

**无中转服务器**。一切都在你自己的机器上,通过 iCloud 和 iPhone 上的 Glassbook 共享同一份数据库。

## 安装

```bash
cd glassbook-mcp
swift build -c release
sudo cp .build/release/glassbook-mcp /usr/local/bin/
```

或者未来走 Homebrew:

```bash
brew tap glassbook/tap
brew install glassbook-mcp
```

## 配置 Claude Desktop

编辑 `~/Library/Application Support/Claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "glassbook": {
      "command": "/usr/local/bin/glassbook-mcp"
    }
  }
}
```

重启 Claude Desktop。顶部应该会看到 "glassbook" 连接图标。试着发一句:

> 「刚刚打车去机场花了 86 块,记一下」

Claude 会调用 `add_transaction` 工具,几秒后你的 iPhone 打开 Glassbook 就能看到这笔新交易 (iCloud 同步到位的话)。

## 6 个工具

| 工具 | 用途 | 输入 |
|---|---|---|
| `add_transaction`    | 记一笔交易              | `amount`, `category`, `merchant?`, `note?`, `kind?`, `timestamp?` |
| `query_budget`       | 查预算使用情况          | `category?` (空为总预算) |
| `list_subscriptions` | 列订阅                   | `filter?`: all / active / idle_30 / idle_90 |
| `get_monthly_summary`| 月度汇总                  | `year?`, `month?` (默认当月) |
| `find_similar_txns`  | 按商户模糊查             | `merchant`, `limit?` |
| `set_budget`         | 改预算                    | `amount`, `category?` |

每个工具返回:
- `content[0]`: 给 Claude 看的一句人话摘要
- `structuredContent`: 结构化 JSON (Claude 可进一步推理)

## 数据源

默认读写 `~/Library/Mobile Documents/iCloud~app~glassbook~ios/Documents/glassbook.json`,由 iOS app 用 SwiftData/SQLCipher 写入,Mac 这边直接文件级读取。

文件不存在时降级到内置示例数据,方便 `glassbook-mcp` 单独跑通 (开发测试)。

## 隐私边界

- stdio 通讯只走本机管道,不经过任何网络
- iCloud 同步由苹果端到端加密
- Claude 看到的 OCR/明细数据完全在你的机器本地
- API Key 不存这里,由 iOS app 管 (Keychain)

## 协议

MCP 2025-03-26。实现 `initialize` / `tools/list` / `tools/call` 子集,满足 Claude Desktop 连接需求。

## 开发

```bash
# 交互式测试 (模拟 Claude Desktop 发消息):
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}' | swift run glassbook-mcp
echo '{"jsonrpc":"2.0","id":2,"method":"tools/list"}' | swift run glassbook-mcp
```

Built with restraint, shipped with care.
