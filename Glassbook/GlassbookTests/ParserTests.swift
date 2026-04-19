import Testing
import Foundation
@testable import Glassbook

@Suite("ParserKit.amount") struct ParserKitAmountTests {
    @Test func basicYuanValue() {
        let r = ParserKit.extractAmountCents(from: "¥28.50")
        #expect(r?.cents == 2_850)
    }
    @Test func negativeSign() {
        let r = ParserKit.extractAmountCents(from: "-¥100", assumeExpense: true)
        #expect(r?.cents == 10_000)
        #expect(r?.isIncome == false)
    }
    @Test func positiveSignIsIncome() {
        let r = ParserKit.extractAmountCents(from: "+¥50.00")
        #expect(r?.cents == 5_000)
        #expect(r?.isIncome == true)
    }
    @Test func commaGroupingStripped() {
        let r = ParserKit.extractAmountCents(from: "1,234.56")
        #expect(r?.cents == 123_456)
    }
    @Test func keywordRefundAsIncome() {
        let r = ParserKit.extractAmountCents(from: "退款 50.00", assumeExpense: true)
        #expect(r?.isIncome == true)
    }
    @Test func keywordIncomeAsIncome() {
        let r = ParserKit.extractAmountCents(from: "工资 8800")
        #expect(r?.isIncome == true)
    }
    @Test func zeroReturnsNil() {
        #expect(ParserKit.extractAmountCents(from: "0") == nil)
    }
    @Test func noDigitsReturnsNil() {
        #expect(ParserKit.extractAmountCents(from: "abc") == nil)
    }
    @Test func spaceBetweenSignAndNumber() {
        let r = ParserKit.extractAmountCents(from: "- 38.90")
        #expect(r?.cents == 3_890)
    }
    @Test func oneFen() {
        let r = ParserKit.extractAmountCents(from: "1.01")
        #expect(r?.cents == 101)
    }
}

@Suite("ParserKit.date") struct ParserKitDateTests {
    @Test func isoFormatFullTime() {
        let d = ParserKit.extractDate(from: "2026-04-18 20:45:00", defaultYear: 2026)
        #expect(d != nil)
        let c = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: d!)
        #expect(c.year == 2026); #expect(c.month == 4); #expect(c.day == 18)
        #expect(c.hour == 20); #expect(c.minute == 45)
    }
    @Test func shortFormatUsesDefaultYear() {
        let d = ParserKit.extractDate(from: "04-19 08:12", defaultYear: 2026)
        #expect(d != nil)
        let c = Calendar.current.dateComponents([.year, .month], from: d!)
        #expect(c.year == 2026)
        #expect(c.month == 4)
    }
    @Test func slashSeparator() {
        let d = ParserKit.extractDate(from: "2026/04/18 12:00", defaultYear: 2026)
        #expect(d != nil)
    }
    @Test func garbageReturnsNil() {
        #expect(ParserKit.extractDate(from: "no date here", defaultYear: 2026) == nil)
    }
}

@Suite("AlipayParser") struct AlipayParserTests {
    let parser = AlipayParser()
    @Test func canParseDetectsPlatform() {
        #expect(parser.canParse(lines: ["支付宝", "账单"]))
        #expect(parser.canParse(lines: ["Alipay", "payment"]))
        #expect(!parser.canParse(lines: ["微信支付"]))
    }
    @Test func parsesFakeBill() {
        let rows = parser.parse(lines: VisionOCRService.fakeAlipayBill())
        #expect(rows.count >= 3, "got \(rows.count)")
        #expect(rows.contains { $0.merchant.contains("美团") })
        #expect(rows.allSatisfy { $0.source == .alipay })
    }
    @Test func classifiesKnownMerchants() {
        let rows = parser.parse(lines: VisionOCRService.fakeAlipayBill())
        if let r = rows.first(where: { $0.merchant.contains("美团") }) {
            #expect(r.categoryID == .food)
        }
    }
    @Test func skipsPlatformNoise() {
        // "支付宝" and "账单" lines shouldn't turn into rows.
        let rows = parser.parse(lines: ["支付宝", "账单", "—"])
        #expect(rows.isEmpty)
    }
}

@Suite("WeChatParser") struct WeChatParserTests {
    let parser = WeChatParser()
    @Test func canParseDetectsPlatform() {
        #expect(parser.canParse(lines: ["微信支付"]))
        #expect(parser.canParse(lines: ["WeChat Pay"]))
        #expect(parser.canParse(lines: ["零钱"]))
        #expect(!parser.canParse(lines: ["支付宝"]))
    }
    @Test func parsesFakeBill() {
        let rows = parser.parse(lines: VisionOCRService.fakeWeChatBill())
        #expect(!rows.isEmpty)
        #expect(rows.allSatisfy { $0.source == .wechat })
    }
}

@Suite("CMBParser") struct CMBParserTests {
    let parser = CMBParser()
    @Test func canParseDetectsPlatform() {
        #expect(parser.canParse(lines: ["招商银行"]))
        #expect(parser.canParse(lines: ["收支明细"]))
        #expect(parser.canParse(lines: ["CMB"]))
        #expect(parser.canParse(lines: ["信用卡账单"]))
        #expect(!parser.canParse(lines: ["支付宝"]))
    }
    @Test func parsesFakeBill() {
        let rows = parser.parse(lines: VisionOCRService.fakeCMBBill())
        #expect(rows.count >= 2)
        #expect(rows.allSatisfy { $0.source == .cmb })
    }
}

@Suite("ParserRegistry") struct ParserRegistryTests {
    @Test func hasThreeParsers() { #expect(ParserRegistry.all.count == 3) }
    @Test func picksAlipayForAlipayLines() {
        #expect(ParserRegistry.pick(for: ["支付宝"]).platform == .alipay)
    }
    @Test func picksWeChatForWechatLines() {
        #expect(ParserRegistry.pick(for: ["微信支付"]).platform == .wechat)
    }
    @Test func picksCMBForCMBLines() {
        #expect(ParserRegistry.pick(for: ["招商银行"]).platform == .cmb)
    }
    @Test func fallsBackToAlipayForUnknown() {
        #expect(ParserRegistry.pick(for: ["random"]).platform == .alipay)
    }
}
