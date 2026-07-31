import XCTest

final class ReplayKitAppUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
    }

    @MainActor
    func testWelcomeScreenAndMenuNavigation() throws {
        let app = XCUIApplication()
        app.launch()

        // Verify title exists
        let welcomeHeader = app.staticTexts["Broadcast Client"]
        XCTAssertTrue(welcomeHeader.exists)
        
        // Verify all 4 options are visible as button/cards
        XCTAssertTrue(app.staticTexts["A) In-App Screen Recording"].exists)
        XCTAssertTrue(app.staticTexts["B) In-App Raw Frame Capture"].exists)
        XCTAssertTrue(app.staticTexts["C) System Wide - Screen Broadcast"].exists)
        XCTAssertTrue(app.staticTexts["D) Rolling Clips Recording"].exists)
        
        // Tap first option card to navigate to In-App Screen Recording view
        app.staticTexts["A) In-App Screen Recording"].tap()
        
        // Verify we navigated to the recording screen
        XCTAssertTrue(app.staticTexts["In-App Screen Recording"].exists)
        
        // Go back
        app.navigationBars.buttons.element(boundBy: 0).tap()
        
        // Verify we are back on the welcome dashboard
        XCTAssertTrue(app.staticTexts["Broadcast Client"].exists)
    }
}
