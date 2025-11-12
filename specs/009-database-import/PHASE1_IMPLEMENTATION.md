# Feature 009 - Implementation Kickoff

**Date**: 12 November 2025  
**Status**: ✅ ALL DECISIONS FINALIZED - READY TO BEGIN PHASE 1
**Timeline**: 11 days estimated

---

## Final Decisions Summary

| # | Decision | Your Choice | Status |
|---|----------|-------------|--------|
| 1 | Folder Structure | A: groupName → Project Type | ✅ |
| 2 | Scene Components | C: Create TextFile extension + SceneMetadata | ✅ |
| 3 | Submission Mapping | Keep duplicates (collection + publication) | ✅ |
| 4 | Data Integrity | C: Hybrid (warn, continue, rollback on error) | ✅ |
| 5 | AttributedString | Import only (NSAttributedString → RTF) | ✅ |
| 6 | Import Workflow | Check `hasPerformedImport` setting, block UI, rollback on error | ✅ |
| 7 | Database Location | `~/Library/Application Support/{bundle-id}/Writing-Shed.sqlite` | ✅ |
| 8 | Test Data | Use your Writing-Shed.sqlite database | ✅ |

---

## Phase 1: Core Infrastructure (Days 1-2)

### Goal
Create the foundation for reading legacy Core Data and converting to new SwiftData format.

### Tasks

#### 1.1: LegacyDatabaseService
**Purpose**: Read legacy Core Data store using NSPersistentStoreCoordinator

**File**: `Services/LegacyDatabaseService.swift`

**Responsibilities**:
- Locate legacy database: `~/Library/Application Support/{bundle-id}/Writing-Shed.sqlite`
- Create NSPersistentStoreCoordinator for read-only access
- Fetch WS_Project_Entity, WS_Text_Entity, WS_Version_Entity, WS_TextString_Entity
- Fetch WS_Collection_Entity, WS_CollectionSubmission_Entity
- Fetch WS_Scene_Entity, WS_Character_Entity, WS_Location_Entity
- Extract NSAttributedString from Core Data transformable

**Key Methods**:
```swift
class LegacyDatabaseService {
    func connect() throws
    
    // Project fetching
    func fetchProjects() throws -> [NSManagedObject]
    
    // Text fetching
    func fetchTexts(for project: NSManagedObject) throws -> [NSManagedObject]
    
    // Version fetching
    func fetchVersions(for text: NSManagedObject) throws -> [NSManagedObject]
    
    // TextString (content) fetching
    func fetchTextString(for version: NSManagedObject) throws -> NSAttributedString?
    
    // Scene/Character/Location fetching
    func fetchScenes(for project: NSManagedObject) throws -> [NSManagedObject]
    func fetchCharacters(for project: NSManagedObject) throws -> [NSManagedObject]
    func fetchLocations(for project: NSManagedObject) throws -> [NSManagedObject]
    
    // Collection fetching
    func fetchCollections(for project: NSManagedObject) throws -> [NSManagedObject]
    func fetchCollectionSubmissions(for collection: NSManagedObject) throws -> [NSManagedObject]
}
```

#### 1.2: Entity Mapping Functions
**Purpose**: Convert legacy Core Data objects to new SwiftData models

**File**: `Services/DataMapper.swift`

**Responsibilities**:
- Map WS_Project_Entity → Project
- Map WS_Text_Entity → TextFile
- Map WS_Version_Entity → Version
- Map WS_TextString_Entity → (String + RTF Data)
- Map WS_Scene_Entity → TextFile (with sceneType="Scene")
- Map WS_Character_Entity → TextFile (in Characters folder)
- Map WS_Location_Entity → TextFile (in Locations folder)
- Map WS_Collection_Entity → Submission (publication=nil)
- Map WS_CollectionSubmission_Entity → Submission (publication=set)

**Key Methods**:
```swift
class DataMapper {
    let legacyService: LegacyDatabaseService
    
    func mapProject(_ legacy: NSManagedObject) throws -> Project
    func mapTextFile(_ legacy: NSManagedObject, folder: Folder) throws -> TextFile
    func mapVersion(_ legacy: NSManagedObject, file: TextFile) throws -> Version
    func mapTextStringToContent(_ legacy: NSManagedObject) throws -> (String, Data?)
    func mapCollection(_ legacy: NSManagedObject, project: Project) throws -> Submission
    func mapScene(_ legacy: NSManagedObject, folder: Folder) throws -> TextFile
    func mapCharacter(_ legacy: NSManagedObject, project: Project) throws -> TextFile
    func mapLocation(_ legacy: NSManagedObject, project: Project) throws -> TextFile
}
```

#### 1.3: Folder Structure Builder
**Purpose**: Create folder hierarchy from legacy groupName values

