# Feature 009 - Entity Mapping Reference

**Date**: 12 November 2025  
**Status**: Complete mappings for all importable entities

---

## Overview

Complete mapping specifications from legacy Writing Shed (Core Data) to new Writing Shed Pro (SwiftData).

**18 Legacy Entities** → **8 New SwiftData Models** (with extended support for Scene components)

---

## Master Mapping Table

| Legacy Entity | → | New Model | Status | Priority |
|---------------|---|-----------|--------|----------|
| WS_Project_Entity | → | Project | ✅ Mapped | P0 |
| WS_Text_Entity | → | TextFile | ✅ Mapped | P0 |
| WS_Version_Entity + WS_TextString_Entity | → | Version | ✅ Mapped | P0 |
| WS_Collection_Entity | → | Submission (publication=nil) | ✅ Mapped | P0 |
| WS_CollectedVersion_Entity | → | SubmittedFile | ✅ Mapped | P0 |
| WS_CollectionSubmission_Entity | → | Submission (publication=set) | ✅ Mapped | P1 |
| WS_Scene_Entity | → | TextFile + SceneMetadata | ✅ Mapped | P2 |
| WS_Character_Entity | → | TextFile (in Characters folder) | ✅ Mapped | P2 |
| WS_Location_Entity | → | TextFile (in Locations folder) | ✅ Mapped | P2 |
| WS_Publication_Entity | → | Publication (manual creation) | ⏳ Manual | P3 |
| WS_Settings_Entity | → | UserDefaults | ❌ Skip | P4 |

---

## Priority 0: Core Import (Essential)

### 1. WS_Project_Entity → Project

**Legacy Entity**:
```xml
<entity name="WS_Project_Entity" representedClassName="WS_Project">
    <attribute name="name" type="String"/>
    <attribute name="projectType" type="String"/>  <!-- "novel", "poetry", "script", etc -->
    <attribute name="createdOn" type="Date"/>
    <attribute name="targetWordCount" type="Int32" default="0"/>
    <attribute name="top" type="Float"/>
    <attribute name="bottom" type="Float"/>
    <attribute name="left" type="Float"/>
    <attribute name="right" type="Float"/>
    <attribute name="pageHeight" type="Float"/>
    <attribute name="pageWidth" type="Float"/>
    <relationship name="texts" type="To Many" destinationEntity="WS_Text_Entity"/>
    <relationship name="collections" type="To Many" destinationEntity="WS_Collection_Entity"/>
</entity>
```

**New Model**:
```swift
@Model
final class Project {
    var id: UUID = UUID()
    var name: String?
    var typeRaw: String?
    var creationDate: Date?
    var modifiedDate: Date?
    
    @Relationship(deleteRule: .cascade, inverse: \Folder.project) 
    var folders: [Folder]?
    
    @Relationship(deleteRule: .cascade, inverse: \Publication.project) 
    var publications: [Publication]? = []
    
    @Relationship(deleteRule: .cascade, inverse: \Submission.project) 
    var submissions: [Submission]? = []
}
```

**Mapping Function**:
```swift
func mapProject(_ legacy: NSManagedObject) throws -> Project {
    let project = Project()
    project.name = legacy.value(forKey: "name") as? String
    project.creationDate = legacy.value(forKey: "createdOn") as? Date
    project.modifiedDate = project.creationDate
    
    // Map project type
    if let typeString = legacy.value(forKey: "projectType") as? String {
        project.typeRaw = mapProjectType(typeString).rawValue
    }
    
    return project
}

func mapProjectType(_ legacyType: String) -> ProjectType {
    let typeMapping: [String: ProjectType] = [
        "novel": .novel,
        "poetry": .poetry,
        "script": .script,
        "shortStory": .shortStory,
        "blank": .blank
    ]
    return typeMapping[legacyType] ?? .blank
}
```

**Notes**:
- Page setup (top, bottom, left, right, pageHeight, pageWidth) not imported (future feature)
- Word count target not currently used in new model
- Settings stored separately in UserDefaults (skip for now)

