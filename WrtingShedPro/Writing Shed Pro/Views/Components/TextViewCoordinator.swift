import UIKit
import Combine

/// Coordinator to manage UITextView reference and typing attributes
class TextViewCoordinator: NSObject, ObservableObject, UIDocumentPickerDelegate {
    weak var textView: UITextView?
    var onImagePicked: ((URL) -> Void)?
    weak var presentingViewController: UIViewController?
    var documentPicker: UIDocumentPickerViewController? // Strong reference for Mac Catalyst
    
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
    
    // MARK: - UIDocumentPickerDelegate
    
    // Modern delegate method (iOS 11+)
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        print("📄 ✅ Document picker selected \(urls.count) files (modern API)")
        guard let url = urls.first else {
            print("📄 ❌ No URL in urls array")
            return
        }
        print("📄 Selected file: \(url.lastPathComponent)")
        print("📄 File path: \(url.path)")
        print("📄 onImagePicked callback is: \(self.onImagePicked != nil ? "SET" : "NIL")")
        
        // The document picker will dismiss itself automatically
        // We need to wait for both the dismissal animation AND the presentation system to settle
        // before trying to present another sheet from SwiftUI
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            print("📄 Calling onImagePicked after dismissal delay")
            self.onImagePicked?(url)
            // Clear references
            self.documentPicker = nil
        }
    }
    
    // Legacy delegate method (might be called on Mac Catalyst)
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
        print("📄 ✅ Document picker selected file (legacy API): \(url.lastPathComponent)")
        print("📄 File path: \(url.path)")
        print("📄 onImagePicked callback is: \(self.onImagePicked != nil ? "SET" : "NIL")")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            print("📄 Calling onImagePicked after dismissal delay")
            self.onImagePicked?(url)
            // Clear references
            self.documentPicker = nil
        }
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        print("📄 ❌ Image picker was cancelled")
        print("📄 Controller: \(controller)")
        print("📄 Delegate is still set: \(controller.delegate != nil)")
        // Clear references
        self.onImagePicked = nil
        self.documentPicker = nil
    }
}
