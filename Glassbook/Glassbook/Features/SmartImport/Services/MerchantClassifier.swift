import Foundation
import SwiftData

/// Spec §5.4 · 商户→分类映射 + 学习能力.
/// - Seeded with a hand-curated lookup covering the most common Chinese merchants.
/// - Persists user overrides to `SDMerchantLearning` so the next encounter self-applies.
final class MerchantClassifier {

    /// Shared singleton — views/parsers call `MerchantClassifier.shared.classify(…)`.
    /// Inject a `ModelContext` in `AppStore` bootstrap so learning round-trips to disk.
    static let shared = MerchantClassifier()

    private var learnedCache: [String: Category.Slug] = [:]
    private weak var context: ModelContext?

    private init() {}

    // MARK: - Attach persistence

    func attach(context: ModelContext) {
        self.context = context
        hydrate()
    }

    private func hydrate() {
        guard let context else { return }
        let desc = FetchDescriptor<SDMerchantLearning>()
        let rows = (try? context.fetch(desc)) ?? []
        learnedCache = Dictionary(uniqueKeysWithValues: rows.map { ($0.merchantKey, $0.category) })
    }

    // MARK: - Classify

    func classify(merchant: String) -> Category.Slug {
        let key = normalize(merchant)
        if let learned = learnedCache[key] { return learned }
        for (needle, slug) in Self.lookup {
            if key.contains(needle) { return slug }
        }
        return .other
    }

    /// Called when the user manually overrides a detected category — persists the rule
    /// so the next sighting of this merchant auto-classifies correctly.
    func remember(merchant: String, as slug: Category.Slug) {
        let key = normalize(merchant)
        learnedCache[key] = slug

        guard let context else { return }
        let existing = (try? context.fetch(
            FetchDescriptor<SDMerchantLearning>(predicate: #Predicate { $0.merchantKey == key })
        ))?.first
        if let existing {
            existing.categoryRaw = slug.rawValue
            existing.lastTouched = .now
        } else {
            context.insert(SDMerchantLearning(merchantKey: key, category: slug))
        }
        try? context.save()
    }

    private func normalize(_ s: String) -> String {
        s.lowercased()
         .replacingOccurrences(of: " ", with: "")
         .replacingOccurrences(of: "·", with: "")
    }

    // MARK: - Lookup table (seed)

    /// Substring matcher (merchant.contains(key)). Order doesn't matter much since each
    /// merchant typically hits only one entry.
    private static let lookup: [(String, Category.Slug)] = [
        // 餐饮
        ("美团外卖", .food), ("饿了么", .food), ("美团", .food), ("麦当劳", .food),
        ("肯德基", .food), ("星巴克", .food), ("瑞幸", .food), ("海底捞", .food),
        ("奈雪", .food), ("喜茶", .food), ("肯德基", .food), ("必胜客", .food),
        ("面馆", .food), ("餐厅", .food), ("外卖", .food), ("烤鱼", .food),
        ("火锅", .food), ("早餐", .food), ("便当", .food),
        // 交通
        ("滴滴", .transport), ("高德打车", .transport), ("美团打车", .transport),
        ("12306", .transport), ("铁路", .transport), ("地铁", .transport),
        ("公交", .transport), ("共享单车", .transport), ("哈啰", .transport),
        ("打车", .transport), ("高铁", .transport),
        // 购物
        ("淘宝", .shopping), ("天猫", .shopping), ("京东", .shopping), ("拼多多", .shopping),
        ("得物", .shopping), ("小红书", .shopping), ("唯品会", .shopping),
        ("优衣库", .shopping), ("zara", .shopping), ("h&m", .shopping),
        // 娱乐
        ("爱奇艺", .entertainment), ("腾讯视频", .entertainment), ("b站", .entertainment),
        ("bilibili", .entertainment), ("网易云", .entertainment), ("qq音乐", .entertainment),
        ("apple", .entertainment), ("spotify", .entertainment), ("电影", .entertainment),
        ("ktv", .entertainment), ("健身", .entertainment), ("舞蹈", .entertainment),
        ("剧本杀", .entertainment),
        // 居家
        ("国家电网", .home), ("自来水", .home), ("燃气", .home), ("物业", .home),
        ("宽带", .home), ("移动", .home), ("联通", .home), ("电信", .home),
        ("家居", .home), ("宜家", .home), ("日用", .home), ("洗衣", .home),
        // 医疗
        ("医院", .health), ("药店", .health), ("药房", .health), ("体检", .health),
        ("维生素", .health), ("口腔", .health), ("诊所", .health),
        // 学习
        ("得到", .learning), ("樊登", .learning), ("喜马拉雅", .learning), ("书籍", .learning),
        ("新书", .learning), ("kindle", .learning), ("网课", .learning), ("课程", .learning),
    ]
}
