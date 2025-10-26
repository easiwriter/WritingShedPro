//
//  AppDelegate.swift
//  Writing Shed Pro
//
//  Created on 26/10/2025.
//

import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        return true
    }
    
    override func buildMenu(with builder: UIMenuBuilder) {
        super.buildMenu(with: builder)
        
        // Remove all standard menus
        builder.remove(menu: .file)
        builder.remove(menu: .edit)
        builder.remove(menu: .view)
        builder.remove(menu: .window)
        builder.remove(menu: .help)
        builder.remove(menu: .format)
        builder.remove(menu: .services)
    }
}
