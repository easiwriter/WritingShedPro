//
//  AppearancePreferences.swift
//  Writing Shed Pro
//
//  Manages appearance mode preferences (light/dark mode)
//

import SwiftUI

/// Manages user appearance mode preferences
@Observable
class AppearancePreferences {
    
    // MARK: - Singleton
    
    static let shared = AppearancePreferences()
    
    // MARK: - Properties
    
    /// Current appearance mode setting
    var appearanceMode: AppearanceMode {
        didSet {
            savePreference()
        }
    }
    
    // MARK: - Initialization
    
    private init() {
        // Load saved preference
        if let rawValue = UserDefaults.standard.string(forKey: "AppearanceMode"),
           let mode = AppearanceMode(rawValue: rawValue) {
            self.appearanceMode = mode
        } else {
            self.appearanceMode = .system
        }
    }
    
    // MARK: - Persistence
    
    private func savePreference() {
        UserDefaults.standard.set(appearanceMode.rawValue, forKey: "AppearanceMode")
        #if DEBUG
        print("💡 Saved appearance mode: \(appearanceMode.rawValue)")
        #endif
    }
    
    // MARK: - Computed Properties
    
    /// Get the ColorScheme for the current preference
    var colorScheme: ColorScheme? {
        switch appearanceMode {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

// MARK: - Appearance Mode Enum

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .system:
            return "System"
        case .light:
            return "Light Mode"
        case .dark:
            return "Dark Mode"
        }
    }
    
    var icon: String {
        switch self {
        case .system:
            return "circle.lefthalf.filled"
        case .light:
            return "sun.max"
        case .dark:
            return "moon"
        }
    }
}
