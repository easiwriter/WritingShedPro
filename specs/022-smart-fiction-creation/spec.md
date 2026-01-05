# Feature 022: Smart Fiction Creation

**Status**: Draft  
**Priority**: High  
**Estimated Effort**: TBD  
**Dependencies**: 001-project-management-ios-macos  
**Created**: 2026-01-01

## Overview

The user can create projects for handling fiction, by which I mean anything other than Poetry and Drama. The General Purpose project type is intended for writing non-genre texts.

### Fiction Classes

When the user creates a Fiction project, they must choose the class of fiction via a dropdown menu:
- **Novel** (long fiction) - includes Chapters which contain Scenes
- **Short Fiction** - contains Scenes directly, no chapter layer

This choice is stored as a property on the project and cannot be changed after creation.

### Core Concepts

**Scene**: A scene is a place where something happens. There should be a clear outcome. Scenes are the fundamental unit of storytelling in fiction projects.

**Chapter** (Novel only): A mandatory container for scenes in novels. Chapters organize scenes into logical groupings.

**Manuscript**: A place for collecting the work:
- In Novels: collects Chapters (which contain Scenes)
- In Short Fiction: collects Scenes directly

**Character**: A character definition with attributes. Attributes vary based on whether the monomyth structure is used:
- Without monomyth: user-defined custom fields (key-value pairs)
- With monomyth: archetype-based attributes (Hero, Mentor, Herald, Threshold Guardian, Shapeshifter, Shadow, Ally, Trickster)

**Location**: A location definition where actions take place. Uses user-defined custom fields for flexible attribute specification.

### Plot Structure

Fiction projects can optionally be structured according to Joseph Campbell's monomyth as exemplified in *The Writer's Journey* by Christopher Vogler.

**Plot Outline**: A way for the writer to plan their story structure.
- If monomyth is selected: the plot outline follows the 12 stages (Ordinary World, Call to Adventure, Refusal of the Call, Meeting the Mentor, Crossing the Threshold, Tests/Allies/Enemies, Approach to the Inmost Cave, Ordeal, Reward, The Road Back, Resurrection, Return with the Elixir)
- If monomyth is not selected: freeform plot outline structure

Plot outline elements can link to scenes, allowing the writer to track which scenes fulfill which plot beats.

## User Stories

### US1: Create Fiction Project with Class Selection (P1)

**As a** fiction writer  
**I want to** create a new fiction project and choose whether it's a novel or short fiction  
**So that** I have the right structure for my work from the start

**Acceptance Criteria:**
- When creating a Fiction project, a dropdown appears for fiction class selection
- Options are "Novel" and "Short Fiction"
- Selection is required before project creation
- The choice is stored on the project and displayed in project details
- The choice cannot be changed after creation

---

### US2: Create and Manage Scenes (P1)

**As a** fiction writer  
**I want to** create scenes with clear outcomes  
**So that** I can build my story from fundamental units

**Acceptance Criteria:**
- Can create a new scene with a name
- Can add content to the scene (the actual writing)
- Can edit scene name and content
- Can delete scenes
- Scenes display in a list view

---

### US3: Organize Scenes into Chapters - Novel Only (P1)

**As a** novelist  
**I want to** group my scenes into chapters  
**So that** I can organize my long-form work logically

**Acceptance Criteria:**
- Novel projects have a Chapters folder
- Can create new chapters
- Can add scenes to chapters
- Can reorder scenes within a chapter
- Can move scenes between chapters
- Short Fiction projects do NOT have chapters

---

### US4: Build Manuscript (P1)

**As a** fiction writer  
**I want to** collect my work into a manuscript  
**So that** I can see and export my complete story

**Acceptance Criteria:**
- Novel: Manuscript collects chapters (in order) which contain scenes
- Short Fiction: Manuscript collects scenes directly
- Can view manuscript as a continuous document
- Can print or export manuscript

---

### US5: Define Characters (P2)

**As a** fiction writer  
**I want to** create character definitions with attributes  
**So that** I can track my characters' details

**Acceptance Criteria:**
- Can create a character with a name
- Without monomyth: can add custom key-value attributes
- With monomyth: can assign archetype (Hero, Mentor, etc.)
- Can edit and delete characters
- Characters display in a list view

