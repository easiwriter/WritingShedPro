//
//  View+ConditionalModifier.swift
//  Writing Shed Pro
//
//  Conditional view modifier extension for applying modifiers based on a Boolean condition.
//

import SwiftUI
#if targetEnvironment(macCatalyst)
import UIKit
#endif

@MainActor
func dismissPresentedSheetOnCatalyst() {
    #if targetEnvironment(macCatalyst)
    DispatchQueue.main.async {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
        guard let rootViewController = (windows.first { $0.isKeyWindow } ?? windows.first)?.rootViewController else {
            return
        }

        var topViewController = rootViewController
        while let presented = topViewController.presentedViewController {
            topViewController = presented
        }
        if topViewController !== rootViewController {
            topViewController.dismiss(animated: true)
        }
    }
    #endif
}

extension View {
    /// Conditionally applies a view modifier.
    /// - Parameters:
    ///   - condition: Boolean condition
    ///   - transform: The modifier to apply when condition is true
    /// - Returns: The modified or unmodified view
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

/// Applies `.presentationSizing(.page)` on iOS 18+ / macOS 15+; no-op on earlier versions.
struct PagePresentationSizingModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 18.0, macOS 15.0, *) {
            content.presentationSizing(.page)
        } else {
            content
        }
    }
}
