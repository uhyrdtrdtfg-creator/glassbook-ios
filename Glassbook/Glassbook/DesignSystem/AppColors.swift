import SwiftUI

enum AppColors {
    // Ink (主文字色)
    static let ink       = Color(hex: 0x1A1A2E)
    static let ink2      = Color(hex: 0x1A1A2E).opacity(0.7)
    static let ink3      = Color(hex: 0x1A1A2E).opacity(0.45)
    static let ink4      = Color(hex: 0x1A1A2E).opacity(0.25)

    // Glass
    static let glassFill   = Color.white.opacity(0.38)
    static let glassBorder = Color.white.opacity(0.6)
    static let glassDivider = Color.white.opacity(0.5)

    // Aurora light-spots
    static let auroraPink   = Color(hex: 0xFF9A7B)
    static let auroraBlue   = Color(hex: 0x7EA8FF)
    static let auroraPurple = Color(hex: 0xC48AFF)
    static let auroraAmber  = Color(hex: 0xFFD46B)

    // Brand gradient
    static let brandStart = Color(hex: 0xFF6B9D)
    static let brandEnd   = Color(hex: 0x7EA8FF)

    // Semantics
    static let expenseRed = Color(hex: 0xD04A7A)
    static let incomeGreen = Color(hex: 0x4A8A5E)
    static let warnRed    = Color(hex: 0xD04A7A)
    static let successGreen = Color(hex: 0x7ACFA5)

    // Category tints (8)
    static let catFood     = [Color(hex: 0xFFB199), Color(hex: 0xFF7A9C)]
    static let catTransport = [Color(hex: 0x9CC0FF), Color(hex: 0x7A9CFF)]
    static let catShopping  = [Color(hex: 0xD4A5FF), Color(hex: 0xA87AFF)]
    static let catEntertainment = [Color(hex: 0xFFD46B), Color(hex: 0xFFA87A)]
    static let catHome      = [Color(hex: 0xA8E4D2), Color(hex: 0x7ACFA5)]
    static let catHealth    = [Color(hex: 0xFFB4CC), Color(hex: 0xFF7AA8)]
    static let catLearning  = [Color(hex: 0xB8E6FF), Color(hex: 0x7EC4FF)]
    static let catOther     = [Color(hex: 0xD8D0C4), Color(hex: 0xB5A99A)]

    // Platform brand
    static let platAlipay = [Color(hex: 0x1677FF), Color(hex: 0x4A9EFF)]
    static let platWeChat = [Color(hex: 0x07C160), Color(hex: 0x4ED88C)]
    static let platCMB    = [Color(hex: 0xC8171E), Color(hex: 0xE55A60)]
    static let platJD     = [Color(hex: 0xE1251B), Color(hex: 0xF2564B)]
    static let platMeituan = [Color(hex: 0xFFC900), Color(hex: 0xFFB84D)]
}

extension Color {
    init(hex: UInt32, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >>  8) & 0xFF) / 255
        let b = Double( hex        & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

extension LinearGradient {
    static func brand(start: UnitPoint = .leading, end: UnitPoint = .trailing) -> LinearGradient {
        LinearGradient(colors: [AppColors.brandStart, AppColors.brandEnd], startPoint: start, endPoint: end)
    }
    static func gradient(_ colors: [Color], start: UnitPoint = .topLeading, end: UnitPoint = .bottomTrailing) -> LinearGradient {
        LinearGradient(colors: colors, startPoint: start, endPoint: end)
    }
}
