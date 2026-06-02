# Write Development Guidelines

Auto-generated from all feature plans. Last updated: 2025-10-20

## Active Technologies
- (001-project-management-ios-macos)
- Swift 5.0, targeting iOS 18.5+ / macOS 14.0+ + SwiftUI, SwiftData, CloudKit, Combine, NSPersistentCloudKitContainer (038-cloudkit-rate-limiting)
- SwiftData with CloudKit backend (SQLite at `URL.documentsDirectory/writingshed.sqlite`, container `iCloud.com.appworks.writingshedpro`) (038-cloudkit-rate-limiting)

## Project Structure
```
backend/
frontend/
tests/
```

## Commands
# Add commands for 

## Code Style
: Follow standard conventions
- **Do NOT create #Preview blocks** - Previews are not used in this project

## Swift Observation Framework
**CRITICAL: Always use @Observable, never @Published/ObservableObject**
- Use `@Observable` macro for all observable classes (Swift 5.9+)
- DO NOT use `@Published` properties or `ObservableObject` protocol
- `@Observable` provides fine-grained observation - only updates views using changed properties
- `@Published` causes ALL observing views to redraw on ANY property change (major performance issue)
- Example:
  ```swift
  import Observation
  
  @Observable
  class MyManager {
      var count: Int = 0  // Not @Published
      var name: String = ""
  }
  ```

## SwiftData + CloudKit Requirements
When creating SwiftData @Model classes with CloudKit integration:
- **All attributes must be optional OR have default values** (CloudKit requirement)
- **Do NOT use @Attribute(.unique)** - CloudKit does not support unique constraints
- Use optional properties (with `?`) or provide explicit default values in init
- Example: `var id: UUID = UUID()` or `var name: String?`

## CloudKit Sync: NEVER Delete Based on Missing Relationships
**CRITICAL: CloudKit syncs entities and relationships SEPARATELY**

This caused data loss on 2026-01-30. The MigrationService deleted folders that appeared "orphaned" (no project relationship) but were actually just waiting for CloudKit to sync the relationship.

**What happens with CloudKit sync:**
1. A `Folder` record syncs first with its properties (name, id, etc.)
2. The `project` relationship syncs LATER in a separate transaction
3. Between those moments: `folder.project == nil` even though it's NOT orphaned

**NEVER DO THIS:**
```swift
// ❌ DANGEROUS - will delete valid data during CloudKit sync
if folder.project == nil && folder.parentFolder == nil {
    context.delete(folder)  // WRONG!
}
```

**Rules for CloudKit-safe code:**
1. **Never delete records just because a relationship is nil** - it may sync later
2. **Never run cleanup/migration on app launch** - sync may be incomplete
3. **If cleanup is truly needed**, require explicit user action (button press), not automatic
4. **Log warnings instead of deleting** when relationships appear missing
5. **Consider a "grace period"** - only flag records as orphaned if they've been relationless for days, not seconds

**Safe alternative:**
```swift
// ✅ SAFE - just log, don't delete
if folder.project == nil && folder.parentFolder == nil {
    print("⚠️ Folder '\(folder.name)' has no relationships (may be syncing)")
    // DO NOT DELETE
}
```

## Recent Changes
- 038-cloudkit-rate-limiting: Added Swift 5.0, targeting iOS 18.5+ / macOS 14.0+ + SwiftUI, SwiftData, CloudKit, Combine, NSPersistentCloudKitContainer
- 001-project-management-ios-macos: Added
- 014-comments: SwiftData/CloudKit requirements documented

<!-- MANUAL ADDITIONS START -->

## Swift Memory Management: Structs vs Classes
**CRITICAL: Structs CANNOT use [weak self] in closures**
- SwiftUI Views are structs, not classes
- `[weak self]` is only valid for class and class-bound protocol types
- In struct closures (alert handlers, buttons, etc.), either:
  - Use direct `self` capture if scope is small/temporary (no retain cycle risk)
  - Extract logic into a separate method called without capture
  - Use captured properties instead of self
- When you see `'weak' may only be applied to class and class-bound protocol types, not 'YourViewName'`, it means YourViewName is a struct

## Localization: Always Add Strings to Localizable.strings
**CRITICAL: Every `NSLocalizedString` key MUST have a corresponding entry in `Localizable.strings`**
- Localizable.strings location: `WrtingShedPro/Writing Shed Pro/Resources/en.lproj/Localizable.strings`
- When adding new `NSLocalizedString("key", comment: "...")` calls in Swift code, **immediately** add a matching `"key" = "English text";` entry to the Localizable.strings file
- Before using a localization key, **grep the Localizable.strings file** to check if it already exists
- Use existing keys where possible (e.g. `common.cancel`, `common.done`, `fiction.untitled`)
- Group new keys under a `// MARK: -` comment section
- Keys that exist without a Localizable.strings entry will display the raw key text at runtime

## Git Media Policy
**CRITICAL: Do not commit MP4 files**
- Exclude all `.mp4` assets from git commits by default
- If a video must be shared, use external hosting or Git LFS instead of normal git
<!-- MANUAL ADDITIONS END -->
