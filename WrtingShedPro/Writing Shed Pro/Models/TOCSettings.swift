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
    
    /// Style name to use for the TOC title
    var titleStyleName: String = "title"
    
    /// Style name to use for TOC entries
    var entryStyleName: String = "body"
    
    /// Whether to show page numbers
    var showPageNumbers: Bool = true
    
    /// Whether to use dot leaders (repeated separator)
    var useDotLeaders: Bool = true
    
    // MARK: - Default Instance
    
    static let `default` = TOCSettings()
}
