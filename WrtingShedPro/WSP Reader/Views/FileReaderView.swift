//
//  FileReaderView.swift
//  WSP Reader
//
//  Displays the content of a single file with formatting.
//  Feature 026: WSP Reader App
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct FileReaderView: View {
    let file: WSPReaderFile
    let fontSize: CGFloat
    var onNavigateToFile: ((String) -> Void)? = nil
    
    @State private var showFootnotes: Bool = false
    @State private var showComments: Bool = false
    @State private var showVersionInfo: Bool = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // File header
                fileHeader
                
                Divider()
                
                // Main content
                AttributedTextView(
                    attributedString: scaledContent,
                    fontSize: fontSize,
                    onLinkTap: handleLinkTap
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Footnotes section
                if !footnotes.isEmpty {
                    footnotesSection
                }
                
                Spacer(minLength: 40)
            }
            .padding()
            .frame(maxWidth: 700, alignment: .leading)
        }
        .background(readerBackground)
        .navigationTitle(file.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItemGroup(placement: .secondaryAction) {
                if !footnotes.isEmpty {
                    Button {
                        showFootnotes.toggle()
                    } label: {
                        Label("Footnotes", systemImage: "note.text")
                    }
                }
                
                if !comments.isEmpty {
                    Button {
                        showComments.toggle()
                    } label: {
                        Label("Comments", systemImage: "text.bubble")
                    }
                }
                
                if file.versions.count > 1 {
                    Button {
                        showVersionInfo.toggle()
                    } label: {
                        Label("Version Info", systemImage: "clock.arrow.circlepath")
                    }
                }
            }
        }
        .sheet(isPresented: $showFootnotes) {
            FootnotesSheet(footnotes: footnotes)
        }
        .sheet(isPresented: $showComments) {
            CommentsSheet(comments: comments)
        }
        .sheet(isPresented: $showVersionInfo) {
            VersionInfoSheet(file: file)
        }
    }
    
    // MARK: - File Header
    
    @ViewBuilder
    private var fileHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(file.name)
                .font(.title)
                .fontWeight(.bold)
            
            HStack(spacing: 16) {
                Label("\(file.wordCount) words", systemImage: "text.word.spacing")
                
                if let form = file.poetryFormName {
                    Label(form, systemImage: "text.quote")
                }
                
                if let status = file.workflowStatus {
                    Label(status.capitalized, systemImage: "checkmark.circle")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            
            Text("Modified \(formattedDate(file.modifiedDate))")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
    
    // MARK: - Footnotes Section
    
    @ViewBuilder
    private var footnotesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            
            Text("Footnotes")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            ForEach(footnotes) { footnote in
                HStack(alignment: .top, spacing: 8) {
                    Text("\(footnote.number).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 24, alignment: .trailing)
                    
                    Text(footnote.text)
                        .font(.footnote)
                }
            }
        }
        .padding(.top, 16)
    }
    
    // MARK: - Helpers
    
    private var scaledContent: NSAttributedString {
        let original = file.attributedContent
        let mutable = NSMutableAttributedString(attributedString: original)
        
        // Scale fonts to match user preference
        mutable.enumerateAttribute(.font, in: NSRange(location: 0, length: mutable.length)) { value, range, _ in
            #if canImport(UIKit)
            if let font = value as? UIFont {
                let scaleFactor = fontSize / 16.0
                let newSize = font.pointSize * scaleFactor
                let newFont = font.withSize(newSize)
                mutable.addAttribute(.font, value: newFont, range: range)
            }
            #elseif canImport(AppKit)
            if let font = value as? NSFont {
                let scaleFactor = fontSize / 16.0
                let newSize = font.pointSize * scaleFactor
                let newFont = NSFont(descriptor: font.fontDescriptor, size: newSize) ?? NSFont.systemFont(ofSize: newSize)
                mutable.addAttribute(.font, value: newFont, range: range)
            }
            #endif
        }
        
        return mutable
    }

    private var readerBackground: Color {
        #if canImport(UIKit)
        return Color(uiColor: .systemBackground)
        #elseif canImport(AppKit)
        return Color(nsColor: .textBackgroundColor)
        #else
        return Color.background
        #endif
    }
    
    private var footnotes: [WSPReaderFootnote] {
        file.currentVersion?.footnotes ?? []
    }
    
    private var comments: [WSPReaderComment] {
        file.currentVersion?.comments ?? []
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // MARK: - Link Handling
    
    private func handleLinkTap(_ url: URL) -> Bool {
        // Check for internal wsp:// links
        if url.scheme == "wsp" {
            // Parse wsp://file/{fileId} format
            let fileId = url.lastPathComponent
            onNavigateToFile?(fileId)
            return true
        }
        
        // Check for file-reference links (from References feature)
        if url.absoluteString.contains("file-reference:") {
            let fileId = url.absoluteString.replacingOccurrences(of: "file-reference:", with: "")
            onNavigateToFile?(fileId)
            return true
        }
        
        // External links - let system handle
        return false
    }
}

// MARK: - Attributed Text View

struct AttributedTextView: View {
    let attributedString: NSAttributedString
    let fontSize: CGFloat
    var onLinkTap: ((URL) -> Bool)? = nil

    var body: some View {
        #if canImport(UIKit)
        UIKitAttributedTextView(attributedString: attributedString, onLinkTap: onLinkTap)
            .frame(maxWidth: .infinity, alignment: .leading)
        #else
        Text(attributedString.string)
            .font(.system(size: fontSize))
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
        #endif
    }
}

#if canImport(UIKit)
private struct UIKitAttributedTextView: UIViewRepresentable {
    let attributedString: NSAttributedString
    var onLinkTap: ((URL) -> Bool)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(onLinkTap: onLinkTap)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.dataDetectorTypes = [.link]
        textView.delegate = context.coordinator
        textView.linkTextAttributes = [
            .foregroundColor: UIColor.systemBrown,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        textView.attributedText = attributedString
        context.coordinator.onLinkTap = onLinkTap
    }

    class Coordinator: NSObject, UITextViewDelegate {
        var onLinkTap: ((URL) -> Bool)?

        init(onLinkTap: ((URL) -> Bool)?) {
            self.onLinkTap = onLinkTap
        }

        func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange) -> Bool {
            if let handler = onLinkTap {
                return !handler(URL)
            }
            return true
        }
    }
}
#endif

