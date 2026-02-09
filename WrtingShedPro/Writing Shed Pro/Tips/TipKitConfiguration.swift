//
//  TipKitConfiguration.swift
//  Writing Shed Pro
//
//  Feature 035: TipKit Tips
//  Global on/off switch for tips, checked by every TipView site.
//

import Foundation

/// Centralised check for the user's "Show Tips" preference.
/// Every `TipView` / `.popoverTip` call site should guard on
/// `TipKitConfiguration.tipsEnabled` before rendering.
enum TipKitConfiguration {
    
    private static let disabledKey = "tipkit.disabled"
    
    /// Whether all tips are disabled by the user (Settings → Show Tips OFF).
    static var tipsDisabled: Bool {
        UserDefaults.standard.bool(forKey: disabledKey)
    }
    
    /// Convenience inverse — true when tips should be shown.
    static var tipsEnabled: Bool {
        !tipsDisabled
    }
    
    /// Toggle the disabled state. Called from SettingsSheet.
    static func setDisabled(_ disabled: Bool) {
        UserDefaults.standard.set(disabled, forKey: disabledKey)
    }
}
