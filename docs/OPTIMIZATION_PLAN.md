# Glassbook 优化计划

> 活清单 · 按 "用户感知痛点 ÷ 工程量" 排序。前面的做完再往下推。
> 每个条目形式: **标题** · 现状 · 做法 · 估时 · 关联文件。

状态标记:
- 🟢 已完成
- 🟡 进行中
- ⚪ 未开始

---

## 🔥 第一梯队 · 日常痛点 · 每个 0.5-2 小时

### 1. 🟢 编辑时未保存提示
落在 [552258c](https://github.com/uhyrdtrdtfg-creator/glassbook-ios/commit/552258c). `RichTxFormView` 内部 `hasEditedValues` + `.confirmationDialog`,8 个 field 全部挂上 dirty 信号;两处 caller (EditTransactionSheet / EditPendingRowSheet) 零 diff。

---

### 2. 🟢 批量删除 / 多选
落在 [b08d0bf](https://github.com/uhyrdtrdtfg-creator/glassbook-ios/commit/b08d0bf) (与 3 共体). 工具栏"编辑"翻 EditMode, 行前 checkbox, 底部浮出 `.borderedProminent` + `expenseRed` 的 "删除选中 (N)"; 编辑中隐搜索 / summary 卡腾出纵向空间。走 `deleteMany(ids:)` 共享撤销管道。

---

### 3. 🟢 删除后撤销 (Toast)
落在 [b08d0bf](https://github.com/uhyrdtrdtfg-creator/glassbook-ios/commit/b08d0bf). `PendingDeletion { ids, snapshot }` + `Task.sleep(5s)` timer; `undoDelete` 恢复内存快照并取消 task; scenePhase 进后台立即 `commitPendingDeletionNow`。新增 `Features/Components/Toast.swift` · `UndoToast` 组件, `.ultraThinMaterial` + "撤销" 胶囊按钮, 父视图控制显隐。

---

### 4. 🟢 跨月搜索
落在 [68145db](https://github.com/uhyrdtrdtfg-creator/glassbook-ios/commit/68145db). `.searchable` + `localizedCaseInsensitiveContains` 扫全量 · 命中期间隐藏月份导航和汇总卡 · 零结果走 "找不到「query」" 空态。分类 chip 仍然生效。

---

### 5. 🟢 CSV 导出
落在 [c6bf8fd](https://github.com/uhyrdtrdtfg-creator/glassbook-ios/commit/c6bf8fd). UTF-8 BOM + 7 列 (date/merchant/category/amount/account/note/source),RFC 4180 quoting,写临时文件后交给 `ShareLink(item: URL)`,文件名 `Glassbook-yyyyMMdd-HHmmss.csv` 与 PDF 配对。

---

## 🟡 第二梯队 · 差异化功能 · 每个 1-3 小时

### 6. 🟢 AI 自动分类预览
落在 [ad74c02](https://github.com/uhyrdtrdtfg-creator/glassbook-ios/commit/ad74c02) (与 7 共体). `runAIClassify` 不再直接覆盖, 构建 `AIClassifyDiffItem` 过滤掉 no-op 行, 打开 `AIClassifyDiffSheet` (inline, AuroraBackground + glassCard 列表) 让用户逐行确认; footer "应用勾选的 N 项"。

---

### 7. 🟢 AI 修正商户名
落在 [ad74c02](https://github.com/uhyrdtrdtfg-creator/glassbook-ios/commit/ad74c02). `LLMClassifier.simplifyMerchantName(raw:)` 带结果清洗 (去引号 / 单行 / 长度上限 30); "✨ AI 简化" 按钮放进 `RichTxFormView.merchantNoteCard` 一次搞定两个 sheet; `appleIntelligence` / 未配 key 自动隐藏。

---

### 8. 🟢 Webhook URL 挪到 Keychain
落在 [adf369c](https://github.com/uhyrdtrdtfg-creator/glassbook-ios/commit/adf369c). `Endpoint.url` 保留 stored var (UI 绑定兼容) 但 `CodingKeys` 显式排除;Keychain key `webhook.url.<uuid>`;`restore()` double-decode 老数据一次性迁移,Keychain 写失败回滚 UD 防丢配置。UI 层零改动。

---

### 9. 🟢 首次启动引导
落在 [4ab1de3](https://github.com/uhyrdtrdtfg-creator/glassbook-ios/commit/4ab1de3). `@AppStorage("hasCompletedOnboarding")`, 从 `RootView` 挂 `.sheet` + `.interactiveDismissDisabled()`。三步: AIEnginePicker (teaser → 我 → AI 引擎) / ScreenshotAutomation (Shortcut 名 "Glassbook 识别截屏") / Family (写真实 `store.familyGroupName`, 与 EditProfileSheet 共用存储)。每步可跳过, 3 点进度条。

---

### 10. 🟢 月度对比卡片
落在 [525f4b2](https://github.com/uhyrdtrdtfg-creator/glassbook-ios/commit/525f4b2). 发现 `AppStore.monthlyTrend` offset>0 返回合成数据,改用 `lastMonthExpenseCents` + `thisMonthExpenseCents` 真实对比;locale-aware 月名 (`setLocalizedDateFormatFromTemplate("MMM")`),上月零支出降级为 "本月首次支出"。

---

## 🔵 第三梯队 · 数据 / 隐私 / 品质

### 11. 🟢 CKShare 家庭操作闭环
落在 [40171bf](https://github.com/uhyrdtrdtfg-creator/glassbook-ios/commit/40171bf). Service 从 enum 升 `@Observable class` (留 .shared),加 `refreshOwnership` / `leaveShare` / `dissolveShare`;拥有者私有 DB 删 share + zone,非拥有者抛 `.permissionFailure`;`zoneNotFound` / `unknownItem` 全吞当幂等。FamilyBookView 尾部"危险操作"玻璃卡按 ownership 只显对应按钮。

---

### 12. 🟢 Receipt OCR 发 LLM 前脱敏
落在 [144f748](https://github.com/uhyrdtrdtfg-creator/glassbook-ios/commit/144f748). `Util/PIIRedactor.swift` · 7 pass 顺序: ID → Card → Mobile → Landline → Email → Addr (带 `(?<!\d)...(?!\d)` 锁边界,天然幂等)。落地 3 个出站点: ReceiptOCRService LLM 抽取 · LLMClassifier.categorize + simplifyMerchantName · AdvisorChatService.remoteRespond。

---

### 13. 🟢 汇率定时刷新
落在 [5df4467](https://github.com/uhyrdtrdtfg-creator/glassbook-ios/commit/5df4467). `lastFetchedAt` 写 UD (key `currency.lastFetchedAt`, Double), `isStale = now - t > 24h`。init / scenePhase `.active` / 显式 `refreshIfStale()` 三路都 gate;网络失败不敲时间戳,下次前台再试。

---

### 14. 🟢 Watch 快速记账
落在 [2258c4c](https://github.com/uhyrdtrdtfg-creator/glassbook-ios/commit/2258c4c). `@FocusState` + `digitalCrownRotation(0...9999, .medium)` 绑 `¥` 整元 · 9 分类横滚条 (Watch target 进不到 Models.swift 按 Category.Slug rawValue 本地硬编) · 保存 `PendingImportQueue.enqueue`,下次 iOS 前台 `drainPendingImports` 回收为真实 Transaction。

---

### 15. ⚪ iPad / Mac Catalyst 适配
**现状**: `SUPPORTS_MACCATALYST=YES` 但 Mac 上几个 sheet 太小, 玻璃样式不精致。

**做法**: Mac sheet 用 `.form` 或 `.large` detent, 布局判断 `horizontalSizeClass`。

**估时**: 3 小时
**文件**: 多处 View

---

## 🧪 工程层 · 自己看见 · 长期重要

### 16. 🟢 批量 OCR perf 单测
落在 [f817c5b](https://github.com/uhyrdtrdtfg-creator/glassbook-ios/commit/f817c5b). Swift Testing `@Test batchOcrUnderMemoryBudget`,10 张 1024×1024 程序生成图,走 `VisionOCRService.recognize` + 3-way TaskGroup 复现热路径 (不经 LLM/网络);`mach_task_basic_info` 抓 RSS,warm-up 一轮后稳态增量 < 200MB。iPhone 16 sim 12.4s 绿。

---

### 17. 🟢 Snapshot 测试
落在 [ccb6288](https://github.com/uhyrdtrdtfg-creator/glassbook-ios/commit/ccb6288). project.yml 加 `packages:` + `SnapshotTesting 1.17` 挂 GlassbookTests 依赖。3 张基线 (HomeView / BillsView / SmartImportEntryScreen) 走 UIHostingController · `.image(on: .iPhone13, precision: 0.98)`;首跑自动记,二跑全绿。XCTest 而非 Swift Testing (Swift Testing 会吃掉 XCTContext PNG diff)。

---

### 18. ⚪ AIEngineStore / WebhookStore 去单例
**现状**: `.shared` 全局状态, 单测要小心 teardown。

**做法**: 改成 `@Observable` 实例 + `.environment` 注入。各 View 用 `@Environment(AIEngineStore.self)`。

**估时**: 2 小时
**文件**: `Services/AIEngineStore.swift`, `Services/WebhookStore.swift`, `GlassbookApp.swift` + 所有消费方

---

### 19. 🟢 拆分 SmartImportFlow.swift
落在 [9800e97](https://github.com/uhyrdtrdtfg-creator/glassbook-ios/commit/9800e97). 1403 → 344 行 + 6 子文件 (Screens/{Entry,Scanning,Confirm,Done} · Sheets/{EditPendingRow,AIClassifyDiff})。零行为改动,零 rename,零 access 修正 (原本就 internal);coordinator 留 Step / 扫描 pipeline / Preview (跨 screen 引 StatefulPreview)。EmptyScreen 本来就独立文件。

---

### 20. 🟢 CI 加性能基线
落在 [f7f6c2a](https://github.com/uhyrdtrdtfg-creator/glassbook-ios/commit/f7f6c2a). `perf.yml` · UTC 15:00 (北京 23:00) 夜跑 PerfTests · runner / Xcode / scheme 对齐 ci.yml (`macos-14` · `Xcode_15.4` · `GlassbookCI` 避 watchOS SDK 坑)。回归 dedup Option A: `listForRepo` 找已开 `perf+regression` issue 就 comment · 没有才开 · 不刷屏。

---

## 🎯 推荐一周冲刺顺序

**Day 1** · 日常痛点四件套 (第 1, 2, 3, 4 项) · 半天
**Day 2** · CSV 导出 (第 5 项) + AI 修正商户名 (第 7 项) · 半天
**Day 3** · AI 自动分类预览 (第 6 项) + 月度对比卡 (第 10 项) · 半天
**Day 4** · Webhook URL 入 Keychain (第 8 项) + PII 脱敏 (第 12 项) · 一天
**Day 5** · 首次启动引导 (第 9 项) · 一天
**Day 6** · 批量 OCR perf 单测 (第 16 项) + Snapshot 测试 (第 17 项) · 一天
**Day 7** · 长尾 · 剩下按需做

## 📊 总估时

- 第一梯队 5 项: ~3.5 小时
- 第二梯队 5 项: ~8 小时
- 第三梯队 5 项: ~8 小时
- 工程层 5 项: ~9 小时
- **总计: ~28.5 小时 (~4 个工作日)**

## 🔄 活清单怎么维护

每做完一项 · 把状态改成 🟢 并链接到落库 commit · 比如:

```markdown
### 1. 🟢 编辑时未保存提示
落在 [commit abc1234](https://github.com/...). 303 → 305 tests。
```

新发现的优化项目插到对应梯队尾部, 保持排序。
