# Feature Specification: Writing Shed Database Import

**Feature ID**: 013  
**Created**: 9 November 2025  
**Status**: Planning / Critical for Migration  
**Priority**: High (for existing users)  
**Dependencies**: Core data models, CloudKit setup

---

## Overview

Import data from the original Writing Shed app (legacy version) into Writing Shed Pro, preserving user's existing projects, files, and metadata.

---

## Goals

- Enable seamless migration from Writing Shed to Writing Shed Pro
- Preserve all user data (projects, folders, files, versions, formatting)
- Maintain file organization and structure
- Minimal user intervention required
- Prevent data loss during migration
- Support both local and iCloud databases

---

## Background

### Original Writing Shed
- Built with Core Data
- Supports iCloud sync (probably NSPersistentCloudKitContainer)
- Has existing data model with projects, folders, files
- Unknown version history - may have undergone schema changes

### Writing Shed Pro
- Built with SwiftData
- Uses CloudKit for sync
- New data model (similar but not identical)
- Enhanced features not in original app

---

## Migration Challenges

### 1. Data Model Differences

**Potential Differences**:
- Original: `File` model → New: `TextFile` model
- Different relationship structures
- New features (versions, submissions, etc.) don't exist in old app
- UUID vs. other identifier types
- Attribute name changes

**Solution**: Mapping layer between old and new models

### 2. Core Data to SwiftData

**Technical Challenge**: Core Data and SwiftData are not directly compatible

**Approach Options**:
1. **Read Core Data, Write SwiftData** - Fetch from Core Data store, create SwiftData objects
2. **Export/Import** - Export old data to intermediate format (JSON), import to new
3. **Dual Stack** - Temporarily run both Core Data and SwiftData, copy data

**Recommended**: Option 1 (direct read/write) for best user experience

### 3. iCloud Data

**Challenge**: If user has data in iCloud from original app, how to import?

**Considerations**:
- May need to access old CloudKit containers
- Sync state might be incomplete
- User might have data on multiple devices

**Solution**: Import from local device only, user chooses which device to migrate from

### 4. File Content & Formatting

**Challenge**: Preserve rich text formatting

**Original Format**: Likely NSAttributedString stored as data
**New Format**: NSAttributedString in SwiftData

**Requirements**:
- Preserve bold, italic, underline
- Preserve font sizes and styles
- Preserve paragraph formatting
- Preserve images (if supported in original)
- Handle legacy format quirks

---

## Import Process Design

### User Flow

**Step 1: Discovery**
```
┌─────────────────────────────────────┐
│ Welcome to Writing Shed Pro         │
├─────────────────────────────────────┤
│ We detected Writing Shed data on    │
│ this device.                        │
│                                     │
│ Projects found: 5                   │
│ Files found: 127                    │
│                                     │
│ Would you like to import your       │
│ existing work?                      │
│                                     │
│ [Not Now]       [Import Data]       │
└─────────────────────────────────────┘
```

**Step 2: Import Options**
```
┌─────────────────────────────────────┐
│ Import Options                      │
├─────────────────────────────────────┤
│ ☑ Import all projects               │
│ ☑ Import all files                  │
│ ☑ Import folder structure           │
│ ☑ Preserve formatting               │
│                                     │
│ ⚠️ This will not modify your        │
│ original Writing Shed data.         │
│                                     │
│ [Cancel]               [Import]     │
└─────────────────────────────────────┘
```

**Step 3: Progress**
```
┌─────────────────────────────────────┐
│ Importing Data...                   │
├─────────────────────────────────────┤
│ ━━━━━━━━━━━━━━━━━━━━ 65%           │
│                                     │
│ Current: Novel Project              │
│ Files imported: 82 / 127            │
│                                     │
│ Estimated time: 2 minutes           │
│                                     │
│ [Cancel Import]                     │
└─────────────────────────────────────┘
```

**Step 4: Completion**
```
┌─────────────────────────────────────┐
│ ✓ Import Complete                   │
├─────────────────────────────────────┤
│ Successfully imported:              │
│ • 5 projects                        │
│ • 23 folders                        │
│ • 127 files                         │
│                                     │
│ Your original Writing Shed data     │
│ remains unchanged.                  │
│                                     │
│ [View My Projects]                  │
└─────────────────────────────────────┘
```

