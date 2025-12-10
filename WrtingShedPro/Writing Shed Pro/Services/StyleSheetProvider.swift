//
//  StyleSheetProvider.swift
//  Writing Shed Pro
//
//  Global stylesheet access for view providers and other components
//  Phase 006: Image Support - Caption feature
//

import Foundation

/// Provides access to the active stylesheet for rendering components
class StyleSheetProvider {
    
    // MARK: - Singleton
    
    static let shared = StyleSheetProvider()
    
    private init() {
        setupNotifications()
    }
    
    // MARK: - Properties
    
    /// Currently active stylesheet (per-file)
    private var activeStyleSheets: [UUID: StyleSheet] = [:]
    
    /// Default lock for thread safety
    private let lock = NSLock()
    
    // MARK: - Public Interface
    
    /// Register a stylesheet for a specific file
    func register(styleSheet: StyleSheet, for fileID: UUID) {
        lock.lock()
        defer { lock.unlock() }
        
        activeStyleSheets[fileID] = styleSheet
        
        #if DEBUG
        print("📋 StyleSheetProvider: Registered stylesheet '\(styleSheet.name)' for file \(fileID)")
        #endif
    }
    
    /// Unregister a stylesheet for a specific file
    func unregister(fileID: UUID) {
        lock.lock()
        defer { lock.unlock() }
        
        activeStyleSheets.removeValue(forKey: fileID)
        
        #if DEBUG
        print("📋 StyleSheetProvider: Unregistered stylesheet for file \(fileID)")
        #endif
    }
    
    /// Get the stylesheet for a specific file
    func styleSheet(for fileID: UUID) -> StyleSheet? {
        lock.lock()
        defer { lock.unlock() }
        
        return activeStyleSheets[fileID]
    }
    
    /// Get any active stylesheet (fallback when file ID not available)
    /// This is a last resort and should be avoided if possible
    func anyActiveStyleSheet() -> StyleSheet? {
        lock.lock()
        defer { lock.unlock() }
        
        return activeStyleSheets.values.first
    }
    
    // MARK: - Notifications
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleStyleSheetModified(_:)),
            name: NSNotification.Name("StyleSheetModified"),
            object: nil
        )
    }
    
    @objc private func handleStyleSheetModified(_ notification: Notification) {
        // Stylesheet was modified - views will refresh themselves via their own observers
        #if DEBUG
        print("📋 StyleSheetProvider: Received StyleSheetModified notification")
        #endif
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
