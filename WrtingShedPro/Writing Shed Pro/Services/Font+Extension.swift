//
//  Font.swift
//  Write!
//
//  Created by Keith Lander on 28/02/2020.
//  Copyright © 2020 Keith Lander. All rights reserved.
//

import SwiftUI

@Observable class FontArray {
    var fontItems = [FontItem]()
    var fontItem: FontItem?

    func with(first name: String?) -> [FontItem] {
        guard name != nil else {
            return fontItems
        }
        var fonts = fontItems.compactMap { (f) -> FontItem? in
            if f.name == name {
                fontItem = f
                return nil
            } else {
                return f
            }
        }
        fonts.insert(fontItem!, at: 0)
        return Array(fonts)
    }
}

struct FontItem: Identifiable, Equatable {
    var name: String
    var id = UUID()
    var faces = FacesArray()

    init(name: String, faces: FacesArray) {
        self.name = name
        self.faces = faces
    }

    init(item: FontItem) {
        name = item.name
        id = item.id
        faces = item.faces
    }

    static func == (lhs: FontItem, rhs: FontItem) -> Bool {
        lhs.id == rhs.id
    }
}

typealias FacesArray = [FaceItem]

struct FaceItem: Identifiable {
    var name: String
    var id = UUID()
    var font: CTFont
    var fontName: String
}

extension UIFont {
    class func allNames() -> FontArray {
        let theFonts = FontArray()
        UIFont.familyNames.forEach {
            if $0 != "System Font" {
                let fonts = UIFont.fontNames(forFamilyName: $0)
                var fontFaces = FacesArray()
                fonts.forEach {
                    let postScriptName = UIFont.postScriptNameFromFullName($0)
                    let font = CTFontCreateWithName(postScriptName as CFString, 14.0, nil)
                    let faceNameSplit = $0.split(separator: "-")
                    let faceName = faceNameSplit.count == 1 ? "Regular" : faceNameSplit[1]
                    fontFaces.append(FaceItem(name: String(faceName), font: font, fontName: $0))
                }
                theFonts.fontItems.append(FontItem(name: $0, faces: fontFaces))
            }
        }
        theFonts.fontItems = theFonts.fontItems.sorted { $0.name <= $1.name }
        return theFonts
    }

    class func allFaces(for font: String, in fonts: FontArray) -> FacesArray {
        var faces: FacesArray?
        fonts.fontItems.forEach { item in
            if item.name == font {
                faces = item.faces
            }
        }
        guard let theFaces = faces else {
            fatalError("Font faces not found for font: \(font)")
        }
        return theFaces
    }

    class func getTraits(for font: String)->(bold: String, italic: String) {
        var result = (bold:"false", italic:"false")
        let traits = UIFontDescriptor(name: font as String, size: 12.0).symbolicTraits
        result.italic = traits.contains(UIFontDescriptor.SymbolicTraits.traitItalic) ? "true" : "false"
        result.bold = traits.contains(UIFontDescriptor.SymbolicTraits.traitBold) ? "true" : "false"
        return result
    }

    class func postScriptNameFromFullName(_ fullName: String) -> String {
        guard let font = UIFont(name: fullName, size: 1) else {
            let faceNameSplit = fullName.split(separator: "-")
            return String(faceNameSplit[0])
        }
        return CTFontCopyPostScriptName(font) as String
    }

    class func getTypefaceForFontAndTraits(_ name: String, size: CGFloat, bold: Bool, italic: Bool) -> String {
        let fontRef = UIFont.getFontRefForNameAndTraits(name, size: size, bold: bold, italic: italic)
        let fullName = CTFontCopyName(fontRef, kCTFontPostScriptNameKey)! as String
        let faceNameSplit = fullName.split(separator: "-")
        let faceName = faceNameSplit.count == 1 ? "Regular" : faceNameSplit[1]
        return String(faceName)
    }

    class func fontWithNameAndTraits(_ name: String, size: CGFloat, bold: Bool, italic: Bool) -> UIFont {
        let fontRef = UIFont.getFontRefForNameAndTraits(name, size: size, bold: bold, italic: italic)
        let fontNameKey = CTFontCopyName(fontRef, kCTFontPostScriptNameKey)! as String
        return UIFont(name: fontNameKey as String, size: CTFontGetSize(fontRef ))!
    }

