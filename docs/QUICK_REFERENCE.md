# Write! Quick Reference Card
## Phase 001-002 Implementation Summary

**Commit**: `b8a46c2` | **Tests**: 66/66 ✅ | **Date**: 21 Oct 2025

---

## 30-Second Summary

Built a complete iOS/macOS writing app with:
- ✅ Project management (add/edit/delete with 3 types)
- ✅ Auto-generated folder templates (3 root + 12 nested)
- ✅ Hierarchical folder/file navigation
- ✅ Full CloudKit sync
- ✅ Comprehensive test coverage (66 tests)

**Tech**: SwiftUI + SwiftData + CloudKit + XCTest

---

## Architecture at a Glance

```
Models (BaseModels.swift)
├── Project (container for folders)
├── Folder (hierarchical, can contain folders/files)
└── File (text document)

Services (Shared logic)
├── NameValidator (checks non-empty)
├── UniquenessChecker (checks duplicates)
├── ProjectTemplateService (generates folders)
└── CloudKitSyncService (handles sync)

Views (SwiftUI UI)
├── ContentView (project list)
├── ProjectDetailView (shows FolderListView)
├── FolderListView (folder hierarchy)
├── ProjectInfoSheet (project details modal)
├── AddProjectSheet, AddFolderSheet (creation forms)
└── FileDetailView (file metadata)
```

---

## Folder Template Structure

**When you create a project, this structure is auto-generated:**

```
Project
├── Your [Type]              ← "Your Poetry" or "Your Prose" or "Your Drama"
│   ├── All
│   ├── Draft
│   ├── Ready
│   ├── Set Aside
│   ├── Published
│   ├── Collections/
│   ├── Submissions/
│   └── Research/
├── Publications
│   ├── Magazines/
│   ├── Competitions/
│   ├── Commissions/
│   └── Other/
└── Trash
```

**Total**: 3 root + 12 nested = 15 folders per project

---

## Critical Design Decisions

| Decision | Why | How |
|----------|-----|-----|
| **SwiftData** | Modern Apple persistence | Auto-syncs via CloudKit |
| **Optional project on subfolders** | Prevent inverse relationship auto-adds | Only root folders get project reference |
| **Direct relationship access** | Avoid SwiftData predicate bugs | Use `folder.subfolders` instead of @Query predicates |
| **State-based navigation** | More control than NavigationLink | Use `.navigationDestination(item:)` |
| **Info sheet for details** | Separate concerns | Folders primary, details secondary |
| **Cascade delete** | Prevent orphaned data | SwiftData .cascade rule + UI confirmation |

---

## Debugging Quick Links

| Issue | Solution | File |
|-------|----------|------|
| Folder count wrong (15 instead of 3) | Don't set project on subfolders | ProjectTemplateService.swift |
| Navigation loop | Use direct property access, not predicates | FolderListView.swift |
| Info sheet blank | Pass state bindings, not .constant() | ProjectDetailView.swift |
| Info button disabled | Move NavigationLink outside button | ContentView.swift |
| Build fails | Clean build, check CloudKit entitlements | Xcode → Product → Scheme |
| Tests fail | Verify iOS 17.5+, CloudKit enabled | IMPLEMENTATION_GUIDE.md |

---

## Common Code Patterns

### Create Project with Template
```swift
let project = Project(name: "My Poetry", type: .poetry)
modelContext.insert(project)
ProjectTemplateService.createDefaultFolders(for: project, in: modelContext)
```

### Create Folder
```swift
let folder = Folder(name: "Draft", project: nil)
folder.parentFolder = parentFolder
modelContext.insert(folder)
```

### Query Folders
```swift
// ✅ Right: Direct property access
var childFolders: [Folder] {
    parentFolder?.folders ?? project.folders
}

// ❌ Wrong: Predicate with optional chaining
@Query(filter: #Predicate<Folder> { $0.parentFolder?.id == id })
```

### Validate Name
```swift
do {
    try NameValidator.validateProjectName(name)
    if UniquenessChecker.isProjectNameUnique(name, in: projects) {
        // Proceed
    } else {
        // Show duplicate error
    }
} catch {
    // Show validation error
}
```

---

## File Locations

