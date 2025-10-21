# Research: Project Management (iOS/MacOS)

## Decision: Use SwiftData for local storage
- **Rationale**: SwiftData is the modern Apple framework for local persistence, fully integrated with SwiftUI and optimized for iOS/macOS. It supports object graph management and is recommended for new projects.

## Decision: Use CloudKit for sync
- **Rationale**: CloudKit is the Apple-recommended solution for syncing user data across devices. It is secure, privacy-focused, and works seamlessly with SwiftData.

## Decision: Test Driven Development (TDD) with XCTest
- **Rationale**: XCTest is the standard for Swift projects. TDD ensures all features are testable and robust, aligning with project constitution and Apple best practices.

## Decision: Project structure
- **Rationale**: Separate platform-specific code (ios/, macos/) and shared modules for models/services maximizes code reuse and maintainability. Tests are organized by type for clarity.

## Decision: Project types (prose, poetry, drama)
- **Rationale**: Supporting multiple project types from the start allows for future extensibility and clear user flows. Each type can have tailored file/folder structures.

## Decision: Localization support
- **Rationale**: SwiftUI and Xcode provide built-in localization via `.strings` files and the `LocalizedStringResource` macro. All user-facing text must use localization keys to support multiple languages and meet non-functional requirements.

