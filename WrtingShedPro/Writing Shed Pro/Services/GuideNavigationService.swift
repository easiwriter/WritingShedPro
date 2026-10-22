//
//  GuideNavigationService.swift
//  Writing Shed Pro
//
//  Service for navigating to guide sections in the HTML manual
//

import Foundation

enum AppUpdateDetector {
    private static let lastLaunchedVersionKey = "lastLaunchedMarketingVersion"

    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    static func pendingVersion(defaults: UserDefaults = .standard) -> String? {
        let version = currentVersion
        guard !version.isEmpty else { return nil }

        guard let previousVersion = defaults.string(forKey: lastLaunchedVersionKey) else {
            defaults.set(version, forKey: lastLaunchedVersionKey)
            return nil
        }

        return previousVersion == version ? nil : version
    }

    static func markPresented(version: String, defaults: UserDefaults = .standard) {
        defaults.set(version, forKey: lastLaunchedVersionKey)
    }
}

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
