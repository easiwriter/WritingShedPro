//
//  PopToRootBackButton.swift
//  Writing Shed Pro
//
//  Custom back button that supports long-press to return to project list
//

import SwiftUI

// MARK: - Notification for Pop to Root

extension Notification.Name {
    /// Notification posted when the user long-presses the back button to return to project list
    static let popToRootNavigation = Notification.Name("popToRootNavigation")
}

// MARK: - Pop to Root Back Button

/// A custom back button that supports long-press gesture to pop to root navigation
/// Usage: Add this to views that should support long-press-to-root navigation
/// and hide the default back button with .navigationBarBackButtonHidden(true)
struct PopToRootBackButton: View {
    @Environment(\.dismiss) private var dismiss
    
    /// Optional custom title for the back button (use previous screen's title)
    var title: String?
    
    var body: some View {
        Button {
            dismiss()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                    .fontWeight(.semibold)
                if let title = title {
                    Text(title)
                }
            }
        }
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    // Post notification to trigger pop to root
                    NotificationCenter.default.post(name: .popToRootNavigation, object: nil)
                }
        )
        .accessibilityLabel(NSLocalizedString("navigation.back", comment: "Back button accessibility label"))
        .accessibilityHint(NSLocalizedString("navigation.backLongPressHint", comment: "Long press to return to project list"))
    }
}

// MARK: - View Extension for Pop to Root

extension View {
    /// Adds a listener for the pop-to-root notification that dismisses this view
    func onPopToRoot(perform action: @escaping () -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: .popToRootNavigation)) { _ in
            action()
        }
    }
}
