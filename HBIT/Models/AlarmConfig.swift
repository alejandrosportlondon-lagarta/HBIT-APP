import Foundation
import SwiftData
import ProofKit

/// The user's alarm configuration (free tier: exactly one). Wall-clock time
/// plus timezone identifier — scheduling always happens in the user's
/// timezone, and concrete fire dates are computed (in UTC) per occurrence
/// by the AlarmEngine, which owns DST correctness.
@Model
final class AlarmConfig {
    @Attribute(.unique) var id: UUID
    var hour: Int
    var minute: Int
    /// IANA timezone identifier the wall-clock time is anchored to.
    var timeZoneID: String
    private var proofTypeRaw: String
    var proofReferenceID: UUID?
    var isEnabled: Bool
    var soundName: String
    var createdAt: Date
    var updatedAt: Date

    var proofType: ProofType {
        get { ProofType(rawValue: proofTypeRaw) ?? .math }
        set { proofTypeRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        hour: Int,
        minute: Int,
        timeZoneID: String = TimeZone.current.identifier,
        proofType: ProofType = .math,
        proofReferenceID: UUID? = nil,
        isEnabled: Bool = true,
        soundName: String = "default",
        now: Date = .now
    ) {
        self.id = id
        self.hour = hour
        self.minute = minute
        self.timeZoneID = timeZoneID
        self.proofTypeRaw = proofType.rawValue
        self.proofReferenceID = proofReferenceID
        self.isEnabled = isEnabled
        self.soundName = soundName
        self.createdAt = now
        self.updatedAt = now
    }
}
