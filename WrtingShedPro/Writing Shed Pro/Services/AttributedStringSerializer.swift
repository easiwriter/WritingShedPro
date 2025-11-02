import Foundation
import UIKit

/// Struct to hold attribute values for a range of text
struct AttributeValues: Codable {
    var location: Int?
    var length: Int?
    var fontName: String?
    var fontSize: CGFloat?
    var bold: Bool?
    var italic: Bool?
    var underline: CGFloat?
    var strikethrough: CGFloat?
    var textAlignment: Int?
    var lineHeightMultiple: CGFloat?
    var lineSpacing: CGFloat?
    var spaceBefore: CGFloat?
    var spaceAfter: CGFloat?
    var firstLineIndent: CGFloat?
    var headIndent: CGFloat?
    var tailIndent: CGFloat?
    var maxLineHeight: CGFloat?
    var minLineHeight: CGFloat?
    var textStyle: String?  // Stores UIFont.TextStyle.rawValue
    var textColorHex: String?  // Stores text color as hex string
    
    // Image attachment properties
    var isImageAttachment: Bool?
    var imageID: String?
    var imageData: String?  // Base64-encoded image data
    var imageScale: CGFloat?
    var imageAlignment: String?
    var hasCaption: Bool?
    var captionText: String?
    var captionStyle: String?
}

/// Service for converting between NSAttributedString and storable formats
struct AttributedStringSerializer {
    
    // MARK: - Adaptive Color Detection
    
    /// Check if a color is an adaptive system color that should not be serialized
    /// These colors automatically adapt to light/dark mode
    /// - Parameter color: The UIColor to check
    /// - Returns: true if this is an adaptive system color
    static func isAdaptiveSystemColor(_ color: UIColor) -> Bool {
        // CRITICAL: Can't use color == .label because dynamic colors don't compare correctly
        // Instead, check if the color resolves to pure black or white, which indicates
        // it's likely a system adaptive color
        
        // Get the hex value of the resolved color
        guard let hex = color.toHex() else {
            print("🔍 isAdaptiveSystemColor: Failed to convert color to hex")
            return false
        }
        let upperHex = hex.uppercased()
        
        print("🔍 isAdaptiveSystemColor: Checking color with hex=\(upperHex)")
        
        // If it's pure black or white, treat it as adaptive
        // This catches both .label in light mode (black) and dark mode (white)
        if upperHex == "#000000" || upperHex == "#000000FF" ||
           upperHex == "#FFFFFF" || upperHex == "#FFFFFFFF" {
            print("   ✅ IS adaptive (black or white)")
            return true
        }
        
        // Also check for gray colors that might be .secondaryLabel, etc.
        // These resolve to various shades of gray
        if upperHex.hasPrefix("#") {
            let hexWithoutHash = String(upperHex.dropFirst())
            // Extract RGB components
            if hexWithoutHash.count >= 6 {
                let r = hexWithoutHash.prefix(2)
                let g = hexWithoutHash.dropFirst(2).prefix(2)
                let b = hexWithoutHash.dropFirst(4).prefix(2)
                
                // If R, G, B are all equal (gray), likely a system label color
                if r == g && g == b {
                    print("   ✅ IS adaptive (gray R=G=B)")
                    return true
                }
            }
        }
        
        print("   ❌ NOT adaptive (user color)")
        return false
    }
    
    /// Check if a color is a fixed black or white that should be treated as adaptive
    /// This handles colors from old documents that have fixed black/white
    /// - Parameter color: The UIColor to check
    /// - Returns: true if this is pure black or white
    static func isFixedBlackOrWhite(_ color: UIColor) -> Bool {
        guard let hex = color.toHex() else {
            print("🔍 isFixedBlackOrWhite: Failed to convert color to hex")
            return false
        }
        // Check for pure black or white (with or without alpha)
        let upperHex = hex.uppercased()
        let result = upperHex == "#000000" || upperHex == "#000000FF" ||
                     upperHex == "#FFFFFF" || upperHex == "#FFFFFFFF"
        print("🔍 isFixedBlackOrWhite: hex=\(upperHex) result=\(result)")
        return result
    }
    
