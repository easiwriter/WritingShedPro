//
//  StyleSheetService.swift
//  Writing Shed Pro
//
//  Service for managing stylesheets and initializing default styles
//

import Foundation
import SwiftData
import UIKit

struct StyleSheetService {
    
    // MARK: - Default StyleSheet Creation
    
    /// Create the default system stylesheet with all UIFont.TextStyle equivalents
    static func createDefaultStyleSheet() -> StyleSheet {
        let sheet = StyleSheet(name: "Default", isSystemStyleSheet: true)
        
        // System text styles based on UIFont.TextStyle
        let systemStyles: [(UIFont.TextStyle, String, StyleCategory, Int, CGFloat?)] = [
            (.largeTitle, "Large Title", .heading, 0, nil),
            (.title1, "Title 1", .heading, 1, nil),
            (.title2, "Title 2", .heading, 2, nil),
            (.title3, "Title 3", .heading, 3, nil),
            (.headline, "Headline", .heading, 4, nil),
            (.body, "Body", .text, 5, nil),
            (.callout, "Body 1", .text, 6, 16),  // Renamed to Body 1, set to 16pt
            (.subheadline, "Body 2", .text, 7, 14),  // Renamed to Body 2, set to 14pt
            (.footnote, "Footnote", .footnote, 8, nil),  // Keep for pagination but hidden from picker
            (.caption1, "Caption 1", .text, 9, nil),
            (.caption2, "Caption 2", .text, 10, nil)
        ]
        
        var styles: [TextStyleModel] = []
        
        for (textStyle, displayName, category, order, customFontSize) in systemStyles {
            let font = UIFont.preferredFont(forTextStyle: textStyle)
            
            // Set bold/italic explicitly based on style type
            // Headline should be bold, everything else plain
            let isBold = (textStyle == .headline)
            let isItalic = false
            
            // Use custom font size if provided, otherwise use system default
            // Platform scaling (Mac Catalyst) now applied at render time in generateFont()
            let fontSize = customFontSize ?? font.pointSize
            
            // Footnote styles always have numbering with decimal format and plain adornment
            let numberFormat: NumberFormat = (category == .footnote) ? .decimal : .none
            let numberAdornment: NumberingAdornment = (category == .footnote) ? .plain : .period
            
            let style = TextStyleModel(
                name: textStyle.rawValue,
                displayName: displayName,
                displayOrder: order,
                fontSize: fontSize,
                isBold: isBold,
                isItalic: isItalic,
                alignment: .left,  // Explicitly set left alignment for system styles
                numberFormat: numberFormat,
                styleCategory: category,
                isSystemStyle: true
            )
            
            // Set adornment after initialization
            style.numberAdornment = numberAdornment
            
            styles.append(style)
        }
        
        // Add specialized list styles
        let listStyles: [(String, String, NumberFormat, Int)] = [
            ("list-numbered", "Numbered List", .decimal, 11),
            ("list-bullet", "Bullet List", .bulletSymbols, 12)
        ]
        
        for (name, displayName, numberFormat, order) in listStyles {
            let style = TextStyleModel(
                name: name,
                displayName: displayName,
                displayOrder: order,
                fontSize: 17,  // Platform scaling now applied at render time in generateFont()
                alignment: .left,  // Explicitly set left alignment for list styles
                numberFormat: numberFormat,
                styleCategory: .list,
                isSystemStyle: false
            )
            styles.append(style)
        }
        
        sheet.textStyles = styles
        
        // Set relationships for text styles
        for style in styles {
            style.styleSheet = sheet
        }
        
        // Add default image style
        let defaultImageStyle = ImageStyle.createDefault()
        defaultImageStyle.styleSheet = sheet
        sheet.imageStyles = [defaultImageStyle]
        
        return sheet
    }
    
    // MARK: - Style Category Migration
    
