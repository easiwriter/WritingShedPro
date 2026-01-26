//
//  HTMLManualView.swift
//  Writing Shed Pro
//
//  Feature 027: WSP Manual
//  Displays the HTML version of the WSP Manual in a web view
//

import SwiftUI
import WebKit

/// View for displaying the bundled HTML guide
struct HTMLManualView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var htmlContent: String = ""
    
    /// Name of the bundled HTML guide file (without extension)
    private static let guideFileName = "Writing Shed Pro Guide"
    
    var body: some View {
        NavigationStack {
            Group {
                #if targetEnvironment(macCatalyst)
                // Mac Catalyst: Use ScrollView with AttributedString to avoid WKWebView issues
                HTMLManualScrollView(htmlContent: htmlContent)
                #else
                // iOS: Use WKWebView
                HTMLManualWebView(htmlContent: htmlContent)
                #endif
            }
            .navigationTitle("Writing Shed Pro Guide")
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
            .onAppear {
                loadHTMLContent()
            }
        }
    }
    
    private func loadHTMLContent() {
        if let guideURL = Bundle.main.url(
            forResource: Self.guideFileName,
            withExtension: "html"
        ),
           let content = try? String(contentsOf: guideURL, encoding: .utf8) {
            #if DEBUG
            print("📖 [HTMLManualView] Loaded HTML content, length: \(content.count)")
            #endif
            htmlContent = content
        } else {
            #if DEBUG
            print("❌ [HTMLManualView] Failed to load HTML file")
            #endif
            htmlContent = """
            <!DOCTYPE html>
            <html><body>
            <h1>Guide Not Found</h1>
            <p>The guide could not be loaded.</p>
            </body></html>
            """
        }
    }
}

// MARK: - Mac Catalyst: Open in browser fallback

#if targetEnvironment(macCatalyst)
/// Mac Catalyst fallback - opens guide in default browser
struct HTMLManualScrollView: View {
    let htmlContent: String
    @Environment(\.dismiss) private var dismiss
    @State private var showOpenInBrowserPrompt = true
    
    /// Name of the bundled HTML guide file (without extension)
    private static let guideFileName = "Writing Shed Pro Guide"
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "book.pages")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)
            
            Text("Writing Shed Pro Guide")
                .font(.title)
                .fontWeight(.semibold)
            
            Text("The guide will open in your default web browser for the best viewing experience on Mac.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 40)
            
            Button(action: openInBrowser) {
                Label("Open Guide in Browser", systemImage: "safari")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 10)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemBackground))
        .onAppear {
            // Automatically open in browser
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                openInBrowser()
            }
        }
    }
    
    private func openInBrowser() {
        // Open the bundled HTML file directly in Safari
        if let guideURL = Bundle.main.url(
            forResource: Self.guideFileName,
            withExtension: "html"
        ) {
            #if DEBUG
            print("📖 [HTMLManualView] Opening guide in browser: \(guideURL)")
            #endif
            
            UIApplication.shared.open(guideURL)
        } else {
            #if DEBUG
            print("❌ [HTMLManualView] Guide file not found in bundle")
            #endif
        }
        
        // Dismiss the sheet after opening
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            dismiss()
        }
    }
}
#endif

// MARK: - iOS: WKWebView-based HTML display

/// WebView wrapper for displaying HTML content (iOS only)
struct HTMLManualWebView: UIViewRepresentable {
    let htmlContent: String
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        configuration.suppressesIncrementalRendering = false
        
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 300, height: 500), configuration: configuration)
        webView.isOpaque = true
        webView.backgroundColor = .white
        webView.scrollView.backgroundColor = .white
        webView.navigationDelegate = context.coordinator
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // Load content when it becomes available
        if !htmlContent.isEmpty && webView.url == nil {
            #if DEBUG
            print("📖 [HTMLManualView] Loading HTML into WebView, length: \(htmlContent.count)")
            #endif
            webView.loadHTMLString(htmlContent, baseURL: nil)
        }
    }
    
    /// Coordinator to handle WKWebView navigation delegate
    class Coordinator: NSObject, WKNavigationDelegate {
        
        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }
            
            // Handle anchor links (scroll within document)
            if url.fragment != nil && (url.scheme == nil || url.scheme == "file" || url.scheme == "about") {
                // Allow in-page anchor navigation
                decisionHandler(.allow)
                return
            }
            
            // Handle external links - open in Safari
            if let scheme = url.scheme, (scheme == "http" || scheme == "https") {
                #if os(iOS)
                UIApplication.shared.open(url)
                #elseif os(macOS)
                NSWorkspace.shared.open(url)
                #endif
                decisionHandler(.cancel)
                return
            }
            
            // Allow local/about navigation
            decisionHandler(.allow)
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            #if DEBUG
            print("📖 [HTMLManualView] Started loading")
            #endif
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            #if DEBUG
            print("📖 [HTMLManualView] Finished loading")
            #endif
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            #if DEBUG
            print("❌ [HTMLManualView] Navigation failed: \(error)")
            #endif
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            #if DEBUG
            print("❌ [HTMLManualView] Provisional navigation failed: \(error)")
            #endif
        }
    }
}
