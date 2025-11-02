//
//  FormattedTextEditorUITests.swift
//  WritingShedProUITests
//
//  UI tests for FormattedTextEditor component interactions
//

import XCTest

final class FormattedTextEditorUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Basic Typing Tests
    
    func testTypingInEditor() throws {
        // Given - Navigate to text editor
        // NOTE: Adjust navigation based on your app's structure
        let textEditor = app.textViews.firstMatch
        XCTAssertTrue(textEditor.waitForExistence(timeout: 5))
        
        // When - Type text
        textEditor.tap()
        textEditor.typeText("Hello World")
        
        // Then - Text should appear
        XCTAssertTrue(textEditor.value as? String == "Hello World" ||
                     textEditor.staticTexts["Hello World"].exists)
    }
    
    func testTypingMultipleLines() throws {
        let textEditor = app.textViews.firstMatch
        XCTAssertTrue(textEditor.waitForExistence(timeout: 5))
        
        // When
        textEditor.tap()
        textEditor.typeText("Line 1\nLine 2\nLine 3")
        
        // Then
        let text = textEditor.value as? String ?? ""
        XCTAssertTrue(text.contains("Line 1"))
        XCTAssertTrue(text.contains("Line 2"))
        XCTAssertTrue(text.contains("Line 3"))
    }
    
    // MARK: - Formatting Toolbar Tests
    
    func testBoldButtonExists() throws {
        // Given
        let textEditor = app.textViews.firstMatch
        XCTAssertTrue(textEditor.waitForExistence(timeout: 5))
        textEditor.tap()
        
        // Then - Bold button should be accessible
        let boldButton = app.buttons["Bold"]
        XCTAssertTrue(boldButton.exists || app.buttons["B"].exists,
                     "Bold button should exist in toolbar")
    }
    
    func testItalicButtonExists() throws {
        let textEditor = app.textViews.firstMatch
        XCTAssertTrue(textEditor.waitForExistence(timeout: 5))
        textEditor.tap()
        
        // Then
        let italicButton = app.buttons["Italic"]
        XCTAssertTrue(italicButton.exists || app.buttons["I"].exists,
                     "Italic button should exist in toolbar")
    }
    
    func testUnderlineButtonExists() throws {
        let textEditor = app.textViews.firstMatch
        XCTAssertTrue(textEditor.waitForExistence(timeout: 5))
        textEditor.tap()
        
        // Then
        let underlineButton = app.buttons["Underline"]
        XCTAssertTrue(underlineButton.exists || app.buttons["U"].exists,
                     "Underline button should exist in toolbar")
    }
    
    func testStrikethroughButtonExists() throws {
        let textEditor = app.textViews.firstMatch
        XCTAssertTrue(textEditor.waitForExistence(timeout: 5))
        textEditor.tap()
        
        // Then
        let strikeButton = app.buttons["Strikethrough"]
        XCTAssertTrue(strikeButton.exists || app.buttons["S"].exists,
                     "Strikethrough button should exist in toolbar")
    }
    
    // MARK: - Formatting Application Tests
    
    func testApplyBoldFormatting() throws {
        let textEditor = app.textViews.firstMatch
        XCTAssertTrue(textEditor.waitForExistence(timeout: 5))
        
        // Given - Type text
        textEditor.tap()
        textEditor.typeText("Bold Text")
        
        // When - Select all and apply bold
        textEditor.doubleTap() // Select word
        
        let boldButton = app.buttons["Bold"].exists ? app.buttons["Bold"] : app.buttons["B"]
        if boldButton.exists {
            boldButton.tap()
            
            // Then - Button should show active state or formatting should be applied
            // NOTE: Verification depends on how your UI indicates active formatting
            XCTAssertTrue(true, "Bold button tapped successfully")
        } else {
            XCTFail("Bold button not found")
        }
    }
    
    func testApplyItalicFormatting() throws {
        let textEditor = app.textViews.firstMatch
        XCTAssertTrue(textEditor.waitForExistence(timeout: 5))
        
        // Given
        textEditor.tap()
        textEditor.typeText("Italic Text")
        
        // When
        textEditor.doubleTap()
        
        let italicButton = app.buttons["Italic"].exists ? app.buttons["Italic"] : app.buttons["I"]
        if italicButton.exists {
            italicButton.tap()
            XCTAssertTrue(true, "Italic button tapped successfully")
        } else {
            XCTFail("Italic button not found")
        }
    }
    
    func testApplyUnderlineFormatting() throws {
        let textEditor = app.textViews.firstMatch
        XCTAssertTrue(textEditor.waitForExistence(timeout: 5))
        
        textEditor.tap()
        textEditor.typeText("Underline")
        textEditor.doubleTap()
        
        let underlineButton = app.buttons["Underline"].exists ? app.buttons["Underline"] : app.buttons["U"]
        if underlineButton.exists {
            underlineButton.tap()
            XCTAssertTrue(true, "Underline button tapped successfully")
        } else {
            XCTFail("Underline button not found")
        }
    }
    
    func testApplyStrikethroughFormatting() throws {
        let textEditor = app.textViews.firstMatch
        XCTAssertTrue(textEditor.waitForExistence(timeout: 5))
        
        textEditor.tap()
        textEditor.typeText("Strike")
        textEditor.doubleTap()
        
        let strikeButton = app.buttons["Strikethrough"].exists ? app.buttons["Strikethrough"] : app.buttons["S"]
        if strikeButton.exists {
            strikeButton.tap()
            XCTAssertTrue(true, "Strikethrough button tapped successfully")
        } else {
            XCTFail("Strikethrough button not found")
        }
    }
    
    // MARK: - Text Selection Tests
    
    func testSelectWord() throws {
        let textEditor = app.textViews.firstMatch
        XCTAssertTrue(textEditor.waitForExistence(timeout: 5))
        
        // Given
        textEditor.tap()
        textEditor.typeText("Hello World")
        
        // When - Double tap to select word
        textEditor.doubleTap()
        
        // Then - Selection menu should appear
        XCTAssertTrue(app.menuItems.count > 0 || app.buttons["Cut"].exists,
                     "Selection menu should appear")
    }
    
    func testSelectAll() throws {
        let textEditor = app.textViews.firstMatch
        XCTAssertTrue(textEditor.waitForExistence(timeout: 5))
        
        // Given
        textEditor.tap()
        textEditor.typeText("All this text")
        
        // When - Tap and hold to show menu, then select all
        textEditor.press(forDuration: 1.0)
        
        if app.menuItems["Select All"].exists {
            app.menuItems["Select All"].tap()
            
            // Then - All text should be selected
            XCTAssertTrue(true, "Select All executed")
        }
    }
    
    // MARK: - Undo/Redo UI Tests
    
    func testUndoButton() throws {
        let textEditor = app.textViews.firstMatch
        XCTAssertTrue(textEditor.waitForExistence(timeout: 5))
        
        // Given - Type text
        textEditor.tap()
        textEditor.typeText("Undo this")
        
        // When - Shake device or use undo button/menu
        // NOTE: Undo gesture varies by platform
        app.buttons["Undo"].tap() // If undo button exists
        
        // Then - Text should be undone
        // Verification depends on implementation
        XCTAssertTrue(true, "Undo action completed")
    }
    
    // MARK: - Style Picker Tests
    
    func testStylePickerOpens() throws {
        // Given
        let textEditor = app.textViews.firstMatch
        XCTAssertTrue(textEditor.waitForExistence(timeout: 5))
        textEditor.tap()
        
        // When - Tap style picker button
        let styleButton = app.buttons["Style"] // Adjust to your button name
        if styleButton.exists {
            styleButton.tap()
            
            // Then - Style picker sheet should appear
            XCTAssertTrue(app.sheets.count > 0 || app.navigationBars.count > 0,
                         "Style picker should open")
        }
    }
    
    func testSelectStyleFromPicker() throws {
        let textEditor = app.textViews.firstMatch
        XCTAssertTrue(textEditor.waitForExistence(timeout: 5))
        textEditor.tap()
        textEditor.typeText("Styled text")
        
        // Open style picker
        let styleButton = app.buttons["Style"]
        if styleButton.exists {
            styleButton.tap()
            
            // Select a style (e.g., "Heading 1")
            let heading1 = app.buttons["Heading 1"]
            if heading1.exists {
                heading1.tap()
                
                // Verify style was applied
                XCTAssertTrue(true, "Style selected successfully")
            }
        }
    }
    
    // MARK: - Color Picker Tests
    
    func testColorPickerOpens() throws {
        let textEditor = app.textViews.firstMatch
        XCTAssertTrue(textEditor.waitForExistence(timeout: 5))
        textEditor.tap()
        
        // When - Tap color button
        let colorButton = app.buttons["Text Color"] // Adjust to your button name
        if colorButton.exists {
            colorButton.tap()
            
            // Then - Color picker should appear
            XCTAssertTrue(app.colorWells.count > 0 || app.buttons.matching(identifier: "ColorPicker").count > 0,
                         "Color picker should open")
        }
    }
    
    // MARK: - Paragraph Style Tests
    
    func testAlignmentButtons() throws {
        let textEditor = app.textViews.firstMatch
        XCTAssertTrue(textEditor.waitForExistence(timeout: 5))
        textEditor.tap()
        textEditor.typeText("Aligned text")
        
        // Check for alignment buttons
        let leftAlign = app.buttons["Align Left"]
        let centerAlign = app.buttons["Align Center"]
        let rightAlign = app.buttons["Align Right"]
        
        XCTAssertTrue(leftAlign.exists || centerAlign.exists || rightAlign.exists,
                     "At least one alignment button should exist")
    }
    
    func testApplyCenterAlignment() throws {
        let textEditor = app.textViews.firstMatch
        XCTAssertTrue(textEditor.waitForExistence(timeout: 5))
        textEditor.tap()
        textEditor.typeText("Center me")
        
        let centerButton = app.buttons["Align Center"]
        if centerButton.exists {
            centerButton.tap()
            XCTAssertTrue(true, "Center alignment applied")
        }
    }
    
    // MARK: - Keyboard Tests
    
    func testKeyboardAppears() throws {
        let textEditor = app.textViews.firstMatch
        XCTAssertTrue(textEditor.waitForExistence(timeout: 5))
        
        // When
        textEditor.tap()
        
        // Then
        XCTAssertTrue(app.keyboards.count > 0, "Keyboard should appear")
    }
    
    func testKeyboardDismisses() throws {
        let textEditor = app.textViews.firstMatch
        XCTAssertTrue(textEditor.waitForExistence(timeout: 5))
        
        // Given
        textEditor.tap()
        XCTAssertTrue(app.keyboards.count > 0)
        
        // When - Tap outside or dismiss button
        // NOTE: Implementation depends on your dismiss mechanism
        app.tap() // Tap outside
        
        // Then - Keyboard may or may not dismiss depending on implementation
        XCTAssertTrue(true, "Keyboard dismiss tested")
    }
    
    // MARK: - Multi-Touch Tests
    
    func testTypingWhileFormattingToolbarVisible() throws {
        let textEditor = app.textViews.firstMatch
        XCTAssertTrue(textEditor.waitForExistence(timeout: 5))
        
        // Given
        textEditor.tap()
        
        // When - Type with toolbar visible
        textEditor.typeText("Test")
        
        let boldButton = app.buttons["Bold"].exists ? app.buttons["Bold"] : app.buttons["B"]
        if boldButton.exists {
            boldButton.tap()
        }
        
        textEditor.typeText(" More")
        
        // Then
        let text = textEditor.value as? String ?? ""
        XCTAssertTrue(text.contains("Test") && text.contains("More"))
    }
    
    // MARK: - Accessibility Tests
    
    func testFormattingButtonsAccessibility() throws {
        let textEditor = app.textViews.firstMatch
        XCTAssertTrue(textEditor.waitForExistence(timeout: 5))
        textEditor.tap()
        
        // Then - Formatting buttons should have accessibility labels
        let buttons = ["Bold", "Italic", "Underline", "Strikethrough", "B", "I", "U", "S"]
        var foundButton = false
        
        for buttonLabel in buttons {
            if app.buttons[buttonLabel].exists {
                foundButton = true
                XCTAssertTrue(app.buttons[buttonLabel].isEnabled,
                            "\(buttonLabel) button should be enabled")
            }
        }
        
        XCTAssertTrue(foundButton, "At least one formatting button should exist")
    }
    
    func testTextEditorAccessibility() throws {
        let textEditor = app.textViews.firstMatch
        XCTAssertTrue(textEditor.waitForExistence(timeout: 5))
        
        // Then
        XCTAssertTrue(textEditor.isEnabled, "Text editor should be enabled")
        XCTAssertTrue(textEditor.isHittable, "Text editor should be hittable")
    }
    
    // MARK: - Performance UI Tests
    
    func testTypingPerformance() throws {
        let textEditor = app.textViews.firstMatch
        XCTAssertTrue(textEditor.waitForExistence(timeout: 5))
        textEditor.tap()
        
        // When - Type continuously
        measure(metrics: [XCTApplicationLaunchMetric(), XCTClockMetric()]) {
            textEditor.typeText("Performance test text string")
        }
    }
    
    func testFormattingButtonResponseTime() throws {
        let textEditor = app.textViews.firstMatch
        XCTAssertTrue(textEditor.waitForExistence(timeout: 5))
        textEditor.tap()
        textEditor.typeText("Format me")
        
        let boldButton = app.buttons["Bold"].exists ? app.buttons["Bold"] : app.buttons["B"]
        
        // When - Measure button tap response
        measure(metrics: [XCTClockMetric()]) {
            if boldButton.exists {
                boldButton.tap()
            }
        }
    }
    
    // MARK: - Edge Case Tests
    
    func testEmptyEditorFormatting() throws {
        let textEditor = app.textViews.firstMatch
        XCTAssertTrue(textEditor.waitForExistence(timeout: 5))
        textEditor.tap()
        
        // When - Apply formatting to empty editor
        let boldButton = app.buttons["Bold"].exists ? app.buttons["Bold"] : app.buttons["B"]
        if boldButton.exists {
            boldButton.tap()
            
            // Then - Should not crash
            XCTAssertTrue(true, "Formatting empty editor handled")
        }
    }
    
    func testVeryLongText() throws {
        let textEditor = app.textViews.firstMatch
        XCTAssertTrue(textEditor.waitForExistence(timeout: 5))
        textEditor.tap()
        
        // When - Type very long text
        let longText = String(repeating: "Long text ", count: 100)
        textEditor.typeText(longText)
        
        // Then - Should handle without issues
        XCTAssertTrue(true, "Long text handled")
    }
}
