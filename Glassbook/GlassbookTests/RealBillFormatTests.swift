import Testing
import Foundation
@testable import Glassbook

// Real-world bill formats transcribed from user screenshots (2026-04-19).
// Vision OCR returns observations sorted top-to-bottom by bounding box midY,
// so two-column rows emit as `leftText, rightText` interleaved.
//
// Screenshot source:  Alipay / WeChat Pay / CMB monthly bill lists.
// Purpose: regression gate that forces the regex parsers to handle the line
// order real users actually see, not just our curated fakes.

@Suite("Real bill formats (transcribed from screenshots)")
struct RealBillFormatTests {

    // MARK: - Alipay (支付宝)
    //
    // Layout per row:
    //   [icon] <merchant>          <amount>
    //          <category>
    //          <date>
    // Vision emit order (same Y first, then descending):
    //   merchant, amount, category, date

    static let alipayLines: [String] = [
        "21:19", "37",
        "搜索交易记录", "搜索",
        "全部", "支出", "转账", "退款", "订单", "筛选",
        "4月", "贴纸新功能",
        "支出", "¥ 2,870.98", "收入", "¥ 150.00",
        "复盘本周收支", "设置支出预算", "收支分析",
        // 1
        "Gomoney秒速【入奶】尼区全平台...", "-1,036.00",
        "日用百货", "今天 16:21",
        // 2
        "Gomoney秒速【入奶】尼区全平台 | ...", "-500.00",
        "日用百货", "今天 15:45",
        // 3
        "小宝的零花钱-转入", "-10.00",
        "转账红包", "昨天 17:03",
        // 4
        "余额宝-收益发放", "0.01",
        "投资理财", "昨天 05:01",
        // 5
        "余额宝-收益发放", "0.01",
        "投资理财", "04-17 05:14",
        // 6
        "余额宝-收益发放", "0.01",
    ]

    static let alipayExpected: [(merchant: String, cents: Int)] = [
        ("Gomoney", 103_600),
        ("Gomoney", 50_000),
        ("小宝的零花钱", 1_000),
        ("余额宝", 1),
        ("余额宝", 1),
        ("余额宝", 1),
    ]

    @Test func alipayRealRecall() {
        let parsed = AlipayParser().parse(lines: Self.alipayLines)
        print("📊 Alipay REAL parsed \(parsed.count) rows:")
        for r in parsed { print("   → \(r.merchant) / \(r.amountCents)") }
        let matched = Self.matches(parsed: parsed, expected: Self.alipayExpected)
        let recall = Double(matched) / Double(Self.alipayExpected.count)
        print("📊 Alipay REAL recall: \(matched)/\(Self.alipayExpected.count) = \(Int(recall*100))%")
        // We set a low bar here — this test documents real-bill accuracy over time
        // rather than block commits. Ratchet up as the parser improves.
        #expect(recall >= 0.5, "Alipay real recall regressed: \(recall)")
    }

    // MARK: - WeChat Pay (微信支付)
    //
    // Layout per row:
    //   [icon] <merchant>                    <amount>
    //          <date>
    // Vision emit order:  merchant, amount, date

    static let wechatLines: [String] = [
        "21:19", "37",
        "账单",
        "全部账单", "查找交易", "收支统计",
        "2026年4月", "支出¥5197.04", "收入¥60.00",
        "名创优品",                  "-17.66",  "4月19日 19:13",
        "扫二维码付款-给娜姐~",       "-9.00",   "4月19日 18:25",
        "扫二维码付款-给娜姐~",       "-19.00",  "4月19日 12:31",
        "大生优品生活超市",           "-3.00",   "4月19日 09:18",
        "津品汤包半里花海店",         "-2.00",   "4月19日 09:09",
        "熊大爷",                    "-18.00",  "4月18日 19:44",
        "熊大爷",                    "-3.00",   "4月18日 19:41",
        "熊大爷",                    "-34.00",  "4月18日 19:38",
        "广东 ELEVEN 7",             "-5.90",   "4月18日 12:27",
    ]

    static let wechatExpected: [(merchant: String, cents: Int)] = [
        ("名创优品", 1_766),
        ("扫二维码付款", 900),
        ("扫二维码付款", 1_900),
        ("大生优品生活超市", 300),
        ("津品汤包半里花海店", 200),
        ("熊大爷", 1_800),
        ("熊大爷", 300),
        ("熊大爷", 3_400),
        ("ELEVEN", 590),
    ]

