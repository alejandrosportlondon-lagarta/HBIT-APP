import MorningKit
import ProofKit
import SwiftData
import SwiftUI

/// Edit the morning mission list (3–5 items): templates or custom, reorder,
/// delete, and (Pro) attach a barcode/photo proof to any mission. Editing
/// is blocked while the goal lock is engaged.
struct MissionEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AlarmCoordinator.self) private var coordinator
    @Query(sort: \Mission.position) private var missions: [Mission]

    @State private var customTitle = ""
    @State private var attachingProofTo: Mission?
    @State private var registeringBarcode = false
    @State private var registeringPhoto = false

    private var active: [Mission] { missions.filter(\.isActive) }
    private var isLocked: Bool {
        if case .open = coordinator.goalLockPhase() { return false }
        return true
    }

    var body: some View {
        NavigationStack {
            List {
                if isLocked {
                    Text("Goal locked — the mission list can't change until this morning closes.")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.accent)
                }

                Section("Missions (\(active.count) of 3–5)") {
                    ForEach(active) { mission in
                        missionRow(mission)
                    }
                    .onDelete { offsets in delete(at: offsets) }
                    .onMove { source, destination in move(from: source, to: destination) }
                }
                .disabled(isLocked)

                if active.count < MissionRules.morningListRange.upperBound && !isLocked {
                    Section("Add") {
                        ForEach(MissionTemplate.allCases.filter { $0 != .custom }, id: \.self) { template in
                            Button(template.defaultTitle) { add(template: template) }
                        }
                        HStack {
                            TextField("Custom mission", text: $customTitle)
                            Button("Add") { addCustom() }
                                .disabled(customTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                }
            }
            .navigationTitle("Morning missions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .primaryAction) { EditButton() }
            }
            .sheet(isPresented: $registeringBarcode) {
                BarcodeRegistrationView { payload, symbology in
                    attachProof(kind: .barcode, payload: try? BarcodeProofConfig(
                        payload: payload, symbology: symbology
                    ).payloadData())
                }
            }
            .sheet(isPresented: $registeringPhoto) {
                PhotoRegistrationView { photoConfig in
                    attachProof(kind: .photoMatch, payload: try? photoConfig.payloadData())
                }
            }
        }
    }

    private func missionRow(_ mission: Mission) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(mission.title)
                if let kind = mission.proofType {
                    Text("Proof: \(kind.rawValue) ⭐")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                }
            }
            Spacer()
            Menu {
                Button("Attach barcode proof ⭐") {
                    attachingProofTo = mission
                    registeringBarcode = true
                }
                Button("Attach photo proof ⭐") {
                    attachingProofTo = mission
                    registeringPhoto = true
                }
                if mission.proofType != nil {
                    Button("Remove proof", role: .destructive) { removeProof(from: mission) }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }

    private func add(template: MissionTemplate) {
        insertMission(title: template.defaultTitle, template: template.rawValue)
    }

    private func addCustom() {
        let title = customTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }
        insertMission(title: title, template: MissionTemplate.custom.rawValue)
        customTitle = ""
    }

    private func insertMission(title: String, template: String) {
        guard active.count < MissionRules.morningListRange.upperBound else { return }
        let mission = Mission(title: title, template: template, position: (active.last?.position ?? -1) + 1)
        modelContext.insert(mission)
    }

    private func delete(at offsets: IndexSet) {
        let current = active
        for index in offsets where current.indices.contains(index) {
            modelContext.delete(current[index])
        }
        renumber()
    }

    private func move(from source: IndexSet, to destination: Int) {
        var current = active
        current.move(fromOffsets: source, toOffset: destination)
        for (index, mission) in current.enumerated() {
            mission.position = index
        }
    }

    private func renumber() {
        for (index, mission) in active.enumerated() {
            mission.position = index
        }
    }

    private func attachProof(kind: ProofType, payload: Data?) {
        guard let mission = attachingProofTo, let payload else { return }
        let reference = ProofReference(kind: kind, payload: payload)
        modelContext.insert(reference)
        mission.proofType = kind
        mission.proofReferenceID = reference.id
        mission.updatedAt = .now
        attachingProofTo = nil
    }

    private func removeProof(from mission: Mission) {
        mission.proofType = nil
        mission.proofReferenceID = nil
        mission.updatedAt = .now
    }
}
