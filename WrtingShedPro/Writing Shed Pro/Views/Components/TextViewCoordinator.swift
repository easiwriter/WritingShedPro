import UIKit
import Combine
import PhotosUI

/// Coordinator to manage UITextView reference and typing attributes
class TextViewCoordinator: NSObject, ObservableObject, UIDocumentPickerDelegate, PHPickerViewControllerDelegate {
    weak var textView: UITextView?
    var onImagePicked: ((URL) -> Void)?
    weak var presentingViewController: UIViewController?
    var documentPicker: UIDocumentPickerViewController? // Strong reference for Mac Catalyst
    var phPicker: PHPickerViewController? // Strong reference for PHPicker
    
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
    
    // MARK: - PHPickerViewControllerDelegate
    
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        print("📸 PHPicker finished with \(results.count) results")
        
        // Dismiss the picker first
        picker.dismiss(animated: true) {
            guard let result = results.first else {
                print("📸 ❌ No results selected")
                self.phPicker = nil
                return
            }
            
            print("📸 Processing result...")
            
            // Load the image as a file representation
            result.itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { url, error in
                if let error = error {
                    print("📸 ❌ Error loading file: \(error.localizedDescription)")
                    return
                }
                
                guard let url = url else {
                    print("📸 ❌ No URL from file representation")
                    return
                }
                
                print("📸 ✅ Got URL: \(url.lastPathComponent)")
                
                // Copy to temporary location since PHPicker URL is temporary
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
                do {
                    // Remove existing file if present
                    if FileManager.default.fileExists(atPath: tempURL.path) {
                        try FileManager.default.removeItem(at: tempURL)
                    }
                    try FileManager.default.copyItem(at: url, to: tempURL)
                    print("📸 Copied to temp location: \(tempURL.path)")
                    
                    // Call the callback on main thread with a delay for dismissal
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        print("📸 Calling onImagePicked")
                        self.onImagePicked?(tempURL)
                        self.phPicker = nil
                    }
                } catch {
                    print("📸 ❌ Error copying file: \(error.localizedDescription)")
                }
            }
        }
    }
}
