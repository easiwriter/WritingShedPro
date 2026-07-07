# Phase 3: Import Preview

**Date**: 2026-07-04  
**Status**: Phase 3b started  
**Scope**: Reconstruct remote sync state and materialize it only in an isolated CloudKit-disabled debug store

## Purpose

Validate the restore/import side of the Cloudflare sync POC before creating local records.

The important safety constraint is that the current WSP SwiftData store is still CloudKit-backed. Creating a local "test import" project in the main app store would also queue that project for production CloudKit export. For this reason, Phase 3 started with an in-memory import preview, then Phase 3b added materialization only into a separate debug store with CloudKit disabled.

## Implemented App Surface

Debug UI:

- `SyncDiagnosticsView` includes `Preview Remote Import` in the DEBUG/simulator-only `Cloudflare Sync POC` section.
- `SyncDiagnosticsView` includes `Materialize Isolated Import` in the same DEBUG/simulator-only section.
- `SyncDiagnosticsView` includes `Run Tombstone Probe` in the same DEBUG/simulator-only section.

Service:

- `CloudflareSyncPOCService.previewRemoteImport(projects:)`
- `CloudflareSyncPOCService.materializeIsolatedImport(projects:)`
- `CloudflareSyncPOCService.runTombstoneProbe(projects:)`
- `WritingShedModelSchema.schema` centralizes the app model schema so the production container and isolated import container use the same model registration list.

## Behavior

`Preview Remote Import`:

1. Selects the first non-trashed local project, matching the current push/pull sample source.
2. Bootstraps that project/device against the Worker.
3. Pulls remote operations from sequence 0.
4. Replays supported `upsert` operations in memory.
5. Reports the reconstructed project name, style count, folder count, text-file count, version count, comment count, footnote count, story-record count, join-link count, publication/submission count, total text characters, remote operation count, and latest sequence.

Supported entity types for preview:

- `Project`
- `StyleSheet`
- `TextStyleModel`
- `ImageStyle`
- `Folder`
- `TextFile`
- `Version`
- `CommentModel`
- `FootnoteModel`
- `StoryScene`
- `Chapter`
- `Act`
- `ProseSection`
- `PoetryCollection`
- `Book`
- `Character`
- `Location`
- `PlotElement`
- `TextFileSectionLink`
- `TextFileCollectionLink`
- `SceneChapterLink`
- `SceneActLink`
- `SceneBookLink`
- `ScenePlotElementLink`
- `SceneCharacterLink`
- `CharacterPlotElementLink`
- `LocationPlotElementLink`
- `SceneLocationLink`
- `NoteEntry`
- `GlossaryEntry`
- `ReferenceEntry`
- `CitationEntry`
- `IndexEntry`
- `ContributorEntry`
- `Publication`
- `Submission`
- `SubmittedFile`

Unsupported entities are ignored for now.

## Phase 3b Materialization Behavior

`Materialize Isolated Import`:

1. Selects the same first non-trashed local project.
2. Bootstraps that project/device against the Worker.
3. Pulls remote operations from sequence 0.
4. Replays supported `upsert` operations into a fresh, separate SwiftData SQLite store.
5. Creates a marked project named `Cloudflare POC Import - <Remote Project Name>`.
6. Inserts reconstructed stylesheet/text-style/image-style, folder, text-file, version, comment, footnote, story, container, character, location, plot-element, join-link, publication, submission, and submitted-file records into that isolated store.
7. Attaches the imported stylesheet to the imported project when available.
8. Saves and reports project name, folder count, text-file count, version count, comment count, footnote count, story-record count, join-link count, total text characters, and store filename.

## Style Coverage

The POC now exports and imports the selected project's linked `StyleSheet` plus its `TextStyleModel` and `ImageStyle` records.

Included stylesheet fields:

- name
- system stylesheet flag
- footnote marker style
- created/modified dates

Included text-style fields:

- display identity and order
- font family/name/size and traits
- color hex
- paragraph alignment, spacing, indent, line-height fields
- numbering format/adornment
- follow-on and parent style names
- style category/system flag
- TOC fields
- first-paragraph style flag

