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

### 2. ⚪ 批量删除 / 多选
**现状**: [BillsView](../Glassbook/Glassbook/Features/Bills/BillsView.swift) 只能一笔一笔删。10 笔重复 = 10 次长按 · 一只手操作很难。

**做法**:
- Bills nav 加"编辑"按钮进 `EditMode`
- TransactionRow 左侧出 checkbox
- 底部浮一条"删除选中 (N)"
- AppStore 加 `deleteMany(ids: [UUID])` 批量走 SwiftData delete

**估时**: 1 小时
**文件**: `Features/Bills/BillsView.swift`, `Store/AppStore.swift`

---

### 3. ⚪ 删除后撤销 (Toast)
**现状**: `store.delete(id)` 立即生效。手抖删错只能重录入。

**做法**:
- AppStore 加 `recentlyDeleted: Transaction?` + 5 秒 timer
- 删除时不立即 SwiftData delete, 先从 in-memory 移除
- 弹 `Toast` · "已删除 · 撤销" (SwiftUI 自定义 overlay 或 iOS 17+ `.toast`)
- 5 秒后 timer 到, 真正 commit delete; 点"撤销"则 revert

**估时**: 1-1.5 小时
**文件**: `Store/AppStore.swift`, 新 `Components/Toast.swift`

---

