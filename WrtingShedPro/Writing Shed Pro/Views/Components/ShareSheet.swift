//
//  ShareSheet.swift
//  Writing Shed Pro
//
//  Wraps UIActivityViewController for sharing files via SwiftUI
//

import SwiftUI

struct ShareSheet: UIViewControllerRepresentable {
    let urls: [URL]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let activityViewController = UIActivityViewController(
            activityItems: urls,
            applicationActivities: nil
        )
        
        // Exclude certain activities if desired (optional)
        // activityViewController.excludedActivityTypes = [.saveToCameraRoll]
        
        return activityViewController
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No updates needed
    }
}
