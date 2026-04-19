import Foundation
import SwiftUI

enum SampleData {
    static let primaryAccountID = UUID()

    static let accounts: [Account] = [
        .init(id: primaryAccountID, name: "日常支出", type: .cash, balanceCents: 2_845_00, isPrimary: true),
        .init(id: UUID(), name: "招行信用卡", type: .credit, balanceCents: -1_250_00, isPrimary: false),
        .init(id: UUID(), name: "余额宝", type: .fund, balanceCents: 18_672_00, isPrimary: false),
    ]

    /// Produces ~62 transactions spanning the current month — enough to drive all views.
    static let transactions: [Transaction] = makeMonth()

    private static func makeMonth() -> [Transaction] {
        let now = Date()
        let cal = Calendar(identifier: .gregorian)
        let startOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: now))!

        var seeds: [(Category.Slug, String, Int, Transaction.Source, Int /* hourOfDay */ )] = [
            // day 1
            (.food,      "兰州牛肉面",     2800, .alipay, 12),
            (.transport, "地铁通勤",      600,  .alipay, 9),
            (.shopping,  "优衣库春装",    29900, .wechat, 19),
            (.food,      "星巴克",        3800, .alipay, 15),
            (.entertainment, "电影票",    7200, .wechat, 20),
            // day 2
            (.food,      "盒马鲜生",      8640, .alipay, 18),
            (.transport, "打车回家",      4200, .cmb,    22),
            (.home,      "日用品",        5680, .jd,     13),
            // day 3
            (.food,      "楼下便当",      2500, .wechat, 12),
            (.learning,  "得到听书年卡",  39800, .alipay, 10),
            (.health,    "维生素片",      12800, .jd,    16),
            // day 4
            (.food,      "711 早餐",      1480, .wechat, 8),
            (.transport, "共享单车",      150,  .alipay, 9),
            (.shopping,  "Kindle 新书",   4900, .jd,     21),
            (.food,      "外卖麻辣烫",    3600, .meituan, 12),
            // day 5
            (.entertainment, "健身房月卡", 29800, .cmb,   7),
            (.food,      "日式居酒屋",    18500, .wechat, 19),
            (.transport, "高铁北京→上海",  55300, .alipay, 11),
            // day 6
            (.food,      "酒店早餐",      6800, .cmb,    9),
            (.learning,  "技术书籍",      11580, .jd,    14),
            (.home,      "洗衣液",        4390, .alipay, 17),
        ]

        // Extra tail of typical daily expenses
        let tail: [(Category.Slug, String, Int, Transaction.Source, Int)] = [
            (.food,      "小面馆",        1800, .wechat, 12),
            (.transport, "地铁",          600,  .alipay, 9),
            (.food,      "咖啡",          2800, .alipay, 15),
            (.food,      "超市便当",      1980, .wechat, 12),
            (.transport, "地铁",          600,  .alipay, 19),
            (.shopping,  "日用品",        5500, .alipay, 20),
            (.food,      "烤鱼",          8800, .wechat, 19),
            (.entertainment, "KTV",        12000, .cmb,   22),
            (.food,      "火锅 AA",       15200, .wechat, 20),
            (.transport, "打车",          2800, .alipay, 23),
        ]
        seeds += tail
        seeds += tail
        seeds += tail.prefix(10)

        var out: [Transaction] = []
        for (i, seed) in seeds.enumerated() {
            let dayOffset = i / 2
            let date = cal.date(byAdding: .day, value: dayOffset, to: startOfMonth)!
            let ts = cal.date(bySettingHour: seed.4, minute: (i * 7) % 60, second: 0, of: date) ?? date

            out.append(Transaction(
                id: UUID(),
                kind: .expense,
                amountCents: seed.2,
                categoryID: seed.0,
                accountID: primaryAccountID,
                timestamp: ts,
                merchant: seed.1,
                note: nil,
                source: seed.3,
                importBatchID: nil
            ))
        }
        // Two income rows
        out.append(Transaction(
            id: UUID(),
            kind: .income,
            amountCents: 1_800_000,
            categoryID: .other,
            accountID: primaryAccountID,
            timestamp: cal.date(byAdding: .day, value: 8, to: startOfMonth)!,
            merchant: "4 月工资",
            note: nil,
            source: .manual,
            importBatchID: nil
        ))
        out.append(Transaction(
            id: UUID(),
            kind: .income,
            amountCents: 88_000,
            categoryID: .other,
            accountID: primaryAccountID,
            timestamp: cal.date(byAdding: .day, value: 12, to: startOfMonth)!,
            merchant: "季度奖金",
            note: nil,
            source: .manual,
            importBatchID: nil
        ))

        return out.filter { $0.timestamp <= now }
    }

    // MARK: - Subscriptions

    static let subscriptions: [Subscription] = {
        let cal = Calendar.current
        func addDays(_ d: Int) -> Date { cal.date(byAdding: .day, value: d, to: Date()) ?? Date() }

        return [
            .init(id: UUID(), name: "Netflix", emoji: "🎬", amountCents: 6800,
                  period: .monthly, nextRenewalDate: addDays(3), lastUsedDate: addDays(-1),
                  gradient: [Color(hex: 0xE50914), Color(hex: 0xB20710)], isActive: true),
            .init(id: UUID(), name: "Apple One", emoji: "🍎", amountCents: 6800,
                  period: .monthly, nextRenewalDate: addDays(11), lastUsedDate: addDays(0),
                  gradient: [Color(hex: 0x1a1a2e), Color(hex: 0x555555)], isActive: true),
            .init(id: UUID(), name: "Spotify", emoji: "🎵", amountCents: 1800,
                  period: .monthly, nextRenewalDate: addDays(6), lastUsedDate: addDays(-2),
                  gradient: [Color(hex: 0x1DB954), Color(hex: 0x1ED760)], isActive: true),
            .init(id: UUID(), name: "iCloud 200GB", emoji: "☁️", amountCents: 900,
                  period: .monthly, nextRenewalDate: addDays(18), lastUsedDate: addDays(0),
                  gradient: [Color(hex: 0x4A9EFF), Color(hex: 0x7EA8FF)], isActive: true),
            .init(id: UUID(), name: "得到 · 年卡", emoji: "📚", amountCents: 39800,
                  period: .yearly, nextRenewalDate: addDays(240), lastUsedDate: addDays(-45),
                  gradient: [Color(hex: 0xFFB84D), Color(hex: 0xFFD46B)], isActive: true),
            .init(id: UUID(), name: "Keep 会员", emoji: "🏃", amountCents: 2800,
                  period: .monthly, nextRenewalDate: addDays(21), lastUsedDate: addDays(-110),
                  gradient: [Color(hex: 0x07C160), Color(hex: 0x4ED88C)], isActive: true),
            .init(id: UUID(), name: "豆瓣 Pro", emoji: "📖", amountCents: 1500,
                  period: .monthly, nextRenewalDate: addDays(1), lastUsedDate: addDays(-40),
                  gradient: [Color(hex: 0x2E8B57), Color(hex: 0x7ACFA5)], isActive: true),
        ]
    }()

    // MARK: - Savings Goals

    static let savingsGoals: [SavingsGoal] = {
        let cal = Calendar.current
        func addDays(_ d: Int) -> Date { cal.date(byAdding: .day, value: d, to: Date()) ?? Date() }
        return [
            .init(id: UUID(), name: "索尼相机", emoji: "📷",
                  targetCents: 1_200_000, currentCents: 350_000,
                  deadline: addDays(180), createdAt: addDays(-90),
                  gradient: [Color(hex: 0xFF6B9D), Color(hex: 0xC48AFF)]),
            .init(id: UUID(), name: "日本关西游", emoji: "🗾",
                  targetCents: 800_000, currentCents: 420_000,
                  deadline: addDays(120), createdAt: addDays(-60),
                  gradient: [Color(hex: 0xFFA87A), Color(hex: 0xFFD46B)]),
            .init(id: UUID(), name: "应急储蓄", emoji: "🛟",
                  targetCents: 3_000_000, currentCents: 1_500_000,
                  deadline: addDays(365), createdAt: addDays(-200),
                  gradient: [Color(hex: 0x7EA8FF), Color(hex: 0xA8C0FF)]),
            .init(id: UUID(), name: "技术书专项", emoji: "📚",
                  targetCents: 200_000, currentCents: 168_000,
                  deadline: addDays(60), createdAt: addDays(-30),
                  gradient: [Color(hex: 0x7ACFA5), Color(hex: 0xA8E4D2)]),
        ]
    }()

    // MARK: - Family Members (Spec v2 §6.5)

    static let familyMembers: [FamilyMember] = [
        .init(id: UUID(), name: "Roger (我)", initial: "R", role: .admin,
              avatarColorHex: 0x3B82F6, monthlyContributionCents: 428_000, avatar: "👨"),
        .init(id: UUID(), name: "Lily", initial: "L", role: .member,
              avatarColorHex: 0xEC4899, monthlyContributionCents: 349_200, avatar: "👩"),
        .init(id: UUID(), name: "小朋友 (神兽)", initial: "小", role: .childPassive,
              avatarColorHex: 0xF59E0B, monthlyContributionCents: 70_000, avatar: "👶"),
    ]

    /// Sample rows for the Smart-Import confirm page.
    static let pendingImport: [PendingImportRow] = {
        let now = Date()
        return [
            PendingImportRow(id: UUID(), merchant: "美团外卖 · 麦当劳",  amountCents: 3890,
                             categoryID: .food, timestamp: now.addingTimeInterval(-3600*8), source: .wechat, isDuplicate: false, isSelected: true),
            PendingImportRow(id: UUID(), merchant: "滴滴出行",            amountCents: 2650,
                             categoryID: .transport, timestamp: now.addingTimeInterval(-3600*9), source: .alipay, isDuplicate: false, isSelected: true),
            PendingImportRow(id: UUID(), merchant: "淘宝 · 家居用品",     amountCents: 14900,
                             categoryID: .home, timestamp: now.addingTimeInterval(-3600*12), source: .alipay, isDuplicate: false, isSelected: true),
            PendingImportRow(id: UUID(), merchant: "星巴克",              amountCents: 3800,
                             categoryID: .food, timestamp: now.addingTimeInterval(-3600*14), source: .alipay, isDuplicate: true, isSelected: false),
            PendingImportRow(id: UUID(), merchant: "招行信用卡还款",       amountCents: 125000,
                             categoryID: .other, timestamp: now.addingTimeInterval(-3600*18), source: .cmb, isDuplicate: false, isSelected: true),
            PendingImportRow(id: UUID(), merchant: "Apple 订阅",          amountCents: 2800,
                             categoryID: .entertainment, timestamp: now.addingTimeInterval(-3600*20), source: .alipay, isDuplicate: false, isSelected: true),
            PendingImportRow(id: UUID(), merchant: "京东 · 投影仪",        amountCents: 299900,
                             categoryID: .shopping, timestamp: now.addingTimeInterval(-3600*24), source: .jd, isDuplicate: false, isSelected: true),
            PendingImportRow(id: UUID(), merchant: "线下餐厅",            amountCents: 9280,
                             categoryID: .food, timestamp: now.addingTimeInterval(-3600*28), source: .wechat, isDuplicate: false, isSelected: true),
        ]
    }()
}

// MARK: - Formatting helpers

enum Money {
    static func yuan(_ cents: Int, showDecimals: Bool = true, showSign: Bool = false) -> String {
        let sign = showSign ? (cents > 0 ? "+" : (cents < 0 ? "-" : "")) : (cents < 0 ? "-" : "")
        let abs = Swift.abs(cents)
        let yuan = abs / 100
        let fen = abs % 100
        let group = NumberFormatter()
        group.groupingSeparator = ","
        group.numberStyle = .decimal
        let body = group.string(from: NSNumber(value: yuan)) ?? "\(yuan)"
        if showDecimals {
            return "\(sign)¥\(body).\(String(format: "%02d", fen))"
        } else {
            return "\(sign)¥\(body)"
        }
    }
}
