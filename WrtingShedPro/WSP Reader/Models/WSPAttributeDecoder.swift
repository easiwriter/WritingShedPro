//
//  WSPAttributeDecoder.swift
//  WSP Reader (macOS target)
//
//  Decodes the binary PropertyList format written by Writing Shed Pro's
//  AttributedStringSerializer into a displayable NSAttributedString.
//

import Foundation
#if canImport(UIKit)
import UIKit
typealias WSPFont  = UIFont
typealias WSPColor = UIColor
typealias WSPImage = UIImage
#elseif canImport(AppKit)
import AppKit
typealias WSPFont  = NSFont
typealias WSPColor = NSColor
typealias WSPImage = NSImage
#endif

// MARK: - Property list model (mirrors AttributeValues in the main app)

private struct WSPAttributeValues: Codable {
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
    var textStyle: String?
    var textColorHex: String?
    // Image attachment properties
    var isImageAttachment: Bool?
    var imageData: String?
    var imageScale: CGFloat?
    var isCommentAttachment: Bool?
    var isFootnoteAttachment: Bool?
    var isReferenceAttachment: Bool?
}

// MARK: - Decoder

enum WSPAttributeDecoder {

    /// Try to decode a binary plist produced by AttributedStringSerializer.
    /// Returns nil if the data is not in that format (caller should try RTF next).
    static func decode(_ data: Data, text: String) -> NSAttributedString? {
        guard !data.isEmpty, !text.isEmpty else { return nil }

        let values: [WSPAttributeValues]
        do {
            values = try PropertyListDecoder().decode([WSPAttributeValues].self, from: data)
        } catch {
            return nil  // Not plist format – let caller try RTF
        }

        #if canImport(UIKit)
        let defaultFont = UIFont.preferredFont(forTextStyle: .body)
        #elseif canImport(AppKit)
        let defaultFont = NSFont.preferredFont(forTextStyle: .body)
        #endif

        let result = NSMutableAttributedString(
            string: text,
            attributes: [.font: defaultFont]
        )

        for v in values {
            guard let loc = v.location, let len = v.length, len > 0,
                  loc >= 0, loc + len <= result.length else { continue }

            if v.isImageAttachment == true,
               let imageBase64 = v.imageData,
               let imageBytes = Data(base64Encoded: imageBase64),
               let image = platformImage(from: imageBytes) {
                let range = NSRange(location: loc, length: len)
                let attachment = NSTextAttachment()
                attachment.image = image
                let imageSize = image.size

                let scale = max(0.1, v.imageScale ?? 1.0)
                let maxDisplayWidth: CGFloat = 520
                let targetWidth = min(maxDisplayWidth * scale, imageSize.width)
                let aspectRatio = imageSize.height / max(imageSize.width, 1)
                attachment.bounds = CGRect(x: 0, y: 0, width: targetWidth, height: targetWidth * aspectRatio)

                result.addAttribute(.attachment, value: attachment, range: range)
                continue
            }

            // Skip non-image attachment placeholders
            if v.isCommentAttachment == true ||
               v.isFootnoteAttachment == true || v.isReferenceAttachment == true {
                continue
            }

            let range = NSRange(location: loc, length: len)
            var attrs: [NSAttributedString.Key: Any] = [:]

            // Font
            if let fontName = v.fontName, let fontSize = v.fontSize {
                let bold   = isBold(v)
                let italic = v.italic ?? false
                attrs[.font] = resolveFont(name: fontName, size: fontSize, bold: bold, italic: italic, textStyle: v.textStyle)
            }

            // Color
            if let hex = v.textColorHex, let color = color(fromHex: hex) {
                attrs[.foregroundColor] = color
            }

            // Underline / strikethrough
            if let u = v.underline { attrs[.underlineStyle] = Int(u) }
            if let s = v.strikethrough { attrs[.strikethroughStyle] = Int(s) }

            // Paragraph style
            let para = NSMutableParagraphStyle()
            if let al = v.textAlignment, let alignment = nsTextAlignment(from: al) {
                para.alignment = alignment
            }
            if let lh = v.lineHeightMultiple, lh > 0 { para.lineHeightMultiple = lh }
            if let ls = v.lineSpacing,        ls > 0 { para.lineSpacing = ls }
            if let sb = v.spaceBefore,        sb > 0 { para.paragraphSpacingBefore = sb }
            if let sa = v.spaceAfter,         sa > 0 { para.paragraphSpacing = sa }
            if let fi = v.firstLineIndent               { para.firstLineHeadIndent = fi }
            if let hi = v.headIndent                    { para.headIndent = hi }
            if let ti = v.tailIndent                    { para.tailIndent = ti }
            if let max = v.maxLineHeight, max > 0       { para.maximumLineHeight = max }
            if let min = v.minLineHeight, min > 0       { para.minimumLineHeight = min }
            attrs[.paragraphStyle] = para

            result.addAttributes(attrs, range: range)
        }
        return result
    }

