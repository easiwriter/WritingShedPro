# Write Development Guidelines

Auto-generated from all feature plans. Last updated: 2025-10-20

## Active Technologies
- (001-project-management-ios-macos)

## Project Structure
```
backend/
frontend/
tests/
```

## Commands
# Add commands for 

## Code Style
: Follow standard conventions
- **Do NOT create #Preview blocks** - Previews are not used in this project

## SwiftData + CloudKit Requirements
When creating SwiftData @Model classes with CloudKit integration:
- **All attributes must be optional OR have default values** (CloudKit requirement)
- **Do NOT use @Attribute(.unique)** - CloudKit does not support unique constraints
- Use optional properties (with `?`) or provide explicit default values in init
- Example: `var id: UUID = UUID()` or `var name: String?`

## Recent Changes
- 001-project-management-ios-macos: Added
- 014-comments: SwiftData/CloudKit requirements documented

<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->
