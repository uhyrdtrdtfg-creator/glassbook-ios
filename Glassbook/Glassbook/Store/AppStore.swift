import Foundation
import Observation
import SwiftData

/// AppStore is the view-model façade all SwiftUI screens talk to.
/// Reads / writes to SwiftData on mutation; views remain struct-oriented.
@Observable
final class AppStore {
    var transactions: [Transaction] = []
    var accounts: [Account] = []
    var subscriptions: [Subscription] = []
    var goals: [SavingsGoal] = []
    var familyMembers: [FamilyMember] = SampleData.familyMembers
    var budget: Budget = .default
    var userName: String = "Roger"
    var userInitial: String = "R"
    var isPro: Bool = true

    private let context: ModelContext?

    // MARK: - Init

    /// Primary init — persists to a context tied to the given container.
    /// `ModelContext(container)` avoids the `@MainActor` isolation on `container.mainContext`,
    /// which keeps AppStore callable from any actor while still sharing the same SQLite store.
    init(container: ModelContainer) {
        let ctx = ModelContext(container)
        self.context = ctx
        reload()
        if transactions.isEmpty {
            AppSeed.seed(context: ctx)
            reload()
        }
        // Drain anything a Shortcut-triggered AppIntent enqueued while we were
        // backgrounded / terminated (spec v2 · Diagram 03).
        drainPendingImports()
    }

    /// Called on init and on foreground. Pops everything the
    /// `ImportScreenshotIntent` put in the App Group queue and writes each
    /// entry through `addExpense()` so it goes to SwiftData + snapshots.
    func drainPendingImports() {
        let entries = PendingImportQueue.drain()
        guard !entries.isEmpty else { return }
        print("📥 Draining \(entries.count) shortcut-captured transactions")
        for e in entries {
            guard let slug = Category.Slug(rawValue: e.categorySlug) else { continue }
            addExpense(
                amountCents: e.amountCents,
                category: slug,
                merchant: e.merchant,
                note: "via iOS Shortcut",
                timestamp: e.timestamp
            )
        }
    }

    /// Preview / in-memory init (no persistence). Used by `#Preview` blocks.
    init() {
        self.context = nil
        self.transactions = SampleData.transactions
        self.accounts = SampleData.accounts
        self.subscriptions = SampleData.subscriptions
        self.goals = SampleData.savingsGoals
        self.budget = .default
    }

    // MARK: - Derived

    var thisMonthExpenseCents: Int {
        transactionsInMonth(Date()).filter { $0.kind == .expense }.reduce(0) { $0 + $1.amountCents }
    }
    var thisMonthIncomeCents: Int {
        transactionsInMonth(Date()).filter { $0.kind == .income }.reduce(0) { $0 + $1.amountCents }
    }
    var thisMonthTransactionCount: Int { transactionsInMonth(Date()).count }
    var thisMonthDailyAverageCents: Int {
        let cal = Calendar(identifier: .gregorian)
        let day = cal.component(.day, from: Date())
        return day == 0 ? 0 : thisMonthExpenseCents / day
    }
    var budgetRemainingCents: Int { budget.monthlyTotalCents - thisMonthExpenseCents }
    var budgetUsedPercent: Double {
        guard budget.monthlyTotalCents > 0 else { return 0 }
        return Double(thisMonthExpenseCents) / Double(budget.monthlyTotalCents)
    }
    var lastMonthExpenseCents: Int {
        let cal = Calendar(identifier: .gregorian)
        let lastMonth = cal.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        return transactionsInMonth(lastMonth).filter { $0.kind == .expense }.reduce(0) { $0 + $1.amountCents }
    }
    var monthOverMonthChangePct: Double {
        guard lastMonthExpenseCents > 0 else { return 0 }
        return (Double(thisMonthExpenseCents) - Double(lastMonthExpenseCents))
            / Double(lastMonthExpenseCents)
    }
    var primaryAccountID: UUID {
        accounts.first(where: \.isPrimary)?.id ?? SampleData.primaryAccountID
    }

    /// Multi-account net worth (Spec §6.1 P0).
    /// Cash / savings / fund → added. Credit card → subtracted if balance is negative (debt).
    var netWorthCents: Int {
        accounts.reduce(0) { running, acc in
            switch acc.type {
            case .credit:
                return running + acc.balanceCents   // credit balance is already signed (negative = debt)
            default:
                return running + acc.balanceCents
            }
        }
    }
    var monthlySubscriptionTotalCents: Int {
        subscriptions.filter(\.isActive).reduce(0) { $0 + $1.monthlyEquivalentCents }
    }
    var totalSavedCents: Int {
        goals.reduce(0) { $0 + $1.currentCents }
    }
    var totalGoalsTargetCents: Int {
        goals.reduce(0) { $0 + $1.targetCents }
    }

