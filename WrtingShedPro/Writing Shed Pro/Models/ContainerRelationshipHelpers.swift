//
//  ContainerRelationshipHelpers.swift
//  Writing Shed Pro
//
//  Convenience methods for many-to-many container relationships.
//  All many-to-many relationships use join tables for CloudKit compatibility.
//  TextFile ↔ PoetryCollection, TextFile ↔ ProseSection
//  StoryScene ↔ Chapter, StoryScene ↔ Act, StoryScene ↔ Book
//

import Foundation

// MARK: - TextFile Container Helpers

extension TextFile {
    
    // MARK: Poetry Collection
    
    /// Whether this file belongs to the given poetry collection
    func isInPoetryCollection(_ collection: PoetryCollection) -> Bool {
        poetryCollectionLinks?.contains(where: { $0.poetryCollection?.id == collection.id }) ?? false
    }
    
    /// Add this file to a poetry collection (no-op if already a member)
    func addToPoetryCollection(_ collection: PoetryCollection) {
        guard !isInPoetryCollection(collection) else { return }
        let link = TextFileCollectionLink(textFile: self, poetryCollection: collection)
        if poetryCollectionLinks == nil { poetryCollectionLinks = [] }
        poetryCollectionLinks?.append(link)
    }
    
    /// Remove this file from a specific poetry collection
    func removeFromPoetryCollection(_ collection: PoetryCollection) {
        guard let links = poetryCollectionLinks else { return }
        for link in links where link.poetryCollection?.id == collection.id {
            modelContext?.delete(link)
        }
        poetryCollectionLinks?.removeAll(where: { $0.poetryCollection?.id == collection.id })
    }
    
    /// Remove this file from all poetry collections
    func removeFromAllPoetryCollections() {
        for link in poetryCollectionLinks ?? [] { modelContext?.delete(link) }
        poetryCollectionLinks = []
    }
    
    /// The first (or only) poetry collection — backwards-compat convenience
    var poetryCollection: PoetryCollection? {
        get { poetryCollections?.first }
        set {
            removeFromAllPoetryCollections()
            if let c = newValue {
                addToPoetryCollection(c)
            }
        }
    }
    
    // MARK: Prose Section
    
    /// Whether this file belongs to the given prose section
    func isInSection(_ section: ProseSection) -> Bool {
        sectionLinks?.contains(where: { $0.section?.id == section.id }) ?? false
    }
    
    /// Add this file to a prose section (no-op if already a member)
    func addToSection(_ section: ProseSection) {
        guard !isInSection(section) else { return }
        let link = TextFileSectionLink(textFile: self, section: section)
        if sectionLinks == nil { sectionLinks = [] }
        sectionLinks?.append(link)
    }
    
    /// Remove this file from a specific prose section
    func removeFromSection(_ section: ProseSection) {
        guard let links = sectionLinks else { return }
        for link in links where link.section?.id == section.id {
            modelContext?.delete(link)
        }
        sectionLinks?.removeAll(where: { $0.section?.id == section.id })
    }
    
    /// Remove this file from all prose sections
    func removeFromAllSections() {
        for link in sectionLinks ?? [] { modelContext?.delete(link) }
        sectionLinks = []
    }
    
    /// The first (or only) section — backwards-compat convenience
    var section: ProseSection? {
        get { sections?.first }
        set {
            removeFromAllSections()
            if let s = newValue {
                addToSection(s)
            }
        }
    }
}

// MARK: - StoryScene Container Helpers

extension StoryScene {
    
    // MARK: Chapter
    
    /// Whether this scene belongs to the given chapter
    func isInChapter(_ chapter: Chapter) -> Bool {
        chapterLinks?.contains(where: { $0.chapter?.id == chapter.id }) ?? false
    }
    
    /// Add this scene to a chapter (no-op if already a member)
    func addToChapter(_ chapter: Chapter) {
        guard !isInChapter(chapter) else { return }
        let link = SceneChapterLink(scene: self, chapter: chapter)
        if chapterLinks == nil { chapterLinks = [] }
        chapterLinks?.append(link)
    }
    
    /// Remove this scene from a specific chapter
    func removeFromChapter(_ chapter: Chapter) {
        guard let links = chapterLinks else { return }
        for link in links where link.chapter?.id == chapter.id {
            modelContext?.delete(link)
        }
        chapterLinks?.removeAll(where: { $0.chapter?.id == chapter.id })
    }
    
    /// Remove this scene from all chapters
    func removeFromAllChapters() {
        for link in chapterLinks ?? [] { modelContext?.delete(link) }
        chapterLinks = []
    }
    
    /// The first (or only) chapter — backwards-compat convenience
    var chapter: Chapter? {
        get { chapters?.first }
        set {
            removeFromAllChapters()
            if let c = newValue {
                addToChapter(c)
            }
        }
    }
    
    // MARK: Act
    
    /// Whether this scene belongs to the given act
    func isInAct(_ act: Act) -> Bool {
        actLinks?.contains(where: { $0.act?.id == act.id }) ?? false
    }
    
    /// Add this scene to an act (no-op if already a member)
    func addToAct(_ act: Act) {
        guard !isInAct(act) else { return }
        let link = SceneActLink(scene: self, act: act)
        if actLinks == nil { actLinks = [] }
        actLinks?.append(link)
    }
    
    /// Remove this scene from a specific act
    func removeFromAct(_ act: Act) {
        guard let links = actLinks else { return }
        for link in links where link.act?.id == act.id {
            modelContext?.delete(link)
        }
        actLinks?.removeAll(where: { $0.act?.id == act.id })
    }
    
    /// Remove this scene from all acts
    func removeFromAllActs() {
        for link in actLinks ?? [] { modelContext?.delete(link) }
        actLinks = []
    }
    
    /// The first (or only) act — backwards-compat convenience
    var act: Act? {
        get { acts?.first }
        set {
            removeFromAllActs()
            if let a = newValue {
                addToAct(a)
            }
        }
    }
    
    // MARK: Book
    
    /// Whether this scene belongs to the given book
    func isInBook(_ book: Book) -> Bool {
        bookLinks?.contains(where: { $0.book?.id == book.id }) ?? false
    }
    
    /// Add this scene to a book (no-op if already a member)
    func addToBook(_ book: Book) {
        guard !isInBook(book) else { return }
        let link = SceneBookLink(scene: self, book: book)
        if bookLinks == nil { bookLinks = [] }
        bookLinks?.append(link)
    }
    
    /// Remove this scene from a specific book
    func removeFromBook(_ book: Book) {
        guard let links = bookLinks else { return }
        for link in links where link.book?.id == book.id {
            modelContext?.delete(link)
        }
        bookLinks?.removeAll(where: { $0.book?.id == book.id })
    }
    
    /// Remove this scene from all books
    func removeFromAllBooks() {
        for link in bookLinks ?? [] { modelContext?.delete(link) }
        bookLinks = []
    }
    
    /// The first (or only) book — backwards-compat convenience
    var book: Book? {
        get { books?.first }
        set {
            removeFromAllBooks()
            if let b = newValue {
                addToBook(b)
            }
        }
    }
}
