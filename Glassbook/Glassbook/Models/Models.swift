import SwiftUI

// MARK: - Transaction

/// Spec §4.2 数据字段 · amount stored as Int cents to avoid float precision drift.
struct Transaction: Identifiable, Hashable {
    enum Kind: String, CaseIterable, Hashable { case expense, income, transfer }
    enum Source: String, Hashable {
        case manual, alipay, wechat, cmb, jd, meituan, douyin, otherOCR
    }

    let id: UUID
    var kind: Kind
    var amountCents: Int
    var categoryID: Category.ID
    var accountID: Account.ID
    var timestamp: Date
    var merchant: String
    var note: String?
    var source: Source
    var importBatchID: UUID?
    var mood: Mood? = nil
    var visibility: Visibility = .family
    var originalCurrency: Currency = .cny
    var originalAmountCents: Int? = nil   // only set when tx was in foreign currency

    var amount: Decimal { Decimal(amountCents) / 100 }
    var signedAmount: Decimal { kind == .income ? amount : -amount }
}

// MARK: - Family Member (Spec v2 §6.5)

struct FamilyMember: Identifiable, Hashable {
    enum Role: String, Hashable, Codable {
        case admin          // 管理员 · 全部权限
        case member         // 成员 · 可记账/查看
        case childPassive   // 被动维度 · 不登录

        var displayName: String {
            switch self {
            case .admin:        "管理员 · 全部权限"
            case .member:       "成员 · 可记账/查看"
            case .childPassive: "被动维度 · 不登录"
            }
        }
        var lockEmoji: String {
            switch self {
            case .admin:        "🔓"
            case .member:       "🔒"
            case .childPassive: "👀"
            }
        }
    }
    let id: UUID
    var name: String
    var initial: String
    var role: Role
    var avatarColorHex: UInt32
    var monthlyContributionCents: Int
    /// Emoji shown in split-bar rows (👨 / 👩 / 👶).
    var avatar: String
}

// MARK: - Sunk Cost item (Spec v2 §6.6)

/// Unused subscription OR one-off hardware gathering dust.
struct SunkCostItem: Identifiable, Hashable {
    enum Kind { case subscription, hardware, software }
    let id: UUID
    var kind: Kind
    var name: String
    var iconEmoji: String
    var monthlyDrainCents: Int      // ¥/month equivalent still being spent
    var daysIdle: Int               // usage gap
    var rationale: String           // why we flagged this
}

// MARK: - Mood (Spec v2 §6 情绪记账)

/// Lightweight mood tag attached at record-time. Drives the 情绪账本 year-in-review.
enum Mood: String, CaseIterable, Hashable, Codable {
    case happy      // 开心
    case necessary  // 刚需
    case reward     // 犒赏
    case regret     // 后悔
    case anxious    // 焦虑

    var displayName: String {
        switch self {
        case .happy:     "开心"
        case .necessary: "刚需"
        case .reward:    "犒赏"
        case .regret:    "后悔"
        case .anxious:   "焦虑"
        }
    }
    var emoji: String {
        switch self {
        case .happy:     "😊"
        case .necessary: "📌"
        case .reward:    "🎁"
        case .regret:    "😔"
        case .anxious:   "😰"
        }
    }
    /// Soft tint for Aurora-friendly chip background.
    var tintHex: UInt32 {
        switch self {
        case .happy:     0x4A8A5E
        case .necessary: 0x7EA8FF
        case .reward:    0xFFB84D
        case .regret:    0xC8171E
        case .anxious:   0xC48AFF
        }
    }
}

// MARK: - Visibility (Spec v2 §5 家庭共享分级隐私)

/// Per-transaction visibility for CKShare-backed family books.
enum Visibility: String, CaseIterable, Hashable, Codable {
    case family    // 家庭可见
    case partner   // 仅伴侣
    case personal  // 仅自己 (private)

    var displayName: String {
        switch self {
        case .family: "家庭可见"
        case .partner: "仅伴侣"
        case .personal: "仅自己"
        }
    }
    var emoji: String {
        switch self {
        case .family: "👨‍👩‍👧"
        case .partner: "💞"
        case .personal: "🔒"
        }
    }
}

// MARK: - Currency (Spec v2 §6.1 多币种)

enum Currency: String, CaseIterable, Hashable, Codable {
    case cny, usd, hkd, eur, jpy, gbp

    var symbol: String {
        switch self {
        case .cny: "¥"; case .usd: "$"; case .hkd: "HK$"
        case .eur: "€"; case .jpy: "¥"; case .gbp: "£"
        }
    }
    var code: String { rawValue.uppercased() }
}

// MARK: - Category

/// 9 default categories — extended with "孩子" (Spec v2 §6.3 神兽专项开支).
struct Category: Identifiable, Hashable {
    enum Slug: String, CaseIterable {
        case food, transport, shopping, entertainment, home, health, learning, kids, other
    }
    let id: Slug
    let name: String
    let emoji: String
    let gradient: [Color]

    static let all: [Category] = [
        .init(id: .food, name: "餐饮", emoji: "🍜", gradient: AppColors.catFood),
        .init(id: .transport, name: "交通", emoji: "🚇", gradient: AppColors.catTransport),
        .init(id: .shopping, name: "购物", emoji: "🛍", gradient: AppColors.catShopping),
        .init(id: .entertainment, name: "娱乐", emoji: "🎬", gradient: AppColors.catEntertainment),
        .init(id: .home, name: "居家", emoji: "🏠", gradient: AppColors.catHome),
        .init(id: .health, name: "医疗", emoji: "💊", gradient: AppColors.catHealth),
        .init(id: .learning, name: "学习", emoji: "📚", gradient: AppColors.catLearning),
        .init(id: .kids, name: "孩子", emoji: "🧒", gradient: [Color(hex: 0xFFC8A8), Color(hex: 0xFFB199)]),
        .init(id: .other, name: "其他", emoji: "✨", gradient: AppColors.catOther),
    ]

