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
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(styleSheets, id: \.id) { sheet in
                    NavigationLink {
                        StyleSheetDetailView(styleSheet: sheet)
                    } label: {
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
                                sheetToDelete = sheet
                                showDeleteAlert = true
                            }) {
                                Label("styleSheetManagement.delete", systemImage: "trash")
                                    .labelStyle(.iconOnly)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("styleSheetManagement.delete.accessibility")
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("styleSheetManagement.title")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("button.done") {
                        dismiss()
                    }
                }
                
                #if DEBUG
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {
                        resetDatabase()
                    }) {
                        Label("Reset DB", systemImage: "arrow.clockwise")
                    }
                }
                
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {
                        fixAllCategories()
                    }) {
                        Label("Fix Categories", systemImage: "wrench.and.screwdriver")
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
        }
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
        let duplicate = StyleSheet(
            name: "\(original.name) Copy",
            isSystemStyleSheet: false
        )
        
        // Copy all text styles
        if let originalStyles = original.textStyles {
            for style in originalStyles {
                let newStyle = TextStyleModel(
                    name: style.name,
                    displayName: style.displayName,
                    displayOrder: style.displayOrder
                )
                
                // Copy all attributes
                newStyle.fontSize = style.fontSize
                newStyle.fontFamily = style.fontFamily
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
                
                newStyle.styleSheet = duplicate
            }
        }
        
        modelContext.insert(duplicate)
        
        do {
            try modelContext.save()
            loadStyleSheets()
        } catch {
            #if DEBUG
            print("❌ Error duplicating stylesheet: \(error)")
            #endif
        }
    }
    
    private func deleteStyleSheet(_ sheet: StyleSheet) {
        modelContext.delete(sheet)
        
        do {
            try modelContext.save()
            loadStyleSheets()
        } catch {
            #if DEBUG
            print("❌ Error deleting stylesheet: \(error)")
            #endif
        }
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
            try modelContext.save()
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
                        isSystemStyle: false  // User stylesheets should have editable styles
                    )
                    
                    newImageStyle.styleSheet = newSheet
                    modelContext.insert(newImageStyle)
                }
            }
        }
        
        modelContext.insert(newSheet)
        
        do {
            try modelContext.save()
            onCreated()
            dismiss()
        } catch {
            errorMessage = String(format: NSLocalizedString("createStyleSheet.error.failed", comment: ""), error.localizedDescription)
            showError = true
        }
    }
}