**Test Data Sample**:
```
Legacy: WS_Project_Entity {
    name: "My Novel"
    projectType: "novel"
    createdOn: 2024-01-15 10:30:00
    targetWordCount: 80000
}

→ New Project {
    id: UUID()
    name: "My Novel"
    typeRaw: "novel"
    creationDate: 2024-01-15 10:30:00
    modifiedDate: 2024-01-15 10:30:00
    folders: [] (will be populated by folder mapping)
}
```

---

### 2. WS_Text_Entity → TextFile

**Legacy Entity**:
```xml
<entity name="WS_Text_Entity" representedClassName="WS_Text">
    <attribute name="name" type="String"/>
    <attribute name="groupName" type="String"/>  <!-- Folder organization -->
    <attribute name="dateCreated" type="Date"/>
    <attribute name="dateLastUpdated" type="Date"/>
    <attribute name="uniqueIdentifier" type="String"/>
    <relationship name="project" type="To One" destinationEntity="WS_Project_Entity"/>
    <relationship name="versions" type="To Many" destinationEntity="WS_Version_Entity"/>
</entity>
```

**New Model**:
```swift
@Model
final class TextFile {
    var id: UUID = UUID()
    var name: String = ""
    var createdDate: Date = Date()
    var modifiedDate: Date = Date()
    var currentVersionIndex: Int = 0
    
    @Relationship(deleteRule: .nullify, inverse: \Folder.textFiles) 
    var parentFolder: Folder?
    
    @Relationship(deleteRule: .cascade, inverse: \Version.textFile) 
    var versions: [Version]? = nil
}
```

**Mapping Function**:
```swift
func mapTextFile(
    _ legacy: NSManagedObject,
    folder: Folder
) throws -> TextFile {
    let file = TextFile()
    file.name = (legacy.value(forKey: "name") as? String) ?? "Untitled"
    file.createdDate = (legacy.value(forKey: "dateCreated") as? Date) ?? Date()
    file.modifiedDate = (legacy.value(forKey: "dateLastUpdated") as? Date) ?? Date()
    file.parentFolder = folder
    
    // UUID mapping
    if let uniqueId = legacy.value(forKey: "uniqueIdentifier") as? String,
       let uuid = UUID(uuidString: uniqueId) {
        file.id = uuid
    }
    
    return file
}
```

**Special Handling: groupName → Folder Mapping**
```swift
func mapGroupNameToFolder(
    groupName: String,
    project: Project,
    modelContext: ModelContext
) -> Folder {
    // Check if folder exists
    if let existingFolder = project.folders?.first(where: { $0.name == groupName }) {
        return existingFolder
    }
    
    // Create new folder
    let folder = Folder(name: groupName, project: project)
    modelContext.insert(folder)
    return folder
}
```

**Notes**:
- `groupName` doesn't appear in new TextFile (stored in parent Folder)
- `uniqueIdentifier` must be valid UUID string, else generate new one
- Create folder structure from unique groupName values

**Test Data Sample**:
```
Legacy: WS_Text_Entity {
    name: "Chapter 1"
    groupName: "Part 1"
    dateCreated: 2024-01-20 09:00:00
    dateLastUpdated: 2024-01-22 14:30:00
    uniqueIdentifier: "550E8400-E29B-41D4-A716-446655440000"
}

→ New TextFile {
    id: 550E8400-E29B-41D4-A716-446655440000
    name: "Chapter 1"
    createdDate: 2024-01-20 09:00:00
    modifiedDate: 2024-01-22 14:30:00
    parentFolder: (Folder named "Part 1")
}
```

---

### 3. WS_Version_Entity + WS_TextString_Entity → Version

**Legacy Entities**:
```xml
<entity name="WS_Version_Entity" representedClassName="WS_Version">
    <attribute name="date" type="Date"/>
    <attribute name="locked" type="Boolean"/>
    <attribute name="notes" type="String"/>
    <attribute name="uniqueIdentifier" type="String"/>
    <relationship name="text" type="To One" destinationEntity="WS_Text_Entity"/>
    <relationship name="textString" type="To One" destinationEntity="WS_TextString_Entity"/>
</entity>

<entity name="WS_TextString_Entity" representedClassName="WS_TextString">
    <attribute name="textFile" type="Transformable" valueTransformerName="AttributedStringTransformer"/>
    <attribute name="uniqueIdentifier" type="String"/>
    <relationship name="version" type="To One" destinationEntity="WS_Version_Entity"/>
</entity>
```

