# Writing Shed Pro - Development Guidelines

Last updated: 9 November 2025

## Active Feature
- Feature 008b: Publication Management System (Phase 1 complete)

## Project Structure
```
WrtingShedPro/
  Writing Shed Pro/
    Models/          # SwiftData models
    Views/           # SwiftUI views
    Services/        # Business logic services
    Extensions/      # Swift extensions
    Resources/       # Assets, localizations
specs/               # Feature specifications
  008b-publication-system/
    spec.md          # Main specification
    plan.md          # 15-phase implementation plan
    tasks.md         # Current phase tasks
    requirements-updates.md  # User requirements
    DEVELOPMENT_NOTES.md     # Critical standards
```

## Critical Development Standards

### iOS Version
⚠️ **ALWAYS use iOS 16+ simulators for testing**
- Do NOT use iOS 15 simulators
- Minimum deployment: iOS 16.0

### Localization (MANDATORY)
❌ NEVER use hard-coded user-facing strings
✅ ALWAYS use localized string keys

```swift
// ❌ WRONG
Text("Publications")

// ✅ CORRECT
Text("publications.title")
```

All user-facing text MUST be localized:
- Button labels
- Text views
- Alert messages
- Error messages
- Placeholders
- Accessibility labels

### Accessibility (MANDATORY)
ALL interactive elements MUST have accessibility support:

```swift
Button("Delete") { }
    .accessibilityLabel(Text("accessibility.delete.publication"))
    .accessibilityHint(Text("accessibility.delete.publication.hint"))
```

Requirements:
- All buttons need .accessibilityLabel()
- All custom views need .accessibilityElement()
- All icons need descriptive labels
- All status indicators must announce correctly
- Test with VoiceOver enabled

### SwiftData Models
- Use @Model macro
- Include createdDate and modifiedDate
- Define relationships explicitly
- Add computed properties for derived data
- Keep business logic in services, not models

### Code Quality
- No force unwraps (use guard/if let)
- Handle all error cases
- Use proper Swift naming conventions
- Add documentation comments for public APIs
- Keep view files focused (extract components)

## Feature 008b: Publication Management

### Completed (Phase 1)
✅ Data models (Publication, Submission, SubmittedFile)
✅ Enums (PublicationType, SubmissionStatus)
✅ Version locking infrastructure
✅ ReminderService (EventKit integration)
✅ SwiftData schema updates

### Next Phase (Phase 2)
- PublicationsListView
- PublicationFormView
- PublicationDetailView
- Deadline indicators

### Key Concepts
- Publications track magazines/competitions
- Submissions link publications to files with versions
- SubmittedFile is join table with status tracking
- Published folder is computed view (not physical)
- Version locking prevents editing submitted versions

## Commands
```bash
# Build project
xcodebuild -project "Writing Shed Pro.xcodeproj" -scheme "Writing Shed Pro" build

# Run tests
xcodebuild test -project "Writing Shed Pro.xcodeproj" -scheme "Writing Shed Pro" -destination 'platform=iOS Simulator,name=iPhone 15,OS=16.0'
```

## Code Review Checklist
Before any commit:
- [ ] No hard-coded strings (all localized)
- [ ] All interactive elements have accessibility
- [ ] Tested on iOS 16+ simulator
- [ ] No force unwraps
- [ ] Error handling complete
- [ ] VoiceOver tested (if UI changes)

<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->
