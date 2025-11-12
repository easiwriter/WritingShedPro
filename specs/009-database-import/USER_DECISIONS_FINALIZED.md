# Feature 009 - Implementation Decisions: User Answers

**Date**: 12 November 2025  
**Status**: User Decisions Collected - Ready for Implementation Planning

---

## Summary of User Answers

### Decision 1: Folder Structure Mapping ✅ ANSWERED
**Choice**: A - Create folders from groupName
**Additional Info**: groupName maps to Project Type
**Status**: Implementation Ready

---

### Decision 2: Scene Components ✅ ANSWERED (Modified Scope)
**Choice**: C - Create new note fields (Extended scope)
**Additional Info**: 
- Scenes are a subclass of WS_Text_Entity
- Needed for Novel & Script projects
- SwiftData doesn't support inheritance, so need workaround
- Not applicable for Poetry/Short Story projects

**Implementation Impact**:
- EXTEND TextFile model to support scene metadata
- Add scene-specific properties when importing Scene entities
- Map WS_Character_Entity and WS_Location_Entity to scene metadata
- Only populate when importing Novel/Script projects

**Architecture Change**:
```swift
// NEW: Scene metadata extension (for Novel/Script)
@Model
final class TextFile {
    // Existing properties...
    
    // NEW: Scene-specific data (optional, only for Novel/Script)
    var sceneType: String?  // "Scene", "Character", "Location"
    var sceneMetadata: SceneMetadata?  // Related characters, locations
}

// NEW: Model for scene relationships
@Model
final class SceneMetadata {
    var id: UUID = UUID()
    var characters: [String] = []  // Character names referenced
    var locations: [String] = []   // Location names referenced
    var relatedScenes: [String] = [] // Scene IDs
}
```

**Data Flow**:
```
WS_Scene_Entity (subclass of WS_Text_Entity)
  - textName: "Chapter 1 - The Beginning"
  - groupName: "Part 1"
  - relationships: characters[], locations[]
  ↓
TextFile (with sceneMetadata)
  - name: "Chapter 1 - The Beginning"
  - parentFolder: "Part 1"
  - sceneType: "Scene"
  - sceneMetadata: SceneMetadata(
      characters: ["Alice", "Bob"],
      locations: ["London"],
      relatedScenes: [scene2.id, scene3.id]
    )

WS_Character_Entity
  - name: "Alice"
  - description: NSAttributedString
  - projectId: [reference to project]
  ↓
TextFile (as imported character note)
  - name: "Alice"
  - parentFolder: "[Project Name]/Characters" (auto-created)
  - sceneType: "Character"
  - sceneMetadata: SceneMetadata(
      characters: [],
      locations: []
    )
```

**Implementation Tasks**:
1. ✅ Analyze Scene entity structure in legacy model
2. ✅ Design SceneMetadata model
3. ✅ Implement scene mapping functions
4. ✅ Create character/location text files during import
5. ✅ Map relationships between scenes and components
6. ✅ Test with Novel/Script sample data

**Timeline Impact**: +1-2 days for scene implementation

---

### Decision 3: Submission Data Mapping ✅ ANSWERED
**Choice**: Keep approach (create duplicates is OK)
**Rationale**: Creates collection Submission AND publication Submission
**Status**: Implementation Ready

**Mapping Logic**:
```
LEGACY → NEW

WS_Collection_Entity
  ├─ Contains texts → Submission (publication=nil)
  │  └─ Contains SubmittedFile(s)
  │
  └─ If submitted to publication → NEW Submission (publication=set)
     └─ Copy SubmittedFile(s) to publication submission
```

---

### Decision 4: Data Integrity Approach ✅ ANSWERED
**Choice**: C - Hybrid mode (warn user, continue)
**Implementation**:
- Report all issues found during import
- Give user choice to continue or abort
- Show detailed import report after completion
- Log all warnings/errors for debugging

**Status**: Implementation Ready

---

### Decision 5: AttributedString Compatibility ✅ ANSWERED
**Choice**: Don't need round-trip (import only)
**Details**: 
- Legacy stores standard NSAttributedString (transformable)
- App only imports FROM legacy (no export)
- Can decode NSAttributedString directly
- No need to verify round-trip compatibility

**Implementation**:
- Read NSAttributedString from Core Data
- Convert to plain text for Version.content
- Convert to RTF Data for Version.formattedContent
- Simplified compatibility testing (one-way only)

**Status**: Implementation Ready

---

### Decision 6: Import Workflow Location ✅ ANSWERED (With Discussion)
**Choice**: C - Both (first launch + Settings)
**Additional Note**: "discuss details"

**Discussion Topics**:
1. **First Launch Detection**: How do we detect first launch?
   - Check if ModelContext has any Projects?
   - Check if WritingShed.sqlite exists on disk?
   - User preference flag?

2. **UI/UX Details**:
   - Should import block app startup or run in background?
   - Progress indicator during import?
   - Cancel button during import?
   - What happens if import fails?

3. **Settings Integration**:
   - "Import More Data" for adding more projects?
   - "Re-import" to update existing data?
   - Show import history/status?