**File**: `Services/LegacyImportEngine.swift` (part 1)

**Responsibilities**:
- Parse unique groupName values from legacy texts
- Create corresponding folders in new project
- Handle empty/null groupName (create "Imported" folder)
- Create auto-generated folders for Scenes, Characters, Locations

**Key Methods**:
```swift
class LegacyImportEngine {
    func createFolderStructure(
        project: Project,
        legacyFolderNames: [String]
    ) -> [String: Folder]
    
    func createAutoFolders(
        project: Project,
        forScenes: Bool,
        forCharacters: Bool,
        forLocations: Bool
    ) -> [String: Folder]
}
```

#### 1.4: AttributedString Conversion
**Purpose**: Convert NSAttributedString to RTF Data for storage

**File**: `Services/AttributedStringConverter.swift`

**Responsibilities**:
- Extract plain text from NSAttributedString
- Convert NSAttributedString to RTF Data
- Handle formatting edge cases
- Log conversion warnings

**Key Methods**:
```swift
class AttributedStringConverter {
    static func convert(_ attributed: NSAttributedString) throws -> (plainText: String, rtfData: Data?) {
        let plainText = attributed.string
        
        do {
            let range = NSRange(location: 0, length: attributed.length)
            let rtfData = try attributed.data(
                from: range,
                documentType: .rtf
            )
            return (plainText, rtfData)
        } catch {
            // RTF conversion failed, just use plain text
            return (plainText, nil)
        }
    }
}
```

#### 1.5: Error Handling & Rollback
**Purpose**: Implement hybrid error handling with rollback capability

**File**: `Services/ImportErrorHandler.swift`

**Responsibilities**:
- Collect all warnings/errors during import
- Implement database rollback on fatal error
- Generate import report
- Log detailed error information

**Key Methods**:
```swift
class ImportErrorHandler {
    var warnings: [String] = []
    var errors: [String] = []
    
    func addWarning(_ message: String)
    func addError(_ message: String)
    func isFatal() -> Bool
    
    func generateReport() -> ImportReport
    
    // Rollback on ModelContext
    func rollback(on modelContext: ModelContext) throws
}

struct ImportReport {
    let successCount: Int
    let warningCount: Int
    let errorCount: Int
    let warnings: [String]
    let errors: [String]
    let duration: TimeInterval
    let isFatal: Bool
}
```

#### 1.6: Progress Tracking
**Purpose**: Track import progress for UI display

**File**: `Services/ImportProgressTracker.swift`

**Responsibilities**:
- Track total items and processed count
- Calculate percentage completion
- Estimate time remaining
- Observable for SwiftUI binding

**Key Methods**:
```swift
@Observable
class ImportProgressTracker {
    var totalItems: Int = 0
    var processedItems: Int = 0
    var currentPhase: String = ""
    
    var percentComplete: Double { 
        totalItems > 0 ? Double(processedItems) / Double(totalItems) : 0 
    }
    
    func incrementProcessed()
    func setPhase(_ phase: String)
}
```

### Testing Strategy (Phase 1)

1. **Unit Tests**:
   - Test LegacyDatabaseService can connect to real database
   - Test entity mapping produces valid new models
   - Test AttributedString conversion (round-trip)
   - Test folder structure creation
   - Test error collection and reporting

2. **Integration Tests**:
   - Import sample project from legacy database
   - Verify all entities mapped correctly
   - Verify folder structure matches groupName values
   - Verify version relationships intact

3. **Manual Testing**:
   - Run with real Writing-Shed.sqlite database
   - Inspect imported data in SwiftData
   - Verify no data loss
   - Check AttributedString formatting preserved

---

## Phase 2: Scene Component Support (Days 3-4)

### Goal
Extend TextFile model and implement scene/character/location mapping.

### Tasks

#### 2.1: SceneMetadata Model Design
```swift
@Model
final class SceneMetadata {
    var id: UUID = UUID()
    var sceneType: String  // "Scene", "Character", "Location"
    var characters: [String] = []  // Character names
    var locations: [String] = []   // Location names
    var relatedScenes: [String] = [] // Related scene IDs
}
```

#### 2.2: TextFile Model Extension
```swift
@Model
final class TextFile {
    // Existing properties...
    
    // NEW: Scene support
    var sceneMetadata: SceneMetadata?
}
```

#### 2.3: Scene Relationship Mapping
- Map WS_Scene relationships to characters and locations
- Store as string arrays in SceneMetadata
- Handle bidirectional scene relationships

---

## Phase 3: Import Engine (Days 5-6)

### Goal
Orchestrate complete import process with all entity types.

### Tasks

#### 3.1: ImportOrchestrator
Coordinates phases:
1. Validate legacy database exists
2. Create project and folder structure
3. Import texts and versions
4. Import scenes, characters, locations
5. Import collections and submissions
6. Handle errors and rollback

