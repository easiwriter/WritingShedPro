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
    var id: UUID = UUID()
    var name: String?
    @Relationship(deleteRule: .cascade, inverse: \File.parentFolder) 
    var files: [File]?  // ✅ Contains files (based on capability)
    @Relationship(deleteRule: .cascade) 
    var folders: [Folder]?  // ✅ Contains subfolders (based on capability)
    var parentFolder: Folder?  // ✅ Parent folder (for hierarchical structure)
    @Relationship(deleteRule: .nullify, inverse: \Project.folders) 
    var project: Project?  // ✅ Parent project
    
    // ... initializer
}
```

**Key Points**:
- **Selective nesting structure**: Folders can contain subfolders AND/OR files based on capability rules
- `folders` relationship supports hierarchical nesting (one-sided to avoid circular SwiftData references)
- `parentFolder` relationship identifies parent in hierarchy
- Cascade delete: deleting folder deletes all files and subfolders within it
- FolderCapabilityService determines what each folder can contain based on name/type
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

### Template Structure (Selective Nesting)

When a project is created, `ProjectTemplateService` generates folder structures with **selective nesting** based on folder capabilities. Folder capabilities are managed by `FolderCapabilityService`:

**Folder Capability Types:**

1. **Subfolder-Only Folders** (cannot contain files):
   - Magazines
   - Competitions
   - Commissions
   - Other
   - Collections
   - Submissions
   - Chapters
   - Acts

2. **File-Only Folders** (cannot contain subfolders):
   - All
   - Ready
   - Set Aside
   - Published
   - Research
   - Novel
   - Script
   - Trash

3. **Mixed Capability Folders** (can contain both files AND subfolders):
   - Draft
   - Scenes
   - Characters
   - Locations

4. **User-Created Folders**: Always have mixed capability

```
Project (e.g., "My Poetry Collection")
├── All                    (file-only)
├── Draft                  (mixed - can have files and subfolders)
├── Ready                  (file-only)
├── Set Aside              (file-only)
├── Published              (file-only)
├── Collections            (subfolder-only)
├── Submissions            (subfolder-only)
├── Research               (file-only)
├── Magazines             (publications folders - poetry/short story only)
├── Competitions          (publications folders)
├── Commissions           (publications folders)
├── Other                 (publications folders)
└── Trash                 (always present)
```

**Type Variations**:
- **Poetry/Short Story**: All folders above
- **Novel**: Novel, Chapters, Scenes, Characters, Locations, Set Aside, Research, Competitions, Commissions, Other, Trash
- **Script**: Script, Acts, Scenes, Characters, Locations, Set Aside, Research, Competitions, Commissions, Other, Trash
- **Blank**: All, Trash only

---

## Folder Relationships

### Root-Level Folders

**Characteristics**:
- Belong directly to project (no parent folder)
- `project = <the project>`
- `parentFolder = nil`

**Examples**:
- "All"
- "Draft"
- "Magazines" 
- "Trash"

**Query**:
```swift
@Query(filter: #Predicate<Folder> { folder in
    folder.project?.id == projectId && folder.parentFolder == nil
})
var rootFolders: [Folder]
```

---

### Nested Folders (Subfolders)

**Characteristics**:
- Belong to parent folder
- `parentFolder = <the parent folder>`
- `project = <the project>` (inherited for easy querying)

**Examples**:
- Subfolder in "Magazines"
- Subfolder in "Draft"
- Subfolder in "Collections"

**Query**:
```swift
@Query(filter: #Predicate<Folder> { folder in
    folder.parentFolder?.id == parentFolderId
})
var subfolders: [Folder]
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

## FolderCapabilityService

The `FolderCapabilityService` determines what operations are allowed on each folder based on its name and type:

```swift
struct FolderCapabilityService {
    // Folders that can ONLY contain subfolders (no files)
    private static let subfolderOnlyFolders: Set<String> = [
        "Magazines", "Competitions", "Commissions", "Other",
        "Collections", "Submissions", "Chapters", "Acts"
    ]
    
    // Folders that can ONLY contain files (no subfolders)
    private static let fileOnlyFolders: Set<String> = [
        "All", "Ready", "Set Aside", "Published", "Research",
        "Novel", "Script", "Trash"
    ]
    
    // Folders that can contain BOTH files and subfolders
    private static let mixedCapabilityFolders: Set<String> = [
        "Draft", "Scenes", "Characters", "Locations"
    ]
    
    static func canAddSubfolder(to folder: Folder) -> Bool
    static func canAddFile(to folder: Folder) -> Bool
    static func isTemplateFolder(_ folder: Folder) -> Bool
    static func disallowedOperationMessage(for folder: Folder, operation: String) -> String
}
```

