import XCTest
@testable import Writing_Shed_Pro

final class DocumentSpellingManagerTests: XCTestCase {
    func testFindIssuesReturnsUTF16RangeForMisspelledWord() throws {
        let language = try XCTUnwrap(
            DocumentSpellingManager.availableLanguages.first(where: { $0.hasPrefix("en") })
        )
        let text = "Correct qzxqzxword correct"

        let issues = DocumentSpellingManager.findIssues(in: text, language: language)
        let issue = try XCTUnwrap(issues.first(where: { $0.word == "qzxqzxword" }))

        XCTAssertEqual(issue.range, (text as NSString).range(of: "qzxqzxword"))
    }

    func testFindIssuesHonorsIgnoredWords() throws {
        let language = try XCTUnwrap(
            DocumentSpellingManager.availableLanguages.first(where: { $0.hasPrefix("en") })
        )
        let text = "qzxqzxword qzxqzxword"

        let issues = DocumentSpellingManager.findIssues(
            in: text,
            language: language,
            ignoring: ["qzxqzxword"]
        )

        XCTAssertTrue(issues.isEmpty)
    }

    func testFindIssuesHonorsPersistedIgnoredRanges() throws {
        let language = try XCTUnwrap(
            DocumentSpellingManager.availableLanguages.first(where: { $0.hasPrefix("en") })
        )
        let text = "qzxqzxword anotherbadword"
        let ignoredRange = (text as NSString).range(of: "qzxqzxword")

        let issues = DocumentSpellingManager.findIssues(
            in: text,
            language: language,
            ignoredRanges: [ignoredRange]
        )

        XCTAssertFalse(issues.contains(where: { $0.word == "qzxqzxword" }))
    }

    func testReplacementAdjustsFollowingUTF16Ranges() {
        let issues = [
            DocumentSpellingIssue(word: "bad", range: NSRange(location: 2, length: 3)),
            DocumentSpellingIssue(word: "later", range: NSRange(location: 10, length: 5))
        ]

        let adjusted = DocumentSpellingManager.issuesAfterReplacing(
            issues,
            at: 0,
            replacementUTF16Length: 7
        )

        XCTAssertEqual(adjusted.count, 1)
        XCTAssertEqual(adjusted[0].word, "later")
        XCTAssertEqual(adjusted[0].range, NSRange(location: 14, length: 5))
    }
}