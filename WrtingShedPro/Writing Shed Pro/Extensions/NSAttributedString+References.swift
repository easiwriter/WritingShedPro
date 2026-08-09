//
//  NSAttributedString+References.swift
//  Writing Shed Pro
//
//  Feature 029: Back Matter Reference System
//  Created by GitHub Copilot on 15/01/2026.
//
//  Extensions for storing and managing reference markers in NSAttributedString
//

import Foundation
import UIKit

// MARK: - Custom Attribute Keys

extension NSAttributedString.Key {
    /// The type of reference (note, endnote, reference, glossary, index, figure, table)
    static let referenceType = NSAttributedString.Key("com.writingshed.referenceType")
    
    /// The UUID of the referenced entry (NoteEntry, GlossaryEntry, etc.)
    static let referenceID = NSAttributedString.Key("com.writingshed.referenceID")
    
    /// Whether this is a primary reference (Bool) - displayed bold in index
    static let referencePrimary = NSAttributedString.Key("com.writingshed.referencePrimary")
}

// MARK: - Reference Marker Info

/// Information about a reference marker found in text
struct ReferenceMarkerInfo: Identifiable, Equatable {
    let id: UUID  // Unique ID for this marker instance
    let type: ReferenceType
    let entryID: UUID  // ID of the referenced entry
    let range: NSRange
    let markerText: String
    let isPrimary: Bool  // For index entries: whether this is a primary reference (shown bold)
    
    init(type: ReferenceType, entryID: UUID, range: NSRange, markerText: String, isPrimary: Bool = false) {
        self.id = UUID()
        self.type = type
        self.entryID = entryID
        self.range = range
        self.markerText = markerText
        self.isPrimary = isPrimary
    }
    
    static func == (lhs: ReferenceMarkerInfo, rhs: ReferenceMarkerInfo) -> Bool {
        lhs.entryID == rhs.entryID && lhs.range.location == rhs.range.location
    }
}

// MARK: - NSAttributedString Reference Extensions

extension NSAttributedString {
    
    /// Find all reference markers in the attributed string
    /// - Returns: Array of reference marker information
    func allReferences() -> [ReferenceMarkerInfo] {
        var markers: [ReferenceMarkerInfo] = []
        let fullRange = NSRange(location: 0, length: length)
        
        enumerateAttributes(in: fullRange, options: []) { attributes, range, _ in
            if let typeString = attributes[.referenceType] as? String,
               let type = ReferenceType(rawValue: typeString),
               let idString = attributes[.referenceID] as? String,
               let entryID = UUID(uuidString: idString) {
                let markerText = (string as NSString).substring(with: range)
                let isPrimary = attributes[.referencePrimary] as? Bool ?? false
                markers.append(ReferenceMarkerInfo(
                    type: type,
                    entryID: entryID,
                    range: range,
                    markerText: markerText,
                    isPrimary: isPrimary
                ))
            }
        }
        
        return markers.sorted { $0.range.location < $1.range.location }
    }
    
    /// Find references within a specific range
    /// - Parameter range: The range to search within
    /// - Returns: Array of reference marker information
    func references(in range: NSRange) -> [ReferenceMarkerInfo] {
        // Clamp range to valid bounds
        let validRange = NSIntersectionRange(range, NSRange(location: 0, length: length))
        guard validRange.length > 0 else { return [] }

        return allReferences().filter { NSIntersectionRange($0.range, validRange).length > 0 }
    }

    /// Expand a proposed text deletion to include every complete inline reference
    /// marker it intersects.
    func deletionRangeIncludingReferences(_ range: NSRange) -> NSRange {
        let validRange = NSIntersectionRange(range, NSRange(location: 0, length: length))
        guard validRange.length > 0 else { return validRange }

        return references(in: validRange).reduce(validRange) { expandedRange, marker in
            NSUnionRange(expandedRange, marker.range)
        }
    }
    
    /// Find all references of a specific type
    /// - Parameter type: The reference type to find
    /// - Returns: Array of reference marker information
    func references(ofType type: ReferenceType) -> [ReferenceMarkerInfo] {
        allReferences().filter { $0.type == type }
    }
    
    /// Find all references to a specific entry
    /// - Parameter entryID: The UUID of the entry
    /// - Returns: Array of reference marker information
    func references(toEntry entryID: UUID) -> [ReferenceMarkerInfo] {
        allReferences().filter { $0.entryID == entryID }
    }
    
