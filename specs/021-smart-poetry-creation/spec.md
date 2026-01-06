# Feature Specification: Smart Poetry Creation

**Feature Branch**: `021-smart-poetry-creation`  
**Created**: 2025-12-30  
**Status**: Phase 1 Complete, Phase 2 Pending  
**Input**: User description: "Smart poetry creation"

## Overview

This feature provides intelligent poetry creation assistance within Poetry projects. When users create new poetry files, the system offers smart templates and structure guidance based on common poetry forms, helping writers start with proper formatting for their chosen poetic style.

**Phase 1** (Complete): Core form selection, templates, reference panel, metrics, and stress analysis using bundled JSON definitions.

**Phase 2** (Pending): Custom poetry form editor allowing users to create, edit, and manage their own poetry forms stored in the database. Includes migration of bundled forms to database storage.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Create Poetry with Form Selection (Priority: P1)

A poet wants to write a new sonnet. Instead of manually counting lines and remembering the structure, they select "Sonnet" from the poetry form options when creating a new file. The system creates a new file pre-formatted with 14 numbered line placeholders and displays the expected rhyme scheme (ABAB CDCD EFEF GG) as a reference guide.

**Why this priority**: This is the core value proposition - helping poets write in established forms without having to memorize structural requirements. This differentiates the app from generic text editors.

**Independent Test**: Can be fully tested by creating a new poetry file, selecting a form, and verifying the template structure appears correctly. Delivers immediate value by reducing cognitive load for structured poetry.

**Acceptance Scenarios**:

1. **Given** a user is in a Poetry project Draft folder, **When** they tap the "+" button to create a new file, **Then** they see an option to select a poetry form in addition to entering a title
2. **Given** a user selects "Sonnet" as the poetry form, **When** the file is created, **Then** the file contains a template with 14 line placeholders and displays the rhyme scheme guide
3. **Given** a user selects "Free Verse" or "No Template", **When** the file is created, **Then** the file is blank with no structural constraints
4. **Given** a user has created a file with a template, **When** they edit the content, **Then** the template placeholders are fully editable and can be replaced with their poetry

---

### User Story 2 - View Poetry Form Reference (Priority: P2)

A poet is writing a haiku but can't remember if it's 5-7-5 or 7-5-7 syllables. While editing their poetry file, they access a quick reference panel that shows the rules for their selected form including syllable counts, line requirements, and rhyme patterns.

**Why this priority**: Provides ongoing assistance during the writing process, not just at creation time. Essential for poets learning new forms or working with complex structures.

**Independent Test**: Can be tested by opening any poetry file with an assigned form and accessing the reference panel to verify correct form information displays.

**Acceptance Scenarios**:

1. **Given** a poetry file has an assigned form (e.g., Haiku), **When** the user opens the file for editing, **Then** they can access a reference panel showing the form's rules
2. **Given** a poetry file was created with "Free Verse", **When** the user views the reference panel, **Then** the panel shows "Free Verse - No structural requirements"
3. **Given** a user is viewing the form reference, **When** they dismiss it, **Then** they return to editing without losing their place or content

---

### User Story 3 - Change Poetry Form After Creation (Priority: P3)

A poet started writing what they thought would be a haiku but it evolved into something longer. They want to change the form designation to "Free Verse" or perhaps "Tanka" (5-7-5-7-7) to better match their work.

**Why this priority**: Provides flexibility for the organic nature of creative writing. Poetry often evolves during composition, and writers shouldn't be locked into their initial form choice.

**Independent Test**: Can be tested by creating a file with one form, then changing it to another and verifying the form reference updates accordingly.

**Acceptance Scenarios**:

1. **Given** a poetry file has an assigned form, **When** the user accesses file settings, **Then** they see an option to change the poetry form
2. **Given** a user changes the form from Haiku to Tanka, **When** the change is saved, **Then** the form reference panel shows Tanka rules instead of Haiku rules
3. **Given** a user changes the form, **When** viewing the file, **Then** existing content is preserved unchanged (the form change only affects the reference, not the content)

---

### User Story 4 - Syllable and Line Counter (Priority: P3)

A poet writing a haiku wants to verify their syllable count per line. The system provides a real-time syllable estimate and line count to help them stay within form requirements.

**Why this priority**: Enhances the writing experience by providing live feedback, but is supplementary to the core template and reference features.

**Independent Test**: Can be tested by typing poetry content and verifying syllable/line counts update in real-time.

**Acceptance Scenarios**:

