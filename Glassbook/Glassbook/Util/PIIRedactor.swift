import Foundation

/// Spec v2 §12 · 出站到外部 LLM (OpenAI / Claude / Gemini / 自托管) 的文本先过
/// 这一层,把明显的个人敏感信息替换成占位符。云端记账助手必看商户和金额,
/// 但不需要看到银行卡号 / 手机号 / 身份证 / 家庭住址 / 邮箱。
///
/// **脱敏是单向的** — redact(redact(x)) == redact(x),既不会把已经掩码过的
/// 字符串再处理成乱码,也不会丢失信息熵之外的东西。所有 regex 都做了
/// 「边界/长度」约束,命中后生成的占位符本身不会再次触发同一 pattern。
///
/// 只处理「看起来是 PII」的字面量。如果模型需要数字上下文 (金额、日期、
/// 条目号),维持原状 — 合法 4-8 位数字通不过卡号/身份证/手机号 regex。
enum PIIRedactor {

    /// 主入口。按顺序跑所有子 pass,每个 pass 互不依赖。
    /// 顺序经过设计:先处理长数字串 (身份证/卡号),再处理手机号 / 座机,
    /// 最后处理地址 / 邮箱。后面的 pass 不会误伤前面留下的 `*` 填充字符。
    static func redact(_ s: String) -> String {
        var out = s
        out = redactIDCard(out)
        out = redactCardNumber(out)
        out = redactMobile(out)
        out = redactLandline(out)
        out = redactEmail(out)
        out = redactAddress(out)
        return out
    }

    // MARK: - ID 身份证

    /// 18 位身份证 = 17 位数字 + 1 位校验 (数字或 X)。卡号 pattern 也能
    /// 吃掉 18 位纯数字,所以必须先跑 ID pass,避免 20250418 * 2 这种
    /// 拼接被误判。保留前 6 位 (省市区) + 后 4 位,中间 8 位 → `*`。
    /// `(?<!\d)...(?!\d)` 防止在 20 位以上数字串中间挖坑。
    private static let idCardRegex = try! NSRegularExpression(
        pattern: #"(?<!\d)\d{17}[\dXx](?!\d)"#
    )

    private static func redactIDCard(_ s: String) -> String {
        replaceMatches(in: s, regex: idCardRegex) { match in
            let head = match.prefix(6)
            let tail = match.suffix(4)
            return "\(head)********\(tail)"
        }
    }

    // MARK: - Card 银行卡号

    /// 13–19 位纯数字,覆盖 Visa / MasterCard / UnionPay / Amex。
    /// `(?<!\d)...(?!\d)` 锁边界,避免和金额 / 日期数字串黏在一起。
    /// 保留末 4,其余替换成固定 12 个 `*` (长度一致,不泄露原长度线索)。
    private static let cardRegex = try! NSRegularExpression(
        pattern: #"(?<!\d)\d{13,19}(?!\d)"#
    )

    private static func redactCardNumber(_ s: String) -> String {
        replaceMatches(in: s, regex: cardRegex) { match in
            let tail = match.suffix(4)
            return "************\(tail)"
        }
    }

    // MARK: - Mobile 手机号

    /// 国内移动号段:1 开头 + 3-9 + 9 位数字。前 3 保留段前缀,后 2 保留尾号,
    /// 中间 6 位 → `*`。同样用 `(?<!\d)...(?!\d)` 防黏连 (避免被前置的卡号
    /// pass 漏掉的残骸再匹配一次)。
    private static let mobileRegex = try! NSRegularExpression(
        pattern: #"(?<!\d)1[3-9]\d{9}(?!\d)"#
    )

    private static func redactMobile(_ s: String) -> String {
        replaceMatches(in: s, regex: mobileRegex) { match in
            let head = match.prefix(3)
            let tail = match.suffix(2)
            return "\(head)******\(tail)"
        }
    }

    // MARK: - Landline 座机

    /// 国内座机 `010-12345678` / `0755-1234567` 形式。区号 3-4 位 + `-` +
    /// 号码 7-8 位。保留区号 + 后 2,其余遮掉。少见但收据上偶尔出现。
    private static let landlineRegex = try! NSRegularExpression(
        pattern: #"(?<!\d)0\d{2,3}-\d{7,8}(?!\d)"#
    )

    private static func redactLandline(_ s: String) -> String {
        replaceMatches(in: s, regex: landlineRegex) { match in
            guard let dash = match.firstIndex(of: "-") else { return match }
            let area = match[..<dash]
            let tail = match.suffix(2)
            return "\(area)-****\(tail)"
        }
    }

    // MARK: - Email 邮箱

    /// 标准 RFC-ish 邮箱。只留用户名首字符 + `***@` + 域名 — 域名通常是
    /// 公开信息 (gmail.com / qq.com),但用户名可能是真名拼音或工号。
    private static let emailRegex = try! NSRegularExpression(
        pattern: #"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#
    )

