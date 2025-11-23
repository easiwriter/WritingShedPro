# Refactoring Plan: Version-Centric Comments & Footnotes

**Date:** November 23, 2025  
**Status:** Planning  
**Priority:** High - Architectural Fix  
**Estimated Effort:** 12-16 hours  

---

## Problem Statement

### Critical Architectural Flaw

Both Comments (Feature 014) and Footnotes (Feature 015) currently store annotations with `textFileID` and absolute `characterPosition`. This breaks when:

1. **Multiple versions exist** with different content lengths
2. **Users switch between versions** - positions become meaningless
3. **Content is edited** - positions shift but only tracked for current editing session

### Example of the Problem

```
Version 1: "The quick brown fox"  (19 chars)
          - Comment at position 4 (after "The ")
          
Version 2: "The very quick brown fox"  (24 chars)
          - User switches to Version 2
          - Position 4 is now in middle of "very" ❌
          - Comment appears in WRONG LOCATION
```

---

## Solution: Version-Centric Architecture

### Core Principle

**Annotations belong to specific versions, not files.**

Each version maintains its own independent set of comments and footnotes with positions relative to that version's content.

---

## Implementation Plan

### Phase 1: Data Model Changes

#### 1.1 Update CommentModel

**File:** `Models/CommentModel.swift`

```swift
@Model
final class CommentModel {
    var id: UUID = UUID()
    
    // CHANGED: Link to version instead of file
    var versionID: UUID = UUID()  // ⭐ WAS: textFileID
    
    var characterPosition: Int = 0
    var attachmentID: UUID = UUID()
    var text: String = ""
    var author: String = ""
    var createdAt: Date = Date()
    var resolvedAt: Date?
    
    // REMOVED: textFileID property
    
    var isResolved: Bool {
        resolvedAt != nil
    }
    
    init(
        id: UUID = UUID(),
        versionID: UUID,  // ⭐ CHANGED parameter
        characterPosition: Int,
        attachmentID: UUID = UUID(),
        text: String,
        author: String,
        createdAt: Date = Date(),
        resolvedAt: Date? = nil
    ) {
        self.id = id
        self.versionID = versionID  // ⭐ CHANGED
        self.characterPosition = characterPosition
        self.attachmentID = attachmentID
        self.text = text
        self.author = author
        self.createdAt = createdAt
        self.resolvedAt = resolvedAt
    }
    
    // Existing methods unchanged
    func resolve() { resolvedAt = Date() }
    func reopen() { resolvedAt = nil }
    func updateText(_ newText: String) { text = newText }
    func updatePosition(_ newPosition: Int) { characterPosition = newPosition }
}
```

#### 1.2 Update FootnoteModel

**File:** `Models/FootnoteModel.swift`

```swift
@Model
final class FootnoteModel {
    var id: UUID = UUID()
    
    // CHANGED: Link to version instead of file
    var versionID: UUID = UUID()  // ⭐ WAS: textFileID
    
    var characterPosition: Int = 0
    var attachmentID: UUID = UUID()
    var text: String = ""
    var number: Int = 0
    var createdAt: Date = Date()
    var modifiedAt: Date = Date()
    var isDeleted: Bool = false
    var deletedAt: Date?
    
    // REMOVED: textFileID property
    
    init(
        id: UUID = UUID(),
        versionID: UUID,  // ⭐ CHANGED parameter
        characterPosition: Int,
        attachmentID: UUID = UUID(),
        text: String,
        number: Int,
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        isDeleted: Bool = false,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.versionID = versionID  // ⭐ CHANGED
        self.characterPosition = characterPosition
        self.attachmentID = attachmentID
        self.text = text
        self.number = number
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.isDeleted = isDeleted
        self.deletedAt = deletedAt
    }
    
    // Existing methods unchanged
    func updateText(_ newText: String) {
        text = newText
        modifiedAt = Date()
    }
    
    func updateNumber(_ newNumber: Int) {
        number = newNumber
        modifiedAt = Date()
    }
}
```

#### 1.3 Update Version Model - Add Relationships

**File:** `Models/BaseModels.swift`