### Import Steps (Technical)

1. **Detect Legacy Database**
   - Check for Core Data store file
   - Verify it's Writing Shed database
   - Check version/schema

2. **Load Legacy Data**
   - Initialize Core Data stack (read-only)
   - Fetch all objects
   - Build object graph

3. **Map to New Models**
   - Project → Project (new)
   - Folder → Folder (new)
   - File → TextFile (new)
   - Handle model differences

4. **Import Content**
   - Convert rich text content
   - Preserve formatting attributes
   - Handle images/attachments
   - Create initial versions

5. **Rebuild Relationships**
   - Link projects to folders
   - Link folders to files
   - Set parent/child relationships
   - Validate referential integrity

6. **Verify Import**
   - Check counts match
   - Verify content integrity
   - Test file opening
   - Generate import report

7. **Save to SwiftData**
   - Insert all objects
   - Save context
   - Trigger CloudKit sync

---

## Data Mapping

### Project Mapping

```swift
// Legacy Core Data
class LegacyProject: NSManagedObject {
    var id: UUID
    var name: String
    var type: String          // "poetry", "novel", etc.
    var createdDate: Date
    var folders: Set<LegacyFolder>
}

// Map to SwiftData
func mapProject(_ legacy: LegacyProject) -> Project {
    let project = Project(
        name: legacy.name,
        type: mapProjectType(legacy.type)
    )
    project.createdDate = legacy.createdDate
    // Folders mapped separately
    return project
}
```

### Folder Mapping

```swift
// Legacy
class LegacyFolder: NSManagedObject {
    var id: UUID
    var name: String
    var project: LegacyProject
    var files: Set<LegacyFile>
}

// Map to SwiftData
func mapFolder(_ legacy: LegacyFolder, project: Project) -> Folder {
    let folder = Folder(
        name: legacy.name,
        project: project
    )
    // Files mapped separately
    return folder
}
```

### File Mapping

```swift
// Legacy
class LegacyFile: NSManagedObject {
    var id: UUID
    var name: String
    var content: Data              // NSAttributedString archived
    var createdDate: Date
    var modifiedDate: Date
    var folder: LegacyFolder
}

// Map to SwiftData
func mapFile(_ legacy: LegacyFile, folder: Folder) -> TextFile {
    // Unarchive attributed string
    let attributedString = try? NSKeyedUnarchiver
        .unarchivedObject(
            ofClass: NSAttributedString.self, 
            from: legacy.content
        )
    
    let file = TextFile(
        name: legacy.name,
        initialContent: attributedString?.string ?? "",
        parentFolder: folder
    )
    file.createdDate = legacy.createdDate
    file.modifiedDate = legacy.modifiedDate
    
    // Store formatted content
    file.content = attributedString
    
    // Create initial version
    let version = Version(file: file)
    file.versions = [version]
    
    return file
}
```

---

## Error Handling

### Possible Errors

1. **Database Not Found**
   - User never had Writing Shed
   - Database deleted
   - Different device

**Handling**: Offer to skip import, start fresh

2. **Database Corrupted**
   - Core Data store damaged
   - Incomplete schema
   - Migration failure

**Handling**: Attempt partial import, report errors

3. **Incompatible Version**
   - Very old Writing Shed version
   - Unknown schema version
   - Missing required fields

**Handling**: Warn user, attempt best-effort import

4. **Insufficient Space**
   - Device storage full
   - iCloud storage full

**Handling**: Clear error message, cleanup failed import

5. **Partial Import Failure**
   - Some files fail to import
   - Relationship errors
   - Content decoding errors

**Handling**: Continue with successful items, log failures, show report

### Error UI

```
┌─────────────────────────────────────┐
│ ⚠️ Import Warning                   │
├─────────────────────────────────────┤
│ Some items could not be imported:   │
│                                     │
│ • 3 files had corrupted content     │
│ • 1 project had missing data        │
│                                     │
│ Successfully imported:              │
│ • 4 projects                        │
│ • 124 files                         │
│                                     │
│ [View Details]  [Continue]          │
└─────────────────────────────────────┘
```

