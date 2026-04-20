# Glassbook 发布手册

这篇是从零到 App Store 的完整操作指导。一次性配好,以后每次发版都是 `git tag` + `git push --tags`,然后等 TestFlight 邮件。

---

## 一、一次性准备(只做一次)

### 1. Apple Developer Program 账号

- 开账号: <https://developer.apple.com/programs/enroll/> · ¥688/年
- 开完记下 **Team ID** (10 位字母数字,在 Membership 页面右上角)

### 2. App Store Connect 创建 App

- 打开 <https://appstoreconnect.apple.com/apps> → 右上 "+" → 新增 App
- 平台: iOS · 名称: `Glassbook` · 主要语言: 简体中文
- Bundle ID: `app.glassbook.ios` (要和 [`Glassbook/project.yml:32`](../Glassbook/project.yml#L32) 里一致)
- SKU: `glassbook-ios-001` (随便写,不会露给用户)

### 3. 生成 App Store Connect API Key(CI 用)

CI 要用这个 key 上传 IPA,比用密码安全。

1. <https://appstoreconnect.apple.com/access/api> → "密钥" 标签 → "+" 生成新密钥
2. 名称填 `Glassbook CI` · 权限选 **App Manager**(必须,否则上传被拒)
3. 下载 `AuthKey_XXXXXX.p8` 文件(**只能下一次,丢了只能重发**)
4. 记下三个值:
   - **Key ID**: 10 位字母数字(页面上 "密钥 ID" 列)
   - **Issuer ID**: UUID 格式(页面顶部)
   - **p8 文件**: 上面下载的那个

### 4. 生成分发证书 + Provisioning Profile

本地先配一次(CI 需要 base64 版本):

```bash
# 1. 打开 Xcode → Settings → Accounts → 登录你的 Apple ID
# 2. 选 Team → Manage Certificates → "+" → Apple Distribution
# 3. Keychain Access 里找到这个证书 → 右键 Export → Glassbook_Dist.p12
#    设个密码,记下来(待会儿塞 secret 用)
```

Provisioning Profile:

1. <https://developer.apple.com/account/resources/profiles/list>
2. "+" → iOS App Store → 选你的 App ID (`app.glassbook.ios`)
3. 选刚生成的 Distribution Certificate
4. 名称: `Glassbook App Store` · 下载 `.mobileprovision`

### 5. 把 Secrets 塞进 GitHub

仓库主页 → Settings → Secrets and variables → Actions → New repository secret。

把文件转成 base64:

```bash
base64 -i Glassbook_Dist.p12         | pbcopy   # → APPLE_DEV_CERT_P12
base64 -i Glassbook_App_Store.mobileprovision | pbcopy   # → APPLE_DEV_PROFILE
base64 -i AuthKey_XXXXXX.p8          | pbcopy   # → APP_STORE_CONNECT_API_KEY
```

要填的 7 个 secret:

| Secret 名称 | 内容 |
|---|---|
| `APPLE_TEAM_ID` | 10 位 Team ID(第 1 步拿的) |
| `APPLE_DEV_CERT_P12` | `.p12` 的 base64 |
| `APPLE_DEV_CERT_PASSWORD` | 导出 `.p12` 时设的密码 |
| `APPLE_DEV_PROFILE` | `.mobileprovision` 的 base64 |
| `APPLE_DEV_KEYCHAIN_PASSWORD` | 随便一串随机字符,CI 临时 keychain 用 |
| `APP_STORE_CONNECT_API_KEY_ID` | 第 3 步的 Key ID |
| `APP_STORE_CONNECT_API_ISSUER_ID` | 第 3 步的 Issuer ID |
| `APP_STORE_CONNECT_API_KEY` | `.p8` 的 base64 |

配完刷新页面应该看到 8 条灰色的 secret 条目。

### 6. 验证 CI 能跑

先推一条小改动到 main 或开 PR,看 [Actions 页面](https://github.com/uhyrdtrdtfg-creator/glassbook-ios/actions) 里的 **CI** 工作流是不是绿的。绿了才往下走。

---

## 二、每次发版(以下都会跑完)

### 1. 本地回归一次

```bash
cd /path/to/Glassbook
xcodegen generate
xcodebuild test -scheme GlassbookCI -destination 'platform=iOS Simulator,name=iPhone 16'
# → 期望: 279 tests passed
```

### 2. 确定版本号

遵循 Semver:

- 修 bug / 小调整 → patch: `1.2.0` → `1.2.1`
- 加功能、不破坏现有 → minor: `1.2.1` → `1.3.0`
- 重写数据模型、破 CloudKit schema → major: `1.3.0` → `2.0.0`

Build number 由 CI 自动递增(用的是 `github.run_number`),不用手动管。

### 3. 改 changelog(可选但建议)

TestFlight 给测试者看的 "这个 build 改了啥",内部写一下留档:

```bash
# 新建 docs/CHANGELOG.md 或在 GitHub Release 描述里写
```

### 4. 打 tag 推送

```bash
git tag v1.3.0
git push origin v1.3.0
```

就这两行。推完立即去 [Actions 页面](https://github.com/uhyrdtrdtfg-creator/glassbook-ios/actions) 看 Release workflow 跑起来了。

### 5. 等上传完成 (~15 分钟)

- Actions 工作流 ≈ 8 分钟(xcodegen → archive → export → altool 上传)
- altool 上传完 App Store Connect 还要处理 3~10 分钟才出现在 TestFlight

工作流结束后你会收到两封邮件:
1. 来自 Apple: "Glassbook 1.3.0 (build 42) is now ready for testing"
2. 来自 GitHub: Release 已创建

### 6. TestFlight 内部测试

1. <https://appstoreconnect.apple.com/apps> → 选 Glassbook → TestFlight 标签
2. 左侧 "内部测试" 组 → 加上你自己的 Apple ID
3. 手机装 TestFlight app → 用同一 Apple ID 登录 → 看到 build → 点 "安装"
4. **实机跑一遍 golden path:** 记一笔 / Face ID 解锁 / OCR 截屏 / 看订阅
5. 有问题 → 修 → 发 patch 版本(`v1.3.1`)

### 7. 提交正式审核

TestFlight 验证没问题后:

1. App Store Connect → Glassbook → "App Store" 标签 → 左侧 "+ 版本或平台" → iOS
2. 新版本号填 `1.3.0`(和 tag 一致)
3. 填写:
   - 此版本新增内容(2~4 句话,用户看得懂)
   - 截图(如果 UI 大改了就补,没改沿用上版)
   - 审核备注(如 "演示账号 demo@glassbook.app / 无密码")
4. "可供销售" 里选构建版本 → 挑刚才 TestFlight 上那个 build
5. 右上 "添加以供审核" → "提交以供审核"

### 8. 等审核 (24~48 小时通常)

- 审核结果邮件 + App Store Connect 通知
- 常见被拒原因:
  - 权限描述和实际不符: 检查 [`Glassbook/project.yml:39-41`](../Glassbook/project.yml#L39)
  - 截图有占位文字: 用实机截图而不是 Xcode Preview
  - CloudKit schema 未 deploy 到 Production: 去 CloudKit Dashboard "Deploy to Production"

### 9. 过审 → 发布

审核通过后有两种模式:
- **自动发布**: 过审后 24 小时内上线
- **手动发布**: 你点 "立即发布" 才上线(推荐,可以对齐营销动作)

过审后也可以 **分阶段发布**(7 天从 1% 放到 100%),有大改时更保险。

---

## 三、回滚怎么做

### 情况 1: TestFlight build 有严重 bug
- 不管它,下个版本覆盖就行,TestFlight 测试者拿到新 build 自动替代

### 情况 2: 正式版本发布后发现严重 bug
- **App Store 不能下架旧版让它"回滚"**
- 只能发 hotfix 版本: `1.3.0` → `1.3.1`
- 走加急审核: App Store Connect → Resolution Center → Request Expedited Review(一年只有几次,别滥用)

### 情况 3: CI 失败
- 看 Actions 日志,`TestResults.xcresult` 会作为 artifact 上传,下载后 Xcode 双击能看
- 本地复现: `xcodebuild test -scheme GlassbookCI` 对着干

---

## 四、常见坑

**"Unable to find a device matching ..." 本地跑测试报错**
- 模拟器名字漂移,打开 Xcode → Window → Devices and Simulators 看当前装了啥,改 `-destination` 参数

**altool 上传报 "No suitable application records were found"**
- Bundle ID 和 App Store Connect 里的 App 不一致,核对 [`Glassbook/project.yml:32`](../Glassbook/project.yml#L32)

**CloudKit 本地能同步,TestFlight 装机打不开**
- 忘了把 schema 推到 Production:
  1. CloudKit Dashboard → Schema 标签 → "Deploy Schema Changes"
  2. 确认 Development 和 Production 一致后再 TestFlight 测

**Archive 成功但 Export 失败 "no profiles matching"**
- `.mobileprovision` 里的 App ID 和构建的 Bundle ID 不匹配,重新生成 profile

**证书 1 年后过期**
- 生成新的 Distribution Certificate,重做第一部分的第 4~5 步,更新两个 secret(`APPLE_DEV_CERT_P12`, `APPLE_DEV_CERT_PASSWORD`)

---

## 五、TL;DR 速查

**日常发布**:
```bash
# 本地回归
xcodebuild test -scheme GlassbookCI -destination 'platform=iOS Simulator,name=iPhone 16'

# 发版
git tag v1.3.0 && git push origin v1.3.0

# 然后: 去 TestFlight 装一下 → 过了去 App Store Connect 提审核
```

就这么简单。其他的 CI 替你干了。
