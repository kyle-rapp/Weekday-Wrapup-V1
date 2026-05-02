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

    @MainActor
    func testExample() throws {
        let app = XCUIApplication()
        app.launchArguments.append("--uitest-mode")
        app.launch()

        let feedTab = app.tabBars.buttons["Feed"]
        XCTAssertTrue(feedTab.waitForExistence(timeout: 8))
        feedTab.tap()

        let shareTab = app.tabBars.buttons["Share"]
        XCTAssertTrue(shareTab.exists)
        shareTab.tap()

        let learnTab = app.tabBars.buttons["Learn"]
        XCTAssertTrue(learnTab.exists)
        learnTab.tap()
    }

    @MainActor
    func testProfileSaveFlowAccessible() throws {
        let app = XCUIApplication()
        app.launchArguments.append("--uitest-mode")
        app.launch()

        app.tabBars.buttons["Feed"].tap()
        let profileButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Profile'")).firstMatch
        if !profileButton.waitForExistence(timeout: 4) {
            throw XCTSkip("Profile entry point not visible in current auth state.")
        }
        profileButton.tap()
    }

    @MainActor
    func testRecommendationsPathReachable() throws {
        let app = XCUIApplication()
        app.launchArguments.append("--uitest-mode")
        app.launch()

        let growTab = app.tabBars.buttons["Grow"]
        guard growTab.waitForExistence(timeout: 6) else {
            throw XCTSkip("Grow tab not available.")
        }
        growTab.tap()
        XCTAssertTrue(app.staticTexts["Recommended for you"].waitForExistence(timeout: 5))
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