    private static func redactEmail(_ s: String) -> String {
        replaceMatches(in: s, regex: emailRegex) { match in
            guard let at = match.firstIndex(of: "@") else { return match }
            let user = match[..<at]
            let domain = match[match.index(after: at)...]
            guard let firstChar = user.first else { return match }
            return "\(firstChar)***@\(domain)"
        }
    }

    // MARK: - Address 物理地址

    /// 「省 + 市 + 区/县」三段式完整中式地址,后面拖着街道/路/号/巷/弄明细。
    /// 拆成 3 个 capture group 保留行政区,详细地址 (可能含门牌号 = 个人线索)
    /// 一律 `***`。不带「省/自治区」前缀的城市 (北京/上海/重庆/天津) 单独处理。
    ///
    /// 注意:`一-鿿` 是 CJK 统一表意字符区,不会匹配到 `*`,所以重跑幂等。
    private static let fullAddressRegex = try! NSRegularExpression(
        pattern: #"([一-鿿]{2,8})(省|自治区)([一-鿿]{2,8})(市|自治州)([一-鿿]{2,8})(区|县|市|自治县)[一-鿿0-9A-Za-z\-号街路巷弄街道社区村镇]{2,40}"#
    )

    /// 直辖市开头 (北京市/上海市/重庆市/天津市) + 区县 + 明细。跟上面互斥 —
    /// 先跑完整版再跑这个,后者命中的是前者匹配不到的剩余内容。
    private static let municipalityAddressRegex = try! NSRegularExpression(
        pattern: #"(北京|上海|重庆|天津)市([一-鿿]{2,8})(区|县)[一-鿿0-9A-Za-z\-号街路巷弄街道社区村镇]{2,40}"#
    )

    private static func redactAddress(_ s: String) -> String {
        var out = replaceMatches(in: s, regex: fullAddressRegex) { match in
            // 拿 6 个 capture group 拼回「省市区」骨架,其余 `***`。
            // 这里用 NSRegularExpression 重跑一次以拿 groups — closure 拿到的
            // 是整段匹配,groups 要单独算。
            let nsMatch = match as NSString
            let range = NSRange(location: 0, length: nsMatch.length)
            guard let m = fullAddressRegex.firstMatch(in: match, range: range),
                  m.numberOfRanges >= 7 else {
                return match
            }
            func g(_ i: Int) -> String { nsMatch.substring(with: m.range(at: i)) }
            return "\(g(1))\(g(2))\(g(3))\(g(4))\(g(5))\(g(6))***"
        }
        out = replaceMatches(in: out, regex: municipalityAddressRegex) { match in
            let nsMatch = match as NSString
            let range = NSRange(location: 0, length: nsMatch.length)
            guard let m = municipalityAddressRegex.firstMatch(in: match, range: range),
                  m.numberOfRanges >= 4 else {
                return match
            }
            func g(_ i: Int) -> String { nsMatch.substring(with: m.range(at: i)) }
            return "\(g(1))市\(g(2))\(g(3))***"
        }
        return out
    }

    // MARK: - 内部工具

    /// 从尾部向头部遍历 match (保证替换不破坏前面 match 的 NSRange offset),
    /// 每个 match 交给 `transform` 决定新字符串。
    private static func replaceMatches(
        in s: String,
        regex: NSRegularExpression,
        transform: (String) -> String
    ) -> String {
        let ns = s as NSString
        let full = NSRange(location: 0, length: ns.length)
        let matches = regex.matches(in: s, range: full)
        guard !matches.isEmpty else { return s }
        var out = ns as String
        for m in matches.reversed() {
            let range = m.range
            guard range.location != NSNotFound else { continue }
            let hit = (out as NSString).substring(with: range)
            let replaced = transform(hit)
            out = (out as NSString).replacingCharacters(in: range, with: replaced)
        }
        return out
    }

    // MARK: - Examples (idempotent by construction)
    //
    // 原文 → redact 结果 → 再 redact 结果
    //
    // "卡号 6222023456789012"            → "卡号 ************9012"            → "卡号 ************9012"
    // "电话 13812345678"                  → "电话 138******78"                 → "电话 138******78"
    // "身份证 440301199001011234"         → "身份证 440301********1234"        → "身份证 440301********1234"
    // "邮箱 roger@example.com"            → "邮箱 r***@example.com"            → "邮箱 r***@example.com"
    // "广东省深圳市南山区科技园路 22 号"  → "广东省深圳市南山区***"            → "广东省深圳市南山区***"
    // "北京市海淀区中关村大街 1 号"       → "北京市海淀区***"                  → "北京市海淀区***"
    // "座机 0755-12345678"                → "0755-****78"                       → "0755-****78"
}