    /// Check if a reference exists at a specific location
    /// - Parameter location: Character index to check
    /// - Returns: Reference info if found, nil otherwise
    func reference(at location: Int) -> ReferenceMarkerInfo? {
        guard location >= 0 && location < length else { return nil }
        
        var result: ReferenceMarkerInfo?
        let checkRange = NSRange(location: location, length: 1)
        
        enumerateAttributes(in: checkRange, options: []) { attributes, range, stop in
            if let typeString = attributes[.referenceType] as? String,
               let type = ReferenceType(rawValue: typeString),
               let idString = attributes[.referenceID] as? String,
               let entryID = UUID(uuidString: idString) {
                
                // Find the full range of this reference
                var fullRange = range
                
                // Expand backwards to find the start
                var startLocation = location
                while startLocation > 0 {
                    let prevLocation = startLocation - 1
                    let prevRange = NSRange(location: prevLocation, length: 1)
                    var hasRef = false
                    enumerateAttributes(in: prevRange, options: []) { prevAttrs, _, _ in
                        if prevAttrs[.referenceType] as? String == typeString,
                           prevAttrs[.referenceID] as? String == idString {
                            hasRef = true
                        }
                    }
                    if hasRef {
                        startLocation = prevLocation
                    } else {
                        break
                    }
                }
                
                // Expand forwards to find the end
                var endLocation = location + 1
                while endLocation < length {
                    let nextRange = NSRange(location: endLocation, length: 1)
                    var hasRef = false
                    enumerateAttributes(in: nextRange, options: []) { nextAttrs, _, _ in
                        if nextAttrs[.referenceType] as? String == typeString,
                           nextAttrs[.referenceID] as? String == idString {
                            hasRef = true
                        }
                    }
                    if hasRef {
                        endLocation += 1
                    } else {
                        break
                    }
                }
                
                fullRange = NSRange(location: startLocation, length: endLocation - startLocation)
                let markerText = (string as NSString).substring(with: fullRange)
                result = ReferenceMarkerInfo(
                    type: type,
                    entryID: entryID,
                    range: fullRange,
                    markerText: markerText
                )
                stop.pointee = true
            }
        }
        
        return result
    }
    
    /// Get unique entry IDs referenced in this string
    /// - Returns: Set of entry UUIDs
    func referencedEntryIDs() -> Set<UUID> {
        Set(allReferences().map { $0.entryID })
    }
    
    /// Count references by type
    /// - Returns: Dictionary of type to count
    func referenceCountsByType() -> [ReferenceType: Int] {
        var counts: [ReferenceType: Int] = [:]
        for marker in allReferences() {
            counts[marker.type, default: 0] += 1
        }
        return counts
    }
}

// MARK: - NSMutableAttributedString Reference Extensions

extension NSMutableAttributedString {
    
    /// Add a reference marker at the specified range
    /// - Parameters:
    ///   - type: The type of reference
    ///   - entryID: The UUID of the referenced entry
    ///   - range: The range to apply the reference to
    func addReference(type: ReferenceType, entryID: UUID, to range: NSRange) {
        guard range.location >= 0 && NSMaxRange(range) <= length else { return }
        
        addAttribute(.referenceType, value: type.rawValue, range: range)
        addAttribute(.referenceID, value: entryID.uuidString, range: range)
    }
    
    /// Insert a reference marker at the specified location
    /// - Parameters:
    ///   - markerText: The text to display for the marker
    ///   - type: The type of reference
    ///   - entryID: The UUID of the referenced entry
    ///   - location: The position to insert at
    ///   - attributes: Additional attributes for the marker text (font, etc.)
    func insertReference(
        markerText: String,
        type: ReferenceType,
        entryID: UUID,
        at location: Int,
        attributes: [NSAttributedString.Key: Any] = [:]
    ) {
        guard location >= 0 && location <= length else { return }
        
        // Create the marker attributed string
        var markerAttributes = attributes
        markerAttributes[.referenceType] = type.rawValue
        markerAttributes[.referenceID] = entryID.uuidString
        
        // Add styling based on reference type
        switch type {
        case .endnote:
            // Superscript styling for endnotes
            if let font = attributes[.font] as? UIFont {
                let superscriptFont = font.withSize(font.pointSize * 0.75)
                markerAttributes[.font] = superscriptFont
                markerAttributes[.baselineOffset] = font.pointSize * 0.3
            }
        case .glossary:
            // Underline and color for glossary terms
            markerAttributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
            markerAttributes[.foregroundColor] = UIColor.systemBlue
        case .index:
            // Invisible marker - use zero-width space
            break
        default:
            break
        }
        
        let marker = NSAttributedString(string: markerText, attributes: markerAttributes)
        insert(marker, at: location)
    }
    