**New Model**:
```swift
@Model
final class Version {
    var id: UUID = UUID()
    var content: String = ""
    var createdDate: Date = Date()
    var versionNumber: Int = 1
    var comment: String?
    
    // NEW: Formatted content storage
    var formattedContent: Data?  // RTF data from NSAttributedString
    
    var textFile: TextFile?
    @Relationship(deleteRule: .nullify, inverse: \SubmittedFile.version) 
    var submittedFiles: [SubmittedFile]? = []
}
```

**Mapping Function**:
```swift
func mapVersion(
    _ legacyVersion: NSManagedObject,
    file: TextFile,
    versionNumber: Int
) throws -> Version {
    let version = Version()
    version.createdDate = (legacyVersion.value(forKey: "date") as? Date) ?? Date()
    version.versionNumber = versionNumber
    version.comment = legacyVersion.value(forKey: "notes") as? String
    version.textFile = file
    
    // Map UUID
    if let uniqueId = legacyVersion.value(forKey: "uniqueIdentifier") as? String,
       let uuid = UUID(uuidString: uniqueId) {
        version.id = uuid
    }
    
    // Get TextString (content)
    if let textStringEntity = legacyVersion.value(forKey: "textString") as? NSManagedObject {
        let (plainText, rtfData) = try mapTextStringToContent(textStringEntity)
        version.content = plainText
        version.formattedContent = rtfData
    }
    
    return version
}

func mapTextStringToContent(_ legacyTextString: NSManagedObject) throws -> (String, Data?) {
    // Get NSAttributedString from transformable attribute
    guard let nsAttributedString = legacyTextString.value(forKey: "textFile") as? NSAttributedString else {
        throw ImportError.missingContent
    }
    
    let plainText = nsAttributedString.string
    
    // Try to convert to RTF
    let rtfData: Data?
    do {
        let range = NSRange(location: 0, length: nsAttributedString.length)
        rtfData = try nsAttributedString.data(
            from: range,
            documentType: .rtf
        )
    } catch {
        // If RTF conversion fails, just use plain text
        rtfData = nil
    }
    
    return (plainText, rtfData)
}
```

**Critical Notes**:
- **NSAttributedString Handling**: Core Data stores it as transformable, access directly
- **RTF Conversion**: Best-effort to preserve formatting; fallback to plain text
- **Version Numbering**: Assign sequential version numbers based on date ordering
- **Locked Status**: Legacy has `locked` boolean; new model has no direct equivalent (store in notes?)

**Test Data Sample**:
```
Legacy: WS_Version_Entity {
    date: 2024-01-20 09:00:00
    locked: false
    notes: "First draft"
    uniqueIdentifier: "550E8400-E29B-41D4-A716-446655440001"
}
+ WS_TextString_Entity {
    textFile: NSAttributedString("Chapter 1 content with bold formatting")
    uniqueIdentifier: "550E8400-E29B-41D4-A716-446655440002"
}

→ New Version {
    id: 550E8400-E29B-41D4-A716-446655440001
    content: "Chapter 1 content with bold formatting"
    formattedContent: [RTF data preserving bold]
    createdDate: 2024-01-20 09:00:00
    versionNumber: 1
    comment: "First draft"
}
```

---

### 4. WS_Collection_Entity → Submission (publication=nil)

**Legacy Entity**:
```xml
<entity name="WS_Collection_Entity" representedClassName="WS_Collection">
    <relationship name="components" type="To Many" destinationEntity="WS_CollectionComponent_Entity"/>
    <relationship name="project" type="To One" destinationEntity="WS_Project_Entity"/>
    <relationship name="collectionSubmissions" type="To Many" destinationEntity="WS_CollectionSubmission_Entity"/>
</entity>

<entity name="WS_CollectionComponent_Entity">
    <attribute name="name" type="String"/>  <!-- Collection name -->
    <attribute name="created" type="Date"/>
    <relationship name="collection" type="To One" destinationEntity="WS_Collection_Entity"/>
</entity>
```