    /// Strip adaptive colors from an attributed string
    /// This removes .foregroundColor attributes that are system adaptive colors or pure black/white
    /// Allows the text to adapt to the current appearance mode
    /// - Parameter attributedString: The attributed string to clean
    /// - Returns: A new attributed string without adaptive colors
    static func stripAdaptiveColors(from attributedString: NSAttributedString) -> NSAttributedString {
        let mutableString = NSMutableAttributedString(attributedString: attributedString)
        let fullRange = NSRange(location: 0, length: mutableString.length)
        
        var rangesToStrip: [(NSRange, UIColor)] = []
        
        // Find all color attributes that should be stripped
        mutableString.enumerateAttribute(.foregroundColor, in: fullRange, options: []) { value, range, _ in
            if let color = value as? UIColor {
                if isAdaptiveSystemColor(color) || isFixedBlackOrWhite(color) {
                    rangesToStrip.append((range, color))
                }
            }
        }
        
        // Remove adaptive colors
        for (range, color) in rangesToStrip {
            mutableString.removeAttribute(.foregroundColor, range: range)
            #if DEBUG
            print("🧹 Stripped adaptive color \(color.toHex() ?? "unknown") from range {\(range.location), \(range.length)}")
            #endif
        }
        
        #if DEBUG
        if !rangesToStrip.isEmpty {
            print("🧹 Stripped \(rangesToStrip.count) adaptive color ranges - text will now adapt to appearance mode")
        }
        #endif
        
        return mutableString
    }
    
    // MARK: - Attribute-based Encoding/Decoding
    
