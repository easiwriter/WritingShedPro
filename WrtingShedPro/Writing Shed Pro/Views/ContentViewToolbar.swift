//
//  ContentViewToolbar.swift
//  Writing Shed Pro
//
//  Extracted toolbar content for ContentView to improve compilation time
//

import SwiftUI

struct ContentViewToolbar: ToolbarContent {
    var state: ContentViewState
    let projects: [Project]
    let onHandleImportMenu: () -> Void
    
    @Environment(\.requestReview) var requestReview
    private var entitlementManager: EntitlementManager { .shared }
    
    /// Poetry preferences accessed via state for proper observation in ToolbarContent
    private var poetryPrefs: PoetryPreferences { state.poetryPreferences }
    
    init(state: ContentViewState, projects: [Project], onHandleImportMenu: @escaping () -> Void) {
        self.state = state
        self.projects = projects
        self.onHandleImportMenu = onHandleImportMenu
    }
    
    var body: some ToolbarContent {
        // Action buttons (trailing)
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack(spacing: 16) {
                if let trialStatusText = entitlementManager.trialStatusText {
                    Button {
                        state.showStore = true
                    } label: {
                        Label(
                            trialStatusText,
                            systemImage: entitlementManager.isCoreReadOnly ? "lock.fill" : "clock"
                        )
                        .font(.caption)
                    }
                    .accessibilityHint(NSLocalizedString("iap.trial.status.accessibilityHint", comment: "Open Full Access purchase screen"))
                }

                // Settings button - opens settings sheet
                Button {
                    state.showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("Settings")
                
                // Help button - opens HTML manual
                Button(action: {
                    state.showHTMLManual = true
                }) {
                    Image(systemName: "questionmark.circle")
                }
                .accessibilityLabel("Help")
                
                Button(action: { state.showAddProject = true }) {
                    Label(NSLocalizedString("contentView.addProject", comment: "Button to add new project"), systemImage: "plus")
                }
                .accessibilityLabel(NSLocalizedString("contentView.addProjectAccessibility", comment: "Accessibility label for add project button"))
                .disabled(state.editMode == .active || !entitlementManager.canModifyContent)
                
                // Sort Menu
                Menu {
                    ForEach(ProjectSortService.sortOptions(), id: \.order) { option in
                        Button(action: {
                            state.selectedSortOrder = option.order
                        }) {
                            HStack {
                                Text(option.title)
                                if state.selectedSortOrder == option.order {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
                .disabled(state.editMode == .active)
                
                // Edit/Done button
                if !projects.isEmpty {
                    Button {
                        withAnimation {
                            state.editMode = state.editMode == .inactive ? .active : .inactive
                        }
                    } label: {
                        Text(state.editMode == .inactive ? "Edit" : "Done")
                    }
                    .disabled(!entitlementManager.canModifyContent)
                }
            }
        }
    }
}
