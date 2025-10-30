//
//  StyleSheetModels.swift
//  Writing Shed Pro
//
//  SwiftData models for StyleSheet and TextStyle
//  Phase 5: Style Editor implementation
//

import Foundation
import SwiftData
import UIKit

// MARK: - StyleSheet Model

@Model
final class StyleSheet {
    var id: UUID = UUID()
    var name: String
    var isSystemStyleSheet: Bool
    var createdDate: Date = Date()
    var modifiedDate: Date = Date()
    
    @Relationship(deleteRule: .cascade, inverse: \TextStyleModel.styleSheet)
    var textStyles: [TextStyleModel]?
    
    @Relationship(inverse: \Project.styleSheet)
    var projects: [Project]?
    
    init(
        name: String,
        isSystemStyleSheet: Bool = false
    ) {
        self.name = name
        self.isSystemStyleSheet = isSystemStyleSheet
        self.textStyles = []
    }
    
    /// Get a style by name
    func style(named name: String) -> TextStyleModel? {
        return textStyles?.first(where: { $0.name == name })
    }
    
    /// Get all styles sorted by display order
    var sortedStyles: [TextStyleModel] {
        return textStyles?.sorted(by: { $0.displayOrder < $1.displayOrder }) ?? []
    }
}

// MARK: - TextStyle Model

@Model
final class TextStyleModel {
    var id: UUID = UUID()
    var name: String  // "body", "title1", "headline", "custom-quote", etc.
    var displayName: String  // "Body", "Title 1", "Headline", "Block Quote"
    var displayOrder: Int  // For sorting in UI
    
    // MARK: - Font Attributes
    var fontFamily: String?  // nil = use system font
    var fontSize: CGFloat
    var isBold: Bool
    var isItalic: Bool
    var isUnderlined: Bool
    var isStrikethrough: Bool
    var textColorHex: String?  // Hex color string, nil = default
    
    // MARK: - Paragraph Attributes
    var alignmentRaw: Int  // NSTextAlignment raw value
    var lineSpacing: CGFloat
    var paragraphSpacingBefore: CGFloat
    var paragraphSpacingAfter: CGFloat
    var firstLineIndent: CGFloat
    var headIndent: CGFloat  // Left margin
    var tailIndent: CGFloat  // Right margin
    
    // MARK: - Line Height
    var lineHeightMultiple: CGFloat
    var minimumLineHeight: CGFloat
    var maximumLineHeight: CGFloat
    
    // MARK: - Numbering/Bullets
    var numberFormatRaw: String  // NumberFormat.rawValue
    
    // MARK: - Style Classification
    var styleCategoryRaw: String  // "text", "list", "footnote", "heading"
    var isSystemStyle: Bool  // true for built-in UIFont.TextStyle equivalents
    
    // MARK: - Metadata
    var createdDate: Date = Date()
    var modifiedDate: Date = Date()
    
    // MARK: - Relationships
    var styleSheet: StyleSheet?
    
    // MARK: - Computed Properties
    
    var alignment: NSTextAlignment {
        get { NSTextAlignment(rawValue: alignmentRaw) ?? .natural }
        set { alignmentRaw = newValue.rawValue }
    }
    
    var numberFormat: NumberFormat {
        get { NumberFormat(rawValue: numberFormatRaw) ?? .none }
        set { numberFormatRaw = newValue.rawValue }
    }
    
    var styleCategory: StyleCategory {
        get { StyleCategory(rawValue: styleCategoryRaw) ?? .text }
        set { styleCategoryRaw = newValue.rawValue }
    }
    
    var textColor: UIColor? {
        get {
            guard let hex = textColorHex else { return nil }
            return UIColor(hex: hex)
        }
        set {
            textColorHex = newValue?.toHex()
        }
    }
    
    // MARK: - Initialization
    
    init(
        name: String,
        displayName: String,
        displayOrder: Int = 0,
        fontFamily: String? = nil,
        fontSize: CGFloat = 17,
        isBold: Bool = false,
        isItalic: Bool = false,
        isUnderlined: Bool = false,
        isStrikethrough: Bool = false,
        textColor: UIColor? = nil,
        alignment: NSTextAlignment = .natural,
        lineSpacing: CGFloat = 0,
        paragraphSpacingBefore: CGFloat = 0,
        paragraphSpacingAfter: CGFloat = 0,
        firstLineIndent: CGFloat = 0,
        headIndent: CGFloat = 0,
        tailIndent: CGFloat = 0,
        lineHeightMultiple: CGFloat = 0,
        minimumLineHeight: CGFloat = 0,
        maximumLineHeight: CGFloat = 0,
        numberFormat: NumberFormat = .none,
        styleCategory: StyleCategory = .text,
        isSystemStyle: Bool = false
    ) {
        self.name = name
        self.displayName = displayName
        self.displayOrder = displayOrder
        self.fontFamily = fontFamily
        self.fontSize = fontSize
        self.isBold = isBold
        self.isItalic = isItalic
        self.isUnderlined = isUnderlined
        self.isStrikethrough = isStrikethrough
        self.textColorHex = textColor?.toHex()
        self.alignmentRaw = alignment.rawValue
        self.lineSpacing = lineSpacing
        self.paragraphSpacingBefore = paragraphSpacingBefore
        self.paragraphSpacingAfter = paragraphSpacingAfter
        self.firstLineIndent = firstLineIndent
        self.headIndent = headIndent
        self.tailIndent = tailIndent
        self.lineHeightMultiple = lineHeightMultiple
        self.minimumLineHeight = minimumLineHeight
        self.maximumLineHeight = maximumLineHeight
        self.numberFormatRaw = numberFormat.rawValue
        self.styleCategoryRaw = styleCategory.rawValue
        self.isSystemStyle = isSystemStyle
    }
    