    /// Fix categories for existing system styles that were created before categories were properly set
    static func fixStyleCategories(in stylesheet: StyleSheet, context: ModelContext) {
        guard let styles = stylesheet.textStyles else {
            #if DEBUG
            print("⚠️ No styles found in stylesheet")
            #endif
            return
        }
        
        #if DEBUG
        print("🔧 Checking \(styles.count) styles for category fixes...")
        #endif
        
        // Map of style names to their correct categories
        let categoryMap: [String: StyleCategory] = [
            "UICTFontTextStyleTitle0": .heading,        // Large Title
            "UICTFontTextStyleTitle1": .heading,        // Title 1
            "UICTFontTextStyleTitle2": .heading,        // Title 2
            "UICTFontTextStyleTitle3": .heading,        // Title 3
            "UICTFontTextStyleHeadline": .heading,      // Headline
            "UICTFontTextStyleBody": .text,             // Body
            "UICTFontTextStyleCallout": .text,          // Body 1
            "UICTFontTextStyleSubheadline": .text,      // Body 2
            "UICTFontTextStyleFootnote": .footnote,     // Footnote
            "UICTFontTextStyleCaption1": .text,         // Caption 1
            "UICTFontTextStyleCaption2": .text,         // Caption 2
            "list-numbered": .list,                      // Numbered List
            "list-bullet": .list                         // Bullet List
        ]
        
        // Obsolete styles to remove
        let obsoleteStyleNames = ["list-lowercase-letter", "list-uppercase-letter"]
        
        var fixedCount = 0
        var deletedCount = 0
        
        for style in styles {
            // Check if this is an obsolete style that should be deleted
            if obsoleteStyleNames.contains(style.name) {
                #if DEBUG
                print("🗑️ Removing obsolete style: \(style.displayName)")
                #endif
                context.delete(style)
                deletedCount += 1
                continue
            }
            
            // Fix category if needed
            if let correctCategory = categoryMap[style.name] {
                if style.styleCategory != correctCategory {
                    #if DEBUG
                    print("📝 Fixing category for \(style.displayName): \(style.styleCategory.rawValue) -> \(correctCategory.rawValue)")
                    #endif
                    style.styleCategory = correctCategory
                    fixedCount += 1
                    
                    // Also fix numbering for footnotes
                    if correctCategory == .footnote {
                        style.numberFormat = .decimal
                        style.numberAdornment = .plain
                        #if DEBUG
                        print("   Also set footnote numbering to decimal/plain")
                        #endif
                    }
                }
            }
        }
        
        if fixedCount > 0 || deletedCount > 0 {
            #if DEBUG
            print("✅ Fixed \(fixedCount) style categories, deleted \(deletedCount) obsolete styles - saving...")
            #endif
            do {
                try context.save()
                #if DEBUG
                print("✅ Changes saved successfully")
                #endif
            } catch {
                #if DEBUG
                print("❌ Error saving changes: \(error)")
                #endif
            }
        } else {
            #if DEBUG
            print("✅ All style categories are correct, no obsolete styles found")
            #endif
        }
    }
    
    // MARK: - StyleSheet Initialization
    
