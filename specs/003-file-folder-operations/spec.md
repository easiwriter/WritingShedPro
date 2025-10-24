# Feature Specification: File and Folder Operations

**Feature Branch**: `003-file-folder-operations`  
**Created**: 23 October 2025  
**Status**: Draft  
**Dependencies**: [002-folder-file-management](../002-folder-file-management/spec.md)  
**Input**: User description: "The next phase is to be able to add files and folders to the current folders and to be able to sort and move files and folders about. Only folders can be added to the folders in Publications, and to Collections, Submissions and Research. Only files can be added to Draft. The All folder contains links to all files. Files can be moved between Draft, Ready and Set Aside."

## Context

This feature operates on the folder hierarchy established in Phase 002, which creates project-type-specific folder structures for all 5 project types (`blank`, `novel`, `poetry`, `script`, `short story`). The hierarchy rules defined here apply universally across all project types.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Add Files and Folders (Priority: P1)

A user creates new files and folders within the project structure, following the folder hierarchy rules (folders only in Publications/Collections/Submissions/Research, files only in Draft).

**Why this priority**: Creating content is the foundation of any writing workflow and must respect the established folder structure.

**Independent Test**: Can be fully tested by creating files in Draft and folders in appropriate locations, verifying they appear correctly and follow hierarchy rules.

**Acceptance Scenarios**:

1. **Given** a project is open, **When** the user adds a file to Draft, **Then** the file is created and visible in Draft and All folders.
2. **Given** a project is open, **When** the user tries to add a folder to a folder in Publications, **Then** the folder is created successfully.
3 **Given** a project is open, **then** the user does not have the option to add a file to a folder in Publications.
4. **Given** a project is open, **When** the user tries to add a folder to Collections, Submissions or Research, **Then** the folder is created successfully.
5. **Given** a project is open, **then** the user does not have the option to add a file to Collections, Submissions or Research
6. **Given** a project is open, **then** a file/folder can only be added to Trash by a delete operation applied to file(s)/folder(s) in one of the project folders
---

### User Story 2 - Move Files Between Workflow States (Priority: P2)

A user moves files between Draft, Ready, and Set Aside folders to manage their writing workflow and track file status.

**Why this priority**: File movement between workflow states is essential for managing writing progress and organization.

**Independent Test**: Can be tested by moving files between the three workflow folders and verifying they appear in the correct location.

**Acceptance Scenarios**:

1. **Given** a file exists in Draft, **When** the user moves it to Ready or Set Aside, **Then** the file appears in Ready or Set Aside and disappears from Draft.
2. **Given** a file exists in Ready, **When** the user moves it to Set Aside, **Then** the file appears in Set Aside and disappears from Ready.
3. **Given** a file exists in Set Aside, **When** the user moves it to Ready or Draft, **Then** the file appears in Ready/Draft and disappears from Set Aside.
4. **Given** files exist in Draft & Ready & Set Aside folders, **When** the user views All folder, **Then** all files are visible with their current location indicated.

---

### User Story 3 - Sort and Organize Files and Folders (Priority: P3)

A user sorts and arranges files and folders within each location to maintain an organized workspace.

**Why this priority**: Organization capabilities improve productivity and help users find content efficiently.

**Independent Test**: Can be tested by reordering items and verifying the new arrangement persists.

**Acceptance Scenarios**:

1. **Given** multiple files exist in a folder, **When** the user sorts by name, **Then** files are arranged alphabetically.
2. **Given** multiple files exist in a folder, **When** the user sorts by date, **Then** files are arranged by creation or modification date.
3. **Given** files and folders exist, **When** the user manually reorders them, **Then** the custom order is maintained.

---

### Edge Cases

- What happens when trying to move a file to an invalid location?
- How does the system handle moving files with duplicate names?
- What occurs when the All folder becomes very large with many files?
- How are nested folders within allowed locations handled?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST allow adding files only to the Draft folder.
- **FR-002**: System MUST allow adding folders only to Publications, Collections, Submissions, and Research folders.
- **FR-003**: System MUST prevent adding files to Publications, Collections, Submissions, and Research folders.
- **FR-004**: System MUST prevent adding folders to Draft, Ready, and Set Aside folders.
- **FR-005**: System MUST allow moving files between Draft, Ready, and Set Aside folders.
- **FR-006**: System MUST update the All folder to reflect all files regardless of their location.
- **FR-007**: System MUST support sorting files and folders by name and date.
- **FR-008**: System MUST support manual reordering of files and folders.
- **FR-009**: System MUST provide clear feedback when operations violate folder hierarchy rules.

### Key Entities

