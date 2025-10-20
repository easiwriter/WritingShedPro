
<!--
Sync Impact Report
Version change: 1.0.0 → 1.1.0
Modified principles: replaced all with new focus (see below)
Added sections: None
Removed sections: None
Templates requiring updates: 
	- plan-template.md ✅
	- spec-template.md ✅
	- tasks-template.md ✅
Follow-up TODOs: None
-->

# Write Project Constitution

## Core Principles

### I. Code Quality
All code MUST be readable, maintainable, and follow agreed style guides. Code reviews are mandatory for all changes. No code is merged without at least one peer review. All code must be commented and be fully localisable.

**Rationale**: High code quality reduces defects, improves onboarding, and ensures long-term maintainability.

### II. Testing Standards
All features MUST include automated tests. Tests MUST cover critical paths and edge cases. No feature is considered complete without passing tests. Continuous integration MUST run all tests on every commit to main branches.

**Rationale**: Testing prevents regressions, increases confidence in releases, and enables safe refactoring.

### III. User Experience Consistency
The user interface and interactions MUST be consistent across platforms. All user-facing changes MUST be reviewed for usability and accessibility. User feedback MUST be incorporated into iterative improvements.

**Rationale**: Consistency and accessibility drive user satisfaction and reduce confusion.

### IV. Performance Requirements
The application MUST meet defined performance targets for responsiveness and resource usage. Performance regressions are not permitted without explicit review and mitigation plan. All features MUST be profiled and optimized as needed before release.

**Rationale**: Good performance is essential for user retention and platform compliance.

## Additional Constraints

- All dependencies MUST be approved and tracked.
- Security best practices MUST be followed for all code and data.

## Development Workflow

- All work MUST be tracked via issues and linked to user stories.
- Pull requests MUST reference relevant tasks and user stories.
- Releases MUST follow semantic versioning.

## Governance

This constitution supersedes all other practices. Amendments require documentation, approval by project maintainers, and a migration plan if breaking changes are introduced. All PRs and reviews MUST verify compliance with these principles. Constitution versioning follows semantic versioning: MAJOR for breaking changes, MINOR for new principles or sections, PATCH for clarifications or non-semantic edits.

**Version**: 1.1.0 | **Ratified**: TODO(RATIFICATION_DATE): original adoption date unknown | **Last Amended**: 2025-10-20
