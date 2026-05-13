//
//  BodyMatterView.swift
//  Writing Shed Pro
//
//  Feature 036: Project Folder Revamp
//  Manages items in the Body Matter section of the Manuscript.
//  Users can add, remove, and reorder items from their source containers.
//

import SwiftUI
import SwiftData

/// A unified protocol for items that can appear in Body Matter.
/// All conforming types are @Model classes which already conform to Identifiable.
protocol BodyMatterItem {
    var id: UUID { get }
    var name: String? { get }
    var isInBodyMatter: Bool { get set }
    var bodyMatterOrder: Int? { get set }
}

// Conformances
extension PoetryCollection: BodyMatterItem {}
extension ProseSection: BodyMatterItem {}
extension Chapter: BodyMatterItem {}
extension StoryScene: BodyMatterItem {}
extension Book: BodyMatterItem {}
extension Act: BodyMatterItem {}

/// View for managing the Body Matter content of a manuscript.
/// Allows adding, removing, and reordering items based on project type.
struct BodyMatterView: View {
    let project: Project
    @Environment(\.modelContext) private var modelContext
    
    @State private var showAddItemSheet = false
    @State private var showNoItemsAlert = false
    @State private var editMode: EditMode = .inactive
    
    // MARK: - Body
    
    var body: some View {
        Group {
            if bodyMatterItems.isEmpty {
                emptyState
            } else {
                itemList
            }
        }
        .navigationTitle(NSLocalizedString("bodyMatter.title", comment: "Body Matter"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    if !bodyMatterItems.isEmpty {
                        Button {
                            withAnimation {
                                editMode = editMode == .active ? .inactive : .active
                            }
                        } label: {
                            Text(editMode == .active
                                 ? NSLocalizedString("button.done", comment: "Done")
                                 : NSLocalizedString("button.edit", comment: "Edit"))
                        }
                    }
                    Button {
                        if availableItems.isEmpty {
                            showNoItemsAlert = true
                        } else {
                            showAddItemSheet = true
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showAddItemSheet) {
            addItemSheet
        }
        .alert(
            NSLocalizedString("bodyMatter.noItems.title", comment: "No Items Available"),
            isPresented: $showNoItemsAlert
        ) {
            Button(NSLocalizedString("button.ok", comment: "OK"), role: .cancel) { }
        } message: {
            if bodyMatterItems.isEmpty {
                Text(String(format: NSLocalizedString("bodyMatter.noItems.message", comment: "Create %@ first, then add them to Body Matter."), itemTypeName))
            } else {
                Text(String(format: NSLocalizedString("bodyMatter.noItems.messageAllAdded", comment: "Create another item first, then add it to Body Matter."), itemTypeName))
            }
        }
    }
    
    // MARK: - Item List
    
    @ViewBuilder
    private var itemList: some View {
        List {
            ForEach(bodyMatterItems, id: \.id) { item in
                NavigationLink {
                    destinationView(for: item)
                } label: {
                    HStack {
                        Image(systemName: iconForItem)
                            .foregroundStyle(.secondary)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name ?? NSLocalizedString("bodyMatter.untitled", comment: "Untitled"))
                                .font(.body)

                            Text(subtitleForItem(item))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .onDelete(perform: removeItems)
            .onMove(perform: moveItems)
        }
        .listStyle(.plain)
        .environment(\.editMode, $editMode)
    }
    
    // MARK: - Navigation Destination
    
    /// Returns the appropriate detail view for a body matter item based on project type
    @ViewBuilder
    private func destinationView(for item: any BodyMatterItem) -> some View {
        switch project.type {
        case .poetry:
            if let collection = item as? PoetryCollection {
                PoetryCollectionPoemsView(project: project, collection: collection)
            }
        case .prose:
            if let section = item as? ProseSection {
                ProseFilesView(project: project, section: section)
            }
        case .fiction:
            switch project.fictionClass {
            case .novel:
                if let chapter = item as? Chapter {
                    SceneListView(project: project, chapter: chapter)
                }
            case .shortFiction:
                if let scene = item as? StoryScene, let textFile = scene.textFile {
                    FileEditView(file: textFile)
                }
            case .verseNovel:
                if let book = item as? Book {
                    SceneListView(project: project, book: book)
                }
            case .none:
                EmptyView()
            }
        case .drama:
            if let act = item as? Act {
                SceneListView(project: project, act: act)
            }
        }
    }
    
    // MARK: - Empty State
    
    @ViewBuilder
    private var emptyState: some View {
        ContentUnavailableView {
            Label(NSLocalizedString("bodyMatter.empty.title", comment: "No Body Matter"),
                  systemImage: "doc.on.doc")
        } description: {
            Text(emptyStateDescription)
        } actions: {
            if !availableItems.isEmpty {
                Button(NSLocalizedString("bodyMatter.addItems", comment: "Add Items")) {
                    showAddItemSheet = true
                }
            }
        }
    }
    
    // MARK: - Add Item Sheet
    
    @ViewBuilder
    private var addItemSheet: some View {
        NavigationStack {
            List {
                ForEach(availableItems, id: \.id) { item in
                    Button {
                        addItemToBodyMatter(item)
                    } label: {
                        HStack {
                            Image(systemName: iconForItem)
                                .foregroundStyle(.blue)
                            Text(item.name ?? NSLocalizedString("bodyMatter.untitled", comment: "Untitled"))
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "plus.circle")
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }
            .navigationTitle(addItemTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("button.done", comment: "Done")) {
                        showAddItemSheet = false
                    }
                }
            }
        }
    }
    
    // MARK: - Data Access
    
    /// Items currently in Body Matter, sorted by bodyMatterOrder
    private var bodyMatterItems: [any BodyMatterItem] {
        switch project.type {
        case .poetry:
            return (project.poetryCollections ?? [])
                .filter { $0.isInBodyMatter }
                .sorted { ($0.bodyMatterOrder ?? Int.max) < ($1.bodyMatterOrder ?? Int.max) }
        case .prose:
            return (project.sections ?? [])
                .filter { $0.isInBodyMatter }
                .sorted { ($0.bodyMatterOrder ?? Int.max) < ($1.bodyMatterOrder ?? Int.max) }
        case .fiction:
            switch project.fictionClass {
            case .novel:
                return (project.chapters ?? [])
                    .filter { $0.isInBodyMatter }
                    .sorted { ($0.bodyMatterOrder ?? Int.max) < ($1.bodyMatterOrder ?? Int.max) }
            case .shortFiction:
                // Short Fiction: stories are top-level StoryScenes
                return (project.scenes ?? [])
                    .filter { $0.isInBodyMatter }
                    .sorted { ($0.bodyMatterOrder ?? Int.max) < ($1.bodyMatterOrder ?? Int.max) }
            case .verseNovel:
                return (project.books ?? [])
                    .filter { $0.isInBodyMatter }
                    .sorted { ($0.bodyMatterOrder ?? Int.max) < ($1.bodyMatterOrder ?? Int.max) }
            case .none:
                return []
            }
        case .drama:
            return (project.acts ?? [])
                .filter { $0.isInBodyMatter }
                .sorted { ($0.bodyMatterOrder ?? Int.max) < ($1.bodyMatterOrder ?? Int.max) }
        }
    }
    
    /// All source items (both in and not in Body Matter)
    private var allSourceItems: [any BodyMatterItem] {
        switch project.type {
        case .poetry:
            return project.poetryCollections ?? []
        case .prose:
            return project.sections ?? []
        case .fiction:
            switch project.fictionClass {
            case .novel:
                return project.chapters ?? []
            case .shortFiction:
                return project.scenes ?? []
            case .verseNovel:
                return project.books ?? []
            case .none:
                return []
            }
        case .drama:
            return project.acts ?? []
        }
    }
    
    /// Items available to add (not yet in Body Matter)
    private var availableItems: [any BodyMatterItem] {
        switch project.type {
        case .poetry:
            return (project.poetryCollections ?? [])
                .filter { !$0.isInBodyMatter }
                .sorted { ($0.userOrder ?? Int.max) < ($1.userOrder ?? Int.max) }
        case .prose:
            return (project.sections ?? [])
                .filter { !$0.isInBodyMatter }
                .sorted { ($0.userOrder ?? Int.max) < ($1.userOrder ?? Int.max) }
        case .fiction:
            switch project.fictionClass {
            case .novel:
                return (project.chapters ?? [])
                    .filter { !$0.isInBodyMatter }
                    .sorted { ($0.userOrder ?? Int.max) < ($1.userOrder ?? Int.max) }
            case .shortFiction:
                return (project.scenes ?? [])
                    .filter { !$0.isInBodyMatter }
                    .sorted { ($0.userOrder ?? Int.max) < ($1.userOrder ?? Int.max) }
            case .verseNovel:
                return (project.books ?? [])
                    .filter { !$0.isInBodyMatter }
                    .sorted { ($0.userOrder ?? Int.max) < ($1.userOrder ?? Int.max) }
            case .none:
                return []
            }
        case .drama:
            return (project.acts ?? [])
                .filter { !$0.isInBodyMatter }
                .sorted { ($0.userOrder ?? Int.max) < ($1.userOrder ?? Int.max) }
        }
    }
    
    // MARK: - Actions

    private func markBodyMatterAsExplicitlyManaged() {
        var settings = project.manuscriptSettings
        settings.useExplicitBodyMatter = true
        project.manuscriptSettings = settings
    }
    
    private func addItemToBodyMatter(_ item: any BodyMatterItem) {
        let nextOrder = (bodyMatterItems.map { $0.bodyMatterOrder ?? 0 }.max() ?? -1) + 1
        markBodyMatterAsExplicitlyManaged()
        
        // Use type-specific mutation since protocols can't mutate through existentials
        switch project.type {
        case .poetry:
            if let collection = item as? PoetryCollection {
                collection.isInBodyMatter = true
                collection.bodyMatterOrder = nextOrder
            }
        case .prose:
            if let section = item as? ProseSection {
                section.isInBodyMatter = true
                section.bodyMatterOrder = nextOrder
            }
        case .fiction:
            switch project.fictionClass {
            case .novel:
                if let chapter = item as? Chapter {
                    chapter.isInBodyMatter = true
                    chapter.bodyMatterOrder = nextOrder
                }
            case .shortFiction:
                if let scene = item as? StoryScene {
                    scene.isInBodyMatter = true
                    scene.bodyMatterOrder = nextOrder
                }
            case .verseNovel:
                if let book = item as? Book {
                    book.isInBodyMatter = true
                    book.bodyMatterOrder = nextOrder
                }
            case .none:
                break
            }
        case .drama:
            if let act = item as? Act {
                act.isInBodyMatter = true
                act.bodyMatterOrder = nextOrder
            }
        }
        
        project.modifiedDate = Date()
        try? modelContext.save()
    }
    
    private func removeItems(at offsets: IndexSet) {
        markBodyMatterAsExplicitlyManaged()
        let items = bodyMatterItems
        for index in offsets {
            let item = items[index]
            
            switch project.type {
            case .poetry:
                if let collection = item as? PoetryCollection {
                    collection.isInBodyMatter = false
                    collection.bodyMatterOrder = nil
                }
            case .prose:
                if let section = item as? ProseSection {
                    section.isInBodyMatter = false
                    section.bodyMatterOrder = nil
                }
            case .fiction:
                switch project.fictionClass {
                case .novel:
                    if let chapter = item as? Chapter {
                        chapter.isInBodyMatter = false
                        chapter.bodyMatterOrder = nil
                    }
                case .shortFiction:
                    if let scene = item as? StoryScene {
                        scene.isInBodyMatter = false
                        scene.bodyMatterOrder = nil
                    }
                case .verseNovel:
                    if let book = item as? Book {
                        book.isInBodyMatter = false
                        book.bodyMatterOrder = nil
                    }
                case .none:
                    break
                }
            case .drama:
                if let act = item as? Act {
                    act.isInBodyMatter = false
                    act.bodyMatterOrder = nil
                }
            }
        }
        
        // Renumber remaining items
        renumberBodyMatterItems()
        project.modifiedDate = Date()
        try? modelContext.save()
    }
    
    private func moveItems(from source: IndexSet, to destination: Int) {
        markBodyMatterAsExplicitlyManaged()
        // Moving is type-specific since we need to mutate the actual model objects
        switch project.type {
        case .poetry:
            var items = (project.poetryCollections ?? [])
                .filter { $0.isInBodyMatter }
                .sorted { ($0.bodyMatterOrder ?? Int.max) < ($1.bodyMatterOrder ?? Int.max) }
            items.move(fromOffsets: source, toOffset: destination)
            for (index, item) in items.enumerated() {
                item.bodyMatterOrder = index
            }
        case .prose:
            var items = (project.sections ?? [])
                .filter { $0.isInBodyMatter }
                .sorted { ($0.bodyMatterOrder ?? Int.max) < ($1.bodyMatterOrder ?? Int.max) }
            items.move(fromOffsets: source, toOffset: destination)
            for (index, item) in items.enumerated() {
                item.bodyMatterOrder = index
            }
        case .fiction:
            switch project.fictionClass {
            case .novel:
                var items = (project.chapters ?? [])
                    .filter { $0.isInBodyMatter }
                    .sorted { ($0.bodyMatterOrder ?? Int.max) < ($1.bodyMatterOrder ?? Int.max) }
                items.move(fromOffsets: source, toOffset: destination)
                for (index, item) in items.enumerated() {
                    item.bodyMatterOrder = index
                }
            case .shortFiction:
                var items = (project.scenes ?? [])
                    .filter { $0.isInBodyMatter }
                    .sorted { ($0.bodyMatterOrder ?? Int.max) < ($1.bodyMatterOrder ?? Int.max) }
                items.move(fromOffsets: source, toOffset: destination)
                for (index, item) in items.enumerated() {
                    item.bodyMatterOrder = index
                }
            case .verseNovel:
                var items = (project.books ?? [])
                    .filter { $0.isInBodyMatter }
                    .sorted { ($0.bodyMatterOrder ?? Int.max) < ($1.bodyMatterOrder ?? Int.max) }
                items.move(fromOffsets: source, toOffset: destination)
                for (index, item) in items.enumerated() {
                    item.bodyMatterOrder = index
                }
            case .none:
                break
            }
        case .drama:
            var items = (project.acts ?? [])
                .filter { $0.isInBodyMatter }
                .sorted { ($0.bodyMatterOrder ?? Int.max) < ($1.bodyMatterOrder ?? Int.max) }
            items.move(fromOffsets: source, toOffset: destination)
            for (index, item) in items.enumerated() {
                item.bodyMatterOrder = index
            }
        }
        
        project.modifiedDate = Date()
        try? modelContext.save()
    }
    
    private func renumberBodyMatterItems() {
        switch project.type {
        case .poetry:
            let items = (project.poetryCollections ?? [])
                .filter { $0.isInBodyMatter }
                .sorted { ($0.bodyMatterOrder ?? Int.max) < ($1.bodyMatterOrder ?? Int.max) }
            for (index, item) in items.enumerated() {
                item.bodyMatterOrder = index
            }
        case .prose:
            let items = (project.sections ?? [])
                .filter { $0.isInBodyMatter }
                .sorted { ($0.bodyMatterOrder ?? Int.max) < ($1.bodyMatterOrder ?? Int.max) }
            for (index, item) in items.enumerated() {
                item.bodyMatterOrder = index
            }
        case .fiction:
            switch project.fictionClass {
            case .novel:
                let items = (project.chapters ?? [])
                    .filter { $0.isInBodyMatter }
                    .sorted { ($0.bodyMatterOrder ?? Int.max) < ($1.bodyMatterOrder ?? Int.max) }
                for (index, item) in items.enumerated() {
                    item.bodyMatterOrder = index
                }
            case .shortFiction:
                let items = (project.scenes ?? [])
                    .filter { $0.isInBodyMatter }
                    .sorted { ($0.bodyMatterOrder ?? Int.max) < ($1.bodyMatterOrder ?? Int.max) }
                for (index, item) in items.enumerated() {
                    item.bodyMatterOrder = index
                }
            case .verseNovel:
                let items = (project.books ?? [])
                    .filter { $0.isInBodyMatter }
                    .sorted { ($0.bodyMatterOrder ?? Int.max) < ($1.bodyMatterOrder ?? Int.max) }
                for (index, item) in items.enumerated() {
                    item.bodyMatterOrder = index
                }
            case .none:
                break
            }
        case .drama:
            let items = (project.acts ?? [])
                .filter { $0.isInBodyMatter }
                .sorted { ($0.bodyMatterOrder ?? Int.max) < ($1.bodyMatterOrder ?? Int.max) }
            for (index, item) in items.enumerated() {
                item.bodyMatterOrder = index
            }
        }
    }
    
    // MARK: - Display Helpers
    
    private var iconForItem: String {
        switch project.type {
        case .poetry: return "text.book.closed"
        case .prose: return "doc.text"
        case .fiction:
            switch project.fictionClass {
            case .novel: return "bookmark"
            case .shortFiction: return "doc.text"
            case .verseNovel: return "book"
            case .none: return "doc.text"
            }
        case .drama: return "theatermasks"
        }
    }
    
    private var itemTypeName: String {
        switch project.type {
        case .poetry: return NSLocalizedString("bodyMatter.type.collections", comment: "Collections")
        case .prose: return NSLocalizedString("bodyMatter.type.sections", comment: "Sections")
        case .fiction:
            switch project.fictionClass {
            case .novel: return NSLocalizedString("bodyMatter.type.chapters", comment: "Chapters")
            case .shortFiction: return NSLocalizedString("bodyMatter.type.stories", comment: "Stories")
            case .verseNovel: return NSLocalizedString("bodyMatter.type.books", comment: "Books")
            case .none: return ""
            }
        case .drama: return NSLocalizedString("bodyMatter.type.acts", comment: "Acts")
        }
    }
    
    private var addItemTitle: String {
        String(format: NSLocalizedString("bodyMatter.add.title", comment: "Add %@"), itemTypeName)
    }
    
    private var emptyStateDescription: String {
        if allSourceItems.isEmpty {
            return String(format: NSLocalizedString("bodyMatter.empty.noSource", comment: "Create %@ first, then add them here."), itemTypeName)
        }
        return String(format: NSLocalizedString("bodyMatter.empty.description", comment: "Add %@ to include them in the manuscript body."), itemTypeName)
    }
    
    private func subtitleForItem(_ item: any BodyMatterItem) -> String {
        let wordsLabel = localizedWordCount(wordCountForItem(item))

        switch project.type {
        case .poetry:
            if let collection = item as? PoetryCollection {
                let count = collection.textFiles?.count ?? 0
                let structure = String(format: NSLocalizedString("bodyMatter.subtitle.poems", comment: "%d poems"), count)
                return "\(wordsLabel) • \(structure)"
            }
        case .prose:
            if let section = item as? ProseSection {
                let count = section.textFiles?.count ?? 0
                let structure = String(format: NSLocalizedString("bodyMatter.subtitle.files", comment: "%d files"), count)
                return "\(wordsLabel) • \(structure)"
            }
        case .fiction:
            switch project.fictionClass {
            case .novel:
                if let chapter = item as? Chapter {
                    let count = chapter.scenes?.count ?? 0
                    let structure = String(format: NSLocalizedString("bodyMatter.subtitle.scenes", comment: "%d scenes"), count)
                    return "\(wordsLabel) • \(structure)"
                }
            case .shortFiction:
                if let scene = item as? StoryScene {
                    let hasContent = scene.textFile != nil
                    let structure = hasContent
                        ? NSLocalizedString("bodyMatter.subtitle.hasContent", comment: "Has content")
                        : NSLocalizedString("bodyMatter.subtitle.empty", comment: "Empty")
                    return "\(wordsLabel) • \(structure)"
                }
            case .verseNovel:
                if let book = item as? Book {
                    let count = book.scenes?.count ?? 0
                    let structure = String(format: NSLocalizedString("bodyMatter.subtitle.episodes", comment: "%d episodes"), count)
                    return "\(wordsLabel) • \(structure)"
                }
            case .none:
                break
            }
        case .drama:
            if let act = item as? Act {
                let count = act.scenes?.count ?? 0
                let structure = String(format: NSLocalizedString("bodyMatter.subtitle.scenes", comment: "%d scenes"), count)
                return "\(wordsLabel) • \(structure)"
            }
        }
        return wordsLabel
    }

    private func localizedWordCount(_ count: Int) -> String {
        let key = count == 1 ? "common.wordCountSingularFormat" : "common.wordCountPluralFormat"
        return String(format: NSLocalizedString(key, comment: "Word count format"), count)
    }

    private func wordCountForItem(_ item: any BodyMatterItem) -> Int {
        switch project.type {
        case .poetry:
            if let collection = item as? PoetryCollection {
                return (collection.textFiles ?? []).reduce(0) { $0 + wordCount(for: $1) }
            }
        case .prose:
            if let section = item as? ProseSection {
                return (section.textFiles ?? []).reduce(0) { $0 + wordCount(for: $1) }
            }
        case .fiction:
            switch project.fictionClass {
            case .novel:
                if let chapter = item as? Chapter {
                    return (chapter.scenes ?? [])
                        .compactMap { $0.textFile }
                        .reduce(0) { $0 + wordCount(for: $1) }
                }
            case .shortFiction:
                if let scene = item as? StoryScene {
                    return scene.textFile.map(wordCount(for:)) ?? 0
                }
            case .verseNovel:
                if let book = item as? Book {
                    return (book.scenes ?? [])
                        .compactMap { $0.textFile }
                        .reduce(0) { $0 + wordCount(for: $1) }
                }
            case .none:
                return 0
            }
        case .drama:
            if let act = item as? Act {
                return (act.scenes ?? [])
                    .compactMap { $0.textFile }
                    .reduce(0) { $0 + wordCount(for: $1) }
            }
        }
        return 0
    }

    private func wordCount(for file: TextFile) -> Int {
        let content = file.currentVersion?.content ?? ""
        return content
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .count
    }
}
