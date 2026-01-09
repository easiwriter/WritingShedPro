//
//  DramaMarkupTests.swift
//  Writing Shed ProTests
//
//  Feature 023: Smart Drama Creation - Tests for DML parser and renderer
//

import XCTest
@testable import Writing_Shed_Pro

final class DramaMarkupParserTests: XCTestCase {
    
    var parser: DramaMarkupParser!
    
    override func setUp() {
        super.setUp()
        parser = DramaMarkupParser.shared
    }
    
    // MARK: - Scene Heading Tests
    
    func testParseSceneHeading() {
        let source = "# ACT I, Scene 1"
        let document = parser.parse(source)
        
        XCTAssertEqual(document.elements.count, 1)
        XCTAssertEqual(document.elements[0].type, .sceneHeading)
        XCTAssertEqual(document.elements[0].content, "ACT I, Scene 1")
    }
    
    func testParseFilmSceneHeading() {
        let source = "# INT. COFFEE SHOP - DAY"
        let document = parser.parse(source)
        
        XCTAssertEqual(document.elements.count, 1)
        XCTAssertEqual(document.elements[0].type, .sceneHeading)
        XCTAssertEqual(document.elements[0].content, "INT. COFFEE SHOP - DAY")
    }
    
    // MARK: - Action/Stage Direction Tests
    
    func testParseAction() {
        let source = "> John paces near the window."
        let document = parser.parse(source)
        
        XCTAssertEqual(document.elements.count, 1)
        XCTAssertEqual(document.elements[0].type, .action)
        XCTAssertEqual(document.elements[0].content, "John paces near the window.")
    }
    
    // MARK: - Character Tests
    
    func testParseCharacter() {
        let source = """
        JOHN
        Hello there.
        """
        let document = parser.parse(source)
        
        XCTAssertEqual(document.elements.count, 2)
        XCTAssertEqual(document.elements[0].type, .character)
        XCTAssertEqual(document.elements[0].characterName, "JOHN")
        XCTAssertEqual(document.elements[1].type, .dialogue)
    }
    
    func testParseCharacterWithParenthetical() {
        let source = """
        JOHN
        (hesitantly)
        I don't think we should go.
        """
        let document = parser.parse(source)
        
        XCTAssertEqual(document.elements.count, 3)
        XCTAssertEqual(document.elements[0].type, .character)
        XCTAssertEqual(document.elements[1].type, .parenthetical)
        XCTAssertEqual(document.elements[1].parentheticalText, "hesitantly")
        XCTAssertEqual(document.elements[2].type, .dialogue)
    }
    
    // MARK: - Transition Tests
    
    func testParseTransition() {
        let source = ">> CUT TO:"
        let document = parser.parse(source)
        
        XCTAssertEqual(document.elements.count, 1)
        XCTAssertEqual(document.elements[0].type, .transition)
        XCTAssertEqual(document.elements[0].content, "CUT TO:")
    }
    
    // MARK: - Note Tests
    
    func testParseNote() {
        let source = "[[Remember to add tension here]]"
        let document = parser.parse(source)
        
        XCTAssertEqual(document.elements.count, 1)
        XCTAssertEqual(document.elements[0].type, .note)
        XCTAssertEqual(document.elements[0].noteText, "Remember to add tension here")
    }
    
    // MARK: - Metadata Tests
    
    func testParseLocationMeta() {
        let source = "@ LOCATION: Coffee Shop"
        let document = parser.parse(source)
        
        XCTAssertEqual(document.elements.count, 1)
        XCTAssertEqual(document.elements[0].type, .locationMeta)
        XCTAssertEqual(document.location, "Coffee Shop")
    }
    
    func testParseTimeMeta() {
        let source = "= Night, raining"
        let document = parser.parse(source)
        
        XCTAssertEqual(document.elements.count, 1)
        XCTAssertEqual(document.elements[0].type, .timeMeta)
        XCTAssertEqual(document.timeAtmosphere, "Night, raining")
    }
    
    // MARK: - Complex Document Tests
    
    func testParseCompleteScene() {
        let source = """
        # ACT I, Scene 1
        @ LOCATION: Living Room
        = Night, raining
        
        > A modest living room. Rain streaks the window. JOHN stands nearby, agitated.
        
        JOHN
        (hesitantly)
        I don't think we should go.
        
        MARY
        We don't have a choice.
        
        > Mary crosses to the door. John follows.
        
        JOHN
        Wait—
        
        >> BLACKOUT
        """
        
        let document = parser.parse(source)
        
        // Verify document properties
        XCTAssertEqual(document.sceneHeading, "ACT I, Scene 1")
        XCTAssertEqual(document.location, "Living Room")
        XCTAssertEqual(document.timeAtmosphere, "Night, raining")
        
        // Verify characters
        XCTAssertEqual(document.characters.count, 2)
        XCTAssertTrue(document.characters.contains("JOHN"))
        XCTAssertTrue(document.characters.contains("MARY"))
        
        // Verify dialogue blocks
        let dialogueBlocks = document.dialogueBlocks
        XCTAssertEqual(dialogueBlocks.count, 3)  // JOHN speaks twice, MARY once
    }
    
