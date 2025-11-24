# Feature 019: Settings Menu & Smart Import

## Overview
Replace the stylesheet editor button with a comprehensive Settings menu (gear icon). Consolidate scattered settings into one location and add intelligent legacy database import detection.

## Requirements

### 1. Settings Menu Structure

**Location:** Left side of Projects screen toolbar (replacing current stylesheet button)

**Icon:** `gear` or `gearshape`

**Menu Items:**
1. About Writing Shed Pro
2. Stylesheet Editor
3. Page Setup
4. Import
5. Contact Support

### 2. Page Setup Refactoring

**Current State:**
- Available per-project in ProjectItemView ellipsis menu
- Each project can have different page setup

**New State:**
- Remove from ProjectItemView ellipsis menu
- Move to Settings menu as global setting
- **Question to resolve:** Should this be:
  - A. Global default that new projects inherit?
  - B. Global setting applied to all projects?
  - C. Global UI that lets user select which project to configure?

**Recommendation:** Option A - Global default for new projects, existing projects keep their settings.

### 3. Smart Import System

#### 3.1 Current Toolbar State
**Remove:**
- Import button from main toolbar (iOS/Mac)
- Legacy import button from Mac toolbar

**Replace with:** Settings > Import (with intelligent behavior)

#### 3.2 Import Logic Flow

```
User taps Settings > Import
    ↓
Check for legacy database existence
    ↓
    ├─ NO LEGACY DATABASE
    │   └─> Show file picker (current import behavior)
    │
    └─ LEGACY DATABASE EXISTS
        ↓
        Query legacy projects
        ↓
        Compare with SwiftData projects (by name/ID?)
        ↓
        Filter out already-imported projects
        ↓
        ├─ NO NEW PROJECTS TO IMPORT
        │   └─> Show file picker (current import behavior)
        │
        └─ HAS PROJECTS TO IMPORT
            ↓
            Show submenu:
            ├─ "Import from File..."
            └─ "Import from Writing Shed..." 
                ↓
                Show multi-select list of legacy projects
                ↓
                User selects projects
                ↓
                Import selected projects
```

#### 3.3 Legacy Project Detection

**Key Questions:**
1. How to identify if a project has already been imported?
   - Option A: Add `legacyDatabaseID` field to SwiftData Project
   - Option B: Match by name (fragile)
   - Option C: Create import tracking table

2. Where is legacy database located?
   - Mac: Standard location?
   - iOS: Not applicable (legacy was Mac-only)?

3. What legacy database format?
   - CoreData?
   - SQLite?
   - Other?

#### 3.4 Multi-Select Import UI

**Sheet/View:**
- NavigationStack with List
- Checkboxes for each unimported project
- Show project name and type
- "Import Selected" button (disabled if none selected)
- "Cancel" button

**After Import:**
- Show progress for multi-project import
- Use existing ImportProgressBanner
- Dismiss sheet when complete

### 4. Menu Items Implementation Details

#### 4.1 About Writing Shed Pro
- Show sheet with:
  - App name and icon
  - Version number
  - Copyright info
  - Link to website (if applicable)
- Initially can be a simple placeholder

#### 4.2 Stylesheet Editor
- Open existing StyleSheetListView
- No changes to functionality

#### 4.3 Page Setup
- Open existing PageSetupForm
- **Key Question:** Which project's settings to show?
  - Option A: Create "Default Page Setup" that's template for new projects
  - Option B: Let user select project from picker first
  - Option C: Show global settings that apply to all

**Recommendation:** Option A with separate PageSetup model for defaults

#### 4.4 Import
- Implement smart import logic as described above

#### 4.5 Contact Support
- Open mail composer or show contact options
- Can be simple placeholder initially

## Technical Design

### 4.1 New Models

```swift
// Option: Track legacy imports
@Model
class LegacyImportRecord {
    var legacyProjectID: String
    var legacyProjectName: String
    var importedDate: Date
    var swiftDataProject: Project?
}

// Option: Default page setup
@Model
class DefaultPageSetup {
    var pageWidth: Double = 8.5
    var pageHeight: Double = 11.0
    // ... other page setup fields
}
```

### 4.2 New Services

```swift
class LegacyDatabaseService {
    static func databaseExists() -> Bool
    static func getUnimportedProjects(context: ModelContext) -> [LegacyProject]
    static func importProjects(_ projects: [LegacyProject], context: ModelContext) async throws
}
```

### 4.3 New Views

```swift
// Settings menu in ContentView toolbar
Menu {
    Button("About Writing Shed Pro") { ... }
    Button("Stylesheet Editor") { ... }
    Button("Page Setup") { ... }
    Button("Import") { ... }
    Button("Contact Support") { ... }
} label: {
    Image(systemName: "gearshape")
}

// Legacy project picker
struct LegacyProjectPickerView: View {
    let projects: [LegacyProject]
    @State private var selectedProjects: Set<String> = []
    let onImport: ([LegacyProject]) -> Void
}
```

## Implementation Plan

### Phase 1: Basic Settings Menu (No Import Changes)
1. Add Settings menu to ContentView toolbar
2. Remove stylesheet button
3. Add "About" placeholder sheet
4. Hook up existing StyleSheetListView
5. Add "Contact Support" placeholder
6. Leave Import as simple file picker for now

### Phase 2: Page Setup Refactoring
1. Decide on global vs per-project approach
2. If global default: Create DefaultPageSetup model
3. Remove Page Setup from ProjectItemView menu
4. Add to Settings menu
5. Update Project creation to use default settings

### Phase 3: Legacy Database Detection
1. Add LegacyImportRecord model (if needed)
2. Implement LegacyDatabaseService.databaseExists()
3. Implement LegacyDatabaseService.getUnimportedProjects()
4. Add project comparison logic

### Phase 4: Smart Import UI
1. Create LegacyProjectPickerView
2. Update Import menu item to show submenu when legacy projects exist
3. Wire up multi-select import
4. Test import flow

### Phase 5: Cleanup & Polish
1. Remove old import buttons from toolbar
2. Test all Settings menu items
3. Update accessibility labels
4. Localize new strings

## Questions to Resolve

1. **Page Setup Scope:**
   - Should it be a global default or applied to all projects?
   
2. **Legacy Database Location:**
   - Where is the Mac legacy database stored?
   - How to access it from iOS (or is it Mac-only)?

3. **Import Tracking:**
   - Best way to track which legacy projects are already imported?
   - Add field to Project model or separate tracking table?

4. **Legacy Database Format:**
   - What format is the legacy database?
   - Do we have existing import code to reference?

5. **Multi-Project Import:**
   - Import sequentially or in parallel?
   - Show combined progress or per-project?

## Testing Checklist

- [ ] Settings menu appears on Projects screen
- [ ] All menu items are accessible
- [ ] Stylesheet editor opens correctly
- [ ] Page Setup works (after refactoring)
- [ ] Import detects legacy database correctly
- [ ] Import shows correct menu options based on detection
- [ ] Legacy project list shows only unimported projects
- [ ] Multi-select import works correctly
- [ ] File import still works as fallback
- [ ] Progress tracking works for multi-project import
- [ ] About and Contact Support display properly
- [ ] Mac and iOS both work correctly
- [ ] Toolbar layout looks good on both platforms

## Future Enhancements

- Add more settings (app preferences, default text formatting, etc.)
- Cloud sync settings
- Export settings
- Backup/restore functionality
- App theme selection
