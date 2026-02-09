//
//  ContentViewToolbar.swift
//  Writing Shed Pro
//
//  Extracted toolbar content for ContentView to improve compilation time
//

import SwiftUI
import TipKit

struct ContentViewToolbar: ToolbarContent {
    var state: ContentViewState
    let projects: [Project]
    let onHandleImportMenu: () -> Void
    
    @Environment(\.requestReview) var requestReview
    
    /// Poetry preferences accessed via state for proper observation in ToolbarContent
    private var poetryPrefs: PoetryPreferences { state.poetryPreferences }
    
    var body: some ToolbarContent {
        // Action buttons (trailing)
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack(spacing: 16) {
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
                
                #if DEBUG && (targetEnvironment(macCatalyst) || os(macOS))
                Button(role: .destructive, action: { state.showDeleteAllConfirmation = true }) {
                    Label("contentView.deleteAll", systemImage: "trash")
                }
                .accessibilityLabel("contentView.deleteAll.accessibility")
                .disabled(state.editMode == .active)
                #endif
                
                Button(action: { state.showAddProject = true }) {
                    Label(NSLocalizedString("contentView.addProject", comment: "Button to add new project"), systemImage: "plus")
                        .popoverTip(CreateProjectTip()) { action in
                            TipActionHandler.handle(action, guideSection: CreateProjectTip.guideSection)
                        }
                }
                .accessibilityLabel(NSLocalizedString("contentView.addProjectAccessibility", comment: "Accessibility label for add project button"))
                .disabled(state.editMode == .active)
                
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
                }
            }
        }
    }
}