    // MARK: - Escaped Prefix Tests
    
    func testParseEscapedPrefix() {
        let source = """
        JOHN
        \\# This is not a scene heading
        """
        let document = parser.parse(source)
        
        XCTAssertEqual(document.elements.count, 2)
        XCTAssertEqual(document.elements[0].type, .character)
        XCTAssertEqual(document.elements[1].type, .dialogue)
        XCTAssertEqual(document.elements[1].content, "# This is not a scene heading")
    }
    
    // MARK: - Character Detection Edge Cases
    
    func testDoNotParseTransitionAsCharacter() {
        let source = "CUT TO:"
        let document = parser.parse(source)
        
        // Should be parsed as dialogue (default), not character
        // because CUT TO: is a known transition pattern
        XCTAssertEqual(document.elements.count, 1)
        XCTAssertNotEqual(document.elements[0].type, .character)
    }
    
    func testDoNotParseSceneHeadingAsCharacter() {
        let source = "INT. COFFEE SHOP - DAY"
        let document = parser.parse(source)
        
        // Without # prefix, this is just dialogue
        XCTAssertEqual(document.elements.count, 1)
        XCTAssertNotEqual(document.elements[0].type, .character)
    }
    
    // MARK: - Validation Tests
    
    func testValidateOrphanedParenthetical() {
        let source = """
        (whispers)
        This has no character.
        """
        let errors = parser.validate(source)
        
        XCTAssertFalse(errors.isEmpty)
        XCTAssertTrue(errors.contains { $0.message.contains("Parenthetical") })
    }
    
    func testValidateUnclosedNote() {
        let source = "[[This note is not closed"
        let errors = parser.validate(source)
        
        XCTAssertFalse(errors.isEmpty)
        XCTAssertTrue(errors.contains { $0.message.contains("closed") })
    }
}

// MARK: - Renderer Tests

final class DramaMarkupRendererTests: XCTestCase {
    
    var parser: DramaMarkupParser!
    var renderer: DramaMarkupRenderer!
    
    override func setUp() {
        super.setUp()
        parser = DramaMarkupParser.shared
        renderer = DramaMarkupRenderer.shared
    }
    
    // MARK: - Basic Rendering Tests
    
    func testRenderSourceMode() {
        let source = """
        # ACT I, Scene 1
        
        JOHN
        Hello.
        """
        
        let document = parser.parse(source)
        let rendered = renderer.render(document, scriptType: .film, viewMode: .source)
        
        XCTAssertFalse(rendered.string.isEmpty)
        XCTAssertTrue(rendered.string.contains("ACT I"))
        XCTAssertTrue(rendered.string.contains("JOHN"))
        XCTAssertTrue(rendered.string.contains("Hello"))
    }
    
    func testRenderFormattedFilmMode() {
        let source = """
        # INT. COFFEE SHOP - DAY
        
        > John sits at a table.
        
        JOHN
        (nervously)
        Hi there.
        """
        
        let document = parser.parse(source)
        let rendered = renderer.render(document, scriptType: .film, viewMode: .formatted)
        
        XCTAssertFalse(rendered.string.isEmpty)
        // Film mode should keep INT. format
        XCTAssertTrue(rendered.string.contains("INT. COFFEE SHOP"))
    }
    
    func testRenderFormattedStageMode() {
        let source = """
        # ACT I, Scene 1
        
        > John sits at a table.
        
        JOHN
        Hi there.
        """
        
        let document = parser.parse(source)
        let rendered = renderer.render(document, scriptType: .stage, viewMode: .formatted)
        
        XCTAssertFalse(rendered.string.isEmpty)
        // Stage mode wraps stage directions in parentheses
        XCTAssertTrue(rendered.string.contains("(John sits at a table.)"))
    }
    
    // MARK: - Note Visibility Tests
    
    func testNotesHiddenInFormattedMode() {
        let source = """
        JOHN
        Hello.
        
        [[This is a note]]
        """
        
        let document = parser.parse(source)
        let rendered = renderer.render(document, scriptType: .film, viewMode: .formatted, showNotes: false)
        
        XCTAssertFalse(rendered.string.contains("This is a note"))
    }
    
    func testNotesShownWhenRequested() {
        let source = """
        JOHN
        Hello.
        
        [[This is a note]]
        """
        
        let document = parser.parse(source)
        let rendered = renderer.render(document, scriptType: .film, viewMode: .formatted, showNotes: true)
        
        XCTAssertTrue(rendered.string.contains("This is a note"))
    }
}

