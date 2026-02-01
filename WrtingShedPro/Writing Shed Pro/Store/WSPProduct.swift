//
//  WSPProduct.swift
//  Writing Shed Pro
//
//  Created by Keith Lander on 01/02/2026.
//

import Foundation
import SwiftUI
import StoreKitManager

// MARK: - Product Identifiers

/// Defines all in-app purchase products for Writing Shed Pro
enum WSPProduct: String, CaseIterable, Identifiable {
    case proseWriter = "com.writingshedpro.prosewriter"
    case poetryWriter = "com.writingshedpro.poetrywriter"
    case fictionWriter = "com.writingshedpro.fictionwriter"
    case dramaWriter = "com.writingshedpro.dramawriter"
    case allInBundle = "com.writingshedpro.allinbundle"
    
    var id: String { rawValue }
    
    // MARK: - All Product IDs
    
    /// Set of all product identifiers for StoreKit
    static var allProductIDs: Set<String> {
        Set(allCases.map { $0.rawValue })
    }
    
    // MARK: - Project Type Mapping
    
    /// Maps product to its corresponding ProjectType (nil for bundle)
    var projectType: ProjectType? {
        switch self {
        case .proseWriter: return .prose
        case .poetryWriter: return .poetry
        case .fictionWriter: return .fiction
        case .dramaWriter: return .drama
        case .allInBundle: return nil  // Bundle unlocks all
        }
    }
    
    /// Get the product for a given ProjectType
    static func product(for projectType: ProjectType) -> WSPProduct {
        switch projectType {
        case .prose: return .proseWriter
        case .poetry: return .poetryWriter
        case .fiction: return .fictionWriter
        case .drama: return .dramaWriter
        }
    }
    
    // MARK: - Display Properties
    
    /// User-facing display name
    var displayName: String {
        switch self {
        case .proseWriter: return "Prose Writer"
        case .poetryWriter: return "Poetry Writer"
        case .fictionWriter: return "Fiction Writer"
        case .dramaWriter: return "Drama Writer"
        case .allInBundle: return "All-in Bundle"
        }
    }
    
    /// Short description for UI
    var shortDescription: String {
        switch self {
        case .proseWriter: return "Essays, articles, journals"
        case .poetryWriter: return "Syllable counting, rhymes, forms"
        case .fictionWriter: return "Novels, short fiction, outlines"
        case .dramaWriter: return "Stage plays, screenplays, DML"
        case .allInBundle: return "All modules - best value!"
        }
    }
    
    /// SF Symbol icon name
    var iconName: String {
        switch self {
        case .proseWriter: return "doc.text"
        case .poetryWriter: return "text.quote"
        case .fictionWriter: return "book"
        case .dramaWriter: return "theatermasks"
        case .allInBundle: return "star.circle.fill"
        }
    }
    
    /// Theme color for UI
    var themeColor: Color {
        switch self {
        case .proseWriter: return .blue
        case .poetryWriter: return .purple
        case .fictionWriter: return .orange
        case .dramaWriter: return .red
        case .allInBundle: return .purple
        }
    }
    
    /// Whether this is the bundle product
    var isBundle: Bool {
        self == .allInBundle
    }
    
    /// Individual modules (excludes bundle)
    static var individualModules: [WSPProduct] {
        allCases.filter { !$0.isBundle }
    }
}
