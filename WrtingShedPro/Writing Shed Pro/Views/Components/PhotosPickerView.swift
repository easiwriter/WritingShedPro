//
//  PhotosPickerView.swift
//  Writing Shed Pro
//
//  Photo Library picker using PHPickerViewController
//

import SwiftUI
import PhotosUI

struct PhotosPickerView: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onImageSelected: (URL) -> Void
    
    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        controller.view.backgroundColor = .clear
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        if isPresented && context.coordinator.picker == nil {
            // Create and present PHPickerViewController
            var configuration = PHPickerConfiguration(photoLibrary: .shared())
            configuration.filter = .images
            configuration.selectionLimit = 1
            
            let picker = PHPickerViewController(configuration: configuration)
            picker.delegate = context.coordinator
            context.coordinator.picker = picker
            
            DispatchQueue.main.async {
                uiViewController.present(picker, animated: true)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(isPresented: $isPresented, onImageSelected: onImageSelected)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        @Binding var isPresented: Bool
        let onImageSelected: (URL) -> Void
        var picker: PHPickerViewController?
        
        init(isPresented: Binding<Bool>, onImageSelected: @escaping (URL) -> Void) {
            self._isPresented = isPresented
            self.onImageSelected = onImageSelected
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            print("🖼️ PHPicker didFinishPicking with \(results.count) results")
            
            picker.dismiss(animated: true) {
                self.isPresented = false
                self.picker = nil
            }
            
            guard let result = results.first else {
                print("🖼️ PHPicker: No results")
                return
            }
            
            // Get the image data
            result.itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.image.identifier) { url, error in
                if let error = error {
                    print("❌ PHPicker error loading file: \(error.localizedDescription)")
                    return
                }
                
                guard let url = url else {
                    print("❌ PHPicker: No URL from file representation")
                    return
                }
                
                print("🖼️ PHPicker selected: \(url.lastPathComponent)")
                
                // Copy file to temporary directory since the URL is temporary
                let tempDir = FileManager.default.temporaryDirectory
                let fileName = url.lastPathComponent.isEmpty ? "photo.jpg" : url.lastPathComponent
                let destinationURL = tempDir.appendingPathComponent(fileName)
                
                do {
                    // Remove existing file if it exists
                    if FileManager.default.fileExists(atPath: destinationURL.path) {
                        try FileManager.default.removeItem(at: destinationURL)
                    }
                    
                    // Copy the file
                    try FileManager.default.copyItem(at: url, to: destinationURL)
                    print("🖼️ PHPicker: Copied to temp directory: \(destinationURL.path)")
                    
                    // Call completion on main thread
                    DispatchQueue.main.async {
                        self.onImageSelected(destinationURL)
                    }
                } catch {
                    print("❌ PHPicker: Failed to copy file: \(error.localizedDescription)")
                }
            }
        }
    }
}