Included image-style fields:

- display identity and order
- default scale
- default alignment
- caption default flag
- default caption style
- system-style flag

## Publication Coverage

The POC now exports and imports a bounded publication/submission sample for the selected project.

Limits:

- up to 6 publications
- up to 12 submissions/collections
- up to 30 submitted-file links

Included publication fields:

- name
- type
- URL
- notes
- deadline
- typical response days
- reminder date
- created/modified dates

Included submission fields:

- linked publication ID
- collection name/description
- collection flag
- submitted date
- expected/returned dates
- notes
- typical response days
- reminder date
- user order
- created/modified dates

Included submitted-file fields:

- linked submission ID
- linked text-file ID
- linked version ID
- status
- status date/notes
- created/modified dates

Because the entity sample is now larger, the Worker POC push limit was raised from 100 to 250 operations, then to 500 operations for Phase 3c story-record coverage, then to 1000 operations for Phase 3d join-link coverage, then to 2000 operations for Phase 3e realistic project coverage.

Preview/materialization now page through Worker pull responses instead of assuming a single 500-operation response is complete.
Push/pull sample pushes are chunked into batches of 200 operations so realistic project payloads do not depend on one large request succeeding.

## Annotation Coverage

The POC now exports and imports bounded comment and footnote samples attached to the exported versions.

Limits:

- up to 60 comments
- up to 60 footnotes

Included comment fields:

- linked version ID
- character position
- attachment ID
- text
- author
- created date
- resolved date

Included footnote fields:

- linked version ID
- character position
- attachment ID
- text
- number
- created/modified dates

## Front/Back Matter Coverage

Front matter and back matter content is represented by the existing folder/text-file/version payloads. The POC now also preserves the front/back matter settings stored on `Folder` records:

- fiction front matter settings
- fiction back matter settings
- drama front matter settings
- drama back matter settings

These settings are transported as base64-encoded JSON data and restored only in the isolated CloudKit-disabled materialization store.

The debug reports now show a matter breakdown for both local source and remote/import state:

- Front Matter folder present or missing
- Back Matter folder present or missing
- direct text-file count in each matter folder
- version count for those files
- whether any matter settings data is present on the folder

## Back-Matter Reference Coverage

The POC now exports and imports bounded reference/back-matter records attached directly to the selected project.

Limits:

- up to 100 records per reference/back-matter type

Included reference/back-matter types:

- notes/endnotes
- glossary entries
- references
- citations
- index entries
- contributors

Included relationship fields:

- glossary citation ID
- index parent entry ID
- index see/see-also IDs
- note/index referencing file IDs

Binary or structured fields such as formatted note content, citation authors, index references, and page-number data are transported as base64-encoded data and restored only in the isolated CloudKit-disabled materialization store.

The debug reports show a per-type reference breakdown for source and remote state, for example: notes, glossary, references, citations, index, and contributors. If Preview or Materialize shows zero after an older push, run Push/Pull again from a build that includes reference coverage so the Worker receives those entity operations.

## Story Record Coverage

The POC now exports and imports bounded base story/planning records for the selected project. This phase reconstructs the records themselves; many-to-many join-table reconstruction remains a follow-up slice.

Limits:

- up to 100 records per story/planning type

Included story/planning types:

- scenes
- chapters
- acts
- prose sections
- poetry collections
- verse-novel books
- characters
- locations
- plot elements

Included shared container fields:

- name
- synopsis
- user order
- created/modified dates
- body-matter order
- body-matter flag

Included scene-specific fields:

- monomyth/Campbell stage
- three-act/Pearson stage
- trashed flag/date
- linked text-file ID
- legacy linked location ID

Included character/location/plot fields:

- character role, archetypes, history, looks, traits, work
- location detail, sights, sounds, smells
- plot notes and story-stage fields

## Join-Link Coverage

The POC now exports and imports bounded many-to-many join records for the selected project. These are materialized only in the isolated CloudKit-disabled debug store.

Limits:

