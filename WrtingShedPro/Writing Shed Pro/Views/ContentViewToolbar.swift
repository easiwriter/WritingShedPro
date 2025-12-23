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
    
    var body: some ToolbarContent {
        // Settings menu (leading)
        ToolbarItem(placement: .navigationBarLeading) {
            Menu {
                Button(action: { state.showAbout = true }) {
                    Label("About Writing Shed Pro", systemImage: "info.circle")
                }
                
                Button(action: { state.showManageStyles = true }) {
                    Label("Stylesheet Editor", systemImage: "paintbrush")
                }
                
                Button(action: { onHandleImportMenu() }) {
                    Label("Import", systemImage: "arrow.down.doc")
                }
                
                #if !targetEnvironment(macCatalyst)
                Menu {
                    ForEach(AppearanceMode.allCases) { mode in
                        Button(action: {
                            state.appearancePreferences.appearanceMode = mode
                        }) {
                            HStack {
                                Label(mode.displayName, systemImage: mode.icon)
                                if state.appearancePreferences.appearanceMode == mode {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Label("Appearance", systemImage: state.appearancePreferences.appearanceMode.icon)
                }
                #endif
                
                Divider()
                
                Button(action: { state.showSyncDiagnostics = true }) {
                    Label("Sync Diagnostics", systemImage: "arrow.triangle.2.circlepath")
                }
                
                Button(action: { state.showContactSupport = true }) {
                    Label("Contact Support", systemImage: "envelope")
                }
                
                Button(action: { 
                    Task {
                        ReviewManager.shared.requestReviewManually()
                        await MainActor.run {
                            requestReview()
                        }
                    }
                }) {
                    Label("Rate This App", systemImage: "star.fill")
                }
            } label: {
                Image(systemName: "gearshape")
            }
            .accessibilityLabel("Settings")
        }
        
        // Action buttons (trailing)
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack(spacing: 16) {
                #if DEBUG && (targetEnvironment(macCatalyst) || os(macOS))
                Button(role: .destructive, action: { state.showDeleteAllConfirmation = true }) {
                    Label("contentView.deleteAll", systemImage: "trash")
                }
                .accessibilityLabel("contentView.deleteAll.accessibility")
                #endif
                
                Button(action: { state.showAddProject = true }) {
                    Label(NSLocalizedString("contentView.addProject", comment: "Button to add new project"), systemImage: "plus")
                }
                .accessibilityLabel(NSLocalizedString("contentView.addProjectAccessibility", comment: "Accessibility label for add project button"))
                
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
