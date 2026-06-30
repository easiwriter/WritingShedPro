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

### 7. Implementation Surface
- `ContentView.swift`: own the launch-time eligibility check and CloudKit wait task.
- `ContentViewBody.swift`: present onboarding and coordinate with existing project-list navigation.
- `ContentViewState.swift`: hold any onboarding presentation/navigation flags needed by the root view.
- `AddProjectSheet.swift`: move creation logic into a shared service and keep the sheet using that service.
- `AddFileSheet.swift`: move creation logic into a shared service and keep the sheet using that service.
- `ProjectTemplateService.swift`: continue to own default folder creation.
- `CloudKitSyncThrottler.swift`: provide import completion/in-progress signals for onboarding eligibility.
- `SettingsSheet.swift`: add the restart onboarding action and warning.

## Implementation Plan

### Phase 1: Extract Reusable Creation Services
1. Add an `OnboardingDefaults` helper that maps genre/fiction class to default project name, starter file name, and destination folder name.
2. Extract the project creation logic from `AddProjectSheet` into a reusable service method that validates names, checks uniqueness, checks entitlements, sets fiction/story structure fields, assigns the default stylesheet, clears tombstones, creates default folders through `ProjectTemplateService`, saves, and returns the created `Project`.
3. Extract the file creation logic from `AddFileSheet` into a reusable service method that validates names, checks entitlements, checks `FolderCapabilityService`, assigns poetry form defaults for Poetry and Verse Novel episodes, creates the `TextFile`, applies draft workflow status for content folders, saves, and returns the created `TextFile`.
4. Update `AddProjectSheet` and `AddFileSheet` to call the shared services so onboarding and normal creation cannot drift.

### Phase 2: Add Onboarding State and Eligibility
1. Add an `@Observable` onboarding coordinator/state object, using `@Observable` rather than `ObservableObject` or `@Published`.
2. Persist onboarding completion with UserDefaults.
3. Track skip-for-now only in memory for the current launch so onboarding returns on next launch.
4. Add a first-run eligibility check that uses a fresh `ModelContext(modelContext.container)` to count active projects directly from the persistent store instead of trusting `@Query` alone.
5. Gate eligibility behind CloudKit initial import status from `CloudKitSyncThrottler`: wait until import completes/succeeds, existing projects appear, or the 60-second timeout elapses, then re-check the persistent store before deciding whether to present onboarding.
6. Do not mark onboarding complete until the starter project and starter file are successfully created.

### Phase 3: Build the Onboarding Flow
1. Add an `OnboardingView` presented from `ContentViewBody` as a sheet or full-screen cover, depending on platform layout needs.
2. Screen 1: explain projects, genres, and first-file setup; provide Continue and Skip for Now.
3. Screen 2: show the single-selection tick-list for Poetry, Prose, Fiction, and Drama.
4. Screen 3: if Fiction was selected, show Novel, Short Fiction, and Verse Novel subtype choices.
5. Screen 4: project name entry with the mapped default value.
6. Screen 5: starter file name entry with the mapped default value.
7. Confirm creates the project, finds the destination folder by localized folder name or capability fallback, creates the starter file, and hands both objects back to the coordinator.
8. Surface validation and entitlement failures inside onboarding using the same error messages as normal creation.

### Phase 4: Navigation and Editor Introduction
1. Extend `ContentViewState` navigation support if needed so onboarding can open the new project and then the new file.
2. Navigate first to the newly created project using the existing `showProject(_:)` path.
3. Add a route or notification for opening the starter file in `FolderFilesView`/`FileEditView` after the project route is active.
4. Present the one-time editor introduction sheet only after the editor is visible.
5. Persist the editor introduction sheet display state so it is not shown again for normal editing.
6. Ensure auto-open-last-project does not compete with onboarding on the same launch.

### Phase 5: Settings Restart and Localization
1. Add a Settings row for restarting onboarding.
2. Show a confirmation alert warning that restarting onboarding does not delete existing work and may create another project.
3. Restarting onboarding should clear the onboarding-complete flag but not delete data, hide projects, reset CloudKit, or alter existing navigation state beyond presenting onboarding.
4. Add all new strings to `Resources/en.lproj/Localizable.strings` at the same time as the Swift code.

### Phase 6: Validation
1. Unit test `OnboardingDefaults` mappings.
2. Unit test onboarding eligibility with completed, skipped-for-now, existing-project, empty-store, import-completed, import-in-progress, and timeout cases.
3. Unit test shared project/file creation services where practical, using existing project-template tests as a model.
4. UI/manual test a fresh install with no CloudKit data.
5. UI/manual test a fresh install while CloudKit import is pending to confirm onboarding waits up to 60 seconds and does not create duplicates when projects arrive.
6. UI/manual test skip-for-now returning on next launch.
7. UI/manual test Settings restart and confirmation warning.
8. UI/manual test Poetry, Prose, Novel, Short Fiction, Verse Novel, and Drama flows on iPhone, iPad, and Mac/Catalyst.

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