// MARK: - Footnotes Sheet

struct FootnotesSheet: View {
    let footnotes: [WSPReaderFootnote]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List(footnotes) { footnote in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(footnote.number)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                        .frame(width: 30, alignment: .trailing)
                    
                    Text(footnote.text)
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("Footnotes")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Comments Sheet

struct CommentsSheet: View {
    let comments: [WSPReaderComment]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List(comments) { comment in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(comment.author)
                            .font(.caption)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Text(formattedDate(comment.createdAt))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    
                    Text(comment.text)
                        .font(.body)
                    
                    if comment.isResolved {
                        Label("Resolved", systemImage: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("Comments")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Version Info Sheet

struct VersionInfoSheet: View {
    let file: WSPReaderFile
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section("Current Version") {
                    if let version = file.currentVersion {
                        versionRow(version, isCurrent: true)
                    }
                }
                
                if file.versions.count > 1 {
                    Section("All Versions") {
                        ForEach(file.versions.reversed()) { version in
                            versionRow(version, isCurrent: version.id == file.currentVersion?.id)
                        }
                    }
                }
            }
            .navigationTitle("Version History")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    @ViewBuilder
    private func versionRow(_ version: WSPReaderVersion, isCurrent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Version \(version.versionNumber)")
                    .fontWeight(isCurrent ? .semibold : .regular)
                
                if isCurrent {
                    Text("Current")
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.blue)
                        .cornerRadius(4)
                }
            }
            
            Text(formattedDate(version.createdDate))
                .font(.caption)
                .foregroundStyle(.secondary)
            
            if let comment = version.comment, !comment.isEmpty {
                Text(comment)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .italic()
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    Text("File Reader Preview")
}
