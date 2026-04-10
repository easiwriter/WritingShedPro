# Feature Specification: Reliable CloudKit Sync

**Feature Branch**: `038-cloudkit-rate-limiting`
**Created**: 2026-04-10
**Status**: Draft
**Input**: User description: "An approach for avoiding CloudKit rate limiting"

## Overview

Writing Shed Pro syncs user data (projects, folders, text files, comments, references, etc.) across iOS and macOS devices via CloudKit. Under certain conditions the sync engine can be rate-limited by CloudKit, causing sync to stall — sometimes indefinitely. This is the app's most critical reliability concern: users must trust that their writing is safely synced across devices.

The app has previously addressed some rate-limiting triggers (removed proactive sync nudges, added exponential backoff for rate-limit errors, moved large blobs to external storage, auto-reset after consecutive failures). However, several areas remain where the app generates more write operations than necessary, increasing the likelihood of hitting CloudKit's rate limits.

**Core principle**: Sync may sometimes be slow, but it must always eventually complete. Users should never lose data or be left wondering whether their changes have synced.

### Background: How Rate Limiting Happens

CloudKit throttles primarily on write operations. Each save of the local data context can trigger a CloudKit export operation. When too many exports happen in a short window, CloudKit responds with rate-limit errors. Without proper handling, the sync engine can enter a death spiral: retrying failed exports generates more rate-limit errors, which generates more retries.

**What's already addressed:**
- Forced sync nudges removed (watchdog timers, forced zone fetches, foreground resume nudges)
- Exponential backoff on rate-limit errors with auto-reset after 50 consecutive failures
- Large blob properties use external storage to keep record sizes small
- Private database used (more generous limits than shared/public)
- Single data context pattern (no chatty background contexts)
- No re-saving after CloudKit merge/import

**What still needs work:**
- **Write frequency**: Formatting changes, comments, footnotes, references, and poetry forms all save immediately with no debounce or batching (only text typing is debounced at 0.5 seconds)
- **Write coalescing**: No mechanism to batch multiple rapid saves into a single operation
- **Persistent history tracking**: Not enabled, despite being recommended for CloudKit sync
- **Scheduling intelligence**: No awareness of app state (active editing vs. idle) when deciding save timing
- **Stall detection and recovery**: No proactive mechanism to detect when sync has stalled and recover automatically

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Editing Without Sync Disruption (Priority: P1)

A writer is actively editing a manuscript — typing text, applying formatting, adding footnotes and comments. All changes sync to their other devices without the app triggering CloudKit rate limits. The writer never notices sync happening and never experiences sync stalls during or after an editing session.

**Why this priority**: This is the most common user activity and the primary trigger for excessive write operations. Reducing write frequency during active editing eliminates the largest source of rate-limiting risk.

**Independent Test**: Open a document on Device A, perform 50 rapid edits (mix of typing, formatting, adding comments), then check Device B — all changes should appear within 5 minutes with no rate-limit errors in the sync log.

**Acceptance Scenarios**:

1. **Given** a user is typing in a document, **When** they type continuously for 60 seconds, **Then** the system generates no more than 15 save operations during that period
2. **Given** a user applies 10 formatting changes in rapid succession, **When** the changes are saved, **Then** they are batched into no more than 3 save operations
3. **Given** a user adds 5 footnotes in quick succession, **When** the operations complete, **Then** fewer than 5 individual save operations are generated
4. **Given** the user stops editing, **When** 5 seconds of inactivity pass, **Then** all pending changes have been saved and are queued for sync

---

### User Story 2 - Sync Stall Detection and Recovery (Priority: P2)

A writer finishes editing on their iPad and picks up their Mac expecting to see recent changes. If sync has stalled for any reason (rate limiting, network issues, transient CloudKit errors), the system detects this automatically and takes corrective action without user intervention. The user can also see sync status at a glance.

**Why this priority**: Even with reduced write frequency, external factors (network, CloudKit outages) can still cause sync stalls. Users need confidence that the system will self-heal and that they can verify sync status.

**Independent Test**: Simulate a sync stall by triggering rate-limit conditions, then verify the system detects the stall within 5 minutes, takes recovery action, and completes sync without user intervention.

**Acceptance Scenarios**:

1. **Given** sync has not completed successfully for more than 5 minutes after local changes were saved, **When** the system checks sync health, **Then** it flags the stall and logs a diagnostic entry
2. **Given** a sync stall has been detected, **When** the system attempts recovery, **Then** it uses progressive strategies (wait → retry with backoff → reset sync database as last resort)
3. **Given** the user opens Settings or the sync status area, **When** sync is stalled, **Then** a clear, non-alarming indicator shows that sync is catching up and estimated health status
4. **Given** a sync stall was automatically recovered, **When** recovery completes, **Then** the user sees confirmation that all data is now in sync

---

### User Story 3 - Multi-Device Consistency After Extended Editing (Priority: P3)

A writer works extensively on one device over several hours — creating new projects, reorganising folders, editing multiple files, adding references and comments. When they switch to another device, all changes are present. No data is lost, duplicated, or corrupted, even if the editing session generated hundreds of individual changes.

