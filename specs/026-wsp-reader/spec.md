# Feature 026: WSP Reader App

**Status**: Complete  
**Priority**: Medium  
**Estimated Effort**: TBD  
**Dependencies**: 024-hyperlinks, 025-manual-project-type  
**Created**: 2026-01-10
**Implementation**: 2026-01-24 - All code complete in WrtingShedPro/WSPReader/

## Overview

Create a free, standalone iOS/macOS app that can open and display WSP documents in read-only mode. This enables document sharing with non-WSP users and serves as a marketing funnel to the full Writing Shed Pro app.

## Strategic Goals

1. **Document Sharing**: Writers can share work with editors, beta readers, publishers
2. **Format Adoption**: More people using .wsp files increases format value
3. **Marketing Funnel**: Free app exposes users to WSP quality → upgrade path to Pro
4. **Manual Distribution**: Primary way to distribute WSP user manual

## Requirements

### 1. App Identity

#### 1.1 App Details
- **Name**: WSP Reader (or "Writing Shed Reader"?)
- **Bundle ID**: `com.yourcompany.wspreader`
- **Price**: Free
- **Platforms**: iOS 17+, macOS 14+ (Catalyst or native)
- **App Store Category**: Productivity or Books

#### 1.2 Branding
- Related but distinct from Writing Shed Pro
- Simpler icon (emphasize "reading" - book/document imagery)
- Consistent color scheme with Pro app

### 2. Core Functionality

#### 2.1 Open WSP Files
- Register as handler for `.wsp` files
- Open from Files app, Mail, Safari downloads, AirDrop
- Support Open In / Share Sheet integration

#### 2.2 Document Display
- Render all WSP text formatting accurately
- Display images embedded in documents
- Support all text styles (bold, italic, headings, etc.)
- Pagination display (page breaks, headers/footers)
- Footnotes display

#### 2.3 Project Structure Navigation
- Display project's folder/file structure
- Navigate between files in project
- Manual project type: Full TOC navigation (per 025)

#### 2.4 Hyperlink Support
- Clickable external links (open in browser)
- Clickable internal links (navigate within document)
- Cross-file links navigate between project files

### 3. What's NOT Included

The Reader is intentionally limited:

| Feature | Included? | Notes |
|---------|-----------|-------|
| Text editing | ❌ | Core differentiator |
| SwiftData/CloudKit | ❌ | Not needed - opens files directly |
| Project creation | ❌ | Read-only |
| File management | ❌ | Just opens, doesn't organize |
| Export to other formats | ❌ | (Consider: allow PDF export?) |
| Formatting toolbar | ❌ | No editing |
| Comments/Footnote editing | ❌ | Display only |
| Submissions tracking | ❌ | Pro feature |
| Collections | ❌ | Pro feature |

### 4. User Interface

#### 4.1 Document Picker / Home Screen
Simple launch experience:
- "Open Document" button
- Recent documents list
- Drag-and-drop zone (macOS)

```
┌─────────────────────────────────────┐
│         WSP Reader                  │
├─────────────────────────────────────┤
│                                     │
│        📄                           │
│   [Open WSP Document]               │
│                                     │
│   ─────── Recent ───────            │
│                                     │
│   📘 My Novel Draft                 │
│      Opened yesterday               │
│                                     │
│   📗 Writing Shed Manual            │
│      Opened 3 days ago              │
│                                     │
│   📕 Short Story Collection         │
│      Opened last week               │
│                                     │
├─────────────────────────────────────┤
│   Get Writing Shed Pro →            │
└─────────────────────────────────────┘
```

#### 4.2 Document Reading View

**Standard Documents**:
- Clean reading layout
- File list sidebar (collapsible)
- Current file content
- Previous/Next navigation

**Manual Projects**:
- TOC sidebar (per 025-manual-project-type)
- Chapter navigation
- Breadcrumb trail

#### 4.3 Reading Controls
- Font size adjustment (accessibility)
- Light/Dark mode support
- Full-screen reading mode
- Search within document

### 5. File Handling

