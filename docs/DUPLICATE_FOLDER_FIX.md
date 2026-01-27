# Duplicate Folder Fix

## Issue
After importing .wsp backup files, folders like "Front Matter", "Back Matter", and "All Sections" (or "All Chapters", "All Stories") appeared twice in the project - once at the root level and once as a subfolder of Manuscript.

A related crash can occur:
```
Fatal error: This model instance was invalidated because its backing data could no longer be found the store.
```

## Root Cause
The issue had two contributing factors:

### 1. Data Structure Issue
SwiftData folders have two relationships:
- `folder.project` - links root-level folders to the project
- `folder.parentFolder` - links subfolders to their parent

The original code was setting BOTH `project` AND `parentFolder` on subfolders. This meant subfolders appeared in both:
- `project.folders` (all folders with `project` relationship)
- `parentFolder.folders` (all folders with that parent)

### 2. Export Logic Issue
The `buildFolderData(from project:)` method in `JSONExportService.swift` was exporting ALL folders from `project.folders` at the top level, then each folder recursively exported its subfolders. This caused duplication in the export file.

### 3. Crash Issue
When folders are deleted but SwiftData keeps references to them in relationship arrays, accessing those invalidated objects causes a crash.

## Fix Applied

### 1. Write_App.swift - Early Cleanup
Added `MigrationService.cleanupOrphanedFoldersEarly()` call immediately after ModelContainer creation, BEFORE any views load. This prevents crashes from invalidated folder objects.

### 2. MigrationService.swift - Cleanup Logic
Added `cleanupOrphanedFoldersEarly()` method that:
- Removes `project` reference from subfolders (folders that have both project AND parentFolder)
- Deletes orphaned folders (folders with neither project nor parentFolder)

### 3. JSONExportService.swift
Modified `buildFolderData(from project:)` to filter out folders that have a parent:

```swift
let rootFolders = folders.filter { $0.parentFolder == nil }
```

### 4. AddFolderSheet.swift
Modified folder creation to only set `project` on root-level folders:

```swift
let newFolder = Folder(name: folderName, project: parentFolder == nil ? project : nil, parentFolder: parentFolder)
```

### 5. ProjectTemplateService.swift
Modified subfolder creation to NOT set `project`:

```swift
let subfolder = Folder(name: name, project: nil, userOrder: index)
subfolder.parentFolder = manuscriptFolder
```

### 6. BaseModels.swift - Project Extensions
Added helper methods to find matter folders consistently:

```swift
func findBackMatterFolder() -> Folder?
func findFrontMatterFolder() -> Folder?
func findManuscriptFolder() -> Folder?
```

These helpers check both root level (legacy) and Manuscript subfolder (modern structure), and handle nil names safely.

### 7. Updated Usages
Updated all places that looked for Back Matter folder to use the new `project.findBackMatterFolder()` helper:
- FileEditView.swift (multiple locations)
- ReferenceEditorSheet.swift
- TextStyleEditorView.swift

## Impact
- **Startup**: Early cleanup runs before any views load, preventing crashes
- **Export**: New exports will only include root-level folders at the top level; subfolders are included recursively via their parent
- **Import**: No changes needed - import already handles parent relationships correctly
- **New Projects**: Subfolders correctly have `project: nil` and only `parentFolder` set
- **Existing Projects**: Automatically cleaned up on app launch

## Testing
1. Launch app → should not crash
2. Check console for "Early cleanup" messages showing fixed folders
3. Create a new project → verify Manuscript subfolders appear only under Manuscript
4. Export project to .wsp → verify folders only appear once in JSON
5. Import .wsp → verify no duplicate folders
6. Check Back Matter file generation still works
