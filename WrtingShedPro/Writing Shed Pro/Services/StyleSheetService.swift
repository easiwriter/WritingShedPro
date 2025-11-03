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
            
            // Set bold/italic explicitly based on style type
            // Headline should be bold, everything else plain
            let isBold = (textStyle == .headline)
            let isItalic = false
            
            let style = TextStyleModel(
                name: textStyle.rawValue,
                displayName: displayName,
                displayOrder: order,
                fontSize: font.pointSize,
                isBold: isBold,
                isItalic: isItalic,
                alignment: .left,  // Explicitly set left alignment for system styles
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
    
    // MARK: - StyleSheet Initialization
    
    /// Initialize stylesheets in the model context if none exist
    static func initializeStyleSheetsIfNeeded(context: ModelContext) {
        // Check if we already have a system stylesheet
        let systemDescriptor = FetchDescriptor<StyleSheet>(
            predicate: #Predicate { $0.isSystemStyleSheet == true }
        )
        let existingSystemSheets = (try? context.fetch(systemDescriptor)) ?? []
        
        // Remove duplicates if they exist
        if existingSystemSheets.count > 1 {
            print("⚠️ Found \(existingSystemSheets.count) system stylesheets - removing duplicates")
            // Keep the first one, delete the rest
            for i in 1..<existingSystemSheets.count {
                context.delete(existingSystemSheets[i])
            }
            try? context.save()
        }
        
        // If we have an existing system stylesheet, check if it has image styles
        if let existingSheet = existingSystemSheets.first {
            print("📐 System stylesheet already exists")
            
            // Check if it has image styles
            if existingSheet.imageStyles?.isEmpty ?? true {
                print("📐 Adding default image style to existing stylesheet...")
                
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
                    print("✅ Added default image style to existing stylesheet")
                } catch {
                    print("❌ Error saving image style: \(error)")
                }
            } else {
                print("📐 System stylesheet already has \(existingSheet.imageStyles?.count ?? 0) image styles")
            }
            return
        }
        
        print("📐 Creating default stylesheet...")
        
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
            print("📐 Default stylesheet created successfully with \(defaultSheet.textStyles?.count ?? 0) text styles and \(defaultSheet.imageStyles?.count ?? 0) image styles")
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
