//
//  ContainerAssignmentView.swift
//  Writing Shed Pro
//
//  Created on 28 February 2026.
//  Generic container assignment dialog for all project types.
//  Shows selected items with their current container, and Move/Copy actions.
//

import SwiftUI
import SwiftData

// MARK: - Protocol for Container Items

/// Protocol that both TextFile and StoryScene conform to, providing a common interface
/// for the container assignment dialog.
/// Note: Do NOT inherit Identifiable here — @Model types already conform,
/// and re-declaring causes duplicate linker symbols.
protocol ContainerAssignable: AnyObject {
    var id: UUID { get }
    var displayName: String { get }
}

extension TextFile: ContainerAssignable {
    var displayName: String { name }
}

extension StoryScene: ContainerAssignable {
    var displayName: String { name ?? NSLocalizedString("fiction.untitled", comment: "Untitled") }
}

// MARK: - Container Descriptor

/// Describes a container and provides add/remove callbacks.
struct ContainerDescriptor<Item: ContainerAssignable> {
    let id: UUID
    let name: String
    let memberIDs: Set<UUID>
    
    /// Callback to add an item to this container
    let addItem: (Item) -> Void
    /// Callback to remove an item from this container
    let removeItem: (Item) -> Void
    
    /// Check if an item is currently in this container
    func contains(_ item: Item) -> Bool {
        memberIDs.contains(item.id)
    }
}

// MARK: - Container Assignment View

/// Shows selected items with selection circles and current container labels.
/// Move and Copy menu buttons let the user pick a destination container.
/// Move removes existing assignments and assigns to the target.
/// Copy adds the target while keeping existing assignments.
struct ContainerAssignmentView<Item: ContainerAssignable>: View {
    
    // MARK: - Properties
    
    /// Display name for the container type (e.g. "Collection", "Section", "Chapter")
    let containerTypeName: String
    
    /// Items passed in from the parent view
    let selectedItems: [Item]
    
    /// All available containers for this project
    let containers: [ContainerDescriptor<Item>]
    
    /// Lookup that returns the set of container IDs an item currently belongs to
    /// (queried from the item's direct relationship, not the container inverse).
    let currentContainerIDs: (Item) -> Set<UUID>
    
    /// Callback to persist changes
    let onSave: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - State
    
    /// Which items are checked (selected) within this dialog for the next action
    @State private var dialogSelection: Set<UUID> = []
    
    /// Live assignment map: itemID → set of containerIDs the item belongs to
    @State private var assignments: [UUID: Set<UUID>] = [:]
    
    /// Snapshot taken on appear so we can diff on save
    @State private var originalAssignments: [UUID: Set<UUID>] = [:]
    
    /// Guard against double-save
    @State private var didApply = false
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                List {
                    ForEach(selectedItems, id: \.id) { item in
                        itemRow(item)
                    }
                }
                .listStyle(.insetGrouped)
                
                Divider()
                
