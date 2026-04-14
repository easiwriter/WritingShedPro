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

    static func uniqueStyleSheets(from sheets: [StyleSheet], preferredSheetID: UUID? = nil) -> [StyleSheet] {
        var grouped: [String: [StyleSheet]] = [:]

        for sheet in sheets {
            let normalizedName = sheet.name
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            grouped[normalizedName, default: []].append(sheet)
        }

        return grouped.values.compactMap { group in
            if group.count == 1 {
                return group.first
            }

            if let preferredSheetID,
               let preferred = group.first(where: { $0.id == preferredSheetID }) {
                return preferred
            }

            return group.sorted { lhs, rhs in
                if lhs.isSystemStyleSheet != rhs.isSystemStyleSheet {
                    return lhs.isSystemStyleSheet
                }
                return lhs.createdDate <= rhs.createdDate
            }.first
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    // MARK: - Default StyleSheet Creation
    
    /// Create the default system stylesheet with all UIFont.TextStyle equivalents
    static func createDefaultStyleSheet() -> StyleSheet {
        let sheet = StyleSheet(name: "Default", isSystemStyleSheet: true)
        
        // System text styles based on UIFont.TextStyle
        // Format: (textStyle, displayName, category, order, customFontSize, includeInTOC, tocLevel)
        let systemStyles: [(UIFont.TextStyle, String, StyleCategory, Int, CGFloat?, Bool, Int)] = [
            (.largeTitle, "Large Title", .heading, 0, nil, true, 0),   // TOC Level 0 (no indent)
            (.title1, "Title 1", .heading, 1, nil, true, 0),           // TOC Level 0 (no indent)
            (.title2, "Title 2", .heading, 2, nil, true, 1),           // TOC Level 1 (first indent)
            (.title3, "Title 3", .heading, 3, nil, true, 2),           // TOC Level 2 (second indent)
            (.headline, "Headline", .heading, 4, nil, true, 3),        // TOC Level 3 (third indent)
            (.body, "Body", .text, 5, nil, false, 0),
            (.callout, "Body 1", .text, 6, 16, false, 0),  // Renamed to Body 1, set to 16pt
            (.subheadline, "Body 2", .text, 7, 14, false, 0),  // Renamed to Body 2, set to 14pt
            (.footnote, "Footnote", .footnote, 8, nil, false, 0),  // Keep for pagination but hidden from picker
            (.caption1, "Caption 1", .text, 9, nil, false, 0),
            (.caption2, "Caption 2", .text, 10, nil, false, 0)
        ]
        
        var styles: [TextStyleModel] = []
        
        for (textStyle, displayName, category, order, customFontSize, includeInTOC, tocLevel) in systemStyles {
            let font = UIFont.preferredFont(forTextStyle: textStyle)
            
            // Set bold/italic explicitly based on style type
            // All heading-category styles should be bold (Large Title, Title 1–3, Headline)
            let isBold = (category == .heading)
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
            
            // Set TOC properties for heading styles
            style.includeInTOC = includeInTOC
            style.tocLevel = tocLevel
            
            styles.append(style)
        }
        
        // Add specialized list styles
        // Base indentation per level: 36 points (0.5 inches)
        let listIndentPerLevel: CGFloat = 36.0
        
        // List styles: (name, displayName, numberFormat, order, level, bulletChar, parentStyleName)
        // Level 0 = base, Level 1 = first sub-level, Level 2 = second sub-level
        // parentStyleName is used to reset sub-list numbering when parent changes
        let listStyles: [(String, String, NumberFormat, Int, Int, String?, String?)] = [
            // Numbered lists
            ("list-numbered", "Numbered List", .decimal, 11, 0, nil, nil),
            ("list-numbered-level-2", "Numbered List Level 2", .lowercaseLetter, 12, 1, nil, "list-numbered"),
            ("list-numbered-level-3", "Numbered List Level 3", .lowercaseRoman, 13, 2, nil, "list-numbered-level-2"),
            // Bullet lists
            ("list-bullet", "Bullet List", .bulletSymbols, 14, 0, "•", nil),
            ("list-bullet-level-2", "Bullet List Level 2", .bulletSymbols, 15, 1, "◦", "list-bullet"),
            ("list-bullet-level-3", "Bullet List Level 3", .bulletSymbols, 16, 2, "▪", "list-bullet-level-2")
        ]
        
        for (name, displayName, numberFormat, order, level, _, parentStyle) in listStyles {
            let headIndent = listIndentPerLevel * CGFloat(level + 1)
            let style = TextStyleModel(
                name: name,
                displayName: displayName,
                displayOrder: order,
                fontSize: 17,  // Platform scaling now applied at render time in generateFont()
                alignment: .left,  // Explicitly set left alignment for list styles
                headIndent: headIndent,
                numberFormat: numberFormat,
                styleCategory: .list,
                isSystemStyle: false
            )
            style.parentStyleName = parentStyle
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
            "list-numbered-level-2": .list,              // Numbered List Level 2
            "list-numbered-level-3": .list,              // Numbered List Level 3
            "list-bullet": .list,                        // Bullet List
            "list-bullet-level-2": .list,                // Bullet List Level 2
            "list-bullet-level-3": .list                 // Bullet List Level 3
        ]
        
        // Obsolete styles to remove
        let obsoleteStyleNames = ["list-lowercase-letter", "list-uppercase-letter"]
        
        var fixedCount = 0
        var deletedCount = 0
        var addedCount = 0
        
        // Get existing style names for quick lookup
        let existingStyleNames = Set(styles.map { $0.name })
        
        // Add missing system text/heading/footnote styles
        // These can be lost during CloudKit sync turbulence
        let systemStyleDefs: [(UIFont.TextStyle, String, StyleCategory, Int, CGFloat?, Bool, Int)] = [
            (.largeTitle, "Large Title", .heading, 0, nil, true, 0),
            (.title1, "Title 1", .heading, 1, nil, true, 0),
            (.title2, "Title 2", .heading, 2, nil, true, 1),
            (.title3, "Title 3", .heading, 3, nil, true, 2),
            (.headline, "Headline", .heading, 4, nil, true, 3),
            (.body, "Body", .text, 5, nil, false, 0),
            (.callout, "Body 1", .text, 6, 16, false, 0),
            (.subheadline, "Body 2", .text, 7, 14, false, 0),
            (.footnote, "Footnote", .footnote, 8, nil, false, 0),
            (.caption1, "Caption 1", .text, 9, nil, false, 0),
            (.caption2, "Caption 2", .text, 10, nil, false, 0)
        ]
        
        for (textStyle, displayName, category, order, customFontSize, includeInTOC, tocLevel) in systemStyleDefs {
            let styleName = textStyle.rawValue
            if !existingStyleNames.contains(styleName) {
                let font = UIFont.preferredFont(forTextStyle: textStyle)
                let isBold = (category == .heading)
                let fontSize = customFontSize ?? font.pointSize
                let numberFormat: NumberFormat = (category == .footnote) ? .decimal : .none
                let numberAdornment: NumberingAdornment = (category == .footnote) ? .plain : .period
                
                let newStyle = TextStyleModel(
                    name: styleName,
                    displayName: displayName,
                    displayOrder: order,
                    fontSize: fontSize,
                    isBold: isBold,
                    isItalic: false,
                    alignment: .left,
                    numberFormat: numberFormat,
                    styleCategory: category,
                    isSystemStyle: true
                )
                newStyle.numberAdornment = numberAdornment
                newStyle.includeInTOC = includeInTOC
                newStyle.tocLevel = tocLevel
                newStyle.styleSheet = stylesheet
                context.insert(newStyle)
                
                if stylesheet.textStyles == nil {
                    stylesheet.textStyles = [newStyle]
                } else {
                    stylesheet.textStyles?.append(newStyle)
                }
                
                addedCount += 1
                #if DEBUG
                print("➕ Added missing system style: \(displayName)")
                #endif
            }
        }
        
        // Add missing nested list styles (Level 2 and 3)
        let listIndentPerLevel: CGFloat = 36.0
        let nestedListStyles: [(String, String, NumberFormat, Int, Int)] = [
            // Base list styles (in case they're missing)
            ("list-numbered", "Numbered List", .decimal, 11, 0),
            ("list-bullet", "Bullet List", .bulletSymbols, 14, 0),
            // Nested list styles
            ("list-numbered-level-2", "Numbered List Level 2", .lowercaseLetter, 12, 1),
            ("list-numbered-level-3", "Numbered List Level 3", .lowercaseRoman, 13, 2),
            ("list-bullet-level-2", "Bullet List Level 2", .bulletSymbols, 15, 1),
            ("list-bullet-level-3", "Bullet List Level 3", .bulletSymbols, 16, 2)
        ]
        
        for (name, displayName, numberFormat, order, level) in nestedListStyles {
            if !existingStyleNames.contains(name) {
                let headIndent = listIndentPerLevel * CGFloat(level + 1)
                let newStyle = TextStyleModel(
                    name: name,
                    displayName: displayName,
                    displayOrder: order,
                    fontSize: 17,
                    alignment: .left,
                    headIndent: headIndent,
                    numberFormat: numberFormat,
                    styleCategory: .list,
                    isSystemStyle: false
                )
                newStyle.styleSheet = stylesheet
                context.insert(newStyle)
                
                // Also append to the stylesheet's textStyles array explicitly
                if stylesheet.textStyles == nil {
                    stylesheet.textStyles = [newStyle]
                } else {
                    stylesheet.textStyles?.append(newStyle)
                }
                
                addedCount += 1
                #if DEBUG
                print("➕ Added missing list style: \(displayName)")
                #endif
            }
        }
        
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
        
        if fixedCount > 0 || deletedCount > 0 || addedCount > 0 {
            #if DEBUG
            print("✅ Fixed \(fixedCount) style categories, deleted \(deletedCount) obsolete styles, added \(addedCount) missing styles - saving...")
            #endif
            Task { @MainActor in WriteCoalescer.shared?.requestSave() }
        } else {
            #if DEBUG
            print("✅ All style categories are correct, no obsolete styles found, no missing styles")
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
        
        // Also fix all project stylesheets (not just system ones)
        let allSheetsDescriptor = FetchDescriptor<StyleSheet>()
        if let allSheets = try? context.fetch(allSheetsDescriptor) {
            for sheet in allSheets {
                if !existingSystemSheets.contains(where: { $0.id == sheet.id }) {
                    fixStyleCategories(in: sheet, context: context)
                }
            }
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
            Task { @MainActor in WriteCoalescer.shared?.requestSave() }
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
                    Task { @MainActor in WriteCoalescer.shared?.requestSave() }
                    #if DEBUG
                    print("✅ Added default image style to existing stylesheet")
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
        Task { @MainActor in WriteCoalescer.shared?.requestSave() }
        #if DEBUG
        print("📐 Default stylesheet created successfully with \(defaultSheet.textStyles?.count ?? 0) text styles and \(defaultSheet.imageStyles?.count ?? 0) image styles")
        #endif
    }
    
    // MARK: - Style Migration
    
    /// Update existing stylesheets to enable TOC for heading styles
    /// Called during app launch to ensure existing data has TOC settings
    static func migrateHeadingStylesToTOC(context: ModelContext) {
        // Define which styles should be in TOC and their levels
        let tocConfig: [String: (includeInTOC: Bool, tocLevel: Int)] = [
            "UICTFontTextStyleLargeTitle": (true, 0),  // Large Title - no indent
            "UICTFontTextStyleTitle1": (true, 0),      // Title 1 - no indent
            "UICTFontTextStyleTitle2": (true, 1),      // Title 2 - level 1
            "UICTFontTextStyleTitle3": (true, 2),      // Title 3 - level 2
            "UICTFontTextStyleHeadline": (true, 3)     // Headline - level 3
        ]
        
        // Get all stylesheets
        let descriptor = FetchDescriptor<StyleSheet>()
        guard let sheets = try? context.fetch(descriptor) else {
            return
        }
        
        var updated = false
        
        for sheet in sheets {
            guard let styles = sheet.textStyles else { continue }
            
            for style in styles {
                if let config = tocConfig[style.name] {
                    // Only update if not already configured for TOC
                    if !style.includeInTOC {
                        style.includeInTOC = config.includeInTOC
                        style.tocLevel = config.tocLevel
                        updated = true
                        #if DEBUG
                        print("[StyleSheet Migration] Enabled TOC for style: \(style.displayName) at level \(config.tocLevel)")
                        #endif
                    }
                }
            }
        }
        
        if updated {
            Task { @MainActor in WriteCoalescer.shared?.requestSave() }
            #if DEBUG
            print("[StyleSheet Migration] TOC settings migration complete")
            #endif
        }
    }
    
    /// Ensure all heading-category styles have isBold = true
    /// Previously only Headline was set bold; Title 1–3 and Large Title were missed.
    static func migrateHeadingStylesToBold(context: ModelContext) {
        // Style names that should be bold (all heading-category system styles)
        let headingStyleNames: Set<String> = [
            "UICTFontTextStyleTitle0",       // Large Title (alias)
            "UICTFontTextStyleLargeTitle",    // Large Title
            "UICTFontTextStyleTitle1",        // Title 1
            "UICTFontTextStyleTitle2",        // Title 2
            "UICTFontTextStyleTitle3",        // Title 3
            "UICTFontTextStyleHeadline"       // Headline (already bold, but included for safety)
        ]
        
        let descriptor = FetchDescriptor<StyleSheet>()
        guard let sheets = try? context.fetch(descriptor) else { return }
        
        var updated = false
        
        for sheet in sheets {
            guard let styles = sheet.textStyles else { continue }
            
            for style in styles {
                if headingStyleNames.contains(style.name) && !style.isBold {
                    style.isBold = true
                    updated = true
                    #if DEBUG
                    print("[StyleSheet Migration] Set bold for heading style: \(style.displayName)")
                    #endif
                }
            }
        }
        
        if updated {
            Task { @MainActor in WriteCoalescer.shared?.requestSave() }
            #if DEBUG
            print("[StyleSheet Migration] Heading bold migration complete")
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
        
        // Assign default to project (will be persisted on next natural save)
        project.styleSheet = defaultSheet
        
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

    // MARK: - Style Reapply

    /// Reapply an updated style definition to all files that reference this style name
    /// in all projects using the provided stylesheet.
    ///
    /// This is used when the user edits a style and chooses "Update Style" so that
    /// manuscript preview/export reflects the new style immediately, even for files
    /// that are not currently open in the editor.
    @discardableResult
    static func reapplyUpdatedStyle(
        styleName: String,
        in styleSheet: StyleSheet,
        context: ModelContext
    ) -> Int {
        let projects = styleSheet.projects ?? []
        guard !projects.isEmpty else { return 0 }

        var updatedFilesCount = 0

        for project in projects {
            updatedFilesCount += reapplyStyleInProject(
                styleName: styleName,
                styleSheet: styleSheet,
                project: project,
                context: context
            )
        }

        if updatedFilesCount > 0 {
            Task { @MainActor in WriteCoalescer.shared?.requestSave() }
        }

        return updatedFilesCount
    }

    private static func reapplyStyleInProject(
        styleName: String,
        styleSheet: StyleSheet,
        project: Project,
        context: ModelContext
    ) -> Int {
        guard let folders = project.folders else { return 0 }

        var updatedCount = 0

        func processFolder(_ folder: Folder) {
            if let textFiles = folder.textFiles {
                for textFile in textFiles {
                    if reapplyStyleInFile(
                        textFile,
                        styleName: styleName,
                        styleSheet: styleSheet,
                        project: project,
                        context: context
                    ) {
                        updatedCount += 1
                    }
                }
            }

            if let subfolders = folder.folders {
                for subfolder in subfolders {
                    processFolder(subfolder)
                }
            }
        }

        for folder in folders {
            processFolder(folder)
        }

        return updatedCount
    }

    private static func reapplyStyleInFile(
        _ file: TextFile,
        styleName: String,
        styleSheet: StyleSheet,
        project: Project,
        context: ModelContext
    ) -> Bool {
        guard let version = file.currentVersion,
              let attributedString = version.attributedContent,
              attributedString.length > 0,
              let updatedStyle = styleSheet.style(named: styleName)
                ?? resolveStyle(named: styleName, for: project, context: context) else {
            return false
        }

        let updatedAttributes = updatedStyle.generateAttributes()
        guard let updatedBaseFont = updatedAttributes[.font] as? UIFont else { return false }

        let mutable = NSMutableAttributedString(attributedString: attributedString)
        let fullRange = NSRange(location: 0, length: mutable.length)
        var didChange = false

        mutable.enumerateAttribute(.textStyle, in: fullRange, options: []) { value, styleRange, _ in
            guard let value = value as? String, value == styleName else { return }

            mutable.enumerateAttributes(in: styleRange, options: []) { currentAttrs, subrange, _ in
                var newAttrs = updatedAttributes

                let existingFont = currentAttrs[.font] as? UIFont ?? updatedBaseFont
                let existingTraits = existingFont.fontDescriptor.symbolicTraits
                if !existingTraits.isEmpty,
                   let descriptor = updatedBaseFont.fontDescriptor.withSymbolicTraits(existingTraits) {
                    newAttrs[.font] = UIFont(descriptor: descriptor, size: updatedBaseFont.pointSize)
                } else {
                    newAttrs[.font] = updatedBaseFont
                }

                newAttrs[.textStyle] = styleName

                if let attachment = currentAttrs[.attachment] {
                    newAttrs[.attachment] = attachment
                }

                if let poemSectionType = currentAttrs[.poemSectionType] {
                    newAttrs[.poemSectionType] = poemSectionType
                    newAttrs[.foregroundColor] = UIColor.systemGray
                }

                mutable.setAttributes(newAttrs, range: subrange)
            }

            didChange = true
        }

        guard didChange else { return false }

        version.attributedContent = mutable
        file.modifiedDate = Date()
        return true
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
        Task { @MainActor in WriteCoalescer.shared?.requestSave() }
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
