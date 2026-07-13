import XCTest
@testable import TabTapCore

final class DoubleClickRecognizerTests: XCTestCase {
    func testRecognizesTwoClicksOnSameTarget() {
        var recognizer = DoubleClickRecognizer()

        XCTAssertFalse(recognizer.registerClick(
            timestamp: 10,
            position: PointerPosition(x: 100, y: 20),
            targetID: "tab-a"
        ))
        XCTAssertTrue(recognizer.registerClick(
            timestamp: 10.2,
            position: PointerPosition(x: 102, y: 21),
            targetID: "tab-a"
        ))
    }

    func testRejectsClicksOnDifferentTabs() {
        var recognizer = DoubleClickRecognizer()

        XCTAssertFalse(recognizer.registerClick(
            timestamp: 10,
            position: PointerPosition(x: 100, y: 20),
            targetID: "tab-a"
        ))
        XCTAssertFalse(recognizer.registerClick(
            timestamp: 10.1,
            position: PointerPosition(x: 101, y: 20),
            targetID: "tab-b"
        ))
    }

    func testRejectsSlowClicks() {
        var recognizer = DoubleClickRecognizer(maximumInterval: 0.4)

        XCTAssertFalse(recognizer.registerClick(
            timestamp: 10,
            position: PointerPosition(x: 100, y: 20),
            targetID: "tab-a"
        ))
        XCTAssertFalse(recognizer.registerClick(
            timestamp: 10.5,
            position: PointerPosition(x: 100, y: 20),
            targetID: "tab-a"
        ))
    }

    func testRejectsClicksThatMoveTooFar() {
        var recognizer = DoubleClickRecognizer(maximumDistance: 4)

        XCTAssertFalse(recognizer.registerClick(
            timestamp: 10,
            position: PointerPosition(x: 100, y: 20),
            targetID: "tab-a"
        ))
        XCTAssertFalse(recognizer.registerClick(
            timestamp: 10.1,
            position: PointerPosition(x: 110, y: 20),
            targetID: "tab-a"
        ))
    }

    func testSuccessfulDoubleClickDoesNotBecomeTripleClick() {
        var recognizer = DoubleClickRecognizer()

        XCTAssertFalse(recognizer.registerClick(
            timestamp: 10,
            position: PointerPosition(x: 100, y: 20),
            targetID: "tab-a"
        ))
        XCTAssertTrue(recognizer.registerClick(
            timestamp: 10.1,
            position: PointerPosition(x: 100, y: 20),
            targetID: "tab-a"
        ))
        XCTAssertFalse(recognizer.registerClick(
            timestamp: 10.2,
            position: PointerPosition(x: 100, y: 20),
            targetID: "tab-a"
        ))
    }
}
