# Phase 0 Baseline: Ensembles Sync Port

**Date**: 2026-07-03
**Status**: In progress
**Purpose**: Record the reversible starting point for the Ensembles port before replacing WSP's production sync engine.

## Reversibility Boundary

Phase 0 must remain easy to back out.

Current reversible changes are limited to:

1. Ensembles package/product wiring in the Xcode project.
2. `EnsemblesConfiguration` license activation helper.
3. A launch-time call to activate the Ensembles license.
4. A one-line schema registration for `SceneLocationLink.self`.
5. Spec and baseline documentation under `specs/042-ensembles-sync-port/`.

No production sync engine switch has been made in Phase 0. The main store still uses SwiftData with `cloudKitDatabase: .automatic` and the existing `NSPersistentCloudKitContainer` mirroring path.

To revert Phase 0 manually, restore the modified project/app files and remove the new spec folder. Do not delete user data stores as part of a code revert.

## Package State

Resolved package:

- `Ensembles3` 3.0.1
- Repository: `https://github.com/mentalfaculty/Ensembles3.git`
- Revision: `50ea0aa439800612873e638b1b17dca11b238598`

Linked products observed in the Xcode project:

- `Ensembles`
- `EnsemblesSwiftData`
- `EnsemblesCloudKit`

The activation key is intentionally not repeated in this document and must not be included in support diagnostics or logs.

## Current Sync Mode

Current production store configuration remains CloudKit mirroring:

- Store path: `URL.documentsDirectory.appending(path: "writingshed.sqlite")`
- Configuration name: `WritingShedProConfiguration`
- Sync mode: `cloudKitDatabase: .automatic`
- Legacy mirroring observers/recovery UI are still present.

CloudKit-specific code still to gate or retire in later phases:

- `NSPersistentCloudKitContainer.eventChangedNotification` observers.
- `CloudKitSyncThrottler` import/export mirroring state.
- Sync Diagnostics zone delete, reset database, force re-export, foreign-zone cleanup, and Core Data CloudKit metadata queries.
- AppDelegate remote-notification setup that exists specifically for mirroring subscriptions.

## SwiftData Model Inventory

Main app schema now explicitly registers these 42 synced candidates:

1. `Project`
2. `Folder`
3. `TextFile`
4. `Version`
5. `TrashItem`
6. `StyleSheet`
7. `TextStyleModel`
8. `PageSetup`
9. `PrinterPaper`
10. `Publication`
11. `Submission`
12. `SubmittedFile`
13. `CommentModel`
14. `FootnoteModel`
15. `PoetryFormModel`
16. `StoryScene`
17. `Chapter`
18. `Character`
19. `Location`
20. `CustomAttribute`
21. `PlotElement`
22. `Act`
23. `ProseSection`
24. `PoetryCollection`
25. `Book`
26. `TextFileSectionLink`
27. `TextFileCollectionLink`
28. `SceneChapterLink`
29. `SceneActLink`
30. `SceneBookLink`
31. `ScenePlotElementLink`
32. `SceneCharacterLink`
33. `CharacterPlotElementLink`
34. `LocationPlotElementLink`
35. `SceneLocationLink`
36. `NoteEntry`
37. `GlossaryEntry`
38. `ReferenceEntry`
39. `CitationEntry`
40. `IndexEntry`
41. `ContributorEntry`
42. `ImageStyle`

Note: the actual schema list contained 41 entries before `SceneLocationLink` was added and contains 42 entries after the Phase 0 correction.

## Unregistered `@Model` Classes

The model source also declares these unregistered `@Model` classes:

- `ManuscriptReview`
- `ReviewSuggestion`

Current evidence:

- `ManuscriptAnalystService` constructs `ManuscriptReview` and `ReviewSuggestion` values.
- No `modelContext.insert`, `FetchDescriptor<ManuscriptReview>`, or `@Query` usage was found for these classes in the main app source during Phase 0.
- `ManuscriptReview.reviewId` uses `@Attribute(.unique)`, which is acceptable only if the model is not part of the CloudKit-backed/synced store.

Phase 1 decision required:

- Keep analyst review models as transient/domain-only types, or
- Convert them to plain non-`@Model` classes/structs, or
- Register and persist them intentionally after removing CloudKit-incompatible uniqueness assumptions and defining stable identity.

## Schema Correction Applied

`SceneLocationLink` is a persisted join model referenced by `StoryScene.locationLinks` and `Location.sceneLinks`. It is also inserted when setting `StoryScene.locations`.

Phase 0 added `SceneLocationLink.self` to the main app schema because a persisted model reachable from registered schema types should be explicitly registered. This is a one-line, reversible correction.

Validation after change:

- `get_errors` reported no errors in `Write_App.swift`.

Important release note:

- Because `SceneLocationLink` is now explicitly in the CloudKit-backed SwiftData schema, deploy CloudKit schema changes to production before any TestFlight/App Store build that includes this change, unless the app is switched fully to Ensembles before release.

## High-Risk Areas for Later Phases

- Stable `Syncable` identity for every synced entity.
- Default/reference data duplication: stylesheets, text styles, image styles, printer papers, page setups, poetry forms.
- Rich text content conflict behavior.
- Delete-vs-edit conflicts for `Project`, `Folder`, `TextFile`, `Version`, comments, footnotes, references, and join links.
- Tombstone behavior under event replay.
- Old mirroring state coexisting with new Ensembles sync state.
- Existing devices with stale local data attaching to the new sync dataset.

## Phase 0 Exit Criteria

Phase 0 is complete when:

- The package integration builds.
- The model inventory is documented.
- Schema omissions and CloudKit-incompatible model declarations are identified.
- The revert boundary is clear.
- No production switch from CloudKit mirroring to Ensembles has been made.
