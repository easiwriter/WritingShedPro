# Feature 041: Onboarding

**Status**: Draft
**Priority**: TBD
**Estimated Effort**: TBD
**Dependencies**: TBD
**Created**: 2026-06-30
**Implementation**: TBD

## Overview

Add an onboarding process for first-time users of Writing Shed Pro. When the app first launches the user is presented with a screen explaining how the user's work is stored in named projects according to genre. They are then presented with a tick-list of the genre types: Poetry, Prose, Fiction and Drama. The user is asked to choose a genre for their first project. They are also given the chance to skip onboarding altogether (with an ask on next launch option). When they have chosen a genre they are asked to specify the name of the project (suitable defaults chosen for fiction). WSP then creates the project and displays the project folders screen and asks the user to choose a name for the first file. This file is then created and the editor displayed with a sheet explaining where they are and how to proceed. 

## Goals

1. Help new users understand the app's core workflow.
2. Reduce friction during initial setup and first project creation.
3. Guide the user from first launch to an open editor with a project and starter file already created.
4. Avoid interrupting existing CloudKit users whose projects have not imported yet.

## Requirements

### 1. Product Requirements
- Provide a first-run onboarding flow for users who have not completed onboarding.
- The flow creates one starter project and one starter file.
- Users can skip onboarding for now; if skipped, the app asks again on the next launch.
- Onboarding can be restarted from Settings, but restarting must show a confirmation warning.

### 2. User Experience
- The first screen explains that work is stored in named projects according to genre.
- The genre selector uses a tick-list presentation for Poetry, Prose, Fiction, and Drama.
- Although presented as a tick-list, onboarding allows one genre selection only.
- If Fiction is selected, the user must choose a fiction subtype before naming the project: Novel, Short Fiction, or Verse Novel.
- The project name step provides genre-specific defaults; Fiction defaults must be based on the selected fiction subtype.
- The first file name step provides a default of `Untitled <type>`.
- After the first file is created and opened in the editor, show a one-time sheet explaining where the user is and how to proceed: "This is your editor. Start writing here; your work is saved automatically and stored inside your project."

### 2.1 Default Project and File Mapping
- Poetry: default project name `My Poetry Collection`; create first file `Untitled Poem` in `Poems`.
- Prose: default project name `My Prose Project`; create first file `Untitled Prose` in `Prose`.
- Fiction - Novel: default project name `My Novel`; create first file `Untitled Chapter` in `Chapters`.
- Fiction - Short Fiction: default project name `My Short Fiction`; create first file `Untitled Scene` in `Scenes`.
- Fiction - Verse Novel: default project name `My Verse Novel`; create first file `Untitled Episode` in `Episodes`.
- Drama: default project name `My Play`; create first file `Untitled Scene` in `Scenes`.

### 3. Functional Behavior
- Onboarding starts only when the app determines the user is eligible for first-run onboarding.
- The user chooses exactly one project genre.
- Fiction requires a subtype selection before project creation.
- WSP creates the project using the existing project template behavior for the chosen genre/type.
- WSP displays the project folders screen after project creation.
- WSP asks the user to name the first file.
- WSP creates the first file in the folder appropriate for the selected project type.
- WSP opens the new file in the editor.
- WSP shows the editor introduction sheet once for the onboarding-created file.

### 4. First-Run Detection
- Onboarding should appear on first launch unless the user has completed onboarding or skipped it for the current launch.
- If onboarding is skipped for now, ask again on the next app launch.
- Before presenting onboarding, wait until initial CloudKit import has either completed or timed out after 60 seconds.
- A fresh install that is still waiting for CloudKit projects must not be treated as a new user too early.

### 5. Platform Scope
- iOS: Supported.
- macOS/Catalyst: Supported.
- The flow should be the same across platforms, with layout adapted to available screen size and platform conventions.

### 6. Performance
- Onboarding must not block app launch while waiting indefinitely for CloudKit import.
- CloudKit import waiting must use a 60-second timeout.
- Project and file creation should use existing creation services and save/coalescing behavior where applicable.

