# 003: Text File Creation

## Overview
Enable users to create and manage text files within the "All" folder of blank projects. This feature focuses on the core writing functionality with minimal complexity.

## Scope
- **Target**: Blank projects only (simplest case)
- **Location**: "All" folder within "BLANK" project type folder
- **Functionality**: Create, edit, and manage text files

## Requirements

### 1. Data Model Enhancement
- Add `TextFile` model type extending the existing `File` model
- Ensure proper SwiftData relationships and CloudKit sync

### 2. User Interface
- Add text file creation option in the "All" folder
- Provide text editing interface
- Display list of text files in folder view

### 3. Core Features
- Create new text files with names
- Edit text file content
- Save changes automatically
- Delete text files
- Basic file management (rename)

## Technical Approach

### Data Model
```swift
@Model
final class TextFile {
    var id: UUID = UUID()
    var name: String
    var content: String
    var createdDate: Date
    var modifiedDate: Date
    var parentFolder: Folder?
    
    // Relationship to existing folder structure
}
```

### Implementation Strategy
1. Extend existing `File` model or create `TextFile` model
2. Add file creation UI to folder views
3. Implement text editor view
4. Ensure proper data persistence
5. Maintain existing folder structure integrity

## Success Criteria
- [ ] User can create text files in "All" folder of blank projects
- [ ] Text files persist across app sessions
- [ ] Text files sync via CloudKit
- [ ] Simple, intuitive user experience
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