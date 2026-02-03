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
    var titleStyleName: String = "UICTFontTextStyleLargeTitle"
    
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
    
    /// Whether to show page numbers (disabled by default until page calculation is implemented)
    var showPageNumbers: Bool = false
    
    /// Whether to use dot leaders (repeated separator)
    var useDotLeaders: Bool = true
    
    /// Fixed line width for TOC entries (for consistent alignment)
    var lineWidth: CGFloat = 480
    
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
}
