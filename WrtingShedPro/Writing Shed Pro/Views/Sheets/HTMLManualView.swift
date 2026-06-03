//
//  HTMLManualView.swift
//  Writing Shed Pro
//
//  Feature 027: WSP Manual
//  Displays the HTML guide using split section files for instant loading.
//  Uses native AttributedString rendering (no WKWebView) for zero-delay display.
//  Help button shows TOC (guide_00-toc.html), Learn More shows a section file directly.
//  Clicking a TOC entry or internal link loads the corresponding section file.
//  Each section has a "← Contents" link back to the TOC.
//

import SwiftUI

/// View for displaying the bundled HTML guide.
///
/// When `section` is nil (Help button), loads the table of contents.
/// When `section` is provided (Learn More), loads that section's file directly.
struct HTMLManualView: View {
    @Environment(\.dismiss) private var dismiss
    private let guideSubdirectory = "User Guide"
    
    /// Optional section to open directly (e.g. "22-creating-your-first-project")
    var section: String? = nil
    
    /// Current section being displayed — drives navigation between sections
    @State private var currentSection: String
    
    /// Rendered attributed string for the current section
    @State private var attributedContent: AttributedString = AttributedString()
    @State private var showAskQuestion = false
    @State private var selectedTutorialVideo: TutorialVideo?
    
    init(section: String? = nil) {
        self.section = section
        self._currentSection = State(initialValue: section ?? "00-toc")
    }
    
    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Invisible anchor at the top for scrolling
                        Color.clear.frame(height: 0).id("top")
                        
                        // Back to Contents link for non-TOC sections
                        if currentSection != "00-toc" {
                            HStack {
                                Button {
                                    currentSection = "00-toc"
                                } label: {
                                    Label("Contents", systemImage: "chevron.left")
                                        .font(.subheadline)
                                }
                                Spacer()
                            }
                            .padding(.horizontal)
                            .padding(.top, 8)
                        }
                        
