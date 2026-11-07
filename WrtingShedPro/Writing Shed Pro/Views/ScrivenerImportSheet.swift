import SwiftUI

struct ScrivenerImportSheet: View {
    let draft: ScrivenerProjectDraft
    let onCancel: () -> Void
    let onImport: (ScrivenerImportOptions) -> Void

    @State private var options = ScrivenerImportOptions()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent(
                        NSLocalizedString("scrivener.import.projectName", comment: "Imported project name"),
                        value: draft.projectName
                    )
                    LabeledContent(
                        NSLocalizedString("scrivener.import.contents", comment: "Imported project contents"),
                        value: String(
                            format: NSLocalizedString(
                                "scrivener.import.contentsCount",
                                comment: "Folder and document count"
                            ),
                            draft.folderCount,
                            draft.documentCount
                        )
                    )
                    Picker(
                        NSLocalizedString("scrivener.import.projectType", comment: "New project type"),
                        selection: $options.projectType
                    ) {
                        ForEach(ProjectType.allCases, id: \.self) { type in
                            Text(type.localizedName).tag(type)
                        }
                    }
                    mappingDescription
                } header: {
                    Text(NSLocalizedString("scrivener.import.summary", comment: "Import summary"))
                }

                if options.projectType == .fiction {
                    Section {
                        Picker(
                            NSLocalizedString("scrivener.import.fictionClass", comment: "Fiction structure"),
                            selection: $options.fictionClass
                        ) {
                            ForEach(FictionClass.allCases, id: \.self) { fictionClass in
                                Text(fictionClass.localizedName).tag(fictionClass)
                            }
                        }
                    }
                }

                if options.projectType == .drama {
                    Section {
                        Picker(
                            NSLocalizedString("scrivener.import.dramaType", comment: "Drama script type"),
                            selection: $options.dramaScriptType
                        ) {
                            ForEach(DramaScriptType.allCases, id: \.self) { scriptType in
                                Text(scriptType.localizedName).tag(scriptType)
                            }
                        }
                    }
                }

                if !draft.researchItems.isEmpty || !draft.trashItems.isEmpty {
                    Section {
                        if !draft.researchItems.isEmpty {
                            Toggle(
                                String(
                                    format: NSLocalizedString(
                                        "scrivener.import.includeResearch",
                                        comment: "Include Scrivener research items"
                                    ),
                                    draft.researchItems.reduce(0) { $0 + $1.documentCount }
                                ),
                                isOn: $options.includeResearch
                            )
                        }
                        if !draft.trashItems.isEmpty {
                            Toggle(
                                String(
                                    format: NSLocalizedString(
                                        "scrivener.import.includeTrash",
                                        comment: "Include Scrivener trash items"
                                    ),
                                    draft.trashItems.reduce(0) { $0 + $1.documentCount }
                                ),
                                isOn: $options.includeTrash
                            )
                        }
                    } header: {
                        Text(NSLocalizedString("scrivener.import.optionalItems", comment: "Optional imported items"))
                    } footer: {
                        Text(NSLocalizedString("scrivener.import.optionalItemsNote", comment: "Research and Trash default"))
                    }
                }

                if !draft.warnings.isEmpty {
                    Section {
                        ForEach(draft.warnings.indices.prefix(5), id: \.self) { index in
                            Label(draft.warnings[index], systemImage: "exclamationmark.triangle")
                                .font(.footnote)
                        }
                        if draft.warnings.count > 5 {
                            Text(
                                String(
                                    format: NSLocalizedString(
                                        "scrivener.import.moreWarnings",
                                        comment: "Additional import warnings"
                                    ),
                                    draft.warnings.count - 5
                                )
                            )
                            .font(.footnote)
                        }
                    } header: {
                        Text(NSLocalizedString("scrivener.import.warnings", comment: "Import warnings"))
                    }
                }

                Section {
                    Text(NSLocalizedString("scrivener.import.compileNote", comment: "Compile exclusions note"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(NSLocalizedString("scrivener.import.title", comment: "Scrivener import title"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("button.cancel", comment: "Cancel")) {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(NSLocalizedString("scrivener.import.action", comment: "Import Scrivener project")) {
                        onImport(options)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var mappingDescription: some View {
        Text(mappingDescriptionText)
            .font(.footnote)
            .foregroundStyle(.secondary)
    }

    private var mappingDescriptionText: String {
        switch options.projectType {
        case .prose:
            return NSLocalizedString("scrivener.import.mapping.prose", comment: "Prose binder mapping")
        case .fiction:
            return NSLocalizedString("scrivener.import.mapping.fiction", comment: "Fiction binder mapping")
        case .poetry:
            return NSLocalizedString("scrivener.import.mapping.poetry", comment: "Poetry binder mapping")
        case .drama:
            return NSLocalizedString("scrivener.import.mapping.drama", comment: "Drama binder mapping")
        }
    }
}
