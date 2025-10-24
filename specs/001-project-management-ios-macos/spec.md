
# Feature Specification: Project Management (iOS/MacOS)

**Phase**: 001  
**Created**: 20 October 2025  
**Status**: ✅ Complete (21 October 2025)  
**Next Phase**: [002-folder-file-management](../002-folder-file-management/spec.md)  
**Input**: User description: "This is the first stage of a writing app called Writing Shed Pro to run on IOS and MacOS (Mac Catalyst). The app lets users store their work in objects called Project. All user work is held in SwiftData. All code is in Swift using SwiftUI. It should be fully testable. All the first stage should be able to do is: - add projects - delete projects - rename projects - display project details - display a list of projects - order the project list"

## Key Entities

**Project**: Represents a user's writing work. Key attributes: name, type, creation date, details, userOrder (for custom sorting). Each project is independent and stored in SwiftData. The following project types are supported:
- `blank`: allows text files and nested folders
- `novel`: allows text files and nested folders specifically for writing a novel
- `poetry`: allows text files and nested folders specifically for writing poetry
- `script`: allows text files and nested folders specifically for writing plays and filmscripts
- `short story`: allows text files and nested folders specifically for writing short stories

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Add a Project (Priority: P1)

A user opens the app and creates a new project to begin organizing their writing work.

**Why this priority**: Creating projects is the foundation for all other actions in the app.

**Independent Test**: Can be fully tested by creating a project and verifying it appears in the project list.

**Acceptance Scenarios**:

1. **Given** the app is open, **When** the user selects "Add Project", **Then** a new project is created and shown in the list.
2. **Given** the user enters a project name, **When** the project is created, **Then** the name is saved and displayed.

---

### User Story 2 - Display and Order Project List (Priority: P2)

A user views all their projects in a list and can order them by name or creation date.

**Why this priority**: Users need to easily find and organize their work.

**Independent Test**: Can be tested by adding multiple projects and verifying the list displays and orders them correctly.

**Acceptance Scenarios**:

1. **Given** multiple projects exist, **When** the user views the project list, **Then** all projects are displayed.
2. **Given** the user selects an ordering option, **When** the list updates, **Then** projects are ordered accordingly.

---

### User Story 3 - Rename, Delete, and View Project Details (Priority: P3)

A user can rename a project, delete a project, and view details about a project.

**Why this priority**: Managing project details is essential for organization and cleanup.

**Independent Test**: Can be tested by renaming, deleting, and viewing details for a project and verifying changes are reflected.

**Acceptance Scenarios**:

1. **Given** a project exists, **When** the user renames it, **Then** the new name is saved and shown.
2. **Given** a project exists, **When** the user deletes it, **Then** it is removed from the list.
3. **Given** a project exists, **When** the user views its details, **Then** relevant information is displayed.

---

### User Story 4 - Drag to Reorder Projects (Priority: P3)

A user can drag projects to reorder them in their preferred custom sequence and save this ordering as "User's Order".

**Why this priority**: Users want to organize their work in their own preferred order, beyond alphabetical or date-based sorting.

**Independent Test**: Can be tested by dragging projects to new positions and verifying the order is maintained when "User's Order" sort is selected.

**Acceptance Scenarios**:

1. **Given** the project list is in Edit mode with "User's Order" selected, **When** the user drags a project to a new position, **Then** the project moves to that position and the order is saved.
2. **Given** projects have been reordered by the user, **When** the user selects "User's Order" sorting, **Then** projects appear in the custom order.
3. **Given** the user has a custom order set, **When** they switch to other sort options and back to "User's Order", **Then** their custom order is preserved.

---

### Edge Cases
- How does the system handle deleting the last remaining project?
It simply displays an empty project list
- What if a user tries to rename a project to an empty string?
It should reject the attempt and ask the user to retry
- How does the app behave if there are no projects?
It should propmpt the user to create a project

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST allow users to add new projects.
- **FR-002**: System MUST allow users to delete existing projects.
- **FR-003**: System MUST allow users to rename projects.
- **FR-004**: System MUST display a list of all projects.
- **FR-005**: System MUST allow users to order the project list by name, creation date, or user's custom order.
- **FR-006**: System MUST display project details when selected.
- **FR-007**: System MUST prevent renaming a project to an empty name.
- **FR-008**: System MUST handle duplicate project names by alerting the user and asking them to retry.
- **FR-009**: System MUST allow users to drag projects to reorder them when in Edit mode and "User's Order" is selected.
- **FR-010**: System MUST save and persist the user's custom project order across app sessions.
- **FR-011**: System MUST only enable drag-to-reorder when "User's Order" sort option is active.

### Non-functional Requirements

- System must localize all relevant code
- Preview blocks (#Preview) must be disabled - no Xcode previews should be generated
- System must comply with Apple Accessibility Guidelines (WCAG 2.1 Level AA minimum):
  - **Accessibility Labels**: All interactive elements (buttons, text fields, navigation links) MUST have descriptive `accessibilityLabel` modifiers
  - **Accessibility Hints**: Interactive elements with non-obvious behavior MUST have `accessibilityHint` providing guidance (e.g., "Double tap to edit project name")
  - **Semantic Roles**: Buttons MUST use appropriate roles (`.destructive`, `.cancel`) to provide semantic meaning to screen readers
  - **Dynamic Type Support**: All text MUST support dynamic type scaling; avoid `.lineLimit(1)` on primary content, use `.lineLimit(.max)` instead
  - **Color Independence**: Information MUST NOT rely on color alone (e.g., validation errors must use both color and text labels)
  - **Grouped Elements**: Related elements MUST use `accessibilityElement(children: .combine)` to group them for screen readers
  - **Icon-Only Buttons**: Any icon-only button MUST have an accessibility label; purely decorative icons MUST be marked with `.accessibilityHidden(true)`
  - **Modal Dialogs**: Confirmation dialogs and alerts MUST have clear accessibility labels and focus management
  - **Form Fields**: Text input fields MUST have associated labels using `accessibilityLabel` describing their purpose

### Key Entities

- **Project**: Represents a user’s writing work. Key attributes: name, type, creation date, details. Each project is independent and stored in SwiftData. The followng project types are defined ealier in this document.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can add, delete, and rename projects without errors.
- **SC-002**: 100% of projects are displayed in the list after creation.
- **SC-003**: Users can order the project list and see changes instantly.
- **SC-004**: 95% of users successfully complete project management tasks (add, delete, rename, view details, reorder) on first attempt.
- **SC-005**: No crashes or data loss during project management actions.
- **SC-006**: All interactive elements have accessibility labels and hints; app passes automated accessibility audit with zero critical issues.
- **SC-007**: Users can drag to reorder projects and the custom order persists across app sessions.
- **SC-008**: Drag-to-reorder is only available when "User's Order" sort option is active and Edit mode is enabled.

## Assumptions

- All user data is stored locally using SwiftData.
- All data must use CloudKit to sync
- The app is single-user (no sharing or collaboration in this stage).
- Reasonable defaults are used for project ordering (alphabetical by name unless changed).
- Error messages are user-friendly and guide users to resolve issues.

