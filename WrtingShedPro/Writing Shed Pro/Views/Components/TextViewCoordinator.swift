import UIKit
import Combine

/// Coordinator to manage UITextView reference and typing attributes
class TextViewCoordinator: NSObject, ObservableObject, UIDocumentPickerDelegate {
    weak var textView: UITextView?
    var onImagePicked: ((URL) -> Void)?
    
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
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        print("📄 Document picker selected \(urls.count) files")
        guard let url = urls.first else { return }
        print("📄 Calling onImagePicked with: \(url.lastPathComponent)")
        onImagePicked?(url)
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        print("📄 Image picker was cancelled")
    }
}
