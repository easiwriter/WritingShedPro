//
//  ContactSupportView.swift
//  Writing Shed Pro
//
//  Contact support form — bug reports & suggestions
//  Feature 019: Settings Menu
//  Feature 037: AI User Support — sends query to support service first
//

import SwiftUI
import MessageUI
import SwiftData

// MARK: - Mail Compose Representable

struct MailComposeView: UIViewControllerRepresentable {
    let recipients: [String]
    let subject: String
    let body: String
    var onDismiss: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onDismiss: onDismiss) }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.mailComposeDelegate = context.coordinator
        vc.setToRecipients(recipients)
        vc.setSubject(subject)
        vc.setMessageBody(body, isHTML: false)
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let onDismiss: () -> Void
        init(onDismiss: @escaping () -> Void) { self.onDismiss = onDismiss }
        func mailComposeController(_ controller: MFMailComposeViewController,
                                   didFinishWith result: MFMailComposeResult,
                                   error: Error?) {
            controller.dismiss(animated: true) { self.onDismiss() }
        }
    }
}

// MARK: - Contact Support View

struct ContactSupportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    enum PresentationMode {
        case full
        case questionOnly
    }

    enum ReportType: String, CaseIterable, Identifiable {
        case bug = "Bug Report"
        case suggestion = "Suggestion"
        case question = "Question"
        var id: String { rawValue }
    }

    @State private var reportType: ReportType
    @State private var subject: String = ""
    @State private var details: String = ""
    @State private var stepsToReproduce: String = ""
    @State private var notARobot: Bool = false

    @State private var showMailCompose = false
    @State private var showMailUnavailable = false
    @State private var showRobotAlert = false
    @State private var showValidationAlert = false
    @State private var validationMessage = ""
    @State private var showSupportResponse = false
    @State private var includeSyncDiagnostics = true
    @State private var diagnosticsSnapshot = ""

    // Robot-check: simple arithmetic challenge
    @State private var challengeA: Int = Int.random(in: 2...9)
    @State private var challengeB: Int = Int.random(in: 2...9)
    @State private var challengeAnswer: String = ""

    @State private var supportService = SupportService()
    private let presentationMode: PresentationMode

    private let supportEmail = "easiwriter@writing-shed.com"

    init(
        initialReportType: ReportType = .bug,
        presentationMode: PresentationMode = .full,
        initialSubject: String = "",
        initialDetails: String = ""
    ) {
        _reportType = State(initialValue: initialReportType)
        _subject = State(initialValue: initialSubject)
        _details = State(initialValue: initialDetails)
        self.presentationMode = presentationMode
    }

    var body: some View {
        let unavailableMessage: String = NSLocalizedString("support.mail.unavailable", comment: "")
        
        NavigationStack {
            Form {
                if presentationMode == .full {
                    typePickerSection
                }
                subjectSection
                detailsSection
                stepsSection
                robotCheckSection
                deviceInfoSection
                syncDiagnosticsSection
                privacyNoticeSection
            }
            .navigationTitle(NSLocalizedString("support.title", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("common.cancel", comment: "")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        attemptSend()
                    } label: {
                        if supportService.isLoading {
                            ProgressView()
                        } else {
                            Text(NSLocalizedString("support.send", comment: ""))
                        }
                    }
                    .disabled(subject.trimmingCharacters(in: .whitespaces).isEmpty ||
                              details.trimmingCharacters(in: .whitespaces).isEmpty ||
                              supportService.isLoading)
                }
            }
            .sheet(isPresented: $showMailCompose) {
                MailComposeView(
                    recipients: [supportEmail],
                    subject: mailSubject,
                    body: mailBody,
                    onDismiss: { dismiss() }
                )
            }
            .sheet(isPresented: $showSupportResponse) {
                if let response = supportService.response {
                    SupportResponseView(
                        responseText: response,
                        onDismiss: { dismiss() },
                        onAskDeveloper: {
                            showSupportResponse = false
                            openEmailFlow()
                        }
                    )
                }
            }
            .alert(NSLocalizedString("support.mail.unavailableTitle", comment: ""),
                   isPresented: $showMailUnavailable) {
                Button(NSLocalizedString("support.mail.copyToClipboard", comment: "")) {
                    prepareDiagnosticsSnapshotIfNeeded()
                    UIPasteboard.general.string = "\(mailSubject)\n\n\(mailBody)"
                }
                Button("OK", role: .cancel) {}
            } message: {
                Text(unavailableMessage)
            }
            .alert(NSLocalizedString("support.robotCheck.failedTitle", comment: ""),
                   isPresented: $showRobotAlert) {
                Button("OK", role: .cancel) {
                    challengeA = Int.random(in: 2...9)
                    challengeB = Int.random(in: 2...9)
                    challengeAnswer = ""
                }
            } message: {
                Text(NSLocalizedString("support.robotCheck.failedMessage", comment: ""))
            }
            .alert(NSLocalizedString("support.validation.missingTitle", comment: ""),
                   isPresented: $showValidationAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(validationMessage)
            }
            .alert(NSLocalizedString("support.error.title", comment: ""),
                   isPresented: .init(
                       get: { supportService.errorMessage != nil },
                       set: { if !$0 { supportService.errorMessage = nil } }
                   )) {
                Button(NSLocalizedString("support.error.emailInstead", comment: "")) {
                    supportService.errorMessage = nil
                    openEmailFlow()
                }
                Button("OK", role: .cancel) {
                    supportService.errorMessage = nil
                }
            } message: {
                Text(supportService.errorMessage ?? "")
            }
        }
    }

    // MARK: - Form Sections

    private var typePickerSection: some View {
        Section {
            Picker("Type", selection: $reportType) {
                ForEach(ReportType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)
        } header: {
            Text(NSLocalizedString("support.section.type", comment: ""))
        }
    }

    private var subjectSection: some View {
        Section {
            TextField(NSLocalizedString("support.subject.placeholder", comment: ""), text: $subject)
        } header: {
            Text(NSLocalizedString("support.section.subject", comment: ""))
        }
    }

    private var detailsSection: some View {
        Section {
            TextEditor(text: $details)
                .frame(minHeight: 120)
        } header: {
            switch reportType {
            case .bug:
                Text(NSLocalizedString("support.details.bugHeader", comment: ""))
            case .suggestion:
                Text(NSLocalizedString("support.details.suggestionHeader", comment: ""))
            case .question:
                Text(NSLocalizedString("support.details.questionHeader", comment: ""))
            }
        }
    }

    @ViewBuilder
    private var stepsSection: some View {
        if reportType == .bug {
            Section {
                TextEditor(text: $stepsToReproduce)
                    .frame(minHeight: 80)
            } header: {
                Text(NSLocalizedString("support.steps.header", comment: ""))
            }
        }
    }

    private var deviceInfoSection: some View {
        Section {
            HStack {
                Text(NSLocalizedString("support.device.label", comment: ""))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(deviceInfo)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
            }
            HStack {
                Text(NSLocalizedString("support.appVersion.label", comment: ""))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(appVersion)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text(NSLocalizedString("support.section.systemInfo", comment: ""))
        } footer: {
            Text(NSLocalizedString("support.systemInfo.footer", comment: ""))
        }
    }

    private var privacyNoticeSection: some View {
        Section {
            Label {
                Text(NSLocalizedString("support.privacy.notice", comment: ""))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } icon: {
                Image(systemName: "lock.shield")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var syncDiagnosticsSection: some View {
        Section {
            Toggle(NSLocalizedString("support.syncDiagnostics.include", comment: ""), isOn: $includeSyncDiagnostics)
        } header: {
            Text(NSLocalizedString("support.section.syncDiagnostics", comment: ""))
        } footer: {
            Text(NSLocalizedString("support.syncDiagnostics.footer", comment: ""))
        }
    }

    private var robotCheckSection: some View {
        Section {
            HStack {
                Text(String(format: NSLocalizedString("support.robotCheck.question", comment: ""),
                            challengeA, challengeB))
                Spacer()
                TextField(NSLocalizedString("support.robotCheck.answer", comment: ""),
                          text: $challengeAnswer)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 60)
            }
        } header: {
            Text(NSLocalizedString("support.section.robotCheck", comment: ""))
        }
    }

    // MARK: - Actions

    private func attemptSend() {
        let trimmedSubject = subject.trimmingCharacters(in: .whitespaces)
        let trimmedDetails = details.trimmingCharacters(in: .whitespaces)

        if trimmedSubject.isEmpty || trimmedDetails.isEmpty {
            validationMessage = NSLocalizedString("support.validation.missingMessage", comment: "")
            showValidationAlert = true
            return
        }

        guard let answer = Int(challengeAnswer.trimmingCharacters(in: .whitespaces)),
              answer == challengeA + challengeB else {
            showRobotAlert = true
            return
        }

        // Only questions go through the AI support flow.
        // Bug reports and suggestions should go directly to developer contact.
        guard reportType == .question else {
            openEmailFlow()
            return
        }

        // Submit to support service
        Task {
            await supportService.submitQuery(
                reportType: reportType.rawValue,
                subject: trimmedSubject,
                details: trimmedDetails,
                stepsToReproduce: stepsToReproduce,
                deviceInfo: deviceInfo,
                appVersion: appVersion
            )

            if supportService.response != nil {
                showSupportResponse = true
            }
            // If errorMessage is set, the alert binding handles it automatically
        }
    }

    private func openEmailFlow() {
        prepareDiagnosticsSnapshotIfNeeded()

        if MFMailComposeViewController.canSendMail() {
            showMailCompose = true
        } else {
            showMailUnavailable = true
        }
    }

    private func prepareDiagnosticsSnapshotIfNeeded() {
        guard includeSyncDiagnostics else {
            diagnosticsSnapshot = ""
            return
        }

        diagnosticsSnapshot = SupportDiagnosticsSnapshotBuilder.buildSnapshot(modelContext: modelContext)
    }

    // MARK: - Mail Content

    private var mailSubject: String {
        let prefix: String
        switch reportType {
        case .bug: prefix = "[Bug]"
        case .suggestion: prefix = "[Suggestion]"
        case .question: prefix = "[Question]"
        }
        return "\(prefix) \(subject)"
    }

    private var mailBody: String {
        var body = """
        \(reportType.rawValue)
        ============================

        \(details)
        """

        if reportType == .bug && !stepsToReproduce.trimmingCharacters(in: .whitespaces).isEmpty {
            body += """


            Steps to Reproduce
            ----------------------------
            \(stepsToReproduce)
            """
        }

        body += """


        ----------------------------
        Device: \(deviceInfo)
        App Version: \(appVersion)
        """

        if includeSyncDiagnostics {
            body += """


            ----------------------------
            \(NSLocalizedString("support.syncDiagnostics.header", comment: ""))
            ----------------------------
            \(diagnosticsSnapshot)
            """
        }

        return body
    }

    // MARK: - Helpers

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private var deviceInfo: String {
        #if targetEnvironment(macCatalyst)
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        return "Mac (Catalyst) — macOS \(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)"
        #else
        return "\(UIDevice.current.model) — \(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"
        #endif
    }
}
