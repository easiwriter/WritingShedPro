# Feature Specification: Word Count and Line Count

**Phase**: 007  
**Feature**: `007-word-line-count`  
**Created**: 6 November 2025  
**Status**: 📝 Draft  
**Previous Phase**: [006-image-support](../006-image-support/spec.md)  
**Input**: User requirement: "Add Word Count to all project types and files, and line count to Poetry files (excluding blank lines)"

## Overview

This feature adds statistics tracking to projects and files:
- **Word Count**: Displayed for all project types (Blank, Novel, Poetry, Script, Short Story) and individual text files
- **Line Count**: Displayed for Poetry project types and Poetry files only, excluding blank lines

## User Scenarios & Testing *(mandatory)*

### User Story 1 - View Word Count on Files (Priority: P1)

A user opens a text file and sees the current word count displayed in the UI.

**Why this priority**: Word count is essential for writers to track their progress and meet writing goals.

**Independent Test**: Can be tested by creating a file with known content and verifying the word count is accurate.

**Acceptance Scenarios**:

1. **Given** a text file with content, **When** the user views the file, **Then** an accurate word count is displayed.
2. **Given** a user types or deletes text, **When** the content changes, **Then** the word count updates in real-time.
3. **Given** a file contains formatted text with bold, italic, or images, **When** the word count is calculated, **Then** only actual text words are counted (not formatting codes or image markers).

---

### User Story 2 - View Word Count on Projects (Priority: P1)

A user views a project and sees the total word count across all files in the project.

**Why this priority**: Writers need to track total progress across their entire project.

**Independent Test**: Can be tested by creating a project with multiple files and verifying the total word count sums all file word counts.

**Acceptance Scenarios**:

1. **Given** a project with multiple files, **When** the user views the project, **Then** the total word count across all files is displayed.
2. **Given** a user adds or removes files, **When** the project view refreshes, **Then** the total word count updates accordingly.
3. **Given** a user edits a file within a project, **When** they return to the project view, **Then** the project's total word count reflects the changes.

---

### User Story 3 - View Line Count on Poetry Files (Priority: P2)

A user working on a Poetry project or file sees both word count and line count, with blank lines excluded from the line count.

**Why this priority**: Poets often track their work by lines rather than words, and blank lines are typically excluded from official line counts.

**Independent Test**: Can be tested by creating a Poetry file with known lines (including blank lines) and verifying the line count excludes blank lines.

**Acceptance Scenarios**:

1. **Given** a Poetry file with text and blank lines, **When** the user views the file, **Then** the line count displays only non-blank lines.
2. **Given** a user adds or removes lines, **When** the content changes, **Then** the line count updates in real-time.
3. **Given** a line contains only whitespace (spaces, tabs), **When** the line count is calculated, **Then** that line is considered blank and excluded.

---

### User Story 4 - View Line Count on Poetry Projects (Priority: P2)

A user views a Poetry project and sees the total line count across all files in the project.

**Why this priority**: Poets need to track total progress across their poetry collection.

**Independent Test**: Can be tested by creating a Poetry project with multiple files and verifying the total line count sums all file line counts (excluding blank lines).

**Acceptance Scenarios**:

1. **Given** a Poetry project with multiple files, **When** the user views the project, **Then** the total line count (excluding blank lines) is displayed.
2. **Given** a user adds or removes files, **When** the project view refreshes, **Then** the total line count updates accordingly.

---

### Edge Cases

- How does the system handle files with only whitespace or blank lines?
  - Word count: 0 words
  - Line count (Poetry): 0 lines
- What if a file contains embedded images or special formatting?
  - Images and formatting codes are excluded from word count
  - Images don't affect line count
- How are hyphenated words counted?
  - "Twenty-five" counts as one word (standard word count rules)
- How are contractions counted?
  - "Don't" counts as one word
- What about numbers?
  - Numbers like "42" or "2025" count as words
- How are multiple spaces handled?
  - Multiple spaces are treated as single word separators
- What defines a blank line?
  - A line with no characters, or only whitespace (spaces, tabs, newlines)

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST display word count for all text files regardless of project type.
- **FR-002**: System MUST display total word count for all projects (sum of all files).
- **FR-003**: System MUST update word count in real-time as user types or edits text.
- **FR-004**: System MUST display line count (excluding blank lines) for Poetry project files.
- **FR-005**: System MUST display total line count (excluding blank lines) for Poetry projects.
- **FR-006**: System MUST update line count in real-time as user types or edits text in Poetry files.
- **FR-007**: System MUST exclude formatting codes, images, and embedded objects from word count.
- **FR-008**: System MUST consider a line blank if it contains only whitespace characters (spaces, tabs, newlines).
- **FR-009**: Word count MUST follow standard writing industry rules:
  - Hyphenated words count as one word
  - Contractions count as one word
  - Numbers count as words
  - Multiple spaces treated as single separator
