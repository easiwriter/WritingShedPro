# 003: Text File Creation

## Overview
Enable users to create and manage text files within the "All" folder of blank projects. This feature focuses on the core writing functionality with minimal complexity.

## Scope
- **Target**: Blank projects only (simplest case)
- **Location**: "All" folder within "BLANK" project type folder
- **Functionality**: Create, edit, and manage text files

## Requirements

### 1. Data Model Enhancement
- Add `TextFile` model as container for file metadata and versions
- Add `Version` model to store actual text content and version history
- Ensure proper SwiftData relationships and CloudKit sync
- Implement version navigation and management

### 2. User Interface
- Add text file creation option in the "All" folder
- Provide text editing interface with version management
- Display list of text files in folder view
- Add version history navigation UI

### 3. Core Features
- Create new text files with names
- Edit text file content with automatic versioning
- Navigate between different versions of the same file
- Save changes automatically
- Delete text files (and all versions)
- Basic file management (rename)
- Version history with timestamps

## Technical Approach

### Data Model
```swift
@Model
final class TextFile {
    var id: UUID = UUID()
    var name: String
    var createdDate: Date
    var modifiedDate: Date
    var currentVersionIndex: Int = 0
    var parentFolder: Folder?
    
    @Relationship(deleteRule: .cascade, inverse: \Version.textFile)
    var versions: [Version] = []
}

@Model 
final class Version {
    var id: UUID = UUID()
    var content: String
    var createdDate: Date
    var versionNumber: Int
    var comment: String?
    var textFile: TextFile?
}
```

### Implementation Strategy
1. Create `TextFile` and `Version` models with proper relationships
2. Add file creation UI to folder views
3. Implement text editor view with version support
4. Add version navigation interface
5. Ensure proper data persistence and sync
6. Maintain existing folder structure integrity

## Success Criteria
- [ ] User can create text files in "All" folder of blank projects
- [ ] Text files support multiple versions with navigation
- [ ] Versions persist across app sessions
- [ ] Text files and versions sync via CloudKit
- [ ] Simple, intuitive user experience for writing and versioning
- [ ] No impact on existing project/folder functionality

## Out of Scope (for this iteration)
- File operations in non-blank projects
- Complex folder operations
- File import/export
- Rich text formatting
- File collaboration features

## Dependencies
- Existing Project and Folder models
- Current SwiftData + CloudKit setup
- Existing UI components (AddProjectSheet, FolderListView)

## Notes
This minimal approach ensures we build core writing functionality without overwhelming complexity. Focus on getting the basic text file creation and editing working perfectly before adding advanced features.