#### 3.2: Submission Duplicate Handling
- Create collection Submission (publication=nil)
- For each collection submission, create publication Submission
- Copy SubmittedFiles between submissions

---

## Phase 4: Import UI & Workflow (Days 7-8)

### Goal
Implement first-launch import with progress UI and error handling.

### Tasks

#### 4.1: Check hasPerformedImport Setting
- Add to UserDefaults
- Check on app startup
- Only import if false AND legacy database exists

#### 4.2: Import Progress View
```swift
struct ImportProgressView: View {
    @Bindable var tracker: ImportProgressTracker
    
    // Show:
    // - Progress bar (percentComplete)
    // - Current phase (currentPhase)
    // - Item count (processed/total)
    // - No cancel button
}
```

#### 4.3: Error Handling & Rollback
- Catch import errors
- Rollback all changes to ModelContext
- Show error alert: "Import failed. Please try again later."
- Do NOT set hasPerformedImport = true
- User can retry on next app launch

---

## Phase 5: Testing & Polish (Days 9-11)

### Goal
Verify import with real data and optimize performance.

### Tasks

#### 5.1: Real Database Testing
- Import from user's actual Writing-Shed.sqlite
- Verify all project types (Novel, Script, Poetry, etc.)
- Check data integrity

#### 5.2: Edge Cases
- Empty projects
- Very large text files
- Corrupted Core Data
- Missing relationships
- Special characters in names

#### 5.3: Performance
- Profile import time
- Optimize database queries
- Minimize memory usage during import

---

## Immediate Next Steps (Today)

### 1. Prepare Legacy Database Samples ⏳
**Before coding Phase 1, extract real data samples**

- [ ] Locate your Writing-Shed.sqlite file
- [ ] Connect to it with Core Data inspector tools
- [ ] Extract sample entities:
  - [ ] 1 WS_Project_Entity
  - [ ] 1-2 WS_Text_Entity (regular and scene if available)
  - [ ] 1-2 WS_Version_Entity
  - [ ] 1 WS_TextString_Entity (for AttributedString inspection)
  - [ ] 1 WS_Character_Entity (if available)
  - [ ] 1 WS_Collection_Entity

### 2. Verify Database Accessibility ⏳
```swift
let supportURL = FileManager.default.urls(
    for: .applicationSupportDirectory,
    in: .userDomainMask
)[0]
let bundleID = Bundle.main.bundleIdentifier ?? "com.example"
let legacyDBURL = supportURL.appending(component: bundleID)
    .appending(component: "Writing-Shed.sqlite")

// Check if file exists
let exists = FileManager.default.fileExists(atPath: legacyDBURL.path)
```

### 3. Begin Phase 1 Implementation ⏳

Create skeleton files:
```
Services/
  LegacyDatabaseService.swift
  DataMapper.swift
  AttributedStringConverter.swift
  LegacyImportEngine.swift
  ImportErrorHandler.swift
  ImportProgressTracker.swift
```

---

## Implementation Notes

### SwiftData + Core Data Coexistence
- LegacyDatabaseService uses Core Data (NSPersistentStoreCoordinator)
- DataMapper converts to SwiftData models
- ModelContext saves converted data

### Error Handling Philosophy
- **Hybrid Approach**: Try to recover, warn user if needed
- **On Fatal Error**: Rollback entire import, tell user to retry later
- **No Partial Imports**: Either all succeeds or all rolls back

### Performance Considerations
- Batch fetch from Core Data (avoid N+1 queries)
- Use transactions for rollback reliability
- Monitor memory during large imports
- Show progress updates frequently (UI responsiveness)

### Testing Data
- Use real Writing-Shed.sqlite from user
- Test with various project types
- Test edge cases with corrupted data

---

## Success Criteria

### Phase 1 Complete When:
- ✅ LegacyDatabaseService successfully reads legacy database
- ✅ All entity types map correctly to new models
- ✅ AttributedString converts to RTF without data loss
- ✅ Folder structure matches legacy groupName
- ✅ Error handling and rollback working
- ✅ Unit tests passing (80%+ coverage)

### Full Feature Complete When:
- ✅ All phases implemented
- ✅ Tested with real user database
- ✅ No data loss observed
- ✅ Performance acceptable (<15 seconds for typical database)
- ✅ Error messages clear and actionable
- ✅ Integration tests passing
- ✅ UI/UX polished

---

## Questions Before Starting?

Ready to begin Phase 1 implementation? 

Key clarifications if needed:
1. Path to your Writing-Shed.sqlite file?
2. Approximate size of database (number of projects/texts)?
3. Any specific project type you want to prioritize testing?
4. Any known data corruption issues to handle?

Let me know if you're ready to start coding Phase 1! 🚀