- **FR-010**: System MUST display counts in a clear, non-intrusive location in the UI.
- **FR-011**: For non-Poetry projects, line count MUST NOT be displayed (only word count).

### Non-functional Requirements

- **NFR-001**: Word count calculation MUST complete within 100ms for files up to 100,000 words.
- **NFR-002**: Real-time updates MUST not cause UI lag or stuttering during typing.
- **NFR-003**: Count calculations MUST use efficient algorithms to avoid performance impact.
- **NFR-004**: Counts MUST be accurate within ±1 word/line for edge cases (formatting boundaries).
- **NFR-005**: System MUST handle files up to 500,000 words without performance degradation.
- **NFR-006**: All count displays MUST support localization (e.g., "1,000 words" vs "1.000 Wörter").
- **NFR-007**: Count displays MUST be accessible with proper accessibility labels for screen readers.
- **NFR-008**: System MUST use number formatters appropriate for user's locale.

### Key Entities

- **WordCountService**: Service responsible for calculating word counts from NSAttributedString
- **LineCountService**: Service responsible for calculating line counts (excluding blank lines) from text
- **FileStatistics**: Value type containing word count and optional line count for a file
- **ProjectStatistics**: Value type containing aggregated word count and optional line count for a project

## UI/UX Design *(mandatory)*

### Word Count Display Locations

1. **File Editor View**:
   - Location: Bottom of editor or toolbar
   - Format: "### words" (e.g., "1,234 words")
   - For Poetry files: "### words | ### lines" (e.g., "342 words | 28 lines")
   - Updates in real-time as user types

2. **Project Detail View**:
   - Location: In project information section
   - Format: "Total: ### words" (e.g., "Total: 45,678 words")
   - For Poetry projects: "Total: ### words | ### lines" (e.g., "Total: 2,834 words | 156 lines")

3. **Project List Item** (Optional enhancement):
   - Location: Subtitle below project name
   - Format: "### words" (e.g., "12,543 words")
   - For Poetry: "### lines" (e.g., "423 lines") - prioritize line count for poetry

### Visual Design

- **Typography**: Use secondary text color (gray) to avoid distraction
- **Font Size**: Smaller than body text (e.g., `.caption` or `.footnote`)
- **Position**: Non-intrusive, bottom-right or status bar position
- **Animation**: Smooth update without jarring UI changes
- **Number Formatting**: Use locale-appropriate thousand separators

### Accessibility

- **Accessibility Label**: "Word count: 1,234 words" (read by VoiceOver)
- **For Poetry**: "Word count: 342 words, Line count: 28 lines"
- **Updates**: Announce updates only on significant changes (not every character)
- **Semantic Role**: Use `.accessibilityElement(children: .combine)` for grouped statistics

## Technical Design *(mandatory)*

### Word Count Algorithm

```swift
func countWords(in attributedString: NSAttributedString) -> Int {
    let text = attributedString.string
    
    // Remove leading/trailing whitespace
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    
    // Handle empty string
    if trimmed.isEmpty {
        return 0
    }
    
    // Split by whitespace and newlines
    let words = trimmed.components(separatedBy: .whitespacesAndNewlines)
    
    // Filter out empty components
    let nonEmptyWords = words.filter { !$0.isEmpty }
    
    return nonEmptyWords.count
}
```

### Line Count Algorithm (Poetry)

```swift
func countNonBlankLines(in text: String) -> Int {
    let lines = text.components(separatedBy: .newlines)
    
    // Filter out blank lines (empty or only whitespace)
    let nonBlankLines = lines.filter { line in
        !line.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    return nonBlankLines.count
}
```

### Performance Optimization

- **Debouncing**: Delay count updates by 200-300ms after user stops typing
- **Background Calculation**: For large files (>50,000 words), calculate on background queue
- **Caching**: Cache counts and only recalculate when text actually changes
- **Incremental Updates**: For real-time updates, only recalculate affected sections if possible

### Data Models

