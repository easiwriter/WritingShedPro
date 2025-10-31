//
//  StyleSheetManagementView.swift
//  Writing Shed Pro
//
//  View for managing stylesheets - create, edit, delete, duplicate
//

import SwiftUI
import SwiftData

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
                                
                                if sheet.isSystemStyleSheet {
                                    Text("System Default")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Text("\(sheet.textStyles?.count ?? 0) styles")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            if !sheet.isSystemStyleSheet {
                                Button(action: {
                                    duplicateStyleSheet(sheet)
                                }) {
                                    Label("Duplicate", systemImage: "doc.on.doc")
                                        .labelStyle(.iconOnly)
                                }
                                .buttonStyle(.plain)
                                
                                Button(role: .destructive, action: {
                                    sheetToDelete = sheet
                                    showDeleteAlert = true
                                }) {
                                    Label("Delete", systemImage: "trash")
                                        .labelStyle(.iconOnly)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Stylesheets")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
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
                #endif
                
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        showCreateSheet = true
                    }) {
                        Label("New Stylesheet", systemImage: "plus")
                    }
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
            .alert("Delete Stylesheet", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    if let sheet = sheetToDelete {
                        deleteStyleSheet(sheet)
                    }
                }
            } message: {
                if let sheet = sheetToDelete {
                    Text("Are you sure you want to delete '\(sheet.name)'? Projects using this stylesheet will revert to the system default.")
                }
            }
        }
    }
    
    private func loadStyleSheets() {
        var descriptor = FetchDescriptor<StyleSheet>()
        descriptor.sortBy = [SortDescriptor(\.name)]
        
        if let sheets = try? modelContext.fetch(descriptor) {
            // Sort with system sheets first
            styleSheets = sheets.sorted { first, second in
                if first.isSystemStyleSheet != second.isSystemStyleSheet {
                    return first.isSystemStyleSheet
                }
                return first.name < second.name
            }
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
            print("❌ Error duplicating stylesheet: \(error)")
        }
    }
    
    private func deleteStyleSheet(_ sheet: StyleSheet) {
        modelContext.delete(sheet)
        
        do {
            try modelContext.save()
            loadStyleSheets()
        } catch {
            print("❌ Error deleting stylesheet: \(error)")
        }
    }
    
    #if DEBUG
    /// Debug function to reset database to only have default stylesheet
    private func resetDatabase() {
        print("🔄 Resetting database...")
        
        // Delete all non-system stylesheets
        let descriptor = FetchDescriptor<StyleSheet>()
        if let sheets = try? modelContext.fetch(descriptor) {
            for sheet in sheets where !sheet.isSystemStyleSheet {
                print("🗑️ Deleting stylesheet: \(sheet.name)")
                modelContext.delete(sheet)
            }
        }
        
        // Delete all projects
        let projectDescriptor = FetchDescriptor<Project>()
        if let projects = try? modelContext.fetch(projectDescriptor) {
            for project in projects {
                print("🗑️ Deleting project: \(project.name ?? "unnamed")")
                modelContext.delete(project)
            }
        }
        
        do {
            try modelContext.save()
            print("✅ Database reset complete")
            
            // Ensure default stylesheet exists
            StyleSheetService.initializeStyleSheetsIfNeeded(context: modelContext)
            
            loadStyleSheets()
        } catch {
            print("❌ Error resetting database: \(error)")
        }
    }
    #endif
}

// MARK: - Create Stylesheet View

struct CreateStyleSheetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String = ""
    @State private var copyFromDefault: Bool = true
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    
    let onCreated: () -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Stylesheet Name") {
                    TextField("Name", text: $name)
                }
                
                Section {
                    Toggle("Copy styles from system default", isOn: $copyFromDefault)
                } footer: {
                    Text("If enabled, the new stylesheet will include all styles from the system default. Otherwise, it will start empty.")
                }
            }
            .navigationTitle("New Stylesheet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createStyleSheet()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
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
            errorMessage = "A stylesheet with this name already exists."
            showError = true
            return
        }
        
        // Create new stylesheet
        let newSheet = StyleSheet(
            name: trimmedName,
            isSystemStyleSheet: false
        )
        
        // Copy from default if requested
        if copyFromDefault {
            if let defaultSheet = StyleSheetService.getDefaultStyleSheet(context: modelContext),
               let defaultStyles = defaultSheet.textStyles {
                
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
        }
        
        modelContext.insert(newSheet)
        
        do {
            try modelContext.save()
            onCreated()
            dismiss()
        } catch {
            errorMessage = "Failed to create stylesheet: \(error.localizedDescription)"
            showError = true
        }
    }
}