1. **Given** a poetry file is open for editing, **When** the user types content, **Then** a line count is displayed and updates in real-time
2. **Given** a poetry file has syllable-based form requirements (e.g., Haiku), **When** the user types on a line, **Then** an estimated syllable count for that line is displayed
3. **Given** syllable counting is enabled, **When** words with unusual syllable patterns are entered, **Then** the system provides a reasonable estimate (noting that syllable counting is approximate)

---

### User Story 5 - Stress Pattern Analysis (Priority: P3)

A poet writing a Shakespearean sonnet needs to verify their lines follow iambic pentameter (unstressed-stressed pattern, 5 feet per line). The system displays stress pattern analysis showing the detected meter for each line, helping them identify where the rhythm breaks or needs adjustment.

**Why this priority**: Essential for metered poetry but more complex than syllable counting. Poets working with formal verse (sonnets, blank verse) will find this invaluable, while free verse poets can ignore it.

**Independent Test**: Can be tested by typing lines of poetry and verifying stress patterns display with visual indicators (e.g., ˘ for unstressed, ´ for stressed syllables).

**Acceptance Scenarios**:

1. **Given** a poetry file has a meter-based form (e.g., Sonnet, Blank Verse), **When** the user enables stress analysis, **Then** each line displays its detected stress pattern
2. **Given** stress analysis is enabled, **When** viewing a line, **Then** stressed syllables are marked differently from unstressed syllables (e.g., ˘ ´ notation or visual highlighting)
3. **Given** a form requires iambic pentameter, **When** a line deviates from the expected pattern, **Then** the deviation is indicated but not blocked (poets often use intentional variations)
4. **Given** stress analysis is enabled, **When** the user finds it distracting, **Then** they can toggle it off while keeping other metrics visible
5. **Given** a word has multiple valid stress patterns (e.g., "record" as noun vs. verb), **When** analyzing the line, **Then** the system uses context or shows the most common pattern with an indicator that alternatives exist

---

### User Story 6 - Metrics Dashboard (Priority: P4)

A poet wants to see all metrics at a glance: line count, syllable counts, stress patterns, and how their poem compares to the expected form structure. A unified metrics panel provides this overview without cluttering the editing experience.

**Why this priority**: Convenience feature that aggregates other metrics. Lower priority as individual metrics can be accessed separately.

**Independent Test**: Can be tested by opening the metrics dashboard and verifying all relevant statistics display correctly for the current poem and form.

**Acceptance Scenarios**:

1. **Given** a poetry file is open, **When** the user accesses the metrics dashboard, **Then** they see a summary including total lines, syllables per line, and stress pattern analysis
2. **Given** the file has an assigned metered form, **When** viewing the dashboard, **Then** it shows how many lines match the expected meter vs. deviate
3. **Given** the metrics dashboard is open, **When** the user makes edits, **Then** the dashboard updates to reflect changes

---

### Edge Cases

- What happens when a user pastes content that exceeds the form's line count? → Content is accepted; the reference guide shows the expected count for comparison, but does not restrict the poet
- How does the system handle poetry forms with variable structures (e.g., villanelle with refrains)? → Shows the structural pattern with clear indication of which lines should repeat
- What happens when creating files in Poetry projects that have no network connection? → All form templates are stored locally; feature works fully offline
- How does syllable counting handle contractions, hyphenated words, or non-English words? → Uses best-effort estimation; displays count as "~X syllables" to indicate approximation
- What if a user wants a form not in the predefined list? → User can select "Custom Form" and add their own notes in the form description field
- How does stress analysis handle words with ambiguous stress (e.g., compound words, proper nouns)? → Uses dictionary-based lookup with fallback heuristics; marks ambiguous words with a subtle indicator
- What happens with archaic or poetic pronunciations (e.g., "blessed" as two syllables)? → System uses modern pronunciation by default; future enhancement could allow user overrides
- How accurate is automated stress detection? → Displayed as guidance, not absolute truth; accuracy target is 85%+ for common English words

---

## Phase 2: Custom Poetry Form Editor

### User Story 7 - Create Custom Poetry Form (Priority: P1)

A poet wants to use a Pantoum form which isn't in the predefined list. They access the form editor, enter the form name, description, and structural requirements (line count, syllable pattern, rhyme scheme, meter), and save it. The new form appears alongside the predefined forms when creating new poetry files.

**Why this priority**: This is the core Phase 2 feature - enabling poets to extend the app with any form they need, including obscure traditional forms (terza rima, pantoum, rondeau) or entirely invented structures.