```swift
@Model
final class Version {
    var id: UUID = UUID()
    var content: String = ""
    var createdDate: Date = Date()
    var versionNumber: Int = 1
    var comment: String?
    var formattedContent: Data?
    
    // Existing transient properties
    @Transient private var _cachedAttributedContent: NSAttributedString?
    @Transient private var _cachedFormattedContentHash: Data?
    
    // Existing relationship
    var textFile: TextFile?
    
    // Feature 008b: Publication Management
    @Relationship(deleteRule: .nullify, inverse: \SubmittedFile.version) 
    var submittedFiles: [SubmittedFile]? = []
    
    // ⭐ NEW: Feature 014 - Comments
    @Relationship(deleteRule: .cascade)
    var comments: [CommentModel]? = []
    
    // ⭐ NEW: Feature 015 - Footnotes
    @Relationship(deleteRule: .cascade)
    var footnotes: [FootnoteModel]? = []
    
    // ... rest of Version implementation unchanged
}
```

**Benefits:**
- ✅ Automatic cascade deletion when version deleted
- ✅ SwiftData handles the relationship
- ✅ Can query: `version.comments` or `version.footnotes`
- ✅ CloudKit compatible (optional relationships)

---

### Phase 2: Manager Updates

#### 2.1 Update CommentManager

**File:** `Managers/CommentManager.swift`

**Changes Required:**

```swift
// OLD METHOD - REMOVE
func createComment(
    textFileID: UUID,  // ❌ Wrong parameter
    ...
) -> CommentModel

// NEW METHOD - ADD
func createComment(
    versionID: UUID,   // ⭐ Correct parameter
    characterPosition: Int,
    text: String,
    author: String,
    context: ModelContext
) -> CommentModel {
    let comment = CommentModel(
        versionID: versionID,  // ⭐ Changed
        characterPosition: characterPosition,
        text: text,
        author: author
    )
    
    context.insert(comment)
    
    do {
        try context.save()
    } catch {
        print("❌ Failed to create comment: \(error)")
    }
    
    return comment
}

// OLD METHOD - REMOVE
func getComments(forTextFile textFileID: UUID, ...) -> [CommentModel]

// NEW METHOD - ADD
func getComments(forVersion versionID: UUID, context: ModelContext) -> [CommentModel] {
    let descriptor = FetchDescriptor<CommentModel>(
        predicate: #Predicate { comment in
            comment.versionID == versionID  // ⭐ Changed
        },
        sortBy: [SortDescriptor(\.characterPosition)]
    )
    
    return (try? context.fetch(descriptor)) ?? []
}

// OLD METHOD - REMOVE
func getActiveComments(forTextFile textFileID: UUID, ...) -> [CommentModel]

// NEW METHOD - ADD
func getActiveComments(forVersion versionID: UUID, context: ModelContext) -> [CommentModel] {
    let descriptor = FetchDescriptor<CommentModel>(
        predicate: #Predicate { comment in
            comment.versionID == versionID && comment.resolvedAt == nil  // ⭐ Changed
        },
        sortBy: [SortDescriptor(\.characterPosition)]
    )
    
    return (try? context.fetch(descriptor)) ?? []
}

// UPDATE: Position tracking (still needed for current version editing)
func updatePositionsAfterEdit(
    versionID: UUID,      // ⭐ Changed parameter name
    editPosition: Int,
    lengthDelta: Int,
    context: ModelContext
) {
    let comments = getComments(forVersion: versionID, context: context)  // ⭐ Changed
    
    for comment in comments {
        if comment.characterPosition >= editPosition {
            let newPosition = max(editPosition, comment.characterPosition + lengthDelta)
            comment.updatePosition(newPosition)
        }
    }
    
    do {
        try context.save()
    } catch {
        print("❌ Failed to update comment positions: \(error)")
    }
}

// ⭐ NEW METHOD: Copy comments when creating new version
func copyComments(
    from sourceVersionID: UUID,
    to targetVersionID: UUID,
    context: ModelContext
) -> [CommentModel] {
    let sourceComments = getComments(forVersion: sourceVersionID, context: context)
    var copiedComments: [CommentModel] = []
    
    for sourceComment in sourceComments {
        let copy = CommentModel(
            versionID: targetVersionID,  // New version
            characterPosition: sourceComment.characterPosition,
            text: sourceComment.text,
            author: sourceComment.author,
            createdAt: Date(),  // New timestamp
            resolvedAt: nil  // Don't copy resolved state
        )
        
        context.insert(copy)
        copiedComments.append(copy)
    }
    
    do {
        try context.save()
        print("✅ Copied \(copiedComments.count) comments to new version")
    } catch {
        print("❌ Failed to copy comments: \(error)")
    }
    
    return copiedComments
}
```

