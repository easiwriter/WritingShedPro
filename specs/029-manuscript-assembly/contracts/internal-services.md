# Feature 029: Internal Service Contracts

**Date**: 2026-01-10  
**Purpose**: Define internal Swift protocols for Manuscript Assembly services

---

## 1. ManuscriptAssemblyServiceProtocol

```swift
import Foundation
import SwiftData

/// Protocol defining the manuscript assembly service interface
protocol ManuscriptAssemblyServiceProtocol {
    
    /// Get all sections for a project's manuscript
    /// - Parameter project: The project to get sections for
    /// - Returns: Array of ManuscriptSection in assembly order
    func getSections(for project: Project) -> [ManuscriptSection]
    
    /// Get the source folder for body content based on project type
    /// - Parameter project: The project to get source folder for
    /// - Returns: The folder containing body content (Poems, Scenes, etc.)
    func getBodySourceFolder(for project: Project) -> Folder?
    
    /// Assemble the complete manuscript content
    /// - Parameter project: The project to assemble
    /// - Returns: ManuscriptContent with assembled attributed string
    /// - Throws: AssemblyError if assembly fails
    func assembleContent(for project: Project) async throws -> ManuscriptContent
    
    /// Calculate page layout for assembled content
    /// - Parameters:
    ///   - content: The assembled manuscript content
    ///   - pageSetup: Page layout configuration
    /// - Returns: ManuscriptContent with pageMap populated
    func calculateLayout(
        for content: ManuscriptContent,
        pageSetup: PageSetup
    ) -> ManuscriptContent
}
```

---

## 2. TOCGeneratorServiceProtocol

```swift
import Foundation

/// Protocol defining the Table of Contents generation service
protocol TOCGeneratorServiceProtocol {
    
    /// Generate TOC entries from manuscript sections
    /// - Parameters:
    ///   - sections: The manuscript sections
    ///   - pageMap: Map of file IDs to page numbers
    ///   - settings: TOC formatting settings
    /// - Returns: Array of TOCEntry in order
    func generateEntries(
        from sections: [ManuscriptSection],
        pageMap: [UUID: Int],
        settings: TOCSettings
    ) -> [TOCEntry]
    
    /// Generate formatted TOC attributed string
    /// - Parameters:
    ///   - entries: The TOC entries
    ///   - settings: TOC formatting settings
    /// - Returns: Formatted attributed string for the TOC
    func formatTOC(
        entries: [TOCEntry],
        settings: TOCSettings
    ) -> NSAttributedString
    
    /// Generate complete TableOfContents
    /// - Parameters:
    ///   - sections: The manuscript sections
    ///   - pageMap: Map of file IDs to page numbers
    ///   - settings: TOC settings
    ///   - pageSetup: Page layout for estimating TOC page count
    /// - Returns: Complete TableOfContents struct
    func generateTableOfContents(
        from sections: [ManuscriptSection],
        pageMap: [UUID: Int],
        settings: TOCSettings,
        pageSetup: PageSetup
    ) -> TableOfContents
}
```

---

## 3. ManuscriptExportServiceProtocol

```swift
import Foundation
import SwiftData

/// Protocol defining the manuscript export service
protocol ManuscriptExportServiceProtocol {
    
    /// Export manuscript to PDF format
    /// - Parameters:
    ///   - content: Assembled manuscript content
    ///   - project: Project for settings
    ///   - options: Export options
    /// - Returns: PDF data
    /// - Throws: AssemblyError.exportFailed if export fails
    func exportToPDF(
        content: ManuscriptContent,
        project: Project,
        options: ExportOptions
    ) async throws -> Data
    
    /// Export manuscript to RTF format
    /// - Parameters:
    ///   - content: Assembled manuscript content
    ///   - options: Export options
    /// - Returns: RTF data
    /// - Throws: AssemblyError.exportFailed if export fails
    func exportToRTF(
        content: ManuscriptContent,
        options: ExportOptions
    ) async throws -> Data
    
    /// Export manuscript to plain text
    /// - Parameters:
    ///   - content: Assembled manuscript content
    ///   - options: Export options
    /// - Returns: Plain text data (UTF-8)
    /// - Throws: AssemblyError.exportFailed if export fails
    func exportToPlainText(
        content: ManuscriptContent,
        options: ExportOptions
    ) async throws -> Data
    
    /// Export manuscript to Word (.docx) format
    /// - Parameters:
    ///   - content: Assembled manuscript content
    ///   - options: Export options
    /// - Returns: DOCX data
    /// - Throws: AssemblyError.exportFailed if export fails
    func exportToWord(
        content: ManuscriptContent,
        options: ExportOptions
    ) async throws -> Data
    
    /// Export using specified format
    /// - Parameters:
    ///   - content: Assembled manuscript content
    ///   - project: Project for PDF settings
    ///   - options: Export options including format
    /// - Returns: Data in requested format
    /// - Throws: AssemblyError.exportFailed if export fails
    func export(
        content: ManuscriptContent,
        project: Project,
        options: ExportOptions
    ) async throws -> Data
}
```

---

## 4. ManuscriptPreviewProviderProtocol

```swift
import Foundation
import SwiftData

/// Protocol for providing manuscript preview data
protocol ManuscriptPreviewProviderProtocol {
    
    /// Generate preview content for a project
    /// - Parameter project: The project to preview
    /// - Returns: ManuscriptContent ready for display
    /// - Throws: AssemblyError if preview generation fails
    func generatePreview(for project: Project) async throws -> ManuscriptContent
    
    /// Update preview after file changes
    /// - Parameters:
    ///   - project: The project
    ///   - changedFiles: Files that were modified
    func invalidateCache(for project: Project, changedFiles: [TextFile]?)
    
    /// Get cached preview if available
    /// - Parameter project: The project
    /// - Returns: Cached content or nil
    func getCachedPreview(for project: Project) -> ManuscriptContent?
}
```

---

## 5. Usage Notes

### Dependency Injection Pattern

```swift
// In views, inject via Environment or init
struct ManuscriptBodyView: View {
    let assemblyService: ManuscriptAssemblyServiceProtocol
    
    // Or use concrete type since these are internal services
    let assemblyService: ManuscriptAssemblyService
}
```

### Testing with Protocols

```swift
// Mock implementation for testing
final class MockManuscriptAssemblyService: ManuscriptAssemblyServiceProtocol {
    var sectionsToReturn: [ManuscriptSection] = []
    var contentToReturn: ManuscriptContent?
    var shouldThrowError = false
    
    func getSections(for project: Project) -> [ManuscriptSection] {
        return sectionsToReturn
    }
    
    func assembleContent(for project: Project) async throws -> ManuscriptContent {
        if shouldThrowError {
            throw AssemblyError.noFilesFound
        }
        guard let content = contentToReturn else {
            throw AssemblyError.noFilesFound
        }
        return content
    }
    
    // ... other methods
}
```

### Implementation Order

1. Implement `ManuscriptAssemblyServiceProtocol` first (Phase 2)
2. Implement `ManuscriptExportServiceProtocol` (Phase 5)
3. Implement `TOCGeneratorServiceProtocol` (Phase 7)
4. `ManuscriptPreviewProviderProtocol` is optional caching layer
