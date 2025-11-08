# Full Migration: File → TextFile
## Integration Phase: Feature 008a

**Date**: November 8, 2025  
**Branch**: 008-file-movement-system  
**Goal**: Complete migration from legacy `File` model to `TextFile` model + integrate file movement features

---

## Overview

The app currently uses two file models:
- **`File`** (legacy) - Used by existing app views (FileEditableList, FileEditView, etc.)
- **`TextFile`** (new) - Used by Feature 008a components (FileListView, FileMoveService, TrashView)

This migration will:
1. Remove the legacy `File` model entirely
2. Update all views and services to use `TextFile`
3. Integrate the new FileListView component
4. Add Trash navigation to the sidebar
5. Update tests to work with TextFile

---

## Files to Modify

### Models
- ✅ `BaseModels.swift` - Remove `File` class, keep only `TextFile`
- ✅ `Write_App.swift` - Remove `File.self` from schema

### Services
- ✅ `TextFileUndoManager.swift` - Update to work with `TextFile` instead of `File`
- ✅ `FileSortService.swift` - Update sort methods for `TextFile`

### Views (Replace FileEditableList with FileListView)
- ✅ `FileEditableList.swift` - DELETE this file (replaced by FileListView)
- ✅ `FolderListView.swift` - Update navigation to use FileListView
- ✅ `FolderDetailView.swift` - Update to show TextFile data
- ✅ `FileEditView.swift` - Update to accept TextFile instead of File
- ✅ `AddFileSheet.swift` - Create TextFile instead of File

### Sidebar/Navigation
- ✅ Add TrashView to sidebar navigation
- ✅ Wire up Trash to project context

### Tests
- ✅ `UndoRedoTests.swift` - Update to use TextFile
- ✅ `TypingCoalescingTests.swift` - Update to use TextFile
- ❓ Any other tests referencing File model

---

## Migration Steps

### Step 1: Update BaseModels.swift (Remove File Model)
**Action**: Delete the entire `File` class from BaseModels.swift

**Rationale**: TextFile is the replacement, has all necessary features plus better CloudKit support

**Impact**: High - breaks all existing file-related views

---

### Step 2: Update Folder Model Relationships
**Action**: Remove `files` relationship from Folder, keep only `textFiles`

```swift
@Model
final class Folder {
    // REMOVE THIS:
    // @Relationship(deleteRule: .cascade, inverse: \File.parentFolder) var files: [File]?
    
    // KEEP THIS:
    @Relationship(deleteRule: .cascade) var textFiles: [TextFile]?
}
```

**Impact**: Medium - FileEditableList currently uses `folder.files`

---

### Step 3: Update Write_App.swift Schema
**Action**: Remove `File.self` from ModelContainer schema

```swift
// BEFORE:
Schema([
    Project.self,
    Folder.self,
    File.self,  // ← REMOVE THIS
    TextFile.self,
    // ...
])

// AFTER:
Schema([
    Project.self,
    Folder.self,
    TextFile.self,
    // ...
])
```

---

### Step 4: Replace FileEditableList with FileListView Integration

**FileEditableList.swift** - DELETE ENTIRE FILE

**FolderListView.swift** - Update navigation:
```swift
// BEFORE:
NavigationLink(destination: FileEditableList(folder: folder)) {
    FolderRowView(folder: folder)
}

// AFTER:
NavigationLink(destination: FolderFilesView(folder: folder)) {
    FolderRowView(folder: folder)
}
```

**Create NEW: FolderFilesView.swift**:
```swift
struct FolderFilesView: View {
    @Bindable var folder: Folder
    @Environment(\.modelContext) var modelContext
    
    @State private var showMoveDestinationPicker = false
    @State private var filesToMove: [TextFile] = []
    @State private var showAddFileSheet = false
    
    var body: some View {
        FileListView(
            files: folder.textFiles ?? [],
            onFileSelected: { file in
                // Navigate to FileEditView
            },
            onMove: { files in
                filesToMove = files
                showMoveDestinationPicker = true
            },
            onDelete: { files in
                let service = FileMoveService(modelContext: modelContext)
                try? service.deleteFiles(files)
            }
        )
        .navigationTitle(folder.name ?? "Files")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showAddFileSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showMoveDestinationPicker) {
            if let project = folder.project {
                MoveDestinationPicker(
                    project: project,
                    currentFolder: folder,
                    filesToMove: filesToMove,
                    onDestinationSelected: { destination in
                        let service = FileMoveService(modelContext: modelContext)
                        try? service.moveFiles(filesToMove, to: destination)
                        showMoveDestinationPicker = false
                    },
                    onCancel: {
                        showMoveDestinationPicker = false
                    }
                )
            }
        }
        .sheet(isPresented: $showAddFileSheet) {
            AddFileSheet(
                isPresented: $showAddFileSheet,
                parentFolder: folder,
                existingFiles: folder.textFiles ?? []
            )
        }
    }
}
```