    /// Family book total — transactions with visibility `.family` this month.
    var familyTotalThisMonthCents: Int {
        transactionsInMonth(Date())
            .filter { $0.kind == .expense && $0.visibility == .family }
            .reduce(0) { $0 + $1.amountCents }
    }

    // MARK: - Queries

    func transactionsInMonth(_ date: Date) -> [Transaction] {
        let cal = Calendar(identifier: .gregorian)
        let y = cal.component(.year, from: date)
        let m = cal.component(.month, from: date)
        return transactions.filter {
            cal.component(.year, from: $0.timestamp) == y &&
            cal.component(.month, from: $0.timestamp) == m
        }.sorted { $0.timestamp > $1.timestamp }
    }

    func expensesByCategory(in date: Date) -> [(Category, Int)] {
        let tx = transactionsInMonth(date).filter { $0.kind == .expense }
        var buckets = [Category.Slug: Int]()
        for t in tx { buckets[t.categoryID, default: 0] += t.amountCents }
        return Category.all.compactMap { cat in
            guard let cents = buckets[cat.id], cents > 0 else { return nil }
            return (cat, cents)
        }.sorted { $0.1 > $1.1 }
    }

    func monthlyTrend(months: Int = 7) -> [(label: String, expenseCents: Int, incomeCents: Int)] {
        let cal = Calendar(identifier: .gregorian)
        var out: [(String, Int, Int)] = []
        for offset in (0..<months).reversed() {
            let base = cal.date(byAdding: .month, value: -offset, to: Date()) ?? Date()
            let m = cal.component(.month, from: base)
            let tx = transactionsInMonth(base)
            let exp = tx.filter { $0.kind == .expense }.reduce(0) { $0 + $1.amountCents }
            let inc = tx.filter { $0.kind == .income }.reduce(0) { $0 + $1.amountCents }
            let simulatedExp = offset == 0 ? exp : (380_000 + (offset * 37_000) % 180_000)
            out.append(("\(m)月", simulatedExp, inc))
        }
        return out
    }

    func txByDay(in date: Date) -> [(date: Date, items: [Transaction])] {
        let cal = Calendar(identifier: .gregorian)
        let grouped = Dictionary(grouping: transactionsInMonth(date)) { tx in
            cal.startOfDay(for: tx.timestamp)
        }
        return grouped.keys.sorted(by: >).map { key in
            (key, grouped[key]!.sorted { $0.timestamp > $1.timestamp })
        }
    }

    // MARK: - Mutations

    func addExpense(amountCents: Int, category: Category.Slug, merchant: String,
                    note: String?, mood: Mood? = nil, visibility: Visibility = .family,
                    timestamp: Date = Date(),
                    originalCurrency: Currency = .cny, originalAmountCents: Int? = nil) {
        guard amountCents > 0 else { return }
        let tx = Transaction(
            id: UUID(), kind: .expense, amountCents: amountCents,
            categoryID: category, accountID: primaryAccountID, timestamp: timestamp,
            merchant: merchant.isEmpty ? Category.by(category).name : merchant,
            note: note?.isEmpty == false ? note : nil,
            source: .manual, importBatchID: nil,
            mood: mood, visibility: visibility,
            originalCurrency: originalCurrency,
            originalAmountCents: originalAmountCents
        )
        transactions.insert(tx, at: 0)
        persist(tx: tx)
    }

