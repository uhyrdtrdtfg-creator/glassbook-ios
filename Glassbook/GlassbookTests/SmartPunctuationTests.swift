import Testing
@testable import Glassbook

/// Regression guard: a curly quote in a webhook template used to ship as
/// U+201C/201D which is not a valid JSON string delimiter. Any future change
/// that drops the normalization step should flip these tests red.
@Suite("SmartPunctuation · normalizer")
struct SmartPunctuationTests {

    @Test func curlyDoubleQuotesBecomeStraight() {
        let curly = "{\u{201C}text\u{201D}: \u{201C}hi\u{201D}}"
        #expect(curly.normalizingSmartPunctuation() == "{\"text\": \"hi\"}")
    }

    @Test func curlySingleQuotesBecomeApostrophe() {
        // U+2018 left + U+2019 right → both map to '.
        let s = "it\u{2019}s \u{2018}quoted\u{2019}"
        #expect(s.normalizingSmartPunctuation() == "it's 'quoted'")
    }

    @Test func enAndEmDashesBecomeHyphen() {
        #expect("alpha\u{2013}beta".normalizingSmartPunctuation() == "alpha-beta")
        #expect("gamma\u{2014}delta".normalizingSmartPunctuation() == "gamma-delta")
    }

    @Test func ellipsisExpandsToThreeDots() {
        #expect("wait\u{2026}ok".normalizingSmartPunctuation() == "wait...ok")
    }

    @Test func nonBreakingSpaceCollapsesToSpace() {
        // NBSP (U+00A0) in URLs breaks curl / URLSession; must become a
        // regular space so caller can trim or the URL parser can flag it.
        #expect("https://api.example.com/v1\u{00A0}endpoint"
            .normalizingSmartPunctuation() == "https://api.example.com/v1 endpoint")
    }

    @Test func alreadyStraightTextIsUnchanged() {
        let plain = "{\"name\": \"Slack\", \"enabled\": true}"
        #expect(plain.normalizingSmartPunctuation() == plain)
    }

    @Test func emptyStringReturnsEmpty() {
        #expect("".normalizingSmartPunctuation() == "")
    }
}
