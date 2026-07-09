import Foundation
import SwiftData
import ProofKit
import SyncKit

/// A registered proof target: the barcode payload, reference-photo feature
/// print, or math/steps configuration an alarm (or Pro mission) verifies
/// against. Payload is opaque JSON owned by ProofKit — verification must
/// work fully offline, so everything needed lives in this record.
@Model
final class ProofReference {
    @Attribute(.unique) var id: UUID
    private var kindRaw: String
    var payload: Data
    private var syncStatusRaw: String
    var createdAt: Date
    var updatedAt: Date

    var kind: ProofType {
        get { ProofType(rawValue: kindRaw) ?? .math }
        set { kindRaw = newValue.rawValue }
    }

    var syncStatus: SyncStatus {
        get { SyncStatus(rawValue: syncStatusRaw) ?? .pending }
        set { syncStatusRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        kind: ProofType,
        payload: Data = Data("{}".utf8),
        syncStatus: SyncStatus = .pending,
        now: Date = .now
    ) {
        self.id = id
        self.kindRaw = kind.rawValue
        self.payload = payload
        self.syncStatusRaw = syncStatus.rawValue
        self.createdAt = now
        self.updatedAt = now
    }
}
