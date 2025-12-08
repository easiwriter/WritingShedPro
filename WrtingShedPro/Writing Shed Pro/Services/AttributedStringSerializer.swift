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
    
    // Comment attachment properties
    var isCommentAttachment: Bool?
    var commentID: String?
    var commentIsResolved: Bool?
    
    // Footnote attachment properties
    var isFootnoteAttachment: Bool?
    var footnoteID: String?
    var footnoteNumber: Int?
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
        var rangesToAddLabel: [NSRange] = []
        
        // Find all color attributes that should be stripped or ranges with no color
        mutableString.enumerateAttribute(.foregroundColor, in: fullRange, options: []) { value, range, _ in
            if let color = value as? UIColor {
                print("🧹 Found foreground color at range {\(range.location), \(range.length)}: \(color.toHex() ?? "unknown")")
                if isAdaptiveSystemColor(color) || isFixedBlackOrWhite(color) {
                    rangesToStrip.append((range, color))
                    rangesToAddLabel.append(range)
                }
            } else {
                // No color attribute in this range - need to add .label for dark mode support
                rangesToAddLabel.append(range)
            }
        }
        
//        if !hasAnyColorAttribute {
//            print("🧹 WARNING: No foreground color attributes found in string (length: \(mutableString.length))")
//            print("🧹 Will add .label color explicitly for dark mode support")
//        }
        
        // Remove adaptive colors first
        for (range, color) in rangesToStrip {
            mutableString.removeAttribute(.foregroundColor, range: range)
            print("🧹 Stripped adaptive color \(color.toHex() ?? "unknown") from range {\(range.location), \(range.length)}")
        }
        
        // Add .label color to ranges that have no color or had adaptive colors removed
        // This ensures UITextView uses adaptive color instead of defaulting to black
        for range in rangesToAddLabel {
            mutableString.addAttribute(.foregroundColor, value: UIColor.label, range: range)
//            print("🧹 Added .label color for adaptive dark mode at range {\(range.location), \(range.length)}")
        }
        
