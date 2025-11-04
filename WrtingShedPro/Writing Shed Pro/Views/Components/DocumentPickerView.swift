//
//  DocumentPickerView.swift
//  Writing Shed Pro
//
//  Created on November 3, 2025.
//

import SwiftUI
import UniformTypeIdentifiers

/// SwiftUI wrapper for UIDocumentPickerViewController
/// Works around Mac Catalyst issues with direct UIKit presentation
struct DocumentPickerView: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let contentTypes: [UTType]
    let onPick: (URL) -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    func makeUIViewController(context: Context) -> UIViewController {
        let container = UIViewController()
        container.view.backgroundColor = .clear
        return container
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        if isPresented && uiViewController.presentedViewController == nil {
            let picker = UIDocumentPickerViewController(forOpeningContentTypes: contentTypes)
            picker.allowsMultipleSelection = false
            picker.delegate = context.coordinator
            
            #if targetEnvironment(macCatalyst)
            picker.modalPresentationStyle = .formSheet
            #else
            picker.modalPresentationStyle = .pageSheet
            #endif
            
            DispatchQueue.main.async {
                uiViewController.present(picker, animated: true)
            }
        } else if !isPresented && uiViewController.presentedViewController != nil {
            uiViewController.dismiss(animated: true)
        }
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPickerView
        
        init(parent: DocumentPickerView) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            print("📄 ✅ Picker selected \(urls.count) files (modern)")
            guard let url = urls.first else { return }
            parent.isPresented = false
            parent.onPick(url)
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
            print("📄 ✅ Picker selected file (legacy)")
            parent.isPresented = false
            parent.onPick(url)
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            print("📄 ❌ Picker was cancelled")
            parent.isPresented = false
        }
    }
}
