//
//  StyleSheetModels.swift
//  Writing Shed Pro
//
//  SwiftData models for StyleSheet and TextStyle
//  Phase 5: Style Editor implementation
//
//  Pure @Model classes only - supporting types in separate files:
//  - StyleCategory.swift (enum)
//  - UIColor+Hex.swift (extension)
//

import Foundation
import SwiftData
import UIKit

// MARK: - StyleSheet Model

@Model
@Syncable
final class StyleSheet {
    var id: UUID = UUID()
    var name: String = ""
    var isSystemStyleSheet: Bool = false
    var createdDate: Date = Date()
    var modifiedDate: Date = Date()
    
    @Relationship(deleteRule: .cascade, inverse: \TextStyleModel.styleSheet)
    var textStyles: [TextStyleModel]?
    
    @Relationship(deleteRule: .cascade, inverse: \ImageStyle.styleSheet)
    var imageStyles: [ImageStyle]?
    
    @Relationship(inverse: \Project.styleSheet)
    var projects: [Project]?
    
    init(
        name: String,
        isSystemStyleSheet: Bool = false
    ) {
        self.name = name
        self.isSystemStyleSheet = isSystemStyleSheet
        self.textStyles = []
        self.imageStyles = []
    }
    
    /// Get a text style by name
    func style(named name: String) -> TextStyleModel? {
        return textStyles?.first(where: { $0.name == name })
    }
    
    /// Get an image style by name
    func imageStyle(named name: String) -> ImageStyle? {
        return imageStyles?.first(where: { $0.name == name })
    }
    
    /// Get default image style (first in list or create one)
    func defaultImageStyle() -> ImageStyle {
        if let first = imageStyles?.first {
            return first
        }
        // Return a temporary default if none exists
        return ImageStyle.createDefault()
    }
    
    /// Get all styles sorted by display order
    var sortedStyles: [TextStyleModel] {
        return textStyles?.sorted(by: { $0.displayOrder < $1.displayOrder }) ?? []
    }
    
    /// Get all image styles sorted by display order
    var sortedImageStyles: [ImageStyle] {
        return imageStyles?.sorted(by: { $0.displayOrder < $1.displayOrder }) ?? []
    }
}

// MARK: - TextStyle Model

@Model
@Syncable
final class TextStyleModel {
    var id: UUID = UUID()
    var name: String = ""  // "body", "title1", "headline", "custom-quote", etc.
    var displayName: String = ""  // "Body", "Title 1", "Headline", "Block Quote"
    var displayOrder: Int = 0  // For sorting in UI
    
    // MARK: - Font Attributes
    var fontFamily: String?  // nil = use system font
    var fontName: String?  // Full font name (e.g., "Helvetica-Bold"), nil = derive from family + traits
    var fontSize: CGFloat = 17
    var isBold: Bool = false
    var isItalic: Bool = false
    var isUnderlined: Bool = false
    var isStrikethrough: Bool = false
    var textColorHex: String?  // Hex color string, nil = default
    
    // MARK: - Paragraph Attributes
    var alignmentRaw: Int = 0  // NSTextAlignment raw value
    var lineSpacing: CGFloat = 0
    var paragraphSpacingBefore: CGFloat = 0
    var paragraphSpacingAfter: CGFloat = 0
    var firstLineIndent: CGFloat = 0
    var headIndent: CGFloat = 0  // Left margin
    var tailIndent: CGFloat = 0  // Right margin
    
    // MARK: - Line Height
    var lineHeightMultiple: CGFloat = 0
    var minimumLineHeight: CGFloat = 0
    var maximumLineHeight: CGFloat = 0
    
    // MARK: - Numbering/Bullets
    var numberFormatRaw: String = "none"  // NumberFormat.rawValue
    
    // MARK: - Style Classification
    var styleCategoryRaw: String = "text"  // "text", "list", "footnote", "heading"
    var isSystemStyle: Bool = false  // true for built-in UIFont.TextStyle equivalents
    
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
    
    /// Update bold/italic flags based on the current font name
    func updateTraitsFromFontName() {
        guard let fontName = fontName else { return }
        
        let lowercased = fontName.lowercased()
        
        // Check for bold
        isBold = lowercased.contains("bold") || lowercased.contains("-b-") || lowercased.hasSuffix("-b")
        
        // Check for italic
        isItalic = lowercased.contains("italic") || lowercased.contains("oblique") || 
                   lowercased.contains("-i-") || lowercased.hasSuffix("-i")
    }
    
