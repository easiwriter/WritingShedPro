# Data Model: Project Management (iOS/MacOS, MacCatalyst)

## Entity: Project
- id: UUID (auto-generated; used for identification; uniqueness not enforced by SwiftData)
- name: String (non-empty; uniqueness enforced in application logic)
- type: Enum (blank, novel, poetry, script, shortStory)
- creationDate: Date
- details: String (optional)
- files: [File] (nested, supports folders)

## Platform Context
- The app is a multiplatform Xcode app targeting iOS and macOS via MacCatalyst.
- Shared models and services are used for both platforms.

## Entity: File
- id: UUID
- name: String
- content: String
- parentFolder: Folder (optional)
- project: Project (parent)

## Entity: Folder
- id: UUID
- name: String
- files: [File]
- folders: [Folder] (nested)
- project: Project (parent)

## Validation Rules
- Project name must be non-empty; uniqueness is enforced in application logic (not by SwiftData)
- File and folder names must be non-empty
- Folder names must be unique within their parent folder (enforced in application logic)
- File names must be unique within their folder (enforced in application logic)
- Deleting a project deletes all files/folders within
- Renaming to an empty string is rejected

## State Transitions
- Project: created → renamed → deleted
- File/Folder: created → renamed → moved → deleted

## Localization Considerations
- All user-facing strings (error messages, button labels, placeholder text) must use `LocalizedStringResource` or `.strings` files
- Project type enum values (`blank`, `novel`, `poetry`, `script`, `shortStory`) should have localized display names

