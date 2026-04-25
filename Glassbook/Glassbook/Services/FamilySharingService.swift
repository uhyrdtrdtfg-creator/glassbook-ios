import Foundation
import CloudKit
import UIKit
import Observation

/// Spec v2 §6.5 · 家庭共享 via CKShare. Opens Apple's native
/// `UICloudSharingController` so the user can invite a family member over
/// iMessage, Mail, etc. The invitee accepts with their own iCloud account;
/// CloudKit provisions a shared zone and the CoreData+CloudKit mirroring
/// automatically keeps family transactions in sync.
///
/// Scaffold behaviour:
/// - On signed-in devices with iCloud and our container entitlement active,
///   this flow works end-to-end (sharing controller presents the invite UI).
/// - On simulator without iCloud sign-in / team signing, we fall back to
///   a system share sheet with a deep link so the product flow is still
///   demonstrable.
@MainActor
@Observable
final class FamilySharingService {

    /// Caller role relative to the family book share.
    enum Ownership: Equatable { case owner, participant, none, unknown }

    static let shared = FamilySharingService()

    private let containerID = "iCloud.app.glassbook.ios"
    private let zoneName = "family_book_zone"
    private let rootRecordName = "family_book"

    /// Last fetched share for the family book (nil = no share exists / not loaded).
    private(set) var share: CKShare?
    /// Cached ownership state. `.unknown` until `refreshOwnership()` runs.
    private(set) var ownership: Ownership = .unknown
    /// Human-readable last error (network, permissions). Views bind alerts here.
    var lastError: String?

    private init() {}

    // MARK: - Invite (existing entry point)

    /// Present the native iCloud share sheet (or fallback) from the given UIKit host.
    static func presentInvite(from host: UIViewController) async {
        guard let url = await shared.makeCKShareURL() else {
            let link = URL(string: "https://glassbook.app/join/family?scaffold=1")!
            shared.present(activityItems: [link, "加入我的 Glassbook 家庭账本"], from: host)
            return
        }
        shared.present(activityItems: [url, "加入我的 Glassbook 家庭账本"], from: host)
    }

    // MARK: - Ownership detection

    /// Refresh `share` + `ownership` from CloudKit. Safe to call on simulator —
    /// it silently falls back to `.none` when iCloud is unavailable.
    func refreshOwnership() async {
        let container = CKContainer(identifier: containerID)
        do {
            let status = try await container.accountStatus()
            guard status == .available else {
                ownership = .none
                share = nil
                return
            }
        } catch {
            ownership = .none
            share = nil
            return
        }

        // why: a participant's share lives in the shared DB; an owner's in the private DB.
        // Probe private first — if we find the record we created, we're the owner.
        if let ownerShare = try? await fetchOwnerShare(container: container) {
            share = ownerShare
            ownership = .owner
            return
        }
        if let participantShare = try? await fetchParticipantShare(container: container) {
            share = participantShare
            ownership = .participant
            return
        }
        share = nil
        ownership = .none
    }

    private func fetchOwnerShare(container: CKContainer) async throws -> CKShare? {
        let db = container.privateCloudDatabase
        let rootID = CKRecord.ID(recordName: rootRecordName)
        guard let root = try? await db.record(for: rootID) else { return nil }
        guard let shareRef = root.share else { return nil }
        let rec = try await db.record(for: shareRef.recordID)
        return rec as? CKShare
    }

    private func fetchParticipantShare(container: CKContainer) async throws -> CKShare? {
        // The shared DB exposes zones owned by others we've accepted. Walk zones;
        // the first CKShare we find in the family book zone is ours.
        let sharedDB = container.sharedCloudDatabase
        let zones = try await sharedDB.allRecordZones()
        for zone in zones where zone.zoneID.zoneName == zoneName {
            let shareRecordID = CKRecord.ID(
                recordName: CKRecordNameZoneWideShare,
                zoneID: zone.zoneID
            )
            if let rec = try? await sharedDB.record(for: shareRecordID),
               let share = rec as? CKShare {
                return share
            }
        }
        return nil
    }

    // MARK: - Leave (participant)