    /// Generate a UIFont from this style's attributes
    /// Applies platform-specific scaling for Mac Catalyst (unless disabled)
    /// - Parameter applyPlatformScaling: If false, uses actual font size (for print preview/pagination)
    func generateFont(applyPlatformScaling: Bool = true) -> UIFont {
        // Apply platform scaling for Mac Catalyst (unless explicitly disabled for print preview)
        #if targetEnvironment(macCatalyst)
        let platformScaleFactor: CGFloat = applyPlatformScaling ? 1.3 : 1.0  // 30% larger on Mac for editing
        #else
        let platformScaleFactor: CGFloat = 1.0  // Standard size on iOS/iPadOS
        #endif
        
        let baseSize = fontSize * platformScaleFactor
        
        // If a specific font name is set (e.g., "Helvetica-Bold"), use it directly
        if let specificFontName = fontName, !specificFontName.isEmpty {
            if let font = UIFont(name: specificFontName, size: baseSize) {
                return font
            }
            // Fall through if font name is invalid
        }
        
        // Start with either custom font family or system font
        var font: UIFont
        if let family = fontFamily, !family.isEmpty {
            font = UIFont(name: family, size: baseSize) ?? UIFont.systemFont(ofSize: baseSize)
        } else {
            font = UIFont.systemFont(ofSize: baseSize)
        }
        
        // Apply traits (bold, italic) only if no specific font name was set
        if fontName == nil {
            var traits: UIFontDescriptor.SymbolicTraits = []
            if isBold { traits.insert(.traitBold) }
            if isItalic { traits.insert(.traitItalic) }
            
            if !traits.isEmpty {
                if let descriptor = font.fontDescriptor.withSymbolicTraits(traits) {
                    font = UIFont(descriptor: descriptor, size: 0) // 0 = use descriptor's size
                }
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
        // ONLY include color if it's set AND it's not a pure black/white/gray
        // (those should adapt to appearance mode)
        if let color = textColor {
            // Check if this is a color that should adapt to appearance
            if !AttributedStringSerializer.isAdaptiveSystemColor(color) && 
               !AttributedStringSerializer.isFixedBlackOrWhite(color) {
                // It's a real custom color (red, blue, cyan, etc.) - include it
                attrs[.foregroundColor] = color
            } else {
                // It's a black/white/gray that should adapt - use .label
                attrs[.foregroundColor] = UIColor.label
            }
        } else {
            // No color set in stylesheet - use adaptive .label
            attrs[.foregroundColor] = UIColor.label
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

// MARK: - ImageStyle Model

/// Defines default properties for images in a stylesheet
///
/// **Design Note: Template vs Instance Properties**
/// ImageStyle serves as a TEMPLATE for newly inserted images.
/// - When a user inserts an image, it gets these default values
/// - When a user edits an image, those changes are saved on the ImageAttachment instance
/// - Changing ImageStyle properties only affects NEW images, not existing ones
/// - Similar to text styles: changing "Body" style doesn't affect manually bolded text
///
/// This design ensures:
/// - Consistent defaults for new images across a document
/// - User customizations are preserved and never overwritten by stylesheet changes
/// - Predictable behavior familiar from word processors
@Model
@Syncable
final class ImageStyle {
    var id: UUID = UUID()
    var name: String = ""  // "default", "figure", "photo", "diagram", etc.
    var displayName: String = ""  // "Default", "Figure", "Photo", "Diagram"
    var displayOrder: Int = 0  // For sorting in UI
    
    // MARK: - Default Image Properties
    var defaultScale: CGFloat = 1.0  // 0.1 to 2.0
    var defaultAlignmentRaw: String = "center"  // ImageAlignment raw value
    var hasCaptionByDefault: Bool = false
    var defaultCaptionStyle: String = "caption1"  // References a TextStyle name
    
    // MARK: - Metadata
    var createdDate: Date = Date()
    var modifiedDate: Date = Date()
    var isSystemStyle: Bool = false
    
    // MARK: - Relationships
    var styleSheet: StyleSheet?
    
    // MARK: - Computed Properties
    
    var defaultAlignment: ImageAttachment.ImageAlignment {
        get { ImageAttachment.ImageAlignment(rawValue: defaultAlignmentRaw) ?? .center }
        set { defaultAlignmentRaw = newValue.rawValue }
    }
    
    // MARK: - Initialization
    
    init(
        name: String,
        displayName: String,
        displayOrder: Int = 0,
        defaultScale: CGFloat = 1.0,
        defaultAlignment: ImageAttachment.ImageAlignment = .center,
        hasCaptionByDefault: Bool = false,
        defaultCaptionStyle: String = "caption1",
        isSystemStyle: Bool = false
    ) {
        self.name = name
        self.displayName = displayName
        self.displayOrder = displayOrder
        self.defaultScale = defaultScale
        self.defaultAlignment = defaultAlignment
        self.hasCaptionByDefault = hasCaptionByDefault
        self.defaultCaptionStyle = defaultCaptionStyle
        self.isSystemStyle = isSystemStyle
    }
    
    /// Create default image style
    static func createDefault() -> ImageStyle {
        return ImageStyle(
            name: "default",
            displayName: "Default",
            displayOrder: 0,
            defaultScale: 1.0,
            defaultAlignment: .center,
            hasCaptionByDefault: false,
            defaultCaptionStyle: "caption1",
            isSystemStyle: true
        )
    }
}