- **File**: Document with content, belongs to one workflow folder (Draft, Ready, Set Aside) and appears in All folder. Key attributes: name, content, creation date, current location.
- **Folder**: Container for files or other folders, depending on location. Key attributes: name, location, parent folder, creation date.
- **Workflow Folders**: Special system folders (Draft, Ready, Set Aside) that manage file workflow states.
- **Organization Folders**: Special system folders (Publications, Collections, Submissions, Research) that contain subfolders for organization.
- **All Folder**: Virtual folder that provides links to all files across the project.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can create files and folders without errors when following hierarchy rules.
- **SC-002**: 100% of file movement operations between workflow folders succeed without data loss.
- **SC-003**: All folder accurately reflects all files in the project at all times.
- **SC-004**: Folder hierarchy rules are enforced with 100% accuracy.
- **SC-005**: Users can sort and organize content with changes persisting across app sessions.
- **SC-006**: 95% of users successfully organize their content using the folder structure on first attempt.

## Assumptions

- The basic project structure with predefined folders (Draft, Ready, Set Aside, Publications, Collections, Submissions, Research, All) already exists from the previous phase.
- File operations maintain data integrity and sync across devices via CloudKit.
- The app supports both iOS and MacCatalyst platforms.
- Users understand the writing workflow concept of moving files through Draft → Ready → Set Aside.
- Folder hierarchy rules are designed to maintain a clean, purpose-driven organization system.

## User Scenarios & Testing *(mandatory)*

<!--
  IMPORTANT: User stories should be PRIORITIZED as user journeys ordered by importance.
  Each user story/journey must be INDEPENDENTLY TESTABLE - meaning if you implement just ONE of them,
  you should still have a viable MVP (Minimum Viable Product) that delivers value.
  
  Assign priorities (P1, P2, P3, etc.) to each story, where P1 is the most critical.
  Think of each story as a standalone slice of functionality that can be:
  - Developed independently
  - Tested independently
  - Deployed independently
  - Demonstrated to users independently
-->

### User Story 1 - [Brief Title] (Priority: P1)

[Describe this user journey in plain language]

**Why this priority**: [Explain the value and why it has this priority level]

**Independent Test**: [Describe how this can be tested independently - e.g., "Can be fully tested by [specific action] and delivers [specific value]"]

**Acceptance Scenarios**:

1. **Given** [initial state], **When** [action], **Then** [expected outcome]
2. **Given** [initial state], **When** [action], **Then** [expected outcome]

---

### User Story 2 - [Brief Title] (Priority: P2)

[Describe this user journey in plain language]

**Why this priority**: [Explain the value and why it has this priority level]

**Independent Test**: [Describe how this can be tested independently]

**Acceptance Scenarios**:

1. **Given** [initial state], **When** [action], **Then** [expected outcome]

---

### User Story 3 - [Brief Title] (Priority: P3)

[Describe this user journey in plain language]

**Why this priority**: [Explain the value and why it has this priority level]

**Independent Test**: [Describe how this can be tested independently]

**Acceptance Scenarios**:

1. **Given** [initial state], **When** [action], **Then** [expected outcome]

---

[Add more user stories as needed, each with an assigned priority]

### Edge Cases

<!--
  ACTION REQUIRED: The content in this section represents placeholders.
  Fill them out with the right edge cases.
-->

- What happens when [boundary condition]?
- How does system handle [error scenario]?

## Requirements *(mandatory)*

<!--
  ACTION REQUIRED: The content in this section represents placeholders.
  Fill them out with the right functional requirements.
-->

### Functional Requirements

- **FR-001**: System MUST [specific capability, e.g., "allow users to create accounts"]
- **FR-002**: System MUST [specific capability, e.g., "validate email addresses"]  
- **FR-003**: Users MUST be able to [key interaction, e.g., "reset their password"]
- **FR-004**: System MUST [data requirement, e.g., "persist user preferences"]
- **FR-005**: System MUST [behavior, e.g., "log all security events"]

*Example of marking unclear requirements:*

- **FR-006**: System MUST authenticate users via [NEEDS CLARIFICATION: auth method not specified - email/password, SSO, OAuth?]
- **FR-007**: System MUST retain user data for [NEEDS CLARIFICATION: retention period not specified]

### Key Entities *(include if feature involves data)*

- **[Entity 1]**: [What it represents, key attributes without implementation]
- **[Entity 2]**: [What it represents, relationships to other entities]

## Success Criteria *(mandatory)*

<!--
  ACTION REQUIRED: Define measurable success criteria.
  These must be technology-agnostic and measurable.
-->

### Measurable Outcomes

- **SC-001**: [Measurable metric, e.g., "Users can complete account creation in under 2 minutes"]
- **SC-002**: [Measurable metric, e.g., "System handles 1000 concurrent users without degradation"]
- **SC-003**: [User satisfaction metric, e.g., "90% of users successfully complete primary task on first attempt"]
- **SC-004**: [Business metric, e.g., "Reduce support tickets related to [X] by 50%"]

