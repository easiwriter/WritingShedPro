# Writing Shed Database Import - Legacy Model Analysis

**Date**: 12 November 2025  
**Analysis of**: Writing_Shed.xcdatamodeld (Version 35)  
**Purpose**: Map legacy Core Data model to new SwiftData model

---

## Executive Summary

The original Writing Shed app uses a complex Core Data hierarchy with:
- **18 entities** organized in inheritance hierarchies
- **Rich text attributes** stored as transformables
- **Version tracking** with file content as `AttributedString`
- **Collections** that group versioned texts
- **Submissions** for tracking collection submissions to publications
- **Scene components** (Characters, Locations) for novel/script projects

The new Writing Shed Pro has a simplified, flatter structure more suited to poetry/short story focus.

---

## Legacy Entity Hierarchy

### Base Entities

#### 1. **WS_Project_Entity** (Root)
**Purpose**: Container for all project data

**Attributes**:
- `name`: String
- `projectType`: String (e.g., "poetry", "novel", "script", "blank")
- `createdOn`: Date
- `updatedOn`: Date
- `uniqueIdentifier`: String (UUID)
- `targetWordCount`: Int32
- Page setup attributes: `top`, `bottom`, `left`, `right`, headers, footers, spacing

**Relationships**:
- `texts` (many): WS_Text_Entity
- `collectionComponents` (many): WS_CollectionComponent_Entity
- `sceneComponents` (many): WS_SceneComponent_Entity
- `settings` (one): WS_Settings_Entity

#### 2. **WS_Settings_Entity**
**Purpose**: Global app settings

**Attributes**:
- `author`: String
- `address`: String
- `email`: String
- `currentProject`: String
- Font, units, alert flags
- App store and trial info

#### 3. **WS_Text_Entity** (File equivalent)
**Purpose**: Represents a text file/document

**Attributes**:
- `name`: String
- `groupName`: String (folder/organization)
- `dateCreated`: Date
- `dateLastUpdated`: Date
- `uniqueIdentifier`: String (UUID)
- `sectionIdentifier`: String
- `quicklook`: Boolean
- `searchResult`: String

**Relationships**:
- `project` (one): WS_Project_Entity
- `versions` (many): WS_Version_Entity
- `collections` (many): WS_Collection_Entity (for collections this text is in)

#### 4. **WS_Version_Entity** (Version information)
**Purpose**: Specific version of a text

**Attributes**:
- `date`: Date (creation/modification date)
- `dateLastUpdated`: Date
- `locked`: Boolean (version locking)
- `notes`: NSAttributedString (version notes/comments)
- `uniqueIdentifier`: String (UUID)

**Relationships**:
- `text` (one): WS_Text_Entity
- `textString` (one): WS_TextString_Entity (the actual content)
- `collectedVersions` (many): WS_CollectedVersion_Entity

#### 5. **WS_TextString_Entity** (Content storage)
**Purpose**: Stores actual rich text content

**Attributes**:
- `textFile`: NSAttributedString (the actual content!)
- `fileType`: String
- `uniqueIdentifier`: String (UUID)

**Relationships**:
- `version` (one): WS_Version_Entity

### Collection Management Entities

#### 6. **WS_Collection_Entity** (Groups of texts)
**Purpose**: A named collection of versioned texts

**Attributes**:
- `groupName`: String
- `dateCreated`: Date
- `position`: Int16 (ordering)
- (Inherits from WS_CollectionComponent_Entity)

**Relationships**:
- `texts` (many): WS_Text_Entity (which texts are in this collection)
- `textCollection` (one): WS_TextCollection_Entity
- `collectionSubmissions` (many): WS_CollectionSubmission_Entity

#### 7. **WS_CollectionComponent_Entity** (Base for collections)
**Purpose**: Base class for collection and submission entities

**Attributes**:
- `name`: String
- `createdOn`: Date
- `notes`: NSAttributedString (optional)
- `sectionIdentifier`: String
- `uniqueIdentifier`: String (UUID)

**Relationships**:
- `project` (one): WS_Project_Entity

#### 8. **WS_TextCollection_Entity** (Collection metadata)
**Purpose**: Extended collection data

**Attributes**: (inherits from WS_Text_Entity)

**Relationships**:
- `collection` (one): WS_Collection_Entity
- `collectedVersions` (many): WS_CollectedVersion_Entity

#### 9. **WS_CollectedVersion_Entity** (Version in collection)
**Purpose**: Links a specific version to a collection

**Attributes**:
- `positionInCollection`: Int16
- `status`: Int16 (submission status?)
- `uniqueIdentifier`: String (UUID)

**Relationships**:
- `version` (one): WS_Version_Entity
- `textCollection` (one): WS_TextCollection_Entity

### Submission Entities

#### 10. **WS_Submission_Entity** (Publication submission)
**Purpose**: Track submission of collections to publications

**Attributes**:
- `groupName`: String
- (Inherits from WS_CollectionComponent_Entity)

**Relationships**:
- `collectionSubmissions` (many): WS_CollectionSubmission_Entity