#### 2.2 Update FootnoteManager

**File:** `Managers/FootnoteManager.swift`

**Changes Required:**

```swift
// OLD METHOD - REMOVE
func createFootnote(
    textFileID: UUID,  // ❌ Wrong parameter
    ...
) -> FootnoteModel

// NEW METHOD - ADD
func createFootnote(
    versionID: UUID,   // ⭐ Correct parameter
    characterPosition: Int,
    attachmentID: UUID = UUID(),
    text: String,
    context: ModelContext
) -> FootnoteModel {
    // Calculate number based on position in THIS version
    let number = calculateFootnoteNumber(
        forVersion: versionID,  // ⭐ Changed
        at: characterPosition,
        context: context
    )
    
    let footnote = FootnoteModel(
        versionID: versionID,  // ⭐ Changed
        characterPosition: characterPosition,
        attachmentID: attachmentID,
        text: text,
        number: number
    )
    
    context.insert(footnote)
    
    do {
        try context.save()
    } catch {
        print("❌ Failed to create footnote: \(error)")
    }
    
    return footnote
}

// OLD METHOD - REMOVE
func getFootnotes(forTextFile textFileID: UUID, ...) -> [FootnoteModel]

// NEW METHOD - ADD
func getFootnotes(forVersion versionID: UUID, context: ModelContext) -> [FootnoteModel] {
    let descriptor = FetchDescriptor<FootnoteModel>(
        predicate: #Predicate { footnote in
            footnote.versionID == versionID && !footnote.isDeleted  // ⭐ Changed
        },
        sortBy: [SortDescriptor(\.characterPosition)]
    )
    
    return (try? context.fetch(descriptor)) ?? []
}

// UPDATE: Renumbering (now per version)
func renumberFootnotes(forVersion versionID: UUID, context: ModelContext) {
    let footnotes = getFootnotes(forVersion: versionID, context: context)  // ⭐ Changed
    
    for (index, footnote) in footnotes.enumerated() {
        footnote.updateNumber(index + 1)
    }
    
    do {
        try context.save()
    } catch {
        print("❌ Failed to renumber footnotes: \(error)")
    }
}

// UPDATE: Position tracking
func updatePositionsAfterEdit(
    versionID: UUID,      // ⭐ Changed parameter name
    editPosition: Int,
    lengthDelta: Int,
    context: ModelContext
) {
    let footnotes = getFootnotes(forVersion: versionID, context: context)  // ⭐ Changed
    
    for footnote in footnotes {
        if footnote.characterPosition >= editPosition {
            let newPosition = max(editPosition, footnote.characterPosition + lengthDelta)
            footnote.characterPosition = newPosition
            footnote.modifiedAt = Date()
        }
    }
    
    // Renumber after position changes
    renumberFootnotes(forVersion: versionID, context: context)
}

// UPDATE: Calculate number (now per version)
func calculateFootnoteNumber(
    forVersion versionID: UUID,  // ⭐ Changed parameter
    at position: Int,
    context: ModelContext
) -> Int {
    let existingFootnotes = getFootnotes(forVersion: versionID, context: context)
    
    let footnotesBefore = existingFootnotes.filter { $0.characterPosition < position }
    
    return footnotesBefore.count + 1
}

// ⭐ NEW METHOD: Copy footnotes when creating new version
func copyFootnotes(
    from sourceVersionID: UUID,
    to targetVersionID: UUID,
    context: ModelContext
) -> [FootnoteModel] {
    let sourceFootnotes = getFootnotes(forVersion: sourceVersionID, context: context)
    var copiedFootnotes: [FootnoteModel] = []
    
    for sourceFootnote in sourceFootnotes {
        let copy = FootnoteModel(
            versionID: targetVersionID,  // New version
            characterPosition: sourceFootnote.characterPosition,
            text: sourceFootnote.text,
            number: sourceFootnote.number,  // Keep same number initially
            createdAt: Date()
        )
        
        context.insert(copy)
        copiedFootnotes.append(copy)
    }
    
    // Renumber in the new version
    renumberFootnotes(forVersion: targetVersionID, context: context)
    
    do {
        try context.save()
        print("✅ Copied \(copiedFootnotes.count) footnotes to new version")
    } catch {
        print("❌ Failed to copy footnotes: \(error)")
    }
    
    return copiedFootnotes
}
```

