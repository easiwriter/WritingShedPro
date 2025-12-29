//
//  ContentViewState.swift
//  Writing Shed Pro
//
//  Consolidated state management for ContentView to improve compilation performance
//

import SwiftUI
import Observation

@MainActor
@Observable
final class ContentViewState {
    // Navigation
    var navigationPath = NavigationPath()
    
    // UI State
    var showAddProject = false
    var showManageStyles = false
    var isImporting = false
    var showingJSONImportPicker = false
    var showImportError = false
    var importErrorMessage = ""
    var showDeleteAllConfirmation = false
    var selectedSortOrder: SortOrder = .byName
    var editMode: EditMode = .inactive
    
    // Settings menu sheets
    var showAbout = false
    var projectForPageSetup: Project? // Tracks which project's page setup to show
    var showContactSupport = false
    
    // Debug
    var showSyncDiagnostics = false
    
    // Appearance preferences
    var appearancePreferences = AppearancePreferences.shared
    
    init() {}
}
