//
//  PublicationType.swift
//  Writing Shed Pro
//
//  Created on 9 November 2025.
//  Feature 008b: Publication Management System
//

import Foundation

enum PublicationType: String, Codable {
    case magazine
    case competition
    case publisher
    case agent
    case other
    
    var displayName: String {
        switch self {
        case .magazine: return NSLocalizedString("publications.type.magazine", comment: "Magazine")
        case .competition: return NSLocalizedString("publications.type.competition", comment: "Competition")
        case .publisher: return NSLocalizedString("publications.type.publisher", comment: "Publisher")
        case .agent: return NSLocalizedString("publications.type.agent", comment: "Agent")
        case .other: return NSLocalizedString("publications.type.other", comment: "Other")
        }
    }
    
    var icon: String {
        switch self {
        case .magazine: return "📰"
        case .competition: return "🏆"
        case .publisher: return "📚"
        case .agent: return "🤝"
        case .other: return "📄"
        }
    }
    
    /// Returns the publication types available for a given project type
    static func availableTypes(for type: ProjectType) -> [PublicationType] {
        [.magazine, .competition, .publisher, .agent, .other]
    }
}
