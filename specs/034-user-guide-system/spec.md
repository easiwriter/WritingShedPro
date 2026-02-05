# Feature 034: User Guide System

**Status:** Planning  
**Branch:** TBD  
**Date:** 2026-02-05  
**Priority:** Pre-release (required before v1.0)

## Overview

The User Guide System provides an in-app user manual that users can read, annotate, and customize. The guide is bundled with the app and stored in the database for user access. Users can add their own notes to the guide, and when a new version of the guide is released with an app update, users have control over whether to update (preserving their annotated version as a separate project).

---

## Requirements

### Functional Requirements

#### FR-1: Guide Storage and Loading
- [ ] FR-1.1: Guide content is bundled with the app as a `.wsp` export file
- [ ] FR-1.2: On first launch, import guide into database as a Prose project named "Writing Shed Pro Guide"
- [ ] FR-1.3: Store guide version number in UserDefaults (e.g., `userGuideVersion`)
- [ ] FR-1.4: Guide files are markdown format (`contentType = .markdown`)
- [ ] FR-1.5: Guide project is read-only by default (no editing)

#### FR-2: Opening the Guide
- [ ] FR-2.1: Help menu contains "Writing Shed Pro Guide" command
- [ ] FR-2.2: Command opens the guide project from database
- [ ] FR-2.3: Guide opens in normal project view with folder/file navigation
- [ ] FR-2.4: Files display in markdown preview mode (not edit mode)
- [ ] FR-2.5: Internal links between guide sections work correctly

#### FR-3: User Customization
- [ ] FR-3.1: Settings/Help menu contains "Edit Guide" or "Add Notes to Guide" command
- [ ] FR-3.2: When enabled, guide project becomes editable
- [ ] FR-3.3: User can add text, comments, and annotations
- [ ] FR-3.4: User changes persist in database
- [ ] FR-3.5: "Save Guide Changes" command saves customizations (or auto-save)

#### FR-4: Version Management
- [ ] FR-4.1: Each bundled guide has a version number (e.g., "1.0", "1.1")
- [ ] FR-4.2: On app launch, compare bundled version with stored version
- [ ] FR-4.3: If bundled version is newer, show update alert (only if user has customizations)
- [ ] FR-4.4: Alert: "A new version of the User Guide is available. Your current guide may have customizations. Update now? Your current guide will be renamed so you can reference it."
- [ ] FR-4.5: If user accepts update:
  - Rename existing guide project (e.g., "Writing Shed Pro Guide (v1.0 - My Notes)")
  - Import new bundled guide as "Writing Shed Pro Guide"
  - Update stored version number
- [ ] FR-4.6: If user declines, don't ask again until next app version with newer guide
- [ ] FR-4.7: If user has made NO customizations, update silently (replace in place)

#### FR-5: Manual Guide Reset
- [ ] FR-5.1: Settings/Help menu contains "Reset Guide to Default" command
- [ ] FR-5.2: Confirmation dialog warns about losing customizations
- [ ] FR-5.3: Deletes current guide project and reimports from bundle
- [ ] FR-5.4: Resets stored version to bundled version

### Non-Functional Requirements

#### NFR-1: Performance
- [ ] NFR-1.1: Guide import on first launch completes within 3 seconds
- [ ] NFR-1.2: Opening guide project is as fast as opening any project

#### NFR-2: Storage
- [ ] NFR-2.1: Guide uses standard SwiftData models (Project, Folder, TextFile, Version)
- [ ] NFR-2.2: No special database schema required
- [ ] NFR-2.3: Guide syncs via CloudKit like other projects

#### NFR-3: Maintenance
- [ ] NFR-3.1: Guide content is maintained as markdown files in `docs/wsp-guide/`
- [ ] NFR-3.2: Build process exports markdown to `.wsp` bundle for inclusion
- [ ] NFR-3.3: Version number is defined in a single location (easy to bump)

---

## Data Model

### UserDefaults Keys
```swift
// Version of the guide currently stored in database
static let userGuideStoredVersion = "userGuideStoredVersion"

// Whether user has customized the guide (triggers update confirmation)
static let userGuideHasCustomizations = "userGuideHasCustomizations"

// User declined update for this version (don't ask again)
static let userGuideDeclinedVersion = "userGuideDeclinedVersion"
```

### Constants
```swift
struct UserGuideConstants {
    /// Current bundled guide version - bump when guide content changes
    static let bundledVersion = "1.0"
    
    /// Project name for the guide in database
    static let projectName = "Writing Shed Pro Guide"
    
    /// Bundle resource name for the guide .wsp file
    static let bundleResourceName = "Writing Shed Pro Guide"
    static let bundleResourceExtension = "wsp"
}
```