    static func by(_ id: Slug) -> Category { all.first { $0.id == id } ?? all.last! }
}

// MARK: - Account

struct Account: Identifiable, Hashable {
    let id: UUID
    var name: String
    var type: Kind
    var balanceCents: Int
    var isPrimary: Bool

    enum Kind: String, Hashable { case cash, savings, credit, fund, virtual }
}

// MARK: - Budget

/// Spec §4.5 · total + per-category caps. Stored as Int cents.
struct Budget: Hashable {
    var monthlyTotalCents: Int
    var perCategory: [Category.Slug: Int]   // cents

    static let `default` = Budget(
        monthlyTotalCents: 600_000,          // ¥6,000
        perCategory: [
            .food:         150_000,
            .transport:     60_000,
            .shopping:     120_000,
            .entertainment: 50_000,
            .home:          80_000,
            .health:        30_000,
            .learning:      40_000,
            .other:         30_000,
        ]
    )
}

// MARK: - Smart-Import batch

struct ImportBatch: Identifiable, Hashable {
    let id: UUID
    var platform: Platform
    var importedAt: Date
    var totalTxCount: Int
    var totalAmountCents: Int
    var duplicatesSkipped: Int

    enum Platform: String, CaseIterable {
        case alipay, wechat, cmb, jd, meituan, douyin, otherBank
        var displayName: String {
            switch self {
            case .alipay:   return "支付宝"
            case .wechat:   return "微信支付"
            case .cmb:      return "招商银行"
            case .jd:       return "京东"
            case .meituan:  return "美团"
            case .douyin:   return "抖音"
            case .otherBank: return "其他银行"
            }
        }
        var abbrev: String {
            switch self {
            case .alipay:   return "支"
            case .wechat:   return "微"
            case .cmb:      return "招"
            case .jd:       return "京"
            case .meituan:  return "美"
            case .douyin:   return "抖"
            case .otherBank: return "他"
            }
        }
        var gradient: [Color] {
            switch self {
            case .alipay:   return AppColors.platAlipay
            case .wechat:   return AppColors.platWeChat
            case .cmb:      return AppColors.platCMB
            case .jd:       return AppColors.platJD
            case .meituan:  return AppColors.platMeituan
            case .douyin:   return [Color(hex: 0x000000), Color(hex: 0x222222)]
            case .otherBank: return [Color(hex: 0x8A8176), Color(hex: 0xC9A961)]
            }
        }
        var supportedFormats: String {
            switch self {
            case .alipay:   return "账单列表 / 月报 / 转账记录"
            case .wechat:   return "账单明细 / 钱包截图"
            case .cmb:      return "收支明细 / 信用卡账单"
            case .jd:       return "订单页截图"
            case .meituan:  return "外卖 / 到店订单"
            case .douyin:   return "支付记录"
            case .otherBank: return "通用 OCR 识别"
            }
        }
    }
}

// MARK: - Subscription (Spec §6.2 Hero 3)

struct Subscription: Identifiable, Hashable {
    enum Period: String, CaseIterable {
        case weekly, monthly, yearly
        var displayName: String {
            switch self { case .weekly: "每周"; case .monthly: "每月"; case .yearly: "每年" }
        }
        var daysBetween: Int {
            switch self { case .weekly: 7; case .monthly: 30; case .yearly: 365 }
        }
    }

    let id: UUID
    var name: String
    var emoji: String
    var amountCents: Int
    var period: Period
    var nextRenewalDate: Date
    var lastUsedDate: Date
    var gradient: [Color]
    var isActive: Bool

    /// Normalized to ¥/month for the hero card.
    var monthlyEquivalentCents: Int {
        switch period {
        case .weekly:  return amountCents * 52 / 12
        case .monthly: return amountCents
        case .yearly:  return amountCents / 12
        }
    }
    var daysSinceLastUse: Int {
        Calendar.current.dateComponents([.day], from: lastUsedDate, to: Date()).day ?? 0
    }
    var zombieLevel: ZombieLevel {
        let d = daysSinceLastUse
        if d >= 90 { return .dormant }
        if d >= 30 { return .idle }
        return .active
    }
    enum ZombieLevel { case active, idle, dormant }

    var daysToRenewal: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: nextRenewalDate).day ?? 0
    }
}

// MARK: - Savings Goal (Spec §6.2 Hero 2)

struct SavingsGoal: Identifiable, Hashable {
    let id: UUID
    var name: String
    var emoji: String
    var targetCents: Int
    var currentCents: Int
    var deadline: Date?
    var createdAt: Date
    var gradient: [Color]

    var progress: Double {
        guard targetCents > 0 else { return 0 }
        return min(1.0, Double(currentCents) / Double(targetCents))
    }
    var daysRemaining: Int? {
        guard let deadline else { return nil }
        return max(0, Calendar.current.dateComponents([.day], from: Date(), to: deadline).day ?? 0)
    }
    /// Suggested ¥/day to hit the target on time.
    var dailyTargetCents: Int? {
        guard let d = daysRemaining, d > 0 else { return nil }
        let remaining = max(0, targetCents - currentCents)
        return remaining / d
    }
}

// MARK: - Pending (awaiting-confirm) import row

struct PendingImportRow: Identifiable, Hashable {
    let id: UUID
    var merchant: String
    var amountCents: Int
    var categoryID: Category.Slug
    var timestamp: Date
    var source: ImportBatch.Platform
    var isDuplicate: Bool
    var isSelected: Bool
}