---

### Phase 3: UI Updates

#### 3.1 Update FileEditView

**File:** `Views/FileEditView.swift`

**Key Changes:**

```swift
// CHANGE: All queries use currentVersion.id instead of file.id

// OLD:
let comments = CommentManager.shared.getComments(
    forTextFile: file.id,  // ❌ Wrong
    context: modelContext
)

// NEW:
guard let currentVersion = file.currentVersion else { return }
let comments = CommentManager.shared.getComments(
    forVersion: currentVersion.id,  // ⭐ Correct
    context: modelContext
)

// OLD:
let footnotes = FootnoteManager.shared.getFootnotes(
    forTextFile: file.id,  // ❌ Wrong
    context: modelContext
)

// NEW:
let footnotes = FootnoteManager.shared.getFootnotes(
    forVersion: currentVersion.id,  // ⭐ Correct
    context: modelContext
)

// UPDATE: Position tracking calls
private func handleAttributedTextChange(newAttributedText: NSAttributedString) {
    // ... existing code ...
    
    guard let currentVersion = file.currentVersion else { return }
    
    // Update comment positions
    CommentManager.shared.updatePositionsAfterEdit(
        versionID: currentVersion.id,  // ⭐ Changed
        editPosition: editPosition,
        lengthDelta: delta,
        context: modelContext
    )
    
    // Update footnote positions
    FootnoteManager.shared.updatePositionsAfterEdit(
        versionID: currentVersion.id,  // ⭐ Changed
        editPosition: editPosition,
        lengthDelta: delta,
        context: modelContext
    )
}

// UPDATE: Create comment
private func addCommentAtSelection() {
    guard let currentVersion = file.currentVersion else { return }
    guard let selectedRange = textViewCoordinator.textView?.selectedRange else { return }
    
    let comment = CommentManager.shared.createComment(
        versionID: currentVersion.id,  // ⭐ Changed
        characterPosition: selectedRange.location,
        text: commentText,
        author: "User",  // TODO: Get from settings
        context: modelContext
    )
    
    // ... insert attachment ...
}

// UPDATE: Create footnote
private func addFootnoteAtCursor() {
    guard let currentVersion = file.currentVersion else { return }
    guard let cursorPosition = textViewCoordinator.textView?.selectedRange.location else { return }
    
    let footnote = FootnoteManager.shared.createFootnote(
        versionID: currentVersion.id,  // ⭐ Changed
        characterPosition: cursorPosition,
        text: footnoteText,
        context: modelContext
    )
    
    // ... insert attachment ...
}
```

#### 3.2 Update CommentsListView

**File:** `Views/Comments/CommentsListView.swift`

**Key Changes:**

```swift
struct CommentsListView: View {
    let file: TextFile
    @Environment(\.modelContext) private var modelContext
    
    // CHANGE: Fetch comments for current version only
    @State private var comments: [CommentModel] = []
    
    var body: some View {
        List {
            ForEach(comments) { comment in
                // ... existing UI ...
            }
        }
        .onAppear {
            loadComments()
        }
        .onChange(of: file.currentVersionIndex) {
            // ⭐ NEW: Reload when version changes
            loadComments()
        }
    }
    
    private func loadComments() {
        guard let currentVersion = file.currentVersion else {
            comments = []
            return
        }
        
        comments = CommentManager.shared.getComments(
            forVersion: currentVersion.id,  // ⭐ Changed
            context: modelContext
        )
    }
}
```