**New Model**:
```swift
@Model
class Submission {
    var id: UUID = UUID()
    var name: String = ""
    var submittedDate: Date = Date()
    
    var publication: Publication?  // nil means this is a collection
    var project: Project?
    
    @Relationship(deleteRule: .cascade, inverse: \SubmittedFile.submission) 
    var submittedFiles: [SubmittedFile]? = []
}
```

**Mapping Function**:
```swift
func mapCollection(
    _ legacyCollection: NSManagedObject,
    project: Project
) throws -> Submission {
    let submission = Submission()
    submission.project = project
    submission.publication = nil  // Mark as collection
    
    // Get collection name from component
    if let components = legacyCollection.value(forKey: "components") as? NSSet,
       let firstComponent = components.anyObject() as? NSManagedObject,
       let name = firstComponent.value(forKey: "name") as? String {
        submission.name = name
    }
    
    // Get creation date
    if let components = legacyCollection.value(forKey: "components") as? NSSet,
       let firstComponent = components.anyObject() as? NSManagedObject,
       let created = firstComponent.value(forKey: "created") as? Date {
        submission.submittedDate = created
    }
    
    return submission
}
```

**Notes**:
- Collections become Submission objects with `publication = nil`
- Collection name comes from WS_CollectionComponent_Entity
- Create date comes from WS_CollectionComponent_Entity

**Test Data Sample**:
```
Legacy: WS_Collection_Entity {
    components: [
        WS_CollectionComponent_Entity {
            name: "Spring Poetry Collection"
            created: 2024-02-01 11:00:00
        }
    ]
    project: (reference to My Poetry project)
}

→ New Submission {
    id: UUID()
    name: "Spring Poetry Collection"
    submittedDate: 2024-02-01 11:00:00
    publication: nil  // Marks this as collection
    project: (My Poetry project)
}
```

---

### 5. WS_CollectedVersion_Entity → SubmittedFile

**Legacy Entity**:
```xml
<entity name="WS_CollectedVersion_Entity" representedClassName="WS_CollectedVersion">
    <attribute name="positionInCollection" type="Int16"/>
    <attribute name="status" type="Int16"/>  <!-- 0=pending, 1=accepted, 2=rejected -->
    <relationship name="version" type="To One" destinationEntity="WS_Version_Entity"/>
    <relationship name="collection" type="To One" destinationEntity="WS_Collection_Entity"/>
</entity>
```

**New Model**:
```swift
@Model
class SubmittedFile {
    var id: UUID = UUID()
    var submission: Submission?
    var textFile: TextFile?
    var version: Version?
    
    var status: SubmissionStatus = .pending
    var statusDate: Date?
    var statusNotes: String?
    
    var project: Project?
    var createdDate: Date = Date()
    var modifiedDate: Date = Date()
}

enum SubmissionStatus: String, Codable {
    case pending
    case accepted
    case rejected
    case withdrawn
}
```

**Mapping Function**:
```swift
func mapCollectedVersion(
    _ legacyCollectedVersion: NSManagedObject,
    collection: Submission,
    modelContext: ModelContext
) throws -> SubmittedFile {
    let submittedFile = SubmittedFile()
    submittedFile.submission = collection
    
    // Get version and text file
    if let version = legacyCollectedVersion.value(forKey: "version") as? NSManagedObject {
        // submittedFile.version will be set after version mapping
        
        // Get the associated text file from version
        if let textEntity = version.value(forKey: "text") as? NSManagedObject {
            // submittedFile.textFile will be set after text mapping
        }
    }
    
    // Map status
    if let statusInt = legacyCollectedVersion.value(forKey: "status") as? Int16 {
        submittedFile.status = mapSubmissionStatus(statusInt)
    }
    
    submittedFile.project = collection.project
    submittedFile.createdDate = Date()
    
    return submittedFile
}

func mapSubmissionStatus(_ legacyStatus: Int16) -> SubmissionStatus {
    switch legacyStatus {
    case 0: return .pending
    case 1: return .accepted
    case 2: return .rejected
    default: return .pending
    }
}
```

