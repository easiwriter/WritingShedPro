import SwiftUI
import UIKit
import Combine
import Observation

/// Observable service that detects keyboard state and type
/// Distinguishes between on-screen (software) keyboard and external (hardware) keyboard
@Observable
class KeyboardObserver {
    
    // MARK: - Observable Properties
    
    /// Whether any keyboard is currently visible
    private(set) var isKeyboardVisible = false
    
    /// Whether the on-screen software keyboard is visible
    private(set) var isOnScreenKeyboard = false
    
    /// Whether an external hardware keyboard is being used
    private(set) var isExternalKeyboard = false
    
    /// Current keyboard height (0 if not visible)
    private(set) var keyboardHeight: CGFloat = 0
    
    /// Keyboard animation duration (for matching animations)
    private(set) var keyboardAnimationDuration: TimeInterval = 0.25
    
    /// Keyboard animation curve
    private(set) var keyboardAnimationCurve: UIView.AnimationCurve = .easeInOut
    
    // MARK: - Initialization
    
    init() {
        setupNotifications()
        detectKeyboardType()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Private Methods
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow(_:)),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardDidChangeFrame(_:)),
            name: UIResponder.keyboardDidChangeFrameNotification,
            object: nil
        )
    }
    
    private func detectKeyboardType() {
        // On Mac Catalyst, always treat as external keyboard
        #if targetEnvironment(macCatalyst)
        isExternalKeyboard = true
        isOnScreenKeyboard = false
        #else
        // On iPad, check if external keyboard is connected
        // This is heuristic-based since iOS doesn't provide a direct API
        // If the keyboard height is very small (< 100 points) or zero,
        // it's likely an external keyboard or iPad with keyboard attached
        if keyboardHeight < 100 {
            isExternalKeyboard = true
            isOnScreenKeyboard = false
        } else {
            isExternalKeyboard = false
            isOnScreenKeyboard = true
        }
        #endif
    }
    
    // MARK: - Notification Handlers
    
    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval,
              let curveValue = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? Int,
              let curve = UIView.AnimationCurve(rawValue: curveValue) else {
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.isKeyboardVisible = true
            self.keyboardHeight = keyboardFrame.height
            self.keyboardAnimationDuration = duration
            self.keyboardAnimationCurve = curve
            
            self.detectKeyboardType()
            
            #if DEBUG
            print("🎹 Keyboard shown - Height: \(self.keyboardHeight), Type: \(self.isOnScreenKeyboard ? "On-Screen" : "External")")
            #endif
        }
    }
    
    @objc private func keyboardWillHide(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval,
              let curveValue = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? Int,
              let curve = UIView.AnimationCurve(rawValue: curveValue) else {
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.isKeyboardVisible = false
            self.keyboardHeight = 0
            self.keyboardAnimationDuration = duration
            self.keyboardAnimationCurve = curve
            self.isOnScreenKeyboard = false
            
            #if DEBUG
            print("🎹 Keyboard hidden")
            #endif
        }
    }
    
    @objc private func keyboardDidChangeFrame(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let newHeight = keyboardFrame.height
            
            // Only update if height actually changed
            if abs(self.keyboardHeight - newHeight) > 1 {
                self.keyboardHeight = newHeight
                self.detectKeyboardType()
                
                #if DEBUG
                print("🎹 Keyboard frame changed - Height: \(self.keyboardHeight)")
                #endif
            }
        }
    }
    
    // MARK: - Public Helpers
    
    /// Returns the appropriate toolbar position based on keyboard state
    var toolbarPosition: ToolbarPosition {
        #if targetEnvironment(macCatalyst)
        return .top
        #else
        if isOnScreenKeyboard {
            return .inputAccessory
        } else if isExternalKeyboard {
            return .bottom
        } else {
            return .bottom
        }
        #endif
    }
}

// MARK: - Toolbar Position

enum ToolbarPosition {
    /// Above the keyboard (iOS on-screen keyboard only)
    case inputAccessory
    
    /// At the bottom of the screen (iOS with external keyboard)
    case bottom
    
    /// At the top of the screen (Mac Catalyst)
    case top
}

// MARK: - CustomStringConvertible

extension ToolbarPosition: CustomStringConvertible {
    var description: String {
        switch self {
        case .inputAccessory: return "Input Accessory"
        case .bottom: return "Bottom"
        case .top: return "Top"
        }
    }
}