### 4. 🟢 跨月搜索
落在 [68145db](https://github.com/uhyrdtrdtfg-creator/glassbook-ios/commit/68145db). `.searchable` + `localizedCaseInsensitiveContains` 扫全量 · 命中期间隐藏月份导航和汇总卡 · 零结果走 "找不到「query」" 空态。分类 chip 仍然生效。

---

### 5. 🟢 CSV 导出
落在 [c6bf8fd](https://github.com/uhyrdtrdtfg-creator/glassbook-ios/commit/c6bf8fd). UTF-8 BOM + 7 列 (date/merchant/category/amount/account/note/source),RFC 4180 quoting,写临时文件后交给 `ShareLink(item: URL)`,文件名 `Glassbook-yyyyMMdd-HHmmss.csv` 与 PDF 配对。

---

## 🟡 第二梯队 · 差异化功能 · 每个 1-3 小时

### 6. ⚪ AI 自动分类预览
**现状**: SmartImportConfirmScreen 的"AI 自动分类"按钮点了直接覆盖。看不到模型把哪笔从 A 改到了 B。

**做法**:
- `LLMClassifier.categorize` 返回值已经是 `[UUID: Category.Slug]`
- 加 `PreviewDiffSheet` 显示 "钱大妈 餐饮 → 其他?" 列表
- 每行 checkbox 默认勾选 · 点"应用勾选的 N 项"才覆盖

**估时**: 1.5 小时
**文件**: `Features/SmartImport/SmartImportFlow.swift`, `Services/LLMClassifier.swift`

---

### 7. ⚪ AI 修正商户名
**现状**: OCR 出来的"深圳市兜点实业有限责任公司"看着就想改成"兜点便利店"。现在只能手动编辑。

**做法**:
- EditPendingRowSheet / EditTransactionSheet 商户名旁加 "✨ AI 简化" 按钮
- 调当前 BYO 引擎 · prompt: "把这个商户名简化成用户日常叫的版本, 直接输出简化后的名字不要解释"
- 把结果填入 merchant 字段 · 用户可以继续改
- 失败 / 未配 LLM 降级为不显示按钮

**估时**: 1 小时
**文件**: `Services/LLMClassifier.swift` 加 `simplifyMerchantName`, UI 2 处

---

### 8. 🟢 Webhook URL 挪到 Keychain
落在 [adf369c](https://github.com/uhyrdtrdtfg-creator/glassbook-ios/commit/adf369c). `Endpoint.url` 保留 stored var (UI 绑定兼容) 但 `CodingKeys` 显式排除;Keychain key `webhook.url.<uuid>`;`restore()` double-decode 老数据一次性迁移,Keychain 写失败回滚 UD 防丢配置。UI 层零改动。

---

### 9. ⚪ 首次启动引导
**现状**: 新装直接进首页, 用户不知道有 AI 分类 / 截屏自动识别 / 家庭共享。

**做法**:
- 首次启动检测 (UserDefaults flag)
- 3 步 sheet: `AIEnginePickerStep` (可跳过) → `ScreenshotAutomationStep` (教 Shortcut) → `FamilyStep` (起名, 可跳过)
- 完成后写 flag, 以后不再弹

**估时**: 2-3 小时
**文件**: 新 `Features/Onboarding/` 目录

---

### 10. 🟢 月度对比卡片
落在 [525f4b2](https://github.com/uhyrdtrdtfg-creator/glassbook-ios/commit/525f4b2). 发现 `AppStore.monthlyTrend` offset>0 返回合成数据,改用 `lastMonthExpenseCents` + `thisMonthExpenseCents` 真实对比;locale-aware 月名 (`setLocalizedDateFormatFromTemplate("MMM")`),上月零支出降级为 "本月首次支出"。

---

## 🔵 第三梯队 · 数据 / 隐私 / 品质

### 11. ⚪ CKShare 家庭操作闭环
**现状**: 能创建家庭分享但没"退出" / "解散"入口。CloudKit 数据留在服务器。

**做法**: FamilyBookView 加 "退出此家庭账本" + "重置所有共享" 两个按钮, 走 CKShare API。

**估时**: 2 小时
**文件**: `Features/Family/FamilyBookView.swift`, `Services/FamilySharingService.swift`

---

### 12. ⚪ Receipt OCR 发 LLM 前脱敏
**现状**: 收据原文整段扔给 BYO 引擎 (可能是 OpenAI 云), 可能含卡号尾号 / 地址 / 手机号。

**做法**:
- 发送前正则扫: `\d{16,}` → `****`, `1[3-9]\d{9}` → `1*****`, `[地址栏 xxxx]` 省市区截断到区
- 统一放 `Util/PIIRedactor.swift`
- 所有 LLM 出站调用 (Classifier / Receipt / Advisor) 过一遍

**估时**: 1 小时
**文件**: 新 `Util/PIIRedactor.swift`, 多处调用点

---

### 13. ⚪ 汇率定时刷新
**现状**: 启动时拉一次 · App 不重启就用旧数据。多币种用户会偏差。

**做法**: CurrencyService 加 24h TTL, 过期自动后台刷。

**估时**: 30 分钟
**文件**: `Services/CurrencyService.swift`

---

### 14. ⚪ Watch 快速记账
**现状**: WatchQuickAddView 只是框架, Digital Crown 调金额的交互没做。

**做法**: `.focusable() + .digitalCrownRotation` 绑金额, List 选分类, 保存走 AppStore。

**估时**: 1.5 小时
**文件**: `GlassbookWatch/WatchQuickAddView.swift`

---

### 15. ⚪ iPad / Mac Catalyst 适配
**现状**: `SUPPORTS_MACCATALYST=YES` 但 Mac 上几个 sheet 太小, 玻璃样式不精致。

**做法**: Mac sheet 用 `.form` 或 `.large` detent, 布局判断 `horizontalSizeClass`。

**估时**: 3 小时
**文件**: 多处 View

---

## 🧪 工程层 · 自己看见 · 长期重要

### 16. ⚪ 批量 OCR perf 单测
**现状**: 限并发 + 缩图容易回归 · 没有自动化 gate。

**做法**: `@Test func batchOcrUnderMemoryBudget()` 跑 10 张 fake image, 监控 RSS 不过阈值。

**估时**: 1 小时
**文件**: 新 `GlassbookTests/PerfTests.swift`

---

### 17. ⚪ Snapshot 测试
**现状**: SmokeTests 只测 view build, CSS 样式 regress 没人发现。

**做法**: 引入 `pointfreeco/swift-snapshot-testing`, 关键页面留 PNG 基线。CI 跑 diff, 改了会失败强制 review。

**估时**: 3 小时
**文件**: `Package.swift` / `project.yml` 加 package, 新 `GlassbookTests/SnapshotTests.swift`

---

### 18. ⚪ AIEngineStore / WebhookStore 去单例
**现状**: `.shared` 全局状态, 单测要小心 teardown。

**做法**: 改成 `@Observable` 实例 + `.environment` 注入。各 View 用 `@Environment(AIEngineStore.self)`。

**估时**: 2 小时
**文件**: `Services/AIEngineStore.swift`, `Services/WebhookStore.swift`, `GlassbookApp.swift` + 所有消费方

---

### 19. ⚪ 拆分 SmartImportFlow.swift
**现状**: 1100+ 行, 5 个 Screen + 共享 helpers 全挤在一个文件。

**做法**: 按 Screen 拆, `SmartImport/` 下多文件:
- `SmartImportFlow.swift` (只留 coordinator)
- `Screens/EntryScreen.swift`
- `Screens/ScanningScreen.swift`
- `Screens/ConfirmScreen.swift`
- `Screens/DoneScreen.swift`
- `Screens/EmptyScreen.swift`
- `Sheets/EditPendingRowSheet.swift`

**估时**: 1 小时
**文件**: `Features/SmartImport/`

---

### 20. ⚪ CI 加性能基线
**现状**: Actions 只跑功能测试, 没跑性能。

**做法**: nightly job 跑批量 OCR 计时 + 内存峰值, 回归开 issue。

**估时**: 2 小时
**文件**: `.github/workflows/perf.yml`

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