**Notes**:
- Position in collection not stored in new model (maintained by array order)
- Status mapping: 0→pending, 1→accepted, 2→rejected

---

## Priority 1: Publication Submissions

### 6. WS_CollectionSubmission_Entity → Submission (publication=set)

**Legacy Entity**:
```xml
<entity name="WS_CollectionSubmission_Entity">
    <attribute name="submittedDate" type="Date"/>
    <attribute name="responseDate" type="Date"/>
    <attribute name="status" type="Int16"/>
    <relationship name="collection" type="To One" destinationEntity="WS_Collection_Entity"/>
    <relationship name="publication" type="To One" destinationEntity="WS_Publication_Entity"/>
</entity>
```

**Mapping Logic**:
```swift
func mapCollectionSubmission(
    _ legacySubmission: NSManagedObject,
    collectionSubmission: Submission,
    modelContext: ModelContext
) throws -> Submission {
    // Create new Submission for publication
    let pubSubmission = Submission()
    pubSubmission.project = collectionSubmission.project
    
    // Get publication (must already exist or be mapped)
    if let pubEntity = legacySubmission.value(forKey: "publication") as? NSManagedObject {
        let publication = try mapOrFetchPublication(pubEntity, modelContext: modelContext)
        pubSubmission.publication = publication
    }
    
    // Copy dates and status
    pubSubmission.submittedDate = (legacySubmission.value(forKey: "submittedDate") as? Date) ?? Date()
    
    // Copy all submitted files from collection to publication submission
    if let collectionFiles = collectionSubmission.submittedFiles {
        for file in collectionFiles {
            let newFile = SubmittedFile()
            newFile.submission = pubSubmission
            newFile.textFile = file.textFile
            newFile.version = file.version
            newFile.status = .pending
            newFile.project = pubSubmission.project
            pubSubmission.submittedFiles?.append(newFile)
        }
    }
    
    return pubSubmission
}
```

**Result**: Creates duplicate submissions (collection + publication), as specified by user

---

## Priority 2: Scene Components (Extended Scope)

### 7. WS_Scene_Entity → TextFile + SceneMetadata

**New Model Extension**:
```swift
@Model
final class SceneMetadata {
    var id: UUID = UUID()
    var sceneType: String  // "Scene", "Character", "Location"
    var characters: [String] = []
    var locations: [String] = []
    var relatedScenes: [String] = []
}

// Extend TextFile
@Model
final class TextFile {
    // ... existing properties ...
    var sceneMetadata: SceneMetadata?
}
```

**Mapping Function**:
```swift
func mapScene(
    _ legacyScene: NSManagedObject,
    folder: Folder,
    modelContext: ModelContext
) throws -> TextFile {
    let file = try mapTextFile(legacyScene, folder: folder)
    
    // Add scene metadata
    let metadata = SceneMetadata()
    metadata.sceneType = "Scene"
    
    // Map character references
    if let characters = legacyScene.value(forKey: "characters") as? NSSet {
        metadata.characters = characters.compactMap { 
            ($0 as? NSManagedObject)?.value(forKey: "name") as? String 
        }
    }
    
    // Map location references
    if let locations = legacyScene.value(forKey: "locations") as? NSSet {
        metadata.locations = locations.compactMap { 
            ($0 as? NSManagedObject)?.value(forKey: "name") as? String 
        }
    }
    
    file.sceneMetadata = metadata
    return file
}
```

### 8. WS_Character_Entity → TextFile (Characters folder)

