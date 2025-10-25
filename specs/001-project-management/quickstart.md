# Quickstart: Project Management (iOS/MacOS)

## Overview
Write! is a multiplatform project management app for writers, supporting prose, poetry, and drama projects with automatic CloudKit sync across iOS and macOS devices.

## Prerequisites
- Xcode 15+
- iOS 18.5+ or macOS 14+ (via MacCatalyst)
- Swift 5.9+
- iCloud account (for CloudKit sync)

## Setup
1. Clone the repository
2. Open `Write!.xcodeproj` in Xcode
3. Ensure CloudKit entitlements are enabled in project settings
4. Sign in with your Apple ID in Xcode (for CloudKit development)
5. Build and run on iOS simulator, Mac, or physical device

## Project Structure
```
Write!/
├── Write!/                    # Main app source
│   ├── Write_App.swift       # App entry point with ModelContainer
│   ├── BaseModels.swift      # SwiftData models (Project, Folder, File)
│   ├── ContentView.swift     # Main project list view
│   ├── AddProjectSheet.swift # Add new project form
│   ├── ProjectDetailView.swift # Edit/delete project view
│   ├── NameValidator.swift   # Validation logic
│   ├── UniquenessChecker.swift # Duplicate name checking
│   ├── ProjectSortService.swift # Sorting logic
│   └── Localizable.strings   # Localization strings
└── Write!Tests/              # Test suite
    ├── NameValidatorTests.swift
    ├── UniquenessCheckerTests.swift
    ├── ProjectSortServiceTests.swift
    ├── ProjectCreationIntegrationTests.swift
    ├── ProjectListDisplayIntegrationTests.swift
    ├── ProjectRenameDeleteTests.swift
    └── ProjectRenameDeleteIntegrationTests.swift
```

## Features

### ✅ Add Projects
1. Tap the **"+"** button in the top toolbar
2. Enter a project name (required, must be unique)
3. Select project type: Prose, Poetry, or Drama
4. Optionally add project details
5. Tap **"Add"** to create the project

**Validation:**
- Empty names are rejected
- Duplicate names show an error alert
- The Add button is disabled until a valid name is entered

### ✅ View Projects
- Projects appear in a scrollable list
- Each project shows its name and type
- Tap a project to view details

### ✅ Sort Projects
- Tap the sort button (⬍) in the toolbar
- Choose to sort by:
  - **Name** (alphabetically, case-insensitive)
  - **Creation Date** (oldest first)

### ✅ Edit Projects
1. Tap a project to open the detail view
2. Edit the project name inline (validated on change)
3. Edit project details in the text field
4. Changes save automatically

**Validation:**
- Empty names are rejected with an alert
- Original name is restored if validation fails

### ✅ Delete Projects
1. Swipe left on a project in the list, or
2. Tap a project → tap the trash icon in the toolbar
3. Confirm deletion in the alert dialog
4. Project is permanently deleted (cannot be undone)

**Note:** Deleting a project also deletes all associated folders and files (cascade delete).

### ✅ CloudKit Sync
- Projects automatically sync across all your devices
- Requires iCloud account and internet connection
- Changes appear within seconds on other devices
- Works seamlessly in the background

**Setup CloudKit:**
1. Enable iCloud in iOS Settings / System Preferences
2. Sign in with your Apple ID
3. Ensure iCloud Drive is enabled
4. Launch the app on multiple devices

## Testing

### Run Tests in Xcode
1. Open the project in Xcode
2. Press `⌘+U` to run all tests
3. View test results in the Test Navigator (⌘+6)

### Test Coverage
- **Unit Tests:** Validation, uniqueness checking, sorting logic
- **Integration Tests:** Project creation, list display, rename/delete workflows
- **All tests pass:** ✅ 45+ test cases

### Known Issues
- UI tests may not terminate when run from command line (use Xcode UI instead)

## Localization
- All user-facing text uses `NSLocalizedString()`
- Localization strings are in `Localizable.strings`
- Currently supports English (extensible to additional languages)

## Architecture
- **SwiftUI** for all UI components
- **SwiftData** for local persistence
- **CloudKit** for automatic sync (via ModelContainer configuration)
- **MVVM** pattern with service layer separation
- **TDD** approach with comprehensive test coverage

## Development Guidelines
1. All new features must have unit tests
2. All user-facing text must be localized
3. Follow existing naming conventions
4. Ensure CloudKit compatibility (optional properties, no unique constraints on primitives)
5. Run tests before committing changes

## Troubleshooting

### CloudKit Not Syncing
- Verify iCloud is enabled in device settings
- Check internet connection
- Ensure you're signed in with the same Apple ID on all devices
- Check Xcode capabilities for CloudKit entitlements

### Build Errors
- Clean build folder: `⌘+Shift+K`
- Delete derived data: `Xcode > Preferences > Locations > Derived Data`
- Restart Xcode

### Test Failures
- Ensure all dependencies are resolved
- Check that models conform to CloudKit requirements (optional relationships, default values)

## Next Steps
- Add folder and file management features
- Implement text editing capabilities
- Add export functionality
- Support additional languages
- Add dark mode customization

## Support
For issues or questions, refer to:
- `spec.md` for detailed requirements
- `plan.md` for architecture decisions
- `tasks.md` for implementation checklist

