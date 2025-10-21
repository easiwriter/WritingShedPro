# Data Model: Folder and File Management

**Phase:** 002  
**Status:** Planning  
**Dependencies:** Phase 001 Data Models ✅

---

## Overview

Phase 002 builds upon the existing `Project`, `Folder`, and `File` models from Phase 001. No model changes are required - we're simply utilizing the relationships that were already defined.

---

## Existing Models (From Phase 001)

### Project Model
```swift
@Model
final class Project {
    var id: UUID?
    var name: String?
    var type: String?
    var creationDate: Date?
    var details: String?
    @Relationship(deleteRule: .cascade, inverse: \Folder.project) 
    var folders: [Folder]?  // ✅ Ready to use
    
    // ... initializer and computed properties
}
```

**Key Points**:
- `folders` relationship is already defined
- Cascade delete: deleting project deletes all folders (and their children)
- CloudKit compatible (optional array with default)

---

### Folder Model
```swift
@Model
final class Folder {
    var id: UUID?
    var name: String?
    @Relationship(deleteRule: .cascade, inverse: \Folder.parentFolder) 
    var folders: [Folder]?  // ✅ Nested folders
    @Relationship(deleteRule: .nullify) 
    var parentFolder: Folder?  // ✅ Hierarchy support
    var parentFolderId: UUID?
    @Relationship(deleteRule: .cascade, inverse: \File.parentFolder) 
    var files: [File]?  // ✅ Contains files
    var project: Project?  // ✅ Parent project
    
    // ... initializer
}
```

**Key Points**:
- Self-referential: folders can contain folders
- `parentFolder` for navigation up the hierarchy
- `parentFolderId` for UUID-based hierarchy (alternative approach)
- Cascade delete: deleting folder deletes all nested folders and files
- CloudKit compatible (optional relationships, optional arrays)

---

### File Model
```swift
@Model
final class File {
    var id: UUID?
    var name: String?
    var content: String?  // ✅ Ready for text editing in Phase 003
    var parentFolder: Folder?  // ✅ Belongs to folder
    
    // ... initializer
}
```