    // MARK: - Font Generation
    
    /// Generate a UIFont from this style's attributes
    func generateFont() -> UIFont {
        let baseSize = fontSize
        
        // Start with either custom font family or system font
        var font: UIFont
        if let family = fontFamily, !family.isEmpty {
            font = UIFont(name: family, size: baseSize) ?? UIFont.systemFont(ofSize: baseSize)
        } else {
            font = UIFont.systemFont(ofSize: baseSize)
        }
        
        // Apply traits (bold, italic)
        var traits: UIFontDescriptor.SymbolicTraits = []
        if isBold { traits.insert(.traitBold) }
        if isItalic { traits.insert(.traitItalic) }
        
        if !traits.isEmpty {
            if let descriptor = font.fontDescriptor.withSymbolicTraits(traits) {
                font = UIFont(descriptor: descriptor, size: 0) // 0 = use descriptor's size
            }
        }
        
        return font
    }
    
    /// Generate full NSAttributedString attributes from this style
    func generateAttributes() -> [NSAttributedString.Key: Any] {
        var attrs: [NSAttributedString.Key: Any] = [:]
        
        // Font
        attrs[.font] = generateFont()
        
        // Text style name (for lookup)
        attrs[.textStyle] = name
        
        // Text color
        if let color = textColor {
            attrs[.foregroundColor] = color
        }
        
        // Underline
        if isUnderlined {
            attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue
        }
        
        // Strikethrough
        if isStrikethrough {
            attrs[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
        }
        
        // Paragraph style
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment
        paragraphStyle.lineSpacing = lineSpacing
        paragraphStyle.paragraphSpacingBefore = paragraphSpacingBefore
        paragraphStyle.paragraphSpacing = paragraphSpacingAfter
        paragraphStyle.firstLineHeadIndent = firstLineIndent
        paragraphStyle.headIndent = headIndent
        paragraphStyle.tailIndent = tailIndent
        if lineHeightMultiple > 0 {
            paragraphStyle.lineHeightMultiple = lineHeightMultiple
        }
        if minimumLineHeight > 0 {
            paragraphStyle.minimumLineHeight = minimumLineHeight
        }
        if maximumLineHeight > 0 {
            paragraphStyle.maximumLineHeight = maximumLineHeight
        }
        attrs[.paragraphStyle] = paragraphStyle
        
        // Number format (stored but not rendered in Phase 5)
        attrs[.numberFormat] = numberFormat.rawValue
        
        return attrs
    }
}

// MARK: - Style Category

enum StyleCategory: String, Codable {
    case text       // Body, callout, etc.
    case heading    // Title1-3, headline
    case list       // List items
    case footnote   // Footnotes
    case custom     // User-defined styles
}

// MARK: - UIColor Hex Extension

extension UIColor {
    /// Convert UIColor to hex string
    func toHex() -> String? {
        guard let components = cgColor.components else { return nil }
        
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        let a = Float(components.count >= 4 ? components[3] : 1.0)
        
        if a == 1.0 {
            return String(format: "#%02lX%02lX%02lX",
                         lroundf(r * 255),
                         lroundf(g * 255),
                         lroundf(b * 255))
        } else {
            return String(format: "#%02lX%02lX%02lX%02lX",
                         lroundf(r * 255),
                         lroundf(g * 255),
                         lroundf(b * 255),
                         lroundf(a * 255))
        }
    }
    
    /// Create UIColor from hex string
    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        
        let length = hexSanitized.count
        let r, g, b, a: CGFloat
        
        if length == 6 {
            r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
            g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
            b = CGFloat(rgb & 0x0000FF) / 255.0
            a = 1.0
        } else if length == 8 {
            r = CGFloat((rgb & 0xFF000000) >> 24) / 255.0
            g = CGFloat((rgb & 0x00FF0000) >> 16) / 255.0
            b = CGFloat((rgb & 0x0000FF00) >> 8) / 255.0
            a = CGFloat(rgb & 0x000000FF) / 255.0
        } else {
            return nil
        }
        
        self.init(red: r, green: g, blue: b, alpha: a)
    }
}
