import Foundation
import UIKit

/// Represents how numbers are adorned (brackets, periods, etc.)
enum NumberingAdornment: String, Codable, CaseIterable {
    case plain            // 1
    case period           // 1.
    case parentheses      // (1)
    case rightParen       // 1)
    case dashBefore       // -1
    case dashAfter        // 1-
    case dashBoth         // -1-
    
    var displayName: String {
        switch self {
        case .plain:
            return NSLocalizedString("numberAdornment.plain", comment: "1")
        case .period:
            return NSLocalizedString("numberAdornment.period", comment: "1.")
        case .parentheses:
            return NSLocalizedString("numberAdornment.parentheses", comment: "(1)")
        case .rightParen:
            return NSLocalizedString("numberAdornment.rightParen", comment: "1)")
        case .dashBefore:
            return NSLocalizedString("numberAdornment.dashBefore", comment: "-1")
        case .dashAfter:
            return NSLocalizedString("numberAdornment.dashAfter", comment: "1-")
        case .dashBoth:
            return NSLocalizedString("numberAdornment.dashBoth", comment: "-1-")
        }
    }
    
    /// Apply adornment to a number string
    func apply(to number: String) -> String {
        switch self {
        case .plain:
            return number
        case .period:
            return "\(number)."
        case .parentheses:
            return "(\(number))"
        case .rightParen:
            return "\(number))"
        case .dashBefore:
            return "-\(number)"
        case .dashAfter:
            return "\(number)-"
        case .dashBoth:
            return "-\(number)-"
        }
    }
}

/// Represents the numbering/bullet format for a paragraph
/// Phase 005: Format is stored as an attribute but not automatically applied
/// Phase 006+: Will be used for automatic list numbering
enum NumberFormat: String, Codable, CaseIterable {
    case none                // No numbering (default)
    case decimal             // 1, 2, 3, 4...
    case lowercaseRoman      // i, ii, iii, iv...
    case uppercaseRoman      // I, II, III, IV...
    case lowercaseLetter     // a, b, c, d...
    case uppercaseLetter     // A, B, C, D...
    case footnoteSymbols     // *, †, ‡, §, ¶
    case bulletSymbols       // •, ◦, ▪, ▫, ▸
    
    // MARK: - Display Names
    
    /// Human-readable name for the format
    var displayName: String {
        switch self {
        case .none:
            return NSLocalizedString("numberFormat.none", comment: "None")
        case .decimal:
            return NSLocalizedString("numberFormat.decimal", comment: "1, 2, 3...")
        case .lowercaseRoman:
            return NSLocalizedString("numberFormat.lowercaseRoman", comment: "i, ii, iii...")
        case .uppercaseRoman:
            return NSLocalizedString("numberFormat.uppercaseRoman", comment: "I, II, III...")
        case .lowercaseLetter:
            return NSLocalizedString("numberFormat.lowercaseLetter", comment: "a, b, c...")
        case .uppercaseLetter:
            return NSLocalizedString("numberFormat.uppercaseLetter", comment: "A, B, C...")
        case .footnoteSymbols:
            return NSLocalizedString("numberFormat.footnoteSymbols", comment: "*, †, ‡...")
        case .bulletSymbols:
            return NSLocalizedString("numberFormat.bulletSymbols", comment: "•, ◦, ▪...")
        }
    }
    
    // MARK: - Symbol Generation
    
