import Foundation
import SwiftData
import ProofKit
import SyncKit

/// A mission in the user's configured morning list (3–5 items). The list is
/// snapshotted into `Morning.missionsSnapshot` when the goal lock engages;
/// this model is the editable template between mornings.
@Model
final class Mission {
    @Attribute(.unique) var id: UUID
    var title: String
    /// Template key: "water", "pushups", "read", "no_phone" or "custom".
    var template: String
    /// Pro: an attached proof requirement (barcode or photo). Nil = plain
    /// check-off mission.
    private var proofTypeRaw: String?
    var proofReferenceID: UUID?
    /// Order within the morning list.
    var position: Int
    var isActive: Bool
    private var syncStatusRaw: String
    var createdAt: Date
    var updatedAt: Date

    var proofType: ProofType? {
        get { proofTypeRaw.flatMap(ProofType.init(rawValue:)) }
        set { proofTypeRaw = newValue?.rawValue }
    }

    var syncStatus: SyncStatus {
        get { SyncStatus(rawValue: syncStatusRaw) ?? .pending }
        set { syncStatusRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        title: String,
        template: String = "custom",
        proofType: ProofType? = nil,
        proofReferenceID: UUID? = nil,
        position: Int,
        isActive: Bool = true,
        syncStatus: SyncStatus = .pending,
        now: Date = .now
    ) {
        self.id = id
        self.title = title
        self.template = template
        self.proofTypeRaw = proofType?.rawValue
        self.proofReferenceID = proofReferenceID
        self.position = position
        self.isActive = isActive
        self.syncStatusRaw = syncStatus.rawValue
        self.createdAt = now
        self.updatedAt = now
    }
}
