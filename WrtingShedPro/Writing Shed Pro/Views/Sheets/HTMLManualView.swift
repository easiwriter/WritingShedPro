//
//  HTMLManualView.swift
//  Writing Shed Pro
//
//  Feature 027: WSP Manual
//  Displays the HTML version of the WSP Manual in a web view
//

import SwiftUI
import WebKit

/// View for displaying the bundled HTML manual
struct HTMLManualView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            HTMLManualWebView()
                .navigationTitle("Writing Shed Pro Manual")
                #if !os(macOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
        }
    }
}

/// WebView wrapper for displaying HTML content
struct HTMLManualWebView: UIViewRepresentable {
    
    /// Name of the bundled HTML manual file (without extension)
    private static let manualFileName = "WSP Manual"
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.isOpaque = false
        webView.backgroundColor = .systemBackground
        loadManual(into: webView)
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // No updates needed
    }
    
    private func loadManual(into webView: WKWebView) {
        // Try to load the HTML manual from the app bundle
        if let manualURL = Bundle.main.url(
            forResource: Self.manualFileName,
            withExtension: "html"
        ) {
            webView.loadFileURL(manualURL, allowingReadAccessTo: manualURL.deletingLastPathComponent())
        } else {
            // Show placeholder message if manual not found
            let placeholderHTML = """
            <!DOCTYPE html>
            <html>
            <head>
                <meta name="viewport" content="width=device-width, initial-scale=1">
                <style>
                    body {
                        font-family: -apple-system, BlinkMacSystemFont, sans-serif;
                        padding: 40px 20px;
                        text-align: center;
                        color: #666;
                    }
                    h1 { color: #333; }
                    .coming-soon {
                        background: #f5f5f5;
                        padding: 20px;
                        border-radius: 12px;
                        margin-top: 20px;
                    }
                </style>
            </head>
            <body>
                <h1>📖 Writing Shed Pro Manual</h1>
                <div class="coming-soon">
                    <p>The manual is coming soon!</p>
                    <p>In the meantime, explore the app or contact support for help.</p>
                </div>
            </body>
            </html>
            """
            webView.loadHTMLString(placeholderHTML, baseURL: nil)
        }
    }
}