    /// Initialize stylesheets in the model context if none exist
    static func initializeStyleSheetsIfNeeded(context: ModelContext) {
        #if DEBUG
        print("🔧 initializeStyleSheetsIfNeeded called")
        #endif
        
        // Check if we already have a system stylesheet
        let systemDescriptor = FetchDescriptor<StyleSheet>(
            predicate: #Predicate { $0.isSystemStyleSheet == true }
        )
        let existingSystemSheets = (try? context.fetch(systemDescriptor)) ?? []
        
        #if DEBUG
        print("🔧 Found \(existingSystemSheets.count) system stylesheets")
        #endif
        
        // Fix categories in existing stylesheets
        for sheet in existingSystemSheets {
            fixStyleCategories(in: sheet, context: context)
        }
        
        // Remove duplicates if they exist
        if existingSystemSheets.count > 1 {
            #if DEBUG
            print("⚠️ Found \(existingSystemSheets.count) system stylesheets - removing duplicates")
            #endif
            // Keep the first one, delete the rest
            for i in 1..<existingSystemSheets.count {
                context.delete(existingSystemSheets[i])
            }
            try? context.save()
        }
        
        // If we have an existing system stylesheet, check if it has image styles
        if let existingSheet = existingSystemSheets.first {
            #if DEBUG
            print("📐 System stylesheet already exists")
            #endif
            
            // Check if it has image styles
            if existingSheet.imageStyles?.isEmpty ?? true {
                #if DEBUG
                print("📐 Adding default image style to existing stylesheet...")
                #endif
                
                let defaultImageStyle = ImageStyle.createDefault()
                defaultImageStyle.styleSheet = existingSheet
                context.insert(defaultImageStyle)
                
                if existingSheet.imageStyles == nil {
                    existingSheet.imageStyles = [defaultImageStyle]
                } else {
                    existingSheet.imageStyles?.append(defaultImageStyle)
                }
                
                do {
                    try context.save()
                    #if DEBUG
                    print("✅ Added default image style to existing stylesheet")
                    #endif
                } catch {
                    #if DEBUG
                    print("❌ Error saving image style: \(error)")
                    #endif
                }
            } else {
                #if DEBUG
                print("📐 System stylesheet already has \(existingSheet.imageStyles?.count ?? 0) image styles")
                #endif
            }
            return
        }
        
        #if DEBUG
        print("📐 Creating default stylesheet...")
        #endif
        
        // Create default stylesheet
        let defaultSheet = createDefaultStyleSheet()
        context.insert(defaultSheet)
        
        // Insert all text styles into context
        if let textStyles = defaultSheet.textStyles {
            for style in textStyles {
                context.insert(style)
            }
        }
        
        // Insert all image styles into context
        if let imageStyles = defaultSheet.imageStyles {
            for style in imageStyles {
                context.insert(style)
            }
        }
        
        // Save context
        do {
            try context.save()
            #if DEBUG
            print("📐 Default stylesheet created successfully with \(defaultSheet.textStyles?.count ?? 0) text styles and \(defaultSheet.imageStyles?.count ?? 0) image styles")
            #endif
        } catch {
            #if DEBUG
            print("❌ Error saving default stylesheet: \(error)")
            #endif
        }
    }
    
    // MARK: - StyleSheet Lookup
    
    /// Get the default stylesheet
    static func getDefaultStyleSheet(context: ModelContext) -> StyleSheet? {
        let descriptor = FetchDescriptor<StyleSheet>(
            predicate: #Predicate { $0.isSystemStyleSheet == true }
        )
        return try? context.fetch(descriptor).first
    }
    
    /// Get or create a stylesheet for a project
    /// If project has no stylesheet, assign the default one
    static func getStyleSheet(for project: Project, context: ModelContext) -> StyleSheet? {
        // Return project's stylesheet if it has one
        if let sheet = project.styleSheet {
            return sheet
        }
        
        // Otherwise get default
        guard let defaultSheet = getDefaultStyleSheet(context: context) else {
            return nil
        }
        
        // Assign default to project
        project.styleSheet = defaultSheet
        try? context.save()
        
        return defaultSheet
    }
    
    // MARK: - Style Lookup
    
    /// Resolve a text style by name from a project's stylesheet
    /// Falls back to default stylesheet if not found
    static func resolveStyle(
        named name: String,
        for project: Project,
        context: ModelContext
    ) -> TextStyleModel? {
        // 1. Look in project's stylesheet
        if let projectSheet = project.styleSheet,
           let style = projectSheet.style(named: name) {
            return style
        }
        
        // 2. Fall back to default stylesheet
        if let defaultSheet = getDefaultStyleSheet(context: context),
           let style = defaultSheet.style(named: name) {
            return style
        }
        
        // 3. Fall back to body style
        if let defaultSheet = getDefaultStyleSheet(context: context),
           let bodyStyle = defaultSheet.style(named: UIFont.TextStyle.body.rawValue) {
            return bodyStyle
        }
        
        return nil
    }
    
    /// Resolve a text style by UIFont.TextStyle
    static func resolveStyle(
        _ textStyle: UIFont.TextStyle,
        for project: Project,
        context: ModelContext
    ) -> TextStyleModel? {
        return resolveStyle(named: textStyle.rawValue, for: project, context: context)
    }
    
    // MARK: - Style Usage Detection
    
