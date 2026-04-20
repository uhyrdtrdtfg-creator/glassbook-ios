# 自动推送更新 · 原理和怎么配

> "别人 App 更新都是自动的,我不用去 TestFlight 手动点,也能做到吗?"

能。完整链路是三层,每一层都能自动化。配好之后你日常只要一行:

```bash
git tag v1.3.0 && git push origin v1.3.0
```

用户手机上就会自动出现新版本。不用开 Xcode 点 Archive,不用去 TestFlight 拖 IPA。

---

## 三层都在自动化什么

```
你这边                   Apple 这边                  用户手机
─────                    ──────                     ────────
git tag v1.3.0
        │
        ▼
   GitHub Actions ──────→ App Store Connect ──────→ TestFlight App
   (release.yml)          (TestFlight 构建处理)      (自动下载新 build)
        │                         │
  archive + sign             Beta App Review
  altool upload              (首次外部测试 ~24h)
                                   │
                                   ▼
                             App Store ──────────→ iOS App Store
                             (正式审核 ~48h)         (自动更新开关)
```

### 层 1 · 代码 → TestFlight(CI 干)

**做什么**:打 tag → GitHub Actions 构建 + 签名 + 上传 IPA 到 App Store Connect。

**谁干的**:`.github/workflows/release.yml`(已经写好,在仓库根)。

**触发条件**:推一个 `v*.*.*` 格式的 tag。

**替代手动的是**:
- 以前每次发版都要开 Xcode → Product → Archive → Window → Organizer → Distribute App → Upload
- 现在只要 `git push origin v1.3.0`

**前置配置**(一次性):仓库 Settings → Secrets and variables → Actions,塞 8 个 secret。详细步骤见 [`docs/RELEASE.md`](RELEASE.md)。

### 层 2 · TestFlight → 测试者手机(Apple 干)

**做什么**:测试者不用每天开 TestFlight 看有没有新版本,系统后台自己装。

**谁干的**:Apple 的 TestFlight App。

**触发条件**:测试者在 TestFlight App 里打开"自动更新"开关。

**配法**:
1. 测试者在 iPhone 上打开 TestFlight
2. 选 Glassbook
3. 右上角 `⋯` → 打开"自动更新"

之后你每次上传新 build,他连 Wi-Fi + 充电时会自动装。看都不用看。

### 层 3 · App Store → 普通用户(Apple 干)

**做什么**:上架 App Store 后,所有用户系统自动更新,不需要他手动去 App Store 点。

**谁干的**:iOS 系统的 App Store 后台任务。

**触发条件**:用户 iPhone 设置 → App Store → App Updates 打开(绝大多数人默认都开着)。

这是 iOS 默认行为,不需要你做任何事。

---

## 所以日常发版我要做什么

### 一次性配置(只做一次)

1. **Apple Developer 账号**(¥688/年)→ 拿 Team ID
2. **App Store Connect 建 App**(bundle id `app.glassbook.ios`)
3. **生成 4 份物料**:Distribution 证书 `.p12` · Provisioning Profile `.mobileprovision` · App Store Connect API Key `.p8` · 一串随机 keychain 密码
4. **base64 编码后塞 GitHub Secrets**(8 个值,名字见 [`docs/RELEASE.md`](RELEASE.md))

做完一次之后这些就不用再碰了。证书 1 年后过期要重做一次第 3~4 步。

### 日常每次发版

```bash
# 1. 本地确认测试绿
cd /Users/samxiao/desgin/Glassbook
xcodebuild test -scheme GlassbookCI \
  -destination 'platform=iOS Simulator,name=iPhone 16'

# 2. 改 MARKETING_VERSION (可选 · CI 也能用 agvtool 自动写)
# 在 project.yml 里改一下 1.3.0 → 1.3.1
# xcodegen generate

# 3. 打 tag 推远程
git tag v1.3.1
git push origin v1.3.1

# 4. 等邮件 (~15 分钟)
```

15 分钟后收两封邮件:
- Apple:"Glassbook 1.3.1 is now ready for testing"
- GitHub:Release 已创建

内部测试组的人就能在 TestFlight 里看到了。如果他们开了自动更新,手机上也同步到了。

### 正式上架 App Store

TestFlight 测试没问题后:

1. App Store Connect → Glassbook → "App Store" 标签 → "+ 版本" → iOS
2. 新版本填 1.3.1,对齐 tag
3. 填写更新说明(2~4 句话,用户能看懂)
4. "可供销售"里选刚上的 build
5. 提交审核 → 24~48 小时过
6. 过审后选"自动发布"或"立即发布"

过审后,所有装了 Glassbook 的用户 iPhone 会在下一次 App Store 自动更新检查时装上新版本。你什么都不用做。

---

## 常见误区

**误区 1 · "自动推送 = 绕过审核"**

不对。正式 App Store 版本每次都要审。你能"自动化"的是**上传到审核队列**的过程,不是审核本身。

**例外**:TestFlight 的内部测试(≤100 个苹果 ID,都在你的团队里)不审,上传即测。所以很多人先给自己 + 同事发 TestFlight 里跑着,真要上架才开审。

**误区 2 · "CI 搭了就一键发版了"**

没搭 secret 的话,CI 会失败。8 个 secret 都配齐了才能跑通。

**误区 3 · "测试者 / 用户会立刻看到新版本"**

- TestFlight 自动更新:Wi-Fi + 充电时,可能延迟几小时
- App Store 自动更新:同上,Apple 一般 24 小时内全球覆盖
- 想让用户立刻拿到:只能让他自己开 App Store 主动搜 Glassbook → 点更新

**误区 4 · "我可以在 App 里搞 OTA,绕过 App Store"**

不行。苹果政策不允许公开 App 做 OTA 代码更新。企业分发(Enterprise Program)可以,但那是给公司内部员工用的,不能上架 App Store。

---

## 回滚怎么办

**情况 1 · TestFlight build 有严重 bug** → 不管它,下个版本覆盖就行。

**情况 2 · 正式版本发布后发现严重 bug** → App Store 不能"降级",只能发 hotfix 版本走**加急审核**:
1. App Store Connect → Resolution Center → Request Expedited Review
2. 一年只有几次机会,留给真正紧急的

**情况 3 · CI 失败** → 看 [Actions 页面](https://github.com/uhyrdtrdtfg-creator/glassbook-ios/actions)日志,`TestResults.xcresult` 会作为 artifact 上传。本地复现:`xcodebuild test -scheme GlassbookCI`。

---

## TL;DR 速查

```bash
# 日常发版
git tag v1.3.0 && git push origin v1.3.0
# 等邮件 → TestFlight 装机验证 → ASC 提审 → 发布
```

配一次,以后都是这两行。

详细的 secret 配置步骤 + 签名物料获取在 [`docs/RELEASE.md`](RELEASE.md)。