#### 3.3 Update FootnotesListView

**File:** `Views/Footnotes/FootnotesListView.swift`

**Key Changes:**

```swift
struct FootnotesListView: View {
    let file: TextFile
    @Environment(\.modelContext) private var modelContext
    
    // CHANGE: Fetch footnotes for current version only
    @State private var footnotes: [FootnoteModel] = []
    
    var body: some View {
        List {
            ForEach(footnotes) { footnote in
                // ... existing UI ...
            }
        }
        .onAppear {
            loadFootnotes()
        }
        .onChange(of: file.currentVersionIndex) {
            // ⭐ NEW: Reload when version changes
            loadFootnotes()
        }
    }
    
    private func loadFootnotes() {
        guard let currentVersion = file.currentVersion else {
            footnotes = []
            return
        }
        
        footnotes = FootnoteManager.shared.getFootnotes(
            forVersion: currentVersion.id,  // ⭐ Changed
            context: modelContext
        )
    }
}
```

---

### Phase 4: Version Creation - Copy Annotations

#### 4.1 Update TextFile Extensions

**File:** `Models/TextFile+Versions.swift`

**Add copying logic to version creation:**

```swift
extension TextFile {
    
    /// Create a new version from the current version
    /// - Parameter comment: Optional comment for the new version
    /// - Parameter context: SwiftData model context for copying annotations
    /// - Returns: The newly created version
    func createNewVersion(comment: String? = nil, context: ModelContext) -> Version {
        guard let currentVer = currentVersion else {
            fatalError("Cannot create new version without a current version")
        }
        
        let nextVersionNumber = (versions?.map { $0.versionNumber }.max() ?? 0) + 1
        
        // Create new version with current content
        let newVersion = Version(
            content: currentVer.content,
            versionNumber: nextVersionNumber,
            comment: comment
        )
        
        // Copy formatted content
        newVersion.formattedContent = currentVer.formattedContent
        
        // Add to versions array
        if versions == nil {
            versions = []
        }
        versions?.append(newVersion)
        newVersion.textFile = self
        
        // Update current version index
        currentVersionIndex = nextVersionNumber - 1
        
        // ⭐ NEW: Copy comments from current version to new version
        _ = CommentManager.shared.copyComments(
            from: currentVer.id,
            to: newVersion.id,
            context: context
        )
        
        // ⭐ NEW: Copy footnotes from current version to new version
        _ = FootnoteManager.shared.copyFootnotes(
            from: currentVer.id,
            to: newVersion.id,
            context: context
        )
        
        print("✅ Created Version \(nextVersionNumber) with copied annotations")
        
        return newVersion
    }
    
    // ... existing methods ...
}
```

#### 4.2 Update UI for Version Creation

**File:** `Views/ProjectDetailView.swift` (or wherever version creation happens)

**Ensure context is passed:**

```swift
// When creating new version
Button("Create New Version") {
    let newVersion = file.createNewVersion(
        comment: versionComment,
        context: modelContext  // ⭐ Pass context for copying
    )
    
    do {
        try modelContext.save()
        print("✅ New version created with annotations")
    } catch {
        print("❌ Failed to save: \(error)")
    }
}
```

---

### Phase 5: Testing Updates

#### 5.1 Update CommentManagerTests

**File:** `WritingShedProTests/CommentManagerTests.swift`

**Update all tests:**