### 7. Accessibility
- The genre tick-list must be accessible as a single-choice control.
- All onboarding screens must support VoiceOver, Dynamic Type, keyboard navigation where applicable, and clear focus order.

### 8. Localization
- All onboarding copy, button titles, alerts, default names, and sheet text must use localized strings.

## Technical Notes

### 1. Architecture
- Prefer a dedicated onboarding coordinator/state object to keep first-run state and navigation decisions out of individual view bodies.
- Reuse existing project creation, template, folder, and file creation paths rather than duplicating setup logic.

### 2. Data Model Impact
- No new SwiftData model is expected unless implementation discovers a need for persisted onboarding session state beyond UserDefaults.
- If any @Model changes are required, CloudKit schema changes must be deployed before TestFlight/App Store builds.

### 3. Persistence/UserDefaults
- Persist onboarding completion state.
- Persist skip-for-now state only for the current launch cycle; the user should be asked again next launch.
- Persist editor introduction sheet display state so it is not shown repeatedly.
- Restarting onboarding from Settings must not erase existing user data.

### 4. Navigation Integration
- On completion, navigate to the newly created project's folders screen.
- After the starter file is named and created, navigate to the editor for that file.
- The editor introduction sheet should be presented after the editor is visible.

### 5. Backward Compatibility
- Existing users with projects should not be forced into onboarding.
- Fresh installs with existing CloudKit data should wait for import completion or timeout before deciding whether to show onboarding.

### 6. CloudKit/Sync Considerations
- Do not create starter projects while an initial CloudKit import may still be about to restore existing projects.
- The import wait must time out after 60 seconds so a genuinely new user is not stuck.
- Project/file creation must produce normal SwiftData changes that sync through CloudKit.

## Implementation Plan

### Phase 1: Discovery
1. Identify existing launch, project creation, folder selection, and file creation paths.
2. Identify existing CloudKit import status signals and choose the onboarding timeout behavior.
3. Confirm genre-to-folder and type-to-default-name mappings.

### Phase 2: Core Implementation
1. Add onboarding state and first-run eligibility checks.
2. Build the genre tick-list, fiction subtype step, project name step, and starter file name step.
3. Reuse existing project and file creation logic.
4. Navigate to the folders screen and then editor after creation.

### Phase 3: UX Polish
1. Add the one-time editor introduction sheet.
2. Add Settings restart action with confirmation warning.
3. Localize all onboarding strings and defaults.

### Phase 4: Validation
1. Validate fresh install with no CloudKit data.
2. Validate fresh install while CloudKit import is pending.
3. Validate skip-for-now and next-launch behavior.
4. Validate Settings restart behavior does not affect existing data.

## Testing

### Unit Tests
- First-run eligibility logic.
- CloudKit import wait/timeout decision logic.
- Genre/type default project and starter file naming.

### UI Tests
- Complete onboarding for each genre.
- Complete onboarding for each Fiction subtype.
- Skip onboarding and confirm it returns on next launch.
- Restart onboarding from Settings and confirm the warning appears.

### Manual Test Cases
- Fresh install with no CloudKit data creates a project, starter file, opens the editor, and shows the editor introduction sheet once.
- Fresh install with existing CloudKit data waits for import completion or timeout before showing onboarding.
- iPhone, iPad, and Mac/Catalyst layouts remain usable.

## Risks and Mitigations

- Risk: Onboarding could create duplicate starter projects before CloudKit import restores existing data.
- Mitigation: Wait for initial CloudKit import completion or timeout before showing onboarding.
- Risk: Restarting onboarding from Settings could imply data reset.
- Mitigation: Show a warning that restarting onboarding does not delete existing work and may create an additional project.
- Risk: A tick-list UI could imply multiple selection.
- Mitigation: Use clear single-selection behavior and accessible state while preserving the tick-list presentation.

## Open Questions

1. Confirm final onboarding copy before implementation.
2. Confirm whether `My Short Fiction` should be renamed to `My Short Story Collection` in user-facing defaults.

## Release Notes Draft

- Added: First-run onboarding for creating an initial project and starter file.
- Changed: TBD
- Fixed: TBD