#### 11. **WS_CollectionSubmission_Entity** (Submission record)
**Purpose**: Tracks a collection's submission to a publication

**Attributes**:
- `submittedOn`: Date
- `accepted`: Int16 (boolean)
- `returnExpectedBy`: Date
- `returnedOn`: String (date as string)
- `notes`: String (feedback)
- `uniqueIdentifier`: String (UUID)

**Relationships**:
- `collection` (one): WS_Collection_Entity
- `submission` (one): WS_Submission_Entity

### Novel/Script Scene Components

#### 12. **WS_SceneComponent_Entity** (Base for scene elements)
**Purpose**: Base for character, location components

**Attributes**:
- `name`: String
- `groupName`: String
- `role`: String
- `sectionIdentifier`: String
- `uniqueIdentifier`: String (UUID)

**Relationships**:
- `project` (one): WS_Project_Entity
- `scenes` (many): WS_Scene_Entity

#### 13. **WS_Scene_Entity** (Scene content)
**Purpose**: Represents a scene in novel/script projects

**Attributes**:
- `action`: String
- `notes`: String
- `role`: String
- `position`: Int16
- (Inherits from WS_Text_Entity)

**Relationships**:
- `sceneComponents` (many): WS_SceneComponent_Entity

#### 14. **WS_Character_Entity** (Scene component subtype)
**Purpose**: Character information for scenes

**Attributes**:
- `traits`: String
- `looks`: String
- `history`: String
- `work`: String

#### 15. **WS_Location_Entity** (Scene component subtype)
**Purpose**: Location/setting information

**Attributes**:
- `detail`: String
- `sights`: String
- `sounds`: String
- `smells`: String

#### 16. **WS_Act_Entity** (Collection subtype)
**Purpose**: Specialized collection for acts/chapters

#### 17. **WS_Chapter_Entity** (Collection subtype)
**Purpose**: Specialized collection for chapters

#### 18. **WS_Story_Entity** (Scene subtype)
**Purpose**: Specialized scene type for stories

---

## Key Data Flow

### Text Content Storage
```
WS_Text_Entity (name, metadata)
  └─ WS_Version_Entity (locked, notes, date)
       └─ WS_TextString_Entity (textFile: NSAttributedString)
```

### Collection Workflow
```
WS_Collection_Entity (named group)
  ├─ WS_CollectedVersion_Entity[] (version references)
  │   └─ WS_Version_Entity (which version to use)
  │
  └─ WS_CollectionSubmission_Entity (submission tracking)
      └─ WS_Submission_Entity (publication being submitted to)
```

### Project Structure
```
WS_Project_Entity
  ├─ WS_Text_Entity[] (individual texts/files)
  │
  ├─ WS_Collection_Entity[] (collections of texts)
  │
  ├─ WS_SceneComponent_Entity[] (characters, locations)
  │
  └─ WS_Settings_Entity (project preferences)
```

---

## Mapping to New SwiftData Model

### Project → Project
```swift
// Legacy
WS_Project_Entity {
    name: String
    projectType: String
    createdOn: Date
    targetWordCount: Int32
    top, bottom, left, right: Float
    ...pageSetup
}

// New
Project {
    name: String
    type: ProjectType
    createdDate: Date
    wordTarget: Int (stored as Int)
    // Page setup not yet implemented
}
```

**Notes**:
- `projectType` string needs parsing to enum
- Page setup attributes not in new model (future feature)
- No direct mapping for settings data yet

### WS_Text_Entity → TextFile
```swift
// Legacy
WS_Text_Entity {
    name: String
    groupName: String (organization)
    dateCreated: Date
    dateLastUpdated: Date
    uniqueIdentifier: String
}

// New
TextFile {
    name: String
    // groupName not used (folder hierarchy different)
    createdDate: Date
    modifiedDate: Date
    id: UUID (from uniqueIdentifier)
}
```

**Notes**:
- Legacy groups files by `groupName` string
- New model uses folder hierarchy instead
- Need to map groupName to folder structure

### WS_Version_Entity & WS_TextString_Entity → Version
```swift
// Legacy
WS_Version_Entity {
    date: Date
    locked: Boolean
    notes: NSAttributedString
}
+ WS_TextString_Entity {
    textFile: NSAttributedString (content)
}

// New
Version {
    date: Date
    versionLocked: Boolean
    content: NSAttributedString
    notes: String (currently String, not AttributedString)
}
```

**Notes**:
- Content stored across two entities in legacy, combined in new
- NSAttributedString should transfer directly
- Version notes as String in new model (may lose formatting)

### WS_Collection_Entity → Submission (where publication=nil)
```swift
// Legacy
WS_Collection_Entity {
    name: String (from WS_CollectionComponent_Entity)
    dateCreated: Date
    collectedVersions: [WS_CollectedVersion_Entity]
}

// New
Submission {
    publication: nil  // Marks as collection
    name: String
    createdDate: Date
    submittedFiles: [SubmittedFile]
}
```

**Notes**:
- Collections are Submission objects with publication=nil
- CollectedVersions map to SubmittedFiles