```swift
func testCreateComment() {
    // Create test file and version
    let project = Project(name: "Test")
    let folder = Folder(name: "Test", project: project)
    let file = TextFile(name: "Test.txt", parentFolder: folder)
    let version = file.currentVersion!
    
    // Create comment with versionID
    let comment = CommentManager.shared.createComment(
        versionID: version.id,  // ⭐ Changed
        characterPosition: 10,
        text: "Test comment",
        author: "Tester",
        context: modelContext
    )
    
    XCTAssertEqual(comment.versionID, version.id)  // ⭐ Changed assertion
    XCTAssertEqual(comment.characterPosition, 10)
}

func testGetCommentsForVersion() {
    // Create test data
    let version = createTestVersion()
    
    _ = CommentManager.shared.createComment(
        versionID: version.id,  // ⭐ Changed
        characterPosition: 5,
        text: "Comment 1",
        author: "Tester",
        context: modelContext
    )
    
    // Fetch comments
    let comments = CommentManager.shared.getComments(
        forVersion: version.id,  // ⭐ Changed
        context: modelContext
    )
    
    XCTAssertEqual(comments.count, 1)
}

// ⭐ NEW TEST: Version isolation
func testCommentsAreVersionSpecific() {
    let file = createTestFile()
    let version1 = file.currentVersion!
    
    // Add comment to version 1
    _ = CommentManager.shared.createComment(
        versionID: version1.id,
        characterPosition: 5,
        text: "V1 Comment",
        author: "Tester",
        context: modelContext
    )
    
    // Create version 2 (without copying)
    let version2 = Version(content: "Different content", versionNumber: 2)
    file.versions?.append(version2)
    
    // Add comment to version 2
    _ = CommentManager.shared.createComment(
        versionID: version2.id,
        characterPosition: 10,
        text: "V2 Comment",
        author: "Tester",
        context: modelContext
    )
    
    // Verify isolation
    let v1Comments = CommentManager.shared.getComments(
        forVersion: version1.id,
        context: modelContext
    )
    let v2Comments = CommentManager.shared.getComments(
        forVersion: version2.id,
        context: modelContext
    )
    
    XCTAssertEqual(v1Comments.count, 1)
    XCTAssertEqual(v2Comments.count, 1)
    XCTAssertEqual(v1Comments[0].text, "V1 Comment")
    XCTAssertEqual(v2Comments[0].text, "V2 Comment")
}

// ⭐ NEW TEST: Copying comments
func testCopyCommentsToNewVersion() {
    let file = createTestFile()
    let version1 = file.currentVersion!
    
    // Add comments to version 1
    _ = CommentManager.shared.createComment(
        versionID: version1.id,
        characterPosition: 5,
        text: "Comment 1",
        author: "Tester",
        context: modelContext
    )
    _ = CommentManager.shared.createComment(
        versionID: version1.id,
        characterPosition: 15,
        text: "Comment 2",
        author: "Tester",
        context: modelContext
    )
    
    // Create version 2
    let version2 = Version(content: version1.content, versionNumber: 2)
    file.versions?.append(version2)
    
    // Copy comments
    let copiedComments = CommentManager.shared.copyComments(
        from: version1.id,
        to: version2.id,
        context: modelContext
    )
    
    // Verify
    XCTAssertEqual(copiedComments.count, 2)
    XCTAssertEqual(copiedComments[0].text, "Comment 1")
    XCTAssertEqual(copiedComments[1].text, "Comment 2")
    XCTAssertEqual(copiedComments[0].versionID, version2.id)
    
    // Original comments unchanged
    let v1Comments = CommentManager.shared.getComments(
        forVersion: version1.id,
        context: modelContext
    )
    XCTAssertEqual(v1Comments.count, 2)
}
```

#### 5.2 Update FootnoteManagerTests

**File:** `WritingShedProTests/FootnoteManagerTests.swift`

**Similar updates as CommentManagerTests:**

