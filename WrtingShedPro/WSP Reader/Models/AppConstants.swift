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
    static let websiteURL = URL(string: "https://writingshedpro.com")!
    static let supportURL = URL(string: "https://writingshedpro.com/support")!
    static let privacyURL = URL(string: "https://writingshedpro.com/privacy")!
    
    // MARK: - App Store
    static let appStoreURL = URL(string: "https://apps.apple.com/app/writing-shed-pro/id0000000000")!
    
    // MARK: - Font Size Defaults
    static let defaultFontSize: CGFloat = 16
    static let minimumFontSize: CGFloat = 12
    static let maximumFontSize: CGFloat = 32
    static let fontSizeStep: CGFloat = 2
}