    /// Encode NSAttributedString to Data by extracting font traits
    /// - Parameter attributedString: The attributed string to encode
    /// - Returns: Encoded data
    static func encode(_ attributedString: NSAttributedString) -> Data {
        var allAttributes = [AttributeValues]()
        let range = NSRange(location: 0, length: attributedString.length)
        
        if attributedString.length > 0 {
            attributedString.enumerateAttributes(in: range, options: []) { (attr, range, _) in
                var attributes = AttributeValues()
                attributes.location = range.location
                attributes.length = range.length
                
                attr.forEach { (key, value) in
                    switch key {
                    case .font:
                        let font = value as? UIFont
                        let desc = font?.fontDescriptor
                        
                        // Check if this is a dynamic type font by looking at the family name
                        let familyName = desc?.fontAttributes[.family] as? String
                        if let familyName = familyName, familyName.contains("UICTFont") {
                            // Store the dynamic type style name, not the rendered font name
                            attributes.fontName = familyName
                        } else {
                            // Store the actual font name for non-dynamic fonts
                            attributes.fontName = font?.fontName ?? "Helvetica"
                        }
                        
                        attributes.fontSize = font?.pointSize ?? 17
                        let isBold = desc?.symbolicTraits.contains(.traitBold) ?? false
                        let isItalic = desc?.symbolicTraits.contains(.traitItalic) ?? false
                        attributes.bold = isBold
                        attributes.italic = isItalic
                        print("💾 ENCODE at \(range.location): font=\(attributes.fontName ?? "nil"), bold=\(isBold), italic=\(isItalic)")
                        
                    case .underlineStyle:
                        attributes.underline = value as? CGFloat
                        
                    case .strikethroughStyle:
                        attributes.strikethrough = value as? CGFloat
                    
                    case .foregroundColor:
                        // CRITICAL: Only store explicitly set colors, NOT system adaptive colors
                        // System colors like .label adapt to light/dark mode automatically
                        // If we serialize them, they become fixed black/white and break appearance switching
                        if let color = value as? UIColor {
                            // Use helper to check if this should be skipped
                            if !isAdaptiveSystemColor(color) && !isFixedBlackOrWhite(color) {
                                // Only serialize non-adaptive colors (user-selected colors)
                                attributes.textColorHex = color.toHex()
                                print("💾 ENCODE color at \(range.location): \(color.toHex() ?? "nil") (explicit color)")
                            } else {
                                print("💾 SKIP color at \(range.location): adaptive/black/white color (will adapt to appearance)")
                            }
                        }
                        
                    case .paragraphStyle:
                        let ps = value as? NSParagraphStyle
                        // Only store alignment if it's not the default .natural (0)
                        if let alignment = ps?.alignment, alignment != .natural {
                            attributes.textAlignment = alignment.rawValue
                        }
                        // Only store non-zero values to avoid NaN errors when reconstructing
                        if let multiple = ps?.lineHeightMultiple, multiple != 0 {
                            attributes.lineHeightMultiple = multiple
                        }
                        if let spacing = ps?.lineSpacing, spacing != 0 {
                            attributes.lineSpacing = spacing
                        }
                        if let before = ps?.paragraphSpacingBefore, before != 0 {
                            attributes.spaceBefore = before
                        }
                        if let after = ps?.paragraphSpacing, after != 0 {
                            attributes.spaceAfter = after
                        }
                        if let first = ps?.firstLineHeadIndent, first != 0 {
                            attributes.firstLineIndent = first
                        }
                        if let head = ps?.headIndent, head != 0 {
                            attributes.headIndent = head
                        }
                        if let tail = ps?.tailIndent, tail != 0 {
                            attributes.tailIndent = tail
                        }
                        // Critical: Don't store 0 for line heights - causes NaN in CoreGraphics
                        if let maxHeight = ps?.maximumLineHeight, maxHeight > 0 {
                            attributes.maxLineHeight = maxHeight
                        }
                        if let minHeight = ps?.minimumLineHeight, minHeight > 0 {
                            attributes.minLineHeight = minHeight
                        }
                    
                    case .textStyle:
                        // Store the text style raw value
                        if let styleValue = value as? String {
                            attributes.textStyle = styleValue
                            print("💾 ENCODE textStyle at \(range.location): \(styleValue)")
                        }
                    
                    case .attachment:
                        // Handle image attachments
                        if let imageAttachment = value as? ImageAttachment {
                            attributes.isImageAttachment = true
                            attributes.imageID = imageAttachment.imageID.uuidString
                            
                            // Encode image data as base64
                            if let imageData = imageAttachment.imageData {
                                attributes.imageData = imageData.base64EncodedString()
                            }
                            
                            attributes.imageScale = imageAttachment.scale
                            attributes.imageAlignment = imageAttachment.alignment.rawValue
                            attributes.hasCaption = imageAttachment.hasCaption
                            attributes.captionText = imageAttachment.captionText
                            attributes.captionStyle = imageAttachment.captionStyle
                            
                            print("💾 ENCODE image at \(range.location): id=\(imageAttachment.imageID), scale=\(imageAttachment.scale), alignment=\(imageAttachment.alignment.rawValue)")
                        }
                        
                    default:
                        break
                    }
                }
                allAttributes.append(attributes)
            }
        }
        
        do {
            return try PropertyListEncoder().encode(allAttributes)
        } catch {
            print("❌ Error encoding attributed string: \(error)")
            return Data()
        }
    }
    