```swift
func testCreateFootnote() {
    let version = createTestVersion()
    
    let footnote = FootnoteManager.shared.createFootnote(
        versionID: version.id,  // ⭐ Changed
        characterPosition: 10,
        text: "Test footnote",
        context: modelContext
    )
    
    XCTAssertEqual(footnote.versionID, version.id)  // ⭐ Changed
    XCTAssertEqual(footnote.number, 1)
}

// ⭐ NEW TEST: Version-specific numbering
func testFootnoteNumberingPerVersion() {
    let file = createTestFile()
    let version1 = file.currentVersion!
    let version2 = Version(content: "Version 2", versionNumber: 2)
    file.versions?.append(version2)
    
    // Add 3 footnotes to version 1
    for i in 0..<3 {
        _ = FootnoteManager.shared.createFootnote(
            versionID: version1.id,
            characterPosition: i * 10,
            text: "Footnote \(i + 1)",
            context: modelContext
        )
    }
    
    // Add 2 footnotes to version 2
    for i in 0..<2 {
        _ = FootnoteManager.shared.createFootnote(
            versionID: version2.id,
            characterPosition: i * 10,
            text: "V2 Footnote \(i + 1)",
            context: modelContext
        )
    }
    
    // Verify independent numbering
    let v1Footnotes = FootnoteManager.shared.getFootnotes(
        forVersion: version1.id,
        context: modelContext
    )
    let v2Footnotes = FootnoteManager.shared.getFootnotes(
        forVersion: version2.id,
        context: modelContext
    )
    
    XCTAssertEqual(v1Footnotes.count, 3)
    XCTAssertEqual(v2Footnotes.count, 2)
    XCTAssertEqual(v1Footnotes.last?.number, 3)
    XCTAssertEqual(v2Footnotes.last?.number, 2)
}

// ⭐ NEW TEST: Copy footnotes
func testCopyFootnotesToNewVersion() {
    let file = createTestFile()
    let version1 = file.currentVersion!
    
    // Add footnotes
    _ = FootnoteManager.shared.createFootnote(
        versionID: version1.id,
        characterPosition: 10,
        text: "Source 1",
        context: modelContext
    )
    _ = FootnoteManager.shared.createFootnote(
        versionID: version1.id,
        characterPosition: 50,
        text: "Source 2",
        context: modelContext
    )
    
    // Create version 2
    let version2 = Version(content: version1.content, versionNumber: 2)
    file.versions?.append(version2)
    
    // Copy footnotes
    let copied = FootnoteManager.shared.copyFootnotes(
        from: version1.id,
        to: version2.id,
        context: modelContext
    )
    
    XCTAssertEqual(copied.count, 2)
    XCTAssertEqual(copied[0].versionID, version2.id)
    XCTAssertEqual(copied[0].text, "Source 1")
}
```

---

### Phase 6: Documentation Updates

#### 6.1 Update Specs

**Files to update:**
- `specs/014-comments/data-model.md`
- `specs/015-footnotes/data-model.md`

**Add section:**

```markdown
## Version-Centric Architecture

### Design Decision

Comments/Footnotes belong to **specific versions**, not to text files.

**Rationale:**
- Each version can have different content lengths
- Character positions are only meaningful within a version's content
- Switching versions would break absolute positions
- Annotations are reviews/notes on specific drafts

### Implementation

```swift
@Model
final class CommentModel {
    var versionID: UUID  // Links to specific Version
    var characterPosition: Int  // Position in that version
}

@Model
final class Version {
    @Relationship(deleteRule: .cascade)
    var comments: [CommentModel]?
}
```

### Behavior

**Creating New Version:**
- All comments/footnotes from source version are **copied** to new version
- Positions are preserved (content is initially identical)
- Each version has independent annotations thereafter

**Switching Versions:**
- Only comments/footnotes for current version are displayed
- Positions are always correct for the displayed version
- No position tracking across versions needed
```

#### 6.2 Create Migration Guide

**File:** `MIGRATION_VERSION_CENTRIC_ANNOTATIONS.md`

```markdown
# Migration Guide: Version-Centric Annotations

## Breaking Changes

### Data Model
- `CommentModel.textFileID` → `CommentModel.versionID`
- `FootnoteModel.textFileID` → `FootnoteModel.versionID`

### API Changes

**CommentManager:**
```swift
// OLD
createComment(textFileID: UUID, ...)
getComments(forTextFile: UUID, ...)

// NEW
createComment(versionID: UUID, ...)
getComments(forVersion: UUID, ...)
```

**FootnoteManager:**
```swift
// OLD
createFootnote(textFileID: UUID, ...)
getFootnotes(forTextFile: UUID, ...)

