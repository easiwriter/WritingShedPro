//
//  AppConstants.swift
//  WSP Reader
//
//  App-wide constants and configuration
//  Feature 026: WSP Reader App
//

import Foundation

enum AppConstants {
    // MARK: - Website URLs
    static let websiteURL = URL(string: "https://appworks.pro")!
    static let supportURL = URL(string: "https://appworks.pro/contact/")!
    static let privacyURL = URL(string: "https://appworks.pro/wsp-privacy-policy/")!
    
    // MARK: - App Store
    static let appStoreURL = URL(string: "https://apps.apple.com/gb/app/writing-shed-pro/id6747890719")!
    
    // MARK: - Font Size Defaults
    static let defaultFontSize: CGFloat = 16
    static let minimumFontSize: CGFloat = 12
    static let maximumFontSize: CGFloat = 32
    static let fontSizeStep: CGFloat = 2
}
