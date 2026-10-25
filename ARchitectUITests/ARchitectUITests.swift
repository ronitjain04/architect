import XCTest

final class ARchitectUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @MainActor func testAuthenticationHasRecoveryAndSignUp() throws {
        let app = XCUIApplication()
        app.launch()
        // Fresh simulator account must have a way to sign in and recover access.
        XCTAssertTrue(app.buttons["Forgot password?"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.textFields["Email"].exists)
        XCTAssertTrue(app.secureTextFields["Password"].exists)
        app.buttons["Forgot password?"].tap()
        XCTAssertTrue(app.staticTexts["Enter your email above first, then tap Forgot password."].waitForExistence(timeout: 3))
    }
}
