//
//  MarkdownPreviewView.swift
//  Writing Shed Pro
//
//  Markdown preview and validation view for markdown files
//

import SwiftUI
import SwiftData

/// View for previewing and validating markdown content
/// Shows rendered markdown with syntax error highlighting
struct MarkdownPreviewView: View {
    
    // MARK: - Properties
    
    /// The raw markdown content to preview
    let markdownContent: String
    
    /// Optional stylesheet for styling the preview
    let styleSheet: StyleSheet?
    
    /// File name for display
    let fileName: String
    
    // MARK: - Environment
    
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - State
    
    @State private var renderedContent: NSAttributedString?
    @State private var validationErrors: [MarkdownValidationError] = []
    @State private var isLoading = true
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Validation status bar
                if !validationErrors.isEmpty {
                    validationStatusBar
                }
                
                // Preview content - using scrolling text view that fills the space
                if isLoading {
                    ProgressView(NSLocalizedString("markdown.preview.loading", comment: "Loading preview..."))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let content = renderedContent {
                    ScrollingAttributedTextView(attributedText: content)
                } else {
                    ContentUnavailableView(
                        NSLocalizedString("markdown.preview.empty", comment: "No Content"),
                        systemImage: "doc.text",
                        description: Text(NSLocalizedString("markdown.preview.emptyDescription", comment: "The markdown content is empty"))
                    )
                }
            }
            .navigationTitle(NSLocalizedString("markdown.preview.title", comment: "Markdown Preview"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("button.done", comment: "Done")) {
                        dismiss()
                    }
                }
            }
            .task {
                await renderMarkdown()
            }
        }
    }
    
    // MARK: - Subviews
    
    private var validationStatusBar: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text(String(format: NSLocalizedString("markdown.preview.issuesFound", comment: "%d issues found"), validationErrors.count))
                .font(.subheadline)
            Spacer()
            Button {
                // Show validation details
            } label: {
                Text(NSLocalizedString("markdown.preview.showIssues", comment: "Show"))
                    .font(.subheadline)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.1))
    }
    
    // MARK: - Methods
    
    private func renderMarkdown() async {
        isLoading = true
        
        // Validate markdown
        validationErrors = MarkdownValidator.validate(markdownContent)
        
        // Render markdown to attributed string
        do {
            let rendered = try MarkdownImportService.importMarkdown(from: markdownContent, styleSheet: styleSheet)
            await MainActor.run {
                renderedContent = rendered
                isLoading = false
            }
        } catch {
            await MainActor.run {
                renderedContent = nil
                isLoading = false
            }
            #if DEBUG
            print("❌ Markdown render error: \(error)")
            #endif
        }
    }
}

// MARK: - Markdown Validation

/// Errors found during markdown validation
struct MarkdownValidationError: Identifiable {
    let id = UUID()
    let line: Int
    let message: String
    let severity: Severity
    
    enum Severity {
        case warning
        case error
    }
}

/// Validator for checking common markdown issues
struct MarkdownValidator {
    
    static func validate(_ content: String) -> [MarkdownValidationError] {
        var errors: [MarkdownValidationError] = []
        let lines = content.components(separatedBy: .newlines)
        
        var inCodeBlock = false
        var codeBlockStartLine = 0
        
        for (index, line) in lines.enumerated() {
            let lineNumber = index + 1
            
            // Track code blocks
            if line.hasPrefix("```") {
                if inCodeBlock {
                    inCodeBlock = false
                } else {
                    inCodeBlock = true
                    codeBlockStartLine = lineNumber
                }
                continue
            }
            
            // Skip validation inside code blocks
            if inCodeBlock { continue }
            
            // Check for unclosed inline code
            let backtickCount = line.filter { $0 == "`" }.count
            if backtickCount % 2 != 0 {
                errors.append(MarkdownValidationError(
                    line: lineNumber,
                    message: NSLocalizedString("markdown.validation.unclosedCode", comment: "Unclosed inline code"),
                    severity: .warning
                ))
            }
            
            // Check for unclosed bold/italic
            let asteriskCount = line.components(separatedBy: "**").count - 1
            if asteriskCount % 2 != 0 {
                errors.append(MarkdownValidationError(
                    line: lineNumber,
                    message: NSLocalizedString("markdown.validation.unclosedBold", comment: "Unclosed bold text"),
                    severity: .warning
                ))
            }
            
            // Check for heading without space after #
            if line.hasPrefix("#") && !line.hasPrefix("# ") && !line.hasPrefix("##") {
                let hashCount = line.prefix(while: { $0 == "#" }).count
                let afterHashes = line.dropFirst(hashCount)
                if !afterHashes.isEmpty && !afterHashes.hasPrefix(" ") {
                    errors.append(MarkdownValidationError(
                        line: lineNumber,
                        message: NSLocalizedString("markdown.validation.headingSpace", comment: "Heading should have space after #"),
                        severity: .warning
                    ))
                }
            }
            
            // Check for broken links
            let linkPattern = #"\[([^\]]*)\]\(([^\)]*)\)"#
            if let regex = try? NSRegularExpression(pattern: linkPattern) {
                let range = NSRange(line.startIndex..., in: line)
                let matches = regex.matches(in: line, range: range)
                for match in matches {
                    if match.numberOfRanges >= 3 {
                        let urlRange = Range(match.range(at: 2), in: line)
                        if let urlRange = urlRange {
                            let url = String(line[urlRange])
                            if url.isEmpty {
                                errors.append(MarkdownValidationError(
                                    line: lineNumber,
                                    message: NSLocalizedString("markdown.validation.emptyLink", comment: "Empty link URL"),
                                    severity: .error
                                ))
                            }
                        }
                    }
                }
            }
        }
        
        // Check for unclosed code block at end of document
        if inCodeBlock {
            errors.append(MarkdownValidationError(
                line: codeBlockStartLine,
                message: NSLocalizedString("markdown.validation.unclosedCodeBlock", comment: "Unclosed code block"),
                severity: .error
            ))
        }
        
        return errors
    }
}

// MARK: - Markdown Attributed Text View

/// UIViewRepresentable wrapper for displaying attributed text with its own scrolling
/// This is the main preview view that handles its own scrolling (no SwiftUI ScrollView needed)
struct ScrollingAttributedTextView: UIViewRepresentable {
    let attributedText: NSAttributedString
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isScrollEnabled = true  // Handle our own scrolling
        textView.backgroundColor = .systemBackground
        textView.textContainerInset = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        textView.alwaysBounceVertical = true
        textView.showsVerticalScrollIndicator = true
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.attributedText = attributedText
        // Scroll to top when content changes
        uiView.setContentOffset(.zero, animated: false)
    }
}

/// UIViewRepresentable wrapper for displaying attributed text that sizes to fit content
/// For use inside a SwiftUI ScrollView (not currently used, kept for reference)
struct MarkdownAttributedTextView: UIViewRepresentable {
    let attributedText: NSAttributedString
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isScrollEnabled = false  // Let SwiftUI ScrollView handle scrolling
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.attributedText = attributedText
        
        // Force layout and size calculation
        uiView.invalidateIntrinsicContentSize()
    }
    
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let width = proposal.width ?? UIScreen.main.bounds.width
        let size = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: size.height)
    }
}
