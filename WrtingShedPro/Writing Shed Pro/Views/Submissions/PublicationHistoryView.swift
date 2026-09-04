import SwiftUI
import SwiftData
import UIKit

struct PublicationHistoryView: View {
    private struct HistoryEntry: Identifiable {
        let submittedFile: SubmittedFile
        let submission: Submission
        let publication: Publication

        var id: UUID { submittedFile.id }
    }

    @Query private var allSubmittedFiles: [SubmittedFile]
    @Query private var allSubmissions: [Submission]
    @Query private var allPublications: [Publication]

    let project: Project

    @State private var selectedSubmission: Submission?
    @State private var printErrorMessage = ""
    @State private var showPrintError = false
    @State private var upgradePromptReason: UpgradePromptReason?

    private let nameWidth: CGFloat = 180
    private let dateWidth: CGFloat = 120
    private let typeWidth: CGFloat = 140
    private let publicationWidth: CGFloat = 180
    private let statusWidth: CGFloat = 150

    private var historyEntries: [HistoryEntry] {
        var submittedFilesByID = Dictionary(
            uniqueKeysWithValues: allSubmittedFiles.map { ($0.id, $0) }
        )
        for submittedFile in project.submittedFiles ?? [] {
            submittedFilesByID[submittedFile.id] = submittedFile
        }

        return submittedFilesByID.values.compactMap { submittedFile in
            guard let linkedSubmission = submittedFile.submission else { return nil }
            let submission = allSubmissions.first { $0.id == linkedSubmission.id } ?? linkedSubmission
            guard !submission.isCollection else { return nil }
            guard submission.projectId == project.id
                    || submission.project?.id == project.id
                    || submittedFile.project?.id == project.id else { return nil }
            guard let linkedPublication = submission.publication else { return nil }
            let publication = allPublications.first { $0.id == linkedPublication.id } ?? linkedPublication
            return HistoryEntry(
                submittedFile: submittedFile,
                submission: submission,
                publication: publication
            )
        }
        .sorted { lhs, rhs in
            if lhs.submission.submittedDate != rhs.submission.submittedDate {
                return lhs.submission.submittedDate > rhs.submission.submittedDate
            }
            return (lhs.submittedFile.textFile?.name ?? "")
                .localizedCaseInsensitiveCompare(rhs.submittedFile.textFile?.name ?? "") == .orderedAscending
        }
    }