    @Test func wechatRealRecall() {
        let parsed = WeChatParser().parse(lines: Self.wechatLines)
        print("📊 WeChat REAL parsed \(parsed.count) rows:")
        for r in parsed { print("   → \(r.merchant) / \(r.amountCents)") }
        let matched = Self.matches(parsed: parsed, expected: Self.wechatExpected)
        let recall = Double(matched) / Double(Self.wechatExpected.count)
        print("📊 WeChat REAL recall: \(matched)/\(Self.wechatExpected.count) = \(Int(recall*100))%")
        #expect(recall >= 0.5, "WeChat real recall regressed: \(recall)")
    }

    // MARK: - CMB (招商银行)
    //
    // Layout per row:
    //   [icon] <merchant>                  <status-chip> <amount>
    //          <card-label> <time>        <balance (优选储蓄卡才有)>
    // Vision emit order varies: leaf tags like 未入账 can sit right next to amount.
    // Simplified here as: merchant, <maybe chip>, amount, card+time

    static let cmbLines: [String] = [
        "21:20", "36",
        "收支",
        "2026.04", "银行卡", "按金额", "筛选",
        "昨天",
        "711便利店", "未入账", "-¥5.90", "信用卡1440 12:27",
        "711便利店", "未入账", "-¥10.00", "信用卡1440 12:26",
        "711便利店", "未入账", "-¥29.50", "信用卡1440 08:40",
        "4.17",
        "深圳市樱川餐饮有限公司", "-¥17.00", "信用卡1440 17:45",
        "深圳市樱川餐饮有限公司", "-¥17.00", "信用卡1440 11:33",
        "深圳市水务（集团）有限公司", "-¥16.00", "储蓄卡1756 10:31", "余额:¥192,653.32",
        "深圳市水务（集团）有限公司", "-¥42.72", "储蓄卡1756 10:15", "余额:¥192,669.32",
        "深圳市水务（集团）有限公司", "-¥8.26", "储蓄卡1756 10:14", "余额:¥192,712.04",
        "深圳市樱川餐饮有限公司", "-¥6.00", "信用卡1440 08:19",
        "4.16",
    ]

    static let cmbExpected: [(merchant: String, cents: Int)] = [
        ("711便利店", 590),
        ("711便利店", 1_000),
        ("711便利店", 2_950),
        ("樱川", 1_700),
        ("樱川", 1_700),
        ("水务", 1_600),
        ("水务", 4_272),
        ("水务", 826),
        ("樱川", 600),
    ]

    @Test func cmbRealRecall() {
        let parsed = CMBParser().parse(lines: Self.cmbLines)
        print("📊 CMB REAL parsed \(parsed.count) rows:")
        for r in parsed { print("   → \(r.merchant) / \(r.amountCents)") }
        let matched = Self.matches(parsed: parsed, expected: Self.cmbExpected)
        let recall = Double(matched) / Double(Self.cmbExpected.count)
        print("📊 CMB REAL recall: \(matched)/\(Self.cmbExpected.count) = \(Int(recall*100))%")
        #expect(recall >= 1.0, "CMB real recall regressed: \(recall)")
    }

    // MARK: - CMB screenshot #2 (user submitted 2026-04-20)
    //
    // Second real CMB screenshot with a denser "钱大妈" run, a "4.11" day
    // header mid-list, and a partial row clipped at the top. Nine full rows
    // should parse cleanly; the clipped top row is intentionally NOT in the
    // expected list since its merchant isn't visible.

    static let cmbLines2: [String] = [
        "21:59",
        "收支",
        "2026.04", "银行卡", "按金额", "筛选",
        "信用卡1440 14:18",                                    // clipped top row
        "钱大妈",           "-¥2.59",  "信用卡1440 09:45",
        "钱大妈",           "-¥3.98",  "信用卡1440 09:44",
        "钱大妈",           "-¥22.26", "信用卡1440 09:43",
        "钱大妈",           "-¥45.34", "信用卡1440 08:17",
        "津品汤包半里花海店", "-¥11.00", "信用卡1440 08:13",
        "大生优品生活超市",   "-¥82.04", "信用卡1440 08:10",
        "肯德基",           "-¥6.00",  "信用卡1440 08:06",
        "4.11",
        "美团平台商户",      "-¥65.00", "信用卡1440 21:28",
        "湾仔阿婆牛杂创维店", "-¥26.80", "信用卡1440 18:08",
        "上拉加载更多数据",
        "明细", "账本",
    ]

