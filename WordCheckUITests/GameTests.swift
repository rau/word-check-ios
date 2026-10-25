import XCTest
final class GameTests: XCTestCase {
 var app:XCUIApplication!
 override func setUpWithError() throws {
  continueAfterFailure=false; app=XCUIApplication();app.launchArguments=["-freshGame","-lexicon","0"];app.launch()
  app.buttons["newGame"].tap()
  app.textFields["playerName-0"].tap();app.textFields["playerName-0"].typeText("Alex")
  app.textFields["playerName-1"].tap();app.textFields["playerName-1"].typeText("Sam")
  app.buttons["startGame"].tap()
 }
 func choose(_ index:Int){app.buttons["square-\(index)"].tap()}
 func fitBoard(){
  let board=app.scrollViews["zoomBoard"]
  let percent=Double((board.value as? String ?? "100").components(separatedBy:" ")[0]) ?? 100
  if percent > 101 { board.pinch(withScale:0.2,velocity:-2) }
 }
 func type(_ text:String){let f=app.textFields["moveWord"];f.tap();f.typeText(text)}
 func menu(_ name:String){app.buttons["gameMenu"].tap();app.buttons[name].tap()}
 func capture(_ name:String){let a=XCTAttachment(screenshot:app.screenshot());a.name=name;a.lifetime = .keepAlways;add(a)}
 func testGameEndToEndAndZoom() {
  XCTAssertFalse(app.buttons["fitBoard"].exists)
  XCTAssertFalse(app.buttons["zoomIn"].exists)
  XCTAssertFalse(app.staticTexts["moveStatus"].exists)
  choose(111);choose(113);choose(112);type("CAT\n")
  XCTAssertTrue(app.buttons["playMove"].label.contains("10"))
  app.buttons["playMove"].tap()
  XCTAssertEqual(app.staticTexts["score-0"].label,"Alex\n10")
  let board=app.scrollViews["zoomBoard"]
  fitBoard()
  let original=app.buttons["square-112"].frame.width
  // XCTest starts its pinch fingers very close together; iPad needs a wider gesture.
  board.pinch(withScale:app.frame.width > 700 ? 5 : 2,velocity:2)
  XCTAssertGreaterThan(app.buttons["square-112"].frame.width,original*1.3)
  board.swipeLeft();fitBoard()
  XCTAssertEqual(app.buttons["square-112"].frame.width,original,accuracy:2)
  choose(112);app.buttons["square-112"].doubleTap()
  XCTAssertEqual(app.buttons["square-112"].frame.width,original,accuracy:2)
  XCTAssertTrue(app.segmentedControls["moveDirection"].buttons["Down ↓"].isSelected)
  fitBoard()
  choose(113);app.segmentedControls["moveDirection"].buttons["Down ↓"].tap();type("T\n")
  XCTAssertTrue(app.buttons["playMove"].label.contains("3"));app.buttons["playMove"].tap()
  XCTAssertEqual(app.staticTexts["score-1"].label,"Sam\n3")
  menu("Pass turn");app.alerts.buttons["Pass"].tap()
  XCTAssertFalse(app.staticTexts["currentTurn"].exists)
  menu("Undo last turn");app.alerts.buttons["Undo"].tap()
  XCTAssertFalse(app.staticTexts["currentTurn"].exists)
  app.terminate();app.launchArguments=[];app.launch()
  XCTAssertEqual(app.staticTexts["score-0"].label,"Alex\n10")
  XCTAssertEqual(app.staticTexts["score-1"].label,"Sam\n3")
  choose(0);type("DOG\n");app.buttons["playMove"].tap();XCTAssertTrue(app.alerts["Check placement"].exists);app.alerts.buttons["OK"].tap()
  app.buttons["Clear draft"].tap()
  menu("Finish game");app.textFields["rack-1"].tap();app.textFields["rack-1"].typeText("QZ")
  app.segmentedControls["wentOut"].buttons["Alex"].tap();app.buttons["finishGame"].tap()
  XCTAssertEqual(app.staticTexts["score-0"].label,"Alex\n30")
  XCTAssertEqual(app.staticTexts["score-1"].label,"Sam\n-17")
  XCTAssertEqual(app.staticTexts["currentTurn"].label,"Alex wins")
  menu("Undo last turn");app.alerts.buttons["Undo"].tap();XCTAssertTrue(app.textFields["moveWord"].exists)
 }
 func testAutomaticIntersectionsAndBackspace() {
  choose(112);type("CAT\n");app.buttons["playMove"].tap()
  choose(97);app.segmentedControls["moveDirection"].buttons["Down ↓"].tap()
  type("A")
  let field=app.textFields["moveWord"]
  XCTAssertEqual(field.value as? String,"AC")
  field.typeText("T");XCTAssertEqual(field.value as? String,"ACT")
  field.typeText(XCUIKeyboardKey.delete.rawValue);XCTAssertEqual(field.value as? String,"AC")
  field.typeText(XCUIKeyboardKey.delete.rawValue);XCTAssertEqual(field.value as? String,"Word")
  XCTAssertTrue(app.buttons["square-112"].label.contains("C"))
  field.typeText("AT\n");XCTAssertEqual(field.value as? String,"ACT")
  app.buttons["playMove"].tap()
  XCTAssertEqual(app.staticTexts["score-1"].label,"Sam\n5")
  XCTAssertTrue(app.buttons["square-112"].label.contains("C"))
 }
 func testStandaloneBlankCrossing() {
  choose(112);type("CAT\n");app.buttons["playMove"].tap()
  choose(97);app.segmentedControls["moveDirection"].buttons["Down ↓"].tap()
  type("?");let field=app.textFields["moveWord"]
  XCTAssertEqual(field.value as? String,"?C")
  field.typeText("T");XCTAssertEqual(field.value as? String,"?CT")
  field.typeText(XCUIKeyboardKey.delete.rawValue);XCTAssertEqual(field.value as? String,"?C")
  field.typeText(XCUIKeyboardKey.delete.rawValue);XCTAssertEqual(field.value as? String,"Word")
  field.typeText("??\n");XCTAssertEqual(field.value as? String,"?C?")
  app.buttons["playMove"].tap()
  XCTAssertTrue(app.textFields["blankLetter"].waitForExistence(timeout:3))
  app.textFields["blankLetter"].typeText("A");app.alerts.buttons["Continue"].tap()
  XCTAssertTrue(app.textFields["blankLetter"].waitForExistence(timeout:3))
  app.textFields["blankLetter"].typeText("T");app.alerts.buttons["Continue"].tap()
  XCTAssertEqual(app.staticTexts["score-1"].label,"Sam\n3")
  XCTAssertTrue(app.buttons["square-97"].label.contains("A, blank"))
  XCTAssertTrue(app.buttons["square-127"].label.contains("T, blank"))
  XCTAssertTrue(app.buttons["square-112"].label.contains("C, 3 points"))
 }
 func testBlankAppearance() {
  choose(112);type("?T\n")
  XCTAssertTrue(app.buttons["square-112"].label.contains("?, blank"));capture("Pending-blank")
  app.buttons["playMove"].tap();assignBlank("A")
  XCTAssertTrue(app.buttons["square-112"].label.contains("A, blank"));capture("Played-blank")
 }
 func assignBlank(_ letter:String) {
  XCTAssertTrue(app.textFields["blankLetter"].waitForExistence(timeout:3))
  app.textFields["blankLetter"].typeText(letter);app.alerts.buttons["Continue"].tap()
 }
 func testTypedBlanksAndFAQ() {
  choose(112);type("?AT\n")
  XCTAssertFalse(app.staticTexts["moveStatus"].exists)
  XCTAssertFalse(app.staticTexts["currentTurn"].exists)
  app.buttons["playMove"].tap();assignBlank("C")
  XCTAssertEqual(app.staticTexts["score-0"].label,"Alex\n4")
  XCTAssertTrue(app.buttons["square-112"].label.contains("blank"))
  menu("FAQ")
  XCTAssertTrue(app.navigationBars["FAQ"].waitForExistence(timeout:3))
  XCTAssertTrue(app.staticTexts["How do I enter a blank?"].exists)
  app.buttons["Done"].tap()
  menu("Pass turn")
  XCTAssertTrue(app.alerts.staticTexts["Pass turn"].exists)
  app.alerts.buttons["Pass"].tap()
 }
 func testSelectionAppearance() {
  choose(112);type("CAT\n")
  let clear=app.buttons["Clear draft"]
  XCTAssertEqual(clear.frame.width,clear.frame.height,accuracy:0.5)
  capture("Across-selection")
  app.buttons["square-112"].doubleTap()
  XCTAssertTrue(app.segmentedControls["moveDirection"].buttons["Down ↓"].isSelected)
  capture("Down-selection")
 }
 func testChallengeAndNativeHistory() {
  choose(112);type("Z?\n")
  XCTAssertTrue(app.buttons["playMove"].isEnabled)
  XCTAssertFalse(app.staticTexts["moveStatus"].exists)
  app.buttons["playMove"].tap();assignBlank("Z")
  menu("Challenge last play");app.alerts.buttons["Challenge"].tap()
  XCTAssertTrue(app.alerts["Challenge successful"].waitForExistence(timeout:3));app.alerts.buttons["OK"].tap()
  XCTAssertEqual(app.staticTexts["score-0"].label,"Alex\n0")
  XCTAssertFalse(app.staticTexts["currentTurn"].exists)
  menu("History")
  XCTAssertTrue(app.staticTexts["ZZ"].waitForExistence(timeout:3))
  XCTAssertTrue(app.staticTexts["Alex · Challenged successfully\nAlex +20"].exists)
  capture("Challenge-history");app.buttons["Done"].tap()
  choose(112);type("CAT\n");app.buttons["playMove"].tap()
  menu("Challenge last play");app.alerts.buttons["Challenge"].tap()
  XCTAssertTrue(app.alerts["Challenge unsuccessful"].waitForExistence(timeout:3));app.alerts.buttons["OK"].tap()
  XCTAssertFalse(app.staticTexts["currentTurn"].exists)
 }
 func testSwitchDictionaryDuringGame() {
  choose(112);type("CAT\n");app.buttons["playMove"].tap()
  choose(112);app.segmentedControls["moveDirection"].buttons["Down ↓"].tap();type("H\n")
  XCTAssertTrue(app.buttons["playMove"].isEnabled)
  app.segmentedControls["gameDictionary"].buttons["Collins"].tap()
  XCTAssertTrue(app.buttons["playMove"].label.contains("7"))
  XCTAssertEqual(app.staticTexts["score-0"].label,"Alex\n10")
  app.buttons["playMove"].tap();XCTAssertEqual(app.staticTexts["score-1"].label,"Sam\n7")
  app.terminate();app.launchArguments=[];app.launch()
  XCTAssertTrue(app.segmentedControls["gameDictionary"].buttons["Collins"].isSelected)
  app.segmentedControls["gameDictionary"].buttons["NASPA"].tap()
  XCTAssertEqual(app.staticTexts["score-1"].label,"Sam\n7")
 }
 func testFourPlayersAndCollins() {
  menu("New game");app.alerts.buttons["New game"].tap()
  app.segmentedControls["playerCount"].buttons["4 players"].tap()
  app.segmentedControls["setupDictionary"].buttons["Collins"].tap();app.buttons["startGame"].tap()
  XCTAssertTrue(app.staticTexts["score-3"].exists)
  choose(112);type("CH\n");XCTAssertTrue(app.buttons["playMove"].label.contains("14"))
  app.buttons["playMove"].tap()
  for _ in 0..<3 {
   menu("Pass turn");app.alerts.buttons["Pass"].tap();XCTAssertFalse(app.staticTexts["currentTurn"].exists)
  }
 }
 func testTabletLandscapeKeyboard() throws {
  XCUIDevice.shared.orientation = .landscapeLeft
  defer {XCUIDevice.shared.orientation = .portrait}
  choose(112);type("CAT")
  XCTAssertTrue(app.buttons["playMove"].isHittable)
  XCTAssertTrue(app.scrollViews["zoomBoard"].isHittable)
  app.buttons["playMove"].tap()
  XCTAssertEqual(app.staticTexts["score-0"].label,"Alex\n10")
  capture("Tablet-landscape")
 }
 func testBoardScreenshotsAndBlanks() {
  choose(109);type("READING\n");XCTAssertTrue(app.buttons["playMove"].isEnabled);app.buttons["playMove"].tap()
  choose(97);app.segmentedControls["moveDirection"].buttons["Down ↓"].tap();type("A\n");XCTAssertTrue(app.buttons["playMove"].isEnabled);app.buttons["playMove"].tap()
  fitBoard();capture("01-Board")
  let zoom=app.scrollViews["zoomBoard"]
  let before=app.buttons["square-112"].frame.width
  zoom.pinch(withScale:app.frame.width > 700 ? 5 : 2,velocity:2)
  if app.buttons["square-112"].frame.width < before*1.2 { zoom.pinch(withScale:2,velocity:1) }
  XCTAssertGreaterThan(app.buttons["square-112"].frame.width,before*1.2)
  capture("02-Zoom")
  fitBoard();choose(109);app.segmentedControls["moveDirection"].buttons["Across →"].tap();type("?\n")
  XCTAssertTrue(app.buttons["playMove"].isEnabled)
  app.buttons["playMove"].tap();assignBlank("S");XCTAssertTrue(app.buttons["square-116"].label.contains("blank"))
  capture("03-Score")
 }
 func testCancelActionsPreserveGameAndExchangeAdvancesTurn() {
  choose(112);type("CAT\n");app.buttons["playMove"].tap()
  for action in ["Pass turn","Exchange tiles","Undo last turn","New game","Challenge last play"] {
   menu(action);app.alerts.buttons["Cancel"].tap()
   XCTAssertEqual(app.staticTexts["score-0"].label,"Alex\n10")
   XCTAssertEqual(app.staticTexts["score-1"].value as? String,"Current turn")
   XCTAssertTrue(app.buttons["square-112"].label.contains("C"))
  }
  menu("Exchange tiles")
  XCTAssertTrue(app.alerts.staticTexts["Exchange tiles?"].exists)
  app.alerts.buttons["Exchange"].tap()
  XCTAssertEqual(app.staticTexts["score-0"].value as? String,"Current turn")
  menu("History");XCTAssertTrue(app.staticTexts["Exchange"].exists);app.buttons["Done"].tap()
 }
 func testBlankAssignmentCancelAndInvalidLetterRecovery() {
  choose(112);type("?T\n");app.buttons["playMove"].tap()
  XCTAssertTrue(app.textFields["blankLetter"].waitForExistence(timeout:3))
  app.alerts.buttons["Cancel"].tap()
  XCTAssertEqual(app.staticTexts["score-0"].label,"Alex\n0")
  XCTAssertEqual(app.textFields["moveWord"].value as? String,"?T")
  app.buttons["playMove"].tap();assignBlank("12")
  XCTAssertTrue(app.textFields["blankLetter"].waitForExistence(timeout:3))
  assignBlank("A")
  XCTAssertEqual(app.staticTexts["score-0"].label,"Alex\n2")
  XCTAssertTrue(app.buttons["square-112"].label.contains("A, blank"))
 }
 func testSetupRejectsDuplicateNamesAndUsesDefaultNames() {
  menu("New game");app.alerts.buttons["New game"].tap()
  app.textFields["playerName-0"].tap();app.textFields["playerName-0"].typeText("Alex")
  app.textFields["playerName-1"].tap();app.textFields["playerName-1"].typeText("alex")
  app.buttons["startGame"].tap()
  XCTAssertTrue(app.alerts["Check the details"].exists);app.alerts.buttons["OK"].tap()
  app.navigationBars.buttons["Cancel"].tap()
  XCTAssertEqual(app.staticTexts["score-0"].label,"Alex\n0")
  menu("New game");app.alerts.buttons["New game"].tap()
  app.segmentedControls["playerCount"].buttons["3 players"].tap()
  app.buttons["startGame"].tap()
  XCTAssertEqual(app.staticTexts["score-2"].label,"Player 3\n0")
  menu("History")
  XCTAssertTrue(app.navigationBars["History"].waitForExistence(timeout:3))
  // UIKit exposes the empty table to accessibility, not the decorative message.
  XCTAssertTrue(app.tables["Empty list"].waitForExistence(timeout:3))
  capture("Empty-history")
  XCTAssertEqual(app.tables.cells.count,0)
  app.buttons["Done"].tap()
 }

}
