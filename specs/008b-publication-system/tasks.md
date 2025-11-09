# Feature 008b - Implementation Tasks

**Current Phase**: Phase 1 - Data Model & Core Infrastructure  
**Status**: Ready to Start  
**Updated**: 9 November 2025

---

## Phase 1: Data Model & Core Infrastructure

**Goal**: Set up all SwiftData models, enums, and framework dependencies needed for publication management.

**Duration**: 2 days  
**Dependencies**: Feature 008a complete ✅

---

### Task 1.1: Create Supporting Enums
**Status**: 🔲 Not Started  
**Estimated Time**: 15 minutes

#### Implementation
Create file: `Models/PublicationType.swift`
```swift
import Foundation

enum PublicationType: String, Codable {
    case magazine
    case competition
    
    var displayName: String {
        switch self {
        case .magazine: return "Magazine"
        case .competition: return "Competition"
        }
    }
    
    var icon: String {
        switch self {
        case .magazine: return "📰"
        case .competition: return "🏆"
        }
    }
}
```

Create file: `Models/SubmissionStatus.swift`
```swift
import Foundation

enum SubmissionStatus: String, Codable {
    case pending
    case accepted
    case rejected
    
    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .accepted: return "Accepted"
        case .rejected: return "Rejected"
        }
    }
    
    var icon: String {
        switch self {
        case .pending: return "⏳"
        case .accepted: return "✓"
        case .rejected: return "✗"
        }
    }
    
    var color: String {
        switch self {
        case .pending: return "orange"
        case .accepted: return "green"
        case .rejected: return "red"
        }
    }
}
```

#### Verification
- [ ] Both enums compile without errors
- [ ] Enums conform to Codable
- [ ] Display properties work correctly

---

### Task 1.2: Create Publication Model
**Status**: 🔲 Not Started  
**Estimated Time**: 30 minutes  
**Depends On**: Task 1.1

#### Implementation
Create file: `Models/Publication.swift`
```swift
import Foundation
import SwiftData

@Model
class Publication {
    var id: UUID
    var name: String
    var type: PublicationType
    var url: String?
    var notes: String?
    var deadline: Date?
    
    var project: Project
    var submissions: [Submission]
    
    var createdDate: Date
    var modifiedDate: Date
    
    init(
        id: UUID = UUID(),
        name: String,
        type: PublicationType,
        url: String? = nil,
        notes: String? = nil,
        deadline: Date? = nil,
        project: Project
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.url = url
        self.notes = notes
        self.deadline = deadline
        self.project = project
        self.submissions = []
        self.createdDate = Date()
        self.modifiedDate = Date()
    }
    
    // MARK: - Computed Properties
    
    var hasDeadline: Bool {
        deadline != nil
    }
    
    var daysUntilDeadline: Int? {
        guard let deadline = deadline else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: deadline).day
    }
    
    var isDeadlinePassed: Bool {
        guard let deadline = deadline else { return false }
        return deadline < Date()
    }
    
    var isDeadlineApproaching: Bool {
        guard let days = daysUntilDeadline else { return false }
        return days >= 0 && days < 7
    }
    
    var deadlineStatus: DeadlineStatus {
        guard hasDeadline else { return .none }
        if isDeadlinePassed { return .passed }
        if isDeadlineApproaching { return .approaching }
        return .future
    }
    
    enum DeadlineStatus {
        case none       // No deadline set
        case future     // More than 7 days away
        case approaching // Less than 7 days
        case passed     // Past deadline
    }
}
```

#### Verification
- [ ] Model compiles without errors
- [ ] @Model macro applied correctly
- [ ] All computed properties work
- [ ] Relationships defined (project, submissions)

---

### Task 1.3: Create Submission Model
**Status**: 🔲 Not Started  
**Estimated Time**: 20 minutes  
**Depends On**: Task 1.2

#### Implementation
Create file: `Models/Submission.swift`
```swift
import Foundation
import SwiftData

@Model
class Submission {
    var id: UUID
    var publication: Publication
    var project: Project
    
    var submittedFiles: [SubmittedFile]
    
    var submittedDate: Date
    var notes: String?
    
    var createdDate: Date
    var modifiedDate: Date
    
    init(
        id: UUID = UUID(),
        publication: Publication,
        project: Project,
        submittedDate: Date = Date(),
        notes: String? = nil
    ) {
        self.id = id
        self.publication = publication
        self.project = project
        self.submittedDate = submittedDate
        self.notes = notes
        self.submittedFiles = []
        self.createdDate = Date()
        self.modifiedDate = Date()
    }
    
    // MARK: - Computed Properties
    
    var fileCount: Int {
        submittedFiles.count
    }
    
    var pendingCount: Int {
        submittedFiles.filter { $0.status == .pending }.count
    }
    
    var acceptedCount: Int {
        submittedFiles.filter { $0.status == .accepted }.count
    }
    
    var rejectedCount: Int {
        submittedFiles.filter { $0.status == .rejected }.count
    }
    
    var overallStatus: OverallStatus {
        if acceptedCount == fileCount { return .allAccepted }
        if rejectedCount == fileCount { return .allRejected }
        if acceptedCount > 0 { return .partiallyAccepted }
        return .pending
    }
    
    enum OverallStatus {
        case pending
        case partiallyAccepted
        case allAccepted
        case allRejected
    }
}
```

