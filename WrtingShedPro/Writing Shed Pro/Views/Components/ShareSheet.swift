//
//  ShareSheet.swift
//  Writing Shed Pro
//
//  Wraps UIActivityViewController for sharing files via SwiftUI
//

import SwiftUI

struct ShareSheet: UIViewControllerRepresentable {
    let urls: [URL]
    let facebookText: String?

    init(urls: [URL], facebookText: String? = nil) {
        self.urls = urls
        self.facebookText = facebookText
    }
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let activityItems: [Any] = urls.map { url in
            ShareActivityItemSource(url: url, facebookText: facebookText)
        }

        let activityViewController = UIActivityViewController(
            activityItems: activityItems,
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

final class ShareActivityItemSource: NSObject, UIActivityItemSource {
    private let url: URL
    private let facebookText: String

    init(url: URL, facebookText: String?) {
        self.url = url
        self.facebookText = facebookText ?? "Shared from Writing Shed Pro: \(url.lastPathComponent)"
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        // Use text placeholder so text-based extensions (including Facebook) can appear.
        facebookText
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        if let rawValue = activityType?.rawValue.lowercased(), rawValue.contains("facebook") {
            return facebookText
        }

        return url
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        subjectForActivityType activityType: UIActivity.ActivityType?
    ) -> String {
        return url.deletingPathExtension().lastPathComponent
    }
}
