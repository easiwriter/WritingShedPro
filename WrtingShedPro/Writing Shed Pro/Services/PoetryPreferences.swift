//
//  PoetryPreferences.swift
//  Writing Shed Pro
//
//  Global poetry feature preferences
//  Feature 021: Smart Poetry Creation
//

import Foundation
import Observation

/// English dialect for pronunciation/stress analysis
enum EnglishDialect: String, CaseIterable, Codable {
    case american = "american"
    case british = "british"
    
    var displayName: String {
        switch self {
        case .american: return NSLocalizedString("dialect.american", comment: "American English")
        case .british: return NSLocalizedString("dialect.british", comment: "British English")
        }
    }
    
    var shortName: String {
        switch self {
        case .american: return "US"
        case .british: return "UK"
        }
    }
    
    /// The dictionary file name for this dialect
    var dictionaryFileName: String {
        switch self {
        case .american: return "cmudict"
        case .british: return "britdict"
        }
    }
}

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
        static let englishDialect = "poetry.englishDialect"
    }
    
    // MARK: - Properties
    
    private let store = UserDefaults.standard
    
    // Backing stored properties for @Observable to track changes
    private var _showMetricsBar: Bool
    private var _showStressAnalysis: Bool
    private var _autoOpenFormReference: Bool
    private var _showSyllableHints: Bool
    private var _englishDialect: EnglishDialect
    
    /// Whether to show the metrics bar in the editor for Poetry projects
    /// Default: true
    var showMetricsBar: Bool {
        get { _showMetricsBar }
        set {
            _showMetricsBar = newValue
            store.set(newValue, forKey: Keys.showMetricsBar)
        }
    }
    
    /// Whether to show stress pattern analysis (more detailed, can be toggled off for simplicity)
    /// Default: false (opt-in feature)
    var showStressAnalysis: Bool {
        get { _showStressAnalysis }
        set {
            _showStressAnalysis = newValue
            store.set(newValue, forKey: Keys.showStressAnalysis)
        }
    }
    
    /// Whether to automatically show form reference when creating a new poetry file
    /// Default: false
    var autoOpenFormReference: Bool {
        get { _autoOpenFormReference }
        set {
            _autoOpenFormReference = newValue
            store.set(newValue, forKey: Keys.autoOpenFormReference)
        }
    }
    
    /// Whether to show inline syllable hints during editing
    /// Default: true
    var showSyllableHints: Bool {
        get { _showSyllableHints }
        set {
            _showSyllableHints = newValue
            store.set(newValue, forKey: Keys.showSyllableHints)
        }
    }
    
    /// English dialect for pronunciation and stress analysis
    /// Default: .american (CMU dictionary)
    var englishDialect: EnglishDialect {
        get { _englishDialect }
        set {
            let oldValue = _englishDialect
            _englishDialect = newValue
            store.set(newValue.rawValue, forKey: Keys.englishDialect)
            // Notify dictionary services to reload if dialect changed
            if oldValue != newValue {
                NotificationCenter.default.post(name: .dialectDidChange, object: newValue)
            }
        }
    }
    
    // MARK: - Singleton
    
    static let shared = PoetryPreferences()
    
    private init() {
        // Load from UserDefaults or use defaults
        _showMetricsBar = store.object(forKey: Keys.showMetricsBar) as? Bool ?? true
        _showStressAnalysis = store.object(forKey: Keys.showStressAnalysis) as? Bool ?? false
        _autoOpenFormReference = store.object(forKey: Keys.autoOpenFormReference) as? Bool ?? false
        _showSyllableHints = store.object(forKey: Keys.showSyllableHints) as? Bool ?? true
        
        if let rawValue = store.string(forKey: Keys.englishDialect),
           let dialect = EnglishDialect(rawValue: rawValue) {
            _englishDialect = dialect
        } else {
            _englishDialect = .american
        }
    }
    
    // MARK: - Reset
    
    /// Reset all poetry preferences to defaults
    func resetToDefaults() {
        showMetricsBar = true
        showStressAnalysis = false
        autoOpenFormReference = false
        showSyllableHints = true
        englishDialect = .american
        
        store.removeObject(forKey: Keys.showMetricsBar)
        store.removeObject(forKey: Keys.showStressAnalysis)
        store.removeObject(forKey: Keys.autoOpenFormReference)
        store.removeObject(forKey: Keys.showSyllableHints)
        store.removeObject(forKey: Keys.englishDialect)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when the English dialect preference changes
    static let dialectDidChange = Notification.Name("com.writingshed.dialectDidChange")
}