    /// Check if a text style is used in any file within the project
    /// Returns a list of file names that use this style
    static func findStyleUsage(
        style: TextStyleModel,
        in project: Project
    ) -> [String] {
        #if DEBUG
        print("🔍 findStyleUsage: Looking for style '\(style.name)' in project '\(project.name ?? "Untitled")'")
        #endif
        
        var filesUsingStyle: [String] = []
        let styleName = style.name
        
        // Get all folders in the project
        guard let folders = project.folders else {
            #if DEBUG
            print("⚠️ findStyleUsage: No folders in project")
            #endif
            return []
        }
        
        #if DEBUG
        print("📁 findStyleUsage: Found \(folders.count) root folder(s)")
        #endif
        
        // Recursively check all files
        func checkFolder(_ folder: Folder) {
            #if DEBUG
            print("📂 Checking folder: \(folder.name ?? "Untitled")")
            #endif
            
            // Check text files in this folder
            if let textFiles = folder.textFiles {
                #if DEBUG
                print("   \(textFiles.count) file(s) in folder")
                #endif
                for textFile in textFiles {
                    if fileUsesStyle(textFile, styleName: styleName) {
                        filesUsingStyle.append(textFile.name)
                    }
                }
            }
            
            // Check subfolders
            if let subfolders = folder.folders {
                for subfolder in subfolders {
                    checkFolder(subfolder)
                }
            }
        }
        
        // Check each root folder
        for folder in folders {
            checkFolder(folder)
        }
        
        #if DEBUG
        print("✅ findStyleUsage: Found \(filesUsingStyle.count) file(s) using style '\(styleName)'")
        if !filesUsingStyle.isEmpty {
            #if DEBUG
            print("   Files: \(filesUsingStyle.joined(separator: ", "))")
            #endif
        }
        #endif
        
        return filesUsingStyle
    }
    
    /// Check if a text file uses a specific style
    private static func fileUsesStyle(_ file: TextFile, styleName: String) -> Bool {
        // Check current version
        guard let currentVersion = file.currentVersion,
              let attributedString = currentVersion.attributedContent else {
            #if DEBUG
            print("⚠️ fileUsesStyle: No current version or attributed content for file: \(file.name)")
            #endif
            return false
        }
        
        #if DEBUG
        print("🔍 fileUsesStyle: Checking file '\(file.name)' for style '\(styleName)'")
        #if DEBUG
        print("   Content length: \(attributedString.length)")
        #endif
        #endif
        
        // Search for the style attribute in the string
        var foundStyle = false
        let fullRange = NSRange(location: 0, length: attributedString.length)
        
        attributedString.enumerateAttribute(
            NSAttributedString.Key.textStyle,
            in: fullRange,
            options: []
        ) { value, range, stop in
            #if DEBUG
            if let styleValue = value as? String {
                #if DEBUG
                print("   Found style '\(styleValue)' at range \(range)")
                #endif
                if styleValue == styleName {
                    #if DEBUG
                    print("   ✅ MATCH!")
                    #endif
                }
            } else if value != nil {
                #if DEBUG
                print("   Found non-string style value: \(String(describing: value))")
                #endif
            }
            #endif
            
            if let styleValue = value as? String,
               styleValue == styleName {
                foundStyle = true
                stop.pointee = true
            }
        }
        
        #if DEBUG
        print("   Result: \(foundStyle ? "FOUND" : "NOT FOUND")")
        #endif
        
        return foundStyle
    }
    
    /// Check if a style can be safely deleted
    /// Returns nil if safe, or an error message if not
    static func canDeleteStyle(
        _ style: TextStyleModel,
        from project: Project
    ) -> (canDelete: Bool, message: String?) {
        // System styles cannot be deleted
        if style.isSystemStyle {
            return (false, "System styles cannot be deleted.")
        }
        
        // Check if style is in use
        let filesUsing = findStyleUsage(style: style, in: project)
        
        if filesUsing.isEmpty {
            return (true, nil)
        } else {
            let fileList = filesUsing.prefix(5).joined(separator: ", ")
            let moreCount = filesUsing.count - 5
            let message = "This style is used in \(filesUsing.count) file(s): \(fileList)\(moreCount > 0 ? ", and \(moreCount) more" : "")"
            return (false, message)
        }
    }
    