    static let cmbExpected2: [(merchant: String, cents: Int)] = [
        ("钱大妈", 259),
        ("钱大妈", 398),
        ("钱大妈", 2_226),
        ("钱大妈", 4_534),
        ("津品汤包半里花海店", 1_100),
        ("大生优品生活超市", 8_204),
        ("肯德基", 600),
        ("美团平台商户", 6_500),
        ("湾仔阿婆牛杂创维店", 2_680),
    ]

    @Test func cmbRealRecall2() {
        let parsed = CMBParser().parse(lines: Self.cmbLines2)
        print("📊 CMB REAL #2 parsed \(parsed.count) rows:")
        for r in parsed { print("   → \(r.merchant) / \(r.amountCents)") }
        let matched = Self.matches(parsed: parsed, expected: Self.cmbExpected2)
        let recall = Double(matched) / Double(Self.cmbExpected2.count)
        print("📊 CMB REAL #2 recall: \(matched)/\(Self.cmbExpected2.count) = \(Int(recall*100))%")
        #expect(recall >= 1.0, "CMB real #2 recall regressed: \(recall)")
    }

    // MARK: - CMB screenshot #3 (user submitted 2026-04-22)
    //
    // Vision sometimes picks up CMB's left-column category icons (🛍/🍴/🎤) as
    // single CJK characters that look like boxes — 日, 口, 田, 目. They land
    // either as a standalone line ABOVE the merchant, or fused onto the front
    // of the merchant name ("日深圳宜家家居有限公司"). The fixture below
    // exercises both cases and expects clean output.

    static let cmbLines3: [String] = [
        "21:55",
        "收支",
        "2026.04", "银行卡", "按金额", "筛选",
        "4.12",
        // icon + merchant on same row, fused into one line
        "日深圳宜家家居有限公司",   "-¥5.00",    "信用卡1440 20:20",
        // icon as standalone line ABOVE merchant
        "口",  "宜家家居",           "-¥39.99",   "信用卡1440 20:07",
        "日深圳宜家家居有限公司",   "-¥9.99",    "信用卡1440 18:34",
        "日深圳宜家家居有限公司",   "-¥292.85",  "信用卡1440 18:29",
        "口",  "深圳市香遇含忆餐饮管理有限公司", "-¥36.00", "信用卡1440 16:37",
        "田",  "深圳世界之窗有限公司", "-¥12.00", "信用卡1440 16:08",
        "口",  "滑冰场咖啡厅",       "-¥10.00",   "信用卡1440 15:49",
        "口",  "滑冰场咖啡厅",       "-¥30.00",   "信用卡1440 15:47",
        "口",  "滑冰场咖啡厅",       "-¥10.00",   "信用卡1440 15:43",
        "口",  "深圳市兜点实业有限责任公司", "-¥24.10", "信用卡1440 14:18",
        "口",  "钱大妈",             "-¥2.59",    "信用卡1440 09:45",
    ]

    static let cmbExpected3: [(merchant: String, cents: Int)] = [
        ("深圳宜家家居有限公司", 500),
        ("宜家家居", 3_999),
        ("深圳宜家家居有限公司", 999),
        ("深圳宜家家居有限公司", 29_285),
        ("深圳市香遇含忆餐饮管理有限公司", 3_600),
        ("深圳世界之窗有限公司", 1_200),
        ("滑冰场咖啡厅", 1_000),
        ("滑冰场咖啡厅", 3_000),
        ("滑冰场咖啡厅", 1_000),
        ("深圳市兜点实业有限责任公司", 2_410),
        ("钱大妈", 259),
    ]