    /// Remove a reference at the specified range
    /// - Parameter range: The range of the reference to remove
    /// - Note: This removes only the reference attributes, not the text
    func removeReference(at range: NSRange) {
        guard range.location >= 0 && NSMaxRange(range) <= length else { return }
        
        removeAttribute(.referenceType, range: range)
        removeAttribute(.referenceID, range: range)
    }
    
    /// Remove all references to a specific entry
    /// - Parameter entryID: The UUID of the entry
    /// - Parameter deleteText: If true, also delete the marker text
    func removeAllReferences(toEntry entryID: UUID, deleteText: Bool = false) {
        let refs = references(toEntry: entryID).sorted { $0.range.location > $1.range.location }
        
        for ref in refs {
            if deleteText {
                deleteCharacters(in: ref.range)
            } else {
                removeReference(at: ref.range)
            }
        }
    }
    
    /// Update marker text for a reference entry
    /// - Parameters:
    ///   - entryID: The UUID of the entry
    ///   - newText: The new marker text
    func updateReferenceMarkerText(forEntry entryID: UUID, newText: String) {
        let refs = references(toEntry: entryID).sorted { $0.range.location > $1.range.location }
        
        for ref in refs {
            // Preserve attributes
            var attributes: [NSAttributedString.Key: Any] = [:]
            if ref.range.length > 0 {
                attributes = self.attributes(at: ref.range.location, effectiveRange: nil)
            }
            
            // Replace the text
            replaceCharacters(in: ref.range, with: NSAttributedString(string: newText, attributes: attributes))
        }
    }
    
    /// Convert all reference markers to plain text format
    /// - Parameter resolver: Closure that provides the plain text for each reference
    func convertReferencesToPlainText(
        resolver: (_ type: ReferenceType, _ entryID: UUID, _ markerText: String) -> String
    ) {
        let refs = allReferences().sorted { $0.range.location > $1.range.location }
        
        for ref in refs {
            let plainText = resolver(ref.type, ref.entryID, ref.markerText)
            
            // Get existing attributes (except reference attributes)
            var attributes: [NSAttributedString.Key: Any] = [:]
            if ref.range.length > 0 {
                attributes = self.attributes(at: ref.range.location, effectiveRange: nil)
                attributes.removeValue(forKey: .referenceType)
                attributes.removeValue(forKey: .referenceID)
            }
            
            // Replace with plain text
            replaceCharacters(in: ref.range, with: NSAttributedString(string: plainText, attributes: attributes))
        }
    }
}

// MARK: - Reference Styling

extension NSMutableAttributedString {
    
    /// Apply standard styling for a reference type
    /// - Parameters:
    ///   - type: The reference type
    ///   - range: The range to style
    func applyReferenceStyle(type: ReferenceType, to range: NSRange) {
        guard range.location >= 0 && NSMaxRange(range) <= length else { return }
        
        switch type {
        case .endnote:
            // Superscript blue text
            addAttribute(.foregroundColor, value: UIColor.systemBlue, range: range)
            if let currentFont = attribute(.font, at: range.location, effectiveRange: nil) as? UIFont {
                let smallerFont = currentFont.withSize(currentFont.pointSize * 0.75)
                addAttribute(.font, value: smallerFont, range: range)
                addAttribute(.baselineOffset, value: currentFont.pointSize * 0.35, range: range)
            }
            
        case .note:
            // Blue text
            addAttribute(.foregroundColor, value: UIColor.systemBlue, range: range)
            
        case .reference:
            // Brown/orange text for references
            addAttribute(.foregroundColor, value: UIColor(red: 0.8, green: 0.5, blue: 0.2, alpha: 1.0), range: range)
            
        case .glossary:
            // Underlined, tappable
            addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            addAttribute(.foregroundColor, value: UIColor.systemTeal, range: range)
            
        case .figure, .table:
            // Blue text
            addAttribute(.foregroundColor, value: UIColor.systemBlue, range: range)
            
        case .index:
            // Invisible - could use zero-width or very subtle indicator
            // For now, no visible styling
            break
        }
    }
}
