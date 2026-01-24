# Feature 030: WS Novel Import Enhancement

**Status:** Not Started  
**Priority:** High  
**Estimated Effort:** TBD  
**Dependencies:** 009-database-import, 022-smart-fiction-creation  
**Created:** 2026-01-24  
**Last Updated:** 2026-01-24

## Implementation Status

### Completed
- *(None yet)*

### In Progress / Not Started
- ⏳ Detect and map WS Novel project type during import
- ⏳ Import WS Novel chapters as Fiction chapters
- ⏳ Import WS Novel scenes as Fiction scenes
- ⏳ Map WS Novel folder structure to Fiction structure
- ⏳ Handle WS Novel-specific metadata
- ⏳ Preserve scene-chapter relationships

## Overview

This specification enhances the JSON import service to properly handle Novel projects exported from the legacy Writing Shed app. The legacy app has a Novel project type with its own folder structure and data model that needs to be mapped to Writing Shed Pro's Fiction project structure.

There are a few changes needed to the models. (The legacy model DB spec is somewhere in this project)

First the WS_Character_Entity contains attributes for role, history, looks, traits and work. These are all Strings. The WSP Character class contains a field for the role, but not the others. We need to replace the biography field of the Character class with string fields for history, looks, traits and work.

Next the WS_Location_Entity contains attributes for detail, sights, sounds and smells. These are all strings. The WSP Location class contains a locationDescription. We need to replace this with fields for detail, sights, sounds and smells.

Next the WS_Scene_Entity contains attributes for role, action and notes. These are all strings. The WSP StoryScene Model contains a synopsis field. I think we should simply copy the action and notes into this field.

## Background

### Legacy Writing Shed Novel Structure

The original Writing Shed app has a "Novel" project model that differs from Poetry, Drama, and Prose:

```
WS Novel Project
├── Chapters/
│   ├── Chapter 1/
│   │   ├── Scene 1
│   │   ├── Scene 2
│   │   └── Scene 3
│   └── Chapter 2/
│       ├── Scene 1
│       └── Scene 2
├── Characters/
├── Locations/
├── Plot Outline/
├── Research/
└── Manuscript
```

### Writing Shed Pro Fiction Structure

Writing Shed Pro uses a unified "Fiction" project type with a class selection:

```
WSP Fiction Project (Novel class)
├── Chapters/
│   └── [Chapter] → contains Scenes
├── Scenes/ (orphaned scenes)
├── Characters/
├── Locations/
├── Plot Outline/
└── Manuscript
```

## Current Import Limitations

The current `JSONImportService` does not properly handle:

1. **Project Type Mapping**: WS "Novel" projects are not mapped to Fiction-Novel
2. **Chapter Import**: WS chapters are not created as `Chapter` model instances
3. **Scene Import**: WS scenes are not created as `StoryScene` model instances
4. **Hierarchy Preservation**: Chapter→Scene relationships are lost
5. **Metadata**: Novel-specific metadata is not imported

---

## Legacy Data Model Analysis (Actual WSD Export Structure)

The WSD export uses nested JSON strings within the main JSON structure. Each entity has its metadata encoded as a JSON string within a `sceneComponent`, `textFile`, or `collectionComponent` field.

### Project Detection

Project type comes from `project.projectType` field (not `projectModel`):

```json
{
  "project": "{\n  \"projectType\" : \"Novel\",\n  \"name\" : \"My Novel\",\n  ...}"
}
```

Note: `projectModel` contains a numeric value ("35" for Novel) which is less reliable.

### Character Entity (`sceneComponentDatas`)

```json
{
  "type": "WS_Character_Entity",
  "id": "DE67D986-FBE1-4131-99E5-6035F5F370B6",
  "sceneComponent": "{\n  \"name\" : \"Noddy\",\n  \"role\" : \"Hero\",\n  \"history\" : \"Born in a toy box\",\n  \"looks\" : \"Ugly creep\",\n  \"traits\" : \"Bad tempered\",\n  \"work\" : \"Works at games\"\n}"
}
```

### Location Entity (`sceneComponentDatas`)