**Why this priority**: Extended sessions are the highest-volume scenario and the most likely to exhaust CloudKit's rate budget. This validates that write coalescing and scheduling work at scale.

**Independent Test**: Perform a 2-hour intensive editing session on one device (create project, add 10 files, edit each, add comments and references, reorganise folders), then verify complete and accurate sync on the second device.

**Acceptance Scenarios**:

1. **Given** a user has made 200+ individual changes during a long editing session, **When** they switch to another device, **Then** all changes appear within 10 minutes of the second device coming online
2. **Given** the system has been write-coalescing during the session, **When** the session ends, **Then** all coalesced changes are flushed and queued for sync within 30 seconds
3. **Given** the app was rate-limited during the session, **When** the rate limit expires, **Then** sync resumes automatically and all changes are delivered without user intervention

---

### Edge Cases

- What happens when a user makes changes on two devices simultaneously and both are near the rate limit?
- How does the system behave when the device is offline for an extended period and then reconnects with a large backlog of unsaved changes?
- What happens if the app is terminated (force-quit or crash) while changes are still pending in the write coalescing buffer?
- How does the system handle a CloudKit service outage that persists for hours?
- What happens when the user creates a large project from a template (many entities at once) — does the batch save avoid rate limiting?
- How does the system behave when autosave and user-initiated save overlap?

## Requirements *(mandatory)*

### Functional Requirements

**Write Frequency Reduction:**
- **FR-001**: System MUST debounce or coalesce all save operations (not just text typing) so that rapid sequential changes produce fewer individual saves
- **FR-002**: System MUST batch formatting changes made within a short time window into a single save operation
- **FR-003**: System MUST coalesce saves from comment, footnote, and reference operations performed in rapid succession
- **FR-004**: System MUST NOT save unchanged objects — only dirty records should trigger a sync export
- **FR-005**: System MUST flush all pending coalesced changes when the user stops active editing (after a configurable idle period, defaulting to 2-3 seconds)

**Write Scheduling:**
- **FR-006**: System MUST be aware of current sync health when deciding save timing — during active rate-limiting, non-critical saves should be deferred
- **FR-007**: System MUST flush all pending changes before the app enters the background, to avoid data loss
- **FR-008**: System MUST NOT trigger multiple rapid saves when the app becomes active (e.g., avoid processing a backlog aggressively on foreground resume)

**Persistent History Tracking:**
- **FR-009**: System MUST enable persistent history tracking to support efficient CloudKit sync processing

**Stall Detection and Recovery:**
- **FR-010**: System MUST detect when outbound sync has not progressed for a configurable period (default: 5 minutes after the last local change)
- **FR-011**: System MUST attempt progressive recovery when a stall is detected: wait with backoff, then escalate to sync database reset as a last resort
- **FR-012**: System MUST log all stall detections, recovery attempts, and outcomes for diagnostics
- **FR-013**: System MUST NOT attempt destructive recovery (database reset) without first exhausting non-destructive options

**Sync Status Visibility:**
- **FR-014**: System MUST provide a user-visible indication of sync health (synced, syncing, stalled, recovering)
- **FR-015**: System MUST NOT use alarming language or block the user from working when sync is slow or stalled

**Data Safety:**
- **FR-016**: System MUST guarantee that all local changes are eventually synced — no change may be silently dropped
- **FR-017**: System MUST persist pending changes locally even if CloudKit sync is unavailable, so they are synced when connectivity resumes
- **FR-018**: If the app is terminated while changes are pending in a coalescing buffer, those changes MUST be recoverable on next launch

### Key Entities

- **Sync Health State**: Tracks current sync status (healthy, degraded, stalled, recovering), time since last successful sync, and count of pending local changes
- **Write Coalescing Buffer**: Accumulates rapid changes and flushes them as a single save operation after an idle threshold
- **Stall Recovery Strategy**: Progressive escalation path (wait → retry → backoff → reset) with counters and timeouts

## Assumptions

- CloudKit rate limits are not published as exact numbers; the system must adapt to observed behaviour rather than targeting a specific threshold
- The existing exponential backoff and auto-reset mechanisms (already in CloudKitSyncThrottler) will be preserved and integrated into the new stall recovery flow
- The single ModelContainer / main context architecture will be maintained (no additional contexts will be introduced)
- The 0.5-second debounce on text typing is already adequate and does not need to change
- "Immediate save" for formatting was required for Mac Catalyst stability — the write coalescing approach must maintain this stability while reducing save frequency
- Users do not need real-time (sub-second) sync between devices; eventual consistency within minutes is acceptable

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: During a 10-minute intensive editing session (typing, formatting, comments, footnotes), the system produces at least 50% fewer save operations compared to the current behaviour
- **SC-002**: 100% of local changes sync to a second device within 10 minutes of the editing device going idle, under normal network conditions
- **SC-003**: When rate-limited, the system recovers automatically and completes sync within 30 minutes of the rate limit lifting — without user intervention
- **SC-004**: No data loss occurs across 100 consecutive editing sessions of varying intensity, verified by comparing local and remote record counts
- **SC-005**: Users can verify sync status at a glance in under 2 seconds from the settings or status area
- **SC-006**: Zero rate-limit errors observed during normal single-user editing workflows (typing + occasional formatting/comments)
