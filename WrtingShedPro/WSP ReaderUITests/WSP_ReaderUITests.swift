//
//  WSP_ReaderUITests.swift
//  WSP ReaderUITests
//

import XCTest

final class WSP_ReaderUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Home Screen

    @MainActor
    func testHomeScreenShowsTitle() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(
            app.navigationBars["WSP Reader"].exists ||
            app.staticTexts["WSP Reader"].exists,
            "Home screen should display 'WSP Reader' title"
        )
    }

    @MainActor
    func testHomeScreenHasAddButton() throws {
        let app = XCUIApplication()
        app.launch()
        // + button is in the navigation bar; accessibility label is "Open WSP Project"
        let addButton = app.buttons["Open WSP Project"].firstMatch
        let navButton = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(
            addButton.exists || navButton.exists,
            "A button to open a WSP file should be present on the home screen"
        )
    }

    @MainActor
    func testHomeScreenRendersWithoutCrash() throws {
        let app = XCUIApplication()
        app.launch()
        // Either empty state or recent documents list should be shown.
        let noProjects = app.staticTexts["No Projects"]
        let openButton = app.buttons["Open WSP File"]
        XCTAssertTrue(
            noProjects.exists || openButton.exists || app.cells.count > 0,
            "Home screen should show empty state or recent documents"
        )
    }

    // MARK: - Help (Catalyst only)

    @MainActor
    func testHelpMenuItemOpensSomeContent() throws {
        #if !targetEnvironment(macCatalyst)
        throw XCTSkip("Help menu only exists on Mac Catalyst")
        #endif
        let app = XCUIApplication()
        app.launch()
        let helpMenu = app.menuBars.menuBarItems["Help"]
        guard helpMenu.exists else {
            throw XCTSkip("Help menu bar item not found")
        }
        helpMenu.click()
        let helpItem = app.menuItems["WSP Reader Help"]
        XCTAssertTrue(helpItem.exists, "WSP Reader Help item should appear in the Help menu")
        helpItem.click()
        let helpTitle = app.staticTexts["WSP Reader Help"].firstMatch
        XCTAssertTrue(
            helpTitle.waitForExistence(timeout: 3),
            "Help sheet should appear after tapping WSP Reader Help"
        )
    }

    // MARK: - Performance

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
