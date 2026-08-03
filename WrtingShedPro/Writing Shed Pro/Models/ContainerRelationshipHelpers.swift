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
import SwiftData

// MARK: - TextFile Container Helpers

extension TextFile {
    
    // MARK: Poetry Collection
    
    /// Whether this file belongs to the given poetry collection
    func isInPoetryCollection(_ collection: PoetryCollection) -> Bool {
        if poetryCollectionLinks?.contains(where: { $0.poetryCollectionID == collection.id || $0.poetryCollection?.id == collection.id }) == true {
            return true
        }

        guard let context = modelContext else { return false }
        let descriptor = FetchDescriptor<TextFileCollectionLink>()
        let links = (try? context.fetch(descriptor)) ?? []
        return links.contains { link in
            (link.textFileID == id || link.textFile?.id == id) &&
            (link.poetryCollectionID == collection.id || link.poetryCollection?.id == collection.id)
        }
    }
    
    /// Add this file to a poetry collection (no-op if already a member)
    func addToPoetryCollection(_ collection: PoetryCollection) {
        guard !isInPoetryCollection(collection) else { return }
        let link = TextFileCollectionLink(textFileID: id, poetryCollectionID: collection.id)
        modelContext?.insert(link)
        modifiedDate = Date()
        collection.modifiedDate = Date()
    }
    
    /// Remove this file from a specific poetry collection
    func removeFromPoetryCollection(_ collection: PoetryCollection) {
        let links = poetryCollectionLinks ?? []
        let removedLinkIDs = Set(
            links
                .filter { $0.poetryCollectionID == collection.id || $0.poetryCollection?.id == collection.id }
                .map { $0.id }
        )
        let contextLinks: [TextFileCollectionLink]
        if let context = modelContext {
            contextLinks = (try? context.fetch(FetchDescriptor<TextFileCollectionLink>())) ?? []
        } else {
            contextLinks = []
        }
        let collectionSideRemovedLinkIDs = Set(
            contextLinks
                .filter { ($0.textFileID == id || $0.textFile?.id == id) && ($0.poetryCollectionID == collection.id || $0.poetryCollection?.id == collection.id) }
                .map { $0.id }
        )

        for link in links where link.poetryCollectionID == collection.id || link.poetryCollection?.id == collection.id {
            modelContext?.delete(link)
        }
        for link in contextLinks where (link.textFileID == id || link.textFile?.id == id) && (link.poetryCollectionID == collection.id || link.poetryCollection?.id == collection.id) && !removedLinkIDs.contains(link.id) {
            modelContext?.delete(link)
        }

        if !removedLinkIDs.isEmpty || !collectionSideRemovedLinkIDs.isEmpty {
            modifiedDate = Date()
            collection.modifiedDate = Date()
        }
    }
    
    /// Remove this file from all poetry collections
    func removeFromAllPoetryCollections() {
        guard let context = modelContext else {
            poetryCollectionLinks = []
            modifiedDate = Date()
            return
        }

        let contextLinks = (try? context.fetch(FetchDescriptor<TextFileCollectionLink>())) ?? []
        let matchingLinks = contextLinks.filter { $0.resolvedTextFileID == id }

        for link in matchingLinks {
            if let collection = link.poetryCollection {
                collection.modifiedDate = Date()
            }
            context.delete(link)
        }
        poetryCollectionLinks = []
        modifiedDate = Date()
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
        modelContext?.insert(link)
        if sectionLinks == nil { sectionLinks = [] }
        sectionLinks?.append(link)
        section.modifiedDate = Date()
    }
    
    /// Remove this file from a specific prose section
    func removeFromSection(_ section: ProseSection) {
        guard let links = sectionLinks else { return }
        for link in links where link.section?.id == section.id {
            modelContext?.delete(link)
        }
        sectionLinks?.removeAll(where: { $0.section?.id == section.id })
        section.modifiedDate = Date()
    }
    
    /// Remove this file from all prose sections
    func removeFromAllSections() {
        for link in sectionLinks ?? [] {
            modelContext?.delete(link)
            if let section = link.section {
                section.modifiedDate = Date()
            }
        }
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
        modelContext?.insert(link)
        if chapterLinks == nil { chapterLinks = [] }
        chapterLinks?.append(link)
        chapter.modifiedDate = Date()
    }
    
    /// Remove this scene from a specific chapter
    func removeFromChapter(_ chapter: Chapter) {
        guard let links = chapterLinks else { return }
        for link in links where link.chapter?.id == chapter.id {
            modelContext?.delete(link)
        }
        chapterLinks?.removeAll(where: { $0.chapter?.id == chapter.id })
        chapter.modifiedDate = Date()
    }
    
    /// Remove this scene from all chapters
    func removeFromAllChapters() {
        for link in chapterLinks ?? [] {
            modelContext?.delete(link)
            if let chapter = link.chapter {
                chapter.modifiedDate = Date()
            }
        }
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
        modelContext?.insert(link)
        if actLinks == nil { actLinks = [] }
        actLinks?.append(link)
        act.modifiedDate = Date()
    }
    
    /// Remove this scene from a specific act
    func removeFromAct(_ act: Act) {
        guard let links = actLinks else { return }
        for link in links where link.act?.id == act.id {
            modelContext?.delete(link)
        }
        actLinks?.removeAll(where: { $0.act?.id == act.id })
        act.modifiedDate = Date()
    }
    
    /// Remove this scene from all acts
    func removeFromAllActs() {
        for link in actLinks ?? [] {
            modelContext?.delete(link)
            if let act = link.act {
                act.modifiedDate = Date()
            }
        }
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
        modelContext?.insert(link)
        if bookLinks == nil { bookLinks = [] }
        bookLinks?.append(link)
        book.modifiedDate = Date()
    }
    
    /// Remove this scene from a specific book
    func removeFromBook(_ book: Book) {
        guard let links = bookLinks else { return }
        for link in links where link.book?.id == book.id {
            modelContext?.delete(link)
        }
        bookLinks?.removeAll(where: { $0.book?.id == book.id })
        book.modifiedDate = Date()
    }
    
    /// Remove this scene from all books
    func removeFromAllBooks() {
        for link in bookLinks ?? [] {
            modelContext?.delete(link)
            if let book = link.book {
                book.modifiedDate = Date()
            }
        }
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
