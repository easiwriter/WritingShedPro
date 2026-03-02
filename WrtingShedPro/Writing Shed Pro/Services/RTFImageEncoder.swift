//
//  RTFImageEncoder.swift
//  Writing Shed Pro
//
//  Custom RTF generator with image embedding support
//  Created on 11 December 2025.
//

import Foundation
import UIKit

/// Service for encoding NSAttributedString to RTF format with image support
class RTFImageEncoder {
    
    /// Convert an attributed string to RTF data with embedded images
    /// - Parameter attributedString: The attributed string to convert
    /// - Returns: RTF data, or nil if conversion fails
    static func encodeToRTF(_ attributedString: NSAttributedString) -> Data? {
        let rtfString = generateRTF(from: attributedString)
        return rtfString.data(using: .utf8)
    }
    
    /// Check if the attributed string contains any images
    /// - Parameter attributedString: The attributed string to check
    /// - Returns: True if images are found
    static func containsImages(_ attributedString: NSAttributedString) -> Bool {
        var hasImages = false
        attributedString.enumerateAttribute(.attachment, in: NSRange(location: 0, length: attributedString.length)) { value, _, stop in
            if value is ImageAttachment {
                hasImages = true
                stop.pointee = true
            } else if let attachment = value as? NSTextAttachment,
                      attachment.image != nil || attachment.contents != nil {
                hasImages = true
                stop.pointee = true
            }
        }
        return hasImages
    }
    
    /// Generate RTF string from attributed string
    private static func generateRTF(from attributedString: NSAttributedString) -> String {
        var rtf = """
        {\\rtf1\\ansi\\ansicpg1252\\cocoartf2709
        \\cocoatextscaling0\\cocoaplatform0{\\fonttbl\\f0\\fswiss\\fcharset0 Helvetica;}
        {\\colortbl;\\red255\\green255\\blue255;\\red0\\green0\\blue0;}
        {\\*\\expandedcolortbl;;\\cssrgb\\c0\\c0\\c0;}
        \\margl1440\\margr1440\\vieww11520\\viewh8400\\viewkind0
        \\pard\\tx720\\tx1440\\tx2160\\tx2880\\tx3600\\tx4320\\tx5040\\tx5760\\tx6480\\tx7200\\tx7920\\tx8640\\pardirnatural\\partightenfactor0
        
        """
        
        #if DEBUG
        print("📝 RTF: Starting to encode \(attributedString.length) characters")
        #endif
        #if DEBUG
        print("📝 RTF: String content: \(attributedString.string.prefix(100))...")
        #endif
        
        // Process the attributed string character by character
        let length = attributedString.length
        var currentAttributes: [NSAttributedString.Key: Any]? = nil
        
        for i in 0..<length {
            let range = NSRange(location: i, length: 1)
            let attributes = attributedString.attributes(at: i, effectiveRange: nil)
            let character = (attributedString.string as NSString).substring(with: range)
            
            // Check if this is an image attachment.
            // Handle both ImageAttachment and generic NSTextAttachment (which can occur
            // when copying attributed strings re-archives the custom subclass).
            if let imageAttachment = attributes[.attachment] as? ImageAttachment {
                // Close any open formatting before the image
                if currentAttributes != nil {
                    rtf += closeFormatting(currentAttributes!)
                    currentAttributes = nil
                }
                
                #if DEBUG
                print("📷 RTF: Embedding ImageAttachment at position \(i)")
                #endif
                
                rtf += generateRTFImage(from: imageAttachment)
                continue
            } else if let genericAttachment = attributes[.attachment] as? NSTextAttachment,
                      genericAttachment.image != nil || genericAttachment.contents != nil {
                // Fallback for generic NSTextAttachment that has image data
                if currentAttributes != nil {
                    rtf += closeFormatting(currentAttributes!)
                    currentAttributes = nil
                }
                
                #if DEBUG
                print("📷 RTF: Embedding generic NSTextAttachment at position \(i)")
                #endif
                
                rtf += generateRTFImageFromAttachment(genericAttachment)
                continue
            }
            
            // Check if attributes changed
            if currentAttributes == nil || !attributesEqual(currentAttributes!, attributes) {
                // Close previous formatting
                if currentAttributes != nil {
                    rtf += closeFormatting(currentAttributes!)
                }
                
                // Open new formatting
                rtf += openFormatting(attributes)
                currentAttributes = attributes
            }
            
            // Add the character (with RTF escaping)
            rtf += escapeRTFCharacter(character)
        }
        
        // Close any remaining formatting
        if currentAttributes != nil {
            rtf += closeFormatting(currentAttributes!)
        }
        
        rtf += "\n}"
        
        return rtf
    }
    
    // MARK: - Image Embedding
    
    /// Maximum dimension (width or height in pixels) for images embedded in RTF.
    /// Larger images are downscaled to keep the file size reasonable.
    private static let maxImageDimension: CGFloat = 1200
    