---

## Import Report

### Post-Import Summary

```
Import Report
Generated: Nov 9, 2025 3:45 PM

Projects Imported: 5
Folders Imported: 23
Files Imported: 127

Errors Encountered: 4
- File "corrupted.txt" could not be decoded
- File "missing.txt" had no content
- Project "Test" had invalid type
- Folder "Unknown" had no parent project

Import Duration: 3 minutes 24 seconds
Database Size: 45.2 MB

All successfully imported data is now available
in Writing Shed Pro and will sync via CloudKit.
```

**Actions**:
- Export report as text file
- Email report to user
- Keep report in app for reference

---

## Testing Strategy

### Test Cases

1. **Empty Database** - User has no Writing Shed data
2. **Small Database** - 1 project, few files
3. **Large Database** - 10+ projects, 500+ files
4. **Complex Hierarchy** - Nested folders, relationships
5. **Rich Content** - Formatted text, images
6. **Corrupted Data** - Intentionally damaged database
7. **Old Schema** - Legacy database version

### Test Data

Create sample Writing Shed databases for testing:
- Fresh install (empty)
- Light user (1 project, 10 files)
- Medium user (5 projects, 100 files)
- Heavy user (20 projects, 1000+ files)
- Corrupted database (partial damage)

### Performance Targets

- **Small import** (< 50 files): < 30 seconds
- **Medium import** (< 200 files): < 2 minutes
- **Large import** (< 1000 files): < 10 minutes
- **Memory usage**: < 200 MB during import
- **No app crashes**: Handle errors gracefully

---

## Re-importing for Development & Testing

### Overview

In production, import runs **once per device** automatically on first launch. However, during development and testing, you may need to re-import multiple times.

### Why Re-import is Not Available to Users

1. **Import is one-time only** - Sets `hasPerformedImport` flag in UserDefaults
2. **Destructive operation** - Would delete all current projects and data
3. **CloudKit complications** - Deleted local data may re-sync from cloud
4. **No user benefit** - After initial import, CloudKit handles multi-device sync

### Methods for Development Re-import

#### Method 1a: 

Have a user variable called legacyImportAllowed initialised to true. When the app launches it checks this. If it is true then the legacy import process should run and the flag set to false on completion. If false then the app launches as normal. A debug only button should be added to the toolbar. Tapping the button should reset legacyImportAllowed to true.

Add an attribute to Project model called 'status'. This should be an enum with values:
    - legacy
    - pro
Projects added during legacy import should have status set to legacy. Projects added via the user should have it set to pro.

When legacy import runs it first fetches all projects and deletes those with status == legacy. It should save the changes before starting the import.

#### Method 1b: Delete App Completely (Recommended)

**On Mac:**
```bash
# Delete the app bundle
rm -rf /Applications/Writing\ Shed\ Pro.app

# Delete app data container
rm -rf ~/Library/Containers/com.appworks.writingshedpro

# Reinstall and run from Xcode
```

**On iOS:**
1. Long-press app icon → Delete App → Delete
2. In Settings → General → iPhone Storage → Writing Shed Pro → Delete App
3. Reinstall from Xcode

**Result**: Clean slate, import runs automatically on first launch.

#### Method 2: Delete SwiftData Store Only

**Quick reset without reinstalling:**
```bash
# Navigate to app's Application Support
cd ~/Library/Containers/com.appworks.writingshedpro/Data/Library/Application\ Support/

# Delete SwiftData store files
rm -rf default.store*
rm -rf .default.store*
rm -rf ckAssetFiles/

# Run app - import will trigger
```

**Result**: Import flag still set, but empty database triggers re-import.

#### Method 3: Reset Import Flag via Terminal

**Minimal approach - only resets the flag:**
```bash
# Clear the hasPerformedImport flag
defaults delete com.appworks.writingshedpro hasPerformedImport

# Then manually delete projects in the app UI or via Method 2
```

**Result**: Import will run on next launch if database is empty.

#### Method 4: Different Simulators/Devices