// MARK: - Fountain Converter Tests

final class FountainConverterTests: XCTestCase {
    
    var converter: FountainConverter!
    
    override func setUp() {
        super.setUp()
        converter = FountainConverter.shared
    }
    
    // MARK: - Fountain to DML Tests
    
    func testFountainSceneHeadingToDML() {
        let fountain = "INT. COFFEE SHOP - DAY"
        let dml = converter.fountainToDML(fountain)
        
        XCTAssertTrue(dml.contains("# INT. COFFEE SHOP - DAY"))
    }
    
    func testFountainForcedSceneHeadingToDML() {
        let fountain = ".FORCED SCENE HEADING"
        let dml = converter.fountainToDML(fountain)
        
        XCTAssertTrue(dml.contains("# FORCED SCENE HEADING"))
    }
    
    func testFountainActionToDML() {
        let fountain = """
        INT. ROOM - DAY
        
        John walks into the room.
        """
        let dml = converter.fountainToDML(fountain)
        
        XCTAssertTrue(dml.contains("> John walks into the room."))
    }
    
    func testFountainDialogueToDML() {
        let fountain = """
        JOHN
        Hello there.
        """
        let dml = converter.fountainToDML(fountain)
        
        XCTAssertTrue(dml.contains("JOHN"))
        XCTAssertTrue(dml.contains("Hello there."))
    }
    
    func testFountainTransitionToDML() {
        let fountain = "CUT TO:"
        let dml = converter.fountainToDML(fountain)
        
        XCTAssertTrue(dml.contains(">> CUT TO:"))
    }
    
    // MARK: - DML to Fountain Tests
    
    func testDMLSceneHeadingToFountain() {
        let dml = "# INT. COFFEE SHOP - DAY"
        let fountain = converter.dmlToFountain(dml)
        
        XCTAssertTrue(fountain.contains("INT. COFFEE SHOP - DAY"))
    }
    
    func testDMLActionToFountain() {
        let dml = "> John walks in."
        let fountain = converter.dmlToFountain(dml)
        
        XCTAssertTrue(fountain.contains("John walks in."))
    }
    
    func testDMLDialogueToFountain() {
        let dml = """
        JOHN
        Hello there.
        """
        let fountain = converter.dmlToFountain(dml)
        
        XCTAssertTrue(fountain.contains("JOHN"))
        XCTAssertTrue(fountain.contains("Hello there."))
    }
    
    func testDMLTransitionToFountain() {
        let dml = ">> CUT TO:"
        let fountain = converter.dmlToFountain(dml)
        
        XCTAssertTrue(fountain.contains("CUT TO:"))
    }
    
    // MARK: - Round-Trip Tests
    
    func testFountainRoundTrip() {
        let original = """
        INT. COFFEE SHOP - DAY
        
        John sits at a table, reading.
        
        JOHN
        (to himself)
        This is interesting.
        
        CUT TO:
        """
        
        // Fountain → DML → Fountain
        let dml = converter.fountainToDML(original)
        let roundTripped = converter.dmlToFountain(dml)
        
        // Key elements should be preserved
        XCTAssertTrue(roundTripped.contains("INT. COFFEE SHOP"))
        XCTAssertTrue(roundTripped.contains("JOHN"))
        XCTAssertTrue(roundTripped.contains("This is interesting"))
        XCTAssertTrue(roundTripped.contains("CUT TO:"))
    }
}

// MARK: - Final Draft Converter Tests

final class FinalDraftConverterTests: XCTestCase {
    
    var converter: FinalDraftConverter!
    
    override func setUp() {
        super.setUp()
        converter = FinalDraftConverter.shared
    }
    
    // MARK: - DML to FDX Tests
    
    func testDMLToFDXBasic() {
        let dml = """
        # INT. COFFEE SHOP - DAY
        
        > John enters.
        
        JOHN
        Hello.
        """
        
        let fdx = converter.dmlToFDX(dml, title: "Test Script")
        
        XCTAssertTrue(fdx.contains("<?xml version"))
        XCTAssertTrue(fdx.contains("<FinalDraft"))
        XCTAssertTrue(fdx.contains("Test Script"))
        XCTAssertTrue(fdx.contains("Scene Heading"))
        XCTAssertTrue(fdx.contains("INT. COFFEE SHOP - DAY"))
        XCTAssertTrue(fdx.contains("Action"))
        XCTAssertTrue(fdx.contains("John enters"))
        XCTAssertTrue(fdx.contains("Character"))
        XCTAssertTrue(fdx.contains("JOHN"))
        XCTAssertTrue(fdx.contains("Dialogue"))
        XCTAssertTrue(fdx.contains("Hello"))
    }
    
