import Foundation
import SwiftData

enum PersistenceController {

    /// Full schema — expand here when you add new @Model types.
    static let schema = Schema([
        SDTransaction.self,
        SDAccount.self,
        SDBudget.self,
        SDImportBatch.self,
        SDMerchantLearning.self,
        SDSubscription.self,
        SDSavingsGoal.self,
    ])

    /// CloudKit container identifier (Spec §8.2).
    /// Must match an iCloud Container on developer.apple.com configured against
    /// the signing team. The entitlement is declared in Glassbook.entitlements.
    static let cloudKitContainer = "iCloud.app.glassbook.ios"

    /// Disk-backed container with a 3-stage fallback:
    /// 1. CloudKit-synced SQLite (requires iCloud entitlement + signed-in team)
    /// 2. Local-only SQLite (always works)
    /// 3. In-memory (last resort — e.g., corrupt store on disk)
    static func makeDiskContainer(useCloudKit: Bool = true) -> ModelContainer {
        // Stage 1 · CloudKit
        if useCloudKit {
            let ckConfig = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .private(cloudKitContainer)
            )
            if let c = try? ModelContainer(for: schema, configurations: ckConfig) {
                print("☁️ Glassbook · SwiftData + CloudKit ready (\(cloudKitContainer))")
                return c
            }
            print("⚠️ CloudKit container unavailable (no team / entitlement mismatch). Falling back to local-only.")
        }

        // Stage 2 · Local SQLite
        let localConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        if let c = try? ModelContainer(for: schema, configurations: localConfig) {
            print("💾 Glassbook · SwiftData local-only ready")
            return c
        }
        print("⚠️ On-disk container failed. Falling back to in-memory.")

        // Stage 3 · In-memory
        return makeInMemoryContainer()
    }

    /// In-memory container for previews / tests.
    static func makeInMemoryContainer(seeded: Bool = true) -> ModelContainer {
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: config)
        if seeded { AppSeed.seed(context: ModelContext(container)) }
        return container
    }
}
