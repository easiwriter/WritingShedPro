//
//  StyleSheetManagementView.swift
//  Writing Shed Pro
//
//  View for managing stylesheets - create, edit, delete, duplicate
//

import SwiftUI
import SwiftData

// Alias for consistency
typealias StyleSheetListView = StyleSheetManagementView

struct StyleSheetManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var styleSheets: [StyleSheet] = []
    @State private var showCreateSheet = false
    @State private var showDeleteAlert = false
    @State private var sheetToDelete: StyleSheet?
    @State private var showStylesheetInUseAlert = false
    @State private var projectsUsingStylesheet: [String] = []
    @State private var showDeleteErrorAlert = false
    @State private var deleteErrorMessage = ""
    @State private var showRepairResultAlert = false
    @State private var repairResultMessage: String = ""
    @State private var showNormalizeResultAlert = false
    @State private var normalizeResultMessage: String = ""
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(styleSheets, id: \.id) { sheet in
                    NavigationLink {
                        StyleSheetDetailView(styleSheet: sheet)
                    } label: {
                        styleSheetRow(sheet)
                    }
                }
            }
            .navigationTitle("styleSheetManagement.title")
            .toolbar { managementToolbar }
            .onAppear {
                loadStyleSheets()
            }
            .sheet(isPresented: $showCreateSheet) {
                CreateStyleSheetView(onCreated: {
                    loadStyleSheets()
                })
            }
            .alert("styleSheetManagement.deleteAlert.title", isPresented: $showDeleteAlert) {
                Button("button.cancel", role: .cancel) { }
                Button("styleSheetManagement.delete", role: .destructive) {
                    if let sheet = sheetToDelete {
                        deleteStyleSheet(sheet)
                    }
                }
            } message: {
                if let sheet = sheetToDelete {
                    Text(String(format: NSLocalizedString("styleSheetManagement.deleteAlert.message", comment: ""), sheet.name))
                }
            }
            .alert("styleSheetManagement.deleteInUse.title", isPresented: $showStylesheetInUseAlert) {
                Button("button.ok", role: .cancel) { }
            } message: {
                if let sheet = sheetToDelete {
                    Text(
                        String(
                            format: NSLocalizedString("styleSheetManagement.deleteInUse.message", comment: ""),
                            sheet.name,
                            projectsUsingStylesheet.joined(separator: ", ")
                        )
                    )
                }
            }
            .alert("styleSheetManagement.deleteError.title", isPresented: $showDeleteErrorAlert) {
                Button("button.ok", role: .cancel) { }
            } message: {
                Text(deleteErrorMessage)
            }
            .alert("styleSheetManagement.repairListStyles.resultTitle", isPresented: $showRepairResultAlert) {
                Button("button.ok", role: .cancel) { }
            } message: {
                Text(repairResultMessage)
            }
            .alert("styleSheetManagement.normalizeLegacyFonts.resultTitle", isPresented: $showNormalizeResultAlert) {
                Button("button.ok", role: .cancel) { }
            } message: {
                Text(normalizeResultMessage)
            }
        }
    }

    @ToolbarContentBuilder
    private var managementToolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("button.done") {
                dismiss()
            }
        }

        ToolbarItem(placement: .topBarLeading) {
            Button(action: {
                repairRequiredListStyles()
            }) {
                Label("styleSheetManagement.repairListStyles", systemImage: "wrench.and.screwdriver")
            }
            .accessibilityLabel("styleSheetManagement.repairListStyles.accessibility")
        }

        ToolbarItem(placement: .topBarLeading) {
            Button(action: {
                normalizeLegacyFonts()
            }) {
                Label("styleSheetManagement.normalizeLegacyFonts", systemImage: "textformat.size")
            }
            .accessibilityLabel("styleSheetManagement.normalizeLegacyFonts.accessibility")
        }

        #if DEBUG
        ToolbarItem(placement: .topBarLeading) {
            Button(action: {
                resetDatabase()
            }) {
                Label("Reset DB", systemImage: "arrow.clockwise")
            }
        }
        #endif

        ToolbarItem(placement: .primaryAction) {
            Button(action: {
                showCreateSheet = true
            }) {
                Label("styleSheetManagement.newStylesheet", systemImage: "plus")
            }
            .accessibilityLabel("styleSheetManagement.newStylesheet.accessibility")
        }
    }

    @ViewBuilder
    private func styleSheetRow(_ sheet: StyleSheet) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(sheet.name)
                    .font(.headline)

                Text(String(format: NSLocalizedString("styleSheetManagement.stylesCount", comment: ""), sheet.textStyles?.count ?? 0))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: {
                duplicateStyleSheet(sheet)
            }) {
                Label("styleSheetManagement.duplicate", systemImage: "doc.on.doc")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("styleSheetManagement.duplicate.accessibility")

            Button(role: .destructive, action: {
                handleDeleteAttempt(for: sheet)
            }) {
                Label("styleSheetManagement.delete", systemImage: "trash")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("styleSheetManagement.delete.accessibility")
        }
        .padding(.vertical, 4)
    }
    
    private func loadStyleSheets() {
        var descriptor = FetchDescriptor<StyleSheet>()
        descriptor.sortBy = [SortDescriptor(\.name)]
        // Filter out system stylesheets - users can only manage custom ones
        descriptor.predicate = #Predicate<StyleSheet> { sheet in
            sheet.isSystemStyleSheet == false
        }
        
        if let sheets = try? modelContext.fetch(descriptor) {
            styleSheets = sheets
        }
    }
    
    private func duplicateStyleSheet(_ original: StyleSheet) {
        let duplicate = StyleSheetService.duplicateStyleSheet(original)
        modelContext.insert(duplicate)
        
        do {
            try WriteCoalescer.shared.requestSaveAndFlush(reason: "stylesheet-management-duplicate")
            loadStyleSheets()
        } catch {
            #if DEBUG
            print("❌ Error duplicating stylesheet: \(error)")
            #endif
        }
    }

    private func handleDeleteAttempt(for sheet: StyleSheet) {
        sheetToDelete = sheet

        let sheetID = sheet.id
        let projects = (try? modelContext.fetch(FetchDescriptor<Project>())) ?? []
        projectsUsingStylesheet = projects
            .filter { $0.styleSheet?.id == sheetID }
            .map { $0.name ?? NSLocalizedString("projectItem.untitledProject", comment: "") }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }

        if projectsUsingStylesheet.isEmpty {
            showDeleteAlert = true
        } else {
            showStylesheetInUseAlert = true
        }
    }
    
    private func deleteStyleSheet(_ sheet: StyleSheet) {
        let sheetID = sheet.id
        let remainingStyleSheets = styleSheets.filter { $0.id != sheetID }
        sheetToDelete = nil

        do {
            let deleteContext = ModelContext(modelContext.container)
            let descriptor = FetchDescriptor<StyleSheet>(
                predicate: #Predicate<StyleSheet> { candidate in
                    candidate.id == sheetID
                }
            )
            guard let sheetToDelete = try deleteContext.fetch(descriptor).first else {
                loadStyleSheets()
                self.sheetToDelete = nil
                return
            }

            deleteContext.delete(sheetToDelete)
            try EnsemblesSaveGate.save(deleteContext, reason: "stylesheet-management-delete")
            withAnimation {
                styleSheets = remainingStyleSheets
            }
        } catch {
            deleteErrorMessage = error.localizedDescription
            showDeleteErrorAlert = true
            #if DEBUG
            print("❌ Error deleting stylesheet: \(error)")
            #endif
        }
    }

    private func repairRequiredListStyles() {
        let (updatedSheets, repairedStyles) = StyleSheetService.repairRequiredListStyles(context: modelContext)

        if repairedStyles > 0 {
            repairResultMessage = String(
                format: NSLocalizedString("styleSheetManagement.repairListStyles.success", comment: ""),
                repairedStyles,
                updatedSheets
            )
        } else {
            repairResultMessage = NSLocalizedString("styleSheetManagement.repairListStyles.noChanges", comment: "")
        }

        loadStyleSheets()
        showRepairResultAlert = true
    }

    private func normalizeLegacyFonts() {
        let (normalizedFiles, scannedFiles) = StyleSheetService.normalizeLegacyIPhoneScaledFonts(context: modelContext)

        if normalizedFiles > 0 {
            normalizeResultMessage = String(
                format: NSLocalizedString("styleSheetManagement.normalizeLegacyFonts.success", comment: ""),
                normalizedFiles,
                scannedFiles
            )
        } else {
            normalizeResultMessage = String(
                format: NSLocalizedString("styleSheetManagement.normalizeLegacyFonts.noChanges", comment: ""),
                scannedFiles
            )
        }

        showNormalizeResultAlert = true
    }
    
    #if DEBUG
    /// Debug function to reset database to clean state with fresh default stylesheet
    private func resetDatabase() {
        #if DEBUG
        print("🔄 Resetting database...")
        #endif
        
        // Delete ALL stylesheets (including system default - we'll recreate it)
        let descriptor = FetchDescriptor<StyleSheet>()
        if let sheets = try? modelContext.fetch(descriptor) {
            for sheet in sheets {
                #if DEBUG
                print("🗑️ Deleting stylesheet: \(sheet.name) (isSystem: \(sheet.isSystemStyleSheet))")
                #endif
                modelContext.delete(sheet)
            }
        }
        
        // Delete all projects
        let projectDescriptor = FetchDescriptor<Project>()
        if let projects = try? modelContext.fetch(projectDescriptor) {
            for project in projects {
                #if DEBUG
                print("🗑️ Deleting project: \(project.name ?? "unnamed")")
                #endif
                modelContext.delete(project)
            }
        }
        
        do {
            try WriteCoalescer.shared.requestSaveAndFlush(reason: "stylesheet-management-debug-reset")
            #if DEBUG
            print("✅ Database cleared")
            #endif
            
            // Recreate fresh default stylesheet with correct values
            #if DEBUG
            print("📐 Creating fresh default stylesheet...")
            #endif
            StyleSheetService.initializeStyleSheetsIfNeeded(context: modelContext)
            
            loadStyleSheets()
            #if DEBUG
            print("✅ Reset complete")
            #endif
        } catch {
            #if DEBUG
            print("❌ Error resetting database: \(error)")
            #endif
        }
    }
    
    private func fixAllCategories() {
        #if DEBUG
        print("🔧 Manually fixing all stylesheet categories...")
        #endif
        let descriptor = FetchDescriptor<StyleSheet>()
        if let sheets = try? modelContext.fetch(descriptor) {
            for sheet in sheets {
                #if DEBUG
                print("🔧 Fixing categories for stylesheet: \(sheet.name)")
                #endif
                StyleSheetService.fixStyleCategories(in: sheet, context: modelContext)
            }
            loadStyleSheets()
            #if DEBUG
            print("✅ Category fix complete - check console for details")
            #endif
        } else {
            #if DEBUG
            print("❌ No stylesheets found")
            #endif
        }
    }
    #endif
}

