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
    
    /// Convert an attributed string to RTF data (images will be omitted)
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
            
            // Check if this is an attachment (image)
            if let attachment = attributes[.attachment] as? ImageAttachment {
                // Images are not supported in RTF export - skip them
                #if DEBUG
                print("📷 RTF: Skipping image at position \(i) (RTF image export not supported)")
                #endif
                #if DEBUG
                print("📷 RTF: attachment.originalFilename = \(attachment.originalFilename ?? "nil")")
                #endif
                #if DEBUG
                print("📷 RTF: attachment.captionText = \(attachment.captionText ?? "nil")")
                #endif
                
                // Close any open formatting before skipping the image
                if currentAttributes != nil {
                    rtf += closeFormatting(currentAttributes!)
                    currentAttributes = nil
                }
                
                // Use original filename if available, otherwise caption, otherwise imageID
                let imageName: String
                if let filename = attachment.originalFilename, !filename.isEmpty {
                    imageName = filename
                    #if DEBUG
                    print("📷 RTF: Using filename: \(imageName)")
                    #endif
                } else if let caption = attachment.captionText, !caption.isEmpty {
                    imageName = caption
                    #if DEBUG
                    print("📷 RTF: Using caption: \(imageName)")
                    #endif
                } else {
                    imageName = "Image-\(attachment.imageID.uuidString.prefix(8))"
                    #if DEBUG
                    print("📷 RTF: Using imageID: \(imageName)")
                    #endif
                }
                
                // Add a placeholder indicator with the image identifier
                rtf += " [Image: \(imageName)] "
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
    
    /*
    /// Generate RTF code for an embedded image
    private static func generateRTFImage(image: UIImage, scale: CGFloat, alignment: ImageAttachment.ImageAlignment) -> String {
        // Downscale large images before encoding
        // RTF readers struggle with large embedded images
        let maxDimension: CGFloat = 800 // Max width or height
        
        var imageToEncode = image
        let size = image.size
        
        if size.width > maxDimension || size.height > maxDimension {
            let scaleFactor = min(maxDimension / size.width, maxDimension / size.height)
            let newSize = CGSize(width: size.width * scaleFactor, height: size.height * scaleFactor)
            
            #if DEBUG
            print("📷 Downscaling image from \(size) to \(newSize) for RTF")
            #endif
            
            UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
            image.draw(in: CGRect(origin: .zero, size: newSize))
            imageToEncode = UIGraphicsGetImageFromCurrentImageContext() ?? image
            UIGraphicsEndImageContext()
        }
        
        // Use PNG for better quality at smaller sizes
        guard let imageData = imageToEncode.pngData() else {
            #if DEBUG
            print("❌ Failed to get PNG data from image")
            #endif
            return ""
        }
        
        #if DEBUG
        print("📷 Creating NSTextAttachment with PNG data (\(imageData.count) bytes)")
        #endif
        
        let attachment = NSTextAttachment()
        
        // Set the image data on the attachment
        attachment.contents = imageData
        
        // Set bounds for the attachment (using original scale parameter)
        let scaledSize = CGSize(width: imageToEncode.size.width * scale, height: imageToEncode.size.height * scale)
        attachment.bounds = CGRect(origin: .zero, size: scaledSize)
        
        // Create attributed string with just this attachment
        let attrString = NSAttributedString(attachment: attachment)
        
        #if DEBUG
        print("📷 Converting attachment to RTF...")
        #endif
        
        // Convert to RTF data using Apple's converter
        guard let rtfData = try? attrString.data(
            from: NSRange(location: 0, length: attrString.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        ), let rtfString = String(data: rtfData, encoding: .utf8) else {
            #if DEBUG
            print("❌ Failed to generate RTF for image")
            #endif
            return ""
        }
        
        #if DEBUG
        print("📷 RTF generated, length: \(rtfString.count) chars")
        #endif
        
        // Extract just the picture part from the RTF (between \pict and the closing brace)
        // Apple's RTF will have: {\pict...data...}
        if let pictStart = rtfString.range(of: "{\\pict"),
           let closingBrace = rtfString.range(of: "}", range: pictStart.upperBound..<rtfString.endIndex) {
            let pictureCode = String(rtfString[pictStart.lowerBound..<closingBrace.upperBound])
            #if DEBUG
            print("📷 Extracted Apple RTF picture code (length: \(pictureCode.count) chars)")
            #endif
            return pictureCode
        }
        
        #if DEBUG
        print("⚠️ Could not extract picture code from Apple RTF")
        #endif
        #if DEBUG
        print("📷 RTF sample: \(rtfString.prefix(500))")
        #endif
        return ""
    }
    */
    
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
