//
//  ContentViewState.swift
//  Writing Shed Pro
//
//  Consolidated state management for ContentView to improve compilation performance
//

import SwiftUI

@MainActor
final class ContentViewState: ObservableObject {
    // UI State
    @Published var showAddProject = false
    @Published var showManageStyles = false
    @Published var isImporting = false
    @Published var showingJSONImportPicker = false
    @Published var showImportError = false
    @Published var importErrorMessage = ""
    @Published var showDeleteAllConfirmation = false
    @Published var selectedSortOrder: SortOrder = .byName
    @Published var editMode: EditMode = .inactive
    
    // Settings menu sheets
    @Published var showAbout = false
    @Published var showPageSetup = false
    @Published var showContactSupport = false
    
    // Import options
    @Published var showImportOptions = false
    @Published var showLegacyProjectPicker = false
    @Published var availableLegacyProjects: [LegacyProjectData] = []
    
    // Debug
    @Published var showSyncDiagnostics = false
    
    // Appearance preferences
    @Published var appearancePreferences = AppearancePreferences.shared
    
    init() {}
}
