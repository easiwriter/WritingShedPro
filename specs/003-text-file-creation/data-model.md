# Data Model Specification

## TextFile Model

### Core Properties
```swift
@Model
final class TextFile {
    var id: UUID = UUID()
    var name: String
    var content: String
    var createdDate: Date
    var modifiedDate: Date
    
    // SwiftData Relationships
    @Relationship(deleteRule: .nullify) 
    var parentFolder: Folder?
    
    init(name: String, content: String = "", parentFolder: Folder? = nil) {
        self.name = name
        self.content = content
        self.createdDate = Date()
        self.modifiedDate = Date()
        self.parentFolder = parentFolder
    }
    
    func updateContent(_ newContent: String) {
        self.content = newContent
        self.modifiedDate = Date()
    }
}
```

### Integration with Existing Models

#### Folder Model Updates
```swift
@Model
final class Folder {
    // ... existing properties ...
    
    // Add relationship to text files
    @Relationship(deleteRule: .cascade, inverse: \TextFile.parentFolder) 
    var textFiles: [TextFile] = []
    
    // ... existing code ...
}
```

### CloudKit Considerations
- `TextFile` will automatically sync via CloudKit through SwiftData
- Ensure proper `@Attribute` annotations for CloudKit compatibility
- Consider file size limits for CloudKit (1MB per record)

### Database Schema Changes
- New `TextFile` table will be created
- Foreign key relationship to existing `Folder` table
- Automatic migration handled by SwiftData

### Validation Rules
- File name must be non-empty
- File name must be unique within parent folder
- Content can be empty (new file)
- Dates automatically managed

### Performance Considerations
- Index on `parentFolder` for fast folder-based queries
- Consider lazy loading for large text content
- Batch operations for multiple file changes

## Data Flow

1. **Create**: User creates TextFile → Added to Folder.textFiles → Syncs to CloudKit
2. **Read**: Folder loads → TextFiles queried by relationship → Displayed in UI
3. **Update**: Content modified → modifiedDate updated → Auto-sync to CloudKit
4. **Delete**: TextFile removed → Cascade delete handled by SwiftData

## Migration Strategy
- New model addition (no existing data to migrate)
- SwiftData handles schema evolution automatically
- No breaking changes to existing Project/Folder models