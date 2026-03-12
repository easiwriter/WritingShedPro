//
//  AppDelegate.swift
//  Writing Shed Pro
//
//  Created on 26/10/2025.
//

import UIKit
import CloudKit

class AppDelegate: UIResponder, UIApplicationDelegate {
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