#### Verification
- [ ] Model compiles without errors
- [ ] Relationships defined correctly
- [ ] Computed properties calculate correctly

---

### Task 1.4: Create SubmittedFile Model (Join Table)
**Status**: 🔲 Not Started  
**Estimated Time**: 30 minutes  
**Depends On**: Task 1.3

#### Implementation
Create file: `Models/SubmittedFile.swift`
```swift
import Foundation
import SwiftData

@Model
class SubmittedFile {
    var id: UUID
    var submission: Submission
    var textFile: TextFile
    var version: Version
    
    var status: SubmissionStatus
    var statusDate: Date?
    var statusNotes: String?
    
    var project: Project
    
    var createdDate: Date
    var modifiedDate: Date
    
    init(
        id: UUID = UUID(),
        submission: Submission,
        textFile: TextFile,
        version: Version,
        status: SubmissionStatus = .pending,
        statusDate: Date? = nil,
        statusNotes: String? = nil,
        project: Project
    ) {
        self.id = id
        self.submission = submission
        self.textFile = textFile
        self.version = version
        self.status = status
        self.statusDate = statusDate
        self.statusNotes = statusNotes
        self.project = project
        self.createdDate = Date()
        self.modifiedDate = Date()
    }
    
    // MARK: - Computed Properties
    
    var acceptanceDate: Date? {
        status == .accepted ? statusDate : nil
    }
    
    var rejectionDate: Date? {
        status == .rejected ? statusDate : nil
    }
    
    var daysSinceSubmission: Int {
        let endDate = statusDate ?? Date()
        return Calendar.current.dateComponents(
            [.day],
            from: submission.submittedDate,
            to: endDate
        ).day ?? 0
    }
    
    var responseTime: String {
        let days = daysSinceSubmission
        if days == 0 { return "Today" }
        if days == 1 { return "1 day" }
        if days < 7 { return "\(days) days" }
        let weeks = days / 7
        if weeks == 1 { return "1 week" }
        if days < 30 { return "\(weeks) weeks" }
        let months = days / 30
        if months == 1 { return "1 month" }
        return "\(months) months"
    }
}
```

#### Verification
- [ ] Model compiles without errors
- [ ] Join table relationships correct (submission, textFile, version)
- [ ] Response time calculation works
- [ ] Status-specific date properties work

---

### Task 1.5: Add Version Locking Support
**Status**: 🔲 Not Started  
**Estimated Time**: 30 minutes  
**Depends On**: Task 1.4

#### Implementation
Update existing file: `Models/Version.swift`

Add these computed properties:
```swift
// MARK: - Submission Locking

/// Returns true if this version is referenced by any active submission
var isLocked: Bool {
    // Note: This will be implemented when we have SwiftData context access
    // For now, this is a placeholder that returns false
    // In actual implementation, we'll query SubmittedFile records
    return false
}

/// Returns all submissions that reference this version
var referencingSubmissions: [SubmittedFile] {
    // Note: This will be implemented when we have SwiftData context access
    // For now, returns empty array
    // In actual implementation, we'll query SubmittedFile where version == self
    return []
}

/// Can this version be edited?
var canEdit: Bool {
    !isLocked
}

/// Can this version be deleted?
var canDelete: Bool {
    !isLocked
}

/// Reason why version is locked (for error messages)
var lockReason: String? {
    guard isLocked else { return nil }
    let submissions = referencingSubmissions
    if submissions.isEmpty { return nil }
    
    let publicationNames = submissions.map { $0.submission.publication.name }
    if publicationNames.count == 1 {
        return "This version is locked because it's part of a submission to \(publicationNames[0])."
    } else {
        return "This version is locked because it's part of \(publicationNames.count) submissions."
    }
}
```

#### Note
The actual implementation of `isLocked` and `referencingSubmissions` will require SwiftData context access. We'll implement the query logic in Phase 4 when we build the version locking service.

#### Verification
- [ ] Properties compile without errors
- [ ] Properties are computed (not stored)
- [ ] lockReason generates appropriate messages

---

### Task 1.6: Add EventKit Framework
**Status**: 🔲 Not Started  
**Estimated Time**: 15 minutes

#### Implementation Steps
1. Open Xcode project
2. Select project in navigator
3. Select "Writing Shed Pro" target
4. Go to "Frameworks, Libraries, and Embedded Content"
5. Click "+" button
6. Search for "EventKit"
7. Add "EventKit.framework"
8. Set to "Do Not Embed"

#### Update Info.plist
Add reminder usage description:

```xml
<key>NSRemindersUsageDescription</key>
<string>Writing Shed Pro uses Reminders to help you follow up on submissions and track publication deadlines. You can create optional reminders for submission follow-ups and approaching deadlines.</string>
```

#### Verification
- [ ] EventKit framework added to project
- [ ] Info.plist has NSRemindersUsageDescription
- [ ] Project still builds successfully
- [ ] No warnings or errors

