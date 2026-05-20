//
//  FootnoteMarkerStyle.swift
//  Writing Shed Pro
//
//  Defines the visual style for footnote markers (numeric vs typographic symbols)
//

import Foundation

/// Controls how footnote numbers are displayed in the document and footnote area
enum FootnoteMarkerStyle: String, Codable, CaseIterable {
    case numeric
    case typographic
    
    var localizedName: String {
        switch self {
        case .numeric:
            return NSLocalizedString("footnoteMarkerStyle.numeric", comment: "Numeric")
        case .typographic:
            return NSLocalizedString("footnoteMarkerStyle.typographic", comment: "Typographic")
        }
    }
    
    // MARK: - Typographic Symbols
    
    /// The base typographic symbols used for footnotes, in traditional order
    private static let typographicSymbols = ["*", "†", "‡", "§", "‖", "¶", "#"]
    
    /// Convert a footnote number (1-based) to its display string
    /// - Parameter number: The footnote number (1, 2, 3, ...)
    /// - Returns: The display string for the marker
    func displayString(for number: Int) -> String {
        switch self {
        case .numeric:
            return "\(number)"
        case .typographic:
            return Self.typographicSymbol(for: number)
        }
    }
    
    /// Convert a 1-based footnote number to the corresponding typographic symbol.
    /// Numbers 1–7 use the base symbols (*, †, ‡, §, ‖, ¶, #).
    /// Numbers 8–14 double them (**, ††, ...).
    /// Numbers 15–21 triple them, and so on.
    private static func typographicSymbol(for number: Int) -> String {
        guard number > 0 else { return "*" }
        let index = (number - 1) % typographicSymbols.count
        let repetitions = ((number - 1) / typographicSymbols.count) + 1
        return String(repeating: typographicSymbols[index], count: repetitions)
    }
}
