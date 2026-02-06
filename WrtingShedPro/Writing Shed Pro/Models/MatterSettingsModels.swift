//
//  MatterSettingsModels.swift
//  Writing Shed Pro
//
//  Settings models for Front Matter and Back Matter folder items
//

import Foundation

// MARK: - Front Matter Items

/// Enumeration of available front matter items
/// Order defines display order in the folder
enum FrontMatterItem: String, CaseIterable, Codable, Identifiable {
    case halfTitle = "Half Title"
    case titlePage = "Title Page"
    case copyright = "Copyright"
    case dedication = "Dedication"
    case epigraph = "Epigraph"
    case tableOfContents = "Table of Contents"
    case foreword = "Foreword"
    case preface = "Preface"
    case acknowledgements = "Acknowledgements"
    
    var id: String { rawValue }
    
    /// Localized display name
    var localizedName: String {
        switch self {
        case .halfTitle:
            return NSLocalizedString("frontMatter.halfTitle", comment: "Half Title")
        case .titlePage:
            return NSLocalizedString("frontMatter.titlePage", comment: "Title Page")
        case .copyright:
            return NSLocalizedString("frontMatter.copyright", comment: "Copyright")
        case .dedication:
            return NSLocalizedString("frontMatter.dedication", comment: "Dedication")
        case .epigraph:
            return NSLocalizedString("frontMatter.epigraph", comment: "Epigraph")
        case .tableOfContents:
            return NSLocalizedString("frontMatter.tableOfContents", comment: "Table of Contents")
        case .foreword:
            return NSLocalizedString("frontMatter.foreword", comment: "Foreword")
        case .preface:
            return NSLocalizedString("frontMatter.preface", comment: "Preface")
        case .acknowledgements:
            return NSLocalizedString("frontMatter.acknowledgements", comment: "Acknowledgements")
        }
    }
    
    /// File name to create in the folder
    var fileName: String { rawValue }
    
    /// Sort order for display in folder
    var sortOrder: Int {
        switch self {
        case .halfTitle: return 0
        case .titlePage: return 1
        case .copyright: return 2
        case .dedication: return 3
        case .epigraph: return 4
        case .tableOfContents: return 5
        case .foreword: return 6
        case .preface: return 7
        case .acknowledgements: return 8
        }
    }
}

// MARK: - Back Matter Items

/// Enumeration of available back matter items
/// Order defines display order in the folder
enum BackMatterItem: String, CaseIterable, Codable, Identifiable {
    case endnotes = "Endnotes"
    case glossary = "Glossary"
    case references = "References"
    case tableOfFigures = "Table of Figures"
    case index = "Index"
    case contributors = "Contributors"
    
    var id: String { rawValue }
    
    /// Localized display name
    var localizedName: String {
        switch self {
        case .endnotes:
            return NSLocalizedString("backMatter.endnotes", comment: "Endnotes")
        case .glossary:
            return NSLocalizedString("backMatter.glossary", comment: "Glossary")
        case .references:
            return NSLocalizedString("backMatter.references", comment: "References")
        case .tableOfFigures:
            return NSLocalizedString("backMatter.tableOfFigures", comment: "Table of Figures")
        case .index:
            return NSLocalizedString("backMatter.index", comment: "Index")
        case .contributors:
            return NSLocalizedString("backMatter.contributors", comment: "Contributors")
        }
    }
    
    /// File name to create in the folder
    var fileName: String { rawValue }
    
    /// Sort order for display in folder
    var sortOrder: Int {
        switch self {
        case .endnotes: return 0
        case .glossary: return 1
        case .references: return 2
        case .tableOfFigures: return 3
        case .index: return 4
        case .contributors: return 5
        }
    }
}

// MARK: - Front Matter Settings

/// Settings for which front matter items are enabled
struct FrontMatterSettings: Codable, Equatable {
    var enabledItems: Set<FrontMatterItem>
    
    init(enabledItems: Set<FrontMatterItem> = []) {
        self.enabledItems = enabledItems
    }
    
    /// Check if an item is enabled
    func isEnabled(_ item: FrontMatterItem) -> Bool {
        enabledItems.contains(item)
    }
    
    /// Toggle an item on or off
    mutating func toggle(_ item: FrontMatterItem) {
        if enabledItems.contains(item) {
            enabledItems.remove(item)
        } else {
            enabledItems.insert(item)
        }
    }
    
    /// Set an item's enabled state
    mutating func setEnabled(_ item: FrontMatterItem, enabled: Bool) {
        if enabled {
            enabledItems.insert(item)
        } else {
            enabledItems.remove(item)
        }
    }
    
    /// Get enabled items sorted by sort order
    var sortedEnabledItems: [FrontMatterItem] {
        enabledItems.sorted { $0.sortOrder < $1.sortOrder }
    }
}

// MARK: - Back Matter Settings

/// Settings for which back matter items are enabled
struct BackMatterSettings: Codable, Equatable {
    var enabledItems: Set<BackMatterItem>
    
    /// Number of columns for index display (1-3, default 2)
    var indexColumnCount: Int
    
    init(enabledItems: Set<BackMatterItem> = [], indexColumnCount: Int = 2) {
        self.enabledItems = enabledItems
        self.indexColumnCount = max(1, min(3, indexColumnCount))
    }
    
    /// Check if an item is enabled
    func isEnabled(_ item: BackMatterItem) -> Bool {
        enabledItems.contains(item)
    }
    