                        Text(attributedContent)
                            .textSelection(.enabled)
                            .padding(.horizontal)
                            .padding(.bottom, 40)
                            .environment(\.openURL, OpenURLAction { url in
                                // Handle guide: links for internal navigation
                                if url.scheme == "guide" {
                                    let sectionId = url.absoluteString
                                        .replacingOccurrences(of: "guide:", with: "")
                                        .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                                    currentSection = sectionId
                                    return .handled
                                }
                                if url.scheme == "wspvideo" {
                                    let rawID = url.absoluteString
                                        .replacingOccurrences(of: "wspvideo:", with: "")
                                        .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                                    if let tutorial = TutorialVideoCatalog.video(for: rawID) {
                                        selectedTutorialVideo = tutorial
                                        return .handled
                                    }
                                }
                                // External links open in Safari
                                return .systemAction
                            })
                    }
                }
                .background(Color(.systemBackground))
                .onChange(of: currentSection) { _, newSection in
                    loadSection(newSection)
                    // Scroll to top after loading the new section content
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        withAnimation {
                            proxy.scrollTo("top", anchor: .top)
                        }
                    }
                }
            }
            .navigationTitle("Writing Shed Pro Guide")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showAskQuestion = true
                    }
                    label: {
                        Text("Ask a question")
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showAskQuestion) {
                ContactSupportView(initialReportType: .question, presentationMode: .questionOnly)
            }
            .fullScreenCover(item: $selectedTutorialVideo) { tutorial in
                TutorialVideoPlayerSheet(video: tutorial)
            }
            .onAppear {
                loadSection(currentSection)
            }
        }
    }
    
    /// Load and render an HTML section file as AttributedString
    private func loadSection(_ sectionId: String) {
        let resourceName = "guide_\(sectionId)"

        let sectionURL = Bundle.main.url(
            forResource: resourceName,
            withExtension: "html",
            subdirectory: guideSubdirectory
        ) ?? Bundle.main.url(forResource: resourceName, withExtension: "html")

        guard let url = sectionURL,
              var html = try? String(contentsOf: url, encoding: .utf8) else {
            #if DEBUG
            print("❌ [Guide] Section file not found: \(resourceName).html")
            #endif
            attributedContent = AttributedString("Section not found: \(sectionId)")
            return
        }
        
        #if DEBUG
        print("📖 [Guide] Loading section: \(resourceName).html")
        #endif
        
        // Remove the HTML "← Contents" link (the native SwiftUI button handles this)
        html = html.replacingOccurrences(
            of: "<p class=\"back-nav\"><a href=\"guide:00-toc\">← Contents</a></p>",
            with: ""
        )
        
        // Strip background/color declarations from CSS so NSAttributedString doesn't
        // bake them into the attributed string (which bleeds into the navigation bar).
        // SwiftUI handles light/dark mode natively via the system label color.
        // Use regex to remove background: and color: declarations from the CSS.
        html = html.replacingOccurrences(
            of: "background:\\s*#[0-9a-fA-F]+;?",
            with: "",
            options: .regularExpression
        )
        html = html.replacingOccurrences(
            of: "(?<!-)color:\\s*#[0-9a-fA-F]+;?",
            with: "",
            options: .regularExpression
        )
        
        // Inject CSS overrides for NSAttributedString rendering.
        // Don't set color/background here — NSAttributedString doesn't support
        // system color tokens. We post-process colors after parsing instead.
        let cssOverrides = """
        <style>
        body {
            font: -apple-system-body;
            font-size: 17px;
            margin: 0;
            padding: 0;
        }
        </style>
        """
        html = html.replacingOccurrences(of: "</head>", with: cssOverrides + "</head>")
        
        // NSAttributedString's HTML parser ignores margin-top on headings,
        // so inject explicit spacing before h2/h3 tags for visual separation
        html = html.replacingOccurrences(of: "<h2", with: "<br><br><h2")
        html = html.replacingOccurrences(of: "<h3", with: "<br><h3")
        // Don't double-space if h2/h3 is the very first element after body
        html = html.replacingOccurrences(of: "<body>\n<br><br><h2", with: "<body>\n<h2")
        html = html.replacingOccurrences(of: "<body>\n<br><h3", with: "<body>\n<h3")
        
        guard let data = html.data(using: .utf8) else {
            attributedContent = AttributedString("Failed to encode section.")
            return
        }
        
        // Parse HTML into NSAttributedString, then convert to SwiftUI AttributedString
        if let nsAttr = try? NSAttributedString(
            data: data,
            options: [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue
            ],
            documentAttributes: nil
        ) {
            // Post-process: replace hard-coded CSS colors with system-adaptive colors
            // so the guide renders correctly in both light and dark mode.
            let mutable = NSMutableAttributedString(attributedString: nsAttr)
            let fullRange = NSRange(location: 0, length: mutable.length)
            
            // Replace all foreground colors with .label (adapts to light/dark)
            // but preserve link colors (blue)
            mutable.enumerateAttribute(.foregroundColor, in: fullRange, options: []) { value, range, _ in
                if value is UIColor {
                    // Check if this is a link by looking for the .link attribute
                    let hasLink = mutable.attribute(.link, at: range.location, effectiveRange: nil) != nil
                    if hasLink {
                        mutable.addAttribute(.foregroundColor, value: UIColor.link, range: range)
                    } else {
                        mutable.addAttribute(.foregroundColor, value: UIColor.label, range: range)
                    }
                }
            }
            
            // Remove all background colors (prevents nav bar bleed-through)
            mutable.removeAttribute(.backgroundColor, range: fullRange)
            
            // Ensure all links are explicitly blue (Catalyst may not apply link color automatically
            // after CSS color stripping)
            mutable.enumerateAttribute(.link, in: fullRange, options: []) { value, range, _ in
                if value != nil {
                    mutable.addAttribute(.foregroundColor, value: UIColor.link, range: range)
                }
            }
            
            attributedContent = AttributedString(mutable)
        } else {
            attributedContent = AttributedString("Failed to render section.")
        }
    }
}
