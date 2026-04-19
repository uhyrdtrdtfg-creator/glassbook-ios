# Glassbook iOS — V1.0 MVP Scaffold

一款会呼吸的智能记账 App · SwiftUI · iOS 17+

根据 `Glassbook-产品规格说明书.docx` V1.0 + 4 份 HTML 高保真稿搭建的可直接运行的 SwiftUI 工程脚手架。

---

## 快速开始

```bash
cd /Users/samxiao/desgin/Glassbook
open Glassbook.xcodeproj
# ⌘R 跑到模拟器
```

首次打开如果 Xcode 提示签名,在 `Target → Signing & Capabilities` 选一个 Apple ID 团队即可 (Bundle ID 默认为 `app.glassbook.ios`)。

---

## 当前实现了什么

### V1.0 MVP 全部 6 屏 + 智能识别 4 屏流程

| 模块 | 状态 | 对应 spec |
|---|---|---|
| 首页 · 本月总览 | 可交互 + 样本数据 | §4.1 |
| 记一笔 (含自定义键盘 + 扫一扫入口) | 可交互 + 保存到 AppStore | §4.2 |
| 账单明细 (按日分组 + 月份切换 + 分类筛选) | 可交互 | §4.3 |
| 数据统计 (Swift Charts 环形图 + 7 月柱状图 + AI 解读卡) | 可交互 | §4.4 |
| 预算管理 (总环形进度 + 分类进度条) | 可交互 | §4.5 |
| 我的 (资料 + 3 格数据 + 分组菜单) | 可交互 | §4.6 |
| **智能识别 · 入口** | 平台列表 + 隐私说明 + 双底按钮 | §5.3.1 |
| **智能识别 · 扫描** | 扫描线动画 + 四角焦点框 + 进度 | §5.3.2 |
| **智能识别 · 确认** | 8 行可勾选列表 + 去重标记 + 批量全选 | §5.3.3 |
| **智能识别 · 完成** | 对勾动画 + 绿色光晕 + 汇总卡 | §5.3.4 |

### 设计系统 (严格对齐 spec §7)
- `AppColors`: Aurora 4 光斑 + 品牌渐变 + 8 分类渐变 + 5 平台品牌色
- `AppFont`: 7 层级字号 (Display 44 / H1 32 / H2 20 / Title 17 / Body 15 / Label 13 / Caption 11)
- `Space` + `Radius`: 8 倍基数间距系统 + 5 档圆角
- `AuroraBackground`: 10 种预制光斑背景 (6 主屏 + 4 导入流程)
- `GlassCard`: `.ultraThinMaterial` + 白色高光边 + 柔和投影 (spec §7.1.2)

### 数据层
- `Transaction` / `Category` / `Account` / `Budget` / `ImportBatch`
- **金额以分 (Int) 存储**,避免 Decimal 精度漂移 (spec §8.3)
- `source` 字段追踪来源: `manual / alipay / wechat / cmb / jd / meituan / douyin / otherOCR`
- `importBatchID` 支持整批回滚
- `AppStore` 使用 iOS 17 `@Observable`,Home/Stats/Budget 的派生数据 (月支出/预算剩余/环形图/7 月趋势) 全部从它算出

### 样本数据
`SampleData.transactions` 生成当月 ~62 笔交易 + 2 笔收入,驱动所有页面的图表和列表,无需数据库即可预览全流程。

---

## 目录结构

```
Glassbook/
├── project.yml                            # xcodegen 配置
├── README.md
└── Glassbook/
    ├── GlassbookApp.swift                 # @main 入口
    ├── App/
    │   └── RootView.swift                 # 根视图 + 自定义 TabBar (4+1 FAB)
    ├── DesignSystem/
    │   ├── AppColors.swift
    │   ├── AppTypography.swift
    │   ├── AppSpacing.swift
    │   ├── AuroraBackground.swift
    │   └── GlassCard.swift
    ├── Models/
    │   ├── Models.swift                   # Transaction / Category / Account / Budget / ImportBatch
    │   └── SampleData.swift
    ├── Store/
    │   └── AppStore.swift                 # @Observable 状态
    ├── Features/
    │   ├── Home/HomeView.swift
    │   ├── Bills/BillsView.swift
    │   ├── AddTransaction/AddTransactionView.swift
    │   ├── Stats/StatsView.swift
    │   ├── Budget/BudgetView.swift
    │   ├── Profile/ProfileView.swift
    │   └── SmartImport/SmartImportFlow.swift   # 4 屏合一
    ├── Components/
    │   └── TransactionRow.swift
    └── Assets.xcassets/
```

---

## 下一步 (V1.1 → V1.2 优先级)

**真数据层 (必做)**
- [ ] Core Data 模型 (`Transaction` / `Category` / `Account` / `Budget` / `ImportBatch`),迁移 `SampleData`
- [ ] CloudKit 私有库同步 (spec §8.2)
- [ ] Face ID 启动守卫 (spec §8.4)

**智能识别真实落地 (差异化核心)**
- [ ] Vision Framework OCR (`VNRecognizeTextRequest` · spec §8.2)
- [ ] 支付宝/微信/招行的规则解析器 (商户名 / 金额 / 时间正则)
- [ ] 商户→分类映射表 + 学习能力 (spec §5.4)
- [ ] 去重逻辑: 同商户 + 同金额 + 5 分钟窗口 (spec §5.4)

**V1.1 扩展**
- [ ] 多账户切换与净资产 (spec §6.1 P0)
- [ ] 订阅管理 + 续费提醒 (spec §6.2 Hero 3)
- [ ] 储蓄目标 (spec §6.2 Hero 2)

**V1.2 Pro**
- [ ] 年度回顾 (Spotify Wrapped 式 · spec §6.2 Hero 1)
- [ ] 桌面小组件 (WidgetKit)
- [ ] AI 消费洞察

---

## 开发备忘

- Aurora 使用真 radial gradient + opacity 光斑,比用图片省 assets 尺寸。`UIScreen.main.bounds` 驱动半径,iPad 适配时换 `GeometryReader`
- Glass 卡片基于 `.ultraThinMaterial`,在亮色 Aurora 上表现最好;spec §8.1 二期 Android 要换自绘模糊
- iOS 17 `@Observable` 替代 `ObservableObject`,免 `@Published` 标记,`@Environment` 注入更简洁
- Charts 仅用于环形图 (`SectorMark`);柱状图因需极细控制改用手写,与 spec mockup 一致

Built with restraint, shipped with care.
