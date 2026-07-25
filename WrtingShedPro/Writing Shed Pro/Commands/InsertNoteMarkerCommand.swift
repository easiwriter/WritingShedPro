import Foundation
import SwiftData

/// Command for inserting a note marker into text
final class InsertNoteMarkerCommand: UndoableCommand {
    let id: UUID
    let timestamp: Date
    let description: String
    
    /// Position where the marker should be inserted
    let position: Int
    
    /// Length of the attachment (needed to remove it during undo)
    var attachmentLength: Int = 1  // Attachments are usually 1 character
    
    /// The note entry being referenced
    let noteID: UUID
    let noteTag: String?
    let noteNumber: Int
    let noteIsEndnote: Bool
    
    /// File containing this reference
    let fileID: UUID
    
    /// Previous reference count (for undo - should be incremented from this)
    let previousRefCount: Int
    let previousReferencingFileIDs: [UUID]
    
    /// Weak references to data model objects
    weak var targetFile: TextFile?
    weak var modelContext: ModelContext?
    var updateBackMatterCallback: (() -> Void)?
    var removeAttachmentCallback: (() -> Void)?  // Called to remove attachment from text view during undo
    var reinsertAttachmentCallback: (() -> Void)?  // Called to re-insert attachment during redo
    
    // MARK: - Initialization
    
    init(id: UUID = UUID(),
         timestamp: Date = Date(),
         description: String = "Insert Note Marker",
         position: Int,
         noteID: UUID,
         noteTag: String?,
         noteNumber: Int,
         noteIsEndnote: Bool,
         fileID: UUID,
         previousRefCount: Int,
         previousReferencingFileIDs: [UUID] = [],
         targetFile: TextFile? = nil,
         modelContext: ModelContext? = nil,
         updateBackMatterCallback: (() -> Void)? = nil,
         removeAttachmentCallback: (() -> Void)? = nil,
         reinsertAttachmentCallback: (() -> Void)? = nil) {
        self.id = id
        self.timestamp = timestamp
        self.description = description
        self.position = position
        self.noteID = noteID
        self.noteTag = noteTag
        self.noteNumber = noteNumber
        self.noteIsEndnote = noteIsEndnote
        self.fileID = fileID
        self.previousRefCount = previousRefCount
        self.previousReferencingFileIDs = previousReferencingFileIDs
        self.targetFile = targetFile
        self.modelContext = modelContext
        self.updateBackMatterCallback = updateBackMatterCallback
        self.removeAttachmentCallback = removeAttachmentCallback
        self.reinsertAttachmentCallback = reinsertAttachmentCallback
    }
    
    // MARK: - UndoableCommand
    
    func execute() {
        guard let context = modelContext else {
            #if DEBUG
            print("❌ InsertNoteMarkerCommand.execute: No model context")
            #endif
            return
        }
        
        #if DEBUG
        print("🔄 InsertNoteMarkerCommand.execute: Insert \(noteIsEndnote ? "endnote" : "note") \(noteID.uuidString.prefix(8)) at position \(position)")
        #endif
        
        // Re-insert the attachment into the text view (for redo operations)
        #if DEBUG
        print("📝 Calling reinsertAttachmentCallback to re-insert into text view")
        #endif
        reinsertAttachmentCallback?()
        
        // Find the note entry
        guard let noteEntry = try? context.fetch(FetchDescriptor<NoteEntry>())
            .first(where: { $0.id == noteID }) else {
            #if DEBUG
            print("❌ Could not find note entry for insertion: \(noteID)")
            #endif
            return
        }
        
        // Increment reference count
        noteEntry.referenceCount += 1
        
        // Add file to referencingFileIDs if not already there
        if !noteEntry.referencingFileIDs.contains(fileID) {
            noteEntry.referencingFileIDs.append(fileID)
        }
        
        #if DEBUG
        print("📝 Incremented note ref count to: \(noteEntry.referenceCount), referencingFiles: \(noteEntry.referencingFileIDs.count)")
        #endif
        
        Task { @MainActor in WriteCoalescer.shared?.requestSave(reason: "insert-note-marker-execute") }
        
        // Update back matter
        #if DEBUG
        print("📋 InsertNoteMarkerCommand.execute: Calling updateBackMatterCallback")
        #endif
        updateBackMatterCallback?()
    }
    
    func undo() {
        guard let context = modelContext else {
            #if DEBUG
            print("❌ InsertNoteMarkerCommand.undo: No model context")
            #endif
            return
        }
        
        #if DEBUG
        print("⏮️ InsertNoteMarkerCommand.undo: Remove \(noteIsEndnote ? "endnote" : "note") \(noteID.uuidString.prefix(8)) at position \(position)")
        #endif
        
        // Remove the attachment from the text view using the callback
        #if DEBUG
        print("📝 Calling removeAttachmentCallback to remove from text view")
        #endif
        removeAttachmentCallback?()
        
        // Find the note entry
        guard let noteEntry = try? context.fetch(FetchDescriptor<NoteEntry>())
            .first(where: { $0.id == noteID }) else {
            #if DEBUG
            print("❌ Could not find note entry for undo: \(noteID)")
            #endif
            return
        }
        
        // Restore previous state
        noteEntry.referenceCount = previousRefCount
        noteEntry.referencingFileIDs = previousReferencingFileIDs
        
        #if DEBUG
        print("📝 Restored note ref count to: \(noteEntry.referenceCount), referencingFiles: \(noteEntry.referencingFileIDs.count)")
        #endif
        
        Task { @MainActor in WriteCoalescer.shared?.requestSave(reason: "insert-note-marker-undo") }
        
        // Update back matter
        #if DEBUG
        print("📋 InsertNoteMarkerCommand.undo: Calling updateBackMatterCallback")
        #endif
        updateBackMatterCallback?()
    }
    
    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case id, timestamp, description
        case position, noteID, noteTag, noteNumber, noteIsEndnote, fileID
        case previousRefCount, previousReferencingFileIDs
    }
    
    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        description = try container.decode(String.self, forKey: .description)
        position = try container.decode(Int.self, forKey: .position)
        noteID = try container.decode(UUID.self, forKey: .noteID)
        noteTag = try container.decodeIfPresent(String.self, forKey: .noteTag)
        noteNumber = try container.decode(Int.self, forKey: .noteNumber)
        noteIsEndnote = try container.decode(Bool.self, forKey: .noteIsEndnote)
        fileID = try container.decode(UUID.self, forKey: .fileID)
        previousRefCount = try container.decode(Int.self, forKey: .previousRefCount)
        previousReferencingFileIDs = try container.decode([UUID].self, forKey: .previousReferencingFileIDs)
    }
    
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(description, forKey: .description)
        try container.encode(position, forKey: .position)
        try container.encode(noteID, forKey: .noteID)
        try container.encodeIfPresent(noteTag, forKey: .noteTag)
        try container.encode(noteNumber, forKey: .noteNumber)
        try container.encode(noteIsEndnote, forKey: .noteIsEndnote)
        try container.encode(fileID, forKey: .fileID)
        try container.encode(previousRefCount, forKey: .previousRefCount)
        try container.encode(previousReferencingFileIDs, forKey: .previousReferencingFileIDs)
    }
}
