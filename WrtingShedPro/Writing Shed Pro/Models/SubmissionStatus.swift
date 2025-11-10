//
//  SubmissionStatus.swift
//  Writing Shed Pro
//
//  Created on 9 November 2025.
//  Feature 008b: Publication Management System
//

import Foundation
import SwiftUI

enum SubmissionStatus: String, Codable {
    case pending
    case accepted
    case rejected
    
    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .accepted: return "Accepted"
        case .rejected: return "Rejected"
        }
    }
    
    var icon: String {
        switch self {
        case .pending: return "⏳"
        case .accepted: return "✓"
        case .rejected: return "✗"
        }
    }
    
    var color: Color {
        switch self {
        case .pending: return .orange
        case .accepted: return .green
        case .rejected: return .red
        }
    }
}