---

### US6: Define Locations (P2)

**As a** fiction writer  
**I want to** create location definitions  
**So that** I can track the places in my story

**Acceptance Criteria:**
- Can create a location with a name
- Can add custom key-value attributes
- Can edit and delete locations
- Locations display in a list view

---

### US7: Use Monomyth Plot Structure (P2)

**As a** fiction writer  
**I want to** optionally structure my plot using the monomyth  
**So that** I can follow a proven storytelling framework

**Acceptance Criteria:**
- Can enable/disable monomyth structure for the project
- If enabled, plot outline shows 12 monomyth stages
- If disabled, plot outline is freeform
- Character archetypes available when monomyth is enabled

---

### US8: Create Plot Outline (P2)

**As a** fiction writer  
**I want to** plan my story structure  
**So that** I have a roadmap for my writing

**Acceptance Criteria:**
- With monomyth: shows 12 stages as outline elements
- Without monomyth: can create custom outline elements
- Can add notes to each outline element
- Can link outline elements to scenes
- Can see which scenes fulfill which plot beats

---

## Functional Requirements

### FR1: Fiction Project Creation
- **FR1.1:** When creating a Fiction project, system MUST display a fiction class dropdown with options "Novel" and "Short Fiction"
- **FR1.2:** Fiction class selection MUST be required before project creation can complete
- **FR1.3:** System MUST store the fiction class as a property on the Project model
- **FR1.4:** Fiction class MUST be displayed in project details view
- **FR1.5:** Fiction class MUST NOT be editable after project creation
- **FR1.6:** System MUST create appropriate folder structure based on fiction class

### FR2: Scene Management
- **FR2.1:** System MUST allow creation of scenes with a name
- **FR2.2:** Scenes MUST support rich text content (using existing Version/TextFile model)
- **FR2.3:** System MUST allow editing scene name and content
- **FR2.4:** System MUST allow deleting scenes with confirmation
- **FR2.5:** Scenes MUST display in a sortable list view
- **FR2.6:** System MUST allow reordering scenes via drag-and-drop

### FR3: Chapter Management (Novel Only)
- **FR3.1:** Novel projects MUST have a Chapters container
- **FR3.2:** Short Fiction projects MUST NOT have chapters
- **FR3.3:** System MUST allow creation of chapters with a name
- **FR3.4:** Chapters MUST contain scenes as children
- **FR3.5:** System MUST allow adding scenes to chapters
- **FR3.6:** System MUST allow reordering scenes within a chapter
- **FR3.7:** System MUST allow moving scenes between chapters
- **FR3.8:** System MUST allow reordering chapters
- **FR3.9:** System MUST allow deleting chapters (with option to preserve or delete contained scenes)

### FR4: Manuscript
- **FR4.1:** System MUST provide a Manuscript view for the complete work
- **FR4.2:** Novel manuscript MUST collect chapters in order, with scenes within each chapter
- **FR4.3:** Short Fiction manuscript MUST collect scenes directly in order
- **FR4.4:** Manuscript MUST display as a continuous document
- **FR4.5:** System MUST allow printing the manuscript
- **FR4.6:** System MUST allow exporting the manuscript (PDF, DOCX, etc.)

### FR5: Character Management
- **FR5.1:** System MUST allow creation of characters with a name
- **FR5.2:** System MUST allow adding custom key-value attributes to characters
- **FR5.3:** When monomyth is enabled, system MUST allow assigning archetypes to characters
- **FR5.4:** Available archetypes: Hero, Mentor, Herald, Threshold Guardian, Shapeshifter, Shadow, Ally, Trickster
- **FR5.5:** System MUST allow editing and deleting characters
- **FR5.6:** Characters MUST display in a list view

### FR6: Location Management
- **FR6.1:** System MUST allow creation of locations with a name
- **FR6.2:** System MUST allow adding custom key-value attributes to locations
- **FR6.3:** System MUST allow editing and deleting locations
- **FR6.4:** Locations MUST display in a list view

