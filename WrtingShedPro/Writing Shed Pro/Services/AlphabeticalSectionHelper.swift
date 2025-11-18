//
//  AlphabeticalSectionHelper.swift
//  Writing Shed Pro
//
//  Created on 2025-11-14.
//  Helper for grouping items alphabetically into collapsible sections
//

import Foundation

/// Helper for organizing items into alphabetical sections
struct AlphabeticalSectionHelper {
    
    /// Represents a section of items grouped by first letter
    struct Section<T>: Identifiable {
        let letter: String
        let items: [T]
        
        var id: String { letter }
        
        var count: Int { items.count }
    }
    
    /// Groups text files by first letter of their name
    /// - Parameter files: Array of TextFile objects
    /// - Returns: Array of sections, each containing files starting with that letter
    static func groupFiles(_ files: [TextFile]) -> [Section<TextFile>] {
        // Group files by first letter
        let grouped = Dictionary(grouping: files) { file -> String in
            let firstChar = file.name.prefix(1).uppercased()
            // Return the letter if it's A-Z, otherwise use "#" for numbers/symbols
            return firstChar.rangeOfCharacter(from: .letters) != nil ? firstChar : "#"
        }
        
        // Create sections and sort
        let sections = grouped.map { letter, files in
            Section(letter: letter, items: files.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending })
        }
        
        // Sort sections: "#" first (if exists), then A-Z
        return sections.sorted { section1, section2 in
            if section1.letter == "#" { return true }
            if section2.letter == "#" { return false }
            return section1.letter < section2.letter
        }
    }
    
    /// Groups generic items by a key extractor function
    /// - Parameters:
    ///   - items: Array of items to group
    ///   - keyExtractor: Function that returns the string to group by (first letter will be used)
    /// - Returns: Array of sections
    static func group<T>(_ items: [T], by keyExtractor: (T) -> String) -> [Section<T>] {
        // Group items by first letter
        let grouped = Dictionary(grouping: items) { item -> String in
            let key = keyExtractor(item)
            let firstChar = key.prefix(1).uppercased()
            return firstChar.rangeOfCharacter(from: .letters) != nil ? firstChar : "#"
        }
        
        // Create sections and sort
        let sections = grouped.map { letter, items in
            Section(letter: letter, items: items.sorted { 
                keyExtractor($0).localizedCaseInsensitiveCompare(keyExtractor($1)) == .orderedAscending 
            })
        }
        
        // Sort sections
        return sections.sorted { section1, section2 in
            if section1.letter == "#" { return true }
            if section2.letter == "#" { return false }
            return section1.letter < section2.letter
        }
    }
}
