import XCTest

final class QuantumToyUITests: XCTestCase {
    @MainActor func testWorkbenchesAndLiveControl() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.navigationBars["Quantum Toy"].waitForExistence(timeout: 15))
        selectTab("Grover", in: app)
        let oracle = app.buttons["groverOracle"]
        reveal(oracle, in: app)
        XCTAssertTrue(oracle.isEnabled)
        oracle.tap()
        let diffuse = app.buttons["groverDiffuse"]
        XCTAssertTrue(diffuse.isEnabled)
        diffuse.tap()
        app.buttons["groverReset"].tap()
        XCTAssertTrue(oracle.isEnabled)

        selectTab("Keys", in: app)
        let recover = app.buttons["Recover toy key"]
        reveal(recover, in: app)
        recover.tap()
        XCTAssertTrue(app.staticTexts["keySearchStatus"].label.contains("recovered secret is 7"))

        selectTab("Qubit Lab", in: app)
        let run = app.buttons["qubitRun"]
        reveal(run, in: app)
        run.tap()
        XCTAssertTrue(app.buttons["qubitRun"].label.contains("Pause"))
        app.buttons["qubitRun"].tap()
        XCTAssertTrue(app.buttons["qubitRun"].label.contains("Run"))
        let tune = app.buttons["coldTune"]
        reveal(tune, in: app)
        tune.tap()
        XCTAssertTrue(app.sliders["EFFECTIVE QUBIT TEMPERATURE"].exists)
        app.buttons["modelGuide"].tap()
        XCTAssertTrue(app.navigationBars["Field guide"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
    }

    @MainActor func testShorPipelineCanRetryAndReset() {
        let app = XCUIApplication()
        app.launch()
        let next = app.buttons["shorNext"]
        reveal(next, in: app)
        XCTAssertTrue(next.exists)
        for _ in 0..<4 {
            reveal(next, in: app)
            if next.isEnabled { next.tap() }
        }
        let reset = app.buttons["shorReset"]
        reveal(reset, in: app)
        reset.tap()
        XCTAssertTrue(next.isEnabled)
    }

    @MainActor private func selectTab(_ title: String, in app: XCUIApplication) {
        let button = app.tabBars.buttons[title]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        button.tap()
    }

    @MainActor private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<10 {
            if element.exists && element.isHittable { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.exists && element.isHittable)
    }
}
