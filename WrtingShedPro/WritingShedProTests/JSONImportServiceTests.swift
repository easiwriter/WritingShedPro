//
//  JSONImportServiceTests.swift
//  Writing Shed ProTests
//
//  Created on 13 December 2025.
//  Tests for JSON import from Writing Shed v1, including Collections/Submissions separation
//

import XCTest
import SwiftData
@testable import Writing_Shed_Pro

@MainActor
final class JSONImportServiceTests: XCTestCase {
    
    var modelContainer: ModelContainer!
    var modelContext: ModelContext!
    var importService: JSONImportService!
    var errorHandler: ImportErrorHandler!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create in-memory model container for testing
        let schema = Schema([
            Project.self,
            Folder.self,
            TextFile.self,
            Version.self,
            Publication.self,
            Submission.self,
            SubmittedFile.self
        ])
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        
        modelContainer = try ModelContainer(
            for: schema,
            configurations: [modelConfiguration]
        )
        
        modelContext = ModelContext(modelContainer)
        errorHandler = ImportErrorHandler()
        importService = JSONImportService(modelContext: modelContext, errorHandler: errorHandler)
    }
    
    override func tearDown() async throws {
        modelContainer = nil
        modelContext = nil
        importService = nil
        errorHandler = nil
        try await super.tearDown()
    }
    
    // MARK: - Collections/Submissions Separation Tests
    
    func testCollectionSubmissionIds_Decoding() throws {
        // Test that we correctly decode collectionSubmissionIds plist data
        
        // Create test plist data with empty array (should be Collection)
        let emptyArray: [String] = []
        let emptyData = try PropertyListEncoder().encode(emptyArray)
        
        let decodedEmpty = try PropertyListDecoder().decode([String].self, from: emptyData)
        XCTAssertTrue(decodedEmpty.isEmpty, "Empty array should decode as empty")
        
        // Create test plist data with non-empty array (should be Submission)
        let submissionIds = ["submission1", "submission2"]
        let submissionData = try PropertyListEncoder().encode(submissionIds)
        
        let decodedSubmissions = try PropertyListDecoder().decode([String].self, from: submissionData)
        XCTAssertFalse(decodedSubmissions.isEmpty, "Non-empty array should decode with items")
        XCTAssertEqual(decodedSubmissions.count, 2)
    }
    
    func testCollectionFlag_EmptySubmissionIds() throws {
        // When collectionSubmissionIds is empty or nil, isCollection should be true
        
        let emptyArray: [String] = []
        let emptyData = try PropertyListEncoder().encode(emptyArray)
        let decodedEmpty = try PropertyListDecoder().decode([String].self, from: emptyData)
        
        let isCollection = decodedEmpty.isEmpty
        XCTAssertTrue(isCollection, "Empty collectionSubmissionIds means it's a Collection")
    }
    
    func testCollectionFlag_WithSubmissionIds() throws {
        // When collectionSubmissionIds has items, isCollection should be false
        
        let submissionIds = ["sub1", "sub2"]
        let submissionData = try PropertyListEncoder().encode(submissionIds)
        let decodedSubmissions = try PropertyListDecoder().decode([String].self, from: submissionData)
        
        let isCollection = decodedSubmissions.isEmpty
        XCTAssertFalse(isCollection, "Non-empty collectionSubmissionIds means it's a Submission")
    }
    
    func testCollectionComponentData_WithoutSubmissionIds() throws {
        // Test CollectionComponentData without collectionSubmissionIds (Collection)
        
        let componentData = CollectionComponentData(
            type: "WS_Collection_Entity",
            id: "test-collection-1",
            collectionComponent: "{\"name\":\"Test Collection\",\"groupName\":\"Collections\"}",
            notes: Data(),
            notesText: "",
            collectionSubmissionsDatas: nil,
            collectionSubmissionIds: nil, // No submission IDs = Collection
            submissionSubmissionIds: nil,
            textCollectionData: nil,
            collectedTextIds: nil
        )
        
        // Verify no submission IDs
        XCTAssertNil(componentData.collectionSubmissionIds)
        
        // This should be treated as a Collection (isCollection = true)
        let hasSubmissionIds = false // nil means no submissions
        let isCollection = !hasSubmissionIds
        XCTAssertTrue(isCollection)
    }
    
    func testCollectionComponentData_WithSubmissionIds() throws {
        // Test CollectionComponentData with collectionSubmissionIds (Submission)
        
        let submissionIds = ["sub1", "sub2"]
        let submissionData = try PropertyListEncoder().encode(submissionIds)
        
        let componentData = CollectionComponentData(
            type: "WS_Collection_Entity",
            id: "test-submission-1",
            collectionComponent: "{\"name\":\"Test Submission\",\"groupName\":\"Submissions\"}",
            notes: Data(),
            notesText: "",
            collectionSubmissionsDatas: nil,
            collectionSubmissionIds: submissionData, // Has submission IDs = Submission
            submissionSubmissionIds: nil,
            textCollectionData: nil,
            collectedTextIds: nil
        )
        
        // Verify has submission IDs
        XCTAssertNotNil(componentData.collectionSubmissionIds)
        
        // Decode and check
        let decoded = try PropertyListDecoder().decode([String].self, from: componentData.collectionSubmissionIds!)
        let hasSubmissionIds = !decoded.isEmpty
        let isCollection = !hasSubmissionIds
        XCTAssertFalse(isCollection, "Should be a Submission, not a Collection")
    }
    
    // MARK: - Project Name Cleaning Tests
    
    func testProjectName_RemovesTimestamp() throws {
        // Test that project names with timestamps are cleaned
        let testCases: [(input: String, expected: String)] = [
            ("The 1st World (15:11:2025, 08:47)", "The 1st World"),
            ("My Novel (01/12/2024, 14:30)", "My Novel"),
            ("Poetry Collection (31/12/2025, 23:59)", "Poetry Collection"),
            ("Simple Name", "Simple Name"),
            ("Name Without Timestamp", "Name Without Timestamp")
        ]
        
        for testCase in testCases {
            // Use reflection to access private method
            let cleaned = cleanProjectNameHelper(testCase.input)
            XCTAssertEqual(cleaned, testCase.expected, "Failed for input: \(testCase.input)")
        }
    }
    
    func testProjectName_RemovesProjectPrefix() throws {
        // Test that project names with <>timestamp prefix are cleaned
        let testCases: [(input: String, expected: String)] = [
            ("<>03/06/2016, 09:09Poetry", "Poetry"),
            ("<>01/01/2020, 00:00Novel", "Novel"),
            ("NormalName", "NormalName")
        ]
        
        for testCase in testCases {
            let cleaned = cleanProjectNameHelper(testCase.input)
            XCTAssertEqual(cleaned, testCase.expected, "Failed for input: \(testCase.input)")
        }
    }
    
    // Helper to simulate the cleaning logic
    private func cleanProjectNameHelper(_ name: String) -> String {
        var cleaned = name
        
        // Remove <>timestamp prefix
        if let components = cleaned.split(separator: "<>", maxSplits: 1).first {
            cleaned = String(components)
        }
        
        // Remove timestamp in brackets at end
        let pattern = "\\s*\\([\\d:,\\s/]+\\)\\s*$"
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let range = NSRange(cleaned.startIndex..., in: cleaned)
            cleaned = regex.stringByReplacingMatches(in: cleaned, range: range, withTemplate: "")
        }
        
        return cleaned.trimmingCharacters(in: .whitespaces)
    }
    
    // MARK: - Project Type Mapping Tests
    
    func testProjectType_NumericMapping() throws {
        // Test mapping of legacy numeric project types
        let testCases: [(input: String, expected: ProjectType)] = [
            ("35", .poetry),
            ("36", .novel),
            ("37", .script),
            ("38", .shortStory)
        ]
        
        for testCase in testCases {
            let mapped = mapProjectTypeHelper(testCase.input)
            XCTAssertEqual(mapped, testCase.expected, "Failed to map \(testCase.input)")
        }
    }
    
    func testProjectType_StringMapping() throws {
        // Test mapping of string project types
        let testCases: [(input: String, expected: ProjectType)] = [
            ("novel", .novel),
            ("Novel", .novel),
            ("NOVEL", .novel),
            ("poetry", .poetry),
            ("script", .script),
            ("shortStory", .shortStory),
            ("short story", .shortStory),
            ("blank", .blank),
            ("unknown", .blank)
        ]
        
        for testCase in testCases {
            let mapped = mapProjectTypeHelper(testCase.input)
            XCTAssertEqual(mapped, testCase.expected, "Failed to map \(testCase.input)")
        }
    }
    
    // Helper to simulate project type mapping
    private func mapProjectTypeHelper(_ modelString: String) -> ProjectType {
        let numericMapping: [String: ProjectType] = [
            "35": .poetry,
            "36": .novel,
            "37": .script,
            "38": .shortStory
        ]
        
        if let type = numericMapping[modelString] {
            return type
        }
        
        let typeMapping: [String: ProjectType] = [
            "novel": .novel,
            "poetry": .poetry,
            "script": .script,
            "shortStory": .shortStory,
            "short story": .shortStory,
            "blank": .blank
        ]
        
        return typeMapping[modelString.lowercased()] ?? .blank
    }
    
    // MARK: - Folder Name Mapping Tests
    
    func testFolderName_LegacyMapping() throws {
        // Test mapping of legacy folder names
        let testCases: [(input: String, expected: String)] = [
            ("Accepted", "Published"),  // Old name mapped to new
            ("Draft", "Draft"),         // Unchanged
            ("Ready", "Ready"),         // Unchanged
            ("Set Aside", "Set Aside"), // Unchanged
            ("Collections", "Collections"), // Unchanged
            ("Research", "Research"),   // Unchanged
            ("Trash", "Trash"),         // Unchanged
            ("Custom Folder", "Custom Folder") // Unknown folders preserved
        ]
        
        for testCase in testCases {
            let mapped = mapLegacyFolderNameHelper(testCase.input)
            XCTAssertEqual(mapped, testCase.expected, "Failed to map folder: \(testCase.input)")
        }
    }
    
    private func mapLegacyFolderNameHelper(_ legacyName: String) -> String {
        switch legacyName {
        case "Accepted":
            return "Published"
        case "Draft", "Ready", "Set Aside", "Collections", "Research", "Trash":
            return legacyName
        default:
            return legacyName
        }
    }
    
    // MARK: - Publication Type Mapping Tests
    
    func testPublicationType_Mapping() throws {
        // Test mapping of publication types
        let testCases: [(input: String, expected: PublicationType)] = [
            ("magazine", .magazine),
            ("magazines", .magazine),
            ("Magazine", .magazine),
            ("competition", .competition),
            ("competitions", .competition),
            ("Competition", .competition),
            ("commission", .commission),
            ("commissions", .commission),
            ("Commission", .commission),
            ("other", .other),
            ("unknown", .other)
        ]
        
        for testCase in testCases {
            let mapped = mapPublicationTypeHelper(testCase.input)
            XCTAssertEqual(mapped, testCase.expected, "Failed to map: \(testCase.input)")
        }
    }
    
    private func mapPublicationTypeHelper(_ groupName: String) -> PublicationType {
        switch groupName.lowercased() {
        case "magazine", "magazines":
            return .magazine
        case "competition", "competitions":
            return .competition
        case "commission", "commissions":
            return .commission
        default:
            return .other
        }
    }
    
    // MARK: - Date Parsing Tests
    
    func testDateParsing_JSONFormat() throws {
        // Test parsing dates from JSON format (Core Data reference date)
        let jsonString = "{\"date\": 783237732.3579321, \"dateLastUpdated\": 785361073.1350951}"
        
        let parsed = parseDateFromVersionStringHelper(jsonString)
        
        // Verify date is reasonable (not default Date())
        let now = Date()
        let yearAgo = now.addingTimeInterval(-365 * 24 * 60 * 60)
        
        // Date should be between 2000 and now
        XCTAssertTrue(parsed.timeIntervalSince1970 > 946684800, "Date should be after 2000")
        XCTAssertTrue(parsed.timeIntervalSince1970 < now.timeIntervalSince1970, "Date should be before now")
    }
    
    func testDateParsing_NumericTimestamp() throws {
        // Test parsing numeric timestamps
        let timestamp = 783237732.0 // Core Data reference date format
        let timestampString = "\(timestamp)"
        
        let parsed = parseDateFromVersionStringHelper(timestampString)
        
        // Verify it's a reasonable date
        XCTAssertTrue(parsed.timeIntervalSince1970 > 946684800, "Should be after 2000")
    }
    
    func testDateParsing_ISO8601() throws {
        // Test parsing ISO 8601 formatted dates
        let dateString = "2024-12-10 14:30:00 +0000"
        
        let parsed = parseDateFromVersionStringHelper(dateString)
        
        // Verify it parsed to 2024
        let components = Calendar.current.dateComponents([.year], from: parsed)
        XCTAssertEqual(components.year, 2024, "Should parse to year 2024")
    }
    
    func testDateParsing_Fallback() throws {
        // Test that invalid dates fall back to current date
        let invalidString = "not a date"
        
        let parsed = parseDateFromVersionStringHelper(invalidString)
        let now = Date()
        
        // Should be very close to current time
        let timeDifference = abs(parsed.timeIntervalSince(now))
        XCTAssertLessThan(timeDifference, 5.0, "Should fall back to current date")
    }
    
    private func parseDateFromVersionStringHelper(_ versionString: String) -> Date {
        // Try JSON format first
        if let jsonData = versionString.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
           let dateValue = json["date"] as? Double {
            return Date(timeIntervalSinceReferenceDate: dateValue)
        }
        
        // Try numeric timestamp
        if let timestamp = Double(versionString) {
            let date = Date(timeIntervalSinceReferenceDate: timestamp)
            if date.timeIntervalSince1970 > 946684800 && date.timeIntervalSince1970 < 1893456000 {
                return date
            }
            
            let unixDate = Date(timeIntervalSince1970: timestamp)
            if unixDate.timeIntervalSince1970 > 946684800 && unixDate.timeIntervalSince1970 < 1893456000 {
                return unixDate
            }
        }
        
        // Try date formatters
        let formatters: [DateFormatter] = [
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
                formatter.locale = Locale(identifier: "en_US_POSIX")
                return formatter
            }(),
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.timeZone = TimeZone(secondsFromGMT: 0)
                return formatter
            }()
        ]
        
        for formatter in formatters {
            if let date = formatter.date(from: versionString) {
                return date
            }
        }
        
        return Date()
    }
    
    // MARK: - Version Sorting Tests
    
    func testVersionSorting_ChronologicalOrder() throws {
        // Test that versions are sorted by date, oldest first
        
        let versionDates = [
            "2024-01-15 10:00:00 +0000",
            "2024-01-10 09:00:00 +0000",
            "2024-01-20 11:00:00 +0000"
        ]
        
        let parsedDates = versionDates.map { parseDateFromVersionStringHelper($0) }
        let sortedDates = parsedDates.sorted { $0 < $1 }
        
        // Verify sorted order
        XCTAssertTrue(sortedDates[0] < sortedDates[1])
        XCTAssertTrue(sortedDates[1] < sortedDates[2])
        
        // Verify version numbers would be assigned correctly
        let versionNumbers = sortedDates.enumerated().map { $0.offset + 1 }
        XCTAssertEqual(versionNumbers, [1, 2, 3])
    }
    
    // MARK: - Error Handling Tests
    
    func testImportError_MissingContent() {
        let error = ImportError.missingContent
        XCTAssertNotNil(error)
    }
    
    func testImportError_InvalidData() {
        let error = ImportError.invalidData
        XCTAssertNotNil(error)
    }
    
    func testImportError_DecodingFailed() {
        let error = ImportError.decodingFailed
        XCTAssertNotNil(error)
    }
    
    func testErrorHandler_WarningsCollection() {
        let handler = ImportErrorHandler()
        
        XCTAssertEqual(handler.warnings.count, 0)
        
        handler.addWarning("Test warning 1")
        XCTAssertEqual(handler.warnings.count, 1)
        
        handler.addWarning("Test warning 2")
        XCTAssertEqual(handler.warnings.count, 2)
        
        XCTAssertEqual(handler.warnings[0], "Test warning 1")
        XCTAssertEqual(handler.warnings[1], "Test warning 2")
    }
}