---

### Task 1.7: Update Model Container
**Status**: 🔲 Not Started  
**Estimated Time**: 15 minutes  
**Depends On**: Tasks 1.2, 1.3, 1.4

#### Implementation
Update file: `Write_App.swift` (or wherever ModelContainer is configured)

Add new models to schema:
```swift
let schema = Schema([
    // Existing models
    Project.self,
    Folder.self,
    TextFile.self,
    Version.self,
    
    // NEW: Publication system models
    Publication.self,
    Submission.self,
    SubmittedFile.self
])
```

#### Verification
- [ ] App compiles with new models
- [ ] App launches without crashes
- [ ] SwiftData container initializes correctly
- [ ] No schema migration errors

---

### Task 1.8: Create Placeholder ReminderService
**Status**: 🔲 Not Started  
**Estimated Time**: 20 minutes  
**Depends On**: Task 1.6

#### Implementation
Create file: `Services/ReminderService.swift`

```swift
import Foundation
import EventKit

/// Service for creating iOS Reminders for submission follow-ups and deadlines
class ReminderService {
    private let eventStore = EKEventStore()
    
    // MARK: - Permission Handling
    
    /// Request access to Reminders
    func requestAccess() async throws -> Bool {
        return try await eventStore.requestAccess(to: .reminder)
    }
    
    // MARK: - Submission Reminders
    
    /// Create reminder for submission follow-up
    /// - Parameters:
    ///   - submission: The submission to create reminder for
    ///   - daysAfterSubmission: Number of days after submission date
    ///   - notes: Optional custom notes
    /// - Returns: The created reminder
    func createSubmissionReminder(
        for submission: Submission,
        daysAfterSubmission: Int,
        notes: String? = nil
    ) async throws -> EKReminder {
        // Verify permission
        guard try await requestAccess() else {
            throw ReminderError.permissionDenied
        }
        
        // Create reminder
        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = "Follow up: \(submission.publication.name)"
        reminder.notes = notes ?? "Check on submission status"
        reminder.calendar = eventStore.defaultCalendarForNewReminders()
        
        // Calculate due date
        let dueDate = Calendar.current.date(
            byAdding: .day,
            value: daysAfterSubmission,
            to: submission.submittedDate
        ) ?? Date()
        
        reminder.dueDateComponents = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: dueDate
        )
        
        // Save reminder
        try eventStore.save(reminder, commit: true)
        return reminder
    }
    
    // MARK: - Deadline Reminders
    
    /// Create reminder for publication deadline
    /// - Parameters:
    ///   - publication: The publication with deadline
    ///   - daysBefore: Number of days before deadline (0 = on deadline date)
    ///   - notes: Optional custom notes
    /// - Returns: The created reminder
    func createDeadlineReminder(
        for publication: Publication,
        daysBefore: Int,
        notes: String? = nil
    ) async throws -> EKReminder {
        guard let deadline = publication.deadline else {
            throw ReminderError.noDeadline
        }
        
        // Verify permission
        guard try await requestAccess() else {
            throw ReminderError.permissionDenied
        }
        
        // Create reminder
        let reminder = EKReminder(eventStore: eventStore)
        
        if daysBefore == 0 {
            reminder.title = "Deadline Today: \(publication.name)"
            reminder.notes = notes ?? "Submission deadline is today"
        } else {
            reminder.title = "Deadline: \(publication.name)"
            reminder.notes = notes ?? "Submission deadline in \(daysBefore) days"
        }
        
        reminder.calendar = eventStore.defaultCalendarForNewReminders()
        
        // Calculate reminder date
        let reminderDate = Calendar.current.date(
            byAdding: .day,
            value: -daysBefore,
            to: deadline
        ) ?? Date()
        
        reminder.dueDateComponents = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: reminderDate
        )
        
        // Save reminder
        try eventStore.save(reminder, commit: true)
        return reminder
    }
}

// MARK: - Errors

enum ReminderError: LocalizedError {
    case permissionDenied
    case noDeadline
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Permission to access Reminders was denied. Please enable in Settings."
        case .noDeadline:
            return "This publication has no deadline set."
        }
    }
}
```

#### Verification
- [ ] Service compiles without errors
- [ ] EventKit imports successfully
- [ ] Error types defined
- [ ] Methods have proper async/throws signatures

---

## Phase 1 Completion Checklist

Before moving to Phase 2, verify:

- [ ] ✅ All 8 tasks completed
- [ ] ✅ All models compile without errors
- [ ] ✅ App launches successfully
- [ ] ✅ SwiftData container includes new models
- [ ] ✅ EventKit framework added
- [ ] ✅ Info.plist has reminder usage description
- [ ] ✅ No warnings or errors in console
- [ ] ✅ Models show in SwiftData preview (optional)

---

## Next Phase

Once Phase 1 is complete, we'll move to **Phase 2: Publications Management UI** which includes:
- PublicationsListView
- PublicationFormView
- PublicationDetailView

---

**Ready to Start?** Begin with Task 1.1 and work through sequentially. Each task builds on the previous one.
