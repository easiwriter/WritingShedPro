//
//  AppDelegate.swift
//  Writing Shed Pro
//
//  Created on 26/10/2025.
//

import UIKit

class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        return true
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


