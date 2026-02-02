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
    var showSettings = false  // Settings sheet
    var isImporting = false
    var showingJSONImportPicker = false
    var showImportError = false
    var importErrorMessage = ""
    var showDeleteAllConfirmation = false
    
    // Sort order - stored property that syncs with UserDefaults for persistence
    private static let sortOrderKey = "projectSortOrder"
    var selectedSortOrder: SortOrder {
        didSet {
            UserDefaults.standard.set(selectedSortOrder.rawValue, forKey: Self.sortOrderKey)
        }
    }
    
    var editMode: EditMode = .inactive
    
    // Settings menu sheets
    var showAbout = false
    var projectForPageSetup: Project? // Tracks which project's page setup to show
    var showContactSupport = false
    
    // Help & Manual
    var showHTMLManual = false
    var showManualImportConfirmation = false
    var showManualImportError = false
    var manualImportErrorMessage = ""
    
    // Debug
    var showSyncDiagnostics = false
    
    // Store
    var showStore = false
    
    // Appearance preferences
    var appearancePreferences = AppearancePreferences.shared
    
    // Poetry preferences (observed for UI updates)
    var poetryPreferences = PoetryPreferences.shared
    
    init() {
        // Load saved sort order from UserDefaults
        if let rawValue = UserDefaults.standard.string(forKey: Self.sortOrderKey),
           let order = SortOrder(rawValue: rawValue) {
            self.selectedSortOrder = order
        } else {
            self.selectedSortOrder = .byName
        }
    }
}
