# Writing Shed Pro - Development Guidelines

Last updated: 16 November 2025

## Active Feature
- Feature 014: TextKit 2 Migration (Specification complete, ready to implement)

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

**CRITICAL: Correct Localization Patterns**

```swift
// ✅ CORRECT: SwiftUI views with LocalizedStringKey (simple string literal)
Text("publications.title")
Button("button.cancel") { }
Label("publications.button.add", systemImage: "plus")
.navigationTitle("publications.detail.title")
LabeledContent("publications.form.name.label") { }

// ✅ CORRECT: Enum properties and formatted strings with NSLocalizedString
var displayName: String {
    return NSLocalizedString("publications.type.magazine", comment: "Magazine")
}
Text(String(format: NSLocalizedString("submissions.files.count", comment: "Files"), count))

// ❌ WRONG: NSLocalizedString in SwiftUI view initializers
Text(NSLocalizedString("publications.title", comment: ""))  // Shows as literal key!
Button(NSLocalizedString("button.cancel", comment: "")) { } // Shows as literal key!
LabeledContent(NSLocalizedString("label", comment: "")) { } // Shows as literal key!

// ❌ WRONG: Hard-coded English strings
Text("Publications")  // Not localized!
```

**The Rule:**
- SwiftUI views (Text, Button, Label, etc.): Use simple string literals → LocalizedStringKey
- Enum properties, String variables: Use NSLocalizedString()
- String(format:) with parameters: Use NSLocalizedString()

**IMPORTANT:** All localized strings must be in `Resources/en.lproj/Localizable.strings`
- Never create multiple Localizable.strings files
- Single source of truth for all localizations

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

### Text Editing Architecture
**Current State**: Migrating from TextKit 1 to TextKit 2
- Text editor: `FormattedTextEditor.swift` (UIViewRepresentable wrapper)
- During migration: Use `textView.textLayoutManager` (TextKit 2) not `textView.layoutManager` (TextKit 1)
- Storage: NSAttributedString serialized to RTF (unchanged)
- Images: Custom ImageAttachment with inline positioning

### SwiftUI Previews
❌ **DO NOT add #Preview code blocks**
- User does not use SwiftUI previews
- Previews cause maintenance overhead with model changes
- Test views by running the app instead

### Code Quality
- No force unwraps (use guard/if let)
- Handle all error cases
- Use proper Swift naming conventions
- Add documentation comments for public APIs
- Keep view files focused (extract components)

## Feature 014: TextKit 2 Migration

### Status
📋 Specification complete - ready to implement
🎯 Foundation for future comments feature

### Overview
Migrate text editing from TextKit 1 to TextKit 2 for:
- Future-proofing (TextKit 2 is the modern standard)
- Enable comments/annotations feature
- Better performance and correctness
- Modern text layout APIs

### Implementation Plan
6 phases, ~15 hours estimated (2 work days):
1. **Setup** (1-2h): Enable TextKit 2, add helper utilities
2. **Layout** (2-3h): Replace NSLayoutManager with NSTextLayoutManager
3. **Images** (2-3h): Fix attachment positioning with TextKit 2
4. **Selection** (1-2h): Verify cursor and selection handling
5. **Storage** (1-2h): Verify text modification operations
6. **Testing** (2-3h): Comprehensive testing and refinement

### Key Files
- `FormattedTextEditor.swift` - Main text view (35 references to update)
- `TextLayoutManagerExtensions.swift` - New helper utilities (to create)
- `FileEditView.swift` - No changes needed (uses FormattedTextEditor)
- Data models - No changes needed (storage format unchanged)

### Critical Patterns

**✅ DO use TextKit 2:**
```swift
if let textLayoutManager = textView.textLayoutManager {
    textLayoutManager.ensureLayout(for: documentRange)
}
```

**❌ DON'T use TextKit 1:**
```swift
textView.layoutManager.ensureLayout(for: textView.textContainer) // Old!
```

### Resources
- Spec: `specs/014-textkit2-migration/spec.md`
- Plan: `specs/014-textkit2-migration/plan.md`
- Quick Reference: `specs/014-textkit2-migration/quickstart.md`

## Feature 008b: Publication Management (Deferred)

### Status
Phase 3 complete, deferred pending user requirements

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
- [ ] No #Preview code blocks added

<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->
