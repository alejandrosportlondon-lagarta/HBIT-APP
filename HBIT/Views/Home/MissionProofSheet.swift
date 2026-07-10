import MorningKit
import ProofKit
import SwiftData
import SwiftUI

/// Verifies a proof-attached mission (Pro): resolves the mission's
/// ProofReference and runs the matching proof UI. Cancelling is always
/// possible — missions are motivation, not captivity.
struct MissionProofSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let item: MissionSnapshotItem
    let onVerified: () -> Void

    var body: some View {
        NavigationStack {
            Group {
                switch resolvedProof() {
                case .barcode(let config):
                    BarcodeProofView(config: config) { onVerified() }
                case .photo(let config):
                    PhotoProofView(config: config) { onVerified() }
                default:
                    // Unresolvable reference: never hold the mission
                    // hostage to a broken payload.
                    VStack(spacing: DesignSystem.Spacing.md) {
                        Text("This mission's proof could not be loaded.")
                            .font(DesignSystem.Typography.body)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                        Button("Complete without proof") { onVerified() }
                            .buttonStyle(.borderedProminent)
                            .tint(DesignSystem.Colors.success)
                    }
                }
            }
            .padding(DesignSystem.Spacing.lg)
            .background(DesignSystem.Colors.background)
            .navigationTitle(item.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func resolvedProof() -> ActiveProof {
        guard let referenceID = item.proofReferenceID else { return .placeholder }
        var descriptor = FetchDescriptor<ProofReference>(predicate: #Predicate { $0.id == referenceID })
        descriptor.fetchLimit = 1
        guard let reference = try? modelContext.fetch(descriptor).first else { return .placeholder }
        switch reference.kind {
        case .barcode:
            return (try? BarcodeProofConfig.from(payload: reference.payload)).map(ActiveProof.barcode) ?? .placeholder
        case .photoMatch:
            return (try? PhotoProofConfig.from(payload: reference.payload)).map(ActiveProof.photo) ?? .placeholder
        case .math, .steps:
            return .placeholder
        }
    }
}
