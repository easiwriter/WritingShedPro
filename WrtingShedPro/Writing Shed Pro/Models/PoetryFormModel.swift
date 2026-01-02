//
//  PoetryFormModel.swift
//  Writing Shed Pro
//
//  Created by AI Assistant on 2026-01-01.
//  Feature 021 Phase 2: Custom Poetry Form Editor
//

import Foundation
import SwiftData

/// SwiftData model for storing poetry forms in the database
/// Supports both predefined forms (migrated from JSON) and custom user-created forms
/// CloudKit compatible: all attributes are optional or have default values
@Model
final class PoetryFormModel {
    
    // MARK: - Properties
    
    /// Unique identifier for the form
    var id: UUID = UUID()
    
    /// Display name of the form (e.g., "Haiku", "Sonnet")
    var name: String = ""
    
    /// Category for grouping (stored as raw string for CloudKit compatibility)
    var categoryRaw: String = ""
    
    /// Number of lines in the form (nil for variable-length forms)
    var lineCount: Int?
    
    /// JSON-encoded syllable pattern array (e.g., "[5,7,5]" for Haiku)
    var syllablePatternData: Data?
    
    /// Rhyme scheme pattern (e.g., "ABAB CDCD EFEF GG" for Shakespearean Sonnet)
    var rhymeScheme: String?
    
    /// Meter pattern description (e.g., "iambic pentameter")
    var meterPattern: String?
    
    /// Detailed description of the form
    var formDescription: String = ""
    
    /// Template content to pre-populate new files
    var templateContent: String = ""
    
    /// Whether this is a user-created custom form
    var isCustom: Bool = true
    
    /// Whether this is a predefined form (migrated from JSON)
    var isPredefined: Bool = false
    
    /// When the form was created
    var createdDate: Date = Date()
    
    /// When the form was last modified
    var modifiedDate: Date = Date()
    
    // MARK: - Computed Properties
    
    /// Category enum accessor
    var category: PoetryFormCategory {
        get {
            PoetryFormCategory(rawValue: categoryRaw) ?? .custom
        }
        set {
            categoryRaw = newValue.rawValue
        }
    }
    
    /// Syllable pattern array accessor
    var syllablePattern: [Int]? {
        get {
            guard let data = syllablePatternData else { return nil }
            return try? JSONDecoder().decode([Int].self, from: data)
        }
        set {
            if let pattern = newValue {
                syllablePatternData = try? JSONEncoder().encode(pattern)
            } else {
                syllablePatternData = nil
            }
        }
    }
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        name: String = "",
        category: PoetryFormCategory = .custom,
        lineCount: Int? = nil,
        syllablePattern: [Int]? = nil,
        rhymeScheme: String? = nil,
        meterPattern: String? = nil,
        formDescription: String = "",
        templateContent: String = "",
        isCustom: Bool = true,
        isPredefined: Bool = false,
        createdDate: Date = Date(),
        modifiedDate: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.categoryRaw = category.rawValue
        self.lineCount = lineCount
        self.rhymeScheme = rhymeScheme
        self.meterPattern = meterPattern
        self.formDescription = formDescription
        self.templateContent = templateContent
        self.isCustom = isCustom
        self.isPredefined = isPredefined
        self.createdDate = createdDate
        self.modifiedDate = modifiedDate
        
        // Set syllable pattern through computed property
        if let pattern = syllablePattern {
            self.syllablePatternData = try? JSONEncoder().encode(pattern)
        }
    }
    
    // MARK: - Conversion Methods
    
    /// Convert this model to a lightweight PoetryForm struct for UI use
    func toPoetryForm() -> PoetryForm {
        PoetryForm(
            id: id,
            name: name,
            category: category,
            lineCount: lineCount,
            syllablePattern: syllablePattern,
            rhymeScheme: rhymeScheme,
            meterPattern: meterPattern,
            description: formDescription,
            templateContent: templateContent,
            isCustom: isCustom
        )
    }
    
    /// Create a PoetryFormModel from a PoetryForm struct
    /// - Parameters:
    ///   - form: The PoetryForm struct to convert
    ///   - isPredefined: Whether this is a predefined form (from JSON)
    /// - Returns: A new PoetryFormModel instance
    static func from(_ form: PoetryForm, isPredefined: Bool = false) -> PoetryFormModel {
        PoetryFormModel(
            id: form.id,
            name: form.name,
            category: form.category,
            lineCount: form.lineCount,
            syllablePattern: form.syllablePattern,
            rhymeScheme: form.rhymeScheme,
            meterPattern: form.meterPattern,
            formDescription: form.description,
            templateContent: form.templateContent,
            isCustom: form.isCustom,
            isPredefined: isPredefined
        )
    }
    
    /// Create a duplicate of this form as a custom form
    /// Used for "Duplicate as Custom" functionality
    func duplicateAsCustom() -> PoetryFormModel {
        PoetryFormModel(
            id: UUID(),  // New ID for the duplicate
            name: "\(name) (Copy)",
            category: category,
            lineCount: lineCount,
            syllablePattern: syllablePattern,
            rhymeScheme: rhymeScheme,
            meterPattern: meterPattern,
            formDescription: formDescription,
            templateContent: templateContent,
            isCustom: true,
            isPredefined: false,
            createdDate: Date(),
            modifiedDate: Date()
        )
    }
}