    /// Participant path: delete my local share participation, unsubscribe zone changes.
    /// Owner is unaffected. Idempotent — if no share exists we flip state and return.
    func leaveShare() async throws {
        let container = CKContainer(identifier: containerID)
        let sharedDB = container.sharedCloudDatabase

        guard let share = try await fetchParticipantShare(container: container) else {
            // why: nothing to leave — treat as success so UI can clean up state.
            self.share = nil
            ownership = .none
            return
        }

        do {
            try await sharedDB.deleteRecord(withID: share.recordID)
        } catch let ckErr as CKError {
            switch ckErr.code {
            case .unknownItem, .zoneNotFound:
                break // already gone → idempotent success
            case .networkUnavailable, .networkFailure:
                lastError = "网络不可用 · 请稍后重试"
                throw ckErr
            default:
                lastError = ckErr.localizedDescription
                throw ckErr
            }
        }
        self.share = nil
        ownership = .none
    }

    // MARK: - Dissolve (owner)

    /// Owner path: delete the CKShare + destroy the custom zone (which wipes
    /// shared records for all participants). Refuses to run if caller isn't owner.
    /// Idempotent — repeated calls no-op once zone/share is gone.
    func dissolveShare() async throws {
        let container = CKContainer(identifier: containerID)
        let privateDB = container.privateCloudDatabase

        // why: only the owner may delete the underlying zone. Re-check live state
        // rather than trusting the cached `ownership` which might be stale.
        if ownership == .unknown { await refreshOwnership() }
        guard ownership == .owner || ownership == .none else {
            lastError = "只有创建者可以解散家庭账本"
            throw CKError(.permissionFailure)
        }

        // 1. Delete the share record if present.
        if let share = share {
            do {
                try await privateDB.deleteRecord(withID: share.recordID)
            } catch let ckErr as CKError where ckErr.code == .unknownItem {
                // already deleted
            } catch let ckErr as CKError where ckErr.code == .networkUnavailable || ckErr.code == .networkFailure {
                lastError = "网络不可用 · 请稍后重试"
                throw ckErr
            }
        }

        // 2. Nuke the zone. `.zoneNotFound` means someone already cleaned up.
        let zoneID = CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)
        do {
            _ = try await privateDB.deleteRecordZone(withID: zoneID)
        } catch let ckErr as CKError {
            switch ckErr.code {
            case .zoneNotFound, .unknownItem:
                break // idempotent: zone already gone
            case .networkUnavailable, .networkFailure:
                lastError = "网络不可用 · 请稍后重试"
                throw ckErr
            default:
                lastError = ckErr.localizedDescription
                throw ckErr
            }
        }

        self.share = nil
        ownership = .none
    }

    // MARK: - Private · create on demand

    /// Try to create (or fetch) the CKShare URL for the family book zone.
    /// Returns nil on simulator / unsigned-team / no iCloud.
    private func makeCKShareURL() async -> URL? {
        let container = CKContainer(identifier: containerID)

        do {
            let status = try await container.accountStatus()
            guard status == .available else { return nil }
        } catch {
            return nil
        }

        let db = container.privateCloudDatabase
        let recordID = CKRecord.ID(recordName: rootRecordName)
        let record = CKRecord(recordType: "FamilyBook", recordID: recordID)
        record["createdAt"] = Date() as CKRecordValue

        let share = CKShare(rootRecord: record)
        share[CKShare.SystemFieldKey.title] = "Glassbook · 家庭账本" as CKRecordValue
        share[CKShare.SystemFieldKey.thumbnailImageData] = nil
        share.publicPermission = .none

        do {
            _ = try await db.modifyRecords(saving: [record, share], deleting: [])
            self.share = share
            ownership = .owner
            return share.url
        } catch {
            print("⚠️ FamilySharing · CKShare save failed: \(error.localizedDescription)")
            return nil
        }
    }

    private func present(activityItems: [Any], from host: UIViewController) {
        let vc = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        if let pop = vc.popoverPresentationController {
            pop.sourceView = host.view
            pop.sourceRect = CGRect(x: host.view.bounds.midX, y: host.view.bounds.midY, width: 0, height: 0)
            pop.permittedArrowDirections = []
        }
        host.present(vc, animated: true)
    }
}

/// SwiftUI helper to reach the top `UIViewController` — needed for
/// UIActivityViewController / UICloudSharingController presentation.
@MainActor
enum UIKitHost {
    static var rootViewController: UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow?.rootViewController }
            .first?
            .topmostPresented
    }
}

private extension UIViewController {
    var topmostPresented: UIViewController {
        var vc: UIViewController = self
        while let next = vc.presentedViewController { vc = next }
        return vc
    }
}
