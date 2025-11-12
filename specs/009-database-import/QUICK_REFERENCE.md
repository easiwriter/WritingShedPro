# Feature 009 - Quick Reference Guide

**Complete Database Import Analysis Ready**

---

## 📊 What We Know

### Legacy Model (Original Writing Shed)
```
WS_Project_Entity
├── WS_Text_Entity (files)
│   └── WS_Version_Entity
│       └── WS_TextString_Entity (content: NSAttributedString)
├── WS_Collection_Entity (named groups)
│   ├── WS_CollectedVersion_Entity (version refs)
│   └── WS_CollectionSubmission_Entity (submission tracking)
├── WS_Submission_Entity (publications)
└── WS_SceneComponent_Entity (Characters, Locations)
```

### New Model (Writing Shed Pro)
```
Project
├── Folder (hierarchy)
│   └── TextFile
│       └── Version (content: NSAttributedString)
├── Submission (where publication=nil → Collection)
│   └── SubmittedFile (version references)
└── Submission (where publication!=nil → Published)
```

---

## 🗺️ Entity Mapping Reference

| Legacy | → | New | Notes |
|--------|---|-----|-------|
| WS_Project_Entity | → | Project | Parse `projectType` string to enum |
| WS_Text_Entity | → | TextFile | Lose `groupName` (use folder instead) |
| WS_Version_Entity | → | Version | Keep locked flag |
| WS_TextString_Entity | → | Version.content | NSAttributedString (direct transfer) |
| WS_Collection_Entity | → | Submission (pub=nil) | Add name field needed |
| WS_CollectedVersion_Entity | → | SubmittedFile | Include position/status |
| WS_CollectionSubmission_Entity | → | Submission (pub set) | Creates new submission |
| WS_Character_Entity | → | ❌ Skip (Phase 2) | Novel/script components |
| WS_Location_Entity | → | ❌ Skip (Phase 2) | Novel/script components |

---

## ❓ Critical Questions to Answer

### Structural
- [ ] **Q1**: Create folders from `groupName` or dump in one folder?
- [ ] **Q2**: Skip scene components or try to import?
- [ ] **Q7**: WHERE is legacy database located? ⚠️ BLOCKING

### Data Handling
- [ ] **Q3**: Is duplicate Submission structure OK?
- [ ] **Q4**: Strict/Lenient/Hybrid error handling?
- [ ] **Q5**: Test AttributedString first?

### UX
- [ ] **Q6**: Import on first launch, settings, or both?
- [ ] **Q8**: Can we use your real Writing Shed data?

---

## 📈 Import Architecture

```
1. DISCOVERY
   ├─ Locate legacy Core Data file
   └─ Open read-only connection

2. LOADING
   ├─ Fetch all WS_Project_Entity objects
   ├─ For each project:
   │  ├─ Fetch WS_Text_Entity
   │  ├─ Fetch WS_Version_Entity for each text
   │  ├─ Fetch WS_TextString_Entity (content)
   │  └─ Fetch WS_Collection_Entity
   └─ Cache object graph

3. MAPPING
   ├─ Project → Project
   ├─ Text → TextFile (assign to folder)
   ├─ Version → Version (with content)
   ├─ Collection → Submission(pub=nil)
   ├─ CollectedVersion → SubmittedFile
   └─ CollectionSubmission → Submission(pub set)

4. INSERTION
   ├─ Insert all Project objects
   ├─ Insert all Folder objects
   ├─ Insert all TextFile objects
   ├─ Insert all Version objects
   ├─ Insert all Submission objects
   └─ Insert all SubmittedFile objects

5. VALIDATION
   ├─ Verify counts match
   ├─ Verify relationships intact
   ├─ Check data integrity
   └─ Generate report

6. COMPLETION
   └─ Show user import summary
```

---

## 🛠️ Ready to Implement

### Core Services Needed
1. `LegacyDatabaseService` - Read Core Data
2. `DataMapper` - Map entities
3. `ImportEngine` - Orchestrate process
4. `ImportUICoordinator` - Handle UI/progress

### Key Functions Ready
- `mapProject(_ legacy: WS_Project_Entity) -> Project`
- `mapTextFile(_ legacy: WS_Text_Entity) -> TextFile`
- `mapVersion(_ legacy: WS_Version_Entity) -> Version`
- `mapCollection(_ legacy: WS_Collection_Entity) -> Submission`
- `mapSubmittedFile(_ legacy: WS_CollectedVersion_Entity) -> SubmittedFile`

### Error Handling Strategies
- Invalid UUID: Skip item, log warning
- Missing content: Create with placeholder
- Corrupted data: Use hybrid approach (report + continue)
- Missing relationships: Handle gracefully

---

## ⏱️ Timeline

**Total: 9-12 days** (once decisions made)

```
Days 1-2:  Core Data reader service
Days 3-4:  Mapping functions & engine
Days 5-6:  Import UI & progress
Days 7-9:  Testing & edge cases
Days 10-12: Integration & polish
```

---

## 📋 Before Implementation: Checklist

- [ ] Answer all 8 key questions
- [ ] Find legacy database file path
- [ ] Verify AttributedString compatibility
- [ ] Have test data (your Writing Shed database)
- [ ] Review LEGACY_MODEL_ANALYSIS.md
- [ ] Approve entity mappings
- [ ] Decide on error handling approach

---

## 🎯 What Happens Next

### If you answer the questions TODAY:
✅ We can start implementation TOMORROW
✅ LegacyDatabaseService built in 1-2 days
✅ Full import working in ~5 days
✅ Feature complete in ~10 days

### If we wait:
❌ Need to guess at implementation details
❌ Might build wrong approach
❌ Rework required if decisions change

---

## 🚀 Getting Started

**IMMEDIATE ACTIONS NEEDED**:

1. **Find the database file**
   ```bash
   # Try these locations:
   ~/Library/Application\ Support/Writing\ Shed/
   ~/Library/Group\ Containers/*/
   ~/iCloud\ Drive/Writing\ Shed/
   
   # Or tell us where it is
   ```

2. **Answer the 8 questions**
   - See IMPLEMENTATION_DECISIONS.md for details

3. **Verify AttributedString compatibility**
   - Test reading a legacy version's content

---

## 📚 Documentation

- **LEGACY_MODEL_ANALYSIS.md** - Complete model breakdown
- **IMPLEMENTATION_DECISIONS.md** - 8 key decisions with options
- **ANALYSIS_SUMMARY.md** - Overview and status
- **spec.md** - Original specification

---

## Questions?

See **IMPLEMENTATION_DECISIONS.md** for:
- Each decision with pros/cons
- Detailed explanations
- Recommendations
- Technical considerations

---

**Status**: ✅ Analysis Complete | ⏳ Awaiting Implementation Decisions

**Ready to build**: Once you provide answers and database location!
