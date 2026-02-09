//
//  GuideNavigationService.swift
//  Writing Shed Pro
//
//  Feature 035: TipKit Tips
//  FR-9: Guide link buttons — navigates to guide sections from tip "Learn More" actions
//

import Foundation

/// Service that opens a specific section in the Writing Shed Pro HTML Guide.
///
/// When a user taps "Learn More" on a tip, this service posts a notification
/// with the section anchor ID. ContentViewBody receives this and opens the
/// HTML manual scrolled to that section.
@MainActor
class GuideNavigationService {
    static let shared = GuideNavigationService()
    
    /// Notification posted when a guide section should be opened.
    /// The `userInfo` contains `["section": String]` with the anchor ID.
    static let openGuideSectionNotification = Notification.Name("openGuideSection")
    
    /// Opens a guide section by posting a notification with the section anchor.
    /// - Parameter sectionId: The section identifier (e.g., "42-text-formatting")
    func openGuideSection(_ sectionId: String) {
        NotificationCenter.default.post(
            name: Self.openGuideSectionNotification,
            object: nil,
            userInfo: ["section": sectionId]
        )
    }
}
