//
//  AppDelegate.swift
//  Writing Shed Pro
//
//  Created on 26/10/2025.
//

import SwiftUI

#if os(macOS)
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Remove standard menus
        if let mainMenu = NSApplication.shared.mainMenu {
            // Remove menus by title (keeping only the app menu at index 0)
            // Work backwards to avoid index issues
            for index in stride(from: mainMenu.items.count - 1, through: 1, by: -1) {
                mainMenu.removeItem(at: index)
            }
        }
    }
}
#endif