- up to 300 join links

Included join-link types:

- text file to prose section
- text file to poetry collection
- scene to chapter
- scene to act
- scene to verse-novel book
- scene to plot element
- scene to character
- scene to location
- character to plot element
- location to plot element

Included join-link fields:

- concrete join model type
- left/right entity IDs
- user order where the join model supports it

## Tombstone Probe

`Run Tombstone Probe` validates delete/tombstone semantics without deleting local WSP data.

It uses a synthetic remote-only entity type:

```text
TombstoneProbe
```

The probe sequence is:

1. Bootstrap the selected project/device.
2. Push a synthetic `TombstoneProbe` upsert.
3. Push a synthetic `TombstoneProbe` delete for the same entity ID.
4. Push a stale upsert for the same entity ID with a base sequence older than the tombstone.
5. Require the Worker to reject the stale update with `stale_update_after_tombstone`.

This tests the Worker tombstone table and stale-update rejection path. No local SwiftData records are inserted, updated, or deleted.

The isolated store uses:

```swift
let configuration = ModelConfiguration("CloudflareSyncPOCImportConfiguration", schema: WritingShedModelSchema.schema, url: storeURL, cloudKitDatabase: .none)
```

The store file is reset on each materialized import run and lives under the app's Application Support directory in a `CloudflareSyncPOC` folder.

## Safety Boundaries

- No records are inserted, updated, or deleted in the production SwiftData container.
- No pulled Cloudflare data is applied to the source project.
- The tombstone probe uses synthetic remote-only records and does not delete local WSP records.
- Production CloudKit remains the active app sync path.
- The preview exists only in DEBUG/simulator diagnostics UI.
- Materialization exists only in DEBUG/simulator diagnostics UI and writes only to a separate CloudKit-disabled SwiftData container.

## Why Not Create a Test Project in the Main Store?

A test project in the main SwiftData store is not isolated. Because the store is CloudKit-backed, SwiftData would export that test project through the production CloudKit container.

For Phase 3b, the chosen path is:

1. Create a separate debug-only local store/container with CloudKit disabled.

The other possible paths remain deferred:

1. Add an explicit user-confirmed import path that accepts a CloudKit-visible test project.
2. Wait until the Cloudflare sync path has a separate app data model/storage boundary.

## Validation

- `get_errors` reported no errors for `CloudflareSyncPOCService.swift`.
- `get_errors` reported no errors for `SyncDiagnosticsView.swift`.
- `get_errors` reported no errors for `WritingShedModelSchema.swift`.
- `get_errors` reported no errors for `Write_App.swift` after switching the production container to the shared schema factory.
- `get_errors` reported no errors for this spec/doc slice.
- Read-only inspection of `The 2nd World.wsp` showed realistic poetry-project scale: 13 folders, 237 text files, 469 versions, 16 poetry collections, 16 publications, 36 submissions, 213 submitted-file records, and 145 poetry collection links. This drove Phase 3e paged pulls and wider POC caps.
- App-side realistic-project test with `The 2nd World` succeeded for push/pull: remote summary reported `Folder=13`, `PoetryCollection=16`, `Project=1`, `Publication=16`, `Submission=36`, `SubmittedFile=213`, `TextFile=237`, `TextFileCollectionLink=145`, `Version=469`, and `upsert=1146`.
- App-side structured-project preview with `The Republic of Heaven` succeeded: `1` stylesheet, `17` text styles, `1` image style, `15` folders, `23` text files, `29` versions, `38` story records, `38` join links, `1` submission, `164` remote operations.

## Next Steps

1. Build a DEBUG/Catalyst app.
2. Run `Push/Pull Project Sample`.
3. Run `Preview Remote Import`.
4. Confirm preview counts match the bounded sample.
5. Run `Materialize Isolated Import`.
6. Confirm the reported counts match the preview counts, including versions, comments, footnotes, story records, and join links.
7. Run `Run Tombstone Probe` and confirm stale update rejection.
8. Decide whether to add a debug viewer for the isolated store or move next to full baseline export coverage.
