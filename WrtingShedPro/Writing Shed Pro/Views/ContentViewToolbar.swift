//
//  ContentViewToolbar.swift
//  Writing Shed Pro
//
//  Extracted toolbar content for ContentView to improve compilation time
//

import SwiftUI

struct ContentViewToolbar: ToolbarContent {
    @Binding var showSettings: Bool
    @Binding var showAddProject: Bool
    @Binding var showAbout: Bool
    @Binding var showManageStyles: Bool
    @Binding var showPageSetup: Bool
    @Binding var showContactSupport: Bool
    @Binding var showDeleteAllConfirmation: Bool
    @Binding var showSyncDiagnostics: Bool
    @Binding var showImportMenu: Bool
    @Binding var selectedSortOrder: SortOrder
    @Binding var editMode: EditMode
    
    @State private var appearancePreferences = AppearancePreferences.shared
    let projects: [Project]
    
    var body: some ToolbarContent {
        // Settings menu (leading)
        ToolbarItem(placement: .navigationBarLeading) {
            Menu {
                Button(action: { showAbout = true }) {
                    Label("About Writing Shed Pro", systemImage: "info.circle")
                }
                
                Button(action: { showManageStyles = true }) {
                    Label("Stylesheet Editor", systemImage: "paintbrush")
                }
                
                Button(action: { showPageSetup = true }) {
                    Label("Page Setup", systemImage: "doc.richtext")
                }
                
                Button(action: { showImportMenu = true }) {
                    Label("Import", systemImage: "arrow.down.doc")
                }
                
                #if !targetEnvironment(macCatalyst)
                Menu {
                    ForEach(AppearanceMode.allCases) { mode in
                        Button(action: {
                            appearancePreferences.appearanceMode = mode
                        }) {
                            HStack {
                                Label(mode.displayName, systemImage: mode.icon)
                                if appearancePreferences.appearanceMode == mode {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Label("Appearance", systemImage: appearancePreferences.appearanceMode.icon)
                }
                #endif
                
                Divider()
                
                #if DEBUG
                Button(action: { showSyncDiagnostics = true }) {
                    Label("Sync Diagnostics", systemImage: "arrow.triangle.2.circlepath")
                }
                #endif
                
                Button(action: { showContactSupport = true }) {
                    Label("Contact Support", systemImage: "envelope")
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
                Button(role: .destructive, action: { showDeleteAllConfirmation = true }) {
                    Label("contentView.deleteAll", systemImage: "trash")
                }
                .accessibilityLabel("contentView.deleteAll.accessibility")
                #endif
                
                Button(action: { showAddProject = true }) {
                    Label(NSLocalizedString("contentView.addProject", comment: "Button to add new project"), systemImage: "plus")
                }
                .accessibilityLabel(NSLocalizedString("contentView.addProjectAccessibility", comment: "Accessibility label for add project button"))
                
                // Sort Menu
                Menu {
                    ForEach(ProjectSortService.sortOptions(), id: \.order) { option in
                        Button(action: {
                            selectedSortOrder = option.order
                        }) {
                            HStack {
                                Text(option.title)
                                if selectedSortOrder == option.order {
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
                            editMode = editMode == .inactive ? .active : .inactive
                        }
                    } label: {
                        Text(editMode == .inactive ? "Edit" : "Done")
                    }
                }
            }
        }
    }
}