    /// Toggle an item on or off
    mutating func toggle(_ item: BackMatterItem) {
        if enabledItems.contains(item) {
            enabledItems.remove(item)
        } else {
            enabledItems.insert(item)
        }
    }
    
    /// Set an item's enabled state
    mutating func setEnabled(_ item: BackMatterItem, enabled: Bool) {
        if enabled {
            enabledItems.insert(item)
        } else {
            enabledItems.remove(item)
        }
    }
    
    /// Get enabled items sorted by sort order
    var sortedEnabledItems: [BackMatterItem] {
        enabledItems.sorted { $0.sortOrder < $1.sortOrder }
    }
}

// MARK: - Drama Front Matter Items

/// Enumeration of available front matter items for Drama projects
enum DramaFrontMatterItem: String, CaseIterable, Codable, Identifiable {
    case titlePage = "Title Page"
    case castList = "Cast List"
    case settingsAndTime = "Settings & Time"
    case productionNote = "Production Note"
    case acknowledgements = "Acknowledgements"
    
    var id: String { rawValue }
    
    /// Localized display name
    var localizedName: String {
        switch self {
        case .titlePage:
            return NSLocalizedString("drama.frontMatter.titlePage", comment: "Title Page")
        case .castList:
            return NSLocalizedString("drama.frontMatter.castList", comment: "Cast List")
        case .settingsAndTime:
            return NSLocalizedString("drama.frontMatter.settingsAndTime", comment: "Settings & Time")
        case .productionNote:
            return NSLocalizedString("drama.frontMatter.productionNote", comment: "Production Note")
        case .acknowledgements:
            return NSLocalizedString("drama.frontMatter.acknowledgements", comment: "Acknowledgements")
        }
    }
    
    /// File name to create in the folder
    var fileName: String { rawValue }
    
    /// Sort order for display in folder
    var sortOrder: Int {
        switch self {
        case .titlePage: return 0
        case .castList: return 1
        case .settingsAndTime: return 2
        case .productionNote: return 3
        case .acknowledgements: return 4
        }
    }
}

// MARK: - Drama Back Matter Items

/// Enumeration of available back matter items for Drama projects
enum DramaBackMatterItem: String, CaseIterable, Codable, Identifiable {
    case productionHistory = "Production History"
    case afterword = "Afterword"
    case rightsAndPermissions = "Rights & Permissions"
    
    var id: String { rawValue }
    
    /// Localized display name
    var localizedName: String {
        switch self {
        case .productionHistory:
            return NSLocalizedString("drama.backMatter.productionHistory", comment: "Production History")
        case .afterword:
            return NSLocalizedString("drama.backMatter.afterword", comment: "Afterword")
        case .rightsAndPermissions:
            return NSLocalizedString("drama.backMatter.rightsAndPermissions", comment: "Rights & Permissions")
        }
    }
    
    /// File name to create in the folder
    var fileName: String { rawValue }
    
    /// Sort order for display in folder
    var sortOrder: Int {
        switch self {
        case .productionHistory: return 0
        case .afterword: return 1
        case .rightsAndPermissions: return 2
        }
    }
}

// MARK: - Drama Front Matter Settings

/// Settings for which front matter items are enabled in Drama projects
struct DramaFrontMatterSettings: Codable, Equatable {
    var enabledItems: Set<DramaFrontMatterItem>
    
    init(enabledItems: Set<DramaFrontMatterItem> = []) {
        self.enabledItems = enabledItems
    }
    
    /// Check if an item is enabled
    func isEnabled(_ item: DramaFrontMatterItem) -> Bool {
        enabledItems.contains(item)
    }
    
    /// Toggle an item on or off
    mutating func toggle(_ item: DramaFrontMatterItem) {
        if enabledItems.contains(item) {
            enabledItems.remove(item)
        } else {
            enabledItems.insert(item)
        }
    }
    
    /// Set an item's enabled state
    mutating func setEnabled(_ item: DramaFrontMatterItem, enabled: Bool) {
        if enabled {
            enabledItems.insert(item)
        } else {
            enabledItems.remove(item)
        }
    }
    
    /// Get enabled items sorted by sort order
    var sortedEnabledItems: [DramaFrontMatterItem] {
        enabledItems.sorted { $0.sortOrder < $1.sortOrder }
    }
}

// MARK: - Drama Back Matter Settings

/// Settings for which back matter items are enabled in Drama projects
struct DramaBackMatterSettings: Codable, Equatable {
    var enabledItems: Set<DramaBackMatterItem>
    
    init(enabledItems: Set<DramaBackMatterItem> = []) {
        self.enabledItems = enabledItems
    }
    
    /// Check if an item is enabled
    func isEnabled(_ item: DramaBackMatterItem) -> Bool {
        enabledItems.contains(item)
    }
    
    /// Toggle an item on or off
    mutating func toggle(_ item: DramaBackMatterItem) {
        if enabledItems.contains(item) {
            enabledItems.remove(item)
        } else {
            enabledItems.insert(item)
        }
    }
    
    /// Set an item's enabled state
    mutating func setEnabled(_ item: DramaBackMatterItem, enabled: Bool) {
        if enabled {
            enabledItems.insert(item)
        } else {
            enabledItems.remove(item)
        }
    }
    
    /// Get enabled items sorted by sort order
    var sortedEnabledItems: [DramaBackMatterItem] {
        enabledItems.sorted { $0.sortOrder < $1.sortOrder }
    }
}
