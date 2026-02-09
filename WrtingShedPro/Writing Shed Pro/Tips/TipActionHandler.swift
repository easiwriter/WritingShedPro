//
//  TipActionHandler.swift
//  Writing Shed Pro
//
//  Feature 035: TipKit Tips
//  Reusable helper for handling tip "Learn More" actions
//

import SwiftUI
import TipKit

/// Handles the "Learn More" action from any tip by opening the guide at a section.
///
/// Usage in views:
/// ```swift
/// TipView(myTip) { action in
///     TipActionHandler.handle(action, guideSection: MyTipType.guideSection)
/// }
/// ```
enum TipActionHandler {
    
    /// Handle a tip action — if it's "learn-more", open the guide at the section
    /// - Parameters:
    ///   - action: The tip action that was tapped
    ///   - guideSection: The guide section identifier (e.g., "42-text-formatting")
    @MainActor
    static func handle(_ action: Tip.Action, guideSection: String?) {
        if action.id == "learn-more", let section = guideSection {
            GuideNavigationService.shared.openGuideSection(section)
        }
    }
}