**For testing multi-device scenarios:**
- Use different iOS simulators (each has isolated data)
- Use different test devices
- Each device imports independently on first run

### Testing Import Changes

**Workflow for import code changes:**

1. Make changes to import code
2. Use Method 2 (fastest - delete store only)
3. Run app from Xcode
4. Import executes automatically
5. Verify changes worked
6. Repeat as needed

### CloudKit Sync Considerations

**After re-importing:**

- **First sync takes time** - Large datasets may take 5-10 minutes to sync
- **Don't test too quickly** - Wait for sync to complete before checking other devices
- **CloudKit quota** - Excessive re-imports during testing count toward development quota
- **Test with patience** - CloudKit sync is asynchronous, not instant

### iOS-Specific Notes

**iOS cannot auto-detect legacy database** due to app sandboxing:
- Each app runs in its own isolated container
- Cannot access other apps' Application Support directories
- **Solution**: Import on Mac, rely on CloudKit sync to iOS devices

**For iOS testing:**
1. Import on Mac first
2. Wait for CloudKit sync (5-10 minutes)
3. Launch on iOS - data syncs down automatically
4. No direct import on iOS needed

### Production Behavior

**What ships to users:**
- ✅ Automatic one-time import on Mac (first launch)
- ✅ CloudKit sync to all devices
- ✅ `hasPerformedImport` flag prevents duplicate imports
- ❌ No "re-import" button or option
- ❌ No way to trigger import again without deleting app

**User workflow:**
1. User launches Writing Shed Pro on Mac
2. Import detects legacy database → imports automatically
3. Import completes → sets flag → never runs again
4. User launches on iPhone/iPad → data syncs from CloudKit
5. Done ✅

### iOS-Only Users (Future Enhancement)

**Current Limitation**: iOS users without a Mac cannot import legacy data directly due to app sandboxing.

**Potential Solution**: The legacy Writing Shed app has a project export function that saves files to the user's Files app. A future enhancement could add:

1. **Import from Files** feature in Writing Shed Pro
2. User workflow:
   - Open legacy Writing Shed app on iOS
   - Export projects → saves to Files app
   - Open Writing Shed Pro
   - Tap "Import from Files" button
   - Select exported project files
   - Import runs from exported files instead of database

**Implementation Notes**:
- Would need to reverse-engineer export file format
- Could use UIDocumentPickerViewController for file selection
- Would be a one-time import (not automatic on launch)
- Lower priority since most users likely have a Mac or can borrow one for initial import

---

## Implementation Details

### Core Data Stack (Read-Only)

```swift
class LegacyImporter {
    private var legacyContainer: NSPersistentContainer?
    
    func loadLegacyDatabase() throws {
        // Locate legacy database
        guard let legacyURL = findLegacyDatabase() else {
            throw ImportError.databaseNotFound
        }
        
        // Load legacy Core Data model
        guard let model = loadLegacyModel() else {
            throw ImportError.incompatibleModel
        }
        
        // Create container (read-only)
        let container = NSPersistentContainer(
            name: "WritingShed",
            managedObjectModel: model
        )
        
        let description = NSPersistentStoreDescription(url: legacyURL)
        description.isReadOnly = true
        container.persistentStoreDescriptions = [description]
        
        container.loadPersistentStores { _, error in
            if let error = error {
                throw ImportError.loadFailed(error)
            }
        }
        
        self.legacyContainer = container
    }
    
    func importData(progress: @escaping (Double) -> Void) async throws {
        guard let container = legacyContainer else {
            throw ImportError.notLoaded
        }
        
        let context = container.viewContext
        
        // Fetch legacy projects
        let projectRequest: NSFetchRequest<LegacyProject> = ...
        let legacyProjects = try context.fetch(projectRequest)
        
        var completed = 0.0
        let total = Double(legacyProjects.count)
        
        for legacyProject in legacyProjects {
            // Map and import
            let project = await mapProject(legacyProject)
            
            completed += 1.0
            progress(completed / total)
        }
    }
}
```

### SwiftData Import