    /// Generate an RTF block that embeds the image inline using \\pict
    /// Includes paragraph alignment and an optional caption line below.
    private static func generateRTFImage(from attachment: ImageAttachment) -> String {
        // Load the UIImage from the attachment
        guard let image = attachment.image ?? (attachment.imageData.flatMap { UIImage(data: $0) }) else {
            #if DEBUG
            print("📷 RTF: No image data available — inserting placeholder")
            #endif
            let name = attachment.originalFilename ?? attachment.captionText ?? "Image"
            return "\\par [Image: \(escapeRTFString(name))]\\par\n"
        }
        
        // Determine the display size (pixels) after applying the attachment's scale
        let originalSize = image.size
        var pixelWidth  = originalSize.width  * attachment.scale
        var pixelHeight = originalSize.height * attachment.scale
        
        // Clamp to maxImageDimension to avoid enormous hex blobs
        if pixelWidth > maxImageDimension || pixelHeight > maxImageDimension {
            let factor = min(maxImageDimension / pixelWidth, maxImageDimension / pixelHeight)
            pixelWidth  *= factor
            pixelHeight *= factor
        }
        
        // Re-render at the target pixel size (scale 1.0 so size == pixels)
        let targetSize = CGSize(width: pixelWidth, height: pixelHeight)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resizedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        
        // Encode to JPEG (good balance of quality and size for RTF)
        guard let jpegData = resizedImage.jpegData(compressionQuality: 0.85) else {
            #if DEBUG
            print("📷 RTF: Failed to encode image as JPEG")
            #endif
            let name = attachment.originalFilename ?? attachment.captionText ?? "Image"
            return "\\par [Image: \(escapeRTFString(name))]\\par\n"
        }
        
        #if DEBUG
        print("📷 RTF: Encoded JPEG \(Int(pixelWidth))×\(Int(pixelHeight)), \(jpegData.count) bytes")
        #endif
        
        // RTF dimensions are in twips (1 twip = 1/1440 inch).
        // Assume 72 dpi for display: 1 pixel = 20 twips.
        let twipWidth  = Int(pixelWidth  * 20)
        let twipHeight = Int(pixelHeight * 20)
        
        // Paragraph alignment
        let alignmentCode: String
        switch attachment.alignment {
        case .center: alignmentCode = "\\qc"
        case .right:  alignmentCode = "\\qr"
        default:      alignmentCode = "\\ql"   // left / inline
        }
        
        // Build the hex string from JPEG data
        let hexString = jpegData.map { String(format: "%02x", $0) }.joined()
        
        // Build RTF: paragraph break, alignment, then {\pict ...}
        var block = "\\par\n"
        block += "\\pard\(alignmentCode)\\pardirnatural\\partightenfactor0\n"
        block += "{\\pict\\jpegblip\\picw\(Int(pixelWidth))\\pich\(Int(pixelHeight))\\picwgoal\(twipWidth)\\pichgoal\(twipHeight)\n"
        
        // Write hex in 128-char lines for readability
        var offset = hexString.startIndex
        while offset < hexString.endIndex {
            let end = hexString.index(offset, offsetBy: 128, limitedBy: hexString.endIndex) ?? hexString.endIndex
            block += String(hexString[offset..<end]) + "\n"
            offset = end
        }
        block += "}\n"
        
        // Add caption if present
        if attachment.hasCaption {
            let captionParts: [String] = [
                attachment.captionPrefix,
                attachment.captionNumber > 0 ? "\(attachment.captionNumber)" : nil,
                attachment.captionText
            ].compactMap { $0?.isEmpty == false ? $0 : nil }
            
            if !captionParts.isEmpty {
                let captionLine = captionParts.joined(separator: " ")
                // Caption in italic, centered, slightly smaller
                block += "\\pard\\qc\\pardirnatural\\partightenfactor0\n"
                block += "{\\f0\\fs20\\i " + escapeRTFString(captionLine) + "\\i0}\\par\n"
            }
        }
        
        // Restore left-aligned paragraph for subsequent text
        block += "\\pard\\pardirnatural\\partightenfactor0\n"
        
        return block
    }
    
