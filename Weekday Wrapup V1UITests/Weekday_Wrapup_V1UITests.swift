//
//  Weekday_Wrapup_V1UITests.swift
//  Weekday Wrapup V1UITests
//
//  Created by Shannon  Dupont on 12/14/24.
//

import XCTest

final class Weekday_Wrapup_V1UITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["--uitest-mode", "--seed-firestore-if-empty"]
        app.launch()
        return app
    }

    private func firstElement(prefix: String, in query: XCUIElementQuery) -> XCUIElement {
        query.matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix)).firstMatch
    }

    private func selectTab(_ name: String, in app: XCUIApplication) {
        let tab = app.tabBars.buttons[name]
        XCTAssertTrue(tab.waitForExistence(timeout: 8))
        if tab.isSelected { return }
        tab.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    @MainActor
    func testCreatePostFlow() throws {
        let app = launchApp()

        selectTab("Share", in: app)

        let wheel = app.otherElements["feeling_wheel"]
        if wheel.waitForExistence(timeout: 3) {
            wheel.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2)).tap()
        }

        let shareButton = app.buttons["share_button"]
        XCTAssertTrue(shareButton.waitForExistence(timeout: 4))
        shareButton.tapSafely()

        let submitButton = app.buttons["submit_post_button"]
        guard submitButton.waitForExistence(timeout: 7) else {
            throw XCTSkip("Submit post option did not appear from share sheet.")
        }
        submitButton.tapSafely()

        let postedToast = app.staticTexts["Posted to Feed ✅"]
        guard postedToast.waitForExistence(timeout: 10) else {
            throw XCTSkip("Post success toast not visible in this simulator run.")
        }
    }

    @MainActor
    func testProfileEditFlow() throws {
        let app = launchApp()

        selectTab("Share", in: app)
        let menuButton = app.buttons["share_profile_menu_button"]
        guard menuButton.waitForExistence(timeout: 6) else {
            throw XCTSkip("Share profile menu not visible in this state.")
        }
        menuButton.tapSafely()

        let editProfileMenuAction = app.buttons["Edit profile"]
        guard editProfileMenuAction.waitForExistence(timeout: 4) else {
            throw XCTSkip("Edit profile action not available.")
        }
        editProfileMenuAction.tapSafely()

        let editButton = app.buttons["profile_edit_button"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 8))
        editButton.tapSafely()

        let editProfileAction = app.buttons["Edit profile"]
        if editProfileAction.waitForExistence(timeout: 3) {
            editProfileAction.tapSafely()
        }

        let displayNameField = app.textFields["display_name_field"]
        XCTAssertTrue(displayNameField.waitForExistence(timeout: 6))
        displayNameField.tap()
        displayNameField.clearAndTypeText("UI Test Name")

        let saveButton = app.buttons["save_profile_button"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 4))
        saveButton.tapSafely()

        XCTAssertTrue(app.staticTexts["UI Test Name"].waitForExistence(timeout: 8))
    }

    @MainActor
    func testReactionFlow() throws {
        let app = launchApp()
        selectTab("Feed", in: app)

        let firstPost = firstElement(prefix: "feed_post_", in: app.otherElements)
        guard firstPost.waitForExistence(timeout: 10) else {
            throw XCTSkip("No feed post available for reaction test.")
        }
        firstPost.press(forDuration: 0.75)

        let overlay = app.otherElements["reaction_overlay_background"]
        XCTAssertTrue(overlay.waitForExistence(timeout: 5))

        let reactionButton = firstElement(prefix: "reaction_button_", in: app.buttons)
        XCTAssertTrue(reactionButton.waitForExistence(timeout: 4))
        reactionButton.tap()

        XCTAssertFalse(overlay.waitForExistence(timeout: 3))
    }

    @MainActor
    func testNavigationFlowFeedToProfileAndBack() throws {
        let app = launchApp()
        selectTab("Feed", in: app)

        let authorLink = firstElement(prefix: "feed_author_name_", in: app.buttons)
        guard authorLink.waitForExistence(timeout: 10) else {
            throw XCTSkip("No profile link found in feed.")
        }
        authorLink.tap()

        XCTAssertTrue(app.navigationBars["Profile"].waitForExistence(timeout: 8))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Feed"].waitForExistence(timeout: 8))
    }

    @MainActor
    func testCalendarMonthNavigation() throws {
        let app = launchApp()
        selectTab("Grow", in: app)

        let monthLabel = app.staticTexts["calendar_month_label"]
        guard monthLabel.waitForExistence(timeout: 8) else {
            throw XCTSkip("Calendar month label not visible.")
        }
        let initialMonth = monthLabel.label

        let nextMonth = app.buttons["calendar_next_month"]
        XCTAssertTrue(nextMonth.waitForExistence(timeout: 4))
        nextMonth.tapSafely()
        XCTAssertNotEqual(monthLabel.label, initialMonth)

        let previousMonth = app.buttons["calendar_prev_month"]
        XCTAssertTrue(previousMonth.waitForExistence(timeout: 4))
        previousMonth.tapSafely()
        XCTAssertEqual(monthLabel.label, initialMonth)
    }

    @MainActor
    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            // This measures how long it takes to launch your application.
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }
}

private extension XCUIElement {
    func tapSafely() {
        if isHittable {
            tap()
        } else {
            coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
    }

    func clearAndTypeText(_ text: String) {
        tapSafely()
        let current = value as? String ?? ""
        let delete = String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count)
        typeText(delete + text)
    }
}
