# Data Model Specification

## TextFile Model (Parent Container)

### Core Properties
```swift
@Model
final class TextFile {
    var id: UUID = UUID()
    var name: String
    var createdDate: Date
    var modifiedDate: Date
    var currentVersionIndex: Int = 0  // Points to active version
    
    // SwiftData Relationships
    @Relationship(deleteRule: .nullify) 
    var parentFolder: Folder?
    
    @Relationship(deleteRule: .cascade, inverse: \Version.textFile)
    var versions: [Version] = []
    
    init(name: String, initialContent: String = "", parentFolder: Folder? = nil) {
        self.name = name
        self.createdDate = Date()
        self.modifiedDate = Date()
        self.parentFolder = parentFolder
        
        // Create initial version
        let firstVersion = Version(content: initialContent, versionNumber: 1)
        self.versions = [firstVersion]
    }
    
    // Computed properties for easy access
    var currentVersion: Version? {
        guard currentVersionIndex < versions.count else { return versions.first }
        return versions[currentVersionIndex]
    }
    
    var currentContent: String {
        return currentVersion?.content ?? ""
    }
    
    // Version management methods
    func createNewVersion(content: String) -> Version {
        let nextVersionNumber = (versions.map { $0.versionNumber }.max() ?? 0) + 1
        let newVersion = Version(content: content, versionNumber: nextVersionNumber)
        versions.append(newVersion)
        currentVersionIndex = versions.count - 1
        modifiedDate = Date()
        return newVersion
    }
    
    func switchToVersion(_ version: Version) {
        if let index = versions.firstIndex(of: version) {
            currentVersionIndex = index
            modifiedDate = Date()
        }
    }
}
```

## Version Model (Content Container)

### Core Properties
```swift
@Model
final class Version {
    var id: UUID = UUID()
    var content: String
    var createdDate: Date
    var versionNumber: Int
    var comment: String?  // Optional user comment for this version
    
    // SwiftData Relationships
    @Relationship(deleteRule: .nullify)
    var textFile: TextFile?
    
    init(content: String, versionNumber: Int, comment: String? = nil) {
        self.content = content
        self.versionNumber = versionNumber
        self.comment = comment
        self.createdDate = Date()
    }
    
    func updateContent(_ newContent: String) {
        self.content = newContent
    }
}
```

### Integration with Existing Models

#### Folder Model Updates
```swift
@Model
final class Folder {
    // ... existing properties ...
    
    // Add relationship to text files (unchanged)
    @Relationship(deleteRule: .cascade, inverse: \TextFile.parentFolder) 
    var textFiles: [TextFile] = []
    
    // ... existing code ...
}
```

### CloudKit Considerations
- Both `TextFile` and `Version` will sync via CloudKit through SwiftData
- `Version.content` field may hit CloudKit 1MB limit for very large documents
- Consider chunking large content or using CloudKit assets for large files
- Version history provides built-in backup and recovery

### Database Schema Changes
- New `TextFile` table (container for versions)
- New `Version` table (actual content storage)
- Foreign key relationships: `TextFile` → `Folder`, `Version` → `TextFile`
- Automatic migration handled by SwiftData

### Validation Rules
- File name must be non-empty and unique within parent folder
- Each TextFile must have at least one version
- Version numbers must be sequential and unique within TextFile
- Content can be empty (new version)
- currentVersionIndex must be valid array index

### Performance Considerations
- Index on `parentFolder` for fast folder-based queries
- Index on `versionNumber` for fast version navigation
- Consider lazy loading for version content to improve list performance
- Batch operations for multiple version changes

## Data Flow

1. **Create**: User creates TextFile → Initial Version created → Added to Folder.textFiles → Syncs to CloudKit
2. **Read**: Folder loads → TextFiles queried → Current version content displayed
3. **Edit**: Content modified → New Version created OR current version updated → Auto-sync to CloudKit
4. **Version Navigation**: User switches versions → currentVersionIndex updated → UI shows different content
5. **Delete**: TextFile removed → All versions cascade deleted → SwiftData handles cleanup

## Versioning Strategy

### When to Create New Versions
- **Manual**: User explicitly creates new version
- **Auto-save intervals**: Every N minutes of editing
- **Significant changes**: After substantial content modifications
- **Session-based**: New version when reopening file

### Version Management
- Keep unlimited versions (user can manually clean up)
- Display version list with timestamps and comments
- Allow version comparison (future enhancement)
- Support version merging (future enhancement)

## Migration Strategy
- New model addition (no existing data to migrate)
- SwiftData handles schema evolution automatically
- No breaking changes to existing Project/Folder models