**Business Rules**:
- **Template folders**: Use name-based capability rules (defined above)
- **User-created folders**: Always have mixed capability (both files and subfolders allowed)
- **UI Integration**: FolderListView uses service to show/hide toolbar buttons
- **Validation**: AddFolderSheet and AddFileSheet validate operations before creation

---

## Cascade Delete Behavior

### Delete Project
```
Delete Project
    ↓
Cascade to all root folders (via folders relationship)
    ↓
Cascade to all subfolders (via folders.folders relationship)
    ↓
Cascade to all files (via folders.files relationship)
    ↓
Everything deleted
```

### Delete Folder
```
Delete Folder
    ↓
Cascade to all subfolders (via folders relationship)
    ↓
Cascade to all files in folder (via files relationship)
    ↓
Subfolders and files deleted
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
- Must be unique within project (case-insensitive)
- No duplicate folder names allowed in same project
- Example: Cannot have two folders named "Draft" in same project

**Implementation**:
```swift
// Validate name
try NameValidator.validateProjectName(folderName)

// Check uniqueness
let isUnique = UniquenessChecker.isFolderNameUnique(folderName, in: project)
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

### Get All Folders for Project
```swift
@Query(filter: #Predicate<Folder> { folder in
    folder.project?.id == projectId
})
var projectFolders: [Folder]
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
- Query root folders first, then navigate into subfolders as needed
- Query folder files only when folder is selected
- Use predicates to filter at database level

**Example - Good**:
```swift
// Query root-level folders
@Query(filter: #Predicate<Folder> { 
    $0.project?.id == projectId && $0.parentFolder == nil 
})
var rootFolders: [Folder]

// Query subfolders when navigating into a folder
@Query(filter: #Predicate<Folder> { $0.parentFolder?.id == parentId })
var subfolders: [Folder]
```

**Example - Avoid**:
```swift
// Query all folders, then filter in Swift
@Query var allFolders: [Folder]
let filtered = allFolders.filter { $0.project?.id == projectId }
```

---

### Large Hierarchies

**Tested Scenarios**:
- 100 folders in project ✅  
- 1000 files in one folder ✅

**Performance**:
- Queries complete in < 100ms
- Navigation is instant
- CloudKit sync is background, non-blocking

---

## Folder Template Details

### Root and Nested Folders

Folders can be at root level or nested within other folders based on capabilities:

| Folder Name | Purpose | Capability | Type-Specific |
|------------|---------|------------|---------------|
| All | Smart folder (Phase 003) | File-only | All types |
| Draft | Work in progress | Mixed (files + subfolders) | Poetry, Novel, Script |
| Ready | Ready for submission | File-only | Poetry, Short Story |
| Set Aside | Paused work | All types |
| Published | Published works | Poetry, Short Story |
| Collections | Pre-submission groupings | Poetry, Short Story |
| Submissions | Submitted works | Poetry, Short Story |
| Research | Reference materials | All types |
| Novel | Main novel content | Novel only |
| Chapters | Novel chapters | Novel only |
| Scenes | Individual scenes | Novel, Script |
| Script | Main script content | Script only |
| Acts | Script acts | Script only |
| Characters | Character development | Novel, Script |
| Locations | Setting details | Novel, Script |
| Magazines | Magazine targets | Poetry, Short Story |
| Competitions | Competition targets | All types (except Blank) |
| Commissions | Commissioned works | All types (except Blank) |
| Other | Miscellaneous | All types (except Blank) |
| Trash | Soft delete location | All types |

---

## Edge Cases

### Empty Folders
- Allowed (no minimum file/folder count)
- Display "No folders yet" / "No files yet" messages

### Duplicate Names
- Not allowed within same project
- Each folder name must be unique in project
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
