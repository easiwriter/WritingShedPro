import SwiftUI
import SwiftData
import UniformTypeIdentifiers


/// View displaying assembled manuscript content.
/// Uses the shared manuscript assembly pipeline (front + body + back matter).
struct ManuscriptBodyView: View {
    let project: Project
    @Environment(\.modelContext) private var context
    
    @State private var assemblyService: ManuscriptAssemblyService?
    @State private var sections: [ManuscriptSection] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var frontMatterPageCount: Int = 0
    /// Pre-assembled text file — built off the main thread so the view appears instantly
    @State private var assembledTextFile: TextFile?
    @State private var headingWarnings: [String] = []
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView(NSLocalizedString("manuscript.progress.assembling", comment: "Assembling..."))
            } else if let error = errorMessage {
                ContentUnavailableView {
                    Label("manuscript.error.assemblyFailed", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                }
            } else if sections.isEmpty {
                ContentUnavailableView {
                    Label("manuscript.body.empty", systemImage: "doc.on.doc")
                } description: {
                    Text("manuscript.body.emptyDescription")
                }
            } else {
                bodyContent
            }
        }
        .navigationTitle("Manuscript")

        .task {
            await loadBodySections()
        }
    }
    
    @ViewBuilder
    private var bodyContent: some View {
        if let textFile = assembledTextFile {
            VStack(spacing: 0) {
                if !headingWarnings.isEmpty {
                    manuscriptHeadingWarning
                }

                PaginatedDocumentView(
                    textFile: textFile,
                    project: project,
                    showActualPageNumbers: true,
                    startingPageNumber: frontMatterPageCount + 1,
                    showPrintButton: false
                )
            }
        } else {
            ContentUnavailableView {
                Label("manuscript.body.empty", systemImage: "doc.on.doc")
            } description: {
                Text("manuscript.body.emptyDescription")
            }
        }
    }

    private var manuscriptHeadingWarning: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 4) {
                Text(NSLocalizedString("manuscript.warning.missingHeadings.title", comment: "Missing manuscript headings warning title"))
                    .font(.subheadline.weight(.semibold))
                Text(headingWarnings.joined(separator: "\n"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private func loadBodySections() async {
        errorMessage = nil
        let service = ManuscriptAssemblyService(context: context)
        assemblyService = service
        do {
            // Use the same assembly path as manuscript export/preview for consistent behavior.
            let content = try await service.assembleContent(for: project)
            sections = content.sections
            headingWarnings = missingHeadingWarnings(in: content.sections)

            guard content.attributedString.length > 0 else {
                isLoading = false
                return
            }

            let tf = TextFile(name: project.name ?? "Manuscript")
            if let version = tf.versions?.first {
                version.attributedContent = content.attributedString
            }
            assembledTextFile = tf

            // Full manuscript now starts at page 1.
            frontMatterPageCount = 0

            #if DEBUG
            print("📄 [ManuscriptBodyView] Full assembly complete. sections: \(sections.count), length: \(content.attributedString.length)")
            #endif
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    private func missingHeadingWarnings(in sections: [ManuscriptSection]) -> [String] {
        guard project.type == .prose else { return [] }

        let settings = project.manuscriptSettings
        guard settings.includeSectionHeadings || settings.includeFileTitles else { return [] }

        var missingSectionHeadings: [String] = []
        var missingFileTitles: [String] = []

        for section in sections where section.sectionType == .body {
            if settings.includeSectionHeadings,
               !section.files.contains(where: { fileContainsStyledHeading($0, matching: section.title) }) {
                missingSectionHeadings.append(section.title)
            }

            if settings.includeFileTitles {
                for file in section.files where !fileContainsStyledHeading(file, matching: file.name) {
                    missingFileTitles.append(file.name)
                }
            }
        }

        var warnings: [String] = []
        if !missingSectionHeadings.isEmpty {
            let names = missingSectionHeadings.prefix(3).joined(separator: ", ")
            warnings.append(String(format: NSLocalizedString("manuscript.warning.missingSectionHeadings", comment: "Missing manuscript section headings warning"), names))
        }
        if !missingFileTitles.isEmpty {
            let names = missingFileTitles.prefix(3).joined(separator: ", ")
            warnings.append(String(format: NSLocalizedString("manuscript.warning.missingFileTitles", comment: "Missing manuscript file title headings warning"), names))
        }

        return warnings
    }

    private func fileContainsStyledHeading(_ file: TextFile, matching expectedTitle: String) -> Bool {
        guard let content = file.currentVersion?.attributedContent else { return false }
        let expected = normalizedHeadingText(expectedTitle)
        guard !expected.isEmpty else { return false }

        let string = content.string as NSString
        var location = 0
        while location < string.length {
            let paragraphRange = string.paragraphRange(for: NSRange(location: location, length: 0))
            let paragraph = string.substring(with: paragraphRange)
            if normalizedHeadingText(paragraph) == expected,
               paragraphHasHeadingStyle(in: content, range: paragraphRange) {
                return true
            }
            location = NSMaxRange(paragraphRange)
        }

        return false
    }

    private func paragraphHasHeadingStyle(in content: NSAttributedString, range: NSRange) -> Bool {
        let headingStyles: Set<String> = [
            UIFont.TextStyle.largeTitle.rawValue,
            UIFont.TextStyle.title1.rawValue,
            UIFont.TextStyle.title2.rawValue,
            UIFont.TextStyle.title3.rawValue,
            UIFont.TextStyle.headline.rawValue,
            "UICTFontTextStyleTitle0"
        ]

        var hasHeadingStyle = false
        content.enumerateAttribute(.textStyle, in: range, options: []) { value, _, stop in
            if let style = value as? String, headingStyles.contains(style) {
                hasHeadingStyle = true
                stop.pointee = true
            }
        }
        return hasHeadingStyle
    }

    private func normalizedHeadingText(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"^\d+(?:\.\d+)*(?:\.)?\s*"#, with: "", options: .regularExpression)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
    
}