    func testDMLToFDXWithTransition() {
        let dml = ">> CUT TO:"
        let fdx = converter.dmlToFDX(dml)
        
        XCTAssertTrue(fdx.contains("Transition"))
        XCTAssertTrue(fdx.contains("CUT TO:"))
    }
    
    func testDMLToFDXWithNote() {
        let dml = "[[This is a script note]]"
        let fdx = converter.dmlToFDX(dml)
        
        XCTAssertTrue(fdx.contains("Script Note"))
        XCTAssertTrue(fdx.contains("This is a script note"))
    }
    
    func testDMLToFDXWithParenthetical() {
        let dml = """
        JOHN
        (sarcastically)
        Sure, whatever.
        """
        let fdx = converter.dmlToFDX(dml)
        
        XCTAssertTrue(fdx.contains("Parenthetical"))
        XCTAssertTrue(fdx.contains("sarcastically"))
    }
    
    func testDMLToFDXEscapesXML() {
        let dml = """
        JOHN
        This has <special> & "characters"
        """
        let fdx = converter.dmlToFDX(dml)
        
        XCTAssertTrue(fdx.contains("&lt;special&gt;"))
        XCTAssertTrue(fdx.contains("&amp;"))
        XCTAssertTrue(fdx.contains("&quot;characters&quot;"))
    }
    
    // MARK: - FDX to DML Tests
    
    func testFDXToDMLBasic() {
        let fdx = """
        <?xml version="1.0" encoding="UTF-8"?>
        <FinalDraft DocumentType="Script" Template="No" Version="5">
            <Content>
                <Paragraph Type="Scene Heading">
                    <Text>INT. COFFEE SHOP - DAY</Text>
                </Paragraph>
                <Paragraph Type="Action">
                    <Text>John enters.</Text>
                </Paragraph>
                <Paragraph Type="Character">
                    <Text>JOHN</Text>
                </Paragraph>
                <Paragraph Type="Dialogue">
                    <Text>Hello.</Text>
                </Paragraph>
            </Content>
        </FinalDraft>
        """
        
        guard let dml = converter.fdxToDML(fdx) else {
            XCTFail("Failed to parse FDX")
            return
        }
        
        XCTAssertTrue(dml.contains("# INT. COFFEE SHOP - DAY"))
        XCTAssertTrue(dml.contains("> John enters."))
        XCTAssertTrue(dml.contains("JOHN"))
        XCTAssertTrue(dml.contains("Hello."))
    }
    
    func testFDXToDMLWithTransition() {
        let fdx = """
        <?xml version="1.0" encoding="UTF-8"?>
        <FinalDraft DocumentType="Script" Template="No" Version="5">
            <Content>
                <Paragraph Type="Transition">
                    <Text>CUT TO:</Text>
                </Paragraph>
            </Content>
        </FinalDraft>
        """
        
        guard let dml = converter.fdxToDML(fdx) else {
            XCTFail("Failed to parse FDX")
            return
        }
        
        XCTAssertTrue(dml.contains(">> CUT TO:"))
    }
    
    func testFDXToDMLWithParenthetical() {
        let fdx = """
        <?xml version="1.0" encoding="UTF-8"?>
        <FinalDraft DocumentType="Script" Template="No" Version="5">
            <Content>
                <Paragraph Type="Character">
                    <Text>JOHN</Text>
                </Paragraph>
                <Paragraph Type="Parenthetical">
                    <Text>(whispering)</Text>
                </Paragraph>
                <Paragraph Type="Dialogue">
                    <Text>Over here.</Text>
                </Paragraph>
            </Content>
        </FinalDraft>
        """
        
        guard let dml = converter.fdxToDML(fdx) else {
            XCTFail("Failed to parse FDX")
            return
        }
        
        XCTAssertTrue(dml.contains("JOHN"))
        XCTAssertTrue(dml.contains("(whispering)"))
        XCTAssertTrue(dml.contains("Over here."))
    }
    
    // MARK: - Round-Trip Tests
    
    func testFDXRoundTrip() {
        let original = """
        # INT. COFFEE SHOP - DAY
        
        > John sits at a table.
        
        JOHN
        (nervously)
        Hi there.
        
        >> CUT TO:
        """
        
        // DML → FDX → DML
        let fdx = converter.dmlToFDX(original)
        guard let roundTripped = converter.fdxToDML(fdx) else {
            XCTFail("Failed to round-trip through FDX")
            return
        }
        
        // Key elements should be preserved
        XCTAssertTrue(roundTripped.contains("# INT. COFFEE SHOP - DAY"))
        XCTAssertTrue(roundTripped.contains("> John sits at a table."))
        XCTAssertTrue(roundTripped.contains("JOHN"))
        XCTAssertTrue(roundTripped.contains("(nervously)"))
        XCTAssertTrue(roundTripped.contains("Hi there."))
        XCTAssertTrue(roundTripped.contains(">> CUT TO:"))
    }
}
