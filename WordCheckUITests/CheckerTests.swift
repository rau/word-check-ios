import XCTest

final class CheckerTests: XCTestCase {
    private var app: XCUIApplication!
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-lexicon", "0", "-showChecker"]
        app.launch()
        if app.buttons["Continue"].waitForExistence(timeout: 2) { app.buttons["Continue"].tap() }
    }
    func testMenuCheckerAndKeyboardDismissal() {
        app.terminate(); app.launchArguments = []; app.launch()
        XCTAssertFalse(app.tabBars.buttons["Check"].exists)
        app.buttons["gameMenu"].tap(); app.buttons["Check a word"].tap()
        let field = app.textFields["wordInput"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertFalse(app.keyboards.firstMatch.exists)
        field.tap(); field.typeText("qi")
        app.toolbars.buttons["Done"].tap()
        XCTAssertFalse(app.keyboards.firstMatch.exists)
        app.buttons["checkWord"].tap()
        XCTAssertEqual(app.staticTexts["verdict"].label, "Valid")
        XCTAssertFalse(app.keyboards.firstMatch.exists)
        app.segmentedControls["dictionaryPicker"].buttons["Collins"].tap()
        XCTAssertFalse(app.keyboards.firstMatch.exists)
        app.buttons["closeChecker"].tap()
        XCTAssertTrue(app.buttons["gameMenu"].exists)
    }
    func testRepeatedLookupAndDictionarySwitch() {
        let field = app.textFields["wordInput"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["checkWord"].isEnabled)
        XCTAssertFalse(app.staticTexts["verdict"].exists)
        field.tap()
        field.typeText("qi")
        app.buttons["checkWord"].tap()
        XCTAssertEqual(app.staticTexts["verdict"].label, "Valid")
        field.typeText("zzzz\n")
        XCTAssertEqual(app.staticTexts["verdict"].label, "Not valid")
        XCTAssertEqual(field.value as? String, "ZZZZ")
        field.typeText("ch\n")
        XCTAssertEqual(app.staticTexts["verdict"].label, "Not valid")
        app.segmentedControls["dictionaryPicker"].buttons["Collins"].tap()
        XCTAssertEqual(app.staticTexts["verdict"].label, "Valid")
        field.typeText("cat")
        XCTAssertFalse(app.staticTexts["verdict"].exists)
        app.buttons["checkWord"].tap()
        XCTAssertEqual(app.staticTexts["verdict"].label, "Valid")
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Native Liquid Glass checker"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
    func testMalformedInputAndRecovery() {
        let field = app.textFields["wordInput"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap()
        field.typeText("two words\n")
        XCTAssertEqual(app.staticTexts["verdict"].label, "Use letters A–Z only. Check one word at a time.")
        field.typeText("a\n")
        XCTAssertEqual(app.staticTexts["verdict"].label, "Enter a word with 2–15 letters.")
        field.typeText("hello\n")
        XCTAssertEqual(app.staticTexts["verdict"].label, "Valid")
    }
    func testStoreScreenshotsAndPrivacy() {
        let field = app.textFields["wordInput"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap()
        field.typeText("qi\n")
        XCTAssertEqual(app.staticTexts["verdict"].label, "Valid")
        capture("01-NASPA")
        app.segmentedControls["dictionaryPicker"].buttons["Collins"].tap()
        field.typeText("ch\n")
        XCTAssertEqual(app.staticTexts["verdict"].label, "Valid")
        capture("02-Collins")
        field.typeText("zzzz\n")
        XCTAssertEqual(app.staticTexts["verdict"].label, "Not valid")
        capture("03-Invalid")
        XCTAssertFalse(app.buttons["appInformation"].exists)
    }
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
