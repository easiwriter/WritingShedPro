import Foundation
import SwiftData

/// Command for deleting a reference from text and updating the back matter
final class ReferenceDeleteCommand: UndoableCommand {
    let id: UUID
    let timestamp: Date
    let description: String
    
    /// The type of reference being deleted (note, glossary, citation, index)
    let referenceType: String
    
    /// ID of the reference entry being decremented
    let referenceID: UUID
    
    /// ID of the file containing the deleted reference
    let fileID: UUID
    
    /// Previous reference count (for undo)
    let previousRefCount: Int
    
    /// Previous referencingFileIDs (for Notes only)
    let previousReferencingFileIDs: [UUID]
    
    /// Weak references to data model objects (can't be codable, but needed for execute/undo)
    weak var targetFile: TextFile?
    weak var modelContext: ModelContext?
    var updateBackMatterCallback: (() -> Void)?
    
    // MARK: - Initialization
    
    init(id: UUID = UUID(),
         timestamp: Date = Date(),
         description: String = "Delete Reference",
         referenceType: String,
         referenceID: UUID,
         fileID: UUID,
         previousRefCount: Int,
         previousReferencingFileIDs: [UUID] = [],
         targetFile: TextFile? = nil,
         modelContext: ModelContext? = nil,
         updateBackMatterCallback: (() -> Void)? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.description = description
        self.referenceType = referenceType
        self.referenceID = referenceID
        self.fileID = fileID
        self.previousRefCount = previousRefCount
        self.previousReferencingFileIDs = previousReferencingFileIDs
        self.targetFile = targetFile
        self.modelContext = modelContext
        self.updateBackMatterCallback = updateBackMatterCallback
    }
    
    // MARK: - UndoableCommand
    
    func execute() {
        guard let context = modelContext else {
            #if DEBUG
            print("❌ ReferenceDeleteCommand.execute: No model context")
            #endif
            return
        }
        
        #if DEBUG
        print("🔄 ReferenceDeleteCommand.execute: \(referenceType) ref \(referenceID.uuidString.prefix(8)) in file \(fileID.uuidString.prefix(8))")
        #endif
        
        // Decrement the reference count for the specified reference type
        switch referenceType {
        case "note":
            if let noteEntry = try? context.fetch(FetchDescriptor<NoteEntry>())
                .first(where: { $0.id == referenceID }) {
                if noteEntry.referenceCount > 0 {
                    noteEntry.referenceCount -= 1
                }
                // Remove this file from referencingFileIDs
                noteEntry.referencingFileIDs.removeAll { $0 == fileID }
                #if DEBUG
                print("📝 Decremented note ref count to: \(noteEntry.referenceCount), referencingFiles: \(noteEntry.referencingFileIDs.count)")
                #endif
            }
        case "glossary":
            if let glossaryEntry = try? context.fetch(FetchDescriptor<GlossaryEntry>())
                .first(where: { $0.id == referenceID }) {
                if glossaryEntry.referenceCount > 0 {
                    glossaryEntry.referenceCount -= 1
                }
                #if DEBUG
                print("📕 Decremented glossary ref count to: \(glossaryEntry.referenceCount)")
                #endif
            }
        case "citation":
            if let citationEntry = try? context.fetch(FetchDescriptor<CitationEntry>())
                .first(where: { $0.id == referenceID }) {
                if citationEntry.referenceCount > 0 {
                    citationEntry.referenceCount -= 1
                }
                #if DEBUG
                print("📗 Decremented citation ref count to: \(citationEntry.referenceCount)")
                #endif
            }
        case "index":
            if let indexEntry = try? context.fetch(FetchDescriptor<IndexEntry>())
                .first(where: { $0.id == referenceID }) {
                if indexEntry.referenceCount > 0 {
                    indexEntry.referenceCount -= 1
                }
                #if DEBUG
                print("📙 Decremented index ref count to: \(indexEntry.referenceCount)")
                #endif
            }
        default:
            #if DEBUG
            print("⚠️ Unknown reference type: \(referenceType)")
            #endif
            break
        }
        
        do {
            try context.save()
            #if DEBUG
            print("💾 ReferenceDeleteCommand.execute: Saved model context")
            #endif
        } catch {
            #if DEBUG
            print("❌ ReferenceDeleteCommand.execute: Error saving: \(error)")
            #endif
        }
        
        // Update back matter after deletion
        #if DEBUG
        print("📋 ReferenceDeleteCommand.execute: Calling updateBackMatterCallback")
        #endif
        updateBackMatterCallback?()
    }
    