// NEW
createFootnote(versionID: UUID, ...)
getFootnotes(forVersion: UUID, ...)
```

## Testing During Development

Since no production data exists:
1. Delete app and reinstall to clear database
2. Create test files with multiple versions
3. Add comments/footnotes to each version
4. Verify version switching shows correct annotations
5. Test version creation copies annotations

## What to Test

- [ ] Create comment in Version 1
- [ ] Switch to Version 2 - comment not visible
- [ ] Create Version 2 from Version 1 - comment copied
- [ ] Edit Version 2 - positions update correctly
- [ ] Delete Version 1 - comments cascade deleted
- [ ] Same for footnotes
```

---

## Implementation Checklist

### Phase 1: Data Models ✅
- [ ] Update `CommentModel.swift` - change to `versionID`
- [ ] Update `FootnoteModel.swift` - change to `versionID`
- [ ] Update `BaseModels.swift` - add relationships to `Version`
- [ ] Compile and fix any immediate errors

### Phase 2: Managers ✅
- [ ] Update `CommentManager.swift` - all methods
- [ ] Add `copyComments()` method
- [ ] Update `FootnoteManager.swift` - all methods
- [ ] Add `copyFootnotes()` method
- [ ] Test managers in isolation

### Phase 3: UI Updates ✅
- [ ] Update `FileEditView.swift` - all queries
- [ ] Update `CommentsListView.swift` - version-aware loading
- [ ] Update `FootnotesListView.swift` - version-aware loading
- [ ] Update `CommentDetailView.swift` - if needed
- [ ] Update `FootnoteDetailView.swift` - if needed
- [ ] Test UI in app

### Phase 4: Version Creation ✅
- [ ] Update `TextFile+Versions.swift` - add copying
- [ ] Update version creation UI
- [ ] Test creating versions with annotations

### Phase 5: Testing ✅
- [ ] Update `CommentManagerTests.swift`
- [ ] Update `FootnoteManagerTests.swift`
- [ ] Add new tests for version isolation
- [ ] Add new tests for copying
- [ ] Run all tests - ensure 100% pass

### Phase 6: Documentation ✅
- [ ] Update `specs/014-comments/data-model.md`
- [ ] Update `specs/015-footnotes/data-model.md`
- [ ] Create migration guide
- [ ] Update README if needed

---

## Validation Checklist

After implementation, verify:

### Functional Tests
- [ ] Create comment in V1, not visible in V2 ✅
- [ ] Create footnote in V1, not visible in V2 ✅
- [ ] Create V2 from V1, annotations copied ✅
- [ ] Edit V2, positions update correctly ✅
- [ ] Delete V1, annotations cascade deleted ✅
- [ ] Positions always correct when switching versions ✅

### Edge Cases
- [ ] Version with no annotations
- [ ] Version with 100+ annotations
- [ ] Copy empty version (no annotations)
- [ ] Delete version with annotations
- [ ] Undo/redo still works

### Performance
- [ ] Large files (10,000+ words) with annotations
- [ ] Version switching is instant
- [ ] No lag when scrolling past annotations

---

## Estimated Timeline

| Phase | Hours | Notes |
|-------|-------|-------|
| Phase 1: Data Models | 1-2 | Straightforward |
| Phase 2: Managers | 3-4 | Method updates + copying |
| Phase 3: UI Updates | 2-3 | Multiple view files |
| Phase 4: Version Creation | 1-2 | Integration |
| Phase 5: Testing | 3-4 | Comprehensive tests |
| Phase 6: Documentation | 1-2 | Specs + guide |
| **Total** | **12-16** | **Full implementation** |

---

## Benefits After Refactoring

✅ **Correctness**: Positions always accurate  
✅ **Clarity**: Clear ownership (version owns annotations)  
✅ **Simplicity**: No cross-version position tracking  
✅ **Scalability**: Works with any number of versions  
✅ **User Experience**: Predictable behavior  
✅ **Data Integrity**: Cascade deletion, proper relationships  

---

## Status

**Current:** Planning  
**Next Step:** Phase 1 - Data Model Changes  
**Blockers:** None  

---

*Created: November 23, 2025*  
*Author: GitHub Copilot*  
*Review: Pending*
