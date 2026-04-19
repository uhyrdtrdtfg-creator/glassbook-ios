import Testing
import Foundation
@testable import Glassbook

// Measures end-to-end recall/precision of the platform parsers on the
// curated fake bills. These are NOT a statement about real-world bill
// accuracy — only a repeatable baseline that fails loudly if the regex
// stops matching something it used to.

@Suite("Parser accuracy · fake bills")
struct ParserAccuracyTests {

    @Test func alipayRecallOnFakeBill() {
        // Ground truth: 5 planted transactions in VisionOCRService.fakeAlipayBill().
        let expected: [(merchant: String, cents: Int)] = [
            ("美团外卖",       3_890),
            ("滴滴出行",       2_650),
            ("淘宝 · 家居用品", 14_900),
            ("星巴克",         3_800),
            ("Apple 订阅",     2_800),
        ]
        let parsed = AlipayParser().parse(lines: VisionOCRService.fakeAlipayBill())
        let matched = expected.filter { exp in
            parsed.contains { $0.merchant.contains(exp.merchant) && $0.amountCents == exp.cents }
        }.count
        let recall = Double(matched) / Double(expected.count)
        print("📊 AlipayParser recall: \(matched)/\(expected.count) = \(Int(recall*100))%")
        #expect(recall >= 0.80, "Alipay recall regressed: \(recall)")
    }

    @Test func wechatRecallOnFakeBill() {
        let expected: [(merchant: String, cents: Int)] = [
            ("楼下包子铺", 850),
            ("盒马鲜生",   8_640),
            ("滴滴快车",   1_420),
        ]
        let parsed = WeChatParser().parse(lines: VisionOCRService.fakeWeChatBill())
        let matched = expected.filter { exp in
            parsed.contains { $0.merchant.contains(exp.merchant) && $0.amountCents == exp.cents }
        }.count
        let recall = Double(matched) / Double(expected.count)
        print("📊 WeChatParser recall: \(matched)/\(expected.count) = \(Int(recall*100))%")
        #expect(recall >= 0.66, "WeChat recall regressed: \(recall)")
    }

    @Test func cmbRecallOnFakeBill() {
        let expected: [(merchant: String, cents: Int)] = [
            ("京东商城", 299_900),
            ("还款",     125_000),   // income
            ("美团酒店", 68_000),
        ]
        let parsed = CMBParser().parse(lines: VisionOCRService.fakeCMBBill())
        print("📊 CMB parsed rows: \(parsed.count)")
        for r in parsed {
            print("   → merchant=\"\(r.merchant)\" cents=\(r.amountCents)")
        }
        let matched = expected.filter { exp in
            parsed.contains { $0.merchant.contains(exp.merchant) && $0.amountCents == exp.cents }
        }.count
        let recall = Double(matched) / Double(expected.count)
        print("📊 CMBParser recall: \(matched)/\(expected.count) = \(Int(recall*100))%")
        #expect(recall >= 0.66, "CMB recall regressed: \(recall)")
    }

    @Test func combinedRecall() {
        let all: [(parser: any PlatformParser, lines: [String], expected: Int)] = [
            (AlipayParser(), VisionOCRService.fakeAlipayBill(), 5),
            (WeChatParser(), VisionOCRService.fakeWeChatBill(), 3),
            (CMBParser(),    VisionOCRService.fakeCMBBill(),    3),
        ]
        var totalExpected = 0, totalRecovered = 0
        for case let (parser, lines, expected) in all {
            let parsed = parser.parse(lines: lines)
            totalExpected += expected
            totalRecovered += parsed.count
        }
        let recall = Double(totalRecovered) / Double(totalExpected)
        print("📊 Combined parser recall: \(totalRecovered)/\(totalExpected) = \(Int(recall*100))%")
        #expect(recall >= 0.80, "Combined recall below 80%: \(recall)")
    }
}
