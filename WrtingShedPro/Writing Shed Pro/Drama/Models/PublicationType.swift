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
    case commission
    case publisher
    case agent
    case other
    
    var displayName: String {
        switch self {
        case .magazine: return NSLocalizedString("publications.type.magazine", comment: "Magazine")
        case .competition: return NSLocalizedString("publications.type.competition", comment: "Competition")
        case .commission: return NSLocalizedString("publications.type.commission", comment: "Commission")
        case .publisher: return NSLocalizedString("publications.type.publisher", comment: "Publisher")
        case .agent: return NSLocalizedString("publications.type.agent", comment: "Agent")
        case .other: return NSLocalizedString("publications.type.other", comment: "Other")
        }
    }
    
    var icon: String {
        switch self {
        case .magazine: return "📰"
        case .competition: return "🏆"
        case .commission: return "📝"
        case .publisher: return "📚"
        case .agent: return "🤝"
        case .other: return "📄"
        }
    }
    
    /// Returns the publication types available for a given project type
    static func availableTypes(for type: ProjectType) -> [PublicationType] {
        switch type {
        case .poetry:
            // Poetry: Magazines, Competitions, Other
            return [.magazine, .competition, .other]
        case .prose, .fiction, .drama:
            // Prose, Fiction (Novels), Drama (Plays): Publishers, Agents, Other
            return [.publisher, .agent, .other]
        }
    }
}
