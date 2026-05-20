//
//  StyleCategory.swift
//  Writing Shed Pro
//
//  Style category enumeration for organizing text styles
//

import Foundation

/// Categories for organizing text styles in the style sheet
enum StyleCategory: String, Codable, CaseIterable {
    case text       // Body text, captions
    case heading    // Titles, headings
    case list       // Numbered and bulleted lists
    case footnote   // Footnotes
    case custom     // User-defined styles
}
