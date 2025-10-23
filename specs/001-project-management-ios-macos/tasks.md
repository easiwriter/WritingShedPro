# Tasks: Project Management (iOS/MacOS)

## Phase 1: Setup
- [X] T001 Create ios/, macos/, models/, services/, and tests/ directories per plan.md
- [X] T002 Initialize multiplatform Xcode app project for iOS and MacCatalyst targets
- [X] T003 Configure SwiftData and CloudKit entitlements in Xcode project
- [X] T004 Set up XCTest for TDD in multiplatform app

## Phase 2: Foundational
- [X] T005 Implement base Project, File, and Folder models in models/
- [X] T006 Implement validation logic for project, file, and folder names in services/
- [X] T007 Implement uniqueness checks for project names, folder names (per parent), and file names (per folder) in services/
- [X] T008 Implement basic SwiftData storage integration in services/
- [X] T009 Implement CloudKit sync integration in services/

## Phase 3: User Story 1 - Add a Project (P1)
- [X] T010 [US1] Implement UI to add a new project in ios/ and macos/ (MacCatalyst)
- [X] T011 [US1] Integrate add project UI with validation and uniqueness logic
- [X] T012 [US1] Add unit tests for add project logic in tests/unit/
- [X] T013 [US1] Add integration test for project creation in tests/integration/

## Phase 4: User Story 2 - Display and Order Project List (P2)
- [X] T014 [US2] Implement UI to display project list in ios/ and macos/ (MacCatalyst)
- [X] T015 [US2] Implement ordering logic (by name, creation date) in services/
- [X] T016 [US2] Integrate ordering options in project list UI
- [X] T017 [US2] Add unit tests for ordering logic in tests/unit/
- [X] T018 [US2] Add integration test for project list display in tests/integration/

## Phase 5: User Story 3 - Rename, Delete, and View Project Details (P3)
- [X] T019 [US3] Implement UI to rename, delete, and view project details in ios/ and macos/ (MacCatalyst)
- [X] T020 [US3] Integrate rename/delete UI with validation and uniqueness logic
- [X] T021 [US3] Add unit tests for rename/delete logic in tests/unit/
- [X] T022 [US3] Add integration test for rename/delete/project details in tests/integration/

## Phase 6: User Story 4 - Drag to Reorder Projects (P3)
- [X] T027 [US4] Add userOrder property to Project model in models/BaseModels.swift
- [X] T028 [US4] Extend SortOrder enum to include byUserOrder case in services/ProjectSortService.swift
- [X] T029 [US4] Implement updateUserOrder method in ProjectSortService to handle drag operations
- [X] T030 [US4] Update project list UI to support .onMove modifier when Edit mode and User's Order are active
- [X] T031 [US4] Add "User's Order" option to sort picker in project list UI
- [X] T032 [US4] Implement logic to only enable drag-to-reorder when User's Order is selected
- [X] T033 [US4] Add unit tests for userOrder sorting logic in tests/unit/
- [X] T034 [US4] Add unit tests for updateUserOrder method in tests/unit/
- [X] T035 [US4] Add integration test for drag-to-reorder functionality in tests/integration/
- [X] T036 [US4] Add accessibility labels for drag handles and reorder actions
- [X] T037 [US4] Test userOrder persistence across app sessions and CloudKit sync

## Final Phase: Polish & Cross-Cutting Concerns
- [X] T023 Add user-friendly error messages for all validation failures in services/
- [X] T024 Add accessibility and localization support in ios/ and macos/ (MacCatalyst)
- [X] T025 Review and refactor code for maintainability and constitution compliance
- [X] T026 Update quickstart.md and documentation for new features

## Dependencies
- Phase 1 (Setup) → Phase 2 (Foundational) → Phase 3 (US1) → Phase 4 (US2) → Phase 5 (US3) → Phase 6 (US4) → Final Phase (Polish)

## Parallel Execution Examples
- T012, T013 ([US1] unit and integration tests) can be done in parallel after T011
- T017, T018 ([US2] tests) can be done in parallel after T016
- T021, T022 ([US3] tests) can be done in parallel after T020
- T033, T034, T035 ([US4] tests) can be done in parallel after T032
- T023, T024, T025, T026 (Polish) can be done in parallel after all user stories

## Implementation Strategy
- MVP: Complete through Phase 3 (User Story 1 - Add a Project)
- Incremental delivery: Each user story phase is independently testable and can be delivered in order of priority