    /// The actual character/string to display for a given index
    /// - Parameters:
    ///   - index: Zero-based index (0, 1, 2...)
    ///   - adornment: Optional adornment style (default: .period for backward compatibility)
    /// - Returns: Formatted string for display
    func symbol(for index: Int, adornment: NumberingAdornment = .period) -> String {
        switch self {
        case .none:
            return ""
        case .decimal:
            return adornment.apply(to: "\(index + 1)")
        case .lowercaseRoman:
            return adornment.apply(to: romanNumeral(index + 1, uppercase: false))
        case .uppercaseRoman:
            return adornment.apply(to: romanNumeral(index + 1, uppercase: true))
        case .lowercaseLetter:
            return adornment.apply(to: letter(index, uppercase: false))
        case .uppercaseLetter:
            return adornment.apply(to: letter(index, uppercase: true))
        case .footnoteSymbols:
            let symbols = ["*", "†", "‡", "§", "¶"]
            return symbols[index % symbols.count]
        case .bulletSymbols:
            let symbols = ["•", "◦", "▪", "▫", "▸"]
            return symbols[index % symbols.count]
        }
    }
    
    // MARK: - Helper Methods
    
    /// Convert number to Roman numeral
    private func romanNumeral(_ num: Int, uppercase: Bool) -> String {
        let values = [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1]
        let numerals = ["M", "CM", "D", "CD", "C", "XC", "L", "XL", "X", "IX", "V", "IV", "I"]
        
        var result = ""
        var number = num
        
        for (index, value) in values.enumerated() {
            while number >= value {
                result += numerals[index]
                number -= value
            }
        }
        
        return uppercase ? result : result.lowercased()
    }
    
    /// Convert index to letter (a, b, c... or A, B, C...)
    private func letter(_ index: Int, uppercase: Bool) -> String {
        let base = uppercase ? "A" : "a"
        let scalar = base.unicodeScalars.first!.value + UInt32(index % 26)
        let char = String(UnicodeScalar(scalar)!)
        
        // For indices beyond 25, add repetitions (aa, bb, cc...)
        let repetitions = (index / 26) + 1
        return String(repeating: char, count: repetitions)
    }
}

// MARK: - NSAttributedString Integration

extension NSAttributedString.Key {
    /// Custom attribute key for number format
    /// Used to store NumberFormat enum as part of paragraph formatting
    static let numberFormat = NSAttributedString.Key("WritingShedPro.NumberFormat")
}

extension NumberFormat {
    /// Convert to attribute value for NSAttributedString
    var attributeValue: String {
        return self.rawValue
    }
    
    /// Create from attribute value
    static func from(attributeValue: Any?) -> NumberFormat? {
        guard let string = attributeValue as? String else { return nil }
        return NumberFormat(rawValue: string)
    }
    
    /// Estimate the width needed for paragraph numbers in this format
    /// Used to automatically add space for numbers in the first line indent
    /// - Parameters:
    ///   - font: The font used for the paragraph
    ///   - adornment: The number adornment style
    ///   - hasParent: Whether this is a child style with hierarchical numbering (e.g., "1.a")
    /// - Returns: Estimated width needed for the number plus a small gap
    func estimatedWidth(for font: UIFont, adornment: NumberingAdornment = .period, hasParent: Bool = false) -> CGFloat {
        guard self != .none else { return 0 }
        
        // Use a representative "wide" number for estimation
        // For most formats, index 8 ("9" or "ix") is a reasonable worst case for single digits
        let sampleNumber: String
        switch self {
        case .none:
            return 0
        case .decimal:
            sampleNumber = hasParent ? "99.9" : "99" // Allow for 2 digits
        case .lowercaseRoman:
            sampleNumber = hasParent ? "x.viii" : "viii" // Roman numeral 8
        case .uppercaseRoman:
            sampleNumber = hasParent ? "X.VIII" : "VIII"
        case .lowercaseLetter:
            sampleNumber = hasParent ? "9.m" : "m" // Wide letter
        case .uppercaseLetter:
            sampleNumber = hasParent ? "9.M" : "M"
        case .footnoteSymbols, .bulletSymbols:
            sampleNumber = "•" // Single character
        }
        
        let displayNumber = adornment.apply(to: sampleNumber)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let size = (displayNumber as NSString).size(withAttributes: attributes)
        
        // Add a small gap (4pt) between number and text
        return ceil(size.width) + 4
    }
}
