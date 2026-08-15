//
//  ActPickerSheet.swift
//  Writing Shed Pro
//
//  Sheet for selecting an act to assign scenes to
//

import SwiftUI
import SwiftData

/// Sheet for picking an act to assign selected scenes to
struct ActPickerSheet: View {
    
    // MARK: - Environment
    
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Properties
    
    let project: Project
    let selectedScenes: [StoryScene]
    let onAssign: (Act?) -> Void
    let onCancel: () -> Void
    
    // MARK: - Computed
    
    private var sortedActs: [Act] {
        (project.acts ?? []).sorted(by: ContainerDisplayOrder.isOrdered)
    }
    
    /// Check if all selected scenes are assigned to the same act
    private var assignedAct: Act? {
        // Get the act of the first scene
        guard let firstAct = selectedScenes.first?.act else { return nil }
        // Check if all scenes are assigned to the same act
        let allSameAct = selectedScenes.allSatisfy { $0.act?.id == firstAct.id }
        return allSameAct ? firstAct : nil
    }
    
    /// Check if any selected scene is currently assigned to an act
    private var anyScenesAssignedToAct: Bool {
        selectedScenes.contains { $0.act != nil }
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            List {
                // If all scenes are assigned to the same act, only show remove option
                if let act = assignedAct {
                    Section {
                        Button {
                            onAssign(nil)
                        } label: {
                            HStack {
                                Image(systemName: "minus.circle")
                                    .foregroundColor(.red)
                                Text(String(format: NSLocalizedString("drama.scenes.removeFromActNamed", comment: "Remove from Act X"), act.name ?? NSLocalizedString("drama.untitled", comment: "Untitled")))
                                    .foregroundColor(.primary)
                            }
                        }
                    } header: {
                        Text(NSLocalizedString("drama.scenes.currentAssignment", comment: "Current Assignment"))
                    } footer: {
                        Text(String(format: NSLocalizedString("drama.scenes.assignedToAct", comment: "Assigned to act"), act.name ?? NSLocalizedString("drama.untitled", comment: "Untitled")))
                    }
                } else {
                    // Scenes are unassigned - show list of acts to assign to
                    Section {
                        if sortedActs.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "theatermasks")
                                    .font(.system(size: 40))
                                    .foregroundColor(.secondary)
                                
                                Text(NSLocalizedString("drama.acts.empty.title", comment: "No Acts Yet"))
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                
                                Text(NSLocalizedString("drama.acts.picker.createHint", comment: "Create acts in the Acts folder"))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                        } else {
                            ForEach(sortedActs) { act in
                                Button {
                                    onAssign(act)
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            if let userOrder = act.userOrder {
                                                Text(String(format: NSLocalizedString("drama.act.number", comment: "Act X"), userOrder + 1))
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            Text(act.name ?? NSLocalizedString("drama.untitled", comment: "Untitled"))
                                                .foregroundColor(.primary)
                                        }
                                        
                                        Spacer()
                                        
                                        // Show scene count in this act
                                        let sceneCount = act.scenes?.count ?? 0
                                        Text("\(sceneCount)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color(.secondarySystemBackground))
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                        }
                    } header: {
                        Text(NSLocalizedString("drama.acts.title", comment: "Acts"))
                    } footer: {
                        if !sortedActs.isEmpty {
                            Text(String(format: NSLocalizedString("drama.scenes.assignCount", comment: "Assign count"), selectedScenes.count))
                        }
                    }
                }
            }
            .navigationTitle(assignedAct != nil ? NSLocalizedString("drama.scenes.actAssignment", comment: "Act Assignment") : NSLocalizedString("drama.scenes.addToAct", comment: "Add to Act"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("button.cancel", comment: "Cancel")) {
                        onCancel()
                        dismiss()
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}
