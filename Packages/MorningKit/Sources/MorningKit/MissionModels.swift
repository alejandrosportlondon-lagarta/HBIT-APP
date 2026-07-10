import Foundation

/// Built-in mission templates (raw values match the `missions.template`
/// column and the snapshot JSON).
public enum MissionTemplate: String, Codable, CaseIterable, Sendable {
    case water
    case pushups
    case read
    case noPhone = "no_phone"
    case custom

    public var defaultTitle: String {
        switch self {
        case .water: "Drink a glass of water"
        case .pushups: "Do 10 push-ups"
        case .read: "Read 5 pages"
        case .noPhone: "No phone for 30 minutes"
        case .custom: "Custom mission"
        }
    }
}

public enum MissionRules {
    /// The morning mission list is 3–5 items (product spec).
    public static let morningListRange = 3...5
}

/// One mission as locked into a morning's snapshot (`Morning.missionsSnapshot`
/// locally, `mornings.missions` jsonb remotely). Proof attachment is kept as
/// raw values so MorningKit stays independent of ProofKit.
public struct MissionSnapshotItem: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public let title: String
    public let template: String
    /// Raw `ProofType` when the mission is proof-attached (Pro), else nil.
    public let proofKind: String?
    public let proofReferenceID: UUID?
    public var completedAt: Date?

    public var isCompleted: Bool { completedAt != nil }
    public var requiresProof: Bool { proofKind != nil }

    public init(
        id: UUID,
        title: String,
        template: String,
        proofKind: String? = nil,
        proofReferenceID: UUID? = nil,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.template = template
        self.proofKind = proofKind
        self.proofReferenceID = proofReferenceID
        self.completedAt = completedAt
    }

    public static func encode(_ items: [MissionSnapshotItem]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(items)
    }

    public static func decode(_ data: Data) -> [MissionSnapshotItem] {
        (try? JSONDecoder().decode([MissionSnapshotItem].self, from: data)) ?? []
    }
}
