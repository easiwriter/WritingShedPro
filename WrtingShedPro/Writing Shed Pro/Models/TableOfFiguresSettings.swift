//
//  TableOfFiguresSettings.swift
//  Writing Shed Pro
//
//  Settings for Table of Figures generation
//  Feature 112: Table of Figures - back matter listing all images with captions and page numbers
//

import Foundation
import UIKit

/// Settings for Table of Figures generation and formatting
struct TableOfFiguresSettings: Codable, Equatable {
    /// Title displayed at the top of the Table of Figures
    var title: String = "List of Figures"
    
    /// Style name for the title (internal UIFont.TextStyle name)
    var titleStyleName: String = "UICTFontTextStyleTitle0"
    
    /// Style name for figure entries
    var entryStyleName: String = "UICTFontTextStyleBody"
    
    /// Whether to show page numbers
    var showPageNumbers: Bool = true
    
    /// Separator character between figure caption and page number
    var separator: String = "."
    
    /// Whether to use dot leaders (repeated separator)
    var useDotLeaders: Bool = true
    
    /// Tab stop position for page numbers (in points from left margin)
    var pageNumberPosition: CGFloat = 480
    
    /// Whether to show "Missing caption" for images without captions
    /// When true: Shows "Missing caption" in the list
    /// When false: Silently skips uncaptioned images
    var showMissingCaption: Bool = false
    
    /// Caption prefix to display (e.g., "Figure", "Photo", nil for caption text only)
    /// When set, entries display as "Figure 1: Caption text"
    /// When nil, entries display as "Caption text"
    var captionPrefix: String? = "Figure"
    
    // MARK: - Default Instance
    
    static let `default` = TableOfFiguresSettings()
}