```swift
class SwiftDataImporter {
    let modelContext: ModelContext
    
    func importProject(_ legacy: LegacyProject) async throws -> Project {
        // Create new project
        let project = Project(
            name: legacy.name,
            type: mapProjectType(legacy.type)
        )
        project.createdDate = legacy.createdDate
        
        modelContext.insert(project)
        
        // Import folders
        for legacyFolder in legacy.folders {
            let folder = try await importFolder(legacyFolder, project: project)
            // Folders auto-link to project via relationship
        }
        
        try modelContext.save()
        return project
    }
}
```

---

## User Communication

### Pre-Import Messaging

**In App Store Description**:
"Upgrading from Writing Shed? Writing Shed Pro includes a one-click importer that brings all your projects, folders, and files into the new app."

**First Launch**:
- Detect legacy database
- Show import option prominently
- Explain what will be imported
- Emphasize data safety (original untouched)

### Post-Import Support

**Help Documentation**:
- "Importing from Writing Shed" guide
- FAQ about import process
- What to do if import fails
- How to manually migrate if needed

**Support Email Template**:
Provide import report to support for troubleshooting

---

## Data Privacy & Safety

### Safety Measures

1. **Read-Only Legacy Access** - Never modify original database
2. **Transaction Safety** - All-or-nothing import per project
3. **Rollback Support** - Can undo import if issues detected
4. **Backup Reminder** - Encourage user to backup before import
5. **Original Data Preserved** - Never delete legacy database

### Privacy

- All import happens on-device
- No data sent to servers
- User controls when/if to import
- Can delete imported data separately from original

---

## Alternative: Export/Import Flow

### If Direct Migration Too Complex

**Export from Legacy App**:
1. Add export feature to Writing Shed (if possible)
2. Export to ZIP file with JSON metadata
3. User transfers file to Writing Shed Pro
4. Import from ZIP

**Format**:
```json
{
  "version": "1.0",
  "exportDate": "2025-11-09",
  "projects": [
    {
      "id": "...",
      "name": "My Novel",
      "folders": [
        {
          "id": "...",
          "name": "Draft",
          "files": [
            {
              "id": "...",
              "name": "chapter1.txt",
              "content": "...",
              "contentType": "rtf",
              "createdDate": "..."
            }
          ]
        }
      ]
    }
  ]
}
```

**Pros**: Cleaner separation, less Core Data complexity
**Cons**: Requires update to legacy app, extra user step

---

## Open Questions

1. **Legacy app update**: Can we ship final Writing Shed update with export feature?
2. **Multiple imports**: What if user imports multiple times (different devices)?
3. **Merge vs. replace**: If user already has data in Pro, merge or replace?
4. **iCloud sync**: Should import trigger immediate CloudKit sync or wait?
5. **Version history**: Can we reconstruct version history from legacy data?
6. **Partial import**: Allow user to select specific projects to import?

---

## Success Criteria

- **Discoverability**: 95% of users with legacy data see import option
- **Success Rate**: 90%+ of imports complete successfully
- **Data Integrity**: 100% of successfully imported files are readable
- **Performance**: Large imports (1000 files) complete in < 10 minutes
- **User Satisfaction**: Post-import survey shows 90%+ satisfaction

---

## Dependencies

- Access to Writing Shed source code/database schema
- Core Data model definition
- SwiftData models finalized
- CloudKit schema stable

---

## Implementation Phases

### Phase 1: Discovery & Research
- Reverse engineer legacy database
- Document schema
- Build test databases

### Phase 2: Prototype
- Build basic importer
- Test with sample data
- Measure performance

### Phase 3: Error Handling
- Handle edge cases
- Implement retry logic
- Build error reporting

### Phase 4: UI & UX
- Import wizard
- Progress tracking
- Success/error screens

### Phase 5: Testing
- Test with real user databases
- Performance testing
- Beta testing

---

## Related Resources

- Core Data documentation
- SwiftData migration guides
- NSKeyedArchiver/Unarchiver for content
- CloudKit sync considerations

---

**Status**: 📋 Specification Draft - High Priority  
**Next Steps**: Access legacy database, reverse engineer schema, build prototype importer  
**Estimated Effort**: Large (6-8 weeks, critical path for launch)  
**Risk**: High (data migration always risky, requires careful testing)