// MARK: - Create Stylesheet View

struct CreateStyleSheetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String = ""
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    
    let onCreated: () -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("createStyleSheet.name", text: $name)
                        .accessibilityLabel("createStyleSheet.name.accessibility")
                } header: {
                    Text("createStyleSheet.stylesheetName")
                } footer: {
                    Text("createStyleSheet.footer")
                }
            }
            .navigationTitle("createStyleSheet.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("button.cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("button.create") {
                        createStyleSheet()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert("error.title", isPresented: $showError) {
                Button("button.ok", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func createStyleSheet() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check if name already exists
        let descriptor = FetchDescriptor<StyleSheet>(
            predicate: #Predicate { $0.name == trimmedName }
        )
        
        if let existing = try? modelContext.fetch(descriptor), !existing.isEmpty {
            errorMessage = NSLocalizedString("createStyleSheet.error.duplicate", comment: "")
            showError = true
            return
        }
        
        // Create new stylesheet
        let newSheet = StyleSheet(
            name: trimmedName,
            isSystemStyleSheet: false
        )
        
        // Always copy styles from default stylesheet
        if let defaultSheet = StyleSheetService.getDefaultStyleSheet(context: modelContext) {
            // Copy text styles
            if let defaultStyles = defaultSheet.textStyles {
                for style in defaultStyles {
                    let newStyle = TextStyleModel(
                        name: style.name,
                        displayName: style.displayName,
                        displayOrder: style.displayOrder
                    )
                    
                    // Copy all attributes
                    newStyle.fontSize = style.fontSize
                    newStyle.fontFamily = style.fontFamily
                    newStyle.fontName = style.fontName
                    newStyle.isBold = style.isBold
                    newStyle.isItalic = style.isItalic
                    newStyle.isUnderlined = style.isUnderlined
                    newStyle.isStrikethrough = style.isStrikethrough
                    newStyle.textColor = style.textColor
                    newStyle.alignment = style.alignment
                    newStyle.lineSpacing = style.lineSpacing
                    newStyle.paragraphSpacingBefore = style.paragraphSpacingBefore
                    newStyle.paragraphSpacingAfter = style.paragraphSpacingAfter
                    newStyle.firstLineIndent = style.firstLineIndent
                    newStyle.headIndent = style.headIndent
                    newStyle.tailIndent = style.tailIndent
                    newStyle.lineHeightMultiple = style.lineHeightMultiple
                    newStyle.minimumLineHeight = style.minimumLineHeight
                    newStyle.maximumLineHeight = style.maximumLineHeight
                    newStyle.numberFormat = style.numberFormat
                    newStyle.numberAdornment = style.numberAdornment
                    newStyle.styleCategory = style.styleCategory
                    newStyle.parentStyleName = style.parentStyleName
                    newStyle.followOnStyleName = style.followOnStyleName
                    newStyle.includeInTOC = style.includeInTOC
                    newStyle.tocLevel = style.tocLevel
                    
                    newStyle.styleSheet = newSheet
                }
            }
            
            // Copy image styles
            if let defaultImageStyles = defaultSheet.imageStyles {
                for imageStyle in defaultImageStyles {
                    let newImageStyle = ImageStyle(
                        name: imageStyle.name,
                        displayName: imageStyle.displayName,
                        displayOrder: imageStyle.displayOrder,
                        defaultScale: imageStyle.defaultScale,
                        defaultAlignment: imageStyle.defaultAlignment,
                        hasCaptionByDefault: imageStyle.hasCaptionByDefault,
                        defaultCaptionStyle: imageStyle.defaultCaptionStyle,
                        defaultSpacingAbove: imageStyle.defaultSpacingAbove,
                        defaultSpacingBelow: imageStyle.defaultSpacingBelow,
                        defaultBorderStyle: imageStyle.defaultBorderStyle,
                        defaultBorderPadding: imageStyle.defaultBorderPadding,
                        isSystemStyle: false  // User stylesheets should have editable styles
                    )
                    
                    newImageStyle.styleSheet = newSheet
                    modelContext.insert(newImageStyle)
                }
            }
        }
        
        modelContext.insert(newSheet)
        
        do {
            try WriteCoalescer.shared.requestSaveAndFlush(reason: "stylesheet-management-create")
            onCreated()
            dismiss()
        } catch {
            errorMessage = String(format: NSLocalizedString("createStyleSheet.error.failed", comment: ""), error.localizedDescription)
            showError = true
        }
    }
}
