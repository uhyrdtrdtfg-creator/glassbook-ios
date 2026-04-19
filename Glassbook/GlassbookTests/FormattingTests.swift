import Testing
import Foundation
@testable import Glassbook

@Suite("Money.yuan") struct MoneyYuanTests {
    @Test func zeroCents() {
        #expect(Money.yuan(0, showDecimals: false) == "¥0")
        #expect(Money.yuan(0, showDecimals: true)  == "¥0.00")
    }
    @Test func wholeYuan() {
        #expect(Money.yuan(12_300, showDecimals: false) == "¥123")
        #expect(Money.yuan(12_300, showDecimals: true)  == "¥123.00")
    }
    @Test func fractional() {
        #expect(Money.yuan(12_345, showDecimals: true)  == "¥123.45")
        #expect(Money.yuan(12_345, showDecimals: false) == "¥123")
    }
    @Test func groupingForLargeAmounts() {
        #expect(Money.yuan(12_345_678, showDecimals: true).contains("123,456.78"))
    }
    @Test func negativeWithoutSignShowsMinus() {
        #expect(Money.yuan(-5_000, showDecimals: false) == "-¥50")
    }
    @Test func showSignFlagPositive() {
        #expect(Money.yuan(5_000, showDecimals: false, showSign: true) == "+¥50")
    }
    @Test func showSignFlagZero() {
        #expect(Money.yuan(0, showDecimals: false, showSign: true) == "¥0")
    }
    @Test func showSignFlagNegative() {
        #expect(Money.yuan(-5_000, showDecimals: false, showSign: true) == "-¥50")
    }
    @Test func singleDigitFen() {
        #expect(Money.yuan(101, showDecimals: true) == "¥1.01")
    }
}

@Suite("Money.dual") struct MoneyDualTests {
    @Test func cnyCurrencyReturnsCnyOnly() {
        #expect(Money.dual(cnyCents: 12_300, originalCents: 12_300, currency: .cny) == "¥123")
    }
    @Test func nilOriginalReturnsCnyOnly() {
        #expect(Money.dual(cnyCents: 5_000, originalCents: nil, currency: .usd) == "¥50")
    }
    @Test func foreignShowsDual() {
        let s = Money.dual(cnyCents: 12_480, originalCents: 1_720, currency: .usd)
        #expect(s == "¥124 · $17")
    }
    @Test func foreignWithDecimals() {
        let s = Money.dual(cnyCents: 12_480, originalCents: 1_720, currency: .usd, showDecimals: true)
        #expect(s.contains("·"))
        #expect(s.contains("$17.20"))
    }
}

@Suite("Currency enum") struct CurrencyEnumTests {
    @Test func symbolsPresent() {
        for c in Currency.allCases {
            #expect(!c.symbol.isEmpty, "\(c) missing symbol")
            #expect(!c.code.isEmpty, "\(c) missing code")
        }
    }
    @Test func codeIsUppercase() {
        #expect(Currency.usd.code == "USD")
        #expect(Currency.cny.code == "CNY")
    }
}
