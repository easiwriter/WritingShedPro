//
//  PageSetupPreferences.swift
//  Writing Shed Pro
//
//  Global page setup preferences stored in UserDefaults
//  Feature 019: Settings Menu
//

import Foundation

/// Service for managing global page setup preferences
/// Page setup is stored in UserDefaults and applies to all projects
class PageSetupPreferences {
    
    // MARK: - UserDefaults Keys
    
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
    
    private let defaults = UserDefaults.standard
    
    // MARK: - Singleton
    
    static let shared = PageSetupPreferences()
    
    private init() {
        // Initialize defaults on first launch
        registerDefaults()
    }
    
    // MARK: - Register Defaults
    
    private func registerDefaults() {
        let defaultValues: [String: Any] = [
            Keys.paperName: PaperSizes.defaultForRegion.rawValue,
            Keys.orientation: Orientation.portrait.rawValue,
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
            Keys.scaleFactor: PageSetupDefaults.scaleFactorInches
        ]
        
        defaults.register(defaults: defaultValues)
    }
    
    // MARK: - Public API - Getters
    
    var paperName: String {
        defaults.string(forKey: Keys.paperName) ?? PaperSizes.defaultForRegion.rawValue
    }
    
    var orientation: Orientation {
        Orientation(rawValue: Int16(defaults.integer(forKey: Keys.orientation))) ?? .portrait
    }
    
    var headers: Bool {
        defaults.bool(forKey: Keys.headers)
    }
    
    var footers: Bool {
        defaults.bool(forKey: Keys.footers)
    }
    
    var facingPages: Bool {
        defaults.bool(forKey: Keys.facingPages)
    }
    
    var hideFirstSection: Bool {
        defaults.bool(forKey: Keys.hideFirstSection)
    }
    
    var matchPreviousSection: Bool {
        defaults.bool(forKey: Keys.matchPreviousSection)
    }
    
    var marginTop: Double {
        let value = defaults.double(forKey: Keys.marginTop)
        return value > 0 ? value : PageSetupDefaults.marginTop
    }
    
    var marginBottom: Double {
        let value = defaults.double(forKey: Keys.marginBottom)
        return value > 0 ? value : PageSetupDefaults.marginBottom
    }
    
    var marginLeft: Double {
        let value = defaults.double(forKey: Keys.marginLeft)
        return value > 0 ? value : PageSetupDefaults.marginLeft
    }
    
    var marginRight: Double {
        let value = defaults.double(forKey: Keys.marginRight)
        return value > 0 ? value : PageSetupDefaults.marginRight
    }
    
    var headerDepth: Double {
        let value = defaults.double(forKey: Keys.headerDepth)
        return value > 0 ? value : PageSetupDefaults.headerDepth
    }
    
    var footerDepth: Double {
        let value = defaults.double(forKey: Keys.footerDepth)
        return value > 0 ? value : PageSetupDefaults.footerDepth
    }
    
    var scaleFactor: Double {
        let value = defaults.double(forKey: Keys.scaleFactor)
        return value > 0 ? value : PageSetupDefaults.scaleFactorInches
    }
    
    // MARK: - Public API - Setters
    
    func setPaperName(_ value: String) {
        defaults.set(value, forKey: Keys.paperName)
    }
    
    func setOrientation(_ value: Orientation) {
        defaults.set(value.rawValue, forKey: Keys.orientation)
    }
    
    func setHeaders(_ value: Bool) {
        defaults.set(value, forKey: Keys.headers)
    }
    
    func setFooters(_ value: Bool) {
        defaults.set(value, forKey: Keys.footers)
    }
    
    func setFacingPages(_ value: Bool) {
        defaults.set(value, forKey: Keys.facingPages)
    }
    
    func setHideFirstSection(_ value: Bool) {
        defaults.set(value, forKey: Keys.hideFirstSection)
    }
    
    func setMatchPreviousSection(_ value: Bool) {
        defaults.set(value, forKey: Keys.matchPreviousSection)
    }
    
    func setMarginTop(_ value: Double) {
        defaults.set(value, forKey: Keys.marginTop)
    }
    
    func setMarginBottom(_ value: Double) {
        defaults.set(value, forKey: Keys.marginBottom)
    }
    
    func setMarginLeft(_ value: Double) {
        defaults.set(value, forKey: Keys.marginLeft)
    }
    
    func setMarginRight(_ value: Double) {
        defaults.set(value, forKey: Keys.marginRight)
    }
    
    func setHeaderDepth(_ value: Double) {
        defaults.set(value, forKey: Keys.headerDepth)
    }
    
    func setFooterDepth(_ value: Double) {
        defaults.set(value, forKey: Keys.footerDepth)
    }
    
    func setScaleFactor(_ value: Double) {
        defaults.set(value, forKey: Keys.scaleFactor)
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
