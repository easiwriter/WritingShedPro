import UIKit
import Combine

/// Coordinator to manage UITextView reference and typing attributes
class TextViewCoordinator: ObservableObject {
    weak var textView: UITextView?
    
    /// Modify typing attributes without triggering SwiftUI updates
    func modifyTypingAttributes(_ modifier: @escaping (UITextView) -> Void) {
        guard let textView = textView else {
            print("⚠️ textView is nil in coordinator")
            return
        }
        
        // Apply modifier on the main thread
        DispatchQueue.main.async {
            modifier(textView)
        }
    }
}