                actionBar
                    .padding(.horizontal)
                    .padding(.vertical, 12)
            }
            .navigationTitle(
                String(format: NSLocalizedString("containerAssignment.title", comment: "%@ Assignment"),
                       containerTypeName)
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(NSLocalizedString("common.cancel", comment: "Cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(NSLocalizedString("common.done", comment: "Done")) {
                        applyChanges()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            initializeState()
        }
    }
    
    // MARK: - Item Row
    
    @ViewBuilder
    private func itemRow(_ item: Item) -> some View {
        let isChecked = dialogSelection.contains(item.id)
        
        Button {
            if isChecked {
                dialogSelection.remove(item.id)
            } else {
                dialogSelection.insert(item.id)
            }
        } label: {
            HStack {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isChecked ? Color.accentColor : .secondary)
                    .imageScale(.large)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.displayName)
                        .foregroundStyle(.primary)
                    
                    Text(containerLabel(for: item))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Action Bar
    
    private var actionBar: some View {
        HStack(spacing: 16) {
            // Move button — removes from current containers then assigns to target
            Menu {
                Button(NSLocalizedString("containerAssignment.unassigned", comment: "Unassigned")) {
                    performAction(.move, targetContainerID: nil)
                }
                Divider()

                ForEach(containers, id: \.id) { container in
                    Button(container.name) {
                        performAction(.move, targetContainerID: container.id)
                    }
                }
            } label: {
                Label(NSLocalizedString("containerAssignment.move", comment: "Move"),
                      systemImage: "arrow.right")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(dialogSelection.isEmpty)
            
            // Copy button — adds target while keeping existing assignments
            Menu {
                ForEach(containers, id: \.id) { container in
                    Button(container.name) {
                        performAction(.copy, targetContainerID: container.id)
                    }
                }
            } label: {
                Label(NSLocalizedString("containerAssignment.copy", comment: "Copy"),
                      systemImage: "doc.on.doc")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(dialogSelection.isEmpty || containers.isEmpty)
        }
    }
    
    // MARK: - Actions
    
    private enum ActionMode { case move, copy }
    
    private func performAction(_ mode: ActionMode, targetContainerID: UUID?) {
        for itemID in dialogSelection {
            switch mode {
            case .move:
                if let targetID = targetContainerID {
                    assignments[itemID] = [targetID]
                } else {
                    // Move to Unassigned = remove from all containers
                    assignments[itemID] = []
                }
            case .copy:
                if let targetID = targetContainerID {
                    assignments[itemID, default: []].insert(targetID)
                }
                // Copy without a target is a no-op
            }
        }

        switch mode {
        case .move:
            // Move is a complete action: commit immediately and close the sheet.
            applyChanges()
            dismiss()
        case .copy:
            // Keep dialog open for additional copy actions.
            dialogSelection.removeAll()
        }
    }
    
    // MARK: - Helpers
    
    /// Human-readable container list for one item
    private func containerLabel(for item: Item) -> String {
        let ids = assignments[item.id] ?? []
        if ids.isEmpty {
            return NSLocalizedString("containerAssignment.unassigned", comment: "Unassigned")
        }
        let names = containers
            .filter { ids.contains($0.id) }
            .map(\.name)
        return names.joined(separator: ", ")
    }
    
    /// Populate state on first appear
    private func initializeState() {
        // All items checked by default
        dialogSelection = Set(selectedItems.map(\.id))
        
        // Build assignment map from the item's direct relationship
        var initial: [UUID: Set<UUID>] = [:]
        for item in selectedItems {
            initial[item.id] = currentContainerIDs(item)
        }
        assignments = initial
        originalAssignments = initial
    }
    
    /// Diff original vs current assignments and call add/remove callbacks
    private func applyChanges() {
        guard !didApply else { return }
        didApply = true
        
        for item in selectedItems {
            let original = originalAssignments[item.id] ?? []
            let current = assignments[item.id] ?? []
            
            // Remove from containers no longer assigned
            for containerID in original.subtracting(current) {
                if let container = containers.first(where: { $0.id == containerID }) {
                    container.removeItem(item)
                }
            }
            
            // Add to newly assigned containers
            for containerID in current.subtracting(original) {
                if let container = containers.first(where: { $0.id == containerID }) {
                    container.addItem(item)
                }
            }
        }
        
        onSave()
    }
}

// MARK: - Factory Methods for Each Project Type

extension ContainerAssignmentView where Item == TextFile {
    
    /// Create a container assignment view for Poetry projects (Collections)
    static func forPoetryCollections(
        project: Project,
        selectedFiles: [TextFile],
        modelContext: ModelContext
    ) -> ContainerAssignmentView<TextFile> {
        let descriptor = FetchDescriptor<PoetryCollection>()
        let collections = ((try? modelContext.fetch(descriptor)) ?? [])
            .filter { $0.project?.id == project.id }
            .sorted { lhs, rhs in
                let lhsOrder = lhs.userOrder ?? Int.max
                let rhsOrder = rhs.userOrder ?? Int.max
                if lhsOrder != rhsOrder { return lhsOrder < rhsOrder }
                return (lhs.name ?? "").localizedCaseInsensitiveCompare(rhs.name ?? "") == .orderedAscending
            }
        let collectionLinks = (try? modelContext.fetch(FetchDescriptor<TextFileCollectionLink>())) ?? []
        
        let descriptors = collections.map { collection in
            ContainerDescriptor<TextFile>(
                id: collection.id,
                name: collection.name ?? NSLocalizedString("poetry.collection.untitled", comment: "Untitled"),
                memberIDs: Set(
                    collectionLinks.compactMap { link in
                        (link.poetryCollectionID == collection.id || link.poetryCollection?.id == collection.id)
                            ? (link.textFileID ?? link.textFile?.id)
                            : nil
                    }
                ),
                addItem: { file in
                    file.addToPoetryCollection(collection)
                },
                removeItem: { file in
                    file.removeFromPoetryCollection(collection)
                }
            )
        }
        
        return ContainerAssignmentView<TextFile>(
            containerTypeName: NSLocalizedString("poetry.collection", comment: "Collection"),
            selectedItems: selectedFiles,
            containers: descriptors,
            currentContainerIDs: { file in
                Set(
                    collectionLinks.compactMap { link in
                        (link.textFileID == file.id || link.textFile?.id == file.id)
                            ? (link.poetryCollectionID ?? link.poetryCollection?.id)
                            : nil
                    }
                )
            },
            onSave: {
                WriteCoalescer.shared?.requestSave(reason: "container-assignment-poetry-save")
                WriteCoalescer.shared?.flush()
                NotificationCenter.default.post(name: .poetryCollectionMembershipDidChange, object: nil)
            }
        )
    }
    
    /// Create a container assignment view for Prose projects (Sections)
    static func forProseSections(
        project: Project,
        selectedFiles: [TextFile],
        modelContext: ModelContext
    ) -> ContainerAssignmentView<TextFile> {
        let sections = (project.sections ?? [])
            .sorted { ($0.userOrder ?? 0) < ($1.userOrder ?? 0) }
        
        let descriptors = sections.map { section in
            ContainerDescriptor<TextFile>(
                id: section.id,
                name: section.name ?? NSLocalizedString("prose.untitled", comment: "Untitled"),
                memberIDs: Set((section.textFiles ?? []).map(\.id)),
                addItem: { file in
                    file.addToSection(section)
                },
                removeItem: { file in
                    file.removeFromSection(section)
                }
            )
        }
        
        return ContainerAssignmentView<TextFile>(
            containerTypeName: NSLocalizedString("prose.section", comment: "Section"),
            selectedItems: selectedFiles,
            containers: descriptors,
            currentContainerIDs: { file in
                Set((file.sections ?? []).map(\.id))
            },
            onSave: {
                WriteCoalescer.shared?.requestSave(reason: "container-assignment-prose-sections")
                WriteCoalescer.shared?.flush()
            }
        )
    }
}

extension ContainerAssignmentView where Item == StoryScene {
    
    /// Create a container assignment view for Drama projects (Acts)
    static func forActs(
        project: Project,
        selectedScenes: [StoryScene],
        modelContext: ModelContext
    ) -> ContainerAssignmentView<StoryScene> {
        let acts = (project.acts ?? [])
            .sorted { ($0.userOrder ?? 0) < ($1.userOrder ?? 0) }
        
        let descriptors = acts.map { act in
            ContainerDescriptor<StoryScene>(
                id: act.id,
                name: act.name ?? NSLocalizedString("drama.untitled", comment: "Untitled"),
                memberIDs: Set((act.scenes ?? []).map(\.id)),
                addItem: { scene in
                    scene.addToAct(act)
                },
                removeItem: { scene in
                    scene.removeFromAct(act)
                }
            )
        }
        
        return ContainerAssignmentView<StoryScene>(
            containerTypeName: NSLocalizedString("drama.act", comment: "Act"),
            selectedItems: selectedScenes,
            containers: descriptors,
            currentContainerIDs: { scene in
                Set((scene.acts ?? []).map(\.id))
            },
            onSave: {
                WriteCoalescer.shared?.requestSave(reason: "container-assignment-acts")
                WriteCoalescer.shared?.flush()
            }
        )
    }
    
    /// Create a container assignment view for Fiction projects (Chapters/Stories)
    static func forChapters(
        project: Project,
        selectedScenes: [StoryScene],
        modelContext: ModelContext
    ) -> ContainerAssignmentView<StoryScene> {
        if project.fictionClass == .verseNovel {
            return forBooks(project: project, selectedScenes: selectedScenes, modelContext: modelContext)
        }

        let chapters = (project.chapters ?? [])
            .sorted { ($0.userOrder ?? 0) < ($1.userOrder ?? 0) }
        
        let fictionClass = project.fictionClass ?? .novel
        let containerName: String
        switch fictionClass {
        case .novel:
            containerName = NSLocalizedString("fiction.chapter", comment: "Chapter")
        case .shortFiction:
            containerName = NSLocalizedString("fiction.story", comment: "Story")
        case .verseNovel:
            containerName = NSLocalizedString("fiction.book", comment: "Book")
        }
        
        let descriptors = chapters.map { chapter in
            ContainerDescriptor<StoryScene>(
                id: chapter.id,
                name: chapter.name ?? NSLocalizedString("fiction.untitled", comment: "Untitled"),
                memberIDs: Set((chapter.scenes ?? []).map(\.id)),
                addItem: { scene in
                    scene.addToChapter(chapter)
                },
                removeItem: { scene in
                    scene.removeFromChapter(chapter)
                }
            )
        }
        
        return ContainerAssignmentView<StoryScene>(
            containerTypeName: containerName,
            selectedItems: selectedScenes,
            containers: descriptors,
            currentContainerIDs: { scene in
                Set((scene.chapters ?? []).map(\.id))
            },
            onSave: {
                WriteCoalescer.shared?.requestSave(reason: "container-assignment-chapters")
                WriteCoalescer.shared?.flush()
            }
        )
    }
    
    /// Create a container assignment view for Verse Novel projects (Books)
    static func forBooks(
        project: Project,
        selectedScenes: [StoryScene],
        modelContext: ModelContext
    ) -> ContainerAssignmentView<StoryScene> {
        let books = (project.books ?? [])
            .sorted { ($0.userOrder ?? 0) < ($1.userOrder ?? 0) }
        
        let descriptors = books.map { book in
            ContainerDescriptor<StoryScene>(
                id: book.id,
                name: book.name ?? NSLocalizedString("fiction.untitled", comment: "Untitled"),
                memberIDs: Set((book.scenes ?? []).map(\.id)),
                addItem: { scene in
                    scene.addToBook(book)
                },
                removeItem: { scene in
                    scene.removeFromBook(book)
                }
            )
        }
        
        return ContainerAssignmentView<StoryScene>(
            containerTypeName: NSLocalizedString("fiction.book", comment: "Book"),
            selectedItems: selectedScenes,
            containers: descriptors,
            currentContainerIDs: { scene in
                Set((scene.books ?? []).map(\.id))
            },
            onSave: {
                WriteCoalescer.shared?.requestSave(reason: "container-assignment-books")
                WriteCoalescer.shared?.flush()
            }
        )
    }
}