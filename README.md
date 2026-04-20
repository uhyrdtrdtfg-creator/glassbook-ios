# Glassbook

[![CI](https://github.com/uhyrdtrdtfg-creator/glassbook-ios/actions/workflows/ci.yml/badge.svg)](https://github.com/uhyrdtrdtfg-creator/glassbook-ios/actions/workflows/ci.yml)

> 一款**会呼吸的智能记账 App** · 玻璃拟态视觉 · 本地优先 · BYO LLM

基于《Glassbook 产品规格说明书》+ 4 份 HTML 高保真交互稿 + Local-First Synthesis v2 方向文档,完整落地的 iOS 应用脚手架。

**Stack:** SwiftUI · SwiftData · CloudKit · Vision · WidgetKit · ActivityKit · watchOS · WatchKit · PhotosUI · Keychain

---

## 项目构成

```
/Users/samxiao/desgin/
├── Glassbook/              # Xcode 工程(iOS + Widget + Watch + Tests)
│   ├── project.yml         # xcodegen 配置
│   ├── Glassbook.xcodeproj # 由 xcodegen 生成
│   ├── Glassbook/          # iOS 主 App 源码 (~9k 行)
│   ├── GlassbookWidget/    # WidgetKit 扩展 (Small/Medium/Large + Live Activity)
│   ├── GlassbookWatch/     # watchOS 独立 App
│   └── GlassbookTests/     # Swift Testing 单元 / 渲染 / 准确率测试
└── glassbook-mcp/          # 独立 SwiftPM 项目:Mac 端 MCP Server
```

## 快速开始

```bash
# 1. 生成 Xcode 工程
cd Glassbook
xcodegen generate

# 2. 打开 Xcode,选 iPhone 模拟器按 ⌘R
open Glassbook.xcodeproj

# 3. 跑测试 + 覆盖率
xcodebuild test -scheme GlassbookCI \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -enableCodeCoverage YES

# 4. MCP Server(Mac 本地进程,给 Claude Desktop 用)
cd ../glassbook-mcp
swift build -c release
sudo cp .build/release/glassbook-mcp /usr/local/bin/
```

## 功能清单

### V1.0 MVP(全部落地)
- **6 核心页面** · 首页 / 记一笔 / 账单 / 统计 / 预算 / 我的
- **智能账单识别** · 支付宝 / 微信 / 招行 三平台,Vision 本地 OCR + regex 解析 + 去重
- **玻璃拟态设计系统** · Aurora 10 种光斑 + 9 分类渐变 + 7 层级字号
- **Face ID 启动守卫** · LAContext + 访客模式
- **SwiftData + CloudKit** · 三级降级(CloudKit → 本地 SQLite → 内存)
- **商户分类学习** · 70+ 条种子词典 + 用户改写持久化(SDMerchantLearning)
- **情绪记账** · 5 chips(开心/刚需/犒赏/后悔/焦虑)
- **CKShare 分级隐私** · 按笔选家庭/伴侣/仅自己
- **神兽专项(孩子分类)** · 9 分类网格

### V1.1 扩展
- **多账户 + 净资产** · 资产/负债/账户分组
- **订阅管理** · 活跃 + 僵尸订阅检测(30/90 天)+ 续费倒计时
- **储蓄目标** · 进度环 + 日均指标 + 贡献 sheet

### V1.2 Pro
- **AI 消费洞察** · 7 类规则引擎(人格/趋势/省钱建议/最贵一天/新店)
- **年度回顾** · Spotify Wrapped 风,5 张故事卡 + ShareLink
- **桌面 Widget** · Small / Medium / Large 三尺寸

### V1.5 Developer Edition
- **BYO LLM** · OpenAI / Claude / Gemini / Ollama / 自定义端点 · Key 走 Keychain
- **设备端 Webhook** · Slack / 飞书 / n8n · 4 触发器
- **自动化设置** · 截屏/短信/MCP 三通道
- **沉没成本分析** · 闲置订阅 + 吃灰硬件可省回
- **家庭账本** · 3 角色(admin/member/childPassive)+ 神兽专项

### V2.0
- **AI 财务顾问** · 多轮对话 · 本地规则 + BYO LLM 双轨
- **发票 PDF 导出** · UIGraphicsPDFRenderer · 多页 A4 · ShareLink
- **收据 OCR** · Vision 识别商户/总额/明细/日期 + 预填记账页
- **Live Activity** · Diagram 03 真实实现(锁屏横幅 + Dynamic Island)
- **Apple Watch** · 3 页(本月/最近/Digital Crown 快速记账)
- **Mac Catalyst** · 工程已开启 SUPPORTS_MACCATALYST

### MCP Server(独立项目)
- **对话即记账** · Claude Desktop / Cline / Zed 用 stdio JSON-RPC 2.0 连接
- 6 工具: `add_transaction` / `query_budget` / `list_subscriptions` / `get_monthly_summary` / `find_similar_txns` / `set_budget`
- 数据经 iCloud Drive,与 iOS App 共享一份数据库

## 测试

| 模块 | 测试数 | 结果 |
|---|---|---|
| iOS(单测 + 视图渲染 + 视图 smoke + 准确率) | **279** | ✅ all pass |
| MCP Server(6 工具 + JSON-RPC + DataStore) | **25** | ✅ all pass |
| **合计** | **304** | |

### 覆盖率

| 模块 | 覆盖率 |
|---|---|
| Services / Models / Data / Store | **~80%** |
| Features/Views(smoke + render 触发 body) | ~15% |
| DesignSystem / App shell | ~82% |

非 UI 逻辑层覆盖 ~80%。UI View body 的每个分支只在特定状态下执行(例如 loading/error/空态),要达到 90%+ 需要 ViewInspector 或 snapshot 测试,目前用 UIHostingController 渲染触发 body 大部分路径。

### 账单识别 Recall(基于内置假账单)

| 平台 | Recall |
|---|---|
| 支付宝 | 5/5 = 100% |
| 微信支付 | 3/3 = 100% |
| 招商银行 | 3/3 = 100% |

`ParserAccuracyTests` 持续监控 regex 回归。真实账单准确率会低一些(70-80%),因为布局变化和广告行。

## 架构要点

**本地优先**:所有数据默认在设备上;同步走 iCloud(端到端加密);AI 走 Apple Intelligence 或用户自带模型。无自有云端。

**零云端约束解**:
- 数据 → CloudKit 私有库(SwiftData + CKShare)
- AI → on-device(Apple Intelligence)或 BYO(OpenAI/Claude/Gemini/Ollama)
- 事件 → 设备端 Webhook 直出 Slack/飞书,无中转服务器
- 外部对话 → Mac 端 MCP Server 跑本地进程

**设计系统**(spec §7):
- Aurora 暖粉橙 / 天蓝 / 淡紫 / 琥珀金
- 玻璃卡 `.ultraThinMaterial` + 白色高光 1px + 柔和下投影
- 金额以 Int cents 存储,规避浮点漂移

## 发布到 App Store

- **[docs/AUTO_UPDATE.md](docs/AUTO_UPDATE.md)** · 自动推送更新是怎么做的 · 三层自动化链路
- **[docs/RELEASE.md](docs/RELEASE.md)** · 详细的证书 / Profile / TestFlight / 审核步骤

一次性配好 8 个 GitHub secret 后,每次发版只需要两行:

```bash
git tag v1.3.0
git push origin v1.3.0
```

[`.github/workflows/release.yml`](.github/workflows/release.yml) 会自动 archive + 上传 TestFlight,并开一个 GitHub Release。
日常 push / PR 由 [`.github/workflows/ci.yml`](.github/workflows/ci.yml) 跑 287 个测试。

## 文档

- [Glassbook 产品规格说明书](Glassbook-产品规格说明书.docx)
- [glassbook-app-screens.html](glassbook-app-screens.html) · 6 核心页高保真
- [glassbook-smart-import.html](glassbook-smart-import.html) · 智能识别 4 屏流程
- [glassbook-feature-insights.html](glassbook-feature-insights.html) · 扩展功能图谱
- [glassbook-advanced-features.html](glassbook-advanced-features.html) · Local-First Synthesis v2
- [docs/AUTO_UPDATE.md](docs/AUTO_UPDATE.md) · 自动推送更新三层机制
- [docs/RELEASE.md](docs/RELEASE.md) · 发布手册(证书 / TestFlight / 审核)

## License

MIT · 随便用,欢迎贡献。

Built with restraint, shipped with care.