**Independent Test**: Can be fully tested by creating a new custom form, verifying it appears in the form picker, and using it to create a new poetry file.

**Acceptance Scenarios**:

1. **Given** a user accesses the poetry forms management screen, **When** they tap "Add Custom Form", **Then** they see an editor with fields for name, category, description, and optional structure fields (line count, syllable pattern, rhyme scheme, meter, template)
2. **Given** a user fills in the form name and description, **When** they tap "Save", **Then** the custom form is saved to the database and appears in the form picker
3. **Given** a user creates a custom form, **When** they later create a new poetry file, **Then** the custom form appears in the "Custom" category of the form picker
4. **Given** a user enters an invalid syllable pattern (e.g., non-numeric), **When** they try to save, **Then** validation feedback indicates the error

---

### User Story 8 - Edit Custom Poetry Form (Priority: P2)

A poet created a custom form but made a mistake in the syllable pattern. They access the form management screen, select their custom form, edit the pattern, and save. All poetry files using this form reflect the updated requirements in their reference panels.

**Why this priority**: Essential companion to form creation - users need to fix mistakes and refine their custom forms.

**Independent Test**: Can be tested by creating a form, editing it, and verifying the changes appear in the form reference panel for files using that form.

**Acceptance Scenarios**:

1. **Given** a user has created custom forms, **When** they access the forms management screen, **Then** they see a list of their custom forms with edit/delete options
2. **Given** a user taps "Edit" on a custom form, **When** the editor opens, **Then** all current values are pre-populated in the fields
3. **Given** a user modifies a custom form and saves, **When** they view a poetry file using that form, **Then** the reference panel shows the updated requirements
4. **Given** a user tries to edit a predefined form (e.g., Haiku), **Then** they see view-only details without edit capability (or a "Duplicate as Custom" option)

---

### User Story 9 - Delete Custom Poetry Form (Priority: P2)

A poet no longer needs a custom form they created. They delete it from the forms management screen. Poetry files that were using that form are changed to "Free Verse" (or "Custom" placeholder) to maintain data integrity.

**Why this priority**: Users need to clean up unused custom forms, but must handle orphaned references gracefully.

**Independent Test**: Can be tested by creating a form, assigning it to a file, deleting the form, and verifying the file's form reference is handled appropriately.

**Acceptance Scenarios**:

1. **Given** a user has a custom form, **When** they tap "Delete", **Then** they see a confirmation dialog warning about files using this form
2. **Given** files are using the custom form, **When** the user confirms deletion, **Then** those files are updated to use "Free Verse" (or display "Unknown Form")
3. **Given** no files are using the custom form, **When** the user confirms deletion, **Then** the form is immediately removed without additional warnings
4. **Given** a user tries to delete a predefined form, **Then** the delete option is not available (predefined forms are protected)

---

### User Story 10 - Import/Export Custom Forms (Priority: P3)

A poet wants to share their custom forms with another device or another user. They export selected custom forms as a JSON file, which can be imported on another device or shared with others.

**Why this priority**: Enables form sharing and backup, but not essential for core functionality.

**Independent Test**: Can be tested by exporting a custom form, clearing the database, importing the file, and verifying the form is restored.

**Acceptance Scenarios**:

1. **Given** a user has custom forms, **When** they tap "Export", **Then** they can select which forms to export and save as a JSON file
2. **Given** a user has a JSON file with poetry forms, **When** they tap "Import", **Then** the forms are added to their custom forms list
3. **Given** an imported form has the same name as an existing custom form, **When** importing, **Then** the user is prompted to rename, replace, or skip
4. **Given** an import file contains invalid data, **When** importing, **Then** the user sees an error message and valid forms are still imported

---

### User Story 11 - Database Migration of Predefined Forms (Priority: P1)

The system migrates predefined forms from the bundled JSON file to the database on first launch (or upgrade). This enables a unified storage model where both predefined and custom forms are queried from the same source, while preserving the original JSON as a bootstrap/reset source.

**Why this priority**: Technical foundation required before custom forms can be implemented. Enables consistent data access patterns.

**Independent Test**: Can be tested by clearing the database, launching the app, and verifying predefined forms are loaded from database queries.

**Acceptance Scenarios**:

