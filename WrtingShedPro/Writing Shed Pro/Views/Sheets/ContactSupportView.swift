//
//  ContactSupportView.swift
//  Writing Shed Pro
//
//  Contact support form — bug reports & suggestions
//  Feature 019: Settings Menu
//

import SwiftUI
import MessageUI

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

    enum ReportType: String, CaseIterable, Identifiable {
        case bug = "Bug Report"
        case suggestion = "Suggestion"
        var id: String { rawValue }
    }

    @State private var reportType: ReportType = .bug
    @State private var subject: String = ""
    @State private var details: String = ""
    @State private var stepsToReproduce: String = ""
    @State private var notARobot: Bool = false

    @State private var showMailCompose = false
    @State private var showMailUnavailable = false
    @State private var showRobotAlert = false
    @State private var showValidationAlert = false
    @State private var validationMessage = ""

    // Robot-check: simple arithmetic challenge
    @State private var challengeA: Int = Int.random(in: 2...9)
    @State private var challengeB: Int = Int.random(in: 2...9)
    @State private var challengeAnswer: String = ""

    private let supportEmail = "easiwriter@writing-shed.com"

    var body: some View {
        let clipboardString: String = "\(mailSubject)\n\n\(mailBody)"
        let unavailableMessage: String = "Mail is not configured on this device. You can copy the message and email it to \(supportEmail) manually."
        
        NavigationStack {
            Form {
                typePickerSection
                subjectSection
                detailsSection
                stepsSection
                deviceInfoSection
                robotCheckSection
                sendButtonSection
            }
            .navigationTitle("Contact Support")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
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
            .alert("Cannot Send Email", isPresented: $showMailUnavailable) {
                Button("Copy to Clipboard") {
                    UIPasteboard.general.string = clipboardString
                }
                Button("OK", role: .cancel) {}
            } message: {
                Text(unavailableMessage)
            }
            .alert("Robot Check Failed", isPresented: $showRobotAlert) {
                Button("OK", role: .cancel) {
                    // Generate a new challenge
                    challengeA = Int.random(in: 2...9)
                    challengeB = Int.random(in: 2...9)
                    challengeAnswer = ""
                }
            } message: {
                Text("Please answer the arithmetic question correctly to verify you are not a robot.")
            }
            .alert("Missing Information", isPresented: $showValidationAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(validationMessage)
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
            Text("What would you like to send?")
        }
    }

    private var subjectSection: some View {
        Section {
            TextField("Brief summary", text: $subject)
        } header: {
            Text("Subject")
        }
    }

    private var detailsSection: some View {
        Section {
            TextEditor(text: $details)
                .frame(minHeight: 120)
        } header: {
            Text(reportType == .bug ? "Describe the problem" : "Your suggestion")
        }
    }

    @ViewBuilder
    private var stepsSection: some View {
        if reportType == .bug {
            Section {
                TextEditor(text: $stepsToReproduce)
                    .frame(minHeight: 80)
            } header: {
                Text("Steps to reproduce (optional)")
            }
        }
    }

    private var deviceInfoSection: some View {
        Section {
            HStack {
                Text("Device")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(deviceInfo)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
            }
            HStack {
                Text("App Version")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(appVersion)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("System Information")
        } footer: {
            Text("This information is included automatically to help us diagnose issues.")
        }
    }

    private var robotCheckSection: some View {
        Section {
            HStack {
                Text("What is \(challengeA) + \(challengeB)?")
                Spacer()
                TextField("Answer", text: $challengeAnswer)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 60)
            }
        } header: {
            Text("Verify you are not a robot")
        }
    }

    private var sendButtonSection: some View {
        Section {
            Button {
                attemptSend()
            } label: {
                HStack {
                    Spacer()
                    Label("Send", systemImage: "paperplane.fill")
                        .font(.headline)
                    Spacer()
                }
            }
            .disabled(subject.trimmingCharacters(in: .whitespaces).isEmpty ||
                      details.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    // MARK: - Actions

    private func attemptSend() {
        // Validate required fields
        let trimmedSubject = subject.trimmingCharacters(in: .whitespaces)
        let trimmedDetails = details.trimmingCharacters(in: .whitespaces)

        if trimmedSubject.isEmpty || trimmedDetails.isEmpty {
            validationMessage = "Please fill in both the subject and the description."
            showValidationAlert = true
            return
        }

        // Verify robot check
        guard let answer = Int(challengeAnswer.trimmingCharacters(in: .whitespaces)),
              answer == challengeA + challengeB else {
            showRobotAlert = true
            return
        }

        // Send
        if MFMailComposeViewController.canSendMail() {
            showMailCompose = true
        } else {
            showMailUnavailable = true
        }
    }

    // MARK: - Mail Content

    private var mailSubject: String {
        let prefix = reportType == .bug ? "[Bug]" : "[Suggestion]"
        return "\(prefix) \(subject)"
    }

    private var mailBody: String {
        var body = """
        \(reportType == .bug ? "Bug Report" : "Suggestion")
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

        return body
    }

    // MARK: - Helpers

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private var deviceInfo: String {
        "\(UIDevice.current.model) — \(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"
    }
}
