import XCTest
import UIKit
@testable import Writing_Shed_Pro

final class FormattedTextEditorAttachmentComparisonTests: XCTestCase {
    func testImageAttachmentPositionChangeMatchesWhenTextChanged() {
        let attachment = ImageAttachment()
        let before = attributedText(prefix: "Before ", attachment: attachment, suffix: " after")
        let after = attributedText(prefix: "Before \n", attachment: attachment, suffix: " after")

        XCTAssertFalse(
            FormattedTextEditorAttachmentComparison.attachmentsMatch(before, after, includeLocation: true),
            "Position-aware comparison should detect that the image moved."
        )
        XCTAssertTrue(
            FormattedTextEditorAttachmentComparison.attachmentsMatch(before, after, includeLocation: false),
            "During a text edit, moving the same image attachment must not be treated as attachment loss."
        )
    }

    func testDifferentImageAttachmentDoesNotMatchWhenTextChanged() {
        let before = attributedText(prefix: "Before ", attachment: ImageAttachment(), suffix: " after")
        let after = attributedText(prefix: "Before \n", attachment: ImageAttachment(), suffix: " after")

        XCTAssertFalse(
            FormattedTextEditorAttachmentComparison.attachmentsMatch(before, after, includeLocation: false),
            "A genuinely different image attachment should still be treated as an attachment change."
        )
    }

    private func attributedText(prefix: String, attachment: ImageAttachment, suffix: String) -> NSAttributedString {
        let result = NSMutableAttributedString(string: prefix)
        result.append(NSAttributedString(attachment: attachment))
        result.append(NSAttributedString(string: suffix))
        return result
    }
}