**Mapping Function**:
```swift
func mapCharacter(
    _ legacyCharacter: NSManagedObject,
    project: Project,
    modelContext: ModelContext
) throws -> TextFile {
    // Create Characters folder if needed
    let charactersFolder = getOrCreateAutoFolder(
        named: "\(project.name ?? "Project")/Characters",
        in: project,
        modelContext: modelContext
    )
    
    // Map as regular text file
    let file = TextFile()
    file.name = (legacyCharacter.value(forKey: "name") as? String) ?? "Character"
    file.parentFolder = charactersFolder
    
    // Add character metadata
    let metadata = SceneMetadata()
    metadata.sceneType = "Character"
    file.sceneMetadata = metadata
    
    // Import character description as first version
    if let description = legacyCharacter.value(forKey: "description") as? NSAttributedString {
        let version = Version()
        version.content = description.string
        version.versionNumber = 1
        file.versions = [version]
    }
    
    return file
}
```

### 9. WS_Location_Entity → TextFile (Locations folder)

**Mapping Function**:
```swift
func mapLocation(
    _ legacyLocation: NSManagedObject,
    project: Project,
    modelContext: ModelContext
) throws -> TextFile {
    // Create Locations folder if needed
    let locationsFolder = getOrCreateAutoFolder(
        named: "\(project.name ?? "Project")/Locations",
        in: project,
        modelContext: modelContext
    )
    
    // Map as regular text file
    let file = TextFile()
    file.name = (legacyLocation.value(forKey: "name") as? String) ?? "Location"
    file.parentFolder = locationsFolder
    
    // Add location metadata
    let metadata = SceneMetadata()
    metadata.sceneType = "Location"
    file.sceneMetadata = metadata
    
    // Import location description as first version
    if let description = legacyLocation.value(forKey: "description") as? NSAttributedString {
        let version = Version()
        version.content = description.string
        version.versionNumber = 1
        file.versions = [version]
    }
    
    return file
}
```

---

## Priority 3: Publications (Manual)

### 10. WS_Publication_Entity → Publication

**Note**: Publications don't have direct mapping because they're part of a different workflow in legacy system. For now, users must:
1. Import all data first
2. Manually create Publication objects in the new app
3. Then create Submissions linked to them

This can be automated in Phase 2 if detailed publication mapping is needed.

---

## Helper Functions

### Folder Structure Creation

```swift
func createFolderStructure(
    project: Project,
    legacyFolderNames: [String],
    modelContext: ModelContext
) -> [String: Folder] {
    var folders: [String: Folder] = [:]
    
    for groupName in legacyFolderNames {
        if let existing = project.folders?.first(where: { $0.name == groupName }) {
            folders[groupName] = existing
        } else {
            let folder = Folder(name: groupName, project: project)
            project.folders?.append(folder)
            folders[groupName] = folder
            modelContext.insert(folder)
        }
    }
    
    return folders
}

func getOrCreateAutoFolder(
    named: String,
    in project: Project,
    modelContext: ModelContext
) -> Folder {
    if let existing = project.folders?.first(where: { $0.name == named }) {
        return existing
    }
    
    let folder = Folder(name: named, project: project)
    project.folders?.append(folder)
    modelContext.insert(folder)
    return folder
}
```

### Error Handling

```swift
enum ImportError: Error {
    case missingContent
    case invalidUUID
    case corruptedData
    case invalidProjectType
}
```

---

## Mapping Checklist

### Phase 1 (Essential)
- [ ] WS_Project_Entity → Project
- [ ] WS_Text_Entity → TextFile
- [ ] WS_Version_Entity + WS_TextString_Entity → Version
- [ ] WS_Collection_Entity → Submission (publication=nil)
- [ ] WS_CollectedVersion_Entity → SubmittedFile
- [ ] Folder structure from groupName

### Phase 2 (Extended)
- [ ] WS_Scene_Entity → TextFile + SceneMetadata
- [ ] WS_Character_Entity → TextFile
- [ ] WS_Location_Entity → TextFile
- [ ] Scene relationship mapping

### Phase 3 (Publication)
- [ ] WS_CollectionSubmission_Entity → Submission (publication=set)
- [ ] Publication entity mapping (manual for now)

---

## Summary

✅ **All entity mappings specified**  
✅ **Mapping functions documented with code**  
✅ **Test data samples provided**  
✅ **Helper functions for folder creation**  
✅ **Priority levels defined**  
✅ **Error handling strategy included**  

**Status**: Ready for Phase 1 implementation of DataMapper and LegacyDatabaseService
