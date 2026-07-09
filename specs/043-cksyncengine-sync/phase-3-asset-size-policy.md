# Phase 3: Asset Size Policy

**Status**: Reviewed - proposed bands accepted
**Created**: 2026-07-09
**Depends on**:

- [phase-3-export-dry-run-plan.md](phase-3-export-dry-run-plan.md)
- [phase-0-core-record-mapping.md](phase-0-core-record-mapping.md)

## Purpose

Define how export dry-run reports asset payloads before any temp-file creation, `CKAsset` construction, or CloudKit write path exists.

## Asset Categories

Known asset candidates in the current mapping:

- `Version.formattedContent`
- `Version.notesFormattedContent`
- `TextFile.coverImageData`

Likely future candidates:

- Rich note/reference payloads if inline data becomes too large.
- Images or generated media added to manuscripts.

## Policy

Phase 3 should count asset placeholders and report byte sizes only. It must not write asset temp files or construct `CKAsset` values.

## Suggested Size Bands

| Band | Byte count | Handling |
| --- | ---: | --- |
| `small` | `< 256 KB` | Report only |
| `medium` | `256 KB - 5 MB` | Report and include in total asset byte count |
| `large` | `5 MB - 50 MB` | Warning in dry-run report |
| `oversized` | `> 50 MB` | Error in dry-run report; requires explicit review before any future upload |

These bands are diagnostic thresholds, not CloudKit write limits. They exist to catch unexpected payload growth before export code exists.

## Rules

- Do not fetch or decode asset body data during read-only inspection.
- Do not create temp files in Phase 3.
- Do not create `CKAsset` values in Phase 3.
- Do not upload assets in Phase 3.
- Do not drop records solely because an asset is large; report the issue and keep the record in the dry-run output.

## Recommended Decision

Reviewed decision: adopt the size bands above for dry-run diagnostics. Keep Phase 3 asset handling as placeholder counting plus warnings/errors only.
