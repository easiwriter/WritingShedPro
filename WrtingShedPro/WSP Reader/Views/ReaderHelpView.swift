//
//  ReaderHelpView.swift
//  WSP Reader
//
//  Help sheet explaining what WSP Reader does.
//

import SwiftUI

extension Notification.Name {
    static let wspReaderShowHelp = Notification.Name("wspReaderShowHelp")
}

struct ReaderHelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {

                    // Icon + intro
                    HStack(spacing: 16) {
                        Image(systemName: "books.vertical")
                            .font(.system(size: 48))
                            .foregroundStyle(.brown)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("WSP Reader")
                                .font(.title2)
                                .fontWeight(.semibold)
                            Text("Read your Writing Shed Pro projects")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Divider()

                    helpSection(
                        icon: "doc.badge.plus",
                        title: "Opening a Project",
                        body: "Tap the + button to open a .wsp file. WSP files are exported from Writing Shed Pro on any device. Once opened, a project appears in your recent list for quick access."
                    )

                    helpSection(
                        icon: "sidebar.left",
                        title: "Browsing Files",
                        body: "Use the sidebar to navigate between your chapters, poems, scenes, or other files. Tap any file to read it. On Mac, use the sidebar toggle in the toolbar to show or hide the file list."
                    )

                    helpSection(
                        icon: "eye",
                        title: "View Manuscript",
                        body: "Select View Manuscript in the sidebar to read the assembled document in order — front matter, body files, and back matter — exactly as it would be exported."
                    )

                    helpSection(
                        icon: "textformat.size",
                        title: "Adjusting Text Size",
                        body: "Use the Aa buttons in the toolbar to make the text larger or smaller. Your size preference is remembered between sessions."
                    )

                    helpSection(
                        icon: "text.bubble",
                        title: "Adding Comments",
                        body: "Open any file and tap Comments in the toolbar. Add your notes in the comments panel. Your comments are stored locally in Reader until you export an annotated copy."
                    )

                    helpSection(
                        icon: "square.and.arrow.up",
                        title: "Sending Comments Back",
                        body: "In the document toolbar, use Export Annotated Copy to create a new .wsp file that includes your feedback. Send that file back to the author. In Writing Shed Pro, reader feedback is added to version notes under a Reader Comments section."
                    )

                    helpSection(
                        icon: "arrow.clockwise",
                        title: "Refreshing a Project",
                        body: "If you export a new version of a project from Writing Shed Pro, open the updated .wsp file again using the + button. It will replace the previous entry in your recent list."
                    )

                    Divider()

                    // Version
                    HStack {
                        Text("Version")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
                            .foregroundStyle(.secondary)
                    }
                    .font(.footnote)
                }
                .padding(24)
            }
            .navigationTitle("WSP Reader Help")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        #if targetEnvironment(macCatalyst)
        .frame(minWidth: 460, idealWidth: 520, minHeight: 540, idealHeight: 600)
        #endif
    }

    private func helpSection(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(.brown)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(body)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
