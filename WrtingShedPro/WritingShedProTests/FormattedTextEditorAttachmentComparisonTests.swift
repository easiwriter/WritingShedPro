import XCTest
import UIKit
@testable import Writing_Shed_Pro

final class FormattedTextEditorAttachmentComparisonTests: XCTestCase {
    func testParagraphSpacingChangeRequiresExternalAttributeRefresh() {
        let originalParagraphStyle = NSMutableParagraphStyle()
        let updatedParagraphStyle = NSMutableParagraphStyle()
        updatedParagraphStyle.paragraphSpacing = 12

        let current = NSAttributedString(
            string: "First paragraph\nSecond paragraph",
            attributes: [.paragraphStyle: originalParagraphStyle]
        )
        let incoming = NSAttributedString(
            string: current.string,
            attributes: [.paragraphStyle: updatedParagraphStyle]
        )

        XCTAssertTrue(
            FormattedTextEditorContentComparison.hasExternalAttributeChange(
                current: current,
                incoming: incoming,
                bindingObjectChanged: true,
                isProcessingUserTextChange: false
            )
        )
    }

    func testExternalAttributeRefreshIsSuppressedDuringUserTextChange() {
        let current = NSAttributedString(string: "Text", attributes: [.font: UIFont.systemFont(ofSize: 16)])
        let incoming = NSAttributedString(string: "Text", attributes: [.font: UIFont.boldSystemFont(ofSize: 16)])

        XCTAssertFalse(
            FormattedTextEditorContentComparison.hasExternalAttributeChange(
                current: current,
                incoming: incoming,
                bindingObjectChanged: true,
                isProcessingUserTextChange: true
            )
        )
    }

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