### FR7: Monomyth Structure
- **FR7.1:** System MUST allow enabling/disabling monomyth structure per project
- **FR7.2:** Monomyth choice SHOULD be made at project creation but MAY be toggled later
- **FR7.3:** When monomyth is enabled, plot outline MUST show 12 predefined stages
- **FR7.4:** The 12 stages are: Ordinary World, Call to Adventure, Refusal of the Call, Meeting the Mentor, Crossing the Threshold, Tests/Allies/Enemies, Approach to the Inmost Cave, Ordeal, Reward, The Road Back, Resurrection, Return with the Elixir
- **FR7.5:** When monomyth is disabled, plot outline MUST be freeform (user-created elements)

### FR8: Plot Outline
- **FR8.1:** System MUST provide a plot outline view
- **FR8.2:** With monomyth: outline MUST display the 12 stages as elements
- **FR8.3:** Without monomyth: system MUST allow creating custom outline elements
- **FR8.4:** System MUST allow adding notes to each outline element
- **FR8.5:** System MUST allow linking outline elements to one or more scenes
- **FR8.6:** System MUST display which scenes are linked to each outline element
- **FR8.7:** System MUST allow reordering outline elements (freeform mode only)

### FR9: Folder Structure
- **FR9.1:** Fiction projects MUST create these folders: Scenes, Characters, Locations, Plot, Manuscript, Research, Trash
- **FR9.2:** Novel projects MUST additionally create: Chapters
- **FR9.3:** Folder display order MUST follow logical workflow

## Non-Functional Requirements