    var body: some View {
        Group {
            if historyEntries.isEmpty {
                ContentUnavailableView {
                    Label(
                        NSLocalizedString("publicationHistory.emptyTitle", comment: "No publication history title"),
                        systemImage: "clock.arrow.circlepath"
                    )
                } description: {
                    Text(NSLocalizedString("publicationHistory.emptyMessage", comment: "No publication history message"))
                }
            } else {
                historyTable
            }
        }
        .navigationTitle(NSLocalizedString("publicationHistory.title", comment: "Publication History title"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedSubmission) { submission in
            SubmissionDetailView(submission: submission)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: printHistory) {
                    Label(NSLocalizedString("button.print", comment: "Print"), systemImage: "printer")
                }
                .disabled(historyEntries.isEmpty || !PrintService.isPrintingAvailable())
            }
        }
        .alert(NSLocalizedString("publicationHistory.printErrorTitle", comment: "Print error title"), isPresented: $showPrintError) {
            Button(NSLocalizedString("button.ok", comment: "OK"), role: .cancel) { }
        } message: {
            Text(printErrorMessage)
        }
        .upgradePrompt(reason: $upgradePromptReason)
    }

    private var historyTable: some View {
        ScrollView([.horizontal, .vertical]) {
            Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
                GridRow {
                    headerCell("publicationHistory.column.name", width: nameWidth)
                    headerCell("publicationHistory.column.submittedDate", width: dateWidth)
                    headerCell("publicationHistory.column.publicationType", width: typeWidth)
                    headerCell("publicationHistory.column.publicationName", width: publicationWidth)
                    headerCell("publicationHistory.column.status", width: statusWidth)
                }

                Divider().gridCellColumns(5)

                ForEach(Array(historyEntries.enumerated()), id: \.element.id) { index, entry in
                    GridRow {
                        textCell(entry.submittedFile.textFile?.name ?? "", width: nameWidth)
                        textCell(
                            entry.submission.submittedDate.formatted(date: .abbreviated, time: .omitted),
                            width: dateWidth
                        )
                        textCell(entry.publication.publicationType?.displayName ?? "", width: typeWidth)
                        textCell(entry.publication.name, width: publicationWidth)
                        statusCell(entry.submittedFile.submissionStatus ?? .pending)
                    }
                    .background(index.isMultiple(of: 2) ? Color.clear : Color.secondary.opacity(0.06))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedSubmission = entry.submission
                    }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel(accessibilityLabel(for: entry))
                    .accessibilityAction {
                        selectedSubmission = entry.submission
                    }

                    Divider().gridCellColumns(5)
                }
            }
            .overlay {
                Rectangle()
                    .stroke(Color.secondary.opacity(0.45), lineWidth: 1)
            }
            .background {
                DirectionalScrollLockConfigurator(
                    isEnabled: shouldLockScrollDirection
                )
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
    }

    private func headerCell(_ key: String, width: CGFloat) -> some View {
        Text(NSLocalizedString(key, comment: "Publication history column heading"))
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(width: width, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 12)
    }

    private func textCell(_ text: String, width: CGFloat) -> some View {
        Text(text)
            .lineLimit(2)
            .frame(width: width, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 12)
    }

    private func statusCell(_ status: SubmissionStatus) -> some View {
        Group {
            if status == .pending {
                Label(historyDisplayName(for: status), systemImage: "clock.fill")
            } else {
                Text(historyDisplayName(for: status))
            }
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(status.color)
        .frame(width: statusWidth, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 12)
    }

    private func accessibilityLabel(for entry: HistoryEntry) -> String {
        let fileName = entry.submittedFile.textFile?.name ?? ""
        let date = entry.submission.submittedDate.formatted(date: .long, time: .omitted)
        let type = entry.publication.publicationType?.displayName ?? ""
        let status = historyDisplayName(for: entry.submittedFile.submissionStatus ?? .pending)
        return "\(fileName), \(date), \(type), \(entry.publication.name), \(status)"
    }

    private func historyDisplayName(for status: SubmissionStatus) -> String {
        if status == .pending {
            return NSLocalizedString("publicationHistory.status.waiting", comment: "Waiting")
        }
        return status.displayName
    }

    private var shouldLockScrollDirection: Bool {
        #if targetEnvironment(macCatalyst)
        return true
        #else
        return UIDevice.current.userInterfaceIdiom == .phone
        #endif
    }

    private func printHistory() {
        guard EntitlementManager.shared.canPrint(projectType: project.type) else {
            upgradePromptReason = .printBlocked(projectType: project.type)
            return
        }

        guard UIPrintInteractionController.isPrintingAvailable else {
            printErrorMessage = NSLocalizedString("print.error.notAvailable", comment: "Printing is not available")
            showPrintError = true
            return
        }

        let printInfo = UIPrintInfo.printInfo()
        printInfo.jobName = String(
            format: NSLocalizedString("publicationHistory.printJobName", comment: "Publication history print job name"),
            project.name ?? ""
        )
        printInfo.outputType = .general
        printInfo.orientation = .landscape

        let printController = UIPrintInteractionController.shared
        printController.printInfo = printInfo
        let formatter = UIMarkupTextPrintFormatter(markupText: printableHTML)
        formatter.perPageContentInsets = UIEdgeInsets(top: 36, left: 36, bottom: 36, right: 36)
        printController.printFormatter = formatter
        printController.present(animated: true) { _, _, error in
            if let error {
                printErrorMessage = error.localizedDescription
                showPrintError = true
            }
        }
    }

    private var printableHTML: String {
        let projectName = escapedHTML(project.name ?? "")
        let title = escapedHTML(NSLocalizedString("publicationHistory.title", comment: "Publication History title"))
        let headings = [
            "publicationHistory.column.name",
            "publicationHistory.column.submittedDate",
            "publicationHistory.column.publicationType",
            "publicationHistory.column.publicationName",
            "publicationHistory.column.status"
        ].map { escapedHTML(NSLocalizedString($0, comment: "Publication history column heading")) }

        let rows = historyEntries.map { entry in
            let values = [
                entry.submittedFile.textFile?.name ?? "",
                entry.submission.submittedDate.formatted(date: .abbreviated, time: .omitted),
                entry.publication.publicationType?.displayName ?? "",
                entry.publication.name,
                historyDisplayName(for: entry.submittedFile.submissionStatus ?? .pending)
            ]
            return "<tr>\(values.map { "<td>\(escapedHTML($0))</td>" }.joined())</tr>"
        }.joined()

        return """
        <html><head><style>
        body { font-family: -apple-system, sans-serif; font-size: 10pt; }
        h1 { font-size: 18pt; margin-bottom: 2pt; }
        h2 { font-size: 11pt; font-weight: normal; margin-top: 0; color: #555; }
        table { width: 100%; border-collapse: collapse; margin-top: 18pt; }
        th, td { border: 1px solid #777; padding: 6pt; text-align: left; vertical-align: top; }
        th { background: #eee; font-weight: 600; }
        </style></head><body>
        <h1>\(title)</h1><h2>\(projectName)</h2>
        <table><thead><tr>\(headings.map { "<th>\($0)</th>" }.joined())</tr></thead>
        <tbody>\(rows)</tbody></table>
        </body></html>
        """
    }

    private func escapedHTML(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}

private struct DirectionalScrollLockConfigurator: UIViewRepresentable {
    let isEnabled: Bool

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        configureEnclosingScrollView(from: view)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        configureEnclosingScrollView(from: uiView)
    }

    private func configureEnclosingScrollView(from view: UIView) {
        DispatchQueue.main.async {
            var ancestor = view.superview
            while let current = ancestor {
                if let scrollView = current as? UIScrollView {
                    scrollView.isDirectionalLockEnabled = isEnabled
                    return
                }
                ancestor = current.superview
            }
        }
    }
}