    func delete(_ id: UUID) {
        transactions.removeAll { $0.id == id }
        guard let context else { return }
        let desc = FetchDescriptor<SDTransaction>(predicate: #Predicate { $0.id == id })
        for sd in (try? context.fetch(desc)) ?? [] { context.delete(sd) }
        try? context.save()
    }

    /// Spec §5.3 · commit a smart-import batch. Returns the new batchID so the UI can
    /// offer a 7-day rollback affordance (Spec §5.5).
    @discardableResult
    func importBatch(rows: [PendingImportRow], platform: ImportBatch.Platform) -> UUID {
        let batchID = UUID()
        let selected = rows.filter(\.isSelected)
        let mapped: [Transaction] = selected.map { row in
            Transaction(
                id: UUID(), kind: .expense, amountCents: row.amountCents,
                categoryID: row.categoryID, accountID: primaryAccountID,
                timestamp: row.timestamp, merchant: row.merchant, note: nil,
                source: Self.source(for: platform), importBatchID: batchID
            )
        }
        for tx in mapped {
            transactions.insert(tx, at: 0)
            persist(tx: tx)
        }
        persistBatch(SDImportBatch(
            id: batchID,
            platform: platform,
            importedAt: .now,
            totalTxCount: selected.count,
            totalAmountCents: selected.reduce(0) { $0 + $1.amountCents },
            duplicatesSkipped: rows.count - selected.count
        ))
        return batchID
    }

    /// Remove all transactions in a batch. Called if the user hits "撤销整批".
    func rollbackBatch(_ batchID: UUID) {
        transactions.removeAll { $0.importBatchID == batchID }
        guard let context else { return }
        let desc = FetchDescriptor<SDTransaction>(predicate: #Predicate { $0.importBatchID == batchID })
        for sd in (try? context.fetch(desc)) ?? [] { context.delete(sd) }
        let bdesc = FetchDescriptor<SDImportBatch>(predicate: #Predicate { $0.id == batchID })
        for sd in (try? context.fetch(bdesc)) ?? [] { context.delete(sd) }
        try? context.save()
    }

    // MARK: - Persistence helpers

    private func persist(tx: Transaction) {
        guard let context else { return }
        context.insert(SDTransaction(from: tx))
        try? context.save()
        syncSnapshots()
    }

    /// After any mutation we push two derived views of the store out:
    /// - App Group `SharedSnapshot` (for Widget + Watch)
    /// - iCloud Drive JSON mirror (for the Mac `glassbook-mcp` process)
    private func syncSnapshots() {
        SharedStorage.write(buildSharedSnapshot())
        _ = iCloudExporter.export(
            transactions: transactions,
            subscriptions: subscriptions,
            budget: budget
        )
    }

    private func buildSharedSnapshot() -> SharedSnapshot {
        let recent = Array(transactionsInMonth(Date()).prefix(5))
        let fmt = DateFormatter()
        fmt.locale = .init(identifier: "zh_CN")
        fmt.dateFormat = "M月d日 HH:mm"
        let top = expensesByCategory(in: Date()).first?.0
        return SharedSnapshot(
            monthExpenseCents: thisMonthExpenseCents,
            monthBudgetCents: budget.monthlyTotalCents,
            dailyAverageCents: thisMonthDailyAverageCents,
            topCategoryName: top?.name ?? "—",
            topCategoryEmoji: top?.emoji ?? "✨",
            recentTransactions: recent.map {
                .init(merchant: $0.merchant,
                      emoji: Category.by($0.categoryID).emoji,
                      cents: $0.amountCents,
                      timeLabel: fmt.string(from: $0.timestamp))
            },
            updatedAt: .now
        )
    }
    private func persistBatch(_ batch: SDImportBatch) {
        guard let context else { return }
        context.insert(batch)
        try? context.save()
        syncSnapshots()
    }

    // MARK: - Data management (wipe / reset)

    /// Delete every transaction, account, subscription, goal, budget row, and
    /// import-batch record on disk. Keeps merchant-learning (user-tuned) and
    /// user preferences (name, avatar, BYO LLM keys) alone. The in-memory
    /// state is cleared synchronously so the UI updates instantly.
    func wipeAll() {
        transactions = []
        accounts = []
        subscriptions = []
        goals = []
        budget = .default
        guard let context else { return }
        do {
            try context.delete(model: SDTransaction.self)
            try context.delete(model: SDAccount.self)
            try context.delete(model: SDBudget.self)
            try context.delete(model: SDImportBatch.self)
            try context.delete(model: SDSubscription.self)
            try context.delete(model: SDSavingsGoal.self)
            try context.save()
        } catch {
            print("⚠️ wipeAll failed: \(error)")
        }
    }

    /// Clear just the transaction history (and their import batches). Leaves
    /// accounts / subscriptions / goals / budget intact.
    func wipeTransactions() {
        transactions = []
        guard let context else { return }
        try? context.delete(model: SDTransaction.self)
        try? context.delete(model: SDImportBatch.self)
        try? context.save()
    }

    func wipeSubscriptions() {
        subscriptions = []
        guard let context else { return }
        try? context.delete(model: SDSubscription.self)
        try? context.save()
    }

    func wipeGoals() {
        goals = []
        guard let context else { return }
        try? context.delete(model: SDSavingsGoal.self)
        try? context.save()
    }

    func wipeMerchantLearning() {
        guard let context else { return }
        try? context.delete(model: SDMerchantLearning.self)
        try? context.save()
    }

    /// Nuke everything then re-seed the sample set (Roger / 62 tx / 3 accounts /
    /// 7 subs / 4 goals). Useful for scaffold demos and "factory reset".
    func resetToDemo() {
        wipeAll()
        wipeMerchantLearning()
        if let context {
            AppSeed.seed(context: context)
            reload()
        } else {
            // In-memory path (preview target).
            transactions = SampleData.transactions
            accounts = SampleData.accounts
            subscriptions = SampleData.subscriptions
            goals = SampleData.savingsGoals
            budget = .default
        }
    }

    private func reload() {
        guard let context else { return }
        let txDesc = FetchDescriptor<SDTransaction>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
        transactions = ((try? context.fetch(txDesc)) ?? []).map { $0.toStruct() }

        let accDesc = FetchDescriptor<SDAccount>()
        accounts = ((try? context.fetch(accDesc)) ?? []).map { $0.toStruct() }
        if accounts.isEmpty { accounts = SampleData.accounts }

        let subDesc = FetchDescriptor<SDSubscription>(sortBy: [SortDescriptor(\.nextRenewalDate)])
        subscriptions = ((try? context.fetch(subDesc)) ?? []).map { $0.toStruct() }

        let goalDesc = FetchDescriptor<SDSavingsGoal>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        goals = ((try? context.fetch(goalDesc)) ?? []).map { $0.toStruct() }

        let budgetDesc = FetchDescriptor<SDBudget>()
        if let b = (try? context.fetch(budgetDesc))?.first {
            budget = b.toStruct()
        }
        // Fresh boot — push current state to external surfaces.
        syncSnapshots()
    }

    // MARK: - Account mutations

    func addAccount(_ account: Account) {
        accounts.append(account)
        guard let context else { return }
        context.insert(SDAccount(from: account))
        try? context.save()
    }
    func deleteAccount(id: UUID) {
        accounts.removeAll { $0.id == id }
        guard let context else { return }
        let desc = FetchDescriptor<SDAccount>(predicate: #Predicate { $0.id == id })
        for sd in (try? context.fetch(desc)) ?? [] { context.delete(sd) }
        try? context.save()
    }

    // MARK: - Budget mutation

    func updateBudget(monthlyTotalCents: Int? = nil,
                      perCategory: [Category.Slug: Int]? = nil) {
        if let total = monthlyTotalCents { budget.monthlyTotalCents = total }
        if let cats = perCategory { budget.perCategory = cats }
        guard let context else { return }
        let desc = FetchDescriptor<SDBudget>()
        if let sd = (try? context.fetch(desc))?.first {
            sd.monthlyTotalCents = budget.monthlyTotalCents
            sd.perCategoryEncoded = SDBudget.encode(budget.perCategory)
        } else {
            context.insert(SDBudget(from: budget))
        }
        try? context.save()
    }

    // MARK: - Family mutations

    func addFamilyMember(_ m: FamilyMember) {
        familyMembers.append(m)
        // Family members are purely in-memory in this scaffold — CKShare
        // invites would persist them to the shared CloudKit zone in production.
    }
    func deleteFamilyMember(id: UUID) {
        familyMembers.removeAll { $0.id == id }
    }

    // MARK: - Subscription mutations

    func addSubscription(_ s: Subscription) {
        subscriptions.append(s)
        subscriptions.sort { $0.nextRenewalDate < $1.nextRenewalDate }
        guard let context else { return }
        context.insert(SDSubscription(from: s))
        try? context.save()
    }
    func deleteSubscription(id: UUID) {
        subscriptions.removeAll { $0.id == id }
        guard let context else { return }
        let desc = FetchDescriptor<SDSubscription>(predicate: #Predicate { $0.id == id })
        for sd in (try? context.fetch(desc)) ?? [] { context.delete(sd) }
        try? context.save()
    }

    // MARK: - Goal mutations

    func addGoal(_ g: SavingsGoal) {
        goals.insert(g, at: 0)
        guard let context else { return }
        context.insert(SDSavingsGoal(from: g))
        try? context.save()
    }
    func contribute(to goalID: UUID, cents: Int) {
        guard cents > 0, let idx = goals.firstIndex(where: { $0.id == goalID }) else { return }
        goals[idx].currentCents += cents
        guard let context else { return }
        let desc = FetchDescriptor<SDSavingsGoal>(predicate: #Predicate { $0.id == goalID })
        if let sd = (try? context.fetch(desc))?.first {
            sd.currentCents += cents
            try? context.save()
        }
    }
    func deleteGoal(id: UUID) {
        goals.removeAll { $0.id == id }
        guard let context else { return }
        let desc = FetchDescriptor<SDSavingsGoal>(predicate: #Predicate { $0.id == id })
        for sd in (try? context.fetch(desc)) ?? [] { context.delete(sd) }
        try? context.save()
    }

    private static func source(for platform: ImportBatch.Platform) -> Transaction.Source {
        switch platform {
        case .alipay: .alipay
        case .wechat: .wechat
        case .cmb:    .cmb
        case .jd:     .jd
        case .meituan: .meituan
        case .douyin:  .douyin
        case .otherBank: .otherOCR
        }
    }
}