    // MARK: - Helpers

    private static func isBold(_ v: WSPAttributeValues) -> Bool {
        if v.bold == true { return true }
        let headings: Set<String> = [
            "UICTFontTextStyleTitle0", "UICTFontTextStyleTitle1",
            "UICTFontTextStyleTitle2", "UICTFontTextStyleTitle3",
            "UICTFontTextStyleHeadline"
        ]
        if let ts = v.textStyle, headings.contains(ts) { return true }
        return false
    }

    private static func resolveFont(name: String, size: CGFloat, bold: Bool, italic: Bool, textStyle: String?) -> WSPFont {
#if canImport(UIKit)
        if let ts = textStyle, ts.hasPrefix("UICTFontTextStyle") {
            let style = UIFont.TextStyle(rawValue: ts)
            let base  = UIFont.preferredFont(forTextStyle: style)
            if bold || italic {
                var traits: UIFontDescriptor.SymbolicTraits = []
                if bold   { traits.insert(.traitBold) }
                if italic { traits.insert(.traitItalic) }
                if let desc = base.fontDescriptor.withSymbolicTraits(traits) {
                    return UIFont(descriptor: desc, size: base.pointSize)
                }
            }
            return base
        }
        if name.hasPrefix(".") || name.contains("SFUI") || name.contains("AppleSystemUI") {
            if bold && italic {
                let desc = UIFont.systemFont(ofSize: size).fontDescriptor
                if let d = desc.withSymbolicTraits([.traitBold, .traitItalic]) {
                    return UIFont(descriptor: d, size: size)
                }
            }
            if bold   { return UIFont.boldSystemFont(ofSize: size) }
            if italic { return UIFont.italicSystemFont(ofSize: size) }
            return UIFont.systemFont(ofSize: size)
        }
        if let font = UIFont(name: name, size: size) { return font }
        return UIFont.systemFont(ofSize: size)
#elseif canImport(AppKit)
        if bold && italic {
            return NSFontManager.shared.font(withFamily: NSFont.systemFont(ofSize: size).familyName ?? "",
                traits: [.boldFontMask, .italicFontMask], weight: 0, size: size) ?? NSFont.systemFont(ofSize: size)
        }
        if bold { return NSFont.boldSystemFont(ofSize: size) }
        if let font = NSFont(name: name, size: size) { return font }
        return NSFont.systemFont(ofSize: size)
#endif
    }

    private static func color(fromHex hex: String) -> WSPColor? {
        var s = hex.trimmingCharacters(in: .alphanumerics.inverted)
        if s.count == 6 { s = "FF" + s }
        guard s.count == 8 else { return nil }
        var value: UInt64 = 0
        guard Scanner(string: s).scanHexInt64(&value) else { return nil }
        let a = CGFloat((value >> 24) & 0xFF) / 255
        let r = CGFloat((value >> 16) & 0xFF) / 255
        let g = CGFloat((value >>  8) & 0xFF) / 255
        let b = CGFloat( value        & 0xFF) / 255
#if canImport(UIKit)
        return UIColor(red: r, green: g, blue: b, alpha: a)
#elseif canImport(AppKit)
        return NSColor(red: r, green: g, blue: b, alpha: a)
#endif
    }

            private static func platformImage(from data: Data) -> WSPImage? {
    #if canImport(UIKit)
        return UIImage(data: data)
    #elseif canImport(AppKit)
        return NSImage(data: data)
    #endif
        }

    private static func nsTextAlignment(from raw: Int) -> NSTextAlignment? {
        switch raw {
        case 0: return .left
        case 1: return .right
        case 2: return .center
        case 3: return .justified
        case 4: return .natural
        default: return nil
        }
    }
}