```json
{
  "type": "WS_Location_Entity",
  "id": "A6BCF699-25AB-4467-BFEC-E8653E4BB7CD",
  "sceneComponent": "{\n  \"name\" : \"home\",\n  \"detail\" : \"Suburban semi\",\n  \"sights\" : \"Sights untold\",\n  \"sounds\" : \"Deadly silent\",\n  \"smells\" : \"Dung\",\n  \"role\" : \"Where all the action takes place\"\n}"
}
```

### Scene Entity (`textFileDatas`)

```json
{
  "type": "WS_Scene_Entity",
  "id": "1F3E66E6-18FE-416D-8B33-84BC7A6FF31D",
  "textFile": "{\n  \"name\" : \"one\",\n  \"role\" : \"Hero\",\n  \"action\" : \"Kill the beast\",\n  \"notes\" : \"Nothing to say\",\n  \"position\" : 0\n}",
  "versions": [...]
}
```

### Chapter Entity (`collectionComponentDatas`)

```json
{
  "type": "WS_Chapter_Entity",
  "id": "DC230165-8EA3-40FD-AB6A-82590919F584",
  "collectionComponent": "{\n  \"name\" : \"the start\",\n  \"position\" : 0\n}"
}
```

### Key Field Mappings

| WS Entity | WS Fields | WSP Model | WSP Fields |
|-----------|-----------|-----------|------------|
| `WS_Character_Entity` | `name`, `role`, `history`, `looks`, `traits`, `work` | `Character` | Same field names |
| `WS_Location_Entity` | `name`, `detail`, `sights`, `sounds`, `smells` | `Location` | Same field names |
| `WS_Scene_Entity` | `name`, `action`, `notes`, `position` | `StoryScene` | `name`, `synopsis` (concatenate action+notes), `userOrder` |
| `WS_Chapter_Entity` | `name`, `position` | `Chapter` | `name`, `userOrder` |

---

## Implementation Plan

### Phase 1: Project Type Detection

Modify `mapProjectType()` in `JSONImportService` to detect Novel:

```swift
private func mapProjectType(_ modelName: String) -> ProjectType {
    switch modelName.lowercased() {
    case "poetry", "poems":
        return .poetry
    case "drama", "play", "screenplay":
        return .drama
    case "novel":
        return .fiction  // Set fictionClass = .novel
    case "shortstories", "short stories", "short fiction":
        return .fiction  // Set fictionClass = .shortFiction
    default:
        return .prose
    }
}
```

Also set `fictionClass` property:

```swift
if modelName.lowercased() == "novel" {
    project.fictionClass = .novel
} else if modelName.lowercased().contains("short") {
    project.fictionClass = .shortFiction
}
```

### Phase 2: Chapter Import

Add method to import WS chapters:

```swift
private func importNovelChapters(from data: WritingShedData, into project: Project) throws {
    // Filter chapter entities from sceneComponentDatas
    let chapterEntities = data.sceneComponentDatas.filter { 
        $0.type == "WS_Chapter_Entity" 
    }
    
    for (index, chapterData) in chapterEntities.sorted(by: { $0.displayOrder < $1.displayOrder }).enumerated() {
        let chapter = Chapter(
            id: UUID(uuidString: chapterData.id) ?? UUID(),
            name: chapterData.name,
            project: project
        )
        chapter.userOrder = index
        modelContext.insert(chapter)
        
        // Store mapping for scene import
        chapterMap[chapterData.id] = chapter
    }
}
```

### Phase 3: Scene Import

Add method to import WS scenes with chapter relationships:

```swift
private func importNovelScenes(from data: WritingShedData, into project: Project) throws {
    let sceneEntities = data.sceneComponentDatas.filter {
        $0.type == "WS_Scene_Entity"
    }
    
    for sceneData in sceneEntities.sorted(by: { $0.displayOrder < $1.displayOrder }) {
        // Find linked text file
        let textFile = textFileMap[sceneData.textFileId]
        
        // Find parent chapter
        let chapter = sceneData.chapterId.flatMap { chapterMap[$0] }
        
        let scene = StoryScene(
            id: UUID(uuidString: sceneData.id) ?? UUID(),
            name: sceneData.name,
            project: project,
            chapter: chapter,
            textFile: textFile
        )
        scene.userOrder = sceneData.displayOrder
        modelContext.insert(scene)
    }
}
```

### Phase 4: Character & Location Import

