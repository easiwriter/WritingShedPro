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
    
    /// Style name to use for TOC entries (internal UIFont.TextStyle name)
    var entryStyleName: String = "UICTFontTextStyleBody"
    
    /// Whether to show page numbers (disabled by default until page calculation is implemented)
    var showPageNumbers: Bool = false
    
    /// Whether to use dot leaders (repeated separator)
    var useDotLeaders: Bool = true
    
    // MARK: - Default Instance
    
    static let `default` = TOCSettings()
}