    var withSmallCaps: UIFont {
        let upperCaseFeature = [
            UIFontDescriptor.FeatureKey.type: kUpperCaseType,
            UIFontDescriptor.FeatureKey.type: kUpperCaseSmallCapsSelector
        ]
        let lowerCaseFeature = [
            UIFontDescriptor.FeatureKey.type: kLowerCaseType,
            UIFontDescriptor.FeatureKey.type: kLowerCaseSmallCapsSelector
        ]
        let features = [upperCaseFeature, lowerCaseFeature]
        let smallCapsDescriptor = self.fontDescriptor.addingAttributes([UIFontDescriptor.AttributeName.featureSettings: features])
        return UIFont(descriptor: smallCapsDescriptor, size: pointSize)
    }

    class func scaleText(by zoomFactor: CGFloat, in text:inout NSMutableAttributedString) {
        let range = NSRange(location: 0, length: text.string.count)
        text.enumerateAttribute(NSAttributedString.Key.font, in: range, options: NSAttributedString.EnumerationOptions(rawValue: 0)) { (value, range, _) in
            if value != nil {
                let font = value as! UIFont
                let newSize = (zoomFactor * font.pointSize).rounded(.down)
                let newFont = UIFont(name: font.fontName, size: newSize)
                text.removeAttribute(NSAttributedString.Key.font, range: range)
                text.addAttribute(NSAttributedString.Key.font, value: newFont as Any, range: range)
            }
        }
    }

    func scaleFont(by zoomFactor: CGFloat) -> UIFont {
        let newSize = (zoomFactor * self.pointSize).rounded(.down)
        return UIFont(name: self.fontName, size: newSize) ?? self
    }

    class func scaleAttachments(in text: NSMutableAttributedString, width: CGFloat) -> NSAttributedString {
        let range = NSRange(location: 0, length: text.string.count)
        text.enumerateAttribute(NSAttributedString.Key.attachment, in: range, options: NSAttributedString.EnumerationOptions(rawValue: 0)) { (value, range, _) in
            if value != nil {
                let attachment = value as! NSTextAttachment
                var photo = attachment.image
                let scale = photo!.size.width / width * 1.3
                photo = UIImage(cgImage: (photo?.cgImage)!, scale: scale, orientation: .up)
                attachment.image = photo
                text.removeAttribute(NSAttributedString.Key.attachment, range: range)
                text.addAttribute(NSAttributedString.Key.attachment, value: attachment as Any, range: range)
            }
        }
        return text
    }

    /// Returns a bold draft of `self`
    public var bolded: UIFont {
        return fontDescriptor.withSymbolicTraits(.traitBold)
            .map { UIFont(descriptor: $0, size: 0) } ?? self
    }

    /// Returns an italic draft of `self`
    public var italicized: UIFont {
        return fontDescriptor.withSymbolicTraits(.traitItalic)
            .map { UIFont(descriptor: $0, size: 0) } ?? self
    }

    /// Returns a scaled draft of `self`
    func scaled(scaleFactor: CGFloat) -> UIFont {
        let newDescriptor = fontDescriptor.withSize(fontDescriptor.pointSize * scaleFactor)
        return UIFont(descriptor: newDescriptor, size: 0)
    }

    class func getFontRefForNameAndTraits(_ name: String, size: CGFloat, bold: Bool, italic: Bool) -> CTFont {
        let postScriptName = UIFont.postScriptNameFromFullName(name)
        var traits: UInt32 = 0
        var symbolicTraits: CTFontSymbolicTraits
        var newFontRef: CTFont?
        let fontWithoutTrait = CTFontCreateWithName(postScriptName as CFString, size, nil)
        if italic {
            traits |= UInt32(Int(CTFontSymbolicTraits.traitItalic.rawValue))
        }
        if bold {
            traits |= UInt32(Int(CTFontSymbolicTraits.traitBold.rawValue))
        }
        symbolicTraits = CTFontSymbolicTraits(rawValue: traits)
        if traits == 0 {
            newFontRef = CTFontCreateCopyWithAttributes(fontWithoutTrait, 0.0, nil, nil)
        } else {
            newFontRef = CTFontCreateCopyWithSymbolicTraits(fontWithoutTrait, 0.0, nil, symbolicTraits, symbolicTraits)
            if newFontRef == nil {
                newFontRef = CTFontCreateCopyWithAttributes(fontWithoutTrait, 0.0, nil, nil)
            }
        }
        guard let newFont = newFontRef else {
            fatalError("Can't create fontRef for font: \(name)")
        }
        return newFont
    }
}