### WS_CollectedVersion_Entity → SubmittedFile
```swift
// Legacy
WS_CollectedVersion_Entity {
    version: WS_Version_Entity
    textCollection: WS_TextCollection_Entity
    status: Int16
    positionInCollection: Int16
}

// New
SubmittedFile {
    submission: Submission
    textFile: TextFile
    version: Version
    status: SubmissionStatus
    statusDate: Date
}
```

### WS_CollectionSubmission_Entity → (Not directly used)
```swift
// Legacy
WS_CollectionSubmission_Entity {
    collection: WS_Collection_Entity
    submission: WS_Submission_Entity
    submittedOn: Date
    accepted: Boolean
    returnExpectedBy: Date
}

// New - Creates Publication Submission
Submission {
    publication: Publication
    project: Project
    submittedDate: Date
}
```

**Notes**:
- In legacy, tracks submission of collection to publication
- In new, publication submission is separate Submission object
- Return dates and acceptance not yet tracked in new model

---

## Import Challenges & Solutions

### Challenge 1: Model Simplification
**Legacy**: 18 entities with complex hierarchies  
**New**: Simplified, flatter structure

**Solution**: Map only relevant entities, skip scene components for now
- Import WS_Text_Entity → TextFile
- Import WS_Version_Entity → Version
- Import WS_Collection_Entity → Submission (publication=nil)
- Skip WS_Character_Entity, WS_Location_Entity (not in scope for Phase 1)

### Challenge 2: AttributedString Storage
**Legacy**: NSAttributedString stored as transformable in Core Data  
**New**: NSAttributedString also used in SwiftData

**Solution**: Direct conversion possible but need to verify format compatibility
- AttributedString should serialize/deserialize correctly
- Test with actual old app data to ensure compatibility
- Handle corrupted or invalid attributed strings

### Challenge 3: Folder Organization
**Legacy**: Uses `groupName` string for organization  
**New**: Uses folder hierarchy

**Solution**: Create folders from groupName values
- Group texts by groupName
- Create/map to corresponding Folder entities
- Assign texts to correct folder in hierarchy

### Challenge 4: UUID Mapping
**Legacy**: Uses String uniqueIdentifier  
**New**: Uses UUID

**Solution**: Convert string UUIDs to UUID type
- Parse `uniqueIdentifier` as UUID
- Use as primary identifier for new objects
- Handle invalid UUIDs gracefully

### Challenge 5: Scene Components
**Legacy**: Separate Character and Location entities  
**New**: No equivalent (Poetry/Short Story focus)

**Solution**: Skip scene components in initial import
- These are mainly for novels/scripts
- Can be added in later phases if needed
- User won't lose data (just not imported)

### Challenge 6: Project Type Mapping
**Legacy**: String projectType values  
**New**: ProjectType enum

**Solution**: Create mapping function
```swift
let typeMapping: [String: ProjectType] = [
    "poetry": .poetry,
    "novel": .novel,
    "script": .script,
    "blank": .blank,
    "shortStory": .shortStory
]
```

---

## Import Order & Dependencies

**Phase 1 - Core Import Order**:
1. ✅ Discover and open legacy Core Data database
2. ✅ Fetch all WS_Project_Entity objects
3. ✅ For each project:
   - ✅ Map to new Project
   - ✅ Fetch all WS_Text_Entity for project
   - ✅ For each text:
     - ✅ Create TextFile
     - ✅ Fetch versions
     - ✅ For each version:
       - ✅ Fetch WS_TextString_Entity content
       - ✅ Create Version with content
     - ✅ Fetch collections containing this text
     - ✅ For each collection:
       - ✅ Create/link Submission (publication=nil)
4. ✅ Save all to SwiftData

**Phase 2 - (Future)**:
- Import page setup attributes (not in new model yet)
- Import scene components if needed
- Import user settings/preferences

---

## Data Validation Checklist

Before finalizing import:
- [ ] Count: Projects match
- [ ] Count: Texts match
- [ ] Count: Versions match  
- [ ] Count: Collections match
- [ ] Content: Open random imported file, verify content correct
- [ ] Content: Open file with multiple versions, verify all versions present
- [ ] Structure: Collections contain correct texts
- [ ] Structure: Project hierarchy preserved
- [ ] Dates: Creation dates preserved
- [ ] Formatting: Bold/italic/underline preserved in content
- [ ] Locking: Locked versions correctly marked

---

## Recommendations

1. **Start with Core Data read layer**: Create service to safely read legacy database
2. **Implement incremental import**: Not all-or-nothing, handle partial success
3. **Create import report**: Show user what was/wasn't imported
4. **Backup original**: Keep legacy database untouched
5. **Test with real data**: Use actual user's Writing Shed database to test
6. **Handle edge cases**: Corrupted data, missing relations, invalid UUIDs

---

## Next Steps

1. Implement `LegacyDatabaseService` to read Core Data store
2. Create mapping functions for each entity type
3. Build import workflow UI with progress tracking
4. Implement error handling and recovery
5. Create comprehensive import tests
6. Document any data loss or transformation
