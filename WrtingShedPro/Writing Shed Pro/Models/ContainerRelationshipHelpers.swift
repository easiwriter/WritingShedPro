//
//  ContainerRelationshipHelpers.swift
//  Writing Shed Pro
//
//  Convenience methods for many-to-many container relationships.
//  TextFile ↔ PoetryCollection, TextFile ↔ ProseSection
//  StoryScene ↔ Chapter, StoryScene ↔ Act, StoryScene ↔ Book
//

import Foundation

// MARK: - TextFile Container Helpers

extension TextFile {
    
    // MARK: Poetry Collection
    
    /// Whether this file belongs to the given poetry collection
    func isInPoetryCollection(_ collection: PoetryCollection) -> Bool {
        poetryCollections?.contains(where: { $0.id == collection.id }) ?? false
    }
    
    /// Add this file to a poetry collection (no-op if already a member)
    func addToPoetryCollection(_ collection: PoetryCollection) {
        if poetryCollections == nil { poetryCollections = [] }
        guard !isInPoetryCollection(collection) else { return }
        poetryCollections?.append(collection)
    }
    
    /// Remove this file from a specific poetry collection
    func removeFromPoetryCollection(_ collection: PoetryCollection) {
        poetryCollections?.removeAll(where: { $0.id == collection.id })
    }
    
    /// Remove this file from all poetry collections
    func removeFromAllPoetryCollections() {
        poetryCollections = []
    }
    
    /// The first (or only) poetry collection — backwards-compat convenience
    var poetryCollection: PoetryCollection? {
        get { poetryCollections?.first }
        set {
            if let c = newValue {
                poetryCollections = [c]
            } else {
                poetryCollections = []
            }
        }
    }
    
    // MARK: Prose Section
    
    /// Whether this file belongs to the given prose section
    func isInSection(_ section: ProseSection) -> Bool {
        sections?.contains(where: { $0.id == section.id }) ?? false
    }
    
    /// Add this file to a prose section (no-op if already a member)
    func addToSection(_ section: ProseSection) {
        if sections == nil { sections = [] }
        guard !isInSection(section) else { return }
        sections?.append(section)
    }
    
    /// Remove this file from a specific prose section
    func removeFromSection(_ section: ProseSection) {
        sections?.removeAll(where: { $0.id == section.id })
    }
    
    /// Remove this file from all prose sections
    func removeFromAllSections() {
        sections = []
    }
    
    /// The first (or only) section — backwards-compat convenience
    var section: ProseSection? {
        get { sections?.first }
        set {
            if let s = newValue {
                sections = [s]
            } else {
                sections = []
            }
        }
    }
}

// MARK: - StoryScene Container Helpers

extension StoryScene {
    
    // MARK: Chapter
    
    /// Whether this scene belongs to the given chapter
    func isInChapter(_ chapter: Chapter) -> Bool {
        chapters?.contains(where: { $0.id == chapter.id }) ?? false
    }
    
    /// Add this scene to a chapter (no-op if already a member)
    func addToChapter(_ chapter: Chapter) {
        if chapters == nil { chapters = [] }
        guard !isInChapter(chapter) else { return }
        chapters?.append(chapter)
    }
    
    /// Remove this scene from a specific chapter
    func removeFromChapter(_ chapter: Chapter) {
        chapters?.removeAll(where: { $0.id == chapter.id })
    }
    
    /// Remove this scene from all chapters
    func removeFromAllChapters() {
        chapters = []
    }
    
    /// The first (or only) chapter — backwards-compat convenience
    var chapter: Chapter? {
        get { chapters?.first }
        set {
            if let c = newValue {
                chapters = [c]
            } else {
                chapters = []
            }
        }
    }
    
    // MARK: Act
    
    /// Whether this scene belongs to the given act
    func isInAct(_ act: Act) -> Bool {
        acts?.contains(where: { $0.id == act.id }) ?? false
    }
    
    /// Add this scene to an act (no-op if already a member)
    func addToAct(_ act: Act) {
        if acts == nil { acts = [] }
        guard !isInAct(act) else { return }
        acts?.append(act)
    }
    
    /// Remove this scene from a specific act
    func removeFromAct(_ act: Act) {
        acts?.removeAll(where: { $0.id == act.id })
    }
    
    /// Remove this scene from all acts
    func removeFromAllActs() {
        acts = []
    }
    
    /// The first (or only) act — backwards-compat convenience
    var act: Act? {
        get { acts?.first }
        set {
            if let a = newValue {
                acts = [a]
            } else {
                acts = []
            }
        }
    }
    
    // MARK: Book
    
    /// Whether this scene belongs to the given book
    func isInBook(_ book: Book) -> Bool {
        books?.contains(where: { $0.id == book.id }) ?? false
    }
    
    /// Add this scene to a book (no-op if already a member)
    func addToBook(_ book: Book) {
        if books == nil { books = [] }
        guard !isInBook(book) else { return }
        books?.append(book)
    }
    
    /// Remove this scene from a specific book
    func removeFromBook(_ book: Book) {
        books?.removeAll(where: { $0.id == book.id })
    }
    
    /// Remove this scene from all books
    func removeFromAllBooks() {
        books = []
    }
    
    /// The first (or only) book — backwards-compat convenience
    var book: Book? {
        get { books?.first }
        set {
            if let b = newValue {
                books = [b]
            } else {
                books = []
            }
        }
    }
}