- **NFR1:** All UI text MUST be localized using NSLocalizedString
- **NFR2:** Preview blocks (#Preview) MUST NOT be created - no Xcode previews
- **NFR3:** All interactive elements MUST have accessibility labels
- **NFR4:** All models MUST use optional properties or defaults for CloudKit compatibility
- **NFR5:** All relationships MUST use appropriate delete rules for data integrity
- **NFR6:** Scene content MUST use existing Version model for undo/redo support
- **NFR7:** Manuscript export MUST reuse existing PrintService and export services
- **NFR8:** Fiction class dropdown MUST integrate with existing AddProjectSheet

## Key Entities

### Project (Extended)
```swift
@Model
final class Project {
    // Existing properties...
    
    // New for Fiction
    var fictionClassRaw: String?  // "novel" or "shortFiction"
    var useMonomyth: Bool = false
    
    var fictionClass: FictionClass? {
        get { FictionClass(rawValue: fictionClassRaw ?? "") }
        set { fictionClassRaw = newValue?.rawValue }
    }
}

enum FictionClass: String, Codable, CaseIterable {
    case novel
    case shortFiction
}
```

### Scene
```swift
@Model
final class Scene {
    var id: UUID = UUID()
    var name: String?
    var userOrder: Int?
    var synopsis: String?  // Brief description of what happens
    
    // Relationships
    var chapter: Chapter?  // nil for Short Fiction
    var project: Project?
    var textFile: TextFile?  // Contains the actual scene content
    var plotElements: [PlotElement]?  // Which plot beats this scene fulfills
}
```

### Chapter (Novel only)
```swift
@Model
final class Chapter {
    var id: UUID = UUID()
    var name: String?
    var userOrder: Int?
    var synopsis: String?
    
    // Relationships
    var project: Project?
    @Relationship(deleteRule: .nullify, inverse: \Scene.chapter)
    var scenes: [Scene]?
}
```

### Character
```swift
@Model
final class Character {
    var id: UUID = UUID()
    var name: String?
    var archetypeRaw: String?  // Only used when monomyth enabled
    var notes: String?
    
    // Relationships
    var project: Project?
    var customAttributes: [CustomAttribute]?
    
    var archetype: CharacterArchetype? {
        get { CharacterArchetype(rawValue: archetypeRaw ?? "") }
        set { archetypeRaw = newValue?.rawValue }
    }
}

enum CharacterArchetype: String, Codable, CaseIterable {
    case hero
    case mentor
    case herald
    case thresholdGuardian
    case shapeshifter
    case shadow
    case ally
    case trickster
}
```

### Location
```swift
@Model
final class Location {
    var id: UUID = UUID()
    var name: String?
    var notes: String?
    
    // Relationships
    var project: Project?
    var customAttributes: [CustomAttribute]?
}
```

### CustomAttribute
```swift
@Model
final class CustomAttribute {
    var id: UUID = UUID()
    var key: String?
    var value: String?
    
    // Relationships
    var character: Character?
    var location: Location?
}
```

### PlotElement
```swift
@Model
final class PlotElement {
    var id: UUID = UUID()
    var name: String?
    var notes: String?
    var userOrder: Int?
    var monomythStageRaw: String?  // Only for monomyth projects
    
    // Relationships
    var project: Project?
    var linkedScenes: [Scene]?
    
    var monomythStage: MonomythStage? {
        get { MonomythStage(rawValue: monomythStageRaw ?? "") }
        set { monomythStageRaw = newValue?.rawValue }
    }
}

enum MonomythStage: String, Codable, CaseIterable {
    case ordinaryWorld
    case callToAdventure
    case refusalOfTheCall
    case meetingTheMentor
    case crossingTheThreshold
    case testsAlliesEnemies
    case approachToTheInmostCave
    case ordeal
    case reward
    case theRoadBack
    case resurrection
    case returnWithTheElixir
    
    var displayName: String {
        switch self {
        case .ordinaryWorld: return "Ordinary World"
        case .callToAdventure: return "Call to Adventure"
        case .refusalOfTheCall: return "Refusal of the Call"
        case .meetingTheMentor: return "Meeting the Mentor"
        case .crossingTheThreshold: return "Crossing the Threshold"
        case .testsAlliesEnemies: return "Tests, Allies, Enemies"
        case .approachToTheInmostCave: return "Approach to the Inmost Cave"
        case .ordeal: return "Ordeal"
        case .reward: return "Reward"
        case .theRoadBack: return "The Road Back"
        case .resurrection: return "Resurrection"
        case .returnWithTheElixir: return "Return with the Elixir"
        }
    }
}
```

## Edge Cases

1. **Deleting a chapter with scenes**: User must choose to either delete all contained scenes or move them to "unassigned" state
2. **Deleting a scene linked to plot elements**: Links should be removed but plot elements preserved
3. **Toggling monomyth off after archetypes assigned**: Archetype data preserved but hidden from UI; can be restored if monomyth re-enabled
4. **Empty manuscript**: Display helpful message prompting user to create scenes/chapters
5. **Scene without content**: Allow creation but display indicator that scene needs content
6. **Duplicate names**: Allow duplicate scene/chapter/character names (user's choice) but warn if detected
7. **Moving scene from chapter to unassigned**: In novels, scenes can exist outside chapters temporarily
8. **Character without archetype (monomyth enabled)**: Allowed - archetype is optional even with monomyth
9. **Plot element with no linked scenes**: Allowed - serves as planning placeholder
10. **Fiction class not selected**: Block project creation until class is chosen

## Success Criteria

- **SC1:** Users can create Fiction projects with Novel or Short Fiction class selection
- **SC2:** Novel projects display chapters containing scenes; Short Fiction projects display scenes directly
- **SC3:** Users can create, edit, reorder, and delete scenes
- **SC4:** Users can create, edit, reorder, and delete chapters (Novel only)
- **SC5:** Manuscript view correctly assembles content in proper order
- **SC6:** Users can print and export manuscripts
- **SC7:** Users can create characters with custom attributes or archetypes
- **SC8:** Users can create locations with custom attributes
- **SC9:** Monomyth structure shows 12 stages when enabled
- **SC10:** Plot outline elements can be linked to scenes
- **SC11:** All data syncs correctly via CloudKit
- **SC12:** No data loss when toggling monomyth on/off

## Assumptions

1. **Reuse existing infrastructure**: Scene content will use existing TextFile/Version models for rich text, undo/redo, and versioning
2. **Folder-based navigation**: Fiction projects will use the existing folder navigation pattern with fiction-specific folders
3. **CloudKit compatibility**: All new models will follow existing patterns (optional properties, appropriate delete rules)
4. **No migration required**: This is a new feature with no existing Fiction projects to migrate
5. **Monomyth is optional**: Writers can use Fiction projects without any plot structure assistance
6. **Print/Export reuse**: Manuscript printing will reuse existing PrintService; export will reuse existing export services
7. **Character archetypes are suggestions**: The 8 archetypes are from Vogler but users aren't limited to these patterns
8. **Scenes are the atomic unit**: All actual writing happens in scenes; chapters are organizational containers only