    /// Decode Data to NSAttributedString using plain text and attribute data
    /// - Parameters:
    ///   - data: The encoded attribute data
    ///   - text: The plain text content
    /// - Returns: Reconstructed NSAttributedString
    static func decode(_ data: Data, text: String) -> NSAttributedString {
        // Start with body font and textStyle as default
        let result = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: UIFont.preferredFont(forTextStyle: .body),
                .textStyle: UIFont.TextStyle.body.attributeValue
            ]
        )
        
        guard result.length > 0, !data.isEmpty else {
            return result
        }
        
        do {
            let jsonAttributesArray = try PropertyListDecoder().decode([AttributeValues].self, from: data)
            
            jsonAttributesArray.forEach { jsonAttributes in
                guard let location = jsonAttributes.location,
                      let length = jsonAttributes.length,
                      location + length <= result.length else {
                    return
                }
                
                var attributes = [NSAttributedString.Key: Any]()
                
                // Reconstruct font with traits
                if let fontName = jsonAttributes.fontName,
                   let fontSize = jsonAttributes.fontSize {
                    
                    var font: UIFont
                    let isBold = jsonAttributes.bold ?? false
                    let isItalic = jsonAttributes.italic ?? false
                    
                    print("💾 DECODE at \(location): fontName=\(fontName), bold=\(isBold), italic=\(isItalic)")
                    
                    // Check if this is a dynamic type font (UICTFont)
                    if fontName.contains("UICT") || fontName.contains("TextStyle") {
                        // Use dynamic type font - preserves size category preferences
                        let baseFont = UIFont.preferredFont(forTextStyle: .body)
                        // Adjust size if it differs from the default
                        let adjustedFont = abs(baseFont.pointSize - fontSize) > 0.5 ? baseFont.withSize(fontSize) : baseFont
                        // Apply traits using the proven method
                        font = UIFont.fontWithNameAndTraits(adjustedFont.familyName, size: fontSize, bold: isBold, italic: isItalic)
                    } else {
                        // Use the font name directly with traits
                        font = UIFont.fontWithNameAndTraits(fontName, size: fontSize, bold: isBold, italic: isItalic)
                    }
                    
                    print("💾   Final font: \(font.fontName)")
                    
                    attributes[.font] = font
                }
                
                // Underline
                if let underline = jsonAttributes.underline, underline > 0 {
                    attributes[.underlineStyle] = underline
                }
                
                // Strikethrough
                if let strikethrough = jsonAttributes.strikethrough, strikethrough > 0 {
                    attributes[.strikethroughStyle] = strikethrough
                }
                
                // Text color
                if let colorHex = jsonAttributes.textColorHex,
                   let color = UIColor(hex: colorHex) {
                    attributes[.foregroundColor] = color
                    print("💾 DECODE color at \(location): \(colorHex)")
                }
                
                // Text style - restore the stored style name
                if let textStyleValue = jsonAttributes.textStyle {
                    attributes[.textStyle] = textStyleValue
                }
                
                // Paragraph style - only add if we have non-default values
                var hasParagraphStyleAttributes = false
                let paragraphStyle = NSMutableParagraphStyle()
                
                if let alignment = jsonAttributes.textAlignment {
                    paragraphStyle.alignment = NSTextAlignment(rawValue: alignment) ?? .natural
                    hasParagraphStyleAttributes = true
                }
                if let lineHeightMultiple = jsonAttributes.lineHeightMultiple {
                    paragraphStyle.lineHeightMultiple = lineHeightMultiple
                    hasParagraphStyleAttributes = true
                }
                if let lineSpacing = jsonAttributes.lineSpacing {
                    paragraphStyle.lineSpacing = lineSpacing
                    hasParagraphStyleAttributes = true
                }
                if let spaceBefore = jsonAttributes.spaceBefore {
                    paragraphStyle.paragraphSpacingBefore = spaceBefore
                    hasParagraphStyleAttributes = true
                }
                if let spaceAfter = jsonAttributes.spaceAfter {
                    paragraphStyle.paragraphSpacing = spaceAfter
                    hasParagraphStyleAttributes = true
                }
                if let firstLineIndent = jsonAttributes.firstLineIndent {
                    paragraphStyle.firstLineHeadIndent = firstLineIndent
                    hasParagraphStyleAttributes = true
                }
                if let headIndent = jsonAttributes.headIndent {
                    paragraphStyle.headIndent = headIndent
                    hasParagraphStyleAttributes = true
                }
                if let tailIndent = jsonAttributes.tailIndent {
                    paragraphStyle.tailIndent = tailIndent
                    hasParagraphStyleAttributes = true
                }
                if let maxLineHeight = jsonAttributes.maxLineHeight, maxLineHeight > 0 {
                    paragraphStyle.maximumLineHeight = maxLineHeight
                    hasParagraphStyleAttributes = true
                }
                if let minLineHeight = jsonAttributes.minLineHeight, minLineHeight > 0 {
                    paragraphStyle.minimumLineHeight = minLineHeight
                    hasParagraphStyleAttributes = true
                }
                
                // Only add paragraph style if we actually have custom values
                if hasParagraphStyleAttributes {
                    attributes[.paragraphStyle] = paragraphStyle
                }
                
                // Image attachment - reconstruct ImageAttachment
                if let isImage = jsonAttributes.isImageAttachment, isImage,
                   let imageIDString = jsonAttributes.imageID,
                   let imageID = UUID(uuidString: imageIDString) {
                    
                    // Create ImageAttachment
                    let attachment = ImageAttachment()
                    attachment.imageID = imageID
                    
                    // Decode image data from base64
                    if let imageDataString = jsonAttributes.imageData,
                       let imageData = Data(base64Encoded: imageDataString) {
                        attachment.imageData = imageData
                        attachment.image = UIImage(data: imageData)
                    }
                    
                    // Restore scale and alignment
                    if let scale = jsonAttributes.imageScale {
                        attachment.scale = scale
                    }
                    
                    if let alignmentString = jsonAttributes.imageAlignment,
                       let alignment = ImageAttachment.ImageAlignment(rawValue: alignmentString) {
                        attachment.alignment = alignment
                    }
                    
                    // Restore caption
                    attachment.hasCaption = jsonAttributes.hasCaption ?? false
                    attachment.captionText = jsonAttributes.captionText
                    attachment.captionStyle = jsonAttributes.captionStyle
                    
                    // Update bounds
                    attachment.bounds = CGRect(origin: .zero, size: attachment.displaySize)
                    
                    attributes[.attachment] = attachment
                    
                    print("💾 DECODE image at \(location): id=\(imageID), scale=\(attachment.scale), alignment=\(attachment.alignment.rawValue)")
                }
                
                result.addAttributes(attributes, range: NSRange(location: location, length: length))
            }
        } catch {
            print("❌ Error decoding attributed string: \(error)")
        }
        
        // CRITICAL: Strip adaptive colors after decoding
        // This handles old documents that have fixed black/white colors
        return stripAdaptiveColors(from: result)
    }
    
    // MARK: - RTF Conversion
    
    /// Convert NSAttributedString to RTF Data for storage
    /// - Parameter attributedString: The attributed string to convert
    /// - Returns: RTF data, or nil if conversion fails
    static func toRTF(_ attributedString: NSAttributedString) -> Data? {
        let range = NSRange(location: 0, length: attributedString.length)
        
        do {
            return try attributedString.data(
                from: range,
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
            )
        } catch {
            print("❌ AttributedStringSerializer.toRTF error: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Convert RTF Data to NSAttributedString
    /// - Parameter data: The RTF data to convert
    /// - Returns: NSAttributedString, or nil if conversion fails
    static func fromRTF(_ data: Data) -> NSAttributedString? {
        do {
            return try NSAttributedString(
                data: data,
                options: [.documentType: NSAttributedString.DocumentType.rtf],
                documentAttributes: nil
            )
        } catch {
            print("❌ AttributedStringSerializer.fromRTF error: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Plain Text Extraction
    
    /// Extract plain text from NSAttributedString (strips all formatting)
    /// - Parameter attributedString: The attributed string
    /// - Returns: Plain text string
    static func toPlainText(_ attributedString: NSAttributedString) -> String {
        return attributedString.string
    }
    
    // MARK: - Size Estimation
    
    /// Get estimated storage size for an attributed string
    /// - Parameter attributedString: The attributed string
    /// - Returns: Estimated size in bytes
    static func estimatedSize(_ attributedString: NSAttributedString) -> Int {
        return toRTF(attributedString)?.count ?? 0
    }
    
    // MARK: - Validation
    
    /// Test if an attributed string can be successfully converted to RTF and back
    /// - Parameter attributedString: The attributed string to test
    /// - Returns: True if round-trip conversion succeeds
    static func validateRoundTrip(_ attributedString: NSAttributedString) -> Bool {
        guard let rtfData = toRTF(attributedString) else {
            return false
        }
        guard let restored = fromRTF(rtfData) else {
            return false
        }
        // Check if plain text is preserved
        return restored.string == attributedString.string
    }
}
