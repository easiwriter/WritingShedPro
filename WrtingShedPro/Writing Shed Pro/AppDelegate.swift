//
//  AppDelegate.swift
//  Writing Shed Pro
//
//  Created on 26/10/2025.
//

import UIKit
import CloudKit

extension NSNotification.Name {
    /// Posted by AppDelegate when a file is opened via Finder / Share sheet / drag-from-dock.
    /// `object` is the `URL` to open.
    static let writingShedProOpenFile = NSNotification.Name("WritingShedProOpenFile")
    /// Posted to tell the main ContentView to present its file-importer picker.
    static let writingShedProShowImportPicker = NSNotification.Name("WritingShedProShowImportPicker")
}

class AppDelegate: UIResponder, UIApplicationDelegate {

    // Store URL delivered at cold-launch so ContentView can consume it in onAppear/task.
    private(set) var pendingOpenURL: URL?
    private var lastLoggedRemoteNotificationToken: String?

    func consumePendingOpenURL() -> URL? {
        defer { pendingOpenURL = nil }
        return pendingOpenURL
    }

    // MARK: - File Open via Finder / Share sheet

    /// Called by UIKit when another app (Finder, Files, etc.) asks this app to open a URL.
    /// This is the reliable Mac Catalyst entry point – SwiftUI's onOpenURL can miss the cold-launch case.
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        #if DEBUG
        print("📂 [AppDelegate] application(_:open:options:) → \(url.lastPathComponent)")
        #endif
        pendingOpenURL = url
        NotificationCenter.default.post(name: .writingShedProOpenFile, object: url)
        return true
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // CRITICAL for Mac Catalyst: register for remote (silent push) notifications.
        // NSPersistentCloudKitContainer relies on CKDatabaseSubscription pushes to
        // trigger imports. Without this call the container starts an import event
        // at launch but never receives the push that tells it to actually pull records,
        // causing sync to stall indefinitely on Catalyst.
        application.registerForRemoteNotifications()
        #if DEBUG
        print("📱 [AppDelegate] Registered for remote notifications")
        #endif
        return true
    }
    
    // MARK: - Remote Notification Handling
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        guard token != lastLoggedRemoteNotificationToken else { return }
        lastLoggedRemoteNotificationToken = token
        print("✅ [AppDelegate] Remote notification token: \(token.prefix(16))…")
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("⚠️ [AppDelegate] Failed to register for remote notifications: \(error.localizedDescription)")
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        // When a CKDatabaseSubscription push arrives, the persistent store
        // coordinator processes it automatically.  We just need to tell the
        // system we received it.
        #if DEBUG
        print("☁️ [AppDelegate] Received remote notification — CloudKit will process")
        #endif
        completionHandler(.newData)
    }
    
    override func buildMenu(with builder: UIMenuBuilder) {
        // Only modify the main system menu
        guard builder.system == .main else {
            super.buildMenu(with: builder)
            return
        }
        
        // Remove all standard menus
        builder.remove(menu: .file)
        builder.remove(menu: .edit)
        builder.remove(menu: .view)
        builder.remove(menu: .window)
        builder.remove(menu: .help)
        builder.remove(menu: .format)
        
        // Add Format menu with indent commands for Tab/Shift+Tab handling
        let increaseIndentCommand = UIKeyCommand(
            title: NSLocalizedString("formattingToolbar.increaseIndent", comment: "Increase Indent"),
            action: #selector(CustomTextViewActions.increaseIndent(_:)),
            input: "\t",
            modifierFlags: []
        )
        
        let decreaseIndentCommand = UIKeyCommand(
            title: NSLocalizedString("formattingToolbar.decreaseIndent", comment: "Decrease Indent"),
            action: #selector(CustomTextViewActions.decreaseIndent(_:)),
            input: "\t",
            modifierFlags: .shift
        )
        
        let indentMenu = UIMenu(
            title: "Indentation",
            options: .displayInline,
            children: [increaseIndentCommand, decreaseIndentCommand]
        )
        
        let formatMenu = UIMenu(
            title: "Format",
            identifier: .init("com.writingshed.format"),
            children: [indentMenu]
        )
        
        builder.insertSibling(formatMenu, afterMenu: .application)
        
        super.buildMenu(with: builder)
    }
}

/// Protocol for indent actions - implemented by CustomTextView
@objc protocol CustomTextViewActions {
    func increaseIndent(_ sender: Any?)
    func decreaseIndent(_ sender: Any?)
}


