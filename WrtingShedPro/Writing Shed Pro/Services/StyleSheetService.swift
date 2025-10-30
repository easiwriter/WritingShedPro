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
        let systemStyles: [(UIFont.TextStyle, String, StyleCategory, Int)] = [
            (.largeTitle, "Large Title", .heading, 0),
            (.title1, "Title 1", .heading, 1),
            (.title2, "Title 2", .heading, 2),
            (.title3, "Title 3", .heading, 3),
            (.headline, "Headline", .heading, 4),
            (.body, "Body", .text, 5),
            (.callout, "Callout", .text, 6),
            (.subheadline, "Subheadline", .text, 7),
            (.footnote, "Footnote", .footnote, 8),
            (.caption1, "Caption 1", .text, 9),
            (.caption2, "Caption 2", .text, 10)
        ]
        
        var styles: [TextStyleModel] = []
        
        for (textStyle, displayName, category, order) in systemStyles {
            let font = UIFont.preferredFont(forTextStyle: textStyle)
            let descriptor = font.fontDescriptor
            let traits = descriptor.symbolicTraits
            
            let style = TextStyleModel(
                name: textStyle.rawValue,
                displayName: displayName,
                displayOrder: order,
                fontSize: font.pointSize,
                isBold: traits.contains(.traitBold),
                isItalic: traits.contains(.traitItalic),
                styleCategory: category,
                isSystemStyle: true
            )
            
            styles.append(style)
        }
        
        // Add specialized list styles
        let listStyles: [(String, String, NumberFormat, Int)] = [
            ("list-numbered", "Numbered List", .decimal, 11),
            ("list-bullet", "Bullet List", .bulletSymbols, 12),
            ("list-lowercase-letter", "Letter List (a, b, c)", .lowercaseLetter, 13),
            ("list-uppercase-letter", "Letter List (A, B, C)", .uppercaseLetter, 14)
        ]
        
        for (name, displayName, numberFormat, order) in listStyles {
            let style = TextStyleModel(
                name: name,
                displayName: displayName,
                displayOrder: order,
                fontSize: 17,
                numberFormat: numberFormat,
                styleCategory: .list,
                isSystemStyle: false
            )
            styles.append(style)
        }
        
        sheet.textStyles = styles
        
        // Set relationships
        for style in styles {
            style.styleSheet = sheet
        }
        
        return sheet
    }
    
    // MARK: - StyleSheet Initialization
    
    /// Initialize stylesheets in the model context if none exist
    static func initializeStyleSheetsIfNeeded(context: ModelContext) {
        // Check if we already have stylesheets
        let descriptor = FetchDescriptor<StyleSheet>()
        let existingSheets = (try? context.fetch(descriptor)) ?? []
        
        guard existingSheets.isEmpty else {
            print("📐 StyleSheets already exist - skipping initialization")
            return
        }
        
        print("📐 Creating default stylesheet...")
        
        // Create default stylesheet
        let defaultSheet = createDefaultStyleSheet()
        context.insert(defaultSheet)
        
        // Save context
        do {
            try context.save()
            print("📐 Default stylesheet created successfully")
        } catch {
            print("❌ Error saving default stylesheet: \(error)")
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
}