1. **Given** a fresh app install, **When** the app launches, **Then** predefined forms from JSON are seeded into the database
2. **Given** forms already exist in the database, **When** the app launches, **Then** no duplicate forms are created (idempotent migration)
3. **Given** a new app version adds predefined forms to JSON, **When** the app launches, **Then** new predefined forms are added without affecting existing custom forms
4. **Given** the database is corrupted or empty, **When** the user accesses forms, **Then** the system falls back to loading from bundled JSON

---

### Phase 2 Edge Cases

- What happens if a user creates a custom form with the same name as a predefined form? → Allowed; custom forms are shown in "Custom" category, distinguished by category grouping
- How does CloudKit sync handle custom forms? → Custom forms sync across devices using the same iCloud account via CloudKit
- What happens if two devices create forms with the same name simultaneously? → CloudKit conflict resolution applies; both forms are preserved with unique IDs
- Can users modify predefined forms? → No, predefined forms are read-only. Users can "Duplicate as Custom" to create an editable copy
- What if the syllable pattern array length doesn't match line count? → Validation warns but allows save; form reference shows available syllables and notes discrepancy
- How are forms ordered in the picker? → Predefined forms by category/alphabetical order, custom forms in "Custom" category by creation date (newest first) or alphabetically

## Requirements *(mandatory)*

### Functional Requirements - Phase 1 (Complete)

- **FR-001**: System MUST provide a list of common poetry forms when creating a new file in Poetry projects
- **FR-002**: System MUST include at minimum these poetry forms: Sonnet (Shakespearean), Sonnet (Petrarchan), Haiku, Tanka, Limerick, Villanelle, Ghazal, Free Verse, Blank Verse, and Custom
- **FR-003**: Users MUST be able to create poetry files without selecting a form (Free Verse default)
- **FR-004**: System MUST generate appropriate template content based on selected poetry form
- **FR-005**: System MUST store the selected poetry form as metadata on the text file
- **FR-006**: Users MUST be able to access a reference panel showing the current form's rules while editing
- **FR-007**: Users MUST be able to change the poetry form after file creation
- **FR-008**: System MUST display a real-time line count for all poetry files
- **FR-009**: System MUST display an estimated syllable count per line for forms with syllable requirements
- **FR-013**: System MUST provide stress pattern analysis for forms with meter requirements (e.g., iambic pentameter)
- **FR-014**: System MUST display stress patterns using standard notation (˘ for unstressed, ´ for stressed) or visual highlighting
- **FR-015**: System MUST allow users to toggle stress analysis on/off independently of other metrics
- **FR-016**: System MUST indicate when a line's stress pattern deviates from the expected meter without blocking user input
- **FR-017**: System MUST provide a metrics dashboard summarizing line count, syllable counts, and stress pattern conformance
- **FR-010**: System MUST preserve all user content when the poetry form is changed
- **FR-011**: System MUST work fully offline with locally stored form definitions
- **FR-012**: System MUST sync poetry form metadata across devices via CloudKit

### Functional Requirements - Phase 2 (Pending)

- **FR-020**: System MUST migrate predefined forms from bundled JSON to database on first launch/upgrade
- **FR-021**: System MUST provide a form management screen accessible from Poetry project settings or file editor
- **FR-022**: Users MUST be able to create new custom poetry forms with: name, category, description, and optional structure (line count, syllable pattern, rhyme scheme, meter pattern, template content)
- **FR-023**: Users MUST be able to edit their custom poetry forms
- **FR-024**: Users MUST be able to delete their custom poetry forms with confirmation
- **FR-025**: System MUST handle orphaned form references gracefully when a custom form is deleted (fallback to Free Verse)
- **FR-026**: Predefined forms MUST be read-only (users cannot edit or delete them)
- **FR-027**: Custom forms MUST appear in the form picker alongside predefined forms, grouped in the "Custom" category
- **FR-028**: Custom forms MUST sync across devices via CloudKit
- **FR-029**: System SHOULD provide import/export functionality for custom forms as JSON
- **FR-030**: Form editor MUST validate syllable pattern format (comma-separated integers or hyphenated)
- **FR-031**: System MUST support "Duplicate as Custom" action for predefined forms to enable user modifications

### Poetry Project Folder Structure

Poetry projects have the following folder structure:

**Workflow Folders** (for organizing poems by status):
- **All**: Contains all poems in the project
- **Draft**: Poems that are work in progress
- **Ready**: Poems that are complete and ready for submission
- **Submissions**: Collections of poems for submission tracking
- **Set Aside**: Poems on hold or for later consideration
- **Published**: Successfully published poems
- **Collections**: User-organized groupings of poems

