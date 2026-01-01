//
//  PoetryPreferences.swift
//  Writing Shed Pro
//
//  Global poetry feature preferences
//  Feature 021: Smart Poetry Creation
//

import Foundation
import Observation

/// Service for managing poetry feature preferences
/// Persisted in UserDefaults and syncs across app lifecycle
@Observable
final class PoetryPreferences {
    
    // MARK: - Keys
    
    private enum Keys {
        static let showMetricsBar = "poetry.showMetricsBar"
        static let showStressAnalysis = "poetry.showStressAnalysis"
        static let autoOpenFormReference = "poetry.autoOpenFormReference"
        static let showSyllableHints = "poetry.showSyllableHints"
    }
    
    // MARK: - Properties
    
    private let store = UserDefaults.standard
    
    /// Whether to show the metrics bar in the editor for Poetry projects
    /// Default: true
    var showMetricsBar: Bool {
        get { store.object(forKey: Keys.showMetricsBar) as? Bool ?? true }
        set { store.set(newValue, forKey: Keys.showMetricsBar) }
    }
    
    /// Whether to show stress pattern analysis (more detailed, can be toggled off for simplicity)
    /// Default: false (opt-in feature)
    var showStressAnalysis: Bool {
        get { store.object(forKey: Keys.showStressAnalysis) as? Bool ?? false }
        set { store.set(newValue, forKey: Keys.showStressAnalysis) }
    }
    
    /// Whether to automatically show form reference when creating a new poetry file
    /// Default: false
    var autoOpenFormReference: Bool {
        get { store.object(forKey: Keys.autoOpenFormReference) as? Bool ?? false }
        set { store.set(newValue, forKey: Keys.autoOpenFormReference) }
    }
    
    /// Whether to show inline syllable hints during editing
    /// Default: true
    var showSyllableHints: Bool {
        get { store.object(forKey: Keys.showSyllableHints) as? Bool ?? true }
        set { store.set(newValue, forKey: Keys.showSyllableHints) }
    }
    
    // MARK: - Singleton
    
    static let shared = PoetryPreferences()
    
    private init() {
        // Defaults are handled via nil-coalescing in getters
    }
    
    // MARK: - Reset
    
    /// Reset all poetry preferences to defaults
    func resetToDefaults() {
        store.removeObject(forKey: Keys.showMetricsBar)
        store.removeObject(forKey: Keys.showStressAnalysis)
        store.removeObject(forKey: Keys.autoOpenFormReference)
        store.removeObject(forKey: Keys.showSyllableHints)
    }
}
