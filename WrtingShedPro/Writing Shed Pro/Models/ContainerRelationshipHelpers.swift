//
//  ContainerRelationshipHelpers.swift
//  Writing Shed Pro
//
//  Convenience methods for container relationships.
//  Join tables are retained for CloudKit and archive compatibility.
//  Each item has one optional assignment per applicable container type.
//

import Foundation
import SwiftData

protocol ContainerDisplayOrderable {
    var id: UUID { get }
    var name: String? { get }
    var userOrder: Int? { get }
}

extension PoetryCollection: ContainerDisplayOrderable {}
extension ProseSection: ContainerDisplayOrderable {}
extension Chapter: ContainerDisplayOrderable {}
extension Act: ContainerDisplayOrderable {}
extension Book: ContainerDisplayOrderable {}

enum ContainerDisplayOrder {
    static func isOrdered<T: ContainerDisplayOrderable>(_ lhs: T, _ rhs: T) -> Bool {
        let lhsOrder = lhs.userOrder ?? Int.max
        let rhsOrder = rhs.userOrder ?? Int.max
        if lhsOrder != rhsOrder { return lhsOrder < rhsOrder }

        let nameComparison = (lhs.name ?? "").localizedCaseInsensitiveCompare(rhs.name ?? "")
        if nameComparison != .orderedSame { return nameComparison == .orderedAscending }

        return lhs.id.uuidString < rhs.id.uuidString
    }
}

// MARK: - TextFile Container Helpers

extension TextFile {
    
    // MARK: Poetry Collection
    
    /// Whether this file belongs to the given poetry collection
    func isInPoetryCollection(_ collection: PoetryCollection) -> Bool {
        poetryCollection?.id == collection.id
    }
    
    /// Assign this file to one poetry collection, replacing any prior assignment.
    func addToPoetryCollection(_ collection: PoetryCollection) {
        guard poetryCollection?.id != collection.id else { return }
        poetryCollection?.modifiedDate = Date()
        poetryCollection = collection
        modifiedDate = Date()
        collection.modifiedDate = Date()
    }
    
    /// Remove this file from a specific poetry collection
    func removeFromPoetryCollection(_ collection: PoetryCollection) {
        guard poetryCollection?.id == collection.id else { return }
        poetryCollection = nil
        modifiedDate = Date()
        collection.modifiedDate = Date()
    }
    
    /// Remove this file from all poetry collections
    func removeFromAllPoetryCollections() {
        guard let existingCollection = poetryCollection else { return }
        existingCollection.modifiedDate = Date()
        poetryCollection = nil
        modifiedDate = Date()
    }
    
    // MARK: Prose Section
    
    /// Whether this file belongs to the given prose section
    func isInSection(_ section: ProseSection) -> Bool {
        self.section?.id == section.id
    }
    
    /// Assign this file to a prose section, replacing any prior assignment.
    func addToSection(_ section: ProseSection) {
        guard self.section?.id != section.id else { return }
        self.section?.modifiedDate = Date()
        self.section = section
        modifiedDate = Date()
        section.modifiedDate = Date()
    }
    
    /// Remove this file from a specific prose section
    func removeFromSection(_ section: ProseSection) {
        guard self.section?.id == section.id else { return }
        self.section = nil
        modifiedDate = Date()
        section.modifiedDate = Date()
    }
    
    /// Remove this file from all prose sections
    func removeFromAllSections() {
        guard let existingSection = section else { return }
        existingSection.modifiedDate = Date()
        section = nil
        modifiedDate = Date()
    }
}

// MARK: - StoryScene Container Helpers

extension StoryScene {
    
    // MARK: Chapter
    
    /// Whether this scene belongs to the given chapter
    func isInChapter(_ chapter: Chapter) -> Bool {
        self.chapter?.id == chapter.id
    }
    
    /// Assign this scene to a chapter, replacing any prior assignment.
    func addToChapter(_ chapter: Chapter) {
        guard self.chapter?.id != chapter.id else { return }
        self.chapter?.modifiedDate = Date()
        self.chapter = chapter
        modifiedDate = Date()
        chapter.modifiedDate = Date()
    }
    
    /// Remove this scene from a specific chapter
    func removeFromChapter(_ chapter: Chapter) {
        guard self.chapter?.id == chapter.id else { return }
        self.chapter = nil
        modifiedDate = Date()
        chapter.modifiedDate = Date()
    }
    
    /// Remove this scene from all chapters
    func removeFromAllChapters() {
        guard let existingChapter = chapter else { return }
        existingChapter.modifiedDate = Date()
        chapter = nil
        modifiedDate = Date()
    }
    
    // MARK: Act
    
    /// Whether this scene belongs to the given act
    func isInAct(_ act: Act) -> Bool {
        self.act?.id == act.id
    }
    
    /// Assign this scene to an act, replacing any prior assignment.
    func addToAct(_ act: Act) {
        guard self.act?.id != act.id else { return }
        self.act?.modifiedDate = Date()
        self.act = act
        modifiedDate = Date()
        act.modifiedDate = Date()
    }
    
    /// Remove this scene from a specific act
    func removeFromAct(_ act: Act) {
        guard self.act?.id == act.id else { return }
        self.act = nil
        modifiedDate = Date()
        act.modifiedDate = Date()
    }
    
    /// Remove this scene from all acts
    func removeFromAllActs() {
        guard let existingAct = act else { return }
        existingAct.modifiedDate = Date()
        act = nil
        modifiedDate = Date()
    }
    
    // MARK: Book
    
    /// Whether this scene belongs to the given book
    func isInBook(_ book: Book) -> Bool {
        self.book?.id == book.id
    }
    
    /// Assign this scene to a book, replacing any prior assignment.
    func addToBook(_ book: Book) {
        guard self.book?.id != book.id else { return }
        self.book?.modifiedDate = Date()
        self.book = book
        modifiedDate = Date()
        book.modifiedDate = Date()
    }
    
    /// Remove this scene from a specific book
    func removeFromBook(_ book: Book) {
        guard self.book?.id == book.id else { return }
        self.book = nil
        modifiedDate = Date()
        book.modifiedDate = Date()
    }
    
    /// Remove this scene from all books
    func removeFromAllBooks() {
        guard let existingBook = book else { return }
        existingBook.modifiedDate = Date()
        book = nil
        modifiedDate = Date()
    }
}