    /// Delete a style and optionally replace it with another style in all files
    /// If the style is in use and no replacement is provided, this will throw an error
    static func deleteStyle(
        _ style: TextStyleModel,
        replacementStyle: TextStyleModel?,
        from project: Project,
        context: ModelContext
    ) throws {
        // Don't allow deleting system styles
        guard !style.isSystemStyle else {
            throw NSError(domain: "StyleSheetService", code: 1, 
                         userInfo: [NSLocalizedDescriptionKey: "Cannot delete system styles"])
        }
        
        // Check if style is in use
        let filesUsing = findStyleUsage(style: style, in: project)
        
        // If style is in use, replacement is required
        if !filesUsing.isEmpty && replacementStyle == nil {
            throw NSError(domain: "StyleSheetService", code: 2,
                         userInfo: [NSLocalizedDescriptionKey: "Cannot delete style that is in use without providing a replacement"])
        }
        
        // If replacement style is provided, update all files
        if let replacement = replacementStyle {
            replaceStyleInProject(
                oldStyleName: style.name,
                newStyleName: replacement.name,
                in: project,
                context: context
            )
        }
        
        // Remove from stylesheet
        if let stylesheet = style.styleSheet {
            stylesheet.textStyles?.removeAll { $0.id == style.id }
        }
        
        // Delete the style
        context.delete(style)
        try context.save()
    }
    
    /// Replace all occurrences of one style with another in the project
    private static func replaceStyleInProject(
        oldStyleName: String,
        newStyleName: String,
        in project: Project,
        context: ModelContext
    ) {
        guard let folders = project.folders else { return }
        
        func processFolder(_ folder: Folder) {
            // Process text files
            if let textFiles = folder.textFiles {
                for textFile in textFiles {
                    replaceStyleInFile(textFile, oldStyleName: oldStyleName, newStyleName: newStyleName, context: context)
                }
            }
            
            // Process subfolders
            if let subfolders = folder.folders {
                for subfolder in subfolders {
                    processFolder(subfolder)
                }
            }
        }
        
        for folder in folders {
            processFolder(folder)
        }
    }
    
    /// Replace a style in a single file
    /// This both updates the .textStyle attribute AND applies the new style's formatting
    private static func replaceStyleInFile(
        _ file: TextFile,
        oldStyleName: String,
        newStyleName: String,
        context: ModelContext
    ) {
        guard let currentVersion = file.currentVersion,
              let attributedString = currentVersion.attributedContent,
              let project = file.project,
              let newStyle = resolveStyle(named: newStyleName, for: project, context: context) else {
            return
        }
        
        // Use the Version model's attributedContent getter to properly deserialize
        let mutableString = NSMutableAttributedString(attributedString: attributedString)
        let fullRange = NSRange(location: 0, length: mutableString.length)
        
        // Get the new style's attributes once (for efficiency)
        let newStyleAttributes = newStyle.generateAttributes()
        guard let newFont = newStyleAttributes[NSAttributedString.Key.font] as? UIFont else {
            return
        }
        
        // Replace all occurrences of the old style with the new style
        // AND apply the new style's formatting
        mutableString.enumerateAttribute(
            NSAttributedString.Key.textStyle,
            in: fullRange,
            options: []
        ) { value, range, _ in
            if let styleValue = value as? String,
               styleValue == oldStyleName {
                
                // Update the style name
                mutableString.addAttribute(NSAttributedString.Key.textStyle, value: newStyleName, range: range)
                
                // Apply the new style's formatting attributes
                // Preserve character-level traits (bold, italic) within the paragraph
                mutableString.enumerateAttributes(in: range, options: []) { attributes, subrange, _ in
                    var newAttributes = newStyleAttributes
                    
                    // Preserve existing font traits
                    let existingFont = attributes[.font] as? UIFont ?? newFont
                    let existingTraits = existingFont.fontDescriptor.symbolicTraits
                    
                    if !existingTraits.isEmpty {
                        if let descriptor = newFont.fontDescriptor.withSymbolicTraits(existingTraits) {
                            newAttributes[.font] = UIFont(descriptor: descriptor, size: 0)
                        } else {
                            newAttributes[.font] = newFont
                        }
                    }
                    
                    mutableString.setAttributes(newAttributes, range: subrange)
                }
            }
        }
        
        // Save back using the Version model's setter
        // This will use AttributedStringSerializer.encode to preserve custom attributes
        currentVersion.attributedContent = mutableString
    }
}
