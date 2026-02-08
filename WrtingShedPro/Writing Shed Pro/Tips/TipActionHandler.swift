//
//  TipActionHandler.swift
//  Writing Shed Pro
//
//  Feature 035: TipKit Tips
//  Reusable helper for handling tip "Learn More" actions
//

import SwiftUI
import TipKit
import SwiftData

/// Handles the "Learn More" action from any tip by navigating to the guide section.
///
/// Usage in views:
/// ```swift
/// TipView(myTip) { action in
///     TipActionHandler.handle(action, guideSection: MyTipType.guideSection, modelContext: modelContext)
/// }
/// ```
enum TipActionHandler {
    
    /// Handle a tip action — if it's "learn-more", navigate to the guide section
    /// - Parameters:
    ///   - action: The tip action that was tapped
    ///   - guideSection: The guide section identifier (e.g., "42-text-formatting")
    ///   - modelContext: The SwiftData model context
    @MainActor
    static func handle(_ action: Tip.Action, guideSection: String?, modelContext: ModelContext) {
        if action.id == "learn-more", let section = guideSection {
            GuideNavigationService.shared.openGuideSection(section, modelContext: modelContext)
        }
    }
}