#### 5.1 File Association
Register for `.wsp` UTI:
```xml
<key>CFBundleDocumentTypes</key>
<array>
    <dict>
        <key>CFBundleTypeName</key>
        <string>WSP Document</string>
        <key>LSHandlerRank</key>
        <string>Alternate</string>  <!-- Pro is Owner -->
        <key>CFBundleTypeExtensions</key>
        <array>
            <string>wsp</string>
        </array>
    </dict>
</array>
```

#### 5.2 Recent Documents
- Store recently opened file references
- Use security-scoped bookmarks for persistent access
- Clear recent documents option

#### 5.3 Opening Flow
```
File tap/open
    ↓
Parse .wsp file
    ↓
Load project structure
    ↓
├── Standard Project → Show file list + first file
└── Manual Project → Show TOC + first chapter
```

### 6. Marketing Integration

#### 6.1 Upgrade Prompts
Subtle, non-aggressive prompts to upgrade:
- Footer link: "Get Writing Shed Pro"
- When attempting to edit: "Editing requires Writing Shed Pro"
- About screen: "WSP Reader is part of the Writing Shed family"

#### 6.2 App Store Link
- Deep link to Writing Shed Pro in App Store
- Track conversion if possible (SKStoreProductViewController)

### 7. Code Sharing Strategy

#### 7.1 Shared Components
Extract from main WSP codebase:
- `.wsp` file parser
- Text rendering views
- Pagination engine
- Stylesheet system
- Image handling

#### 7.2 Separate Targets
- Shared framework/package for common code
- WSP Pro target (full app)
- WSP Reader target (read-only app)

#### 7.3 Conditional Compilation
```swift
#if WSP_READER
    // Read-only functionality
#else
    // Full editing functionality
#endif
```

### 8. Distribution

#### 8.1 App Store
- Submit as separate app
- Free, no IAP needed
- Family Sharing enabled
- Privacy policy (minimal data collection)

#### 8.2 Version Alignment
- Keep Reader compatible with Pro's .wsp format
- Version Reader alongside Pro releases
- Backward compatibility for older .wsp files

## Implementation Notes

### Phase 1: Project Setup
1. Create new target in Xcode project
2. Extract shared code into framework
3. Basic app shell (icon, launch screen)

### Phase 2: Core Viewing
1. File picker implementation
2. .wsp parsing (use existing code)
3. Basic document rendering
4. Project structure navigation

### Phase 3: Enhanced Display
1. Manual project detection
2. TOC navigation
3. Hyperlink handling
4. Search functionality

### Phase 4: Polish
1. Recent documents
2. Font size controls
3. Upgrade prompts
4. App Store preparation

### Phase 5: Release
1. App Store screenshots/preview
2. App Store description
3. Privacy policy
4. Submit for review

## App Store Assets

### App Description (Draft)
```
WSP Reader lets you read and enjoy documents created with 
Writing Shed Pro - the professional writing app for authors.

Perfect for:
• Reading manuscripts shared by writers
• Viewing the Writing Shed Pro manual
• Previewing .wsp documents before editing

Features:
• Beautiful, distraction-free reading experience
• Navigate complex documents with ease
• Support for all WSP formatting
• Clickable links and cross-references
• Works with all .wsp files

WSP Reader is free and works with any .wsp document.
To create and edit documents, get Writing Shed Pro.
```

### Keywords
- WSP, writing, manuscript, reader, document viewer, ebook, author

## Open Questions

1. Should Reader support PDF export? (Useful for sharing further)
2. Should Reader support printing?
3. How to handle WSP files with features Reader doesn't support (future-proofing)?
4. Should bundled manual be included in Reader or downloaded separately?
5. macOS: Catalyst or native SwiftUI? (Catalyst easier for code sharing)
6. Should Reader support multiple open documents? (Tabs/windows)

## Privacy & Data

### Data Collection
- Minimal or none
- No account required
- Recent documents stored locally only
- No analytics (or minimal, anonymized)

### App Privacy (App Store)
- Data not collected category
- Or: "Data not linked to you" for basic analytics

## Success Metrics

1. Download numbers
2. Conversion rate to Pro (track "Get Pro" taps)
3. App Store rating
4. Support requests (should be minimal)
