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
        static let pageBreakBetweenFiles = "pageSetup.pageBreakBetweenFiles"
    }
    
    // TEMPORARY: Use UserDefaults instead of iCloud key-value store
    // NSUbiquitousKeyValueStore is not persisting values correctly
    // This ensures PageSetup works reliably - iCloud sync can be added later
    private let store = UserDefaults.standard
    
    // MARK: - Singleton
    
    static let shared = PageSetupPreferences()
    
    private init() {
        // Initialize defaults on first launch
        registerDefaults()
        
        // Note: Using UserDefaults (not iCloud) until iCloud sync issues are resolved
        // External changes won't be detected across devices currently
    }
    
    // MARK: - Register Defaults
    
    private func registerDefaults() {
        // Use UserDefaults.register() to set defaults
        // These defaults don't get saved, they're just fallbacks when no value is set
        let defaults: [String: Any] = [
            Keys.paperName: PaperSizes.defaultForRegion.rawValue,
            Keys.orientation: Int(Orientation.portrait.rawValue),
            Keys.headers: false,
            Keys.footers: false,
            Keys.facingPages: false,
            Keys.hideFirstSection: false,
            Keys.matchPreviousSection: false,
            Keys.marginTop: PageSetupDefaults.marginTop,
            Keys.marginBottom: PageSetupDefaults.marginBottom,
            Keys.marginLeft: PageSetupDefaults.marginLeft,
            Keys.marginRight: PageSetupDefaults.marginRight,
            Keys.headerDepth: PageSetupDefaults.headerDepth,
            Keys.footerDepth: PageSetupDefaults.footerDepth,
            Keys.scaleFactor: PageSetupDefaults.scaleFactorInches,
            Keys.pageBreakBetweenFiles: false
        ]
        store.register(defaults: defaults)
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
    
    var pageBreakBetweenFiles: Bool {
        store.bool(forKey: Keys.pageBreakBetweenFiles)
    }
    
    // MARK: - Public API - Setters
    
    func setPaperName(_ value: String) {
        print("[PageSetupPreferences] Setting paperName to: '\(value)'")
        print("[PageSetupPreferences] Before set, store has: '\(store.string(forKey: Keys.paperName) ?? "nil")'")
        store.set(value, forKey: Keys.paperName)
        print("[PageSetupPreferences] After set, store has: '\(store.string(forKey: Keys.paperName) ?? "nil")'")
    }
    
    func setOrientation(_ value: Orientation) {
        store.set(Int(value.rawValue), forKey: Keys.orientation)
    }
    
    func setHeaders(_ value: Bool) {
        store.set(value, forKey: Keys.headers)
    }
    
    func setFooters(_ value: Bool) {
        store.set(value, forKey: Keys.footers)
    }
    
    func setFacingPages(_ value: Bool) {
        store.set(value, forKey: Keys.facingPages)
    }
    
    func setHideFirstSection(_ value: Bool) {
        store.set(value, forKey: Keys.hideFirstSection)
    }
    
    func setMatchPreviousSection(_ value: Bool) {
        store.set(value, forKey: Keys.matchPreviousSection)
    }
    
    func setMarginTop(_ value: Double) {
        store.set(value, forKey: Keys.marginTop)
    }
    
    func setMarginBottom(_ value: Double) {
        store.set(value, forKey: Keys.marginBottom)
    }
    
    func setMarginLeft(_ value: Double) {
        store.set(value, forKey: Keys.marginLeft)
    }
    
    func setMarginRight(_ value: Double) {
        store.set(value, forKey: Keys.marginRight)
    }
    
    func setHeaderDepth(_ value: Double) {
        store.set(value, forKey: Keys.headerDepth)
    }
    
    func setFooterDepth(_ value: Double) {
        store.set(value, forKey: Keys.footerDepth)
    }
    
    func setScaleFactor(_ value: Double) {
        store.set(value, forKey: Keys.scaleFactor)
    }
    
    func setPageBreakBetweenFiles(_ value: Bool) {
        store.set(value, forKey: Keys.pageBreakBetweenFiles)
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