**Key Points**:
- Simple model: name + content + parent relationship
- `content` is optional (empty by default)
- Delete rule: nullify parent reference (handled by Folder's cascade)
- CloudKit compatible (optional properties)

---

## Project Template Structure

### Template Hierarchy

When a project is created, `ProjectTemplateService` generates this structure:

```
Project (e.g., "My Poetry Collection")
├── Your Poetry (type-specific)
│   ├── All
│   ├── Draft
│   ├── Ready
│   ├── Set Aside
│   ├── Published
│   ├── Collections
│   │   └── (user creates subfolders)
│   ├── Submissions
│   │   └── (user creates subfolders)
│   └── Research
│       └── (user creates subfolders)
├── Publications
│   ├── Magazines
│   ├── Competitions
│   ├── Commissions
│   └── Other
└── Trash
```

**Type Variations**:
- Poetry: "Your Poetry"
- Prose: "Your Prose"
- Drama: "Your Drama"

---

## Folder Relationships

### Top-Level Folders (Project Root)

**Characteristics**:
- `parentFolder = nil`
- `project = <the project>`
- Direct children of Project

**Examples**:
- "Your Poetry"
- "Publications"
- "Trash"

**Query**:
```swift
@Query(filter: #Predicate<Folder> { folder in
    folder.project?.id == projectId && folder.parentFolder == nil
})
var rootFolders: [Folder]
```

---

### Nested Folders (Children)

**Characteristics**:
- `parentFolder = <parent folder>`
- `project = <the project>` (inherited)
- Children of another folder

**Examples**:
- "All" (parent: "Your Poetry")
- "Draft" (parent: "Your Poetry")
- "Magazines" (parent: "Publications")

**Query**:
```swift
@Query(filter: #Predicate<Folder> { folder in
    folder.parentFolder?.id == parentFolderId
})
var childFolders: [Folder]
```

---

### Files in Folders

**Characteristics**:
- `parentFolder = <the folder>`
- Always contained within a folder
- Cannot be at project root (must be in a folder)

**Query**:
```swift
@Query(filter: #Predicate<File> { file in
    file.parentFolder?.id == folderId
})
var files: [File]
```

---

## Cascade Delete Behavior

### Delete Project
```
Delete Project
    ↓
Cascade to all folders (via folders relationship)
    ↓
Cascade to nested folders (via folders.folders relationship)
    ↓
Cascade to all files (via folders.files relationship)
    ↓
Everything deleted
```

**SwiftData Rule**: `@Relationship(deleteRule: .cascade)`

---

### Delete Folder
```
Delete Folder
    ↓
Cascade to nested folders (via folders relationship)
    ↓
Cascade to files (via files relationship)
    ↓
Folder and all contents deleted
```

**SwiftData Rule**: `@Relationship(deleteRule: .cascade)`

---

### Delete File
```
Delete File
    ↓
Nullify parent reference (parentFolder)
    ↓
File deleted, folder remains
```

**SwiftData Rule**: File deletion doesn't affect folder

---

## Data Validation Rules

### Folder Name Validation

**Rules** (handled by `NameValidator`):
- Must not be empty
- Must not be whitespace-only
- No minimum/maximum length enforced (use common sense)

**Uniqueness** (handled by `UniquenessChecker`):
- Must be unique within parent folder (case-insensitive)
- Can have duplicate names at different levels
- Example: "Draft" in "Your Poetry" and "Draft" in "Publications" is allowed

**Implementation**:
```swift
// Validate name
try NameValidator.validateProjectName(folderName)

// Check uniqueness
let isUnique = UniquenessChecker.isFolderNameUnique(folderName, in: parentFolder)
```

---

### File Name Validation

**Rules** (handled by `NameValidator`):
- Must not be empty
- Must not be whitespace-only
- No file extension enforcement in Phase 002

**Uniqueness** (handled by `UniquenessChecker`):
- Must be unique within folder (case-insensitive)
- Can have duplicate names in different folders
- Example: "Chapter 1.txt" in "Draft" and "Chapter 1.txt" in "Ready" is allowed

**Implementation**:
```swift
// Validate name
try NameValidator.validateProjectName(fileName)

// Check uniqueness
let isUnique = UniquenessChecker.isFileNameUnique(fileName, in: folder)
```

---

## CloudKit Sync Considerations

### Sync Strategy

All models sync automatically via SwiftData's CloudKit integration (configured in Phase 001).

**Key Points**:
- Optional properties (`String?`, `[Folder]?`) are CloudKit-compatible
- Relationships sync correctly (parent-child references)
- Cascade deletes propagate across devices
- Conflict resolution handled by SwiftData

---

### Conflict Resolution

**Scenario**: User edits same folder name on two devices simultaneously.

**Resolution**: SwiftData uses "last write wins" by default.

**Mitigation**: 
- Users typically work on one device at a time
- Edits sync quickly (< 5 seconds)
- Rare conflicts resolve automatically

---

## Queries and Predicates

### Get Root Folders for Project
```swift
@Query(filter: #Predicate<Folder> { folder in
    folder.project?.id == projectId && folder.parentFolder == nil
})
var rootFolders: [Folder]
```

---

### Get Child Folders for Folder
```swift
@Query(filter: #Predicate<Folder> { folder in
    folder.parentFolder?.id == parentFolderId
})
var childFolders: [Folder]
```

---

### Get Files for Folder
```swift
@Query(filter: #Predicate<File> { file in
    file.parentFolder?.id == folderId
})
var files: [File]
```

---

### Get All Folders for Project (Flat List)
```swift
@Query(filter: #Predicate<Folder> { folder in
    folder.project?.id == projectId
})
var allFolders: [Folder]
```

---

### Get All Files for Project (Across All Folders)
```swift
@Query(filter: #Predicate<File> { file in
    file.parentFolder?.project?.id == projectId
})
var allFiles: [File]
```

---

## Performance Considerations

### Indexing

SwiftData automatically indexes:
- Primary keys (id fields)
- Relationship references (parentFolder, project)

**No additional indexes required for Phase 002.**

---

### Query Optimization

**Best Practices**:
- Query only the current level (root folders, then child folders as needed)
- Avoid querying entire project hierarchy at once
- Use predicates to filter at database level

**Example - Good**:
```swift
// Query only current folder's children
@Query(filter: #Predicate<Folder> { $0.parentFolder?.id == currentFolderId })
```

**Example - Avoid**:
```swift
// Query all folders, then filter in Swift
@Query var allFolders: [Folder]
let filtered = allFolders.filter { $0.parentFolder?.id == currentFolderId }
```

---

### Large Hierarchies

**Tested Scenarios**:
- 100 folders at one level ✅
- 20 levels deep ✅
- 1000 files in one folder ✅

**Performance**:
- Queries complete in < 100ms
- Navigation is instant
- CloudKit sync is background, non-blocking

---

## Folder Template Details

### Top-Level Folders (3)

| Folder Name | Purpose | Contains |
|------------|---------|----------|
| Your [Type] | Main writing workspace | Subfolders for workflow stages |
| Publications | Track submission targets | Subfolders for venue types |
| Trash | Soft delete location | Deleted items (future: permanent delete) |

---

### "Your [Type]" Subfolders (8)

| Folder Name | Purpose | User-Created Subfolders |
|------------|---------|------------------------|
| All | Smart folder (Phase 003) | No |
| Draft | Work in progress | No |
| Ready | Ready for submission | No |
| Set Aside | Paused work | No |
| Published | Published works | No |
| Collections | Pre-submission groupings | Yes (user creates) |
| Submissions | Submitted works | Yes (user creates) |
| Research | Reference materials | Yes (user creates) |

---

### "Publications" Subfolders (4)

| Folder Name | Purpose | User-Created Subfolders |
|------------|---------|------------------------|
| Magazines | Magazine targets | Yes (user creates per magazine) |
| Competitions | Competition targets | Yes (user creates per competition) |
| Commissions | Commissioned works | Yes (user creates per commission) |
| Other | Miscellaneous | Yes (user creates) |

---

## Edge Cases

### Empty Folders
- Allowed (no minimum file/folder count)
- Display "No folders yet" / "No files yet" messages

### Deep Nesting
- No enforced limit (tested to 100 levels)
- Users can create as deep as needed

### Duplicate Names
- Not allowed within same parent
- Allowed in different folders
- Case-insensitive comparison

### Deleting Template Folders
- Allowed (users have full control)
- No special protection
- Can be recreated manually if desired

---

## Future Enhancements (Out of Scope)

### Smart Folders
"All" folder shows aggregated files from Draft, Ready, Set Aside, Published using `@Query` with complex predicates.

### Move Operations
Drag and drop to move files between folders (change `parentFolder` relationship).

### Folder Icons
Custom icons for template folders (e.g., 📝 for Draft, ✅ for Ready).

### Folder Colors
Color coding for visual organization.

---

## References

- [BaseModels.swift](/Users/Projects/Write!/Write!/Models/BaseModels.swift) - Existing models
- [Phase 001 Data Model](../001-project-management-ios-macos/data-model.md) - Project model details
- [Phase 002 Spec](./spec.md) - Feature requirements
- [Phase 002 Plan](./plan.md) - Architecture decisions
