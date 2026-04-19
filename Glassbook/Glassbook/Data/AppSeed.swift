import Foundation
import SwiftData

enum AppSeed {
    /// Populate the given context with `SampleData` on first launch.
    /// Safe to call repeatedly — it no-ops if any transaction rows already exist.
    static func seed(context: ModelContext) {
        let descriptor = FetchDescriptor<SDTransaction>()
        let existingCount = (try? context.fetchCount(descriptor)) ?? 0
        guard existingCount == 0 else { return }

        for tx in SampleData.transactions {
            context.insert(SDTransaction(from: tx))
        }
        for acc in SampleData.accounts {
            context.insert(SDAccount(from: acc))
        }
        for sub in SampleData.subscriptions {
            context.insert(SDSubscription(from: sub))
        }
        for goal in SampleData.savingsGoals {
            context.insert(SDSavingsGoal(from: goal))
        }
        context.insert(SDBudget(from: .default))

        do {
            try context.save()
        } catch {
            print("⚠️ AppSeed save failed: \(error)")
        }
    }
}
