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
        case .magazine: return "Magazine"
        case .competition: return "Competition"
        case .commission: return "Commission"
        case .other: return "Other"
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
