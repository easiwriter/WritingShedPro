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
    var imageAlignment: String?
    var imageSpacingAbove: CGFloat?
    var imageSpacingBelow: CGFloat?
    var imageStyleName: String?
    var imageFileID: String?
    var hasCaption: Bool?
    var captionPrefix: String?
    var captionText: String?
    var captionStyle: String?
    var isCommentAttachment: Bool?
    var isFootnoteAttachment: Bool?
    var isReferenceAttachment: Bool?
    var referenceType: String?
    var referenceEntryID: String?
    var referenceDisplayText: String?
    var referenceDisplayNumber: Int?
}

// MARK: - Decoder

enum WSPAttributeDecoder {

    private static let textStyleKey = NSAttributedString.Key("WritingShedPro.TextStyle")

    /// Try to decode a binary plist produced by AttributedStringSerializer.
    /// Returns nil if the data is not in that format (caller should try RTF next).
    static func decode(
        _ data: Data,
        text: String,
        stylesheet: WSPStyleSheetData? = nil,
        startingCaptionNumbers: [String: Int] = [:]
    ) -> NSAttributedString? {
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
        var imageReplacements: [(range: NSRange, content: NSAttributedString)] = []
        var referenceReplacements: [(range: NSRange, displayText: String, attributes: [NSAttributedString.Key: Any])] = []
        var captionCounters = startingCaptionNumbers

        for v in values {
            guard let loc = v.location, let len = v.length, len > 0,
                  loc >= 0, loc + len <= result.length else { continue }

            if v.isReferenceAttachment == true {
                let range = NSRange(location: loc, length: len)
                let displayText = v.referenceDisplayText?.isEmpty == false ? v.referenceDisplayText! : fallbackReferenceDisplayText(v)
                var attrs = result.attributes(at: loc, effectiveRange: nil)
                attrs.removeValue(forKey: .attachment)
                referenceReplacements.append((range, displayText, attrs))
                continue
            }

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

                let paragraphStyle = imageParagraphStyle(for: v)
                let replacement = NSMutableAttributedString(
                    attributedString: NSAttributedString(
                        attachment: attachment,
                        attributes: [.paragraphStyle: paragraphStyle]
                    )
                )
                let captionStyle = v.captionStyle.flatMap { styleName in
                    stylesheet?.textStyles.first(where: { $0.name == styleName })
                }
                let captionMarker: String?
                if let captionStyle, captionStyle.numberFormatRaw != "none" {
                    captionCounters[captionStyle.name, default: 0] += 1
                    captionMarker = numberSymbol(
                        captionStyle.numberFormatRaw,
                        index: captionCounters[captionStyle.name, default: 1] - 1,
                        adornment: captionStyle.numberAdornmentRaw,
                        level: 0
                    )
                } else {
                    captionMarker = nil
                }
                if v.hasCaption == true, let caption = captionText(for: v, marker: captionMarker) {
                    replacement.append(NSAttributedString(
                        string: "\n\(caption)",
                        attributes: captionAttributes(paragraphStyle: paragraphStyle, style: captionStyle)
                    ))
                }
                imageReplacements.append((range, replacement))
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

            if let referenceType = v.referenceType,
               let referenceEntryID = v.referenceEntryID {
                attrs[NSAttributedString.Key("com.writingshed.referenceType")] = referenceType
                attrs[NSAttributedString.Key("com.writingshed.referenceID")] = referenceEntryID
            }

            if let textStyle = v.textStyle {
                attrs[textStyleKey] = textStyle
            }

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

        let replacements = imageReplacements.map { ($0.range, $0.content) } + referenceReplacements.map {
            ($0.range, NSAttributedString(string: $0.displayText, attributes: $0.attributes))
        }
        for replacement in replacements.sorted(by: { $0.0.location > $1.0.location }) {
            result.replaceCharacters(in: replacement.0, with: replacement.1)
        }
        if let stylesheet {
            materializeParagraphNumbers(in: result, stylesheet: stylesheet)
        }
        return result
    }

    static func captionNumberCounts(
        after data: Data,
        stylesheet: WSPStyleSheetData?,
        startingNumbers: [String: Int] = [:]
    ) -> [String: Int] {
        guard let stylesheet,
              let values = try? PropertyListDecoder().decode([WSPAttributeValues].self, from: data) else {
            return startingNumbers
        }

        var counters = startingNumbers
        for values in values where values.isImageAttachment == true && values.hasCaption == true {
            guard let styleName = values.captionStyle,
                  let style = stylesheet.textStyles.first(where: { $0.name == styleName }),
                  style.numberFormatRaw != "none" else {
                continue
            }
            counters[styleName, default: 0] += 1
        }
        return counters
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

    private static func captionText(for values: WSPAttributeValues, marker: String? = nil) -> String? {
        let parts = [values.captionPrefix, marker, values.captionText]
            .compactMap { value -> String? in
                guard let value else { return nil }
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    private static func imageParagraphStyle(for values: WSPAttributeValues) -> NSMutableParagraphStyle {
        let paragraphStyle = NSMutableParagraphStyle()
        switch values.imageAlignment {
        case "center": paragraphStyle.alignment = .center
        case "right": paragraphStyle.alignment = .right
        default: paragraphStyle.alignment = .left
        }
        paragraphStyle.paragraphSpacingBefore = max(0, values.imageSpacingAbove ?? 0)
        paragraphStyle.paragraphSpacing = max(0, values.imageSpacingBelow ?? 0)
        paragraphStyle.lineBreakMode = .byWordWrapping
        return paragraphStyle
    }

    private static func captionAttributes(
        paragraphStyle: NSParagraphStyle,
        style: WSPTextStyleData?
    ) -> [NSAttributedString.Key: Any] {
        var attributes: [NSAttributedString.Key: Any] = [
            .font: WSPFont.systemFont(ofSize: 14),
            .foregroundColor: WSPColor.secondaryLabel,
            .paragraphStyle: paragraphStyle
        ]
        if let style {
            attributes[.font] = resolveFont(
                name: style.fontName ?? style.fontFamily ?? "",
                size: style.fontSize,
                bold: style.isBold,
                italic: style.isItalic,
                textStyle: style.name
            )
            if let hex = style.textColorHex, let color = color(fromHex: hex) {
                attributes[.foregroundColor] = color
            }
            if style.isUnderlined { attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue }
            if style.isStrikethrough { attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue }
        }
        return attributes
    }

    private static func materializeParagraphNumbers(
        in attributedString: NSMutableAttributedString,
        stylesheet: WSPStyleSheetData
    ) {
        let styles = stylesheet.textStyles.reduce(into: [String: WSPTextStyleData]()) { result, style in
            if result[style.name] == nil {
                result[style.name] = style
            }
        }
        let parentStyles = stylesheet.textStyles.reduce(into: [String: String]()) { result, style in
            if let parent = style.parentStyleName, !parent.isEmpty {
                result[style.name] = parent
            }
        }
        var counters: [String: Int] = [:]
        var insertions: [(location: Int, text: NSAttributedString)] = []
        let source = attributedString.string as NSString
        var location = 0

        while location < source.length {
            let paragraphRange = source.paragraphRange(for: NSRange(location: location, length: 0))
            let attributeLocation = min(paragraphRange.location, attributedString.length - 1)
            if let styleName = attributedString.attribute(textStyleKey, at: attributeLocation, effectiveRange: nil) as? String,
               let style = styles[styleName], style.numberFormatRaw != "none" {
                for candidate in counters.keys where isDescendant(candidate, of: styleName, parentStyles: parentStyles) {
                    counters[candidate] = 0
                }
                counters[styleName, default: 0] += 1
                let marker = hierarchicalMarker(
                    for: style,
                    counter: counters[styleName, default: 1],
                    counters: counters,
                    styles: styles,
                    parentStyles: parentStyles
                )
                if !marker.isEmpty {
                    var attributes = attributedString.attributes(at: attributeLocation, effectiveRange: nil)
                    attributes.removeValue(forKey: .attachment)
                    insertions.append((paragraphRange.location, NSAttributedString(string: "\(marker)\t", attributes: attributes)))
                }
            }
            location = max(NSMaxRange(paragraphRange), location + 1)
        }

        for insertion in insertions.reversed() {
            attributedString.insert(insertion.text, at: insertion.location)
        }
    }

    private static func isDescendant(
        _ styleName: String,
        of ancestor: String,
        parentStyles: [String: String]
    ) -> Bool {
        var current = parentStyles[styleName]
        while let name = current {
            if name == ancestor { return true }
            current = parentStyles[name]
        }
        return false
    }

    private static func hierarchicalMarker(
        for style: WSPTextStyleData,
        counter: Int,
        counters: [String: Int],
        styles: [String: WSPTextStyleData],
        parentStyles: [String: String]
    ) -> String {
        if style.styleCategoryRaw == "list" {
            return numberSymbol(style.numberFormatRaw, index: counter - 1, adornment: style.numberAdornmentRaw, level: bulletLevel(style.name))
        }

        var hierarchy: [(style: WSPTextStyleData, number: Int)] = [(style, counter)]
        var current = parentStyles[style.name]
        while let name = current, let parent = styles[name] {
            hierarchy.append((parent, counters[name] ?? 0))
            current = parentStyles[name]
        }
        hierarchy.reverse()

        guard hierarchy.count > 1 else {
            return numberSymbol(style.numberFormatRaw, index: counter - 1, adornment: style.numberAdornmentRaw, level: bulletLevel(style.name))
        }
        let parts = hierarchy.map { entry in
            numberSymbol(entry.style.numberFormatRaw, index: max(entry.number - 1, 0), adornment: "plain", level: bulletLevel(entry.style.name))
        }
        return applyAdornment(style.numberAdornmentRaw, to: parts.joined(separator: "."))
    }

    private static func numberSymbol(_ format: String, index: Int, adornment: String, level: Int) -> String {
        let value: String
        switch format {
        case "decimal": value = "\(index + 1)"
        case "lowercaseRoman": value = romanNumeral(index + 1).lowercased()
        case "uppercaseRoman": value = romanNumeral(index + 1)
        case "lowercaseLetter": value = letter(index).lowercased()
        case "uppercaseLetter": value = letter(index)
        case "footnoteSymbols":
            let symbols = ["*", "†", "‡", "§", "¶"]
            return symbols[index % symbols.count]
        case "bulletSymbols":
            let symbols = ["•", "◦", "▪"]
            return symbols[min(level, symbols.count - 1)]
        default: return ""
        }
        return applyAdornment(adornment, to: value)
    }

    private static func applyAdornment(_ adornment: String, to value: String) -> String {
        switch adornment {
        case "plain": return value
        case "parentheses": return "(\(value))"
        case "rightParen": return "\(value))"
        case "dashBefore": return "-\(value)"
        case "dashAfter": return "\(value)-"
        case "dashBoth": return "-\(value)-"
        default: return "\(value)."
        }
    }

    private static func bulletLevel(_ styleName: String) -> Int {
        if styleName.contains("level-3") { return 2 }
        if styleName.contains("level-2") { return 1 }
        return 0
    }

    private static func romanNumeral(_ number: Int) -> String {
        guard number > 0 else { return "0" }
        let values = [(1000, "M"), (900, "CM"), (500, "D"), (400, "CD"), (100, "C"), (90, "XC"), (50, "L"), (40, "XL"), (10, "X"), (9, "IX"), (5, "V"), (4, "IV"), (1, "I")]
        var remainder = number
        var result = ""
        for (value, symbol) in values {
            while remainder >= value {
                result += symbol
                remainder -= value
            }
        }
        return result
    }

    private static func letter(_ index: Int) -> String {
        var value = index + 1
        var result = ""
        while value > 0 {
            value -= 1
            result = String(UnicodeScalar(65 + value % 26)!) + result
            value /= 26
        }
        return result
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

    private static func fallbackReferenceDisplayText(_ values: WSPAttributeValues) -> String {
        if let number = values.referenceDisplayNumber, number > 0 {
            switch values.referenceType {
            case "figure": return "[Fig \(number)]"
            case "table": return "[Table \(number)]"
            case "note": return "[Note \(number)]"
            default: return "[\(number)]"
            }
        }

        return "[ref]"
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