---

### Step 5: Update FileEditView to Use TextFile

**Before**:
```swift
struct FileEditView: View {
    @Bindable var file: File  // ← OLD
    // ...
}
```

**After**:
```swift
struct FileEditView: View {
    @Bindable var file: TextFile  // ← NEW
    // ...
}
```

**Changes Needed**:
- Update all property access to use TextFile API
- Version management should work the same way
- Undo/redo needs TextFileUndoManager update (Step 6)

---

### Step 6: Update TextFileUndoManager

**Before**:
```swift
class TextFileUndoManager {
    private weak var file: File?
    
    init(file: File, maxStackSize: Int = 100) {
        self.file = file
    }
}
```

**After**:
```swift
class TextFileUndoManager {
    private weak var file: TextFile?
    
    init(file: TextFile, maxStackSize: Int = 100) {
        self.file = file
    }
    
    // Update all methods to work with TextFile
    // file.undoStackData, file.redoStackData, etc.
}
```

**Note**: TextFile already has version management, may need to add undo stack properties

---

### Step 7: Update AddFileSheet to Create TextFile

**Before**:
```swift
let newFile = File(name: name, content: "")
```

**After**:
```swift
let newFile = TextFile(name: name, initialContent: "", parentFolder: parentFolder)
```

---

### Step 8: Update FileSortService

**FileSortService.swift** - Update to sort `TextFile` instead of `File`:
```swift
// Change method signature
static func sort(_ files: [TextFile], by order: FileSortOrder) -> [TextFile] {
    // Update implementation
}
```

---

### Step 9: Add Trash to Sidebar Navigation

**ContentView.swift** or **SidebarView.swift** - Add Trash link:
```swift
Section {
    NavigationLink(destination: TrashView(project: selectedProject)) {
        Label("Trash", systemImage: "trash")
    }
}
```

---

### Step 10: Fix Tests

**UndoRedoTests.swift**:
```swift
// BEFORE:
var testFile: File!
testFile = File(name: "Test File", content: "Hello World")

// AFTER:
var testFile: TextFile!
testFile = TextFile(name: "Test File", initialContent: "Hello World")
```

**TypingCoalescingTests.swift** - Same pattern

---

## Testing Plan

### Unit Tests
1. Run all 008a tests (should still pass)
2. Run UndoRedoTests (fix File → TextFile)
3. Run TypingCoalescingTests (fix File → TextFile)
4. Run any other File-related tests

### Manual Testing
1. Create new project
2. Add files to Draft folder
3. Move files between folders
4. Delete files to Trash
5. Put back files from Trash
6. Edit file content
7. Test undo/redo
8. Test CloudKit sync

---

## Rollback Plan

If migration causes critical issues:
1. Revert commit
2. Keep on feature branch until fixed
3. DO NOT merge to main until stable

---

## Success Criteria

✅ All code compiles without errors  
✅ All 113 unit tests pass  
✅ Can create files in folders  
✅ Can move files between folders  
✅ Can delete files to trash  
✅ Can restore files from trash  
✅ Can edit file content  
✅ Undo/redo works  
✅ CloudKit sync works  

---

## Timeline

**Estimated**: 4-6 hours  
**Start**: November 8, 2025  
**Target Completion**: Same day

---

## Notes

- This is a **breaking change** for the data model
- Existing app data will need migration (if any real data exists)
- Consider creating a data migration script if needed
- Test thoroughly before merging to main

---

**Status**: 🚧 IN PROGRESS  
**Next Step**: Remove File model from BaseModels.swift
