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
    
    var displayName: String {
        switch self {
        case .magazine: return "Magazine"
        case .competition: return "Competition"
        }
    }
    
    var icon: String {
        switch self {
        case .magazine: return "📰"
        case .competition: return "🏆"
        }
    }
}
