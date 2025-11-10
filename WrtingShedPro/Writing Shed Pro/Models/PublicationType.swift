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
    case other
    
    var displayName: String {
        switch self {
        case .magazine: return NSLocalizedString("publications.type.magazine", comment: "Magazine")
        case .competition: return NSLocalizedString("publications.type.competition", comment: "Competition")
        case .commission: return NSLocalizedString("publications.type.commission", comment: "Commission")
        case .other: return NSLocalizedString("publications.type.other", comment: "Other")
        }
    }
    
    var icon: String {
        switch self {
        case .magazine: return "📰"
        case .competition: return "🏆"
        case .commission: return "📝"
        case .other: return "📄"
        }
    }
}