    func undo() {
        guard let context = modelContext else {
            #if DEBUG
            print("❌ ReferenceDeleteCommand.undo: No model context")
            #endif
            return
        }
        
        #if DEBUG
        print("⏮️ ReferenceDeleteCommand.undo: \(referenceType) ref \(referenceID.uuidString.prefix(8)) in file \(fileID.uuidString.prefix(8))")
        #endif
        
        // Restore the reference count and referencingFileIDs
        switch referenceType {
        case "note":
            if let noteEntry = try? context.fetch(FetchDescriptor<NoteEntry>())
                .first(where: { $0.id == referenceID }) {
                noteEntry.referenceCount = previousRefCount
                noteEntry.referencingFileIDs = previousReferencingFileIDs
                #if DEBUG
                print("📝 Restored note ref count to: \(noteEntry.referenceCount), referencingFiles: \(noteEntry.referencingFileIDs.count)")
                #endif
            }
        case "glossary":
            if let glossaryEntry = try? context.fetch(FetchDescriptor<GlossaryEntry>())
                .first(where: { $0.id == referenceID }) {
                glossaryEntry.referenceCount = previousRefCount
                #if DEBUG
                print("📕 Restored glossary ref count to: \(glossaryEntry.referenceCount)")
                #endif
            }
        case "citation":
            if let citationEntry = try? context.fetch(FetchDescriptor<CitationEntry>())
                .first(where: { $0.id == referenceID }) {
                citationEntry.referenceCount = previousRefCount
                #if DEBUG
                print("📗 Restored citation ref count to: \(citationEntry.referenceCount)")
                #endif
            }
        case "index":
            if let indexEntry = try? context.fetch(FetchDescriptor<IndexEntry>())
                .first(where: { $0.id == referenceID }) {
                indexEntry.referenceCount = previousRefCount
                #if DEBUG
                print("📙 Restored index ref count to: \(indexEntry.referenceCount)")
                #endif
            }
        default:
            #if DEBUG
            print("⚠️ Unknown reference type: \(referenceType)")
            #endif
            break
        }
        
        do {
            try context.save()
            #if DEBUG
            print("💾 ReferenceDeleteCommand.undo: Saved model context")
            #endif
        } catch {
            #if DEBUG
            print("❌ ReferenceDeleteCommand.undo: Error saving: \(error)")
            #endif
        }
        
        // Update back matter after undo (deferred to let SwiftUI binding propagate first)
        #if DEBUG
        print("📋 ReferenceDeleteCommand.undo: Deferring updateBackMatterCallback")
        #endif
        DispatchQueue.main.async { [weak self] in
            #if DEBUG
            print("📋 ReferenceDeleteCommand.undo: Now calling deferred updateBackMatterCallback")
            #endif
            self?.updateBackMatterCallback?()
        }
    }
    
    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case id, timestamp, description
        case referenceType, referenceID, fileID
        case previousRefCount, previousReferencingFileIDs
    }
    
    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        description = try container.decode(String.self, forKey: .description)
        referenceType = try container.decode(String.self, forKey: .referenceType)
        referenceID = try container.decode(UUID.self, forKey: .referenceID)
        fileID = try container.decode(UUID.self, forKey: .fileID)
        previousRefCount = try container.decode(Int.self, forKey: .previousRefCount)
        previousReferencingFileIDs = try container.decode([UUID].self, forKey: .previousReferencingFileIDs)
    }
    
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(description, forKey: .description)
        try container.encode(referenceType, forKey: .referenceType)
        try container.encode(referenceID, forKey: .referenceID)
        try container.encode(fileID, forKey: .fileID)
        try container.encode(previousRefCount, forKey: .previousRefCount)
        try container.encode(previousReferencingFileIDs, forKey: .previousReferencingFileIDs)
    }
}
