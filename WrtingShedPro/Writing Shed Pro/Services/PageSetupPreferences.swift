//
//  PageSetupPreferences.swift
//  Writing Shed Pro
//
//  Global page setup preferences synced via iCloud
//  Feature 019: Settings Menu
//

import Foundation

/// Service for managing global page setup preferences
/// Page setup is stored in iCloud key-value store and syncs across devices
class PageSetupPreferences {
    
    // MARK: - Keys
    
    private enum Keys {
        static let paperName = "pageSetup.paperName"
        static let orientation = "pageSetup.orientation"
        static let headers = "pageSetup.headers"
        static let footers = "pageSetup.footers"
        static let facingPages = "pageSetup.facingPages"
        static let hideFirstSection = "pageSetup.hideFirstSection"
        static let matchPreviousSection = "pageSetup.matchPreviousSection"
        static let marginTop = "pageSetup.marginTop"
        static let marginBottom = "pageSetup.marginBottom"
        static let marginLeft = "pageSetup.marginLeft"
        static let marginRight = "pageSetup.marginRight"
        static let headerDepth = "pageSetup.headerDepth"
        static let footerDepth = "pageSetup.footerDepth"
        static let scaleFactor = "pageSetup.scaleFactor"
    }
    
    // Use iCloud key-value store for cross-device sync
    private let store = NSUbiquitousKeyValueStore.default
    
    // MARK: - Singleton
    
    static let shared = PageSetupPreferences()
    
