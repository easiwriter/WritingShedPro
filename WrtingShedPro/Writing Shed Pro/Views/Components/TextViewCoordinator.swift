import UIKit
import Combine
import PhotosUI

extension UITextView {
    func normalizedNavigationPosition(_ characterPosition: Int) -> Int {
        let string = textStorage.string as NSString
        var position = min(max(0, characterPosition), string.length)

        while position < string.length,
              let scalar = UnicodeScalar(string.character(at: position)),
              CharacterSet.whitespacesAndNewlines.contains(scalar) {
            position += 1
        }

        return position
    }

    func scrollCharacterToTop(_ characterPosition: Int, animated: Bool = false) {
        guard textStorage.length > 0 else {
            setContentOffset(CGPoint(x: contentOffset.x, y: -adjustedContentInset.top), animated: animated)
            return
        }

        let position = min(max(0, characterPosition), textStorage.length - 1)
        layoutManager.ensureLayout(for: textContainer)
        let glyphIndex = layoutManager.glyphIndexForCharacter(at: position)
        let lineRect = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)
        let minimumOffsetY = -adjustedContentInset.top
        let maximumOffsetY = max(
            minimumOffsetY,
            contentSize.height - bounds.height + adjustedContentInset.bottom
        )
        let requestedOffsetY = lineRect.minY + textContainerInset.top - adjustedContentInset.top
        let offsetY = min(maximumOffsetY, max(minimumOffsetY, requestedOffsetY))
        setContentOffset(CGPoint(x: contentOffset.x, y: offsetY), animated: animated)
    }
}

/// Coordinator to manage UITextView reference and typing attributes
class TextViewCoordinator: NSObject, ObservableObject, UIDocumentPickerDelegate, PHPickerViewControllerDelegate {
    weak var textView: UITextView?
    var onImagePicked: ((URL) -> Void)?
    var flushPendingTyping: (() -> Void)?
    weak var presentingViewController: UIViewController?
    var documentPicker: UIDocumentPickerViewController? // Strong reference for Mac Catalyst
    var phPicker: PHPickerViewController? // Strong reference for PHPicker
    
    /// Modify typing attributes without triggering SwiftUI updates
    func modifyTypingAttributes(_ modifier: @escaping (UITextView) -> Void) {
        guard let textView = textView else {
            #if DEBUG
            print("⚠️ textView is nil in coordinator")
            #endif
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
        #if DEBUG
        print("📄 ✅ Document picker selected \(urls.count) files (modern API)")
        #endif
        guard let url = urls.first else {
            #if DEBUG
            print("📄 ❌ No URL in urls array")
            #endif
            return
        }
        #if DEBUG
        print("📄 Selected file: \(url.lastPathComponent)")
        #endif
        #if DEBUG
        print("📄 File path: \(url.path)")
        #endif
        #if DEBUG
        print("📄 onImagePicked callback is: \(self.onImagePicked != nil ? "SET" : "NIL")")
        #endif
        
        // The document picker will dismiss itself automatically
        // We need to wait for both the dismissal animation AND the presentation system to settle
        // before trying to present another sheet from SwiftUI
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            #if DEBUG
            print("📄 Calling onImagePicked after dismissal delay")
            #endif
            self.onImagePicked?(url)
            // Clear references
            self.documentPicker = nil
        }
    }
    
    // Legacy delegate method (might be called on Mac Catalyst)
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
        #if DEBUG
        print("📄 ✅ Document picker selected file (legacy API): \(url.lastPathComponent)")
        #endif
        #if DEBUG
        print("📄 File path: \(url.path)")
        #endif
        #if DEBUG
        print("📄 onImagePicked callback is: \(self.onImagePicked != nil ? "SET" : "NIL")")
        #endif
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            #if DEBUG
            print("📄 Calling onImagePicked after dismissal delay")
            #endif
            self.onImagePicked?(url)
            // Clear references
            self.documentPicker = nil
        }
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        #if DEBUG
        print("📄 ❌ Image picker was cancelled")
        #endif
        #if DEBUG
        print("📄 Controller: \(controller)")
        #endif
        #if DEBUG
        print("📄 Delegate is still set: \(controller.delegate != nil)")
        #endif
        // Clear references
        self.onImagePicked = nil
        self.documentPicker = nil
    }
    
    // MARK: - PHPickerViewControllerDelegate
    
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        #if DEBUG
        print("📸 PHPicker finished with \(results.count) results")
        #endif
        
        // Dismiss the picker first
        picker.dismiss(animated: true) {
            guard let result = results.first else {
                #if DEBUG
                print("📸 ❌ No results selected")
                #endif
                self.phPicker = nil
                return
            }
            
            #if DEBUG
            print("📸 Processing result...")
            #endif
            
            // Load the image as a file representation
            result.itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { url, error in
                if let error = error {
                    #if DEBUG
                    print("📸 ❌ Error loading file: \(error.localizedDescription)")
                    #endif
                    return
                }
                
                guard let url = url else {
                    #if DEBUG
                    print("📸 ❌ No URL from file representation")
                    #endif
                    return
                }
                
                #if DEBUG
                print("📸 ✅ Got URL: \(url.lastPathComponent)")
                #endif
                
                // Copy to temporary location since PHPicker URL is temporary
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
                do {
                    // Remove existing file if present
                    if FileManager.default.fileExists(atPath: tempURL.path) {
                        try FileManager.default.removeItem(at: tempURL)
                    }
                    try FileManager.default.copyItem(at: url, to: tempURL)
                    #if DEBUG
                    print("📸 Copied to temp location: \(tempURL.path)")
                    #endif
                    
                    // Call the callback on main thread with a delay for dismissal
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        #if DEBUG
                        print("📸 Calling onImagePicked")
                        #endif
                        self.onImagePicked?(tempURL)
                        self.phPicker = nil
                    }
                } catch {
                    #if DEBUG
                    print("📸 ❌ Error copying file: \(error.localizedDescription)")
                    #endif
                }
            }
        }
    }
}
