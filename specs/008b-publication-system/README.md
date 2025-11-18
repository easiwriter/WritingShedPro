# Feature 008b: Publication Management System

**Status**: Specification Complete (Deferred to Phase 2)  
**Priority**: Medium  
**Estimated Effort**: 3-4 weeks  
**Dependencies**: Feature 008a (File Movement System)

## Quick Links

- **[Full Specification](./spec.md)** - Complete feature requirements and data model
- **Parent Feature**: [008-file-movement-system](../008-file-movement-system/) (split into 008a and 008b)

## What This Feature Delivers

Professional publication management for tracking submissions to magazines and poetry competitions:

✅ **Publication entities** (magazines, competitions)  
✅ **Submission tracking** with exact version references  
✅ **Status management** (pending/accepted/rejected)  
✅ **Published folder** (auto-populated with accepted work)  
✅ **Submission history** by publication  
✅ **Version integrity** (preserves exact submitted content)  

## Why Split from 008a?

Original Feature 008 combined file movement with publication tracking, resulting in excessive scope. Splitting allows:

- **008a (File Movement)**: Core capability needed now - 2.5 weeks
- **008b (Publication System)**: Professional tracking - 3-4 weeks, build on top of 008a

This phase-based approach reduces risk and delivers value incrementally.

## Key Concepts

### Not Folder-Based Organization

Publications are **tracking entities**, not folders. Files stay in their source folders (Draft/Ready/Set Aside) but gain metadata showing submission history.

```
Publication: "Poetry Magazine"
  ↓
Submission: "November 2025" (3 poems)
  ↓
SubmittedFile: "sunset-poem.txt" (version 2, status: accepted)
```

### Published Folder = Computed View

The "Published" folder is **not a real folder** - it's a filtered view showing all files where `status == .accepted`. This means:

- ✅ Automatically populated when submission accepted
- ✅ Shows exact version submitted (not current version)
- ❌ Can't manually add files
- ❌ File still lives in source folder (Ready/Set Aside)

## Data Model

### Publication
```swift
@Model
class Publication {
  var name: String              // "Poetry Magazine"
  var type: PublicationType     // .magazine or .competition
  var url: String?              // Optional website
  var notes: String?
  var submissions: [Submission]
}
```

### Submission
```swift
@Model
class Submission {
  var publication: Publication
  var submittedFiles: [SubmittedFile]
  var submittedDate: Date
  var notes: String?
}
```

### SubmittedFile (Join Table)
```swift
@Model
class SubmittedFile {
  var submission: Submission
  var textFile: TextFile
  var version: Version           // ← Exact version submitted (immutable)
  var status: SubmissionStatus   // pending/accepted/rejected
  var statusDate: Date?
  var statusNotes: String?
}
```

## User Workflows

### Submit Files to Publication
1. Select files (using 008a edit mode)
2. Tap **Submit...**
3. Choose publication
4. Submission created with current versions locked

### Track Submission Status
1. Open submission detail
2. Change status to **Accepted** or **Rejected**
3. If accepted → File appears in Published folder automatically

### View Published Work
1. Tap **Published** folder in sidebar
2. See all accepted work grouped by publication
3. Tap file → Opens exact version that was accepted

## Critical Design Decisions

### Version Reference Integrity

**Decision**: SubmittedFile references Version (not just TextFile) to preserve exact content submitted.

**Rationale**: User might edit file after submission. We must show exactly what was sent to the publication.

**Implementation**:
```swift
// When creating submission:
let currentVersion = textFile.currentVersion ?? textFile.createVersion()
let submittedFile = SubmittedFile(
    version: currentVersion  // ← Locks to this version
)

// Later edits create new versions:
textFile.edit("New content")  // Creates v2
// submittedFile.version still points to v1
```

### Many-to-Many Relationships

**Pattern**: Use SubmittedFile as join table between Submission and TextFile

**Benefits**:
- Each file can be submitted multiple times
- Each submission can contain multiple files
- Tracks per-file status (one poem accepted, another rejected)
- Maintains version reference per submission

## Testing Strategy

- **Unit Tests** (~20): Publication, Submission, SubmittedFile models, version integrity
- **Integration Tests** (~15): Full submission workflow, CloudKit sync, concurrent edits
- **UI Tests** (~8): Create publication, submit files, change status, view Published folder

## Out of Scope

❌ Submission deadlines/reminders  
❌ Automated submission emails  
❌ Payment tracking  
❌ Contract management  
❌ Rights management  
❌ Publication statistics/analytics  

## Dependencies

- **Required**: Feature 008a (File Movement) - provides edit mode UI pattern
- **Required**: Feature 003 (Text Files) - provides Version model
- **Blocker**: Must complete 008a first to reuse FileListView component

## Implementation Notes

**When starting this feature:**
1. Implement Publication model first (simplest, no dependencies)
2. Then Submission model
3. Then SubmittedFile (most complex due to version references)
4. Test version integrity thoroughly before moving to UI
5. Implement Published folder as computed view last
6. Consider performance with hundreds of submissions

**Key Risks**:
- Version reference integrity (test exhaustively)
- CloudKit sync with complex relationships
- Performance with large submission histories
- Concurrent editing and status changes

## Next Steps (When Ready)

1. **Complete Feature 008a first**
2. Create plan.md for 008b (7-phase implementation)
3. Begin Phase 0: Research many-to-many relationship patterns in SwiftData
4. Design version preservation strategy
5. Prototype Published folder computed view

## Related Features

- **Previous**: [008a-file-movement](../008a-file-movement/) - Complete this first
- **Depends On**: Features 001, 002, 003, 008a