```
Write! (Xcode Project)
├── Write_App.swift              ← App entry + ModelContainer
├── ContentView.swift            ← Project list
├── Views/
│   ├── ProjectDetailView.swift  ← Shows folders + info sheet
│   ├── FolderListView.swift     ← Folder hierarchy
│   ├── ProjectInfoSheet.swift   ← Project details modal
│   ├── AddProjectSheet.swift    ← Create projects
│   ├── AddFolderSheet.swift     ← Create folders
│   └── FileDetailView.swift     ← File metadata
└── Write!Tests/                 ← 66 tests

Write (Shared)
├── models/BaseModels.swift      ← Data models
├── services/                    ← Business logic
│   ├── NameValidator.swift
│   ├── UniquenessChecker.swift
│   ├── ProjectTemplateService.swift
│   ├── ProjectDataService.swift
│   └── CloudKitSyncService.swift
└── specs/                       ← Documentation
    ├── 001-project-management-ios-macos/
    └── 002-folder-file-management/
```

---

## Testing Summary

| Category | Count | Examples |
|----------|-------|----------|
| Validation Tests | 12 | Empty names, duplicates |
| Uniqueness Tests | 8 | Check duplicates in context |
| Template Tests | 5 | Folder structure, counts |
| CRUD Tests | 15 | Create, rename, delete operations |
| Navigation Tests | 6 | Drill down/up hierarchies |
| Integration Tests | 14 | End-to-end workflows |
| CloudKit Tests | 6 | Sync verification |
| **Total** | **66** | All passing ✅ |

**Run all tests**: `⌘+U` in Xcode

---

## Git Workflow

```bash
# See what was done
git show b8a46c2

# See changes in this commit
git diff HEAD~1 HEAD

# Create new branch for Phase 003
git checkout -b 003-text-editing

# Make changes, commit, push
git add .
git commit -m "Add feature"
git push origin 003-text-editing
```

---

## Xcode Shortcuts

| Shortcut | Action |
|----------|--------|
| ⌘+B | Build |
| ⌘+R | Run on simulator |
| ⌘+U | Run all tests |
| ⌘+Shift+K | Clean build |
| ⌘+6 | Show test navigator |
| ⌘+5 | Show debug navigator |
| ⌘+L | Jump to line |

---

## CloudKit Verification

```bash
# 1. Check entitlements
Xcode → Project → Signing & Capabilities
✅ iCloud enabled
✅ CloudKit checked

# 2. Monitor in app
Device Settings → [App] → iCloud → Enable iCloud Drive

# 3. Test sync (2 devices)
Device 1: Create folder → Wait 5s
Device 2: Refresh app → Should see folder

# 4. View debug logs
Product → Scheme → Edit Scheme → Run → Environment Variables
Add: SQLITEDEBUG=1
```

---

## Phase 002 Changes from Phase 001

| Component | Change | Reason |
|-----------|--------|--------|
| ProjectTemplateService | NEW | Auto-generate folders |
| FolderListView | NEW | Display hierarchy |
| ProjectDetailView | UPDATED | Show folders instead of details form |
| ProjectInfoSheet | NEW | Modal for project details |
| AddProjectSheet | UPDATED | Calls template service |
| ContentView | UPDATED | Improved state management |
| Tests | +21 tests | All Phase 002 features |
| Models | None | Reuse existing models |
| Services | None | Reuse validation logic |

---

## Key Metrics

- **Lines of Code**: ~2,500 (Phase 001) + ~1,500 (Phase 002) = ~4,000
- **Test Coverage**: 66 tests, ~95% code coverage
- **Build Time**: ~15-30 seconds
- **Test Time**: ~10-15 seconds
- **App Size**: ~5MB
- **CloudKit Support**: ✅ All entities

---

## Feature 017: Search and Replace (In-Editor)

**Status**: ✅ Phase 1 Complete | **Commits**: 5a88cef, 7bd2a57, 3687634, ce0e9e8, a431d77

### Quick Start

1. **Open Search**: Press `⌘F` or click magnifying glass button in toolbar
2. **Type Search**: Enter text in search field (auto-searches with 300ms debounce)
3. **Navigate**: Use `⌘G` (next) / `⌘⇧G` (previous) or chevron buttons
4. **Replace**: Click chevron to expand replace mode, enter text, click Replace/Replace All
5. **Close**: Press `⎋` (Escape) or click X button

### Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| ⌘F | Open/close search bar |
| ⌘G | Next match |
| ⌘⇧G | Previous match |
| ⎋ | Close search bar |
| ⏎ | Next match (or replace if in replace mode) |
| ⇧⏎ | Previous match |

