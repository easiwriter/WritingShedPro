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
    private static let hideAllProjectsKey = "hideAllProjectsForDemos"
    private static let hiddenProjectIDsKey = "hiddenProjectIDsForDemos"
    private static let resumeLastOpenedProjectKey = "resumeLastOpenedProjectOnLaunch"
    private static let lastOpenedProjectIDKey = "lastOpenedProjectID"

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
    var htmlManualSection: String? = nil  // Anchor to scroll to in the HTML guide

    // Demo mode
    private(set) var hiddenProjectIDs: Set<UUID> {
        didSet {
            let encoded = hiddenProjectIDs.map(\.uuidString)
            UserDefaults.standard.set(encoded, forKey: Self.hiddenProjectIDsKey)
            // Keep legacy key in sync so old flows don't regress.
            UserDefaults.standard.set(!hiddenProjectIDs.isEmpty, forKey: Self.hideAllProjectsKey)
        }
    }

    var hideAllProjects: Bool {
        !hiddenProjectIDs.isEmpty
    }

    var shouldResumeLastOpenedProjectOnLaunch: Bool {
        didSet {
            UserDefaults.standard.set(shouldResumeLastOpenedProjectOnLaunch, forKey: Self.resumeLastOpenedProjectKey)
        }
    }

    var lastOpenedProjectID: UUID? {
        didSet {
            if let lastOpenedProjectID {
                UserDefaults.standard.set(lastOpenedProjectID.uuidString, forKey: Self.lastOpenedProjectIDKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.lastOpenedProjectIDKey)
            }
        }
    }

    
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

        if let storedHiddenIDs = UserDefaults.standard.array(forKey: Self.hiddenProjectIDsKey) as? [String] {
            self.hiddenProjectIDs = Set(storedHiddenIDs.compactMap(UUID.init(uuidString:)))
        } else {
            self.hiddenProjectIDs = []
        }

        self.shouldResumeLastOpenedProjectOnLaunch = UserDefaults.standard.bool(forKey: Self.resumeLastOpenedProjectKey)
        if let storedProjectID = UserDefaults.standard.string(forKey: Self.lastOpenedProjectIDKey),
           let projectID = UUID(uuidString: storedProjectID) {
            self.lastOpenedProjectID = projectID
        } else {
            self.lastOpenedProjectID = nil
        }
    }

    func rememberOpenedProject(_ project: Project) {
        lastOpenedProjectID = project.id
        shouldResumeLastOpenedProjectOnLaunch = true
    }

    func showProject(_ project: Project, rememberForResume: Bool = true) {
        if rememberForResume {
            rememberOpenedProject(project)
        }

        var newPath = NavigationPath()
        newPath.append(project)
        navigationPath = newPath
    }

    func clearProjectResumeBehavior() {
        shouldResumeLastOpenedProjectOnLaunch = false
    }

    func hideExistingProjects(from projects: [Project]) {
        hiddenProjectIDs = Set(projects.filter { !$0.isTrashed }.map(\.id))
    }

    func showAllProjects() {
        hiddenProjectIDs.removeAll()
    }

    func toggleProjectVisibilityMode(using projects: [Project]) {
        if hideAllProjects {
            showAllProjects()
        } else {
            hideExistingProjects(from: projects)
        }
    }

    func isProjectHidden(_ projectID: UUID) -> Bool {
        hiddenProjectIDs.contains(projectID)
    }
}