    private init() {
        // Initialize defaults on first launch
        registerDefaults()
        
        // Listen for external changes from other devices
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(iCloudStoreDidChange(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store
        )
        
        // Ensure we have the latest values from iCloud
        store.synchronize()
    }
    
    @objc private func iCloudStoreDidChange(_ notification: Notification) {
        // Post notification that page setup changed from another device
        NotificationCenter.default.post(name: .pageSetupDidChange, object: nil)
        print("[PageSetupPreferences] Received iCloud update from another device")
    }
    
    // MARK: - Register Defaults
    
    private func registerDefaults() {
        // Set defaults only if not already set
        // iCloud store doesn't have a register() method like UserDefaults
        if store.object(forKey: Keys.paperName) == nil {
            store.set(PaperSizes.defaultForRegion.rawValue, forKey: Keys.paperName)
        }
        if store.object(forKey: Keys.orientation) == nil {
            store.set(Int(Orientation.portrait.rawValue), forKey: Keys.orientation)
        }
        if store.object(forKey: Keys.headers) == nil {
            store.set(false, forKey: Keys.headers)
        }
        if store.object(forKey: Keys.footers) == nil {
            store.set(false, forKey: Keys.footers)
        }
        if store.object(forKey: Keys.facingPages) == nil {
            store.set(false, forKey: Keys.facingPages)
        }
        if store.object(forKey: Keys.hideFirstSection) == nil {
            store.set(false, forKey: Keys.hideFirstSection)
        }
        if store.object(forKey: Keys.matchPreviousSection) == nil {
            store.set(false, forKey: Keys.matchPreviousSection)
        }
        if store.object(forKey: Keys.marginTop) == nil {
            store.set(PageSetupDefaults.marginTop, forKey: Keys.marginTop)
        }
        if store.object(forKey: Keys.marginBottom) == nil {
            store.set(PageSetupDefaults.marginBottom, forKey: Keys.marginBottom)
        }
        if store.object(forKey: Keys.marginLeft) == nil {
            store.set(PageSetupDefaults.marginLeft, forKey: Keys.marginLeft)
        }
        if store.object(forKey: Keys.marginRight) == nil {
            store.set(PageSetupDefaults.marginRight, forKey: Keys.marginRight)
        }
        if store.object(forKey: Keys.headerDepth) == nil {
            store.set(PageSetupDefaults.headerDepth, forKey: Keys.headerDepth)
        }
        if store.object(forKey: Keys.footerDepth) == nil {
            store.set(PageSetupDefaults.footerDepth, forKey: Keys.footerDepth)
        }
        if store.object(forKey: Keys.scaleFactor) == nil {
            store.set(PageSetupDefaults.scaleFactorInches, forKey: Keys.scaleFactor)
        }
        
        // Synchronize to ensure defaults are saved
        store.synchronize()
    }
    
    // MARK: - Public API - Getters
    
    var paperName: String {
        store.string(forKey: Keys.paperName) ?? PaperSizes.defaultForRegion.rawValue
    }
    
    var orientation: Orientation {
        let value = store.object(forKey: Keys.orientation) as? Int ?? Int(Orientation.portrait.rawValue)
        return Orientation(rawValue: Int16(value)) ?? .portrait
    }
    
    var headers: Bool {
        store.bool(forKey: Keys.headers)
    }
    
    var footers: Bool {
        store.bool(forKey: Keys.footers)
    }
    
    var facingPages: Bool {
        store.bool(forKey: Keys.facingPages)
    }
    
    var hideFirstSection: Bool {
        store.bool(forKey: Keys.hideFirstSection)
    }
    
    var matchPreviousSection: Bool {
        store.bool(forKey: Keys.matchPreviousSection)
    }
    
    var marginTop: Double {
        let value = store.double(forKey: Keys.marginTop)
        return value > 0 ? value : PageSetupDefaults.marginTop
    }
    
    var marginBottom: Double {
        let value = store.double(forKey: Keys.marginBottom)
        return value > 0 ? value : PageSetupDefaults.marginBottom
    }
    
    var marginLeft: Double {
        let value = store.double(forKey: Keys.marginLeft)
        return value > 0 ? value : PageSetupDefaults.marginLeft
    }
    
    var marginRight: Double {
        let value = store.double(forKey: Keys.marginRight)
        return value > 0 ? value : PageSetupDefaults.marginRight
    }
    
    var headerDepth: Double {
        let value = store.double(forKey: Keys.headerDepth)
        return value > 0 ? value : PageSetupDefaults.headerDepth
    }
    
    var footerDepth: Double {
        let value = store.double(forKey: Keys.footerDepth)
        return value > 0 ? value : PageSetupDefaults.footerDepth
    }
    
    var scaleFactor: Double {
        let value = store.double(forKey: Keys.scaleFactor)
        return value > 0 ? value : PageSetupDefaults.scaleFactorInches
    }
    
    // MARK: - Public API - Setters
    
    func setPaperName(_ value: String) {
        store.set(value, forKey: Keys.paperName)
        store.synchronize()
    }
    
    func setOrientation(_ value: Orientation) {
        store.set(Int(value.rawValue), forKey: Keys.orientation)
        store.synchronize()
    }
    
    func setHeaders(_ value: Bool) {
        store.set(value, forKey: Keys.headers)
        store.synchronize()
    }
    
    func setFooters(_ value: Bool) {
        store.set(value, forKey: Keys.footers)
        store.synchronize()
    }
    
    func setFacingPages(_ value: Bool) {
        store.set(value, forKey: Keys.facingPages)
        store.synchronize()
    }
    
    func setHideFirstSection(_ value: Bool) {
        store.set(value, forKey: Keys.hideFirstSection)
        store.synchronize()
    }
    
    func setMatchPreviousSection(_ value: Bool) {
        store.set(value, forKey: Keys.matchPreviousSection)
        store.synchronize()
    }
    
    func setMarginTop(_ value: Double) {
        store.set(value, forKey: Keys.marginTop)
        store.synchronize()
    }
    
    func setMarginBottom(_ value: Double) {
        store.set(value, forKey: Keys.marginBottom)
        store.synchronize()
    }
    
    func setMarginLeft(_ value: Double) {
        store.set(value, forKey: Keys.marginLeft)
        store.synchronize()
    }
    
    func setMarginRight(_ value: Double) {
        store.set(value, forKey: Keys.marginRight)
        store.synchronize()
    }
    
    func setHeaderDepth(_ value: Double) {
        store.set(value, forKey: Keys.headerDepth)
        store.synchronize()
    }
    
    func setFooterDepth(_ value: Double) {
        store.set(value, forKey: Keys.footerDepth)
        store.synchronize()
    }
    
    func setScaleFactor(_ value: Double) {
        store.set(value, forKey: Keys.scaleFactor)
        store.synchronize()
    }
    
    // MARK: - Convenience
    
    /// Create a PageSetup model instance from current preferences
    /// Useful for pagination or other operations that need a PageSetup object
    func createPageSetup() -> PageSetup {
        return PageSetup(
            paperName: paperName,
            orientation: orientation,
            headers: headers,
            footers: footers,
            facingPages: facingPages,
            marginTop: marginTop,
            marginBottom: marginBottom,
            marginLeft: marginLeft,
            marginRight: marginRight,
            headerDepth: headerDepth,
            footerDepth: footerDepth,
            scaleFactor: scaleFactor
        )
    }
    
    /// Update preferences from a PageSetup model instance
    func updateFrom(pageSetup: PageSetup) {
        setPaperName(pageSetup.paperName ?? PaperSizes.defaultForRegion.rawValue)
        setOrientation(pageSetup.orientationEnum)
        setHeaders(pageSetup.headers == 1)
        setFooters(pageSetup.footers == 1)
        setFacingPages(pageSetup.facingPages == 1)
        setHideFirstSection(pageSetup.hideFirstSection == 1)
        setMatchPreviousSection(pageSetup.matchPreviousSection == 1)
        setMarginTop(pageSetup.marginTop)
        setMarginBottom(pageSetup.marginBottom)
        setMarginLeft(pageSetup.marginLeft)
        setMarginRight(pageSetup.marginRight)
        setHeaderDepth(pageSetup.headerDepth)
        setFooterDepth(pageSetup.footerDepth)
        setScaleFactor(pageSetup.scaleFactor)
    }
    
    /// Reset to system defaults
    func resetToDefaults() {
        setPaperName(PaperSizes.defaultForRegion.rawValue)
        setOrientation(.portrait)
        setHeaders(false)
        setFooters(false)
        setFacingPages(false)
        setHideFirstSection(false)
        setMatchPreviousSection(false)
        setMarginTop(PageSetupDefaults.marginTop)
        setMarginBottom(PageSetupDefaults.marginBottom)
        setMarginLeft(PageSetupDefaults.marginLeft)
        setMarginRight(PageSetupDefaults.marginRight)
        setHeaderDepth(PageSetupDefaults.headerDepth)
        setFooterDepth(PageSetupDefaults.footerDepth)
        setScaleFactor(PageSetupDefaults.scaleFactorInches)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when page setup changes from another device via iCloud sync
    static let pageSetupDidChange = Notification.Name("pageSetupDidChange")
}