4. **User Preferences**:
   - Remember user's choice (don't ask again)?
   - Option to re-trigger first launch import?

**Next Step**: Clarify these details before UI implementation

---

### Decision 7: File Storage Location ✅ ANSWERED
**Location**: `~/Library/Application Support/{bundle-identifier}/Writing-Shed.sqlite`
**Status**: ✅ RESOLVED - Ready to use

---

### Decision 8: Test Data ✅ ANSWERED
**Can we use your database?**: Yes
**Status**: Ready to use for testing

---

## Implementation Decision Matrix

| Decision | Your Choice | Details | Implementation Status |
|----------|-------------|---------|----------------------|
| 1. Folder mapping | A | groupName → Project Type | ✅ Ready |
| 2. Scene components | C | Extend TextFile for scenes | ⏳ Design phase |
| 3. Submission mapping | Keep duplicates | Create both submissions | ✅ Ready |
| 4. Data integrity | C (Hybrid) | Warn user, continue | ✅ Ready |
| 5. AttributedString | Import only | One-way conversion | ✅ Ready |
| 6. Import workflow | C (Both) | First launch + Settings | ⏳ Discuss details |
| 7. Database location | Known | Direct file access | ✅ Ready |
| 8. Test data | Yes | Your database | ✅ Ready |

---

## Implementation Phases

### Phase 1: Core Infrastructure (Days 1-2)
✅ Decisions finalized
- [ ] LegacyDatabaseService (read Core Data)
- [ ] Core entity mapping functions
- [ ] AttributedString → RTF conversion
- [ ] Error/warning collection

### Phase 2: Extended Scope - Scene Support (Days 3-4)
⏳ Decisions finalized
- [ ] Analyze WS_Scene_Entity structure
- [ ] Design SceneMetadata model
- [ ] Implement scene mapping
- [ ] Character/location import

### Phase 3: Import Engine (Days 5-6)
✅ Decisions finalized
- [ ] DataMapper with all entities
- [ ] Submission duplicate handling
- [ ] Hybrid error recovery
- [ ] Progress tracking

### Phase 4: UI/Workflow (Days 7-8)
⏳ Details to discuss
- [ ] First launch detection
- [ ] Import progress UI
- [ ] Settings integration
- [ ] Error reporting

### Phase 5: Testing & Polish (Days 9-12)
✅ Decisions finalized
- [ ] Test with user's database
- [ ] Edge case handling
- [ ] Performance optimization
- [ ] Documentation

---

## Outstanding Questions

### Decision 6 - Import Workflow Details

Please clarify these items:

1. **First Launch Detection**
   - Detect via: Empty ModelContext? File exists check? Preference flag?

2. **Import Blocking**
   - Should import block app startup or run in background?
   - Progress UI during import?
   - Cancel button?

3. **Failure Handling**
   - If import fails, what's the user experience?
   - Retry option?
   - Rollback changes?

4. **Settings Integration**
   - Should "Settings → Import" re-import everything or add more data?
   - Show import history?
   - Allow selective re-import?

5. **User Preferences**
   - Remember choice (don't ask again)?
   - Option to re-trigger import later?

---

## Next Steps

### Immediate
1. ✅ Clarify Decision 6 workflow details
2. ✅ Review Scene component design
3. ✅ Verify legacy database accessibility

### Before Implementation
1. ✅ Locate your Writing-Shed.sqlite file
2. ✅ Extract sample WS_TextString for AttributedString testing
3. ✅ Extract sample Scene/Character/Location entities for structure verification

### During Implementation
1. ⏳ Test with user's actual database
2. ⏳ Verify all entity mappings work
3. ⏳ Validate import with various project types (Novel/Script/Poetry)

---

## Architecture Adjustments

Based on the decision to support Scenes:

**TextFile Model Extension** (NEW):
```swift
@Model
final class TextFile {
    // Existing...
    var sceneType: String?  // "Scene", "Character", "Location"
    var sceneMetadata: SceneMetadata?
}

@Model
final class SceneMetadata {
    var id: UUID = UUID()
    var characters: [String] = []
    var locations: [String] = []
    var relatedScenes: [String] = []
}
```

**Folder Structure for Imported Data** (NEW):
```
Project (imported from legacy)
├── Folder: "Part 1" (from groupName)
│   ├── TextFile: "Chapter 1"
│   └── TextFile: "Chapter 2"
├── Folder: "[Project Name]/Characters" (auto-created for scene components)
│   ├── TextFile: "Alice" (from WS_Character_Entity)
│   └── TextFile: "Bob"
└── Folder: "[Project Name]/Locations" (auto-created)
    ├── TextFile: "London"
    └── TextFile: "Paris"
```

---

## Summary

✅ **8 implementation decisions made**
✅ **Database location confirmed**
✅ **Test data available**
✅ **Scope extended to support Scene components**
⏳ **Need clarification on Decision 6 workflow details**
⏳ **Scene design needs review**

**Ready to proceed**: Clarify Decision 6 details, then begin Phase 1 implementation.

---
