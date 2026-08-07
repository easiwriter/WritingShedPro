//
//  TOCSettings.swift
//  Writing Shed Pro
//
//  Settings for Table of Contents generation
//

import Foundation
import UIKit

/// Settings for Table of Contents generation and formatting
struct TOCSettings: Codable, Equatable {
    /// Title displayed at the top of the TOC
    var title: String = "Contents"
    
    /// Separator character between heading text and page number
    /// Default is "." which creates dot leaders
    var separator: String = "."
    
    /// Indent amount per TOC level in points
    var indentPoints: CGFloat = 20
    
    /// Style name to use for the TOC title (internal UIFont.TextStyle name)
    var titleStyleName: String = "UICTFontTextStyleTitle0"
    
    /// Style names for each TOC level (0-5)
    /// Level 0 = top-level headings, Level 1 = sub-headings, etc.
    var levelStyleNames: [String] = [
        "UICTFontTextStyleBody",  // Level 0
        "UICTFontTextStyleBody",  // Level 1
        "UICTFontTextStyleBody",  // Level 2
        "UICTFontTextStyleBody",  // Level 3
        "UICTFontTextStyleBody",  // Level 4
        "UICTFontTextStyleBody"   // Level 5
    ]
    
    /// Whether to show page numbers in the TOC
    var showPageNumbers: Bool = true
    
    /// Whether to use dot leaders (repeated separator)
    var useDotLeaders: Bool = true
    
    /// Tab stop position for page numbers (in points from left margin)
    /// Default is 480 points, typical range 300-600
    var pageNumberPosition: CGFloat = 480
    
    /// Legacy alias for pageNumberPosition
    var lineWidth: CGFloat {
        get { pageNumberPosition }
        set { pageNumberPosition = newValue }
    }
    
    // MARK: - Legacy property for backward compatibility
    
    /// Style name to use for TOC entries (deprecated, use levelStyleNames instead)
    var entryStyleName: String {
        get { levelStyleNames.first ?? "UICTFontTextStyleBody" }
        set { 
            // Update all levels to the same style for backward compatibility
            for i in 0..<levelStyleNames.count {
                levelStyleNames[i] = newValue
            }
        }
    }
    
    /// Get the style name for a specific TOC level
    func styleName(forLevel level: Int) -> String {
        let clampedLevel = max(0, min(level, levelStyleNames.count - 1))
        return levelStyleNames[clampedLevel]
    }
    
    // MARK: - Default Instance
    
    static let `default` = TOCSettings()

    static func decode(from data: Data) -> TOCSettings? {
        if let settings = try? JSONDecoder().decode(TOCSettings.self, from: data) {
            return settings
        }

        #if DEBUG
        print("⚠️ Falling back to legacy TOC settings decoder")
        #endif

        return try? JSONDecoder().decode(LegacyTOCSettings.self, from: data).settings
    }

    private struct LegacyTOCSettings: Decodable {
        var title: String?
        var separator: String?
        var indentPoints: CGFloat?
        var titleStyleName: String?
        var levelStyleNames: [String]?
        var entryStyleName: String?
        var showPageNumbers: Bool?
        var useDotLeaders: Bool?
        var pageNumberPosition: CGFloat?

        var settings: TOCSettings {
            var settings = TOCSettings.default
            if let title { settings.title = title }
            if let separator { settings.separator = separator }
            if let indentPoints { settings.indentPoints = indentPoints }
            if let titleStyleName { settings.titleStyleName = titleStyleName }
            if let levelStyleNames { settings.levelStyleNames = levelStyleNames }
            if let entryStyleName, levelStyleNames == nil { settings.entryStyleName = entryStyleName }
            if let showPageNumbers { settings.showPageNumbers = showPageNumbers }
            if let useDotLeaders { settings.useDotLeaders = useDotLeaders }
            if let pageNumberPosition { settings.pageNumberPosition = pageNumberPosition }
            return settings
        }
    }
}
