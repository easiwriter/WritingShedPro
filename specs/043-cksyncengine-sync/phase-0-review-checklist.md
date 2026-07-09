# Phase 0 Review Checklist

**Status**: Reviewed for first implementation slice
**Created**: 2026-07-09

## Purpose

This checklist is the gate between Phase 0 documentation and any test-only dry-run mapper implementation. The first dry-run mapper slice is approved below; CKSyncEngine runtime integration remains blocked.

## Reviewed Decisions

- First dry-run mapper scope: `Project`, `Folder`, `TextFile` metadata, and `Version` metadata.
- Tombstone shape: separate tombstone records from the start.
- Local-only data: editor undo/redo stacks and manuscript analyst review caches stay local-only by default.
- Seed data: predefined poetry forms regenerate locally; only custom poetry forms sync later.
- Page setup: `PageSetup` and `PrinterPaper` are project-owned sync data.
- Zone strategy: use a separate CKSyncEngine shadow zone named `WritingShedProSyncZone`.

## Model Scope Decisions

- [x] Approve first dry-run scope: `Project`, `Folder`, `TextFile` metadata, and `Version` metadata.
- [ ] Approve later syncable structure records and explicit link records.
- [ ] Approve publication/submission records as syncable user data.
- [ ] Approve comments, footnotes, and back matter references as syncable after asset/relationship tests exist.
- [ ] Approve styles as syncable with import-settled seed guards.
- [x] Confirm predefined `PoetryFormModel` rows are regenerated locally, while custom rows sync later.
- [x] Confirm manuscript analyst reviews and suggestions are local-only by default.
- [x] Decide whether `PageSetup` and `PrinterPaper` are project-owned sync data or generated/local settings: project-owned sync data.

## Identity and Relationship Decisions

- [ ] Approve deterministic record names: `<EntityName>:<uuid>`.
- [ ] Approve UUID string fields instead of CKReference delete actions for relationships.
- [ ] Approve explicit link records for all many-to-many membership.
- [ ] Approve two-pass import: decode records first, resolve relationships second.
- [ ] Approve pending relationship diagnostics instead of automatic orphan cleanup.
- [ ] Approve legacy relationship handling for `StoryScene.location` without replacing `SceneLocationLink`.

## Delete and Tombstone Decisions

- [ ] Approve tombstone-first delete lifecycle.
- [x] Decide whether tombstones begin as fields on original records or separate `Tombstone` records: separate tombstone records.
- [ ] Define tombstone retention window.
- [ ] Approve import-specific delete application that avoids SwiftData cascade echo exports.
- [ ] Confirm project trash, file trash, and permanent delete use distinct `deleteReason` values.

## Payload Decisions

- [ ] Approve `Version.formattedContent` as `CKAsset`.
- [ ] Approve `NoteEntry.formattedContentData` as `CKAsset`.
- [ ] Approve `TextFile.coverImageData` as `CKAsset`.
- [x] Confirm `TextFile.undoStackData` and `redoStackData` remain local-only.
- [ ] Confirm JSON/data settings fields remain inline unless diagnostics show size problems.

## Implementation Gate

- [ ] Dry-run mapper has no launch-time side effects.
- [ ] Dry-run mapper cannot write to CloudKit.
- [ ] Dry-run mapper cannot mutate SwiftData.
- [ ] Dry-run report redacts manuscript body content by default.
- [ ] Dry-run tests cover deterministic IDs, skipped local-only fields, asset placeholders, and child-before-parent tolerance.

## Open Review Questions

- Should local notification identifiers sync, or should only reminder dates sync and notification IDs remain local?
- Should style conflict resolution be per-field or last-writer-wins for the first release?