**Manuscript Folder**:
- **Manuscript**: For collecting poems into a cohesive work (chapbook, collection, anthology). Contains text files and supporting matter for assembled works.

**Publications Folders** (for tracking submission targets):
- **Magazines**: Literary magazines and journals
- **Competitions**: Poetry competitions and contests
- **Commissions**: Commissioned work
- **Other**: Other publication opportunities

**Support Folders**:
- **Research**: Reference materials, notes, and inspiration
- **Trash**: Deleted items awaiting permanent removal

### Key Entities

- **PoetryFormModel** (NEW - SwiftData @Model): Database-stored poetry form for both predefined and custom forms. Key attributes: id (UUID), name, category, lineCount (optional), syllablePattern (optional, stored as JSON array), rhymeScheme (optional), meterPattern (optional), description, templateContent, isCustom (Bool), isPredefined (Bool), createdDate, modifiedDate. Relationships: none (standalone entity, referenced by TextFile.poetryFormId).

- **PoetryForm** (existing struct): Lightweight struct for UI/transport. Can be initialized from PoetryFormModel or JSON. Used by views and services.

- **TextFile (extended)**: Extended to include optional poetry form reference (poetryFormId: UUID?). Relationship: a TextFile in a Poetry project may reference one PoetryFormModel by ID.

## Success Criteria *(mandatory)*

### Measurable Outcomes - Phase 1

- **SC-001**: Users can create a new poetry file with a selected form in under 30 seconds
- **SC-002**: 90% of users creating structured poetry (sonnets, haiku, etc.) use the form selection feature rather than manually formatting
- **SC-003**: Users can access the form reference panel within 2 taps/clicks from the editing view
- **SC-004**: Syllable count estimates display within 500ms of user input
- **SC-007**: Stress pattern analysis displays within 1 second of user input
- **SC-008**: Stress pattern detection achieves 85%+ accuracy for common English words
- **SC-009**: Users can toggle stress analysis on/off within 1 tap/click
- **SC-005**: Form templates render correctly for all 10+ predefined poetry forms
- **SC-006**: Users report the form reference feature as "helpful" or "very helpful" at a rate of 80% or higher in feedback surveys

### Measurable Outcomes - Phase 2

- **SC-020**: Users can create a new custom poetry form in under 2 minutes
- **SC-021**: Custom forms appear in the form picker within 1 second of saving
- **SC-022**: Database migration of predefined forms completes in under 2 seconds on first launch
- **SC-023**: Custom forms sync across devices within CloudKit's normal sync timeframe
- **SC-024**: Form editor validates input and shows errors before save attempt
- **SC-025**: Deleting a custom form updates all referencing files within 1 second

## Assumptions

### Phase 1 Assumptions
- Poetry forms will use industry-standard definitions (e.g., Shakespearean sonnet is 14 lines in iambic pentameter with ABAB CDCD EFEF GG rhyme scheme)
- Syllable counting will use English language rules; non-English poetry may have less accurate counts
- Stress pattern analysis uses dictionary-based pronunciation data supplemented by algorithmic heuristics
- Stress analysis is guidance only; intentional metrical variations (substitutions, inversions) are common in formal verse
- The feature applies only to Poetry project types; other project types continue with existing file creation flow
- Template content serves as guidance only and does not restrict user input
- Form metadata syncs with existing CloudKit infrastructure used for other file attributes

### Phase 2 Assumptions
- The bundled PoetryForms.json file remains the source of truth for predefined forms (used for seeding/resetting)
- Predefined forms in the database have stable UUIDs matching the JSON file for consistent references
- Custom forms do not require moderation or validation beyond basic input format checking
- Users understand that their custom forms are personal and not submitted to any central repository
- CloudKit sync handles custom forms using the same patterns as other user data (Project, Folder, TextFile)
- The form editor UI follows existing patterns in the app (modal sheet with form fields)
- Forms with unusual structures (e.g., pantoum's repeating lines) can be described in templateContent and description rather than requiring special parsing logic

## Migration Requirements

### Existing Poetry Projects

When the folder structure is updated (e.g., adding Manuscript folder), existing Poetry projects require migration:

- **ProjectFolderMigrationService**: Versioned migration service that runs on app launch
- **Version 1**: Adds Manuscript folder to existing Poetry projects that don't have one
- Migration is idempotent - folders are only added if missing
- Migration runs automatically via `ContentView.initializeUserOrderIfNeeded()`

**Implementation**: See `ProjectFolderMigrationService.swift`


