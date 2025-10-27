import Foundation
import UIKit

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
    /// - Parameter index: Zero-based index (0, 1, 2...)
    /// - Returns: Formatted string for display
    func symbol(for index: Int) -> String {
        switch self {
        case .none:
            return ""
        case .decimal:
            return "\(index + 1)."
        case .lowercaseRoman:
            return romanNumeral(index + 1, uppercase: false) + "."
        case .uppercaseRoman:
            return romanNumeral(index + 1, uppercase: true) + "."
        case .lowercaseLetter:
            return letter(index, uppercase: false) + "."
        case .uppercaseLetter:
            return letter(index, uppercase: true) + "."
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
}