```swift
struct FileStatistics {
    let wordCount: Int
    let lineCount: Int?  // Only for Poetry files
    
    var displayString: String {
        if let lineCount = lineCount {
            return "\(formattedWordCount) words | \(formattedLineCount) lines"
        } else {
            return "\(formattedWordCount) words"
        }
    }
    
    private var formattedWordCount: String {
        NumberFormatter.localizedString(from: NSNumber(value: wordCount), number: .decimal)
    }
    
    private var formattedLineCount: String {
        NumberFormatter.localizedString(from: NSNumber(value: lineCount ?? 0), number: .decimal)
    }
}

struct ProjectStatistics {
    let totalWordCount: Int
    let totalLineCount: Int?  // Only for Poetry projects
    let fileCount: Int
    
    init(files: [TextFile], projectType: ProjectType) {
        let allStats = files.map { FileStatistics(from: $0) }
        
        self.totalWordCount = allStats.reduce(0) { $0 + $1.wordCount }
        self.fileCount = files.count
        
        if projectType == .poetry {
            self.totalLineCount = allStats.reduce(0) { $0 + ($1.lineCount ?? 0) }
        } else {
            self.totalLineCount = nil
        }
    }
}
```

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Word count is displayed accurately for 100% of files with ±1 word tolerance.
- **SC-002**: Line count (for Poetry) is displayed accurately for 100% of files with ±1 line tolerance.
- **SC-003**: Word count updates within 100ms of user stopping typing for files <100,000 words.
- **SC-004**: No performance degradation (lag, stuttering) during real-time updates.
- **SC-005**: 95% of users can easily locate and read word/line counts in the UI.
- **SC-006**: All count displays pass accessibility audit with proper labels and announcements.
- **SC-007**: Project total counts accurately sum all file counts.
- **SC-008**: Blank lines are correctly excluded from Poetry line counts 100% of the time.

## Testing Strategy *(mandatory)*

### Unit Tests

1. **WordCountService Tests**:
   - Empty string → 0 words
   - Single word → 1 word
   - Multiple words with spaces → correct count
   - Hyphenated words → 1 word
   - Contractions → 1 word
   - Numbers → counted as words
   - Multiple spaces → correct count
   - Text with newlines → correct count
   - Text with tabs → correct count
   - Text with formatting (bold, italic) → correct count
   - Text with embedded images → images excluded

2. **LineCountService Tests** (Poetry):
   - Empty string → 0 lines
   - Single line → 1 line
   - Multiple lines → correct count
   - Lines with only whitespace → excluded
   - Lines with only tabs → excluded
   - Lines with text → included
   - Mixed blank and non-blank lines → correct count
   - Trailing newlines → handled correctly

3. **FileStatistics Tests**:
   - Statistics calculation from TextFile
   - Display string formatting (with/without line count)
   - Locale-specific number formatting

4. **ProjectStatistics Tests**:
   - Aggregation across multiple files
   - Poetry project includes line count
   - Non-poetry project excludes line count
   - Empty project (no files) → 0 words, 0 lines

### Integration Tests

1. **Real-time Update Tests**:
   - Type text → count updates
   - Delete text → count decreases
   - Paste text → count updates correctly
   - Undo/redo → count reflects current state

2. **Project Total Tests**:
   - Add file to project → total increases
   - Delete file from project → total decreases
   - Edit file → project total updates

3. **Performance Tests**:
   - Large file (100,000 words) → count within 100ms
   - Real-time updates don't cause lag
   - Background calculation doesn't block UI

### UI Tests

1. Word count displays in file editor
2. Word count displays in project details
3. Line count displays for Poetry files
4. Line count displays for Poetry projects
5. Line count does NOT display for non-Poetry files/projects
6. Numbers are formatted with locale-appropriate separators

## Assumptions

- Word count follows standard English writing rules (adaptable for other languages)
- Line count is only relevant for Poetry project type
- Real-time updates are preferred over manual refresh
- Performance is critical - no UI lag during typing
- Counts don't need to be persisted (calculated on-demand from text content)
- Very large files (>500,000 words) are rare but must be handled gracefully

## Dependencies

- **TextFile model**: Must have access to text content (NSAttributedString)
- **Project model**: Must be able to enumerate all files in project
- **ProjectType enum**: Must distinguish Poetry from other types
- **Number formatting**: Must use locale-aware number formatters
- **Performance**: May require background queue for large file calculations

## Open Questions

1. Should word count include footnotes, endnotes, or comments?
   - **Decision**: Count only main text content, exclude metadata
   
2. Should counts be displayed in real-time or after a delay?
   - **Decision**: Use debouncing (200-300ms delay) to avoid constant recalculation
   
3. Where exactly should counts be displayed in the UI?
   - **Decision**: Bottom of editor / status bar area, project info section
   
4. Should counts be saved to the database or calculated on-demand?
   - **Decision**: Calculate on-demand from text content (simpler, always accurate)
   
5. Should project list show word/line counts?
   - **Decision**: Optional enhancement, not required for initial implementation

## Future Enhancements

- **Word count goals**: Set target word counts and track progress
- **Session statistics**: Track words written in current session
- **Historical trends**: Graph word count over time
- **Character count**: Display character count alongside word count
- **Reading time estimate**: Calculate estimated reading time based on word count
- **Export statistics**: Export statistics to CSV or other formats
- **Folder statistics**: Show word/line counts for folders (sum of contained files)