```swift
private func importNovelCharacters(from data: WritingShedData, into project: Project) throws {
    let characterEntities = data.sceneComponentDatas.filter {
        $0.type == "WS_Character_Entity"
    }
    
    for charData in characterEntities {
        let character = FictionCharacter(
            id: UUID(uuidString: charData.id) ?? UUID(),
            name: charData.name,
            project: project
        )
        character.notes = charData.notes
        character.role = charData.role
        modelContext.insert(character)
    }
}

private func importNovelLocations(from data: WritingShedData, into project: Project) throws {
    let locationEntities = data.sceneComponentDatas.filter {
        $0.type == "WS_Location_Entity"
    }
    
    for locData in locationEntities {
        let location = FictionLocation(
            id: UUID(uuidString: locData.id) ?? UUID(),
            name: locData.name,
            project: project
        )
        location.notes = locData.notes
        modelContext.insert(location)
    }
}
```

### Phase 5: Plot Outline Import

```swift
private func importNovelPlotElements(from data: WritingShedData, into project: Project) throws {
    let plotEntities = data.sceneComponentDatas.filter {
        $0.type == "WS_PlotElement_Entity"
    }
    
    for (index, plotData) in plotEntities.sorted(by: { $0.displayOrder < $1.displayOrder }).enumerated() {
        let element = PlotElement(
            id: UUID(uuidString: plotData.id) ?? UUID(),
            name: plotData.name,
            project: project
        )
        element.notes = plotData.notes
        element.userOrder = index
        
        // Map monomyth stage if present
        if let stageRaw = plotData.monomythStage {
            element.monomythStageRaw = stageRaw
        }
        
        modelContext.insert(element)
    }
}
```

---

## Data Model Updates

### SceneComponentData Extension

Update the `SceneComponentData` struct to capture all Novel-related fields:

```swift
struct SceneComponentData: Codable {
    let type: String
    let id: String
    let name: String?
    let displayOrder: Int
    
    // Chapter-specific
    let sceneIds: [String]?
    
    // Scene-specific
    let chapterId: String?
    let textFileId: String?
    let synopsis: String?
    let pov: String?
    let setting: String?
    
    // Character-specific
    let role: String?
    let archetype: String?
    let traits: [String]?
    
    // Location-specific
    let description: String?
    
    // Plot element-specific
    let notes: String?
    let monomythStage: String?
    let linkedSceneIds: [String]?
}
```

---

## Folder Structure Mapping

| WS Novel Folder | WSP Fiction Folder | Notes |
|-----------------|-------------------|-------|
| Chapters | Chapters | Contains Chapter models, not folders |
| Research | Research | Direct mapping |
| Characters | Characters | Now uses FictionCharacter model |
| Locations | Locations | Now uses FictionLocation model |
| Plot Outline | Plot Outline | Now uses PlotElement model |
| Manuscript | *(generated)* | Assembled from chapters |

---

## Testing Requirements

### Unit Tests

1. **Project Type Detection**
   - Test `mapProjectType("Novel")` returns `.fiction`
   - Test `fictionClass` is set to `.novel`

2. **Chapter Import**
   - Test chapters are created with correct order
   - Test chapter names are preserved

3. **Scene Import**
   - Test scenes are linked to correct chapters
   - Test scenes are linked to correct text files
   - Test orphaned scenes (no chapter) are handled

4. **Character/Location Import**
   - Test all characters are imported
   - Test character metadata is preserved

5. **Plot Element Import**
   - Test plot elements maintain order
   - Test monomyth stages are mapped correctly

### Integration Tests

1. Import complete WS Novel export file
2. Verify all chapters present
3. Verify all scenes linked correctly
4. Verify chapter navigation works
5. Verify manuscript assembly includes all content

### Test Data

Create test WSD files with:
- Novel project with 3 chapters, 2 scenes each
- Characters with various attributes
- Locations with descriptions
- Plot outline with monomyth stages

---

## Migration Notes

### User Communication

When importing a Novel project, show:
- "Importing Novel project as Fiction (Novel class)"
- Progress indicators for chapters, scenes, characters
- Summary of imported items

### Fallback Behavior

If Novel-specific import fails:
- Fall back to basic Prose import
- Log warning for review
- User can manually reorganize

---

## Future Considerations

- Import WS Short Story projects as Fiction (Short Fiction class)
- Import scene-plot element links
- Import character-scene appearances
- Support for WS Novel metadata (word count goals, deadlines)
