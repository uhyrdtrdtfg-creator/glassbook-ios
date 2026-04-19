import SwiftUI

/// Typography scale mirrors the spec (7.2).
/// iOS SF Pro Display is supplied via .system; PingFang SC is the default CJK substitute.
enum AppFont {
    /// 44pt / weight 200 · Hero number
    static let display = Font.system(size: 44, weight: .ultraLight, design: .default)

    /// 32pt / 300 · H1 page title
    static let h1 = Font.system(size: 32, weight: .light, design: .default)

    /// 20pt / 400 · Section title
    static let h2 = Font.system(size: 20, weight: .regular, design: .default)

    /// 17pt / 500 · Card title
    static let title = Font.system(size: 17, weight: .medium, design: .default)

    /// 15pt / 400 · Body
    static let body = Font.system(size: 15, weight: .regular, design: .default)

    /// 13pt / 400 · Label, timestamps
    static let label = Font.system(size: 13, weight: .regular, design: .default)

    /// 11pt / 500 · Caption, all-caps eyebrows
    static let caption = Font.system(size: 11, weight: .medium, design: .default)

    // Variable amount sizes
    static func amount(_ size: CGFloat) -> Font {
        .system(size: size, weight: .ultraLight, design: .default).monospacedDigit()
    }
}

extension View {
    /// Tabular numerals for aligned currency.
    func tabularNumbers() -> some View { self.monospacedDigit() }

    /// Caption · uppercased · wide letter-spacing.
    func eyebrowStyle() -> some View {
        self.font(AppFont.caption)
            .tracking(2.2)
            .textCase(.uppercase)
            .foregroundStyle(AppColors.ink3)
    }
}