### Search Options

| Option | Icon | What It Does |
|--------|------|-------------|
| **Case Sensitive** | Aa | Match exact case (A ≠ a) |
| **Whole Word** | ⌶ | Match complete words only |
| **Regular Expression** | .* | Use regex patterns |

### Features

- ✅ **Real-time highlighting**: All matches in yellow, current in orange
- ✅ **Auto-scroll**: Current match automatically visible
- ✅ **Circular navigation**: Previous from first → last, next from last → first
- ✅ **Match counter**: Shows "3 of 12" or "No results"
- ✅ **Debounced search**: 300ms delay prevents lag while typing
- ✅ **Regex support**: Validate patterns, show errors, support capture groups
- ✅ **Replace with undo**: All replacements support undo/redo
- ✅ **Replace all**: Batch replace with count feedback

### Architecture

```
Data Layer
├── SearchQuery (search text, options, scope)
├── SearchMatch (range, context, line number)
└── SearchOptions (persistent preferences)

Service Layer
├── TextSearchEngine (search algorithms)
└── InEditorSearchManager (state & UI integration)

UI Layer
├── InEditorSearchBar (SwiftUI view)
└── FileEditView (integration)
```

### Code Locations

| Component | File | Lines |
|-----------|------|-------|
| Data Models | Services/SearchQuery.swift | 62 |
| | Services/SearchMatch.swift | 72 |
| | Services/SearchOptions.swift | 105 |
| Search Engine | Services/TextSearchEngine.swift | 270 |
| Search Manager | Services/InEditorSearchManager.swift | 320 |
| Search Bar UI | Views/InEditorSearchBar.swift | 393 |
| Integration | Views/FileEditView.swift | +32 |

### Test Coverage

- ✅ **Data Models**: 23 tests (SearchDataModelTests.swift)
- ✅ **Search Engine**: 46 tests (TextSearchEngineTests.swift)
- ✅ **Search Manager**: 19 tests (InEditorSearchManagerTests.swift)
- ✅ **Total**: 88 tests with >95% coverage

### What's NOT Included (Future Phases)

- ❌ Project-wide search (Phase 2)
- ❌ Collection-scoped search (Phase 2)
- ❌ Multi-file replace (Phase 3)
- ❌ Search results panel (Phase 3)
- ❌ Advanced regex features (Phase 4)

---

## What's NOT Included (Other Features)

- ❌ Export/import (Future)
- ❌ File sharing (Future)

---

## Next Phase: Phase 003

```
Goals:
├── Rich text editing in files
├── Auto-save on every keystroke
├── Content sync via CloudKit
└── Word count display

Estimated: 2 weeks
Tests: ~15-20 new tests
```

---

## Troubleshooting Checklist

- [ ] Did you commit to git? → `git log` shows b8a46c2
- [ ] Does it build? → `⌘+B` succeeds
- [ ] Do tests pass? → `⌘+U` shows 66/66 ✅
- [ ] Does app run? → `⌘+R` launches on simulator
- [ ] Can you create project? → "+" button works
- [ ] Do folders appear? → 3 root folders visible
- [ ] Can you navigate? → Tap folder goes inside
- [ ] Does CloudKit work? → Changes sync across devices

---

## Documentation to Read

1. **IMPLEMENTATION_GUIDE.md** (Start here for details)
2. **specs/001-project-management-ios-macos/spec.md** (Phase 001 requirements)
3. **specs/002-folder-file-management/spec.md** (Phase 002 requirements)
4. **specs/002-folder-file-management/plan.md** (Architecture decisions)
5. **specs/002-folder-file-management/data-model.md** (Data structure)

---

## Support

| Question | Answer | Location |
|----------|--------|----------|
| How do I run this? | `git clone` + `⌘+R` in Xcode | REPLAY_CHECKLIST.md |
| How was it built? | Follow the specs and plan | specs/ folder |
| What are the decisions? | Read the plan documents | specs/*/plan.md |
| How do I test it? | `⌘+U` in Xcode | All tests passing |
| How do I extend it? | Add to specs, follow TDD | IMPLEMENTATION_GUIDE.md |

---

**Status**: ✅ Complete and Tested  
**Commit**: b8a46c2  
**Next**: Phase 003 (Text Editing)  

🎉 Ready to build Phase 003?
