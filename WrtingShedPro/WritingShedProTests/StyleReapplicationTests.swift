//
//  StyleReapplicationTests.swift
//  WritingShedProTests
//
//  Tests for reapplying styles after modifications and style change tracking
//

import XCTest
import SwiftData
@testable import Writing_Shed_Pro

@MainActor
final class StyleReapplicationTests: XCTestCase {
    
    var container: ModelContainer!
    var context: ModelContext!
    
    override func setUp() async throws {
        // Create in-memory container for testing
        let schema = Schema([
            StyleSheet.self,
            TextStyleModel.self,
            Project.self,
            Folder.self,
            TextFile.self,
            Version.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = ModelContext(container)
        
        // Initialize default stylesheets
        StyleSheetService.initializeStyleSheetsIfNeeded(context: context)
    }
    
    override func tearDown() {
        container = nil
        context = nil
    }
    
    // MARK: - Style Attribute Generation Tests
    
    func testGenerateAttributesWithAllProperties() throws {
        // Given - A style with comprehensive formatting
        let style = TextStyleModel(
            name: "test-style",
            displayName: "Test Style",
            displayOrder: 0,
            fontSize: 24,
            isBold: true,
            isItalic: true
        )
        style.isUnderlined = true
        style.isStrikethrough = true
        style.textColor = UIColor.systemBlue
        style.alignment = .center
        style.lineSpacing = 8.0
        style.paragraphSpacingAfter = 12.0
        style.paragraphSpacingBefore = 10.0
        style.firstLineIndent = 20.0
        style.headIndent = 15.0
        style.tailIndent = -15.0
        
        context.insert(style)
        try context.save()
        
        // When
        let attributes = style.generateAttributes()
        
        // Then - Verify all attributes are present
        XCTAssertNotNil(attributes[.font], "Font should be present")
        XCTAssertNotNil(attributes[.foregroundColor], "Text color should be present")
        XCTAssertNotNil(attributes[.paragraphStyle], "Paragraph style should be present")
        XCTAssertNotNil(attributes[.textStyle], "Text style identifier should be present")
        
        // Verify font attributes
        let font = attributes[.font] as? UIFont
        XCTAssertEqual(font?.pointSize, 24)
        let traits = font?.fontDescriptor.symbolicTraits ?? []
        XCTAssertTrue(traits.contains(.traitBold), "Font should be bold")
        XCTAssertTrue(traits.contains(.traitItalic), "Font should be italic")
        
        // Verify text decorations
        if style.isUnderlined {
            XCTAssertNotNil(attributes[.underlineStyle], "Underline should be present")
        }
        if style.isStrikethrough {
            XCTAssertNotNil(attributes[.strikethroughStyle], "Strikethrough should be present")
        }
        
        // Verify color
        let color = attributes[.foregroundColor] as? UIColor
        XCTAssertNotNil(color, "Color should be present")
        
        // Verify paragraph style
        let paragraphStyle = attributes[.paragraphStyle] as? NSParagraphStyle
        XCTAssertEqual(paragraphStyle?.alignment, .center)
        XCTAssertEqual(paragraphStyle?.lineSpacing, 8.0)
        XCTAssertEqual(paragraphStyle?.paragraphSpacing, 12.0)
        XCTAssertEqual(paragraphStyle?.paragraphSpacingBefore, 10.0)
        XCTAssertEqual(paragraphStyle?.firstLineHeadIndent, 20.0)
        XCTAssertEqual(paragraphStyle?.headIndent, 15.0)
        XCTAssertEqual(paragraphStyle?.tailIndent, -15.0)
        
        // Verify style identifier
        let styleIdentifier = attributes[.textStyle] as? String
        XCTAssertEqual(styleIdentifier, "test-style")
    }
    
    func testGenerateAttributesWithMinimalProperties() throws {
        // Given - A style with minimal formatting
        let style = TextStyleModel(
            name: "minimal",
            displayName: "Minimal",
            displayOrder: 0
        )
        
        context.insert(style)
        try context.save()
        
        // When
        let attributes = style.generateAttributes()
        
        // Then - Should still have basic attributes
        XCTAssertNotNil(attributes[.font])
        XCTAssertNotNil(attributes[.paragraphStyle])
        XCTAssertNotNil(attributes[.textStyle])
        
        let font = attributes[.font] as? UIFont
        XCTAssertEqual(font?.pointSize, 17) // Default size
        
        let paragraphStyle = attributes[.paragraphStyle] as? NSParagraphStyle
        XCTAssertEqual(paragraphStyle?.alignment, .natural)
        XCTAssertEqual(paragraphStyle?.lineSpacing, 0)
    }

    func testDetectsRepeatedShortStyleIslandsInUnstyledText() {
        let text = NSMutableAttributedString(string: "abcdefghij klmnopqrst uvwxyz")
        for location in stride(from: 1, through: 15, by: 2) {
            text.addAttribute(
                .textStyle,
                value: UIFont.TextStyle.body.rawValue,
                range: NSRange(location: location, length: 1)
            )
        }

        let data = AttributedStringSerializer.encode(text)

        XCTAssertTrue(
            AttributedStringSerializer.containsFragmentedTextStyleArtifacts(
                in: data,
                text: text.string
            )
        )
    }

    func testDoesNotTreatNormalParagraphStyleRunsAsFragmentation() {
        let text = NSMutableAttributedString(string: "First paragraph\nSecond paragraph")
        text.addAttribute(
            .textStyle,
            value: UIFont.TextStyle.body.rawValue,
            range: NSRange(location: 0, length: 16)
        )

        let data = AttributedStringSerializer.encode(text)

        XCTAssertFalse(
            AttributedStringSerializer.containsFragmentedTextStyleArtifacts(
                in: data,
                text: text.string
            )
        )
    }

    func testDecodePreservesCustomFontOnTextStyleRun() throws {
        let source = NSMutableAttributedString(
            string: "Papyrus body",
            attributes: [
                .font: UIFont(name: "Papyrus", size: 13)!,
                .textStyle: UIFont.TextStyle.body.rawValue
            ]
        )

        let decoded = AttributedStringSerializer.decode(
            AttributedStringSerializer.encode(source),
            text: source.string
        )
        let font = try XCTUnwrap(decoded.attribute(.font, at: 0, effectiveRange: nil) as? UIFont)

        XCTAssertEqual(font.fontName, "Papyrus")
        XCTAssertEqual(font.pointSize, 13)
        XCTAssertEqual(
            decoded.attribute(.textStyle, at: 0, effectiveRange: nil) as? String,
            UIFont.TextStyle.body.rawValue
        )
    }

    func testReapplicationKeepsFirstLineIndentWhenStyleRunContainsAttachment() throws {
        let style = TextStyleModel(name: "body", displayName: "Body")
        style.firstLineIndent = 16
        let styleAttributes = style.generateAttributes()

        let textAttributes = StyleReapplicationAttributeMerger.merge(
            styleAttributes: styleAttributes,
            currentAttributes: [.font: UIFont.systemFont(ofSize: 17)]
        )
        let textParagraphStyle = textAttributes[.paragraphStyle] as? NSParagraphStyle
        XCTAssertEqual(textParagraphStyle?.firstLineHeadIndent, 16)

        let attachment = ImageAttachment()
        let attachmentParagraphStyle = NSMutableParagraphStyle()
        attachmentParagraphStyle.alignment = .center
        let attachmentAttributes = StyleReapplicationAttributeMerger.merge(
            styleAttributes: styleAttributes,
            currentAttributes: [
                .attachment: attachment,
                .paragraphStyle: attachmentParagraphStyle
            ]
        )
        XCTAssertTrue(attachmentAttributes[.attachment] as? ImageAttachment === attachment)
        XCTAssertEqual(
            (attachmentAttributes[.paragraphStyle] as? NSParagraphStyle)?.alignment,
            .center
        )
    }

    func testReapplyStylesReplacesSystemFontOnFragmentedBodyRun() throws {
        let bodyStyle = TextStyleModel(
            name: UIFont.TextStyle.body.rawValue,
            displayName: "Body",
            fontFamily: "Papyrus",
            fontSize: 13
        )
        let source = NSMutableAttributedString(
            string: "abc",
            attributes: [.font: UIFont(name: "Papyrus", size: 13)!]
        )
        source.addAttributes(
            [
                .font: UIFont.systemFont(ofSize: 17),
                .textStyle: UIFont.TextStyle.body.rawValue
            ],
            range: NSRange(location: 1, length: 1)
        )

        let repaired = StyleReapplicationAttributeMerger.reapplyStyles(in: source) { styleName in
            styleName == bodyStyle.name ? bodyStyle : nil
        }
        let repairedFont = try XCTUnwrap(
            repaired.attribute(.font, at: 1, effectiveRange: nil) as? UIFont
        )

        XCTAssertEqual(repairedFont.fontName, "Papyrus")
        XCTAssertEqual(repairedFont.pointSize, 13)
    }

    func testStyleReapplicationDetectsStaleFontForCurrentSemanticStyle() throws {
        let titleStyle = TextStyleModel(
            name: UIFont.TextStyle.title3.rawValue,
            displayName: "Title 3",
            fontFamily: "Helvetica Neue",
            fontSize: 19,
            isBold: true
        )
        titleStyle.selectFontFace("HelveticaNeue-Bold")
        let staleFont = try XCTUnwrap(UIFont(name: "HelveticaNeue-Bold", size: 20))
        let staleText = NSAttributedString(
            string: "Aeroplanes",
            attributes: [
                .font: staleFont,
                .textStyle: UIFont.TextStyle.title3.rawValue
            ]
        )

        XCTAssertTrue(
            StyleReapplicationAttributeMerger.hasFontMismatch(in: staleText) { styleName in
                styleName == titleStyle.name ? titleStyle : nil
            }
        )

        let currentText = StyleReapplicationAttributeMerger.reapplyStyles(in: staleText) { styleName in
            styleName == titleStyle.name ? titleStyle : nil
        }
        XCTAssertFalse(
            StyleReapplicationAttributeMerger.hasFontMismatch(in: currentText) { styleName in
                styleName == titleStyle.name ? titleStyle : nil
            }
        )
    }

    func testReapplyingDocumentStylesNormalizesEverySemanticStyle() throws {
        let titleStyle = TextStyleModel(
            name: UIFont.TextStyle.title3.rawValue,
            displayName: "Title 3",
            fontFamily: "Helvetica Neue",
            fontSize: 19,
            isBold: true
        )
        titleStyle.selectFontFace("HelveticaNeue-Bold")
        let bodyStyle = TextStyleModel(
            name: UIFont.TextStyle.body.rawValue,
            displayName: "Body",
            fontFamily: "Helvetica Neue",
            fontSize: 17
        )
        bodyStyle.selectFontFace("HelveticaNeue-Regular")
        let expectedTitleFont = titleStyle.generateFont()
        let staleTitleFont = try XCTUnwrap(UIFont(name: "HelveticaNeue-Medium", size: 20))
        let expectedBodyFont = bodyStyle.generateFont()
        let staleBodyFont = try XCTUnwrap(UIFont(name: "Courier", size: 13))
        let source = NSMutableAttributedString(
            string: "New\n",
            attributes: [
                .font: expectedTitleFont,
                .textStyle: titleStyle.name
            ]
        )
        source.append(NSAttributedString(
            string: "Old\n",
            attributes: [
                .font: staleTitleFont,
                .textStyle: titleStyle.name
            ]
        ))
        source.append(NSAttributedString(
            string: "Body",
            attributes: [
                .font: staleBodyFont,
                .textStyle: bodyStyle.name
            ]
        ))

        let normalized = StyleReapplicationAttributeMerger.reapplyStyles(in: source) { styleName in
            switch styleName {
            case titleStyle.name: titleStyle
            case bodyStyle.name: bodyStyle
            default: nil
            }
        }
        let firstTitleFont = try XCTUnwrap(normalized.attribute(.font, at: 0, effectiveRange: nil) as? UIFont)
        let secondTitleFont = try XCTUnwrap(normalized.attribute(.font, at: 4, effectiveRange: nil) as? UIFont)
        let normalizedBodyFont = try XCTUnwrap(normalized.attribute(.font, at: 8, effectiveRange: nil) as? UIFont)

        XCTAssertEqual(firstTitleFont.fontName, expectedTitleFont.fontName)
        XCTAssertEqual(secondTitleFont.fontName, expectedTitleFont.fontName)
        XCTAssertEqual(firstTitleFont.pointSize, expectedTitleFont.pointSize, accuracy: 0.01)
        XCTAssertEqual(secondTitleFont.pointSize, expectedTitleFont.pointSize, accuracy: 0.01)
        XCTAssertEqual(normalizedBodyFont.fontName, expectedBodyFont.fontName)
        XCTAssertEqual(normalizedBodyFont.pointSize, expectedBodyFont.pointSize, accuracy: 0.01)
    }

    func testReapplyChangingBoldItalicFaceToLightRemovesOldFaceTraits() throws {
        let oldFont = try XCTUnwrap(UIFont(name: "HelveticaNeue-BoldItalic", size: 17))
        let lightStyle = TextStyleModel(
            name: UIFont.TextStyle.body.rawValue,
            displayName: "Body",
            fontFamily: "Helvetica Neue",
            fontSize: 17
        )
        lightStyle.selectFontFace("HelveticaNeue-Light")

        let merged = StyleReapplicationAttributeMerger.merge(
            styleAttributes: lightStyle.generateAttributes(),
            currentAttributes: [
                .font: oldFont,
                .textStyle: UIFont.TextStyle.body.rawValue
            ]
        )
        let font = try XCTUnwrap(merged[.font] as? UIFont)

        XCTAssertEqual(font.fontName, "HelveticaNeue-Light")
        XCTAssertFalse(font.fontDescriptor.symbolicTraits.contains(.traitBold))
        XCTAssertFalse(font.fontDescriptor.symbolicTraits.contains(.traitItalic))
    }

    func testReapplyReplacesStaleFontFromDifferentStyleFamily() throws {
        let staleFont = try XCTUnwrap(UIFont(name: "HelveticaNeue-BoldItalic", size: 17))
        let avenirStyle = TextStyleModel(
            name: UIFont.TextStyle.body.rawValue,
            displayName: "Body",
            fontFamily: "Avenir",
            fontSize: 17
        )
        avenirStyle.selectFontFace("Avenir-Light")

        let merged = StyleReapplicationAttributeMerger.merge(
            styleAttributes: avenirStyle.generateAttributes(),
            currentAttributes: [
                .font: staleFont,
                .textStyle: UIFont.TextStyle.body.rawValue
            ]
        )
        let font = try XCTUnwrap(merged[.font] as? UIFont)

        XCTAssertEqual(font.fontName, "Avenir-Light")
        XCTAssertFalse(font.fontDescriptor.symbolicTraits.contains(.traitBold))
        XCTAssertFalse(font.fontDescriptor.symbolicTraits.contains(.traitItalic))
    }

    func testReapplyPreservesExplicitBoldOverrideUsingNewFamilyFace() throws {
        let avenirStyle = TextStyleModel(
            name: UIFont.TextStyle.body.rawValue,
            displayName: "Body",
            fontFamily: "Avenir",
            fontSize: 17
        )
        avenirStyle.selectFontFace("Avenir-Light")

        let merged = StyleReapplicationAttributeMerger.merge(
            styleAttributes: avenirStyle.generateAttributes(),
            currentAttributes: [
                .font: UIFont.systemFont(ofSize: 17),
                .textStyle: UIFont.TextStyle.body.rawValue,
                .explicitBold: true
            ]
        )
        let font = try XCTUnwrap(merged[.font] as? UIFont)

        XCTAssertTrue(FontFaceResolver.traits(of: font).bold)
        XCTAssertEqual(merged[.explicitBold] as? Bool, true)
        XCTAssertEqual(merged[.inlineFormattingBaseFontName] as? String, "Avenir-Light")
    }

    func testInsertionAttributesUseCompleteNumberedBodyStyle() throws {
        let bodyStyle = TextStyleModel(
            name: UIFont.TextStyle.body.rawValue,
            displayName: "Body",
            fontFamily: "Papyrus",
            fontSize: 13
        )
        bodyStyle.numberFormat = .decimal
        bodyStyle.firstLineIndent = 19
        bodyStyle.lineSpacing = 2

        let attributes = FormattedTextEditorInsertionAttributes.merge(
            styleAttributes: bodyStyle.generateAttributes(),
            replacedAttributes: [.font: UIFont.systemFont(ofSize: 17)]
        )
        let font = try XCTUnwrap(attributes[.font] as? UIFont)
        let paragraphStyle = try XCTUnwrap(attributes[.paragraphStyle] as? NSParagraphStyle)

        XCTAssertEqual(font.fontName, "Papyrus")
        XCTAssertEqual(font.pointSize, 13)
        XCTAssertEqual(attributes[.textStyle] as? String, UIFont.TextStyle.body.rawValue)
        let expectedFirstLineIndent = bodyStyle.firstLineIndent
            + bodyStyle.numberFormat.estimatedWidth(
                for: bodyStyle.generateFont(),
                adornment: bodyStyle.numberAdornment,
                ancestorDepth: 0
            )
            + 4
        XCTAssertEqual(paragraphStyle.firstLineHeadIndent, expectedFirstLineIndent)
        XCTAssertEqual(paragraphStyle.lineSpacing, 2)
    }

    func testInsertionAttributesPreserveDeliberateCharacterTraits() throws {
        let bodyStyle = TextStyleModel(
            name: UIFont.TextStyle.body.rawValue,
            displayName: "Body",
            fontFamily: "Papyrus",
            fontSize: 13
        )
        let replacementFont = UIFont.boldSystemFont(ofSize: 17)

        let attributes = FormattedTextEditorInsertionAttributes.merge(
            styleAttributes: bodyStyle.generateAttributes(),
            replacedAttributes: [
                .font: replacementFont,
                .textStyle: UIFont.TextStyle.body.rawValue,
                .explicitBold: true,
                .underlineStyle: NSUnderlineStyle.single.rawValue
            ]
        )
        let font = try XCTUnwrap(attributes[.font] as? UIFont)

        XCTAssertEqual(font.familyName, "Papyrus")
        XCTAssertEqual(attributes[.explicitBold] as? Bool, true)
        XCTAssertEqual(attributes[.underlineStyle] as? Int, NSUnderlineStyle.single.rawValue)
    }

    func testInsertionAttributesDoNotCarryHeadingBoldIntoFollowOnBody() throws {
        let bodyStyle = TextStyleModel(
            name: UIFont.TextStyle.body.rawValue,
            displayName: "Body",
            fontFamily: "Papyrus",
            fontSize: 13
        )

        let attributes = FormattedTextEditorInsertionAttributes.merge(
            styleAttributes: bodyStyle.generateAttributes(),
            replacedAttributes: [
                .font: UIFont.boldSystemFont(ofSize: 19),
                .textStyle: UIFont.TextStyle.headline.rawValue,
                .underlineStyle: NSUnderlineStyle.single.rawValue
            ]
        )
        let font = try XCTUnwrap(attributes[.font] as? UIFont)

        XCTAssertEqual(font.fontName, "Papyrus")
        XCTAssertFalse(font.fontDescriptor.symbolicTraits.contains(.traitBold))
        XCTAssertNil(attributes[.underlineStyle])
        XCTAssertEqual(attributes[.textStyle] as? String, UIFont.TextStyle.body.rawValue)
    }

    func testInsertionContinuesBodyBeforeStaleBoldBoundary() throws {
        let regularBodyFont = try XCTUnwrap(UIFont(name: "HelveticaNeue-Light", size: 17))
        let boldBodyFont = try XCTUnwrap(UIFont(name: "HelveticaNeue-Bold", size: 17))
        let source = NSAttributedString(
            string: "n\n",
            attributes: [
                .font: regularBodyFont,
                .textStyle: UIFont.TextStyle.body.rawValue
            ]
        ).mutableCopy() as! NSMutableAttributedString
        source.setAttributes(
            [
                .font: boldBodyFont,
                .textStyle: UIFont.TextStyle.body.rawValue
            ],
            range: NSRange(location: 1, length: 1)
        )

        let attributes = FormattedTextEditorInsertionAttributes.sourceAttributes(
            in: source,
            typingAttributes: [:],
            replacing: NSRange(location: 1, length: 0)
        )
        let font = try XCTUnwrap(attributes[.font] as? UIFont)

        XCTAssertEqual(font.fontName, "HelveticaNeue-Light")
        XCTAssertFalse(font.fontDescriptor.symbolicTraits.contains(.traitBold))
    }

    func testReturnBetweenBodyAndTitle3AnchorsBodyWithoutMutatingHeading() throws {
        let bodyAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 17),
            .textStyle: UIFont.TextStyle.body.rawValue,
            .paragraphStyle: NSMutableParagraphStyle()
        ]
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 20),
            .textStyle: UIFont.TextStyle.title3.rawValue,
            .paragraphStyle: NSMutableParagraphStyle()
        ]
        let text = NSMutableAttributedString(string: "Body\n", attributes: bodyAttributes)
        text.append(NSAttributedString(string: "Aeroplanes\n", attributes: titleAttributes))
        let paragraphBreak = FormattedTextEditorParagraphBreak.attributedString(
            currentParagraphAttributes: bodyAttributes,
            newParagraphAttributes: bodyAttributes
        )

        text.replaceCharacters(in: NSRange(location: 4, length: 0), with: paragraphBreak)

        XCTAssertEqual(text.string, "Body\n\u{200B}\nAeroplanes\n")
        let anchorFont = try XCTUnwrap(text.attribute(.font, at: 5, effectiveRange: nil) as? UIFont)
        XCTAssertEqual(text.attribute(.textStyle, at: 5, effectiveRange: nil) as? String, UIFont.TextStyle.body.rawValue)
        XCTAssertEqual(anchorFont.pointSize, 17)
        let headingFont = try XCTUnwrap(text.attribute(.font, at: 7, effectiveRange: nil) as? UIFont)
        XCTAssertEqual(text.attribute(.textStyle, at: 7, effectiveRange: nil) as? String, UIFont.TextStyle.title3.rawValue)
        XCTAssertEqual(headingFont.pointSize, 20)
        XCTAssertTrue(headingFont.fontDescriptor.symbolicTraits.contains(.traitBold))
    }
    
    func testGenerateAttributesWithCustomFont() throws {
        // Given - A style with custom font family
        let style = TextStyleModel(
            name: "custom-font",
            displayName: "Custom Font",
            displayOrder: 0,
            fontFamily: "Courier",
            fontSize: 14
        )
        
        context.insert(style)
        try context.save()
        
        // When
        let attributes = style.generateAttributes()
        
        // Then
        let font = attributes[.font] as? UIFont
        XCTAssertNotNil(font)
        XCTAssertTrue(font?.familyName.contains("Courier") ?? false)
        XCTAssertEqual(font?.pointSize, 14)
    }
    
    func testGenerateAttributesWithListFormatting() throws {
        // Given - A style with list formatting
        let style = TextStyleModel(
            name: "numbered-list",
            displayName: "Numbered List",
            displayOrder: 0
        )
        style.styleCategory = .list
        style.numberFormat = .decimal
        style.headIndent = 30.0
        
        context.insert(style)
        try context.save()
        
        // When
        let attributes = style.generateAttributes()
        
        // Then
        let paragraphStyle = attributes[.paragraphStyle] as? NSParagraphStyle
        XCTAssertEqual(paragraphStyle?.headIndent, 30.0)
        XCTAssertEqual(style.numberFormat, .decimal)
        XCTAssertEqual(style.styleCategory, .list)
    }
    
    // MARK: - TextFormatter Integration Tests
    
    func testApplyStyleWithModelBasedFormatting() throws {
        // Given
        let project = Project(name: "Test Project", type: .prose)
        context.insert(project)
        
        let stylesheet = StyleSheet(name: "Test Stylesheet")
        let bodyStyle = TextStyleModel(
            name: UIFont.TextStyle.body.rawValue,
            displayName: "Body",
            displayOrder: 0,
            fontSize: 18
        )
        bodyStyle.textColor = UIColor.systemBlue
        bodyStyle.styleSheet = stylesheet
        
        project.styleSheet = stylesheet
        context.insert(stylesheet)
        try context.save()
        
        let originalText = NSAttributedString(string: "Test text")
        let range = NSRange(location: 0, length: originalText.length)
        
        // When
        let styledText = TextFormatter.applyStyle(
            named: UIFont.TextStyle.body.rawValue,
            to: originalText,
            range: range,
            project: project,
            context: context
        )
        
        // Then
        XCTAssertGreaterThan(styledText.length, 0)
        
        let attributes = styledText.attributes(at: 0, effectiveRange: nil)
        let font = attributes[.font] as? UIFont
        XCTAssertEqual(font?.pointSize, 18)
        
        let color = attributes[.foregroundColor] as? UIColor
        XCTAssertNotNil(color)
        
        let styleIdentifier = attributes[.textStyle] as? String
        XCTAssertEqual(styleIdentifier, UIFont.TextStyle.body.rawValue)
    }
    
    func testApplyStylePreservesCharacterFormatting() throws {
        // Given
        let project = Project(name: "Test Project", type: .prose)
        context.insert(project)
        
        let stylesheet = StyleSheet(name: "Test Stylesheet")
        let bodyStyle = TextStyleModel(
            name: UIFont.TextStyle.body.rawValue,
            displayName: "Body",
            displayOrder: 0,
            fontSize: 16
        )
        bodyStyle.styleSheet = stylesheet
        project.styleSheet = stylesheet
        context.insert(stylesheet)
        try context.save()
        
        // Create text with bold formatting
        let baseFont = UIFont.systemFont(ofSize: 14)
        let boldFont = UIFont.boldSystemFont(ofSize: 14)
        
        let mutableText = NSMutableAttributedString(string: "Normal ")
        mutableText.addAttribute(.font, value: baseFont, range: NSRange(location: 0, length: 7))
        
        let boldText = NSAttributedString(string: "bold", attributes: [.font: boldFont])
        mutableText.append(boldText)
        
        let range = NSRange(location: 0, length: mutableText.length)
        
        // When - Apply paragraph style
        let styledText = TextFormatter.applyStyle(
            named: UIFont.TextStyle.body.rawValue,
            to: mutableText,
            range: range,
            project: project,
            context: context
        )
        
        // Then - Bold trait should be preserved on "bold" text
        let normalAttrs = styledText.attributes(at: 0, effectiveRange: nil)
        let boldAttrs = styledText.attributes(at: 7, effectiveRange: nil)
        
        let normalFont = normalAttrs[.font] as? UIFont
        let boldFontResult = boldAttrs[.font] as? UIFont
        
        XCTAssertEqual(normalFont?.pointSize, 16)
        XCTAssertEqual(boldFontResult?.pointSize, 16)
        
        let boldTraits = boldFontResult?.fontDescriptor.symbolicTraits ?? []
        XCTAssertTrue(boldTraits.contains(.traitBold), "Bold formatting should be preserved")
    }
    
    func testGetCurrentStyleName() throws {
        // Given
        let project = Project(name: "Test Project", type: .prose)
        context.insert(project)
        try context.save()
        
        let stylesheet = StyleSheet(name: "Test Stylesheet")
        let headlineStyle = TextStyleModel(
            name: UIFont.TextStyle.headline.rawValue,
            displayName: "Headline",
            displayOrder: 0
        )
        headlineStyle.styleSheet = stylesheet
        project.styleSheet = stylesheet
        context.insert(stylesheet)
        try context.save()
        
        // Create attributed text with style
        let attrs = headlineStyle.generateAttributes()
        let text = NSAttributedString(string: "Headline text", attributes: attrs)
        
        let range = NSRange(location: 5, length: 0) // Cursor in middle of text
        
        // When
        let styleName = TextFormatter.getCurrentStyleName(
            in: text,
            at: range,
            project: project,
            context: context
        )
        
        // Then
        XCTAssertEqual(styleName, UIFont.TextStyle.headline.rawValue)
    }
    
    // MARK: - Document Reapplication Simulation Tests
    
    func testMultipleStylesInDocument() throws {
        // Given - Document with multiple paragraph styles
        let project = Project(name: "Test Project", type: .prose)
        context.insert(project)
        
        let stylesheet = StyleSheet(name: "Test Stylesheet")
        
        let titleStyle = TextStyleModel(
            name: UIFont.TextStyle.title1.rawValue,
            displayName: "Title 1",
            displayOrder: 0,
            fontSize: 28
        )
        titleStyle.textColor = UIColor.systemRed
        titleStyle.styleSheet = stylesheet
        
        let bodyStyle = TextStyleModel(
            name: UIFont.TextStyle.body.rawValue,
            displayName: "Body",
            displayOrder: 1,
            fontSize: 17
        )
        bodyStyle.textColor = UIColor.label
        bodyStyle.styleSheet = stylesheet
        
        project.styleSheet = stylesheet
        context.insert(stylesheet)
        try context.save()
        
        // Create document with mixed styles
        let titleAttrs = titleStyle.generateAttributes()
        let bodyAttrs = bodyStyle.generateAttributes()
        
        let document = NSMutableAttributedString()
        document.append(NSAttributedString(string: "Title\n", attributes: titleAttrs))
        document.append(NSAttributedString(string: "Body paragraph", attributes: bodyAttrs))
        
        // When - Modify the styles
        titleStyle.fontSize = 32
        titleStyle.textColor = UIColor.systemBlue
        bodyStyle.fontSize = 18
        try context.save()
        
        // Simulate reapplication
        let reappliedDocument = NSMutableAttributedString(attributedString: document)
        
        // Reapply title style
        if let styleName = titleAttrs[.textStyle] as? String,
           let updatedStyle = StyleSheetService.resolveStyle(named: styleName, for: project, context: context) {
            let newAttrs = updatedStyle.generateAttributes()
            reappliedDocument.setAttributes(newAttrs, range: NSRange(location: 0, length: 6))
        }
        
        // Reapply body style
        if let styleName = bodyAttrs[.textStyle] as? String,
           let updatedStyle = StyleSheetService.resolveStyle(named: styleName, for: project, context: context) {
            let newAttrs = updatedStyle.generateAttributes()
            reappliedDocument.setAttributes(newAttrs, range: NSRange(location: 6, length: reappliedDocument.length - 6))
        }
        
        // Then - Verify updated attributes
        let titleFont = reappliedDocument.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertEqual(titleFont?.pointSize, 32, "Title font size should be updated")
        
        let titleColor = reappliedDocument.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? UIColor
        XCTAssertNotNil(titleColor, "Title color should be updated")
        
        let bodyFont = reappliedDocument.attribute(.font, at: 7, effectiveRange: nil) as? UIFont
        XCTAssertEqual(bodyFont?.pointSize, 18, "Body font size should be updated")
    }
    
    func testReapplicationPreservesLocalFormatting() throws {
        // Given - Text with paragraph style AND local character formatting
        let project = Project(name: "Test Project", type: .prose)
        context.insert(project)
        
        let stylesheet = StyleSheet(name: "Test Stylesheet")
        let bodyStyle = TextStyleModel(
            name: UIFont.TextStyle.body.rawValue,
            displayName: "Body",
            displayOrder: 0,
            fontSize: 16
        )
        bodyStyle.textColor = UIColor.label
        bodyStyle.styleSheet = stylesheet
        project.styleSheet = stylesheet
        context.insert(stylesheet)
        try context.save()
        
        // Create text with bold word in middle
        let baseAttrs = bodyStyle.generateAttributes()
        let _ = baseAttrs[.font] as! UIFont  // Get base font for reference
        let boldFont = UIFont.boldSystemFont(ofSize: 16)
        
        let document = NSMutableAttributedString(string: "Normal bold normal", attributes: baseAttrs)
        document.setAttributes([.font: boldFont], range: NSRange(location: 7, length: 4))
        
        // When - Style changes
        bodyStyle.fontSize = 18
        try context.save()
        
        // Simulate reapplication with trait preservation
        let reappliedDocument = NSMutableAttributedString(attributedString: document)
        let updatedStyle = StyleSheetService.resolveStyle(
            named: UIFont.TextStyle.body.rawValue,
            for: project,
            context: context
        )!
        let newBaseAttrs = updatedStyle.generateAttributes()
        let newBaseFont = newBaseAttrs[.font] as! UIFont
        
        reappliedDocument.enumerateAttributes(
            in: NSRange(location: 0, length: reappliedDocument.length),
            options: []
        ) { attrs, range, _ in
            var updatedAttrs = newBaseAttrs
            
            // Preserve bold trait
            if let existingFont = attrs[.font] as? UIFont {
                let traits = existingFont.fontDescriptor.symbolicTraits
                if traits.contains(.traitBold) {
                    if let descriptor = newBaseFont.fontDescriptor.withSymbolicTraits(.traitBold) {
                        updatedAttrs[.font] = UIFont(descriptor: descriptor, size: 0)
                    }
                }
            }
            
            reappliedDocument.setAttributes(updatedAttrs, range: range)
        }
        
        // Then - Bold trait should be preserved
        let normalFont = reappliedDocument.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        XCTAssertEqual(normalFont?.pointSize, 18, "Normal text should have new size")
        
        let boldFontResult = reappliedDocument.attribute(.font, at: 7, effectiveRange: nil) as? UIFont
        XCTAssertEqual(boldFontResult?.pointSize, 18, "Bold text should have new size")
        
        let boldTraits = boldFontResult?.fontDescriptor.symbolicTraits ?? []
        XCTAssertTrue(boldTraits.contains(.traitBold), "Bold trait should be preserved")
    }
    
    // MARK: - Style Enumeration Tests
    
    func testEnumerateTextStyleAttributeInDocument() throws {
        // Given - Document with multiple styled paragraphs
        let project = Project(name: "Test Project", type: .prose)
        context.insert(project)
        
        let stylesheet = StyleSheet(name: "Test Stylesheet")
        
        let title = TextStyleModel(
            name: UIFont.TextStyle.title1.rawValue,
            displayName: "Title",
            displayOrder: 0
        )
        let body = TextStyleModel(
            name: UIFont.TextStyle.body.rawValue,
            displayName: "Body",
            displayOrder: 1
        )
        let caption = TextStyleModel(
            name: UIFont.TextStyle.caption1.rawValue,
            displayName: "Caption",
            displayOrder: 2
        )
        
        title.styleSheet = stylesheet
        body.styleSheet = stylesheet
        caption.styleSheet = stylesheet
        project.styleSheet = stylesheet
        context.insert(stylesheet)
        try context.save()
        
        // Build document
        let document = NSMutableAttributedString()
        document.append(NSAttributedString(string: "Title\n", attributes: title.generateAttributes()))
        document.append(NSAttributedString(string: "Body text\n", attributes: body.generateAttributes()))
        document.append(NSAttributedString(string: "Caption", attributes: caption.generateAttributes()))
        
        // When - Enumerate styles
        var foundStyles: [String: NSRange] = [:]
        document.enumerateAttribute(
            .textStyle,
            in: NSRange(location: 0, length: document.length),
            options: []
        ) { value, range, _ in
            if let styleName = value as? String {
                foundStyles[styleName] = range
            }
        }
        
        // Then
        XCTAssertEqual(foundStyles.count, 3, "Should find all three styles")
        XCTAssertNotNil(foundStyles[UIFont.TextStyle.title1.rawValue])
        XCTAssertNotNil(foundStyles[UIFont.TextStyle.body.rawValue])
        XCTAssertNotNil(foundStyles[UIFont.TextStyle.caption1.rawValue])
    }
}
