# WSP Reader

A free, standalone iOS/macOS app that opens and displays WSP documents in read-only mode.

## Overview

WSP Reader enables document sharing with non-WSP users and serves as a marketing funnel to the full Writing Shed Pro app. It's part of Feature 026.

## Features

- **Open WSP Files**: Register as handler for `.wsp` files
- **Document Display**: Render all WSP text formatting accurately (RTF support)
- **Project Navigation**: Display project's folder/file structure
- **Manual Project TOC**: Special table of contents navigation for Manual projects
- **Hyperlink Support**: Clickable external links
- **Font Size Controls**: Accessibility adjustments (12-32pt)
- **Light/Dark Mode**: Full theme support
- **Document Search**: Search across all files with context snippets
- **Document Info**: View project statistics and metadata
- **Recent Documents**: Track recently opened files with security-scoped bookmarks
- **Drag and Drop**: Drop .wsp files directly on macOS
- **Comments/Footnotes**: Display-only viewing

## What's NOT Included

The Reader is intentionally limited:

- ❌ Text editing (core differentiator)
- ❌ SwiftData/CloudKit (not needed - opens files directly)
- ❌ Project creation
- ❌ File management
- ❌ Formatting toolbar
- ❌ Comments/Footnote editing (display only)
- ❌ Submissions tracking

## Project Structure

```
WSPReader/
├── WSPReaderApp.swift          # App entry point with @Observable state
├── Info.plist                  # App configuration and UTI
├── WSPReader.entitlements      # Sandbox permissions
├── Assets.xcassets/            # App icons and colors
├── Models/
│   ├── WSPDocument.swift       # Document parser and model
│   └── WSPDataModels.swift     # Shared data structures (Codable)
└── Views/
    ├── ContentView.swift       # Main app view with file import/drop
    ├── DocumentReaderView.swift # Split view navigation
    ├── FileReaderView.swift    # Single file display with formatting
    ├── SearchView.swift        # Document-wide search
    ├── ManualNavigationView.swift # Manual project TOC
    ├── DocumentInfoView.swift  # Project metadata and stats
    ├── EditingBlockedView.swift # Upgrade prompt when user tries to edit
    └── ReaderSettingsView.swift # Settings screen
```

## Adding to Xcode Project

1. In Xcode, select File → New → Target
2. Choose "App" under iOS
3. Name it "WSPReader"
4. Set Bundle Identifier: `com.appworks.wspreader`
5. Add all files from the WSPReader folder to the new target
6. Configure signing for the new target

## Build Settings

- **Deployment Target**: iOS 17.0 / macOS 14.0
- **Supports**: iPhone, iPad, Mac Catalyst
- **App Category**: Productivity

## App Store Details

### Name
WSP Reader

### Description
WSP Reader lets you read and enjoy documents created with Writing Shed Pro - the professional writing app for authors.

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

### Keywords
WSP, writing, manuscript, reader, document viewer, ebook, author

### Privacy
- Data not collected
- No account required
- Recent documents stored locally only

## Future Enhancements

- PDF export (sharing further)
- Printing support
- Multiple open documents (tabs/windows on macOS)
- Search highlighting in content