    @Test func cmbRealRecall3() {
        let parsed = CMBParser().parse(lines: Self.cmbLines3)
        print("📊 CMB REAL #3 parsed \(parsed.count) rows:")
        for r in parsed { print("   → \(r.merchant) / \(r.amountCents)") }
        let matched = Self.matches(parsed: parsed, expected: Self.cmbExpected3)
        let recall = Double(matched) / Double(Self.cmbExpected3.count)
        print("📊 CMB REAL #3 recall: \(matched)/\(Self.cmbExpected3.count) = \(Int(recall*100))%")
        // No merchant should start with 日/口/田/目 — those were icon artifacts.
        for row in parsed {
            #expect(!["日","口","田","目"].contains(String(row.merchant.prefix(1))),
                    "Icon glyph leaked into merchant: \(row.merchant)")
        }
        #expect(recall >= 0.9, "CMB real #3 recall regressed: \(recall)")
    }

    // MARK: - Cross-platform dedup (user report, 2026-04-19)
    //
    // Scenario: 7-Eleven purchase — WeChat Pay sees "广东 ELEVEN 7" at 12:27,
    // the linked CMB credit card sees "711便利店" at 12:27, both -¥5.90.
    // My original DedupEngine required merchant substring match, so these
    // didn't collapse. After adding a cross-platform rule (same amount +
    // same minute + different source) they should mark as duplicates.

    @Test func crossPlatformDedupSevenEleven() {
        let now = Date(timeIntervalSince1970: 1_900_000_000)
        let existing = [
            Transaction(id: UUID(), kind: .expense, amountCents: 590,
                        categoryID: .food, accountID: UUID(), timestamp: now,
                        merchant: "广东 ELEVEN 7", note: nil, source: .wechat)
        ]
        let incoming = PendingImportRow(
            id: UUID(), merchant: "711便利店",
            amountCents: 590, categoryID: .food,
            timestamp: now.addingTimeInterval(30),  // 30s later
            source: .cmb, isDuplicate: false, isSelected: true, note: nil
        )
        #expect(DedupEngine.isDuplicate(incoming, against: existing),
                "Same minute + same amount + different source should dedup")
    }

    @Test func crossPlatformDedupMarkDeselects() {
        let now = Date(timeIntervalSince1970: 1_900_000_000)
        let existing = [
            Transaction(id: UUID(), kind: .expense, amountCents: 590,
                        categoryID: .food, accountID: UUID(), timestamp: now,
                        merchant: "广东 ELEVEN 7", note: nil, source: .wechat)
        ]
        let rows = [
            PendingImportRow(id: UUID(), merchant: "711便利店", amountCents: 590,
                             categoryID: .food, timestamp: now.addingTimeInterval(30),
                             source: .cmb, isDuplicate: false, isSelected: true, note: nil),
            PendingImportRow(id: UUID(), merchant: "其他商家", amountCents: 1_000,
                             categoryID: .food, timestamp: now,
                             source: .cmb, isDuplicate: false, isSelected: true, note: nil),
        ]
        let marked = DedupEngine.markDuplicates(rows, against: existing)
        #expect(marked[0].isDuplicate, "7-Eleven row should be flagged")
        #expect(!marked[0].isSelected, "Dup row should be auto-deselected")
        #expect(!marked[1].isDuplicate, "Non-dup row should stay selected")
    }

    // MARK: - Combined report

    @Test func combinedRealRecall() {
        let aliParsed = AlipayParser().parse(lines: Self.alipayLines)
        let wcParsed = WeChatParser().parse(lines: Self.wechatLines)
        let cmbParsed = CMBParser().parse(lines: Self.cmbLines)
        let aliMatched = Self.matches(parsed: aliParsed, expected: Self.alipayExpected)
        let wcMatched = Self.matches(parsed: wcParsed, expected: Self.wechatExpected)
        let cmbMatched = Self.matches(parsed: cmbParsed, expected: Self.cmbExpected)
        let totalExpected = Self.alipayExpected.count + Self.wechatExpected.count + Self.cmbExpected.count
        let totalMatched = aliMatched + wcMatched + cmbMatched
        let recall = Double(totalMatched) / Double(totalExpected)
        print("📊 Combined REAL recall: \(totalMatched)/\(totalExpected) = \(Int(recall*100))%")
    }

    // MARK: - Helpers

    private static func matches(parsed: [PendingImportRow],
                                expected: [(merchant: String, cents: Int)]) -> Int {
        var remaining = parsed
        var count = 0
        for exp in expected {
            if let idx = remaining.firstIndex(where: {
                $0.merchant.contains(exp.merchant) && $0.amountCents == exp.cents
            }) {
                remaining.remove(at: idx)
                count += 1
            }
        }
        return count
    }
}