    /// Generate an RTF image block from a generic NSTextAttachment.
    /// Used when the original ImageAttachment was re-archived into a plain NSTextAttachment
    /// during attributed string copy operations.
    private static func generateRTFImageFromAttachment(_ attachment: NSTextAttachment) -> String {
        // Try to get a UIImage from the attachment
        let image: UIImage?
        if let img = attachment.image {
            image = img
        } else if let data = attachment.contents {
            image = UIImage(data: data)
        } else if let fileWrapper = attachment.fileWrapper, let data = fileWrapper.regularFileContents {
            image = UIImage(data: data)
        } else {
            image = nil
        }
        
        guard let resolvedImage = image else {
            #if DEBUG
            print("📷 RTF: Generic attachment has no usable image data — skipping")
            #endif
            return "\\par [Image]\\par\n"
        }
        
        let originalSize = resolvedImage.size
        var pixelWidth  = originalSize.width
        var pixelHeight = originalSize.height
        
        // Clamp to maxImageDimension
        if pixelWidth > maxImageDimension || pixelHeight > maxImageDimension {
            let factor = min(maxImageDimension / pixelWidth, maxImageDimension / pixelHeight)
            pixelWidth  *= factor
            pixelHeight *= factor
        }
        
        let targetSize = CGSize(width: pixelWidth, height: pixelHeight)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resizedImage = renderer.image { _ in
            resolvedImage.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        
        guard let jpegData = resizedImage.jpegData(compressionQuality: 0.85) else {
            #if DEBUG
            print("📷 RTF: Failed to encode generic attachment as JPEG")
            #endif
            return "\\par [Image]\\par\n"
        }
        
        #if DEBUG
        print("📷 RTF: Encoded generic attachment JPEG \(Int(pixelWidth))×\(Int(pixelHeight)), \(jpegData.count) bytes")
        #endif
        
        let twipWidth  = Int(pixelWidth  * 20)
        let twipHeight = Int(pixelHeight * 20)
        
        let hexString = jpegData.map { String(format: "%02x", $0) }.joined()
        
        var block = "\\par\n"
        block += "\\pard\\qc\\pardirnatural\\partightenfactor0\n"
        block += "{\\pict\\jpegblip\\picw\(Int(pixelWidth))\\pich\(Int(pixelHeight))\\picwgoal\(twipWidth)\\pichgoal\(twipHeight)\n"
        
        var offset = hexString.startIndex
        while offset < hexString.endIndex {
            let end = hexString.index(offset, offsetBy: 128, limitedBy: hexString.endIndex) ?? hexString.endIndex
            block += String(hexString[offset..<end]) + "\n"
            offset = end
        }
        block += "}\n"
        
        // Restore left-aligned paragraph for subsequent text
        block += "\\pard\\pardirnatural\\partightenfactor0\n"
        
        return block
    }
    
    /// Escape a plain string for safe inclusion in RTF (no formatting, just content)
    private static func escapeRTFString(_ string: String) -> String {
        var result = ""
        for char in string {
            let s = String(char)
            result += escapeRTFCharacter(s)
        }
        return result
    }
    
    // MARK: - Formatting Helpers
    
    /// Open RTF formatting codes for given attributes
    private static func openFormatting(_ attributes: [NSAttributedString.Key: Any]) -> String {
        var rtf = ""
        
        // Font
        if let font = attributes[.font] as? UIFont {
            rtf += "\\f0"
            
            // Font size (in half-points)
            let fontSize = Int(font.pointSize * 2)
            rtf += "\\fs\(fontSize)"
            
            // Bold
            if font.fontDescriptor.symbolicTraits.contains(.traitBold) {
                rtf += "\\b"
            }
            
            // Italic
            if font.fontDescriptor.symbolicTraits.contains(.traitItalic) {
                rtf += "\\i"
            }
        }
        
        // Underline
        if let underlineStyle = attributes[.underlineStyle] as? Int, underlineStyle > 0 {
            rtf += "\\ul"
        }
        
        // Foreground color
        if attributes[.foregroundColor] != nil {
            // For simplicity, using color index 2 (black) for all text
            // In a full implementation, you'd build a color table
            rtf += "\\cf2"
        }
        
        rtf += " "
        return rtf
    }
    
    /// Close RTF formatting codes
    private static func closeFormatting(_ attributes: [NSAttributedString.Key: Any]) -> String {
        var rtf = ""
        
        if let font = attributes[.font] as? UIFont {
            if font.fontDescriptor.symbolicTraits.contains(.traitBold) {
                rtf += "\\b0"
            }
            if font.fontDescriptor.symbolicTraits.contains(.traitItalic) {
                rtf += "\\i0"
            }
        }
        
        if let underlineStyle = attributes[.underlineStyle] as? Int, underlineStyle > 0 {
            rtf += "\\ul0"
        }
        
        return rtf
    }
    
    /// Escape special RTF characters
    private static func escapeRTFCharacter(_ character: String) -> String {
        switch character {
        case "\\":
            return "\\\\"
        case "{":
            return "\\{"
        case "}":
            return "\\}"
        case "\n":
            return "\\line\n"
        case "\t":
            return "\\tab "
        default:
            // Check if character needs Unicode escaping
            if let scalar = character.unicodeScalars.first, scalar.value > 127 {
                return "\\u\(Int(scalar.value))?"
            }
            return character
        }
    }
    
    /// Compare two attribute dictionaries for equality
    private static func attributesEqual(_ attr1: [NSAttributedString.Key: Any], _ attr2: [NSAttributedString.Key: Any]) -> Bool {
        // Simple comparison of key font and formatting attributes
        let font1 = attr1[.font] as? UIFont
        let font2 = attr2[.font] as? UIFont
        
        if font1?.fontName != font2?.fontName || font1?.pointSize != font2?.pointSize {
            return false
        }
        
        let underline1 = (attr1[.underlineStyle] as? Int) ?? 0
        let underline2 = (attr2[.underlineStyle] as? Int) ?? 0
        
        if underline1 != underline2 {
            return false
        }
        
        return true
    }
}