---

## User Flows

### First Launch Flow
```
1. App launches
2. Check: Does "Writing Shed Pro Guide" project exist in database?
3. NO → Import guide from bundle
   - Load .wsp from app bundle
   - Import as Prose project
   - Set all files to markdown contentType
   - Store version in UserDefaults
4. YES → Check version (see Update Flow)
```

### Opening Guide Flow
```
1. User selects Help → Writing Shed Pro Guide
2. Find guide project in database
3. Open project in ProjectView
4. Files open in markdown preview mode
```

### Edit Guide Flow
```
1. User selects Help → Add Notes to Guide
2. Set userGuideHasCustomizations = true
3. Guide project switches to edit mode
4. User makes changes
5. Changes auto-save to database
```

### Update Available Flow
```
1. App launches
2. Guide exists in database
3. Compare: bundledVersion > storedVersion?
4. YES and userGuideHasCustomizations == true:
   - Show alert with options
   - "Update" → Rename old, import new
   - "Not Now" → Set declinedVersion, skip
5. YES and userGuideHasCustomizations == false:
   - Delete existing guide
   - Import new guide silently
   - Update storedVersion
6. NO → No action needed
```

---

## UI Design

### Help Menu Items
```
Help
├── Writing Shed Pro Guide          ⌘?
├── ─────────────────────────────
├── Add Notes to Guide...
├── Reset Guide to Default...
├── ─────────────────────────────
├── Contact Support
└── About Writing Shed Pro
```

### Update Available Alert
```
┌─────────────────────────────────────────────────────┐
│                                                     │
│  📖 User Guide Update Available                     │
│                                                     │
│  A new version of the Writing Shed Pro Guide is    │
│  available. Your current guide has customizations. │
│                                                     │
│  If you update, your customized guide will be      │
│  renamed "Writing Shed Pro Guide (My Notes)" so    │
│  you can reference your changes.                   │
│                                                     │
│           [ Not Now ]        [ Update ]            │
│                                                     │
└─────────────────────────────────────────────────────┘
```

### Reset Confirmation Alert
```
┌─────────────────────────────────────────────────────┐
│                                                     │
│  ⚠️ Reset User Guide?                               │
│                                                     │
│  This will delete your current guide including     │
│  any notes you've added, and restore the default   │
│  guide from the app.                               │
│                                                     │
│  This cannot be undone.                            │
│                                                     │
│           [ Cancel ]        [ Reset ]              │
│                                                     │
└─────────────────────────────────────────────────────┘
```

---

## Implementation Phases

### Phase 1: Basic Guide System
- Bundle guide as .wsp file
- Import on first launch
- Help menu command to open guide
- Store and check version

### Phase 2: User Customization
- Edit mode toggle
- Track customization state
- Update alert with rename option

### Phase 3: Polish
- Reset to default command
- Keyboard shortcuts
- Guide-specific UI tweaks (if needed)

---

## Testing Requirements

### Unit Tests
- [ ] Version comparison logic
- [ ] Project rename logic
- [ ] Customization detection

### Integration Tests  
- [ ] First launch import
- [ ] Guide opens correctly
- [ ] Update flow with customizations
- [ ] Update flow without customizations
- [ ] Reset to default

### Manual Tests
- [ ] Fresh install imports guide
- [ ] Guide navigation works
- [ ] Edit mode allows changes
- [ ] Update renames old guide correctly
- [ ] CloudKit sync works for guide project

---

## Build Process

### Guide Bundle Creation
1. Markdown files maintained in `docs/wsp-guide/`
2. Build script converts markdown to .wsp format
3. .wsp file added to app bundle resources
4. Version number updated in `UserGuideConstants.swift`

### Version Bumping Checklist
1. Update guide content in `docs/wsp-guide/`
2. Run export script to generate new .wsp
3. Bump `UserGuideConstants.bundledVersion`
4. Test update flow on device with existing guide

---

## Future Considerations

- **Localization**: Multiple language guides with language-specific .wsp bundles
- **Searchable Index**: Full-text search across guide content
- **Deep Links**: URL scheme to open specific guide sections (e.g., `writingshed://guide/formatting`)
- **What's New**: Highlight new sections when guide updates
- **Diff View**: Show what changed between guide versions

---

## Related Documentation

- [User Guide Content](../../docs/wsp-guide/index.md)
- [Feature 028: Markdown Import](../028-markdown-import/spec.md)
- [Feature 009: Database Import](../009-database-import/spec.md)
