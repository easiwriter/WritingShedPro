//
//  MatterStylePickerSheet.swift
//  Writing Shed Pro
//
//  Sheet for choosing the stylesheet styles used for front/back matter headings and body text.
//  Applies consistently to all generated front and back matter sections.
//

import SwiftUI
import SwiftData

/// Sheet for selecting heading and body styles for front/back matter from the project's stylesheet
struct MatterStylePickerSheet: View {
    @Bindable var project: Project
    @Binding var isPresented: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var selectedHeadingStyleName: String = ""
    @State private var selectedBodyStyleName: String = ""
    
    /// Resolve the project's stylesheet via StyleSheetService (handles fallback)
    private var projectStyleSheet: StyleSheet? {
        StyleSheetService.getStyleSheet(for: project, context: modelContext)
    }
    
    /// All heading styles from the project's stylesheet
    private var headingStyles: [TextStyleModel] {
        guard let styles = projectStyleSheet?.textStyles else { return [] }
        return styles
            .filter { $0.styleCategory == .heading }
            .sorted { $0.displayOrder < $1.displayOrder }
    }
    
    /// All text (body) styles from the project's stylesheet
    private var bodyStyles: [TextStyleModel] {
        guard let styles = projectStyleSheet?.textStyles else { return [] }
        return styles
            .filter { $0.styleCategory == .text }
            .sorted { $0.displayOrder < $1.displayOrder }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(NSLocalizedString("matterStyle.headingStyle", comment: "Heading Style"), selection: $selectedHeadingStyleName) {
                        ForEach(headingStyles) { style in
                            Text(style.displayName)
                                .tag(style.name)
                        }
                    }
                    .pickerStyle(.menu)
                } header: {
                    Text(NSLocalizedString("matterStyle.headingSection", comment: "Section Headings"))
                } footer: {
                    Text(NSLocalizedString("matterStyle.headingFooter", comment: "Style used for headings in generated sections like Notes, Glossary, References, Index, and List of Figures."))
                }
                
                Section {
                    Picker(NSLocalizedString("matterStyle.bodyStyle", comment: "Body Style"), selection: $selectedBodyStyleName) {
                        ForEach(bodyStyles) { style in
                            Text(style.displayName)
                                .tag(style.name)
                        }
                    }
                    .pickerStyle(.menu)
                } header: {
                    Text(NSLocalizedString("matterStyle.bodySection", comment: "Body Text"))
                } footer: {
                    Text(NSLocalizedString("matterStyle.bodyFooter", comment: "Style used for body text in generated sections. Entry labels use a bold variant of this style."))
                }
                
                // Preview
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        if let headingStyle = projectStyleSheet?.style(named: selectedHeadingStyleName) {
                            Text(NSLocalizedString("matterStyle.previewHeading", comment: "Notes"))
                                .font(Font(headingStyle.generateFont()))
                                .foregroundStyle(Color(headingStyle.textColor ?? .label))
                                .frame(maxWidth: .infinity, alignment: headingStyle.alignment == .center ? .center : .leading)
                        }
                        if let bodyStyle = projectStyleSheet?.style(named: selectedBodyStyleName) {
                            let bodyFont = bodyStyle.generateFont()
                            let bodyColor = Color(bodyStyle.textColor ?? .label)
                            HStack(spacing: 0) {
                                Text("Example: ")
                                    .font(Font(bodyFont))
                                    .foregroundStyle(bodyColor)
                                    .bold()
                                Text(NSLocalizedString("matterStyle.previewBody", comment: "Sample body text for preview."))
                                    .font(Font(bodyFont))
                                    .foregroundStyle(bodyColor)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text(NSLocalizedString("matterStyle.previewSection", comment: "Preview"))
                }
            }
            .formStyle(.grouped)
            .navigationTitle(NSLocalizedString("matterStyle.title", comment: "Matter Styles"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("button.cancel", comment: "Cancel")) {
                        dismissSheet()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("button.save", comment: "Save")) {
                        save()
                    }
                }
            }
            .onAppear {
                selectedHeadingStyleName = project.matterHeadingStyleName
                selectedBodyStyleName = project.matterBodyStyleName
            }
        }
    }
    
    /// Dismiss the sheet reliably on all platforms including Mac Catalyst
    private func dismissSheet() {
        isPresented = false
        dismiss()
        dismissPresentedSheetOnCatalyst()
    }
    
    private func save() {
        project.matterHeadingStyleName = selectedHeadingStyleName
        project.matterBodyStyleName = selectedBodyStyleName
        project.modifiedDate = Date()
        WriteCoalescer.shared?.requestSave(reason: "matter-style-picker-save")
        WriteCoalescer.shared?.flush()
        dismissSheet()
    }
}