//        if !rangesToStrip.isEmpty {
//            print("🧹 Stripped \(rangesToStrip.count) adaptive color ranges and added .label")
//        } else if hasAnyColorAttribute {
//            print("🧹 Found colors but none were adaptive - preserving user colors")
//        } else if !rangesToAddLabel.isEmpty {
//            print("🧹 Added .label to \(rangesToAddLabel.count) ranges with no color")
//        }
        
        return mutableString
    }
    
    // MARK: - Attribute-based Encoding/Decoding
    
    /// Encode NSAttributedString to Data by extracting font traits
    /// - Parameter attributedString: The attributed string to encode
    /// - Returns: Encoded data
    static func encode(_ attributedString: NSAttributedString) -> Data {
        // Debug: Count attachments in the string we're encoding
        var commentCount = 0
        var imageCount = 0
        attributedString.enumerateAttribute(.attachment, in: NSRange(location: 0, length: attributedString.length)) { value, range, _ in
            if value is CommentAttachment {
                commentCount += 1
            } else if value is ImageAttachment {
                imageCount += 1
            }
        }
        print("💾📝 ENCODE START: String has \(commentCount) comments and \(imageCount) images")
        
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
                        // print("💾 ENCODE at \(range.location): font=\(attributes.fontName ?? "nil"), bold=\(isBold), italic=\(isItalic)")
                        
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
                                // print("💾 ENCODE color at \(range.location): \(color.toHex() ?? "nil") (explicit color)")
                            } else {
                                // print("💾 SKIP color at \(range.location): adaptive/black/white color (will adapt to appearance)")
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
                            // print("💾 ENCODE textStyle at \(range.location): \(styleValue)")
                        }
                    
                    case .attachment:
                        // Handle image and comment attachments
                        // print("💾 ENCODE: Found attachment at \(range.location), type: \(type(of: value))")
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
                            
                            // Logging commented out to reduce console spam during undo/version saves
                            // print("💾 ENCODE image at \(range.location): id=\(imageAttachment.imageID), scale=\(imageAttachment.scale), alignment=\(imageAttachment.alignment.rawValue)")
                        } else if let commentAttachment = value as? CommentAttachment {
                            attributes.isCommentAttachment = true
                            attributes.commentID = commentAttachment.commentID.uuidString
                            attributes.commentIsResolved = commentAttachment.isResolved
                            print("💬💾 ENCODE comment at \(range.location): id=\(commentAttachment.commentID), resolved=\(commentAttachment.isResolved)")
                        } else if let footnoteAttachment = value as? FootnoteAttachment {
                            attributes.isFootnoteAttachment = true
                            attributes.footnoteID = footnoteAttachment.footnoteID.uuidString
                            attributes.footnoteNumber = footnoteAttachment.number
                            print("📝💾 ENCODE footnote at \(range.location): id=\(footnoteAttachment.footnoteID), number=\(footnoteAttachment.number)")
                        } else {
                            print("💾 ⚠️ ENCODE: Attachment is neither Image, Comment, nor Footnote - type: \(type(of: value))")
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
            
            let _ = jsonAttributesArray.filter { $0.isCommentAttachment == true }.count
            let _ = jsonAttributesArray.filter { $0.isFootnoteAttachment == true }.count
            let _ = jsonAttributesArray.filter { $0.isImageAttachment == true }.count
//            print("📖 DECODE: Found \(commentCount) comments, \(footnoteCount) footnotes, and \(imageCount) images in saved data")
            
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
                }
                
                // Comment attachment - reconstruct CommentAttachment
                if let isComment = jsonAttributes.isCommentAttachment, isComment,
                   let commentIDString = jsonAttributes.commentID,
                   let commentID = UUID(uuidString: commentIDString) {
                    
                    // Create CommentAttachment
                    let isResolved = jsonAttributes.commentIsResolved ?? false
                    let attachment = CommentAttachment(commentID: commentID, isResolved: isResolved)
                    
                    // Debug: Check if the character at this position is the attachment character
                    if location < result.length {
                        let char = (result.string as NSString).character(at: location)
                        let isAttachmentChar = (char == 0xFFFC)  // U+FFFC Object Replacement Character
//                        print("💬📖 DECODE comment at \(location): id=\(commentID), resolved=\(isResolved), length=\(length)")
                        print("       Character at position: \\u{\(String(format: "%04X", char))}, is attachment char: \(isAttachmentChar)")
                    } else {
//                        print("💬📖 DECODE comment at \(location): id=\(commentID) - POSITION OUT OF BOUNDS (text length: \(result.length))")
                    }
                    
                    attributes[.attachment] = attachment
                }
                
                // Footnote attachment - reconstruct FootnoteAttachment
                if let isFootnote = jsonAttributes.isFootnoteAttachment, isFootnote,
                   let footnoteIDString = jsonAttributes.footnoteID,
                   let footnoteID = UUID(uuidString: footnoteIDString),
                   let footnoteNumber = jsonAttributes.footnoteNumber {
                    
                    // Create FootnoteAttachment
                    let attachment = FootnoteAttachment(footnoteID: footnoteID, number: footnoteNumber)
                    
                    // Debug: Check if the character at this position is the attachment character
                    if location < result.length {
                        let char = (result.string as NSString).character(at: location)
                        let isAttachmentChar = (char == 0xFFFC)  // U+FFFC Object Replacement Character
//                        print("📝📖 DECODE footnote at \(location): id=\(footnoteID), number=\(footnoteNumber), length=\(length)")
                        print("       Character at position: \\u{\(String(format: "%04X", char))}, is attachment char: \(isAttachmentChar)")
                    } else {
//                        print("📝📖 DECODE footnote at \(location): id=\(footnoteID) - POSITION OUT OF BOUNDS (text length: \(result.length))")
                    }
                    
                    attributes[.attachment] = attachment
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
    static func fromRTF(_ data: Data, scaleFonts: Bool = false) -> NSAttributedString? {
        do {
            let rtfString = try NSAttributedString(
                data: data,
                options: [.documentType: NSAttributedString.DocumentType.rtf],
                documentAttributes: nil
            )
            
            // DEBUG: Log traits and attributes in RTF before scaling
            #if DEBUG
            var boldCount = 0
            var italicCount = 0
            var underlineCount = 0
            var strikeCount = 0
            rtfString.enumerateAttribute(.font, in: NSRange(location: 0, length: rtfString.length)) { value, _, _ in
                if let font = value as? UIFont {
                    if font.fontDescriptor.symbolicTraits.contains(.traitBold) { boldCount += 1 }
                    if font.fontDescriptor.symbolicTraits.contains(.traitItalic) { italicCount += 1 }
                }
            }
            rtfString.enumerateAttribute(.underlineStyle, in: NSRange(location: 0, length: rtfString.length)) { value, _, _ in
                if let style = value as? Int, style != 0 { underlineCount += 1 }
            }
            rtfString.enumerateAttribute(.strikethroughStyle, in: NSRange(location: 0, length: rtfString.length)) { value, _, _ in
                if let style = value as? Int, style != 0 { strikeCount += 1 }
            }
            print("📝 fromRTF: Decoded RTF has \(boldCount) bold, \(italicCount) italic, \(underlineCount) underline, \(strikeCount) strikethrough ranges")
            #endif
            
            // CRITICAL: Restore multiple spaces that were preserved as non-breaking spaces
            // During RTF encoding, we replaced consecutive spaces with U+00A0 to preserve them
            // Now convert them back to regular spaces for normal display
            let restoredString = restoreMultipleSpaces(rtfString)
            
            // Optionally scale fonts for legacy imports (Writing Shed 1.0 used smaller Mac fonts)
            // iOS/iPadOS needs larger scaling - 1.8x (80% increase) for comfortable reading
            // This matches the typical zoom level users prefer (130% of 1.4x ≈ 1.8x)
            let processedString: NSAttributedString
            if scaleFonts {
                processedString = self.scaleFonts(restoredString, scaleFactor: 1.8)
            } else {
                processedString = restoredString
            }
            
            // CRITICAL: Strip adaptive colors (black/white/gray) from RTF imports
            // RTF data from Mac often contains explicit black color that doesn't adapt to dark mode
            // This is especially important for legacy imports from Writing Shed 1.0
            // The stripAdaptiveColors function removes black/white/gray colors while preserving
            // user-selected colors (red, blue, etc.) so text adapts to appearance mode
            return stripAdaptiveColors(from: processedString)
        } catch {
            print("❌ AttributedStringSerializer.fromRTF error: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Restore multiple consecutive spaces from non-breaking spaces
    /// During RTF encoding, we preserved spaces as U+00A0, now convert back to regular spaces
    /// - Parameter attributedString: The attributed string to process
    /// - Returns: New attributed string with restored regular spaces
    private static func restoreMultipleSpaces(_ attributedString: NSAttributedString) -> NSAttributedString {
        let text = attributedString.string
        
        // Only process if there are non-breaking spaces
        guard text.contains("\u{00A0}") else {
            return attributedString
        }
        
        let mutableString = NSMutableAttributedString(attributedString: attributedString)
        let pattern = "\u{00A0}+" // One or more non-breaking spaces
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return attributedString
        }
        
        let range = NSRange(location: 0, length: mutableString.length)
        let matches = regex.matches(in: mutableString.string, options: [], range: range)
        
        // Process matches in reverse to maintain correct indices
        for match in matches.reversed() {
            let matchRange = match.range
            let nonBreakingSpaces = (mutableString.string as NSString).substring(with: matchRange)
            
            // Replace non-breaking spaces with regular spaces
            let regularSpaces = String(repeating: " ", count: nonBreakingSpaces.count)
            
            // Get attributes from the first character of the match
            let attrs = mutableString.attributes(at: matchRange.location, effectiveRange: nil)
            let replacement = NSAttributedString(string: regularSpaces, attributes: attrs)
            
            mutableString.replaceCharacters(in: matchRange, with: replacement)
        }
        
        return mutableString
    }
    
    /// Decode RTF data with font scaling for legacy imports
    /// - Parameter data: The RTF data to decode
    /// - Returns: NSAttributedString with scaled fonts, or nil if decoding fails
    static func fromLegacyRTF(_ data: Data) -> NSAttributedString? {
        return fromRTF(data, scaleFonts: true)
    }
    
    /// Scale all fonts in an attributed string by a factor
    /// Used for legacy imports where Mac font sizes need iOS adjustment
    /// 
    /// DESIGN: The scaling is purely for readability, not semantic meaning:
    /// - All text is marked as .body style regardless of final font size
    /// - Bold/italic/underline traits are preserved in the UIFont
    /// - The .textStyle attribute ensures text is treated as Body, not matched by size
    /// 
    /// - Parameters:
    ///   - attributedString: The attributed string to scale
    ///   - scaleFactor: Multiplicative scale factor (e.g., 1.8 for 80% increase)
    /// - Returns: New attributed string with scaled fonts and .textStyle = .body attributes
    static func scaleFonts(_ attributedString: NSAttributedString, scaleFactor: CGFloat) -> NSAttributedString {
        guard scaleFactor != 1.0 && attributedString.length > 0 else {
            return attributedString
        }
        
        let mutableString = NSMutableAttributedString(attributedString: attributedString)
        let range = NSRange(location: 0, length: mutableString.length)
        
        var boldRangesBefore = 0
        var italicRangesBefore = 0
        var boldRangesAfter = 0
        var italicRangesAfter = 0
        
        // Count traits BEFORE scaling
        mutableString.enumerateAttribute(.font, in: range, options: []) { value, _, _ in
            if let font = value as? UIFont {
                if font.fontDescriptor.symbolicTraits.contains(.traitBold) { boldRangesBefore += 1 }
                if font.fontDescriptor.symbolicTraits.contains(.traitItalic) { italicRangesBefore += 1 }
            }
        }
        
        mutableString.enumerateAttribute(.font, in: range, options: []) { value, range, _ in
            if let font = value as? UIFont {
                let newSize = font.pointSize * scaleFactor
                
                // CRITICAL: Preserve symbolic traits (bold, italic) when scaling
                // UIFont.withSize() loses traits, so we must use the font descriptor
                let descriptor = font.fontDescriptor
                let scaledDescriptor = descriptor.withSize(newSize)
                let scaledFont = UIFont(descriptor: scaledDescriptor, size: newSize)
                
                mutableString.addAttribute(.font, value: scaledFont, range: range)
                
                // IMPORTANT: Set .textStyle = .body for all legacy imported text
                // The 1.8x scaling is purely for readability (Mac 12pt → iOS 21.6pt)
                // This should NOT affect semantic meaning - all body text should remain Body style
                // The .textStyle attribute takes priority over font-size-based style matching
                // Bold/italic/underline traits are preserved in the scaled font descriptor
                mutableString.addAttribute(.textStyle, value: UIFont.TextStyle.body.attributeValue, range: range)
            }
        }
        
        // Count traits and attributes AFTER scaling
        var underlineRangesAfter = 0
        var strikeRangesAfter = 0
        mutableString.enumerateAttribute(.font, in: range, options: []) { value, _, _ in
            if let font = value as? UIFont {
                if font.fontDescriptor.symbolicTraits.contains(.traitBold) { boldRangesAfter += 1 }
                if font.fontDescriptor.symbolicTraits.contains(.traitItalic) { italicRangesAfter += 1 }
            }
        }
        mutableString.enumerateAttribute(.underlineStyle, in: range, options: []) { value, _, _ in
            if let style = value as? Int, style != 0 { underlineRangesAfter += 1 }
        }
        mutableString.enumerateAttribute(.strikethroughStyle, in: range, options: []) { value, _, _ in
            if let style = value as? Int, style != 0 { strikeRangesAfter += 1 }
        }
        
        print("📝 scaleFonts: BEFORE: \(boldRangesBefore) bold, \(italicRangesBefore) italic | AFTER: \(boldRangesAfter) bold, \(italicRangesAfter) italic, \(underlineRangesAfter) underline, \(strikeRangesAfter) strikethrough")
        
        if boldRangesBefore != boldRangesAfter || italicRangesBefore != italicRangesAfter {
            print("⚠️ WARNING: Trait counts changed during scaling!")
        }
        
        return mutableString
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
